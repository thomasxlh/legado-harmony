import { BookSource } from '../../model/data/Book';

/** acquire 的结果：正常拿到令牌 / 等待期间被取消 / 达到等待上限仍被限流。 */
export enum RateLimitAcquireResult {
  Acquired = 0,
  Cancelled = 1,
  RateLimited = 2
}

export interface RateLimitAcquireHooks {
  /** 累计等待上限（毫秒）；超过后放弃并返回 RateLimited，
   *  避免 worker 被极端限流配置（如 1/3600000）长期占住。 */
  maxWaitMs?: number;
  /** 进入/离开阻塞等待时回调；供上层把限流排队时间排除在网络超时预算之外。 */
  onWaitingChange?: (waiting: boolean) => void;
}

class BookSourceRateState {
  timestamps: number[] = [];
}

export class BookSourceRateLimiter {
  private static states: Record<string, BookSourceRateState> = {};

  /** Acquire a rate limiter slot before executing a source request.
   *  @param isCancelled optional callback; when it returns true the wait exits immediately
   *  without consuming a slot. Used by SearchCoordinator to release orphaned workers early
   *  after cancel() instead of letting them wait the full rate window (up to 60 min config).
   *  @param hooks optional waiting caps and wait-state callbacks used by search to keep
   *  rate-limit queueing out of the per-source network timeout budget. */
  static async acquire(source: BookSource | null, isCancelled?: () => boolean,
    hooks?: RateLimitAcquireHooks): Promise<RateLimitAcquireResult> {
    if (!source || !source.concurrentRate) return RateLimitAcquireResult.Acquired;
    if (isCancelled && isCancelled()) return RateLimitAcquireResult.Cancelled;
    const config = this.parse(source.concurrentRate);
    if (!config) return RateLimitAcquireResult.Acquired;
    const key = source.bookSourceUrl || source.bookSourceName;
    if (!key) return RateLimitAcquireResult.Acquired;
    let state = this.states[key];
    if (!state) {
      state = new BookSourceRateState();
      this.states[key] = state;
    }
    let waitingNotified = false;
    let waitDeadline = 0;
    try {
      while (true) {
        if (isCancelled && isCancelled()) return RateLimitAcquireResult.Cancelled;
        const now = Date.now();
        state.timestamps = state.timestamps.filter(timestamp => now - timestamp < config.windowMs);
        if (state.timestamps.length < config.limit) {
          state.timestamps.push(now);
          return RateLimitAcquireResult.Acquired;
        }
        if (!waitingNotified) {
          waitingNotified = true;
          waitDeadline = hooks && hooks.maxWaitMs ? Date.now() + hooks.maxWaitMs : 0;
          if (hooks && hooks.onWaitingChange) hooks.onWaitingChange(true);
        }
        let waitMs = Math.max(1, state.timestamps[0] + config.windowMs - Date.now());
        if (waitDeadline > 0) {
          const capRemaining = waitDeadline - Date.now();
          if (capRemaining <= 0) return RateLimitAcquireResult.RateLimited;
          waitMs = Math.min(waitMs, capRemaining);
        }
        await this.delay(waitMs);
      }
    } finally {
      if (waitingNotified && hooks && hooks.onWaitingChange) hooks.onWaitingChange(false);
    }
  }

  private static parse(value: string): { limit: number; windowMs: number } | null {
    const match = (value || '').match(/^\s*(\d+)\s*\/\s*(\d+)\s*$/);
    if (!match) return null;
    const limit = Math.min(1000, Math.max(1, parseInt(match[1])));
    const windowMs = Math.min(60 * 60 * 1000, Math.max(100, parseInt(match[2])));
    return { limit: limit, windowMs: windowMs };
  }

  private static delay(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(resolve, ms);
    });
  }
}
