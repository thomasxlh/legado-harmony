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

export async function openPendingShortcut(page: ReadBookPage): Promise<void> {
    if (!RecentReadShortcut.isPending()) {
      return;
    }
    page.saveReadingProgress(true).catch((error: Error) => {
      console.warn('快捷入口切换前保存进度失败:', error);
    });
    try {
      await RecentReadShortcut.openPending(page.hostContext(), true);
    } catch (e) {
      console.error('打开最近阅读快捷项失败:', e);
    }
}

export function enterReaderImmersive(page: ReadBookPage): void {
    window.getLastWindow(page.hostContext()).then((mainWindow: window.Window) => {
      const bg = page.getBackgroundColor();
      const useLightIcons = page.isReaderThemeDark();
      const systemTextColor = useLightIcons ? '#D8D8D8' : '#2F261D';
      const comicMode = page.isReaderComicModeActive();
      mainWindow.setWindowBackgroundColor(bg);
      mainWindow.setWindowLayoutFullScreen(true);
      mainWindow.setWindowSystemBarEnable(comicMode || !page.readerExtendToStatusBar ?
        ['navigation', 'status'] : ['navigation']);
      mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        isStatusBarLightIcon: useLightIcons,
        statusBarContentColor: systemTextColor,
        navigationBarColor: comicMode ? '#00000000' : bg,
        isNavigationBarLightIcon: useLightIcons,
        navigationBarContentColor: systemTextColor
      });
      page.updateStatusBarSafeHeight(mainWindow);
    }).catch((err: Error) => {
      console.error('进入阅读沉浸模式失败:', err);
    });
}

export function exitReaderImmersive(page: ReadBookPage): void {
    window.getLastWindow(page.hostContext()).then((mainWindow: window.Window) => {
      mainWindow.setWindowLayoutFullScreen(true);
      mainWindow.setWindowSystemBarEnable(['navigation', 'status']);
      page.statusBarSafeHeight = 0;
    }).catch((err: Error) => {
      console.error('退出阅读沉浸模式失败:', err);
    });
}

export function updateStatusBarSafeHeight(page: ReadBookPage, mainWindow: window.Window): void {
    try {
      const avoidArea = mainWindow.getWindowAvoidAreaIgnoringVisibility(window.AvoidAreaType.TYPE_SYSTEM);
      const topHeight = px2vp(Math.max(0, avoidArea.topRect.height));
      page.applyReaderStatusBarSafeHeight(topHeight);
    } catch (err) {
      console.error('获取状态栏安全区失败:', err);
      page.applyReaderStatusBarSafeHeight(page.storedStatusBarHeight);
    }
}

export function applyReaderStatusBarSafeHeight(page: ReadBookPage, height: number): void {
    const previousHeight = page.statusBarSafeHeight;
    page.statusBarSafeHeight = Number.isFinite(height) ? Math.max(0, height) : 0;
    if (Math.abs(previousHeight - page.statusBarSafeHeight) >= 0.5 && page.hasPagedReaderArea() && page.content) {
      // The status-bar avoid area arrives asynchronously. In extended mode the reader area's
      // layout size itself does not change, so onAreaChange cannot trigger the required repagination.
      page.readerPaginationCache.clear();
      page.pageTurnPreviewKey = '';
      page.paginateContent(page.content);
    }
}

export async function prepareReaderWebFetchRuntime(page: ReadBookPage, source: BookSource | null): Promise<void> {
    const needed = LeafFns.sourceUsesWebFetchRuntime(source);
    page.readerWebFetchRuntimeNeeded = needed;
    if (!needed) return;
    const attached = await WebBookFetchRuntime.get().waitUntilAttached(3000);
    if (!attached) {
      console.warn('[ReaderOpen] WebView fetch runtime did not attach before book loading');
    }
}

export function initialReaderViewportSize(page: ReadBookPage): ReaderViewportSize {
    const storedWidth = Math.max(0, AppStorage.get<number>('readerLastPageViewWidth') || 0);
    const storedHeight = Math.max(0, AppStorage.get<number>('readerLastPageViewHeight') || 0);
    try {
      const currentDisplay = display.getDefaultDisplaySync();
      const screenWidth = Math.max(1, px2vp(currentDisplay.width));
      const screenHeight = Math.max(1, px2vp(currentDisplay.height));
      const currentLandscape = screenWidth > screenHeight;
      const storedLandscape = storedWidth > storedHeight;
      if (storedWidth > 0 && storedHeight > 0 && currentLandscape === storedLandscape) {
        return { width: storedWidth, height: storedHeight };
      }
      // The exact content area is published by onAreaChange after mount. This display-sized estimate lets the
      // current chapter start pagination before that callback, which otherwise leaves a blank opening panel for
      // several seconds on large devices. A later geometry correction preserves the character offset and reflows.
      const topInset = page.readerExtendToStatusBar ? 0 : Math.max(0, page.statusBarSafeHeight);
      return { width: screenWidth, height: Math.max(1, screenHeight - topInset) };
    } catch (_error) {
      return { width: storedWidth, height: storedHeight };
    }
}

