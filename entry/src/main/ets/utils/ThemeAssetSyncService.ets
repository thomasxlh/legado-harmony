import { Context } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';
import hilog from '@ohos.hilog';
import relationalStore from '@ohos.data.relationalStore';
import { AppDatabase, ThemeAssetRow } from '../model/data/AppDatabase';
import { CloudSyncService, CloudSyncOutcome } from './CloudSyncService';

/** 本地扫描到的单个主题图片文件。 */
class LocalThemeFile {
  /** filesDir 下相对路径（目录名/文件名，含相册子目录），与 theme_assets.assetKey 同构。 */
  assetKey: string = '';
  /** filesDir 下绝对路径。 */
  filePath: string = '';
  size: number = 0;
}

/**
 * 主题/背景图片的端云同步桥。
 *
 * 图片本体在 filesDir 下（theme_startups/main_backgrounds/reader_backgrounds/
 * cover_albums），端云分布式表只能同步 RDB 行与 ASSET 列。按官方约束
 * "资产文件需要存放到分布式文件路径下"，每张图片镜像到
 * distributedFilesDir/theme_assets/<assetKey>，Asset uri 用规范
 * file://<bundle>/... 形式（系统服务跨进程定位沙箱挂载点），path 用
 * distributedFilesDir 下相对路径（引擎下行组 uri = 规范前缀 + path），
 * 后以 theme_assets 表（assetKey = filesDir 相对路径，跨设备稳定）上云。
 * 旧版 uri/path 均为裸绝对路径：上传恒 1017（CloudKitSA 无法解析应用
 * 命名空间内路径），下行 uri 翻倍、附件 jsonParse fail——详见 uploadAsset
 * 注释的实测记录。
 *
 * 注意：debug 安装下上传恒报 1017 path is not exist——实测
 * /proc/<pid>/mounts：cloudkit/dds 对 debug hap（/mnt/debugtmp/...）不挂载
 * el2/distributedfiles，对 release 应用（/mnt/sandbox/...）则完整挂载；
 * 属安装形态限制而非代码缺陷，完整验证需 release 签名安装。
 *
 * 上行：本地扫描发现的文件镜像后入库；下行：云同步会话把资产下载回镜像路径
 * （同 bundle 沙箱路径跨设备一致），再复制回 filesDir 原位，偏好里记录的
 * 绝对路径即直接生效。删除直接硬删行：引擎原生传播行删除，云端记录数随之
 * 收敛，不再保留墓碑行（旧版"行保留防复活"会让云端记录只增不减）。
 *
 * known 集合（device_meta）记录本机已确认落库的 assetKey，用于区分
 * “行被上游删除（本机文件应随删，防止重新上传复活）”与“另一台设备新上传
 * （应下行到本地）”。reader_fonts 刻意不参与（字体文件大、走 WebDAV）。
 */
export class ThemeAssetSyncService {
  /** 参与端云同步的图片目录（filesDir 下，含子目录递归扫描）。 */
  static readonly SYNC_DIRS: string[] = [
    'theme_startups',
    'main_backgrounds',
    'reader_backgrounds',
    'cover_albums'
  ];

  private static readonly MIRROR_ROOT: string = 'theme_assets';
  private static readonly KNOWN_KEYS_META: string = 'theme_asset_known_keys';
  /** 云同步会话定稿后稍等片刻再对账，让 RDB 侧的资产下载落稳。 */
  private static readonly SESSION_SETTLE_DELAY_MS: number = 800;
  /** 启动对账的延迟：错开冷启动高峰。 */
  private static readonly STARTUP_DELAY_MS: number = 3000;
  private static readonly TAG: string = 'ThemeAssetSync';

  private static attached: boolean = false;
  private static context: Context | null = null;
  private static checkTimer: number = -1;
  private static running: boolean = false;
  private static rerunNeeded: boolean = false;
  /** 本进程是否已重传过 ABNORMAL 资产（限一次，避免失败重传循环）。 */
  private static abnormalHealed: boolean = false;
  /** 本进程是否已发起过云端优先恢复同步（解除 409 版本冲突循环）。 */
  private static cloudFirstHealed: boolean = false;
  /** 资产下行落盘完成后的回调（EntryAbility 注册：重绑当前自定义方案的图片路径）。 */
  private static onAssetsRestored: (() => void) | null = null;

