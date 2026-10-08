import { relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import hilog from '@ohos.hilog';

export class CloudSyncService {
  static readonly SYNC_TABLES: string[] = ['books', 'book_sources', 'book_groups', 'search_keywords'];

  static readonly STORAGE_SUPPORTED: string = 'cloudSyncSupported';
  static readonly STORAGE_STATUS: string = 'cloudSyncStatus';
  static readonly STORAGE_LAST_SUCCESS_AT: string = 'cloudSyncLastSuccessAt';
  static readonly STORAGE_MESSAGE: string = 'cloudSyncMessage';
  static readonly STORAGE_REVISION: string = 'cloudSyncRevision';

  static readonly STATUS_IDLE: string = 'idle';
  static readonly STATUS_SYNCING: string = 'syncing';
  static readonly STATUS_SYNCED: string = 'synced';
  static readonly STATUS_ERROR: string = 'error';
  static readonly STATUS_UNSUPPORTED: string = 'unsupported';

  private static store: relationalStore.RdbStore | null = null;
  private static supported: boolean = false;
  private static syncInFlight: boolean = false;

  static initializeStorage(): void {
    AppStorage.setOrCreate(CloudSyncService.STORAGE_SUPPORTED, false);
    AppStorage.setOrCreate(CloudSyncService.STORAGE_STATUS, CloudSyncService.STATUS_IDLE);
    AppStorage.setOrCreate(CloudSyncService.STORAGE_LAST_SUCCESS_AT, 0);
    AppStorage.setOrCreate(CloudSyncService.STORAGE_MESSAGE, '');
    AppStorage.setOrCreate(CloudSyncService.STORAGE_REVISION, 0);
  }

  static async configure(store: relationalStore.RdbStore): Promise<void> {
    CloudSyncService.initializeStorage();
    CloudSyncService.store = store;
    try {
      const config: relationalStore.DistributedConfig = { autoSync: true };
      await store.setDistributedTables(CloudSyncService.SYNC_TABLES,
        relationalStore.DistributedType.DISTRIBUTED_CLOUD, config);
      CloudSyncService.supported = true;
      CloudSyncService.setStatus(CloudSyncService.STATUS_IDLE, '');
    } catch (error) {
      CloudSyncService.supported = false;
      const err = error as BusinessError;
      CloudSyncService.setStatus(CloudSyncService.STATUS_UNSUPPORTED,
        `端云同步不可用（${err.code}）`);
      hilog.warn(0x0000, 'CloudSync', 'setDistributedTables failed: %{public}d %{public}s',
        err.code, err.message);
    }
    AppStorage.setOrCreate(CloudSyncService.STORAGE_SUPPORTED, CloudSyncService.supported);
  }

  static isSupported(): boolean {
    return CloudSyncService.supported;
  }

  static isSyncing(): boolean {
    return CloudSyncService.syncInFlight;
  }

  static message(): string {
    return AppStorage.get<string>(CloudSyncService.STORAGE_MESSAGE) || '';
  }

  static lastSuccessAt(): number {
    return AppStorage.get<number>(CloudSyncService.STORAGE_LAST_SUCCESS_AT) || 0;
  }

  static syncNow(): Promise<void> {
    const store = CloudSyncService.store;
    if (!store || !CloudSyncService.supported) {
      return Promise.reject(new Error('当前设备不支持端云同步'));
    }
    if (CloudSyncService.syncInFlight) {
      return Promise.resolve();
    }
    CloudSyncService.syncInFlight = true;
    CloudSyncService.setStatus(CloudSyncService.STATUS_SYNCING, '');
    return new Promise<void>((resolve, reject) => {
      try {
        store.cloudSync(relationalStore.SyncMode.SYNC_MODE_TIME_FIRST,
          CloudSyncService.SYNC_TABLES,
          (progress: relationalStore.ProgressDetails) => {
          },
          (error: BusinessError) => {
            CloudSyncService.syncInFlight = false;
            if (error) {
              CloudSyncService.setStatus(CloudSyncService.STATUS_ERROR,
                `${error.code}: ${error.message}`);
              reject(new Error(CloudSyncService.describeError(error.code)));
            } else {
              CloudSyncService.setStatus(CloudSyncService.STATUS_SYNCED, '');
              resolve();
            }
          });
      } catch (error) {
        CloudSyncService.syncInFlight = false;
        const err = error as BusinessError;
        CloudSyncService.setStatus(CloudSyncService.STATUS_ERROR, `${err.code}: ${err.message}`);
        reject(new Error(CloudSyncService.describeError(err.code)));
      }
    });
  }

  static statusSummary(): string {
    const status = AppStorage.get<string>(CloudSyncService.STORAGE_STATUS) || CloudSyncService.STATUS_IDLE;
    return CloudSyncService.summary(status, CloudSyncService.lastSuccessAt());
  }

  // Reactive pages must build the summary from their @StorageLink fields (which ArkUI observes)
  // instead of calling statusSummary(), otherwise the bound Text never re-renders.
  static summary(status: string, lastSuccessAt: number): string {
    if (status === CloudSyncService.STATUS_UNSUPPORTED) {
      return '当前设备不支持';
    }
    if (status === CloudSyncService.STATUS_SYNCING) {
      return '正在与云空间同步';
    }
    if (status === CloudSyncService.STATUS_ERROR) {
      return '同步失败';
    }
    if (lastSuccessAt > 0) {
      return `已同步 · ${CloudSyncService.relativeTime(lastSuccessAt)}`;
    }
    return '等待同步';
  }

  static relativeTime(timestamp: number): string {
    const elapsed = Math.max(0, Date.now() - timestamp);
    if (elapsed < 60 * 1000) {
      return '刚刚';
    }
    const minutes = Math.floor(elapsed / (60 * 1000));
    if (minutes < 60) {
      return `${minutes} 分钟前`;
    }
    const hours = Math.floor(minutes / 60);
    if (hours < 24) {
      return `${hours} 小时前`;
    }
    const days = Math.floor(hours / 24);
    if (days < 7) {
      return `${days} 天前`;
    }
    return new Date(timestamp).toLocaleDateString();
  }

  private static describeError(code: number): string {
    if (code === 3) {
      return '未在“设置-云空间”中开启本应用的同步开关';
    }
    if (code === 2) {
      return '网络错误，同步已暂停';
    }
    if (code === 5) {
      return '超出云空间数据上限';
    }
    if (code === 6) {
      return '云空间存储空间不足';
    }
    if (code === 7) {
      return '当前网络不满足同步策略';
    }
    return `同步失败（${code}）`;
  }

  private static setStatus(status: string, message: string): void {
    if (status === CloudSyncService.STATUS_SYNCED) {
      AppStorage.setOrCreate(CloudSyncService.STORAGE_LAST_SUCCESS_AT, Date.now());
    }
    AppStorage.setOrCreate(CloudSyncService.STORAGE_STATUS, status);
    AppStorage.setOrCreate(CloudSyncService.STORAGE_MESSAGE, message);
    const revision = (AppStorage.get<number>(CloudSyncService.STORAGE_REVISION) || 0) + 1;
    AppStorage.setOrCreate(CloudSyncService.STORAGE_REVISION, revision);
  }
}