export function resetReaderStateForBookLoad(page: ReadBookPage): void {
    page.contentLoadSerial++;
    page.cancelReaderPaginationWork(true);
    page.readerWebFetchRuntimeNeeded = false;
    page.content = '';
    page.chapters = [];
    page.tocVisibleChapters = [];
    page.tocWindowStart = 0;
    page.tocSearchVisible = false;
    page.tocSearchQuery = '';
    page.tocSearchChapterIndexes = [];
    page.tocSearchLoading = false;
    page.tocSearchResultActive = false;
    page.tocOrderRevision = 0;
    page.tocDatabaseChapterCount = 0;
    page.tocFirstVisibleGlobalIndex = 0;
    page.tocVisibleItemCount = 1;
    page.tocSearchRequestSerial++;
    page.currentChapterIndex = 0;
    page.contentPages = [];
    page.contentPageStarts = [];
    page.contentPageEnds = [];
    page.pagedContentText = '';
    page.readerParagraphMetricsCache.clear();
    page.readerTextParagraphsCache.clear();
    if (page.readerExtendLayoutRefreshTimerId >= 0) {
      clearTimeout(page.readerExtendLayoutRefreshTimerId);
      page.readerExtendLayoutRefreshTimerId = -1;
    }
    page.readerExtendLayoutReadingOffset = -1;
    page.setReaderTypographyRestoreOffset(-1);
    page.resetReaderPageCurl();
    page.currentPageIndex = 0;
    page.currentPageText = '';
    page.readerSourceActionAreas.clear();
    page.readerSourceActionScrollOffsets.clear();
    page.readerSelectableTextAreas.clear();
    page.readerSelectableTextScrollOffsets.clear();
    page.readerSelectableTextValues.clear();
    page.readerSelectableTextControllers.clear();
    page.setReaderTextSelectionActive(false);
    page.readerContinuousVisibleStart = 0;
    page.readerContinuousVisibleEnd = 0;
    page.readerContinuousReachedEnd = false;
    page.displayPageText = '';
    page.displayPageChapterIndex = 0;
    page.displayPageIndex = 0;
    page.displayPageRenderKey = 0;
    page.chapterJumpRenderGeneration = 0;
    page.readerCommentPanelMarker = '';
    page.readerCommentPanelAnchorBottom = -1;
    page.readerCommentPageAreaTop = -1;
    page.readerCommentPageAreaHeight = 0;
    const initialViewport = page.initialReaderViewportSize();
    page.pageViewWidth = initialViewport.width;
    page.pageViewHeight = initialViewport.height;
    page.readerInitialPageReady = false;
    page.readerInitialOpening = true;
    page.readerComicMode = false;
    page.readerComicImageRatios = [];
    page.clearReaderComicPaginationProgress();
    page.readerComicChapterSwitching = false;
    page.readerComicBoundaryDirection = 0;
    page.readerComicBoundaryPullDistance = 0;
    page.readerComicBoundaryReady = false;
    page.readerComicChapterTransitionY = 0;
    page.readerComicChapterTransitionOpacity = 1;
    page.readerComicBoundaryPullOriginY = 0;
    page.readerComicScrollRestoreSerial++;
    page.readerComicScrollRestoring = false;
    page.clearReaderComicProgressSaveTimer();
    page.readerComicPageDataSource.replace([]);
    page.readerComicBrokenPages = [];
    page.pendingRestorePageIndex = -1;
    page.readerProgressAnchorChapterIndex = -1;
    page.readerProgressAnchorPageIndex = 0;
    page.readerProgressAnchorOffset = -1;
    page.readerProgressAnchorPageCount = 1;
    page.readerProgressAnchorPageText = '';
    page.readerProgressAnchorPageImage = '';
    page.readerProgressRestoreConfirmed = false;
    page.pageTransitionX = 0;
    page.pageTransitionOpacity = 1;
    page.pageSlideOffsetX = 0;
    page.pageSlideOffsetY = 0;
    page.pageSlideDirection = 0;
    page.bookmarkPullOffsetY = 0;
    page.bookmarkPullActive = false;
    page.bookmarkPullReady = false;
    page.pageTurnAnimating = false;
    page.pageTurnIncomingText = '';
    page.pageTurnIncomingSecondaryText = '';
    page.pageTurnIncomingX = 0;
    page.pageTurnIncomingOpacity = 1;
    page.pageTurnIncomingPageIndex = 0;
    page.pageTurnIncomingChapterIndex = 0;
    page.pageTurnIncomingPageStart = -1;
    page.pageTurnIncomingSecondaryPageStart = -1;
    page.pageTurnIncomingDocumentSource = '';
    page.pageTurnIncomingRenderVersion = 0;
    page.isPageTurning = false;
    page.queuedPageTurnDirection = 0;
    page.queuedPageTurnStyle = '';
    page.queuedPageTurnCount = 0;
    page.queuedPageTurnVelocity = 0;
    page.pageTurnCrossChapterHandoff = false;
    page.clearPageTurnPreviewState();
    page.clearTtsHighlight();
    page.ttsSessionTakeoverAttempted = false;
    page.ttsSessionTakeoverInProgress = false;
    page.ttsSessionTakeoverStartedAt = 0;
    page.ttsSessionTakeoverPollScheduled = false;
    page.pageRenderVersion++;
}

