import { avSession } from '@kit.AVSessionKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { common, WantAgent, wantAgent } from '@kit.AbilityKit';
import image from '@ohos.multimedia.image';
import fs from '@ohos.file.fs';
import { Book } from '../model/data/Book';
import { SystemTtsReader } from '../utils/SystemTtsReader';
import { HdsFeedback } from '../utils/HdsFeedback';
import { BookCoverCache } from '../utils/BookCoverCache';

/**
 * 阅读页宿主能力接口：ReaderTtsBackgroundController 通过它读写页面状态、
 * 回调朗读命令。接口方法逐个显式声明，宿主（ReadBookPage struct）implements 实现。
 */
export interface ReaderTtsBackgroundHost {
  hostContext(): common.Context;
  getReaderBook(): Book | null;
  getReaderBookUrl(): string;
  getCurrentChapterIndex(): number;
  getCurrentPageIndex(): number;
  setCurrentPageIndex(value: number): void;
  setPendingRestorePageIndex(value: number): void;
  getContentPageCount(): number;
  getTtsReader(): SystemTtsReader;
  isTtsSpeakingState(): boolean;
  isTtsPausedState(): boolean;
  getTtsSpeed(): number;
  getTtsCharCountSource(): string;
  getChapterTitle(chapterIndex?: number): string;
  getProgressText(): string;
  getBookshelfDisplayCoverRaw(): string;
  isFullTextCaching(): boolean;
  isFullTextCacheBackgroundRunning(): boolean;
  setFullTextCacheBackgroundRunning(value: boolean): void;
  isTtsChapterSwitching(): boolean;
  setTtsChapterSwitching(value: boolean): void;
  getTtsLastMediaChapterCommandAt(): number;
  setTtsLastMediaChapterCommandAt(value: number): void;
  ownsTtsFloatingSession(): boolean;
  isTtsSessionManuallyPaused(): boolean;
  canPlayNextTtsChapter(): boolean;
  canPlayPreviousTtsChapter(): boolean;
  toggleTtsReading(): Promise<void>;
  startTtsReadingFromCurrentPosition(showToast: boolean, manualPageTurnResume?: boolean,
    manualPageTurnResumeSerial?: number, readingStartOffset?: number,
    preserveExistingFocus?: boolean): Promise<void>;
  stopTtsReading(userCancelled?: boolean): void;
  applyTtsSpeed(value: number): void;
  stopTtsReaderForChapterSwitch(): void;
  prepareTtsForManualPageTurn(): void;
  scheduleTtsResumeAfterManualPageTurn(): void;
  clearTtsContinuationWatchdog(): void;
  loadContent(silent?: boolean, targetChapterIndex?: number, preferImmediatePagination?: boolean): Promise<boolean>;
  saveReadingProgress(notifyShelf?: boolean): Promise<void>;
  syncCurrentPageText(): void;
}

/**
 * 朗读后台任务 + AVSession（系统媒体控制）控制器。
 * 从 ReadBook.ets 原样搬迁：后台长时任务启停、心跳保活、AVSession 生命周期、
 * 媒体元数据/封面/进度、锁屏媒体命令（播放/暂停/上一章/下一章/倍速）。
 * 页面保留同名薄委托方法，内部调用点不变。
 */
export class ReaderTtsBackgroundController {
  private readonly host: ReaderTtsBackgroundHost;
  private ttsBackgroundRunning: boolean = false;
  private ttsBackgroundRequesting: boolean = false;
  private ttsBackgroundDesired: boolean = false;
  private ttsBackgroundHeartbeatId: number = -1;
  private ttsBackgroundLastLogAt: number = 0;
  private ttsAvSession: avSession.AVSession | null = null;
  private ttsAvSessionRequesting: boolean = false;
  private ttsMediaImageRefreshSerial: number = 0;
  private ttsMediaImage: string = '';
  private ttsMediaImageRaw: string = '';
  private ttsMediaPixelMap: image.PixelMap | null = null;

