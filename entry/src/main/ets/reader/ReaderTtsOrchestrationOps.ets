import type { ReadBookPage } from '../pages/ReadBook';

import { router, window, promptAction, MeasureOptions } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { common, ConfigurationConstant, WantAgent, wantAgent } from '@kit.AbilityKit';
import { inputConsumer, KeyCode, Action, KeyEvent } from '@kit.InputKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { avSession } from '@kit.AVSessionKit';
import { notificationManager } from '@kit.NotificationKit';
import image from '@ohos.multimedia.image';
import fs from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import graphicsText from '@ohos.graphics.text';
import { LengthMetrics } from '@ohos.arkui.node';
import deviceInfo from '@ohos.deviceInfo';
import display from '@ohos.display';
import Animator, { AnimatorResult } from '@ohos.animator';
import { HdsTabs, HdsListItem, HdsSwipeActionOptions } from '@kit.UIDesignKit';
import { ARView } from '@kit.AREngine';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { Book, BookChapter, Bookmark, BookSource, SearchBook, HttpTTS } from '../model/data/Book';
import { AppDatabase } from '../model/data/AppDatabase';
import { ReadBookEngine } from '../core/book/ReadBookEngine';
import { BookTypeSupport } from '../core/book/BookTypeSupport';
import { LocalBookService } from '../core/book/LocalBookService';
import { WebDavBookService } from '../webdav/WebDavBookService';
import { WebBookService } from '../core/book/WebBookService';
import { VerificationSupport } from '../core/http/VerificationSupport';
import { ReaderActionData, ReaderActionMarker, ReaderActionMatch } from '../core/book/ReaderActionMarker';
import { BookSourceRuntimeSnapshotStore, BookSourceSettingValue } from '../core/book/BookSourceRuntimeSnapshot';
import { ReaderInteractionProviderRegistry } from '../core/book/ReaderInteractionProvider';
import { HdsFeedback } from '../utils/HdsFeedback';
import { RecentReadShortcut } from '../utils/RecentReadShortcut';
import { RecentReadCardUpdater } from '../utils/RecentReadCardUpdater';
import { SystemTtsReader, TtsChunk, TtsVoiceOption } from '../utils/SystemTtsReader';
import { TtsFocusLatencyMonitor } from '../utils/TtsFocusLatencyMonitor';
import { ReaderTtsFloatingSession } from '../utils/ReaderTtsFloatingSession';
import { ReaderProgressCheckpoint } from '../utils/ReaderProgressCheckpoint';
import { isNetworkAvailable } from '../utils/NetworkConnectivity';
import { ReaderSettings, ReaderSettingsStore } from '../utils/ReaderSettingsStore';
import { ReaderReplaceRule, ReaderReplaceRuleStore } from '../utils/ReaderReplaceRuleStore';
import { ReaderThemeHelper, ReaderThemeItem } from '../utils/ReaderThemeHelper';
import { ReaderCustomThemeData, ReaderCustomThemeHelper, ReaderCustomThemeScheme } from '../utils/ReaderCustomThemeHelper';
import { ReaderBackgroundImageStore } from '../utils/ReaderBackgroundImageStore';
import { AdaptiveColorPicker } from '../components/AdaptiveColorPicker';
import { AdaptiveSwitch } from '../components/AdaptiveSwitch';
import { ImmersiveBackButton } from '../components/ImmersiveBackButton';
import { ReaderThemeBackground } from '../components/ReaderThemeBackground';
import { ReaderPageCurlPainter } from '../components/ReaderPageCurlPainter';
import { ReaderEmulationFlipPainter, ReaderEmulationFlipRegion } from '../components/ReaderEmulationFlipPainter';
import { TtsCatalogSheet, CatalogTitleDataSource } from '../components/TtsCatalogSheet';
import { TtsGlobalCapsule } from '../components/TtsGlobalCapsule';
import { BookSourceStageRuntimeHost } from '../components/BookSourceStageRuntimeHost';
import { WebBookFetchRuntimeHost } from '../components/WebBookFetchRuntimeHost';
import { BookSourceStageWebRuntime, StageWebRuntimeRequest } from '../core/book/BookSourceStageWebRuntime';
import { WebBookFetchRuntime } from '../core/book/WebBookFetchRuntime';
import { SourceRuntimeStage } from '../core/book/BookSourceRuntimeRouter';
import { TtsSettings, TtsSettingsStore } from '../utils/TtsSettingsStore';
import { ReaderFontHelper, ReaderFontItem } from '../utils/ReaderFontHelper';
import { ReaderFontBootstrap } from '../utils/ReaderFontBootstrap';
import { ReaderSystemFontHelper } from '../utils/ReaderSystemFontHelper';
import { BookFieldSanitizer } from '../utils/BookFieldSanitizer';
import { CoverUrlNormalizer } from '../utils/CoverUrlNormalizer';
import { SearchExploreSettingsStore } from '../utils/SearchExploreSettingsStore';
import { SystemDialogSession } from '../utils/SystemDialogSession';
import { BookChangeSourceDialog } from '../components/BookChangeSourceDialog';
import { TapZoneSettingsDialogContent } from '../components/TapZoneSettingsDialog';
import { SearchBookShelfHelper } from '../utils/SearchBookShelfHelper';
import { BookDisplayHelper } from '../utils/BookDisplayHelper';
import { BookCoverCache } from '../utils/BookCoverCache';
import { CoverGallerySettings } from '../utils/CoverGallerySettings';
import { AppThemeModeStore } from '../utils/AppThemeModeStore';
import {
  ReaderRegexBubbleStyleResolver,
  ReaderRegexEmphasisContext,
  ReaderRegexFontCodec,
  ReaderRegexFontRule,
  ReaderRegexLegacySettings,
  ReaderResolvedRegexEmphasis
} from '../model/reader/ReaderRegexFontRule';
import { ThemeRuntime } from '../theme/ThemeRuntime';
import { ImmersiveMaterialRuntime } from '../utils/ImmersiveMaterialRuntime';
import { SelectMenuMaterialModifier } from '../components/SelectMenuMaterialModifier';
import { ThemeAssetRegistry } from '../theme/ThemeAssetRegistry';
import { VirtualListScrollbar } from '../utils/VirtualListScrollbar';
import { ReaderContentPreprocessor } from '../core/concurrency/ReaderContentPreprocessor';
import { CooperativeScheduler } from '../core/concurrency/CooperativeScheduler';
import {
  ReaderV2Document,
  ReaderV2DocumentParser,
  ReaderV2SpeechText
} from '../core/reader/ReaderV2Document';
import { ReaderV2LayoutInput, ReaderV2LayoutSnapshot } from '../core/reader/ReaderV2LayoutSnapshot';
import { ReaderV2PageFragment, ReaderV2PageLayout, ReaderV2PageSet, ReaderV2RegexBubbleSegment,
  ReaderV2SelectionRun } from '../core/reader/ReaderV2PageLayout';