export async function loadContent(page: ReadBookPage, silent: boolean = false, targetChapterIndex: number = page.currentChapterIndex, preferImmediatePagination: boolean = false): Promise<boolean> {
    if (page.chapters.length === 0) {
      page.setReaderContent(page.buildBookPreview());
      page.isLoading = false;
      return false;
    }
    
    const engine = ReadBookEngine.get();
    if (engine.book?.bookUrl !== (page.book?.bookUrl || page.bookUrl)) return false;
    const chapterIndex = page.clampChapterIndex(targetChapterIndex);
    const loadSerial = ++page.contentLoadSerial;
    page.readerContentLoadInFlight++;
    const showLoading = !silent && !engine.hasCachedContent(chapterIndex);
    if (showLoading) {
      page.isLoading = true;
      page.loadStatus = '正在加载章节内容...';
    }
    try {
      // 挂起兜底：取文链可能永不返回，超时按获取失败处理，避免永远停在加载遮罩上。
      let body = await page.withReaderFetchTimeout(engine.loadContent(chapterIndex), READER_CONTENT_FETCH_TIMEOUT_MS);
      if (loadSerial !== page.contentLoadSerial) {
        return false;
      }
      if (body === null) {
        // 超时兜底：放弃引擎里仍挂起的取文任务，防止后续重试 join 同一个永不完结的 Promise 反复失败。
        engine.abandonChapterLoad(chapterIndex);
        body = '';
      }
      let loadedContent = await page.prepareReaderContentRules(body, chapterIndex);
      ReaderOpenTrace.mark(page.bookUrl, 'content-preprocessed', `length=${loadedContent.length}`);
      if (loadSerial !== page.contentLoadSerial) {
        return false;
      }
      // Commit the chapter identity only after the asynchronous fetch and preprocessing both
      // succeeded. A rejected/stale load must not leave the reader pointing at a new chapter
      // while it still owns the previous chapter's content.
      const chapterChanged = page.currentChapterIndex !== chapterIndex;
      page.currentChapterIndex = chapterIndex;
      if (chapterChanged) {
        page.readerContinuousReachedEnd = false;
        // readerTypographyRestoreOffset 是上一章的重排恢复锚点，坐标系不跨章。若不清除，
        // restoreReaderTypographyOffsetIfAvailable 会把旧章偏移映射到新章分页（先跳深页再弹回），
        // 覆盖 pendingRestorePageIndex 的落页意图（朗读自动切章跳“下一章末页再回第一页”即此路径）。
        page.setReaderTypographyRestoreOffset(-1);
      }
      page.closeReaderCommentPanel();
      page.readerComicImageRatios = [];
      if (body) {
        page.content = loadedContent;
        page.chapters = [...engine.chapters];
      } else {
        page.updatePendingVerification();
        const c = page.chapters[chapterIndex];
        loadedContent = page.verificationUrl ? `${c ? c.title : '当前章节'}\n\n该书源需要先完成网页验证。请点击右上角“更多操作”，选择“登录”，完成后返回，再从该菜单选择“重试”。` :
          (c ? `${c.title}\n\n章节正文加载失败。请点击右上角“刷新本章”或“换源”。` :
            '章节正文加载失败。请点击右上角“更多操作”，选择“重试”。');
        page.content = loadedContent;
      }
      page.detectReaderComicMode(loadedContent);
      let restoredPagination = body ?
        page.applyPreparedReaderPagination(loadedContent, chapterIndex, preferImmediatePagination) : false;
      if (body && !restoredPagination && !preferImmediatePagination) {
        restoredPagination = await page.restorePersistedReaderPagination(loadedContent, chapterIndex);
      }
      if (loadSerial !== page.contentLoadSerial) {
        return false;
      }
      if (!restoredPagination) {
        page.paginateContent(loadedContent, chapterIndex);
      }
      ReaderOpenTrace.mark(page.bookUrl, 'pagination-published',
        `pages=${page.contentPages.length} restored=${restoredPagination}`);
      // Let the restored/current page win the first frame before network and native-Paragraph work for
      // neighbouring chapters starts competing for the UI thread.
      page.preloadReaderContentLater(720);
      const publishedSource = page.pagedContentText || page.getPagedSourceText();
      // 会话孤儿检测：本次提交让内容换代，而朗读焦点会话仍绑定旧代内容（菜单/目录直接切章、
      // 音量键等未经 stopTtsReaderForChapterSwitch / advanceTtsReadingToNextChapter 的路径）。
      // 受保护的切换路径都会先 invalidateTtsFocusSession（serial 置 -1），不会进入此分支。
      // 旧实现只靠 isCurrentTtsFocusSession 的 serial 比对把后续 chunk 回调静默丢弃：声音继续
      // 播旧章、高亮冻结在旧位置、章末尾校验读到陈旧偏移。这里显式注销旧会话并按新内容重新
      // 锚定朗读，保持“继续听”的语义；正文加载失败（占位文案）不可朗读，直接停止。
      if (page.isTtsSpeaking && page.ttsAutoContinue &&
        page.ttsFocusContentLoadSerial >= 0 && page.ttsFocusContentLoadSerial !== page.contentLoadSerial) {
        console.warn(`[TTS] active focus session orphaned by content load: ` +
          `focusSerial=${page.ttsFocusContentLoadSerial},loadSerial=${loadSerial},` +
          `chapter=${chapterIndex}`);
        if (body) {
          page.invalidateTtsFocusSession();
          page.ttsLastFocusChunk = null;
          page.ttsLastFocusPageIndex = -1;
          page.clearTtsHighlight();
          page.startTtsReadingFromCurrentPosition(false).catch((e: Error) => {
            console.warn('[TTS] re-anchor reading after content load failed:', e);
          });
        } else {
          // 正文加载失败：内容已被占位文案替换，旧朗读文本不复存在。完整收尾
          // （ttsAutoContinue=false）防止迟到的 onFinished 在死会话上重启连续朗读。
          page.finishTtsReading();
        }
      }
      return !!body && page.currentChapterIndex === chapterIndex && publishedSource.length > 0;
    } catch (e) {
      console.error('加载内容失败:', e);
      if (loadSerial === page.contentLoadSerial && !page.content) {
        // 初开时失败也要落到可操作的失败态，不能让“正在打开书籍…”遮罩永久挡住全部交互。
        page.updatePendingVerification();
        const c = page.chapters[chapterIndex];
        page.setReaderContent(page.verificationUrl ?
          `${c ? c.title : '当前章节'}\n\n该书源需要先完成网页验证。请点击右上角“更多操作”，选择“登录”，完成后返回，再从该菜单选择“重试”。` :
          (c ? `${c.title}\n\n章节正文加载失败。请点击右上角“刷新本章”或“换源”。` :
            '章节正文加载失败。请点击右上角“更多操作”，选择“重试”。'));
      }
      return false;
    } finally {
      page.readerContentLoadInFlight = Math.max(0, page.readerContentLoadInFlight - 1);
      if (page.readerContentLoadInFlight === 0) {
        page.isLoading = false;
        page.loadStatus = '';
      }
      page.updatePendingVerification();
    }
}

