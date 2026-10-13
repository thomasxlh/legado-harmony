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
 * cover_albums），端云分布式表只能同步 RDB 行与 ASSET 列，且要求资产文件位于
 * 分布式文件路径下，因此这里把每张图片镜像到 distributedFilesDir 后以
 * theme_assets 表（assetKey = filesDir 相对路径，跨设备稳定）上云。
 *
 * 上行：本地扫描发现的文件镜像后入库；下行：云同步会话把资产下载回镜像路径
 * （同 bundle 沙箱路径跨设备一致），再复制回 filesDir 原位，偏好里记录的
 * 绝对路径即直接生效。删除用墓碑传播：行保留并置 deletedAt，资产状态置
 * ASSET_DELETE 让云端释放文件；行不删除，防止其他设备据本地文件复活该行。
 *
 * known 集合（device_meta）记录本机已确认过的 assetKey，用于区分
 * “本机删除了该文件（应墓碑上传播）”与“另一台设备新上传（应下行到本地）”。
 * reader_fonts 刻意不参与（字体文件大、走 WebDAV）。
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

  /** 挂载同步桥：注册云同步会话回调并安排启动对账。幂等，进程内只需调用一次。 */
  static attach(context: Context): void {
    if (ThemeAssetSyncService.attached) {
      return;
    }
    ThemeAssetSyncService.attached = true;
    ThemeAssetSyncService.context = context;
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
      ThemeAssetSyncService.rerunNeeded = true;
      return;
    }
    ThemeAssetSyncService.running = true;
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

  private static async doReconcile(context: Context): Promise<void> {
    const db = AppDatabase.getInstance();
    await db.initWithContext(context);
    const rows = await db.getThemeAssetRows();
    const known = await ThemeAssetSyncService.loadKnownKeys(db);
    const localFiles = await ThemeAssetSyncService.scanLocalFiles(context);
    const localKeys = new Set<string>();
    for (const item of localFiles) {
      localKeys.add(item.assetKey);
    }
    let knownDirty = false;

    // 分支一：本地文件驱动——新增/变更上行，云端墓碑下行删除。
    for (const item of localFiles) {
      const row = rows.get(item.assetKey);
      if (row && row.deletedAt > 0) {
        // 另一台设备已删除该资源：删除本地文件，行保留（墓碑仍需继续传播）。
        ThemeAssetSyncService.deleteLocalFile(item.filePath);
        if (known.has(item.assetKey)) {
          known.delete(item.assetKey);
          knownDirty = true;
        }
        continue;
      }
      const remoteSize = row && row.asset ? Number(row.asset.size) : -1;
      if (!row || remoteSize !== item.size) {
        await ThemeAssetSyncService.uploadAsset(context, db, item);
      }
      if (!known.has(item.assetKey)) {
        known.add(item.assetKey);
        knownDirty = true;
      }
    }

    // 分支二：行驱动——本机删除墓碑传播，云端新资源下行。
    for (const row of rows.values()) {
      if (localKeys.has(row.assetKey) || row.deletedAt > 0) {
        continue;
      }
      if (known.has(row.assetKey)) {
        // 本机此前确认过该文件而现在没有：本机删除 → 墓碑传播，云端释放文件。
        await db.tombstoneThemeAssetRow(row.assetKey, row.asset);
        known.delete(row.assetKey);
        knownDirty = true;
        continue;
      }
      // 未见过的行：另一台设备上传 → 把资产从镜像路径复制回 filesDir 原位。
      const downloaded = await ThemeAssetSyncService.downloadAsset(context, row);
      if (downloaded) {
        known.add(row.assetKey);
        knownDirty = true;
      }
    }

    if (knownDirty) {
      await db.setDeviceMetaValue(ThemeAssetSyncService.KNOWN_KEYS_META,
        JSON.stringify(Array.from(known)));
    }
  }

  /** 镜像到 distributedFilesDir 并写入 theme_assets 行（上行）。 */
  private static async uploadAsset(context: Context, db: AppDatabase, item: LocalThemeFile): Promise<void> {
    try {
      const mirrorPath = ThemeAssetSyncService.mirrorPath(context, item.assetKey);
      await ThemeAssetSyncService.ensureParentDir(mirrorPath);
      await fs.copy(item.filePath, mirrorPath);
      const stat = await fs.stat(mirrorPath);
      const asset: relationalStore.Asset = {
        name: ThemeAssetSyncService.fileNameOf(item.assetKey),
        uri: mirrorPath,
        path: mirrorPath,
        createTime: String(stat.ctime * 1000),
        modifyTime: String(stat.mtime * 1000),
        size: String(stat.size)
      };
      await db.upsertThemeAssetRow(item.assetKey, asset);
    } catch (error) {
      hilog.warn(0x0000, ThemeAssetSyncService.TAG,
        'upload asset failed: %{public}s %{public}s', item.assetKey, `${error}`);
    }
  }

  /** 把云端下行的资产复制回 filesDir 原位（下行），成功返回 true。 */
  private static async downloadAsset(context: Context, row: ThemeAssetRow): Promise<boolean> {
    const candidates: string[] = [];
    if (row.asset) {
      if (row.asset.path) {
        candidates.push(row.asset.path);
      }
      if (row.asset.uri && row.asset.uri.startsWith('/') && row.asset.uri !== row.asset.path) {
        candidates.push(row.asset.uri);
      }
    }
    candidates.push(ThemeAssetSyncService.mirrorPath(context, row.assetKey));
    for (const source of candidates) {
      if (!ThemeAssetSyncService.fileExists(source)) {
        continue;
      }
      const destPath = `${context.filesDir}/${row.assetKey}`;
      if (source === destPath) {
        return false;
      }
      try {
        await ThemeAssetSyncService.ensureParentDir(destPath);
        await fs.copy(source, destPath);
        return true;
      } catch (error) {
        hilog.warn(0x0000, ThemeAssetSyncService.TAG,
          'download asset failed: %{public}s %{public}s', row.assetKey, `${error}`);
      }
    }
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

  private static mirrorPath(context: Context, assetKey: string): string {
    return `${context.distributedFilesDir}/${ThemeAssetSyncService.MIRROR_ROOT}/${assetKey}`;
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
