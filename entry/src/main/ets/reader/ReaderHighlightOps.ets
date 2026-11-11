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

export function followTtsChunk(page: ReadBookPage, chunk: TtsChunk, token: number, generation: number, chapterIndex: number, sourceIdentity: string): void {
    // Playback cues already arrive on the ArkTS event loop at the audible segment boundary. Deferring them through
    // another timer lets pagination/layout work overtake the focus update, so the previous sentence can remain
    // highlighted after the next sentence is already audible.
    if (!page.isCurrentTtsFocusSession(token, generation, chapterIndex, sourceIdentity)) {
      return;
    }
    const focusStartedAt = Date.now();
    page.applyTtsChunkFocus(chunk);
    page.updateTtsFloatingSession();
    page.noteTtsFocusLatency(Date.now() - focusStartedAt);
}

export function noteTtsFocusLatency(page: ReadBookPage, elapsedMs: number): void {
    if (!page.ttsFocusLatencyMonitor.record(elapsedMs)) {
      return;
    }
    // 整天连续朗读的会话级退化信号：逐句焦点处理中位数持续超阈值，
    // 请求在下一章边界重建音频输出管线（等效手动关掉听书再播放）。
    console.warn(`[TTS] focus latency degraded: median=${page.ttsFocusLatencyMonitor.median()}ms,` +
      `sample=${elapsedMs}ms, requesting pcm output recycle at next chapter boundary`);
    page.ttsReader.requestOutputRecycle();
}

export function applyTtsChunkFocus(page: ReadBookPage, chunk: TtsChunk): void {
    const absoluteStart = page.readerV2TtsSourceOffset(chunk.start);
    // Cloud/custom audio may finish a cancelled prefetch after the replacement session has
    // already advanced. Never allow an older focus cue to move the visible reader backwards.
    if (page.ttsLastAppliedSourceOffset >= 0 && absoluteStart < page.ttsLastAppliedSourceOffset) {
      if (page.isTtsSpeaking && page.ttsAutoContinue) {
        console.warn(`[TTS] chunk dropped below last applied offset: absolute=${absoluteStart},` +
          `lastApplied=${page.ttsLastAppliedSourceOffset},speechTextNull=${!page.readerV2ActiveSpeechText},` +
          `startOffset=${page.ttsTextStartOffset}`);
      }
      return;
    }
    page.ttsLastAppliedSourceOffset = absoluteStart;
    const firstFocusInSession = !page.ttsLastFocusChunk;
    page.ttsLastFocusChunk = chunk;
    // 增量分页尚未覆盖朗读位置时，findPageIndexByOffset 会把越界偏移钳位到最后一页，
    // 直接采用会把高亮钳进错误页面的页尾并提前翻页。仅记录焦点，等分页窗口扩展后由
    // syncActiveTtsFocusAfterPagination 或后续 chunk 重新定位。
    if (page.contentPageEnds.length > 0 && !page.isCurrentReaderPaginationComplete()) {
      const paginatedWindowEnd = page.contentPageEnds[page.contentPageEnds.length - 1];
      if (paginatedWindowEnd >= 0 && absoluteStart >= paginatedWindowEnd) {
        page.ttsLastFocusPageIndex = -1;
        return;
      }
    }
    const pageIndex = page.findPageIndexByOffset(absoluteStart);
    const spreadPageIndex = page.normalizeReaderSpreadPageIndex(pageIndex);
    page.ttsLastFocusPageIndex = pageIndex;
    // Publish the destination range before mounting the incoming page. Both legacy text and V2 rectangles filter
    // the range by page, so it cannot leak onto the outgoing leaf; it does let the new sentence appear highlighted
    // during the turn instead of waiting until the animation has finished while audio continues playing.
    page.updateTtsChunkHighlight(chunk, pageIndex);
    if (spreadPageIndex !== page.currentPageIndex) {
      page.animateTtsToPage(spreadPageIndex, chunk);
      return;
    }
    if (firstFocusInSession) {
      // Starting TTS can replace the continuous-scroll reader with the paged surface in this same UI turn.
      // Republish the first cue after that new surface has mounted instead of relying on the pre-mount frame.
      page.scheduleTtsFocusRepublishAfterPageTurn(page.currentChapterIndex, pageIndex,
        page.readerV2TtsSourceStart, page.readerV2TtsSourceEnd);
    }
}

export function readerHeaderContentSelectedIndex(page: ReadBookPage): number {
    const index = LeafFns.readerHeaderContentValues().indexOf(page.readerHeaderContentMode);
    return index >= 0 ? index : 0;
}

export function readerFooterLeftSelectedIndex(page: ReadBookPage): number {
    const index = LeafFns.readerFooterLeftValues().indexOf(page.readerFooterLeftMode);
    return index >= 0 ? index : 0;
}

export function readerFooterProgressSelectedIndex(page: ReadBookPage): number {
    const index = LeafFns.readerFooterProgressValues().indexOf(page.readerFooterProgressMode);
    return index >= 0 ? index : 0;
}

export function saveReaderChromeSettings(page: ReadBookPage): void {
    ReaderSettingsStore.saveReaderChromeSettings(
      page.hostContext(),
      page.readerHeaderEnabled,
      page.readerHeaderContentMode,
      page.readerFooterEnabled,
      page.readerFooterLeftMode,
      page.readerFooterProgressMode,
      page.readerFooterShowProgressBar
    ).catch((e: Error) => {
      console.warn('保存阅读页眉页脚设置失败:', e);
    });
}

export function syncTtsFocusAfterResumeLater(page: ReadBookPage, delayMs: number): void {
    const serial = ++page.ttsResumeSyncSerial;
    setTimeout(() => {
      if (serial < page.ttsResumeSyncSerial - 1) {
        return;
      }
      // 后台停留期间跨章等会话换代会 bump ttsFocusGeneration/ttsReadToken。恢复同步读取的是执行
      // 瞬间的最新状态（syncTtsFocusAfterResume 内部逐项实时校验会话/内容/分页代际与手动翻页
      // 暂停态），不能因调度瞬间与执行瞬间的代际差异整体丢弃——否则回前台后 0/180ms 两次同步
      // 全部静默失效，页面与高亮停留在冻结位置，残留的 ttsAutoTurningPage/isPageTurning 无人
      // 清理（回前台后翻页卡顿感、高亮与声音不一致的来源）。
      page.syncTtsFocusAfterResume();
    }, delayMs);
}