export async function refreshCurrentChapter(page: ReadBookPage): Promise<void> {
    if (page.chapters.length === 0) {
      return;
    }

    const engine = ReadBookEngine.get();
    const chapterIndex = page.currentChapterIndex;
    // Treat an explicit reload as a new content generation. Previously reloadContent() replaced `content` while
    // the old incremental pagination session, retained V2 document and TTS source mapping remained alive. When the
    // source happened to keep the same cache identity,正文 could reset to page one but TTS rectangles were still
    // resolved through the detached document and stayed invisible even after a page turn.
    const refreshSerial = ++page.contentLoadSerial;
    page.readerContentLoadInFlight++;
    page.isLoading = true;
    page.loadStatus = '正在刷新本章...';
    // Mark the refresh busy before stopping TTS so its delayed sentence checkpoint cannot race the explicit
    // page-one progress written after the replacement pagination has been published.
    page.stopTtsReading();
    page.readerPreparedContentCache.clear();
    try {
      let body = await page.withReaderFetchTimeout(engine.reloadContent(chapterIndex),
        READER_CONTENT_FETCH_TIMEOUT_MS);
      if (refreshSerial !== page.contentLoadSerial || chapterIndex !== page.currentChapterIndex) return;
      if (body === null) {
        // 超时兜底：放弃引擎里仍挂起的取文任务，防止再次刷新 join 同一个永不完结的 Promise 反复失败。
        engine.abandonChapterLoad(chapterIndex);
        body = '';
      }
      if (body) {
        const processedBody = await page.prepareReaderContentRules(body, chapterIndex);
        if (refreshSerial !== page.contentLoadSerial || chapterIndex !== page.currentChapterIndex) return;
        // Cancel every producer and retained consumer derived from the previous正文 before publishing the new one.
        // The surface generation is necessary because NodeContainer may retain the old controller even after the
        // controller map has been cleared; a remount keeps正文、分页边界 and TTS source offsets on one generation.
        page.finishPageTurnAnimation(false);
        page.clearQueuedReaderPageTurns();
        page.cancelReaderPaginationWork(true);
        page.readerV2SurfaceGeneration++;
        page.readerV2ActiveSpeechText = null;
        page.setReaderTypographyRestoreOffset(-1);
        page.readerInitialPageReady = false;
        page.contentPages = [];
        page.contentPageStarts = [];
        page.contentPageEnds = [];
        page.pagedContentText = '';
        page.readerComicImageRatios = [];
        page.content = processedBody;
        page.detectReaderComicMode(processedBody);
        page.chapters = [...engine.chapters];
        page.pendingRestorePageIndex = 0;
        page.currentPageIndex = 0;
        page.paginateContent(processedBody, chapterIndex);
        page.forceCurrentReaderPageRender();
        page.refreshCurrentReaderV2RetainedPages(true);
        page.preloadReaderContentLater(720);
        await page.saveReadingProgress();
        if (refreshSerial !== page.contentLoadSerial || chapterIndex !== page.currentChapterIndex) return;
        HdsFeedback.showToast('本章已刷新');
      } else {
        if (refreshSerial !== page.contentLoadSerial || chapterIndex !== page.currentChapterIndex) return;
        page.updatePendingVerification();
        const chapter = page.chapters[chapterIndex];
        const loadedContent = page.verificationUrl ? `${chapter ? chapter.title : '当前章节'}\n\n该书源需要先完成网页验证。请点击右上角“更多操作”，选择“登录”，完成后返回，再从该菜单选择“重试”。` :
          (chapter ? `${chapter.title}\n\n章节正文刷新失败。请再次点击右上角“刷新本章”或“换源”。` :
            '章节正文刷新失败。请点击右上角“更多操作”，选择“重试”。');
        page.content = loadedContent;
        page.paginateContent(loadedContent);
        HdsFeedback.showToast('刷新本章失败');
      }
    } catch (e) {
      console.error('刷新本章失败:', e);
      HdsFeedback.showToast('刷新本章失败');
    } finally {
      page.readerContentLoadInFlight = Math.max(0, page.readerContentLoadInFlight - 1);
      if (page.readerContentLoadInFlight === 0) {
        page.isLoading = false;
        page.loadStatus = '';
      }
      page.updatePendingVerification();
    }
}

export function readerCachePanelStatus(page: ReadBookPage): string {
    if (page.fullTextCaching) {
      return page.fullTextCacheStatus || page.fullTextCacheProgressText();
    }
    return page.readerCacheStatus;
}

export function closeReaderCacheDialog(page: ReadBookPage): void {
    page.readerCacheLoadSerial++;
    page.showReaderCacheDialog = false;
    page.showReaderChapterCacheDialog = false;
    page.readerCacheChapters = [];
    page.readerCacheStatus = '';
    page.readerCacheRangeDraft = '';
}

export async function refreshReaderCacheChapters(page: ReadBookPage): Promise<void> {
    const bookUrl = page.book?.bookUrl || page.bookUrl;
    if (!bookUrl) return;
    const serial = ++page.readerCacheLoadSerial;
    try {
      const engine = ReadBookEngine.get();
      if (engine.book?.bookUrl !== bookUrl) return;
      await engine.syncChapterCacheDates();
      if (serial !== page.readerCacheLoadSerial || page.book?.bookUrl !== bookUrl) return;
      page.chapters = [...engine.chapters];
      page.readerCacheChapters = [...engine.chapters];
      const cachedCount = LeafFns.countCachedChapters(engine.chapters);
      if (!page.readerCacheRangeCaching) {
        page.readerCacheStatus = engine.chapters.length > 0 ?
          `${cachedCount}章已缓存 ${engine.chapters.length - cachedCount}章待缓存` : '暂未获取到目录';
      }
    } catch (error) {
      console.warn('读取阅读页缓存目录失败:', error);
      if (serial === page.readerCacheLoadSerial) page.readerCacheStatus = '目录加载失败，请稍后重试';
    }
}

export function readerCachedChapterTextColor(page: ReadBookPage): string {
    return page.isReaderThemeDark() ? '#DDEFE5' : '#244B35';
}

export async function cacheReaderSingleChapter(page: ReadBookPage, index: number): Promise<void> {
    await page.cacheReaderChapterIndexes([index]);
}

export async function cacheReaderChapterRange(page: ReadBookPage): Promise<void> {
    const total = page.readerCacheChapters.length > 0 ? page.readerCacheChapters.length : page.chapters.length;
    const indexes = LeafFns.parseReaderChapterRange(page.readerCacheRangeDraft, total);
    if (indexes.length === 0) {
      HdsFeedback.showToast(`请输入有效章节范围（1-${total}）`);
      return;
    }
    await page.cacheReaderChapterIndexes(indexes);
}