import { ReaderV2PaginationSession, ReaderV2Paginator } from '../core/reader/ReaderV2Paginator';
import { ReaderV2Color, ReaderV2SpanStyleRange } from '../core/reader/ReaderV2Style';
import { ReaderV2PageNodeController } from '../core/reader/ReaderV2RenderNode';
import { ReaderV2GestureRouter, ReaderV2TapResult } from '../core/reader/ReaderV2Interaction';
import { ReaderOpenTrace } from '../utils/ReaderOpenTrace';
import { WebRuntimeAvailability } from '../utils/WebRuntimeAvailability';
import { EyeTurnCalibration, EyeTurnController, EyeTurnSample } from '../core/reader/EyeTurnController';
import { AutoPageTurnController, AutoPageTurnOptions } from '../core/reader/AutoPageTurnController';
import { AutoPageTurnIntervalDialogContent } from '../components/AutoPageTurnIntervalDialog';
import { ArEyeSignal, ArEyeTurnHost } from '../core/reader/ArEyeTypes';
import { FullTextCacheCancelCoordinator, FullTextCacheCancelSignal } from '../utils/FullTextCacheCancelCoordinator';
import { ReaderComicPageDataSource } from '../core/reader/ReaderDataSources';
import { ReaderCustomFontItem, ReaderCustomFontData, ReaderTxtCharsetOption } from '../core/reader/ReaderSettingsModels';
import { PageTurnPreview, ReaderParagraphMetrics, ReaderInlineActionBoundsTask, ReaderMergedActionBoundsTask, ReaderTextParagraph, ReadTextSlice, ReaderPaginationResult, ReaderViewportSize, ReaderTextParagraphGroup, ReaderParagraphMeasureFallback, ReaderV2HighlightRect } from '../core/reader/ReaderPageModels';
import { ReaderEyeCalibrationPoint } from '../core/reader/ReaderEyeModels';
import { ReaderTtsBackgroundController, ReaderTtsBackgroundHost } from './ReaderTtsBackgroundController';
import {
  READER_PROGRESS_OFFSET_KEY,
  READER_PROGRESS_OFFSET_CHAPTER_KEY,
  hashText,
  hashTtsText,
  parseAreaDimension,
  savedReaderProgressOffset
} from './ReaderPureUtils';
import {
  READER_EYE_CALIBRATION_HOLD_MS,
  READER_EYE_CALIBRATION_PHASE_COUNT,
  READER_EYE_CALIBRATION_TICK_MS,
  READER_EYE_CALIBRATION_MIN_PHASE_SAMPLES,
  READER_EYE_CALIBRATION_MIN_DELTA,
  AR_EYE_CALIBRATION_RAW,
  DEFAULT_EYE_CALIBRATION_RAW,
  READER_EYE_TURN_AR_ENABLED,
  TOC_WINDOW_PAGE_SIZE,
  TOC_SCROLLBAR_DRAG_UPDATE_INTERVAL_MS,
  FULL_TEXT_CACHE_NOTIFICATION_INTERVAL_MS,
  READER_CURRENT_PAGINATION_AHEAD_PAGE_COUNT,
  READER_ADJACENT_PAGINATION_PREVIEW_PAGE_COUNT,
  READER_PAGINATION_BATCH_DELAY_MS,
  READER_INTERACTIVE_PAGINATION_BATCH_DELAY_MS,
  READER_PAGINATION_BUSY_RETRY_DELAY_MS,
  READER_OPEN_FETCH_TIMEOUT_MS,
  READER_CONTENT_FETCH_TIMEOUT_MS,
  TTS_CONTINUATION_WATCHDOG_MS,
  READER_LOADING_SLOW_HINT_MS,
  READER_DOUBLE_PAGE_DIVIDER_WIDTH,
  READER_REPLACE_MENU_ITEM_ID,
  READER_PAGE_CURL_SNAPSHOT_SCALE,
  READER_PAGINATION_HEIGHT_SCALE_CACHE,
  cacheReaderPaginationHeightScale
} from './ReaderConstants';
import * as LeafFns from './ReaderLeafFns';

export function publishTtsFloatingSession(page: ReadBookPage): void {
    ReaderTtsFloatingSession.attach(
      page.ttsFloatingSessionOwnerId,
      page.bookUrl,
      page.book?.name || '正在朗读',
      page.getChapterTitle(),
      page.isTtsPaused || page.ttsReader.isInterrupted(),
      () => page.toggleTtsReading(),
      () => page.isTtsPaused || page.ttsReader.isPaused() || page.ttsReader.isInterrupted(),
      () => page.stopTtsFloatingSession()
    );
    ReaderTtsFloatingSession.configureControls(
      page.ttsFloatingSessionOwnerId,
      () => { page.playPreviousChapterFromMediaSession(); },
      () => { page.playNextChapterFromMediaSession(); },
      (value: number) => page.applyTtsSpeed(value),
      (minutes: number) => page.setTtsSleepTimer(minutes)
    );
    ReaderTtsFloatingSession.configurePositionControl(
      page.ttsFloatingSessionOwnerId,
      (chapterIndex: number, pageIndex: number, sourceOffset: number): Promise<void> =>
        page.playPositionFromFloatingSession(chapterIndex, pageIndex, sourceOffset)
    );
    ReaderTtsFloatingSession.configureCatalog(
      page.ttsFloatingSessionOwnerId,
      page.chapters.map((chapter: BookChapter) => chapter.title),
      page.currentChapterIndex,
      (index: number) => {
        page.playPositionFromFloatingSession(index, 0).catch(
          (error: Error) => console.warn('朗读目录跳转失败:', error));
      },
      page.readerChapterCachedFlags()
    );
    page.publishTtsFloatingVoices();
    page.updateTtsFloatingSession();
}

export function publishTtsFloatingVoices(page: ReadBookPage): void {
    if (!ReaderTtsFloatingSession.isOwner(page.ttsFloatingSessionOwnerId)) return;
    ReaderTtsFloatingSession.configureTtsVoices(
      page.ttsFloatingSessionOwnerId,
      page.ttsQuickVoiceLabels(),
      page.ttsQuickVoiceSelectedIndex(),
      (index: number) => {
        page.selectTtsQuickVoice(index);
        setTimeout(() => page.publishTtsFloatingVoices(), 0);
      }
    );
}

export function updateTtsFloatingSession(page: ReadBookPage): void {
    ReaderTtsFloatingSession.update(
      page.ttsFloatingSessionOwnerId,
      page.book?.name || '正在朗读',
      page.getChapterTitle(),
      page.isTtsPaused || page.ttsReader.isInterrupted()
    );
    // Keeps the floating catalog highlight on the chapter being read. Availability
    // published here is recomputed identically by updateDetails below.
    ReaderTtsFloatingSession.updateCatalogIndex(page.ttsFloatingSessionOwnerId, page.currentChapterIndex);
    ReaderTtsFloatingSession.updateDetails(
      page.ttsFloatingSessionOwnerId,
      page.ttsPanelFollowingText() || page.ttsQuickSentencePreview(),
      page.ttsPanelTextBefore(),
      page.ttsCurrentSentenceForPanel(),
      page.ttsPanelTextAfter(),
      page.getTtsFloatingCover(),
      '',
      `${page.currentChapterIndex + 1}/${Math.max(1, page.chapters.length)}章`,
      page.ttsSpeed,
      page.ttsSleepTimerMinutes,
      page.ttsSleepTimerRemainingSeconds,
      page.canPlayPreviousTtsChapter(),
      page.canPlayNextTtsChapter(),
      page.ttsQuickProgress()
    );
}

export function stopTtsFloatingSession(page: ReadBookPage): void {
    page.stopTtsReading();
    if (!page.readerPageVisible) {
      page.ttsReader.shutdown();
    }
}