  constructor(host: ReaderTtsBackgroundHost) {
    this.host = host;
  }

  isTtsBackgroundRunning(): boolean {
    return this.ttsBackgroundRunning;
  }

  isTtsBackgroundRequesting(): boolean {
    return this.ttsBackgroundRequesting;
  }

  hasTtsAvSession(): boolean {
    return this.ttsAvSession !== null;
  }

  async startTtsBackgroundRunning(): Promise<boolean> {
    this.ttsBackgroundDesired = true;
    if (this.ttsBackgroundRunning) {
      if (!this.ttsAvSession && !this.ttsAvSessionRequesting) {
        const agent = await this.createTtsBackgroundWantAgent();
        await this.startTtsAvSession(agent);
      }
      await this.updateTtsAvSessionPlaybackState(this.ttsAvPlaybackState());
      this.startTtsBackgroundHeartbeat();
      return !!this.ttsAvSession;
    }
    if (this.ttsBackgroundRequesting) {
      return this.ttsBackgroundRunning;
    }
    this.ttsBackgroundRequesting = true;
    try {
      const agent = await this.createTtsBackgroundWantAgent();
      await this.startTtsAvSession(agent);
      await backgroundTaskManager.startBackgroundRunning(
        this.host.hostContext(),
        ['audioPlayback'],
        agent
      );
      if (this.ttsBackgroundDesired) {
        this.ttsBackgroundRunning = true;
        this.startTtsBackgroundHeartbeat();
        console.info(`[TTS-BG] background audio task started: ${this.ttsBackgroundDebugState()}`);
      } else {
        await backgroundTaskManager.stopBackgroundRunning(this.host.hostContext());
        await this.stopTtsAvSession();
      }
      return this.ttsBackgroundRunning;
    } catch (error) {
      this.ttsBackgroundRunning = false;
      this.stopTtsBackgroundHeartbeat();
      console.warn(`[TTS-BG] start background audio task failed: ${this.formatTtsBackgroundError(error as Object)}; ${this.ttsBackgroundDebugState()}`, error);
      return false;
    } finally {
      this.ttsBackgroundRequesting = false;
    }
  }

  async stopTtsBackgroundRunning(): Promise<void> {
    this.ttsBackgroundDesired = false;
    this.stopTtsBackgroundHeartbeat();
    await this.stopTtsAvSession();
    if (!this.ttsBackgroundRunning && !this.ttsBackgroundRequesting) {
      return;
    }
    if (this.ttsBackgroundRequesting && !this.ttsBackgroundRunning) {
      return;
    }
    this.ttsBackgroundRunning = false;
    if (this.host.isFullTextCaching()) {
      this.host.setFullTextCacheBackgroundRunning(true);
      return;
    }
    if (this.host.isFullTextCacheBackgroundRunning()) {
      return;
    }
    try {
      await backgroundTaskManager.stopBackgroundRunning(this.host.hostContext());
      console.info(`[TTS-BG] background audio task stopped: ${this.ttsBackgroundDebugState()}`);
    } catch (error) {
      console.warn(`[TTS-BG] stop background audio task failed: ${this.formatTtsBackgroundError(error as Object)}; ${this.ttsBackgroundDebugState()}`, error);
    }
  }

  private startTtsBackgroundHeartbeat(): void {
    if (this.ttsBackgroundHeartbeatId >= 0) {
      return;
    }
    this.ttsBackgroundHeartbeatId = setInterval(() => {
      this.keepTtsBackgroundAlive().catch((error: Error) => {
        console.warn(`[TTS-BG] heartbeat failed: ${this.formatTtsBackgroundError(error as Object)}; ${this.ttsBackgroundDebugState()}`, error);
      });
    }, 30000);
  }

  private stopTtsBackgroundHeartbeat(): void {
    if (this.ttsBackgroundHeartbeatId < 0) {
      return;
    }
    clearInterval(this.ttsBackgroundHeartbeatId);
    this.ttsBackgroundHeartbeatId = -1;
  }