export async function cacheReaderChapterIndexes(page: ReadBookPage, indexes: number[]): Promise<void> {
    if (!page.book || LocalBookService.isLocalBook(page.book) || page.fullTextCaching ||
      page.readerCacheRangeCaching || indexes.length === 0) {
      return;
    }
    const targetBook = page.book;
    page.readerCacheRangeCaching = true;
    page.readerCacheRangeCancelRequested = false;
    let successCount = 0;
    let failedCount = 0;
    try {
      const engine = ReadBookEngine.createBackgroundWorker();
      await engine.openBook(targetBook);
      await engine.syncChapterCacheDates();
      for (const index of indexes) {
        if (page.readerCacheRangeCancelRequested) break;
        const chapter = engine.chapters[index];
        if (!chapter || chapter.cacheDate > 0) continue;
        page.readerCacheStatus = `正在缓存第 ${index + 1} 章...`;
        let cached = false;
        for (let attempt = 0; attempt < 2 && !cached; attempt++) {
          try {
            cached = await engine.cacheChapter(index);
          } catch (error) {
            if (attempt === 1) console.warn(`缓存第 ${index + 1} 章失败:`, error);
          }
          if (!cached && attempt === 0) await LeafFns.sleep(300);
        }
        if (cached) {
          successCount++;
          if (LeafFns.syncRenderedChapterCacheDates(page.readerCacheChapters, engine.chapters)) {
            page.readerCacheChapters = [...page.readerCacheChapters];
          }
          if (LeafFns.syncRenderedChapterCacheDates(page.tocVisibleChapters, engine.chapters)) {
            page.tocVisibleChapters = [...page.tocVisibleChapters];
          }
        } else {
          failedCount++;
        }
        await LeafFns.sleep(0);
      }
      await engine.syncChapterCacheDates();
      page.chapters = [...engine.chapters];
      page.readerCacheChapters = [...engine.chapters];
      page.readerCacheStatus = page.readerCacheRangeCancelRequested ? '缓存已取消' :
        (failedCount > 0 ?
          `缓存完成：${successCount}章成功，${failedCount}章失败` :
          (successCount > 0 ? `已缓存 ${successCount} 章` : '所选章节均已缓存'));
      HdsFeedback.showToast(page.readerCacheRangeCancelRequested ? '缓存已取消' :
        (failedCount > 0 ? `缓存完成，${failedCount} 章失败` : `已缓存 ${successCount} 章`));
      AppStorage.setOrCreate('shelfUpdateTime', Date.now());
    } catch (error) {
      console.error('阅读页缓存指定章节失败:', error);
      page.readerCacheStatus = '章节缓存失败';
      HdsFeedback.showToast('章节缓存失败');
    } finally {
      page.readerCacheRangeCaching = false;
      page.readerCacheRangeCancelRequested = false;
    }
}

export function cancelReaderChapterRangeCache(page: ReadBookPage): void {
    if (!page.readerCacheRangeCaching || page.readerCacheRangeCancelRequested) return;
    page.readerCacheRangeCancelRequested = true;
    page.readerCacheStatus = '正在停止缓存…';
}

export async function clearReaderCachedChapters(page: ReadBookPage): Promise<void> {
    if (!page.book || page.fullTextCaching || page.readerCacheRangeCaching) return;
    const bookUrl = page.book.bookUrl;
    if (!bookUrl) return;
    try {
      const db = AppDatabase.getInstance();
      await db.initWithContext(page.hostContext());
      await db.deleteBookCachedContent(bookUrl);
      const engine = ReadBookEngine.get();
      if (engine.book?.bookUrl === bookUrl) {
        engine.clearCurrentBookMemoryCache();
        await engine.syncChapterCacheDates();
        page.chapters = [...engine.chapters];
        page.readerCacheChapters = [...engine.chapters];
      } else {
        page.readerCacheChapters = page.readerCacheChapters.map((chapter: BookChapter) => {
          chapter.cacheDate = 0;
          return chapter;
        });
      }
      page.readerCacheStatus = '已清除缓存章节';
      HdsFeedback.showToast('已清除缓存章节');
      AppStorage.setOrCreate('shelfUpdateTime', Date.now());
    } catch (error) {
      console.error('阅读页清除缓存章节失败:', error);
      page.readerCacheStatus = '清除缓存失败';
      HdsFeedback.showToast('清除缓存失败');
    }
}

export function startFullTextCache(page: ReadBookPage, startIndex: number = 0): void {
    if (page.fullTextCaching) {
      HdsFeedback.showToast(page.fullTextCacheStatus || '全文缓存正在后台进行');
      return;
    }
    if (!page.book || page.chapters.length === 0 || !page.book.origin || page.book.origin === 'local') {
      HdsFeedback.showToast('当前书籍暂无可缓存章节');
      return;
    }
    if (startIndex > 0 && startIndex >= page.chapters.length) {
      HdsFeedback.showToast('当前章之后没有更多章节');
      return;
    }

    page.fullTextCacheStartIndex = Math.max(0, Math.floor(startIndex));
    page.hideReaderPanels();
    HdsFeedback.showToast('已转入后台缓存，可在通知栏取消');
    page.runFullTextCache(++page.fullTextCacheTaskId).catch(async (error: Error): Promise<void> => {
      if (page.fullTextCacheCancelRequested) {
        if (page.fullTextCacheStoppingNotificationTask) await page.fullTextCacheStoppingNotificationTask;
        page.fullTextCaching = false;
        page.fullTextCacheStatus = `${page.fullTextCacheScopeLabel()}缓存已取消`;
        await page.publishFullTextCacheNotification('缓存已停止', page.fullTextCacheProgressText(), false);
        await page.stopFullTextCacheBackgroundRunning();
        page.releaseFullTextCacheCancelRegistration();
        page.fullTextCacheCancelRequested = false;
        return;
      }
      page.releaseFullTextCacheCancelRegistration();
      console.error('全文缓存任务失败:', error);
      page.fullTextCaching = false;
      page.fullTextCacheStatus = '全文缓存失败';
      HdsFeedback.showToast('全文缓存失败');
      page.publishFullTextCacheNotification('全文缓存失败', page.fullTextCacheProgressText(), false).catch((e: Error) => {
        console.warn('更新全文缓存失败通知失败:', e);
      });
      page.stopFullTextCacheBackgroundRunning().catch((e: Error) => {
        console.warn('停止全文缓存后台任务失败:', e);
      });
    });
}

export function cancelFullTextCache(page: ReadBookPage): void {
    if (!page.fullTextCaching || page.fullTextCacheCancelRequested) return;
    if (page.fullTextCacheTaskKey) {
      FullTextCacheCancelCoordinator.request(page.fullTextCacheTaskKey,
        page.book?.bookUrl || page.bookUrl);
      return;
    }
    page.beginStoppingFullTextCache(FullTextCacheCancelCoordinator.nextNonce(), true);
}

export function fullTextCacheScopeLabel(page: ReadBookPage): string {
    return page.fullTextCacheStartIndex > 0 ? '后续章节' : '全文';
}