export async function toggleTtsReading(page: ReadBookPage): Promise<void> {
    if (page.isReaderComicModeActive()) return;
    if (page.isTtsSpeaking || page.ttsReader.isSpeaking()) {
      // 假活跃兜底：续播链路中断后 isTtsSpeaking 仍为 true 但朗读器已结束，
      // 此时 pause()/resume() 都返回 false，按键会完全失效。直接收尾朗读会话。
      // 章节衔接与手动翻页续读的短暂空窗仍走原有逻辑，不受此兜底影响。
      if (!page.ttsReader.isSpeaking() && !page.ttsReader.isPaused() &&
        !page.ttsChapterSwitching && !page.ttsManualPageTurnResumePending) {
        page.finishTtsReading();
        HdsFeedback.showToast('朗读已结束');
        return;
      }
      try {
        if (page.isTtsPaused || page.ttsReader.isPaused() || page.ttsReader.isInterrupted()) {
          page.isTtsPaused = false;
          if (await page.ttsReader.resume()) {
            page.isTtsSpeaking = true;
            page.updateTtsFloatingSession();
            await page.updateTtsAvSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PLAY);
            HdsFeedback.showToast('继续朗读');
            // resume 后高亮锚点已丢失（暂停期间翻过页、源偏移已被清除，readerV2TtsSourceStart < 0）：
            // 直接从当前可见页首重新起播，立即重建高亮，避免"已播放却无高亮"一阵子。
            // 锚点仍在（未翻页）则只重绘一次，等待引擎下一句即可。
            if (page.readerV2TtsSourceStart < 0 && page.ttsManualPageTurnResumePending) {
              await page.startTtsReadingFromCurrentPosition(false);
            } else {
              page.publishTtsHighlightRenderChange();
            }
          } else if (page.ttsManualPageTurnResumePending) {
            // 暂停中手动翻页已丢弃旧朗读队列（ttsReader.stop）：resume 无法恢复，
            // 从翻页后的当前位置重新起播。
            await page.startTtsReadingFromCurrentPosition(false);
          } else {
            page.isTtsPaused = true;
          }
        } else {
          page.isTtsPaused = true;
          if (await page.ttsReader.pause()) {
            page.updateTtsFloatingSession();
            await page.updateTtsAvSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
            HdsFeedback.showToast('已暂停朗读');
          } else {
            page.isTtsPaused = false;
          }
        }
      } catch (error) {
        page.isTtsPaused = page.ttsReader.isPaused();
        page.updateTtsFloatingSession();
        console.warn('切换朗读暂停状态失败:', error);
        HdsFeedback.showToast('切换朗读状态失败');
      }
      return;
    }
    page.ttsMediaControlsExpanded = false;
    await page.startTtsReadingFromCurrentPosition(true);
}

export function setTtsPagedScrollOverride(page: ReadBookPage, enabled: boolean): void {
    const next = enabled && page.readerPageTurnMode === 3 && !page.isReaderComicModeActive();
    if (page.ttsPagedScrollOverride === next) return;
    page.ttsPagedScrollOverride = next;
    page.resetSlidePageEffect();
    if (next) {
      // 取消纵向连续列表尚未执行的定位任务，朗读期间使用原有分页滚动与逐句高亮。
      page.readerComicScrollRestoreSerial++;
      page.readerComicScrollRestoring = false;
    } else if (page.readerPageTurnMode === 3) {
      page.scheduleReaderComicScrollRestore();
    }
}

export async function startTtsReadingFromCurrentPosition(page: ReadBookPage, showToast: boolean, manualPageTurnResume: boolean = false, manualPageTurnResumeSerial: number = -1, readingStartOffset: number = -1, preserveExistingFocus: boolean = false): Promise<void> {
    if (!manualPageTurnResume) {
      page.cancelManualPageTurnTtsResume();
      page.clearQueuedReaderPageTurns();
    } else if (!page.isManualPageTurnTtsResumeCurrent(manualPageTurnResumeSerial)) {
      return;
    }
    if (page.isReaderComicModeActive()) {
      page.finishTtsReading();
      return;
    }
    page.ttsMediaControlsExpanded = false;
    page.setTtsPagedScrollOverride(true);
    const text = page.getTtsReadingText(readingStartOffset);
    if (!text) {
      page.finishTtsReading();
      if (showToast) {
        HdsFeedback.showToast('当前没有可朗读内容');
      }
      return;
    }
    if (readingStartOffset < 0) {
      page.ttsChapterCompletionRetryCount = 0;
    }
    // A source may end in whitespace, decorative separators, image/script signatures or other
    // tails that the TTS text pipeline blanks out before synthesis, so using text.length here
    // can point past the final audible chunk. That made the completion guard replay the last
    // sentence until it gave up and stopped with "chapter tail not confirmed". Derive the
    // endpoint from the same sanitize/trim semantics the chunk pipeline uses, so only content
    // a chunk can actually cover must be confirmed.
    const speechTextEnd = LeafFns.ttsSpeechTextEnd(text);
    const speechEnd = speechTextEnd <= 0 ? page.ttsTextStartOffset : (page.readerV2ActiveSpeechText ?
      page.readerV2ActiveSpeechText.sourceOffsetAt(speechTextEnd) :
      page.ttsTextStartOffset + speechTextEnd);
    page.ttsReadingExpectedSourceEnd = Math.max(page.ttsTextStartOffset, speechEnd);
    const token = ++page.ttsReadToken;
    page.ttsNextChapterAudioPrefetchArmed = false;
    const focusGeneration = ++page.ttsFocusGeneration;
    const focusChapterIndex = page.currentChapterIndex;
    const focusSourceIdentity = page.currentTtsSourceIdentity();
    page.ttsFocusChapterIndex = focusChapterIndex;
    page.ttsFocusSourceIdentity = focusSourceIdentity;
    page.ttsFocusContentLoadSerial = page.contentLoadSerial;
    page.ttsLastAppliedSourceOffset = Math.max(-1, page.ttsTextStartOffset - 1);
    await ReaderTtsFloatingSession.stopOther(page.ttsFloatingSessionOwnerId);
    // A later page turn or explicit stop supersedes this async start. The stale task must not
    // restore auto-continue or tear down the newer page-turn resume that replaced it.
    if (token !== page.ttsReadToken ||
      (manualPageTurnResume && !page.isManualPageTurnTtsResumeCurrent(manualPageTurnResumeSerial))) {
      return;
    }
    page.ttsAutoContinue = true;
    page.isTtsPaused = false;
    if (!preserveExistingFocus) {
      page.ttsDisplayText = page.currentPageText;
      page.ttsHighlightStart = -1;
      page.ttsHighlightEnd = -1;
      page.ttsLastFocusChunk = null;
      page.ttsLastFocusPageIndex = -1;
      page.readerV2TtsSourceStart = -1;
      page.readerV2TtsSourceEnd = -1;
      page.refreshReaderV2TtsOverlay();
      page.publishTtsHighlightRenderChange();
    }
    page.persistTtsReadPosition(page.ttsTextStartOffset, page.ttsTextStartOffset);
    try {
      page.isTtsSpeaking = true;
      page.updateVolumeKeySubscription();
      if (manualPageTurnResume) {
        // The page-turn path already scheduled adjacent-page/chapter preloading. Repeating it here
        // competes with the first resumed audio buffer on the UI thread.
        page.preloadReaderContentLater();
      } else {
        page.preloadReaderContent();
      }
      // Publish the floating session before the AVSession/background-task awaits. The panel that
      // opened on the first 听书 tap reads globalTtsCanPrevious/globalTtsCanNext from AppStorage;
      // with the publish left after these awaits both chapter buttons stayed disabled for the
      // whole first-launch startup window, and a tap on them was silently dropped.
      page.publishTtsFloatingSession();
      const backgroundStarted = await page.startTtsBackgroundRunning();
      if (!backgroundStarted && showToast) {
        HdsFeedback.showToast('后台朗读任务启动失败，息屏后可能中断');
      }
      if (token !== page.ttsReadToken ||
        (manualPageTurnResume && !page.isManualPageTurnTtsResumeCurrent(manualPageTurnResumeSerial))) {
        return;
      }
      // 后台任务启动等待期间内容可能已被换代（焦点会话在上方两个 await 之前捕获）。若仍基于
      // 陈旧文本启动，会话身份将与内容永久错位，之后所有 chunk 回调被 isCurrentTtsFocusSession
      // 静默丢弃（有声无高亮）。内容换代路径（loadContent 的孤儿检测）已接管重新锚定，
      // 这里只兜底未被接管的情况（如 cancelReaderLoading 只递增 serial 不提交内容）。
      if (page.ttsFocusContentLoadSerial !== page.contentLoadSerial ||
        focusChapterIndex !== page.currentChapterIndex) {
        console.warn(`[TTS] content changed during TTS start, aborting stale start: ` +
          `focusChapter=${focusChapterIndex},current=${page.currentChapterIndex}`);
        page.finishTtsReading();
        return;
      }
      if (!page.ttsAutoContinue) {
        if (!manualPageTurnResume) page.stopTtsReading(false);
        return;
      }
      await page.ttsReader.start(text, {
        onFinished: () => {
          page.continueTtsReading(token).catch((e: Error) => {
            console.warn('连续朗读续播失败:', e);
            if (token === page.ttsReadToken) {
              page.finishTtsReading();
            }
          });
        },
        onSpeechless: () => {
          if (token !== page.ttsReadToken) {
            return;
          }
          // The remaining page/chapter has no audible content (punctuation or
          // whitespace only), so no chunk will ever confirm the tail. Clear the
          // expected end before onFinished fires; otherwise continueTtsReading
          // sees zero focus chunks and retries the same speechless range until
          // it stops the whole read with "chapter tail not confirmed".
          page.ttsReadingExpectedSourceEnd = -1;
          page.ttsChapterCompletionRetryCount = 0;
        },
        onError: (message: string) => {
          if (token !== page.ttsReadToken) {
            return;
          }
          page.finishTtsReading();
          HdsFeedback.showToast(message || '系统朗读失败');
        },
        onChunkStart: (chunk: TtsChunk) => {
          if (!page.isCurrentTtsFocusSession(token, focusGeneration,
            focusChapterIndex, focusSourceIdentity)) {
            return;
          }
          page.followTtsChunk(chunk, token, focusGeneration, focusChapterIndex, focusSourceIdentity);
          page.maybePrefetchTtsNextChapterAudio();
        },
        onAudioStart: () => {
          if (token !== page.ttsReadToken) {
            return;
          }
          page.onTtsAudioStarted();
        },
        person: page.ttsPerson,
        online: page.ttsOnline,
        style: page.ttsStyle,
        language: page.ttsLanguage,
        speed: page.ttsSpeed,
        focusBreakOffsets: page.getTtsFocusBreakOffsets(text.length),
        // Continuous reading should keep one renderer/audio route across
        // chapter boundaries; explicit stop/pause paths still release it.
        keepAudioOutputOnFinish: true
      });
      if (showToast && token === page.ttsReadToken) {
        HdsFeedback.showToast('开始连续朗读');
      }
    } catch (error) {
      if (token !== page.ttsReadToken ||
        (manualPageTurnResume && !page.isManualPageTurnTtsResumeCurrent(manualPageTurnResumeSerial))) {
        return;
      }
      page.finishTtsReading();
      HdsFeedback.showToast('当前系统不支持朗读或 TTS 初始化失败');
      console.error('启动系统 TTS 失败:', error);
    }
}

