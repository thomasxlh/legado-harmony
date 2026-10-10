import { relationalStore, cloudData } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import hilog from '@ohos.hilog';

/** 状态机初始态，独立定义以避免类字段初始化顺序上的耦合。 */
const SYNC_STATUS_IDLE_LITERAL: string = 'idle';

/** 端云同步主流程的终局判定结果，供 UI 展示与后续重试决策使用。 */
export class CloudSyncOutcome {
  /** 状态机的终态。一次进度回调都没收到时不会是 SYNCED。 */
  status: string = SYNC_STATUS_IDLE_LITERAL;
  /** 是否确定数据已到达云端。仅 SYNCED 且本值为 true 时才刷新“上次成功时间”。 */
  confirmed: boolean = false;
  /** 主同步过程中见过的最坏进度码；-1 表示没有任何进度回调。 */
  progressCode: number = -1;
  /** 未能同步的行数，来自进度回调的 upload/download failed 计数。 */
  failedRows: number = 0;
  /** 面向用户的补充说明，空串表示无附加信息。 */
  message: string = '';
}

export class CloudSyncService {
  static readonly SYNC_TABLES: string[] =
    ['books', 'book_sources', 'book_groups', 'search_keywords', 'sync_heartbeats'];

  static readonly STORAGE_SUPPORTED: string = 'cloudSyncSupported';
  static readonly STORAGE_STATUS: string = 'cloudSyncStatus';
  static readonly STORAGE_LAST_SUCCESS_AT: string = 'cloudSyncLastSuccessAt';
  static readonly STORAGE_MESSAGE: string = 'cloudSyncMessage';
  static readonly STORAGE_REVISION: string = 'cloudSyncRevision';
  /** 云链路已确认连通；与 STORAGE_SUPPORTED 区分，后者只代表系统版本支持该 API。 */
  static readonly STORAGE_LINKED: string = 'cloudSyncLinked';

  static readonly STATUS_IDLE: string = 'idle';
  static readonly STATUS_SYNCING: string = 'syncing';
  static readonly STATUS_PENDING: string = 'pending';
  static readonly STATUS_SYNCED: string = 'synced';
  static readonly STATUS_ERROR: string = 'error';
  static readonly STATUS_UNSUPPORTED: string = 'unsupported';

  private static store: relationalStore.RdbStore | null = null;
  private static supported: boolean = false;
  /**
   * 同步槽位。槽位在任何 await 之前就挂载（见 acquireSlot/beginSlot），因此不存在
   * “两个调用者同时越过检查”的并发窗口；null 表示当前无人同步。
   */
  private static pendingSync: Promise<CloudSyncOutcome> | null = null;
  /** pendingSync 对应的会话起始时间，用于识别并回收陈旧槽位。 */
  private static pendingSyncStartedAt: number = 0;
  private static deviceId: string = '';
  private static lastAutoSyncRequestAt: number = 0;
  private static lastDataChangeTriggerAt: number = 0;
  /** 自动同步被去抖或在飞时丢弃，标记“有本地变更待上传”，下个窗口优先补传。 */
  private static autoSyncWanted: boolean = false;
  /** 手动同步写心跳后进入的静默窗口：期间云端回推的变更通知不再触发自动同步。 */
  private static heartbeatQuietUntil: number = 0;
  private static autoSyncTriggerRegistered: boolean = false;
  private static followUpTimer: number = -1;
  /** 后台验证器的冷却截止时刻：期间不再重复起新的验证器。 */
  private static verifyUntil: number = 0;

  static readonly AUTO_SYNC_MIN_INTERVAL_MS: number = 5 * 60 * 1000;
  // 后台验证最多 VERIFY_TICKS 轮，单轮等待不超过 VERIFY_TICK_INTERVAL_MS，
  // 因此即使定时器被冻结，槽位也会在有限时间内被回收（见 SLOT_STALE_MS）。
  static readonly VERIFY_TICKS: number = 12;
  static readonly VERIFY_TICK_INTERVAL_MS: number = 30 * 1000;
  /** 心跳静默窗口：覆盖主同步上传 + 云端回推通知的典型耗时。 */
  private static readonly HEARTBEAT_QUIET_MS: number = 90 * 1000;
  /** 心跳行保留窗口，避免重装/换机导致云端行数单调增长。 */
  private static readonly HEARTBEAT_RETAIN_MS: number = 30 * 24 * 60 * 60 * 1000;
  /** 槽位陈旧阈值：远超单次同步的最坏耗时，用于兜底回收。 */
  private static readonly SLOT_STALE_MS: number = 15 * 60 * 1000;
  /** 验证器冷却期：略长于验证器最长运行时间，避免开关长期关闭时反复起验证器。 */
  private static readonly VERIFY_COOL_DOWN_MS: number = 7 * 60 * 1000;
  private static readonly LAST_SUCCESS_KEY: string = 'cloud_sync_last_success_at';