export async function runFullTextCache(page: ReadBookPage, taskId: number): Promise<void> {
    const engine = ReadBookEngine.get();
    if (!engine.book || engine.chapters.length === 0) {
      return;
    }

    page.fullTextCaching = true;
    page.fullTextCacheCancelRequested = false;
    page.fullTextCacheCancelSeenNonce = AppStorage.get<number>('fullTextCacheCancelNonce') || 0;
    page.fullTextCacheNotificationLastAt = 0;
    page.fullTextCacheCancelAgent = null;
    page.fullTextCacheStoppingNotificationTask = null;
    page.fullTextCacheTaskKey = `reader_${taskId}_${Date.now()}`;
    FullTextCacheCancelCoordinator.register(page.fullTextCacheTaskKey, engine.book.bookUrl,
      (signal: FullTextCacheCancelSignal): void => {
        if (FullTextCacheCancelCoordinator.matches(signal, page.fullTextCacheTaskKey, engine.book?.bookUrl || '')) {
          page.beginStoppingFullTextCache(signal.nonce, true);
        }
      });
    await engine.syncChapterCacheDates();
    page.chapters = [...engine.chapters];
    page.fullTextCacheTotal = engine.chapters.length - page.fullTextCacheStartIndex;
    page.fullTextCacheDone = LeafFns.countCachedChaptersFrom(engine.chapters, page.fullTextCacheStartIndex);
    page.fullTextCacheStatus = `${page.fullTextCacheScopeLabel()}缓存后台进行中`;

    await page.startFullTextCacheBackgroundRunning();
    await page.requestFullTextCacheNotificationEnabled();
    await page.publishFullTextCacheProgress(true);

    for (let index = page.fullTextCacheStartIndex; index < engine.chapters.length; index++) {
      if (taskId !== page.fullTextCacheTaskId || page.shouldCancelFullTextCache()) {
        break;
      }
      const chapter = engine.chapters[index];
      if (!chapter || chapter.cacheDate > 0) {
        continue;
      }

      const ok = await page.cacheFullTextChapter(engine, index, taskId);
      if (taskId !== page.fullTextCacheTaskId) {
        break;
      }
      if (ok) {
        page.fullTextCacheDone = LeafFns.countCachedChaptersFrom(engine.chapters, page.fullTextCacheStartIndex);
        page.chapters = [...engine.chapters];
        page.tocVisibleChapters = [...page.tocVisibleChapters];
      }
      if (page.shouldCancelFullTextCache()) break;
      await page.publishFullTextCacheProgress(false);
      await LeafFns.sleep(0);
    }

    if (taskId !== page.fullTextCacheTaskId) {
      page.releaseFullTextCacheCancelRegistration();
      return;
    }

    const canceled = page.shouldCancelFullTextCache();
    await engine.syncChapterCacheDates();
    page.chapters = [...engine.chapters];
    page.fullTextCacheDone = LeafFns.countCachedChaptersFrom(engine.chapters, page.fullTextCacheStartIndex);
    page.fullTextCaching = false;
    const failedCount = Math.max(0, page.fullTextCacheTotal - page.fullTextCacheDone);
    page.fullTextCacheStatus = canceled ? `${page.fullTextCacheScopeLabel()}缓存已取消` :
      (failedCount > 0 ? `缓存结束，仍有 ${failedCount} 章未缓存（${page.fullTextCacheDone}/${page.fullTextCacheTotal}）` :
        `${page.fullTextCacheScopeLabel()}缓存完成`);
    if (canceled && page.fullTextCacheStoppingNotificationTask) {
      await page.fullTextCacheStoppingNotificationTask;
    }
    await page.publishFullTextCacheNotification(
      canceled ? '缓存已停止' : page.fullTextCacheStatus,
      page.fullTextCacheProgressText(),
      false
    );
    // 失败章数显式告知：避免用户误以为“全书已缓存”而离线时打不开漏缓存的章节。
    if (canceled) {
      HdsFeedback.showToast('缓存已停止');
    } else if (failedCount > 0) {
      HdsFeedback.showToast(`缓存结束，仍有 ${failedCount} 章未缓存（网络差或书源限制），离线可能打不开这些章节`);
    } else {
      HdsFeedback.showToast(`${page.fullTextCacheScopeLabel()}缓存完成`);
    }
    await page.stopFullTextCacheBackgroundRunning();
    page.releaseFullTextCacheCancelRegistration();
    page.fullTextCacheCancelRequested = false;
}

export function beginStoppingFullTextCache(page: ReadBookPage, nonce: number, showHint: boolean): void {
    if (!page.fullTextCaching || page.fullTextCacheCancelRequested) return;
    page.fullTextCacheCancelRequested = true;
    page.fullTextCacheCancelSeenNonce = nonce;
    page.fullTextCacheStatus = '正在停止缓存…';
    ReadBookEngine.get().cancelPendingRequests();
    page.fullTextCacheStoppingNotificationTask = page.publishFullTextCacheNotification(
      '正在停止缓存…', page.fullTextCacheProgressText(), true)
      .catch((error: Error) => console.warn('更新正在停止缓存通知失败:', error));
    if (showHint) HdsFeedback.showToast('正在停止缓存…');
}

export function releaseFullTextCacheCancelRegistration(page: ReadBookPage): void {
    FullTextCacheCancelCoordinator.unregister(page.fullTextCacheTaskKey);
    page.fullTextCacheTaskKey = '';
    page.fullTextCacheStoppingNotificationTask = null;
}

export function shouldCancelFullTextCache(page: ReadBookPage): boolean {
    if (page.fullTextCacheCancelRequested) {
      return true;
    }
    const nonce = AppStorage.get<number>('fullTextCacheCancelNonce') || 0;
    if (nonce > 0 && nonce !== page.fullTextCacheCancelSeenNonce) {
      const signal = FullTextCacheCancelCoordinator.parse(
        AppStorage.get<string>('fullTextCacheCancelSignal') || '');
      if (signal && !FullTextCacheCancelCoordinator.matches(signal, page.fullTextCacheTaskKey,
        page.book?.bookUrl || page.bookUrl)) {
        page.fullTextCacheCancelSeenNonce = nonce;
        return false;
      }
      page.beginStoppingFullTextCache(signal ? signal.nonce : nonce, false);
      return page.fullTextCacheCancelRequested;
    }
    return false;
}