export function scheduleTtsFocusResumeSyncRetry(page: ReadBookPage): void {
    // 单飞标志防止重试堆叠；截止时间（onPageShow 设置）防止章末切换卡死时无限轮询。
    // 重试直达 syncTtsFocusAfterResume：章末切换会递增 generation/token，经
    // syncTtsFocusAfterResumeLater 的代际守卫会被误杀。
    if (page.ttsFocusResumeRetryScheduled || Date.now() >= page.ttsFocusResumeRetryDeadline) return;
    page.ttsFocusResumeRetryScheduled = true;
    setTimeout(() => {
      page.ttsFocusResumeRetryScheduled = false;
      page.syncTtsFocusAfterResume();
    }, 500);
}

export function syncTtsFocusAfterResume(page: ReadBookPage): void {
    if (page.isMirroringActiveTtsForCurrentBook()) {
      if (page.mirroredTtsManualTurnPending || page.isPageTurning) return;
      // 进入阅读页时不再长期镜像播放中的后台朗读宿主：双实例并存会竞争同一引擎、进度写入
      // 与分页管线。改为一次性接管——停掉后台宿主，由本页从全局锚点句级续播；暂停中的会话
      // 无逐句推进与竞争窗口，维持原镜像跟随。
      if (!page.globalTtsPaused && !page.ttsSessionTakeoverAttempted) {
        page.takeOverMirroredTtsSession().catch((error: Error) => {
          console.warn('恢复时接管后台朗读会话失败:', error);
        });
        return;
      }
      if (page.ttsSessionTakeoverInProgress) return;
      page.syncMirroredTtsFocus().then(() => {
        page.scheduleCurrentTtsFocusRepublishAfterPageTurn();
      }).catch((error: Error) => {
        console.warn('恢复时同步后台朗读镜像焦点失败:', error);
      });
      return;
    }
    if (!page.isTtsSpeaking || !page.ttsAutoContinue || page.contentPages.length === 0) {
      return;
    }
    // 切回前台时，Home/锁屏冻结可能把自动翻页动画留在 isPageTurning/ttsAutoTurningPage 中间态。
    // 恢复同步不能被这两个残留标志挡住，由下方落位逻辑统一清态并跳到当前朗读句。
    if (page.ttsManualPageTurnResumePending) return;
    if (page.ttsChapterSwitching) {
      // 章末切换（含网络取文）可持续数秒。原先在此直接放弃，而 onPageShow 只在 0/180ms 调度
      // 两次，全部撞上切换窗口后回前台的落位同步就永久丢失。改为有界重试等待切换完成。
      page.scheduleTtsFocusResumeSyncRetry();
      return;
    }
    // 会话已与当前内容脱钩（内容换代后未被重新锚定的残余态）时，不得把陈旧 chunk 的偏移
    // 重发布到新内容的页面上。
    if (page.ttsFocusContentLoadSerial >= 0 && page.ttsFocusContentLoadSerial !== page.contentLoadSerial) {
      return;
    }
    if (!page.ttsLastFocusChunk && !page.restorePersistedTtsFocus()) return;
    if (!page.ttsLastFocusChunk) return;
    const pageIndex = page.resolveTtsChunkPageIndex(page.ttsLastFocusChunk);
    if (pageIndex < 0 || pageIndex >= page.contentPages.length) {
      return;
    }
    page.ttsLastFocusPageIndex = pageIndex;
    page.ttsPendingTargetPageIndex = -1;
    page.ttsPendingHighlightChunk = null;
    page.ttsAutoTurningPage = false;
    page.ttsPageTurnSerial++;
    page.finishPageTurnAnimation();
    const spreadPageIndex = page.normalizeReaderSpreadPageIndex(pageIndex);
    if (spreadPageIndex !== page.currentPageIndex) {
      page.currentPageIndex = spreadPageIndex;
      page.saveReadingProgress().catch((error: Error) => {
        console.warn('同步朗读恢复页码失败:', error);
      });
    }
    page.syncCurrentPageText();
    page.updateTtsChunkHighlight(page.ttsLastFocusChunk, pageIndex);
    console.info(`[TTS] resume focus synced: page=${pageIndex},highlight=${page.ttsHighlightStart}-${page.ttsHighlightEnd}`);
}

export function resolveTtsChunkPageIndex(page: ReadBookPage, chunk: TtsChunk): number {
    const absoluteStart = page.readerV2TtsSourceOffset(chunk.start);
    return page.findPageIndexByOffset(absoluteStart);
}

export function updateTtsChunkHighlight(page: ReadBookPage, chunk: TtsChunk, pageIndex: number, persistPosition: boolean = true): void {
    const absoluteStart = page.readerV2TtsSourceOffset(chunk.start);
    const absoluteEnd = page.readerV2TtsSourceOffset(chunk.end);
    const pageStart = page.getPageStartOffset(pageIndex);
    const pageEnd = page.getPageEndOffset(pageIndex);
    const pageText = page.getPageText(pageIndex);
    page.ttsDisplayText = pageText;
    if (pageIndex === page.currentPageIndex &&
      (page.currentPageText !== pageText || page.displayPageText !== pageText ||
        page.displayPageChapterIndex !== page.currentChapterIndex || page.displayPageIndex !== page.currentPageIndex)) {
      page.setCurrentPageText(pageText);
    }
    page.ttsHighlightStart = Math.max(0, Math.min(absoluteStart - pageStart, pageText.length));
    page.ttsHighlightEnd = Math.max(page.ttsHighlightStart, Math.min(absoluteEnd, pageEnd) - pageStart);
    page.readerV2TtsSourceStart = absoluteStart;
    page.readerV2TtsSourceEnd = absoluteEnd;
    page.refreshReaderV2TtsOverlay();
    if (persistPosition) page.persistTtsReadPosition(absoluteStart, absoluteEnd);
    page.publishTtsHighlightRenderChange();
    if (page.isPageTurning || page.ttsAutoTurningPage || page.ttsManualPageTurnResumePending) {
      page.scheduleTtsFocusRepublishAfterPageTurn(page.currentChapterIndex, pageIndex,
        absoluteStart, absoluteEnd);
    }
}

