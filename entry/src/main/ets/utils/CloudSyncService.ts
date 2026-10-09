import { relationalStore, cloudData } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import hilog from '@ohos.hilog';

export class CloudSyncService {
  static readonly SYNC_TABLES: string[] =
    ['books', 'book_sources', 'book_groups', 'search_keywords', 'sync_heartbeats'];

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
  private static pendingSync: Promise<void> | null = null;
  private static deviceId: string = '';
  private static lastAutoSyncRequestAt: number = 0;
  static readonly AUTO_SYNC_MIN_INTERVAL_MS: number = 5 * 60 * 1000;

  static initializeStorage(): void {
    AppStorage.setOrCreate(CloudSyncService.STORAGE_SUPPORTED, false);
    AppStorage.setOrCreate(CloudSyncService.STORAGE_STATUS, CloudSyncService.STATUS_IDLE);
    AppStorage.setOrCreate(CloudSyncService.STORAGE_LAST_SUCCESS_AT, 0);
    AppStorage.setOrCreate(CloudSyncService.STORAGE_MESSAGE, '');
    AppStorage.setOrCreate(CloudSyncService.STORAGE_REVISION, 0);
  }

  static async configure(store: relationalStore.RdbStore, deviceId: string): Promise<void> {
    CloudSyncService.initializeStorage();
    CloudSyncService.store = store;
    CloudSyncService.deviceId = deviceId;
    try {
      // autoSync 关闭：阅读/听书时进度每几秒落一次库，若交给系统"及时"上云，
      // 云空间会随上传次数持续累积占用。改为由应用在合适时机（前后台切换、
      // 云端变更通知）去抖触发，进度更新合并后择机上传。
      const config: relationalStore.DistributedConfig = { autoSync: false };
      await store.setDistributedTables(CloudSyncService.SYNC_TABLES,
        relationalStore.DistributedType.DISTRIBUTED_CLOUD, config);
      CloudSyncService.supported = true;
      CloudSyncService.setStatus(CloudSyncService.STATUS_IDLE, '');
      CloudSyncService.registerAutoSyncTrigger();
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

  /** 注册系统自动同步触发通知（云端变更/网络恢复/开关打开等），API 26+ 可用。 */
  private static registerAutoSyncTrigger(): void {
    if (typeof cloudData.onAutoSyncTrigger !== 'function') {
      return;
    }
    try {
      cloudData.onAutoSyncTrigger((info: cloudData.AutoSyncTriggerInfo): void => {
        CloudSyncService.requestAutoSync();
      });
    } catch (error) {
      const err = error as BusinessError;
      hilog.warn(0x0000, 'CloudSync', 'onAutoSyncTrigger failed: %{public}d %{public}s',
        err.code, err.message);
    }
  }

  /** 去抖的自动同步入口：App 前后台切换与云端变更通知调用，间隔不少于 5 分钟。 */
  static requestAutoSync(): void {
    if (!CloudSyncService.supported || CloudSyncService.syncInFlight) {
      return;
    }
    const now = Date.now();
    if (now - CloudSyncService.lastAutoSyncRequestAt < CloudSyncService.AUTO_SYNC_MIN_INTERVAL_MS) {
      return;
    }
    CloudSyncService.lastAutoSyncRequestAt = now;
    // 自动同步不写心跳脏行：写心跳会触发云端数据变更通知，
    // onAutoSyncTrigger 再次唤起自动同步，形成"每 5 分钟上传一版心跳"的自我维持循环，
    // 云端版本无限累积导致云空间占用持续增长。
    CloudSyncService.syncNow(false).catch((error: Error) => {
      hilog.info(0x0000, 'CloudSync', 'auto sync skipped: %{public}s', error.message);
    });
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

  /**
   * @param verifyWithHeartbeat 仅手动同步传 true：用“心跳行往返探针”确认数据确实到达云端。
   * 端云框架在云空间开关关闭时不会向应用上报任何错误（完成回调 err=0、进度回调不触发），
   * 因此用探针行做确定性验证：
   * 1. 写入心跳时间戳 T1，随主同步（TIME_FIRST）推送到云端；
   * 2. 本地再写 T2=T1+1 制造端云差异（不推送）；
   * 3. 用 SYNC_MODE_CLOUD_FIRST 仅对探针表做“云→端”拉取；
   * 4. 若本地值被拉回的云端版本覆盖为 T1，证明 T1 已到达云端；若仍是 T2，说明云端不可达
   *    （开关关闭/网络异常），明确报错而不是提示已同步。
   */
  static async syncNow(verifyWithHeartbeat: boolean = false): Promise<void> {
    const store = CloudSyncService.store;
    if (!store || !CloudSyncService.supported) {
      return Promise.reject(new Error('当前设备不支持端云同步'));
    }
    if (CloudSyncService.syncInFlight && CloudSyncService.pendingSync) {
      // 复用在飞任务，等待真实完成，避免并发调用拿到假的成功结果。
      return CloudSyncService.pendingSync;
    }
    let probeStamp = 0;
    if (verifyWithHeartbeat) {
      probeStamp = await CloudSyncService.writeSyncHeartbeat();
      if (CloudSyncService.syncInFlight && CloudSyncService.pendingSync) {
        return CloudSyncService.pendingSync;
      }
    }
    CloudSyncService.syncInFlight = true;
    CloudSyncService.setStatus(CloudSyncService.STATUS_SYNCING, '');
    let latestProgress: relationalStore.ProgressDetails | null = null;
    const mainTask = new Promise<void>((resolve, reject) => {
      try {
        store.cloudSync(relationalStore.SyncMode.SYNC_MODE_TIME_FIRST,
          CloudSyncService.SYNC_TABLES,
          (progress: relationalStore.ProgressDetails) => {
            latestProgress = progress;
            hilog.debug(0x0000, 'CloudSync', 'progress: code=%{public}d details=%{public}s',
              progress.code, JSON.stringify(progress.details));
            const live = CloudSyncService.progressText(progress);
            if (live) {
              CloudSyncService.setStatus(CloudSyncService.STATUS_SYNCING, live);
            }
          },
          (error: BusinessError) => {
            const progressCode = latestProgress ? latestProgress.code : -1;
            hilog.info(0x0000, 'CloudSync',
              'main sync finished: err=%{public}d progressCode=%{public}d probe=%{public}d',
              error ? error.code : 0, progressCode, probeStamp);
            if (error) {
              CloudSyncService.setStatus(CloudSyncService.STATUS_ERROR,
                `${error.code}: ${error.message}`);
              reject(new Error(CloudSyncService.describeError(error.code)));
              return;
            }
            const failure = CloudSyncService.progressFailure(latestProgress);
            if (failure) {
              CloudSyncService.setStatus(CloudSyncService.STATUS_ERROR, failure);
              reject(new Error(failure));
              return;
            }
            resolve();
          });
      } catch (error) {
        const err = error as BusinessError;
        CloudSyncService.setStatus(CloudSyncService.STATUS_ERROR, `${err.code}: ${err.message}`);
        reject(new Error(CloudSyncService.describeError(err.code)));
      }
    });
    const fullTask = mainTask.then(async (): Promise<void> => {
      if (probeStamp <= 0) {
        CloudSyncService.setStatus(CloudSyncService.STATUS_SYNCED, '');
        return;
      }
      const confirmed = await CloudSyncService.probeCloudRoundTrip(probeStamp);
      if (!confirmed) {
        // 清空云端后全量重传时，系统批量上传在后台持续进行，心跳行会长时间滞后，
        // 探针可能暂时无法确认。若主同步已上报 SUCCESS 进度（开关关闭时进度回调
        // 完全不触发），说明云空间链路可用，按成功处理而不是误报失败。
        const progress = latestProgress;
        const progressOk = progress !== null &&
          progress.code === relationalStore.ProgressCode.SUCCESS;
        if (progressOk) {
          hilog.info(0x0000, 'CloudSync',
            'probe unconfirmed but main sync progress ok, treat as synced');
          CloudSyncService.setStatus(CloudSyncService.STATUS_SYNCED, '');
          return;
        }
        const message = '未能连接云空间：请检查“设置-云空间”中本应用的同步开关与网络连接';
        CloudSyncService.setStatus(CloudSyncService.STATUS_ERROR, message);
        throw new Error(message);
      }
      CloudSyncService.setStatus(CloudSyncService.STATUS_SYNCED, '');
    });
    const settledTask = fullTask.then(
      (): Promise<void> => {
        CloudSyncService.syncInFlight = false;
        CloudSyncService.pendingSync = null;
        return Promise.resolve();
      },
      (error: Error): Promise<void> => {
        CloudSyncService.syncInFlight = false;
        CloudSyncService.pendingSync = null;
        return Promise.reject(error);
      });
    CloudSyncService.pendingSync = settledTask;
    return settledTask;
  }

  /** 写入本设备心跳时间戳，返回写入的时间戳；失败返回 0。 */
  private static async writeSyncHeartbeat(): Promise<number> {
    const store = CloudSyncService.store;
    const deviceId = CloudSyncService.deviceId;
    if (!store || !deviceId) {
      return 0;
    }
    const stamp = Date.now();
    try {
      const predicates = new relationalStore.RdbPredicates('sync_heartbeats');
      predicates.equalTo('deviceId', deviceId);
      const bucket: relationalStore.ValuesBucket = { updatedAt: stamp };
      const affected = await store.update(bucket, predicates);
      if (affected <= 0) {
        const insertBucket: relationalStore.ValuesBucket = {
          deviceId: deviceId,
          updatedAt: stamp
        };
        await store.insert('sync_heartbeats', insertBucket);
      }
      return stamp;
    } catch (error) {
      const err = error as BusinessError;
      hilog.warn(0x0000, 'CloudSync', 'write heartbeat failed: %{public}d %{public}s',
        err.code, err.message);
      return 0;
    }
  }

  /** 心跳往返探针：见 syncNow 注释。返回 true 表示推送的行已确认到达云端。 */
  private static async probeCloudRoundTrip(pushedAt: number): Promise<boolean> {
    const store = CloudSyncService.store;
    const deviceId = CloudSyncService.deviceId;
    if (!store || !deviceId) {
      return false;
    }
    // 本地写一个比云端更新的时间戳，制造端云差异（不随主同步推送）。
    const localStamp = pushedAt + 1;
    try {
      const predicates = new relationalStore.RdbPredicates('sync_heartbeats');
      predicates.equalTo('deviceId', deviceId);
      const bumpBucket: relationalStore.ValuesBucket = { updatedAt: localStamp };
      const affected = await store.update(bumpBucket, predicates);
      if (affected <= 0) {
        const insertBucket: relationalStore.ValuesBucket = {
          deviceId: deviceId,
          updatedAt: localStamp
        };
        await store.insert('sync_heartbeats', insertBucket);
      }
    } catch (error) {
      const err = error as BusinessError;
      hilog.warn(0x0000, 'CloudSync', 'probe bump failed: %{public}d %{public}s',
        err.code, err.message);
      return false;
    }
    // 云端刚经历全量重传（如清空云端数据后重新开启），心跳行会滞后于系统批量
    // 上传队列；拉取探针最多重试 3 次（间隔 3 秒）。期间本地若被云端覆盖回
    // pushedAt 即确认成功；开关关闭时拉取不生效，本地始终为 localStamp。
    for (let attempt = 1; attempt <= 3; attempt++) {
      if (attempt > 1) {
        await CloudSyncService.delay(3000);
      }
      try {
        // 仅对探针表执行“云→端”拉取，不会把本地差异推送到云端。
        await CloudSyncService.pullSyncHeartbeatTable(store);
      } catch (error) {
        const err = error as BusinessError;
        hilog.warn(0x0000, 'CloudSync', 'probe pull failed (attempt %{public}d): %{public}d %{public}s',
          attempt, err.code, err.message);
        continue;
      }
      const current = await CloudSyncService.readHeartbeatStamp(store, deviceId);
      const confirmed = current === pushedAt;
      hilog.info(0x0000, 'CloudSync',
        'probe: attempt=%{public}d pushedAt=%{public}d local=%{public}d current=%{public}d confirmed=%{public}d',
        attempt, pushedAt, localStamp, current, confirmed ? 1 : 0);
      if (confirmed) {
        return true;
      }
    }
    hilog.warn(0x0000, 'CloudSync', 'probe not confirmed after retries: pushedAt=%{public}d', pushedAt);
    return false;
  }

  private static readHeartbeatStamp(store: relationalStore.RdbStore,
    deviceId: string): Promise<number> {
    return new Promise<number>((resolve) => {
      const predicates = new relationalStore.RdbPredicates('sync_heartbeats');
      predicates.equalTo('deviceId', deviceId);
      store.query(predicates, []).then((resultSet) => {
        let current = -1;
        try {
          if (resultSet.goToFirstRow()) {
            current = resultSet.getLong(resultSet.getColumnIndex('updatedAt'));
          }
        } catch (error) {
          const err = error as BusinessError;
          hilog.warn(0x0000, 'CloudSync', 'read heartbeat failed: %{public}d %{public}s',
            err.code, err.message);
        } finally {
          resultSet.close();
        }
        resolve(current);
      }).catch((error: BusinessError) => {
        hilog.warn(0x0000, 'CloudSync', 'query heartbeat failed: %{public}d %{public}s',
          error.code, error.message);
        resolve(-1);
      });
    });
  }

  private static delay(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
  }

  /** 统计各同步表的数据量（字节），用于诊断云端占用来源。 */
  static async estimateSyncTableSizes(): Promise<Record<string, number>> {
    const sizes: Record<string, number> = {};
    const store = CloudSyncService.store;
    if (!store) {
      return sizes;
    }
    let total = 0;
    for (const table of CloudSyncService.SYNC_TABLES) {
      let bytes = 0;
      try {
        const resultSet = await store.querySql(`SELECT * FROM ${table}`);
        try {
          const colCount = resultSet.columnCount;
          while (resultSet.goToNextRow()) {
            for (let i = 0; i < colCount; i++) {
              try {
                const value = resultSet.getString(i);
                bytes += value ? value.length : 0;
              } catch (_) {
                // 非文本列（整数等）按固定 8 字节估算
                bytes += 8;
              }
            }
          }
        } finally {
          resultSet.close();
        }
      } catch (error) {
        const err = error as BusinessError;
        hilog.warn(0x0000, 'CloudSync', 'estimate size failed: %{public}s %{public}d %{public}s',
          table, err.code, err.message);
      }
      sizes[table] = bytes;
      total += bytes;
      hilog.info(0x0000, 'CloudSync', 'sync table size: %{public}s = %{public}d bytes',
        table, bytes);
    }
    hilog.info(0x0000, 'CloudSync', 'sync total size: %{public}d bytes', total);
    return sizes;
  }

  static formatBytes(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`;
    }
    if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`;
    }
    return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
  }

  private static pullSyncHeartbeatTable(store: relationalStore.RdbStore): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      try {
        store.cloudSync(relationalStore.SyncMode.SYNC_MODE_CLOUD_FIRST,
          ['sync_heartbeats'],
          (progress: relationalStore.ProgressDetails) => {
            hilog.debug(0x0000, 'CloudSync', 'probe progress: code=%{public}d', progress.code);
          },
          (error: BusinessError) => {
            if (error) {
              reject(new Error(`${error.code}: ${error.message}`));
            } else {
              resolve();
            }
          });
      } catch (error) {
        const err = error as BusinessError;
        reject(new Error(`${err.code}: ${err.message}`));
      }
    });
  }

  // 端云同步的成败以 ProgressDetails.code 为准：云空间开关关闭等情况只会通过
  // 进度回调上报 CLOUD_DISABLED，完成回调本身不携带错误。
  private static progressFailure(progress: relationalStore.ProgressDetails | null): string {
    if (!progress) {
      return '';
    }
    if (progress.code === relationalStore.ProgressCode.CLOUD_DISABLED) {
      return '未在“设置-云空间”中开启本应用的同步开关';
    }
    if (progress.code === relationalStore.ProgressCode.LOCKED_BY_OTHERS) {
      return '其他设备正在占用云端同步，请稍后再试';
    }
    if (progress.code !== relationalStore.ProgressCode.SUCCESS) {
      const described = CloudSyncService.describeError(progress.code);
      const extra = progress.message ? `：${progress.message}` : '';
      return `${described}${extra}`;
    }
    const failed = CloudSyncService.countFailedRows(progress);
    if (failed > 0) {
      return `有 ${failed} 条数据未能同步`;
    }
    return '';
  }

  private static progressText(progress: relationalStore.ProgressDetails): string {
    const details = progress.details;
    if (!details) {
      return '';
    }
    let uploadTotal = 0;
    let uploadRemained = 0;
    let downloadTotal = 0;
    let downloadRemained = 0;
    const tables = Object.keys(details);
    for (const table of tables) {
      const tableDetails = details[table];
      if (!tableDetails) {
        continue;
      }
      uploadTotal += tableDetails.upload.total;
      uploadRemained += tableDetails.upload.remained;
      downloadTotal += tableDetails.download.total;
      downloadRemained += tableDetails.download.remained;
    }
    if (uploadTotal === 0 && downloadTotal === 0) {
      return '';
    }
    const uploadDone = uploadTotal - uploadRemained;
    const downloadDone = downloadTotal - downloadRemained;
    if (uploadTotal > 0 && downloadTotal > 0) {
      return `正在上传 ${uploadDone}/${uploadTotal} · 下载 ${downloadDone}/${downloadTotal}`;
    }
    if (uploadTotal > 0) {
      return `正在上传 ${uploadDone}/${uploadTotal}`;
    }
    return `正在下载 ${downloadDone}/${downloadTotal}`;
  }

  private static countFailedRows(progress: relationalStore.ProgressDetails): number {
    const details = progress.details;
    if (!details) {
      return 0;
    }
    let failed = 0;
    const tables = Object.keys(details);
    for (const table of tables) {
      const tableDetails = details[table];
      if (!tableDetails) {
        continue;
      }
      failed += tableDetails.upload.failed + tableDetails.download.failed;
    }
    return failed;
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
    if (code === relationalStore.ProgressCode.CLOUD_DISABLED) {
      return '未在“设置-云空间”中开启本应用的同步开关';
    }
    if (code === relationalStore.ProgressCode.NETWORK_ERROR) {
      return '网络错误，同步已暂停';
    }
    if (code === relationalStore.ProgressCode.RECORD_LIMIT_EXCEEDED) {
      return '超出云空间数据上限';
    }
    if (code === relationalStore.ProgressCode.NO_SPACE_FOR_ASSET) {
      return '云空间存储空间不足';
    }
    if (code === relationalStore.ProgressCode.BLOCKED_BY_NETWORK_STRATEGY) {
      return '当前网络不满足同步策略';
    }
    if (code === relationalStore.ProgressCode.LOCKED_BY_OTHERS) {
      return '其他设备正在占用云端同步，请稍后再试';
    }
    if (code === relationalStore.ProgressCode.STOP_CLOUD_SYNC) {
      return '同步任务被系统停止';
    }
    if (code === relationalStore.ProgressCode.UNKNOWN_ERROR) {
      return '同步遇到未知错误';
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
