import { relationalStore, cloudData } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import hilog from '@ohos.hilog';

/** 状态机初始态，独立定义以避免类字段初始化顺序上的耦合。 */
const SYNC_STATUS_IDLE_LITERAL: string = 'idle';

/** 单张同步表在一次会话内的传输统计快照，数值取该表最后一次进度回调。 */
interface TableSyncStats {
  uploadTotal: number;
  uploadRemained: number;
  uploadFailed: number;
  downloadTotal: number;
  downloadRemained: number;
  downloadFailed: number;
}

/** 端云同步主流程的终局判定结果，供 UI 展示与后续重试决策使用。 */
export class CloudSyncOutcome {
  /** 状态机的终态。一次进度回调都没收到时不会是 SYNCED。 */
  status: string = SYNC_STATUS_IDLE_LITERAL;
  /** 主同步过程中见过的最坏进度码；-1 表示没有任何进度回调。 */
  progressCode: number = -1;
  /** 未能同步的行数，来自进度回调的 upload/download failed 计数。 */
  failedRows: number = 0;
  /** 本次会话需上传的行数（跨表汇总）；0 表示进度回调未上报任何待传行。 */
  uploadTotal: number = 0;
  /** 本次会话已成功上传的行数。 */
  uploadDone: number = 0;
  /** 本次会话需下载的行数。 */
  downloadTotal: number = 0;
  /** 本次会话已成功下载的行数。 */
  downloadDone: number = 0;
  /** 面向用户的补充说明，空串表示无附加信息。 */
  message: string = '';
}

export class CloudSyncService {
  static readonly SYNC_TABLES: string[] =
    ['books', 'book_sources', 'book_groups', 'search_keywords', 'bookmarks', 'app_preferences',
      'theme_assets'];

  /**
   * 端云分布式表的 autoSync 取值，**必须为 true**。
   * 设为 false 时云空间里本应用的同步开关会被系统置为关闭，且每次应用启动重新
   * 声明都会再关一次，于是“用户在设置里打开了开关、应用却一直报没开”，整轮
   * cloudSync 恒返回 code=1；重登账号与卸载重装都救不了，因为每次启动都关一遍。
   */
  static readonly DISTRIBUTED_AUTO_SYNC: boolean = true;

  static readonly STORAGE_SUPPORTED: string = 'cloudSyncSupported';
  static readonly STORAGE_STATUS: string = 'cloudSyncStatus';
  static readonly STORAGE_LAST_SUCCESS_AT: string = 'cloudSyncLastSuccessAt';
  static readonly STORAGE_MESSAGE: string = 'cloudSyncMessage';
  static readonly STORAGE_REVISION: string = 'cloudSyncRevision';
  /** 最近一次会话实际上传/下载的行数，供 UI 直接回答“到底有没有数据在传”。 */
  static readonly STORAGE_LAST_UPLOAD: string = 'cloudSyncLastUploadRows';
  static readonly STORAGE_LAST_DOWNLOAD: string = 'cloudSyncLastDownloadRows';
  /** 是否有已落库但尚未上传的本地变更，供界面提示“改动待上传”。 */
  static readonly STORAGE_PENDING: string = 'cloudSyncPending';
  /** 云链路已确认连通；与 STORAGE_SUPPORTED 区分，后者只代表系统版本支持该 API。 */
  static readonly STORAGE_LINKED: string = 'cloudSyncLinked';

  static readonly STATUS_IDLE: string = 'idle';
  static readonly STATUS_SYNCING: string = 'syncing';
  /** 同步请求已提交但应用无法确认结果（系统未给任何进度回调），请用户自行去云空间确认。 */
  static readonly STATUS_SUBMITTED: string = 'submitted';
  static readonly STATUS_SYNCED: string = 'synced';
  static readonly STATUS_ERROR: string = 'error';
  /**
   * 同步被可自动恢复的原因暂停（网络错误/其他设备占用/网络策略不满足/被系统停止），
   * 系统会在条件恢复后自动重试。与 STATUS_ERROR 区分：不视为失败、不清空云链路标记。
   */
  static readonly STATUS_PAUSED: string = 'paused';
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
  private static lastAutoSyncRequestAt: number = 0;
  /**
   * 待上传变更的发生时刻，0 表示没有待上传变更。
   * 用时刻而非布尔量：同步会话开始时“取走”当前标记，会话期间新写入的变更会重新
   * 置位，于是会话结束时能区分“本次已纳入的变更”与“之后才发生的变更”——后者
   * 必须继续留在待上传状态，否则补传定时器会因为标记被清空而跳过它们。
   */
  private static pendingSince: number = 0;
  private static autoSyncTriggerRegistered: boolean = false;
  private static followUpTimer: number = -1;
  /**
   * 云同步会话终局的监听者（如偏好同步桥：会话定稿后对 app_preferences 行做
   * 双向对账）。监听回调必须自行幂等：迟到终态会让 applyOutcome 二次触发。
   */
  private static sessionListeners: Array<(outcome: CloudSyncOutcome) => void> = [];

