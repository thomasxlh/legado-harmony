import { Context } from '@kit.AbilityKit';
import preferences from '@ohos.data.preferences';
import hilog from '@ohos.hilog';
import { AppDatabase } from '../model/data/AppDatabase';
import { CloudSyncService, CloudSyncOutcome } from './CloudSyncService';
import { ReaderSettingsStore } from './ReaderSettingsStore';
import { AppThemeModeStore } from './AppThemeModeStore';
import { AppThemeSettingsStore } from './AppThemeSettingsStore';
import { BookshelfDisplaySettingsStore } from './BookshelfDisplaySettingsStore';
import { CoverGalleryStore } from './CoverGalleryStore';
import { GlassSettingsStore } from './GlassSettingsStore';
import { ReaderReplaceRuleStore } from './ReaderReplaceRuleStore';
import { SearchExploreSettingsStore } from './SearchExploreSettingsStore';
import { TtsSettingsStore } from './TtsSettingsStore';

/**
 * 阅读偏好/主题设置的端云同步桥。
 *
 * 偏好本体存在 Preferences（每个 store 一个文件），端云分布式表只能覆盖 RDB，
 * 因此这里把每个偏好 store 的整库内容（getAll 的 JSON 快照）镜像到
 * app_preferences 表（一行一个 store），随 CloudSyncService 上云；
 * 云端下行后再整体写回 Preferences 并失效各 store 的内存缓存。
 *
 * 上行：注册每个 Preferences 实例的 'change' 监听（flush 后触发），内容有变化
 * 才写表；下行：云同步会话定稿后对比行内容与本机内容，按 lastSynced 标记判定
 * 方向（本地新→上传，云端新→应用），避免双向回声。
 *
 * 刻意排除：webdav_settings（连接配置随设备，密码本就不上云）、webdav_secrets
 * （HUKS 设备绑定）、bookshelf_state（本机书架状态）及各类缓存 store。
 */
export class PreferenceCloudSyncService {
  /** 参与端云同步的偏好 store（即 Preferences 文件名，同时是 app_preferences 主键）。 */
  static readonly SYNC_STORES: string[] = [
    'app_theme_mode',
    'app_theme_settings',
    'bookshelf_display_settings',
    'cover_gallery_settings',
    'custom_theme_schemes',
    'glass_settings',
    'reader_replace_rules',
    'reader_settings',
    'search_explore_settings',
    'tts_settings',
    'book_source_groups'
  ];

  /** 单个 store 快照的长度上限：超出视为异常（如被脏数据撑大），不上传。 */
  private static readonly MAX_DUMP_CHARS: number = 256 * 1024;
  /** 偏好写入（change 回调）后的去抖：期间连续的设置调整合并成一次对账。 */
  private static readonly OBSERVER_DEBOUNCE_MS: number = 2000;
  /** 云同步会话定稿后稍等片刻再对账，让 RDB 侧的下载落稳。 */
  private static readonly SESSION_SETTLE_DELAY_MS: number = 500;
  /** 启动对账的延迟：错开冷启动高峰。 */
  private static readonly STARTUP_DELAY_MS: number = 2000;
  private static readonly TAG: string = 'PrefCloudSync';

  private static attached: boolean = false;
  private static context: Context | null = null;
  private static prefStores: Map<string, preferences.Preferences> = new Map();
  private static checkTimer: number = -1;
  private static running: boolean = false;
  private static rerunNeeded: boolean = false;
  /**
   * 是否允许为“云端没有对应行”的 store 做首次播种（把本地内容上传）。
   * 只有云同步会话确认 SYNCED 后才放开：SYNCED 意味着本轮云端已有行必然已
   * 下载完成，此时仍缺行代表云端确实没有该 store 的数据，播种不会覆盖
   * 另一台设备上传的设置。
   */
  private static seedAllowed: boolean = false;

