export class TtsFocusLatencyMonitor {
  private static readonly SAMPLE_LIMIT: number = 30;
  private static readonly DEGRADED_MEDIAN_MS: number = 350;
  private static readonly MIN_SESSION_AGE_MS: number = 10 * 60 * 1000;
  private static readonly RETRIGGER_COOLDOWN_MS: number = 30 * 60 * 1000;

  private samples: number[] = [];
  private sessionStartedAt: number = 0;
  private lastTriggeredAt: number = 0;

  reset(): void {
    this.samples = [];
    this.sessionStartedAt = 0;
    this.lastTriggeredAt = 0;
  }

  record(elapsedMs: number): boolean {
    if (this.sessionStartedAt === 0) {
      this.sessionStartedAt = Date.now();
    }
    this.samples.push(elapsedMs);
    if (this.samples.length > TtsFocusLatencyMonitor.SAMPLE_LIMIT) {
      this.samples.shift();
    }
    if (this.samples.length < TtsFocusLatencyMonitor.SAMPLE_LIMIT ||
      Date.now() - this.sessionStartedAt < TtsFocusLatencyMonitor.MIN_SESSION_AGE_MS) {
      return false;
    }
    const now = Date.now();
    if (now - this.lastTriggeredAt < TtsFocusLatencyMonitor.RETRIGGER_COOLDOWN_MS) {
      return false;
    }
    if (this.median() < TtsFocusLatencyMonitor.DEGRADED_MEDIAN_MS) {
      return false;
    }
    this.lastTriggeredAt = now;
    return true;
  }

  median(): number {
    if (this.samples.length === 0) {
      return 0;
    }
    const sorted = this.samples.slice().sort((a: number, b: number): number => a - b);
    return sorted[Math.floor(sorted.length / 2)];
  }
}