  static readonly AUTO_SYNC_MIN_INTERVAL_MS: number = 5 * 60 * 1000;
  /** 槽位陈旧阈值：远超单次同步的最坏耗时，用于兜底回收。 */
  private static readonly SLOT_STALE_MS: number = 15 * 60 * 1000;
  /** cloudSync 受理回执等待上限：AsyncCallback 正常毫秒级返回，超时视为系统无响应。 */
  private static readonly SUBMISSION_TIMEOUT_MS: number = 30 * 1000;
  /** 受理后等待首个进度回执的宽限：超时仍无任何回执则按“已提交”定稿（开关关闭即此表现）。
   * 取值偏保守：弱网/系统批量传输时首个回执可能晚到十几秒，过短会把“其实成功了”
   * 的会话误判为“已提交”。
   */
  private static readonly FIRST_PROGRESS_GRACE_MS: number = 15 * 1000;
  /** 已有进度回执但未见 FINISH 的会话上限：超时先按“已提交”定稿，迟到终态仍会覆盖。 */
  private static readonly SESSION_FINISH_CAP_MS: number = 10 * 60 * 1000;
  private static readonly LAST_SUCCESS_KEY: string = 'cloud_sync_last_success_at';
  private static readonly LAST_SESSION_KEY: string = 'cloud_sync_last_session';

  static initializeStorage(): void {
    AppStorage.setOrCreate(CloudSyncService.STORAGE_SUPPORTED, false);
    AppStorage.setOrCreate(CloudSyncService.STORAGE_LINKED, false);
    AppStorage.setOrCreate(CloudSyncService.STORAGE_STATUS, CloudSyncService.STATUS_IDLE);
    AppStorage.setOrCreate(CloudSyncService.STORAGE_LAST_SUCCESS_AT, 0);
    AppStorage.setOrCreate(CloudSyncService.STORAGE_MESSAGE, '');
    AppStorage.setOrCreate(CloudSyncService.STORAGE_REVISION, 0);
    AppStorage.setOrCreate(CloudSyncService.STORAGE_LAST_UPLOAD, 0);
    AppStorage.setOrCreate(CloudSyncService.STORAGE_LAST_DOWNLOAD, 0);
    AppStorage.setOrCreate(CloudSyncService.STORAGE_PENDING, false);
  }