export function scheduleTtsFocusRepublishAfterPageTurn(page: ReadBookPage, chapterIndex: number, pageIndex: number, absoluteStart: number, absoluteEnd: number): void {
    const serial = ++page.ttsSurfaceFocusSyncSerial;
    page.republishTtsFocusAfterPageTurn(serial, chapterIndex, pageIndex, absoluteStart, absoluteEnd, 0);
}

export function publishTtsFocusAfterResumeBoundary(page: ReadBookPage): void {
    // 手动翻页续播完成的确定边界：此时 ttsManualPageTurnResumePending 已清，但引擎首句可能尚未
    // 到达（readerV2TtsSourceStart<0），且翻页表面/跨章宿主节点可能仍在切换。做一次"表面落定后
    // 无条件重绘"，确保新页面高亮不依赖那条常被守卫丢弃的延迟重绘链。
    const pin = (attempt: number): void => {
      const start = page.ttsLastFocusChunk ? page.readerV2TtsSourceOffset(page.ttsLastFocusChunk.start)
        : page.readerV2TtsSourceStart;
      const end = page.ttsLastFocusChunk ? page.readerV2TtsSourceOffset(page.ttsLastFocusChunk.end)
        : page.readerV2TtsSourceEnd;
      if ((start < 0 || end <= start) && attempt < 8 && page.isTtsSpeaking) {
        setTimeout(() => pin(attempt + 1), 32);
        return;
      }
      if (start < 0 || end <= start || !page.shouldRenderTtsFocus()) return;
      page.publishTtsHighlightRenderChange();
    };
    if (page.isPageTurning || page.ttsAutoTurningPage) {
      setTimeout(() => pin(0), 32);
      return;
    }
    pin(0);
}

export function scheduleCurrentTtsFocusRepublishAfterPageTurn(page: ReadBookPage): void {
    if (page.readerV2TtsSourceStart < 0 || page.readerV2TtsSourceEnd <= page.readerV2TtsSourceStart ||
      !page.shouldRenderTtsFocus()) return;
    const pageIndex = page.findPageIndexByOffset(page.readerV2TtsSourceStart);
    if (pageIndex < 0 || pageIndex >= page.contentPages.length) return;
    page.scheduleTtsFocusRepublishAfterPageTurn(page.currentChapterIndex, pageIndex,
      page.readerV2TtsSourceStart, page.readerV2TtsSourceEnd);
}

export function republishTtsFocusAfterPageTurn(page: ReadBookPage, serial: number, chapterIndex: number, pageIndex: number, absoluteStart: number, absoluteEnd: number, attempt: number): void {
    setTimeout(() => {
      if (serial !== page.ttsSurfaceFocusSyncSerial || chapterIndex !== page.currentChapterIndex ||
        page.normalizeReaderSpreadPageIndex(pageIndex) !== page.currentPageIndex ||
        !page.shouldRenderTtsFocus()) return;
      // 翻页/续播 pending 期间页面表面尚未稳定，继续等待；放宽重试上限，避免在手动翻页重启窗口内
      // 提前放弃（原 attempt<3 在 ttsManualPageTurnResumePending 仍为真时会直接 return 致死链）。
      if (attempt < 6 && (page.isPageTurning || page.ttsAutoTurningPage ||
        page.ttsManualPageTurnResumePending || page.mirroredTtsManualTurnPending)) {
        page.republishTtsFocusAfterPageTurn(serial, chapterIndex, pageIndex,
          absoluteStart, absoluteEnd, attempt + 1);
        return;
      }
      // 当前/进入中的阅读表面在快速翻页时会交替；延迟重绘只刷新轻量矩形层。但引擎较快时，本定时器触发前
      // 朗读已推进到下一句（readerV2TtsSourceStart 已改变）。基于"当前实时焦点分块"重新推导范围，
      // 而不是直接比对调度瞬间的偏移——否则严格偏移守卫会判定过期并静默丢弃这次唯一的重绘，
      // 导致新页面"有声无高亮"。
      const start = page.ttsLastFocusChunk ? page.readerV2TtsSourceOffset(page.ttsLastFocusChunk.start)
        : page.readerV2TtsSourceStart;
      const end = page.ttsLastFocusChunk ? page.readerV2TtsSourceOffset(page.ttsLastFocusChunk.end)
        : page.readerV2TtsSourceEnd;
      if (start < 0 || end <= start) return;
      page.publishTtsHighlightRenderChange();
    }, attempt === 0 ? 32 : 64);
}

export function scheduleTtsFocusSyncAfterPagination(page: ReadBookPage): void {
    const serial = ++page.ttsPaginationFocusSyncSerial;
    const chapterIndex = page.currentChapterIndex;
    const source = page.pagedContentText;
    // Pagination is commonly followed by a synchronous current-page restore. Reconcile on the next UI task so
    // that restore has settled and the replacement ArkUI/V2 surface exists before its focus layer is republished.
    setTimeout(() => {
      if (serial !== page.ttsPaginationFocusSyncSerial || chapterIndex !== page.currentChapterIndex ||
        source !== page.pagedContentText) return;
      page.syncActiveTtsFocusAfterPagination();
    }, 0);
}