export function clearReaderScreenTimeoutTimer(page: ReadBookPage): void {
    if (page.readerScreenTimeoutTimerId >= 0) {
      clearTimeout(page.readerScreenTimeoutTimerId);
      page.readerScreenTimeoutTimerId = -1;
    }
}

export function applyReaderScreenTimeout(page: ReadBookPage): void {
    page.clearReaderScreenTimeoutTimer();
    const serial = ++page.readerScreenTimeoutSerial;
    if (!page.readerPageVisible) {
      page.setReaderWindowKeepScreenOn(false, serial);
      return;
    }
    const minutes = ReaderSettingsStore.normalizeScreenTimeoutMinutes(page.readerScreenTimeoutMinutes);
    if (minutes === ReaderSettingsStore.SCREEN_TIMEOUT_FOLLOW_SYSTEM) {
      page.setReaderWindowKeepScreenOn(false, serial);
      return;
    }
    page.setReaderWindowKeepScreenOn(true, serial);
    if (minutes > 0) {
      page.readerScreenTimeoutTimerId = setTimeout(() => {
        if (serial !== page.readerScreenTimeoutSerial) {
          return;
        }
        page.readerScreenTimeoutTimerId = -1;
        page.setReaderWindowKeepScreenOn(false, serial);
      }, minutes * 60 * 1000);
    }
}

export function refreshReaderScreenTimeout(page: ReadBookPage): void {
    if (page.readerPageVisible && page.readerScreenTimeoutMinutes > 0) {
      page.applyReaderScreenTimeout();
    }
}

export function releaseReaderScreenTimeout(page: ReadBookPage): void {
    page.clearReaderScreenTimeoutTimer();
    const serial = ++page.readerScreenTimeoutSerial;
    page.setReaderWindowKeepScreenOn(false, serial);
}

export function setReaderWindowKeepScreenOn(page: ReadBookPage, enabled: boolean, serial: number): void {
    window.getLastWindow(page.hostContext()).then((mainWindow: window.Window) => {
      if (serial !== page.readerScreenTimeoutSerial) {
        return;
      }
      mainWindow.setWindowKeepScreenOn(enabled).catch((error: Error) => {
        console.warn('设置阅读页亮屏状态失败:', error);
      });
    }).catch((error: Error) => {
      console.warn('获取阅读页窗口失败:', error);
    });
}

export async function cacheFullTextChapter(page: ReadBookPage, engine: ReadBookEngine, chapterIndex: number, taskId: number): Promise<boolean> {
    for (let attempt = 0; attempt < 2; attempt++) {
      if (taskId !== page.fullTextCacheTaskId || page.shouldCancelFullTextCache()) {
        return false;
      }
      try {
        if (await engine.cacheChapter(chapterIndex,
          (): boolean => taskId !== page.fullTextCacheTaskId || page.shouldCancelFullTextCache())) {
          return true;
        }
      } catch (error) {
        if (!page.shouldCancelFullTextCache()) {
          console.warn(`缓存第 ${chapterIndex + 1} 章失败（第 ${attempt + 1} 次）:`, error);
        }
      }
      if (attempt === 0) {
        await LeafFns.sleep(300);
      }
    }
    return false;
}

export function fullTextCacheProgressText(page: ReadBookPage): string {
    const total = Math.max(page.fullTextCacheTotal, 0);
    if (total === 0) {
      return '正在准备缓存章节';
    }
    const done = Math.max(0, Math.min(page.fullTextCacheDone, total));
    const percent = Math.floor((done / total) * 100);
    return `已缓存 ${done}/${total} 章（${percent}%）`;
}

export async function publishFullTextCacheProgress(page: ReadBookPage, force: boolean): Promise<void> {
    const now = Date.now();
    if (!force && now - page.fullTextCacheNotificationLastAt < FULL_TEXT_CACHE_NOTIFICATION_INTERVAL_MS) {
      return;
    }
    page.fullTextCacheNotificationLastAt = now;
    await page.publishFullTextCacheNotification(page.fullTextCacheStatus || `${page.fullTextCacheScopeLabel()}缓存后台进行中`,
      page.fullTextCacheProgressText(), true);
}

export async function publishFullTextCacheNotification(page: ReadBookPage, text: string, additionalText: string, ongoing: boolean): Promise<void> {
    try {
      const request: notificationManager.NotificationRequest = {
        id: 2601,
        label: 'full_text_cache',
        notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
        isOngoing: ongoing,
        tapDismissed: false,
        isAlertOnce: true,
        autoDeletedTime: ongoing ? undefined : Date.now() + 5000,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: page.book?.name ? `缓存${page.fullTextCacheScopeLabel()}：${page.book.name}` : `缓存${page.fullTextCacheScopeLabel()}`,
            text: text,
            additionalText: additionalText
          }
        }
      };
      if (ongoing) {
        request.actionButtons = [{
          title: '×',
          wantAgent: await page.getFullTextCacheCancelWantAgent()
        }];
      }
      await notificationManager.publish(request);
    } catch (error) {
      console.warn('发布全文缓存通知失败:', error);
    }
}

export async function requestFullTextCacheNotificationEnabled(page: ReadBookPage): Promise<void> {
    try {
      if (await notificationManager.isNotificationEnabled()) {
        return;
      }
      await notificationManager.requestEnableNotification(page.hostContext() as common.UIAbilityContext);
    } catch (error) {
      console.warn('请求通知权限失败:', error);
    }
}