  static initializeStorage(): void {
    AppStorage.setOrCreate(CloudSyncService.STORAGE_SUPPORTED, false);
    AppStorage.setOrCreate(CloudSyncService.STORAGE_LINKED, false);
    AppStorage.setOrCreate(CloudSyncService.STORAGE_STATUS, CloudSyncService.STATUS_IDLE);
    AppStorage.setOrCreate(CloudSyncService.STORAGE_LAST_SUCCESS_AT, 0);
    AppStorage.setOrCreate(CloudSyncService.STORAGE_MESSAGE, '');
    AppStorage.setOrCreate(CloudSyncService.STORAGE_REVISION, 0);
  }

  static async configure(store: relationalStore.RdbStore, deviceId: string): Promise<void> {
    CloudSyncService.initializeStorage();
    CloudSyncService.store = store;
    CloudSyncService.deviceId = deviceId;
    // 先恢复跨冷启动的“上次成功时间”，再设置状态，避免被 STATUS_IDLE 覆盖后丢失。
    await CloudSyncService.restorePersistedLastSuccessAt();
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
      // 冷启动路径：onForeground 早于数据库初始化完成，它触发的自动同步会被
      // supported=false 丢弃。配置成功后补一次，兑现“启动即同步”的文案。
      CloudSyncService.requestAutoSync();
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
    // 重复 configure（如数据库重连）不应重复注册回调，否则每次通知会触发多次同步。
    if (CloudSyncService.autoSyncTriggerRegistered) {
      return;
    }
    if (typeof cloudData.onAutoSyncTrigger !== 'function') {
      return;
    }
    try {
      cloudData.onAutoSyncTrigger((info: cloudData.AutoSyncTriggerInfo): void => {
        CloudSyncService.handleAutoSyncTrigger(info);
      });
      CloudSyncService.autoSyncTriggerRegistered = true;
    } catch (error) {
      const err = error as BusinessError;
      hilog.warn(0x0000, 'CloudSync', 'onAutoSyncTrigger failed: %{public}d %{public}s',
        err.code, err.message);
    }
  }

  private static handleAutoSyncTrigger(info: cloudData.AutoSyncTriggerInfo): void {
    // 本设备上传落地云端后，系统会回推“云端数据变更”通知；
    // 记录其到达时间，作为云空间链路可用的确定性证据（后台验证器使用）。
    if (info.mode === cloudData.AutoSyncTriggerMode.CLOUD_DATA_CHANGE) {
      CloudSyncService.lastDataChangeTriggerAt = Date.now();
      hilog.info(0x0000, 'CloudSync', 'cloud data change trigger received');
    }
    // 手动同步写心跳后进入静默窗口：心跳落地回推的通知不应再唤起自动同步，
    // 否则“手动同步 → 回推 → 自动同步 → 回推”会形成自我维持的上传链条。
    if (Date.now() < CloudSyncService.heartbeatQuietUntil) {
      hilog.info(0x0000, 'CloudSync', 'auto sync trigger suppressed by heartbeat quiet window');
      return;
    }
    CloudSyncService.requestAutoSync();
  }

  /** 汇报一次本地数据变更：仅标记待上传，不主动发起同步（同步时机仍由去抖控制）。 */
  static notifyLocalChange(): void {
    CloudSyncService.autoSyncWanted = true;
  }

  /** 是否已有待上传的本地变更尚未同步。 */
  static hasPendingLocalChange(): boolean {
    return CloudSyncService.autoSyncWanted;
  }