  private async keepTtsBackgroundAlive(): Promise<void> {
    const host = this.host;
    if (!this.ttsBackgroundDesired || (!host.isTtsSpeakingState() && !host.getTtsReader().isSpeaking())) {
      this.stopTtsBackgroundHeartbeat();
      return;
    }
    if (!this.ttsBackgroundRunning && !this.ttsBackgroundRequesting) {
      await this.startTtsBackgroundRunning();
      return;
    }
    await this.syncTtsSystemMediaControls();
    const now = Date.now();
    if (now - this.ttsBackgroundLastLogAt >= 120000) {
      this.ttsBackgroundLastLogAt = now;
      console.info(`[TTS-BG] heartbeat: ${this.ttsBackgroundDebugState()}`);
    }
  }

  onTtsAudioStarted(): void {
    this.host.clearTtsContinuationWatchdog();
    console.info(`[TTS-BG] audio started: ${this.ttsBackgroundDebugState()}`);
    this.refreshTtsBackgroundAfterAudioStarted().catch((error: Error) => {
      console.warn(`[TTS-BG] refresh after audio started failed: ${this.formatTtsBackgroundError(error as Object)}; ${this.ttsBackgroundDebugState()}`, error);
    });
  }

  private async refreshTtsBackgroundAfterAudioStarted(): Promise<void> {
    if (!this.ttsBackgroundRunning && !this.ttsBackgroundRequesting) {
      await this.startTtsBackgroundRunning();
      return;
    }
    await this.syncTtsSystemMediaControls();
  }

  private async startTtsAvSession(agent: WantAgent): Promise<void> {
    if (this.ttsAvSessionRequesting) {
      return;
    }
    this.ttsAvSessionRequesting = true;
    try {
      if (!this.ttsAvSession) {
        this.ttsAvSession = await avSession.createAVSession(this.host.hostContext(), 'LegadoReaderTts', 'audio');
        this.registerTtsAvSessionCommands(this.ttsAvSession);
      }
      await this.ttsAvSession.setLaunchAbility(agent);
      await this.ttsAvSession.setAVQueueTitle(this.host.getReaderBook()?.name || '听书');
      await this.refreshTtsMediaImage();
      await this.ttsAvSession.setAVMetadata(this.getTtsAvMetadata());
      await this.ttsAvSession.setExtras({
        bookUrl: this.host.getReaderBookUrl() || '',
        chapterIndex: this.host.getCurrentChapterIndex(),
        chapterTitle: this.host.getChapterTitle()
      });
      await this.updateTtsAvSessionPlaybackState(this.ttsAvPlaybackState());
      await this.ttsAvSession.activate();
      await this.syncTtsSystemMediaControls();
      console.info(`[TTS-BG] AVSession activated: ${this.ttsBackgroundDebugState()}`);
    } catch (error) {
      console.warn(`[TTS-BG] start AVSession failed: ${this.formatTtsBackgroundError(error as Object)}; ${this.ttsBackgroundDebugState()}`, error);
    } finally {
      this.ttsAvSessionRequesting = false;
    }
  }

  private registerTtsAvSessionCommands(session: avSession.AVSession): void {
    const host = this.host;
    session.on('play', () => {
      if (host.isTtsPausedState() || host.getTtsReader().isPaused() || host.getTtsReader().isInterrupted()) {
        host.toggleTtsReading();
      } else if (!host.isTtsSpeakingState() && !host.getTtsReader().isSpeaking()) {
        host.startTtsReadingFromCurrentPosition(false);
      }
    });
    session.on('pause', () => {
      if (!host.isTtsPausedState() && (host.isTtsSpeakingState() || host.getTtsReader().isSpeaking())) {
        host.toggleTtsReading();
      }
    });
    session.on('stop', () => {
      host.stopTtsReading();
    });
    session.on('playNext', () => {
      this.playNextChapterFromMediaSession();
    });
    session.on('playPrevious', () => {
      this.playPreviousChapterFromMediaSession();
    });
    session.on('setSpeed', (speed: number) => {
      host.applyTtsSpeed(speed);
    });
  }