export function syncActiveTtsFocusAfterPagination(page: ReadBookPage): void {
    if (!page.readerInitialPageReady || page.pendingRestorePageIndex >= 0 ||
      page.hasReaderTypographyRestoreOffset() || page.contentPages.length === 0) return;
    if (page.isMirroringActiveTtsForCurrentBook()) {
      page.syncMirroredTtsFocus().then(() => {
        page.scheduleCurrentTtsFocusRepublishAfterPageTurn();
      }).catch((error: Error) => {
        console.warn('分页更新后同步后台朗读焦点失败:', error);
      });
      return;
    }
    const chunk = page.ttsLastFocusChunk;
    if (!chunk || !page.isTtsSpeaking || !page.ttsAutoContinue ||
      page.ttsFocusChapterIndex !== page.currentChapterIndex ||
      page.ttsFocusContentLoadSerial !== page.contentLoadSerial ||
      page.ttsFocusSourceIdentity !== page.currentTtsSourceIdentity()) return;
    const absoluteStart = page.readerV2TtsSourceOffset(chunk.start);
    const lastKnownEnd = page.contentPageEnds.length > 0 ?
      page.contentPageEnds[page.contentPageEnds.length - 1] : 0;
    if (absoluteStart >= lastKnownEnd && lastKnownEnd < page.pagedContentText.length) return;
    const pageIndex = page.findPageIndexByOffset(absoluteStart);
    if (pageIndex < 0 || pageIndex >= page.contentPages.length) return;
    const targetPageIndex = page.normalizeReaderSpreadPageIndex(pageIndex);
    if (page.isPageTurning || page.ttsAutoTurningPage || page.ttsManualPageTurnResumePending) {
      page.scheduleCurrentTtsFocusRepublishAfterPageTurn();
      return;
    }
    if (targetPageIndex !== page.currentPageIndex) {
      page.finishPageTurnAnimation();
      page.currentPageIndex = targetPageIndex;
      page.syncCurrentPageText();
    } else if (page.displayPageChapterIndex !== page.currentChapterIndex ||
      page.displayPageIndex !== page.currentPageIndex || page.displayPageText !== page.getCurrentPageText()) {
      page.syncCurrentPageText();
    }
    page.ttsLastFocusPageIndex = pageIndex;
    page.updateTtsChunkHighlight(chunk, pageIndex, false);
    page.scheduleCurrentTtsFocusRepublishAfterPageTurn();
}

export function persistTtsReadPosition(page: ReadBookPage, absoluteStart: number, absoluteEnd: number): void {
    if (!page.book) return;
    const sourceLength = (page.pagedContentText || page.getPagedSourceText()).length;
    const start = Math.max(0, Math.min(Math.round(absoluteStart), sourceLength));
    const end = Math.max(start, Math.min(Math.round(absoluteEnd), sourceLength));
    page.book.putVariable('ttsReadChapterIndex', `${page.currentChapterIndex}`);
    page.book.putVariable('ttsReadOffsetStart', `${start}`);
    page.book.putVariable('ttsReadOffsetEnd', `${end}`);
    ReaderTtsFloatingSession.updatePosition(
      page.ttsFloatingSessionOwnerId, page.currentChapterIndex, start, end);
    if (page.ttsProgressSaveTimerId >= 0) return;
    page.ttsProgressSaveTimerId = setTimeout(() => {
      page.ttsProgressSaveTimerId = -1;
      page.saveReadingProgress().catch((error: Error) => {
        console.warn('保存朗读句子位置失败:', error);
      });
    }, 3000);
}

export function flushTtsReadPosition(page: ReadBookPage): void {
    if (page.ttsProgressSaveTimerId < 0) return;
    clearTimeout(page.ttsProgressSaveTimerId);
    page.ttsProgressSaveTimerId = -1;
    page.saveReadingProgress().catch((error: Error) => {
      console.warn('立即保存朗读句子位置失败:', error);
    });
}

export async function flushReadingProgressCheckpoint(page: ReadBookPage): Promise<void> {
    // Normal page turns are debounced. Cancel every delayed writer and persist the current chapter/page snapshot
    // immediately before Harmony freezes the UI in Home or lock-screen background transitions.
    page.settleCommittedLocalPageTurnForCheckpoint();
    page.clearReaderComicProgressSaveTimer();
    page.clearReaderPagedProgressSaveTimer();
    if (page.ttsProgressSaveTimerId >= 0) {
      clearTimeout(page.ttsProgressSaveTimerId);
      page.ttsProgressSaveTimerId = -1;
    }
    await page.saveReadingProgress(true);
}

export function restorePersistedTtsFocus(page: ReadBookPage): boolean {
    if (!page.book) return false;
    const chapterRaw = page.book.getVariable('ttsReadChapterIndex');
    const startRaw = page.book.getVariable('ttsReadOffsetStart');
    const endRaw = page.book.getVariable('ttsReadOffsetEnd');
    if (!chapterRaw || !startRaw) return false;
    const chapterIndex = Number(chapterRaw);
    const absoluteStart = Number(startRaw);
    const absoluteEnd = Number(endRaw);
    if (!Number.isFinite(chapterIndex) || chapterIndex !== page.currentChapterIndex ||
      !Number.isFinite(absoluteStart) || absoluteStart < page.ttsTextStartOffset) {
      return false;
    }
    const source = page.pagedContentText || page.getPagedSourceText();
    const start = Math.max(page.ttsTextStartOffset, Math.min(Math.round(absoluteStart), source.length));
    const end = Math.max(start, Math.min(Number.isFinite(absoluteEnd) ? Math.round(absoluteEnd) : start,
      source.length));
    const chunkStart = page.readerV2ActiveSpeechText ?
      page.readerV2ActiveSpeechText.speechOffsetAt(start) : start - page.ttsTextStartOffset;
    const chunkEnd = page.readerV2ActiveSpeechText ?
      page.readerV2ActiveSpeechText.speechOffsetAt(end) : end - page.ttsTextStartOffset;
    page.ttsLastFocusChunk = {
      text: source.substring(start, end),
      start: chunkStart,
      end: chunkEnd
    };
    return true;
}

export function activeMirroredTtsChapterIndex(page: ReadBookPage): number {
    if (!page.globalTtsActive || ReaderTtsFloatingSession.isOwner(page.ttsFloatingSessionOwnerId) ||
      !page.bookUrl || page.globalTtsBookUrl !== page.bookUrl || !Number.isFinite(page.globalTtsChapterIndex)) {
      return -1;
    }
    const chapterIndex = Math.round(page.globalTtsChapterIndex);
    return chapterIndex >= 0 && chapterIndex < page.chapters.length ? chapterIndex : -1;
}