export function stopTtsReading(page: ReadBookPage, userCancelled: boolean = true): void {
    page.cancelManualPageTurnTtsResume();
    page.clearTtsContinuationWatchdog();
    page.showGlobalTtsCatalog = false;
    page.flushTtsReadPosition();
    page.clearTtsSleepTimer();
    page.isTtsPaused = false;
    ReaderTtsFloatingSession.clear(page.ttsFloatingSessionOwnerId);
    if (userCancelled) {
      page.ttsAutoContinue = false;
      page.ttsReadToken++;
    }
    page.invalidateTtsFocusSession();
    page.ttsAutoTurningPage = false;
    page.ttsPendingTargetPageIndex = -1;
    page.ttsPendingHighlightChunk = null;
    page.ttsLastFocusChunk = null;
    page.ttsLastFocusPageIndex = -1;
    page.ttsReadingExpectedSourceEnd = -1;
    page.ttsChapterCompletionRetryCount = 0;
    page.ttsMediaControlsExpanded = false;
    page.ttsPageTurnSerial++;
    page.stopTtsBackgroundRunning();
    if (!page.isTtsSpeaking && !page.ttsReader.isSpeaking()) {
      page.isTtsSpeaking = false;
      page.updateVolumeKeySubscription();
      page.clearTtsHighlight();
      page.setTtsPagedScrollOverride(false);
      page.resumeCurrentReaderPaginationCompletion();
      return;
    }
    page.ttsReader.stop();
    page.isTtsSpeaking = false;
    page.updateVolumeKeySubscription();
    page.ttsPageTurnSerial++;
    page.clearTtsHighlight();
    page.ttsLastFocusChunk = null;
    page.ttsLastFocusPageIndex = -1;
    page.setTtsPagedScrollOverride(false);
    page.resumeCurrentReaderPaginationCompletion();
}

export function stopTtsReaderForChapterSwitch(page: ReadBookPage): void {
    page.cancelManualPageTurnTtsResume();
    page.clearTtsContinuationWatchdog();
    page.showGlobalTtsCatalog = false;
    page.flushTtsReadPosition();
    page.ttsAutoContinue = false;
    page.isTtsPaused = false;
    page.ttsReadToken++;
    page.invalidateTtsFocusSession();
    page.ttsAutoTurningPage = false;
    page.ttsPendingTargetPageIndex = -1;
    page.ttsPendingHighlightChunk = null;
    page.ttsLastFocusChunk = null;
    page.ttsLastFocusPageIndex = -1;
    page.ttsReadingExpectedSourceEnd = -1;
    page.ttsChapterCompletionRetryCount = 0;
    page.ttsPageTurnSerial++;
    page.ttsReader.stop();
    page.isTtsSpeaking = false;
    page.clearTtsHighlight();
    page.setTtsPagedScrollOverride(false);
}

export function clearManualPageTurnTtsResumeTimer(page: ReadBookPage): void {
    if (page.ttsManualPageTurnResumeTimerId < 0) return;
    clearTimeout(page.ttsManualPageTurnResumeTimerId);
    page.ttsManualPageTurnResumeTimerId = -1;
}

export function cancelManualPageTurnTtsResume(page: ReadBookPage): void {
    page.clearManualPageTurnTtsResumeTimer();
    page.ttsManualPageTurnResumeSerial++;
    page.ttsManualPageTurnResumePending = false;
    page.ttsManualPageTurnStartedAt = 0;
}

export function deferManualPageTurnTtsResume(page: ReadBookPage): void {
    page.clearManualPageTurnTtsResumeTimer();
    page.ttsManualPageTurnResumeSerial++;
}

export function isManualPageTurnTtsResumeCurrent(page: ReadBookPage, serial: number): boolean {
    return serial >= 0 && page.ttsManualPageTurnResumePending &&
      serial === page.ttsManualPageTurnResumeSerial;
}