  /**
   * 去抖的自动同步入口：App 前后台切换与云端变更通知调用。
   * @param urgent 退后台时传 true：绕过 5 分钟去抖窗口，因为退后台后这可能是
   *               本轮最后一次上传机会（听书进度不会实时上云）。
   */
  static requestAutoSync(urgent: boolean = false): void {
    if (!CloudSyncService.supported) {
      // 能力尚未就绪（冷启动早期）：留待办，configure 成功后再补一次。
      CloudSyncService.autoSyncWanted = true;
      return;
    }
    const now = Date.now();
    // 只有 urgent 才绕过去抖。注意不能因为“有堆积变更”就绕过：阅读进度每几秒
    // 落一次库，autoSyncWanted 几乎恒为真，那等于取消去抖，正是这个设计要避免的
    // 云空间持续增长。堆积变更改由 scheduleFollowUp 在下个去抖窗口补传。
    if (!urgent &&
      now - CloudSyncService.lastAutoSyncRequestAt < CloudSyncService.AUTO_SYNC_MIN_INTERVAL_MS) {
      // 去抖期内被丢弃的请求必须留待办：autoSync=false 意味着系统不会兜底补传。
      CloudSyncService.autoSyncWanted = true;
      CloudSyncService.scheduleFollowUp();
      return;
    }
    if (CloudSyncService.pendingSync) {
      // 在飞：不重复发起，但同样留待办，避免这一轮变更被永久跳过。
      CloudSyncService.autoSyncWanted = true;
      CloudSyncService.scheduleFollowUp();
      return;
    }
    CloudSyncService.lastAutoSyncRequestAt = now;
    CloudSyncService.autoSyncWanted = false;
    // 自动同步不写心跳脏行：写心跳会触发云端数据变更通知，
    // onAutoSyncTrigger 再次唤起自动同步，形成"每 5 分钟上传一版心跳"的自我维持循环，
    // 云端版本无限累积导致云空间占用持续增长。
    CloudSyncService.syncNow(false).then((outcome: CloudSyncOutcome) => {
      hilog.info(0x0000, 'CloudSync',
        'auto sync done: status=%{public}s confirmed=%{public}d code=%{public}d',
        outcome.status, outcome.confirmed ? 1 : 0, outcome.progressCode);
    }).catch((error: Error) => {
      // 真实异常单独成行，避免与“去抖跳过”混在一起难以定位。
      hilog.warn(0x0000, 'CloudSync', 'auto sync failed: %{public}s', error.message);
    });
  }

  /** 一轮同步结束后，若期间又有变更被标记待上传，安排一次补传。 */
  private static scheduleFollowUp(): void {
    if (!CloudSyncService.autoSyncWanted || !CloudSyncService.supported) {
      return;
    }
    if (CloudSyncService.followUpTimer >= 0) {
      return;
    }
    CloudSyncService.followUpTimer = setTimeout(() => {
      CloudSyncService.followUpTimer = -1;
      if (CloudSyncService.autoSyncWanted) {
        CloudSyncService.requestAutoSync(true);
      }
    }, CloudSyncService.AUTO_SYNC_MIN_INTERVAL_MS);
  }

  static isSupported(): boolean {
    return CloudSyncService.supported;
  }

  /** 云链路是否已确认连通（区别于“系统版本支持该能力”）。 */
  static isLinked(): boolean {
    return AppStorage.get<boolean>(CloudSyncService.STORAGE_LINKED) || false;
  }