export function isMirroringActiveTtsForCurrentBook(page: ReadBookPage): boolean {
    return page.globalTtsActive && page.globalTtsMode === 'tts' && !!page.bookUrl &&
      page.globalTtsBookUrl === page.bookUrl &&
      !ReaderTtsFloatingSession.isOwner(page.ttsFloatingSessionOwnerId);
}

export async function syncMirroredTtsFocus(page: ReadBookPage): Promise<void> {
    if (page.mirroredTtsManualTurnPending) return;
    const serial = ++page.mirroredTtsFocusSyncSerial;
    const chapterIndex = page.activeMirroredTtsChapterIndex();
    if (chapterIndex < 0 || !page.book || page.contentPages.length === 0) {
      page.clearMirroredTtsFocus();
      return;
    }
    // 全局锚点自上次应用后未变化，而镜像页已手动离开锚点（翻页提交失败/宿主不可用）：
    // 此时回拖会把用户刚翻好的页面拉回旧章节，正是“返回上一章尾页却被跳回下一章”的来源。
    const anchorOffsetStart = Math.max(0, Math.round(page.globalTtsOffsetStart));
    if (chapterIndex === page.mirroredTtsAppliedChapterIndex &&
      anchorOffsetStart === page.mirroredTtsAppliedOffsetStart) {
      const sameChapterTarget = chapterIndex === page.currentChapterIndex ?
        page.normalizeReaderSpreadPageIndex(page.findPageIndexByOffset(anchorOffsetStart)) : -1;
      if (sameChapterTarget !== page.currentPageIndex) {
        page.clearMirroredTtsFocus();
        return;
      }
    }
    // 用户刚手动翻过页：进入“脱离跟随”冷却窗口。冷却期间朗读进度即便前进，也不再立刻把
    // 视图拽回朗读句——否则在镜像模式里根本无法翻看前后文。冷却结束后才平滑重新跟随。
    if (page.mirroredTtsManualTurnPending || page.mirroredTtsFollowSuppressUntil > Date.now()) {
      return;
    }
    if (chapterIndex !== page.currentChapterIndex) {
      const loaded = await page.loadContent(true, chapterIndex);
      if (serial !== page.mirroredTtsFocusSyncSerial) return;
      if (!loaded || page.currentChapterIndex !== chapterIndex) {
        page.clearMirroredTtsFocus();
        return;
      }
    }
    const source = page.pagedContentText || page.getPagedSourceText();
    if (!source || !Number.isFinite(page.globalTtsOffsetStart)) {
      page.clearMirroredTtsFocus();
      return;
    }
    const absoluteStart = Math.max(0, Math.min(Math.round(page.globalTtsOffsetStart), source.length));
    const absoluteEnd = Math.max(absoluteStart,
      Math.min(Number.isFinite(page.globalTtsOffsetEnd) ? Math.round(page.globalTtsOffsetEnd) : absoluteStart,
        source.length));
    if (absoluteEnd <= absoluteStart) {
      // 零长度/无效锚点：保留上一次已渲染的高亮，不清除，避免每句切换瞬间高亮闪灭；
      // 仅跳过本次重定位（下次有效锚点再来时继续跟随）。
      return;
    }
    const pageIndex = page.findPageIndexByOffset(absoluteStart);
    if (pageIndex < 0 || pageIndex >= page.contentPages.length) {
      page.clearMirroredTtsFocus();
      return;
    }
    const pageStart = page.getPageStartOffset(pageIndex);
    const pageEnd = page.getPageEndOffset(pageIndex);
    const pageText = page.getPageText(pageIndex);
    page.mirroredTtsFocusActive = true;
    page.mirroredTtsAppliedChapterIndex = chapterIndex;
    page.mirroredTtsAppliedOffsetStart = absoluteStart;
    const targetPageIndex = page.normalizeReaderSpreadPageIndex(pageIndex);
    if (targetPageIndex !== page.currentPageIndex) {
      page.finishPageTurnAnimation();
      page.currentPageIndex = targetPageIndex;
      page.syncCurrentPageText();
    } else if (page.displayPageChapterIndex !== page.currentChapterIndex ||
      page.displayPageIndex !== page.currentPageIndex || !page.displayPageText) {
      page.syncCurrentPageText();
    }
    page.ttsDisplayText = pageText;
    page.ttsHighlightStart = Math.max(0, Math.min(absoluteStart - pageStart, pageText.length));
    page.ttsHighlightEnd = Math.max(page.ttsHighlightStart,
      Math.min(absoluteEnd, pageEnd) - pageStart);
    page.readerV2TtsSourceStart = absoluteStart;
    page.readerV2TtsSourceEnd = absoluteEnd;
    page.refreshReaderV2TtsOverlay();
    page.publishTtsHighlightRenderChange();
}

export function clearMirroredTtsFocus(page: ReadBookPage): void {
    if (!page.mirroredTtsFocusActive) return;
    page.mirroredTtsFocusActive = false;
    page.clearTtsHighlight();
}