export function prepareTtsForManualPageTurn(page: ReadBookPage): void {
    page.deferManualPageTurnTtsResume();
    // A page turn must reposition a paused session, never resume it. Capture the manual pause
    // before ttsReader.stop() resets the reader-level flags.
    const pausedBeforeTurn = page.isTtsPaused || page.ttsReader.isPaused();
    if (!page.ttsManualPageTurnResumePending) {
      page.ttsManualPageTurnResumePending = true;
      page.ttsManualPageTurnStartedAt = Date.now();
      page.flushTtsReadPosition();
    }
    // This also cancels a deferred start that already passed its debounce window. Previously the
    // early return left that start alive; once it noticed its stale token it performed a full stop
    // and accidentally removed the newest resume timer.
    page.ttsAutoContinue = false;
    page.isTtsPaused = pausedBeforeTurn;
    page.ttsReadToken++;
    page.invalidateTtsFocusSession();
    page.ttsAutoTurningPage = false;
    page.ttsPendingTargetPageIndex = -1;
    page.ttsPendingHighlightChunk = null;
    page.ttsLastFocusChunk = null;
    page.ttsLastFocusPageIndex = -1;
    page.ttsPageTurnSerial++;
    // Preserve the visible speaking/highlight state while the outgoing page animates — but only when
    // reading is about to continue (playing state). For a PAUSED session the turn does not re-speak
    // the old sentence, so leaving the stale highlight's source offsets in place lets that old
    // highlight "wander" onto every later page the user flips through (until the deferred
    // syncTtsStateToVisiblePage finally clears it). Clear it up front for the paused case.
    page.ttsReader.stop();
    if (pausedBeforeTurn) {
      page.ttsHighlightStart = -1;
      page.ttsHighlightEnd = -1;
      page.readerV2TtsSourceStart = -1;
      page.readerV2TtsSourceEnd = -1;
      page.publishTtsHighlightRenderChange();
    }
}

export function scheduleTtsResumeAfterManualPageTurn(page: ReadBookPage, attempt: number = 0): void {
    if (!page.ttsManualPageTurnResumePending) return;
    page.deferManualPageTurnTtsResume();
    const serial = page.ttsManualPageTurnResumeSerial;
    page.ttsManualPageTurnResumeTimerId = setTimeout(() => {
      page.ttsManualPageTurnResumeTimerId = -1;
      if (serial !== page.ttsManualPageTurnResumeSerial || !page.ttsManualPageTurnResumePending) return;
      // A6: bound the 48ms retry chain (100 attempts ~= 4.8s). If the page never
      // settles, fall through to the normal resume path instead of silently wedging
      // continuous reading forever with no audio and a stuck highlight.
      if ((page.isPageTurning || page.queuedPageTurnCount > 0 || page.queuedPageTurnDirection !== 0 ||
        !page.isReaderPageTurnPositionReadyForTts()) && attempt < 100) {
        page.scheduleTtsResumeAfterManualPageTurn(attempt + 1);
        return;
      }
      if (page.isTtsPaused) {
        // 手动暂停优先于自动续读：翻页只把朗读锚点移动到新页，保持暂停等待用户点击继续。
        page.syncTtsStateToVisiblePage();
        return;
      }
      const startedAt = page.ttsManualPageTurnStartedAt;
      const chapterIndex = page.currentChapterIndex;
      const pageIndex = page.currentPageIndex;
      page.syncTtsStateToVisiblePage();
      page.startTtsReadingFromCurrentPosition(false, true, serial)
        .then(() => {
          if (!page.isManualPageTurnTtsResumeCurrent(serial)) return;
          page.ttsManualPageTurnResumePending = false;
          // A fast engine may deliver its first chunk while the final incoming page still owns the
          // temporary turn surface. Republish once more from this deterministic resume-complete
          // boundary so the focus cannot remain attached to the discarded surface.
          // 首句可能尚未到达（readerV2TtsSourceStart<0）：不要整段跳过，等表面真正落定、
          // 首句到达后再用实时偏移无条件重绘一次，否则会"有声无高亮"。
          page.publishTtsFocusAfterResumeBoundary();
          console.info(`[TTS-Turn] resumed chapter=${chapterIndex},page=${pageIndex},` +
            `elapsed=${Math.max(0, Date.now() - startedAt)}ms`);
          page.ttsManualPageTurnStartedAt = 0;
        })
        .catch((error: Error) => {
          if (serial !== page.ttsManualPageTurnResumeSerial) return;
          console.warn('[TTS-Turn] deferred resume failed:', error);
          page.finishTtsReading();
        });
    }, 48);
}

export function isReaderPageTurnPositionReadyForTts(page: ReadBookPage): boolean {
    if (page.pendingRestorePageIndex >= 0 || page.hasReaderTypographyRestoreOffset() ||
      !page.readerInitialPageReady || page.contentPages.length === 0 ||
      page.currentPageIndex < 0 || page.currentPageIndex >= page.contentPages.length) return false;
    return page.displayPageChapterIndex === page.currentChapterIndex &&
      page.displayPageIndex === page.currentPageIndex &&
      page.displayPageText === page.getCurrentPageText();
}

export function syncTtsStateToVisiblePage(page: ReadBookPage): void {
    const pageText = page.getCurrentPageText();
    if (page.currentPageText !== pageText || page.displayPageText !== pageText ||
      page.displayPageChapterIndex !== page.currentChapterIndex || page.displayPageIndex !== page.currentPageIndex) {
      page.commitVisibleCurrentPageText(pageText);
    }
    const pageStart = page.getCurrentPageStartOffset();
    page.ttsTextStartOffset = pageStart;
    page.ttsDisplayText = pageText;
    page.ttsHighlightStart = -1;
    page.ttsHighlightEnd = -1;
    page.readerV2TtsSourceStart = -1;
    page.readerV2TtsSourceEnd = -1;
    page.refreshReaderV2TtsOverlay();
    page.publishTtsHighlightRenderChange();
    page.persistTtsReadPosition(pageStart, pageStart);
    page.updateTtsFloatingSession();
}

export async function continueTtsReading(page: ReadBookPage, token: number): Promise<void> {
    if (token !== page.ttsReadToken || !page.ttsAutoContinue) {
      return;
    }
    page.armTtsContinuationWatchdog();
    if (page.ttsChapterSwitching) {
      return;
    }
    // onFinished is not a sufficient chapter-boundary proof on every TTS route. A delayed/early completion event
    // can arrive while the final synthesized chunks are still absent from the audible queue. Replay from the last
    // confirmed chunk instead of discarding the unspoken tail and entering the next chapter.
    if (!page.isTtsReadingAtExpectedEnd()) {
      if (page.ttsChapterCompletionRetryCount < 2) {
        page.ttsChapterCompletionRetryCount++;
        const resumeOffset = page.ttsLastFocusChunk ?
          page.readerV2TtsSourceOffset(page.ttsLastFocusChunk.start) : page.ttsTextStartOffset;
        console.warn(`[TTS] completion before chapter tail: chapter=${page.currentChapterIndex},` +
          `resume=${resumeOffset},expected=${page.ttsReadingExpectedSourceEnd},` +
          `retry=${page.ttsChapterCompletionRetryCount}`);
        await page.startTtsReadingFromCurrentPosition(false, false, -1, resumeOffset, false);
        return;
      }
      console.warn(`[TTS] chapter tail still not confirmed after retries: chapter=${page.currentChapterIndex},` +
        `expected=${page.ttsReadingExpectedSourceEnd}`);
      // Do not silently consume a chapter when the last focus cue never reached its tail. Stopping here
      // leaves the reader on the current chapter so the user can retry/resume from the last confirmed chunk.
      page.ttsChapterAdvanceError = '当前章节末尾朗读未确认，朗读已暂停';
      page.finishTtsReading();
      HdsFeedback.showToast(page.ttsChapterAdvanceError);
      return;
    }
    const advanced = await page.advanceTtsReadingToNextChapter();
    if (token !== page.ttsReadToken || !page.ttsAutoContinue) {
      return;
    }
    if (!advanced) {
      const errorMessage = page.ttsChapterAdvanceError;
      page.finishTtsReading();
      if (errorMessage) {
        HdsFeedback.showToast(errorMessage);
      }
      return;
    }
    await page.startTtsReadingFromCurrentPosition(false);
}

