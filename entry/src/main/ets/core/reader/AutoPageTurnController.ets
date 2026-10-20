export interface AutoPageTurnOptions {
  intervalMs: number;
  isBlocked: () => boolean;
  onTurn: () => void;
  onTick: (remainingMs: number, intervalMs: number, userPaused: boolean) => void;
}

export class AutoPageTurnController {
  private static readonly TICK_MS: number = 100;
  private tickTimerId: number = -1;
  private intervalMs: number = 0;
  private remainingMs: number = 0;
  private userPaused: boolean = false;
  private options: AutoPageTurnOptions | null = null;

  configure(options: AutoPageTurnOptions): void {
    this.options = options;
  }

  start(intervalMs: number): void {
    this.stop();
    if (!this.options || !(intervalMs > 0)) {
      return;
    }
    this.intervalMs = Math.round(intervalMs);
    this.remainingMs = this.intervalMs;
    this.userPaused = false;
    this.tickTimerId = setInterval(() => {
      this.handleTick();
    }, AutoPageTurnController.TICK_MS);
    this.reportTick();
  }

  stop(): void {
    if (this.tickTimerId >= 0) {
      clearInterval(this.tickTimerId);
      this.tickTimerId = -1;
    }
    this.userPaused = false;
    this.remainingMs = 0;
  }

  reset(): void {
    if (this.tickTimerId < 0) {
      return;
    }
    this.remainingMs = this.intervalMs;
    this.reportTick();
  }

  setIntervalMs(intervalMs: number): void {
    if (!this.options || !(intervalMs > 0)) {
      return;
    }
    this.intervalMs = Math.round(intervalMs);
    if (this.tickTimerId >= 0) {
      this.remainingMs = this.intervalMs;
      this.reportTick();
    }
  }

  toggleUserPause(): void {
    if (this.tickTimerId < 0) {
      return;
    }
    this.userPaused = !this.userPaused;
    this.reportTick();
  }

  isRunning(): boolean {
    return this.tickTimerId >= 0;
  }

  isUserPaused(): boolean {
    return this.userPaused;
  }

  private handleTick(): void {
    if (!this.options || this.tickTimerId < 0) {
      return;
    }
    if (this.userPaused) {
      this.reportTick();
      return;
    }
    if (this.options.isBlocked()) {
      this.reportTick();
      return;
    }
    if (this.remainingMs <= 0) {
      this.options.onTurn();
      this.reportTick();
      return;
    }
    this.remainingMs = Math.max(0, this.remainingMs - AutoPageTurnController.TICK_MS);
    if (this.remainingMs <= 0) {
      this.options.onTurn();
    }
    this.reportTick();
  }

  private reportTick(): void {
    if (this.options) {
      this.options.onTick(this.remainingMs, this.intervalMs, this.userPaused);
    }
  }
}