  /** 挂载同步桥：注册偏好变更监听与云同步会话回调。幂等，进程内只需调用一次。 */
  static async attach(context: Context): Promise<void> {
    if (PreferenceCloudSyncService.attached) {
      return;
    }
    PreferenceCloudSyncService.attached = true;
    PreferenceCloudSyncService.context = context;
    for (const storeName of PreferenceCloudSyncService.SYNC_STORES) {
      try {
        const store = await PreferenceCloudSyncService.prefStore(context, storeName);
        store.on('change', (_key: string): void => {
          PreferenceCloudSyncService.scheduleCheck(PreferenceCloudSyncService.OBSERVER_DEBOUNCE_MS);
        });
      } catch (error) {
        hilog.warn(0x0000, PreferenceCloudSyncService.TAG,
          'attach store failed: %{public}s %{public}s', storeName, `${error}`);
      }
    }
    CloudSyncService.addSessionListener((outcome: CloudSyncOutcome): void => {
      if (outcome.status === CloudSyncService.STATUS_SYNCED) {
        PreferenceCloudSyncService.seedAllowed = true;
      }
      PreferenceCloudSyncService.scheduleCheck(PreferenceCloudSyncService.SESSION_SETTLE_DELAY_MS);
    });
    // 启动对账：处理上一进程下载到 RDB 但尚未应用的行，以及漏上传的本地改动。
    PreferenceCloudSyncService.scheduleCheck(PreferenceCloudSyncService.STARTUP_DELAY_MS);
  }

  private static scheduleCheck(delayMs: number): void {
    if (!PreferenceCloudSyncService.context) {
      return;
    }
    if (PreferenceCloudSyncService.checkTimer >= 0) {
      return;
    }
    PreferenceCloudSyncService.checkTimer = setTimeout((): void => {
      PreferenceCloudSyncService.checkTimer = -1;
      PreferenceCloudSyncService.runSyncCheck().catch((error: Error): void => {
        hilog.warn(0x0000, PreferenceCloudSyncService.TAG,
          'sync check failed: %{public}s', error.message);
      });
    }, delayMs);
  }

  /**
   * 单次对账：逐 store 比较云端行内容、本机 Preferences 内容与 lastSynced 标记，
   * 决定上传、应用或跳过。整个流程串行（running 标记），并发触发时合并为一次。
   */
  private static async runSyncCheck(): Promise<void> {
    if (PreferenceCloudSyncService.running) {
      PreferenceCloudSyncService.rerunNeeded = true;
      return;
    }
    PreferenceCloudSyncService.running = true;
    try {
      const context = PreferenceCloudSyncService.context;
      if (!context) {
        return;
      }
      const db = AppDatabase.getInstance();
      await db.initWithContext(context);
      const rows = await db.getAppPreferenceRows();
      for (const storeName of PreferenceCloudSyncService.SYNC_STORES) {
        const rowValue = rows.get(storeName);
        await PreferenceCloudSyncService.reconcileStore(context, db, storeName, rowValue);
      }
    } catch (error) {
      hilog.warn(0x0000, PreferenceCloudSyncService.TAG,
        'sync check error: %{public}s', `${error}`);
    } finally {
      PreferenceCloudSyncService.running = false;
      if (PreferenceCloudSyncService.rerunNeeded) {
        PreferenceCloudSyncService.rerunNeeded = false;
        PreferenceCloudSyncService.scheduleCheck(PreferenceCloudSyncService.SESSION_SETTLE_DELAY_MS);
      }
    }
  }

  /**
   * 单个 store 的对账分支：
   * 1. 行缺失 → 已确认过云链路（seedAllowed）才播种本地内容；
   * 2. 行内容 == 本机内容 → 只补写 lastSynced 标记；
   * 3. 本机内容 != lastSynced → 本机在最后一次同步点之后变过，本机新 → 上传；
   * 4. 其余 → 行内容在 lastSynced 之后变过（云端下行），应用回 Preferences。
   */
  private static async reconcileStore(context: Context, db: AppDatabase, storeName: string,
    rowValue: string | undefined): Promise<void> {
    const prefStore = await PreferenceCloudSyncService.prefStore(context, storeName);
    const all = await prefStore.getAll() as Record<string, preferences.ValueType>;
    const localDump = PreferenceCloudSyncService.canonicalDump(all);
    const lastSyncedKey = PreferenceCloudSyncService.lastSyncedKey(storeName);
    const lastSynced = await db.getDeviceMetaValue(lastSyncedKey);
    if (rowValue === undefined) {
      if (PreferenceCloudSyncService.seedAllowed && localDump !== '{}') {
        await PreferenceCloudSyncService.uploadStore(db, storeName, localDump);
      }
      return;
    }
    if (rowValue === localDump) {
      if (lastSynced !== localDump) {
        await db.setDeviceMetaValue(lastSyncedKey, localDump);
      }
      return;
    }
    if (localDump !== lastSynced) {
      await PreferenceCloudSyncService.uploadStore(db, storeName, localDump);
      return;
    }
    await PreferenceCloudSyncService.applyRemote(db, storeName, prefStore, rowValue);
  }

