/**
 * 轻量 FIFO 异步信号量：限制同时进入网络临界区的异步任务数。
 * 与"worker 数"（URL 解析/规则执行并发）解耦——排队等许可时不占线程，
 * 仅在真正发起 HTTP 请求前获取，响应返回（或失败/取消）后释放。
 */
export class AsyncSemaphore {
  private available: number;
  private waiters: SemaphoreWaiter[] = [];

  constructor(maxPermits: number) {
    this.available = Math.max(1, Math.floor(maxPermits));
  }

  /**
   * 获取一个许可。
   * @param cancelCheck 排队期间被取消则放弃等待，返回 false（调用方不得 release）；
   *                    已拿到许可后才被取消仍返回 true，由调用方在 finally 中 release。
   */
  async acquire(cancelCheck?: () => boolean): Promise<boolean> {
    if (this.available > 0) {
      this.available--;
      return true;
    }
    return await new Promise<boolean>((resolve): void => {
      const waiter: SemaphoreWaiter = {
        cancelCheck: cancelCheck,
        resolve: resolve
      };
      this.waiters.push(waiter);
    });
  }

  release(): void {
    this.available++;
    this.pump();
  }

  /** 取消信号：唤醒所有排队者，由它们各自的 cancelCheck 决定放弃还是继续，
   *  避免搜索取消后请求仍在信号量队列里滞留。 */
  cancelAllWaiters(): void {
    const pending = this.waiters;
    this.waiters = [];
    for (const waiter of pending) {
      waiter.resolve(false);
    }
  }

  private pump(): void {
    while (this.available > 0 && this.waiters.length > 0) {
      const waiter = this.waiters.shift() as SemaphoreWaiter;
      if (waiter.cancelCheck && waiter.cancelCheck()) {
        waiter.resolve(false);
        continue;
      }
      this.available--;
      waiter.resolve(true);
    }
  }
}

interface SemaphoreWaiter {
  cancelCheck?: () => boolean;
  resolve: (acquired: boolean) => void;
}