export async function takeOverMirroredTtsSession(page: ReadBookPage): Promise<void> {
    if (page.ttsSessionTakeoverInProgress || page.ttsSessionTakeoverAttempted) return;
    if (page.mirroredTtsManualTurnPending || page.isPageTurning) return;
    if (page.globalTtsPaused || !page.isMirroringActiveTtsForCurrentBook()) return;
    const liveChapterIndex = page.activeMirroredTtsChapterIndex();
    const liveOffsetStart = Math.max(0, Math.round(page.globalTtsOffsetStart));
    // 句边界接管：首次只武装并镜像跟随在播句；锚点推进到下一句时才真正接管，
    // 避免当前句被旧宿主与本页先后各播一遍。
    if (page.ttsTakeoverArmedOffsetStart < 0) {
      page.ttsTakeoverArmedChapterIndex = liveChapterIndex;
      page.ttsTakeoverArmedOffsetStart = liveOffsetStart;
      page.syncMirroredTtsFocus().catch((error: Error) => {
        console.warn('同步后台朗读镜像焦点失败:', error);
      });
      return;
    }
    if (liveChapterIndex === page.ttsTakeoverArmedChapterIndex &&
      liveOffsetStart === page.ttsTakeoverArmedOffsetStart) {
      // 仍在武装时的同一句：继续镜像等待句边界。
      page.syncMirroredTtsFocus().catch((error: Error) => {
        console.warn('同步后台朗读镜像焦点失败:', error);
      });
      return;
    }
    if (!page.book || page.contentPages.length === 0) {
      // 分页未就绪：单飞有界轮询等待，超时回退镜像跟随。
      if (page.ttsSessionTakeoverStartedAt === 0) {
        page.ttsSessionTakeoverStartedAt = Date.now();
      }
      if (Date.now() - page.ttsSessionTakeoverStartedAt >= 30000) {
        page.ttsSessionTakeoverAttempted = true;
        page.ttsSessionTakeoverStartedAt = 0;
        console.warn('[TTS] takeover timed out waiting for pagination, fallback to mirror');
        return;
      }
      if (page.ttsSessionTakeoverPollScheduled) return;
      page.ttsSessionTakeoverPollScheduled = true;
      setTimeout(() => {
        page.ttsSessionTakeoverPollScheduled = false;
        page.takeOverMirroredTtsSession().catch((error: Error) => {
          console.warn('接管后台朗读会话失败:', error);
        });
      }, 500);
      return;
    }
    page.ttsSessionTakeoverAttempted = true;
    page.ttsSessionTakeoverInProgress = true;
    const anchorChapterIndex = page.activeMirroredTtsChapterIndex();
    const anchorOffsetStart = Math.max(0, Math.round(page.globalTtsOffsetStart));
    try {
      console.info(`[TTS] taking over background tts session on reader open: ` +
        `chapter=${anchorChapterIndex}, offset=${anchorOffsetStart}`);
      if (anchorChapterIndex >= 0 && anchorChapterIndex !== page.currentChapterIndex) {
        const loaded = await page.loadContent(true, anchorChapterIndex);
        if (!loaded || page.currentChapterIndex !== anchorChapterIndex) {
          console.warn('[TTS] takeover aborted: anchor chapter unavailable');
          return;
        }
      }
      if (page.globalTtsPaused || !page.isMirroringActiveTtsForCurrentBook()) return;
      // 必须在起播前先摘除镜像标志：startTtsReadingFromCurrentPosition 内部 stopOther 会让旧宿主
      // 触发 globalTtsActive=false → onGlobalTtsActiveChanged → clearMirroredTtsFocus →
      // clearTtsHighlight，把 getTtsReadingText 刚写入的 ttsTextStartOffset/readerV2ActiveSpeechText
      // 清零。清零后所有 chunk 经 readerV2TtsSourceOffset 映射到 ttsLastAppliedSourceOffset 之前，
      // 在 applyTtsChunkFocus 入口被静默丢弃——表现为“有声无高亮、不翻页”，章末 resume=0 从头重播。
      // 摘除标志后 clearMirroredTtsFocus 直接跳过，镜像期间渲染的高亮由 preserveExistingFocus 保留、
      // 起播后由引擎逐句刷新。
      page.mirroredTtsFocusActive = false;
      page.mirroredTtsAppliedChapterIndex = -1;
      page.mirroredTtsAppliedOffsetStart = -1;
      // startTtsReadingFromCurrentPosition 内部会 stopOther 停掉后台宿主并重新挂载悬浮会话；
      // preserveExistingFocus 保留镜像期间已渲染的高亮，起播后由引擎逐句刷新。
      await page.startTtsReadingFromCurrentPosition(false, false, -1, anchorOffsetStart, true);
    } finally {
      page.ttsSessionTakeoverInProgress = false;
      page.ttsSessionTakeoverStartedAt = 0;
    }
}

export function shouldRenderTtsFocus(page: ReadBookPage): boolean {
    return page.isTtsSpeaking || page.mirroredTtsFocusActive;
}

export function animateTtsToPage(page: ReadBookPage, targetPageIndex: number, chunk: TtsChunk): void {
    const target = page.normalizeReaderSpreadPageIndex(
      Math.max(0, Math.min(targetPageIndex, Math.max(0, page.contentPages.length - 1)))
    );
    if (target <= page.currentPageIndex) {
      page.updateTtsChunkHighlight(chunk, page.resolveTtsChunkPageIndex(chunk));
      return;
    }
    page.ttsPendingTargetPageIndex = Math.max(page.ttsPendingTargetPageIndex, target);
    page.ttsPendingHighlightChunk = chunk;
    if (page.ttsAutoTurningPage) {
      return;
    }
    page.runPendingTtsPageTurn();
}

export async function runPendingTtsPageTurn(page: ReadBookPage): Promise<void> {
    page.ttsAutoTurningPage = true;
    const turnSerial = page.ttsPageTurnSerial;
    try {
      while (turnSerial === page.ttsPageTurnSerial && page.isTtsSpeaking && page.ttsAutoContinue &&
        page.ttsPendingTargetPageIndex > page.currentPageIndex && page.canTurnPage(1)) {
        const targetPageIndex = page.normalizeReaderSpreadPageIndex(Math.min(
          page.ttsPendingTargetPageIndex, Math.max(0, page.contentPages.length - 1)));
        if (targetPageIndex <= page.currentPageIndex) break;
        if (targetPageIndex > page.currentPageIndex + page.getReaderPageTurnStep()) {
          await page.runTtsPageTurnAnimationTo(targetPageIndex, turnSerial);
        } else {
          await page.runTtsPageTurnAnimation(1, turnSerial);
        }
        if (turnSerial !== page.ttsPageTurnSerial) {
          return;
        }
      }
      if (turnSerial === page.ttsPageTurnSerial && page.isTtsSpeaking && page.ttsPendingHighlightChunk) {
        page.updateTtsChunkHighlight(page.ttsPendingHighlightChunk,
          page.resolveTtsChunkPageIndex(page.ttsPendingHighlightChunk));
      }
    } finally {
      if (turnSerial === page.ttsPageTurnSerial) {
        page.ttsAutoTurningPage = false;
        page.ttsPendingTargetPageIndex = -1;
        page.ttsPendingHighlightChunk = null;
        // The incoming animation surface is gone at this boundary. Publish the current chunk once
        // more to the stable page overlay so focus never remains owned only by that temporary leaf.
        page.scheduleCurrentTtsFocusRepublishAfterPageTurn();
      }
      // A user turn can arrive while the automatic TTS page animation is in
      // progress. It is queued by runPageTurnAnimation and must run as soon as
      // the automatic animation releases the page-turn lock.
      if (!page.ttsAutoTurningPage && !page.isPageTurning) {
        page.runQueuedPageTurnLater();
      }
    }
}