export function isTtsReadingAtExpectedEnd(page: ReadBookPage): boolean {
    if (page.ttsReadingExpectedSourceEnd < 0) return true;
    const chunk = page.ttsLastFocusChunk;
    if (!chunk) return false;
    const spokenEnd = page.readerV2TtsSourceOffset(chunk.end);
    // Chunk boundaries trim only whitespace; tolerate that small non-audible suffix but never a missing paragraph.
    return spokenEnd >= page.ttsReadingExpectedSourceEnd - 4;
}

export function maybePrefetchTtsNextChapterAudio(page: ReadBookPage): void {
    if (page.ttsNextChapterAudioPrefetchArmed || page.ttsChapterSwitching ||
      !page.isTtsSpeaking || !page.ttsAutoContinue || page.ttsReadingExpectedSourceEnd < 0) {
      return;
    }
    const chunk = page.ttsLastFocusChunk;
    if (!chunk) {
      return;
    }
    const spokenEnd = page.readerV2TtsSourceOffset(chunk.end);
    if (page.ttsReadingExpectedSourceEnd - spokenEnd > 160) {
      return;
    }
    page.ttsNextChapterAudioPrefetchArmed = true;
    page.prefetchTtsNextChapterAudio().catch((e: Error) => {
      console.warn('[TTS] next chapter audio prefetch failed:', e);
    });
}

export async function prefetchTtsNextChapterAudio(page: ReadBookPage): Promise<void> {
    if (page.chapters.length === 0) {
      return;
    }
    const sourceChapterIndex = page.currentChapterIndex;
    const targetChapterIndex = sourceChapterIndex + 1;
    if (targetChapterIndex >= page.chapters.length) {
      return;
    }
    const engine = ReadBookEngine.get();
    if (!page.isCurrentReaderEngineBook()) {
      return;
    }
    // peekContent 命中 preloadAround 的缓存时立即返回；未预载则提前发起取文，
    // 让网络等待与当前章尾段的播放重叠。
    const body = await engine.peekContent(targetChapterIndex);
    if (!body || page.currentChapterIndex !== sourceChapterIndex ||
      !page.isTtsSpeaking || !page.ttsAutoContinue) {
      return;
    }
    const processed = await page.prepareReaderContentRules(body, targetChapterIndex);
    if (page.currentChapterIndex !== sourceChapterIndex ||
      !page.isTtsSpeaking || !page.ttsAutoContinue) {
      return;
    }
    const source = page.buildPagedSourceText(targetChapterIndex, processed);
    if (!source) {
      return;
    }
    // 复刻 getTtsReadingText 的起点推导（章末切换后落第 0 页，起点为 0）。
    let start = 0;
    const containingMarker = ReaderActionMarker.findRawRangeContaining(source, start);
    if (containingMarker.length >= 2) {
      start = containingMarker[1];
    }
    let previewText = '';
    if (page.shouldUseReaderLayoutV2(source)) {
      const document = page.readerV2Document(targetChapterIndex, source);
      if (document) {
        previewText = ReaderV2SpeechText.build(document, start).text;
      }
    }
    if (!previewText) {
      previewText = ReaderActionMarker.strip(
        LocalBookService.stripEpubImageMarkers(source.substring(start), true), true);
    }
    if (previewText && page.currentChapterIndex === sourceChapterIndex && page.isTtsSpeaking) {
      page.ttsReader.prefetchNextChapter(previewText);
    }
}

export function armTtsContinuationWatchdog(page: ReadBookPage): void {
    page.clearTtsContinuationWatchdog();
    page.ttsContinuationWatchdogId = setTimeout(() => {
      page.ttsContinuationWatchdogId = -1;
      if (!page.isTtsSpeaking || !page.ttsAutoContinue ||
        page.ttsReader.isSpeaking() || page.ttsReader.isPaused()) {
        return;
      }
      console.warn('[TTS] continuation watchdog fired: chapter handoff did not resume reading');
      HdsFeedback.showToast('连续朗读未能继续，已停止');
      page.finishTtsReading();
    }, TTS_CONTINUATION_WATCHDOG_MS);
}

export function clearTtsContinuationWatchdog(page: ReadBookPage): void {
    if (page.ttsContinuationWatchdogId < 0) {
      return;
    }
    clearTimeout(page.ttsContinuationWatchdogId);
    page.ttsContinuationWatchdogId = -1;
}

export async function advanceTtsReadingToNextChapter(page: ReadBookPage): Promise<boolean> {
    page.ttsChapterAdvanceError = '';
    if (page.chapters.length === 0 || page.currentChapterIndex >= page.chapters.length - 1) {
      // 最后一章读完属于正常结束，给出明确反馈而不是静默停止。
      page.ttsChapterAdvanceError = '本书已读完，朗读已停止';
      return false;
    }
    if (page.ttsChapterSwitching) {
      return false;
    }
    const sourceChapterIndex = page.currentChapterIndex;
    const sourcePageIndex = page.currentPageIndex;
    const sourcePendingRestorePageIndex = page.pendingRestorePageIndex;
    const targetChapterIndex = sourceChapterIndex + 1;
    const handoffReadToken = page.ttsReadToken;
    page.ttsChapterSwitching = true;
    try {
      // The completed chapter can still have a queued UI focus callback. Invalidate it before
      // loading the next chapter so an old offset cannot be interpreted against the new page set.
      page.invalidateTtsFocusSession();
      page.ttsLastFocusChunk = null;
      page.ttsLastFocusPageIndex = -1;
      page.ttsAutoTurningPage = false;
      page.ttsPendingTargetPageIndex = -1;
      page.ttsPendingHighlightChunk = null;
      page.ttsPageTurnSerial++;
      page.pendingRestorePageIndex = 0;
      const loaded = await page.loadContent(true, targetChapterIndex);
      if (!loaded || page.currentChapterIndex !== targetChapterIndex) {
        // Roll back only while this automatic handoff still owns the TTS token. A concurrent
        // explicit navigation owns its own chapter state and must not be overwritten here.
        if (handoffReadToken === page.ttsReadToken) {
          if (page.currentChapterIndex !== sourceChapterIndex) {
            page.currentPageIndex = sourcePageIndex;
            page.pendingRestorePageIndex = sourcePageIndex;
            const restored = await page.loadContent(true, sourceChapterIndex);
            if (!restored) {
              console.warn(`[TTS] failed to restore source chapter after handoff failure: ` +
                `source=${sourceChapterIndex}`);
            }
          }
          if (page.currentChapterIndex === sourceChapterIndex) {
            page.currentPageIndex = page.normalizeReaderSpreadPageIndex(
              Math.min(sourcePageIndex, Math.max(0, page.contentPages.length - 1)));
            page.pendingRestorePageIndex = sourcePendingRestorePageIndex;
            page.syncCurrentPageText();
          }
        }
        page.ttsChapterAdvanceError = '下一章正文加载失败，朗读已停止';
        console.warn(`[TTS] automatic chapter handoff failed: source=${sourceChapterIndex},` +
          `target=${targetChapterIndex},actual=${page.currentChapterIndex},loaded=${loaded}`);
        return false;
      }
      page.currentPageIndex = 0;
      page.pendingRestorePageIndex = -1;
      page.syncCurrentPageText();
      page.persistTtsReadPosition(0, 0);
      // 进度落库与 AVSession 刷新不阻塞章末切换：下一章首段合成要尽快开始，
      // 这些写入改后台完成，失败只记日志（AVSession 内部已捕获全部错误）。
      page.saveReadingProgress().catch((e: Error) => {
        console.warn('[TTS] save progress at chapter handoff failed:', e);
      });
      page.updateTtsFloatingSession();
      page.updateTtsAvSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PLAY);
      return true;
    } finally {
      page.ttsChapterSwitching = false;
    }
}