  static isSyncing(): boolean {
    return CloudSyncService.pendingSync !== null;
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
   *
   * 心跳行只能证明“链路通”，不能证明业务表全部成功：终局判定同时纳入主同步的
   * 最坏进度码与失败行数（见 finishSession）。
   */
  static async syncNow(verifyWithHeartbeat: boolean = false): Promise<CloudSyncOutcome> {
    const store = CloudSyncService.store;
    if (!store || !CloudSyncService.supported) {
      return Promise.reject(new Error('当前设备不支持端云同步'));
    }
    const existing = CloudSyncService.acquireSlot();
    if (existing) {
      // 复用在飞任务，等待真实完成，避免并发调用拿到假的成功结果。
      // “确认中”阶段的在飞任务是后台验证器，加入后会等待最终结论。
      return existing;
    }
    const slot: Promise<CloudSyncOutcome> =
      CloudSyncService.runSyncSession(verifyWithHeartbeat);
    CloudSyncService.pendingSync = slot;
    CloudSyncService.pendingSyncStartedAt = Date.now();
    const release = (): void => {
      if (CloudSyncService.pendingSync === slot) {
        CloudSyncService.pendingSync = null;
        CloudSyncService.pendingSyncStartedAt = 0;
      }
      CloudSyncService.scheduleFollowUp();
    };
    slot.then(release, release);
    return slot;
  }

  /**
   * 抢占同步槽位。返回已存在的在飞任务（调用方应复用），返回 null 表示抢占成功，
   * 调用方必须随后写入自己的 promise。陈旧槽位会被强制回收，避免定时器被系统
   * 冻结后槽位永久占用、导致后续同步全部静默丢弃。
   */
  private static acquireSlot(): Promise<CloudSyncOutcome> | null {
    const slot = CloudSyncService.pendingSync;
    if (!slot) {
      return null;
    }
    const age = Date.now() - CloudSyncService.pendingSyncStartedAt;
    if (age < CloudSyncService.SLOT_STALE_MS) {
      return slot;
    }
    hilog.warn(0x0000, 'CloudSync', 'recycling stale sync slot after %{public}d ms', age);
    CloudSyncService.pendingSync = null;
    CloudSyncService.pendingSyncStartedAt = 0;
    // 陈旧任务可能永不 settle，挂空消费分支，避免未处理的 promise rejection。
    slot.catch(() => undefined);
    return null;
  }

  private static async runSyncSession(verifyWithHeartbeat: boolean): Promise<CloudSyncOutcome> {
    const store = CloudSyncService.store;
    if (!store) {
      const empty = new CloudSyncOutcome();
      empty.status = CloudSyncService.STATUS_ERROR;
      empty.message = '数据库尚未就绪';
      CloudSyncService.applyOutcome(empty);
      throw new Error(empty.message);
    }
    const sessionStart = Date.now();
    let probeStamp = 0;
    if (verifyWithHeartbeat) {
      probeStamp = await CloudSyncService.writeSyncHeartbeat();
      if (probeStamp > 0) {
        // 抑制心跳落地后回推的变更通知，切断“手动同步 → 自动同步”的自触发链。
        CloudSyncService.heartbeatQuietUntil = Date.now() + CloudSyncService.HEARTBEAT_QUIET_MS;
      }
    }
    CloudSyncService.setStatus(CloudSyncService.STATUS_SYNCING, '');
    let worstCode: number = -1;
    let worstMessage: string = '';
    let failedRows: number = 0;
    let sawProgress: boolean = false;
    const mainTask = new Promise<void>((resolve, reject) => {
      try {
        store.cloudSync(relationalStore.SyncMode.SYNC_MODE_TIME_FIRST,
          CloudSyncService.SYNC_TABLES,
          (progress: relationalStore.ProgressDetails) => {
            // 累积整个会话中最坏的结果：多张表会分别回调，只看最后一次会漏掉
            // “books 失败、其它表成功”这类混合场景。
            sawProgress = true;
            worstCode = CloudSyncService.worseProgressCode(worstCode, progress.code);
            failedRows += CloudSyncService.countFailedRows(progress);
            worstMessage = CloudSyncService.progressMessage(progress) || worstMessage;
            hilog.debug(0x0000, 'CloudSync', 'progress: code=%{public}d details=%{public}s',
              progress.code, JSON.stringify(progress.details));
            const live = CloudSyncService.progressText(progress);
            if (live) {
              CloudSyncService.setStatus(CloudSyncService.STATUS_SYNCING, live);
            }
          },
          (error: BusinessError) => {
            hilog.info(0x0000, 'CloudSync',
              'main sync finished: err=%{public}d worstCode=%{public}d failedRows=%{public}d probe=%{public}d',
              error ? error.code : 0, worstCode, failedRows, probeStamp);
            if (error) {
              reject(new Error(CloudSyncService.describeError(error.code, error.message)));
              return;
            }
            resolve();
          });
      } catch (error) {
        const err = error as BusinessError;
        reject(new Error(CloudSyncService.describeError(err.code, err.message)));
      }
    });

    try {
      await mainTask;
    } catch (error) {
      const failed = new CloudSyncOutcome();
      failed.status = CloudSyncService.STATUS_ERROR;
      failed.progressCode = worstCode;
      failed.failedRows = failedRows;
      failed.message = CloudSyncService.errorText(error) || '同步失败';
      CloudSyncService.applyOutcome(failed);
      throw new Error(failed.message);
    }

    let confirmed = false;
    if (probeStamp > 0) {
      confirmed = await CloudSyncService.probeCloudRoundTrip(probeStamp);
    } else if (sawProgress && worstCode === relationalStore.ProgressCode.SUCCESS) {
      // 自动同步不写心跳，但主同步明确上报过 SUCCESS，可视为链路已通。
      confirmed = true;
    }

    const outcome = CloudSyncService.finishSession(probeStamp, sessionStart, worstCode,
      worstMessage, failedRows, sawProgress, confirmed);
    if (outcome.status === CloudSyncService.STATUS_ERROR) {
      CloudSyncService.applyOutcome(outcome);
      throw new Error(outcome.message);
    }
    CloudSyncService.applyOutcome(outcome);
    return outcome;
  }

  /**
   * 主同步无异常后的终局判定。核心原则：一次进度回调都没收到（sawProgress=false）
   * 属于“未知”，绝不能当作成功 —— 云空间开关关闭时正是这种表现。
   */
  private static finishSession(probeStamp: number, sessionStart: number, worstCode: number,
    worstMessage: string, failedRows: number, sawProgress: boolean,
    confirmed: boolean): CloudSyncOutcome {
    const outcome = new CloudSyncOutcome();
    outcome.progressCode = worstCode;
    outcome.failedRows = failedRows;

    // 失败码优先：无论探针结论如何，明确失败就是失败。
    if (worstCode >= 0 && worstCode !== relationalStore.ProgressCode.SUCCESS) {
      outcome.status = CloudSyncService.STATUS_ERROR;
      outcome.message = CloudSyncService.describeProgress(worstCode, worstMessage);
      return outcome;
    }
    // 心跳行到达不代表业务表全部成功：合并主同步统计到的失败行数。
    if (failedRows > 0) {
      outcome.status = CloudSyncService.STATUS_ERROR;
      outcome.message = `有 ${failedRows} 条数据未能同步`;
      return outcome;
    }
    if (confirmed) {
      outcome.status = CloudSyncService.STATUS_SYNCED;
      outcome.confirmed = true;
      return outcome;
    }

    // 走到这里有两种未知：一次进度都没有（开关关闭的典型表现），或写了心跳但
    // 短探针没拉回来（系统批量上传期间应用发起的 cloudSync 会被静默丢弃）。
    // 两者都不能判成功，也都不立刻判失败：进入“确认中”，由后台验证器通过
    // “云端变更通知 + 心跳拉取”双通道在数分钟内得出最终结论。
    outcome.status = CloudSyncService.STATUS_PENDING;
    if (CloudSyncService.verifyBusy()) {
      // 已有验证器在跑或刚跑完（冷却期内）：保持“确认中”即可，重复起验证器
      // 只会让开关长期关闭的设备陷入“每次同步都起一个 6 分钟验证器”的循环。
      hilog.info(0x0000, 'CloudSync',
        'sync result unknown, verifier already active (sawProgress=%{public}d probe=%{public}d)',
        sawProgress ? 1 : 0, probeStamp);
      return outcome;
    }
    CloudSyncService.verifyUntil = Date.now() + CloudSyncService.VERIFY_COOL_DOWN_MS;
    const verdict = CloudSyncService.startCloudVerify(probeStamp, sessionStart);
    CloudSyncService.pendingSync = verdict;
    // 验证器可能以 rejection 结束，而 UI 反馈已由 setStatus 承担；挂空分支防止
    // 无人接管的 promise rejection。
    verdict.catch(() => undefined);
    hilog.info(0x0000, 'CloudSync',
      'sync result unknown (sawProgress=%{public}d probe=%{public}d), background verify started',
      sawProgress ? 1 : 0, probeStamp);
    return outcome;
  }

  /** 后台验证器是否已在运行或刚跑完（冷却期内不再重复起新的验证器）。 */
  private static verifyBusy(): boolean {
    return Date.now() < CloudSyncService.verifyUntil;
  }

  /** 把终局结果落到 AppStorage：只有确认成功才刷新“上次成功时间”。 */
  private static applyOutcome(outcome: CloudSyncOutcome): void {
    if (outcome.status === CloudSyncService.STATUS_SYNCED) {
      if (outcome.confirmed) {
        AppStorage.setOrCreate(CloudSyncService.STORAGE_LINKED, true);
      }
    } else if (outcome.status === CloudSyncService.STATUS_ERROR) {
      AppStorage.setOrCreate(CloudSyncService.STORAGE_LINKED, false);
    }
    CloudSyncService.setStatus(outcome.status, outcome.message);
  }

  /**
   * 后台云连接验证器：终局未知时启动。每 30 秒检查一次：
   * 1. 是否收到“云端数据变更”通知（本设备上传落地后系统会回推，开关关闭时不会有）；
   * 2. 心跳拉取探针是否确认。
   * 最长 VERIFY_TICKS 轮（约 6 分钟）后仍未确认则判定云空间不可达。
   * 单轮等待固定不超过 VERIFY_TICK_INTERVAL_MS，配合槽位陈旧回收，不会永久占用同步。
   */
  private static startCloudVerify(pushedAt: number,
    sessionStart: number): Promise<CloudSyncOutcome> {
    const verdict = CloudSyncService.runCloudVerify(pushedAt, sessionStart);
    const release = (): void => {
      if (CloudSyncService.pendingSync === verdict) {
        CloudSyncService.pendingSync = null;
        CloudSyncService.pendingSyncStartedAt = 0;
      }
    };
    verdict.then(release, release);
    return verdict;
  }

  private static async runCloudVerify(pushedAt: number,
    sessionStart: number): Promise<CloudSyncOutcome> {
    const outcome = new CloudSyncOutcome();
    const store = CloudSyncService.store;
    const deviceId = CloudSyncService.deviceId;
    const linkMessage = '未能连接云空间：请检查“设置-云空间”中本应用的同步开关与网络连接';
    if (!store || !deviceId) {
      outcome.status = CloudSyncService.STATUS_ERROR;
      outcome.message = linkMessage;
      CloudSyncService.applyOutcome(outcome);
      throw new Error(linkMessage);
    }
    for (let tick = 1; tick <= CloudSyncService.VERIFY_TICKS; tick++) {
      await CloudSyncService.delay(CloudSyncService.VERIFY_TICK_INTERVAL_MS);
      // 通道一：本会话期间收到过“云端数据变更”通知，证明链路可用
      if (CloudSyncService.lastDataChangeTriggerAt >= sessionStart) {
        hilog.info(0x0000, 'CloudSync',
          'verify confirmed by data-change trigger, tick=%{public}d', tick);
        outcome.status = CloudSyncService.STATUS_SYNCED;
        outcome.confirmed = true;
        CloudSyncService.applyOutcome(outcome);
        return outcome;
      }
      // 通道二：心跳拉取探针
      if (pushedAt > 0) {
        try {
          await CloudSyncService.pullSyncHeartbeatTable(store);
        } catch (error) {
          const err = error as BusinessError;
          hilog.warn(0x0000, 'CloudSync',
            'verify pull failed (tick %{public}d): %{public}d %{public}s',
            tick, err.code, err.message);
          continue;
        }
        const current = await CloudSyncService.readHeartbeatStamp(store, deviceId);
        if (current === pushedAt) {
          hilog.info(0x0000, 'CloudSync',
            'verify confirmed by heartbeat pull, tick=%{public}d', tick);
          outcome.status = CloudSyncService.STATUS_SYNCED;
          outcome.confirmed = true;
          CloudSyncService.applyOutcome(outcome);
          return outcome;
        }
      }
    }
    hilog.warn(0x0000, 'CloudSync', 'verify failed after all ticks');
    outcome.status = CloudSyncService.STATUS_ERROR;
    outcome.message = linkMessage;
    CloudSyncService.applyOutcome(outcome);
    throw new Error(linkMessage);
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
      // 顺带清理长时间未上报的设备心跳，避免重装/换机导致云端行数单调增长。
      CloudSyncService.pruneSyncHeartbeats(stamp);
      return stamp;
    } catch (error) {
      const err = error as BusinessError;
      hilog.warn(0x0000, 'CloudSync', 'write heartbeat failed: %{public}d %{public}s',
        err.code, err.message);
      return 0;
    }
  }