  static async configure(store: relationalStore.RdbStore): Promise<void> {
    if (CloudSyncService.store === store && CloudSyncService.supported) {
      // 已对同一 store 成功注册过端云同步：重复 setDistributedTables 会与引擎
      // 进行中的任务冲突（如资产恢复期），把可用状态误翻成 UNSUPPORTED。
      // 首次注册失败（supported=false）时此处不拦截，保留重试能力。
      return;
    }
    CloudSyncService.initializeStorage();
    CloudSyncService.store = store;
    // 先恢复跨冷启动的“上次成功时间”，再设置状态，避免被 STATUS_IDLE 覆盖后丢失。
    await CloudSyncService.restorePersistedLastSuccessAt();
    await CloudSyncService.restorePersistedSession();
    try {
      // autoSync 必须为 true，理由见 DISTRIBUTED_AUTO_SYNC：置为 false 会把云空间里
      // 本应用的同步开关关掉，导致整轮 cloudSync 恒失败。
      const config: relationalStore.DistributedConfig = {
        autoSync: CloudSyncService.DISTRIBUTED_AUTO_SYNC
      };
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

  /**
   * 一次性云端优先同步（指定表），用于解除版本冲突死循环：此前轮次已把资产
   * 文件创建到云端并推高云端记录版本，而本地记录版本基线未跟上时，记录保存
   * 恒 409，上传永远无法定稿。必须先强制按云端覆盖本地拉取一轮刷新基线，
   * 后续上传才能落库。直连 store.cloudSync，不占会话簿记。
   * 注意：进度回调是 store 级的，任务被引擎侧 Abort（"another task is
   * running"）时不会收到通知，本方法 resolve(true) 只代表"见到了某个会话
   * 的终态"，不代表本任务真的执行过——调用方必须以数据行状态为准复验。
   * resolve：true=见到会话终态；false=提交被拒/超时未受理。
   */
  static requestCloudFirstHealAsync(tables: string[]): Promise<boolean> {
    return new Promise<boolean>((resolve: (finished: boolean) => void) => {
      const store = CloudSyncService.store;
      if (!store) {
        resolve(false);
        return;
      }
      let done = false;
      const finish = (finished: boolean): void => {
        if (!done) {
          done = true;
          resolve(finished);
        }
      };
      // 兜底：会话悬挂时也要放行（按未见终态处理）。
      setTimeout((): void => finish(false), 45 * 1000);
      try {
        store.cloudSync(relationalStore.SyncMode.SYNC_MODE_CLOUD_FIRST, tables,
          (progress: relationalStore.ProgressDetails): void => {
            if (progress.schedule === relationalStore.Progress.SYNC_FINISH) {
              hilog.info(0x0000, 'CloudSync', 'cloudFirstHeal session finished: code=%{public}d', progress.code);
              finish(true);
            }
          },
          (error: BusinessError): void => {
            if (!error) {
              hilog.info(0x0000, 'CloudSync', 'cloudFirstHeal submitted');
              return;
            }
            hilog.warn(0x0000, 'CloudSync', 'cloudFirstHeal submission failed: %{public}d %{public}s',
              error.code, error.message);
            finish(false);
          });
      } catch (error) {
        const err = error as BusinessError;
        hilog.warn(0x0000, 'CloudSync', 'cloudFirstHeal failed: %{public}d %{public}s', err.code, err.message);
        finish(false);
      }
    });
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
      cloudData.onAutoSyncTrigger((_info: cloudData.AutoSyncTriggerInfo): void => {
        CloudSyncService.requestAutoSync();
      });
      CloudSyncService.autoSyncTriggerRegistered = true;
    } catch (error) {
      const err = error as BusinessError;
      hilog.warn(0x0000, 'CloudSync', 'onAutoSyncTrigger failed: %{public}d %{public}s',
        err.code, err.message);
    }
  }

  /** 注册云同步会话终局监听。重复注册同一监听不会被去重，调用方自行保证只注册一次。 */
  static addSessionListener(listener: (outcome: CloudSyncOutcome) => void): void {
    CloudSyncService.sessionListeners.push(listener);
  }

  /** 通知所有会话监听者；单个监听者异常不影响其余监听与主流程。 */
  private static notifySessionListeners(outcome: CloudSyncOutcome): void {
    for (const listener of CloudSyncService.sessionListeners) {
      try {
        listener(outcome);
      } catch (error) {
        hilog.warn(0x0000, 'CloudSync', 'session listener failed: %{public}s', `${error}`);
      }
    }
  }

  /**
   * 汇报一次本地数据变更：标记待上传，并安排一次去抖补传。
   *
   * 只标记是不够的：系统自动同步的时机由系统控制、应用无法干预，若标记之后一直
   * 没有前后台切换、也没有云端变更通知，这轮变更可能被长期搁置（改了书签/书源
   * 却迟迟不上云，界面还显示“已同步”）。所以这里自己挂上补传定时器作为兜底。
   * 补传仍受去抖约束：定时器只挂一次，重复汇报不会提前也不会叠加，最密也就是
   * 每 AUTO_SYNC_MIN_INTERVAL_MS 一次，不会出现“每写一次库就同步一次”。
   */
  static notifyLocalChange(): void {
    CloudSyncService.markPendingChange();
    CloudSyncService.scheduleFollowUp();
  }

  /** 是否已有待上传的本地变更尚未同步。 */
  static hasPendingLocalChange(): boolean {
    return CloudSyncService.pendingSince > 0;
  }

  /** 置位待上传标记，同时让界面可见（界面据此区分“应用没感知改动”与“上传失败”）。 */
  private static markPendingChange(): void {
    if (CloudSyncService.pendingSince === 0) {
      CloudSyncService.pendingSince = Date.now();
      AppStorage.setOrCreate(CloudSyncService.STORAGE_PENDING, true);
    }
  }

  private static clearPendingChange(): void {
    CloudSyncService.pendingSince = 0;
    AppStorage.setOrCreate(CloudSyncService.STORAGE_PENDING, false);
  }

  /** 会话开始时取走标记：返回这批变更的时刻（0 表示本来就没有待上传变更）。 */
  private static takePendingChange(): number {
    const taken: number = CloudSyncService.pendingSince;
    CloudSyncService.clearPendingChange();
    return taken;
  }

  /** 会话明确失败时把取走的标记还回去，界面继续显示“有本地改动待上传”。 */
  private static restorePendingChange(at: number): void {
    if (at > 0 && CloudSyncService.pendingSince === 0) {
      CloudSyncService.pendingSince = at;
      AppStorage.setOrCreate(CloudSyncService.STORAGE_PENDING, true);
    }
  }

  /**
   * 去抖的自动同步入口：App 前后台切换与云端变更通知调用。
   * @param urgent 退后台时传 true：绕过 5 分钟去抖窗口，因为退后台后这可能是
   *               本轮最后一次上传机会（听书进度不会实时上云）。
   */
  static requestAutoSync(urgent: boolean = false): void {
    if (!CloudSyncService.supported) {
      // 能力尚未就绪（冷启动早期）：留待办，configure 成功后再补一次。
      CloudSyncService.markPendingChange();
      return;
    }
    const now = Date.now();
    // 只有 urgent 才绕过去抖。注意不能因为“有堆积变更”就绕过：阅读进度每几秒
    // 落一次库，待上传标记几乎恒为已置位，那等于取消去抖，会退化成“每写一次库
    // 就同步一次”的频繁同步。堆积变更改由 scheduleFollowUp 在下个去抖窗口补传。
    if (!urgent &&
      now - CloudSyncService.lastAutoSyncRequestAt < CloudSyncService.AUTO_SYNC_MIN_INTERVAL_MS) {
      // 去抖期内被丢弃的请求必须留待办：系统自动同步的时机不可控，不能指望它
      // 恰好覆盖这一次变更。
      CloudSyncService.markPendingChange();
      CloudSyncService.scheduleFollowUp();
      return;
    }
    if (CloudSyncService.pendingSync) {
      // 在飞：不重复发起，但同样留待办，避免这一轮变更被永久跳过。
      CloudSyncService.markPendingChange();
      CloudSyncService.scheduleFollowUp();
      return;
    }
    CloudSyncService.lastAutoSyncRequestAt = now;
    // 待上传标记由 syncNow 在会话开始时取走、在明确失败时还回，这里不再手工清理，
    // 否则会把“同步期间新写入的变更”一并清掉，补传定时器随后会跳过它们。
    CloudSyncService.syncNow().then((outcome: CloudSyncOutcome) => {
      hilog.info(0x0000, 'CloudSync',
        'auto sync done: status=%{public}s code=%{public}d pending=%{public}d',
        outcome.status, outcome.progressCode,
        CloudSyncService.hasPendingLocalChange() ? 1 : 0);
    }).catch((error: Error) => {
      // 真实异常单独成行，避免与“去抖跳过”混在一起难以定位。
      hilog.warn(0x0000, 'CloudSync', 'auto sync failed: %{public}s', error.message);
    });
  }

  /** 一轮同步结束后，若期间又有变更被标记待上传，安排一次补传。 */
  private static scheduleFollowUp(): void {
    if (!CloudSyncService.hasPendingLocalChange() || !CloudSyncService.supported) {
      return;
    }
    if (CloudSyncService.followUpTimer >= 0) {
      return;
    }
    CloudSyncService.followUpTimer = setTimeout(() => {
      CloudSyncService.followUpTimer = -1;
      if (CloudSyncService.hasPendingLocalChange()) {
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
   * 发起一次端云同步。
   *
   * cloudSync 的 AsyncCallback 只是“受理回执”：系统毫秒级返回 err=0 仅表示请求
   * 已受理，不代表同步完成；真实结果由进度回调送达，终态信号是
   * schedule=SYNC_FINISH（携带终态码）或非 SUCCESS 进度码。据此分四态：
   * 1. FINISH 且 SUCCESS → STATUS_SYNCED；
   * 2. 阻断性进度码（开关未开/超上限/空间不足/未知错误）或存在失败行 → STATUS_ERROR；
   * 3. 暂停态进度码（网络错误/其他设备占用/网络策略）→ STATUS_PAUSED，系统自动重试；
   * 4. 超时未见终态（云空间开关关闭时甚至没有任何进度回调）→ STATUS_SUBMITTED：
   *    只提示“已提交”，不声称成功；迟到的 FINISH 仍会重新定稿并覆盖结果。
   * 不做心跳探针之类的“成功性验证”：探针只能证明链路通、不能证明业务表成功，
   * 还会向云端写脏数据并引入长窗口定时器，性价比极低。
   */
  static async syncNow(): Promise<CloudSyncOutcome> {
    const store = CloudSyncService.store;
    if (!store || !CloudSyncService.supported) {
      return Promise.reject(new Error('当前设备不支持端云同步'));
    }
    const existing = CloudSyncService.acquireSlot();
    if (existing) {
      // 复用在飞任务，等待真实完成，避免并发调用拿到假的成功结果。
      return existing;
    }
    const taken: number = CloudSyncService.takePendingChange();
    const slot: Promise<CloudSyncOutcome> = CloudSyncService.runSyncSession();
    // 待上传标记的归属：会话开始时取走的这批变更，只在明确失败或暂停时还回。
    // SUBMITTED（结果未知）不还给——开关没开时那会变成每 5 分钟一次的无效重试。
    // PAUSED 时还回：暂停只代表系统稍后自动续传，本应用的补传定时器仍是兜底保障。
    const tracked: Promise<CloudSyncOutcome> = slot.then((outcome: CloudSyncOutcome) => {
      if (outcome.status === CloudSyncService.STATUS_ERROR ||
        outcome.status === CloudSyncService.STATUS_PAUSED) {
        CloudSyncService.restorePendingChange(taken);
      }
      return outcome;
    }, (error: Error): Promise<CloudSyncOutcome> => {
      CloudSyncService.restorePendingChange(taken);
      return Promise.reject(error);
    });
    CloudSyncService.pendingSync = tracked;
    CloudSyncService.pendingSyncStartedAt = Date.now();
    const release = (): void => {
      if (CloudSyncService.pendingSync === tracked) {
        CloudSyncService.pendingSync = null;
        CloudSyncService.pendingSyncStartedAt = 0;
      }
      CloudSyncService.scheduleFollowUp();
    };
    tracked.then(release, release);
    return tracked;
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

  /**
   * 单次同步会话。cloudSync 的 AsyncCallback 是受理回执（正常毫秒级返回），
   * 真实结果由进度回调给出：schedule=SYNC_FINISH 或非 SUCCESS 进度码即视为终态。
   * 超时未见终态时按“已提交”定稿并返回，但进度闭包保持存活，迟到的 FINISH 会
   * 重新定稿、覆盖 AppStorage 中的旧结果——第一次定稿决定 Promise 归宿，之后的
   * 定稿只刷新界面状态。
   */
  private static runSyncSession(): Promise<CloudSyncOutcome> {
    const store = CloudSyncService.store;
    if (!store) {
      const empty = new CloudSyncOutcome();
      empty.status = CloudSyncService.STATUS_ERROR;
      empty.message = '数据库尚未就绪';
      CloudSyncService.applyOutcome(empty);
      return Promise.reject(new Error(empty.message));
    }
    CloudSyncService.setStatus(CloudSyncService.STATUS_SYNCING, '');
    return new Promise<CloudSyncOutcome>((resolve, reject) => {
      let worstCode: number = -1;
      let worstMessage: string = '';
      let sawProgress: boolean = false;
      let sawFinish: boolean = false;
      // FINISH 已见：系统不应再回调，忽略迟到的杂散回执。
      let finished: boolean = false;
      // 会话是否已定稿：第一次定稿决定 Promise 归宿，之后的定稿只刷新界面。
      let settled: boolean = false;
      let graceTimer: number = -1;
      let capTimer: number = -1;
      // 每张表取最后一次进度回调的统计值：同一张表会多次回调，且中间值单调，
      // 直接覆盖即可；跨表汇总在定稿时进行。
      const tableStats: Map<string, TableSyncStats> = new Map<string, TableSyncStats>();

      const finalize = (): void => {
        if (graceTimer >= 0) {
          clearTimeout(graceTimer);
          graceTimer = -1;
        }
        if (capTimer >= 0) {
          clearTimeout(capTimer);
          capTimer = -1;
        }
        const outcome = CloudSyncService.finishSession(worstCode, worstMessage,
          CloudSyncService.countFailedRowsFrom(tableStats), sawProgress, sawFinish,
          CloudSyncService.aggregateTableStats(tableStats));
        CloudSyncService.applyOutcome(outcome);
        if (settled) {
          return;
        }
        settled = true;
        if (outcome.status === CloudSyncService.STATUS_ERROR) {
          reject(new Error(outcome.message));
        } else {
          resolve(outcome);
        }
      };

      const onProgress = (progress: relationalStore.ProgressDetails): void => {
        if (finished) {
          return;
        }
        sawProgress = true;
        CloudSyncService.captureTableStats(tableStats, progress);
        const message = CloudSyncService.progressMessage(progress);
        if (progress.schedule === relationalStore.Progress.SYNC_FINISH) {
          // FINISH 携带终态码：中途的非 SUCCESS 码可能是瞬时抖动，以终态为准。
          sawFinish = true;
          finished = true;
          worstCode = progress.code;
          worstMessage = message || worstMessage;
          finalize();
          return;
        }
        worstCode = CloudSyncService.worseProgressCode(worstCode, progress.code);
        worstMessage = message || worstMessage;
        if (progress.code !== relationalStore.ProgressCode.SUCCESS &&
          CloudSyncService.isBlockingProgressCode(progress.code)) {
          // 阻断性失败：立即定稿为 ERROR，迟到的 FINISH 仍可覆盖。
          finalize();
          return;
        }
        // 正常传输或暂停态（网络错误/被占用/网络策略等可自动恢复的场景）：
        // 会话保持等待，由会话上限兜底定稿为 PAUSED，迟到的 FINISH 仍可覆盖。
        // 正常传输中：首个回执到达后撤掉受理宽限，改挂会话上限。
        if (graceTimer >= 0) {
          clearTimeout(graceTimer);
          graceTimer = -1;
        }
        if (capTimer < 0) {
          capTimer = setTimeout((): void => {
            capTimer = -1;
            finalize();
          }, CloudSyncService.SESSION_FINISH_CAP_MS);
        }
        const live = CloudSyncService.progressText(progress) ||
          (progress.code !== relationalStore.ProgressCode.SUCCESS
            ? CloudSyncService.describeError(progress.code, message) : '');
        if (live) {
          CloudSyncService.setStatus(CloudSyncService.STATUS_SYNCING, live);
        }
      };

      const submission = new Promise<void>((resolveSubmission, rejectSubmission) => {
        // 受理等待上限：AsyncCallback 正常毫秒级返回，超时说明系统无响应。
        const submissionTimer: number = setTimeout((): void => {
          rejectSubmission(new Error('系统长时间未受理同步请求'));
        }, CloudSyncService.SUBMISSION_TIMEOUT_MS);
        try {
          store.cloudSync(relationalStore.SyncMode.SYNC_MODE_TIME_FIRST,
            CloudSyncService.SYNC_TABLES, onProgress,
            (error: BusinessError): void => {
              clearTimeout(submissionTimer);
              hilog.info(0x0000, 'CloudSync', 'cloudSync submitted: err=%{public}d',
                error ? error.code : 0);
              if (error) {
                rejectSubmission(new Error(CloudSyncService.describeError(error.code, error.message)));
                return;
              }
              resolveSubmission();
            });
        } catch (error) {
          clearTimeout(submissionTimer);
          const err = error as BusinessError;
          rejectSubmission(new Error(CloudSyncService.describeError(err.code, err.message)));
        }
      });

      submission.then((): void => {
        // 已受理但尚无任何进度回执：给首个回执一段宽限，超时按“已提交”定稿
        //（云空间开关关闭时正是这种表现），迟到的回执仍会重新定稿。
        if (settled || sawProgress) {
          return;
        }
        graceTimer = setTimeout((): void => {
          graceTimer = -1;
          finalize();
        }, CloudSyncService.FIRST_PROGRESS_GRACE_MS);
      }, (error: Error): void => {
        // 受理即失败（cloudSync 回调 err 非 0 / 抛异常 / 超时无响应）。
        if (settled) {
          return;
        }
        settled = true;
        const failed = new CloudSyncOutcome();
        failed.status = CloudSyncService.STATUS_ERROR;
        failed.progressCode = worstCode;
        failed.failedRows = CloudSyncService.countFailedRowsFrom(tableStats);
        failed.message = CloudSyncService.errorText(error) || '同步失败';
        CloudSyncService.applyOutcome(failed);
        reject(new Error(failed.message));
      });
    });
  }

  /**
   * 从进度回调里记录各表最新的传输统计；同一张表后到的回调覆盖先到的。
   * 这里必须逐字段做空值兜底：不同系统版本回调上来的 details 结构不完整
   * （见过只有 upload 没有 download 的表），直接在回调里取 .total 会抛异常，
   * 而进度回调里抛异常会连带打断整个同步会话。
   */
  private static captureTableStats(tableStats: Map<string, TableSyncStats>,
    progress: relationalStore.ProgressDetails): void {
    const details = progress.details;
    if (!details) {
      return;
    }
    const tables = Object.keys(details);
    for (const table of tables) {
      const tableDetails = details[table];
      if (!tableDetails) {
        continue;
      }
      // 必须兜住异常：不同系统版本回调上来的 details 结构可能不完整（只有 upload
      // 没有 download 之类），取属性会抛异常；而进度回调里抛出的异常会连带打断
      // 整个同步会话，表现就是“同步莫名其妙失败”。
      try {
        tableStats.set(table, {
          uploadTotal: tableDetails.upload.total,
          uploadRemained: tableDetails.upload.remained,
          uploadFailed: tableDetails.upload.failed,
          downloadTotal: tableDetails.download.total,
          downloadRemained: tableDetails.download.remained,
          downloadFailed: tableDetails.download.failed
        });
      } catch (error) {
        const err = error as BusinessError;
        hilog.warn(0x0000, 'CloudSync', 'capture stats failed: %{public}s %{public}d %{public}s',
          table, err.code, err.message);
      }
    }
  }

  /** 跨表汇总传输统计，用于终局展示与持久化。 */
  private static aggregateTableStats(tableStats: Map<string, TableSyncStats>): TableSyncStats {
    const summary: TableSyncStats = {
      uploadTotal: 0,
      uploadRemained: 0,
      uploadFailed: 0,
      downloadTotal: 0,
      downloadRemained: 0,
      downloadFailed: 0
    };
    tableStats.forEach((stats: TableSyncStats): void => {
      summary.uploadTotal += stats.uploadTotal;
      summary.uploadRemained += stats.uploadRemained;
      summary.uploadFailed += stats.uploadFailed;
      summary.downloadTotal += stats.downloadTotal;
      summary.downloadRemained += stats.downloadRemained;
      summary.downloadFailed += stats.downloadFailed;
    });
    return summary;
  }

  /**
   * 会话定稿时的终局判定。终态信号优先级从高到低：
   * 1. 阻断性进度码（含 FINISH 携带的失败码）→ STATUS_ERROR；
   * 2. 存在失败行 → STATUS_ERROR；
   * 3. 见过 FINISH 且无失败 → STATUS_SYNCED（仅凭中间回执不足以判成功）；
   * 4. 最坏码为暂停态（网络错误/被占用/网络策略等）→ STATUS_PAUSED，
   *    条件恢复后系统自动重试，不视为失败、不清空云链路标记；
   * 5. 有进度回执但超时未见 FINISH → STATUS_SUBMITTED（后台可能仍在传输）；
   * 6. 一次进度回执都没有 → STATUS_SUBMITTED（云空间开关关闭时的典型表现）。
   */
  private static finishSession(worstCode: number, worstMessage: string,
    failedRows: number, sawProgress: boolean, sawFinish: boolean,
    stats: TableSyncStats): CloudSyncOutcome {
    const outcome = new CloudSyncOutcome();
    outcome.progressCode = worstCode;
    outcome.failedRows = failedRows;
    outcome.uploadTotal = stats.uploadTotal;
    outcome.uploadDone = stats.uploadTotal - stats.uploadRemained;
    outcome.downloadTotal = stats.downloadTotal;
    outcome.downloadDone = stats.downloadTotal - stats.downloadRemained;

    // 阻断性码优先：系统明确上报的失败结果，直接判失败。
    if (worstCode >= 0 && worstCode !== relationalStore.ProgressCode.SUCCESS &&
      CloudSyncService.isBlockingProgressCode(worstCode)) {
      outcome.status = CloudSyncService.STATUS_ERROR;
      outcome.message = CloudSyncService.describeProgress(worstCode, worstMessage);
      return outcome;
    }
    if (failedRows > 0) {
      outcome.status = CloudSyncService.STATUS_ERROR;
      outcome.message = `有 ${failedRows} 条数据未能同步，请稍后重试`;
      return outcome;
    }
    if (worstCode >= 0 && worstCode !== relationalStore.ProgressCode.SUCCESS) {
      // 暂停态：不是失败，系统会在网络恢复/云端可用后自动续传。
      outcome.status = CloudSyncService.STATUS_PAUSED;
      outcome.message = CloudSyncService.describeProgress(worstCode, worstMessage);
      return outcome;
    }
    if (sawFinish) {
      // 系统上报过 FINISH 且全部 SUCCESS，是端云链路可用的确定性证据。
      outcome.status = CloudSyncService.STATUS_SYNCED;
      if (outcome.uploadTotal === 0 && outcome.downloadTotal === 0) {
        outcome.message = '云端与本机数据一致，本次无数据传输';
      }
      return outcome;
    }
    if (sawProgress) {
      outcome.status = CloudSyncService.STATUS_SUBMITTED;
      outcome.message = '同步仍在后台进行，暂未收到完成回执，请稍后重试或前往“设置-云空间”确认';
      return outcome;
    }

    // 一次进度回执都没有：云空间开关关闭、系统静默排队/批量传输期都可能如此。
    // 应用无法确认结果，既不判成功也不判失败，交给用户去云空间自行确认。
    outcome.status = CloudSyncService.STATUS_SUBMITTED;
    outcome.message = '同步请求已提交，应用无法确认结果，请前往“设置-云空间”查看';
    return outcome;
  }

  /** 把终局结果落到 AppStorage：只有确认成功才刷新“上次成功时间”。 */
  private static applyOutcome(outcome: CloudSyncOutcome): void {
    if (outcome.status === CloudSyncService.STATUS_SYNCED) {
      AppStorage.setOrCreate(CloudSyncService.STORAGE_LINKED, true);
    } else if (outcome.status === CloudSyncService.STATUS_ERROR) {
      AppStorage.setOrCreate(CloudSyncService.STORAGE_LINKED, false);
    }
    // STATUS_SUBMITTED 不改变云链路标记：既未确认连通，也未确认失败。同理，结果
    // 未知的会话不能用 0 覆盖上一轮的传输行数——那会把“上次确实传了多少行”这个
    // 唯一可诊断的证据抹掉，界面也会退化成“云端与本机一致，本次无数据传输”。
    if (outcome.status !== CloudSyncService.STATUS_SUBMITTED) {
      AppStorage.setOrCreate(CloudSyncService.STORAGE_LAST_UPLOAD, outcome.uploadDone);
      AppStorage.setOrCreate(CloudSyncService.STORAGE_LAST_DOWNLOAD, outcome.downloadDone);
      CloudSyncService.persistLastSession(outcome);
    }
    hilog.info(0x0000, 'CloudSync',
      'session done: status=%{public}s upload=%{public}d/%{public}d download=%{public}d/%{public}d failed=%{public}d',
      outcome.status, outcome.uploadDone, outcome.uploadTotal,
      outcome.downloadDone, outcome.downloadTotal, outcome.failedRows);
    CloudSyncService.setStatus(outcome.status, outcome.message);
    CloudSyncService.notifySessionListeners(outcome);
  }

  /** 最近一次会话的传输行数落到 device_meta，跨冷启动保留，供界面展示。 */
  private static persistLastSession(outcome: CloudSyncOutcome): void {
    const store = CloudSyncService.store;
    if (!store) {
      return;
    }
    const summary: Record<string, number> = {
      uploaded: outcome.uploadDone,
      downloaded: outcome.downloadDone,
      failed: outcome.failedRows,
      finishedAt: Date.now()
    };
    store.executeSql('INSERT OR REPLACE INTO device_meta (key, value) VALUES (?, ?)',
      [CloudSyncService.LAST_SESSION_KEY, JSON.stringify(summary)]).catch((error: BusinessError) => {
      hilog.warn(0x0000, 'CloudSync', 'persist last session failed: %{public}d %{public}s',
        error.code, error.message);
    });
  }

  /** 数据库就绪后补读持久化的上次会话统计。 */
  private static restorePersistedSession(): Promise<void> {
    const store = CloudSyncService.store;
    if (!store) {
      return Promise.resolve();
    }
    return store.querySql('SELECT value FROM device_meta WHERE key = ?',
      [CloudSyncService.LAST_SESSION_KEY]).then((resultSet) => {
      try {
        if (resultSet.goToFirstRow()) {
          const raw = resultSet.getString(resultSet.getColumnIndex('value'));
          const parsed = JSON.parse(raw) as Record<string, number>;
          if (parsed && typeof parsed === 'object') {
            const uploaded = Number(parsed['uploaded']) || 0;
            const downloaded = Number(parsed['downloaded']) || 0;
            AppStorage.setOrCreate(CloudSyncService.STORAGE_LAST_UPLOAD, uploaded);
            AppStorage.setOrCreate(CloudSyncService.STORAGE_LAST_DOWNLOAD, downloaded);
          }
        }
      } finally {
        resultSet.close();
      }
    }).catch((error: BusinessError) => {
      hilog.warn(0x0000, 'CloudSync', 'restore last session failed: %{public}d %{public}s',
        error.code, error.message);
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
      'bookmarks': ['bookmarkUrl', 'bookUrl', 'bookName', 'bookAuthor',
        'chapterName', 'content'],
      'app_preferences': ['prefValue'],
      // ASSET 列（file）的二进制不落 SQL 表（在分布式文件区），SQL 侧只统计 assetKey
      // 本身，图片本体的占用见端云资产实际存储，不在此列。
      'theme_assets': ['assetKey']
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
    }
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

  /**
   * 是否为阻断性进度码：系统明确上报的失败结果，不可自动恢复，应定稿为 ERROR。
   * 其余非 SUCCESS 码（NETWORK_ERROR/LOCKED_BY_OTHERS/BLOCKED_BY_NETWORK_STRATEGY/
   * STOP_CLOUD_SYNC）都是暂停态，条件恢复后系统会自动重试。
   */
  private static isBlockingProgressCode(code: number): boolean {
    return code === relationalStore.ProgressCode.UNKNOWN_ERROR ||
      code === relationalStore.ProgressCode.CLOUD_DISABLED ||
      code === relationalStore.ProgressCode.RECORD_LIMIT_EXCEEDED ||
      code === relationalStore.ProgressCode.NO_SPACE_FOR_ASSET;
  }

  /**
   * 取两个进度码中更坏的一个。一次同步会对多张表分别回调，只看最后一次会漏掉
   * “某张表失败、其它表成功”的混合场景。-1 表示尚未收到任何回调。
   * 阻断性码优先级最高，不能被后续的 SUCCESS 或暂停码覆盖。
   */
  private static worseProgressCode(current: number, incoming: number): number {
    if (current < 0) {
      return incoming;
    }
    if (incoming < 0) {
      return current;
    }
    if (CloudSyncService.isBlockingProgressCode(current)) {
      return current;
    }
    if (CloudSyncService.isBlockingProgressCode(incoming)) {
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

  /** 从各表最后一次统计快照汇总失败行数，避免逐次进度回调累加造成重复计数。 */
  private static countFailedRowsFrom(tableStats: Map<string, TableSyncStats>): number {
    let failed: number = 0;
    tableStats.forEach((stats: TableSyncStats): void => {
      failed += stats.uploadFailed + stats.downloadFailed;
    });
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
      // 同上，结构不完整时按 0 处理，不能让异常冒出进度回调。
      try {
        uploadTotal += tableDetails.upload.total;
        uploadRemained += tableDetails.upload.remained;
        downloadTotal += tableDetails.download.total;
        downloadRemained += tableDetails.download.remained;
      } catch (error) {
        const err = error as BusinessError;
        hilog.warn(0x0000, 'CloudSync', 'progress text failed: %{public}s %{public}d %{public}s',
          table, err.code, err.message);
      }
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
    if (status === CloudSyncService.STATUS_PAUSED) {
      return '同步暂停，将自动重试';
    }
    if (status === CloudSyncService.STATUS_SUBMITTED) {
      return '已提交，请到云空间确认';
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
      const hint = '同步遇到未知错误，请确认已登录华为账号并开启云空间同步开关后重试';
      return rawMessage ? `${hint}（${rawMessage}）` : hint;
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