export function finishTtsReading(page: ReadBookPage): void {
    page.cancelManualPageTurnTtsResume();
    page.clearTtsContinuationWatchdog();
    page.showGlobalTtsCatalog = false;
    page.flushTtsReadPosition();
    page.clearTtsSleepTimer();
    page.ttsAutoContinue = false;
    page.isTtsSpeaking = false;
    page.isTtsPaused = false;
    page.ttsFocusLatencyMonitor.reset();
    ReaderTtsFloatingSession.clear(page.ttsFloatingSessionOwnerId);
    page.updateVolumeKeySubscription();
    page.ttsMediaControlsExpanded = false;
    page.ttsReader.stop();
    page.invalidateTtsFocusSession();
    page.stopTtsBackgroundRunning();
    page.ttsPageTurnSerial++;
    page.clearTtsHighlight();
    page.ttsLastFocusChunk = null;
    page.ttsLastFocusPageIndex = -1;
    page.ttsReadingExpectedSourceEnd = -1;
    page.ttsChapterCompletionRetryCount = 0;
    page.setTtsPagedScrollOverride(false);
    page.resumeCurrentReaderPaginationCompletion();
    if (!page.readerPageVisible) {
      page.ttsReader.shutdown();
    }
}

export async function loadReaderSettings(page: ReadBookPage): Promise<void> {
    try {
      const settings = await ReaderSettingsStore.load(page.hostContext());
      ReaderSettingsStore.applyToStorage(settings);
      page.applyLoadedReaderSettings(settings);
      const registered = await page.registerReaderFontBySettings(
        settings.fontFamily,
        settings.fontFilePath,
        settings.fontSourceName
      );
      if (registered || !page.readerFontFilePath) {
        page.refreshReaderTextRender();
      }
      page.paginateContent(page.content);
    } catch (e) {
      console.warn('读取阅读设置失败:', e);
    }
}

export function isTtsBackgroundRunning(ctrl: ReaderTtsBackgroundController | null): boolean {
    return ctrl ? ctrl.isTtsBackgroundRunning() : false;
}

export function isTtsBackgroundRequesting(ctrl: ReaderTtsBackgroundController | null): boolean {
    return ctrl ? ctrl.isTtsBackgroundRequesting() : false;
}

export function hasTtsAvSession(ctrl: ReaderTtsBackgroundController | null): boolean {
    return ctrl ? ctrl.hasTtsAvSession() : false;
}

export async function startTtsBackgroundRunning(ctrl: ReaderTtsBackgroundController | null): Promise<boolean> {
    return ctrl ? ctrl.startTtsBackgroundRunning() : false;
}

export async function stopTtsBackgroundRunning(ctrl: ReaderTtsBackgroundController | null): Promise<void> {
    if (ctrl) {
      await ctrl.stopTtsBackgroundRunning();
    }
}

export function onTtsAudioStarted(ctrl: ReaderTtsBackgroundController | null): void {
    if (ctrl) {
      ctrl.onTtsAudioStarted();
    }
}

export async function updateTtsAvSessionPlaybackState(ctrl: ReaderTtsBackgroundController | null, state: avSession.PlaybackState): Promise<void> {
    if (ctrl) {
      await ctrl.updateTtsAvSessionPlaybackState(state);
    }
}

export async function syncTtsSystemMediaControls(ctrl: ReaderTtsBackgroundController | null): Promise<void> {
    if (ctrl) {
      await ctrl.syncTtsSystemMediaControls();
    }
}

export function ttsAvPlaybackState(ctrl: ReaderTtsBackgroundController | null): avSession.PlaybackState {
    return ctrl ? ctrl.ttsAvPlaybackState() : avSession.PlaybackState.PLAYBACK_STATE_STOP;
}

export async function refreshTtsMediaImage(ctrl: ReaderTtsBackgroundController | null): Promise<void> {
    if (ctrl) {
      await ctrl.refreshTtsMediaImage();
    }
}

export async function playNextChapterFromMediaSession(ctrl: ReaderTtsBackgroundController | null): Promise<void> {
    if (ctrl) {
      await ctrl.playNextChapterFromMediaSession();
    }
}

export async function playPreviousChapterFromMediaSession(ctrl: ReaderTtsBackgroundController | null): Promise<void> {
    if (ctrl) {
      await ctrl.playPreviousChapterFromMediaSession();
    }
}

export function getReaderBook(page: ReadBookPage): Book | null {
    return page.book;
}

export function getReaderBookUrl(page: ReadBookPage): string {
    return page.bookUrl;
}

export function getCurrentChapterIndex(page: ReadBookPage): number {
    return page.currentChapterIndex;
}

export function getCurrentPageIndex(page: ReadBookPage): number {
    return page.currentPageIndex;
}

export function setCurrentPageIndex(page: ReadBookPage, value: number): void {
    page.currentPageIndex = value;
}

export function setPendingRestorePageIndex(page: ReadBookPage, value: number): void {
    page.pendingRestorePageIndex = value;
}

export function getContentPageCount(page: ReadBookPage): number {
    return page.contentPages.length;
}

export function getTtsReader(page: ReadBookPage): SystemTtsReader {
    return page.ttsReader;
}

export function isTtsSpeakingState(page: ReadBookPage): boolean {
    return page.isTtsSpeaking;
}

export function isTtsPausedState(page: ReadBookPage): boolean {
    return page.isTtsPaused;
}

export function getTtsSpeed(page: ReadBookPage): number {
    return page.ttsSpeed;
}

export function getTtsCharCountSource(page: ReadBookPage): string {
    return page.content || page.currentPageText || '';
}

export function isFullTextCaching(page: ReadBookPage): boolean {
    return page.fullTextCaching;
}

export function isFullTextCacheBackgroundRunning(page: ReadBookPage): boolean {
    return page.fullTextCacheBackgroundRunning;
}

export function setFullTextCacheBackgroundRunning(page: ReadBookPage, value: boolean): void {
    page.fullTextCacheBackgroundRunning = value;
}

export function isTtsChapterSwitching(page: ReadBookPage): boolean {
    return page.ttsChapterSwitching;
}

export function setTtsChapterSwitching(page: ReadBookPage, value: boolean): void {
    page.ttsChapterSwitching = value;
}

export function getTtsLastMediaChapterCommandAt(page: ReadBookPage): number {
    return page.ttsLastMediaChapterCommandAt;
}

export function setTtsLastMediaChapterCommandAt(page: ReadBookPage, value: number): void {
    page.ttsLastMediaChapterCommandAt = value;
}

export function ownsTtsFloatingSession(page: ReadBookPage): boolean {
    return ReaderTtsFloatingSession.isOwner(page.ttsFloatingSessionOwnerId);
}