  /** 挂载同步桥：注册云同步会话回调并安排启动对账。幂等，进程内只需调用一次。 */
  static attach(context: Context): void {
    if (ThemeAssetSyncService.attached) {
      return;
    }
    ThemeAssetSyncService.attached = true;
    ThemeAssetSyncService.context = context;
    hilog.info(0x0000, ThemeAssetSyncService.TAG, 'attach: context ready');
    CloudSyncService.addSessionListener((outcome: CloudSyncOutcome): void => {
      ThemeAssetSyncService.scheduleCheck(ThemeAssetSyncService.SESSION_SETTLE_DELAY_MS);
    });
    // 启动对账：应用上一进程/其他设备下载到 RDB 的资产行，以及上传本地新增图片。
    ThemeAssetSyncService.scheduleCheck(ThemeAssetSyncService.STARTUP_DELAY_MS);
  }

  /**
   * 立即执行一轮对账（保留串行保护），供前台/后台切换在 requestAutoSync 之前
   * 调用，让本轮会话能带上对账产生的行变更。
   */
  static reconcileNow(): Promise<void> {
    return ThemeAssetSyncService.runReconcile();
  }

  /** 注册资产下行落盘回调；传 null 注销。回调在对账串行保护之外触发，须自行防抖。 */
  static setOnAssetsRestored(callback: (() => void) | null): void {
    ThemeAssetSyncService.onAssetsRestored = callback;
  }

  private static scheduleCheck(delayMs: number): void {
    if (!ThemeAssetSyncService.context) {
      return;
    }
    if (ThemeAssetSyncService.checkTimer >= 0) {
      return;
    }
    ThemeAssetSyncService.checkTimer = setTimeout((): void => {
      ThemeAssetSyncService.checkTimer = -1;
      ThemeAssetSyncService.runReconcile().catch((error: Error): void => {
        hilog.warn(0x0000, ThemeAssetSyncService.TAG,
          'reconcile failed: %{public}s', error.message);
      });
    }, delayMs);
  }

  private static async runReconcile(): Promise<void> {
    if (ThemeAssetSyncService.running) {
      hilog.info(0x0000, ThemeAssetSyncService.TAG, 'runReconcile: skipped, already running');
      ThemeAssetSyncService.rerunNeeded = true;
      return;
    }
    ThemeAssetSyncService.running = true;
    hilog.info(0x0000, ThemeAssetSyncService.TAG, 'runReconcile: begin');
    try {
      const context = ThemeAssetSyncService.context;
      if (!context) {
        return;
      }
      await ThemeAssetSyncService.doReconcile(context);
    } catch (error) {
      hilog.warn(0x0000, ThemeAssetSyncService.TAG,
        'reconcile error: %{public}s', `${error}`);
    } finally {
      ThemeAssetSyncService.running = false;
      if (ThemeAssetSyncService.rerunNeeded) {
        ThemeAssetSyncService.rerunNeeded = false;
        ThemeAssetSyncService.scheduleCheck(ThemeAssetSyncService.SESSION_SETTLE_DELAY_MS);
      }
    }
  }

  /** 判断行资产是否处于待云端确认状态（两套状态编号的 NORMAL=0/1 之外，或带高位标志）。 */
  private static isPendingCloudStatus(row: ThemeAssetRow): boolean {
    if (!row.asset) {
      return false;
    }
    const statusNum = Number(row.asset.status);
    return statusNum >= 0x80000000 || (statusNum !== 0 && statusNum !== 1);
  }