  private unregisterTtsAvSessionCommands(session: avSession.AVSession): void {
    try { session.off('play'); } catch (_) {}
    try { session.off('pause'); } catch (_) {}
    try { session.off('stop'); } catch (_) {}
    try { session.off('playNext'); } catch (_) {}
    try { session.off('playPrevious'); } catch (_) {}
    try { session.off('setSpeed'); } catch (_) {}
  }

  async playNextChapterFromMediaSession(): Promise<void> {
    const host = this.host;
    if (!host.canPlayNextTtsChapter()) {
      return;
    }
    const sourceChapterIndex = host.getCurrentChapterIndex();
    const sourcePageIndex = host.getCurrentPageIndex();
    const targetChapterIndex = sourceChapterIndex + 1;
    const now = Date.now();
    if (host.isTtsChapterSwitching() || now - host.getTtsLastMediaChapterCommandAt() < 1000) {
      return;
    }
    host.setTtsLastMediaChapterCommandAt(now);
    host.setTtsChapterSwitching(true);
    try {
      const wasPaused = host.isTtsSessionManuallyPaused();
      const shouldResume = !wasPaused && (host.isTtsSpeakingState() || host.getTtsReader().isSpeaking() ||
        host.ownsTtsFloatingSession());
      console.info(`[TTS] media next chapter: source=${sourceChapterIndex},target=${targetChapterIndex},` +
        `resume=${shouldResume}`);
      if (shouldResume) {
        host.stopTtsReaderForChapterSwitch();
        await this.updateTtsAvSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_BUFFERING);
      } else if (wasPaused) {
        host.prepareTtsForManualPageTurn();
        await this.updateTtsAvSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
      } else {
        host.stopTtsReading();
      }
      host.setCurrentPageIndex(0);
      host.setPendingRestorePageIndex(0);
      const loaded = await host.loadContent(true, targetChapterIndex);
      const switched = loaded && host.getCurrentChapterIndex() === targetChapterIndex;
      if (switched) {
        await host.saveReadingProgress();
      } else {
        host.setCurrentPageIndex(sourcePageIndex);
        host.setPendingRestorePageIndex(sourcePageIndex);
        if (host.getCurrentChapterIndex() !== sourceChapterIndex) {
          await host.loadContent(true, sourceChapterIndex);
        } else {
          host.syncCurrentPageText();
        }
        console.warn(`[TTS] next chapter switch did not reach target: target=${targetChapterIndex},` +
          `actual=${host.getCurrentChapterIndex()}`);
        HdsFeedback.showToast('下一章加载失败，已保留当前朗读位置');
      }
      if (shouldResume) {
        await host.startTtsReadingFromCurrentPosition(false);
      } else if (wasPaused) {
        host.scheduleTtsResumeAfterManualPageTurn();
        await this.updateTtsAvSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
      } else {
        await this.updateTtsAvSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_STOP);
      }
    } finally {
      host.setTtsChapterSwitching(false);
    }
  }

  async playPreviousChapterFromMediaSession(): Promise<void> {
    const host = this.host;
    if (!host.canPlayPreviousTtsChapter()) {
      return;
    }
    const sourceChapterIndex = host.getCurrentChapterIndex();
    const sourcePageIndex = host.getCurrentPageIndex();
    const targetChapterIndex = sourceChapterIndex - 1;
    const now = Date.now();
    if (host.isTtsChapterSwitching() || now - host.getTtsLastMediaChapterCommandAt() < 1000) {
      return;
    }
    host.setTtsLastMediaChapterCommandAt(now);
    host.setTtsChapterSwitching(true);
    try {
      const wasPaused = host.isTtsSessionManuallyPaused();
      const shouldResume = !wasPaused && (host.isTtsSpeakingState() || host.getTtsReader().isSpeaking() ||
        host.ownsTtsFloatingSession());
      console.info(`[TTS] media previous chapter: source=${sourceChapterIndex},target=${targetChapterIndex},` +
        `resume=${shouldResume}`);
      if (shouldResume) {
        host.stopTtsReaderForChapterSwitch();
        await this.updateTtsAvSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_BUFFERING);
      } else if (wasPaused) {
        host.prepareTtsForManualPageTurn();
        await this.updateTtsAvSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
      } else {
        host.stopTtsReading();
      }
      host.setCurrentPageIndex(0);
      host.setPendingRestorePageIndex(0);
      const loaded = await host.loadContent(true, targetChapterIndex);
      const switched = loaded && host.getCurrentChapterIndex() === targetChapterIndex;
      if (switched) {
        await host.saveReadingProgress();
      } else {
        host.setCurrentPageIndex(sourcePageIndex);
        host.setPendingRestorePageIndex(sourcePageIndex);
        if (host.getCurrentChapterIndex() !== sourceChapterIndex) {
          await host.loadContent(true, sourceChapterIndex);
        } else {
          host.syncCurrentPageText();
        }
        console.warn(`[TTS] previous chapter switch did not reach target: target=${targetChapterIndex},` +
          `actual=${host.getCurrentChapterIndex()}`);
        HdsFeedback.showToast('上一章加载失败，已保留当前朗读位置');
      }
      if (shouldResume) {
        await host.startTtsReadingFromCurrentPosition(false);
      } else if (wasPaused) {
        host.scheduleTtsResumeAfterManualPageTurn();
        await this.updateTtsAvSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
      } else {
        await this.updateTtsAvSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_STOP);
      }
    } finally {
      host.setTtsChapterSwitching(false);
    }
  }

  async updateTtsAvSessionPlaybackState(state: avSession.PlaybackState): Promise<void> {
    if (!this.ttsAvSession) {
      return;
    }
    try {
      await this.refreshTtsMediaImage();
      await this.ttsAvSession.setAVMetadata(this.getTtsAvMetadata());
      await this.ttsAvSession.setAVPlaybackState({
        state: state,
        speed: AppStorage.get<number>('ttsSpeed') || 1,
        position: {
          elapsedTime: this.getTtsPlaybackElapsedTime(),
          updateTime: Date.now()
        },
        bufferedTime: this.getTtsPlaybackDuration(),
        loopMode: avSession.LoopMode.LOOP_MODE_SEQUENCE,
        activeItemId: this.host.getCurrentChapterIndex()
      });
      if (state === avSession.PlaybackState.PLAYBACK_STATE_PLAY ||
        state === avSession.PlaybackState.PLAYBACK_STATE_BUFFERING) {
        await this.ttsAvSession.activate();
      }
    } catch (error) {
      console.warn(`[TTS-BG] update AVSession playback state failed: ${this.formatTtsBackgroundError(error as Object)}; ${this.ttsBackgroundDebugState()}`, error);
    }
  }

  async syncTtsSystemMediaControls(): Promise<void> {
    if (!this.host.isTtsSpeakingState() && !this.host.getTtsReader().isSpeaking()) {
      return;
    }
    try {
      if (!this.ttsAvSession) {
        await this.startTtsBackgroundRunning();
        return;
      }
      await this.ttsAvSession.activate();
      await this.updateTtsAvSessionPlaybackState(this.ttsAvPlaybackState());
    } catch (error) {
      console.warn(`[TTS-BG] sync media controls failed: ${this.formatTtsBackgroundError(error as Object)}; ${this.ttsBackgroundDebugState()}`, error);
    }
  }

  ttsAvPlaybackState(): avSession.PlaybackState {
    return this.host.isTtsPausedState() || this.host.getTtsReader().isPaused() ?
      avSession.PlaybackState.PLAYBACK_STATE_PAUSE : avSession.PlaybackState.PLAYBACK_STATE_PLAY;
  }

  private getTtsAvMetadata(): avSession.AVMetadata {
    const host = this.host;
    const metadata: avSession.AVMetadata = {
      assetId: this.getTtsAvAssetId(),
      title: host.getReaderBook()?.name || '朗读',
      subtitle: this.getTtsAvSubtitle(),
      artist: host.getReaderBook()?.author || '阅读',
      author: host.getReaderBook()?.author || '阅读',
      album: host.getReaderBook()?.name || '听书',
      duration: this.getTtsPlaybackDuration(),
      previousAssetId: host.canPlayPreviousTtsChapter() ?
        this.getTtsChapterAssetId(host.getCurrentChapterIndex() - 1) : '',
      nextAssetId: host.canPlayNextTtsChapter() ?
        this.getTtsChapterAssetId(host.getCurrentChapterIndex() + 1) : '',
      avQueueName: host.getReaderBook()?.name || '听书',
      avQueueId: host.getReaderBookUrl() || 'reader_tts'
    };
    if (this.ttsMediaPixelMap) {
      metadata.mediaImage = this.ttsMediaPixelMap;
      metadata.avQueueImage = this.ttsMediaPixelMap;
    } else if (this.ttsMediaImage) {
      metadata.mediaImage = this.ttsMediaImage;
      metadata.avQueueImage = this.ttsMediaImage;
    }
    return metadata;
  }

  async refreshTtsMediaImage(): Promise<void> {
    const serial = ++this.ttsMediaImageRefreshSerial;
    const raw = this.host.getBookshelfDisplayCoverRaw();
    if (raw && raw === this.ttsMediaImageRaw && this.ttsMediaPixelMap) {
      return;
    }
    if (!raw) {
      if (serial === this.ttsMediaImageRefreshSerial) {
        this.ttsMediaImage = '';
        this.ttsMediaImageRaw = '';
        this.releaseTtsMediaPixelMap();
      }
      return;
    }
    let resolved = raw;
    let pixelMap: image.PixelMap | null = null;
    try {
      const context = this.host.hostContext();
      const coverPath = await BookCoverCache.prepareCoverFile(context, raw);
      if (coverPath) {
        pixelMap = await this.createTtsMediaPixelMap(coverPath);
        resolved = pixelMap ? coverPath : await BookCoverCache.resolveCover(context, raw);
      } else {
        resolved = await BookCoverCache.resolveCover(context, raw);
      }
    } catch (error) {
      console.warn('解析朗读媒体封面失败:', error);
    }
    if (serial === this.ttsMediaImageRefreshSerial) {
      this.releaseTtsMediaPixelMap();
      this.ttsMediaImage = resolved || raw;
      this.ttsMediaImageRaw = raw;
      this.ttsMediaPixelMap = pixelMap;
    } else if (pixelMap) {
      pixelMap.release().catch((e: Error) => {
        console.warn('释放过期朗读媒体封面失败:', e);
      });
    }
  }

  private async createTtsMediaPixelMap(path: string): Promise<image.PixelMap | null> {
    let file: fs.File | null = null;
    let source: image.ImageSource | null = null;
    try {
      file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      source = image.createImageSource(file.fd);
      return await source.createPixelMap({
        desiredSize: {
          width: 512,
          height: 512
        }
      });
    } catch (error) {
      console.warn('创建朗读媒体封面 PixelMap 失败:', error);
      return null;
    } finally {
      if (source) {
        try {
          await source.release();
        } catch (e) {
        }
      }
      if (file) {
        try {
          fs.closeSync(file);
        } catch (e) {
        }
      }
    }
  }

  private releaseTtsMediaPixelMap(): void {
    if (!this.ttsMediaPixelMap) {
      return;
    }
    try {
      this.ttsMediaPixelMap.release().catch((e: Error) => {
        console.warn('释放朗读媒体封面失败:', e);
      });
    } catch (e) {
      console.warn('释放朗读媒体封面失败:', e);
    }
    this.ttsMediaPixelMap = null;
  }

  private getTtsPlaybackElapsedTime(): number {
    const pageCount = Math.max(this.host.getContentPageCount(), 1);
    const clampedPageIndex = Math.max(0, Math.min(this.host.getCurrentPageIndex(), pageCount - 1));
    return Math.round((clampedPageIndex / pageCount) * this.getTtsPlaybackDuration());
  }

  private getTtsPlaybackDuration(): number {
    const charCount = Math.max(this.host.getTtsCharCountSource().length, 1);
    const charsPerMinute = 260 * Math.max(this.host.getTtsSpeed() || 1, 0.5);
    return Math.max(60000, Math.round((charCount / charsPerMinute) * 60000));
  }

  private getTtsAvAssetId(): string {
    return `${this.getTtsChapterAssetId(this.host.getCurrentChapterIndex())}_${this.host.getCurrentPageIndex()}_${this.getTtsMediaImageIdentity()}`;
  }

  private getTtsChapterAssetId(chapterIndex: number): string {
    return `${this.host.getReaderBookUrl() || 'reader_tts'}_${chapterIndex}`;
  }

  private getTtsMediaImageIdentity(): string {
    const value = this.ttsMediaImageRaw || this.ttsMediaImage || 'cover';
    let hash = 0;
    for (let i = 0; i < value.length; i++) {
      hash = value.charCodeAt(i) + ((hash << 5) - hash);
    }
    return Math.abs(hash).toString(16);
  }

  private getTtsAvSubtitle(): string {
    const progress = this.host.getProgressText();
    const chapter = this.host.getChapterTitle();
    return progress ? `${chapter} · ${progress}` : chapter;
  }

  private async stopTtsAvSession(): Promise<void> {
    if (!this.ttsAvSession) {
      return;
    }
    const session = this.ttsAvSession;
    this.ttsAvSession = null;
    this.unregisterTtsAvSessionCommands(session);
    try {
      await session.setAVPlaybackState({
        state: avSession.PlaybackState.PLAYBACK_STATE_STOP
      });
    } catch (error) {
      console.warn(`[TTS-BG] mark AVSession stopped failed: ${this.formatTtsBackgroundError(error as Object)}`, error);
    }
    try {
      await session.deactivate();
    } catch (error) {
      console.warn(`[TTS-BG] deactivate AVSession failed: ${this.formatTtsBackgroundError(error as Object)}`, error);
    }
    try {
      await session.destroy();
      console.info('[TTS-BG] AVSession destroyed');
    } catch (error) {
      console.warn(`[TTS-BG] destroy AVSession failed: ${this.formatTtsBackgroundError(error as Object)}`, error);
    } finally {
      this.ttsMediaImage = '';
      this.ttsMediaImageRaw = '';
      this.releaseTtsMediaPixelMap();
    }
  }

  private async createTtsBackgroundWantAgent(): Promise<WantAgent> {
    const context = this.host.hostContext() as common.UIAbilityContext;
    return await wantAgent.getWantAgent({
      wants: [{
        bundleName: context.abilityInfo.bundleName,
        abilityName: 'EntryAbility'
      }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 1001,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    });
  }

  private ttsBackgroundDebugState(): string {
    return `desired=${this.ttsBackgroundDesired},running=${this.ttsBackgroundRunning},requesting=${this.ttsBackgroundRequesting},speaking=${this.host.isTtsSpeakingState()},readerSpeaking=${this.host.getTtsReader().isSpeaking()},avSession=${this.ttsAvSession ? 'yes' : 'no'},audio=${this.host.getTtsReader().audioDebugState()}`;
  }

  private formatTtsBackgroundError(error: Object | null | undefined): string {
    if (!error) {
      return 'unknown';
    }
    const record = error as Record<string, Object>;
    const code = record['code'];
    const message = record['message'];
    const parts: string[] = [];
    if (code !== undefined) {
      parts.push(`code=${String(code)}`);
    }
    if (message !== undefined) {
      parts.push(`message=${String(message)}`);
    }
    return parts.length > 0 ? parts.join(',') : String(error);
  }
}
