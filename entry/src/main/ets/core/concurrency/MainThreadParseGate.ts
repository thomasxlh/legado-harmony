/**
 * 进程级主线程 CPU 解析准入闸门。
 *
 * 背景：书源搜索的网络/Worker 并发可达上百路（在飞 HTTP 上限 128），但规则解析
 * （AnalyzeRule 正则/CSS/JSONPath、QuickJS 求值）全部在唯一的 JS 主线程执行。弱网下
 * 响应突发到达时，几十个解析流水线同时进入可运行状态：每条流水线虽然都有 setTimeout
 * 协作让步，但原生事件循环会把"所有已到期的 timer"合并进同一个 uv_timer_task 连续
 * 执行微任务链，前台看门狗观察不到空闲空档，最终触发 THREAD_BLOCK_3S/6S（appfreeze）。
 *
 * 本闸门把"网络并发"与"主线程解析并发"解耦：
 * - 同时只放行固定数量的解析流水线，其余在 FIFO 队列中挂起（不进入原生 timer 堆，
 *   也就不会参与 timer 合并）；
 * - 许可交接强制延迟一个 UI 帧，且每帧最多放行一个流水线，保证任意两个解析批次之间
 *   必然存在原生任务空档，vsync/输入/IO 回调在空档被处理，看门狗计时得以复位；
 * - 排队期间通过 cancelCheck 支持放弃，搜索取消后不会长期滞留许可。
 *
 * 许可只包裹 CPU 解析段（列表抽取 + 字段批量解析 + 结果装配），不包裹网络请求等待。
 */
const DEFAULT_PARSE_CONCURRENCY: number = 3;
/** 许可交接的帧间隔：与 CooperativeScheduler.yieldToNextUiFrame 的 16ms 对齐。 */
const GRANT_FRAME_GAP_MS: number = 16;

interface ParseGateWaiter {
  resolve: (granted: boolean) => void;
  cancelCheck?: () => boolean;
}

export class MainThreadParseGate {
  private static instance: MainThreadParseGate | null = null;
  private available: number;
  private waiters: ParseGateWaiter[] = [];
  private grantTimerId: number = -1;

  static get(): MainThreadParseGate {
    if (!MainThreadParseGate.instance) {
      MainThreadParseGate.instance = new MainThreadParseGate(DEFAULT_PARSE_CONCURRENCY);
    }
    return MainThreadParseGate.instance;
  }

  constructor(permits: number) {
    this.available = Math.max(1, Math.floor(permits));
  }

  /**
   * 获取解析许可。
   * @param cancelCheck 排队期间被取消则放弃等待，返回 false（此时调用方不得 release）；
   *                    已拿到许可后才取消仍返回 true，由调用方在 finally 中 release。
   */
  async acquire(cancelCheck?: () => boolean): Promise<boolean> {
    // 队列为空且有空闲许可时立即放行，避免单源场景平白多等一帧。
    if (this.available > 0 && this.waiters.length === 0) {
      this.available--;
      return true;
    }
    return await new Promise<boolean>((resolve): void => {
      this.waiters.push({ resolve: resolve, cancelCheck: cancelCheck });
    });
  }

  release(): void {
    this.available++;
    this.schedulePump();
  }

  /** 当前排队等待解析许可的流水线数（诊断用）。 */
  get queueDepth(): number {
    return this.waiters.length;
  }

  private schedulePump(): void {
    if (this.grantTimerId >= 0) return;
    if (this.available <= 0 || this.waiters.length === 0) return;
    // 延迟到下一帧再交接许可：在当前批次与下一批次之间制造看门狗可观察的原生空档。
    this.grantTimerId = setTimeout((): void => {
      this.grantTimerId = -1;
      this.pumpOne();
      // 仍有空闲许可与排队者时继续按帧错峰放行，避免多条流水线同一帧内同时启动。
      this.schedulePump();
    }, GRANT_FRAME_GAP_MS);
  }

  private pumpOne(): void {
    while (this.available > 0 && this.waiters.length > 0) {
      const waiter = this.waiters.shift() as ParseGateWaiter;
      if (waiter.cancelCheck && waiter.cancelCheck()) {
        // 排队期间已取消：不消耗许可，继续考察下一个排队者。
        waiter.resolve(false);
        continue;
      }
      this.available--;
      waiter.resolve(true);
      break;
    }
  }
}