  private static pruneSyncHeartbeats(now: number): void {
    const store = CloudSyncService.store;
    if (!store) {
      return;
    }
    const threshold = now - CloudSyncService.HEARTBEAT_RETAIN_MS;
    store.executeSql('DELETE FROM sync_heartbeats WHERE updatedAt > 0 AND updatedAt < ?',
      [threshold]).catch((error: BusinessError) => {
      hilog.warn(0x0000, 'CloudSync', 'prune heartbeats failed: %{public}d %{public}s',
        error.code, error.message);
    });
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
    // 云端刚经历清空/全量重传时，系统批量上传在后台持续进行，应用发起的 cloudSync
    // 会被静默丢弃，长窗口等待只会阻塞用户。这里只做短窗口快探（约 50 秒）：
    // 稳态下一次拉取即可确认；批量传输期间确认不了则交给后台验证器异步出结论。
    const schedule: number[] = [0, 5000, 10000, 15000, 20000];
    for (let index = 0; index < schedule.length; index++) {
      if (schedule[index] > 0) {
        await CloudSyncService.delay(schedule[index]);
        CloudSyncService.setStatus(CloudSyncService.STATUS_SYNCING,
          `正在校验云连接（第 ${index}/${schedule.length - 1} 次）…`);
      }
      try {
        // 仅对探针表执行“云→端”拉取，不会把本地差异推送到云端。
        await CloudSyncService.pullSyncHeartbeatTable(store);
      } catch (error) {
        const err = error as BusinessError;
        hilog.warn(0x0000, 'CloudSync', 'probe pull failed (attempt %{public}d): %{public}d %{public}s',
          index + 1, err.code, err.message);
        continue;
      }
      const current = await CloudSyncService.readHeartbeatStamp(store, deviceId);
      const confirmed = current === pushedAt;
      hilog.info(0x0000, 'CloudSync',
        'probe: attempt=%{public}d pushedAt=%{public}d local=%{public}d current=%{public}d confirmed=%{public}d',
        index + 1, pushedAt, localStamp, current, confirmed ? 1 : 0);
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
    // 在 SQL 侧聚合，避免把 books.intro / book_sources.jsLib 等大字段全量拉进内存；
    // 并按字节计（CAST AS BLOB）而非 getString 的字符数 —— 后者对中文低估约 3 倍。
    // 只统计实际会上传的列：书源凭据与 rawSourceJson 已迁到 book_source_local，
    // 同步表中恒为空，计入只会虚报占用。
    const columns: Record<string, string[]> = {
      'books': ['bookUrl', 'name', 'author', 'intro', 'customIntro', 'variable',
        'readConfig', 'latestChapterTitle', 'durChapterTitle', 'coverUrl', 'customCoverUrl'],
      'book_sources': ['bookSourceUrl', 'bookSourceName', 'jsLib',
        'bookUrlPattern', 'searchUrl', 'exploreUrl', 'header', 'bookListRule',
        'searchRule', 'exploreRule', 'bookInfoRule', 'tocRule', 'contentRule'],
      'book_groups': ['groupName'],
      'search_keywords': ['keyword'],
      'sync_heartbeats': ['deviceId']
    };
    let total = 0;
    for (const table of CloudSyncService.SYNC_TABLES) {
      let bytes = 0;
      try {
        const cols = columns[table] || [];
        const expr = cols.map((col: string): string => `IFNULL(length(CAST(${col} AS BLOB)), 0)`)
          .join(' + ');
        if (expr === '') {
          sizes[table] = 0;
          continue;
        }
        const resultSet = await store.querySql(`SELECT IFNULL(SUM(${expr}), 0) AS bytes FROM ${table}`);
        try {
          if (resultSet.goToFirstRow()) {
            bytes = resultSet.getLong(resultSet.getColumnIndex('bytes'));
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

  /**
   * 取两个进度码中更坏的一个。一次同步会对多张表分别回调，只看最后一次会漏掉
   * “某张表失败、其它表成功”的混合场景。-1 表示尚未收到任何回调。
   */
  private static worseProgressCode(current: number, incoming: number): number {
    if (current < 0) {
      return incoming;
    }
    if (incoming < 0) {
      return current;
    }
    // 明确的阻断性结果优先级最高，不能被后续的 SUCCESS 覆盖。
    const blocking: number[] = [
      relationalStore.ProgressCode.CLOUD_DISABLED,
      relationalStore.ProgressCode.LOCKED_BY_OTHERS,
      relationalStore.ProgressCode.RECORD_LIMIT_EXCEEDED,
      relationalStore.ProgressCode.NO_SPACE_FOR_ASSET
    ];
    if (blocking.indexOf(current) >= 0) {
      return current;
    }
    if (blocking.indexOf(incoming) >= 0) {
      return incoming;
    }
    if (current === relationalStore.ProgressCode.SUCCESS) {
      return incoming;
    }
    return current;
  }

  private static progressMessage(progress: relationalStore.ProgressDetails): string {
    return progress.message ? progress.message : '';
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
    if (status === CloudSyncService.STATUS_PENDING) {
      return '已提交，正在确认云连接';
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

  /** 统一的进度码文案，供主同步失败与最坏进度码复用。 */
  private static describeProgress(code: number, detail: string): string {
    const described = CloudSyncService.describeError(code, '');
    const extra = detail ? `：${detail}` : '';
    return `${described}${extra}`;
  }

  private static describeError(code: number, rawMessage: string): string {
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
    // 未识别的码带上原始信息，避免出现 “undefined” 之类的空壳文案。
    if (rawMessage) {
      return `同步失败（${code}）：${rawMessage}`;
    }
    return `同步失败（${code}）`;
  }

  /** 把任意 throw 值转成可读文案，兼容非 BusinessError。 */
  private static errorText(error: Object): string {
    if (error instanceof Error) {
      return error.message;
    }
    const err = error as BusinessError;
    if (err && err.code !== undefined) {
      return CloudSyncService.describeError(err.code, err.message);
    }
    return error ? String(error) : '';
  }

  private static setStatus(status: string, message: string): void {
    if (status === CloudSyncService.STATUS_SYNCED) {
      const now = Date.now();
      AppStorage.setOrCreate(CloudSyncService.STORAGE_LAST_SUCCESS_AT, now);
      CloudSyncService.persistLastSuccessAt(now);
    }
    AppStorage.setOrCreate(CloudSyncService.STORAGE_STATUS, status);
    AppStorage.setOrCreate(CloudSyncService.STORAGE_MESSAGE, message);
    const revision = (AppStorage.get<number>(CloudSyncService.STORAGE_REVISION) || 0) + 1;
    AppStorage.setOrCreate(CloudSyncService.STORAGE_REVISION, revision);
  }

  /** 上次成功时间落到 device_meta，跨冷启动保留。 */
  private static persistLastSuccessAt(timestamp: number): void {
    const store = CloudSyncService.store;
    if (!store) {
      return;
    }
    store.executeSql('INSERT OR REPLACE INTO device_meta (key, value) VALUES (?, ?)',
      [CloudSyncService.LAST_SUCCESS_KEY, String(timestamp)]).catch((error: BusinessError) => {
      hilog.warn(0x0000, 'CloudSync', 'persist last success failed: %{public}d %{public}s',
        error.code, error.message);
    });
  }

  /** 数据库就绪后补读持久化的上次成功时间。 */
  private static restorePersistedLastSuccessAt(): Promise<void> {
    const store = CloudSyncService.store;
    if (!store) {
      return Promise.resolve();
    }
    return store.querySql('SELECT value FROM device_meta WHERE key = ?',
      [CloudSyncService.LAST_SUCCESS_KEY]).then((resultSet) => {
      try {
        if (resultSet.goToFirstRow()) {
          const parsed = Number(resultSet.getString(resultSet.getColumnIndex('value')));
          if (!isNaN(parsed) && parsed > 0) {
            AppStorage.setOrCreate(CloudSyncService.STORAGE_LAST_SUCCESS_AT, parsed);
          }
        }
      } finally {
        resultSet.close();
      }
    }).catch((error: BusinessError) => {
      hilog.warn(0x0000, 'CloudSync', 'restore last success failed: %{public}d %{public}s',
        error.code, error.message);
    });
  }
}