export async function runTtsPageTurnAnimationTo(page: ReadBookPage, targetPageIndex: number, turnSerial: number): Promise<void> {
    const target = page.normalizeReaderSpreadPageIndex(Math.max(0,
      Math.min(targetPageIndex, Math.max(0, page.contentPages.length - 1))));
    if (page.isPageTurning || target <= page.currentPageIndex) return;
    page.isPageTurning = true;
    try {
      if (!page.isPageTurnAnimationEnabled()) {
        page.applyTtsPageTarget(target, turnSerial);
        const targetText = page.getCurrentPageText();
        page.commitVisibleCurrentPageText(targetText);
        page.finishPageTurnAnimation();
        page.commitCurrentPageTextLater(page.currentChapterIndex, page.currentPageIndex, targetText);
        return;
      }
      const distance = page.getPageTurnDistance();
      page.prepareSlidePageTurn(1, 0);
      page.pageTurnCrossChapterHandoff = false;
      page.setPageTurnIncomingState(target, page.getPageText(target), true, page.currentChapterIndex,
        page.getSecondaryPageText(target), page.getPageStartOffset(target),
        page.isLandscapeDoublePageActive() ? page.getPageStartOffset(target + 1) : -1,
        page.pagedContentText);
      page.requestReaderPageCurlCapture();
      if (page.usesReaderPageCurlCanvas()) {
        await page.completeSimulationPageTurnMotion(1);
      } else {
        const duration = 140;
        animateTo({ duration: duration, curve: page.pageTurnAnimationCurve() }, () => {
          page.setPageSlideAxisOffset(-distance);
          page.pageTransitionOpacity = 1;
        });
        await LeafFns.delay(duration + 10);
      }
      page.applyTtsPageTarget(target, turnSerial);
      await page.finishAnimatedPageTurn();
    } finally {
      page.isPageTurning = false;
    }
}

export function applyTtsPageTarget(page: ReadBookPage, targetPageIndex: number, turnSerial: number): void {
    if (turnSerial !== page.ttsPageTurnSerial || !page.isTtsSpeaking || !page.ttsAutoContinue) return;
    const target = page.normalizeReaderSpreadPageIndex(Math.max(page.currentPageIndex,
      Math.min(targetPageIndex, Math.max(0, page.contentPages.length - 1))));
    page.currentPageIndex = target;
    page.syncCurrentPageText();
    if (page.contentPages.length - target <= 3) page.preloadReaderContent();
    page.scheduleReaderPagedProgressSave();
}

export async function runTtsPageTurnAnimation(page: ReadBookPage, direction: number, turnSerial: number = page.ttsPageTurnSerial): Promise<void> {
    if (page.isPageTurning || !page.canTurnPage(direction)) {
      return;
    }
    page.isPageTurning = true;
    try {
      if (!page.isPageTurnAnimationEnabled()) {
        await page.applyTtsPageTurn(direction, turnSerial);
        const targetText = page.getCurrentPageText();
        page.commitVisibleCurrentPageText(targetText);
        page.finishPageTurnAnimation();
        page.commitCurrentPageTextLater(page.currentChapterIndex, page.currentPageIndex, targetText);
      } else if (page.readerEffectivePageTurnMode() === 1) {
        await page.runTtsSlidePageTurn(direction, turnSerial);
      } else {
        await page.runTtsTapPageTurn(direction, turnSerial);
      }
    } finally {
      page.isPageTurning = false;
    }
}

export async function runTtsTapPageTurn(page: ReadBookPage, direction: number, turnSerial: number): Promise<void> {
    const distance = page.getPageTurnDistance();
    page.prepareSlidePageTurn(direction, 0);
    if (page.isSimulationPageTurnAnimation()) {
      await page.completeSimulationPageTurnMotion(direction);
    } else {
      const duration = 140;
      animateTo({ duration: duration, curve: page.pageTurnAnimationCurve() }, () => {
        page.setPageSlideAxisOffset(direction > 0 ? -distance : distance);
        page.pageTransitionOpacity = 1;
      });
      await LeafFns.delay(duration + 10);
    }
    await page.applyTtsPageTurn(direction, turnSerial);
    await page.finishAnimatedPageTurn();
}

export async function runTtsSlidePageTurn(page: ReadBookPage, direction: number, turnSerial: number): Promise<void> {
    const distance = page.getPageTurnDistance();
    page.prepareSlidePageTurn(direction, page.getPageSlideAxisOffset());
    if (page.isSimulationPageTurnAnimation()) {
      await page.completeSimulationPageTurnMotion(direction);
    } else {
      const duration = 150;
      animateTo({ duration: duration, curve: page.pageTurnAnimationCurve() }, () => {
        page.setPageSlideAxisOffset(direction > 0 ? -distance : distance);
        page.pageTransitionOpacity = 1;
      });
      await LeafFns.delay(duration + 10);
    }
    await page.applyTtsPageTurn(direction, turnSerial);
    await page.finishAnimatedPageTurn();
}