export async function getFullTextCacheCancelWantAgent(page: ReadBookPage): Promise<WantAgent> {
    if (page.fullTextCacheCancelAgent) {
      return page.fullTextCacheCancelAgent;
    }
    const context = page.hostContext() as common.UIAbilityContext;
    page.fullTextCacheCancelAgent = await wantAgent.getWantAgent({
      wants: [{
        bundleName: context.abilityInfo.bundleName,
        abilityName: 'EntryAbility',
        parameters: {
          cacheAction: 'cancelFullTextCache',
          cacheTaskId: page.fullTextCacheTaskId,
          cacheTaskKey: page.fullTextCacheTaskKey,
          bookUrl: page.book?.bookUrl || page.bookUrl
        }
      }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 2602,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    });
    return page.fullTextCacheCancelAgent;
}

export async function startFullTextCacheBackgroundRunning(page: ReadBookPage): Promise<void> {
    if (page.fullTextCacheBackgroundRunning) {
      return;
    }
    if (page.isTtsBackgroundRunning()) {
      page.fullTextCacheBackgroundRunning = true;
      return;
    }
    try {
      const agent = await page.createFullTextCacheOpenWantAgent();
      await backgroundTaskManager.startBackgroundRunning(page.hostContext(), ['dataTransfer'], agent);
      page.fullTextCacheBackgroundRunning = true;
    } catch (error) {
      console.warn('启动全文缓存后台任务失败:', error);
    }
}

export async function stopFullTextCacheBackgroundRunning(page: ReadBookPage): Promise<void> {
    if (!page.fullTextCacheBackgroundRunning) {
      return;
    }
    page.fullTextCacheBackgroundRunning = false;
    if (page.isTtsBackgroundRunning() || page.isTtsBackgroundRequesting()) {
      return;
    }
    try {
      await backgroundTaskManager.stopBackgroundRunning(page.hostContext());
    } catch (error) {
      console.warn('停止全文缓存后台任务失败:', error);
    }
}

export async function createFullTextCacheOpenWantAgent(page: ReadBookPage): Promise<WantAgent> {
    const context = page.hostContext() as common.UIAbilityContext;
    return await wantAgent.getWantAgent({
      wants: [{
        bundleName: context.abilityInfo.bundleName,
        abilityName: 'EntryAbility',
        parameters: {
          bookUrl: page.bookUrl || ''
        }
      }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 2603,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    });
}

export function finishReaderInitialOpening(page: ReadBookPage): void {
    // 以“镜像页”身份打开（后台朗读宿主仍是隐藏的原阅读页，本页只是镜像）：首屏初始页码来自
    // 保存的阅读进度，可能滞后于“正在朗读”的实时句子位置。必须等首屏正文分页就绪后立刻把视图
    // 定位到实时朗读锚点，否则要等到下一句推送 globalTtsRevision 才跳转，表现为“先停在旧页、下一句
    // 才闪一下跳到正在朗读处”。onPageShow 里 0/180ms 的同步此时正文尚未分页，会提前 return。
    if (page.isMirroringActiveTtsForCurrentBook()) {
      page.syncMirroredTtsFocus().then(() => {
        page.scheduleCurrentTtsFocusRepublishAfterPageTurn();
      }).catch((error: Error) => {
        console.warn('镜像页首屏对齐后台朗读实时位置失败:', error);
      });
    }
    page.readerInitialOpening = false;
    AppStorage.setOrCreate<boolean>('shelfReaderDirectTransition', false);
}

export function shouldRenderPrimaryReaderContent(page: ReadBookPage): boolean {
    return !page.isLoading || !!page.content;
}

export function isPagedReaderAwaitingPagination(page: ReadBookPage): boolean {
    return !!page.content && page.contentPages.length === 0;
}

export function shouldShowReaderLoadingOverlay(page: ReadBookPage): boolean {
    // 翻页进行中由翻页提示页（上一章排版中/加载中）负责覆盖屏幕；恢复进度遮罩若在动画期间浮现，
    // 会盖住提示页并造成“提交后又闪加载框”的割裂感。
    if (page.isPageTurning) return false;
    return page.shouldRenderPrimaryReaderContent() &&
      !page.readerComicChapterSwitching &&
      (page.isLoading || page.isPagedReaderAwaitingPagination() || !page.readerInitialPageReady);
}

export function shouldBlockReaderInteraction(page: ReadBookPage): boolean {
    return page.isLoading || page.isPagedReaderAwaitingPagination() || !page.readerInitialPageReady ||
      page.readerComicPaginationParsing;
}

export function getReaderLoadingText(page: ReadBookPage): string {
    if (page.readerInitialOpening) {
      return '正在打开书籍…';
    }
    if (page.pendingRestorePageIndex >= 0) {
      return '正在恢复阅读进度...';
    }
    if (page.isPagedReaderAwaitingPagination() && !page.isLoading) {
      return '正在排版...';
    }
    return page.loadStatus || '加载中...';
}

export function scheduleReaderLoadingSlowHint(page: ReadBookPage): void {
    if (page.readerLoadingSlowTimerId >= 0) return;
    page.readerLoadingSlowTimerId = setTimeout((): void => {
      page.readerLoadingSlowTimerId = -1;
      page.readerLoadingSlow = true;
    }, READER_LOADING_SLOW_HINT_MS);
}

export function cancelReaderLoadingSlowHint(page: ReadBookPage): void {
    if (page.readerLoadingSlowTimerId >= 0) {
      clearTimeout(page.readerLoadingSlowTimerId);
      page.readerLoadingSlowTimerId = -1;
    }
    page.readerLoadingSlow = false;
}

export function cancelReaderLoading(page: ReadBookPage): void {
    page.bookLoadSerial++;
    page.contentLoadSerial++;
    page.readerContentLoadInFlight = 0;
    page.isLoading = false;
    page.loadStatus = '';
    page.cancelReaderLoadingSlowHint();
    page.updatePendingVerification();
    if (!page.content) {
      const c = page.chapters[page.currentChapterIndex];
      page.setReaderContent(page.verificationUrl ?
        `${c ? c.title : '当前章节'}\n\n该书源需要先完成网页验证。请点击右上角“更多操作”，选择“登录”，完成后返回，再从该菜单选择“重试”。` :
        (c ? `${c.title}\n\n已停止等待加载。请点击右上角“刷新本章”或“换源”。` :
          '已停止等待加载。请点击右上角“更多操作”，选择“重试”。'));
    }
}

export function readerComicBoundaryHintTopPadding(page: ReadBookPage): number {
    // The continuous surface is already inset when body content does not extend into the status bar;
    // extended and comic layouts are not.
    // Add only the unconsumed safe-area height so the top hint never sits underneath status-bar content.
    const consumedTopInset = page.getReaderTopSafePadding();
    return Math.max(14, page.statusBarSafeHeight - consumedTopInset + 12);
}