  private static async uploadStore(db: AppDatabase, storeName: string, dump: string): Promise<void> {
    if (dump.length > PreferenceCloudSyncService.MAX_DUMP_CHARS) {
      hilog.warn(0x0000, PreferenceCloudSyncService.TAG,
        'skip oversized preference dump: %{public}s %{public}d', storeName, dump.length);
      return;
    }
    await db.upsertAppPreferenceRow(storeName, dump);
    await db.setDeviceMetaValue(PreferenceCloudSyncService.lastSyncedKey(storeName), dump);
  }

  /** 把云端下行的 store 快照整体写回 Preferences，并失效相关内存缓存。 */
  private static async applyRemote(db: AppDatabase, storeName: string,
    prefStore: preferences.Preferences, remoteDump: string): Promise<void> {
    let values: Record<string, preferences.ValueType> = {};
    try {
      const parsed = JSON.parse(remoteDump) as Record<string, preferences.ValueType>;
      if (parsed && typeof parsed === 'object') {
        values = parsed;
      }
    } catch (error) {
      hilog.warn(0x0000, PreferenceCloudSyncService.TAG,
        'invalid remote preference row: %{public}s', storeName);
      return;
    }
    try {
      await prefStore.clear();
      for (const key of Object.keys(values)) {
        await prefStore.put(key, values[key]);
      }
      await prefStore.flush();
    } catch (error) {
      // 不更新 lastSynced：下次对账会重试本次应用。
      hilog.warn(0x0000, PreferenceCloudSyncService.TAG,
        'apply remote preferences failed: %{public}s %{public}s', storeName, `${error}`);
      return;
    }
    await db.setDeviceMetaValue(PreferenceCloudSyncService.lastSyncedKey(storeName), remoteDump);
    PreferenceCloudSyncService.invalidateCaches(storeName);
    hilog.info(0x0000, PreferenceCloudSyncService.TAG,
      'applied remote preferences: %{public}s', storeName);
  }

  /** 让“同数据不同序列化”的两端得到相同字符串，内容比较才可靠。 */
  private static canonicalize(value: Object): Object {
    if (!value) {
      return value;
    }
    // 数组按元素顺序序列化、Uint8Array 按下标序列化，天然确定，无需重排。
    if (Array.isArray(value) || value instanceof Uint8Array) {
      return value;
    }
    if (typeof value === 'object') {
      const source = value as Record<string, Object>;
      const result: Record<string, Object> = {};
      const keys = Object.keys(source).sort();
      for (const key of keys) {
        result[key] = PreferenceCloudSyncService.canonicalize(source[key]);
      }
      return result;
    }
    return value;
  }

  private static canonicalDump(values: Record<string, preferences.ValueType>): string {
    return JSON.stringify(PreferenceCloudSyncService.canonicalize(values));
  }

  private static lastSyncedKey(storeName: string): string {
    return `pref_cloud_last_synced_${storeName}`;
  }

  private static async prefStore(context: Context, storeName: string): Promise<preferences.Preferences> {
    const existing = PreferenceCloudSyncService.prefStores.get(storeName);
    if (existing) {
      return existing;
    }
    const store = await preferences.getPreferences(context, storeName);
    PreferenceCloudSyncService.prefStores.set(storeName, store);
    return store;
  }

  /** 云端偏好应用后失效各 store 的内存缓存，下次 load() 重新读 Preferences。 */
  private static invalidateCaches(storeName: string): void {
    switch (storeName) {
      case 'reader_settings':
        ReaderSettingsStore.invalidateCache();
        break;
      case 'app_theme_mode':
        AppThemeModeStore.invalidateCache();
        break;
      case 'app_theme_settings':
        AppThemeSettingsStore.invalidateCache();
        break;
      case 'bookshelf_display_settings':
        BookshelfDisplaySettingsStore.invalidateCache();
        break;
      case 'cover_gallery_settings':
        CoverGalleryStore.invalidateCache();
        break;
      case 'glass_settings':
        GlassSettingsStore.invalidateCache();
        break;
      case 'reader_replace_rules':
        ReaderReplaceRuleStore.invalidateCache();
        break;
      case 'search_explore_settings':
        SearchExploreSettingsStore.invalidateCache();
        break;
      case 'tts_settings':
        TtsSettingsStore.invalidateCache();
        break;
      default:
        break;
    }
  }
}