export async function applyTtsPageTurn(page: ReadBookPage, direction: number, turnSerial: number): Promise<void> {
    if (turnSerial !== page.ttsPageTurnSerial || !page.isTtsSpeaking || !page.ttsAutoContinue) {
      return;
    }
    if (direction > 0) {
      const localPageIndex = page.getLocalPageTurnTargetPageIndex(direction);
      if (localPageIndex >= 0) {
        page.currentPageIndex = localPageIndex;
        page.syncCurrentPageText();
        if (page.contentPages.length - page.currentPageIndex <= 3) {
          page.preloadReaderContent();
        }
        // Keep speech focus responsive; the existing debounce persists the latest page without
        // blocking every automatic animation on a database transaction.
        page.scheduleReaderPagedProgressSave();
      } else if (!page.isCurrentReaderPaginationComplete()) {
        // contentPages 是增量分页快照：临时尾页不是章节尾页。恢复被挂起的分页并等待窗口
        // 扩展，由后续 chunk 焦点 / syncActiveTtsFocusAfterPagination 重新定位，不能把一次
        // 跟页翻页升级成整章跳转。
        page.resumeCurrentReaderPaginationCompletion();
      } else {
        // 分页已完整仍无下一页才是真正的章末。连续朗读的跨章切换只归
        // onFinished -> continueTtsReading -> advanceTtsReadingToNextChapter 所有：这里直接
        // loadNextChapter 会绕过会话注销（contentLoadSerial++ 之后所有 chunk 回调被
        // isCurrentTtsFocusSession 静默丢弃），造成声音继续播旧章、高亮与跟页永久丢失、
        // 章末尾校验读到错乱偏移。等待音频自然结束触发受保护的章末交接。
      }
      return;
    }

    const localPageIndex = page.getLocalPageTurnTargetPageIndex(direction);
    if (localPageIndex >= 0) {
      page.currentPageIndex = localPageIndex;
      page.syncCurrentPageText();
      page.scheduleReaderPagedProgressSave();
    }
    // 反向同理：applyTtsChunkFocus 的单调偏移守卫保证朗读焦点只前进，跟页翻页不应回退
    // 跨章。原先的 loadPrevChapter 与正向属同一绕过会话注销的缺陷路径。
}

export function suspendReaderPaginationWork(page: ReadBookPage): void {
    // Stop scheduled closures without invalidating the immutable page snapshot currently owned by ArkUI.
    // onPageShow can continue the retained pagination session instead of rebuilding its Paragraph objects.
    page.readerPaginationWorkSerial++;
    page.adjacentPaginationPreloadSerial++;
    page.previousPaginationPreloadSerial++;
}

export function resumeReaderPaginationWorkAfterPageShow(page: ReadBookPage): void {
    if (!page.pagedContentText || !page.hasPagedReaderArea()) {
      page.preloadReaderContentLater();
      return;
    }
    const key = page.buildReaderPaginationCacheKey(page.currentChapterIndex, page.pagedContentText);
    const result = page.readerPaginationCache.get(key);
    if (result && !result.complete) {
      page.scheduleReaderPaginationCompletion(page.currentChapterIndex, key, result);
    }
    page.preloadReaderContentLater();
}

export function resumeCurrentReaderPaginationCompletion(page: ReadBookPage): void {
    // scheduleReaderPaginationCompletion's runBatch exits permanently once superseded, hidden or
    // evicted, and nothing re-arms it while the reader stays on the same chapter. TTS auto
    // chapter-advance can leave exactly that state behind, so the chapter-end swipe gate
    // (isCurrentReaderPaginationComplete) stays false and every forward cross-chapter turn
    // silently no-ops. getOrCreateReaderPagination re-arms the retained session (or recreates an
    // evicted one) without disturbing the visible page set: applyReaderPagination keeps it when
    // the incremental result's source is unchanged.
    if (!page.pagedContentText || !page.hasPagedReaderArea()) return;
    const result = page.getOrCreateReaderPagination(page.currentChapterIndex, page.pagedContentText);
    if (result.complete) return;
    page.applyReaderPaginationResult(result, page.pagedContentText);
}

export async function waitForReaderComicBoundaryRestore(page: ReadBookPage, timeoutMs: number = 1800): Promise<void> {
    const deadline = Date.now() + Math.max(0, timeoutMs);
    while (Date.now() < deadline &&
      (page.pendingRestorePageIndex >= 0 || page.hasReaderTypographyRestoreOffset() ||
        page.isPagedReaderAwaitingPagination() || !page.readerInitialPageReady)) {
      await LeafFns.delay(16);
    }
}

export function currentReaderSurfaceId(page: ReadBookPage, alternate: boolean, renderVersion: number, ttsRenderVersion: number): string {
    if (page.shouldUseReaderLayoutV2(page.pagedContentText)) {
      return alternate ? 'reader_current_v2_alternate' : 'reader_current_v2_primary';
    }
    const prefix = alternate ? 'reader_current_alt' : 'reader_current';
    return `${prefix}_${page.currentChapterIndex}_${page.currentPageIndex}_${page.displayPageRenderKey}_` +
      `${renderVersion}_${ttsRenderVersion}`;
}

export function currentReaderSnapshotComponentId(page: ReadBookPage): string {
    return page.currentReaderSurfaceId(page.currentReaderSurfaceIndex() !== 0,
      page.pageRenderVersion, page.ttsHighlightRenderVersion);
}

export function currentReaderPageRenderIdentity(page: ReadBookPage, renderVersion: number = page.pageRenderVersion, ttsRenderVersion: number = page.ttsHighlightRenderVersion): string {
    return LeafFns.readerPageRenderIdentity(
      'current',
      page.displayPageChapterIndex,
      page.displayPageIndex,
      renderVersion,
      ttsRenderVersion,
      page.visibleCurrentPageText(),
      page.displayPageRenderKey
    );
}

export function incomingReaderPageRenderIdentity(page: ReadBookPage, renderVersion: number, text: string): string {
    return LeafFns.readerPageRenderIdentity(
      'incoming',
      page.pageTurnIncomingChapterIndex,
      page.pageTurnIncomingPageIndex,
      renderVersion,
      0,
      text,
      page.pageTurnIncomingRenderVersion
    );
}

export function effectiveReaderPageRenderIdentity(page: ReadBookPage, pageRenderIdentity: string, chapterIndex: number, renderVersion: number, ttsRenderVersion: number, text: string): string {
    return pageRenderIdentity || LeafFns.readerPageRenderIdentity(
      'paragraph',
      chapterIndex,
      page.currentPageIndex,
      renderVersion,
      ttsRenderVersion,
      text
    );
}