  /**
   * 端云 409 版本冲突死循环自愈（每进程一轮）：此前轮次的资产创建/修订更新
   * 已推高云端记录版本，本地基线未跟上时记录保存恒 409；且引擎的重试会话
   * 常驻 CloudSyncer，云端优先任务会被"another task is running"静默挤掉
   * （进度回调是 store 级的，任务级 Abort 无通知）。因此这里反复提交
   * CLOUD_FIRST 会话抢 syncer 空隙，每次会话终态后以数据行状态为准复验：
   * 待确认行清零即停，否则隔 5 秒再试，最多 6 次。行状态带墓碑时不做
   * （避免云端优先把本机删除的墓碑行用云端内容复活）。
   */
  private static async healPendingCloudLoop(db: AppDatabase): Promise<void> {
    if (ThemeAssetSyncService.cloudFirstHealed) {
      return;
    }
    const initial = await db.getThemeAssetRows();
    if (initial.size === 0) {
      return;
    }
    let pendingCloud = false;
    let tombstoned = false;
    for (const row of initial.values()) {
      if (row.deletedAt > 0) {
        tombstoned = true;
        break;
      }
      if (ThemeAssetSyncService.isPendingCloudStatus(row)) {
        pendingCloud = true;
      }
    }
    // 每进程只跑一轮，无论结果如何。
    ThemeAssetSyncService.cloudFirstHealed = true;
    if (!pendingCloud || tombstoned) {
      return;
    }
    hilog.info(0x0000, ThemeAssetSyncService.TAG, 'heal: pending-cloud rows detected, start cloud-first loop');
    for (let attempt = 1; attempt <= 6; attempt++) {
      const finished = await CloudSyncService.requestCloudFirstHealAsync(['theme_assets']);
      const fresh = await db.getThemeAssetRows();
      let pending = 0;
      for (const row of fresh.values()) {
        if (row.deletedAt > 0) {
          continue;
        }
        if (ThemeAssetSyncService.isPendingCloudStatus(row)) {
          pending += 1;
        }
      }
      hilog.info(0x0000, ThemeAssetSyncService.TAG,
        'heal: attempt %{public}d, sessionSeen=%{public}s, pendingRows=%{public}d',
        attempt, finished ? 'y' : 'n', pending);
      if (pending === 0) {
        return;
      }
      await ThemeAssetSyncService.sleepMs(5 * 1000);
    }
    hilog.warn(0x0000, ThemeAssetSyncService.TAG, 'heal: attempts exhausted, pending rows remain');
  }