export async function playPositionFromFloatingSession(page: ReadBookPage, targetChapterIndex: number, targetPageIndex: number, targetSourceOffset: number = -1): Promise<void> {
    const normalizedChapterIndex = page.clampChapterIndex(targetChapterIndex);
    const normalizedPageIndex = Math.max(0, Math.round(targetPageIndex));
    if (normalizedChapterIndex === page.currentChapterIndex && normalizedPageIndex === page.currentPageIndex) {
      return;
    }
    const sourceChapterIndex = page.currentChapterIndex;
    const sourcePageIndex = page.currentPageIndex;
    // 镜像页手动翻页提交的位置不允许被静默丢弃：节流窗口/章节切换期间等待而非直接返回，
    // 否则镜像页随后按未更新的全局锚点回拖，会把刚翻好的页面拉回旧章节。
    const waitDeadline = Date.now() + 2000;
    while ((page.ttsChapterSwitching || Date.now() - page.ttsLastMediaChapterCommandAt < 500) &&
      Date.now() < waitDeadline) {
      await LeafFns.delay(100);
    }
    if (page.ttsChapterSwitching) {
      return;
    }
    page.ttsLastMediaChapterCommandAt = Date.now();
    page.ttsChapterSwitching = true;
    try {
      const wasPaused = page.isTtsSessionManuallyPaused();
      const shouldResume = !wasPaused && (page.isTtsSpeaking || page.ttsReader.isSpeaking() ||
        ReaderTtsFloatingSession.isOwner(page.ttsFloatingSessionOwnerId));
      console.info(`[TTS] floating position: source=${sourceChapterIndex}/${sourcePageIndex},` +
        `target=${normalizedChapterIndex}/${normalizedPageIndex},resume=${shouldResume}`);
      if (shouldResume) {
        page.stopTtsReaderForChapterSwitch();
        await page.updateTtsAvSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_BUFFERING);
      } else if (wasPaused) {
        page.prepareTtsForManualPageTurn();
        await page.updateTtsAvSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
      }
      page.currentPageIndex = normalizedPageIndex;
      page.pendingRestorePageIndex = normalizedPageIndex;
      const loaded = await page.loadContent(true, normalizedChapterIndex);
      const switched = loaded && page.currentChapterIndex === normalizedChapterIndex;
      if (switched) {
        page.currentPageIndex = page.normalizeReaderSpreadPageIndex(
          Math.min(normalizedPageIndex, Math.max(0, page.contentPages.length - 1)));
        page.pendingRestorePageIndex = -1;
        page.syncCurrentPageText();
        await page.saveReadingProgress();
      } else {
        page.currentPageIndex = sourcePageIndex;
        page.pendingRestorePageIndex = sourcePageIndex;
        if (page.currentChapterIndex !== sourceChapterIndex) {
          await page.loadContent(true, sourceChapterIndex);
        } else {
          page.syncCurrentPageText();
        }
        HdsFeedback.showToast('章节加载失败，已保留当前朗读位置');
      }
      if (shouldResume) {
        const sourceLength = (page.pagedContentText || page.getPagedSourceText()).length;
        const resumeOffset = targetSourceOffset >= 0 ?
          Math.max(0, Math.min(Math.round(targetSourceOffset), sourceLength)) : -1;
        // A retained owner may have only the first cooperative pagination window while the visible
        // mirror already knows the target page. The absolute page start keeps speech on that exact
        // visible page without synchronously rebuilding every preceding native Paragraph.
        await page.startTtsReadingFromCurrentPosition(false, false, -1, resumeOffset);
      } else if (wasPaused) {
        if (switched) {
          // 暂停态下在 jumpToPosition 返回前立即发布提交后的位置。镜像页 resolve 后会立刻读取
          // 全局锚点，若依赖 48ms 后的显示就绪定时器（隐藏宿主上可能长期不就绪），镜像页会读到
          // 旧锚点并把自己拖回旧章节（跨章回跳）。
          const sourceLength = (page.pagedContentText || page.getPagedSourceText()).length;
          const publishOffset = targetSourceOffset >= 0 ?
            Math.max(0, Math.min(Math.round(targetSourceOffset), sourceLength)) :
            page.getCurrentPageStartOffset();
          page.persistTtsReadPosition(publishOffset, publishOffset);
        }
        page.scheduleTtsResumeAfterManualPageTurn();
        await page.updateTtsAvSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
      }
    } finally {
      page.ttsChapterSwitching = false;
    }
}

export function getTtsPanelCoverList(page: ReadBookPage): string[] {
    if (!page.book) {
      return [];
    }
    const covers = CoverGallerySettings.getDisplayCoverList(
      page.book,
      page.appDarkMode,
      page.bookshelfCoverAlbums,
      page.bookshelfLightCoverAlbumId,
      page.bookshelfDarkCoverAlbumId,
      page.bookshelfCoverApplyScope,
      page.bookshelfCoverTargetBooks,
      page.bookshelfIgnoreSourceCover,
      page.bookshelfCoverMode
    );
    const displayCovers: string[] = [];
    const context = page.hostContext();
    for (const raw of covers) {
      const cached = BookCoverCache.resolveCachedCover(context, raw);
      displayCovers.push(cached || raw);
    }
    return displayCovers;
}

export function getTtsFloatingCover(page: ReadBookPage): ResourceStr {
    const covers = page.getTtsPanelCoverList();
    return covers.length > 0 ? covers[0] : '';
}

export function getTtsCoverPlaceholderColor(page: ReadBookPage): string {
    const name = page.book?.name || '';
    if (!name) return '#007DFF';
    // 书名哈希标识色：色值参与哈希取模，改动会让同一本书颜色跳变。
    // 属于调色板而非语义危险色，不要替换成 ThemeRuntime.dangerColor。
    const colors: string[] = ['#007DFF', '#E53935', '#43A047', '#EF6C00',
      '#8E24AA', '#00ACC1', '#D81B60', '#5E35B1'];
    let hash = 0;
    for (let index = 0; index < name.length; index++) {
      hash = name.charCodeAt(index) + ((hash << 5) - hash);
    }
    return colors[Math.abs(hash) % colors.length];
}

export function getBookshelfDisplayCoverRaw(page: ReadBookPage): string {
    if (!page.book) {
      return '';
    }
    const albumCover = page.getTtsGalleryCoverRaw();
    if (albumCover) {
      return albumCover;
    }
    const covers = CoverGallerySettings.getDisplayCoverList(
      page.book,
      page.appDarkMode,
      page.bookshelfCoverAlbums,
      page.bookshelfLightCoverAlbumId,
      page.bookshelfDarkCoverAlbumId,
      page.bookshelfCoverApplyScope,
      page.bookshelfCoverTargetBooks,
      page.bookshelfIgnoreSourceCover,
      page.bookshelfCoverMode
    );
    return page.pickStableTtsCover(covers);
}

export function getTtsGalleryCoverRaw(page: ReadBookPage): string {
    if (!page.book) {
      return '';
    }
    if (page.bookshelfCoverApplyScope === 'books' &&
      !CoverGallerySettings.parseTargetBooks(page.bookshelfCoverTargetBooks).includes(page.book.bookUrl)) {
      return '';
    }
    const albumId = CoverGallerySettings.selectedAlbumId(
      page.appDarkMode,
      page.bookshelfLightCoverAlbumId,
      page.bookshelfDarkCoverAlbumId
    );
    const album = CoverGallerySettings.getAlbum(CoverGallerySettings.parseAlbums(page.bookshelfCoverAlbums), albumId);
    return album ? page.pickStableTtsCover(album.covers) : '';
}

export function pickStableTtsCover(page: ReadBookPage, covers: string[]): string {
    const cleaned: string[] = [];
    for (const cover of covers) {
      const value = (cover || '').trim();
      if (value && !cleaned.includes(value)) {
        cleaned.push(value);
      }
    }
    if (cleaned.length === 0) {
      return '';
    }
    if (cleaned.length === 1) {
      return cleaned[0];
    }
    const seed = `${page.bookUrl || page.book?.bookUrl || ''}_${page.book?.name || ''}_` +
      `${page.appDarkMode}_${page.bookshelfLightCoverAlbumId}_${page.bookshelfDarkCoverAlbumId}_` +
      `${page.bookshelfCoverMode}`;
    return cleaned[Math.abs(hashTtsText(seed)) % cleaned.length];
}