  private static sleepMs(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout((): void => {
        resolve();
      }, ms);
    });
  }

  private static async doReconcile(context: Context): Promise<void> {
    const db = AppDatabase.getInstance();
    hilog.info(0x0000, ThemeAssetSyncService.TAG, 'doReconcile: waiting db init');
    await db.initWithContext(context);
    hilog.info(0x0000, ThemeAssetSyncService.TAG, 'doReconcile: db ready, querying rows');
    // 端云版本冲突自愈（每进程一轮）：必须在读行/对账前完成——云端优先拉取
    // 可能覆盖本地行，旧快照会把对账引向错误分支。
    await ThemeAssetSyncService.healPendingCloudLoop(db);
    const rows = await db.getThemeAssetRows();
    hilog.info(0x0000, ThemeAssetSyncService.TAG, 'doReconcile: rows=%{public}d, loading known keys', rows.size);
    const known = await ThemeAssetSyncService.loadKnownKeys(db);
    hilog.info(0x0000, ThemeAssetSyncService.TAG, 'doReconcile: known=%{public}d, scanning local files', known.size);
    const localFiles = await ThemeAssetSyncService.scanLocalFiles(context);
    // assetKey 跨设备稳定，按字典序排序即可，不依赖扫描序——避免探针式轮换造成的
    // uri 漂移与全员误重传。
    localFiles.sort((a: LocalThemeFile, b: LocalThemeFile): number => a.assetKey < b.assetKey ? -1 : 1);
    hilog.info(0x0000, ThemeAssetSyncService.TAG, 'doReconcile: localFiles=%{public}d', localFiles.length);
    const localKeys = new Set<string>();
    for (const item of localFiles) {
      localKeys.add(item.assetKey);
    }
    let knownDirty = false;
    // ABNORMAL 重传每进程放行一整轮（而非只放行第一个命中的资产行）。
    const doHealAbnormal = !ThemeAssetSyncService.abnormalHealed;

    // 分支一：本地文件驱动——新增/变更上行，上游删除下行清理。
    for (const item of localFiles) {
      const row = rows.get(item.assetKey);
      if (row && row.deletedAt > 0) {
        // 遗留墓碑行（另一台设备旧版对账置的 deletedAt）：删除本地文件。
        // 行的硬删除由分支二统一清理，云端记录数随之收敛。
        ThemeAssetSyncService.deleteLocalFile(item.filePath);
        if (known.has(item.assetKey)) {
          known.delete(item.assetKey);
          knownDirty = true;
        }
        continue;
      }
      if (!row && known.has(item.assetKey)) {
        // 行已被引擎删除（上游硬删除传播到位），本机文件仍在：随上游一起删，
        // 防止下一轮对账把文件重新上传、行复活。known 只在行确认落库后加入
        //（见 uploadAsset 返回值），不会误伤上传失败的文件。
        ThemeAssetSyncService.deleteLocalFile(item.filePath);
        known.delete(item.assetKey);
        knownDirty = true;
        continue;
      }
      const remoteSize = row && row.asset ? Number(row.asset.size) : -1;
      // 上传失败被引擎置为 ABNORMAL 的资产行，重启后重传（每进程一轮，防止失败循环）。
      // 注意 getAsset 读回的是 native 状态编号（ABNORMAL=5），与 d.ts 枚举（=4）错一格，
      // 必须用 AppDatabase.isAssetAbnormalStatus 而不能直接比枚举。
      const abnormal = doHealAbnormal && row && row.asset &&
        AppDatabase.isAssetAbnormalStatus(row.asset.status);
      // 行内资产 uri 与当前格式不符（旧版裸绝对路径/翻倍形式遗留）：重刷行
      // 重传，让云端记录换上新格式（uri=规范 file:// 形式）。裸镜像路径也
      // 放行——本机旧版刚上传的行尚未来得及重刷时不至于立刻触发重传循环。
      const expectedRawUri = row ?
        ThemeAssetSyncService.mirrorPath(context, row.assetKey) : '';
      const expectedCanonicalUri = row ?
        ThemeAssetSyncService.canonicalUri(context, ThemeAssetSyncService.mirrorPath(context, row.assetKey)) : '';
      const relocated = row && row.asset && row.asset.uri !== expectedRawUri &&
        row.asset.uri !== expectedCanonicalUri;
      hilog.info(0x0000, ThemeAssetSyncService.TAG,
        'branch-one: %{public}s hasRow=%{public}s remoteSize=%{public}d size=%{public}d abnormal=%{public}s relocated=%{public}s',
        item.assetKey, row !== undefined ? 'y' : 'n', remoteSize, item.size,
        abnormal ? 'y' : 'n', relocated ? 'y' : 'n');
      let landed = row !== undefined;
      if (!row || !row.asset || remoteSize !== item.size || abnormal || relocated) {
        if (abnormal) {
          ThemeAssetSyncService.abnormalHealed = true;
        }
        landed = await ThemeAssetSyncService.uploadAsset(context, db, item);
      }
      // known 只记确认落库的行：行缺席 + known 在册 = 上游已删除（见分支一防复活）。
      // 上传失败不记，下一轮照常重试，也不会被误判为上游删除而清掉本地文件。
      if (landed && !known.has(item.assetKey)) {
        known.add(item.assetKey);
        knownDirty = true;
      }
    }

    // 分支二：行驱动——本机删除硬删行传播，云端新资源下行，遗留墓碑清理。
    let restoredAnyAsset = false;
    for (const row of rows.values()) {
      if (row.deletedAt > 0) {
        // 遗留墓碑行（本机或旧版设备所置）：云端记录只增不减的元凶。硬删除让
        // 引擎把删除传播到云端，记录数收敛；各设备本地文件由分支一按
        // "行缺席 + known 在册"清理，不会复活。
        await db.deleteThemeAssetRow(row.assetKey);
        continue;
      }
      if (localKeys.has(row.assetKey)) {
        continue;
      }
      if (known.has(row.assetKey)) {
        // 本机此前确认落库过该行而现在文件没了：本机删除 → 硬删行传播删除意图，
        // 云端记录数收敛；其他设备收到行删除后由分支一清文件防复活。
        await db.deleteThemeAssetRow(row.assetKey);
        known.delete(row.assetKey);
        knownDirty = true;
        continue;
      }
      // 未见过的行：另一台设备上传 → 把资产从镜像路径复制回 filesDir 原位。
      hilog.info(0x0000, ThemeAssetSyncService.TAG,
        'row-driven: %{public}s asset=%{public}s',
        row.assetKey, row.asset ?
          `status=${row.asset.status} uri=${row.asset.uri} size=${row.asset.size}` : 'null');
      const downloaded = await ThemeAssetSyncService.downloadAsset(context, row);
      if (downloaded) {
        restoredAnyAsset = true;
        known.add(row.assetKey);
        knownDirty = true;
      }
    }

    if (knownDirty) {
      await db.setDeviceMetaValue(ThemeAssetSyncService.KNOWN_KEYS_META,
        JSON.stringify(Array.from(known)));
    }
    // 资产落盘后通知宿主（EntryAbility）重绑当前自定义方案的图片路径：方案行的
    // 下行应用可能早于文件落盘，Image 组件不会因文件后来出现而自动重试加载。
    if (restoredAnyAsset && ThemeAssetSyncService.onAssetsRestored) {
      try {
        ThemeAssetSyncService.onAssetsRestored();
      } catch (error) {
        hilog.warn(0x0000, ThemeAssetSyncService.TAG,
          'onAssetsRestored callback failed: %{public}s', `${error}`);
      }
    }
  }

  /**
   * 把本地图片镜像到 distributedFilesDir/theme_assets/<assetKey>，再以 Asset 值
   * 写入 theme_assets 行上云。行确认落库返回 true。
   *
   * 格式依据（2026-10-26 真机 hilog 实测，市场版 4.1.0）：
   * - 旧格式（uri/path 均为镜像裸绝对路径）在 release 下同样上传失败——
   *   CloudKitSA "RecordAssetToUploadAsset ... canonical and check path failed"，
   *   batchUpdateResult 1017 "path is not exist"：裸 /data/storage/... 是应用
   *   沙箱挂载命名空间内的路径，系统服务进程无法据此定位文件；云端仅产生
   *   mode=temp 孤儿记录，fetch 永不返回，资产内容更不会上云。
   * - 旧格式行的下行物化同样坏掉：本地 Asset uri 变成规范前缀叠加
   *   file://<bundle>/data/storage/el2/distributedfiles/theme_assets/<key> 的
   *   翻倍形式，size 为空，13/13 附件 jsonParse fail，二进制滞留 CloudKitSA
   *   缓存不落沙箱。
   * - 官方语义（data_asset.h / commonType）：uri=系统内绝对路径，path=应用
   *   沙箱内路径。引擎下行组 uri = 规范前缀 + 云端存的 path，故 path 必须是
   *   distributedFilesDir 下的相对路径；uri 用规范 file://<bundle>/... 形式
   *   让 CloudKitSA 跨进程定位文件（含 bundle 名可映射沙箱挂载点）。
   *
   * 注意：debug 安装（/mnt/debugtmp/100/debug_hap/...）下该上传必然 1017
   * "path is not exist"——实测 /proc/<pid>/mounts：cloudkit_service、dds 对
   * debug hap 只挂载 el2/{base,database,cloud} 与 el1/*，不挂
   * el2/distributedfiles；release 应用（/mnt/sandbox/100/<bundle>/...）则完整
   * 挂载（含 distributedfiles，见 com.tencent.wechat 等对照）。属安装形态
   * 限制而非代码缺陷；完整验证需 release 签名安装。
   */
  private static async uploadAsset(context: Context, db: AppDatabase, item: LocalThemeFile): Promise<boolean> {
    try {
      const mirrorPath = ThemeAssetSyncService.mirrorPath(context, item.assetKey);
      await ThemeAssetSyncService.ensureParentDir(mirrorPath);
      await fs.copyFile(item.filePath, mirrorPath);
      const stat = await fs.stat(mirrorPath);
      const asset: relationalStore.Asset = {
        name: ThemeAssetSyncService.fileNameOf(item.assetKey),
        uri: ThemeAssetSyncService.canonicalUri(context, mirrorPath),
        path: `${ThemeAssetSyncService.MIRROR_ROOT}/${item.assetKey}`,
        createTime: String(stat.ctime * 1000),
        modifyTime: String(stat.mtime * 1000),
        size: String(stat.size)
      };
      hilog.info(0x0000, ThemeAssetSyncService.TAG,
        'upload asset: %{public}s uri=%{public}s size=%{public}s',
        item.assetKey, asset.uri, asset.size);
      await db.upsertThemeAssetRow(item.assetKey, asset);
      // 清掉调试期 filesDir/theme_assets 镜像（era-4/5 方案遗留，不再使用）。
      ThemeAssetSyncService.deleteLocalFile(`${context.filesDir}/` +
        `${ThemeAssetSyncService.MIRROR_ROOT}/${item.assetKey}`);
      const stored = await db.getThemeAssetRow(item.assetKey);
      hilog.info(0x0000, ThemeAssetSyncService.TAG,
        'upload readback: %{public}s status=%{public}d uri=%{public}s',
        item.assetKey, stored !== null ? Number(stored.status) : -1,
        stored !== null ? stored.uri : 'null');
      return stored !== null && !AppDatabase.isAssetAbnormalStatus(stored.status);
    } catch (error) {
      hilog.warn(0x0000, ThemeAssetSyncService.TAG,
        'upload asset failed: %{public}s %{public}s', item.assetKey, `${error}`);
      return false;
    }
  }

  /**
   * 把云端下行的资产复制回 filesDir 原位（下行），成功返回 true。
   *
   * 候选源按优先级：行内 path/uri 的裸绝对形式；两者归一化（剥离规范
   * file:// 前缀——含历史翻倍嵌套形式——与裸绝对前缀）后按
   * distributedFilesDir 解析的形式；distributedFilesDir 镜像（新格式引擎
   * 下行落盘处）；调试期 filesDir 镜像（era-4/5 上传的行，其资产曾在该
   * 位置）。最后按文件名在 distributedFilesDir 下递归兜底搜索，覆盖引擎
   * 物化到意外子路径的存量行。
   * 每个候选的存在性与最终结果都打日志：下行链路一旦静默失败就无法定位
   * "行到了文件没到"的卡点。
   */
  private static async downloadAsset(context: Context, row: ThemeAssetRow): Promise<boolean> {
    const candidates: string[] = [];
    if (row.asset) {
      if (row.asset.path && row.asset.path.startsWith('/')) {
        candidates.push(row.asset.path);
      }
      if (row.asset.uri && row.asset.uri.startsWith('/') && row.asset.uri !== row.asset.path) {
        candidates.push(row.asset.uri);
      }
      // 归一化行内 path/uri（兼容规范 file:// 形式与历史翻倍形式）后按
      // distributedFilesDir 解析：覆盖旧格式行与引擎物化路径的种种变体。
      const relatives: string[] = [];
      if (row.asset.path) {
        relatives.push(ThemeAssetSyncService.normalizeToDistributedRelative(row.asset.path));
      }
      if (row.asset.uri) {
        const rel = ThemeAssetSyncService.normalizeToDistributedRelative(row.asset.uri);
        if (relatives.indexOf(rel) < 0) {
          relatives.push(rel);
        }
      }
      for (const rel of relatives) {
        if (rel && !rel.startsWith('/')) {
          const resolved = `${context.distributedFilesDir}/${rel}`;
          if (candidates.indexOf(resolved) < 0) {
            candidates.push(resolved);
          }
        }
      }
    }
    candidates.push(ThemeAssetSyncService.mirrorPath(context, row.assetKey));
    candidates.push(`${context.filesDir}/` +
      `${ThemeAssetSyncService.MIRROR_ROOT}/${row.assetKey}`);
    const destPath = `${context.filesDir}/${row.assetKey}`;
    for (const source of candidates) {
      const exists = ThemeAssetSyncService.fileExists(source);
      hilog.info(0x0000, ThemeAssetSyncService.TAG,
        'download asset: %{public}s candidate=%{public}s exists=%{public}s',
        row.assetKey, source, exists ? 'y' : 'n');
      if (!exists) {
        continue;
      }
      if (source === destPath) {
        // 候选即目标：资产已由引擎直接落在 filesDir 原位，恢复即告完成。
        hilog.info(0x0000, ThemeAssetSyncService.TAG,
          'download asset already in place: %{public}s', row.assetKey);
        return true;
      }
      try {
        await ThemeAssetSyncService.ensureParentDir(destPath);
        await fs.copyFile(source, destPath);
        hilog.info(0x0000, ThemeAssetSyncService.TAG,
          'download asset ok: %{public}s -> %{public}s', row.assetKey, destPath);
        return true;
      } catch (error) {
        hilog.warn(0x0000, ThemeAssetSyncService.TAG,
          'download asset failed: %{public}s %{public}s', row.assetKey, `${error}`);
      }
    }
    // 兜底：按文件名在 distributedFilesDir 下递归搜索——旧格式行引擎物化
    // 可能落在意外子路径（如翻倍前缀目录），候选列表无法穷举。
    const searched = await ThemeAssetSyncService.searchFileByName(
      context.distributedFilesDir, ThemeAssetSyncService.fileNameOf(row.assetKey));
    if (searched) {
      if (searched === destPath) {
        hilog.info(0x0000, ThemeAssetSyncService.TAG,
          'download asset already in place (search): %{public}s', row.assetKey);
        return true;
      }
      try {
        await ThemeAssetSyncService.ensureParentDir(destPath);
        await fs.copyFile(searched, destPath);
        hilog.info(0x0000, ThemeAssetSyncService.TAG,
          'download asset ok (search): %{public}s %{public}s -> %{public}s',
          row.assetKey, searched, destPath);
        return true;
      } catch (error) {
        hilog.warn(0x0000, ThemeAssetSyncService.TAG,
          'download asset failed (search): %{public}s %{public}s', row.assetKey, `${error}`);
      }
    }
    hilog.warn(0x0000, ThemeAssetSyncService.TAG,
      'download asset: no candidate file for %{public}s (asset=%{public}s)',
      row.assetKey, row.asset ? `status=${row.asset.status} size=${row.asset.size}` : 'null');
    return false;
  }

  private static async scanLocalFiles(context: Context): Promise<LocalThemeFile[]> {
    const result: LocalThemeFile[] = [];
    for (const dirName of ThemeAssetSyncService.SYNC_DIRS) {
      await ThemeAssetSyncService.walkDir(`${context.filesDir}/${dirName}`, dirName, result);
    }
    return result;
  }

  /** 递归扫描目录（目录缺失视为空），把文件记录为 LocalThemeFile。 */
  private static async walkDir(dirPath: string, prefix: string, out: LocalThemeFile[]): Promise<void> {
    let names: string[] = [];
    try {
      names = await fs.listFile(dirPath);
    } catch (error) {
      return;
    }
    for (const name of names) {
      const childPath = `${dirPath}/${name}`;
      const childKey = `${prefix}/${name}`;
      let stat: fs.Stat | null = null;
      try {
        stat = await fs.stat(childPath);
      } catch (error) {
        continue;
      }
      if (!stat) {
        continue;
      }
      if (stat.isDirectory()) {
        await ThemeAssetSyncService.walkDir(childPath, childKey, out);
        continue;
      }
      const item = new LocalThemeFile();
      item.assetKey = childKey;
      item.filePath = childPath;
      item.size = stat.size;
      out.push(item);
    }
  }

  private static async loadKnownKeys(db: AppDatabase): Promise<Set<string>> {
    const result = new Set<string>();
    const raw = await db.getDeviceMetaValue(ThemeAssetSyncService.KNOWN_KEYS_META);
    if (!raw) {
      return result;
    }
    try {
      const parsed = JSON.parse(raw) as Object[];
      if (Array.isArray(parsed)) {
        for (const item of parsed) {
          if (typeof item === 'string' && item) {
            result.add(item);
          }
        }
      }
    } catch (error) {
      // 脏数据：按空集合处理，本轮对账会重建。
    }
    return result;
  }

  /**
   * 资产镜像路径：distributedFilesDir/theme_assets/<assetKey>。
   * 官方约束"资产文件需要存放到分布式文件路径下"。
   */
  private static mirrorPath(context: Context, assetKey: string): string {
    return `${context.distributedFilesDir}/${ThemeAssetSyncService.MIRROR_ROOT}/${assetKey}`;
  }

  /**
   * 规范 uri：file://<bundle>/data/storage/el2/distributedfiles/theme_assets/<assetKey>。
   * bundle 名让 CloudKitSA 等系统服务跨进程定位应用沙箱挂载点（裸 /data/storage/...
   * 仅在应用自身命名空间可见，旧格式因此 1017 "path is not exist"）。
   */
  private static canonicalUri(context: Context, mirrorPath: string): string {
    return `file://${context.applicationInfo.name}${mirrorPath}`;
  }

  /**
   * 把行内 path/uri 归一化成 distributedFilesDir 下的相对路径。
   * 依次剥离：规范 file://<bundle>/data/storage/el2/distributedfiles/ 前缀
   * （循环剥离，兼容历史引擎物化出的翻倍嵌套形式）、裸绝对前缀
   * /data/storage/el2/distributedfiles/。已经是相对路径的值原样返回。
   */
  private static normalizeToDistributedRelative(value: string): string {
    let rest = value;
    while (true) {
      const match = /^file:\/\/[^/]+\/data\/storage\/el2\/distributedfiles\//.exec(rest);
      if (!match) {
        break;
      }
      rest = rest.substring(match[0].length);
    }
    const absPrefix = '/data/storage/el2/distributedfiles/';
    if (rest.startsWith(absPrefix)) {
      rest = rest.substring(absPrefix.length);
    }
    return rest;
  }

  /**
   * 在目录树下按文件名递归搜索（目录缺失/未命中返回 null）。仅作下行兜底：
   * 旧格式行的引擎物化可能把资产落在意外子路径，候选列表无法穷举。
   */
  private static async searchFileByName(dirPath: string, fileName: string): Promise<string | null> {
    let names: string[] = [];
    try {
      names = await fs.listFile(dirPath);
    } catch (error) {
      return null;
    }
    for (const name of names) {
      const childPath = `${dirPath}/${name}`;
      let stat: fs.Stat | null = null;
      try {
        stat = await fs.stat(childPath);
      } catch (error) {
        continue;
      }
      if (!stat) {
        continue;
      }
      if (stat.isDirectory()) {
        const hit = await ThemeAssetSyncService.searchFileByName(childPath, fileName);
        if (hit) {
          return hit;
        }
        continue;
      }
      if (name === fileName) {
        return childPath;
      }
    }
    return null;
  }

  private static fileNameOf(assetKey: string): string {
    const index = assetKey.lastIndexOf('/');
    return index >= 0 ? assetKey.substring(index + 1) : assetKey;
  }

  private static fileExists(path: string): boolean {
    try {
      return fs.accessSync(path);
    } catch (error) {
      return false;
    }
  }

  private static deleteLocalFile(path: string): void {
    try {
      fs.unlinkSync(path);
    } catch (error) {
      hilog.warn(0x0000, ThemeAssetSyncService.TAG,
        'delete local file failed: %{public}s %{public}s', path, `${error}`);
    }
  }

  private static async ensureParentDir(path: string): Promise<void> {
    const index = path.lastIndexOf('/');
    if (index <= 0) {
      return;
    }
    const parent = path.substring(0, index);
    try {
      await fs.mkdir(parent, true);
    } catch (error) {
      // 目录已存在等场景：文件写入自会校验。
    }
  }
}
