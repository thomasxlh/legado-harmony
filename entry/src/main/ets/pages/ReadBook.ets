//region 头部: 导入 / 顶层常量 / 纯函数 / 后台TTS Host适配器
// [map] 契约: 无 @State 依赖; 顶层常量已抽到 reader/ReaderConstants.ets; ReadBookTtsBackgroundHost 仅逐方法委托 page
// [map] 文件地图与拆分蓝图: 见仓库根 CODE_MAP.md (改本文件前先读)
// [map] 听书长时运行问题清单: docs/tts-long-running-bugs.md
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
import { ReaderBookmarkPullHint, ReaderComicPaginationPanel, ReaderLoadingPanel, ReaderSourceActionButton,
  ReaderTtsTimerControl } from '../components/ReaderStatusItems';
import { ReaderComicBoundaryHintContent, ReaderCustomThemeDeleteConfirm, ReaderEyeCalibrationSettingItem, ReaderEyeCalibrationPanel } from '../components/ReaderComicAndDialogItems';
import {
  ReaderSelectSettingItem,
  ReaderTtsVoiceOption,
  ReaderTapZoneSettingItem,
  ReaderAutoPageTurnIntervalSettingItem,
  ReaderTxtCharsetOptionRow,
  ReaderLayoutElementSettingsDialog,
  ReaderHeaderFooterSettingsPanel,
  ReaderTxtCharsetDialogContent,
  ReaderSystemTtsVoiceOption,
  ReaderTtsVoicePanel,
  ReaderChapterCacheDialogContent,
  ReaderTypographyCombinedSettings,
} from '../components/ReaderSettingsRows';
import { ReaderActionMenuItem, ReaderCommentPanelDragOverlay, ReaderFloatingIconMenuItem, ReaderHdsMenuItem, ReaderReplaceRulesEntryItem, ReaderActionMenuPanel } from '../components/ReaderMenuItems';
import {
  ReaderCurrentPageBookmarkMarker,
  ReaderEyeTurnPrompt,
  ReaderHeaderInfoBar,
  ReaderSliderStepButton,
  ReaderTtsSleepTimerChip,
  ReaderTtsSpeedChip
} from '../components/ReaderOverlayItems';
import {
  ReaderTtsMediaSymbolControl,
  ReaderTtsMediaSpeedControl,
  ReaderTtsVoiceSectionTitle,
  ReaderCacheActionItem,
  ReaderEpubImage,
  ReaderRoundMenuButton,
  ReaderSwitchSettingItem,
  ReaderLayoutElementToggle
} from '../components/ReaderSettingItems';
import {
  ReaderBottomInfoBar,
  ReaderBookmarkPanelSummary,
  ReaderFloatingTopMenu,
  ReaderAutoPageTurnIndicator,
  ReaderChapterSliderBar,
  ReaderPreloadSettingItem,
  ReaderTtsQuickActionButton,
  ReaderTocVirtualScrollbar,
  ReaderFloatingBottomMenu
} from '../components/ReaderPanelChromeItems';
import { ReaderMenuDismissLayer, ReaderSettingsDismissLayer } from '../components/ReaderDismissLayers';
import {
  ReaderCommentPanelDragHandle,
  ReaderFontEntryItem,
  ReaderBookmarkDeleteAction,
  ReaderBookmarkMultiSelectAction
} from '../components/ReaderStaticItems';
import { ReaderBookmarkActionItem } from '../components/ReaderBookmarkActionItem';
import { ReaderComicBoundaryHint, ReaderComicInteractionLayer,
  ReaderCacheDialogContent } from '../components/ReaderComicAndCacheItems';
import { ReaderFloatingDayNightMenuItem, ReaderHdsDayNightMenuItem, ReaderBookmarkSwipeCard,
  ReaderSimulationPaperBackground, ReaderParagraphGap, ReaderTapLayer } from '../components/ReaderPageFrameItems';
import { ReaderV2TtsHighlightRect, ReaderV2SelectionHighlightRect } from '../components/ReaderV2HighlightRects';
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
import { ReaderTtsBackgroundController, ReaderTtsBackgroundHost } from '../reader/ReaderTtsBackgroundController';
import {
  READER_PROGRESS_OFFSET_KEY,
  READER_PROGRESS_OFFSET_CHAPTER_KEY,
  hashText,
  hashTtsText,
  parseAreaDimension,
  savedReaderProgressOffset
} from '../reader/ReaderPureUtils';
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
} from '../reader/ReaderConstants';
import * as LeafFns from '../reader/ReaderLeafFns';
import * as ReaderLifecycleOps from '../reader/ReaderLifecycleOps';
import * as ReaderLoadCacheOps from '../reader/ReaderLoadCacheOps';
import * as ReaderMenuBuildOps from '../reader/ReaderMenuBuildOps';
import * as ReaderTextPrepOps from '../reader/ReaderTextPrepOps';
import * as ReaderChromeThemeOps from '../reader/ReaderChromeThemeOps';
import * as ReaderGestureOps from '../reader/ReaderGestureOps';
import * as ReaderSettingsOps from '../reader/ReaderSettingsOps';
import * as ReaderTtsOrchestrationOps from '../reader/ReaderTtsOrchestrationOps';
import * as ReaderPaginationOps from '../reader/ReaderPaginationOps';
import * as ReaderHighlightOps from '../reader/ReaderHighlightOps';
import * as ReaderStyledTextOps from '../reader/ReaderStyledTextOps';
import * as ReaderPageTurnOps from '../reader/ReaderPageTurnOps';

/**
 * ReaderTtsBackgroundHost 适配器：ArkTS struct 不允许 implements 接口，
 * 由该普通类持有 struct 引用并逐方法委托到 struct 的访问器实现。
 */
class ReadBookTtsBackgroundHost implements ReaderTtsBackgroundHost {
  private readonly page: ReadBookPage;

  constructor(page: ReadBookPage) {
    this.page = page;
  }

  hostContext(): common.Context {
    return this.page.hostContext();
  }

  getReaderBook(): Book | null {
    return this.page.getReaderBook();
  }

  getReaderBookUrl(): string {
    return this.page.getReaderBookUrl();
  }

  getCurrentChapterIndex(): number {
    return this.page.getCurrentChapterIndex();
  }

  getCurrentPageIndex(): number {
    return this.page.getCurrentPageIndex();
  }

  setCurrentPageIndex(value: number): void {
    this.page.setCurrentPageIndex(value);
  }

  setPendingRestorePageIndex(value: number): void {
    this.page.setPendingRestorePageIndex(value);
  }

  getContentPageCount(): number {
    return this.page.getContentPageCount();
  }

  getTtsReader(): SystemTtsReader {
    return this.page.getTtsReader();
  }

  isTtsSpeakingState(): boolean {
    return this.page.isTtsSpeakingState();
  }

  isTtsPausedState(): boolean {
    return this.page.isTtsPausedState();
  }

  getTtsSpeed(): number {
    return this.page.getTtsSpeed();
  }

  getTtsCharCountSource(): string {
    return this.page.getTtsCharCountSource();
  }

  getChapterTitle(chapterIndex?: number): string {
    return this.page.getChapterTitle(chapterIndex);
  }

  getProgressText(): string {
    return this.page.getProgressText();
  }

  getBookshelfDisplayCoverRaw(): string {
    return this.page.getBookshelfDisplayCoverRaw();
  }

  isFullTextCaching(): boolean {
    return this.page.isFullTextCaching();
  }

  isFullTextCacheBackgroundRunning(): boolean {
    return this.page.isFullTextCacheBackgroundRunning();
  }

  setFullTextCacheBackgroundRunning(value: boolean): void {
    this.page.setFullTextCacheBackgroundRunning(value);
  }

  isTtsChapterSwitching(): boolean {
    return this.page.isTtsChapterSwitching();
  }

  setTtsChapterSwitching(value: boolean): void {
    this.page.setTtsChapterSwitching(value);
  }

  getTtsLastMediaChapterCommandAt(): number {
    return this.page.getTtsLastMediaChapterCommandAt();
  }

  setTtsLastMediaChapterCommandAt(value: number): void {
    this.page.setTtsLastMediaChapterCommandAt(value);
  }

  ownsTtsFloatingSession(): boolean {
    return this.page.ownsTtsFloatingSession();
  }

  isTtsSessionManuallyPaused(): boolean {
    return this.page.isTtsSessionManuallyPaused();
  }

  canPlayNextTtsChapter(): boolean {
    return this.page.canPlayNextTtsChapter();
  }

  canPlayPreviousTtsChapter(): boolean {
    return this.page.canPlayPreviousTtsChapter();
  }

  toggleTtsReading(): Promise<void> {
    return this.page.toggleTtsReading();
  }

  startTtsReadingFromCurrentPosition(showToast: boolean, manualPageTurnResume?: boolean,
    manualPageTurnResumeSerial?: number, readingStartOffset?: number,
    preserveExistingFocus?: boolean): Promise<void> {
    return this.page.startTtsReadingFromCurrentPosition(showToast, manualPageTurnResume,
      manualPageTurnResumeSerial, readingStartOffset, preserveExistingFocus);
  }

  stopTtsReading(userCancelled?: boolean): void {
    this.page.stopTtsReading(userCancelled);
  }

  applyTtsSpeed(value: number): void {
    this.page.applyTtsSpeed(value);
  }

  stopTtsReaderForChapterSwitch(): void {
    this.page.stopTtsReaderForChapterSwitch();
  }

  prepareTtsForManualPageTurn(): void {
    this.page.prepareTtsForManualPageTurn();
  }

  scheduleTtsResumeAfterManualPageTurn(): void {
    this.page.scheduleTtsResumeAfterManualPageTurn();
  }

  clearTtsContinuationWatchdog(): void {
    this.page.clearTtsContinuationWatchdog();
  }

  loadContent(silent?: boolean, targetChapterIndex?: number,
    preferImmediatePagination?: boolean): Promise<boolean> {
    return this.page.loadContent(silent, targetChapterIndex, preferImmediatePagination);
  }

  saveReadingProgress(notifyShelf?: boolean): Promise<void> {
    return this.page.saveReadingProgress(notifyShelf);
  }

  syncCurrentPageText(): void {
    this.page.syncCurrentPageText();
  }
}

//endregion
//region struct 声明与状态字段 (@State / @StorageLink / 私有字段)
// [map] 契约: 仅声明状态, 不含逻辑; ArkUI V1 下 @State 必须留在本 @Component 内, 逻辑外移须走 Controller+Host
@Entry
@Component
export struct ReadBookPage {
  @State bookUrl: string = '';
  @State book: Book | null = null;
  @State chapters: BookChapter[] = [];
  @State tocVisibleChapters: BookChapter[] = [];
  @State tocWindowStart: number = 0;
  @State tocQuickJumpArmed: boolean = false;
  @State tocQuickJumpInputVisible: boolean = false;
  @State tocQuickJumpDraft: string = '';
  @State tocSearchVisible: boolean = false;
  @State tocSearchQuery: string = '';
  @State tocSearchChapterIndexes: number[] = [];
  @State tocSearchLoading: boolean = false;
  @State tocSearchResultActive: boolean = false;
  @State tocReverseOrder: boolean = false;
  @State tocOrderRevision: number = 0;
  @State tocDatabaseChapterCount: number = 0;
  @State tocListViewportHeight: number = 0;
  @State tocFirstVisibleGlobalIndex: number = 0;
  @State tocVisibleItemCount: number = 1;
  @State tocScrollbarDragging: boolean = false;
  @State tocScrollbarDragOffset: number = 0;
  tocSearchRequestSerial: number = 0;
  tocScrollbarPointerAnchor: number = 0;
  tocScrollbarPendingIndex: number = -1;
  tocScrollbarUpdateTimer: number = -1;
  @State currentChapterIndex: number = 0;
  @State menuChapterPreviewIndex: number = 0;
  @State menuChapterSliderActive: boolean = false;
  @State menuChapterTooltipVisible: boolean = false;
  @State menuChapterConfirming: boolean = false;
  @State content: string = '';
  @State readerReplaceRules: ReaderReplaceRule[] = [];
  @State @Watch('onReaderLoadingChanged') isLoading: boolean = true;
  // 加载迟迟未完成时置真，遮罩上浮出“不再等待”逃生口。
  @State readerLoadingSlow: boolean = false;
  readerLoadingSlowTimerId: number = -1;
  @State showMenu: boolean = false;
  @State hdsMaterialRenderBranch: boolean = false;
  @State readerDayNightLongPressHandled: boolean = false;
  // 展开屏上记住用户本次唤起菜单的手指侧：-1 左侧，1 右侧。
  @State readerMenuAnchorSide: number = 1;
  @State showReaderActionMenu: boolean = false;
  @State showLayoutElementSettings: boolean = false;
  txtCharsetDialogSession: SystemDialogSession = new SystemDialogSession();
  readerCacheDialogSession: SystemDialogSession = new SystemDialogSession();
  chapterCacheDialogSession: SystemDialogSession = new SystemDialogSession();
  tapZoneDialogSession: SystemDialogSession = new SystemDialogSession();
  readerCustomThemeDeleteDialogSession: SystemDialogSession = new SystemDialogSession();
  @State @Watch('onSystemDialogFlagChanged') showTxtCharsetDialog: boolean = false;
  @State txtCharsetDraft: string = '';
  @State txtCharsetApplying: boolean = false;
  @State showReaderCommentPanel: boolean = false;
  @State readerCommentPanelTitle: string = '段评';
  @State readerCommentPanelUrl: string = '';
  @State readerCommentPanelProgress: number = 0;
  @State readerCommentPanelLoading: boolean = false;
  @State readerCommentPanelHeightRatio: number = 0.6;
  @State readerCommentPanelHeightValue: number = 432;
  readerCommentPanelHtml: string = '';
  readerCommentPanelBaseUrl: string = '';
  readerCommentPanelHtmlLoaded: boolean = false;
  readerCommentPanelLoadSerial: number = 0;
  readerCommentPanelReadyTimerId: number = -1;
  readerCommentPanelDragStartRatio: number = 0.6;
  readerCommentPanelDragStartWindowY: number = 0;
  readerCommentPanelDragging: boolean = false;
  @State showToc: boolean = false;
  @State tocPanelTab: number = 0;
  @State bookmarks: Bookmark[] = [];
  @State bookmarkMultiSelectMode: boolean = false;
  @State selectedBookmarkUrls: string[] = [];
  @State showBookmarkActionMenu: boolean = false;
  @State pendingBookmarkAction: Bookmark | null = null;
  @State bookmarkActionMenuX: number = 16;
  @State bookmarkActionMenuY: number = 96;
  @State showSettings: boolean = false;
  @State @Watch('onSystemDialogFlagChanged') showTapZoneSettings: boolean = false;
  @State @Watch('onSystemDialogFlagChanged') showReaderCustomThemeDeleteConfirm: boolean = false;
  @State settingsPanelTab: number = 0;
  @State readerTypographySelection: number = 0;
  @State showReaderTypographyValueInput: boolean = false;
  @State readerTypographyValueDraft: string = '';
  @State loadStatus: string = '正在加载...';
  @State verificationUrl: string = '';
  @State verificationTitle: string = '网页验证';
  @State showChangeSourceDialog: boolean = false;
  @State pendingSwitchedBook: Book | null = null;
  @State contentPages: string[] = [];
  @State currentPageIndex: number = 0;
  @State currentPageText: string = '';
  @State displayPageText: string = '';
  @State displayPageChapterIndex: number = 0;
  @State displayPageIndex: number = 0;
  @State displayPageRenderKey: number = 0;
  @State pageRenderVersion: number = 0;
  @State chapterJumpRenderGeneration: number = 0;
  @State readerV2SurfaceGeneration: number = 0;
  @State pageViewWidth: number = 0;
  @State pageViewHeight: number = 0;
  @State readerBottomInfoBarMeasuredHeight: number = 0;
  @State readerInitialPageReady: boolean = false;
  @State readerInitialOpening: boolean = true;
  @State readerWebFetchRuntimeNeeded: boolean = false;
  @State readerComicMode: boolean = false;
  @State readerComicImageRatios: number[] = [];
  // 加载失败（onError）的图片页下标；用于占位提示与失败原因诊断。
  @State readerComicBrokenPages: number[] = [];
  @State readerComicPaginationParsing: boolean = false;
  @State readerComicPaginationParsedPages: number = 0;
  @State readerComicPaginationTotalPages: number = 0;
  @State readerComicChapterSwitching: boolean = false;
  @State readerComicBoundaryDirection: number = 0;
  @State readerComicBoundaryPullDistance: number = 0;
  @State readerComicBoundaryReady: boolean = false;
  @State readerComicChapterTransitionY: number = 0;
  @State readerComicChapterTransitionOpacity: number = 1;
  readerComicPaginationSource: string = '';
  @State statusBarSafeHeight: number = 0;
  @StorageProp('statusBarHeight') @Watch('onStoredStatusBarHeightChanged') storedStatusBarHeight: number = 0;
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @State isTtsSpeaking: boolean = false;
  @State isTtsPaused: boolean = false;
  @State ttsPagedScrollOverride: boolean = false;
  @State ttsMediaControlsExpanded: boolean = false;
  @State ttsDisplayText: string = '';
  @State ttsHighlightStart: number = -1;
  @State ttsHighlightEnd: number = -1;
  @State ttsHighlightRenderVersion: number = 0;
  @State readerV2TtsPaintVersion: number = 0;
  @State readerV2SelectionPaintVersion: number = 0;
  @State ttsSleepTimerMinutes: number = 0;
  @State ttsSleepTimerRemainingSeconds: number = 0;
  @StorageLink('globalTtsActive') @Watch('onGlobalTtsActiveChanged') globalTtsActive: boolean = false;
  @StorageLink('globalTtsPaused') globalTtsPaused: boolean = false;
  @StorageLink('globalTtsBookName') globalTtsBookName: string = '';
  @StorageLink('globalTtsChapterTitle') globalTtsChapterTitle: string = '';
  @StorageLink('globalTtsMode') globalTtsMode: string = '';
  @StorageLink('globalTtsChapterProgress') globalTtsChapterProgress: string = '';
  @StorageLink('globalTtsCanPrevious') globalTtsCanPrevious: boolean = false;
  @StorageLink('globalTtsCanNext') globalTtsCanNext: boolean = false;
  @StorageLink('globalTtsBookUrl') globalTtsBookUrl: string = '';
  @StorageLink('globalTtsChapterIndex') globalTtsChapterIndex: number = -1;
  @StorageLink('globalTtsOffsetStart') globalTtsOffsetStart: number = -1;
  @StorageLink('globalTtsOffsetEnd') globalTtsOffsetEnd: number = -1;
  @StorageLink('globalTtsRevision') @Watch('onGlobalTtsRevisionChanged') globalTtsRevision: number = 0;
  @State showGlobalTtsCatalog: boolean = false;
  @State globalTtsCatalogReverseOrder: boolean = false;
  ttsFloatingSessionOwnerId: string = `reader_${Date.now()}_${Math.random()}`;
  pendingRestorePageIndex: number = -1;
  tocScroller: Scroller = new Scroller();
  tocLoadingPreviousPage: boolean = false;
  tocLoadingNextPage: boolean = false;
  tocPositioning: boolean = false;
  tocPositionRequestSerial: number = 0;
  bookmarkScroller: ListScroller = new ListScroller();
  globalTtsCatalogScroller: ListScroller = new ListScroller();
  globalTtsCatalogSource: CatalogTitleDataSource = new CatalogTitleDataSource();
  readerComicScroller: ListScroller = new ListScroller();
  readerComicPageDataSource: ReaderComicPageDataSource = new ReaderComicPageDataSource();
  readerComicImageRatioCache: Map<string, number> = new Map();
  readerComicImageRatioLoading: Set<string> = new Set();
  readerComicScrollRestoreSerial: number = 0;
  readerComicScrollRestoring: boolean = false;
  readerComicReanchorSerial: number = 0;
  readerComicProgressSaveTimerId: number = -1;
  readerPagedProgressSaveTimerId: number = -1;
  readerComicPanLastOffsetY: number = 0;
  readerComicPanMoved: boolean = false;
  // isAtEnd()/currentOffset() 是同步跨线程查询，手势更新事件频率高于刷新率；
  // 边界方向探测按时间片取样，提示徽标晚一两帧出现无感知。
  readerComicBoundaryProbeNotUntil: number = 0;
  readerComicBoundaryPullOriginY: number = 0;
  readerContinuousScrollOffsetMemoAt: number = 0;
  readerContinuousScrollOffsetMemo: number = 0;
  readerComicSuppressClickUntil: number = 0;
  ttsReader: SystemTtsReader = new SystemTtsReader();
  ttsFocusLatencyMonitor: TtsFocusLatencyMonitor = new TtsFocusLatencyMonitor();
  ttsAutoContinue: boolean = false;
  ttsReadToken: number = 0;
  ttsChapterSwitching: boolean = false;
  ttsChapterAdvanceError: string = '';
  ttsContinuationWatchdogId: number = -1;
  // 目录兜底：朗读会话已被清理（如书读完正常收尾）但快速朗读面板仍打开时，
  // 目录改用当前阅读页的章节列表，选择也直接走本页跳转，不再依赖已清空的悬浮会话。
  ttsCatalogFromLocalChapters: boolean = false;
  ttsLastMediaChapterCommandAt: number = 0;
  ttsTextStartOffset: number = 0;
  // The speech engine reports completion independently from the reader's page state. Keep the expected source
  // tail so a premature onFinished callback cannot advance to the next chapter while trailing chunks are pending.
  ttsReadingExpectedSourceEnd: number = -1;
  ttsChapterCompletionRetryCount: number = 0;
  // 章末预处理去重：当前章尾段还在播时只预合成一次下一章开头音频。
  ttsNextChapterAudioPrefetchArmed: boolean = false;
  ttsLastFocusChunk: TtsChunk | null = null;
  ttsLastFocusPageIndex: number = -1;
  ttsFocusGeneration: number = 0;
  ttsFocusChapterIndex: number = -1;
  ttsFocusSourceIdentity: string = '';
  ttsFocusContentLoadSerial: number = -1;
  ttsLastAppliedSourceOffset: number = -1;
  ttsSurfaceFocusSyncSerial: number = 0;
  ttsPaginationFocusSyncSerial: number = 0;
  ttsResumeSyncSerial: number = 0;
  // 回前台恢复同步在章末切换期间的有界重试：单飞标志防止重试堆叠，截止时间防止切换
  // 卡死时无限轮询。0/180ms 两次固定调度撞上多秒的切换窗口后不再重试，页面与朗读
  // 错位就无法自愈。
  ttsFocusResumeRetryScheduled: boolean = false;
  ttsFocusResumeRetryDeadline: number = 0;
  mirroredTtsFocusSyncSerial: number = 0;
  @State mirroredTtsFocusActive: boolean = false;
  mirroredTtsManualTurnPending: boolean = false;
  mirroredTtsManualTurnTimerId: number = -1;
  // 手动翻页提交后进入“脱离跟随”冷却（毫秒）。冷却期间 syncMirroredTtsFocus 不把视图拽回
  // 朗读点，让用户在镜像模式下能翻看前后文；冷却结束后平滑重新跟随到朗读进度。
  mirroredTtsFollowSuppressUntil: number = 0;
  mirroredTtsManualTurnSerial: number = 0;
  mirroredTtsAppliedChapterIndex: number = -1;
  mirroredTtsAppliedOffsetStart: number = -1;
  // 进入阅读页时对播放中的同书后台朗读会话做一次性接管（停掉后台宿主、由本页从全局锚点
  // 续播），消除双实例并存对引擎/进度写入/分页管线的竞争（翻页高亮卡顿、页面偶发错乱的根源）。
  ttsSessionTakeoverAttempted: boolean = false;
  ttsSessionTakeoverInProgress: boolean = false;
  ttsSessionTakeoverStartedAt: number = 0;
  ttsSessionTakeoverPollScheduled: boolean = false;
  // 句边界接管武装：进入阅读页瞬间，当前句已由后台宿主在播。立刻接管会让这句话从头
  // 重播一遍（听感为“重复播报当前句”）。先武装记录在播句锚点并镜像跟随本句，等后台
  // 宿主推进到下一句（锚点变化）时才接管，由本页从新句开头续播，旧宿主在同一句边界
  // 被停掉，全程无重复。
  ttsTakeoverArmedChapterIndex: number = -1;
  ttsTakeoverArmedOffsetStart: number = -1;
  ttsProgressSaveTimerId: number = -1;
  ttsAutoTurningPage: boolean = false;
  ttsPageTurnSerial: number = 0;
  ttsPendingTargetPageIndex: number = -1;
  ttsPendingHighlightChunk: TtsChunk | null = null;
  ttsManualPageTurnResumePending: boolean = false;
  ttsManualPageTurnResumeTimerId: number = -1;
  ttsManualPageTurnResumeSerial: number = 0;
  ttsManualPageTurnStartedAt: number = 0;
  ttsBackgroundCtrl: ReaderTtsBackgroundController | null = null;
  ttsSpeedSaveTimerId: number = -1;
  ttsSpeedAvSessionTimerId: number = -1;
  ttsSpeedRestartTimerId: number = -1;
  ttsSpeedRestartSerial: number = 0;
  ttsSleepTimerId: number = -1;
  ttsSleepTimerEndAt: number = 0;
  contentPageStarts: number[] = [];
  contentPageEnds: number[] = [];
  pagedContentText: string = '';
  readerPaginationCache: Map<string, ReaderPaginationResult> = new Map();
  readerV2PageSetCache: Map<string, ReaderV2PageSet> = new Map<string, ReaderV2PageSet>();
  readerV2DocumentCache: Map<string, ReaderV2Document> = new Map<string, ReaderV2Document>();
  readerV2Controllers: Map<string, ReaderV2PageNodeController> =
    new Map<string, ReaderV2PageNodeController>();
  readerV2SelectionStyledTextCache: Map<string, MutableStyledString> =
    new Map<string, MutableStyledString>();
  readerV2ActiveDocument: ReaderV2Document | null = null;
  readerV2ActiveSnapshot: ReaderV2LayoutSnapshot | null = null;
  readerV2ActiveSpeechText: ReaderV2SpeechText | null = null;
  readerV2TtsSourceStart: number = -1;
  readerV2TtsSourceEnd: number = -1;
  readerPreparedContentCache: Map<string, string> = new Map();
  readerParagraphMetricsCache: Map<string, ReaderParagraphMetrics> = new Map();
  readerAdaptiveLineHeightCache: Map<string, number> = new Map();
  // 滚动模式下每个分块的正文解析在选择层、渲染层、测量层被反复调用；按块文本缓存切分结果，
  // 避免快速滑动时每个新 LazyForEach 项重复做整块正则归一化与逐段切分。
  readerTextParagraphsCache: Map<string, ReaderTextParagraph[]> = new Map();
  readerPaginationHeightScaleIdentity: string = '';
  readerPaginationHeightScale: number = 1;
  readerPaginationHeightCalibrationResolvedIdentity: string = '';
  readerPaginationBottomFitTimerId: number = -1;
  readerPaginationBottomFitIdentity: string = '';
  readerPaginationBottomFitAttempts: number = 0;
  cachedRegexRulesKey: string = '';
  cachedRegexRules: ReaderRegexFontRule[] = [];
  cachedDocumentRegexSource: string = '';
  cachedDocumentRegexRulesKey: string = '';
  cachedDocumentRegexSlices: ReadTextSlice[] = [];
  regexFrameStyleCache: Map<string, string> = new Map();
  adjacentPaginationPreloadSerial: number = 0;
  previousPaginationPreloadSerial: number = 0;
  adjacentPaginationPreloadActiveSerial: number = -1;
  adjacentPaginationPreloadActiveKey: string = '';
  previousPaginationPreloadActiveSerial: number = -1;
  previousPaginationPreloadActiveKey: string = '';
  readerPaginationWorkSerial: number = 0;
  readerPaginationInteractionIdleUntil: number = 0;
  pageTurnPreviewKey: string = '';
  pageTurnPreviewLoadingKey: string = '';
  readerPageCurlPainter: ReaderPageCurlPainter = new ReaderPageCurlPainter();
  readerEmulationFlipPainter: ReaderEmulationFlipPainter = new ReaderEmulationFlipPainter();
  readerCurlStartRegion: number = ReaderEmulationFlipRegion.MIDDLE;
  readerPageCurlContext: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true));
  readerPageCurlFront: image.PixelMap | null = null;
  readerPageCurlBack: image.PixelMap | null = null;
  readerPageCurlSnapshotHeight: number = 0;
  readerPageCurlCaptureKey: string = '';
  readerPageCurlCaptureSerial: number = 0;
  readerPageCurlCapturePending: boolean = false;
  readerPageCurlCanvasReady: boolean = false;
  readerPageCurlOffset: number = 0;
  readerPageCurlAnimator: AnimatorResult | null = null;
  readerPageCurlAnimationSerial: number = 0;
  @State readerPageCurlSnapshotReady: boolean = false;
  @State pageTransitionX: number = 0;
  @State pageTransitionOpacity: number = 1;
  @State pageSlideOffsetX: number = 0;
  @State pageSlideOffsetY: number = 0;
  @State bookmarkPullOffsetY: number = 0;
  @State bookmarkPullActive: boolean = false;
  @State bookmarkPullReady: boolean = false;
  @State pageSlideDirection: number = 0;
  @State pageTurnAnimating: boolean = false;
  @State pageTurnIncomingText: string = '';
  @State pageTurnIncomingSecondaryText: string = '';
  @State pageTurnIncomingX: number = 0;
  @State pageTurnIncomingOpacity: number = 1;
  @State pageTurnIncomingPageIndex: number = 0;
  @State pageTurnIncomingChapterIndex: number = 0;
  @State pageTurnIncomingPageStart: number = -1;
  @State pageTurnIncomingSecondaryPageStart: number = -1;
  @State pageTurnIncomingDocumentSource: string = '';
  @State pageTurnIncomingRenderVersion: number = 0;
  bookLoadSerial: number = 0;
  contentLoadSerial: number = 0;
  // 正在执行的 loadContent/refreshCurrentChapter 数量。isLoading 的清除以该计数归零为准，
  // 不再依赖 serial 相等判断，避免并发静默加载顶掉 serial 后非静默跳章的加载遮罩永久卡死。
  readerContentLoadInFlight: number = 0;
  isPageTurning: boolean = false;
  queuedPageTurnDirection: number = 0;
  queuedPageTurnStyle: string = '';
  queuedPageTurnCount: number = 0;
  queuedPageTurnVelocity: number = 0;
  queuedPageTurnGeneration: number = 0;
  pendingScrollPreviousChapterTurn: boolean = false;
  pageTurnCrossChapterHandoff: boolean = false;

  lastRecentReadCardReloadAt: number = 0;
  lastRecentReadCardChapterIndex: number = -1;
  readerTouchStartX: number = 0;
  readerTouchStartY: number = 0;
  readerTouchLastX: number = 0;
  readerTouchLastY: number = 0;
  readerTouchActive: boolean = false;
  readerTouchMoved: boolean = false;
  suppressReaderTapClick: boolean = false;
  readerInteractiveActionUntil: number = 0;
  readerSourceActionOpenedAt: number = 0;
  readerTouchActionMarker: string = '';
  readerInlineTouchActionMarker: string = '';
  readerSourceActionAreas: Map<string, number[]> = new Map<string, number[]>();
  readerSourceActionScrollOffsets: Map<string, number[]> = new Map<string, number[]>();
  readerPendingInlineActionBounds: Map<string, ReaderInlineActionBoundsTask> =
    new Map<string, ReaderInlineActionBoundsTask>();
  readerPendingMergedActionBounds: Map<string, ReaderMergedActionBoundsTask> =
    new Map<string, ReaderMergedActionBoundsTask>();
  readerActionMatchCache: Map<string, ReaderActionMatch> = new Map<string, ReaderActionMatch>();
  readerSourceSettingCacheKey: string = '';
  readerSourceSettingCacheRevision: string = '';
  readerSourceSettingCacheContentRule: string = '';
  readerSourceSettingCacheJsLib: string = '';
  readerSourceHasCommentBubbleScript: boolean = false;
  readerSourceActionBoundsFlushPending: boolean = false;
  readerInlineActionTextControllers: Map<string, TextController> = new Map<string, TextController>();
  readerSelectableTextControllers: Map<string, TextController> = new Map<string, TextController>();
  readerSelectableTextAreas: Map<string, number[]> = new Map<string, number[]>();
  readerSelectableTextScrollOffsets: Map<string, number> = new Map<string, number>();
  readerSelectableTextValues: Map<string, string> = new Map<string, string>();
  @State readerTextSelectionActive: boolean = false;
  readerTextSelectionUntil: number = 0;
  readerTextSelectionSerial: number = 0;
  readerV2SelectionChapterIndex: number = -1;
  readerV2SelectionPageIndex: number = -1;
  readerV2SelectionDisplayStart: number = -1;
  readerV2SelectionDisplayEnd: number = -1;
  @State readerV2NativeSelectionHostVersion: number = 0;
  readerV2NativeSelectionChapterIndex: number = -1;
  readerV2NativeSelectionPageIndex: number = -1;
  readerV2NativeSelectionFragmentIndex: number = -1;
  readerV2NativeSelectionRole: string = '';
  readerV2NativeSelectionPendingStart: number = -1;
  readerV2NativeSelectionPendingEnd: number = -1;
  readerV2NativeSelectionPendingSerial: number = -1;
  readerV2NativeSelectionActiveStart: number = -1;
  readerV2NativeSelectionActiveEnd: number = -1;
  readerV2NativeSelectionRecalibrateTimerId: number = -1;
  @State readerV2NativeSelectionOffsetX: number = 0;
  @State readerV2NativeSelectionOffsetY: number = 0;
  readerContinuousVisibleStart: number = 0;
  readerContinuousVisibleEnd: number = 0;
  readerContinuousReachedEnd: boolean = false;
  readerContinuousPointerGlobalX: number = -1;
  readerContinuousPointerGlobalY: number = -1;
  readerContinuousPointerAt: number = 0;
  readerContinuousSelectionTimerId: number = -1;
  readerContinuousSelectionDownX: number = -1;
  readerContinuousSelectionDownY: number = -1;
  readerContinuousSelectionDownAt: number = 0;
  readerContinuousSelectionMoved: boolean = false;
  // A tap outside a live selection dismisses it. The pointer is tracked separately from the page-turn
  // gesture state because a selection owns the stream: no page turn, menu or scroll may run.
  readerSelectionDismissDownX: number = -1;
  readerSelectionDismissDownY: number = -1;
  readerSelectionDismissDownAt: number = 0;
  readerSelectionDismissMoved: boolean = false;
  // True only for a pointer stream whose Down began while a selection was already live. The release of
  // the long press that CREATES a selection also ends a stream; that stream must never dismiss it.
  readerSelectionDismissArmed: boolean = false;
  readerTextSelectionClearPending: boolean = false;
  readerTapLayerGlobalX: number = 0;
  readerTapLayerGlobalY: number = 0;
  // Paragraph-comment pills are visually small, but their interaction target should be close to the platform
  // 44vp recommendation. Expansion remains geometry-only and never changes pagination or painted bubble size.
  readerSourceActionHitSlopX: number = 20;
  readerSourceActionHitSlopY: number = 16;
  readerTapSlop: number = 12;
  // 翻页提交距离下限；实际阈值按页面尺寸比例计算，避免手指只动一点点就把整页翻过去。
  readerPageTurnCommitDistance: number = 18;
  readerPageTurnDirectionRatio: number = 0.8;
  readerPageTurnCommitRatio: number = 0.2;
  readerPageTurnFlickRatio: number = 0.06;
  readerPageTurnFlickVelocity: number = 800;
  readerBookmarkPullStartDistance: number = 48;
  readerBookmarkPullDirectionRatio: number = 1.5;
  readerPanActive: boolean = false;
  readerPageTurnGestureCommitted: boolean = false;
  readerGestureTurnGuardUntil: number = 0;
  readerGestureTurnAllowance: number = 0;
  slideResetSerial: number = 0;
  @StorageLink('readerFontSize') @Watch('onReadLayoutChanged') readerFontSize: number = 20;
  @StorageLink('readerLetterSpacing') @Watch('onReadLayoutChanged') readerLetterSpacing: number = 0;
  @StorageLink('readerTextAlign') @Watch('onReadLayoutChanged') readerTextAlign: string = 'justify';
  @StorageLink('readerLineHeight') @Watch('onReadLayoutChanged') readerLineHeight: number = 12;
  @StorageLink('readerParagraphSpacing') @Watch('onReadLayoutChanged') readerParagraphSpacing: number = 0;
  // 保留段首缩进：开启后分页/分块起点不再裁掉原文的全角空格缩进。
  @StorageLink('readerKeepParagraphIndent') @Watch('onReadLayoutChanged') keepParagraphIndent: boolean = false;
  @StorageLink('readerMarginLeft') @Watch('onReadLayoutChanged') readerMarginLeft: number = 18;
  @StorageLink('readerMarginRight') @Watch('onReadLayoutChanged') readerMarginRight: number = 18;
  @StorageLink('readerMarginTop') @Watch('onReadLayoutChanged') readerMarginTop: number = 18;
  @StorageLink('readerMarginBottom') @Watch('onReadLayoutChanged') readerMarginBottom: number = 18;
  @StorageLink('readerLightThemeIndex') @Watch('onReaderThemeChanged') readerLightThemeIndex: number = 0;
  @StorageLink('readerDarkThemeIndex') @Watch('onReaderThemeChanged') readerDarkThemeIndex: number = 0;
  @StorageLink('readerLightCustomThemeBackgroundColor') @Watch('onReaderThemeChanged') readerLightCustomThemeBackgroundColor: string = ReaderThemeHelper.LIGHT_CUSTOM_BACKGROUND_COLOR;
  @StorageLink('readerLightCustomThemeTextColor') @Watch('onReaderThemeChanged') readerLightCustomThemeTextColor: string = ReaderThemeHelper.LIGHT_CUSTOM_TEXT_COLOR;
  @StorageLink('readerDarkCustomThemeBackgroundColor') @Watch('onReaderThemeChanged') readerDarkCustomThemeBackgroundColor: string = ReaderThemeHelper.DARK_CUSTOM_BACKGROUND_COLOR;
  @StorageLink('readerDarkCustomThemeTextColor') @Watch('onReaderThemeChanged') readerDarkCustomThemeTextColor: string = ReaderThemeHelper.DARK_CUSTOM_TEXT_COLOR;
  @StorageLink('readerCustomThemesRaw') @Watch('onReaderThemeChanged') readerCustomThemesRaw: string = '';
  @State customThemeNameDraft: string = '';
  @StorageLink('readerPageTurnMode') readerPageTurnMode: number = 1;
  @StorageLink('readerPageTurnAnimationType') @Watch('onReaderPageTurnAnimationChanged') readerPageTurnAnimationType: number = ReaderSettingsStore.PAGE_TURN_ANIMATION_SLIDE;
  @StorageLink('readerLandscapeDoublePage') @Watch('onReaderLandscapeDoublePageChanged') readerLandscapeDoublePage: boolean = false;
  @StorageLink('readerScreenOrientation') @Watch('onReaderScreenOrientationChanged') readerScreenOrientation: string =
    ReaderSettingsStore.SCREEN_ORIENTATION_SYSTEM;
  @StorageLink('readerTapZoneActions') readerTapZoneActions: string = '3,3,3,3,1,2,2,2,2';
  @StorageLink('readerVolumeTurnPage') @Watch('onReaderVolumeTurnPageChanged') readerVolumeTurnPage: boolean = false;
  @StorageLink('readerEyeTurnEnabled') readerEyeTurnEnabled: boolean = false;
  @StorageLink('readerEyeTurnPortraitCalibration') readerEyeTurnPortraitCalibration: string = '';
  @StorageLink('readerEyeTurnLandscapeCalibration') readerEyeTurnLandscapeCalibration: string = '';
  @StorageLink('readerEyeTurnPreviousEnabled') readerEyeTurnPreviousEnabled: boolean = false;
  @StorageLink('readerEyeTurnNextEnabled') readerEyeTurnNextEnabled: boolean = true;
  @StorageLink('readerEyeTurnPreviousDwellMs') readerEyeTurnPreviousDwellMs: number = 850;
  @StorageLink('readerEyeTurnNextDwellMs') readerEyeTurnNextDwellMs: number = 650;
  // 自动翻页：间隔随阅读设置持久化并云同步；开关为会话级状态，仅存于 AppStorage，不落盘。
  @StorageLink('readerAutoPageTurnActive') @Watch('onAutoPageTurnActiveChanged') autoPageTurnActive: boolean = false;
  @StorageLink('readerAutoPageTurnIntervalSec') @Watch('onAutoPageTurnIntervalChanged')
  autoPageTurnIntervalSec: number = 15;
  @State autoPageTurnRingProgress: number = 1;
  @State autoPageTurnUserPaused: boolean = false;
  autoPageTurnController: AutoPageTurnController = new AutoPageTurnController();
  autoPageTurnIntervalDialogSession: SystemDialogSession = new SystemDialogSession();
  @State @Watch('onSystemDialogFlagChanged') showAutoPageTurnIntervalDialog: boolean = false;
  @StorageLink('readerScreenTimeoutMinutes') readerScreenTimeoutMinutes: number =
    ReaderSettingsStore.SCREEN_TIMEOUT_FOLLOW_SYSTEM;
  @StorageLink('readerExtendToStatusBar') @Watch('onReaderExtendToStatusBarChanged') readerExtendToStatusBar: boolean = false;
  @StorageLink('readerPreloadEnabled') @Watch('onReaderPreloadChanged') readerPreloadEnabled: boolean = true;
  @StorageLink('readerPreloadChapterCount') @Watch('onReaderPreloadChanged') readerPreloadChapterCount: number = 1;
  @StorageLink('readerUseTtsQuickAction') readerUseTtsQuickAction: boolean = true;
  @StorageLink('readerTtsQuickActionSide') readerTtsQuickActionSide: number = 1;
  @StorageLink('readerUseChapterQuickJump') readerUseChapterQuickJump: boolean = true;
  @StorageLink('readerQuickBookmarkEnabled') readerQuickBookmarkEnabled: boolean = true;
  @StorageLink('readerHeaderEnabled') @Watch('onReaderChromeChanged') readerHeaderEnabled: boolean = false;
  @StorageLink('readerHeaderContentMode') @Watch('onReaderChromeChanged') readerHeaderContentMode: string = 'chapter';
  @StorageLink('readerFooterEnabled') @Watch('onReaderChromeChanged') readerFooterEnabled: boolean = true;
  @StorageLink('readerFooterLeftMode') @Watch('onReaderChromeChanged') readerFooterLeftMode: string = 'chapter';
  @StorageLink('readerFooterProgressMode') @Watch('onReaderChromeChanged') readerFooterProgressMode: string = 'page';
  @StorageLink('readerFooterShowProgressBar') @Watch('onReaderChromeChanged') readerFooterShowProgressBar: boolean = false;
  @StorageLink('readerReplaceRulesUpdateTime') @Watch('onReaderReplaceRulesChanged') readerReplaceRulesUpdateTime: number = 0;
  @StorageLink('readerFontFamily') @Watch('onReaderFontChanged') readerFontFamily: string = '';
  @StorageLink('readerFontFilePath') @Watch('onReaderFontChanged') readerFontFilePath: string = '';
  @StorageLink('readerSystemFontFamily') @Watch('onReaderActiveFontChanged') readerSystemFontFamily: string = '';
  @StorageLink('readerActiveFontFamily') @Watch('onReaderActiveFontChanged') readerActiveFontFamily: string = '';
  @StorageLink('readerFontRegistered') @Watch('onReaderActiveFontChanged') readerStoredFontRegistered: boolean = false;
  @StorageLink('readerBodyFontMode') @Watch('onReaderFontStyleChanged') readerBodyFontMode: string = 'global';
  @StorageLink('readerBodyFontFamily') @Watch('onReaderFontStyleChanged') readerBodyFontFamily: string = '';
  @StorageLink('readerTitleFontMode') @Watch('onReaderFontStyleChanged') readerTitleFontMode: string = 'global';
  @StorageLink('readerTitleFontFamily') @Watch('onReaderFontStyleChanged') readerTitleFontFamily: string = '';
  @StorageLink('readerTitleFontSize') @Watch('onReaderFontStyleChanged') readerTitleFontSize: number = 22;
  @StorageLink('readerRegexFontEnabled') @Watch('onReaderFontStyleChanged') readerRegexFontEnabled: boolean = false;
  @StorageLink('readerRegexFontPattern') @Watch('onReaderFontStyleChanged') readerRegexFontPattern: string = '';
  @StorageLink('readerRegexFontMode') @Watch('onReaderFontStyleChanged') readerRegexFontMode: string = 'global';
  @StorageLink('readerRegexFontFamily') @Watch('onReaderFontStyleChanged') readerRegexFontFamily: string = '';
  @StorageLink('readerRegexFontSize') @Watch('onReaderFontStyleChanged') readerRegexFontSize: number = 20;
  @StorageLink('readerRegexShadowColor') @Watch('onReaderFontStyleChanged') readerRegexShadowColor: string = '';
  @StorageLink('readerRegexFontRulesRaw') @Watch('onReaderFontStyleChanged') readerRegexFontRulesRaw: string = '';
  @State activeReaderFontFamily: string = '';
  @State readerFontRegistered: boolean = false;
  @State readerFontRenderReady: boolean = false;
  @StorageLink('appDarkMode') @Watch('onReaderColorModeChanged') appDarkMode: boolean = false;
  @StorageLink('appThemeMode') appThemeMode: string = 'system';
  @StorageLink('themeRevision') @Watch('onReaderThemeChanged') themeRevision: number = 0;
  @StorageLink('appLightAccentColor') appLightAccentColor: string = '#007DFF';
  @StorageLink('appDarkAccentColor') appDarkAccentColor: string = '#4E9BFF';
  @StorageLink('appLightButtonColor') appLightButtonColor: string = '#007DFF';
  @StorageLink('appDarkButtonColor') appDarkButtonColor: string = '#3F8CFF';
  @StorageLink('bookshelfCoverAlbums') @Watch('onTtsCoverSettingsChanged') bookshelfCoverAlbums: string = '';
  @StorageLink('bookshelfLightCoverAlbumId') @Watch('onTtsCoverSettingsChanged') bookshelfLightCoverAlbumId: string = '';
  @StorageLink('bookshelfDarkCoverAlbumId') @Watch('onTtsCoverSettingsChanged') bookshelfDarkCoverAlbumId: string = '';
  @StorageLink('bookshelfCoverApplyScope') @Watch('onTtsCoverSettingsChanged') bookshelfCoverApplyScope: string = 'all';
  @StorageLink('bookshelfCoverTargetBooks') @Watch('onTtsCoverSettingsChanged') bookshelfCoverTargetBooks: string = '';
  @StorageLink('bookshelfIgnoreSourceCover') @Watch('onTtsCoverSettingsChanged') bookshelfIgnoreSourceCover: boolean = false;
  @StorageLink('bookshelfCoverMode') @Watch('onTtsCoverSettingsChanged') bookshelfCoverMode: string = 'sequence';
  @StorageLink('coverGalleryUpdateTime') @Watch('onTtsCoverSettingsChanged') coverGalleryUpdateTime: number = 0;
  @StorageLink('ttsPerson') ttsPerson: number = 0;
  @StorageLink('ttsOnline') ttsOnline: number = 1;
  @StorageLink('ttsStyle') ttsStyle: string = '';
  @StorageLink('ttsLanguage') ttsLanguage: string = 'zh-CN';
  @StorageLink('ttsSpeed') ttsSpeed: number = 1;
  @StorageLink('ttsInstalledVoiceKeys') ttsInstalledVoiceKeys: string = '';
  @StorageLink('ttsCustomVoiceId') ttsCustomVoiceId: string = '';
  @StorageLink('ttsCustomVoices') @Watch('onTtsCustomVoicesChanged') ttsCustomVoices: string = '';
  @StorageLink('launchShortcutNonce') @Watch('onLaunchShortcutChanged') launchShortcutNonce: number = 0;
  @StorageLink('fullTextCacheCancelNonce') @Watch('onFullTextCacheCancelNonceChanged') fullTextCacheCancelNonce: number = 0;
  @State ttsVoices: TtsVoiceOption[] = [LeafFns.defaultTtsVoice()];
  @State ttsCustomVoiceOptions: HttpTTS[] = [];
  @State ttsSelectedVoiceKey: string = '';
  @State ttsVoicesLoading: boolean = false;
  @State ttsDownloadingVoiceKey: string = '';
  @State showTtsVoiceDropdown: boolean = false;
  @State ttsVoiceRowPressedKey: string = '';
  @State fullTextCaching: boolean = false;
  @State fullTextCacheDone: number = 0;
  @State fullTextCacheTotal: number = 0;
  @State fullTextCacheStatus: string = '';
  @State @Watch('onSystemDialogFlagChanged') showReaderCacheDialog: boolean = false;
  @State @Watch('onSystemDialogFlagChanged') showReaderChapterCacheDialog: boolean = false;
  @State readerCacheChapters: BookChapter[] = [];
  @State readerCacheStatus: string = '';
  @State readerCacheRangeDraft: string = '';
  @State readerCacheRangeCaching: boolean = false;
  readerCacheLoadSerial: number = 0;
  readerCacheRangeCancelRequested: boolean = false;
  fullTextCacheTaskId: number = 0;
  fullTextCacheCancelRequested: boolean = false;
  fullTextCacheCancelSeenNonce: number = 0;
  fullTextCacheNotificationLastAt: number = 0;
  fullTextCacheBackgroundRunning: boolean = false;
  fullTextCacheCancelAgent: WantAgent | null = null;
  fullTextCacheTaskKey: string = '';
  fullTextCacheStartIndex: number = 0;
  fullTextCacheStoppingNotificationTask: Promise<void> | null = null;
  volumeUpCallback?: (event: KeyEvent) => void;
  volumeDownCallback?: (event: KeyEvent) => void;
  lastLoggedReaderFontFamily: string = '';
  readerFontChangeSerial: number = 0;
  readerLayoutApplyTimerId: number = -1;
  readerLayoutStabilizeTimerId: number = -1;
  readerExtendLayoutRefreshTimerId: number = -1;
  readerBottomInfoBarMeasureTimerId: number = -1;
  readerBottomInfoBarPendingHeight: number = 0;
  readerExtendLayoutReadingOffset: number = -1;
  readerTypographyRestoreOffset: number = -1;
  // 章节归属标记：restore offset 是章内坐标系，跨章后必须作废，
  // 防止旧章深位置偏移被钳制映射到新章末页（章末“跳末页再弹回首页”竞态）。
  readerTypographyRestoreOffsetChapterIndex: number = -1;
  // Theme changes can publish appDarkMode and themeRevision in the same frame. Keep a single
  // re-pagination transaction for that pair so the visible page does not jump twice.
  readerThemeRefreshTimerId: number = -1;
  readerThemeRefreshOffset: number = -1;
  readerPageContentTopPaddingSnapshot: number = -1;
  readerLayoutCommitInProgress: boolean = false;
  readerTypographyDraftPending: boolean = false;
  @State readerTypographyValueRevision: number = 0;
  @State readerTypographyFontSize: number = 20;
  @State readerTypographyLetterSpacing: number = 0;
  @State readerTypographyLineHeight: number = 12;
  @State readerTypographyParagraphSpacing: number = 0;
  @State readerTypographyMarginLeft: number = 18;
  @State readerTypographyMarginRight: number = 18;
  @State readerTypographyMarginTop: number = 18;
  @State readerTypographyMarginBottom: number = 18;
  readingProgressSaveQueue: Promise<void> = Promise.resolve();
  readerProgressAnchorChapterIndex: number = -1;
  readerProgressAnchorPageIndex: number = 0;
  readerProgressAnchorOffset: number = -1;
  readerProgressAnchorPageCount: number = 1;
  readerProgressAnchorPageText: string = '';
  readerProgressAnchorPageImage: string = '';
  // A freshly mounted reader can publish the first incremental pages before the saved offset/page is restored.
  // Until that restore is confirmed, lifecycle saves must keep using the immutable database snapshot below.
  readerProgressRestoreConfirmed: boolean = false;
  readerExitProgressSaved: boolean = false;
  openedFromShortcut: boolean = false;
  shortcutReplacedPreviousPage: boolean = false;
  shortcutRoutingActive: boolean = false;
  readerEntryInitializing: boolean = true;
  readerSettingsReloadSerial: number = 0;
  returningFromReaderReplaceRules: boolean = false;
  openedWithShelfAnimation: boolean = false;
  readerScreenTimeoutTimerId: number = -1;
  readerScreenTimeoutSerial: number = 0;
  readerScreenOrientationSerial: number = 0;
  readerObservedBackgroundRevision: number = 0;
  readerPageVisible: boolean = false;
  readerCommentPanelMarker: string = '';
  readerCommentPanelAnchorBottom: number = -1;
  readerCommentPageAreaTop: number = -1;
  readerCommentPageAreaHeight: number = 0;
  readerCommentPanelController: webview.WebviewController = new webview.WebviewController();
  readerEyeTurnController: EyeTurnController = new EyeTurnController();
  arEyeTurnHost: ArEyeTurnHost | null = null;
  arEyeTurnHostLoading: boolean = false;
  @State arEyeTurnHostMounted: boolean = false;
  arEngineFaceActive: boolean = false;
  readerEyeTurnSurfaceController: XComponentController = new XComponentController();
  readerEyeTurnSurfaceId: string = '';
  readerEyeTurnConfiguredLandscape: boolean = false;
  @State readerEyeTurnStatus: string = '未启用';
  @State showReaderEyeCalibration: boolean = false;
  @State readerEyeCalibrationStep: number = 1;
  @State readerEyeCalibrationCapturing: boolean = false;
  @State readerEyeCalibrationProgress: number = 0;
  @State readerEyeCalibrationTargetY: number = 0;
  @State readerEyeCalibrationOverlayWidth: number = 0;
  @State readerEyeCalibrationOverlayHeight: number = 0;
  readerEyeCalibrationPoints: ReaderEyeCalibrationPoint[] = [];
  readerEyeCalibrationTimerId: number = -1;
  readerEyeCalibrationSequenceStartedAt: number = 0;
  readerEyeCalibrationPhaseStartedAt: number = 0;
  @State readerEyeCalibrationSessionActive: boolean = false;
  readerEyeCalibrationStartupAt: number = 0;
  readerEyeCalibrationLandscape: boolean = false;
  readerEyePermissionRequestSerial: number = 0;
//endregion
//region 生命周期 / 全局监听 / @Watch 回调
// [map] 契约: 读写 会话/进度/可见性/焦点 状态; 装配后台控制器、注册(并应注销)全局监听与 @Watch

  async aboutToAppear() {
    // 后台/媒体控制器必须先于一切回调注册装配完成（aboutToAppear 是 async，避免 await 后才初始化）。
    this.ttsBackgroundCtrl = new ReaderTtsBackgroundController(new ReadBookTtsBackgroundHost(this));
    // isLoading 初始即 true（后续同值赋值不触发 @Watch），这里显式启动慢加载提示计时。
    this.scheduleReaderLoadingSlowHint();
    ReaderProgressCheckpoint.attach(this.ttsFloatingSessionOwnerId,
      (): Promise<void> => this.flushReadingProgressCheckpoint());
    // External audio interruptions (calls, other media apps) only flip flags inside the
    // players. Republish the floating session so the capsule reflects the paused state.
    this.ttsReader.setOnInterruptedChangeListener(() => {
      this.updateTtsFloatingSession();
    });
    this.readerPageVisible = true;
    this.readerObservedBackgroundRevision = AppStorage.get<number>('appLifecycleBackgroundRevision') || 0;
    this.applyReaderStatusBarSafeHeight(this.storedStatusBarHeight);
    this.applyReaderScreenOrientation();
    this.shortcutRoutingActive = true;
    this.readerEntryInitializing = true;
    this.enterReaderImmersive();
    this.updateVolumeKeySubscription();
    const params = router.getParams() as Record<string, string>;
    this.openedWithShelfAnimation = !!params && params['shelfBookOpening'] === 'true';
    this.openedFromShortcut = !!params && params['shortcutEntry'] === 'true';
    this.shortcutReplacedPreviousPage = !!params && params['shortcutReplace'] === 'true';
    if (params && params['bookUrl']) {
      this.bookUrl = params['bookUrl'];
      ReaderOpenTrace.beginIfNeeded(this.bookUrl);
      ReaderOpenTrace.mark(this.bookUrl, 'reader-page-appear');
      this.isLoading = true;
      this.loadStatus = '正在加载...';
      this.resetReaderStateForBookLoad();
      ReadBookEngine.get().prewarmOpen(this.bookUrl).catch((error: Error) => {
        console.warn('[ReaderOpen] reader prewarm failed:', error);
      });
    }
    try {
      let initialReplaceRules: ReaderReplaceRule[] = [];
      await Promise.all([
        this.loadReaderSettings(),
        ReaderReplaceRuleStore.load(getContext(this)).then((rules: ReaderReplaceRule[]): void => {
          initialReplaceRules = rules;
        })
      ]);
      this.readerReplaceRules = initialReplaceRules;
      ReaderOpenTrace.mark(this.bookUrl, 'reader-settings-ready', `replaceRules=${initialReplaceRules.length}`);
      this.loadTtsSettingsAndVoices();
      if (this.bookUrl) {
        await this.loadBook();
        this.loadBookmarks().catch((error: Error) => {
          console.warn('读取书签失败:', error);
        });
    }
    } catch (error) {
      console.error('[ReaderOpen] reader entry initialization failed:', error);
      if (!this.content) {
        this.setReaderContent('打开书籍失败。请返回书架后重试。');
      }
      this.isLoading = false;
    } finally {
      this.readerEntryInitializing = false;
      if (this.autoPageTurnActive) {
        this.startAutoPageTurn();
      }
    }
  }

  onPageShow(): void {
    this.readerPageVisible = true;
    const backgroundRevision = AppStorage.get<number>('appLifecycleBackgroundRevision') || 0;
    const returningFromBackground = backgroundRevision > this.readerObservedBackgroundRevision;
    this.readerObservedBackgroundRevision = backgroundRevision;
    this.resumeReaderPaginationWorkAfterPageShow();
    if (this.pagedContentText && this.shouldUseReaderLayoutV2(this.pagedContentText) &&
      !this.readerV2PageSet(this.currentChapterIndex, this.pagedContentText)) {
      this.readerInitialPageReady = false;
      this.pendingRestorePageIndex = Math.max(this.pendingRestorePageIndex, this.currentPageIndex);
      this.paginateContent(this.content);
    }
    if (returningFromBackground) {
      // The chapter-scoped V2 ForEach host can be retained from the page on which the chapter was first mounted.
      // Give a real foreground resume a fresh host so ArkUI cannot replay that old subtree after the controller has
      // already been rebound to the current page. Ordinary page turns still reuse one native node.
      this.readerV2SurfaceGeneration++;
      // 后台朗读期间页码/高亮已继续推进。先按最新朗读焦点同步一次（内部实时校验会话/内容代际，
      // 不满足时保持原状），再重发页面表面——否则先按冻结的 currentPageIndex 强制重建一帧陈旧
      // 页面，随后的 0ms 定时器又跳到真实页码，既闪一帧不一致内容，又让回前台首帧做两次全量重建。
      this.syncTtsFocusAfterResume();
      this.republishCurrentReaderPageAfterBackground();
    }
    this.applyReaderScreenOrientation();
    this.applyReaderScreenTimeout();
    this.shortcutRoutingActive = true;
    const returningFromReplaceRules = this.returningFromReaderReplaceRules;
    this.returningFromReaderReplaceRules = false;
    if (!this.readerEntryInitializing && !returningFromBackground) {
      if (returningFromReplaceRules) {
        // 规则页只会改变替换净化配置，返回时仅重载规则并重排一次。
        this.reloadReaderReplaceRules(true).catch((error: Error) => {
          console.warn('恢复替换净化规则失败:', error);
        });
      } else {
        this.reloadReaderSettingsAfterPageShow().catch((error: Error) => {
          console.warn('恢复阅读设置失败:', error);
        });
        this.reloadReaderReplaceRules(true).catch((error: Error) => {
          console.warn('恢复替换净化规则失败:', error);
        });
        this.reloadSourceInteractionsAfterPageShow().catch((error: Error) => {
          console.warn('恢复书源交互设置失败:', error);
        });
      }
    }
    if (!returningFromReplaceRules) {
      this.reregisterReaderFontAfterShow(0);
      this.reregisterReaderFontAfterShow(120);
    }
    this.ttsFocusResumeRetryDeadline = Date.now() + 8000;
    this.syncTtsFocusAfterResumeLater(0);
    this.syncTtsFocusAfterResumeLater(180);
    this.startReaderEyeTurnIfReady();
    if (this.autoPageTurnActive) {
      this.startAutoPageTurn();
    }
  }

  onGlobalTtsActiveChanged(): void {
    if (!this.globalTtsActive) {
      this.clearMirroredTtsFocus();
    }
  }

  onGlobalTtsRevisionChanged(): void {
    if (!this.isMirroringActiveTtsForCurrentBook()) {
      return;
    }
    // The hidden owner can still publish the outgoing sentence while this mirror is animating a
    // manual turn. Applying it here would snap the visible page back before the target is committed.
    if (this.mirroredTtsManualTurnPending) return;
    // 播放中的后台会话尽快接管，避免长期停留在镜像模式（双实例竞争的根治点）。
    if (!this.globalTtsPaused && !this.ttsSessionTakeoverAttempted) {
      this.takeOverMirroredTtsSession().catch((error: Error) => {
        console.warn('接管后台朗读会话失败:', error);
      });
      return;
    }
    if (this.ttsSessionTakeoverInProgress) return;
    this.syncMirroredTtsFocus().catch((error: Error) => {
      console.warn('同步后台朗读正文焦点失败:', error);
    });
  }

  onBackPress(): boolean {
    if (this.showReaderEyeCalibration) {
      this.cancelReaderEyeCalibration();
      return true;
    }
    if (this.showReaderCommentPanel) {
      this.closeReaderCommentPanel();
      return true;
    }
    if (this.showGlobalTtsCatalog) {
      this.closeGlobalTtsCatalog();
      return true;
    }
    if (this.showTtsVoiceDropdown) {
      this.showTtsVoiceDropdown = false;
      return true;
    }
    if (this.showTxtCharsetDialog) {
      if (!this.txtCharsetApplying) this.showTxtCharsetDialog = false;
      return true;
    }
    if (this.showTapZoneSettings) {
      this.showTapZoneSettings = false;
      return true;
    }
    if (this.showLayoutElementSettings) {
      this.showLayoutElementSettings = false;
      return true;
    }
    if (this.showBookmarkActionMenu) {
      this.closeBookmarkActionMenu();
      return true;
    }
    if (this.showChangeSourceDialog) {
      this.showChangeSourceDialog = false;
      return true;
    }
    if (this.showToc || this.showSettings || this.showMenu) {
      this.showToc = false;
      this.hideReaderPanels();
      return true;
    }
    this.exitReaderPage();
    return true;
  }

  async reloadReaderSettingsAfterPageShow(): Promise<void> {
    return ReaderLifecycleOps.reloadReaderSettingsAfterPageShow(this);
  }

  async reloadSourceInteractionsAfterPageShow(): Promise<void> {
    return ReaderLifecycleOps.reloadSourceInteractionsAfterPageShow(this);
  }

  reregisterReaderFontAfterShow(delayMs: number): void {
    ReaderLifecycleOps.reregisterReaderFontAfterShow(this, delayMs);
  }

  aboutToDisappear() {
    AppStorage.setOrCreate<boolean>('shelfReaderDirectTransition', false);
    this.resetReaderScreenOrientation();
    this.readerPageVisible = false;
    this.autoPageTurnController.stop();
    this.cancelReaderLoadingSlowHint();
    this.stopArEyeTurnHost();
    this.readerEyeTurnController.stop().catch((error: Error): void => {
      console.warn('[EyeTurn] reader disappear release failed:', error.message);
    });
    this.setReaderTextSelectionActive(false);
    this.cancelReaderPaginationWork(true);
    this.resetReaderPageCurl();
    if (this.readerExtendLayoutRefreshTimerId >= 0) {
      clearTimeout(this.readerExtendLayoutRefreshTimerId);
      this.readerExtendLayoutRefreshTimerId = -1;
    }
    if (this.readerLayoutStabilizeTimerId >= 0) {
      clearTimeout(this.readerLayoutStabilizeTimerId);
      this.readerLayoutStabilizeTimerId = -1;
    }
    if (this.readerBottomInfoBarMeasureTimerId >= 0) {
      clearTimeout(this.readerBottomInfoBarMeasureTimerId);
      this.readerBottomInfoBarMeasureTimerId = -1;
    }
    if (this.readerPaginationBottomFitTimerId >= 0) {
      clearTimeout(this.readerPaginationBottomFitTimerId);
      this.readerPaginationBottomFitTimerId = -1;
    }
    if (this.readerThemeRefreshTimerId >= 0) {
      clearTimeout(this.readerThemeRefreshTimerId);
      this.readerThemeRefreshTimerId = -1;
    }
    this.readerThemeRefreshOffset = -1;
    this.readerBottomInfoBarPendingHeight = 0;
    this.readerExtendLayoutReadingOffset = -1;
    this.setReaderTypographyRestoreOffset(-1);
    this.flushPendingReaderLayoutChange(false);
    this.releaseReaderScreenTimeout();
    this.shortcutRoutingActive = false;
    this.flushPendingTtsSpeedSettings();
    this.cancelMirroredTtsManualPageTurn();
    const finalProgressSave = this.flushReadingProgressCheckpoint();
    if (!ReaderTtsFloatingSession.isOwner(this.ttsFloatingSessionOwnerId)) {
      this.stopTtsReading();
      this.ttsReader.shutdown();
    }
    if (!this.readerExitProgressSaved) {
      finalProgressSave.catch((error: Error) => {
        console.error('离开阅读页保存进度失败:', error);
      });
    }
    // Keep this owner valid until its final serialized checkpoint settles. A newly attached reader replaces the
    // owner immediately, which invalidates this old write; detach(ownerId) cannot detach that newer owner.
    finalProgressSave.finally(() => {
      ReaderProgressCheckpoint.detach(this.ttsFloatingSessionOwnerId);
    });
    this.unregisterVolumeKeyTurn();
    this.exitReaderImmersive();
  }

  onLaunchShortcutChanged(): void {
    if (!this.shortcutRoutingActive) {
      return;
    }
    this.openPendingShortcut();
  }

  onPageHide(): void {
    this.shortcutRoutingActive = false;
    this.readerPageVisible = false;
    this.autoPageTurnController.stop();
    this.stopArEyeTurnHost();
    this.readerEyeTurnController.stop().catch((error: Error): void => {
      console.warn('[EyeTurn] reader background release failed:', error.message);
    });
    this.setReaderTextSelectionActive(false);
    // Capture the authoritative visible page before pausing background workers. Clearing the retained V2
    // document here made canSaveReadingProgress() reject the checkpoint, then forced a full repagination on
    // foreground. Apart from losing progress, the freshly rebuilt page surface visibly jumped on the next turn.
    this.flushReadingProgressCheckpoint().catch((error: Error) => {
      console.warn('阅读页退到后台时保存进度失败:', error);
    });
    this.suspendReaderPaginationWork();
    this.releaseReaderScreenTimeout();
  }
//endregion
//region 书籍加载 / 全文缓存 / 后台长时任务 / 屏幕超时 / 加载遮罩
// [map] 契约: 读写 book/chapters/content/缓存/遮罩 状态; 持有后台长时任务与多个成对 timer

  async openPendingShortcut(): Promise<void> {
    return ReaderLoadCacheOps.openPendingShortcut(this);
  }

  enterReaderImmersive() {
    ReaderLoadCacheOps.enterReaderImmersive(this);
  }

  exitReaderImmersive() {
    ReaderLoadCacheOps.exitReaderImmersive(this);
  }

  updateStatusBarSafeHeight(mainWindow: window.Window): void {
    ReaderLoadCacheOps.updateStatusBarSafeHeight(this, mainWindow);
  }

  onStoredStatusBarHeightChanged(): void {
    this.applyReaderStatusBarSafeHeight(this.storedStatusBarHeight);
  }

  applyReaderStatusBarSafeHeight(height: number): void {
    ReaderLoadCacheOps.applyReaderStatusBarSafeHeight(this, height);
  }

  async loadBook() {
    const loadSerial = ++this.bookLoadSerial;
    this.isLoading = true;
    this.loadStatus = '正在加载...';
    this.resetReaderStateForBookLoad();
    try {
      const db = AppDatabase.getInstance();
      await db.initWithContext(getContext(this));
      ReaderOpenTrace.mark(this.bookUrl, 'database-ready');

      const engine = ReadBookEngine.get();
      const preparedBook = engine.getPreparedBook(this.bookUrl);
      // The retained engine is valuable for chapters/content, but its Book object can lag behind the serialized
      // exit checkpoint while the shelf close animation is refreshing. Always take progress metadata (including
      // the character-offset variable) from the database; ReadBookEngine will merge it into the retained session.
      const storedBook = await db.getBook(this.bookUrl);
      this.book = storedBook || preparedBook;
      ReaderOpenTrace.mark(this.bookUrl, 'book-record-ready',
        preparedBook ? 'sessionReused=true' : 'sessionReused=false');
      if (loadSerial !== this.bookLoadSerial) {
        return;
      }
      if (!this.book) {
        this.setReaderContent('书籍不存在，请先从搜索结果加入书架。');
        this.isLoading = false;
        return;
      }
      const sourceForType = this.book.origin && this.book.origin !== 'local' ?
        (engine.getPreparedSource(this.book.bookUrl, this.book.origin) || await db.getBookSource(this.book.origin)) :
        null;
      await this.prepareReaderWebFetchRuntime(sourceForType);
      BookTypeSupport.applyBookType(this.book, sourceForType);
      if (BookTypeSupport.isAudio(this.book)) {
        await db.updateBook(this.book, false);
        ReaderOpenTrace.finish(this.bookUrl, 'redirect-audio-reader');
        await router.replaceUrl({
          url: 'pages/AudioBook',
          params: {
            bookUrl: this.book.bookUrl,
            shelfBookOpening: this.openedWithShelfAnimation ? 'true' : 'false',
            shortcutEntry: this.openedFromShortcut ? 'true' : 'false',
            shortcutReplace: this.shortcutReplacedPreviousPage ? 'true' : 'false'
          }
        });
        return;
      }
      if (LocalBookService.isWebDavBook(this.book)) {
        this.loadStatus = '正在检查 WebDAV 书籍...';
        this.book = await WebDavBookService.ensureCached(getContext(this), this.book,
          (message: string): void => {
            this.loadStatus = message;
          });
      }
      if (this.book.origin === LocalBookService.ORIGIN) {
        this.loadStatus = '正在优化本地书籍...';
        const rebuilt = await LocalBookService.ensureLocalParserCurrent(getContext(this), this.book);
        if (rebuilt) {
          const rebuiltBook = await db.getBook(this.bookUrl);
          if (rebuiltBook) this.book = rebuiltBook;
        }
      }
      if (loadSerial !== this.bookLoadSerial) {
        return;
      }
      if (Book.hasStartedReading(this.book)) {
        this.markBookRecentlyRead().catch((error: Error) => {
          console.warn('更新最近阅读时间失败:', error);
        });
      }

      const requestedBookUrl = this.book.bookUrl;
      const opened = await this.withReaderFetchTimeout(engine.openBook(this.book, sourceForType),
        READER_OPEN_FETCH_TIMEOUT_MS);
      if (opened === null) {
        throw new Error('打开书籍超时');
      }
      ReaderOpenTrace.mark(this.bookUrl, 'reader-engine-ready', `chapters=${engine.chapters.length}`);
      if (loadSerial !== this.bookLoadSerial || engine.book?.bookUrl !== requestedBookUrl) {
        return;
      }
      this.book = engine.book || this.book;
      this.chapters = engine.chapters;
      this.initializeReaderComicMode();
      const activeTtsChapterIndex = this.activeMirroredTtsChapterIndex();
      const savedChapterIndex = activeTtsChapterIndex >= 0 ? activeTtsChapterIndex : engine.curIdx;
      this.currentChapterIndex = this.clampChapterIndex(savedChapterIndex);
      const savedPosition = this.currentChapterIndex === savedChapterIndex ? Math.max(0, engine.curPos) : 0;
      // 镜像打开（后台朗读进行中重进）：落页锚点直接取后台会话正在朗读的句偏移，而不是
      // 滞后的保存进度/引擎页码。首帧即定位到朗读句所在页，避免“先落旧页、镜像同步或
      // 接管完成时再明显跳到朗读页”的二次跳动干扰。
      const liveTtsAnchorOffset = activeTtsChapterIndex >= 0 && Number.isFinite(this.globalTtsOffsetStart) ?
        Math.max(0, Math.round(this.globalTtsOffsetStart)) : -1;
      const savedOffset = activeTtsChapterIndex < 0 ?
        savedReaderProgressOffset(this.book, this.currentChapterIndex) : liveTtsAnchorOffset;
      if (savedOffset >= 0) {
        this.setReaderTypographyRestoreOffset(savedOffset);
        this.pendingRestorePageIndex = -1;
      } else {
        this.pendingRestorePageIndex = savedPosition;
      }
      const restoringStoredProgress = activeTtsChapterIndex < 0 && Book.hasStartedReading(this.book);
      this.readerProgressRestoreConfirmed = !restoringStoredProgress;
      if (restoringStoredProgress) {
        // Seed the exit checkpoint before pagination starts. If the user immediately backs out, the transient
        // first incremental spread must never replace the last position that was already durable in the database.
        this.readerProgressAnchorChapterIndex = this.currentChapterIndex;
        this.readerProgressAnchorPageIndex = savedPosition;
        this.readerProgressAnchorOffset = savedOffset;
        const storedPageCount = Number(this.book.getVariable('readProgressPageCount'));
        this.readerProgressAnchorPageCount = Number.isFinite(storedPageCount) && storedPageCount > 0 ?
          Math.round(storedPageCount) : Math.max(1, savedPosition + 1);
        const shelfSnapshot = await AppDatabase.getInstance().getBookShelfSnapshot(this.book.bookUrl);
        this.readerProgressAnchorPageText = shelfSnapshot?.pageText ?? '';
        this.readerProgressAnchorPageImage = shelfSnapshot?.pageImage ?? '';
      }
      this.readerLightThemeIndex = ReaderThemeHelper.normalizeIndex(this.readerLightThemeIndex);
      this.readerDarkThemeIndex = ReaderThemeHelper.normalizeIndex(this.readerDarkThemeIndex);

      if (this.chapters.length > 0) {
        await this.loadContent();
        ReaderOpenTrace.mark(this.bookUrl, 'reader-content-ready', `chapter=${this.currentChapterIndex}`);
        await this.syncMirroredTtsFocus();
      } else if (this.book.origin !== 'local' && this.book.origin) {
        if (!isNetworkAvailable()) {
          // 本地无缓存目录且离线：明确提示需联网首次获取目录，避免误以为“书坏了”。
          this.setReaderContent(`《${this.book.name}》\n\n作者：${this.book.author || '未知'}\n来源：${this.book.originName || this.book.origin}\n\n本地无缓存目录，当前网络不可用。\n请联网后再次打开，首次获取目录后即可离线阅读。`);
          this.isLoading = false;
        } else {
          this.setReaderContent(`《${this.book.name}》\n\n作者：${this.book.author || '未知'}\n来源：${this.book.originName || this.book.origin}\n\n正在尝试解析目录...`);
          this.loadStatus = '正在获取目录...';
          await this.retryFetchChapters();
        }
      } else {
        this.setReaderContent(this.buildBookPreview());
        this.isLoading = false;
      }
    } catch (e) {
      console.error('加载书籍失败:', e);
      this.setReaderContent('书籍或目录加载失败。请点击右上角“更多操作”，选择“重试”重新加载。');
      this.isLoading = false;
    } finally {
      this.updatePendingVerification();
    }
  }

  async prepareReaderWebFetchRuntime(source: BookSource | null): Promise<void> {
    return ReaderLoadCacheOps.prepareReaderWebFetchRuntime(this, source);
  }

  async retryFetchChapters() {
    try {
      const engine = ReadBookEngine.get();
      const refreshed = await this.withReaderFetchTimeout(engine.refreshToc(), READER_OPEN_FETCH_TIMEOUT_MS);
      if (refreshed === null) {
        throw new Error('获取目录超时');
      }
      this.book = engine.book || this.book;
      this.chapters = engine.chapters;
      if (this.chapters.length > 0) {
        this.loadStatus = '';
        await this.loadContent();
      } else {
        this.updatePendingVerification();
        this.setReaderContent(this.buildBookPreview());
        this.isLoading = false;
      }
    } catch (e) {
      console.error('重试获取目录失败:', e);
      this.updatePendingVerification();
      this.setReaderContent(this.buildBookPreview());
      this.isLoading = false;
    }
  }

  initialReaderViewportSize(): ReaderViewportSize {
    return ReaderLoadCacheOps.initialReaderViewportSize(this);
  }

  resetReaderStateForBookLoad(): void {
    ReaderLoadCacheOps.resetReaderStateForBookLoad(this);
  }

  async loadContent(silent: boolean = false, targetChapterIndex: number = this.currentChapterIndex,
    preferImmediatePagination: boolean = false): Promise<boolean> {
    return ReaderLoadCacheOps.loadContent(this, silent, targetChapterIndex, preferImmediatePagination);
  }

  async refreshCurrentChapter(): Promise<void> {
    return ReaderLoadCacheOps.refreshCurrentChapter(this);
  }

  onFullTextCacheCancelNonceChanged(): void {
    const nonce = this.fullTextCacheCancelNonce || 0;
    if (this.fullTextCaching && nonce > 0 && nonce !== this.fullTextCacheCancelSeenNonce) {
      const signal = FullTextCacheCancelCoordinator.parse(
        AppStorage.get<string>('fullTextCacheCancelSignal') || '');
      if (signal && !FullTextCacheCancelCoordinator.matches(signal, this.fullTextCacheTaskKey,
        this.book?.bookUrl || this.bookUrl)) {
        this.fullTextCacheCancelSeenNonce = nonce;
        return;
      }
      this.beginStoppingFullTextCache(signal ? signal.nonce : nonce, true);
    }
  }

  readerCachePanelStatus(): string {
    return ReaderLoadCacheOps.readerCachePanelStatus(this);
  }

  openReaderCacheDialog(): void {
    if (!this.book || LocalBookService.isLocalBook(this.book)) {
      HdsFeedback.showToast('当前书籍暂无可缓存章节');
      return;
    }
    this.showReaderActionMenu = false;
    this.showMenu = false;
    this.showReaderChapterCacheDialog = false;
    this.showReaderCacheDialog = true;
    this.readerCacheRangeDraft = '';
    this.readerCacheStatus = this.readerCacheRangeCaching ? '正在缓存指定章节...' : '';
    this.refreshReaderCacheChapters();
    this.readerCacheDialogSession.open(this.getUIContext(), (): void => {
      this.readerCacheDialogContent();
    }, {
      autoCancel: false,
      maskColor: this.isReaderThemeDark() ? '#99000000' : '#33000000',
      warnTag: '显示全文缓存弹窗失败:'
    });
  }

  openReaderChapterCacheDialog(): void {
    if (!this.book || LocalBookService.isLocalBook(this.book) || this.fullTextCaching ||
      this.readerCacheRangeCaching) {
      return;
    }
    this.showReaderCacheDialog = false;
    this.showReaderChapterCacheDialog = true;
    this.readerCacheRangeDraft = '';
    this.readerCacheStatus = '正在加载目录...';
    this.refreshReaderCacheChapters();
    this.chapterCacheDialogSession.open(this.getUIContext(), (): void => {
      this.readerChapterCacheDialogContent();
    }, {
      autoCancel: false,
      maskColor: this.isReaderThemeDark() ? '#99000000' : '#33000000',
      warnTag: '显示章节缓存弹窗失败:'
    });
  }

  closeReaderCacheDialog(): void {
    ReaderLoadCacheOps.closeReaderCacheDialog(this);
  }

  async refreshReaderCacheChapters(): Promise<void> {
    return ReaderLoadCacheOps.refreshReaderCacheChapters(this);
  }

  readerCachedChapterTextColor(): string {
    return ReaderLoadCacheOps.readerCachedChapterTextColor(this);
  }

  async cacheReaderSingleChapter(index: number): Promise<void> {
    return ReaderLoadCacheOps.cacheReaderSingleChapter(this, index);
  }

  async cacheReaderChapterRange(): Promise<void> {
    return ReaderLoadCacheOps.cacheReaderChapterRange(this);
  }

  async cacheReaderChapterIndexes(indexes: number[]): Promise<void> {
    return ReaderLoadCacheOps.cacheReaderChapterIndexes(this, indexes);
  }

  cancelReaderChapterRangeCache(): void {
    ReaderLoadCacheOps.cancelReaderChapterRangeCache(this);
  }

  async clearReaderCachedChapters(): Promise<void> {
    return ReaderLoadCacheOps.clearReaderCachedChapters(this);
  }

  startFullTextCache(startIndex: number = 0): void {
    ReaderLoadCacheOps.startFullTextCache(this, startIndex);
  }

  /** Dialog-initiated cancellation; routes through the coordinator like a notification-bar cancel. */
  cancelFullTextCache(): void {
    ReaderLoadCacheOps.cancelFullTextCache(this);
  }

  fullTextCacheScopeLabel(): string {
    return ReaderLoadCacheOps.fullTextCacheScopeLabel(this);
  }

  async runFullTextCache(taskId: number): Promise<void> {
    return ReaderLoadCacheOps.runFullTextCache(this, taskId);
  }

  beginStoppingFullTextCache(nonce: number, showHint: boolean): void {
    ReaderLoadCacheOps.beginStoppingFullTextCache(this, nonce, showHint);
  }

  releaseFullTextCacheCancelRegistration(): void {
    ReaderLoadCacheOps.releaseFullTextCacheCancelRegistration(this);
  }

  shouldCancelFullTextCache(): boolean {
    return ReaderLoadCacheOps.shouldCancelFullTextCache(this);
  }

  clearReaderScreenTimeoutTimer(): void {
    ReaderLoadCacheOps.clearReaderScreenTimeoutTimer(this);
  }

  applyReaderScreenTimeout(): void {
    ReaderLoadCacheOps.applyReaderScreenTimeout(this);
  }

  refreshReaderScreenTimeout(): void {
    ReaderLoadCacheOps.refreshReaderScreenTimeout(this);
  }

  releaseReaderScreenTimeout(): void {
    ReaderLoadCacheOps.releaseReaderScreenTimeout(this);
  }

  setReaderWindowKeepScreenOn(enabled: boolean, serial: number): void {
    ReaderLoadCacheOps.setReaderWindowKeepScreenOn(this, enabled, serial);
  }

  async cacheFullTextChapter(engine: ReadBookEngine, chapterIndex: number, taskId: number): Promise<boolean> {
    return ReaderLoadCacheOps.cacheFullTextChapter(this, engine, chapterIndex, taskId);
  }



  /** Copies fresh cacheDate values from the caching engine's chapters into a rendered list. */

  fullTextCacheProgressText(): string {
    return ReaderLoadCacheOps.fullTextCacheProgressText(this);
  }

  async publishFullTextCacheProgress(force: boolean): Promise<void> {
    return ReaderLoadCacheOps.publishFullTextCacheProgress(this, force);
  }

  async publishFullTextCacheNotification(text: string, additionalText: string, ongoing: boolean): Promise<void> {
    return ReaderLoadCacheOps.publishFullTextCacheNotification(this, text, additionalText, ongoing);
  }

  async requestFullTextCacheNotificationEnabled(): Promise<void> {
    return ReaderLoadCacheOps.requestFullTextCacheNotificationEnabled(this);
  }

  async getFullTextCacheCancelWantAgent(): Promise<WantAgent> {
    return ReaderLoadCacheOps.getFullTextCacheCancelWantAgent(this);
  }

  async startFullTextCacheBackgroundRunning(): Promise<void> {
    return ReaderLoadCacheOps.startFullTextCacheBackgroundRunning(this);
  }

  async stopFullTextCacheBackgroundRunning(): Promise<void> {
    return ReaderLoadCacheOps.stopFullTextCacheBackgroundRunning(this);
  }

  async createFullTextCacheOpenWantAgent(): Promise<WantAgent> {
    return ReaderLoadCacheOps.createFullTextCacheOpenWantAgent(this);
  }

  /** 网络取链限时兜底：挂起时 Promise 永不返回，超时返回 null，由调用方转成可操作的失败态。 */
  async withReaderFetchTimeout<T>(task: Promise<T>, timeoutMs: number): Promise<T | null> {
    let timerId = -1;
    const timeout = new Promise<T | null>((resolve: (value: T | null) => void) => {
      timerId = setTimeout((): void => {
        resolve(null);
      }, timeoutMs);
    });
    try {
      return await Promise.race([task, timeout]);
    } finally {
      if (timerId >= 0) clearTimeout(timerId);
    }
  }

  finishReaderInitialOpening(): void {
    ReaderLoadCacheOps.finishReaderInitialOpening(this);
  }

  shouldRenderPrimaryReaderContent(): boolean {
    return ReaderLoadCacheOps.shouldRenderPrimaryReaderContent(this);
  }

  isPagedReaderAwaitingPagination(): boolean {
    return ReaderLoadCacheOps.isPagedReaderAwaitingPagination(this);
  }

  shouldShowReaderLoadingOverlay(): boolean {
    return ReaderLoadCacheOps.shouldShowReaderLoadingOverlay(this);
  }

  shouldBlockReaderInteraction(): boolean {
    return ReaderLoadCacheOps.shouldBlockReaderInteraction(this);
  }

  getReaderLoadingText(): string {
    return ReaderLoadCacheOps.getReaderLoadingText(this);
  }

  onReaderLoadingChanged(): void {
    if (this.isLoading) {
      this.scheduleReaderLoadingSlowHint();
    } else {
      this.cancelReaderLoadingSlowHint();
    }
  }

  scheduleReaderLoadingSlowHint(): void {
    ReaderLoadCacheOps.scheduleReaderLoadingSlowHint(this);
  }

  cancelReaderLoadingSlowHint(): void {
    ReaderLoadCacheOps.cancelReaderLoadingSlowHint(this);
  }

  /** 逃生口：作废在飞的打开/取文流程，把“无限等待”转成可操作的失败态（可刷新本章/换源/重试）。 */
  cancelReaderLoading(): void {
    ReaderLoadCacheOps.cancelReaderLoading(this);
  }

  @Builder
  readerComicScrollSurface() {
    Stack() {
      List({ space: 0, scroller: this.readerComicScroller }) {
        LazyForEach(this.readerComicPageDataSource, (page: string, index: number) => {
          ListItem() {
            if (LeafFns.isReaderImageOnlyPage(page)) {
              Stack({ alignContent: Alignment.Center }) {
                Image(LeafFns.getReaderEpubImageUri(page))
                  .width('100%')
                  .height(this.getReaderComicImageRenderHeight(index))
                  .margin({ top: -this.getReaderComicImageSeamOverlap(index) })
                  .objectFit(this.getReaderComicImageFit(index))
                  .draggable(false)
                  .onAppear(() => {
                    this.ensureReaderComicImageRatio(index, page).catch((error: Error) => {
                      console.warn('预读取漫画图片尺寸失败:', error);
                    });
                  })
                  .onComplete((event) => {
                    if (event) {
                      this.updateReaderComicImageRatio(index, event.width, event.height);
                    }
                  })
                  .onError((error: ImageError) => {
                    this.markReaderComicImageBroken(index, page, error);
                  })
                if (this.readerComicBrokenPages.includes(index)) {
                  Column({ space: 6 }) {
                    Text('⚠ 图片加载失败')
                      .fontSize(13)
                      .fontColor(this.getSubTextColor())
                    Text(/^(?:https?:|data:)/i.test(LocalBookService.epubImagePathFromMarker(page)) ?
                      '网络图片加载失败，点击重试' : '文件可能已被移动、删除或尚未重新导入')
                      .fontSize(11)
                      .fontColor(this.getSubTextColor())
                      .opacity(0.8)
                  }
                  .width('100%')
                  .onClick(() => {
                    this.retryReaderComicImage(index);
                  })
                }
              }
              .width('100%')
            } else if (this.isReaderNovelContinuousScrollModeActive()) {
              Column() {
                this.styledReaderText(
                  page,
                  0,
                  this.currentChapterIndex,
                  0,
                  this.pageRenderVersion,
                  `reader_vertical_scroll_${this.currentChapterIndex}_${index}`,
                  index,
                  0
                )
              }
              .width('100%')
            } else {
              Column() {
                this.styledReaderText(page, this.getReaderContentBottomPadding(), this.currentChapterIndex,
                  0, this.pageRenderVersion, `reader_comic_fallback_${this.currentChapterIndex}_${index}`, index)
              }
              .width('100%')
              .constraintSize({ minHeight: this.pageViewHeight })
            }
          }
          .width('100%')
        }, (page: string, index: number) => `${this.currentChapterIndex}_${index}_${hashText(page)}`)
      }
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .width('100%')
      .height('100%')
      // In continuous reading the configured vertical margins describe the viewport, not only the first and
      // last pagination fragment. Keep every scrolled line inside those edges. The bottom edge must also
      // reserve the footer band: the footer is a transparent overlay, so without the reserve the last line
      // can never be scrolled clear of the footer text and they permanently overlap.
      .padding({
        top: this.isReaderNovelContinuousScrollModeActive() ? this.getEffectiveReaderMarginTop() : 0,
        bottom: this.isReaderNovelContinuousScrollModeActive() ?
          this.getEffectiveReaderMarginBottom() + this.getReaderContentBottomReserve() : 0
      })
      .enableScrollInteraction(!this.readerTextSelectionActive)
      .scrollBar(BarState.Off)
      // 每个滚动块都是整屏正文（可见 Text + 透明选择 Text 两次排版）。默认只在进入视口时才构建，
      // 快速滑动时会临时排版掉帧；预构建视口外 2 块把排版开销挪到滑动间隙的空闲帧。
      // 漫画模式条目是带显式高度的图片，保持原有时序以隔离行为差异。
      .cachedCount(this.isReaderNovelContinuousScrollModeActive() ? 2 : 0)
      .translate({ y: this.readerComicChapterTransitionY })
      .opacity(this.readerComicChapterTransitionOpacity)
      .onScrollIndex((start: number, end: number) => {
        this.onReaderComicScrollIndexChanged(start, end);
      })
      .onReachEnd(() => {
        this.onReaderContinuousReachEnd();
      })
      .onAppear(() => {
        // A persisted deep/last-page restore can be published before the newly created List has completed its
        // first layout. scrollToIndex() is then accepted but has no visual effect, and the first index callback
        // used to overwrite the durable page with zero. Retry from the mounted surface while the restore guard
        // still owns the authoritative target.
        if (this.readerComicScrollRestoring) this.scheduleReaderComicScrollRestore();
      })

      Column() {
        if (this.readerHeaderEnabled && !!this.getReaderHeaderInfoText() && !this.isReaderComicModeActive()) {
          ReaderHeaderInfoBar({
        infoText: this.getReaderHeaderInfoText(),
        subTextColor: this.getSubTextColor(),
        barHeight: LeafFns.getReaderHeaderInfoBarHeight() + this.getReaderHeaderOverlayTopInset(),
        topInset: this.getReaderHeaderOverlayTopInset()
      })
        }
        Blank()
          .layoutWeight(1)
        if (this.readerFooterEnabled && !this.isReaderComicModeActive()) {
          ReaderBottomInfoBar({
            accentColor: this.accentColor(),
            trackColor: this.readerChapterTrackColor(),
            subTextColor: this.getSubTextColor(),
            showProgressBar: this.readerFooterShowProgressBar,
            progressValue: this.getReaderFooterProgressValue(),
            leftText: this.getReaderFooterLeftText(),
            progressText: this.getReaderFooterProgressText(),
            visualOffsetY: this.getReaderBottomInfoBarVisualOffsetY(),
            onHeightChange: (area: Area): void => {
              this.rememberReaderBottomInfoBarHeight(area);
            }
          })
        }
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)

      if (this.readerComicBoundaryDirection !== 0 || this.readerComicChapterSwitching) {
        ReaderComicBoundaryHint({
          hintText: this.readerComicBoundaryHintText(),
          accentColor: this.accentColor(),
          textColor: this.getTextColor(),
          dark: this.isReaderThemeDark(),
          boundaryDirection: this.readerComicBoundaryDirection,
          pullDistance: this.readerComicBoundaryPullDistance,
          ready: this.readerComicBoundaryReady,
          chapterSwitching: this.readerComicChapterSwitching,
          topPadding: this.readerComicBoundaryHintTopPadding()
        })
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .opacity(this.readerInitialPageReady ? 1 : 0)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.updatePagedReaderArea(newValue);
      this.rememberReaderTapLayerArea(newValue);
    })
    .onTouch((event: TouchEvent) => this.rememberContinuousReaderPointer(event))
    .parallelGesture(
      PanGesture({ direction: PanDirection.Vertical, distance: Math.max(18, this.readerTapSlop * 1.5) })
          .onActionStart(() => {
            if (!this.isReaderNovelContinuousScrollModeActive() || this.readerTextSelectionActive) return;
            this.beginReaderComicPan();
          })
          .onActionUpdate((event: GestureEvent) => {
            if (!this.isReaderNovelContinuousScrollModeActive() || this.readerTextSelectionActive) return;
            this.updateReaderComicPan(event);
          })
          .onActionEnd((event: GestureEvent) => {
            if (!this.isReaderNovelContinuousScrollModeActive()) return;
            if (this.readerTextSelectionActive) {
              this.cancelReaderComicPan();
              return;
            }
            this.finishReaderComicPan(event);
          })
          .onActionCancel(() => {
            this.cancelReaderComicPan();
          }),
      // Track chapter-boundary pans alongside the List and selectable Text instead of taking priority over them.
      // A priority pan makes ArkUI cancel the child's native long press before it can create selection handles.
      GestureMask.Normal
    )
  }

  readerComicBoundaryHintTopPadding(): number {
    return ReaderLoadCacheOps.readerComicBoundaryHintTopPadding(this);
  }

  pageTransition() {
    if (this.openedWithShelfAnimation || AppStorage.get<boolean>('shelfReaderDirectTransition') === true) {
      PageTransitionEnter({ type: RouteType.Push, duration: 0 })
    }
  }
//endregion
//region build / 主内容层 / 悬浮菜单 / 目录·书签·换源·缓存面板
// [map] 契约: 读 主题/排版/章节; 纯渲染 + 面板显隐; 交互只转发到方法, 不写业务状态

  build() {
    Stack() {
      BookSourceStageRuntimeHost()
      if (this.readerWebFetchRuntimeNeeded) {
        WebBookFetchRuntimeHost()
      }
      if (this.readerEyeTurnEnabled) {
        // The camera Surface stays behind the opaque reader background. It is never shown or persisted; only a
        // throttled local PixelMap is sampled while this page is in the foreground.
        XComponent({
          id: 'reader_eye_turn_camera_surface',
          type: XComponentType.SURFACE,
          controller: this.readerEyeTurnSurfaceController
        })
          // Never resize the live camera Surface to 1x1. Some camera drivers use the component's layout viewport
          // as the producer crop even when setXComponentSurfaceRect keeps a 640x480 buffer; shrinking it after
          // calibration then yielded faceNum=0 for every reading-page frame. The opaque theme hides this stable
          // Surface in normal reading mode.
          .width(this.readerEyeCalibrationPreviewWidthVp())
          .height(this.readerEyeCalibrationPreviewHeightVp())
          .position({
            x: this.showReaderEyeCalibration ? this.readerEyeCalibrationPreviewLeftVp() : 0,
            y: this.showReaderEyeCalibration ? LeafFns.readerEyeCalibrationPreviewTopVp() : 0
          })
          // Keep the surface fully rendered even while reading: with a near-zero opacity some
          // builds stop drawing this node, the camera preview stops delivering frames, and the
          // face detector then reports "no face" for the whole reading session. It stays hidden
          // because the opaque reader background is drawn above it (zIndex -1).
          .opacity(1)
          .borderRadius(this.showReaderEyeCalibration ? 20 : 0)
          .clip(true)
          .zIndex(this.showReaderEyeCalibration ? 3 : -1)
          .hitTestBehavior(HitTestMode.None)
          .onLoad((): void => {
            this.readerEyeTurnSurfaceController.setXComponentSurfaceRect({
              surfaceWidth: 640,
              surfaceHeight: 480
            });
            this.readerEyeTurnSurfaceId = this.readerEyeTurnSurfaceController.getXComponentSurfaceId();
            console.info(`[EyeTurn] camera surface loaded id=${this.readerEyeTurnSurfaceId ? 'set' : 'EMPTY'}`);
            this.startReaderEyeTurnIfReady();
          })
          .onDestroy((): void => {
            this.readerEyeTurnSurfaceId = '';
            this.stopArEyeTurnHost();
    this.readerEyeTurnController.stop().catch((error: Error): void => {
              console.warn('[EyeTurn] release surface failed:', error.message);
            });
          })
        if (this.arEyeTurnHostMounted && this.arEyeTurnHost) {
          // Keep the ARView rendered (a fully transparent node never reaches
          // TRACKING) but clamp it to a single pixel behind the page content.
          NodeContainer(this.arEyeTurnHost.controller)
            .width(1).height(1)
            .position({ x: 0, y: 0 })
            .zIndex(-1)
            .hitTestBehavior(HitTestMode.None)
        }
      }
      ReaderThemeBackground({
        surfaceColor: this.getBackgroundColor(),
        backgroundAssetId: this.getBackgroundAssetId(),
        customImage: this.currentReaderTheme().backgroundImageUri,
        customImageFit: this.getBackgroundImageFit(),
        viewportWidthHint: this.pageViewWidth,
        viewportHeightHint: this.getReaderBackgroundViewportHeight()
      })
        .id('reader_theme_background_root')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .hitTestBehavior(HitTestMode.None)

      Column() {
        if (!this.shouldRenderPrimaryReaderContent()) {
          ReaderLoadingPanel({
              accentColor: this.accentColor(),
              panelColor: this.getBackgroundColor(),
              loadingText: this.getReaderLoadingText(),
              dark: this.isReaderThemeDark(),
              slow: this.readerLoadingSlow,
              onCancel: (): void => { this.cancelReaderLoading(); }
            })
        } else if (this.isReaderContinuousScrollSurfaceActive()) {
          this.readerComicScrollSurface()
        } else {
          Stack() {
            if (this.shouldUseReaderLayoutV2(this.pagedContentText)) {
              // Keep the native paragraph node mounted across sequential turns inside one chapter, but give every
              // chapter its own keyed host. Some ArkUI versions retain the old NodeContainer when only its
              // NodeController argument changes; the footer then advances while the canvas keeps painting the
              // previous chapter forever. A chapter-scoped key remounts only at the boundary, while the already
              // prepared incoming leaf remains on top for the short handoff.
              ForEach(this.currentReaderV2ChapterSurfaceKeys(), (_surfaceKey: string) => {
                this.readerActiveCurrentPageSurface(this.pageRenderVersion, this.visibleCurrentPageText(),
                  this.ttsHighlightRenderVersion)
              }, (surfaceKey: string) => surfaceKey)
            } else {
              ForEach(this.currentReaderSurfaceKeys(), (_surfaceKey: string) => {
                this.readerActiveCurrentPageSurface(this.pageRenderVersion, this.visibleCurrentPageText(),
                  this.ttsHighlightRenderVersion)
              }, (surfaceKey: string) => surfaceKey)
            }
            // Keep the V2 TTS focus outside the chapter-scoped正文 host. That host deliberately preserves its
            // native Paragraph node across same-page updates, and some ArkUI builds consequently skip nested
            // ForEach evaluation. Rekey only this lightweight rectangle layer for every audible chunk.
            ForEach(this.currentReaderV2TtsOverlayKeys(this.readerV2TtsPaintVersion), (_focusKey: string) => {
              this.readerCurrentV2TtsOverlay(this.readerV2TtsPaintVersion)
            }, (focusKey: string) => focusKey)
            // Native Text supplies selection handles and the system menu, but its line boxes do not exactly match
            // the Paragraph glyph boxes used to paint正文. Paint the range from Paragraph geometry so text stays
            // vertically centered in the blue selection in every page-turn mode.
            ForEach(this.currentReaderV2SelectionOverlayKeys(this.readerV2SelectionPaintVersion),
              (_selectionPaintKey: string) => {
              this.readerCurrentV2SelectionOverlay(this.readerV2SelectionPaintVersion)
            }, (selectionPaintKey: string) => selectionPaintKey)
            // The retained V2 host above only updates its native canvas during same-chapter turns. Selection Text
            // must be page-keyed outside that host; otherwise its content advances while its paragraph coordinates
            // remain those of the first mounted page, and long-press handles appear on another line.
            ForEach(this.currentReaderV2SelectionSurfaceKeys(this.readerV2NativeSelectionHostVersion),
              (_selectionKey: string) => {
              this.readerCurrentV2SelectionSurface()
            }, (selectionKey: string) => selectionKey)
            // Legacy rich text is keyed by page; V2 updates its retained node in place. Keep the simulation
            // overlay outside both paths so the destination can settle behind the captured leaf without
            // destroying the active Canvas.
            if (this.isPageTurnAnimationEnabled() && this.usesReaderPageCurlCanvas() &&
              this.shouldRenderSlidingPageTurn()) {
              this.readerSimulationPageTurnSurface(this.pageRenderVersion, this.visibleCurrentPageText(),
                this.ttsHighlightRenderVersion, 'overlay')
            }
            // Keep the simulation Canvas mounted for the lifetime of the selected turn mode. Destroying and
            // recreating it at every completed curl races the RenderService submission of the last textured
            // frame (SubmitCanvasPreAllocatedBuffer) and can expose a one-frame handoff shake. The capture
            // surfaces above remain transient; the inexpensive Canvas is merely hidden while it is idle.
            if (this.isPageTurnAnimationEnabled() && this.usesReaderPageCurlCanvas()) {
              this.readerSimulationCurlCanvas()
            }
            Column() {
              if (this.readerHeaderEnabled && !!this.getReaderHeaderInfoText()) {
                ReaderHeaderInfoBar({
        infoText: this.getReaderHeaderInfoText(),
        subTextColor: this.getSubTextColor(),
        barHeight: LeafFns.getReaderHeaderInfoBarHeight() + this.getReaderHeaderOverlayTopInset(),
        topInset: this.getReaderHeaderOverlayTopInset()
      })
              }
              Blank()
                .layoutWeight(1)
              if (this.readerFooterEnabled) {
                ReaderBottomInfoBar({
            accentColor: this.accentColor(),
            trackColor: this.readerChapterTrackColor(),
            subTextColor: this.getSubTextColor(),
            showProgressBar: this.readerFooterShowProgressBar,
            progressValue: this.getReaderFooterProgressValue(),
            leftText: this.getReaderFooterLeftText(),
            progressText: this.getReaderFooterProgressText(),
            visualOffsetY: this.getReaderBottomInfoBarVisualOffsetY(),
            onHeightChange: (area: Area): void => {
              this.rememberReaderBottomInfoBarHeight(area);
            }
          })
              }
            }
            .width('100%')
            .height('100%')
            .hitTestBehavior(HitTestMode.None)
          }
          .width('100%')
          .height('100%')
          .clip(true)
          .opacity(this.readerInitialPageReady ? 1 : 0)
          .onAreaChange((oldValue: Area, newValue: Area) => {
            this.updatePagedReaderArea(newValue);
            this.rememberReaderTapLayerArea(newValue);
          })
        }
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.getReaderTopSafePadding() })
      // 正文未就绪时整列充当加载遮罩。列顶部的状态栏内边距会让遮罩上缘缩进状态栏高度，
      // 主题带背景画时该缝隙会露出 ReaderThemeBackground 的装饰图，因此遮罩期间强制铺不透明底色。
      .backgroundColor(this.shouldRenderPrimaryReaderContent() ? this.readerContentLayerColor() :
        this.getBackgroundColor())
      .hitTestBehavior(HitTestMode.Default)

      if (!this.isReaderContinuousScrollSurfaceActive() && !this.showMenu && !this.showToc && !this.showSettings &&
        !this.shouldBlockReaderInteraction()) {
        ReaderTapLayer({
          pageTurnMode: this.readerEffectivePageTurnMode(),
          tapSlop: this.readerTapSlop,
          verticalPageTurn: this.isVerticalPageTurnAnimation(),
          menuVisible: this.showMenu,
          tocVisible: this.showToc,
          settingsVisible: this.showSettings,
          shouldIgnoreTap: (): boolean => this.consumeSuppressedReaderTapClick(),
          onTapZone: (zone: number): void => {
            this.commitReaderTapZone(zone);
          },
          onPrevPage: (): void => {
            this.turnPrev();
          },
          onNextPage: (): void => {
            this.turnNext();
          },
          onShowMenu: (): void => {
            this.showMenu = true;
          },
          onLayerAreaChange: (area: Area): void => {
            this.rememberReaderTapLayerArea(area);
          },
          onLayerTouch: (event: TouchEvent): void => {
            this.handleReaderTouch(event);
          },
          onPanStart: (event: GestureEvent): void => {
            this.handleReaderPanStart(event);
          },
          onPanUpdate: (event: GestureEvent): void => {
            this.handleReaderPanUpdate(event);
          },
          onPanEnd: (event: GestureEvent): void => {
            this.handleReaderPanEnd(event);
          },
          onPanCancel: (): void => {
            this.handleReaderPanCancel();
          },
          onLongPress: (event: GestureEvent): void => {
            this.selectReaderTextAtGlobalPoint(event);
          }
        })
      }

      if (this.readerComicPaginationParsing) {
        ReaderComicPaginationPanel({
                accentColor: this.accentColor(),
                panelColor: this.getBackgroundColor(),
                textColor: this.getTextColor(),
                dark: this.isReaderThemeDark(),
                parsedPages: this.readerComicPaginationParsedPages,
                totalPages: this.readerComicPaginationTotalPages
              })
      } else if (this.shouldShowReaderLoadingOverlay()) {
        ReaderLoadingPanel({
              accentColor: this.accentColor(),
              panelColor: this.getBackgroundColor(),
              loadingText: this.getReaderLoadingText(),
              dark: this.isReaderThemeDark(),
              slow: this.readerLoadingSlow,
              onCancel: (): void => { this.cancelReaderLoading(); }
            })
      }

      if (this.isReaderContinuousScrollSurfaceActive() && !this.isReaderNovelContinuousScrollModeActive() &&
        !this.showMenu && !this.showToc && !this.showSettings &&
        !this.shouldBlockReaderInteraction() && !this.readerComicChapterSwitching) {
        ReaderComicInteractionLayer({
          panDistance: this.readerTapSlop,
          onLayerClick: (): void => {
            if (this.consumeSuppressedReaderTapClick()) {
              return;
            }
            if (Date.now() >= this.readerComicSuppressClickUntil &&
              !this.showMenu && !this.showToc && !this.showSettings) {
              this.showMenu = true;
            }
          },
          onPanStart: (): void => {
            if (this.isReaderInteractiveActionActive()) {
              return;
            }
            this.beginReaderComicPan();
          },
          onPanUpdate: (event: GestureEvent): void => {
            if (this.isReaderInteractiveActionActive()) {
              return;
            }
            this.updateReaderComicPan(event);
          },
          onPanEnd: (event: GestureEvent): void => {
            if (this.isReaderInteractiveActionActive()) {
              this.cancelReaderComicPan();
              return;
            }
            this.finishReaderComicPan(event);
          },
          onPanCancel: (): void => {
            this.cancelReaderComicPan();
          }
        })
      }

      if (this.bookmarkPullActive) {
        ReaderBookmarkPullHint({
                  hintText: this.bookmarkPullHintText(),
                  hintColor: this.bookmarkPullHintColor(),
                  ready: this.bookmarkPullReady,
                  panelColor: this.readerGlassPanelColor(),
                  glassBorderColor: this.readerGlassBorderColor(),
                  shadowColor: this.readerGlassShadowColor(),
                  topSafePadding: this.getTopControlSafePadding(),
                  pullOffsetY: this.bookmarkPullOffsetY
                })
      }

      if (this.isCurrentPageBookmarked() && !this.showMenu && !this.showToc && !this.showSettings) {
        ReaderCurrentPageBookmarkMarker({
        accentColor: this.accentColor(),
        translateY: this.readerBookmarkMarkerTopOffset() + this.bookmarkPullOffsetY
      })
      }

      if (this.autoPageTurnActive && this.readerInitialPageReady && !this.showMenu && !this.showToc &&
        !this.showSettings && !this.showReaderCommentPanel && !this.isLoading) {
        ReaderAutoPageTurnIndicator({
          accentColor: this.accentColor(),
          ringProgress: this.autoPageTurnRingProgress,
          userPaused: this.autoPageTurnUserPaused,
          textColor: this.getTextColor(),
          darkMode: this.isReaderThemeDark(),
          bottomInset: this.navBarHeight,
          onTogglePause: (): void => {
            this.autoPageTurnController.toggleUserPause();
          },
          onLongPress: (): void => {
            this.presentAutoPageTurnIntervalDialog();
          }
        })
      }

      if (this.showMenu && !this.showToc && !this.showSettings) {
        ReaderMenuDismissLayer({
          onDismiss: (): void => {
            this.hideReaderPanels();
          }
        })
      }

      if (this.showSettings) {
        ReaderSettingsDismissLayer({
          panelHeight: this.readerSettingsPanelHeight(),
          onDismiss: (): void => {
            this.closeSettingsPanelKeepMenu();
          }
        })
      }

      if (this.showMenu) {
        ReaderFloatingTopMenu({
          iconColor: this.readerControlIconColor(),
          darkMode: this.isReaderThemeDark(),
          safeTopPadding: this.getTopControlSafePadding(),
          canRefreshChapter: this.book !== null && !LocalBookService.isLocalBook(this.book) && this.chapters.length > 0,
          canChangeSource: this.book !== null && !LocalBookService.isLocalBook(this.book),
          onBack: (): void => {
            this.exitReaderPage();
          },
          onRefreshChapter: (): void => {
            this.hideReaderPanels();
            this.refreshCurrentChapter();
          },
          onChangeSource: (): void => {
            this.openChangeSourceDialog();
          },
          onToggleActionMenu: (): void => {
            this.showReaderActionMenu = !this.showReaderActionMenu;
          }
        })
      }

      if (this.showMenu && this.showReaderActionMenu && !this.showToc && !this.showSettings) {
        ReaderActionMenuPanel({
          bookmarkLabel: this.isCurrentPageBookmarked() ? '删除书签' : '添加书签',
          firstDivider: this.readerSourceNeedsLogin() || this.readerCanRetry() || !this.isReaderComicModeActive(),
          showCacheItem: this.book !== null && !LocalBookService.isLocalBook(this.book),
          ttsIcon: this.isTtsSpeaking && !this.isTtsPaused ? $r('sys.symbol.pause') : $r('sys.symbol.play'),
          ttsLabel: this.isTtsSpeaking ? (this.isTtsPaused ? '继续朗读' : '暂停朗读') : '开始朗读',
          comicMode: this.isReaderComicModeActive(),
          sourceNeedsLogin: this.readerSourceNeedsLogin(),
          canRetry: this.readerCanRetry(),
          canSelectTxtCharset: this.canSelectTxtCharset(),
          txtCharsetLabel: this.txtCharsetMenuLabel(),
          textColor: this.getTextColor(),
          dividerColor: this.readerGlassBorderColor(),
          panelColor: this.readerGlassPanelColor(),
          glassBorderColor: this.readerGlassBorderColor(),
          shadowColor: this.readerGlassShadowColor(),
          topOffset: this.getTopControlSafePadding() + 72,
          onToggleBookmark: (): void => {
            this.toggleCurrentPageBookmark();
          },
          onOpenCache: (): void => {
            this.openReaderCacheDialog();
          },
          onToggleTts: (): void => {
            this.toggleTtsReading();
          },
          onOpenLogin: (): void => {
            this.openReaderSourceLogin();
          },
          onRetry: (): void => {
            this.retryReaderContent();
          },
          onOpenSettings: (): void => {
            this.openSettingsPanel();
          },
          onOpenTtsSettings: (): void => {
            this.openTtsSettingsPanel();
          },
          onOpenTxtCharset: (): void => {
            this.openTxtCharsetDialog();
          },
          onToggleComic: (): void => {
            this.toggleReaderComicReadingMode();
          },
          onOpenLayoutElement: (): void => {
            this.openLayoutElementSettings();
          },
          onOpenReplaceRules: (): void => {
            this.openCurrentReaderReplaceRules();
          },
          onDismiss: (): void => {
            this.showReaderActionMenu = false;
          },
        })
      }



      if (this.showLayoutElementSettings) {
        ReaderLayoutElementSettingsDialog({
          textColor: this.getTextColor(),
          subTextColor: this.getSubTextColor(),
          accentColor: this.accentColor(),
          dark: this.isReaderThemeDark(),
          panelColor: this.readerGlassPanelColor(),
          glassBorderColor: this.readerGlassBorderColor(),
          shadowColor: this.readerGlassShadowColor(),
          dialogWidth: this.pageViewWidth - 36,
          useTtsQuickAction: this.readerUseTtsQuickAction,
          ttsQuickActionLeft: this.readerTtsQuickActionSide < 0,
          useChapterQuickJump: this.readerUseChapterQuickJump,
          onClose: (): void => {
            this.showLayoutElementSettings = false;
          },
          onToggleTtsQuickAction: (enabled: boolean): void => {
            this.readerUseTtsQuickAction = enabled;
            if (!enabled) this.ttsMediaControlsExpanded = false;
            this.saveReaderLayoutElementSettings();
          },
          onToggleTtsQuickActionSide: (left: boolean): void => {
            this.readerTtsQuickActionSide = left ? -1 : 1;
            this.saveReaderLayoutElementSettings();
          },
          onToggleChapterQuickJump: (enabled: boolean): void => {
            this.readerUseChapterQuickJump = enabled;
            if (!enabled) this.resetMenuChapterPreview();
            this.saveReaderLayoutElementSettings();
          }
        })
      }

      if (this.showMenu && !this.showToc && !this.showSettings && this.chapters.length > 0) {
        if (LeafFns.supportsReaderImmersiveMaterial()) {
          if (this.hdsMaterialRenderBranch) {
            this.readerHdsFloatingBottomMenu()
          } else {
            this.readerHdsFloatingBottomMenu()
          }
        } else {
          ReaderFloatingBottomMenu({
            useChapterQuickJump: this.readerUseChapterQuickJump,
            chapterDisplayIndex: this.getMenuChapterDisplayIndex(),
            chapterCount: this.chapters.length,
            chapterTitle: this.getChapterTitle(this.getMenuChapterDisplayIndex()),
            currentChapterIndex: this.currentChapterIndex,
            loading: this.isLoading,
            comicMode: this.isReaderComicModeActive(),
            textColor: this.getTextColor(),
            subTextColor: this.getSubTextColor(),
            accentColor: this.accentColor(),
            trackColor: this.readerChapterTrackColor(),
            blockColor: this.readerSolidPanelColor(),
            panelColor: this.readerGlassPanelColor(),
            glassBorderColor: this.readerGlassBorderColor(),
            shadowColor: this.readerGlassShadowColor(),
            iconColor: this.readerControlIconColor(),
            dayNightIcon: this.readerDayNightIcon(),
            barLeft: this.readerFloatingBarLeft(),
            barWidth: this.readerFloatingBarWidth(),
            onJumpChapter: (delta: number): void => {
              this.jumpToAdjacentChapterFromMenu(delta).catch(() => {
              });
            },
            onSliderChange: (value: number, mode: SliderChangeMode): void => {
              this.handleMenuChapterSliderChange(value, mode);
            },
            onOpenToc: (): void => {
              this.openTocPanel();
            },
            onOpenSettings: (): void => {
              this.openSettingsPanel();
            },
            onOpenTypography: (): void => {
              this.openTypographySettingsPanel();
            },
            onToggleDayNight: (): void => {
              this.handleReaderDayNightClick();
            },
            onDayNightLongPress: (): void => {
              this.handleReaderDayNightLongPress();
            },
        })
        }
        if (this.readerUseTtsQuickAction && !this.isReaderComicModeActive() && !this.ttsMediaControlsExpanded &&
          !this.isTtsSpeaking && !this.ttsReader.isSpeaking() && !this.globalTtsActive) {
          ReaderTtsQuickActionButton({
          iconColor: this.readerControlIconColor(),
          accentColor: this.accentColor(),
          surfaceColor: this.readerContentLayerColor(),
          darkMode: this.isReaderThemeDark(),
          speaking: this.isTtsSpeaking || this.ttsReader.isSpeaking(),
          offsetX: this.readerTtsQuickActionLeft(),
          offsetY: -(this.readerBottomMenuOverlayHeight() + 62),
          onActivate: (): void => {
            this.handleTtsQuickAction();
          }
        })
        }
        if (this.readerUseTtsQuickAction && this.shouldShowTtsMediaControls()) {
          if (LeafFns.supportsReaderImmersiveMaterial()) {
            if (this.hdsMaterialRenderBranch) {
              this.ttsExpandedMediaControlsBar()
            } else {
              this.ttsExpandedMediaControlsBar()
            }
          } else {
            this.ttsExpandedMediaControlsCompat()
          }
        }
      }

      if (this.showToc) {
        this.readerFloatingTocPanel()
        if (LeafFns.supportsReaderImmersiveMaterial()) {
          if (this.hdsMaterialRenderBranch) {
            this.readerHdsFloatingActionBar(true)
          } else {
            this.readerHdsFloatingActionBar(true)
          }
        }
      }

      if (this.showSettings) {
        this.settingsPanel()
        if (this.showTtsVoiceDropdown) {
          ReaderTtsVoicePanel({
            customVoices: this.selectableCustomTtsVoices(),
            systemVoices: this.selectableSystemTtsVoices(),
            pressedKey: this.ttsVoiceRowPressedKey,
            downloadingKey: this.ttsDownloadingVoiceKey,
            textColor: this.getTextColor(),
            subTextColor: this.getSubTextColor(),
            accentColor: this.accentColor(),
            iconColor: this.readerControlIconColor(),
            darkMode: this.isReaderThemeDark(),
            selectedBackgroundColor: this.tocSelectedBackgroundColor(),
            pressedBackgroundColor: this.isReaderThemeDark() ? '#14FFFFFF' : '#0F000000',
            panelWidth: this.readerFloatingBarWidth(),
            panelHeight: this.readerTocPanelHeight(),
            panelBottomInset: this.readerFloatingPanelBottomInset(),
            panelLeft: this.readerFloatingBarLeft(),
            scrollBarColor: this.readerPanelScrollBarColor(),
            glassPanelColor: this.readerGlassPanelColor(),
            glassBorderColor: this.readerGlassBorderColor(),
            glassShadowColor: this.readerGlassShadowColor(),
            isCustomSelected: (voice: HttpTTS): boolean => this.isCurrentCustomTtsVoice(voice),
            isSystemSelected: (voice: TtsVoiceOption): boolean => this.isCurrentTtsVoice(voice),
            onPress: (key: string, pressed: boolean): void => {
              if (pressed) {
                this.ttsVoiceRowPressedKey = key;
              } else if (this.ttsVoiceRowPressedKey === key) {
                this.ttsVoiceRowPressedKey = '';
              }
            },
            onSelectCustom: (voice: HttpTTS): void => {
              this.showTtsVoiceDropdown = false;
              this.applyCustomTtsVoice(voice, true);
            },
            onSelectSystem: (voice: TtsVoiceOption, available: boolean, downloadable: boolean): void => {
              if (!available) {
                if (downloadable) {
                  this.downloadTtsVoice(voice);
                } else {
                  HdsFeedback.showToast('该系统音色当前不可用');
                }
                return;
              }
              this.showTtsVoiceDropdown = false;
              this.applyTtsVoice(voice, true);
            },
            onClose: (): void => {
              this.showTtsVoiceDropdown = false;
            }
          })
        }
        if (LeafFns.supportsReaderImmersiveMaterial()) {
          if (this.hdsMaterialRenderBranch) {
            this.readerHdsFloatingActionBar(false, true)
          } else {
            this.readerHdsFloatingActionBar(false, true)
          }
        }
      }

      if (this.readerUseTtsQuickAction && this.shouldShowTtsMiniPlayer()) {
TtsGlobalCapsule({
          darkMode: this.isReaderThemeDark(),
          accentColor: this.accentColor(),
          showOpenReader: false,
          viewportWidth: this.pageViewWidth > 0 ? this.pageViewWidth : 360,
          viewportHeight: this.pageViewHeight > 0 ? this.pageViewHeight : 720,
          topInset: this.getReaderTopSafePadding(),
          bottomInset: this.navBarHeight,
          onOpenCatalog: (): void => {
            this.openGlobalTtsCatalog();
          },
          onOpenReader: (): void => {
            this.jumpToGlobalTtsPosition().catch((error: Error) => {
              console.warn('跳转后台朗读位置失败:', error);
            });
          }
        })
      } else if (this.readerUseTtsQuickAction && this.shouldShowGlobalTtsMiniPlayer()) {
TtsGlobalCapsule({
          darkMode: this.isReaderThemeDark(),
          accentColor: this.accentColor(),
          showOpenReader: true,
          viewportWidth: this.pageViewWidth > 0 ? this.pageViewWidth : 360,
          viewportHeight: this.pageViewHeight > 0 ? this.pageViewHeight : 720,
          topInset: this.getReaderTopSafePadding(),
          bottomInset: this.navBarHeight,
          onOpenCatalog: (): void => {
            this.openGlobalTtsCatalog();
          },
          onOpenReader: (): void => {
            this.jumpToGlobalTtsPosition().catch((error: Error) => {
              console.warn('跳转后台朗读位置失败:', error);
            });
          }
        })
      }

      if (this.showGlobalTtsCatalog) {
        TtsCatalogSheet({
          darkMode: this.isReaderThemeDark(),
          accentColor: this.accentColor(),
          primaryTextColor: this.getTextColor(),
          subTextColor: this.getSubTextColor(),
          controlIconColor: this.readerControlIconColor(),
          panelColor: this.readerGlassPanelColor(),
          bookName: this.book?.name || '',
          bookInitial: this.getTocBookInitial(),
          cover: this.getTocCover(),
          bookSubtitle: this.book?.author || '',
          count: this.ttsCatalogCount(),
          currentDisplayIndex: this.globalTtsCatalogDisplayIndex(this.ttsCatalogCurrentIndex()),
          reverseOrder: this.globalTtsCatalogReverseOrder,
          progressText: `${this.ttsCatalogCurrentIndex() + 1} / ` + `${this.ttsCatalogCount()}`,
          bottomInset: this.navBarHeight,
          viewportHeight: this.pageViewHeight,
          zIndexValue: 90,
          scroller: this.globalTtsCatalogScroller,
          source: this.globalTtsCatalogSource,
          isCached: (displayIndex: number): boolean => this.isGlobalTtsCatalogChapterCached(displayIndex),
          onToggleOrder: (): void => {
            this.toggleGlobalTtsCatalogOrder();
          },
          onSelect: (displayIndex: number): void => {
            this.selectGlobalTtsCatalog(displayIndex);
          },
          onClose: (): void => {
            this.closeGlobalTtsCatalog();
          }
        })
      }

      if (this.showBookmarkActionMenu && this.pendingBookmarkAction) {
        this.bookmarkActionMenu()
      }

      if (this.showChangeSourceDialog) {
        BookChangeSourceDialog({
          targetBook: this.book,
          markReadOnSwitch: true,
          onBeforeSwitch: (): Promise<void> => {
            return this.saveReadingProgress();
          },
          onSwitched: (fullBook: Book): void => {
            this.pendingSwitchedBook = fullBook;
          },
          onClosed: (): void => {
            this.showChangeSourceDialog = false;
            if (this.pendingSwitchedBook) {
              const fullBook = this.pendingSwitchedBook;
              this.pendingSwitchedBook = null;
              this.bookUrl = fullBook.bookUrl;
              this.book = fullBook;
              this.loadBook();
              this.loadBookmarks();
            }
          }
        })
      }

      if (this.showReaderCommentPanel) {
        this.readerCommentPanel()
      }

      if (this.readerEyeTurnEnabled && this.readerInitialPageReady && !this.showReaderEyeCalibration &&
        !this.showMenu && !this.showToc && !this.showReaderCommentPanel) {
        ReaderEyeTurnPrompt({
        visible: this.readerEyeTurnPromptVisible(),
        promptTop: this.readerEyeTurnPromptTop()
      })
      }

      if (this.showReaderEyeCalibration) {
        ReaderEyeCalibrationPanel({
          sessionActive: this.readerEyeCalibrationSessionActive,
          capturing: this.readerEyeCalibrationCapturing,
          step: this.readerEyeCalibrationStep,
          progress: this.readerEyeCalibrationProgress,
          instruction: this.readerEyeCalibrationInstruction(),
          targetLabel: this.currentReaderEyeCalibrationTargetLabel(),
          statusText: this.readerEyeTurnStatus,
          previewHint: this.readerEyeCalibrationPreviewHint(),
          previewWidth: this.readerEyeCalibrationPreviewWidthVp(),
          previewHeight: this.readerEyeCalibrationPreviewHeightVp(),
          previewLeft: this.readerEyeCalibrationPreviewLeftVp(),
          previewTop: LeafFns.readerEyeCalibrationPreviewTopVp(),
          targetTop: this.readerEyeCalibrationTargetTopVp(),
          overlayWidth: this.readerEyeCalibrationOverlayWidth,
          overlayHeight: this.readerEyeCalibrationOverlayHeight,
          textColor: this.getTextColor(),
          subTextColor: this.getSubTextColor(),
          accentColor: this.accentColor(),
          darkMode: this.isReaderThemeDark(),
          panelColor: this.readerGlassPanelColor(),
          glassBorderColor: this.readerGlassBorderColor(),
          scrimColor: ThemeRuntime.scrimColor(this.isReaderThemeDark()),
          onCancel: (): void => {
            this.cancelReaderEyeCalibration();
          },
          onBegin: (): void => {
            this.beginReaderEyeCalibrationCapture();
          },
          onSample: (): void => {
            this.startReaderEyeCalibrationPhaseSampling();
          },
          onOverlaySizeChange: (width: number, height: number): void => {
            if (width > 0 && Math.abs(width - this.readerEyeCalibrationOverlayWidth) >= 0.5) {
              this.readerEyeCalibrationOverlayWidth = width;
            }
            if (height > 0 && Math.abs(height - this.readerEyeCalibrationOverlayHeight) >= 0.5) {
              this.readerEyeCalibrationOverlayHeight = height;
            }
          },
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.readerContentLayerColor())
    .expandSafeArea([SafeAreaType.SYSTEM], LeafFns.getReaderSafeAreaEdges())
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.refreshReaderScreenTimeout();
      }
    })
  }

  @Builder
  readerCommentPanel() {
    Column() {
      Row()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor(this.isReaderThemeDark() ? '#52000000' : '#26000000')
        .onClick(() => {
          this.closeReaderCommentPanel();
        })

      Stack() {
        Column() {
          ReaderCommentPanelDragHandle({
            dark: this.isReaderThemeDark(),
            handleHeight: LeafFns.readerCommentPanelDragHandleHeight()
          })
          Stack() {
            Web({ src: this.readerCommentPanelUrl, controller: this.readerCommentPanelController })
            .width('100%')
            .height(Math.max(1, this.readerCommentPanelHeightValue - LeafFns.readerCommentPanelDragHandleHeight()))
            .monopolizeEvents(true)
            .javaScriptAccess(true)
            .domStorageAccess(true)
            .onlineImageAccess(true)
            .imageAccess(true)
            .darkMode(this.appDarkMode ? WebDarkMode.On : WebDarkMode.Off)
            .forceDarkAccess(this.appDarkMode)
            .onControllerAttached(() => {
              this.readerCommentPanelHtmlLoaded = false;
              setTimeout(() => this.loadReaderCommentPanelHtmlIfNeeded(), 0);
            })
            .onPageBegin(() => {
              this.readerCommentPanelLoading = true;
            })
            .onPageEnd(() => {
              if (this.loadReaderCommentPanelHtmlIfNeeded()) return;
              this.scheduleReaderCommentPanelHostReady(0);
            })

            if (this.readerCommentPanelLoading) {
              Column({ space: 10 }) {
                LoadingProgress()
                  .width(38)
                  .height(38)
                  .color(this.accentColor())
                Text('评论加载中…')
                  .fontSize(13)
                  .fontColor(this.getTextColor())
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .backgroundColor(this.readerGlassPanelColor())
            }
          }
          .width('100%')
          .height(this.readerCommentPanelContentHeight())
          .backgroundColor(this.readerGlassPanelColor())
          .backdropBlur(ThemeRuntime.glassBlur('panel', 22))
          .borderRadius({
            topLeft: ThemeRuntime.glassCornerRadius(28, 'panel'),
            topRight: ThemeRuntime.glassCornerRadius(28, 'panel')
          })
          .clip(true)
        }
        .width('100%')
        .backgroundColor('#00000000')
        .height(this.readerCommentPanelHeightValue)

        ReaderCommentPanelDragOverlay({
        onDragTouch: (event: TouchEvent): void => { this.handleReaderCommentPanelDragTouch(event); },
      })
      }
      .width('100%')
      .height(this.readerCommentPanelHeightValue)
      .alignContent(Alignment.Top)
    }
    .width('100%')
    .height('100%')
  }


  @Builder
  readerHdsChapterBarTab() {
    ReaderChapterSliderBar({
      sliderValue: this.getMenuChapterDisplayIndex(),
      sliderMax: Math.max(0, this.chapters.length - 1),
      textColor: this.getTextColor(),
      subTextColor: this.getSubTextColor(),
      accentColor: this.accentColor(),
      trackColor: this.readerChapterTrackColor(),
      blockColor: this.readerSolidPanelColor(),
      canGoPrevious: this.currentChapterIndex > 0 && !this.isLoading,
      canGoNext: this.currentChapterIndex < this.chapters.length - 1 && !this.isLoading,
      onPrevious: (): void => {
        this.jumpToAdjacentChapterFromMenu(-1);
      },
      onNext: (): void => {
        this.jumpToAdjacentChapterFromMenu(1);
      },
      onSliderChange: (value: number, mode: SliderChangeMode): void => {
        this.handleMenuChapterSliderChange(value, mode);
      }
    })
  }

  @Builder
  readerHdsFloatingBottomMenu() {
    Column({ space: 4 }) {
      if (this.readerUseChapterQuickJump) {
        this.readerHdsChapterTabBar()
      }
      this.readerHdsActionBar(false)
    }
    .width('100%')
    .height(this.readerBottomMenuOverlayHeight())
    .padding({ bottom: this.readerFloatingBarBottomMargin() })
    .justifyContent(FlexAlign.End)
    .alignItems(HorizontalAlign.Center)
    .position({ x: 0, y: '100%' })
    .translate({
      x: this.readerFloatingBarTranslateX(),
      y: -this.readerBottomMenuOverlayHeight()
    })
  }

  @Builder
  readerHdsChapterTabBar() {
    Stack({ alignContent: Alignment.Center }) {
      HdsTabs({ barPosition: BarPosition.End, index: 0 }) {
        TabContent() {
          Column()
        }
        .height(56)
        .tabBar(this.readerHdsChapterBarTab())
      }
      .key(`reader_hds_chapter_bar_${this.themeRevision}_${this.isReaderThemeDark() ? 'dark' : 'light'}`)
      .barBackgroundColor(this.readerGlassPanelColor())
      .barMode(BarMode.Fixed)
      .barHeight(48)
      .barOverlap(true)
      .barFloatingStyle({
        barWidth: {
          smallWidth: this.readerFloatingBarWidth(),
          mediumWidth: this.readerFloatingBarWidth(),
          largeWidth: this.readerFloatingBarWidth()
        },
        systemMaterialEffect: {
          materialType: ImmersiveMaterialRuntime.materialType(),
          materialLevel: ImmersiveMaterialRuntime.materialLevel()
        },
        barSideMargin: 0,
        barBottomMargin: 4,
        gradientMask: {
          maskColor: '#00000000',
          maskHeight: 56
        },
        adaptToHandedness: false,
        thermoCtrl: true,
        barOpacity: 1
      })
      .scrollable(false)
      .width('100%')
      .height(56)

      if (this.menuChapterTooltipVisible) {
        Column({ space: 2 }) {
          Text(this.getChapterTitle(this.getMenuChapterDisplayIndex()))
            .fontSize(12)
            .fontColor('#FFFFFFFF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${this.getMenuChapterDisplayIndex() + 1}/${this.chapters.length}`)
            .fontSize(11)
            .fontColor('#CCFFFFFF')
        }
        .width(this.readerChapterTooltipWidth())
        .height(44)
        .padding({ left: 14, right: 14, top: 5, bottom: 5 })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .borderRadius(22)
        .backgroundColor(this.isReaderThemeDark() ? '#E63A3C40' : '#D94B4D52')
        .shadow({ radius: 10, color: '#50000000', offsetX: 0, offsetY: 3 })
        .position({ x: this.readerChapterTooltipCenteredLeft(), y: -48 })
      }
    }
    .width('100%')
    .height(56)
  }

  @Builder
  readerHdsFloatingActionBar(fromToc: boolean, fromSettings: boolean = false) {
    Column() {
      this.readerHdsActionBar(fromToc, fromSettings)
    }
    .width('100%')
    .height(this.readerBottomActionOverlayHeight())
    .padding({ bottom: this.readerFloatingBarBottomMargin() })
    .justifyContent(FlexAlign.End)
    .position({ x: 0, y: '100%' })
    .translate({
      x: this.readerFloatingBarTranslateX(),
      y: -this.readerBottomActionOverlayHeight()
    })
  }

  @Builder
  readerHdsDayNightTab() {
    ReaderHdsDayNightMenuItem({
      icon: this.readerDayNightIcon(),
      iconColor: this.readerControlIconColor(),
      onActivate: (): void => {
        this.handleReaderDayNightClick();
      },
      onLongPress: (): void => {
        this.handleReaderDayNightLongPress();
      }
    })
  }

  @Builder
  readerHdsTabMenuItem(icon: Resource, menuEnabled: boolean) {
    Row() {
      ReaderHdsMenuItem({
        icon: icon,
        iconColor: this.readerControlIconColor(),
        showAddBadge: false,
        menuEnabled: menuEnabled,
      })
    }
    .layoutWeight(1)
    .height(56)
  }

  @Builder
  readerHdsActionBar(fromToc: boolean, fromSettings: boolean = false) {
    HdsTabs({ barPosition: BarPosition.End, index: 0 }) {
      TabContent() {
        Column()
      }
      .height(56)
      .tabBar(this.readerHdsTabMenuItem($r('sys.symbol.list_bullet'), true))

      TabContent() {
        Column()
      }
      .height(56)
      .tabBar(this.readerHdsTabMenuItem($r('sys.symbol.gearshape'), !this.isReaderComicModeActive()))

      TabContent() {
        Column()
      }
      .height(56)
      .tabBar(this.readerHdsTabMenuItem($r('sys.symbol.textformat'), !this.isReaderComicModeActive()))

      TabContent() {
        Column()
      }
      .height(56)
      .tabBar(this.readerHdsDayNightTab())
    }
    .key(`reader_hds_action_bar_${this.themeRevision}_${this.isReaderThemeDark() ? 'dark' : 'light'}`)
    .barBackgroundColor(this.readerGlassPanelColor())
    .barMode(BarMode.Fixed)
    .barHeight(48)
    .barOverlap(true)
    .barFloatingStyle({
      barWidth: {
        smallWidth: this.readerFloatingBarWidth(),
        mediumWidth: this.readerFloatingBarWidth(),
        largeWidth: this.readerFloatingBarWidth()
      },
      systemMaterialEffect: {
        materialType: ImmersiveMaterialRuntime.materialType(),
        materialLevel: ImmersiveMaterialRuntime.materialLevel()
      },
      barSideMargin: 0,
      barBottomMargin: 4,
      gradientMask: {
        maskColor: '#00000000',
        maskHeight: 56
      },
      adaptToHandedness: false,
      thermoCtrl: true,
      barOpacity: 1
    })
    .scrollable(false)
    .onContentWillChange(() => false)
    .onTabBarClick((index: number) => {
      this.handleReaderHdsAction(index, fromToc, fromSettings);
    })
    .width('100%')
    .height(56)
  }

  handleReaderHdsAction(index: number, fromToc: boolean, fromSettings: boolean = false): void {
    ReaderMenuBuildOps.handleReaderHdsAction(this, index, fromToc, fromSettings);
  }

  readerDayNightIcon(): Resource {
    return ReaderMenuBuildOps.readerDayNightIcon(this);
  }

  toggleReaderDayNightMode(): void {
    ReaderMenuBuildOps.toggleReaderDayNightMode(this);
  }

  setReaderAutoMode(): void {
    ReaderMenuBuildOps.setReaderAutoMode(this);
  }

  handleReaderDayNightClick(): void {
    ReaderMenuBuildOps.handleReaderDayNightClick(this);
  }

  handleReaderDayNightLongPress(): void {
    ReaderMenuBuildOps.handleReaderDayNightLongPress(this);
  }

  applyReaderThemeMode(nextMode: string): void {
    ReaderMenuBuildOps.applyReaderThemeMode(this, nextMode);
  }

  @Builder
  readerFloatingTocPanel() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.showToc = false;
        })

      Column() {
        Row({ space: 14 }) {
          if (this.getTocCover()) {
            Image(this.getTocCover())
              .width(52)
              .height(68)
              .borderRadius(8)
              .objectFit(ImageFit.Cover)
          } else {
            Text(this.getTocBookInitial())
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .textAlign(TextAlign.Center)
              .width(52)
              .height(68)
              .borderRadius(8)
              .backgroundColor(this.accentColor())
          }

          Column({ space: 5 }) {
            Text(this.book?.name || '目录')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getTextColor())
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.book?.author || '未知作者')
              .fontSize(12)
              .fontColor(this.getSubTextColor())
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          ImmersiveBackButton({
            icon: $r('sys.symbol.xmark'),
            iconOffsetX: 0,
            iconColor: this.readerControlIconColor(),
            darkMode: this.isReaderThemeDark(),
            buttonSize: 40,
            containerWidth: 40,
            containerHeight: 40,
            startInset: 0,
            materialScale: 0.83,
            compactLayout: true,
            accessibilityLabel: '关闭目录',
            onBack: () => {
              this.showToc = false;
            }
          })
          .alignSelf(ItemAlign.Start)
          .margin({ top: 4 })
        }
        .width('100%')
        .padding({ left: 20, right: 16, top: 12, bottom: 10 })
        .alignItems(VerticalAlign.Center)

        Row() {
          Text('目录')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tocPanelTab === 0 ? this.getTextColor() : this.getSubTextColor())
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(40)
            .borderRadius(20)
            .backgroundColor(this.tocPanelTab === 0 ? this.readerSolidPanelColor() : Color.Transparent)
            .shadow({ radius: this.tocPanelTab === 0 ? 6 : 0,
              color: this.tocPanelTab === 0 ? this.readerGlassShadowColor() : Color.Transparent,
              offsetX: 0, offsetY: 2 })
            .onClick(() => {
              this.tocPanelTab = 0;
              this.cancelBookmarkMultiSelect();
              this.scrollTocToCurrentChapter(false);
            })
          Text('书签')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.tocPanelTab === 1 ? this.getTextColor() : this.getSubTextColor())
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(40)
            .borderRadius(20)
            .backgroundColor(this.tocPanelTab === 1 ? this.readerSolidPanelColor() : Color.Transparent)
            .shadow({ radius: this.tocPanelTab === 1 ? 6 : 0,
              color: this.tocPanelTab === 1 ? this.readerGlassShadowColor() : Color.Transparent,
              offsetX: 0, offsetY: 2 })
            .onClick(() => {
              this.tocPanelTab = 1;
              this.loadBookmarks();
            })
        }
        .width('calc(100% - 40vp)')
        .height(44)
        .padding(2)
        .borderRadius(22)
        .backgroundColor(this.isReaderThemeDark() ? '#20FFFFFF' : '#12000000')
        .margin({ left: 20, right: 20 })

        if (this.tocPanelTab === 0) {
          this.tocPanelSummary()
          this.tocChapterList()
        } else {
          ReaderBookmarkPanelSummary({
            multiSelectMode: this.bookmarkMultiSelectMode,
            selectedCount: this.selectedBookmarkUrls.length,
            totalCount: this.bookmarks.length,
            textColor: this.getTextColor(),
            subTextColor: this.getSubTextColor(),
            accentColor: this.accentColor(),
            onToggleSelectAll: (): void => {
              this.toggleSelectAllBookmarks();
            },
            onDeleteSelected: (): void => {
              this.deleteSelectedBookmarks();
            },
            onCancelMultiSelect: (): void => {
              this.cancelBookmarkMultiSelect();
            }
          })
          this.bookmarkList()
        }
      }
      .width(this.readerFloatingBarWidth())
      .height(this.readerTocPanelHeight())
      .borderRadius(ThemeRuntime.glassCornerRadius(28, 'panel'))
      .clip(true)
      .backgroundColor(this.readerGlassPanelColor())
      .backdropBlur(ThemeRuntime.glassBlur('panel', 22))
      .border({ width: ThemeRuntime.glassBorderWidth('panel'), color: this.readerGlassBorderColor() })
      .shadow({ radius: ThemeRuntime.glassShadowRadius('panel'), color: this.readerGlassShadowColor(), offsetX: ThemeRuntime.glassShadowOffsetX('panel'), offsetY: ThemeRuntime.glassShadowOffsetY('panel') })
      .position({ x: this.readerFloatingBarLeft(), y: '100%' })
      .translate({ y: -(this.readerTocPanelHeight() + this.readerFloatingPanelBottomInset()) })
      .transition(LeafFns.readerPanelTransition())

      if (!LeafFns.supportsReaderImmersiveMaterial()) {
        Row() {
          Row() {
            ReaderFloatingIconMenuItem({
              icon: $r('sys.symbol.list_bullet'),
              iconColor: this.readerControlIconColor(),
              showAddBadge: false,
              menuEnabled: true,
              onMenuClick: () => {
              this.tocPanelTab = 0;
            },
            })
          }
          .layoutWeight(1)
          .height(56)
          Row() {
            ReaderFloatingIconMenuItem({
              icon: $r('sys.symbol.gearshape'),
              iconColor: this.readerControlIconColor(),
              showAddBadge: false,
              menuEnabled: true,
              onMenuClick: () => {
              this.showToc = false;
              this.openSettingsPanel();
            },
            })
          }
          .layoutWeight(1)
          .height(56)
          Row() {
            ReaderFloatingIconMenuItem({
              icon: $r('sys.symbol.textformat'),
              iconColor: this.readerControlIconColor(),
              showAddBadge: false,
              menuEnabled: true,
              onMenuClick: () => {
              this.showToc = false;
              this.openTypographySettingsPanel();
            },
            })
          }
          .layoutWeight(1)
          .height(56)
          ReaderFloatingDayNightMenuItem({
          icon: this.readerDayNightIcon(),
          iconColor: this.readerControlIconColor(),
          onActivate: (): void => {
            this.handleReaderDayNightClick();
          },
          onLongPress: (): void => {
            this.handleReaderDayNightLongPress();
          }
        })
        }
        .width(this.readerFloatingBarWidth())
        .height(56)
        .padding({ left: 8, right: 8 })
        .borderRadius(ThemeRuntime.glassCornerRadius(28, 'panel'))
        .backgroundColor(this.readerGlassPanelColor())
        .backdropBlur(ThemeRuntime.glassBlur('panel', 22))
        .border({ width: ThemeRuntime.glassBorderWidth('panel'), color: this.readerGlassBorderColor() })
        .shadow({ radius: ThemeRuntime.glassShadowRadius('panel'), color: this.readerGlassShadowColor(), offsetX: ThemeRuntime.glassShadowOffsetX('panel'), offsetY: ThemeRuntime.glassShadowOffsetY('panel') })
        .position({ x: this.readerFloatingBarLeft(), y: '100%' })
        .translate({ y: -70 })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  tocPanelSummary() {
    Column({ space: 8 }) {
      Row() {
        if (this.tocQuickJumpInputVisible && !this.isTocSearchActive()) {
          TextInput({ text: this.tocQuickJumpDraft, placeholder: `1-${this.chapters.length}` })
            .type(InputType.Normal)
            .enterKeyType(EnterKeyType.Go)
            .key('tocQuickJumpChapterInput')
            .defaultFocus(true)
            .fontSize(13)
            .fontColor(this.getTextColor())
            .textAlign(TextAlign.Center)
            .width(92)
            .height(34)
            .padding({ left: 8, right: 8 })
            .borderRadius(17)
            .backgroundColor(this.isReaderThemeDark() ? '#2BFFFFFF' : '#14000000')
            .accessibilityText('输入目标章节序号，按回车定位')
            .onChange((value: string) => {
              this.tocQuickJumpDraft = value.replace(/[^0-9]/g, '').substring(0, 6);
            })
            .onSubmit(() => {
              this.submitTocQuickJump();
            })
        } else if (this.isTocSearchActive()) {
          Text(`找到 ${this.tocSearchChapterIndexes.length} 章`)
            .fontSize(14)
            .fontColor(this.getSubTextColor())
            .margin({ left: 6 })
        } else {
          Text(`共 ${this.chapters.length} 章`)
            .fontSize(14)
            .fontColor(this.getSubTextColor())
            .margin({ left: 6 })
            .padding({ left: 8, right: 8 })
            .height(34)
            .textAlign(TextAlign.Center)
            .responseRegion({ x: 0, y: -5, width: '100%', height: 44 })
            .accessibilityText(this.tocQuickJumpArmed ? '再次点击输入目标章节' : '点击回到当前章节')
            .onClick(() => {
              this.handleTocCurrentPositionClick();
            })
        }
        Stack({ alignContent: Alignment.Center }) {
          Column({ space: 0 }) {
            SymbolGlyph($r('sys.symbol.chevron_up'))
              .fontSize(11)
              .fontColor([this.tocReverseOrder ? this.accentColor() : this.getTextColor()])
            SymbolGlyph($r('sys.symbol.chevron_down'))
              .fontSize(11)
              .fontColor([this.tocReverseOrder ? this.accentColor() : this.getTextColor()])
          }
          .alignItems(HorizontalAlign.Center)
        }
          .width(34)
          .height(34)
          .responseRegion({ x: -5, y: -5, width: 44, height: 44 })
          .borderRadius(17)
          .backgroundColor(this.tocReverseOrder ?
            (this.isReaderThemeDark() ? '#24384A' : '#E8F1FF') :
            (this.isReaderThemeDark() ? '#1FFFFFFF' : '#0D000000'))
          .accessibilityText(this.tocReverseOrder ? '切换为正序目录' : '切换为倒序目录')
          .onClick(() => this.toggleTocOrder())
          .margin({ left: 4 })
        Blank()
          .layoutWeight(1)
        if (this.isTocSearchActive()) {
          Text(`匹配 ${this.tocSearchChapterIndexes.length}`)
            .fontSize(12)
            .fontColor(this.getTextColor())
            .height(34)
            .padding({ left: 12, right: 12 })
            .textAlign(TextAlign.Center)
            .borderRadius(16)
            .backgroundColor(this.isReaderThemeDark() ? '#1FFFFFFF' : '#0D000000')
        }
        ImmersiveBackButton({
          icon: $r('sys.symbol.arrow_clockwise'),
          iconOffsetX: 0,
          iconColor: this.readerControlIconColor(),
          darkMode: this.isReaderThemeDark(),
          buttonSize: 34,
          containerWidth: 34,
          containerHeight: 34,
          startInset: 0,
          materialScale: 0.7,
          compactLayout: true,
          accessibilityLabel: '刷新目录',
          onBack: () => {
            this.refreshTocFromPanel();
          }
        })
          .margin({ left: 8 })
        ImmersiveBackButton({
          icon: $r('sys.symbol.magnifyingglass'),
          iconOffsetX: 0,
          iconColor: this.tocSearchVisible ? this.accentColor() : this.getTextColor(),
          darkMode: this.isReaderThemeDark(),
          buttonSize: 34,
          containerWidth: 34,
          containerHeight: 34,
          startInset: 0,
          materialScale: 0.7,
          compactLayout: true,
          accessibilityLabel: '搜索目录',
          onBack: () => {
            this.toggleTocSearch();
          }
        })
          .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.tocSearchVisible) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(18)
            .fontColor([this.getSubTextColor()])
          TextInput({ text: this.tocSearchQuery,
            placeholder: this.tocSearchLoading ? '正在载入完整目录…' : '搜索章节名称' })
            .key('tocChapterSearchInput')
            .defaultFocus(true)
            .fontSize(14)
            .fontColor(this.getTextColor())
            .layoutWeight(1)
            .height(38)
            .padding({ left: 0, right: 0 })
            .backgroundColor(Color.Transparent)
            .enterKeyType(EnterKeyType.Search)
            .onChange((value: string) => {
              this.tocSearchQuery = value;
            })
            .onSubmit(() => {
              this.submitTocSearch();
            })
          if (this.tocSearchQuery) {
            Text('×')
              .fontSize(22)
              .fontColor(this.getSubTextColor())
              .width(32)
              .height(38)
              .textAlign(TextAlign.Center)
              .accessibilityText('清空目录搜索')
              .onClick(() => {
                this.clearTocSearchResult();
                setTimeout(() => focusControl.requestFocus('tocChapterSearchInput'), 30);
              })
          }
        }
        .width('100%')
        .height(40)
        .padding({ left: 12, right: 8 })
        .borderRadius(20)
        .backgroundColor(this.isReaderThemeDark() ? '#2BFFFFFF' : '#14000000')
      }
    }
    .width('100%')
    .padding({ left: 20, right: 16, top: 18, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  tocChapterList() {
    Stack({ alignContent: Alignment.TopEnd }) {
      List({ space: 0, scroller: this.tocScroller }) {
        if (this.isTocSearchActive() && this.tocVisibleChapters.length === 0) {
          ListItem() {
            Column({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.magnifyingglass'))
                .fontSize(28)
                .fontColor([this.getSubTextColor()])
              Text('未找到匹配章节')
                .fontSize(14)
                .fontColor(this.getSubTextColor())
            }
            .width('100%')
            .padding({ top: 44, bottom: 44 })
          }
        }
        ForEach(this.tocVisibleChapters, (chapter: BookChapter, localIndex: number) => {
          ListItem() {
            Row({ space: 10 }) {
              Text(this.tocGlobalIndex(localIndex) === this.currentChapterIndex ? '•' : '·')
                .fontSize(this.tocGlobalIndex(localIndex) === this.currentChapterIndex ? 22 : 18)
                .fontColor(this.tocGlobalIndex(localIndex) === this.currentChapterIndex ?
                  this.accentColor() : this.getSubTextColor())
                .width(18)
                .textAlign(TextAlign.Center)

              Text(this.getChapterTitle(this.tocGlobalIndex(localIndex)))
                .fontSize(15)
                .fontWeight(this.tocGlobalIndex(localIndex) === this.currentChapterIndex ?
                  FontWeight.Medium : FontWeight.Regular)
                .fontColor(this.getTocTitleColor(chapter, this.tocGlobalIndex(localIndex)))
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)

              if (this.book?.origin !== 'local' && chapter.cacheDate > 0) {
                Text('已缓存')
                  .fontSize(12)
                  .fontColor(this.isReaderThemeDark() ? '#7CC7A0' : '#1F8F55')
                  .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                  .backgroundColor(this.isReaderThemeDark() ? '#24382F' : '#E6F4EC')
                  .borderRadius(10)
              }
            }
            .width('100%')
            .padding({ left: 14, right: 16, top: 14, bottom: 14 })
            .backgroundColor(this.tocGlobalIndex(localIndex) === this.currentChapterIndex ?
              this.tocSelectedBackgroundColor() : Color.Transparent)
            .border({ width: { bottom: 0.5 }, color: this.isReaderThemeDark() ? '#1FFFFFFF' : '#0D000000' })
            .onClick(async () => {
              const targetChapterIndex = this.tocGlobalIndex(localIndex);
              this.showToc = false;
              this.showMenu = false;
              await this.jumpToReaderPositionKeepingTts(targetChapterIndex, 0);
            })
          }
        }, (chapter: BookChapter, localIndex: number) =>
          `${this.tocOrderRevision}_${this.tocGlobalIndex(localIndex)}_${chapter.url || chapter.title}_${chapter.cacheDate > 0 ? 1 : 0}`)
      }
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .onScrollIndex((start: number, end: number) => {
        this.updateTocScrollbarPosition(start, end);
      })
      .onReachStart(() => this.loadPreviousTocPage())
      .onReachEnd(() => this.loadNextTocPage())

      if (this.tocShouldShowVirtualScrollbar()) {
        ReaderTocVirtualScrollbar({
          darkMode: this.isReaderThemeDark(),
          viewportHeight: this.tocListViewportHeight,
          dragging: this.tocScrollbarDragging,
          thumbLength: this.tocScrollbarThumbLength(),
          thumbOffset: this.tocDisplayedScrollbarThumbOffset(),
          onThumbDragStart: (event: GestureEvent): void => {
            this.beginTocScrollbarDrag(event);
          },
          onThumbDragUpdate: (event: GestureEvent): void => {
            this.updateTocScrollbarDrag(event);
          },
          onThumbDragEnd: (event: GestureEvent): void => {
            this.endTocScrollbarDrag(event);
          },
          onThumbDragCancel: (): void => {
            this.cancelTocScrollbarDrag();
          },
          onTapJump: (event: GestureEvent): void => {
            this.jumpTocScrollbarToPointer(event);
          }
        })
      }
    }
    .layoutWeight(1)
    .width('100%')
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.tocListViewportHeight = Number(newValue.height);
    })
  }

  @Builder
  bookmarkList() {
    if (this.bookmarks.length === 0) {
      Column({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.bookmark'))
          .fontSize(34)
          .fontColor([this.getSubTextColor()])
        Text('暂无书签')
          .fontSize(15)
          .fontColor(this.getSubTextColor())
        Text('可使用底栏最右侧按钮添加当前阅读位置')
          .fontSize(12)
          .fontColor(this.getSubTextColor())
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else {
      List({ space: 0, scroller: this.bookmarkScroller }) {
        ForEach(this.bookmarks, (bookmark: Bookmark) => {
          if (deviceInfo.sdkApiVersion >= 26) {
            // API 26+ uses one left-swipe action panel. Keep multi-select and
            // delete together instead of exposing multi-select on right swipe.
            HdsListItem({
              customItemBuilder: () => {
                ReaderBookmarkSwipeCard({
                  bookmark: bookmark,
                  selected: this.isBookmarkSelected(bookmark.bookmarkUrl),
                  accentColor: this.accentColor(),
                  textColor: this.getTextColor(),
                  subTextColor: this.getSubTextColor(),
                  selectedBackgroundColor: this.tocSelectedBackgroundColor(),
                  dividerColor: this.isReaderThemeDark() ? '#1FFFFFFF' : '#0D000000',
                  onPrimaryAction: (): void => {
                    if (this.bookmarkMultiSelectMode) this.toggleBookmarkSelection(bookmark.bookmarkUrl);
                    else this.jumpToBookmark(bookmark);
                  },
                  onLongPressAction: (event: GestureEvent): void => {
                    if (!this.bookmarkMultiSelectMode) this.showBookmarkActions(bookmark, event);
                  }
                })
              },
              swipeActionOptions: this.bookmarkSwipeActions(bookmark)
            })
          } else {
            // Older systems use the native ListItem fallback with the same
            // two-button left-swipe action panel.
            ListItem() {
              ReaderBookmarkSwipeCard({
                bookmark: bookmark,
                selected: this.isBookmarkSelected(bookmark.bookmarkUrl),
                accentColor: this.accentColor(),
                textColor: this.getTextColor(),
                subTextColor: this.getSubTextColor(),
                selectedBackgroundColor: this.tocSelectedBackgroundColor(),
                dividerColor: this.isReaderThemeDark() ? '#1FFFFFFF' : '#0D000000',
                onPrimaryAction: (): void => {
                  if (this.bookmarkMultiSelectMode) this.toggleBookmarkSelection(bookmark.bookmarkUrl);
                  else this.jumpToBookmark(bookmark);
                },
                onLongPressAction: (event: GestureEvent): void => {
                  if (!this.bookmarkMultiSelectMode) this.showBookmarkActions(bookmark, event);
                }
              })
            }
            .width('100%')
            .clip(true)
            .swipeAction({
              end: {
                builder: () => {
                  this.bookmarkFallbackSwipeActions(bookmark)
                },
                actionAreaDistance: 128,
                onAction: () => this.deleteBookmark(bookmark)
              },
              edgeEffect: SwipeEdgeEffect.Spring
            })
          }
        }, (bookmark: Bookmark) => `${bookmark.bookmarkUrl}`)
      }
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .layoutWeight(1)
      .width('100%')
      .clip(true)
      .scrollBar(BarState.Auto)
      .scrollBarColor(this.readerPanelScrollBarColor())
    }
  }

  bookmarkSwipeActions(bookmark: Bookmark): HdsSwipeActionOptions {
    return ReaderMenuBuildOps.bookmarkSwipeActions(this, bookmark);
  }


  onSystemDialogFlagChanged(): void {
    if (!this.showTxtCharsetDialog) this.txtCharsetDialogSession.close(this.getUIContext());
    if (!this.showReaderCacheDialog) this.readerCacheDialogSession.close(this.getUIContext());
    if (!this.showReaderChapterCacheDialog) this.chapterCacheDialogSession.close(this.getUIContext());
    if (!this.showTapZoneSettings) this.tapZoneDialogSession.close(this.getUIContext());
    if (!this.showAutoPageTurnIntervalDialog) {
      this.autoPageTurnIntervalDialogSession.close(this.getUIContext());
    }
    if (!this.showReaderCustomThemeDeleteConfirm) this.readerCustomThemeDeleteDialogSession.close(this.getUIContext());
  }

  presentTapZoneSettings(): void {
    this.showTapZoneSettings = true;
    this.tapZoneDialogSession.open(this.getUIContext(), (): void => {
      TapZoneSettingsDialogContent({
        onDone: (): void => {
          this.showTapZoneSettings = false;
          this.tapZoneDialogSession.close(this.getUIContext());
        }
      })
    }, {
      autoCancel: false,
      maskColor: this.isReaderThemeDark() ? '#99000000' : '#33000000',
      warnTag: '显示点击区域设置弹窗失败:'
    });
  }

  async openChangeSourceDialog(): Promise<void> {
    return ReaderMenuBuildOps.openChangeSourceDialog(this);
  }

  @Builder
  readerCacheDialogContent() {
    ReaderCacheDialogContent({
      bookName: this.book?.name || '',
      statusText: this.readerCachePanelStatus(),
      fullTextCaching: this.fullTextCaching,
      rangeCaching: this.readerCacheRangeCaching,
      textColor: this.getTextColor(),
      subTextColor: this.getSubTextColor(),
      dangerColor: this.dangerColor(),
      dark: this.isReaderThemeDark(),
      onToggleFullTextCache: (): void => {
        if (this.fullTextCaching) {
          this.cancelFullTextCache();
        } else {
          this.startFullTextCache(0);
        }
      },
      onCacheToLatest: (): void => {
        this.startFullTextCache(this.currentChapterIndex);
      },
      onOpenChapterRange: (): void => {
        this.openReaderChapterCacheDialog();
      },
      onClearCachedChapters: (): void => {
        this.clearReaderCachedChapters();
      },
      onClose: (): void => {
        this.closeReaderCacheDialog();
      }
    })
  }


  @Builder
  readerChapterCacheDialogContent() {
    ReaderChapterCacheDialogContent({
      statusText: this.readerCachePanelStatus(),
      rangeDraft: this.readerCacheRangeDraft,
      fullTextCaching: this.fullTextCaching,
      rangeCaching: this.readerCacheRangeCaching,
      chapters: this.readerCacheChapters,
      textColor: this.getTextColor(),
      subTextColor: this.getSubTextColor(),
      dangerColor: this.dangerColor(),
      accentColor: this.accentColor(),
      cachedTextColor: this.readerCachedChapterTextColor(),
      darkMode: this.isReaderThemeDark(),
      dialogHeight: Math.min(560, Math.max(420, this.pageViewHeight - 72)),
      onClose: (): void => {
        this.closeReaderCacheDialog();
      },
      onRangeDraftChange: (value: string): void => {
        this.readerCacheRangeDraft = value;
      },
      onToggleRangeCache: (): void => {
        if (this.readerCacheRangeCaching) {
          this.cancelReaderChapterRangeCache();
        } else {
          this.cacheReaderChapterRange();
        }
      },
      onCacheChapter: (index: number): void => {
        this.cacheReaderSingleChapter(index);
      }
    })
  }
//endregion
//region 排版·字符集·替换规则设置 / TTS快捷入口·mini播放器·目录 / 书签 / 正文预处理
// [map] 契约: 读写 设置/目录/书签/TTS浮标显示态; 含 ttsMiniPlayer 等大量 @Builder


  openLayoutElementSettings(): void {
    ReaderTextPrepOps.openLayoutElementSettings(this);
  }

  canSelectTxtCharset(): boolean {
    return ReaderTextPrepOps.canSelectTxtCharset(this);
  }


  txtCharsetMenuLabel(): string {
    return ReaderTextPrepOps.txtCharsetMenuLabel(this);
  }

  openTxtCharsetDialog(): void {
    if (!this.canSelectTxtCharset()) return;
    this.showReaderActionMenu = false;
    this.txtCharsetDraft = LocalBookService.getTxtCharsetOverride(this.book);
    this.showTxtCharsetDialog = true;
    this.txtCharsetDialogSession.open(this.getUIContext(), (): void => {
      ReaderTxtCharsetDialogContent({
        textColor: this.getTextColor(),
        subTextColor: this.getSubTextColor(),
        accentColor: this.accentColor(),
        controlIconColor: this.readerControlIconColor(),
        darkMode: this.isReaderThemeDark(),
        currentCharsetLabel: LeafFns.txtCharsetLabel(this.book?.charset || ''),
        draftCharset: this.txtCharsetDraft,
        applying: this.txtCharsetApplying,
        listHeight: Math.min(440, Math.max(160, this.pageViewHeight - 190)),
        onClose: (): void => {
          if (!this.txtCharsetApplying) this.showTxtCharsetDialog = false;
        },
        onPick: (value: string): void => {
          this.txtCharsetDraft = value;
        },
        onCancel: (): void => {
          this.showTxtCharsetDialog = false;
        },
        onApply: (): void => {
          this.applyTxtCharsetSelection();
        }
      });
    }, {
      autoCancel: false,
      maskColor: this.isReaderThemeDark() ? '#99000000' : '#33000000',
      warnTag: '显示字符编码弹窗失败:'
    });
  }

  async applyTxtCharsetSelection(): Promise<void> {
    return ReaderTextPrepOps.applyTxtCharsetSelection(this);
  }


  openCurrentReaderReplaceRules(): void {
    ReaderTextPrepOps.openCurrentReaderReplaceRules(this);
  }

  prepareReaderReplaceRulesContext(): void {
    ReaderTextPrepOps.prepareReaderReplaceRulesContext(this);
  }

  openReaderReplaceRuleWithSelection(selectedText: string): void {
    ReaderTextPrepOps.openReaderReplaceRuleWithSelection(this, selectedText);
  }

  saveReaderLayoutElementSettings(): void {
    ReaderTextPrepOps.saveReaderLayoutElementSettings(this);
  }


  readerSourceNeedsLogin(): boolean {
    return ReaderTextPrepOps.readerSourceNeedsLogin(this);
  }

  openReaderSourceLogin(): void {
    ReaderTextPrepOps.openReaderSourceLogin(this);
  }

  readerCanRetry(): boolean {
    return ReaderTextPrepOps.readerCanRetry(this);
  }

  retryReaderContent(): void {
    ReaderTextPrepOps.retryReaderContent(this);
  }

  async handleTtsQuickAction(): Promise<void> {
    return ReaderTextPrepOps.handleTtsQuickAction(this);
  }

  shouldShowTtsMiniPlayer(): boolean {
    return ReaderTextPrepOps.shouldShowTtsMiniPlayer(this);
  }

  shouldShowGlobalTtsMiniPlayer(): boolean {
    return ReaderTextPrepOps.shouldShowGlobalTtsMiniPlayer(this);
  }

  openGlobalTtsCatalog(): void {
    ReaderTextPrepOps.openGlobalTtsCatalog(this);
  }

  ttsCatalogTitles(): string[] {
    return ReaderTextPrepOps.ttsCatalogTitles(this);
  }

  ttsCatalogCount(): number {
    return ReaderTextPrepOps.ttsCatalogCount(this);
  }

  ttsCatalogCurrentIndex(): number {
    return ReaderTextPrepOps.ttsCatalogCurrentIndex(this);
  }

  ttsCatalogCachedFlag(canonicalIndex: number): boolean {
    return ReaderTextPrepOps.ttsCatalogCachedFlag(this, canonicalIndex);
  }

  closeGlobalTtsCatalog(): void {
    ReaderTextPrepOps.closeGlobalTtsCatalog(this);
  }

  selectGlobalTtsCatalog(index: number): void {
    ReaderTextPrepOps.selectGlobalTtsCatalog(this, index);
  }

  globalTtsCatalogCanonicalIndex(displayIndex: number): number {
    return ReaderTextPrepOps.globalTtsCatalogCanonicalIndex(this, displayIndex);
  }

  globalTtsCatalogDisplayIndex(canonicalIndex: number): number {
    return ReaderTextPrepOps.globalTtsCatalogDisplayIndex(this, canonicalIndex);
  }

  /**
   * The chip is read from the published session catalog so that the catalog opened
   * from the shelf renders identically to the one opened inside the reader.
   */
  isGlobalTtsCatalogChapterCached(displayIndex: number): boolean {
    return ReaderTextPrepOps.isGlobalTtsCatalogChapterCached(this, displayIndex);
  }

  /** Canonical-order cache flags published with the floating TTS session catalog. */
  readerChapterCachedFlags(): boolean[] {
    return ReaderTextPrepOps.readerChapterCachedFlags(this);
  }

  toggleGlobalTtsCatalogOrder(): void {
    ReaderTextPrepOps.toggleGlobalTtsCatalogOrder(this);
  }

  openGlobalTtsReaderPage(): void {
    ReaderTextPrepOps.openGlobalTtsReaderPage(this);
  }

  // 全局浮标“定位”按钮：同书跳到后台朗读锚点页；他书朗读则打开对应阅读页。
  async jumpToGlobalTtsPosition(): Promise<void> {
    return ReaderTextPrepOps.jumpToGlobalTtsPosition(this);
  }

  ttsCurrentSentence(): string {
    return ReaderTextPrepOps.ttsCurrentSentence(this);
  }

  ttsCurrentSentenceForPanel(): string {
    return ReaderTextPrepOps.ttsCurrentSentenceForPanel(this);
  }

  ttsQuickSentencePreview(): string {
    return ReaderTextPrepOps.ttsQuickSentencePreview(this);
  }

  ttsPanelTextBefore(): string {
    return ReaderTextPrepOps.ttsPanelTextBefore(this);
  }

  ttsPanelTextAfter(): string {
    return ReaderTextPrepOps.ttsPanelTextAfter(this);
  }

  ttsPanelOffsetSource(): string {
    return ReaderTextPrepOps.ttsPanelOffsetSource(this);
  }


  ttsPanelFollowingText(): string {
    return ReaderTextPrepOps.ttsPanelFollowingText(this);
  }

  ttsQuickProgressLabel(): string {
    return ReaderTextPrepOps.ttsQuickProgressLabel(this);
  }

  ttsQuickProgress(): number {
    return ReaderTextPrepOps.ttsQuickProgress(this);
  }

  showBookmarkActions(bookmark: Bookmark, event: GestureEvent): void {
    ReaderTextPrepOps.showBookmarkActions(this, bookmark, event);
  }

  closeBookmarkActionMenu(): void {
    ReaderTextPrepOps.closeBookmarkActionMenu(this);
  }

  bookmarkActionMenuLeft(menuWidth: number): number {
    return ReaderTextPrepOps.bookmarkActionMenuLeft(this, menuWidth);
  }

  bookmarkActionMenuTop(menuHeight: number): number {
    return ReaderTextPrepOps.bookmarkActionMenuTop(this, menuHeight);
  }

  @Builder
  bookmarkActionMenu() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.isReaderThemeDark() ? '#52000000' : '#26FFFFFF')
        .backdropBlur(ThemeRuntime.glassBlur('popover', 18))
        .onClick(() => {
          this.closeBookmarkActionMenu();
        })

      Column() {
        ReaderBookmarkActionItem({
          icon: $r('sys.symbol.checkmark_circle'),
          label: '多选',
          color: this.getTextColor(),
          action: (): void => {
            if (this.pendingBookmarkAction) {
              const bookmarkUrl = this.pendingBookmarkAction.bookmarkUrl;
              this.closeBookmarkActionMenu();
              this.enterBookmarkMultiSelect(bookmarkUrl);
            }
          }
        })
        ReaderBookmarkActionItem({
          icon: $r('sys.symbol.trash'),
          label: '删除',
          color: this.dangerColor(),
          action: (): void => {
            if (this.pendingBookmarkAction) {
              const bookmark = this.pendingBookmarkAction;
              this.closeBookmarkActionMenu();
              this.deleteBookmark(bookmark);
            }
          }
        })
      }
      .width(148)
      .padding({ top: 6, bottom: 6 })
      .backgroundColor(this.readerGlassPanelColor())
      .borderRadius(ThemeRuntime.glassCornerRadius(14, 'panel'))
      .backdropBlur(ThemeRuntime.glassBlur('panel', 22))
      .border({ width: ThemeRuntime.glassBorderWidth('panel'), color: this.readerGlassBorderColor() })
      .shadow({ radius: ThemeRuntime.glassShadowRadius('panel'), color: this.readerGlassShadowColor(), offsetX: ThemeRuntime.glassShadowOffsetX('panel'), offsetY: ThemeRuntime.glassShadowOffsetY('panel') })
      .position({ x: this.bookmarkActionMenuLeft(148), y: this.bookmarkActionMenuTop(100) })
    }
    .width('100%')
    .height('100%')
  }

  getTocCover(): string {
    return ReaderTextPrepOps.getTocCover(this);
  }

  getTocBookInitial(): string {
    return ReaderTextPrepOps.getTocBookInitial(this);
  }

  getChapterTitle(chapterIndex: number = this.currentChapterIndex): string {
    return ReaderTextPrepOps.getChapterTitle(this, chapterIndex);
  }

  applyReaderContentRules(content: string): string {
    return ReaderTextPrepOps.applyReaderContentRules(this, content);
  }

  readerPreparedContentKey(content: string, chapterIndex: number): string {
    return ReaderTextPrepOps.readerPreparedContentKey(this, content, chapterIndex);
  }

  getPreparedReaderContent(content: string, chapterIndex: number): string {
    return ReaderTextPrepOps.getPreparedReaderContent(this, content, chapterIndex);
  }

  async prepareReaderContentRules(content: string, chapterIndex: number): Promise<string> {
    return ReaderTextPrepOps.prepareReaderContentRules(this, content, chapterIndex);
  }

  onReaderReplaceRulesChanged(): void {
    if (this.readerEntryInitializing || !this.readerPageVisible) {
      return;
    }
    this.reloadReaderReplaceRules(true).catch((error: Error) => {
      console.warn('更新替换净化规则失败:', error);
    });
  }

  async reloadReaderReplaceRules(repaginate: boolean): Promise<void> {
    return ReaderTextPrepOps.reloadReaderReplaceRules(this, repaginate);
  }
//endregion
//region 页眉页脚 / 漫画·连续滚动 / 页面度量 / 主题·字体 / 书签 / TTS音色·语速 / 目录搜索
// [map] 契约: 读 排版/主题/字体/章节; 写 字体注册、书签、音色语速、目录滚动条

  cleanChapterTitle(title: string): string {
    return ReaderChromeThemeOps.cleanChapterTitle(this, title);
  }

  updatePendingVerification(): void {
    ReaderChromeThemeOps.updatePendingVerification(this);
  }

  openVerificationPage(): void {
    ReaderChromeThemeOps.openVerificationPage(this);
  }

  getProgressText(): string {
    return ReaderChromeThemeOps.getProgressText(this);
  }

  getChapterInfoText(): string {
    return ReaderChromeThemeOps.getChapterInfoText(this);
  }

  getReaderHeaderInfoText(): string {
    return ReaderChromeThemeOps.getReaderHeaderInfoText(this);
  }

  getReaderFooterLeftText(): string {
    return ReaderChromeThemeOps.getReaderFooterLeftText(this);
  }

  getReaderFooterProgressText(): string {
    const mode = this.readerFooterProgressMode;
    if (mode === 'none') return '';
    if (mode === 'percentage') {
      const total = Math.max(1, this.contentPages.length);
      const page = Math.max(0, Math.min(this.currentPageIndex, total - 1));
      return `${Math.round(((page + 1) / total) * 100)}%`;
    }
    if (mode === 'chapter') {
      return `${this.currentChapterIndex + 1}/${Math.max(1, this.chapters.length)} 章`;
    }
    if (mode === 'book') {
      const chapterCount = Math.max(1, this.chapters.length);
      return `${Math.round(((this.currentChapterIndex + 1) / chapterCount) * 100)}%`;
    }
    return this.getPageInfoText();
  }

  getReaderFooterProgressValue(): number {
    return ReaderChromeThemeOps.getReaderFooterProgressValue(this);
  }

  getPageInfoText(): string {
    return ReaderChromeThemeOps.getPageInfoText(this);
  }

  getPageText(pageIndex: number): string {
    return ReaderChromeThemeOps.getPageText(this, pageIndex);
  }

  getCurrentPageText(): string {
    return ReaderChromeThemeOps.getCurrentPageText(this);
  }

  isLandscapeDoublePageActive(): boolean {
    return ReaderChromeThemeOps.isLandscapeDoublePageActive(this);
  }

  initializeReaderComicMode(): void {
    ReaderChromeThemeOps.initializeReaderComicMode(this);
  }

  readerSourceIndicatesComic(): boolean {
    return ReaderChromeThemeOps.readerSourceIndicatesComic(this);
  }

  detectReaderComicMode(_source: string): void {
    ReaderChromeThemeOps.detectReaderComicMode(this, _source);
  }

  toggleReaderComicReadingMode(): void {
    ReaderChromeThemeOps.toggleReaderComicReadingMode(this);
  }

  isReaderComicModeActive(): boolean {
    return ReaderChromeThemeOps.isReaderComicModeActive(this);
  }

  isReaderNovelContinuousScrollModeActive(): boolean {
    return ReaderChromeThemeOps.isReaderNovelContinuousScrollModeActive(this);
  }

  isReaderContinuousScrollSurfaceActive(): boolean {
    return ReaderChromeThemeOps.isReaderContinuousScrollSurfaceActive(this);
  }

  readerEffectivePageTurnMode(): number {
    return ReaderChromeThemeOps.readerEffectivePageTurnMode(this);
  }

  comicBoundaryChapterSwipeDirection(offsetY: number): number {
    return ReaderChromeThemeOps.comicBoundaryChapterSwipeDirection(this, offsetY);
  }

  beginReaderComicPan(): void {
    ReaderChromeThemeOps.beginReaderComicPan(this);
  }

  updateReaderComicPan(event: GestureEvent): void {
    ReaderChromeThemeOps.updateReaderComicPan(this, event);
  }

  finishReaderComicPan(event: GestureEvent): void {
    ReaderChromeThemeOps.finishReaderComicPan(this, event);
  }

  cancelReaderComicPan(): void {
    ReaderChromeThemeOps.cancelReaderComicPan(this);
  }

  resetReaderComicBoundaryFeedback(animated: boolean): void {
    ReaderChromeThemeOps.resetReaderComicBoundaryFeedback(this, animated);
  }

  readerComicBoundaryHintText(): string {
    return ReaderChromeThemeOps.readerComicBoundaryHintText(this);
  }

  switchComicBoundaryChapter(direction: number): void {
    ReaderChromeThemeOps.switchComicBoundaryChapter(this, direction);
  }

  async runReaderComicChapterTransition(direction: number): Promise<void> {
    return ReaderChromeThemeOps.runReaderComicChapterTransition(this, direction);
  }

  syncReaderComicPageDataSource(): void {
    ReaderChromeThemeOps.syncReaderComicPageDataSource(this);
  }

  /**
   * onDataReloaded 会重建 LazyForEach 的挂载项，部分系统版本会把 List 打回索引 0，表现为
   * "阅读中偶发回到本章开头"。发布分页时 currentPageIndex 仍是权威位置，延迟一帧校验并把
   * List 拉回该页；位置未被破坏时 scrollToIndex 等价于无操作。
   */
  reanchorContinuousReaderScrollAfterReload(reloaded: boolean): void {
    ReaderChromeThemeOps.reanchorContinuousReaderScrollAfterReload(this, reloaded);
  }

  getReaderComicImageHeight(index: number): number {
    return ReaderChromeThemeOps.getReaderComicImageHeight(this, index);
  }

  getReaderComicImageSeamOverlap(index: number): number {
    return ReaderChromeThemeOps.getReaderComicImageSeamOverlap(this, index);
  }

  getReaderComicImageRenderHeight(index: number): number {
    return ReaderChromeThemeOps.getReaderComicImageRenderHeight(this, index);
  }

  getReaderComicImageFit(index: number): ImageFit {
    return ReaderChromeThemeOps.getReaderComicImageFit(this, index);
  }

  updateReaderComicImageRatio(index: number, sourceWidth: number, sourceHeight: number): void {
    ReaderChromeThemeOps.updateReaderComicImageRatio(this, index, sourceWidth, sourceHeight);
  }

  async ensureReaderComicImageRatio(index: number, marker: string): Promise<void> {
    return ReaderChromeThemeOps.ensureReaderComicImageRatio(this, index, marker);
  }

  scheduleReaderComicScrollRestore(): void {
    ReaderChromeThemeOps.scheduleReaderComicScrollRestore(this);
  }

  onReaderComicScrollIndexChanged(start: number, end: number): void {
    ReaderChromeThemeOps.onReaderComicScrollIndexChanged(this, start, end);
  }

  onReaderContinuousReachEnd(): void {
    ReaderChromeThemeOps.onReaderContinuousReachEnd(this);
  }

  pruneContinuousReaderSelectionAreas(): void {
    ReaderChromeThemeOps.pruneContinuousReaderSelectionAreas(this);
  }

  scheduleReaderComicProgressSave(): void {
    ReaderChromeThemeOps.scheduleReaderComicProgressSave(this);
  }

  clearReaderComicProgressSaveTimer(): void {
    ReaderChromeThemeOps.clearReaderComicProgressSaveTimer(this);
  }

  scheduleReaderPagedProgressSave(): void {
    ReaderChromeThemeOps.scheduleReaderPagedProgressSave(this);
  }

  clearReaderPagedProgressSaveTimer(): void {
    ReaderChromeThemeOps.clearReaderPagedProgressSaveTimer(this);
  }



  clearReaderComicPaginationProgress(): void {
    ReaderChromeThemeOps.clearReaderComicPaginationProgress(this);
  }

  updateReaderComicPaginationProgress(chapterIndex: number, result: ReaderPaginationResult): void {
    ReaderChromeThemeOps.updateReaderComicPaginationProgress(this, chapterIndex, result);
  }


  /**
   * 图片 onError 后记录失败页并输出诊断日志：区分网络/本地来源，本地图检查文件是否存在，
   * 网络图记录 Image 组件给出的错误信息，用于区分"文件缺失"与"加载/解码失败"两类空白原因。
   */
  markReaderComicImageBroken(index: number, page: string, error: ImageError): void {
    if (this.readerComicBrokenPages.includes(index)) return;
    this.readerComicBrokenPages = [...this.readerComicBrokenPages, index];
    const payload = LocalBookService.epubImagePathFromMarker(page);
    const isRemote = /^(?:https?:|data:)/i.test(payload);
    let exists = false;
    if (!isRemote && payload) {
      try {
        exists = fs.accessSync(payload);
      } catch (_) {
        exists = false;
      }
    }
    const errorMessage = error?.message || '';
    console.error(`[ReaderComic] 图片加载失败 index=${index} 来源=${isRemote ? '网络' : '本地'} ` +
      `文件存在=${exists} message=${errorMessage} 路径=${payload}`);
  }

  /** 占位提示点击重试：移出失败集合并重建条目，触发 Image 重新加载。 */
  retryReaderComicImage(index: number): void {
    ReaderChromeThemeOps.retryReaderComicImage(this, index);
  }

  getEffectiveReaderMarginLeft(): number {
    return ReaderChromeThemeOps.getEffectiveReaderMarginLeft(this);
  }

  getEffectiveReaderMarginRight(): number {
    return ReaderChromeThemeOps.getEffectiveReaderMarginRight(this);
  }

  getEffectiveReaderHorizontalMargin(left: boolean): number {
    return ReaderChromeThemeOps.getEffectiveReaderHorizontalMargin(this, left);
  }

  getEffectiveReaderMarginTop(): number {
    return ReaderChromeThemeOps.getEffectiveReaderMarginTop(this);
  }


  getReaderHeaderOverlayTopInset(): number {
    return ReaderChromeThemeOps.getReaderHeaderOverlayTopInset(this);
  }

  getReaderHeaderContentReserve(): number {
    return ReaderChromeThemeOps.getReaderHeaderContentReserve(this);
  }

  getEffectiveReaderMarginBottom(): number {
    return ReaderChromeThemeOps.getEffectiveReaderMarginBottom(this);
  }

  getEffectiveReaderVerticalMargin(top: boolean): number {
    return ReaderChromeThemeOps.getEffectiveReaderVerticalMargin(this, top);
  }

  getReaderPageTurnStep(): number {
    return ReaderChromeThemeOps.getReaderPageTurnStep(this);
  }

  normalizeReaderSpreadPageIndex(pageIndex: number): number {
    return ReaderChromeThemeOps.normalizeReaderSpreadPageIndex(this, pageIndex);
  }

  getSecondaryPageText(pageIndex: number = this.currentPageIndex): string {
    return ReaderChromeThemeOps.getSecondaryPageText(this, pageIndex);
  }

  currentReaderSurfaceIndex(): number {
    return ReaderChromeThemeOps.currentReaderSurfaceIndex(this);
  }

  currentReaderSurfaceKeys(): string[] {
    return ReaderChromeThemeOps.currentReaderSurfaceKeys(this);
  }

  currentReaderV2ChapterSurfaceKeys(): string[] {
    return ReaderChromeThemeOps.currentReaderV2ChapterSurfaceKeys(this);
  }

  visibleCurrentPageText(): string {
    return ReaderChromeThemeOps.visibleCurrentPageText(this);
  }

  syncCurrentPageText(): void {
    ReaderChromeThemeOps.syncCurrentPageText(this);
  }

  setCurrentPageText(text: string): void {
    ReaderChromeThemeOps.setCurrentPageText(this, text);
  }

  updatePagedReaderArea(area: Area): void {
    ReaderChromeThemeOps.updatePagedReaderArea(this, area);
  }

  rememberReaderBottomInfoBarHeight(area: Area): void {
    ReaderChromeThemeOps.rememberReaderBottomInfoBarHeight(this, area);
  }


  applyReaderBottomInfoBarMeasuredHeight(height: number): void {
    ReaderChromeThemeOps.applyReaderBottomInfoBarMeasuredHeight(this, height);
  }

  hasPagedReaderArea(): boolean {
    return ReaderChromeThemeOps.hasPagedReaderArea(this);
  }

  getCurrentPageStartOffset(): number {
    return ReaderChromeThemeOps.getCurrentPageStartOffset(this);
  }

  getReaderStableReflowOffset(): number {
    return ReaderChromeThemeOps.getReaderStableReflowOffset(this);
  }

  getPageStartOffset(pageIndex: number): number {
    return ReaderChromeThemeOps.getPageStartOffset(this, pageIndex);
  }

  getPageEndOffset(pageIndex: number): number {
    return ReaderChromeThemeOps.getPageEndOffset(this, pageIndex);
  }

  findPageIndexByOffset(offset: number): number {
    return ReaderChromeThemeOps.findPageIndexByOffset(this, offset);
  }

  restoreReaderTypographyOffsetIfAvailable(paginationComplete: boolean): boolean {
    return ReaderChromeThemeOps.restoreReaderTypographyOffsetIfAvailable(this, paginationComplete);
  }

  setReaderTypographyRestoreOffset(offset: number): void {
    ReaderChromeThemeOps.setReaderTypographyRestoreOffset(this, offset);
  }

  hasReaderTypographyRestoreOffset(): boolean {
    return ReaderChromeThemeOps.hasReaderTypographyRestoreOffset(this);
  }

  getBackgroundColor(): string {
    return ReaderChromeThemeOps.getBackgroundColor(this);
  }

  getBackgroundAssetId(): string {
    return ReaderChromeThemeOps.getBackgroundAssetId(this);
  }

  getBackgroundImageFit(): ImageFit {
    return ReaderChromeThemeOps.getBackgroundImageFit(this);
  }

  hasBackgroundImage(): boolean {
    return ReaderChromeThemeOps.hasBackgroundImage(this);
  }

  readerContentLayerColor(): string {
    return ReaderChromeThemeOps.readerContentLayerColor(this);
  }

  getTextColor(): string {
    return ReaderChromeThemeOps.getTextColor(this);
  }

  currentReaderThemeIndex(): number {
    return ReaderChromeThemeOps.currentReaderThemeIndex(this);
  }

  currentReaderThemes(): ReaderThemeItem[] {
    return ReaderChromeThemeOps.currentReaderThemes(this);
  }

  currentReaderTheme(): ReaderThemeItem {
    return ReaderChromeThemeOps.currentReaderTheme(this);
  }

  currentCustomThemeBackgroundColor(): string {
    return ReaderChromeThemeOps.currentCustomThemeBackgroundColor(this);
  }

  currentCustomThemeTextColor(): string {
    return ReaderChromeThemeOps.currentCustomThemeTextColor(this);
  }

  currentCustomThemeBackgroundImageUri(): string {
    return ReaderChromeThemeOps.currentCustomThemeBackgroundImageUri(this);
  }

  currentCustomThemeBackgroundTypeIndex(): number {
    return ReaderChromeThemeOps.currentCustomThemeBackgroundTypeIndex(this);
  }

  customThemeData(): ReaderCustomThemeData {
    return ReaderChromeThemeOps.customThemeData(this);
  }

  currentCustomThemeScheme(): ReaderCustomThemeScheme {
    return ReaderChromeThemeOps.currentCustomThemeScheme(this);
  }

  currentCustomThemeSchemes(): ReaderCustomThemeScheme[] {
    return ReaderChromeThemeOps.currentCustomThemeSchemes(this);
  }

  currentCustomThemeSelectedIndex(): number {
    return ReaderChromeThemeOps.currentCustomThemeSelectedIndex(this);
  }

  customThemeOptions(): SelectOption[] {
    return ReaderChromeThemeOps.customThemeOptions(this);
  }

  customThemeFitSelectedIndex(): number {
    return ReaderChromeThemeOps.customThemeFitSelectedIndex(this);
  }

  isReaderThemeDark(): boolean {
    return ReaderChromeThemeOps.isReaderThemeDark(this);
  }

  isDarkHexColor(color: string): boolean {
    return ReaderChromeThemeOps.isDarkHexColor(this, color);
  }

  getReaderFontFamily(): string {
    return ReaderChromeThemeOps.getReaderFontFamily(this);
  }

  getBodyReaderFontFamily(): string {
    return ReaderChromeThemeOps.getBodyReaderFontFamily(this);
  }

  getTitleReaderFontFamily(): string {
    return ReaderChromeThemeOps.getTitleReaderFontFamily(this);
  }

  getRegexReaderFontFamily(): string {
    return ReaderChromeThemeOps.getRegexReaderFontFamily(this);
  }

  resolveStyledReaderFontFamily(mode: string, family: string): string {
    return ReaderChromeThemeOps.resolveStyledReaderFontFamily(this, mode, family);
  }


  registerCustomReaderFontFamily(family: string): void {
    ReaderChromeThemeOps.registerCustomReaderFontFamily(this, family);
  }

  registerStyledCustomReaderFonts(): void {
    ReaderChromeThemeOps.registerStyledCustomReaderFonts(this);
  }

  resolveReaderFontFamily(): string {
    return ReaderChromeThemeOps.resolveReaderFontFamily(this);
  }

  getSystemReaderFontFamily(): string {
    return ReaderChromeThemeOps.getSystemReaderFontFamily(this);
  }

  isReaderFontReady(): boolean {
    return ReaderChromeThemeOps.isReaderFontReady(this);
  }

  clearReaderFontState(): void {
    ReaderChromeThemeOps.clearReaderFontState(this);
  }

  async registerReaderFont(): Promise<boolean> {
    return ReaderChromeThemeOps.registerReaderFont(this);
  }

  async registerReaderFontBySettings(fontFamily: string, fontFilePath: string, fontSourceName: string): Promise<boolean> {
    return ReaderChromeThemeOps.registerReaderFontBySettings(this, fontFamily, fontFilePath, fontSourceName);
  }

  async registerReaderFontAsync(source: string): Promise<boolean> {
    return ReaderChromeThemeOps.registerReaderFontAsync(this, source);
  }

  activateRegisteredReaderFont(familyName: string): void {
    ReaderChromeThemeOps.activateRegisteredReaderFont(this, familyName);
  }

  refreshRegisteredReaderFontLater(familyName: string, delayMs: number): void {
    ReaderChromeThemeOps.refreshRegisteredReaderFontLater(this, familyName, delayMs);
  }

  applyLoadedReaderSettings(settings: ReaderSettings): void {
    ReaderChromeThemeOps.applyLoadedReaderSettings(this, settings);
  }

  onReaderFontStyleChanged(): void {
    this.cachedRegexRulesKey = '';
    this.cachedRegexRules = [];
    this.readerPaginationCache.clear();
    this.pageTurnPreviewKey = '';
    this.registerStyledCustomReaderFonts();
    this.refreshReaderTextRender();
    this.paginateContent(this.content);
    this.preloadNextChapterPaginationLater();
  }



  applyReaderApplicationFont(familyName: string): void {
    ReaderChromeThemeOps.applyReaderApplicationFont(this, familyName);
  }

  saveReaderFontSettings(): void {
    ReaderChromeThemeOps.saveReaderFontSettings(this);
  }

  getTocTitleColor(chapter: BookChapter, index: number): string {
    return ReaderChromeThemeOps.getTocTitleColor(this, chapter, index);
  }

  setReaderContent(text: string): void {
    ReaderChromeThemeOps.setReaderContent(this, text);
  }

  openTocPanel(): void {
    ReaderChromeThemeOps.openTocPanel(this);
  }

  async refreshTocFromPanel(): Promise<void> {
    return ReaderChromeThemeOps.refreshTocFromPanel(this);
  }

  async loadBookmarks(): Promise<void> {
    return ReaderChromeThemeOps.loadBookmarks(this);
  }

  currentPageBookmark(): Bookmark | undefined {
    return ReaderChromeThemeOps.currentPageBookmark(this);
  }

  isCurrentPageBookmarked(): boolean {
    return ReaderChromeThemeOps.isCurrentPageBookmarked(this);
  }

  async toggleCurrentPageBookmark(): Promise<void> {
    return ReaderChromeThemeOps.toggleCurrentPageBookmark(this);
  }

  bookmarkPullHintText(): string {
    return ReaderChromeThemeOps.bookmarkPullHintText(this);
  }

  bookmarkPullHintColor(): string {
    return ReaderChromeThemeOps.bookmarkPullHintColor(this);
  }

  readerBookmarkMarkerTopOffset(): number {
    return ReaderChromeThemeOps.readerBookmarkMarkerTopOffset(this);
  }

  async addCurrentBookmark(): Promise<void> {
    return ReaderChromeThemeOps.addCurrentBookmark(this);
  }

  bookmarkContentPreview(pageIndex: number): string {
    return ReaderChromeThemeOps.bookmarkContentPreview(this, pageIndex);
  }

  async deleteBookmark(bookmark: Bookmark): Promise<void> {
    return ReaderChromeThemeOps.deleteBookmark(this, bookmark);
  }

  enterBookmarkMultiSelect(bookmarkUrl: string): void {
    ReaderChromeThemeOps.enterBookmarkMultiSelect(this, bookmarkUrl);
  }

  isBookmarkSelected(bookmarkUrl: string): boolean {
    return ReaderChromeThemeOps.isBookmarkSelected(this, bookmarkUrl);
  }

  toggleBookmarkSelection(bookmarkUrl: string): void {
    ReaderChromeThemeOps.toggleBookmarkSelection(this, bookmarkUrl);
  }

  toggleSelectAllBookmarks(): void {
    ReaderChromeThemeOps.toggleSelectAllBookmarks(this);
  }

  cancelBookmarkMultiSelect(): void {
    ReaderChromeThemeOps.cancelBookmarkMultiSelect(this);
  }

  async deleteSelectedBookmarks(): Promise<void> {
    return ReaderChromeThemeOps.deleteSelectedBookmarks(this);
  }

  async jumpToBookmark(bookmark: Bookmark): Promise<void> {
    return ReaderChromeThemeOps.jumpToBookmark(this, bookmark);
  }


  openSettingsPanel(): void {
    ReaderChromeThemeOps.openSettingsPanel(this);
  }

  openTtsSettingsPanel(): void {
    ReaderChromeThemeOps.openTtsSettingsPanel(this);
  }

  openTypographySettingsPanel(): void {
    ReaderChromeThemeOps.openTypographySettingsPanel(this);
  }

  closeSettingsPanelKeepMenu(): void {
    ReaderChromeThemeOps.closeSettingsPanelKeepMenu(this);
  }

  async loadTtsSettingsAndVoices(): Promise<void> {
    return ReaderChromeThemeOps.loadTtsSettingsAndVoices(this);
  }

  applyLoadedTtsSettings(settings: TtsSettings): void {
    ReaderChromeThemeOps.applyLoadedTtsSettings(this, settings);
  }

  onTtsCustomVoicesChanged(): void {
    this.ttsCustomVoiceOptions = SystemTtsReader.parseCustomVoices(this.ttsCustomVoices);
    this.ttsSelectedVoiceKey = this.currentTtsVoiceKey();
  }

  normalizeDefaultTtsVoice(): void {
    ReaderChromeThemeOps.normalizeDefaultTtsVoice(this);
  }

  currentTtsSettings(): TtsSettings {
    return ReaderChromeThemeOps.currentTtsSettings(this);
  }

  saveTtsSettings(): void {
    ReaderChromeThemeOps.saveTtsSettings(this);
  }

  async loadTtsVoices(): Promise<void> {
    return ReaderChromeThemeOps.loadTtsVoices(this);
  }

  firstAvailableTtsVoice(): TtsVoiceOption {
    return ReaderChromeThemeOps.firstAvailableTtsVoice(this);
  }

  applyInstalledTtsVoiceOverrides(voices: TtsVoiceOption[]): TtsVoiceOption[] {
    return ReaderChromeThemeOps.applyInstalledTtsVoiceOverrides(this, voices);
  }


  isLocallyInstalledTtsVoice(voice: TtsVoiceOption): boolean {
    return ReaderChromeThemeOps.isLocallyInstalledTtsVoice(this, voice);
  }


  isTtsSessionManuallyPaused(): boolean {
    return ReaderChromeThemeOps.isTtsSessionManuallyPaused(this);
  }

  applyTtsVoice(voice: TtsVoiceOption, restartSpeaking: boolean): void {
    ReaderChromeThemeOps.applyTtsVoice(this, voice, restartSpeaking);
  }

  applyTtsSpeed(value: number): void {
    ReaderChromeThemeOps.applyTtsSpeed(this, value);
  }

  scheduleActiveTtsSpeedRestart(): void {
    ReaderChromeThemeOps.scheduleActiveTtsSpeedRestart(this);
  }

  scheduleTtsSpeedSettingsSave(): void {
    ReaderChromeThemeOps.scheduleTtsSpeedSettingsSave(this);
  }

  scheduleTtsSpeedAvSessionUpdate(): void {
    ReaderChromeThemeOps.scheduleTtsSpeedAvSessionUpdate(this);
  }

  flushPendingTtsSpeedSettings(): void {
    ReaderChromeThemeOps.flushPendingTtsSpeedSettings(this);
  }

  currentTtsVoiceKey(): string {
    return ReaderChromeThemeOps.currentTtsVoiceKey(this);
  }

  findCurrentTtsVoice(): TtsVoiceOption | undefined {
    return ReaderChromeThemeOps.findCurrentTtsVoice(this);
  }

  isCurrentTtsVoice(voice: TtsVoiceOption): boolean {
    return ReaderChromeThemeOps.isCurrentTtsVoice(this, voice);
  }

  applyCustomTtsVoice(voice: HttpTTS, restartSpeaking: boolean): void {
    ReaderChromeThemeOps.applyCustomTtsVoice(this, voice, restartSpeaking);
  }

  findCurrentCustomTtsVoice(): HttpTTS | undefined {
    return ReaderChromeThemeOps.findCurrentCustomTtsVoice(this);
  }


  isCurrentCustomTtsVoice(voice: HttpTTS): boolean {
    return ReaderChromeThemeOps.isCurrentCustomTtsVoice(this, voice);
  }




  tocGlobalIndex(localIndex: number): number {
    return ReaderChromeThemeOps.tocGlobalIndex(this, localIndex);
  }

  tocChapterAtDisplayIndex(displayIndex: number): BookChapter {
    return ReaderChromeThemeOps.tocChapterAtDisplayIndex(this, displayIndex);
  }

  toggleTocOrder(): void {
    ReaderChromeThemeOps.toggleTocOrder(this);
  }

  selectableCustomTtsVoices(): HttpTTS[] {
    return ReaderChromeThemeOps.selectableCustomTtsVoices(this);
  }

  selectableSystemTtsVoices(): TtsVoiceOption[] {
    return ReaderChromeThemeOps.selectableSystemTtsVoices(this);
  }

  async downloadTtsVoice(voice: TtsVoiceOption): Promise<void> {
    return ReaderChromeThemeOps.downloadTtsVoice(this, voice);
  }

  markTtsVoiceInstalled(voice: TtsVoiceOption): void {
    ReaderChromeThemeOps.markTtsVoiceInstalled(this, voice);
  }

  selectedTtsVoiceTitle(): string {
    return ReaderChromeThemeOps.selectedTtsVoiceTitle(this);
  }

  ttsQuickVoiceOptions(): SelectOption[] {
    return ReaderChromeThemeOps.ttsQuickVoiceOptions(this);
  }

  ttsQuickVoiceLabels(): string[] {
    return ReaderChromeThemeOps.ttsQuickVoiceLabels(this);
  }

  ttsQuickVoiceSelectedIndex(): number {
    return ReaderChromeThemeOps.ttsQuickVoiceSelectedIndex(this);
  }

  selectTtsQuickVoice(index: number): void {
    ReaderChromeThemeOps.selectTtsQuickVoice(this, index);
  }

  isTocSearchActive(): boolean {
    return ReaderChromeThemeOps.isTocSearchActive(this);
  }

  toggleTocSearch(): void {
    ReaderChromeThemeOps.toggleTocSearch(this);
  }

  async submitTocSearch(): Promise<void> {
    return ReaderChromeThemeOps.submitTocSearch(this);
  }

  clearTocSearchResult(): void {
    ReaderChromeThemeOps.clearTocSearchResult(this);
  }

  async loadTocDatabaseChapterCount(): Promise<void> {
    return ReaderChromeThemeOps.loadTocDatabaseChapterCount(this);
  }

  updateTocScrollbarPosition(start: number, end: number): void {
    ReaderChromeThemeOps.updateTocScrollbarPosition(this, start, end);
  }

  tocShouldShowVirtualScrollbar(): boolean {
    return ReaderChromeThemeOps.tocShouldShowVirtualScrollbar(this);
  }

  tocScrollbarThumbLength(): number {
    return ReaderChromeThemeOps.tocScrollbarThumbLength(this);
  }

  tocScrollbarThumbOffset(): number {
    return ReaderChromeThemeOps.tocScrollbarThumbOffset(this);
  }

  tocDisplayedScrollbarThumbOffset(): number {
    return ReaderChromeThemeOps.tocDisplayedScrollbarThumbOffset(this);
  }


  beginTocScrollbarDrag(event: GestureEvent): void {
    ReaderChromeThemeOps.beginTocScrollbarDrag(this, event);
  }

  updateTocScrollbarDrag(event: GestureEvent): void {
    ReaderChromeThemeOps.updateTocScrollbarDrag(this, event);
  }

  endTocScrollbarDrag(event: GestureEvent): void {
    ReaderChromeThemeOps.endTocScrollbarDrag(this, event);
  }

  cancelTocScrollbarDrag(): void {
    ReaderChromeThemeOps.cancelTocScrollbarDrag(this);
  }

  jumpTocScrollbarToPointer(event: GestureEvent): void {
    ReaderChromeThemeOps.jumpTocScrollbarToPointer(this, event);
  }

  updateTocScrollbarFromPointer(pointerY: number): void {
    ReaderChromeThemeOps.updateTocScrollbarFromPointer(this, pointerY);
  }

  flushTocScrollbarTarget(): void {
    ReaderChromeThemeOps.flushTocScrollbarTarget(this);
  }

  queueTocScrollbarTarget(targetIndex: number, delayMs: number = 16): void {
    ReaderChromeThemeOps.queueTocScrollbarTarget(this, targetIndex, delayMs);
  }

  applyTocScrollbarTarget(targetIndex: number): void {
    ReaderChromeThemeOps.applyTocScrollbarTarget(this, targetIndex);
  }

  nearestTocSearchResultIndex(targetIndex: number): number {
    return ReaderChromeThemeOps.nearestTocSearchResultIndex(this, targetIndex);
  }

  scrollTocVisibleEdge(toEnd: boolean): void {
    ReaderChromeThemeOps.scrollTocVisibleEdge(this, toEnd);
  }

  setTocWindowAround(index: number, align: ScrollAlign): number {
    return ReaderChromeThemeOps.setTocWindowAround(this, index, align);
  }

  loadNextTocPage(): void {
    ReaderChromeThemeOps.loadNextTocPage(this);
  }

  loadPreviousTocPage(): void {
    ReaderChromeThemeOps.loadPreviousTocPage(this);
  }

  scrollTocToCurrentChapter(smooth: boolean = true): void {
    ReaderChromeThemeOps.scrollTocToCurrentChapter(this, smooth);
  }

  scrollTocToChapter(index: number, align: ScrollAlign, smooth: boolean = true): void {
    ReaderChromeThemeOps.scrollTocToChapter(this, index, align, smooth);
  }

  getSubTextColor(): string {
    return ReaderChromeThemeOps.getSubTextColor(this);
  }

  // Reader controls (floating top menu, panels, toolbars) sit on their own
  // light/dark material surface rather than directly on the page, so they need
  // a fixed high-contrast icon color instead of the theme's reader text color.
  readerControlIconColor(): string {
    return ReaderChromeThemeOps.readerControlIconColor(this);
  }

  accentColor(): string {
    return ReaderChromeThemeOps.accentColor(this);
  }

  buttonColor(): string {
    return ReaderChromeThemeOps.buttonColor(this);
  }

  /** 删除/错误等危险操作的语义色：跟随主题，浅色/深色分别取值。 */
  dangerColor(): string {
    return ReaderChromeThemeOps.dangerColor(this);
  }

  /** 设置面板滚动条滑块颜色：深浅两套，收拢散落的硬编码对。 */
  readerPanelScrollBarColor(): string {
    return ReaderChromeThemeOps.readerPanelScrollBarColor(this);
  }

  /** 朗读设置中速速/定时芯片与弱按钮的休眠底色：深浅两套。 */
  readerChipIdleColor(): string {
    return ReaderChromeThemeOps.readerChipIdleColor(this);
  }

  /** 自定义主题编辑器中输入框/选择器的底色（跟随系统深浅色，而非阅读主题）。 */
  customThemeFieldColor(): string {
    return ReaderChromeThemeOps.customThemeFieldColor(this);
  }

  tocSelectedBackgroundColor(): string {
    return ReaderChromeThemeOps.tocSelectedBackgroundColor(this);
  }

  readerGlassPanelColor(): string {
    return ReaderChromeThemeOps.readerGlassPanelColor(this);
  }

  readerGlassBorderColor(): string {
    return ReaderChromeThemeOps.readerGlassBorderColor(this);
  }

  readerGlassShadowColor(): string {
    return ReaderChromeThemeOps.readerGlassShadowColor(this);
  }

  readerSolidPanelColor(): string {
    return ReaderChromeThemeOps.readerSolidPanelColor(this);
  }

  getReaderPageTurnSurfaceSafeAreaEdges(): SafeAreaEdge[] {
    return ReaderChromeThemeOps.getReaderPageTurnSurfaceSafeAreaEdges(this);
  }

  getReaderTopSafePadding(): number {
    return ReaderChromeThemeOps.getReaderTopSafePadding(this);
  }

  getReaderPageContentTopPadding(): number {
    return ReaderChromeThemeOps.getReaderPageContentTopPadding(this);
  }

  getTopControlSafePadding(): number {
    return ReaderChromeThemeOps.getTopControlSafePadding(this);
  }

  getTopOverlayHeight(): number {
    return ReaderChromeThemeOps.getTopOverlayHeight(this);
  }

  getReaderContentBottomReserve(): number {
    return ReaderChromeThemeOps.getReaderContentBottomReserve(this);
  }


  getReaderBottomInfoBarHeight(): number {
    return ReaderChromeThemeOps.getReaderBottomInfoBarHeight(this);
  }

  getReaderBottomInfoBarBottomInset(): number {
    return ReaderChromeThemeOps.getReaderBottomInfoBarBottomInset(this);
  }


  getReaderV2BottomGuard(): number {
    return ReaderChromeThemeOps.getReaderV2BottomGuard(this);
  }
//endregion
//region 尺寸计算 / 排版变更监听 / 媒体控制条·睡眠定时器 / 触摸·翻页手势
// [map] 契约: 读写 面板尺寸/排版代际/媒体控制/触摸 状态; 定时器成对清理

  getReaderPaginationBottomInfoBarHeight(): number {
    return ReaderGestureOps.getReaderPaginationBottomInfoBarHeight(this);
  }

  getReaderBottomInfoBarVisualOffsetY(): number {
    return ReaderGestureOps.getReaderBottomInfoBarVisualOffsetY(this);
  }

  readerFloatingBarBottomMargin(): number {
    return ReaderGestureOps.readerFloatingBarBottomMargin(this);
  }

  readerFloatingBarWidth(): number {
    return ReaderGestureOps.readerFloatingBarWidth(this);
  }

  readerSettingsPanelHeight(): number {
    return ReaderGestureOps.readerSettingsPanelHeight(this);
  }

  readerChapterTrackColor(): string {
    return ReaderGestureOps.readerChapterTrackColor(this);
  }


  readerUsesSideAnchoredControls(): boolean {
    return ReaderGestureOps.readerUsesSideAnchoredControls(this);
  }

  readerFloatingBarLeft(): number {
    return ReaderGestureOps.readerFloatingBarLeft(this);
  }

  readerFloatingBarRight(): number {
    return ReaderGestureOps.readerFloatingBarRight(this);
  }

  readerFloatingBarTranslateX(): number {
    return ReaderGestureOps.readerFloatingBarTranslateX(this);
  }

  readerChapterTooltipWidth(): number {
    return ReaderGestureOps.readerChapterTooltipWidth(this);
  }

  readerChapterTooltipCenteredLeft(): number {
    return ReaderGestureOps.readerChapterTooltipCenteredLeft(this);
  }

  readerTtsQuickActionLeft(): number {
    return ReaderGestureOps.readerTtsQuickActionLeft(this);
  }

  readerTtsExpandedControlLeft(): number {
    return ReaderGestureOps.readerTtsExpandedControlLeft(this);
  }

  readerBottomMenuOverlayHeight(): number {
    return ReaderGestureOps.readerBottomMenuOverlayHeight(this);
  }

  readerBottomActionOverlayHeight(): number {
    return ReaderGestureOps.readerBottomActionOverlayHeight(this);
  }

  readerFloatingPanelBottomInset(): number {
    return ReaderGestureOps.readerFloatingPanelBottomInset(this);
  }

  readerTocPanelHeight(): number {
    return ReaderGestureOps.readerTocPanelHeight(this);
  }

  getReaderContentBottomPadding(): number {
    return ReaderGestureOps.getReaderContentBottomPadding(this);
  }

  getReaderPaginationViewportHeight(): number {
    return ReaderGestureOps.getReaderPaginationViewportHeight(this);
  }

  getReaderBackgroundViewportHeight(): number {
    return ReaderGestureOps.getReaderBackgroundViewportHeight(this);
  }

  getEffectiveReaderLineHeight(): number {
    return ReaderGestureOps.getEffectiveReaderLineHeight(this);
  }

  getReaderPageColumnWidth(): number {
    return ReaderGestureOps.getReaderPageColumnWidth(this);
  }

  getReaderDoublePageRightOrigin(): number {
    return ReaderGestureOps.getReaderDoublePageRightOrigin(this);
  }

  readerTextAlignValue(): TextAlign {
    return ReaderGestureOps.readerTextAlignValue(this);
  }

  readerGraphicsTextAlignValue(): graphicsText.TextAlign {
    return ReaderGestureOps.readerGraphicsTextAlignValue(this);
  }

  getReaderAdaptiveLetterSpacing(): number {
    return ReaderGestureOps.getReaderAdaptiveLetterSpacing(this);
  }

  getReaderPageLineSpacing(pageLineHeight: number = this.getEffectiveReaderLineHeight()): number {
    return ReaderGestureOps.getReaderPageLineSpacing(this, pageLineHeight);
  }

  getReaderParagraphBoundarySpacing(pageLineHeight: number = this.getEffectiveReaderLineHeight()): number {
    return ReaderGestureOps.getReaderParagraphBoundarySpacing(this, pageLineHeight);
  }

  getMeasuredReaderParagraphBoundarySpacingPx(): number {
    return ReaderGestureOps.getMeasuredReaderParagraphBoundarySpacingPx(this);
  }

  getMeasuredReaderParagraphComponentHeightPx(metrics: ReaderParagraphMetrics,
    pageLineHeight: number = this.getEffectiveReaderLineHeight(), componentPixelAligned: boolean = false): number {
    return ReaderGestureOps.getMeasuredReaderParagraphComponentHeightPx(this, metrics, pageLineHeight, componentPixelAligned);
  }

  getMeasuredReaderParagraphBoundarySpacingForLineHeightPx(pageLineHeight: number,
    componentBoundaryPixelAligned: boolean = false): number {
    return ReaderGestureOps.getMeasuredReaderParagraphBoundarySpacingForLineHeightPx(this, pageLineHeight, componentBoundaryPixelAligned);
  }

  getMeasuredReaderPageBodyHeightPx(metricsList: ReaderParagraphMetrics[], pageLineHeight: number,
    componentPixelAligned: boolean[] = []): number {
    return ReaderGestureOps.getMeasuredReaderPageBodyHeightPx(this, metricsList, pageLineHeight, componentPixelAligned);
  }

  getReaderAdaptivePageLineHeight(text: string, chapterIndex: number, pageIndex: number,
    pageStart: number = -1, documentSource: string = ''): number {
    return ReaderGestureOps.getReaderAdaptivePageLineHeight(this, text, chapterIndex, pageIndex, pageStart, documentSource);
  }

  onReadLayoutChanged(): void {
    if (this.readerEntryInitializing || this.readerLayoutCommitInProgress) return;
    this.scheduleReaderLayoutChange();
  }

  onReaderChromeChanged(): void {
    if (this.readerEntryInitializing) return;
    const readingOffset = this.getReaderStableReflowOffset();
    this.setReaderTypographyRestoreOffset(readingOffset);
    this.invalidateReaderTypographyLayout();
    this.refreshReaderTextRender();
    if (this.content) {
      this.paginateContent(this.content);
      if (this.hasPagedReaderArea() && this.pagedContentText) {
        this.currentPageIndex = this.normalizeReaderSpreadPageIndex(
          this.findPageIndexByOffset(readingOffset));
        this.syncCurrentPageText();
        // 页眉/页脚设置会清空 V2 的 retained controller。强制发布当前页，避免 NodeContainer
        // 在下一次翻页前继续绘制设置变更前的旧正文。
        this.forceCurrentReaderPageRender();
        this.refreshCurrentReaderV2RetainedPages(true);
      }
    }
    this.preloadNextChapterPaginationLater();
    this.preloadPreviousChapterPaginationLater();
    this.saveReaderChromeSettings();
    this.saveReadingProgress();
  }

  scheduleReaderLayoutChange(): void {
    ReaderGestureOps.scheduleReaderLayoutChange(this);
  }

  scheduleReaderTypographyChange(): void {
    ReaderGestureOps.scheduleReaderTypographyChange(this);
  }

  applyPendingReaderLayoutChange(): void {
    ReaderGestureOps.applyPendingReaderLayoutChange(this);
  }

  scheduleReaderLayoutStabilization(readingOffset: number): void {
    ReaderGestureOps.scheduleReaderLayoutStabilization(this, readingOffset);
  }

  invalidateReaderTypographyLayout(): void {
    ReaderGestureOps.invalidateReaderTypographyLayout(this);
  }

  flushPendingReaderLayoutChange(repaginate: boolean = true): void {
    ReaderGestureOps.flushPendingReaderLayoutChange(this, repaginate);
  }

  refreshReaderTextRender(): void {
    ReaderGestureOps.refreshReaderTextRender(this);
  }

  forceCurrentReaderPageRender(): void {
    ReaderGestureOps.forceCurrentReaderPageRender(this);
  }

  cancelReaderPaginationWork(releaseNativeCaches: boolean): void {
    ReaderGestureOps.cancelReaderPaginationWork(this, releaseNativeCaches);
  }

  onReaderFontChanged(): void {
    const serial = ++this.readerFontChangeSerial;
    if (!this.readerFontFilePath) {
      this.clearReaderFontState();
      this.refreshReaderTextRender();
      this.onReadLayoutChanged();
      return;
    }
    this.registerReaderFont().then((registered: boolean) => {
      if (serial !== this.readerFontChangeSerial) {
        return;
      }
      if (registered || !this.readerFontFilePath) {
        this.refreshReaderTextRender();
      }
      this.onReadLayoutChanged();
    });
  }

  onReaderActiveFontChanged(): void {
    if (!this.readerFontFilePath && !this.readerActiveFontFamily && !this.readerStoredFontRegistered) {
      this.clearReaderFontState();
      this.refreshReaderTextRender();
      this.onReadLayoutChanged();
    }
  }

  onReaderExtendToStatusBarChanged(): void {
    this.scheduleReaderExtendLayoutRefresh();
  }

  onReaderScreenOrientationChanged(): void {
    if (this.readerPageVisible) this.applyReaderScreenOrientation();
  }

  applyReaderScreenOrientation(orientation: string = this.readerScreenOrientation): void {
    ReaderGestureOps.applyReaderScreenOrientation(this, orientation);
  }

  resetReaderScreenOrientation(): void {
    ReaderGestureOps.resetReaderScreenOrientation(this);
  }

  syncReaderPageHeightForContentTopPadding(): void {
    ReaderGestureOps.syncReaderPageHeightForContentTopPadding(this);
  }

  scheduleReaderExtendLayoutRefresh(readingOffset: number = -1): void {
    ReaderGestureOps.scheduleReaderExtendLayoutRefresh(this, readingOffset);
  }

  onReaderThemeChanged(): void {
    this.scheduleReaderThemeRefresh();
  }

  onReaderColorModeChanged(): void {
    this.scheduleReaderThemeRefresh();
  }

  scheduleReaderThemeRefresh(): void {
    ReaderGestureOps.scheduleReaderThemeRefresh(this);
  }

  onTtsCoverSettingsChanged(): void {
    if (!this.isTtsSpeaking && !this.ttsReader.isSpeaking() && !this.hasTtsAvSession()) {
      this.refreshTtsMediaImage().catch((e: Error) => {
        console.warn('刷新朗读媒体封面失败:', e);
      });
      return;
    }
    this.refreshTtsMediaImage().then(() => {
      return this.updateTtsAvSessionPlaybackState(
        this.isTtsSpeaking || this.ttsReader.isSpeaking() ?
          this.ttsAvPlaybackState() : avSession.PlaybackState.PLAYBACK_STATE_STOP
      );
    }).catch((e: Error) => {
      console.warn('同步朗读媒体封面失败:', e);
    });
  }

  onReaderVolumeTurnPageChanged(): void {
    this.updateVolumeKeySubscription();
    this.saveReadConfig();
  }

  onReaderPageTurnAnimationChanged(): void {
    this.resetSlidePageEffect();
    this.saveReadConfig();
  }

  onReaderPreloadChanged(): void {
    this.preloadReaderContentLater();
    this.saveReadConfig();
  }

  updateVolumeKeySubscription(): void {
    ReaderGestureOps.updateVolumeKeySubscription(this);
  }

  registerVolumeKeyTurn(): void {
    ReaderGestureOps.registerVolumeKeyTurn(this);
  }

  unregisterVolumeKeyTurn(): void {
    ReaderGestureOps.unregisterVolumeKeyTurn(this);
  }

  handleVolumeKeyTurn(direction: number): void {
    ReaderGestureOps.handleVolumeKeyTurn(this, direction);
  }

  clampChapterIndex(index: number): number {
    return ReaderGestureOps.clampChapterIndex(this, index);
  }

  getMenuChapterDisplayIndex(): number {
    return ReaderGestureOps.getMenuChapterDisplayIndex(this);
  }

  handleMenuChapterSliderChange(value: number, mode: SliderChangeMode): void {
    ReaderGestureOps.handleMenuChapterSliderChange(this, value, mode);
  }

  async confirmMenuChapterJump(targetIndex: number): Promise<void> {
    return ReaderGestureOps.confirmMenuChapterJump(this, targetIndex);
  }

  resetMenuChapterPreview(): void {
    ReaderGestureOps.resetMenuChapterPreview(this);
  }

  async jumpToMenuChapter(targetIndex: number): Promise<void> {
    return ReaderGestureOps.jumpToMenuChapter(this, targetIndex);
  }

  async jumpToAdjacentChapterFromMenu(direction: number): Promise<void> {
    return ReaderGestureOps.jumpToAdjacentChapterFromMenu(this, direction);
  }

  restorePendingPageIndex(paginationComplete: boolean = true): void {
    ReaderGestureOps.restorePendingPageIndex(this, paginationComplete);
  }

  canSaveReadingProgress(): boolean {
    return ReaderGestureOps.canSaveReadingProgress(this);
  }

  committedLocalPageTurnCheckpointPageIndex(): number {
    return ReaderGestureOps.committedLocalPageTurnCheckpointPageIndex(this);
  }

  settleCommittedLocalPageTurnForCheckpoint(): void {
    ReaderGestureOps.settleCommittedLocalPageTurnForCheckpoint(this);
  }

  async saveReadingProgress(notifyShelf: boolean = false): Promise<void> {
    return ReaderGestureOps.saveReadingProgress(this, notifyShelf);
  }

  async markBookRecentlyRead() {
    if (!this.book) {
      return;
    }
    const now = Date.now();
    this.book.durChapterTime = now;
    this.book.putVariable('readStarted', '1');
    this.book.putVariable('lastReadTime', `${now}`);
    try {
      const db = AppDatabase.getInstance();
      await db.updateBook(this.book, false);
      AppStorage.setOrCreate('shelfUpdateTime', Date.now());
      this.lastRecentReadCardChapterIndex = this.currentChapterIndex;
      this.reloadRecentReadCardLater(true);
    } catch (e) {
      console.error('更新最近阅读时间失败:', e);
    }
  }

  reloadRecentReadCardLater(force: boolean = false): void {
    ReaderGestureOps.reloadRecentReadCardLater(this, force);
  }

  async saveReadConfig() {
    if (!this.book) return;
    this.book.setPageAnim(this.currentReaderThemeIndex());
    try {
      const db = AppDatabase.getInstance();
      await db.updateBook(this.book);
    } catch (e) {
      console.error('保存阅读设置失败:', e);
    }
  }

  currentChapterProgressPageCount(): number {
    return ReaderGestureOps.currentChapterProgressPageCount(this);
  }

  getShelfLastReadPageText(pageIndex: number): string {
    return ReaderGestureOps.getShelfLastReadPageText(this, pageIndex);
  }

  getShelfLastReadPageImage(pageIndex: number): string {
    const page = (this.getPageText(pageIndex) || '').trim();
    return LeafFns.isReaderImageOnlyPage(page) ? LeafFns.getReaderEpubImageUri(page) : '';
  }

  onReaderLandscapeDoublePageChanged(): void {
    const readingOffset = this.getReaderStableReflowOffset();
    this.finishPageTurnAnimation();
    this.readerPaginationCache.clear();
    this.paginateContent(this.content);
    this.currentPageIndex = this.normalizeReaderSpreadPageIndex(this.findPageIndexByOffset(readingOffset));
    this.syncCurrentPageText();
    this.refreshReaderTextRender();
    this.saveReadingProgress();
    this.saveReadConfig();
  }

  @Builder
  ttsExpandedMediaControlsBar() {
    HdsTabs({ barPosition: BarPosition.End, index: 0 }) {
      TabContent() {
        Column()
      }
      .height(48)
      .tabBar((): void => { ReaderTtsTimerControl({
              timerMinutes: this.ttsSleepTimerMinutes,
              remainingSeconds: this.ttsSleepTimerRemainingSeconds,
              textColor: this.getTextColor(),
              accentColor: this.accentColor()
            }); })

      TabContent() {
        Column()
      }
      .height(48)
      .tabBar((): void => { ReaderTtsMediaSymbolControl({ icon: $r('sys.symbol.arrow_left'), controlEnabled: this.canPlayPreviousTtsChapter(), accessibilityLabel: '上一章', textColor: this.getTextColor(), subTextColor: this.getSubTextColor() }); })

      TabContent() {
        Column()
      }
      .height(48)
      .tabBar((): void => { ReaderTtsMediaSymbolControl({ icon: this.isTtsSpeaking && !this.isTtsPaused ?
        $r('sys.symbol.pause') : $r('sys.symbol.play'), controlEnabled: true, accessibilityLabel: this.isTtsSpeaking && !this.isTtsPaused ? '暂停朗读' : '播放朗读', textColor: this.getTextColor(), subTextColor: this.getSubTextColor() }); })

      TabContent() {
        Column()
      }
      .height(48)
      .tabBar((): void => { ReaderTtsMediaSymbolControl({ icon: $r('sys.symbol.arrow_right'), controlEnabled: this.canPlayNextTtsChapter(), accessibilityLabel: '下一章', textColor: this.getTextColor(), subTextColor: this.getSubTextColor() }); })

      TabContent() {
        Column()
      }
      .height(48)
      .tabBar((): void => { ReaderTtsMediaSpeedControl({ speedText: `${this.ttsSpeed.toFixed(1)}x`, textColor: this.getTextColor() }); })

      TabContent() {
        Column()
      }
      .height(48)
      .tabBar((): void => { ReaderTtsMediaSymbolControl({ icon: $r('sys.symbol.xmark'), controlEnabled: true, accessibilityLabel: '关闭朗读控制', textColor: this.getTextColor(), subTextColor: this.getSubTextColor() }); })
    }
    .key(`reader_tts_controls_bar_${this.themeRevision}_${this.isReaderThemeDark() ? 'dark' : 'light'}`)
    .barBackgroundColor(this.readerGlassPanelColor())
    .barMode(BarMode.Fixed)
    .barHeight(48)
    .barOverlap(true)
    .barFloatingStyle({
      barWidth: {
        smallWidth: LeafFns.readerTtsExpandedControlWidth(),
        mediumWidth: LeafFns.readerTtsExpandedControlWidth(),
        largeWidth: LeafFns.readerTtsExpandedControlWidth()
      },
      systemMaterialEffect: {
        materialType: ImmersiveMaterialRuntime.materialType(),
        materialLevel: ImmersiveMaterialRuntime.materialLevel()
      },
      barSideMargin: 0,
      barBottomMargin: 4,
      gradientMask: {
        maskColor: '#00000000',
        maskHeight: 56
      },
      adaptToHandedness: false,
      thermoCtrl: true,
      barOpacity: 1
    })
    .scrollable(false)
    .onContentWillChange(() => false)
    .onTabBarClick((index: number) => {
      this.handleTtsExpandedControl(index);
    })
    .width(LeafFns.readerTtsExpandedControlWidth())
    .height(56)
    .position({ x: this.readerTtsExpandedControlLeft(), y: '100%' })
    .translate({
      y: -(this.readerBottomMenuOverlayHeight() + 66)
    })
  }

  @Builder
  ttsExpandedMediaControlsCompat() {
    Row() {
      Stack() {
        ReaderTtsTimerControl({
              timerMinutes: this.ttsSleepTimerMinutes,
              remainingSeconds: this.ttsSleepTimerRemainingSeconds,
              textColor: this.getTextColor(),
              accentColor: this.accentColor()
            })
      }
      .layoutWeight(1)
      .onClick(() => this.handleTtsExpandedControl(0))

      Stack() {
        ReaderTtsMediaSymbolControl({ icon: $r('sys.symbol.arrow_left'), controlEnabled: this.canPlayPreviousTtsChapter(), accessibilityLabel: '上一章', textColor: this.getTextColor(), subTextColor: this.getSubTextColor() })
      }
      .layoutWeight(1)
      .onClick(() => this.handleTtsExpandedControl(1))

      Stack() {
        ReaderTtsMediaSymbolControl({ icon: this.isTtsSpeaking && !this.isTtsPaused ?
          $r('sys.symbol.pause') : $r('sys.symbol.play'), controlEnabled: true, accessibilityLabel: this.isTtsSpeaking && !this.isTtsPaused ? '暂停朗读' : '播放朗读', textColor: this.getTextColor(), subTextColor: this.getSubTextColor() })
      }
      .layoutWeight(1)
      .onClick(() => this.handleTtsExpandedControl(2))

      Stack() {
        ReaderTtsMediaSymbolControl({ icon: $r('sys.symbol.arrow_right'), controlEnabled: this.canPlayNextTtsChapter(), accessibilityLabel: '下一章', textColor: this.getTextColor(), subTextColor: this.getSubTextColor() })
      }
      .layoutWeight(1)
      .onClick(() => this.handleTtsExpandedControl(3))

      Stack() {
        ReaderTtsMediaSpeedControl({ speedText: `${this.ttsSpeed.toFixed(1)}x`, textColor: this.getTextColor() })
      }
      .layoutWeight(1)
      .onClick(() => this.handleTtsExpandedControl(4))

      Stack() {
        ReaderTtsMediaSymbolControl({ icon: $r('sys.symbol.xmark'), controlEnabled: true, accessibilityLabel: '关闭朗读控制', textColor: this.getTextColor(), subTextColor: this.getSubTextColor() })
      }
      .layoutWeight(1)
      .onClick(() => this.handleTtsExpandedControl(5))
    }
    .width(LeafFns.readerTtsExpandedControlWidth())
    .height(56)
    .padding({ left: 4, right: 4 })
    .position({ x: this.readerTtsExpandedControlLeft(), y: '100%' })
    .translate({ y: -(this.readerBottomMenuOverlayHeight() + 66) })
    .borderRadius(28)
    .backgroundColor(this.readerGlassPanelColor())
    .backdropBlur(22)
    .border({ width: 1, color: this.readerGlassBorderColor() })
    .shadow({ radius: 10, color: this.readerGlassShadowColor(), offsetX: 0, offsetY: 3 })
  }


  handleTtsExpandedControl(index: number): void {
    ReaderGestureOps.handleTtsExpandedControl(this, index);
  }

  cycleTtsSleepTimer(): void {
    ReaderGestureOps.cycleTtsSleepTimer(this);
  }

  setTtsSleepTimer(minutes: number): void {
    ReaderGestureOps.setTtsSleepTimer(this, minutes);
  }

  clearTtsSleepTimer(): void {
    ReaderGestureOps.clearTtsSleepTimer(this);
  }

  cycleTtsSpeed(): void {
    ReaderGestureOps.cycleTtsSpeed(this);
  }

  shouldShowTtsMediaControls(): boolean {
    return ReaderGestureOps.shouldShowTtsMediaControls(this);
  }

  canPlayPreviousTtsChapter(): boolean {
    return ReaderGestureOps.canPlayPreviousTtsChapter(this);
  }

  canPlayNextTtsChapter(): boolean {
    return ReaderGestureOps.canPlayNextTtsChapter(this);
  }

  disabledButtonColor(): string {
    return ReaderGestureOps.disabledButtonColor(this);
  }

  canHandleReaderPageTurnPan(): boolean {
    return ReaderGestureOps.canHandleReaderPageTurnPan(this);
  }

  handleReaderPagedContentClick(event: ClickEvent): void {
    ReaderGestureOps.handleReaderPagedContentClick(this, event);
  }

  handleReaderPanStart(event: GestureEvent): void {
    ReaderGestureOps.handleReaderPanStart(this, event);
  }

  canHandleBookmarkPull(offsetX: number, offsetY: number): boolean {
    return ReaderGestureOps.canHandleBookmarkPull(this, offsetX, offsetY);
  }

  bookmarkPullCommitDistance(): number {
    return ReaderGestureOps.bookmarkPullCommitDistance(this);
  }

  canCommitBookmarkPull(offsetX: number, offsetY: number): boolean {
    return ReaderGestureOps.canCommitBookmarkPull(this, offsetX, offsetY);
  }

  updateBookmarkPullEffect(offsetX: number, offsetY: number): void {
    ReaderGestureOps.updateBookmarkPullEffect(this, offsetX, offsetY);
  }

  finishBookmarkPull(commit: boolean): void {
    ReaderGestureOps.finishBookmarkPull(this, commit);
  }

  handleReaderPanUpdate(event: GestureEvent): void {
    ReaderGestureOps.handleReaderPanUpdate(this, event);
  }

  handleReaderPanEnd(event: GestureEvent): void {
    ReaderGestureOps.handleReaderPanEnd(this, event);
  }

  handleReaderPanCancel(): void {
    ReaderGestureOps.handleReaderPanCancel(this);
  }

  handleReaderTouch(event: TouchEvent): void {
    ReaderGestureOps.handleReaderTouch(this, event);
  }

  async jumpToReaderPositionKeepingTts(targetChapterIndex: number, targetPageIndex: number): Promise<void> {
    return ReaderGestureOps.jumpToReaderPositionKeepingTts(this, targetChapterIndex, targetPageIndex);
  }

  updateReaderMenuAnchorByPoint(x: number): void {
    ReaderGestureOps.updateReaderMenuAnchorByPoint(this, x);
  }

  finishReaderHorizontalTouch(canCommitTap: boolean = true): void {
    ReaderGestureOps.finishReaderHorizontalTouch(this, canCommitTap);
  }

  commitReaderTapByPoint(x: number, y: number): boolean {
    return ReaderGestureOps.commitReaderTapByPoint(this, x, y);
  }
//endregion
//region 点击区域 / 设置面板 / 音色下拉 / 主题自定义 / 交互·眼动·预载设置
// [map] 契约: 写 各类设置项持久化; 修改后触发重排 / 重载 / 重新分页

  getTapZoneIndex(x: number, y: number, width: number, height: number): number {
    return ReaderSettingsOps.getTapZoneIndex(this, x, y, width, height);
  }

  commitReaderTapZone(index: number): boolean {
    return ReaderSettingsOps.commitReaderTapZone(this, index);
  }

  commitReaderTapAction(action: number): boolean {
    return ReaderSettingsOps.commitReaderTapAction(this, action);
  }

  readerTapZoneActionsList(): number[] {
    return ReaderSettingsOps.readerTapZoneActionsList(this);
  }

  readerTapZoneActionAt(index: number): number {
    return ReaderSettingsOps.readerTapZoneActionAt(this, index);
  }

  cycleTapZoneAction(index: number): void {
    ReaderSettingsOps.cycleTapZoneAction(this, index);
  }

  setTapZoneActions(actions: string): void {
    ReaderSettingsOps.setTapZoneActions(this, actions);
  }




  tapZoneSummaryText(): string {
    return ReaderSettingsOps.tapZoneSummaryText(this);
  }

  isReaderTouchMoved(offsetX: number, offsetY: number): boolean {
    return ReaderSettingsOps.isReaderTouchMoved(this, offsetX, offsetY);
  }

  /**
   * Dismisses a live text selection without performing the action the tap would otherwise trigger.
   * Every tap path funnels through here before turning a page, opening the menu or firing a tap zone,
   * so consuming the click here is enough to cancel the selection. Drag events are never touched, which
   * keeps the native selection handles working.
   */
  consumeSuppressedReaderTapClick(): boolean {
    return ReaderSettingsOps.consumeSuppressedReaderTapClick(this);
  }

  getReaderPageTurnGestureOffset(offsetX: number, offsetY: number): number {
    return ReaderSettingsOps.getReaderPageTurnGestureOffset(this, offsetX, offsetY);
  }

  // 拖动达到页面尺寸的一定比例才提交；快速甩动允许用更短的距离提交，但仍需明确位移。
  isPageTurnCommitOffset(axisOffset: number, axisVelocity: number): boolean {
    return ReaderSettingsOps.isPageTurnCommitOffset(this, axisOffset, axisVelocity);
  }

  isReaderPageTurnCommitGesture(offsetX: number, offsetY: number, axisVelocity: number = 0): boolean {
    return ReaderSettingsOps.isReaderPageTurnCommitGesture(this, offsetX, offsetY, axisVelocity);
  }

  commitReaderMove(offsetX: number, offsetY: number, releaseVelocity: number = 0): void {
    ReaderSettingsOps.commitReaderMove(this, offsetX, offsetY, releaseVelocity);
  }

  commitReaderVerticalMove(offsetY: number, releaseVelocity: number = 0): void {
    ReaderSettingsOps.commitReaderVerticalMove(this, offsetY, releaseVelocity);
  }

  commitReaderHorizontalMove(offsetX: number, releaseVelocity: number = 0): void {
    ReaderSettingsOps.commitReaderHorizontalMove(this, offsetX, releaseVelocity);
  }

  @Builder
  settingsPanel() {
    Column({ space: 12 }) {
      Row() {
        Text(this.settingsPanelTitle())
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getTextColor())

        Blank()
          .layoutWeight(1)

        ImmersiveBackButton({
          icon: $r('sys.symbol.xmark'),
          iconOffsetX: 0,
          iconColor: this.readerControlIconColor(),
          darkMode: this.isReaderThemeDark(),
          buttonSize: 40,
          containerWidth: 40,
          containerHeight: 40,
          startInset: 0,
          materialScale: 0.83,
          compactLayout: true,
          accessibilityLabel: '关闭设置',
          onBack: () => this.closeSettingsPanelKeepMenu()
        })
      }
      .width('100%')
      .padding({ right: LeafFns.readerSettingsContentRightPadding() })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column({ space: 14 }) {
          if (this.settingsPanelTab === 0) {
            Column() {
              this.readerQuickSettingsPanel()
            }
            .width('100%')
            .transition(LeafFns.readerSettingsContentTransition(-1))
          } else if (this.settingsPanelTab === 1) {
            Column() {
              this.ttsQuickSettingsPanel()
            }
            .width('100%')
            .transition(LeafFns.readerSettingsContentTransition(1))
          } else {
            Column() {
              this.readerTypographySettingsPanel()
            }
            .width('100%')
            .transition(LeafFns.readerSettingsContentTransition(1))
          }
        }
        .width('100%')
        .padding({ right: LeafFns.readerSettingsContentRightPadding() })
      }
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .scrollBarColor(this.readerPanelScrollBarColor())
    }
    .width(this.readerFloatingBarWidth())
    .height(this.readerSettingsPanelHeight())
    .padding({ left: 20, right: LeafFns.readerSettingsScrollBarRightInset(), top: 16, bottom: 0 })
    .borderRadius(ThemeRuntime.glassCornerRadius(28, 'panel'))
    .clip(true)
    .backgroundColor(this.readerGlassPanelColor())
    .backdropBlur(ThemeRuntime.glassBlur('panel', 22))
    .border({ width: ThemeRuntime.glassBorderWidth('panel'), color: this.readerGlassBorderColor() })
    .shadow({ radius: ThemeRuntime.glassShadowRadius('panel'), color: this.readerGlassShadowColor(), offsetX: ThemeRuntime.glassShadowOffsetX('panel'), offsetY: ThemeRuntime.glassShadowOffsetY('panel') })
    .position({ x: this.readerFloatingBarLeft(), y: '100%' })
    .translate({ y: -(this.readerSettingsPanelHeight() + this.readerFloatingPanelBottomInset()) })
    .transition(LeafFns.readerPanelTransition())
  }

  settingsPanelTitle(): string {
    return ReaderSettingsOps.settingsPanelTitle(this);
  }


  @Builder
  readerTypographySettingsPanel() {
    Column({ space: 4 }) {
      // 正文排版作为面板首项，统一调整字号、字距、行距、段距及四侧边距。
      ReaderTypographyCombinedSettings({
        selection: this.readerTypographySelection,
        selectedLabel: this.readerTypographySelectedLabel(),
        value: this.readerTypographyValue(this.readerTypographySelection),
        minValue: LeafFns.readerTypographyMin(this.readerTypographySelection),
        maxValue: LeafFns.readerTypographyMax(this.readerTypographySelection),
        valueDraft: this.readerTypographyValueDraft,
        inputVisible: this.showReaderTypographyValueInput,
        textColor: this.getTextColor(),
        subTextColor: this.getSubTextColor(),
        accentColor: this.accentColor(),
        iconColor: this.readerControlIconColor(),
        darkMode: this.isReaderThemeDark(),
        panelColor: this.readerSolidPanelColor(),
        onSelect: (index: number): void => {
          this.showReaderTypographyValueInput = false;
          this.readerTypographySelection = Math.max(0, Math.min(index, 7));
        },
        onStep: (delta: number): void => {
          this.stepReaderTypographyValue(this.readerTypographySelection, delta);
        },
        onDraftChange: (value: string): void => {
          this.readerTypographyValueDraft = value.replace(/[^0-9]/g, '').substring(0, 3);
        },
        onSubmit: (): void => {
          this.applyReaderTypographyValueInput();
        },
        onOpenInput: (): void => {
          this.openReaderTypographyValueInput();
        }
      })
      ReaderSelectSettingItem({
        title: '正文对齐方式',
        description: '设置正文段落的水平对齐方式',
        options: LeafFns.readerTextAlignOptions(),
        selected: this.readerTextAlignSelectedIndex(),
        controlId: 'reader_text_align_select',
        textColor: this.getTextColor(),
        subTextColor: this.getSubTextColor(),
        accentColor: this.accentColor(),
        darkMode: this.isReaderThemeDark(),
        panelColor: this.getBackgroundColor(),
        onSelect: (index: number) => {
          this.setReaderTextAlignByIndex(index);
        }
      })
      ReaderHeaderFooterSettingsPanel({
        headerEnabled: this.readerHeaderEnabled,
        headerContentSelected: this.readerHeaderContentSelectedIndex(),
        footerEnabled: this.readerFooterEnabled,
        footerLeftSelected: this.readerFooterLeftSelectedIndex(),
        footerProgressSelected: this.readerFooterProgressSelectedIndex(),
        footerShowProgressBar: this.readerFooterShowProgressBar,
        textColor: this.getTextColor(),
        subTextColor: this.getSubTextColor(),
        switchColor: this.buttonColor(),
        accentColor: this.accentColor(),
        darkMode: this.isReaderThemeDark(),
        panelColor: this.getBackgroundColor(),
        onToggleHeader: (enabled: boolean): void => {
          this.readerHeaderEnabled = enabled;
        },
        onSelectHeaderContent: (index: number): void => {
          const values = LeafFns.readerHeaderContentValues();
          this.readerHeaderContentMode = index >= 0 && index < values.length ? values[index] : 'chapter';
        },
        onToggleFooter: (enabled: boolean): void => {
          this.readerFooterEnabled = enabled;
        },
        onSelectFooterLeft: (index: number): void => {
          const values = LeafFns.readerFooterLeftValues();
          this.readerFooterLeftMode = index >= 0 && index < values.length ? values[index] : 'chapter';
        },
        onSelectFooterProgress: (index: number): void => {
          const values = LeafFns.readerFooterProgressValues();
          this.readerFooterProgressMode = index >= 0 && index < values.length ? values[index] : 'page';
        },
        onToggleFooterProgressBar: (enabled: boolean): void => {
          this.readerFooterShowProgressBar = enabled;
        }
      })
      ReaderFontEntryItem({
        textColor: this.getTextColor(),
        subTextColor: this.getSubTextColor(),
        onOpen: (): void => {
          router.pushUrl({ url: 'pages/ReaderFontSettings' });
        }
      })

      ReaderSwitchSettingItem({ title: '正文扩展至状态栏', description: '开启后正文同时延伸到顶部状态栏和底部系统安全区', isOn: this.readerExtendToStatusBar, onChange: (checked: boolean) => {
          this.setReaderExtendToStatusBar(checked);
        }, textColor: this.getTextColor(), subTextColor: this.getSubTextColor(), switchColor: this.buttonColor() })

      ReaderSwitchSettingItem({ title: '保留段首缩进', description: '章节开头与页首保留原文的全角空格缩进', isOn: this.keepParagraphIndent, onChange: (checked: boolean) => {
          this.setKeepParagraphIndent(checked);
        }, textColor: this.getTextColor(), subTextColor: this.getSubTextColor(), switchColor: this.buttonColor() })

    }
    .width('100%')
  }

  readerTypographySelectedLabel(): string {
    return ReaderSettingsOps.readerTypographySelectedLabel(this);
  }


  readerTextAlignSelectedIndex(): number {
    return ReaderSettingsOps.readerTextAlignSelectedIndex(this);
  }

  setReaderTextAlignByIndex(index: number): void {
    ReaderSettingsOps.setReaderTextAlignByIndex(this, index);
  }



  readerTypographyValue(settingIndex: number): number {
    return ReaderSettingsOps.readerTypographyValue(this, settingIndex);
  }

  openReaderTypographyValueInput(): void {
    ReaderSettingsOps.openReaderTypographyValueInput(this);
  }

  applyReaderTypographyValueInput(): void {
    ReaderSettingsOps.applyReaderTypographyValueInput(this);
  }

  applyReaderTypographyValue(settingIndex: number, value: number): void {
    ReaderSettingsOps.applyReaderTypographyValue(this, settingIndex, value);
  }

  stepReaderTypographyValue(settingIndex: number, delta: number): void {
    ReaderSettingsOps.stepReaderTypographyValue(this, settingIndex, delta);
  }

  syncReaderTypographyDraft(): void {
    ReaderSettingsOps.syncReaderTypographyDraft(this);
  }

  commitReaderTypographyDraft(): void {
    ReaderSettingsOps.commitReaderTypographyDraft(this);
  }

  @Builder
  readerQuickSettingsPanel() {
    Column({ space: 14 }) {
      ReaderReplaceRulesEntryItem({
        textColor: this.getTextColor(),
        subTextColor: this.getSubTextColor(),
        onOpen: (): void => {
          this.returningFromReaderReplaceRules = true;
          router.pushUrl({ url: 'pages/ReaderReplaceRules' });
        },
      })

      ReaderSelectSettingItem({
        title: '翻页方式',
        description: '选择上下滑动、横向滑动或滚动阅读',
        options: LeafFns.pageTurnModeOptions(),
        selected: this.pageTurnModeSelectedIndex(),
        controlId: 'reader_page_turn_mode_select',
        textColor: this.getTextColor(),
        subTextColor: this.getSubTextColor(),
        accentColor: this.accentColor(),
        darkMode: this.isReaderThemeDark(),
        panelColor: this.getBackgroundColor(),
        onSelect: (index: number) => {
          this.switchPageTurnMode(LeafFns.pageTurnModeByIndex(index));
        }
      })

      if (this.readerPageTurnMode === 2) {
        ReaderTapZoneSettingItem({
          summaryText: this.tapZoneSummaryText(),
          textColor: this.getTextColor(),
          subTextColor: this.getSubTextColor(),
          buttonColor: this.buttonColor(),
          onConfigure: (): void => {
            this.presentTapZoneSettings();
          }
        })
      }

      if (this.readerPageTurnMode === 2) {
        ReaderSelectSettingItem({
        title: '翻页动画',
        description: '选择翻页时使用的页面切换效果',
        options: this.pageTurnAnimationOptions(),
        selected: this.pageTurnAnimationSelectedIndex(),
        controlId: 'reader_page_turn_animation_select_horizontal',
        textColor: this.getTextColor(),
        subTextColor: this.getSubTextColor(),
        accentColor: this.accentColor(),
        darkMode: this.isReaderThemeDark(),
        panelColor: this.getBackgroundColor(),
        onSelect: (index: number) => {
            this.setReaderPageTurnAnimationType(index);
          }
      })
      } else if (this.readerPageTurnMode === 0) {
        ReaderSelectSettingItem({
        title: '翻页动画',
        description: '选择翻页时使用的页面切换效果',
        options: this.pageTurnAnimationOptions(),
        selected: this.pageTurnAnimationSelectedIndex(),
        controlId: 'reader_page_turn_animation_select_vertical',
        textColor: this.getTextColor(),
        subTextColor: this.getSubTextColor(),
        accentColor: this.accentColor(),
        darkMode: this.isReaderThemeDark(),
        panelColor: this.getBackgroundColor(),
        onSelect: (index: number) => {
            this.setReaderPageTurnAnimationType(index);
          }
      })
      }

      ReaderSwitchSettingItem({ title: '使用双翻页', description: '横屏或折叠屏展开等宽屏状态下同时显示左右两页', isOn: this.readerLandscapeDoublePage, onChange: (checked: boolean) => {
          this.setReaderLandscapeDoublePage(checked);
        }, textColor: this.getTextColor(), subTextColor: this.getSubTextColor(), switchColor: this.buttonColor() })

      ReaderSelectSettingItem({
        title: '屏幕方向',
        description: '设置正文阅读时使用的屏幕方向',
        options: LeafFns.screenOrientationOptions(),
        selected: this.screenOrientationSelectedIndex(),
        controlId: 'reader_screen_orientation_select',
        textColor: this.getTextColor(),
        subTextColor: this.getSubTextColor(),
        accentColor: this.accentColor(),
        darkMode: this.isReaderThemeDark(),
        panelColor: this.getBackgroundColor(),
        onSelect: (index: number) => {
          this.setReaderScreenOrientationByIndex(index);
        }
      })

      ReaderSwitchSettingItem({ title: '音量键翻页', description: '阅读页获得焦点时使用音量上/下键翻页', isOn: this.readerVolumeTurnPage, onChange: (checked: boolean) => {
          this.setReaderVolumeTurnPage(checked);
        }, textColor: this.getTextColor(), subTextColor: this.getSubTextColor(), switchColor: this.buttonColor() })

      ReaderSwitchSettingItem({ title: '自动翻页', description: '开启后按设定间隔自动翻到下一页，点击屏幕右下角圆环可暂停或恢复', isOn: this.autoPageTurnActive, onChange: (checked: boolean) => {
          this.setAutoPageTurnActive(checked);
        }, textColor: this.getTextColor(), subTextColor: this.getSubTextColor(), switchColor: this.buttonColor() })

      ReaderAutoPageTurnIntervalSettingItem({
        intervalSec: this.autoPageTurnIntervalSec,
        textColor: this.getTextColor(),
        subTextColor: this.getSubTextColor(),
        fieldColor: this.customThemeFieldColor(),
        onOpen: (): void => {
          this.presentAutoPageTurnIntervalDialog();
        }
      })

      ReaderSwitchSettingItem({ title: '快速添加书签', description: '正文下拉时快速添加或删除当前页书签', isOn: this.readerQuickBookmarkEnabled, onChange: (checked: boolean) => {
          this.setReaderQuickBookmarkEnabled(checked);
        }, textColor: this.getTextColor(), subTextColor: this.getSubTextColor(), switchColor: this.buttonColor() })

      ReaderSwitchSettingItem({ title: '眼动翻页（beta）', description: '视线到达正文底部后提示向上看，向上看即翻到下一页；图像仅在设备本地处理', isOn: this.readerEyeTurnEnabled, onChange: (checked: boolean) => {
          this.setReaderEyeTurnEnabled(checked);
        }, textColor: this.getTextColor(), subTextColor: this.getSubTextColor(), switchColor: this.buttonColor() })

      if (this.readerEyeTurnEnabled) {
        ReaderEyeCalibrationSettingItem({
        textColor: this.getTextColor(),
        subTextColor: this.getSubTextColor(),
        accentColor: this.accentColor(),
        autoCalibrated: this.arEngineFaceActive,
        landscape: this.isReaderEyeLandscape(),
        statusText: this.readerEyeTurnStatus,
        calibrated: !!this.currentReaderEyeCalibrationRaw(),
        onConfigure: (): void => this.openReaderEyeCalibration()
      })
      }

      ReaderSelectSettingItem({
        title: '亮屏时间设置',
        description: '无操作达到所选时长后恢复系统息屏',
        options: LeafFns.screenTimeoutOptions(),
        selected: this.screenTimeoutSelectedIndex(),
        controlId: 'reader_screen_timeout_select',
        textColor: this.getTextColor(),
        subTextColor: this.getSubTextColor(),
        accentColor: this.accentColor(),
        darkMode: this.isReaderThemeDark(),
        panelColor: this.getBackgroundColor(),
        onSelect: (index: number) => {
          this.setReaderScreenTimeoutByIndex(index);
        }
      })

      Row({ space: 10 }) {
        ForEach(this.currentReaderThemes(), (theme: ReaderThemeItem, index: number) => {
          Text(index === ReaderThemeHelper.CUSTOM_THEME_INDEX ? '自' :
            (index === ReaderThemeHelper.APP_THEME_INDEX ? '主' : ''))
            .width(42)
            .height(42)
            .borderRadius(21)
            .fontSize(13)
            .fontColor(theme.textColor)
            .textAlign(TextAlign.Center)
            .backgroundColor(theme.backgroundColor)
            .backgroundImage(theme.backgroundImageUri || '', ImageRepeat.NoRepeat)
            .backgroundImageSize(ImageSize.Cover)
            .border({
              width: this.currentReaderThemeIndex() === index ? 3 : 1,
              color: this.currentReaderThemeIndex() === index ? this.accentColor() : '#22000000'
            })
            .onClick(() => {
              this.applyReaderThemeIndex(index);
            })
        })
      }
      .width('100%')

      if (this.currentReaderThemeIndex() === ReaderThemeHelper.CUSTOM_THEME_INDEX) {
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            Select(this.customThemeOptions())
              .selected(this.currentCustomThemeSelectedIndex())
              .value(this.currentCustomThemeScheme().name)
              .font({ size: 14 })
              .fontColor(this.getTextColor())
              .backgroundColor(this.customThemeFieldColor())
              .borderRadius(16)
              .border({ width: 0 })
              .layoutWeight(1)
              .divider(null)
              .optionBgColor(Color.Transparent)
              .optionFontColor(this.getTextColor())
              .selectedOptionFontColor(this.accentColor())
              .selectedOptionBgColor(ThemeRuntime.accentSurfaceColor(this.isReaderThemeDark()))
              .menuBackgroundColor(ThemeRuntime.dropdownPanelColor(this.isReaderThemeDark(), this.getBackgroundColor()))
              .menuBackgroundBlurStyle(BlurStyle.NONE)
              .attributeModifier(new SelectMenuMaterialModifier())
              .onSelect((index: number) => {
                this.selectCustomTheme(index);
              })
            Button('新增')
              .height(36)
              .fontSize(13)
              .backgroundColor(this.accentColor())
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.addCustomTheme();
              })
            Button('删除')
              .height(36)
              .fontSize(13)
              .backgroundColor(this.customThemeFieldColor())
              .fontColor(this.getTextColor())
              .onClick(() => {
                this.openReaderCustomThemeDeleteConfirm();
              })
          }
          .width('100%')
          TextInput({ text: this.customThemeNameDraft, placeholder: '输入方案名称' })
            .fontSize(14)
            .fontColor(this.getTextColor())
            .height(36)
            .padding({ left: 10, right: 10 })
            .backgroundColor(this.customThemeFieldColor())
            .borderRadius(8)
            .onChange((value: string) => {
              this.customThemeNameDraft = value.substring(0, 20);
            })
            .onSubmit(() => {
              this.renameCurrentCustomTheme(this.customThemeNameDraft);
            })
            .onBlur(() => {
              this.renameCurrentCustomTheme(this.customThemeNameDraft);
            })
          Row() {
            Text('背景设置')
              .fontSize(14)
              .fontColor(this.getTextColor())
            Blank()
            Select([{ value: '背景色' }, { value: '背景图片' }])
              .selected(this.currentCustomThemeBackgroundTypeIndex())
              .value(this.currentCustomThemeBackgroundTypeIndex() === 1 ? '背景图片' : '背景色')
              .font({ size: 14 })
              .fontColor(this.getTextColor())
              .backgroundColor(this.customThemeFieldColor())
              .borderRadius(16)
              .border({ width: 0 })
              .optionBgColor(Color.Transparent)
              .divider(null)
              .optionFontColor(this.getTextColor())
              .selectedOptionFontColor(this.accentColor())
              .selectedOptionBgColor(ThemeRuntime.accentSurfaceColor(this.isReaderThemeDark()))
              .menuBackgroundColor(ThemeRuntime.dropdownPanelColor(this.isReaderThemeDark(), this.getBackgroundColor()))
              .menuBackgroundBlurStyle(BlurStyle.NONE)
              .attributeModifier(new SelectMenuMaterialModifier())
              .onSelect((index: number) => {
                this.setCurrentCustomThemeBackgroundType(index);
              })
          }
          .width('100%')
          if (this.currentCustomThemeBackgroundTypeIndex() === 0) {
            AdaptiveColorPicker({
              value: this.currentCustomThemeBackgroundColor(),
              placeholder: this.currentCustomThemeBackgroundColor(),
              appDarkMode: this.appDarkMode,
              accentColor: this.accentColor(),
              optionTitle: '背景颜色',
              onColorChange: (value: string) => {
                this.setCurrentThemeBackgroundColor(value);
              }
            })
          } else {
            Row({ space: 8 }) {
              Button(this.currentCustomThemeScheme().backgroundImageUri ? '更换背景图片' : '选择背景图片')
                .height(36)
                .fontSize(13)
                .backgroundColor(this.accentColor())
                .fontColor('#FFFFFF')
                .onClick(() => {
                  this.chooseCurrentCustomThemeImage();
                })
              if (this.currentCustomThemeScheme().backgroundImageUri) {
                Button('移除图片')
                  .height(36)
                  .fontSize(13)
                  .backgroundColor(this.customThemeFieldColor())
                  .fontColor(this.getTextColor())
                  .onClick(() => {
                    this.clearCurrentCustomThemeImage();
                  })
                Select([{ value: '裁剪填充' }, { value: '完整显示' }, { value: '拉伸铺满' }])
                  .selected(this.customThemeFitSelectedIndex())
                  .value(['裁剪填充', '完整显示', '拉伸铺满'][this.customThemeFitSelectedIndex()])
                  .font({ size: 13 })
                  .fontColor(this.getTextColor())
                  .backgroundColor(this.customThemeFieldColor())
                  .borderRadius(16)
                  .border({ width: 0 })
                  .layoutWeight(1)
                  .divider(null)
                  .optionBgColor(Color.Transparent)
                  .optionFontColor(this.getTextColor())
                  .selectedOptionFontColor(this.accentColor())
                  .selectedOptionBgColor(ThemeRuntime.accentSurfaceColor(this.isReaderThemeDark()))
                  .menuBackgroundColor(ThemeRuntime.dropdownPanelColor(this.isReaderThemeDark(), this.getBackgroundColor()))
                  .menuBackgroundBlurStyle(BlurStyle.NONE)
                  .attributeModifier(new SelectMenuMaterialModifier())
                  .onSelect((index: number) => {
                    this.setCurrentCustomThemeImageFit(index);
                  })
              }
            }
            .width('100%')
          }
          AdaptiveColorPicker({
            value: this.currentCustomThemeTextColor(),
            placeholder: this.currentCustomThemeTextColor(),
            appDarkMode: this.appDarkMode,
            accentColor: this.accentColor(),
            optionTitle: '文字颜色',
            onColorChange: (value: string) => {
              this.setCurrentThemeTextColor(value);
            }
          })
        }
        .width('100%')
      }

      ReaderPreloadSettingItem({
        preloadEnabled: this.readerPreloadEnabled,
        preloadChapterCount: this.readerPreloadChapterCount,
        textColor: this.getTextColor(),
        subTextColor: this.getSubTextColor(),
        accentColor: this.accentColor(),
        switchColor: this.buttonColor(),
        darkMode: this.isReaderThemeDark(),
        panelColor: this.getBackgroundColor(),
        onToggleEnabled: (value: boolean): void => {
          this.setReaderPreloadEnabled(value);
        },
        onSelectChapterCount: (count: number): void => {
          this.setReaderPreloadChapterCount(count);
        }
      })
    }
    .width('100%')
  }

  @Builder
  ttsQuickSettingsPanel() {
    Column({ space: 14 }) {
      Row() {
        Text('朗读倍速')
          .fontSize(15)
          .fontColor(this.getTextColor())
          .layoutWeight(1)
        Text(`${this.ttsSpeed.toFixed(1)}x`)
          .fontSize(14)
          .fontColor(this.getSubTextColor())
      }
      .width('100%')

      Row({ space: 10 }) {
        ReaderSliderStepButton({
        icon: $r('sys.symbol.minus'),
        accessibilityLabel: '降低朗读倍速',
        controlEnabled: this.ttsSpeed > 0.5,
        action: () => {
          this.applyTtsSpeed(this.ttsSpeed - 0.1);
        },
        iconColor: this.readerControlIconColor(),
        disabledIconColor: this.getSubTextColor(),
        darkMode: this.isReaderThemeDark(),
      })
      Slider({ value: this.ttsSpeed, min: 0.5, max: 3, step: 0.1 })
        .layoutWeight(1)
        .showTips(true)
          .selectedColor(this.accentColor())
        .sliderInteractionMode(ImmersiveMaterialRuntime.supportsHds() ?
          SliderInteraction.SLIDE_AND_CLICK_UP : SliderInteraction.SLIDE_ONLY)
          .onChange((value: number) => {
            this.applyTtsSpeed(value);
          })
        ReaderSliderStepButton({
        icon: $r('sys.symbol.plus'),
        accessibilityLabel: '提高朗读倍速',
        controlEnabled: this.ttsSpeed < 3,
        action: () => {
          this.applyTtsSpeed(this.ttsSpeed + 0.1);
        },
        iconColor: this.readerControlIconColor(),
        disabledIconColor: this.getSubTextColor(),
        darkMode: this.isReaderThemeDark(),
      })
      }
      .width('100%')

      Row({ space: 8 }) {
        ReaderTtsSpeedChip({
        value: 0.8,
        selected: Math.abs(this.ttsSpeed - 0.8) < 0.01,
        textColor: this.getTextColor(),
        accentColor: this.accentColor(),
        idleColor: this.readerChipIdleColor(),
        onSelect: (): void => {
          this.applyTtsSpeed(0.8);
        }
      })
        ReaderTtsSpeedChip({
        value: 1.0,
        selected: Math.abs(this.ttsSpeed - 1.0) < 0.01,
        textColor: this.getTextColor(),
        accentColor: this.accentColor(),
        idleColor: this.readerChipIdleColor(),
        onSelect: (): void => {
          this.applyTtsSpeed(1.0);
        }
      })
        ReaderTtsSpeedChip({
        value: 1.5,
        selected: Math.abs(this.ttsSpeed - 1.5) < 0.01,
        textColor: this.getTextColor(),
        accentColor: this.accentColor(),
        idleColor: this.readerChipIdleColor(),
        onSelect: (): void => {
          this.applyTtsSpeed(1.5);
        }
      })
        ReaderTtsSpeedChip({
        value: 2.0,
        selected: Math.abs(this.ttsSpeed - 2.0) < 0.01,
        textColor: this.getTextColor(),
        accentColor: this.accentColor(),
        idleColor: this.readerChipIdleColor(),
        onSelect: (): void => {
          this.applyTtsSpeed(2.0);
        }
      })
        ReaderTtsSpeedChip({
        value: 3.0,
        selected: Math.abs(this.ttsSpeed - 3.0) < 0.01,
        textColor: this.getTextColor(),
        accentColor: this.accentColor(),
        idleColor: this.readerChipIdleColor(),
        onSelect: (): void => {
          this.applyTtsSpeed(3.0);
        }
      })
      }
      .width('100%')

      Row() {
        Text('朗读音色')
          .fontSize(15)
          .fontColor(this.getTextColor())
          .layoutWeight(1)
        if (this.ttsVoicesLoading) {
          Text('加载中')
            .fontSize(12)
            .fontColor(this.getSubTextColor())
        }
      }
      .width('100%')

      Row() {
        Text(this.selectedTtsVoiceTitle())
          .fontSize(14)
          .fontColor(this.getTextColor())
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        SymbolGlyph($r('sys.symbol.chevron_down'))
          .fontSize(16)
          .fontColor([this.getSubTextColor()])
          .margin({ left: 10 })
      }
        .width('100%')
        .height(44)
        .padding({ left: 14, right: 14 })
        .backgroundColor(this.readerChipIdleColor())
        .borderRadius(8)
        .onClick(() => {
          this.showTtsVoiceDropdown = true;
        })

      Row() {
        Text('朗读定时')
          .fontSize(15)
          .fontColor(this.getTextColor())
          .layoutWeight(1)
        Text(this.ttsSleepTimerMinutes > 0 ?
          `剩余 ${Math.max(1, Math.ceil(this.ttsSleepTimerRemainingSeconds / 60))} 分钟` : '未设置')
          .fontSize(12)
          .fontColor(this.getSubTextColor())
      }
      .width('100%')

      Row({ space: 8 }) {
        ReaderTtsSleepTimerChip({
        minutes: 15,
        selected: this.ttsSleepTimerMinutes === 15,
        textColor: this.getTextColor(),
        accentColor: this.accentColor(),
        idleColor: this.readerChipIdleColor(),
        onToggle: (): void => {
          this.setTtsSleepTimer(this.ttsSleepTimerMinutes === 15 ? 0 : 15);
        }
      })
        ReaderTtsSleepTimerChip({
        minutes: 30,
        selected: this.ttsSleepTimerMinutes === 30,
        textColor: this.getTextColor(),
        accentColor: this.accentColor(),
        idleColor: this.readerChipIdleColor(),
        onToggle: (): void => {
          this.setTtsSleepTimer(this.ttsSleepTimerMinutes === 30 ? 0 : 30);
        }
      })
        ReaderTtsSleepTimerChip({
        minutes: 60,
        selected: this.ttsSleepTimerMinutes === 60,
        textColor: this.getTextColor(),
        accentColor: this.accentColor(),
        idleColor: this.readerChipIdleColor(),
        onToggle: (): void => {
          this.setTtsSleepTimer(this.ttsSleepTimerMinutes === 60 ? 0 : 60);
        }
      })
        ReaderTtsSleepTimerChip({
        minutes: 90,
        selected: this.ttsSleepTimerMinutes === 90,
        textColor: this.getTextColor(),
        accentColor: this.accentColor(),
        idleColor: this.readerChipIdleColor(),
        onToggle: (): void => {
          this.setTtsSleepTimer(this.ttsSleepTimerMinutes === 90 ? 0 : 90);
        }
      })
        ReaderTtsSleepTimerChip({
        minutes: 120,
        selected: this.ttsSleepTimerMinutes === 120,
        textColor: this.getTextColor(),
        accentColor: this.accentColor(),
        idleColor: this.readerChipIdleColor(),
        onToggle: (): void => {
          this.setTtsSleepTimer(this.ttsSleepTimerMinutes === 120 ? 0 : 120);
        }
      })
      }
      .width('100%')

      Button(this.isTtsSpeaking ? '停止朗读' : '开始朗读')
        .width('100%')
        .height(40)
        .backgroundColor(this.isTtsSpeaking ? this.dangerColor() : this.buttonColor())
        .fontColor('#FFFFFF')
        .onClick(() => {
          this.toggleTtsReading();
        })
    }
    .width('100%')
  }


  pageTurnModeSelectedIndex(): number {
    return ReaderSettingsOps.pageTurnModeSelectedIndex(this);
  }

  pageTurnAnimationOptions(): SelectOption[] {
    return ReaderSettingsOps.pageTurnAnimationOptions(this);
  }

  pageTurnAnimationTypes(): number[] {
    return ReaderSettingsOps.pageTurnAnimationTypes(this);
  }

  pageTurnAnimationSelectedIndex(): number {
    return ReaderSettingsOps.pageTurnAnimationSelectedIndex(this);
  }

  pageTurnAnimationValue(): string {
    return ReaderSettingsOps.pageTurnAnimationValue(this);
  }


  screenTimeoutSelectedIndex(): number {
    return ReaderSettingsOps.screenTimeoutSelectedIndex(this);
  }


  screenOrientationSelectedIndex(): number {
    return ReaderSettingsOps.screenOrientationSelectedIndex(this);
  }



  readerEyeTurnPromptVisible(): boolean {
    return ReaderSettingsOps.readerEyeTurnPromptVisible(this);
  }

  readerEyeTurnPromptTop(): number {
    return ReaderSettingsOps.readerEyeTurnPromptTop(this);
  }

  readerEyeCalibrationTargetTopVp(): number {
    return ReaderSettingsOps.readerEyeCalibrationTargetTopVp(this);
  }

  readerEyeCalibrationPreviewWidthVp(): number {
    return ReaderSettingsOps.readerEyeCalibrationPreviewWidthVp(this);
  }

  readerEyeCalibrationPreviewHeightVp(): number {
    return ReaderSettingsOps.readerEyeCalibrationPreviewHeightVp(this);
  }

  readerEyeCalibrationPreviewLeftVp(): number {
    return ReaderSettingsOps.readerEyeCalibrationPreviewLeftVp(this);
  }


  readerEyeCalibrationPreviewHint(): string {
    return ReaderSettingsOps.readerEyeCalibrationPreviewHint(this);
  }

  readerEyeCalibrationInstruction(): string {
    return ReaderSettingsOps.readerEyeCalibrationInstruction(this);
  }

  switchPageTurnMode(mode: number) {
    ReaderSettingsOps.switchPageTurnMode(this, mode);
  }

  setReaderPageTurnAnimationType(index: number): void {
    ReaderSettingsOps.setReaderPageTurnAnimationType(this, index);
  }

  normalizePageTurnAnimationType(type: number): number {
    return ReaderSettingsOps.normalizePageTurnAnimationType(this, type);
  }

  isPageTurnAnimationEnabled(): boolean {
    return ReaderSettingsOps.isPageTurnAnimationEnabled(this);
  }

  saveReaderLayoutSettings(): void {
    ReaderSettingsOps.saveReaderLayoutSettings(this);
  }

  setReaderLandscapeDoublePage(enabled: boolean): void {
    ReaderSettingsOps.setReaderLandscapeDoublePage(this, enabled);
  }

  setReaderScreenOrientationByIndex(index: number): void {
    ReaderSettingsOps.setReaderScreenOrientationByIndex(this, index);
  }

  applyReaderThemeIndex(index: number): void {
    ReaderSettingsOps.applyReaderThemeIndex(this, index);
  }

  saveReaderThemeSettings(): void {
    ReaderSettingsOps.saveReaderThemeSettings(this);
  }

  setCurrentThemeBackgroundColor(color: string): void {
    ReaderSettingsOps.setCurrentThemeBackgroundColor(this, color);
  }

  setCurrentThemeTextColor(color: string): void {
    ReaderSettingsOps.setCurrentThemeTextColor(this, color);
  }

  persistCustomThemeData(data: ReaderCustomThemeData): void {
    ReaderSettingsOps.persistCustomThemeData(this, data);
  }

  addCustomTheme(): void {
    ReaderSettingsOps.addCustomTheme(this);
  }

  openReaderCustomThemeDeleteConfirm(): void {
    this.showReaderCustomThemeDeleteConfirm = true;
    this.readerCustomThemeDeleteDialogSession.open(this.getUIContext(), (): void => {
      ReaderCustomThemeDeleteConfirm({
          textColor: this.getTextColor(),
          subTextColor: this.getSubTextColor(),
          dangerColor: this.dangerColor(),
          chipIdleColor: this.readerChipIdleColor(),
          themeName: this.currentCustomThemeScheme().name,
          onCancel: (): void => this.closeReaderCustomThemeDeleteConfirm(),
          onDelete: (): void => {
            this.closeReaderCustomThemeDeleteConfirm();
            this.deleteCurrentCustomTheme();
          }
        });
    }, {
      autoCancel: false,
      maskColor: this.isReaderThemeDark() ? '#99000000' : '#33000000',
      warnTag: '显示删除自定义主题确认弹窗失败:'
    });
  }

  closeReaderCustomThemeDeleteConfirm(): void {
    ReaderSettingsOps.closeReaderCustomThemeDeleteConfirm(this);
  }

  deleteCurrentCustomTheme(): void {
    ReaderSettingsOps.deleteCurrentCustomTheme(this);
  }

  selectCustomTheme(index: number): void {
    ReaderSettingsOps.selectCustomTheme(this, index);
  }

  renameCurrentCustomTheme(name: string): void {
    ReaderSettingsOps.renameCurrentCustomTheme(this, name);
  }

  async chooseCurrentCustomThemeImage(): Promise<void> {
    return ReaderSettingsOps.chooseCurrentCustomThemeImage(this);
  }

  clearCurrentCustomThemeImage(): void {
    ReaderSettingsOps.clearCurrentCustomThemeImage(this);
  }

  setCurrentCustomThemeBackgroundType(index: number): void {
    ReaderSettingsOps.setCurrentCustomThemeBackgroundType(this, index);
  }

  setCurrentCustomThemeImageFit(index: number): void {
    ReaderSettingsOps.setCurrentCustomThemeImageFit(this, index);
  }

  saveReaderInteractionSettings(): void {
    ReaderSettingsOps.saveReaderInteractionSettings(this);
  }

  setReaderVolumeTurnPage(enabled: boolean): void {
    ReaderSettingsOps.setReaderVolumeTurnPage(this, enabled);
  }

  setReaderEyeTurnEnabled(enabled: boolean): void {
    ReaderSettingsOps.setReaderEyeTurnEnabled(this, enabled);
  }

  saveReaderEyeTurnSettings(): void {
    ReaderSettingsOps.saveReaderEyeTurnSettings(this);
  }

  setReaderEyeTurnDirectionEnabled(previous: boolean, enabled: boolean): void {
    ReaderSettingsOps.setReaderEyeTurnDirectionEnabled(this, previous, enabled);
  }


  setReaderEyeDwell(previous: boolean, index: number): void {
    ReaderSettingsOps.setReaderEyeDwell(this, previous, index);
  }

  isReaderEyeLandscape(): boolean {
    return ReaderSettingsOps.isReaderEyeLandscape(this);
  }

  currentReaderEyeCalibrationRaw(): string {
    return ReaderSettingsOps.currentReaderEyeCalibrationRaw(this);
  }

  configureReaderEyeTurnController(): void {
    ReaderSettingsOps.configureReaderEyeTurnController(this);
  }

  startReaderEyeTurnIfReady(): void {
    ReaderSettingsOps.startReaderEyeTurnIfReady(this);
  }

  /**
   * Prefers AR Engine for gaze signals and only falls back to the camera
   * pipeline when the kit is unavailable on this device.
   */
  startArEyeTurnHostIfAvailable(): void {
    ReaderSettingsOps.startArEyeTurnHostIfAvailable(this);
  }

  startReaderEyeTurnCamera(): void {
    ReaderSettingsOps.startReaderEyeTurnCamera(this);
  }

  /** True when either AR Engine or the camera pipeline is producing gaze samples. */
  readerEyeTurnSignalReady(): boolean {
    return ReaderSettingsOps.readerEyeTurnSignalReady(this);
  }

  stopArEyeTurnHost(): void {
    ReaderSettingsOps.stopArEyeTurnHost(this);
  }

  refreshReaderEyeTurnForViewport(): void {
    ReaderSettingsOps.refreshReaderEyeTurnForViewport(this);
  }

  readerEyeTurnCanTrigger(): boolean {
    return ReaderSettingsOps.readerEyeTurnCanTrigger(this);
  }

  /** Which condition currently blocks an eye-turn, for diagnostics only. */
  readerEyeTurnBlockReason(): string {
    return ReaderSettingsOps.readerEyeTurnBlockReason(this);
  }

  openReaderEyeCalibration(): void {
    ReaderSettingsOps.openReaderEyeCalibration(this);
  }

  beginReaderEyeCalibrationCapture(): void {
    ReaderSettingsOps.beginReaderEyeCalibrationCapture(this);
  }

  /** Starts the 1.5s sampling window for the current fixation (the reader taps to advance). */
  startReaderEyeCalibrationPhaseSampling(): void {
    ReaderSettingsOps.startReaderEyeCalibrationPhaseSampling(this);
  }

  currentReaderEyeCalibrationTargetLabel(): string {
    return ReaderSettingsOps.currentReaderEyeCalibrationTargetLabel(this);
  }

  consumeReaderEyeCalibrationSample(sample: EyeTurnSample): void {
    ReaderSettingsOps.consumeReaderEyeCalibrationSample(this, sample);
  }

  scheduleReaderEyeCalibrationTick(delayMs: number = READER_EYE_CALIBRATION_TICK_MS): void {
    ReaderSettingsOps.scheduleReaderEyeCalibrationTick(this, delayMs);
  }

  updateReaderEyeCalibrationSequence(): void {
    ReaderSettingsOps.updateReaderEyeCalibrationSequence(this);
  }

  /** Median absolute deviation: a robust spread used to reject an unsteady fixation. */
  /**
   * Builds the calibration from the three held fixations: centre, bottom zone, top zone.
   * The sign of the deltas comes straight from the measurements, so the gesture direction
   * can no longer be guessed wrong.
   */
  finishReaderEyeCalibrationFromFixation(): void {
    ReaderSettingsOps.finishReaderEyeCalibrationFromFixation(this);
  }

  failReaderEyeCalibration(message: string): void {
    ReaderSettingsOps.failReaderEyeCalibration(this, message);
  }

  abortReaderEyeCalibrationAttempt(message: string): void {
    ReaderSettingsOps.abortReaderEyeCalibrationAttempt(this, message);
  }

  clearReaderEyeCalibrationTimer(): void {
    ReaderSettingsOps.clearReaderEyeCalibrationTimer(this);
  }

  cancelReaderEyeCalibration(): void {
    ReaderSettingsOps.cancelReaderEyeCalibration(this);
  }

  setReaderScreenTimeoutByIndex(index: number): void {
    ReaderSettingsOps.setReaderScreenTimeoutByIndex(this, index);
  }

  setReaderExtendToStatusBar(enabled: boolean): void {
    ReaderSettingsOps.setReaderExtendToStatusBar(this, enabled);
  }

  setKeepParagraphIndent(enabled: boolean): void {
    ReaderSettingsOps.setKeepParagraphIndent(this, enabled);
  }

  setReaderPreloadEnabled(enabled: boolean): void {
    ReaderSettingsOps.setReaderPreloadEnabled(this, enabled);
  }

  setReaderPreloadChapterCount(count: number): void {
    ReaderSettingsOps.setReaderPreloadChapterCount(this, count);
  }

  setReaderQuickBookmarkEnabled(enabled: boolean): void {
    ReaderSettingsOps.setReaderQuickBookmarkEnabled(this, enabled);
  }
//endregion
//region TTS 浮标会话 / 朗读编排(起播·续播·换章·看门狗) / 后台委托 / 封面 / 高亮清理
// [map] 契约: 核心长链路: ttsReadToken / ttsFocusGeneration / ttsChapterSwitching; 与浮标会话、AVSession 双向同步

  publishTtsFloatingSession(): void {
    ReaderTtsOrchestrationOps.publishTtsFloatingSession(this);
  }

  publishTtsFloatingVoices(): void {
    ReaderTtsOrchestrationOps.publishTtsFloatingVoices(this);
  }

  updateTtsFloatingSession(): void {
    ReaderTtsOrchestrationOps.updateTtsFloatingSession(this);
  }

  stopTtsFloatingSession(): void {
    ReaderTtsOrchestrationOps.stopTtsFloatingSession(this);
  }

  async toggleTtsReading(): Promise<void> {
    return ReaderTtsOrchestrationOps.toggleTtsReading(this);
  }

  setTtsPagedScrollOverride(enabled: boolean): void {
    ReaderTtsOrchestrationOps.setTtsPagedScrollOverride(this, enabled);
  }

  async startTtsReadingFromCurrentPosition(showToast: boolean,
    manualPageTurnResume: boolean = false, manualPageTurnResumeSerial: number = -1,
    readingStartOffset: number = -1, preserveExistingFocus: boolean = false): Promise<void> {
    return ReaderTtsOrchestrationOps.startTtsReadingFromCurrentPosition(this, showToast, manualPageTurnResume, manualPageTurnResumeSerial, readingStartOffset, preserveExistingFocus);
  }

  /** Return the last source position that can belong to an audible TTS chunk. */

  stopTtsReading(userCancelled: boolean = true): void {
    ReaderTtsOrchestrationOps.stopTtsReading(this, userCancelled);
  }

  stopTtsReaderForChapterSwitch(): void {
    ReaderTtsOrchestrationOps.stopTtsReaderForChapterSwitch(this);
  }

  clearManualPageTurnTtsResumeTimer(): void {
    ReaderTtsOrchestrationOps.clearManualPageTurnTtsResumeTimer(this);
  }

  cancelManualPageTurnTtsResume(): void {
    ReaderTtsOrchestrationOps.cancelManualPageTurnTtsResume(this);
  }

  deferManualPageTurnTtsResume(): void {
    ReaderTtsOrchestrationOps.deferManualPageTurnTtsResume(this);
  }

  isManualPageTurnTtsResumeCurrent(serial: number): boolean {
    return ReaderTtsOrchestrationOps.isManualPageTurnTtsResumeCurrent(this, serial);
  }

  prepareTtsForManualPageTurn(): void {
    ReaderTtsOrchestrationOps.prepareTtsForManualPageTurn(this);
  }

  scheduleTtsResumeAfterManualPageTurn(attempt: number = 0): void {
    ReaderTtsOrchestrationOps.scheduleTtsResumeAfterManualPageTurn(this, attempt);
  }

  isReaderPageTurnPositionReadyForTts(): boolean {
    return ReaderTtsOrchestrationOps.isReaderPageTurnPositionReadyForTts(this);
  }

  syncTtsStateToVisiblePage(): void {
    ReaderTtsOrchestrationOps.syncTtsStateToVisiblePage(this);
  }

  async continueTtsReading(token: number): Promise<void> {
    return ReaderTtsOrchestrationOps.continueTtsReading(this, token);
  }

  isTtsReadingAtExpectedEnd(): boolean {
    return ReaderTtsOrchestrationOps.isTtsReadingAtExpectedEnd(this);
  }

  // 章末等待主要来自下一章第一段音频的首次合成（自定义音色是一次网络往返）。
  // 当前章只剩最后一两段时，提前按预取文本合成下一章开头音频；章末切换时直接消费缓存结果。
  maybePrefetchTtsNextChapterAudio(): void {
    ReaderTtsOrchestrationOps.maybePrefetchTtsNextChapterAudio(this);
  }

  async prefetchTtsNextChapterAudio(): Promise<void> {
    return ReaderTtsOrchestrationOps.prefetchTtsNextChapterAudio(this);
  }

  armTtsContinuationWatchdog(): void {
    ReaderTtsOrchestrationOps.armTtsContinuationWatchdog(this);
  }

  clearTtsContinuationWatchdog(): void {
    ReaderTtsOrchestrationOps.clearTtsContinuationWatchdog(this);
  }

  async advanceTtsReadingToNextChapter(): Promise<boolean> {
    return ReaderTtsOrchestrationOps.advanceTtsReadingToNextChapter(this);
  }

  finishTtsReading(): void {
    ReaderTtsOrchestrationOps.finishTtsReading(this);
  }

  async loadReaderSettings(): Promise<void> {
    return ReaderTtsOrchestrationOps.loadReaderSettings(this);
  }

  isTtsBackgroundRunning(): boolean {
    return ReaderTtsOrchestrationOps.isTtsBackgroundRunning(this);
  }

  isTtsBackgroundRequesting(): boolean {
    return ReaderTtsOrchestrationOps.isTtsBackgroundRequesting(this);
  }

  hasTtsAvSession(): boolean {
    return ReaderTtsOrchestrationOps.hasTtsAvSession(this);
  }

  async startTtsBackgroundRunning(): Promise<boolean> {
    return ReaderTtsOrchestrationOps.startTtsBackgroundRunning(this);
  }

  async stopTtsBackgroundRunning(): Promise<void> {
    return ReaderTtsOrchestrationOps.stopTtsBackgroundRunning(this);
  }

  onTtsAudioStarted(): void {
    ReaderTtsOrchestrationOps.onTtsAudioStarted(this);
  }

  async updateTtsAvSessionPlaybackState(state: avSession.PlaybackState): Promise<void> {
    return ReaderTtsOrchestrationOps.updateTtsAvSessionPlaybackState(this, state);
  }

  async syncTtsSystemMediaControls(): Promise<void> {
    return ReaderTtsOrchestrationOps.syncTtsSystemMediaControls(this);
  }

  ttsAvPlaybackState(): avSession.PlaybackState {
    return ReaderTtsOrchestrationOps.ttsAvPlaybackState(this);
  }

  async refreshTtsMediaImage(): Promise<void> {
    return ReaderTtsOrchestrationOps.refreshTtsMediaImage(this);
  }

  async playNextChapterFromMediaSession(): Promise<void> {
    return ReaderTtsOrchestrationOps.playNextChapterFromMediaSession(this);
  }

  async playPreviousChapterFromMediaSession(): Promise<void> {
    return ReaderTtsOrchestrationOps.playPreviousChapterFromMediaSession(this);
  }

  // ---- ReaderTtsBackgroundHost 实现：供控制器读写的页面状态访问器 ----

  hostContext(): common.Context {
    return getContext(this);
  }

  getReaderBook(): Book | null {
    return ReaderTtsOrchestrationOps.getReaderBook(this);
  }

  getReaderBookUrl(): string {
    return ReaderTtsOrchestrationOps.getReaderBookUrl(this);
  }

  getCurrentChapterIndex(): number {
    return ReaderTtsOrchestrationOps.getCurrentChapterIndex(this);
  }

  getCurrentPageIndex(): number {
    return ReaderTtsOrchestrationOps.getCurrentPageIndex(this);
  }

  setCurrentPageIndex(value: number): void {
    ReaderTtsOrchestrationOps.setCurrentPageIndex(this, value);
  }

  setPendingRestorePageIndex(value: number): void {
    ReaderTtsOrchestrationOps.setPendingRestorePageIndex(this, value);
  }

  getContentPageCount(): number {
    return ReaderTtsOrchestrationOps.getContentPageCount(this);
  }

  getTtsReader(): SystemTtsReader {
    return ReaderTtsOrchestrationOps.getTtsReader(this);
  }

  isTtsSpeakingState(): boolean {
    return ReaderTtsOrchestrationOps.isTtsSpeakingState(this);
  }

  isTtsPausedState(): boolean {
    return ReaderTtsOrchestrationOps.isTtsPausedState(this);
  }

  getTtsSpeed(): number {
    return ReaderTtsOrchestrationOps.getTtsSpeed(this);
  }

  getTtsCharCountSource(): string {
    return ReaderTtsOrchestrationOps.getTtsCharCountSource(this);
  }

  isFullTextCaching(): boolean {
    return ReaderTtsOrchestrationOps.isFullTextCaching(this);
  }

  isFullTextCacheBackgroundRunning(): boolean {
    return ReaderTtsOrchestrationOps.isFullTextCacheBackgroundRunning(this);
  }

  setFullTextCacheBackgroundRunning(value: boolean): void {
    ReaderTtsOrchestrationOps.setFullTextCacheBackgroundRunning(this, value);
  }

  isTtsChapterSwitching(): boolean {
    return ReaderTtsOrchestrationOps.isTtsChapterSwitching(this);
  }

  setTtsChapterSwitching(value: boolean): void {
    ReaderTtsOrchestrationOps.setTtsChapterSwitching(this, value);
  }

  getTtsLastMediaChapterCommandAt(): number {
    return ReaderTtsOrchestrationOps.getTtsLastMediaChapterCommandAt(this);
  }

  setTtsLastMediaChapterCommandAt(value: number): void {
    ReaderTtsOrchestrationOps.setTtsLastMediaChapterCommandAt(this, value);
  }

  ownsTtsFloatingSession(): boolean {
    return ReaderTtsOrchestrationOps.ownsTtsFloatingSession(this);
  }

  async playPositionFromFloatingSession(targetChapterIndex: number, targetPageIndex: number,
    targetSourceOffset: number = -1): Promise<void> {
    return ReaderTtsOrchestrationOps.playPositionFromFloatingSession(this, targetChapterIndex, targetPageIndex, targetSourceOffset);
  }

  getTtsPanelCoverList(): string[] {
    return ReaderTtsOrchestrationOps.getTtsPanelCoverList(this);
  }

  getTtsFloatingCover(): ResourceStr {
    return ReaderTtsOrchestrationOps.getTtsFloatingCover(this);
  }

  getTtsCoverPlaceholderColor(): string {
    return ReaderTtsOrchestrationOps.getTtsCoverPlaceholderColor(this);
  }

  getBookshelfDisplayCoverRaw(): string {
    return ReaderTtsOrchestrationOps.getBookshelfDisplayCoverRaw(this);
  }

  getTtsGalleryCoverRaw(): string {
    return ReaderTtsOrchestrationOps.getTtsGalleryCoverRaw(this);
  }

  pickStableTtsCover(covers: string[]): string {
    return ReaderTtsOrchestrationOps.pickStableTtsCover(this, covers);
  }
//endregion
//region 焦点会话 / 正文规范化纯函数群 / 分页测量引擎
// [map] 契约: 含大量可纯化的正文处理(findMeasuredPageEnd 等); 分页测量读排版状态

  clearTtsHighlight(): void {
    ReaderPaginationOps.clearTtsHighlight(this);
  }

  publishTtsHighlightRenderChange(): void {
    ReaderPaginationOps.publishTtsHighlightRenderChange(this);
  }

  currentTtsSourceIdentity(): string {
    return ReaderPaginationOps.currentTtsSourceIdentity(this);
  }

  invalidateTtsFocusSession(): void {
    ReaderPaginationOps.invalidateTtsFocusSession(this);
  }

  isCurrentTtsFocusSession(token: number, generation: number,
    chapterIndex: number, sourceIdentity: string): boolean {
    return ReaderPaginationOps.isCurrentTtsFocusSession(this, token, generation, chapterIndex, sourceIdentity);
  }

  getTtsReadingText(startOffset: number = -1): string {
    return ReaderPaginationOps.getTtsReadingText(this, startOffset);
  }

  getTtsFocusBreakOffsets(textLength: number): number[] {
    return ReaderPaginationOps.getTtsFocusBreakOffsets(this, textLength);
  }

  getPagedSourceText(): string {
    return ReaderPaginationOps.getPagedSourceText(this);
  }

  buildPagedSourceText(chapterIndex: number, content: string): string {
    return ReaderPaginationOps.buildPagedSourceText(this, chapterIndex, content);
  }



  // "保留段首缩进"开启时分页/分块起点仍要跳过的字符：换行与零宽不可见字符。
  // 空格类字符（全角空格、普通空格等）在此模式下保留，段首缩进因此不被裁掉。

  // 分页/分块起点使用的裁剪字符集："保留段首缩进"开启时只跳过换行与零宽字符，
  // 保留空格类缩进；默认行为维持全量裁剪。
  trimPageStartChar(value: string): boolean {
    return ReaderPaginationOps.trimPageStartChar(this, value);
  }

  pushReaderPage(source: string, rawStart: number, rawEnd: number, pages: string[], starts: number[], ends: number[]): void {
    ReaderPaginationOps.pushReaderPage(this, source, rawStart, rawEnd, pages, starts, ends);
  }


  fitReaderActionMarkerPageEnd(source: string, start: number, rawEnd: number, availableWidth: number,
    availableHeight: number, chapterIndex: number): number {
    return ReaderPaginationOps.fitReaderActionMarkerPageEnd(this, source, start, rawEnd, availableWidth, availableHeight, chapterIndex);
  }


  readerInlineActionCarryStart(source: string, pageStart: number, markerStart: number, availableWidth: number,
    chapterIndex: number): number {
    return ReaderPaginationOps.readerInlineActionCarryStart(this, source, pageStart, markerStart, availableWidth, chapterIndex);
  }

  findMeasuredPageEnd(source: string, start: number, availableWidth: number, availableHeight: number,
    chapterIndex: number = this.currentChapterIndex): number {
    return ReaderPaginationOps.findMeasuredPageEnd(this, source, start, availableWidth, availableHeight, chapterIndex);
  }

  findBlockParagraphPageEnd(source: string, start: number, windowEnd: number, availableWidth: number,
    availableHeight: number, chapterIndex: number = this.currentChapterIndex): number {
    return ReaderPaginationOps.findBlockParagraphPageEnd(this, source, start, windowEnd, availableWidth, availableHeight, chapterIndex);
  }

  findSingleParagraphLineEnd(text: string, availableWidth: number, availableHeight: number,
    chapterIndex: number, documentSource: string, absoluteStart: number): number {
    return ReaderPaginationOps.findSingleParagraphLineEnd(this, text, availableWidth, availableHeight, chapterIndex, documentSource, absoluteStart);
  }

  refineMeasuredPageEnd(source: string, start: number, initialEnd: number, availableWidth: number,
    availableHeight: number, chapterIndex: number = this.currentChapterIndex): number {
    return ReaderPaginationOps.refineMeasuredPageEnd(this, source, start, initialEnd, availableWidth, availableHeight, chapterIndex);
  }

  doesMeasuredReaderPageFit(source: string, start: number, end: number, availableWidth: number,
    availableHeight: number, chapterIndex: number = this.currentChapterIndex): boolean {
    return ReaderPaginationOps.doesMeasuredReaderPageFit(this, source, start, end, availableWidth, availableHeight, chapterIndex);
  }

  findParagraphLayoutPageEnd(source: string, start: number, availableWidth: number, availableHeight: number,
    chapterIndex: number = this.currentChapterIndex): number {
    return ReaderPaginationOps.findParagraphLayoutPageEnd(this, source, start, availableWidth, availableHeight, chapterIndex);
  }

  getReaderLayoutWindowSize(availableWidth: number, availableHeight: number): number {
    return ReaderPaginationOps.getReaderLayoutWindowSize(this, availableWidth, availableHeight);
  }


  getReaderPaginationRenderGuardHeight(): number {
    return ReaderPaginationOps.getReaderPaginationRenderGuardHeight(this);
  }

  getReaderTextParagraphs(text: string): ReaderTextParagraph[] {
    return ReaderPaginationOps.getReaderTextParagraphs(this, text);
  }

  cacheReaderTextParagraphs(text: string, paragraphs: ReaderTextParagraph[]): void {
    ReaderPaginationOps.cacheReaderTextParagraphs(this, text, paragraphs);
  }

  measureReaderTextHeight(text: string, availableWidth: number,
    chapterIndex: number = this.currentChapterIndex, documentSource: string = text,
    absoluteStart: number = 0): number {
    return ReaderPaginationOps.measureReaderTextHeight(this, text, availableWidth, chapterIndex, documentSource, absoluteStart);
  }

  measureReaderSingleParagraphHeight(text: string, availableWidth: number,
    chapterIndex: number = this.currentChapterIndex, documentSource: string = text,
    absoluteStart: number = 0): number {
    return ReaderPaginationOps.measureReaderSingleParagraphHeight(this, text, availableWidth, chapterIndex, documentSource, absoluteStart);
  }

  getReaderPaginationHeightScale(): number {
    return ReaderPaginationOps.getReaderPaginationHeightScale(this);
  }

  calibrateReaderPaginationHeightFromMergedText(paragraphs: ReaderTextParagraph[], chapterIndex: number,
    pageStart: number, documentSource: string, pageLineHeight: number, area: Area): void {
    ReaderPaginationOps.calibrateReaderPaginationHeightFromMergedText(this, paragraphs, chapterIndex, pageStart, documentSource, pageLineHeight, area);
  }

  scheduleReaderPaginationBottomFitCalibration(paragraphs: ReaderTextParagraph[], chapterIndex: number,
    pageStart: number, area: Area): void {
    ReaderPaginationOps.scheduleReaderPaginationBottomFitCalibration(this, paragraphs, chapterIndex, pageStart, area);
  }

  readerPaginationHeightCalibrationIdentity(): string {
    return ReaderPaginationOps.readerPaginationHeightCalibrationIdentity(this);
  }

  readerParagraphMetrics(text: string, availableWidth: number,
    chapterIndex: number = this.currentChapterIndex, documentSource: string = text,
    absoluteStart: number = 0): ReaderParagraphMetrics {
    return ReaderPaginationOps.readerParagraphMetrics(this, text, availableWidth, chapterIndex, documentSource, absoluteStart);
  }

  cacheReaderParagraphMetrics(key: string, metrics: ReaderParagraphMetrics): void {
    ReaderPaginationOps.cacheReaderParagraphMetrics(this, key, metrics);
  }

  readerActionMeasurementText(text: string, documentSource: string, absoluteStart: number): string {
    return ReaderPaginationOps.readerActionMeasurementText(this, text, documentSource, absoluteStart);
  }

  buildReaderMeasureTextStyle(fontSize: number, fontFamily: string): graphicsText.TextStyle {
    return ReaderPaginationOps.buildReaderMeasureTextStyle(this, fontSize, fontFamily);
  }

  buildMeasuredReaderParagraph(text: string, availableWidth: number,
    chapterIndex: number = this.currentChapterIndex, documentSource: string = text,
    absoluteStart: number = 0): graphicsText.Paragraph {
    return ReaderPaginationOps.buildMeasuredReaderParagraph(this, text, availableWidth, chapterIndex, documentSource, absoluteStart);
  }

  buildMeasuredMergedReaderParagraph(paragraphs: ReaderTextParagraph[], availableWidth: number,
    chapterIndex: number, documentSource: string, absoluteStart: number): graphicsText.Paragraph {
    return ReaderPaginationOps.buildMeasuredMergedReaderParagraph(this, paragraphs, availableWidth, chapterIndex, documentSource, absoluteStart);
  }

  addMeasuredReaderText(builder: graphicsText.ParagraphBuilder, text: string, chapterIndex: number,
    bodyStyle: graphicsText.TextStyle, documentSource: string = text, absoluteStart: number = 0): void {
    ReaderPaginationOps.addMeasuredReaderText(this, builder, text, chapterIndex, bodyStyle, documentSource, absoluteStart);
  }

  addMeasuredReaderInlineActionText(builder: graphicsText.ParagraphBuilder, text: string, chapterIndex: number,
    bodyStyle: graphicsText.TextStyle, documentSource: string, absoluteStart: number,
    match: ReaderActionMatch): void {
    ReaderPaginationOps.addMeasuredReaderInlineActionText(this, builder, text, chapterIndex, bodyStyle, documentSource, absoluteStart, match);
  }

  addMeasuredRegexReaderText(builder: graphicsText.ParagraphBuilder, text: string,
    bodyStyle: graphicsText.TextStyle, documentSource: string = text, absoluteStart: number = 0): void {
    ReaderPaginationOps.addMeasuredRegexReaderText(this, builder, text, bodyStyle, documentSource, absoluteStart);
  }

  addMeasuredRegexBubbleCap(builder: graphicsText.ParagraphBuilder, slice: ReadTextSlice): void {
    ReaderPaginationOps.addMeasuredRegexBubbleCap(this, builder, slice);
  }

  hasMeasuredThemeRegexDecoration(text: string, documentSource: string, absoluteStart: number): boolean {
    return ReaderPaginationOps.hasMeasuredThemeRegexDecoration(this, text, documentSource, absoluteStart);
  }

  getParagraphFallbackMeasureStyle(text: string, chapterIndex: number): ReaderParagraphMeasureFallback {
    return ReaderPaginationOps.getParagraphFallbackMeasureStyle(this, text, chapterIndex);
  }



  getRenderedReaderParagraphLineBoxPx(text: string, chapterIndex: number,
    documentSource: string = text, absoluteStart: number = 0): number {
    return ReaderPaginationOps.getRenderedReaderParagraphLineBoxPx(this, text, chapterIndex, documentSource, absoluteStart);
  }
//endregion
//region 逐句焦点·高亮·进度持久化 / 镜像会话 / TTS翻页 / 动画表面
// [map] 契约: 每句触发 followTtsChunk→高亮重绘→persistTtsReadPosition→浮标 revision++; 镜像会话接管线




  followTtsChunk(chunk: TtsChunk, token: number, generation: number,
    chapterIndex: number, sourceIdentity: string): void {
    ReaderHighlightOps.followTtsChunk(this, chunk, token, generation, chapterIndex, sourceIdentity);
  }

  noteTtsFocusLatency(elapsedMs: number): void {
    ReaderHighlightOps.noteTtsFocusLatency(this, elapsedMs);
  }

  applyTtsChunkFocus(chunk: TtsChunk): void {
    ReaderHighlightOps.applyTtsChunkFocus(this, chunk);
  }


  readerHeaderContentSelectedIndex(): number {
    return ReaderHighlightOps.readerHeaderContentSelectedIndex(this);
  }


  readerFooterLeftSelectedIndex(): number {
    return ReaderHighlightOps.readerFooterLeftSelectedIndex(this);
  }


  readerFooterProgressSelectedIndex(): number {
    return ReaderHighlightOps.readerFooterProgressSelectedIndex(this);
  }

  saveReaderChromeSettings(): void {
    ReaderHighlightOps.saveReaderChromeSettings(this);
  }

  syncTtsFocusAfterResumeLater(delayMs: number): void {
    ReaderHighlightOps.syncTtsFocusAfterResumeLater(this, delayMs);
  }

  scheduleTtsFocusResumeSyncRetry(): void {
    ReaderHighlightOps.scheduleTtsFocusResumeSyncRetry(this);
  }

  syncTtsFocusAfterResume(): void {
    ReaderHighlightOps.syncTtsFocusAfterResume(this);
  }

  resolveTtsChunkPageIndex(chunk: TtsChunk): number {
    return ReaderHighlightOps.resolveTtsChunkPageIndex(this, chunk);
  }

  updateTtsChunkHighlight(chunk: TtsChunk, pageIndex: number, persistPosition: boolean = true): void {
    ReaderHighlightOps.updateTtsChunkHighlight(this, chunk, pageIndex, persistPosition);
  }

  scheduleTtsFocusRepublishAfterPageTurn(chapterIndex: number, pageIndex: number,
    absoluteStart: number, absoluteEnd: number): void {
    ReaderHighlightOps.scheduleTtsFocusRepublishAfterPageTurn(this, chapterIndex, pageIndex, absoluteStart, absoluteEnd);
  }

  publishTtsFocusAfterResumeBoundary(): void {
    ReaderHighlightOps.publishTtsFocusAfterResumeBoundary(this);
  }

  scheduleCurrentTtsFocusRepublishAfterPageTurn(): void {
    ReaderHighlightOps.scheduleCurrentTtsFocusRepublishAfterPageTurn(this);
  }

  republishTtsFocusAfterPageTurn(serial: number, chapterIndex: number, pageIndex: number,
    absoluteStart: number, absoluteEnd: number, attempt: number): void {
    ReaderHighlightOps.republishTtsFocusAfterPageTurn(this, serial, chapterIndex, pageIndex, absoluteStart, absoluteEnd, attempt);
  }

  scheduleTtsFocusSyncAfterPagination(): void {
    ReaderHighlightOps.scheduleTtsFocusSyncAfterPagination(this);
  }

  syncActiveTtsFocusAfterPagination(): void {
    ReaderHighlightOps.syncActiveTtsFocusAfterPagination(this);
  }

  persistTtsReadPosition(absoluteStart: number, absoluteEnd: number): void {
    ReaderHighlightOps.persistTtsReadPosition(this, absoluteStart, absoluteEnd);
  }

  flushTtsReadPosition(): void {
    ReaderHighlightOps.flushTtsReadPosition(this);
  }

  async flushReadingProgressCheckpoint(): Promise<void> {
    return ReaderHighlightOps.flushReadingProgressCheckpoint(this);
  }

  restorePersistedTtsFocus(): boolean {
    return ReaderHighlightOps.restorePersistedTtsFocus(this);
  }

  activeMirroredTtsChapterIndex(): number {
    return ReaderHighlightOps.activeMirroredTtsChapterIndex(this);
  }

  isMirroringActiveTtsForCurrentBook(): boolean {
    return ReaderHighlightOps.isMirroringActiveTtsForCurrentBook(this);
  }

  async syncMirroredTtsFocus(): Promise<void> {
    return ReaderHighlightOps.syncMirroredTtsFocus(this);
  }

  clearMirroredTtsFocus(): void {
    ReaderHighlightOps.clearMirroredTtsFocus(this);
  }

  // 后台朗读宿主（通常是侧滑返回后残留的上一阅读页实例）与本页并存时，二者共享同一引擎
  // 与进度写入，镜像跟随期间极易出现翻页高亮卡顿、页面偶发错乱。这里在打开本页时一次性
  // 接管：停掉持会话的后台宿主，由本页从全局锚点句级续播，成为唯一宿主。
  async takeOverMirroredTtsSession(): Promise<void> {
    return ReaderHighlightOps.takeOverMirroredTtsSession(this);
  }

  shouldRenderTtsFocus(): boolean {
    return ReaderHighlightOps.shouldRenderTtsFocus(this);
  }

  animateTtsToPage(targetPageIndex: number, chunk: TtsChunk): void {
    ReaderHighlightOps.animateTtsToPage(this, targetPageIndex, chunk);
  }

  async runPendingTtsPageTurn(): Promise<void> {
    return ReaderHighlightOps.runPendingTtsPageTurn(this);
  }

  async runTtsPageTurnAnimationTo(targetPageIndex: number, turnSerial: number): Promise<void> {
    return ReaderHighlightOps.runTtsPageTurnAnimationTo(this, targetPageIndex, turnSerial);
  }

  applyTtsPageTarget(targetPageIndex: number, turnSerial: number): void {
    ReaderHighlightOps.applyTtsPageTarget(this, targetPageIndex, turnSerial);
  }

  async runTtsPageTurnAnimation(direction: number, turnSerial: number = this.ttsPageTurnSerial): Promise<void> {
    return ReaderHighlightOps.runTtsPageTurnAnimation(this, direction, turnSerial);
  }

  async runTtsTapPageTurn(direction: number, turnSerial: number): Promise<void> {
    return ReaderHighlightOps.runTtsTapPageTurn(this, direction, turnSerial);
  }

  async runTtsSlidePageTurn(direction: number, turnSerial: number): Promise<void> {
    return ReaderHighlightOps.runTtsSlidePageTurn(this, direction, turnSerial);
  }

  async applyTtsPageTurn(direction: number, turnSerial: number): Promise<void> {
    return ReaderHighlightOps.applyTtsPageTurn(this, direction, turnSerial);
  }


  suspendReaderPaginationWork(): void {
    ReaderHighlightOps.suspendReaderPaginationWork(this);
  }

  resumeReaderPaginationWorkAfterPageShow(): void {
    ReaderHighlightOps.resumeReaderPaginationWorkAfterPageShow(this);
  }

  resumeCurrentReaderPaginationCompletion(): void {
    ReaderHighlightOps.resumeCurrentReaderPaginationCompletion(this);
  }

  @Builder
  readerActiveCurrentPageSurface(currentRenderVersion: number, currentText: string,
    ttsRenderVersion: number) {
    if (this.currentReaderSurfaceIndex() === 0) {
      if (this.isPageTurnAnimationEnabled() && !this.usesReaderPageCurlCanvas()) {
        this.readerSlidingPageTurnSurface(currentText, currentRenderVersion, ttsRenderVersion)
      } else {
        this.readerCurrentPageSurface(currentRenderVersion, currentText, ttsRenderVersion)
      }
    } else {
      if (this.isPageTurnAnimationEnabled() && !this.usesReaderPageCurlCanvas()) {
        this.readerSlidingPageTurnSurfaceAlternate(currentText, currentRenderVersion, ttsRenderVersion)
      } else {
        this.readerCurrentPageSurfaceAlternate(currentRenderVersion, currentText, ttsRenderVersion)
      }
    }
  }

  async waitForReaderComicBoundaryRestore(timeoutMs: number = 1800): Promise<void> {
    return ReaderHighlightOps.waitForReaderComicBoundaryRestore(this, timeoutMs);
  }

  @Builder
  readerSlidingPageTurnSurface(currentText: string, currentRenderVersion: number, ttsRenderVersion: number) {
    Stack() {
      if (this.shouldRenderSlidingPageTurn()) {
        if (this.isSimulationPageTurnAnimation()) {
          this.readerSimulationPageTurnSurface(currentRenderVersion, currentText, ttsRenderVersion, 'primary')
        } else if (this.isStackPageTurnAnimation()) {
          this.readerCurrentPageSurface(currentRenderVersion, currentText, ttsRenderVersion)
          this.readerIncomingPageSurface(this.pageTurnIncomingRenderVersion,
            this.getVisiblePageTurnIncomingText(), 'incoming_primary')
        } else {
          this.readerIncomingPageSurface(this.pageTurnIncomingRenderVersion,
            this.getVisiblePageTurnIncomingText(), 'incoming_primary')
          this.readerCurrentPageSurface(currentRenderVersion, currentText, ttsRenderVersion)
        }
      } else {
        this.readerCurrentPageSurface(currentRenderVersion, currentText, ttsRenderVersion)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.readerContentLayerColor())
    .clip(true)
    .expandSafeArea([SafeAreaType.SYSTEM], this.getReaderPageTurnSurfaceSafeAreaEdges())
  }

  @Builder
  readerSlidingPageTurnSurfaceAlternate(currentText: string, currentRenderVersion: number, ttsRenderVersion: number) {
    Stack() {
      if (this.shouldRenderSlidingPageTurn()) {
        if (this.isSimulationPageTurnAnimation()) {
          this.readerSimulationPageTurnSurface(currentRenderVersion, currentText, ttsRenderVersion, 'alternate')
        } else if (this.isStackPageTurnAnimation()) {
          this.readerCurrentPageSurfaceAlternate(currentRenderVersion, currentText, ttsRenderVersion)
          this.readerIncomingPageSurface(this.pageTurnIncomingRenderVersion,
            this.getVisiblePageTurnIncomingText(), 'incoming_alternate')
        } else {
          this.readerIncomingPageSurface(this.pageTurnIncomingRenderVersion,
            this.getVisiblePageTurnIncomingText(), 'incoming_alternate')
          this.readerCurrentPageSurfaceAlternate(currentRenderVersion, currentText, ttsRenderVersion)
        }
      } else {
        this.readerCurrentPageSurfaceAlternate(currentRenderVersion, currentText, ttsRenderVersion)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.readerContentLayerColor())
    .clip(true)
    .expandSafeArea([SafeAreaType.SYSTEM], this.getReaderPageTurnSurfaceSafeAreaEdges())
  }

  @Builder
  readerSimulationPageTurnSurface(currentRenderVersion: number, currentText: string, ttsRenderVersion: number,
    surfaceRole: string) {
    if (this.isLandscapeDoublePageActive()) {
      this.readerSimulationDoublePageTurnSurface(currentRenderVersion, currentText, ttsRenderVersion, surfaceRole)
    } else {
      this.readerSimulationSinglePageTurnSurface(currentRenderVersion, currentText, ttsRenderVersion, surfaceRole)
    }
  }

  @Builder
  readerSimulationSinglePageTurnSurface(currentRenderVersion: number, currentText: string,
    ttsRenderVersion: number, surfaceRole: string) {
    Stack() {
      Stack() {
        ReaderSimulationPaperBackground({
          surfaceColor: this.getBackgroundColor(),
          backgroundAssetId: this.getBackgroundAssetId(),
          customImage: this.currentReaderTheme().backgroundImageUri,
          customImageFit: this.getBackgroundImageFit(),
          viewportWidthHint: this.getPageTurnWidth(),
          viewportHeightHint: this.getReaderBackgroundViewportHeight()
        })
        Column() {
          this.readerIncomingPageLayer(this.pageTurnIncomingRenderVersion,
            this.getVisiblePageTurnIncomingText(), `${surfaceRole}_simulation_back`)
        }
        .width('100%')
        .height('100%')
        .padding({ top: this.getReaderPageContentTopPadding() })
      }
      .width('100%')
      .height('100%')
      // Snapshot can capture an off-screen component by id. Keeping this duplicate out of the viewport avoids
      // replacing the already-visible Paragraph tree for the one or two frames before capture completes.
      .position({ x: -this.getPageTurnWidth() * 2, y: 0 })
      .id('reader_page_curl_back_single')
      .renderGroup(true)

      Stack() {
        ReaderSimulationPaperBackground({
          surfaceColor: this.getBackgroundColor(),
          backgroundAssetId: this.getBackgroundAssetId(),
          customImage: this.currentReaderTheme().backgroundImageUri,
          customImageFit: this.getBackgroundImageFit(),
          viewportWidthHint: this.getPageTurnWidth(),
          viewportHeightHint: this.getReaderBackgroundViewportHeight()
        })
        this.readerIncomingPageSurface(this.pageTurnIncomingRenderVersion,
          this.getVisiblePageTurnIncomingText(), `${surfaceRole}_simulation_base`)
      }
      .width('100%')
      .height('100%')
      // Until both textures are ready the stable current surface below remains the only visible正文.
      .opacity(this.readerPageCurlSnapshotReady ? 1 : 0)

    }
    .width('100%')
    .height('100%')
    // The overlay is mounted as soon as the drag direction is known, one frame before the asynchronous front/back
    // snapshots become ready. An opaque outer paper therefore covered the still-valid live page with an empty sheet
    // for that frame. The ready-gated destination surface above already paints its own paper, so keep this host clear.
    .backgroundColor(Color.Transparent)
    .clip(true)
  }

  @Builder
  readerSimulationDoublePageTurnSurface(currentRenderVersion: number, currentText: string,
    ttsRenderVersion: number, surfaceRole: string) {
    Stack() {
      Stack() {
        // The back of the turning leaf belongs to the opposite half of the target spread.
        // Crop it from one spread-sized background instead of fitting a second wallpaper
        // inside this half-width snapshot.
        this.readerSimulationHalfPaperBackground(this.pageSlideDirection < 0)
        if (this.pageSlideDirection > 0) {
          this.readerSimulationIncomingHalfPage(this.pageTurnIncomingText, this.pageTurnIncomingPageIndex,
            this.pageTurnIncomingPageStart, this.pageTurnIncomingRenderVersion,
            `${surfaceRole}_leaf_back_capture`)
        } else {
          this.readerSimulationIncomingHalfPage(this.pageTurnIncomingSecondaryText,
            this.pageTurnIncomingPageIndex + 1, this.pageTurnIncomingSecondaryPageStart,
            this.pageTurnIncomingRenderVersion, `${surfaceRole}_leaf_back_capture`)
        }
      }
      .width(this.getReaderPageColumnWidth())
      .height('100%')
      .position({ x: -this.getPageTurnWidth() * 2, y: 0 })
      .id('reader_page_curl_back_double')
      .renderGroup(true)

      // Keep the non-turning half on the stable正文 surface below this overlay. Rebuilding that half with a
      // second native Paragraph controller made it jump by a fractional layout pixel whenever the snapshot
      // became ready. Only the destination half that really changes needs an opaque paper and正文 layer here.
      Stack() {
        this.readerSimulationHalfPaperBackground(this.pageSlideDirection > 0)
        if (this.pageSlideDirection > 0) {
          this.readerSimulationIncomingHalfPage(this.pageTurnIncomingSecondaryText,
            this.pageTurnIncomingPageIndex + 1, this.pageTurnIncomingSecondaryPageStart,
            this.pageTurnIncomingRenderVersion, `${surfaceRole}_base_right`)
        } else {
          this.readerSimulationIncomingHalfPage(this.pageTurnIncomingText, this.pageTurnIncomingPageIndex,
            this.pageTurnIncomingPageStart, this.pageTurnIncomingRenderVersion,
            `${surfaceRole}_base_left`)
        }
      }
      .width(this.getReaderPageColumnWidth())
      .height('100%')
      .position({ x: this.pageSlideDirection > 0 ? this.getReaderDoublePageRightOrigin() : 0, y: 0 })
      .opacity(this.readerPageCurlSnapshotReady ? 1 : 0)

      Column()
        .width(2)
        .height('94%')
        .position({ x: this.getReaderPageColumnWidth(), y: '3%' })
        .linearGradient({
          angle: 0,
          colors: [['#00000000', 0], [this.getSimulationSpineColor(), 0.5], ['#00000000', 1]]
        })
        .opacity(this.readerPageCurlSnapshotReady ? 1 : 0)

    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .clip(true)
  }

  @Builder
  readerSimulationCurlCanvas() {
    Canvas(this.readerPageCurlContext)
      .width('100%')
      .height('100%')
      .opacity(this.readerPageCurlSnapshotReady ? 1 : 0)
      .hitTestBehavior(HitTestMode.None)
      .onReady(() => {
        this.readerPageCurlCanvasReady = true;
        this.drawReaderPageCurl();
      })
  }

  @Builder
  readerSimulationHalfPaperBackground(rightHalf: boolean) {
    Stack() {
      ReaderThemeBackground({
        surfaceColor: this.getBackgroundColor(),
        backgroundAssetId: this.getBackgroundAssetId(),
        customImage: this.currentReaderTheme().backgroundImageUri,
        customImageFit: this.getBackgroundImageFit(),
        viewportWidthHint: this.getPageTurnWidth(),
        viewportHeightHint: this.getReaderBackgroundViewportHeight()
      })
        .width(this.getPageTurnWidth())
        .height('100%')
        .position({ x: rightHalf ? -this.getReaderDoublePageRightOrigin() : 0, y: 0 })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  readerSimulationIncomingHalfPage(text: string, pageIndex: number, pageStart: number,
    renderVersion: number, identity: string, halfWidth: boolean = false) {
    Column() {
      if (this.shouldUseReaderLayoutV2(this.pageTurnIncomingDocumentSource) &&
        this.readerV2Page(this.pageTurnIncomingChapterIndex, pageIndex, this.pageTurnIncomingDocumentSource)) {
        this.readerV2PageSurface(`simulation_incoming_${identity}`, this.pageTurnIncomingChapterIndex,
          pageIndex, this.pageTurnIncomingDocumentSource)
      } else {
        this.styledReaderText(text, this.getReaderContentBottomPadding(), this.pageTurnIncomingChapterIndex, 0,
          renderVersion, `${this.incomingReaderPageRenderIdentity(renderVersion, text)}_simulation_${identity}`,
          pageIndex, this.getEffectiveReaderMarginTop(), pageStart, this.pageTurnIncomingDocumentSource)
      }
    }
    .width(halfWidth ? this.getReaderPageColumnWidth() : '100%')
    .height('100%')
    .padding({ top: this.getReaderPageContentTopPadding() })
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
  }

  currentReaderSurfaceId(alternate: boolean, renderVersion: number, ttsRenderVersion: number): string {
    return ReaderHighlightOps.currentReaderSurfaceId(this, alternate, renderVersion, ttsRenderVersion);
  }

  currentReaderSnapshotComponentId(): string {
    return ReaderHighlightOps.currentReaderSnapshotComponentId(this);
  }

  @Builder
  readerCurrentPageSurface(renderVersion: number, text: string, ttsRenderVersion: number) {
    Stack() {
      if (this.isStackPageTurnAnimation() || this.isSimulationPageTurnAnimation() ||
        this.is3DPageTurnAnimation()) {
        // Stack and simulation animate/snapshot a full-screen sheet, so their page must own the paper artwork.
        // Slide and fade live below the status-bar inset: painting the same Cover image here would restart its
        // crop at the content origin and create a visible seam against the full-screen root background.
        ReaderSimulationPaperBackground({
          surfaceColor: this.getBackgroundColor(),
          backgroundAssetId: this.getBackgroundAssetId(),
          customImage: this.currentReaderTheme().backgroundImageUri,
          customImageFit: this.getBackgroundImageFit(),
          viewportWidthHint: this.getPageTurnWidth(),
          viewportHeightHint: this.getReaderBackgroundViewportHeight()
        })
      }
      Column() {
        this.readerCurrentPageLayer(renderVersion, text, ttsRenderVersion, 'current_primary')
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.getReaderPageContentTopPadding() })
    }
    .width('100%')
    .height('100%')
    .id(this.currentReaderSurfaceId(false, renderVersion, ttsRenderVersion))
    .backgroundColor(this.readerContentLayerColor())
    .translate({ x: this.getCurrentPageTurnX(), y: this.getCurrentPageTurnY() + this.bookmarkPullOffsetY })
    .opacity(this.getCurrentPageTurnOpacity())
  }

  @Builder
  readerCurrentPageSurfaceAlternate(renderVersion: number, text: string, ttsRenderVersion: number) {
    Stack() {
      if (this.isStackPageTurnAnimation() || this.isSimulationPageTurnAnimation() ||
        this.is3DPageTurnAnimation()) {
        ReaderSimulationPaperBackground({
          surfaceColor: this.getBackgroundColor(),
          backgroundAssetId: this.getBackgroundAssetId(),
          customImage: this.currentReaderTheme().backgroundImageUri,
          customImageFit: this.getBackgroundImageFit(),
          viewportWidthHint: this.getPageTurnWidth(),
          viewportHeightHint: this.getReaderBackgroundViewportHeight()
        })
      }
      Column() {
        this.readerCurrentPageLayer(renderVersion, text, ttsRenderVersion, 'current_alternate')
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.getReaderPageContentTopPadding() })
    }
    .width('100%')
    .height('100%')
    .id(this.currentReaderSurfaceId(true, renderVersion, ttsRenderVersion))
    .backgroundColor(this.readerContentLayerColor())
    .translate({ x: this.getCurrentPageTurnX(), y: this.getCurrentPageTurnY() + this.bookmarkPullOffsetY })
    .opacity(this.getCurrentPageTurnOpacity())
  }

  @Builder
  bookmarkFallbackSwipeActions(bookmark: Bookmark) {
    Row() {
      ReaderBookmarkMultiSelectAction({
        accent: this.accentColor(),
        onClickAction: (): void => {
          this.enterBookmarkMultiSelect(bookmark.bookmarkUrl);
        }
      })
      ReaderBookmarkDeleteAction({
        onClickAction: (): void => {
          this.deleteBookmark(bookmark);
        }
      })
    }
    .height('100%')
  }

  @Builder
  readerIncomingPageSurface(renderVersion: number, text: string, controllerRole: string = 'incoming') {
    Stack() {
      if (this.isStackPageTurnAnimation() || this.is3DPageTurnAnimation()) {
        ReaderThemeBackground({
          surfaceColor: this.getBackgroundColor(),
          backgroundAssetId: this.getBackgroundAssetId(),
          customImage: this.currentReaderTheme().backgroundImageUri,
          customImageFit: this.getBackgroundImageFit(),
          viewportWidthHint: this.pageViewWidth,
          viewportHeightHint: this.getReaderBackgroundViewportHeight()
        })
          .id('reader_incoming_theme_background')
          .hitTestBehavior(HitTestMode.None)
      }
      Column() {
        this.readerIncomingPageLayer(renderVersion, text, controllerRole)
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.getReaderPageContentTopPadding() })
    }
    .width('100%')
    .height('100%')
    .id(`reader_incoming_${this.pageTurnIncomingChapterIndex}_${this.pageTurnIncomingPageIndex}_${renderVersion}`)
    .backgroundColor(this.readerContentLayerColor())
    .renderGroup(true)
    .translate({ x: this.getIncomingSlideX(), y: this.getIncomingSlideY() })
    .opacity(this.getVisiblePageTurnIncomingOpacity())
    .clip(true)
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  readerCurrentPageLayer(renderVersion: number, text: string, ttsRenderVersion: number,
    controllerRole: string = 'current') {
    if (this.shouldUseReaderLayoutV2(this.pagedContentText) &&
      this.readerV2Page(this.currentChapterIndex, this.currentPageIndex, this.pagedContentText)) {
      if (this.isLandscapeDoublePageActive()) {
        Row() {
          this.readerV2PageSurface(`${controllerRole}_left`, this.currentChapterIndex,
            this.currentPageIndex, this.pagedContentText, true)
          Blank()
            .width(READER_DOUBLE_PAGE_DIVIDER_WIDTH)
            .height('88%')
            .backgroundColor(this.getSubTextColor())
            .opacity(0.22)
          this.readerV2PageSurface(`${controllerRole}_right`, this.currentChapterIndex,
            this.currentPageIndex + 1, this.pagedContentText, true)
        }
        .width('100%')
        .height('100%')
        .alignItems(VerticalAlign.Center)
      } else {
        this.readerV2PageSurface(`${controllerRole}_single`, this.currentChapterIndex,
          this.currentPageIndex, this.pagedContentText)
      }
    } else if (this.isLandscapeDoublePageActive()) {
      Row() {
        Column() {
          this.styledCurrentReaderText(text, this.getReaderContentBottomPadding(), this.currentChapterIndex,
            ttsRenderVersion, renderVersion,
            `${this.currentReaderPageRenderIdentity(renderVersion, ttsRenderVersion)}_left`, this.currentPageIndex)
        }
        .layoutWeight(1)
        .height('100%')

        Blank()
          .width(READER_DOUBLE_PAGE_DIVIDER_WIDTH)
          .height('88%')
          .backgroundColor(this.getSubTextColor())
          .opacity(0.22)

        Column() {
          this.styledCurrentReaderText(this.getSecondaryPageText(), this.getReaderContentBottomPadding(),
            this.currentChapterIndex, ttsRenderVersion, renderVersion,
            `${this.currentReaderPageRenderIdentity(renderVersion, ttsRenderVersion)}_right`, this.currentPageIndex + 1)
        }
        .layoutWeight(1)
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.readerContentLayerColor())
    } else {
      Column() {
        this.styledCurrentReaderText(text, this.getReaderContentBottomPadding(),
          this.currentChapterIndex,
          ttsRenderVersion, renderVersion, this.currentReaderPageRenderIdentity(renderVersion, ttsRenderVersion),
          this.currentPageIndex)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(this.readerContentLayerColor())
      .id(`reader_layer_${this.currentReaderPageRenderIdentity(renderVersion, ttsRenderVersion)}`)
    }
  }

  @Builder
  readerIncomingPageLayer(renderVersion: number, text: string, controllerRole: string = 'incoming') {
    if (this.shouldUseReaderLayoutV2(this.pageTurnIncomingDocumentSource) &&
      this.readerV2Page(this.pageTurnIncomingChapterIndex, this.pageTurnIncomingPageIndex,
        this.pageTurnIncomingDocumentSource)) {
      if (this.isLandscapeDoublePageActive()) {
        Row() {
          this.readerV2PageSurface(`${controllerRole}_left`, this.pageTurnIncomingChapterIndex,
            this.pageTurnIncomingPageIndex, this.pageTurnIncomingDocumentSource, true)
          Blank()
            .width(READER_DOUBLE_PAGE_DIVIDER_WIDTH)
            .height('88%')
            .backgroundColor(this.getSubTextColor())
            .opacity(0.22)
          this.readerV2PageSurface(`${controllerRole}_right`, this.pageTurnIncomingChapterIndex,
            this.pageTurnIncomingPageIndex + 1, this.pageTurnIncomingDocumentSource, true)
        }
        .width('100%')
        .height('100%')
        .alignItems(VerticalAlign.Center)
      } else {
        this.readerV2PageSurface(`${controllerRole}_single`, this.pageTurnIncomingChapterIndex,
          this.pageTurnIncomingPageIndex, this.pageTurnIncomingDocumentSource)
      }
    } else if (this.isLandscapeDoublePageActive()) {
      Row() {
        Column() {
          this.styledReaderText(text, this.getReaderContentBottomPadding(), this.pageTurnIncomingChapterIndex, 0,
            renderVersion, `${this.incomingReaderPageRenderIdentity(renderVersion, text)}_left`,
            this.pageTurnIncomingPageIndex, this.getEffectiveReaderMarginTop(), this.pageTurnIncomingPageStart,
            this.pageTurnIncomingDocumentSource)
        }
        .layoutWeight(1)
        .height('100%')

        Blank()
          .width(READER_DOUBLE_PAGE_DIVIDER_WIDTH)
          .height('88%')
          .backgroundColor(this.getSubTextColor())
          .opacity(0.22)

        Column() {
          this.styledReaderText(this.pageTurnIncomingSecondaryText, this.getReaderContentBottomPadding(),
            this.pageTurnIncomingChapterIndex, 0, renderVersion,
            `${this.incomingReaderPageRenderIdentity(renderVersion, text)}_right`, this.pageTurnIncomingPageIndex + 1,
            this.getEffectiveReaderMarginTop(), this.pageTurnIncomingSecondaryPageStart,
            this.pageTurnIncomingDocumentSource)
        }
        .layoutWeight(1)
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.readerContentLayerColor())
    } else {
      Column() {
        this.styledReaderText(text, this.getReaderContentBottomPadding(),
          this.pageTurnIncomingChapterIndex, 0,
          renderVersion, this.incomingReaderPageRenderIdentity(renderVersion, text), this.pageTurnIncomingPageIndex,
          this.getEffectiveReaderMarginTop(), this.pageTurnIncomingPageStart, this.pageTurnIncomingDocumentSource)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(this.readerContentLayerColor())
      .id(`reader_incoming_layer_${this.incomingReaderPageRenderIdentity(renderVersion, text)}`)
    }
  }

  currentReaderPageRenderIdentity(renderVersion: number = this.pageRenderVersion,
    ttsRenderVersion: number = this.ttsHighlightRenderVersion): string {
    return ReaderHighlightOps.currentReaderPageRenderIdentity(this, renderVersion, ttsRenderVersion);
  }

  incomingReaderPageRenderIdentity(renderVersion: number, text: string): string {
    return ReaderHighlightOps.incomingReaderPageRenderIdentity(this, renderVersion, text);
  }

  effectiveReaderPageRenderIdentity(pageRenderIdentity: string, chapterIndex: number, renderVersion: number,
    ttsRenderVersion: number, text: string): string {
    return ReaderHighlightOps.effectiveReaderPageRenderIdentity(this, pageRenderIdentity, chapterIndex, renderVersion, ttsRenderVersion, text);
  }

  @Builder
  styledCurrentReaderText(text: string, bottomPadding: number, chapterIndex: number = this.currentChapterIndex,
    ttsRenderVersion: number = this.ttsHighlightRenderVersion, contentRenderVersion: number = this.pageRenderVersion,
    pageRenderIdentity: string = this.currentReaderPageRenderIdentity(contentRenderVersion, ttsRenderVersion),
    pageIndex: number = this.currentPageIndex) {
    Column() {
      ForEach(this.getReaderTextParagraphGroups(text), (group: ReaderTextParagraphGroup) => {
        this.styledReaderParagraphGroup(group, chapterIndex, this.hasActiveTtsHighlight(text), ttsRenderVersion,
          contentRenderVersion, pageRenderIdentity, this.getPageStartOffset(pageIndex), this.pagedContentText,
          this.getReaderAdaptivePageLineHeight(text, chapterIndex, pageIndex,
            this.getPageStartOffset(pageIndex), this.pagedContentText))
      }, (group: ReaderTextParagraphGroup) => `${pageRenderIdentity}_${group.key}`)
    }
    .width('100%')
    .id(`reader_text_${pageRenderIdentity}`)
    .padding({
      left: LeafFns.getReaderPageHorizontalPadding(text, this.getEffectiveReaderMarginLeft()),
      right: LeafFns.getReaderPageHorizontalPadding(text, this.getEffectiveReaderMarginRight()),
      top: LeafFns.getReaderPageVerticalPadding(text, this.getEffectiveReaderMarginTop()),
      bottom: LeafFns.getReaderPageVerticalPadding(text, bottomPadding)
    })
  }
//endregion
//region 样式化正文 / 段评·源动作·文本选择 / 正则高亮 / V2布局·分页·选区·高亮
// [map] 契约: 读 高亮偏移/正则规则/主题; V2 分页与选区是独立大子系统, 建议优先外移

  @Builder
  styledReaderText(text: string, bottomPadding: number, chapterIndex: number = this.currentChapterIndex,
    ttsRenderVersion: number = this.ttsHighlightRenderVersion, contentRenderVersion: number = this.pageRenderVersion,
    pageRenderIdentity: string = LeafFns.readerPageRenderIdentity('text', chapterIndex, this.currentPageIndex,
      contentRenderVersion, ttsRenderVersion, text), pageIndex: number = this.currentPageIndex,
    topPadding: number = this.getEffectiveReaderMarginTop(), pageStartOverride: number = -2,
    documentSourceOverride: string = '') {
    Column() {
      ForEach(this.getReaderTextParagraphGroups(text), (group: ReaderTextParagraphGroup) => {
        this.styledReaderParagraphGroup(group, chapterIndex, this.hasActiveTtsHighlight(text), ttsRenderVersion,
          contentRenderVersion, pageRenderIdentity,
          pageStartOverride >= -1 ? pageStartOverride :
            (chapterIndex === this.currentChapterIndex ? this.getPageStartOffset(pageIndex) : -1),
          documentSourceOverride || (chapterIndex === this.currentChapterIndex ? this.pagedContentText : ''),
          this.getReaderAdaptivePageLineHeight(text, chapterIndex, pageIndex,
            pageStartOverride >= -1 ? pageStartOverride :
              (chapterIndex === this.currentChapterIndex ? this.getPageStartOffset(pageIndex) : -1),
            documentSourceOverride || (chapterIndex === this.currentChapterIndex ? this.pagedContentText : '')))
      }, (group: ReaderTextParagraphGroup) => `${pageRenderIdentity}_${group.key}`)
    }
    .width('100%')
    .id(`reader_text_${pageRenderIdentity}`)
    .padding({
      left: LeafFns.getReaderPageHorizontalPadding(text, this.getEffectiveReaderMarginLeft()),
      right: LeafFns.getReaderPageHorizontalPadding(text, this.getEffectiveReaderMarginRight()),
      top: LeafFns.getReaderPageVerticalPadding(text, topPadding),
      bottom: LeafFns.getReaderPageVerticalPadding(text, bottomPadding)
    })
  }

  getReaderTextParagraphGroups(text: string): ReaderTextParagraphGroup[] {
    return ReaderStyledTextOps.getReaderTextParagraphGroups(this, text);
  }

  readerParagraphRendersAsIndependentComponent(text: string): boolean {
    return ReaderStyledTextOps.readerParagraphRendersAsIndependentComponent(this, text);
  }

  @Builder
  styledReaderParagraphGroup(group: ReaderTextParagraphGroup, chapterIndex: number,
    ttsHighlightActive: boolean, ttsRenderVersion: number, contentRenderVersion: number,
    pageRenderIdentity: string, pageStart: number, documentSource: string, pageLineHeight: number) {
    if (group.mergeable) {
      this.styledMergedReaderParagraphs(group.paragraphs, chapterIndex, ttsHighlightActive, ttsRenderVersion,
        contentRenderVersion, `${pageRenderIdentity}_${group.key}`, pageStart, documentSource, pageLineHeight)
      if (!group.paragraphs[group.paragraphs.length - 1].isLast) {
        ReaderParagraphGap({ gapHeight: this.getReaderParagraphBoundarySpacing(pageLineHeight) })
      }
    } else {
      ForEach(group.paragraphs, (paragraph: ReaderTextParagraph) => {
        this.styledReaderParagraph(paragraph, chapterIndex, ttsHighlightActive, ttsRenderVersion,
          contentRenderVersion, pageRenderIdentity, pageStart, documentSource, pageLineHeight)
        if (!paragraph.isLast) {
          ReaderParagraphGap({ gapHeight: this.getReaderParagraphBoundarySpacing(pageLineHeight) })
        }
      }, (paragraph: ReaderTextParagraph) => `${pageRenderIdentity}_${paragraph.key}`)
    }
  }

  mergedReaderParagraphText(paragraphs: ReaderTextParagraph[]): string {
    return ReaderStyledTextOps.mergedReaderParagraphText(this, paragraphs);
  }

  @Builder
  styledMergedReaderParagraphs(paragraphs: ReaderTextParagraph[], chapterIndex: number,
    ttsHighlightActive: boolean, ttsRenderVersion: number, contentRenderVersion: number,
    pageRenderIdentity: string, pageStart: number, documentSource: string, pageLineHeight: number) {
    Text('', { controller: this.readerSelectableTextController(LeafFns.readerSelectablePageTextKey(
      pageRenderIdentity, contentRenderVersion, ttsRenderVersion, this.mergedReaderParagraphText(paragraphs))) }) {
      ForEach(paragraphs, (paragraph: ReaderTextParagraph, paragraphIndex: number) => {
        if (paragraphIndex > 0) {
          Span('\n')
            .fontSize(this.readerFontSize)
            .fontFamily(this.getBodyReaderFontFamily())
        }
        if (this.hasInlineReaderSourceAction(paragraph.text)) {
          if (this.shouldUseTitleStyle(paragraph.text, chapterIndex)) {
            ForEach(this.getTitleTextSlices(this.readerInlineSourceActionParagraphData(paragraph), chapterIndex,
              ttsHighlightActive), (slice: ReadTextSlice) => {
              Span(slice.text)
                .fontSize(this.readerTitleFontSize)
                .fontFamily(this.getTitleReaderFontFamily())
                .fontColor(slice.ttsHighlighted ? this.getTtsHighlightTextColor() : this.getTextColor())
                .textBackgroundStyle(slice.ttsHighlighted ? {
                  color: this.getTtsHighlightColor(),
                  radius: 4
                } : {})
            }, (slice: ReadTextSlice) =>
              `merged_inline_title_${pageRenderIdentity}_${paragraph.key}_${slice.key}`)
          } else {
            ForEach(this.getStyledParagraphTextSlices(this.readerInlineSourceActionParagraphData(paragraph),
              ttsHighlightActive, pageStart, documentSource), (slice: ReadTextSlice) => {
              this.styledRegexSlice(slice)
            }, (slice: ReadTextSlice) =>
              `merged_inline_${pageRenderIdentity}_${paragraph.key}_${slice.key}`)
          }
          Span(this.readerInlineSourceActionLabel(paragraph.text))
            .fontSize(this.readerInlineSourceActionFontSize(paragraph.text))
            .fontFamily(LeafFns.readerInlineSourceActionFontFamily())
            .fontColor(this.readerInlineSourceActionFontColor(paragraph.text))
            .textBackgroundStyle({
              color: this.readerInlineSourceActionBackgroundColor(paragraph.text),
              radius: this.readerInlineSourceActionRadius(paragraph.text)
            })
            .textShadow(this.readerInlineSourceActionTextShadow(paragraph.text))
            .onClick(() => {
              const match = this.readerInlineSourceActionMatch(paragraph.text);
              if (match) {
                this.beginReaderInteractiveAction();
                this.openReaderSourceAction(match.marker);
              }
            })
        } else if (this.shouldUseTitleStyle(paragraph.text, chapterIndex)) {
          ForEach(this.getTitleTextSlices(paragraph, chapterIndex, ttsHighlightActive), (slice: ReadTextSlice) => {
            Span(slice.text)
              .fontSize(this.readerTitleFontSize)
              .fontFamily(this.getTitleReaderFontFamily())
              .fontColor(slice.ttsHighlighted ? this.getTtsHighlightTextColor() : this.getTextColor())
              .textBackgroundStyle(slice.ttsHighlighted ? {
                color: this.getTtsHighlightColor(),
                radius: 4
              } : {})
          }, (slice: ReadTextSlice) =>
            `merged_title_${pageRenderIdentity}_${paragraph.key}_${slice.key}`)
          ForEach(this.getTitleBodyTextSlices(paragraph, chapterIndex, ttsHighlightActive, pageStart,
            documentSource), (slice: ReadTextSlice) => {
            this.styledRegexSlice(slice)
          }, (slice: ReadTextSlice) =>
            `merged_title_body_${pageRenderIdentity}_${paragraph.key}_${slice.key}`)
        } else {
          ForEach(this.getStyledParagraphTextSlices(paragraph, ttsHighlightActive, pageStart, documentSource),
            (slice: ReadTextSlice) => {
            this.styledRegexSlice(slice)
          }, (slice: ReadTextSlice) =>
            `merged_body_${pageRenderIdentity}_${paragraph.key}_${slice.key}`)
        }
      }, (paragraph: ReaderTextParagraph) => `merged_${pageRenderIdentity}_${paragraph.key}`)
    }
    .lineSpacing(LengthMetrics.vp(this.getReaderPageLineSpacing(pageLineHeight)), { onlyBetweenLines: true })
    .halfLeading(false)
    .includeFontPadding(false)
    .fontColor(this.getTextColor())
    .letterSpacing(this.getReaderAdaptiveLetterSpacing())
    .textAlign(this.readerTextAlignValue())
    .wordBreak(WordBreak.BREAK_WORD)
    .lineBreakStrategy(LineBreakStrategy.GREEDY)
    .copyOption(CopyOptions.LocalDevice)
    .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
    .editMenuOptions(this.readerTextEditMenuOptions(() => this.mergedReaderParagraphText(paragraphs)))
    .onCopy(() => this.scheduleReaderTextSelectionClear())
    .width('100%')
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      const mergedText = this.mergedReaderParagraphText(paragraphs);
      const selectableKey = LeafFns.readerSelectablePageTextKey(pageRenderIdentity, contentRenderVersion,
        ttsRenderVersion, mergedText);
      this.rememberReaderSelectableText(
        selectableKey,
        mergedText,
        newValue,
        this.readerSelectableTextController(selectableKey)
      );
      this.rememberMergedReaderInlineSourceActionAreas(paragraphs, selectableKey, pageRenderIdentity, newValue);
      this.calibrateReaderPaginationHeightFromMergedText(paragraphs, chapterIndex, pageStart, documentSource,
        pageLineHeight, newValue);
      this.scheduleReaderPaginationBottomFitCalibration(paragraphs, chapterIndex, pageStart, newValue);
    })
    .id(`reader_merged_${pageRenderIdentity}_${LeafFns.buildTextSliceKey(this.mergedReaderParagraphText(paragraphs))}`)
  }

  rememberMergedReaderInlineSourceActionAreas(paragraphs: ReaderTextParagraph[], selectableKey: string,
    pageIdentity: string, area: Area): void {
    ReaderStyledTextOps.rememberMergedReaderInlineSourceActionAreas(this, paragraphs, selectableKey, pageIdentity, area);
  }

  registerMergedReaderInlineSourceActionBounds(task: ReaderMergedActionBoundsTask, visibleText: string): boolean {
    return ReaderStyledTextOps.registerMergedReaderInlineSourceActionBounds(this, task, visibleText);
  }

  @Builder
  styledReaderParagraph(paragraph: ReaderTextParagraph, chapterIndex: number = this.currentChapterIndex,
    ttsHighlightActive: boolean = true, ttsRenderVersion: number = this.ttsHighlightRenderVersion,
    contentRenderVersion: number = this.pageRenderVersion, pageRenderIdentity: string = '', pageStart: number = -1,
    documentSource: string = this.pagedContentText, pageLineHeight: number = this.getEffectiveReaderLineHeight()) {
    if (LocalBookService.isEpubImageMarker(paragraph.text)) {
      ReaderEpubImage({ marker: paragraph.text, imageHeight: this.getReaderEpubImageHeight() })
    } else if (this.hasInlineReaderSourceAction(paragraph.text)) {
      this.readerInlineSourceActionParagraph(paragraph, chapterIndex, ttsHighlightActive, ttsRenderVersion,
        contentRenderVersion, pageRenderIdentity, pageStart, documentSource, pageLineHeight)
    } else if (ReaderActionMarker.parse(paragraph.text)) {
      ReaderSourceActionButton({
        marker: paragraph.text,
        label: (ReaderActionMarker.parse(paragraph.text)?.label || '打开'),
        textColor: this.getTextColor(),
        fontSize: this.readerFontSize,
        onAreaChanged: (area: Area): void => { this.rememberReaderSourceActionArea(paragraph.text, area); },
        onActivate: (): void => {
          this.beginReaderInteractiveAction();
          this.openReaderSourceAction(paragraph.text);
        }
      })
    } else if (this.shouldUseTitleStyle(paragraph.text, chapterIndex)) {
      Text('', { controller: this.readerSelectableTextController(
        LeafFns.readerSelectableTextKey('title', pageRenderIdentity, contentRenderVersion, ttsRenderVersion,
          paragraph)) }) {
        ForEach(this.getTitleTextSlices(paragraph, chapterIndex, ttsHighlightActive), (slice: ReadTextSlice) => {
          Span(slice.text)
            .fontSize(this.readerTitleFontSize)
            .fontFamily(this.getTitleReaderFontFamily())
            .fontColor(slice.ttsHighlighted ? this.getTtsHighlightTextColor() : this.getTextColor())
            .textBackgroundStyle(slice.ttsHighlighted ? {
              color: this.getTtsHighlightColor(),
              radius: 4
            } : {})
        }, (slice: ReadTextSlice) =>
          `title_${this.effectiveReaderPageRenderIdentity(pageRenderIdentity, chapterIndex, contentRenderVersion,
            ttsRenderVersion, paragraph.text)}_${paragraph.key}_${slice.key}`)
        ForEach(this.getTitleBodyTextSlices(paragraph, chapterIndex, ttsHighlightActive, pageStart, documentSource),
          (slice: ReadTextSlice) => {
          this.styledRegexSlice(slice)
        }, (slice: ReadTextSlice) =>
          `title_body_${this.effectiveReaderPageRenderIdentity(pageRenderIdentity, chapterIndex, contentRenderVersion,
            ttsRenderVersion, paragraph.text)}_${paragraph.key}_${slice.key}`)
      }
      .lineSpacing(LengthMetrics.vp(this.getReaderPageLineSpacing(pageLineHeight)), { onlyBetweenLines: true })
      .halfLeading(false)
      .includeFontPadding(false)
      .fontColor(this.getTextColor())
      .letterSpacing(this.getReaderAdaptiveLetterSpacing())
      .textAlign(this.readerTextAlignValue())
      .wordBreak(WordBreak.BREAK_WORD)
      .lineBreakStrategy(LineBreakStrategy.GREEDY)
      .copyOption(CopyOptions.LocalDevice)
      .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
      .editMenuOptions(this.readerTextEditMenuOptions(() => paragraph.text))
      .onCopy(() => this.scheduleReaderTextSelectionClear())
      .width('100%')
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        this.rememberReaderSelectableText(
          LeafFns.readerSelectableTextKey('title', pageRenderIdentity, contentRenderVersion, ttsRenderVersion,
            paragraph),
          paragraph.text,
          newValue
        );
      })
      .id(`reader_title_${this.effectiveReaderPageRenderIdentity(pageRenderIdentity, chapterIndex, contentRenderVersion,
        ttsRenderVersion, paragraph.text)}_${paragraph.key}`)
    } else if (this.readerRegexFontEnabled) {
      this.regexReaderText(paragraph, ttsHighlightActive, ttsRenderVersion, contentRenderVersion,
        this.effectiveReaderPageRenderIdentity(pageRenderIdentity, chapterIndex, contentRenderVersion,
          ttsRenderVersion, paragraph.text), pageStart, documentSource, pageLineHeight)
    } else {
      Text('', { controller: this.readerSelectableTextController(
        LeafFns.readerSelectableTextKey('plain', pageRenderIdentity, contentRenderVersion, ttsRenderVersion,
          paragraph)) }) {
        ForEach(this.getStyledParagraphTextSlices(paragraph, ttsHighlightActive, pageStart, documentSource),
          (slice: ReadTextSlice) => {
          Span(slice.text)
            .fontSize(this.readerFontSize)
            .fontFamily(this.getBodyReaderFontFamily())
            .fontColor(this.getStyledSliceFontColor(slice))
            .textBackgroundStyle(this.getStyledSliceBackgroundStyle(slice))
            .textShadow(this.getStyledSliceTextShadow(slice))
            .decoration(this.getStyledSliceDecoration(slice))
        }, (slice: ReadTextSlice) =>
          `${this.effectiveReaderPageRenderIdentity(pageRenderIdentity, chapterIndex, contentRenderVersion,
            ttsRenderVersion, paragraph.text)}_${paragraph.key}_${slice.key}`)
      }
        .lineSpacing(LengthMetrics.vp(this.getReaderPageLineSpacing(pageLineHeight)), { onlyBetweenLines: true })
        .halfLeading(false)
        .includeFontPadding(false)
        .fontColor(this.getTextColor())
        .letterSpacing(this.getReaderAdaptiveLetterSpacing())
        .textAlign(this.readerTextAlignValue())
        .wordBreak(WordBreak.BREAK_WORD)
        .lineBreakStrategy(LineBreakStrategy.GREEDY)
        .copyOption(CopyOptions.LocalDevice)
        .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
        .editMenuOptions(this.readerTextEditMenuOptions(() => paragraph.text))
        .onCopy(() => this.scheduleReaderTextSelectionClear())
        .width('100%')
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          this.rememberReaderSelectableText(
            LeafFns.readerSelectableTextKey('plain', pageRenderIdentity, contentRenderVersion, ttsRenderVersion,
              paragraph),
            paragraph.text,
            newValue
          );
        })
        .id(`reader_plain_${this.effectiveReaderPageRenderIdentity(pageRenderIdentity, chapterIndex,
          contentRenderVersion, ttsRenderVersion, paragraph.text)}_${paragraph.key}`)
    }
  }

  hasInlineReaderSourceAction(text: string): boolean {
    return ReaderStyledTextOps.hasInlineReaderSourceAction(this, text);
  }

  readerInlineSourceActionMatch(text: string): ReaderActionMatch | null {
    return ReaderStyledTextOps.readerInlineSourceActionMatch(this, text);
  }

  @Builder
  readerInlineSourceActionParagraph(paragraph: ReaderTextParagraph, chapterIndex: number = this.currentChapterIndex,
    ttsHighlightActive: boolean = true, ttsRenderVersion: number = this.ttsHighlightRenderVersion,
    contentRenderVersion: number = this.pageRenderVersion, pageRenderIdentity: string = '', pageStart: number = -1,
    documentSource: string = this.pagedContentText, pageLineHeight: number = this.getEffectiveReaderLineHeight()) {
    Text('', { controller: this.readerInlineActionTextController(paragraph.text) }) {
      if (this.shouldUseTitleStyle(paragraph.text, chapterIndex)) {
        ForEach(this.getTitleTextSlices(this.readerInlineSourceActionParagraphData(paragraph), chapterIndex,
          ttsHighlightActive), (slice: ReadTextSlice) => {
          Span(slice.text)
            .fontSize(this.readerTitleFontSize)
            .fontFamily(this.getTitleReaderFontFamily())
            .fontColor(slice.ttsHighlighted ? this.getTtsHighlightTextColor() : this.getTextColor())
            .textBackgroundStyle(slice.ttsHighlighted ? {
              color: this.getTtsHighlightColor(),
              radius: 4
            } : {})
        }, (slice: ReadTextSlice) =>
          `inline_title_${this.effectiveReaderPageRenderIdentity(pageRenderIdentity, chapterIndex,
            contentRenderVersion, ttsRenderVersion, paragraph.text)}_${paragraph.key}_${slice.key}`)
      } else {
        ForEach(this.getStyledParagraphTextSlices(this.readerInlineSourceActionParagraphData(paragraph),
          ttsHighlightActive, pageStart, documentSource), (slice: ReadTextSlice) => {
          this.styledRegexSlice(slice)
        }, (slice: ReadTextSlice) =>
          `inline_${this.effectiveReaderPageRenderIdentity(pageRenderIdentity, chapterIndex, contentRenderVersion,
            ttsRenderVersion, paragraph.text)}_${paragraph.key}_${slice.key}`)
      }
      Span(this.readerInlineSourceActionLabel(paragraph.text))
        .fontSize(this.readerInlineSourceActionFontSize(paragraph.text))
        .fontFamily(LeafFns.readerInlineSourceActionFontFamily())
        .fontColor(this.readerInlineSourceActionFontColor(paragraph.text))
        .textBackgroundStyle({
          color: this.readerInlineSourceActionBackgroundColor(paragraph.text),
          radius: this.readerInlineSourceActionRadius(paragraph.text)
        })
        .textShadow(this.readerInlineSourceActionTextShadow(paragraph.text))
        .onClick(() => {
          const match = this.readerInlineSourceActionMatch(paragraph.text);
          if (match) {
            this.beginReaderInteractiveAction();
            this.openReaderSourceAction(match.marker);
          }
        })
    }
    .lineSpacing(LengthMetrics.vp(this.getReaderPageLineSpacing(pageLineHeight)), { onlyBetweenLines: true })
    .halfLeading(false)
    .includeFontPadding(false)
    .fontColor(this.getTextColor())
    .letterSpacing(this.getReaderAdaptiveLetterSpacing())
    .textAlign(this.readerTextAlignValue())
    .wordBreak(WordBreak.BREAK_WORD)
    .lineBreakStrategy(LineBreakStrategy.GREEDY)
    .copyOption(CopyOptions.LocalDevice)
    .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
    .editMenuOptions(this.readerTextEditMenuOptions(() => paragraph.text))
    .onCopy(() => this.scheduleReaderTextSelectionClear())
    .width('100%')
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.rememberReaderInlineSourceActionArea(paragraph.text, pageRenderIdentity, newValue);
      this.rememberReaderSelectableText(
        LeafFns.readerSelectableTextKey('inline', pageRenderIdentity, contentRenderVersion, ttsRenderVersion,
          paragraph),
        paragraph.text,
        newValue,
        this.readerInlineActionTextController(paragraph.text)
      );
    })
    .onClick((event: ClickEvent) => {
      const match = this.readerInlineSourceActionMatch(paragraph.text);
      if (match && this.isReaderInlineActionTextPoint(paragraph.text, event.x, event.y)) {
        this.beginReaderInteractiveAction();
        this.openReaderSourceAction(match.marker);
      }
    })
    .onTouch((event: TouchEvent) => this.handleReaderInlineActionTextTouch(paragraph.text, event))
    .id(`reader_inline_${this.effectiveReaderPageRenderIdentity(pageRenderIdentity, chapterIndex,
      contentRenderVersion, ttsRenderVersion, paragraph.text)}_${paragraph.key}`)
  }

  readerInlineActionTextController(text: string): TextController {
    return ReaderStyledTextOps.readerInlineActionTextController(this, text);
  }

  handleReaderInlineActionTextTouch(text: string, event: TouchEvent): void {
    ReaderStyledTextOps.handleReaderInlineActionTextTouch(this, text, event);
  }

  isReaderInlineActionTextPoint(text: string, x: number, y: number): boolean {
    return ReaderStyledTextOps.isReaderInlineActionTextPoint(this, text, x, y);
  }

  readerInlineActionExpectedWidth(): number {
    return ReaderStyledTextOps.readerInlineActionExpectedWidth(this);
  }

  readerInlineActionLocalBounds(text: string, componentWidth: number, componentHeight: number): number[] {
    return ReaderStyledTextOps.readerInlineActionLocalBounds(this, text, componentWidth, componentHeight);
  }

  rememberReaderInlineSourceActionArea(text: string, pageIdentity: string, area: Area): void {
    ReaderStyledTextOps.rememberReaderInlineSourceActionArea(this, text, pageIdentity, area);
  }

  clearPendingReaderSourceActionBounds(): void {
    ReaderStyledTextOps.clearPendingReaderSourceActionBounds(this);
  }

  scheduleReaderSourceActionBoundsFlush(delayMs: number = 0): void {
    ReaderStyledTextOps.scheduleReaderSourceActionBoundsFlush(this, delayMs);
  }

  flushPendingReaderSourceActionBounds(): void {
    ReaderStyledTextOps.flushPendingReaderSourceActionBounds(this);
  }

  registerReaderInlineSourceActionBounds(text: string, marker: string, left: number, top: number,
    width: number, height: number): boolean {
    return ReaderStyledTextOps.registerReaderInlineSourceActionBounds(this, text, marker, left, top, width, height);
  }

  readerInlineSourceActionParagraphData(paragraph: ReaderTextParagraph): ReaderTextParagraph {
    return ReaderStyledTextOps.readerInlineSourceActionParagraphData(this, paragraph);
  }

  readerInlineSourceActionText(text: string): string {
    return ReaderStyledTextOps.readerInlineSourceActionText(this, text);
  }

  readerInlineSourceActionLabel(text: string): string {
    return ReaderStyledTextOps.readerInlineSourceActionLabel(this, text);
  }

  readerInlineSourceActionFontSize(text: string): number {
    return ReaderStyledTextOps.readerInlineSourceActionFontSize(this, text);
  }

  readerInlineSourceActionFontColor(text: string): string {
    return ReaderStyledTextOps.readerInlineSourceActionFontColor(this, text);
  }

  readerInlineSourceActionBackgroundColor(text: string): string {
    return ReaderStyledTextOps.readerInlineSourceActionBackgroundColor(this, text);
  }

  readerInlineSourceActionRadius(text: string): number {
    return ReaderStyledTextOps.readerInlineSourceActionRadius(this, text);
  }

  readerInlineSourceActionTextShadow(text: string): ShadowOptions {
    return ReaderStyledTextOps.readerInlineSourceActionTextShadow(this, text);
  }

  readerUsesConfiguredCommentBubble(text: string): boolean {
    return ReaderStyledTextOps.readerUsesConfiguredCommentBubble(this, text);
  }

  readerSourceSettingValue(key: string): string {
    return ReaderStyledTextOps.readerSourceSettingValue(this, key);
  }

  ensureReaderSourceSettingCache(source: BookSource): void {
    ReaderStyledTextOps.ensureReaderSourceSettingCache(this, source);
  }

  readerSourceSettingEnabled(key: string): boolean {
    return ReaderStyledTextOps.readerSourceSettingEnabled(this, key);
  }

  readerSourceColorSetting(key: string, fallback: string): string {
    return ReaderStyledTextOps.readerSourceColorSetting(this, key, fallback);
  }

  beginReaderInteractiveAction(): void {
    ReaderStyledTextOps.beginReaderInteractiveAction(this);
  }

  setReaderTextSelectionActive(active: boolean): void {
    ReaderStyledTextOps.setReaderTextSelectionActive(this, active);
  }

  /**
   * A selection can be live in three shapes: the continuous-scroll flag, the V2 native selection host
   * mounted over the page, and the V2 painted overlay. All three must be treated as "selecting" so a
   * tap outside the selection dismisses instead of turning the page or opening the menu.
   */
  hasReaderTextSelection(): boolean {
    return ReaderStyledTextOps.hasReaderTextSelection(this);
  }

  /**
   * Dismisses an active selection without running the action the tap would otherwise perform, so a tap
   * outside the selection cancels it instead of turning the page or opening the reader menu. Handle drags
   * (movement) are left to the native selection so the range can still be adjusted. Dismissal only arms
   * for a pointer whose Down began while the selection was already live; the release of the press that
   * created the selection passes through here on Up and must never clear it.
   */
  handleReaderSelectionDismissTouch(event: TouchEvent): boolean {
    return ReaderStyledTextOps.handleReaderSelectionDismissTouch(this, event);
  }

  isReaderInteractiveActionActive(): boolean {
    return ReaderStyledTextOps.isReaderInteractiveActionActive(this);
  }

  rememberReaderSourceActionArea(marker: string, area: Area): void {
    ReaderStyledTextOps.rememberReaderSourceActionArea(this, marker, area);
  }

  rememberReaderSourceActionBounds(marker: string, left: number, top: number, right: number, bottom: number): void {
    ReaderStyledTextOps.rememberReaderSourceActionBounds(this, marker, left, top, right, bottom);
  }

  rememberReaderTapLayerArea(area: Area): void {
    ReaderStyledTextOps.rememberReaderTapLayerArea(this, area);
  }



  currentContinuousReaderScrollOffset(): number {
    return ReaderStyledTextOps.currentContinuousReaderScrollOffset(this);
  }

  rememberContinuousReaderPointer(event: TouchEvent): void {
    ReaderStyledTextOps.rememberContinuousReaderPointer(this, event);
  }

  handleContinuousReaderShortTap(globalX: number, globalY: number): void {
    ReaderStyledTextOps.handleContinuousReaderShortTap(this, globalX, globalY);
  }

  cancelContinuousReaderSelectionTimer(): void {
    ReaderStyledTextOps.cancelContinuousReaderSelectionTimer(this);
  }

  readerContinuousGesturePoint(event: GestureEvent): number[] {
    return ReaderStyledTextOps.readerContinuousGesturePoint(this, event);
  }

  readerSourceActionAtPoint(globalX: number, globalY: number): string {
    return ReaderStyledTextOps.readerSourceActionAtPoint(this, globalX, globalY);
  }

  openReaderSourceAction(marker: string): void {
    ReaderStyledTextOps.openReaderSourceAction(this, marker);
  }


  async openReaderSourceScriptAction(source: BookSource, action: ReaderActionData, marker: string): Promise<void> {
    return ReaderStyledTextOps.openReaderSourceScriptAction(this, source, action, marker);
  }

  openReaderCommentPanel(url: string, title: string, marker: string, sourceHtml: string = ''): void {
    ReaderStyledTextOps.openReaderCommentPanel(this, url, title, marker, sourceHtml);
  }

  loadReaderCommentPanelHtmlIfNeeded(): boolean {
    return ReaderStyledTextOps.loadReaderCommentPanelHtmlIfNeeded(this);
  }

  scheduleReaderCommentPanelHostReady(delayMs: number): void {
    ReaderStyledTextOps.scheduleReaderCommentPanelHostReady(this, delayMs);
  }

  closeReaderCommentPanel(): void {
    ReaderStyledTextOps.closeReaderCommentPanel(this);
  }

  async syncReaderCommentPanelWebTheme(): Promise<void> {
    return ReaderStyledTextOps.syncReaderCommentPanelWebTheme(this);
  }

  readerCommentPanelHeight(): number {
    return ReaderStyledTextOps.readerCommentPanelHeight(this);
  }

  readerCommentPanelHeightForRatio(ratio: number): number {
    return ReaderStyledTextOps.readerCommentPanelHeightForRatio(this, ratio);
  }

  readerCommentPanelContentHeight(): number {
    return ReaderStyledTextOps.readerCommentPanelContentHeight(this);
  }


  handleReaderCommentPanelDragTouch(event: TouchEvent): void {
    ReaderStyledTextOps.handleReaderCommentPanelDragTouch(this, event);
  }

  getReaderSourceActionAnchorBottom(marker: string): number {
    return ReaderStyledTextOps.getReaderSourceActionAnchorBottom(this, marker);
  }

  getReaderEpubImageHeight(): number {
    return ReaderStyledTextOps.getReaderEpubImageHeight(this);
  }

  @Builder
  regexReaderText(paragraph: ReaderTextParagraph, ttsHighlightActive: boolean = true,
    ttsRenderVersion: number = this.ttsHighlightRenderVersion, contentRenderVersion: number = this.pageRenderVersion,
    pageRenderIdentity: string = '', pageStart: number = -1,
    documentSource: string = this.pagedContentText, pageLineHeight: number = this.getEffectiveReaderLineHeight()) {
    Text('', { controller: this.readerSelectableTextController(
      LeafFns.readerSelectableTextKey('regex', pageRenderIdentity, contentRenderVersion, ttsRenderVersion, paragraph)) }) {
      ForEach(this.getStyledParagraphTextSlices(paragraph, ttsHighlightActive, pageStart, documentSource),
        (slice: ReadTextSlice) => {
        this.styledRegexSlice(slice)
      }, (slice: ReadTextSlice) =>
        `${this.effectiveReaderPageRenderIdentity(pageRenderIdentity, this.currentChapterIndex, contentRenderVersion,
          ttsRenderVersion, paragraph.text)}_${paragraph.key}_${slice.key}`)
    }
    .lineSpacing(LengthMetrics.vp(this.getReaderPageLineSpacing(pageLineHeight)), { onlyBetweenLines: true })
    .halfLeading(false)
    .includeFontPadding(false)
    .fontColor(this.getTextColor())
    .letterSpacing(this.getReaderAdaptiveLetterSpacing())
    .textAlign(this.readerTextAlignValue())
    .wordBreak(WordBreak.BREAK_WORD)
    .lineBreakStrategy(LineBreakStrategy.GREEDY)
    .copyOption(CopyOptions.LocalDevice)
    .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
    .editMenuOptions(this.readerTextEditMenuOptions(() => paragraph.text))
    .onCopy(() => this.scheduleReaderTextSelectionClear())
    .width('100%')
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.rememberReaderSelectableText(
        LeafFns.readerSelectableTextKey('regex', pageRenderIdentity, contentRenderVersion, ttsRenderVersion, paragraph),
        paragraph.text,
        newValue
      );
    })
    .id(`reader_regex_${this.effectiveReaderPageRenderIdentity(pageRenderIdentity, this.currentChapterIndex,
      contentRenderVersion, ttsRenderVersion, paragraph.text)}_${paragraph.key}`)
  }


  readerSelectableTextController(key: string): TextController {
    return ReaderStyledTextOps.readerSelectableTextController(this, key);
  }

  rememberReaderSelectableText(key: string, text: string, area: Area,
    controller: TextController | null = null): void {
    ReaderStyledTextOps.rememberReaderSelectableText(this, key, text, area, controller);
  }

  selectReaderTextAtGlobalPoint(event: GestureEvent): void {
    ReaderStyledTextOps.selectReaderTextAtGlobalPoint(this, event);
  }

  selectReaderTextAtPoint(globalX: number, globalY: number): void {
    ReaderStyledTextOps.selectReaderTextAtPoint(this, globalX, globalY);
  }

  selectLegacyReaderTextAtGlobalPoint(globalX: number, globalY: number, serial: number, attempt: number): void {
    ReaderStyledTextOps.selectLegacyReaderTextAtGlobalPoint(this, globalX, globalY, serial, attempt);
  }

  isVisibleContinuousSelectionKey(key: string): boolean {
    return ReaderStyledTextOps.isVisibleContinuousSelectionKey(this, key);
  }

  retryReaderTextSelection(serial: number, attempt: number, action: (attempt: number) => void): void {
    ReaderStyledTextOps.retryReaderTextSelection(this, serial, attempt, action);
  }

  continuousSelectionPageIndexForKey(key: string): number {
    return ReaderStyledTextOps.continuousSelectionPageIndexForKey(this, key);
  }

  showReaderTextSelection(key: string, text: string, localX: number, localY: number): boolean {
    return ReaderStyledTextOps.showReaderTextSelection(this, key, text, localX, localY);
  }

  @Builder
  styledRegexSlice(slice: ReadTextSlice) {
    if (this.shouldUseFullThemeRegexDecoration(slice)) {
      ContainerSpan() {
        ImageSpan(ThemeAssetRegistry.regexBubbleCap(this.getRegexSliceBubbleStyleId(slice)))
          .width(this.getRegexBubbleCapSize(slice))
          .height(this.getRegexBubbleCapSize(slice))
          .objectFit(ImageFit.Contain)
          .verticalAlign(ImageSpanAlignment.CENTER)
        Span(slice.text)
          .fontSize(this.getRegexSliceFontSize(slice))
          .fontFamily(this.getRegexSliceFontFamily(slice))
          .fontColor(this.getStyledSliceFontColor(slice))
          .textBackgroundStyle(slice.ttsHighlighted ? {
            color: this.getTtsHighlightColor(),
            radius: 4
          } : {})
          .textShadow(this.getStyledSliceTextShadow(slice))
          .decoration({ type: TextDecorationType.None })
        ImageSpan(ThemeAssetRegistry.regexBubbleCap(this.getRegexSliceBubbleStyleId(slice)))
          .width(this.getRegexBubbleCapSize(slice))
          .height(this.getRegexBubbleCapSize(slice))
          .objectFit(ImageFit.Contain)
          .verticalAlign(ImageSpanAlignment.CENTER)
          .rotate({ angle: 180 })
      }
      .textBackgroundStyle(this.getStyledSliceBackgroundStyle(slice))
    } else {
      Span(slice.text)
        .fontSize(slice.highlighted ? this.getRegexSliceFontSize(slice) : this.readerFontSize)
        .fontFamily(slice.highlighted ? this.getRegexSliceFontFamily(slice) : this.getBodyReaderFontFamily())
        .fontColor(this.getStyledSliceFontColor(slice))
        .textBackgroundStyle(this.getStyledSliceBackgroundStyle(slice))
        .textShadow(this.getStyledSliceTextShadow(slice))
        .decoration(this.getStyledSliceDecoration(slice))
    }
  }

  shouldUseFullThemeRegexDecoration(slice: ReadTextSlice): boolean {
    return ReaderStyledTextOps.shouldUseFullThemeRegexDecoration(this, slice);
  }

  getRegexSliceBubbleStyleId(slice: ReadTextSlice): string {
    return ReaderStyledTextOps.getRegexSliceBubbleStyleId(this, slice);
  }

  getRegexBubbleCapSize(slice: ReadTextSlice): number {
    return ReaderStyledTextOps.getRegexBubbleCapSize(this, slice);
  }

  shouldUseRegexParagraphFrame(paragraph: ReaderTextParagraph, pageStart: number = -1): boolean {
    return ReaderStyledTextOps.shouldUseRegexParagraphFrame(this, paragraph, pageStart);
  }

  getRegexParagraphFrame(paragraph: ReaderTextParagraph, pageStart: number = -1): ResourceStr {
    return ReaderStyledTextOps.getRegexParagraphFrame(this, paragraph, pageStart);
  }

  getRegexParagraphFrameStyleId(paragraph: ReaderTextParagraph, pageStart: number = -1): string {
    return ReaderStyledTextOps.getRegexParagraphFrameStyleId(this, paragraph, pageStart);
  }

  getRegexParagraphFrameStyleIdForText(text: string): string {
    return ReaderStyledTextOps.getRegexParagraphFrameStyleIdForText(this, text);
  }

  getRegexFrameStyleIdFromSlices(slices: ReadTextSlice[]): string {
    return ReaderStyledTextOps.getRegexFrameStyleIdFromSlices(this, slices);
  }

  getRegexFrameHorizontalPadding(paragraph: ReaderTextParagraph, pageStart: number = -1): number {
    return ReaderStyledTextOps.getRegexFrameHorizontalPadding(this, paragraph, pageStart);
  }


  getRegexFrameVerticalPadding(paragraph: ReaderTextParagraph, pageStart: number = -1): number {
    return ReaderStyledTextOps.getRegexFrameVerticalPadding(this, paragraph, pageStart);
  }


  getRegexFrameBackgroundColor(paragraph: ReaderTextParagraph, pageStart: number = -1): string {
    return ReaderStyledTextOps.getRegexFrameBackgroundColor(this, paragraph, pageStart);
  }

  getRegexFrameBorderColor(paragraph: ReaderTextParagraph, pageStart: number = -1): string {
    return ReaderStyledTextOps.getRegexFrameBorderColor(this, paragraph, pageStart);
  }

  getRegexFrameBorderWidth(paragraph: ReaderTextParagraph, pageStart: number = -1): number {
    return ReaderStyledTextOps.getRegexFrameBorderWidth(this, paragraph, pageStart);
  }

  getRegexFrameBorderStyle(paragraph: ReaderTextParagraph, pageStart: number = -1): BorderStyle {
    return ReaderStyledTextOps.getRegexFrameBorderStyle(this, paragraph, pageStart);
  }

  getRegexFrameBorderRadius(paragraph: ReaderTextParagraph, pageStart: number = -1): number {
    return ReaderStyledTextOps.getRegexFrameBorderRadius(this, paragraph, pageStart);
  }

  getRegexFrameHorizontalSlice(paragraph: ReaderTextParagraph, pageStart: number = -1): number {
    return ReaderStyledTextOps.getRegexFrameHorizontalSlice(this, paragraph, pageStart);
  }

  getRegexFrameVerticalSlice(paragraph: ReaderTextParagraph, pageStart: number = -1): number {
    return ReaderStyledTextOps.getRegexFrameVerticalSlice(this, paragraph, pageStart);
  }

  getTitleTextSlices(paragraph: ReaderTextParagraph, chapterIndex: number,
    ttsHighlightActive: boolean = true): ReadTextSlice[] {
    return ReaderStyledTextOps.getTitleTextSlices(this, paragraph, chapterIndex, ttsHighlightActive);
  }

  getTitleBodyTextSlices(paragraph: ReaderTextParagraph, chapterIndex: number,
    ttsHighlightActive: boolean = true, pageStart: number = -1,
    documentSource: string = this.pagedContentText): ReadTextSlice[] {
    return ReaderStyledTextOps.getTitleBodyTextSlices(this, paragraph, chapterIndex, ttsHighlightActive, pageStart, documentSource);
  }

  handleTocCurrentPositionClick(): void {
    ReaderStyledTextOps.handleTocCurrentPositionClick(this);
  }

  submitTocQuickJump(): void {
    ReaderStyledTextOps.submitTocQuickJump(this);
  }

  getStyledParagraphTextSlices(paragraph: ReaderTextParagraph, ttsHighlightActive: boolean = true,
    pageStart: number = -1, documentSource: string = this.pagedContentText): ReadTextSlice[] {
    return ReaderStyledTextOps.getStyledParagraphTextSlices(this, paragraph, ttsHighlightActive, pageStart, documentSource);
  }

  splitSlicesByTtsHighlight(slices: ReadTextSlice[], paragraphStart: number, segmentOffset: number,
    ttsHighlightActive: boolean = true): ReadTextSlice[] {
    return ReaderStyledTextOps.splitSlicesByTtsHighlight(this, slices, paragraphStart, segmentOffset, ttsHighlightActive);
  }

  splitSliceByTtsHighlight(slice: ReadTextSlice, paragraphStart: number, segmentOffset: number,
    ttsHighlightActive: boolean = true): ReadTextSlice[] {
    return ReaderStyledTextOps.splitSliceByTtsHighlight(this, slice, paragraphStart, segmentOffset, ttsHighlightActive);
  }

  getStyledSliceFontColor(slice: ReadTextSlice): string {
    return ReaderStyledTextOps.getStyledSliceFontColor(this, slice);
  }

  getStyledSliceBackgroundStyle(slice: ReadTextSlice): TextBackgroundStyle {
    return ReaderStyledTextOps.getStyledSliceBackgroundStyle(this, slice);
  }

  getStyledSliceTextShadow(slice: ReadTextSlice): ShadowOptions | ShadowOptions[] {
    return ReaderStyledTextOps.getStyledSliceTextShadow(this, slice);
  }

  shouldUseTitleStyle(text: string, chapterIndex: number = this.currentChapterIndex): boolean {
    return ReaderStyledTextOps.shouldUseTitleStyle(this, text, chapterIndex);
  }

  shouldUseRegexStyle(text: string): boolean {
    return ReaderStyledTextOps.shouldUseRegexStyle(this, text);
  }

  hasRegexMatch(text: string): boolean {
    return ReaderStyledTextOps.hasRegexMatch(this, text);
  }

  getRegexRules(): ReaderRegexFontRule[] {
    return ReaderStyledTextOps.getRegexRules(this);
  }



  themeRegexEmphasisColor(): string {
    return ReaderStyledTextOps.themeRegexEmphasisColor(this);
  }

  readerRegexEmphasisContext(): ReaderRegexEmphasisContext {
    return ReaderStyledTextOps.readerRegexEmphasisContext(this);
  }

  resolvedRegexEmphasis(rule: ReaderRegexFontRule | null): ReaderResolvedRegexEmphasis {
    return ReaderStyledTextOps.resolvedRegexEmphasis(this, rule);
  }

  getRegexTextSlices(text: string): ReadTextSlice[] {
    return ReaderStyledTextOps.getRegexTextSlices(this, text);
  }

  /**
   * 从整章的正则匹配结果中截取当前页面/段落。这样匹配范围即使跨过分页点，
   * 两页上的可见部分也会保持同一条高亮规则。
   */
  getRegexTextSlicesAt(text: string, absoluteStart: number,
    documentSource: string = this.pagedContentText): ReadTextSlice[] {
    return ReaderStyledTextOps.getRegexTextSlicesAt(this, text, absoluteStart, documentSource);
  }

  getRegexTextSlicesForDocumentRange(text: string, documentSource: string,
    absoluteStart: number): ReadTextSlice[] {
    return ReaderStyledTextOps.getRegexTextSlicesForDocumentRange(this, text, documentSource, absoluteStart);
  }


  getRegexRuleBySlice(slice: ReadTextSlice): ReaderRegexFontRule | null {
    return ReaderStyledTextOps.getRegexRuleBySlice(this, slice);
  }

  getRegexSliceFontSize(slice: ReadTextSlice): number {
    return ReaderStyledTextOps.getRegexSliceFontSize(this, slice);
  }

  getRegexSliceFontFamily(slice: ReadTextSlice): string {
    return ReaderStyledTextOps.getRegexSliceFontFamily(this, slice);
  }

  getReadingTextSlices(text: string): ReadTextSlice[] {
    return ReaderStyledTextOps.getReadingTextSlices(this, text);
  }

  getReadingTextSlicesInRange(text: string, start: number, end: number): ReadTextSlice[] {
    return ReaderStyledTextOps.getReadingTextSlicesInRange(this, text, start, end);
  }

  hasActiveTtsHighlight(text: string): boolean {
    return ReaderStyledTextOps.hasActiveTtsHighlight(this, text);
  }

  getReadingRenderText(text: string): string {
    return ReaderStyledTextOps.getReadingRenderText(this, text);
  }


  getTtsHighlightColor(): string {
    return ReaderStyledTextOps.getTtsHighlightColor(this);
  }

  getTtsHighlightTextColor(): string {
    return ReaderStyledTextOps.getTtsHighlightTextColor(this);
  }

  hideReaderPanels() {
    ReaderStyledTextOps.hideReaderPanels(this);
  }

  shouldUseReaderLayoutV2(source: string = this.pagedContentText || this.content): boolean {
    return ReaderStyledTextOps.shouldUseReaderLayoutV2(this, source);
  }

  buildReaderV2Snapshot(): ReaderV2LayoutSnapshot {
    return ReaderStyledTextOps.buildReaderV2Snapshot(this);
  }

  readerV2CommentRadius(): number {
    return ReaderStyledTextOps.readerV2CommentRadius(this);
  }

  buildReaderV2RegexStyles(document: ReaderV2Document): ReaderV2SpanStyleRange[] {
    return ReaderStyledTextOps.buildReaderV2RegexStyles(this, document);
  }

  buildReaderV2Pagination(source: string, chapterIndex: number): ReaderPaginationResult {
    return ReaderStyledTextOps.buildReaderV2Pagination(this, source, chapterIndex);
  }

  createIncrementalReaderV2Pagination(source: string, chapterIndex: number,
    initialPageCount: number): ReaderPaginationResult {
    return ReaderStyledTextOps.createIncrementalReaderV2Pagination(this, source, chapterIndex, initialPageCount);
  }

  registerReaderV2PaginationSession(source: string, chapterIndex: number,
    session: ReaderV2PaginationSession): void {
    ReaderStyledTextOps.registerReaderV2PaginationSession(this, source, chapterIndex, session);
  }


  readerV2PageSet(chapterIndex: number, source: string): ReaderV2PageSet | null {
    return ReaderStyledTextOps.readerV2PageSet(this, chapterIndex, source);
  }

  readerV2Document(chapterIndex: number, source: string): ReaderV2Document | null {
    return ReaderStyledTextOps.readerV2Document(this, chapterIndex, source);
  }

  readerV2Page(chapterIndex: number, pageIndex: number, source: string): ReaderV2PageLayout | null {
    return ReaderStyledTextOps.readerV2Page(this, chapterIndex, pageIndex, source);
  }

  readerV2Controller(role: string, chapterIndex: number, pageIndex: number,
    source: string): ReaderV2PageNodeController {
    let controller = this.readerV2Controllers.get(role);
    if (!controller) {
      controller = new ReaderV2PageNodeController();
      this.readerV2Controllers.set(role, controller);
    }
    const page = this.readerV2Page(chapterIndex, pageIndex, source);
    controller.updatePage(page);
    // TTS focus is a declarative overlay below. Keeping it outside the retained FrameNode avoids
    // HarmonyOS builds that defer RenderNode.invalidate() until the next page transition.
    controller.updateHighlight(-1, -1);
    return controller;
  }

  readerTextEditMenuOptions(textProvider: () => string): EditMenuOptions {
    return ReaderStyledTextOps.readerTextEditMenuOptions(this, textProvider);
  }

  scheduleReaderTextSelectionClear(): void {
    ReaderStyledTextOps.scheduleReaderTextSelectionClear(this);
  }

  refreshCurrentReaderV2RetainedPages(forceRebuild: boolean = false): void {
    if (!this.shouldUseReaderLayoutV2(this.pagedContentText)) return;
    const primaryRole = this.currentReaderSurfaceIndex() === 0 ? 'current_primary' : 'current_alternate';
    const roles: string[] = this.isLandscapeDoublePageActive() ?
      [`${primaryRole}_left`, `${primaryRole}_right`] : [`${primaryRole}_single`];
    const pageIndexes: number[] = this.isLandscapeDoublePageActive() ?
      [this.currentPageIndex, this.currentPageIndex + 1] : [this.currentPageIndex];
    for (let index = 0; index < roles.length; index++) {
      const role = roles[index];
      const pageIndex = pageIndexes[index];
      const page = this.readerV2Page(this.currentChapterIndex, pageIndex, this.pagedContentText);
      const controller = this.readerV2Controllers.get(role);
      if (controller) controller.updatePage(page, forceRebuild);
    }
  }

  republishCurrentReaderPageAfterBackground(): void {
    ReaderStyledTextOps.republishCurrentReaderPageAfterBackground(this);
  }

  readerV2TtsHighlightRects(chapterIndex: number, pageIndex: number, source: string,
    _paintVersion: number = this.readerV2TtsPaintVersion): ReaderV2HighlightRect[] {
    if (chapterIndex !== this.currentChapterIndex || this.readerV2TtsSourceStart < 0 ||
      this.readerV2TtsSourceEnd <= this.readerV2TtsSourceStart) return [];
    const page = this.readerV2Page(chapterIndex, pageIndex, source);
    const document = this.readerV2Document(chapterIndex, source);
    if (!page || !document) return [];
    const absoluteStart = document.displayOffsetForSource(this.readerV2TtsSourceStart);
    const absoluteEnd = document.displayOffsetForSource(this.readerV2TtsSourceEnd);
    return LeafFns.readerV2DisplayHighlightRects(page, absoluteStart, absoluteEnd, 'tts');
  }

  readerV2SelectionHighlightRects(chapterIndex: number, pageIndex: number, source: string,
    _paintVersion: number = this.readerV2SelectionPaintVersion): ReaderV2HighlightRect[] {
    if (chapterIndex !== this.readerV2SelectionChapterIndex || pageIndex !== this.readerV2SelectionPageIndex ||
      this.readerV2SelectionDisplayStart < 0 ||
      this.readerV2SelectionDisplayEnd <= this.readerV2SelectionDisplayStart) return [];
    const page = this.readerV2Page(chapterIndex, pageIndex, source);
    if (!page) return [];
    return LeafFns.readerV2DisplayHighlightRects(page, this.readerV2SelectionDisplayStart,
      this.readerV2SelectionDisplayEnd, 'selection');
  }

  @Builder
  readerV2PageSurface(role: string, chapterIndex: number, pageIndex: number, source: string,
    halfWidth: boolean = false) {
    Stack({ alignContent: Alignment.TopStart }) {
      // TTS paint versions intentionally do not flow into the retained正文 node. Re-publishing that
      // NodeContainer for every spoken chunk can trigger a fresh safe-area measurement after a page
      // animation, moving all glyphs upward. Only the lightweight rectangle overlay below depends on
      // readerV2TtsPaintVersion.
      NodeContainer(this.readerV2Controller(role, chapterIndex, pageIndex, source))
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
      // The retained V2 node paints the bubble background and glyphs. Keep the theme cap artwork in a
      // lightweight ArkUI overlay so the actual reader uses the same ornaments as the font-settings preview.
      this.readerV2RegexBubbleCapsForPage(chapterIndex, pageIndex, source)
    }
    // Pagination subtracts the spread divider before measuring each column. Giving both native pages 50% plus
    // the divider makes their live width differ from the simulation capture width by the divider/fractional pixel,
    // which can reflow or shift glyphs when the capture hands off to the settled spread.
    .width(halfWidth ? this.getReaderPageColumnWidth() : '100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  readerV2RegexBubbleCaps(segment: ReaderV2RegexBubbleSegment) {
    if (segment.leading && segment.leadingCapWidthPx > 0.5) {
      Image(ThemeAssetRegistry.regexBubbleCap(segment.styleId))
        .width(px2vp(segment.capSizePx))
        .height(px2vp(segment.capSizePx))
        .objectFit(ImageFit.Contain)
        .position({
          x: px2vp(segment.rect.left),
          y: px2vp(segment.rect.top + (segment.rect.height() - segment.capSizePx) / 2)
        })
        .hitTestBehavior(HitTestMode.None)
    }
    if (segment.trailing && segment.trailingCapWidthPx > 0.5) {
      Image(ThemeAssetRegistry.regexBubbleCap(segment.styleId))
        .width(px2vp(segment.capSizePx))
        .height(px2vp(segment.capSizePx))
        .objectFit(ImageFit.Contain)
        .rotate({ angle: 180 })
        .position({
          x: px2vp(segment.rect.right - segment.capSizePx),
          y: px2vp(segment.rect.top + (segment.rect.height() - segment.capSizePx) / 2)
        })
        .hitTestBehavior(HitTestMode.None)
    }
  }

  @Builder
  readerV2RegexBubbleCapsForPage(chapterIndex: number, pageIndex: number, source: string) {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(this.readerV2PageFragments(chapterIndex, pageIndex, source),
        (fragment: ReaderV2PageFragment) => {
          ForEach(fragment.regexBubbleSegments, (segment: ReaderV2RegexBubbleSegment) => {
            this.readerV2RegexBubbleCaps(segment)
          }, (segment: ReaderV2RegexBubbleSegment) =>
            `reader_v2_bubble_caps_${segment.styleId}_${segment.rect.left}_${segment.rect.top}_` +
            `${segment.rect.right}_${segment.rect.bottom}_${segment.leading ? 'l' : ''}${segment.trailing ? 'r' : ''}`)
        }, (fragment: ReaderV2PageFragment) => `reader_v2_bubble_fragment_${fragment.blockId}_` +
          `${fragment.displayStart}_${fragment.displayEnd}`)
    }
    .width('100%')
    .height('100%')
    .zIndex(1)
    .hitTestBehavior(HitTestMode.None)
  }

  currentReaderV2TtsOverlayKeys(paintVersion: number): string[] {
    return ReaderStyledTextOps.currentReaderV2TtsOverlayKeys(this, paintVersion);
  }

  currentReaderV2SelectionSurfaceKeys(hostVersion: number): string[] {
    return ReaderStyledTextOps.currentReaderV2SelectionSurfaceKeys(this, hostVersion);
  }

  currentReaderV2SelectionOverlayKeys(paintVersion: number): string[] {
    return ReaderStyledTextOps.currentReaderV2SelectionOverlayKeys(this, paintVersion);
  }

  @Builder
  readerCurrentV2SelectionSurface() {
    Column() {
      if (this.isLandscapeDoublePageActive()) {
        Row() {
          Stack({ alignContent: Alignment.TopStart }) {
            this.readerV2NativeSelectionPage(
              `${this.currentReaderSurfaceIndex() === 0 ? 'current_primary' : 'current_alternate'}_left`,
              this.currentChapterIndex, this.currentPageIndex, this.pagedContentText)
          }
          .width(this.getReaderPageColumnWidth())
          .height('100%')
          Blank()
            .width(READER_DOUBLE_PAGE_DIVIDER_WIDTH)
            .height('100%')
          Stack({ alignContent: Alignment.TopStart }) {
            this.readerV2NativeSelectionPage(
              `${this.currentReaderSurfaceIndex() === 0 ? 'current_primary' : 'current_alternate'}_right`,
              this.currentChapterIndex, this.currentPageIndex + 1, this.pagedContentText)
          }
          .width(this.getReaderPageColumnWidth())
          .height('100%')
        }
        .width('100%')
        .height('100%')
        .alignItems(VerticalAlign.Center)
      } else {
        this.readerV2NativeSelectionPage(
          `${this.currentReaderSurfaceIndex() === 0 ? 'current_primary' : 'current_alternate'}_single`,
          this.currentChapterIndex, this.currentPageIndex, this.pagedContentText)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.getReaderPageContentTopPadding() })
    .translate({ x: this.getCurrentPageTurnX(), y: this.getCurrentPageTurnY() + this.bookmarkPullOffsetY })
    .opacity(this.getCurrentPageTurnOpacity())
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  readerCurrentV2SelectionOverlay(paintVersion: number) {
    Column() {
      if (this.isLandscapeDoublePageActive()) {
        Row() {
          this.readerCurrentV2SelectionOverlayPage(this.currentPageIndex, paintVersion, true)
          Blank()
            .width(READER_DOUBLE_PAGE_DIVIDER_WIDTH)
            .height('100%')
          this.readerCurrentV2SelectionOverlayPage(this.currentPageIndex + 1, paintVersion, true)
        }
        .width('100%')
        .height('100%')
        .alignItems(VerticalAlign.Center)
      } else {
        this.readerCurrentV2SelectionOverlayPage(this.currentPageIndex, paintVersion)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.getReaderPageContentTopPadding() })
    .translate({ x: this.getCurrentPageTurnX(), y: this.getCurrentPageTurnY() + this.bookmarkPullOffsetY })
    .opacity(this.getCurrentPageTurnOpacity())
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  readerCurrentV2SelectionOverlayPage(pageIndex: number, paintVersion: number,
    halfWidth: boolean = false) {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(this.readerV2SelectionHighlightRects(
        this.currentChapterIndex, pageIndex, this.pagedContentText, paintVersion),
      (rect: ReaderV2HighlightRect) => {
        ReaderV2SelectionHighlightRect({
          rectLeftPx: rect.leftPx,
          rectTopPx: rect.topPx,
          rectWidthPx: rect.widthPx,
          rectHeightPx: rect.heightPx
        })
      }, (rect: ReaderV2HighlightRect) => rect.key)
    }
    .width(halfWidth ? this.getReaderPageColumnWidth() : '100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  readerCurrentV2TtsOverlay(paintVersion: number) {
    Column() {
      if (this.isLandscapeDoublePageActive()) {
        Row() {
          this.readerCurrentV2TtsOverlayPage(this.currentPageIndex, paintVersion, true)
          Blank()
            .width(READER_DOUBLE_PAGE_DIVIDER_WIDTH)
            .height('100%')
          this.readerCurrentV2TtsOverlayPage(this.currentPageIndex + 1, paintVersion, true)
        }
        .width('100%')
        .height('100%')
        .alignItems(VerticalAlign.Center)
      } else {
        this.readerCurrentV2TtsOverlayPage(this.currentPageIndex, paintVersion)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.getReaderPageContentTopPadding() })
    .translate({ x: this.getCurrentPageTurnX(), y: this.getCurrentPageTurnY() + this.bookmarkPullOffsetY })
    .opacity(this.getCurrentPageTurnOpacity())
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  readerCurrentV2TtsOverlayPage(pageIndex: number, paintVersion: number, halfWidth: boolean = false) {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(this.readerV2TtsHighlightRects(
        this.currentChapterIndex, pageIndex, this.pagedContentText, paintVersion),
      (rect: ReaderV2HighlightRect) => {
        ReaderV2TtsHighlightRect({
          rectLeftPx: rect.leftPx,
          rectTopPx: rect.topPx,
          rectWidthPx: rect.widthPx,
          rectHeightPx: rect.heightPx
        })
      }, (rect: ReaderV2HighlightRect) => rect.key)
    }
    .width(halfWidth ? this.getReaderPageColumnWidth() : '100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }

  readerV2PageFragments(chapterIndex: number, pageIndex: number, source: string): ReaderV2PageFragment[] {
    const page = this.readerV2Page(chapterIndex, pageIndex, source);
    return page ? page.fragments : [];
  }

  readerV2NativeSelectionKey(role: string, chapterIndex: number, pageIndex: number,
    page: ReaderV2PageLayout): string {
    // Every lazy host owns a fresh controller. A controller retained from a destroyed host can expose the previous
    // page's LayoutManager briefly and put selection handles on stale glyph coordinates.
    return `reader_v2_native_page_${role}_${chapterIndex}_${pageIndex}_${page.identity}_` +
      `${this.readerV2NativeSelectionHostVersion}`;
  }

  readerV2SelectionStyledText(page: ReaderV2PageLayout): MutableStyledString {
    const cacheKey = `${page.identity}_selection_page`;
    const cached = this.readerV2SelectionStyledTextCache.get(cacheKey);
    if (cached) return cached;
    const styles: StyleOptions[] = [];
    const snapshot = this.readerV2ActiveSnapshot || this.buildReaderV2Snapshot();
    for (let fragmentIndex = 0; fragmentIndex < page.fragments.length; fragmentIndex++) {
      const fragment = page.fragments[fragmentIndex];
      let runStart = fragment.selectionPageStart;
      for (const run of fragment.selectionRuns) {
        styles.push({
          start: runStart,
          length: run.text.length,
          styledKey: StyledStringKey.FONT,
          styledValue: new TextStyle({
            fontSize: LengthMetrics.px(run.fontSizePx),
            fontFamily: run.fontFamily || this.getBodyReaderFontFamily(),
            fontWeight: run.bold ? 600 : 400,
            fontColor: Color.Transparent
          })
        });
        styles.push({
          start: runStart,
          length: run.text.length,
          styledKey: StyledStringKey.LETTER_SPACING,
          styledValue: new LetterSpacingStyle(LengthMetrics.px(run.letterSpacingPx))
        });
        runStart += run.text.length;
      }
      const lastRun = fragment.selectionRuns.length > 0 ?
        fragment.selectionRuns[fragment.selectionRuns.length - 1] : null;
      const defaultLineHeight = lastRun ? lastRun.fontSizePx : snapshot.fontSizePx;
      // h12 最终修复：逐行 LINE_HEIGHT = 绘制行距 pitch - lineSpacingPx。
      // h11 标定实验证明：native 行盒 g(LH) = LH + lineSpacingPx（组件 .lineSpacing），
      // 对首行/内行/末行/单行段全部线性可控（13 个探针点 35~70 全部精确命中）。
      // pitch 取相邻绘制行的 top 差（段内下一行，或下一段首行 paragraphY + topHeight），
      // 使 native 每行 top 与分页器逐行一致，多行选择的行间渐移不再累积。
      let lastLineHeight = defaultLineHeight;
      const lineMetrics = LeafFns.readerV2FragmentLineMetrics(fragment);
      for (let lineIndex = 0; lineIndex < lineMetrics.length; lineIndex++) {
        const metric = lineMetrics[lineIndex];
        const spanStart = Math.max(fragment.selectionPageStart,
          fragment.selectionPageStart + metric.startIndex);
        const spanEnd = Math.min(fragment.selectionPageEnd,
          fragment.selectionPageStart + metric.endIndex);
        if (spanEnd <= spanStart) continue;
        let lineHeight = defaultLineHeight;
        let pitch = -1;
        if (lineIndex + 1 < lineMetrics.length) {
          pitch = lineMetrics[lineIndex + 1].topHeight - metric.topHeight;
        } else if (fragmentIndex + 1 < page.fragments.length) {
          const nextFragment = page.fragments[fragmentIndex + 1];
          const nextMetrics = LeafFns.readerV2FragmentLineMetrics(nextFragment);
          const nextTop = nextFragment.paragraphY +
            (nextMetrics.length > 0 ? nextMetrics[0].topHeight : 0);
          pitch = nextTop - (fragment.paragraphY + metric.topHeight);
        }
        if (Number.isFinite(pitch) && pitch > 0) {
          lineHeight = Math.max(1, pitch - snapshot.lineSpacingPx);
        }
        lastLineHeight = lineHeight;
        styles.push({
          start: spanStart,
          length: spanEnd - spanStart,
          styledKey: StyledStringKey.LINE_HEIGHT,
          styledValue: new LineHeightStyle(LengthMetrics.px(lineHeight))
        });
        // h12.1 基线校正：native 基线在行盒内按字体 ascent 比例分布（ratio×盒高），而绘制侧
        // 基线偏移随行型不同（首行/内行/末行/单行段各异），最大偏差 ~7px。逐行 BASELINE_OFFSET
        // 将基线（连同 TIGHT 矩形与选择手柄）对齐到绘制侧度量，使多行选择的残差归零。
        const ascentTotal = metric.ascent + metric.descent;
        if (ascentTotal > 0 && Number.isFinite(metric.baseline) && Number.isFinite(metric.topHeight)) {
          const ascentRatio = metric.ascent / ascentTotal;
          const nativeAscOffset = ascentRatio * (lineHeight + snapshot.lineSpacingPx);
          const baselineShift = (metric.baseline - metric.topHeight) - nativeAscOffset;
          if (Math.abs(baselineShift) > 0.01) {
            styles.push({
              start: spanStart,
              length: spanEnd - spanStart,
              styledKey: StyledStringKey.BASELINE_OFFSET,
              styledValue: new BaselineOffsetStyle(LengthMetrics.px(baselineShift))
            });
          }
        }
      }
      const isLastFragment = fragmentIndex >= page.fragments.length - 1;
      // 样式化段间 '\n' 分隔符：分隔符不属于任何 run，若不显式给样式，引擎在边界布局时用默认字体
      // 度量（asc 49.88 泄漏）参与行盒计算。LH 跟随本段末行值，保证末行行盒单值。
      if (!isLastFragment && lastRun) {
        const separatorStart = fragment.selectionPageEnd;
        styles.push({
          start: separatorStart,
          length: 1,
          styledKey: StyledStringKey.FONT,
          styledValue: new TextStyle({
            fontSize: LengthMetrics.px(lastRun.fontSizePx),
            fontFamily: lastRun.fontFamily || this.getBodyReaderFontFamily(),
            fontWeight: lastRun.bold ? 600 : 400,
            fontColor: Color.Transparent
          })
        });
        styles.push({
          start: separatorStart,
          length: 1,
          styledKey: StyledStringKey.LETTER_SPACING,
          styledValue: new LetterSpacingStyle(LengthMetrics.px(lastRun.letterSpacingPx))
        });
        styles.push({
          start: separatorStart,
          length: 1,
          styledKey: StyledStringKey.LINE_HEIGHT,
          styledValue: new LineHeightStyle(LengthMetrics.px(lastLineHeight))
        });
      }
      const paragraphLength = fragment.selectionPageEnd - fragment.selectionPageStart;
      if (paragraphLength > 0) {
        styles.push({
          start: fragment.selectionPageStart,
          length: paragraphLength,
          styledKey: StyledStringKey.PARAGRAPH_STYLE,
          styledValue: new ParagraphStyle({
            textAlign: this.readerTextAlignValue(),
            wordBreak: WordBreak.BREAK_WORD,
            paragraphSpacing: LengthMetrics.px(0)
          })
        });
      }
    }
    const styled = new MutableStyledString(page.selectionText, styles);
    this.readerV2SelectionStyledTextCache.set(cacheKey, styled);
    while (this.readerV2SelectionStyledTextCache.size > 64) {
      const oldest = this.readerV2SelectionStyledTextCache.keys().next().value as string | undefined;
      if (!oldest) break;
      this.readerV2SelectionStyledTextCache.delete(oldest);
    }
    return styled;
  }

  readerV2NativeSelectionController(key: string, page: ReaderV2PageLayout): TextController {
    const controller = this.readerSelectableTextController(key);
    try {
      controller.setStyledString(this.readerV2SelectionStyledText(page));
    } catch (_) {
    }
    return controller;
  }

  tryCalibrateReaderV2NativeSelection(page: ReaderV2PageLayout, fragmentIndex: number,
    controller: TextController, selectionStart: number = -1, selectionEnd: number = -1): boolean {
    const start = selectionStart >= 0 ? selectionStart : this.readerV2NativeSelectionPendingStart;
    const end = selectionEnd > start ? selectionEnd : this.readerV2NativeSelectionPendingEnd;
    const fragment = page.fragments[fragmentIndex];
    if (!fragment || !fragment.paragraph || start < 0 || end <= start) return false;
    const manager = controller.getLayoutManager();
    if (!manager) return false;
    const fragmentStart = Math.max(0, start - fragment.selectionPageStart);
    const fragmentEnd = Math.min(fragment.selectionPageEnd - fragment.selectionPageStart,
      end - fragment.selectionPageStart);
    const nativeBoxes = manager.getRectsForRange({
      start: start,
      end: end
    }, graphicsText.RectWidthStyle.TIGHT, graphicsText.RectHeightStyle.TIGHT);
    const paintedBoxes = fragment.paragraph.getRectsForRange({ start: fragmentStart, end: fragmentEnd },
      graphicsText.RectWidthStyle.TIGHT, graphicsText.RectHeightStyle.TIGHT);
    if (nativeBoxes.length === 0 || paintedBoxes.length === 0) return false;
    const nativeRect = nativeBoxes[0].rect;
    const paintedRect = paintedBoxes[0].rect;
    const offsetX = fragment.paragraphX + paintedRect.left - (page.selectionX + nativeRect.left);
    const offsetY = fragment.paragraphY + paintedRect.top - (page.selectionY + nativeRect.top);
    if (!Number.isFinite(offsetX) || !Number.isFinite(offsetY) ||
      Math.abs(offsetX) > Math.max(1, page.selectionWidth * 0.5) ||
      Math.abs(offsetY) > Math.max(1, page.selectionHeight * 0.5)) {
      return false;
    }
    this.readerV2NativeSelectionOffsetX = offsetX;
    this.readerV2NativeSelectionOffsetY = offsetY;
    return true;
  }

  showReaderV2NativeSelectionAfterLayout(page: ReaderV2PageLayout, fragmentIndex: number,
    controller: TextController, hostVersion: number, attempt: number = 0): void {
    setTimeout(() => {
      if (hostVersion !== this.readerV2NativeSelectionHostVersion ||
        this.readerV2NativeSelectionPendingSerial !== this.readerTextSelectionSerial ||
        !this.readerPageVisible || this.readerV2NativeSelectionPendingStart < 0 ||
        this.readerV2NativeSelectionPendingEnd <= this.readerV2NativeSelectionPendingStart) return;
      let calibrated = false;
      try {
        calibrated = this.tryCalibrateReaderV2NativeSelection(page, fragmentIndex, controller);
      } catch (e) {
        console.warn('正文选择校准测量异常，稍后重试:', e);
      }
      if (!calibrated && attempt < 4) {
        this.showReaderV2NativeSelectionAfterLayout(page, fragmentIndex, controller, hostVersion, attempt + 1);
        return;
      }
      setTimeout(() => {
        if (hostVersion !== this.readerV2NativeSelectionHostVersion ||
          this.readerV2NativeSelectionPendingSerial !== this.readerTextSelectionSerial ||
          !this.readerPageVisible) return;
        try {
          controller.setTextSelection(this.readerV2NativeSelectionPendingStart,
            this.readerV2NativeSelectionPendingEnd, { menuPolicy: MenuPolicy.SHOW });
        } catch (e) {
          console.warn('正文选择激活失败:', e);
        }
        if (!calibrated) {
          console.warn('正文选择预校准未就绪，选择激活后继续校准');
          this.retryReaderV2NativeSelectionCalibration(page, fragmentIndex, controller, hostVersion, 0);
        }
      }, calibrated ? 32 : 0);
    }, attempt === 0 ? 16 : 24);
  }

  retryReaderV2NativeSelectionCalibration(page: ReaderV2PageLayout, fragmentIndex: number,
    controller: TextController, hostVersion: number, attempt: number): void {
    setTimeout(() => {
      if (hostVersion !== this.readerV2NativeSelectionHostVersion ||
        this.readerV2NativeSelectionPendingSerial !== this.readerTextSelectionSerial ||
        !this.readerPageVisible) return;
      let calibrated = false;
      try {
        calibrated = this.tryCalibrateReaderV2NativeSelection(page, fragmentIndex, controller);
      } catch (_) {
      }
      if (calibrated) {
        console.info('正文选择激活后校准成功，把手已对齐正文');
        return;
      }
      if (attempt < 3) {
        this.retryReaderV2NativeSelectionCalibration(page, fragmentIndex, controller, hostVersion, attempt + 1);
        return;
      }
      console.warn('正文选择校准在激活后仍未就绪，把手可能存在行级偏移');
    }, 48);
  }

  scheduleReaderV2NativeSelectionRecalibration(): void {
    if (this.readerV2NativeSelectionRecalibrateTimerId >= 0) {
      clearTimeout(this.readerV2NativeSelectionRecalibrateTimerId);
    }
    // Handle dragging mutates the native selection continuously; the overlay only re-aligns
    // after the selection settles so the correction never fights the in-progress gesture.
    this.readerV2NativeSelectionRecalibrateTimerId = setTimeout(() => {
      this.readerV2NativeSelectionRecalibrateTimerId = -1;
      if (!this.readerPageVisible || this.readerV2NativeSelectionFragmentIndex < 0 ||
        this.readerV2NativeSelectionChapterIndex !== this.currentChapterIndex ||
        this.readerV2NativeSelectionActiveStart < 0 ||
        this.readerV2NativeSelectionActiveEnd <= this.readerV2NativeSelectionActiveStart) return;
      const page = this.readerV2Page(this.readerV2NativeSelectionChapterIndex,
        this.readerV2NativeSelectionPageIndex, this.pagedContentText);
      if (!page || !page.selectionText) return;
      const fragmentIndex = LeafFns.readerV2FragmentIndexForSelectionOffset(page,
        this.readerV2NativeSelectionActiveStart);
      if (fragmentIndex < 0) return;
      const controller = this.readerSelectableTextController(
        this.readerV2NativeSelectionKey(this.readerV2NativeSelectionRole,
          this.readerV2NativeSelectionChapterIndex, this.readerV2NativeSelectionPageIndex, page));
      try {
        this.tryCalibrateReaderV2NativeSelection(page, fragmentIndex, controller,
          this.readerV2NativeSelectionActiveStart, this.readerV2NativeSelectionActiveEnd);
      } catch (error) {
        console.warn('正文选择随选区校准测量异常:', error);
      }
    }, 160);
  }

  @Builder
  readerV2NativeSelectionPage(role: string, chapterIndex: number, pageIndex: number, source: string) {
    if (chapterIndex === this.readerV2NativeSelectionChapterIndex &&
      pageIndex === this.readerV2NativeSelectionPageIndex && role === this.readerV2NativeSelectionRole &&
      this.readerV2Page(chapterIndex, pageIndex, source)) {
      if ((this.readerV2Page(chapterIndex, pageIndex, source) as ReaderV2PageLayout).selectionText &&
        this.readerV2NativeSelectionFragmentIndex >= 0 &&
        this.readerV2NativeSelectionFragmentIndex <
          (this.readerV2Page(chapterIndex, pageIndex, source) as ReaderV2PageLayout).fragments.length) {
        Stack({ alignContent: Alignment.TopStart }) {
          this.readerV2NativeSelectionText(role, chapterIndex, pageIndex,
            this.readerV2Page(chapterIndex, pageIndex, source) as ReaderV2PageLayout,
            this.readerV2NativeSelectionFragmentIndex)
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
      }
    }
  }

  @Builder
  readerV2NativeSelectionText(role: string, chapterIndex: number, pageIndex: number,
    page: ReaderV2PageLayout, fragmentIndex: number) {
    Stack({ alignContent: Alignment.TopStart }) {
      Text('', { controller: this.readerV2NativeSelectionController(
        this.readerV2NativeSelectionKey(role, chapterIndex, pageIndex, page), page) })
        .lineSpacing(LengthMetrics.vp(px2vp(
          (this.readerV2ActiveSnapshot || this.buildReaderV2Snapshot()).lineSpacingPx)),
        { onlyBetweenLines: true })
        .halfLeading(false)
        .includeFontPadding(true)
        .textAlign(this.readerTextAlignValue())
        .wordBreak(WordBreak.BREAK_WORD)
        .lineBreakStrategy(LineBreakStrategy.GREEDY)
        .copyOption(CopyOptions.LocalDevice)
        .textSelectable(TextSelectableMode.SELECTABLE_FOCUSABLE)
        .editMenuOptions(this.readerTextEditMenuOptions(() => page.selectionText))
        .onCopy(() => this.scheduleReaderTextSelectionClear())
        .selectedBackgroundColor(Color.Transparent)
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .onTextSelectionChange((selectionStart: number, selectionEnd: number) => {
          const textLength = page.selectionText.length;
          this.readerTextSelectionUntil = Date.now() + 900;
          this.suppressReaderTapClick = true;
          this.readerTouchActive = false;
          this.readerPanActive = false;
          const safeStart = Math.max(0, Math.min(selectionStart, textLength));
          const safeEnd = Math.max(safeStart, Math.min(selectionEnd, textLength));
          if (safeEnd > safeStart) {
            this.readerV2NativeSelectionActiveStart = safeStart;
            this.readerV2NativeSelectionActiveEnd = safeEnd;
            this.scheduleReaderV2NativeSelectionRecalibration();
            this.readerV2SelectionChapterIndex = chapterIndex;
            this.readerV2SelectionPageIndex = pageIndex;
            this.readerV2SelectionDisplayStart = LeafFns.readerV2DisplayOffsetForPageSelection(page, safeStart);
            this.readerV2SelectionDisplayEnd = LeafFns.readerV2DisplayOffsetForPageSelection(page, safeEnd);
            this.readerV2SelectionPaintVersion++;
          }
        })
        .id(`reader_v2_selection_${role}_${chapterIndex}_${pageIndex}`)
        .onAppear(() => {
          const key = this.readerV2NativeSelectionKey(role, chapterIndex, pageIndex, page);
          const controller = this.readerV2NativeSelectionController(key, page);
          const hostVersion = this.readerV2NativeSelectionHostVersion;
          this.showReaderV2NativeSelectionAfterLayout(page, fragmentIndex, controller, hostVersion);
        })
    }
    .width(px2vp(page.selectionWidth))
    .height(px2vp(Math.max(1, page.selectionHeight)))
    // 校准偏移必须直接读取 @State：ForEach 的 itemGenerator 在 key 不变时不会重新执行，
    // 通过参数传入的 offset 会停留在挂载时的 (0,0)。属性绑定读取状态后，ArkUI 的最小更新
    // 机制会在校准完成时移动该 Stack 而无需重建 Text，选区与系统菜单得以保留。
    .position({ x: px2vp(page.selectionX + this.readerV2NativeSelectionOffsetX),
      y: px2vp(page.selectionY + this.readerV2NativeSelectionOffsetY) })
    .hitTestBehavior(HitTestMode.None)
  }

  readerV2SurfaceTopOffset(): number {
    return ReaderStyledTextOps.readerV2SurfaceTopOffset(this);
  }

  clearReaderV2SelectionOverlay(): void {
    ReaderStyledTextOps.clearReaderV2SelectionOverlay(this);
  }

  readerV2ActionAtLocalPoint(xVp: number, yVp: number): string {
    const located = this.readerV2LocatedPagePoint(xVp, yVp);
    if (located.length < 4) return '';
    const pageIndex = located[0];
    const xPx = located[1];
    const yPx = located[2];
    const page = this.readerV2Page(this.currentChapterIndex, pageIndex, this.pagedContentText);
    const snapshot = this.readerV2ActiveSnapshot || this.buildReaderV2Snapshot();
    const hit: ReaderV2TapResult = ReaderV2GestureRouter.hitTest(page, snapshot, xPx, yPx);
    return hit.kind === 'action' ? hit.marker : '';
  }

  readerV2LocatedPagePoint(xVp: number, yVp: number): number[] {
    return ReaderStyledTextOps.readerV2LocatedPagePoint(this, xVp, yVp);
  }

  selectReaderV2TextAtGlobalPoint(globalX: number, globalY: number, serial: number, attempt: number): void {
    if (serial !== this.readerTextSelectionSerial) return;
    const localX = globalX - this.readerTapLayerGlobalX;
    const localY = globalY - this.readerTapLayerGlobalY - this.readerV2SurfaceTopOffset();
    const located = this.readerV2LocatedPagePoint(localX, localY);
    if (located.length < 4) return;
    const pageIndex = located[0];
    // The retained page surface alternates between two keyed buffers. Selection must address
    // the controller attached to the currently visible buffer; using a generic current_left key
    // silently created a detached TextController whose selection menu could never appear.
    const surfaceRole = this.currentReaderSurfaceIndex() === 0 ? 'current_primary' : 'current_alternate';
    const role = this.isLandscapeDoublePageActive() ?
      `${surfaceRole}_${pageIndex === this.currentPageIndex ? 'left' : 'right'}` : `${surfaceRole}_single`;
    const page = this.readerV2Page(this.currentChapterIndex, pageIndex, this.pagedContentText);
    if (!page || !page.selectionText) {
      this.retryReaderTextSelection(serial, attempt,
        (nextAttempt: number): void => this.selectReaderV2TextAtGlobalPoint(
          globalX, globalY, serial, nextAttempt));
      return;
    }
    let matchedFragment = false;
    const selectionSlop = LeafFns.toMeasurePx(8);
    for (let fragmentIndex = 0; fragmentIndex < page.fragments.length; fragmentIndex++) {
      const fragment = page.fragments[fragmentIndex];
      if (!fragment.clipRect.contains(located[1], located[2], selectionSlop, selectionSlop)) continue;
      matchedFragment = true;
      try {
        if (!fragment.paragraph) break;
        // The transparent Text's LayoutManager can stay unavailable on some HarmonyOS builds
        // even though it is already on screen. The painted paragraph is the pagination source of
        // truth and always has the exact glyph coordinates, so derive the transparent selection
        // offset from it instead of depending on that optional manager.
        const fragmentPosition = fragment.paragraph.getGlyphPositionAtCoordinate(
          located[1] - fragment.paragraphX, located[2] - fragment.paragraphY).position;
        const text = page.selectionText;
        let position = fragment.selectionPageStart + Math.max(0,
          Math.min(fragment.selectionPageEnd - fragment.selectionPageStart - 1, fragmentPosition));
        position = Math.max(0, Math.min(text.length - 1, position));
        while (position < text.length - 1 && /\s/.test(text.charAt(position))) position++;
        while (position > 0 && /\s/.test(text.charAt(position))) position--;
        let start = position;
        let end = Math.min(text.length, position + 1);
        const wordPattern = /[A-Za-z0-9_]/;
        if (wordPattern.test(text.charAt(position))) {
          while (start > 0 && wordPattern.test(text.charAt(start - 1))) start--;
          while (end < text.length && wordPattern.test(text.charAt(end))) end++;
        } else {
          const code = text.charCodeAt(position);
          if (code >= 0xDC00 && code <= 0xDFFF && start > 0) start--;
          if (code >= 0xD800 && code <= 0xDBFF && end < text.length) end++;
        }
        this.readerTextSelectionUntil = Date.now() + 900;
        this.suppressReaderTapClick = true;
        this.readerTouchActive = false;
        this.readerPanActive = false;
        // Mount one whole-page Text only after long press. Its continuous selection range includes the separators
        // between fragments, allowing native handles to cross paragraph boundaries without adding page-turn cost.
        this.readerV2NativeSelectionChapterIndex = this.currentChapterIndex;
        this.readerV2NativeSelectionPageIndex = pageIndex;
        this.readerV2NativeSelectionFragmentIndex = fragmentIndex;
        this.readerV2NativeSelectionRole = role;
        this.readerV2NativeSelectionPendingStart = start;
        this.readerV2NativeSelectionPendingEnd = end;
        this.readerV2NativeSelectionPendingSerial = serial;
        this.readerV2NativeSelectionOffsetX = 0;
        this.readerV2NativeSelectionOffsetY = 0;
        this.readerV2SelectionChapterIndex = this.currentChapterIndex;
        this.readerV2SelectionPageIndex = pageIndex;
        this.readerV2SelectionDisplayStart = LeafFns.readerV2DisplayOffsetForPageSelection(page, start);
        this.readerV2SelectionDisplayEnd = LeafFns.readerV2DisplayOffsetForPageSelection(page, end);
        this.readerV2SelectionPaintVersion++;
        this.readerV2NativeSelectionHostVersion++;
        return;
      } catch (error) {
        console.info('V2 正文选区布局尚未就绪，准备重试:', error);
      }
      break;
    }
    if (!matchedFragment && attempt >= 3) return;
    this.retryReaderTextSelection(serial, attempt,
      (nextAttempt: number): void => this.selectReaderV2TextAtGlobalPoint(
        globalX, globalY, serial, nextAttempt));
  }

  readerV2TtsSourceOffset(speechOffset: number): number {
    return ReaderStyledTextOps.readerV2TtsSourceOffset(this, speechOffset);
  }

  refreshReaderV2TtsOverlay(): void {
    ReaderStyledTextOps.refreshReaderV2TtsOverlay(this);
  }

  async exitReaderPage(): Promise<void> {
    return ReaderStyledTextOps.exitReaderPage(this);
  }
//endregion
//region 分页缓存 / 翻页·预载·自动翻页 / 翻页动画·卷曲 / 换章
// [map] 契约: 写 currentPageIndex / 翻页动画状态 / 预载; 与 TTS 翻页、镜像手动翻页交织

  paginateReaderSourceText(source: string, chapterIndex: number = this.currentChapterIndex): ReaderPaginationResult {
    return ReaderPageTurnOps.paginateReaderSourceText(this, source, chapterIndex);
  }

  getStyledSliceDecoration(slice: ReadTextSlice): DecorationStyleInterface {
    return ReaderPageTurnOps.getStyledSliceDecoration(this, slice);
  }

  paginateReaderImageSourceText(source: string,
    chapterIndex: number = this.currentChapterIndex): ReaderPaginationResult {
    return ReaderPageTurnOps.paginateReaderImageSourceText(this, source, chapterIndex);
  }

  appendReaderTextSegmentPages(source: string, start: number, end: number, chapterIndex: number,
    pages: string[], starts: number[], ends: number[]): void {
    ReaderPageTurnOps.appendReaderTextSegmentPages(this, source, start, end, chapterIndex, pages, starts, ends);
  }

  buildReaderPaginationCacheKey(chapterIndex: number, source: string): string {
    return ReaderPageTurnOps.buildReaderPaginationCacheKey(this, chapterIndex, source);
  }

  readerTypographyCacheIdentity(): string {
    return ReaderPageTurnOps.readerTypographyCacheIdentity(this);
  }

  getCachedReaderPagination(chapterIndex: number, source: string): ReaderPaginationResult | null {
    return ReaderPageTurnOps.getCachedReaderPagination(this, chapterIndex, source);
  }

  getOrCreateReaderPagination(chapterIndex: number, source: string,
    preferredInitialPageCount: number = 0): ReaderPaginationResult {
    return ReaderPageTurnOps.getOrCreateReaderPagination(this, chapterIndex, source, preferredInitialPageCount);
  }

  createIncrementalReaderPagination(source: string, chapterIndex: number,
    initialPageCount: number): ReaderPaginationResult {
    return ReaderPageTurnOps.createIncrementalReaderPagination(this, source, chapterIndex, initialPageCount);
  }

  appendReaderPaginationBatch(result: ReaderPaginationResult, chapterIndex: number, maxPages: number,
    timeBudgetMs: number = 8): void {
    ReaderPageTurnOps.appendReaderPaginationBatch(this, result, chapterIndex, maxPages, timeBudgetMs);
  }

  scheduleReaderPaginationCompletion(chapterIndex: number, key: string,
    result: ReaderPaginationResult): void {
    ReaderPageTurnOps.scheduleReaderPaginationCompletion(this, chapterIndex, key, result);
  }

  isReaderPaginationInteractionBusy(): boolean {
    return ReaderPageTurnOps.isReaderPaginationInteractionBusy(this);
  }

  deferReaderPaginationForInteraction(idleDelayMs: number = 420): void {
    ReaderPageTurnOps.deferReaderPaginationForInteraction(this, idleDelayMs);
  }

  publishCurrentReaderPagination(result: ReaderPaginationResult): void {
    ReaderPageTurnOps.publishCurrentReaderPagination(this, result);
  }

  persistReaderPagination(chapterIndex: number, key: string, result: ReaderPaginationResult): void {
    ReaderPageTurnOps.persistReaderPagination(this, chapterIndex, key, result);
  }

  applyPreparedReaderPagination(content: string, chapterIndex: number, createIfMissing: boolean): boolean {
    return ReaderPageTurnOps.applyPreparedReaderPagination(this, content, chapterIndex, createIfMissing);
  }

  async restorePersistedReaderPagination(content: string, chapterIndex: number): Promise<boolean> {
    return ReaderPageTurnOps.restorePersistedReaderPagination(this, content, chapterIndex);
  }

  /**
   * 连续朗读（含锁屏/后台）时 onPageHide 置 false 的 readerPageVisible 不能挡住下一章预排版，
   * 否则每到章末切换都要现场联网取文加排版，听书出现长静默。
   */
  isReaderPreloadBlockedByVisibility(): boolean {
    return ReaderPageTurnOps.isReaderPreloadBlockedByVisibility(this);
  }

  preloadNextChapterPaginationLater(delayMs: number = 520): void {
    ReaderPageTurnOps.preloadNextChapterPaginationLater(this, delayMs);
  }

  scheduleNextChapterPaginationCompletion(sourceChapterIndex: number, targetChapterIndex: number, key: string,
    result: ReaderPaginationResult, serial: number): void {
    ReaderPageTurnOps.scheduleNextChapterPaginationCompletion(this, sourceChapterIndex, targetChapterIndex, key, result, serial);
  }

  preloadPreviousChapterPaginationLater(delayMs: number = 760): void {
    ReaderPageTurnOps.preloadPreviousChapterPaginationLater(this, delayMs);
  }

  schedulePreviousChapterPaginationCompletion(sourceChapterIndex: number, targetChapterIndex: number, key: string,
    result: ReaderPaginationResult, serial: number): void {
    ReaderPageTurnOps.schedulePreviousChapterPaginationCompletion(this, sourceChapterIndex, targetChapterIndex, key, result, serial);
  }

  paginateContent(sourceContent?: string, chapterIndex: number = this.currentChapterIndex) {
    ReaderPageTurnOps.paginateContent(this, sourceContent, chapterIndex);
  }

  applyReaderPaginationResult(result: ReaderPaginationResult, fallbackContent: string): void {
    ReaderPageTurnOps.applyReaderPaginationResult(this, result, fallbackContent);
  }

  async turnNext() {
    this.resetAutoPageTurnCountdown();
    if (this.isReaderContinuousScrollSurfaceActive()) {
      this.scrollReaderComicByPage(1);
      return;
    }
    await this.runPageTurnAnimation(1, this.readerEffectivePageTurnMode() === 1 ? 'slide' : 'tap');
  }

  async turnPrev() {
    this.resetAutoPageTurnCountdown();
    if (this.isReaderContinuousScrollSurfaceActive()) {
      this.scrollReaderComicByPage(-1);
      return;
    }
    await this.runPageTurnAnimation(-1, this.readerEffectivePageTurnMode() === 1 ? 'slide' : 'tap');
  }

  setAutoPageTurnActive(enabled: boolean): void {
    ReaderPageTurnOps.setAutoPageTurnActive(this, enabled);
  }

  onAutoPageTurnActiveChanged(): void {
    if (this.autoPageTurnActive) {
      this.startAutoPageTurn();
    } else {
      this.stopAutoPageTurn(false);
    }
  }

  onAutoPageTurnIntervalChanged(): void {
    if (this.autoPageTurnController.isRunning()) {
      this.autoPageTurnController.setIntervalMs(this.autoPageTurnIntervalSec * 1000);
    }
  }

  configureAutoPageTurnController(): void {
    ReaderPageTurnOps.configureAutoPageTurnController(this);
  }

  startAutoPageTurn(): void {
    ReaderPageTurnOps.startAutoPageTurn(this);
  }

  stopAutoPageTurn(showToast: boolean): void {
    ReaderPageTurnOps.stopAutoPageTurn(this, showToast);
  }

  resetAutoPageTurnCountdown(): void {
    ReaderPageTurnOps.resetAutoPageTurnCountdown(this);
  }

  isAutoPageTurnBlocked(): boolean {
    return ReaderPageTurnOps.isAutoPageTurnBlocked(this);
  }

  isAtReaderBookEnd(): boolean {
    return ReaderPageTurnOps.isAtReaderBookEnd(this);
  }

  handleAutoPageTurnExpire(): void {
    ReaderPageTurnOps.handleAutoPageTurnExpire(this);
  }

  presentAutoPageTurnIntervalDialog(): void {
    this.showAutoPageTurnIntervalDialog = true;
    this.autoPageTurnIntervalDialogSession.open(this.getUIContext(), (): void => {
      AutoPageTurnIntervalDialogContent({
        onDone: (): void => {
          this.showAutoPageTurnIntervalDialog = false;
          this.autoPageTurnIntervalDialogSession.close(this.getUIContext());
        }
      })
    }, {
      autoCancel: true,
      maskColor: this.isReaderThemeDark() ? '#99000000' : '#33000000',
      warnTag: '显示自动翻页间隔设置弹窗失败:'
    });
  }

  scrollReaderComicByPage(direction: number): void {
    ReaderPageTurnOps.scrollReaderComicByPage(this, direction);
  }

  preloadReaderContent(): void {
    ReaderPageTurnOps.preloadReaderContent(this);
  }

  isTtsContinuousPreloadActive(): boolean {
    return ReaderPageTurnOps.isTtsContinuousPreloadActive(this);
  }


  preloadReaderContentLater(delayMs: number = 240): void {
    ReaderPageTurnOps.preloadReaderContentLater(this, delayMs);
  }

  canTurnPage(direction: number): boolean {
    return ReaderPageTurnOps.canTurnPage(this, direction);
  }

  isPreviousChapterTurnReady(): boolean {
    return ReaderPageTurnOps.isPreviousChapterTurnReady(this);
  }

  resumeDeferredPreviousChapterTurn(sourceChapterIndex: number): void {
    ReaderPageTurnOps.resumeDeferredPreviousChapterTurn(this, sourceChapterIndex);
  }

  // 向前跨章提交后等待增量排版补齐真实的最后一页（pendingRestorePageIndex 复位）。有界等待 + 兜底落页，
  // 任何情况（网络 hang、排版中断、页面隐藏）下都不会把用户留在提示页上；后台排版完成时会原地补齐边界。
  async waitForReaderChapterTailSettled(timeoutMs: number = 12000): Promise<void> {
    return ReaderPageTurnOps.waitForReaderChapterTailSettled(this, timeoutMs);
  }

  // 提交跨章前翻后，若提示页仍是通用“正在加载章节内容...”，按内容是否已在本地改为更明确的文案。
  showReaderTailWaitingLeafIfGeneric(): void {
    ReaderPageTurnOps.showReaderTailWaitingLeafIfGeneric(this);
  }

  ensureCurrentReaderPaginationAhead(requiredPageCount: number): void {
    ReaderPageTurnOps.ensureCurrentReaderPaginationAhead(this, requiredPageCount);
  }

  currentReaderPaginationResult(): ReaderPaginationResult | null {
    return ReaderPageTurnOps.currentReaderPaginationResult(this);
  }

  createContinuousReaderPagination(source: string): ReaderPaginationResult {
    return ReaderPageTurnOps.createContinuousReaderPagination(this, source);
  }

  isCurrentReaderPaginationComplete(): boolean {
    return ReaderPageTurnOps.isCurrentReaderPaginationComplete(this);
  }

  async applyPageTurn(direction: number, targetPreview: PageTurnPreview | null = null,
    commitText: boolean = true): Promise<void> {
    return ReaderPageTurnOps.applyPageTurn(this, direction, targetPreview, commitText);
  }

  applyLocalPageTurnTarget(targetPageIndex: number, targetPreview: PageTurnPreview | null = null,
    commitText: boolean = true): void {
    ReaderPageTurnOps.applyLocalPageTurnTarget(this, targetPageIndex, targetPreview, commitText);
  }

  capturePageTurnCommitTarget(direction: number): PageTurnPreview | null {
    return ReaderPageTurnOps.capturePageTurnCommitTarget(this, direction);
  }
  async runPageTurnAnimation(direction: number, style: string, fromQueue: boolean = false,
    releaseVelocity: number = 0): Promise<void> {
    return ReaderPageTurnOps.runPageTurnAnimation(this, direction, style, fromQueue, releaseVelocity);
  }

  prepareMirroredTtsManualPageTurn(): void {
    ReaderPageTurnOps.prepareMirroredTtsManualPageTurn(this);
  }

  scheduleMirroredTtsResumeAfterManualPageTurn(): void {
    ReaderPageTurnOps.scheduleMirroredTtsResumeAfterManualPageTurn(this);
  }

  cancelMirroredTtsManualPageTurn(): void {
    ReaderPageTurnOps.cancelMirroredTtsManualPageTurn(this);
  }

  // 手动翻页的“脱离跟随”冷却结束后的平滑重新跟随：回到朗读当前句，而不是一直停在人翻的位置。
  scheduleMirroredTtsResumeAfterSuppress(): void {
    ReaderPageTurnOps.scheduleMirroredTtsResumeAfterSuppress(this);
  }

  runQueuedPageTurnLater(): void {
    ReaderPageTurnOps.runQueuedPageTurnLater(this);
  }

  clearQueuedReaderPageTurns(): void {
    ReaderPageTurnOps.clearQueuedReaderPageTurns(this);
  }

  async runNoAnimationPageTurn(direction: number): Promise<void> {
    return ReaderPageTurnOps.runNoAnimationPageTurn(this, direction);
  }

  commitVisibleCurrentPageText(text: string = this.visibleCurrentPageText(), forceRender: boolean = false): void {
    ReaderPageTurnOps.commitVisibleCurrentPageText(this, text, forceRender);
  }

  commitVisibleCurrentPageTextLater(chapterIndex: number, pageIndex: number): void {
    ReaderPageTurnOps.commitVisibleCurrentPageTextLater(this, chapterIndex, pageIndex);
  }

  commitCurrentPageTextLater(chapterIndex: number, pageIndex: number, expectedText: string): void {
    ReaderPageTurnOps.commitCurrentPageTextLater(this, chapterIndex, pageIndex, expectedText);
  }

  commitCurrentPageTextAfterDelay(chapterIndex: number, pageIndex: number, expectedText: string, delayMs: number): void {
    ReaderPageTurnOps.commitCurrentPageTextAfterDelay(this, chapterIndex, pageIndex, expectedText, delayMs);
  }

  async runLegacyPageTurn(direction: number): Promise<void> {
    return ReaderPageTurnOps.runLegacyPageTurn(this, direction);
  }

  async runTapPageTurn(direction: number): Promise<void> {
    return ReaderPageTurnOps.runTapPageTurn(this, direction);
  }

  async runSlidePageTurn(direction: number, queuedGesture: boolean = false,
    releaseVelocity: number = 0): Promise<void> {
    return ReaderPageTurnOps.runSlidePageTurn(this, direction, queuedGesture, releaseVelocity);
  }

  async finishAnimatedPageTurn(): Promise<void> {
    return ReaderPageTurnOps.finishAnimatedPageTurn(this);
  }

  prepareIncomingPageTurn(direction: number): void {
    ReaderPageTurnOps.prepareIncomingPageTurn(this, direction);
  }

  prepareSlidePageTurn(direction: number, offset: number): void {
    ReaderPageTurnOps.prepareSlidePageTurn(this, direction, offset);
  }

  finishPageTurnAnimation(releaseTurnLock: boolean = true): void {
    ReaderPageTurnOps.finishPageTurnAnimation(this, releaseTurnLock);
  }

  finishPageTurnAnimationLater(): void {
    ReaderPageTurnOps.finishPageTurnAnimationLater(this);
  }

  setPageTurnIncomingState(pageIndex: number, text: string, animating: boolean = true,
    chapterIndex: number = this.currentChapterIndex, secondaryText: string = '', pageStart: number = -1,
    secondaryPageStart: number = -1, documentSource: string = ''): void {
    ReaderPageTurnOps.setPageTurnIncomingState(this, pageIndex, text, animating, chapterIndex, secondaryText, pageStart, secondaryPageStart, documentSource);
  }

  getPageTurnTargetText(direction: number): string {
    return ReaderPageTurnOps.getPageTurnTargetText(this, direction);
  }

  getPageTurnTargetPageIndex(direction: number = 0): number {
    return ReaderPageTurnOps.getPageTurnTargetPageIndex(this, direction);
  }

  getLocalPageTurnTargetPageIndex(direction: number): number {
    return ReaderPageTurnOps.getLocalPageTurnTargetPageIndex(this, direction);
  }

  getAdjacentPageTurnChapterIndex(direction: number): number {
    return ReaderPageTurnOps.getAdjacentPageTurnChapterIndex(this, direction);
  }

  updatePageTurnIncomingForDirection(direction: number): void {
    ReaderPageTurnOps.updatePageTurnIncomingForDirection(this, direction);
  }

  buildPageTurnPreviewKey(direction: number, chapterIndex: number): string {
    return ReaderPageTurnOps.buildPageTurnPreviewKey(this, direction, chapterIndex);
  }

  buildCachedAdjacentPageTurnPreview(direction: number, chapterIndex: number): PageTurnPreview {
    return ReaderPageTurnOps.buildCachedAdjacentPageTurnPreview(this, direction, chapterIndex);
  }

  buildAdjacentPageTurnPreview(direction: number, chapterIndex: number, preparedBody: string): PageTurnPreview {
    return ReaderPageTurnOps.buildAdjacentPageTurnPreview(this, direction, chapterIndex, preparedBody);
  }

  getPageTurnLoadingText(chapterIndex: number): string {
    return ReaderPageTurnOps.getPageTurnLoadingText(this, chapterIndex);
  }

  applyPageTurnPreview(preview: PageTurnPreview): void {
    ReaderPageTurnOps.applyPageTurnPreview(this, preview);
  }

  loadAdjacentPageTurnPreview(direction: number, chapterIndex: number, key: string): void {
    ReaderPageTurnOps.loadAdjacentPageTurnPreview(this, direction, chapterIndex, key);
  }

  isCurrentReaderEngineBook(expectedBookUrl: string = this.book?.bookUrl || this.bookUrl): boolean {
    return ReaderPageTurnOps.isCurrentReaderEngineBook(this, expectedBookUrl);
  }

  updateSlidePageEffect(offset: number): void {
    ReaderPageTurnOps.updateSlidePageEffect(this, offset);
  }

  updateLegacySlidePageEffect(offset: number): void {
    ReaderPageTurnOps.updateLegacySlidePageEffect(this, offset);
  }

  rollbackSlidePageEffect(): void {
    ReaderPageTurnOps.rollbackSlidePageEffect(this);
  }

  async rollbackReaderPageCurl(duration: number, serial: number): Promise<void> {
    return ReaderPageTurnOps.rollbackReaderPageCurl(this, duration, serial);
  }

  resetSlidePageEffect(): void {
    ReaderPageTurnOps.resetSlidePageEffect(this);
  }

  getVisiblePageTurnIncomingText(): string {
    return ReaderPageTurnOps.getVisiblePageTurnIncomingText(this);
  }

  getVisiblePageTurnIncomingOpacity(): number {
    return ReaderPageTurnOps.getVisiblePageTurnIncomingOpacity(this);
  }

  getPageTurnWidth(): number {
    return ReaderPageTurnOps.getPageTurnWidth(this);
  }

  getPageTurnHeight(): number {
    return ReaderPageTurnOps.getPageTurnHeight(this);
  }

  isVerticalPageTurnAnimation(): boolean {
    return ReaderPageTurnOps.isVerticalPageTurnAnimation(this);
  }

  // 3D 仿真在单页与左右双页下都走卷曲画布管线；双页时由 ReaderEmulationFlipPainter 处理半页纸的卷起与落地。
  effectivePageTurnAnimationType(): number {
    return ReaderPageTurnOps.effectivePageTurnAnimationType(this);
  }

  isStackPageTurnAnimation(): boolean {
    return ReaderPageTurnOps.isStackPageTurnAnimation(this);
  }

  isSimulationPageTurnAnimation(): boolean {
    return ReaderPageTurnOps.isSimulationPageTurnAnimation(this);
  }

  is3DPageTurnAnimation(): boolean {
    return ReaderPageTurnOps.is3DPageTurnAnimation(this);
  }

  // 仿真与 3D 仿真都依赖同一个卷曲画布管线：截图当前页、底层铺目标页、由 Canvas 绘制翻页。
  usesReaderPageCurlCanvas(): boolean {
    return ReaderPageTurnOps.usesReaderPageCurlCanvas(this);
  }

  // 对应官方示例 initPanPositionX：按手指落点决定卷曲从上角/下角/中部开始。
  // 折页背面的纸张底色：取主题背景色；背景图主题的背景色常为全透明，此时退回白纸避免透出下层。
  readerFlapPaperColor(): string {
    return ReaderPageTurnOps.readerFlapPaperColor(this);
  }

  captureReaderCurlStartRegion(event: GestureEvent): void {
    ReaderPageTurnOps.captureReaderCurlStartRegion(this, event);
  }

  pageTurnAnimationCurve(): Curve {
    return ReaderPageTurnOps.pageTurnAnimationCurve(this);
  }

  getReaderPageCurlCanvasHeight(): number {
    return ReaderPageTurnOps.getReaderPageCurlCanvasHeight(this);
  }

  readerPageCurlKey(): string {
    return ReaderPageTurnOps.readerPageCurlKey(this);
  }

  drawReaderPageCurl(): void {
    ReaderPageTurnOps.drawReaderPageCurl(this);
  }

  requestReaderPageCurlCapture(): void {
    ReaderPageTurnOps.requestReaderPageCurlCapture(this);
  }

  async captureReaderPageCurlSnapshots(serial: number, key: string): Promise<void> {
    return ReaderPageTurnOps.captureReaderPageCurlSnapshots(this, serial, key);
  }

  async cropReaderPageCurlFrontToTurningLeaf(front: image.PixelMap): Promise<void> {
    return ReaderPageTurnOps.cropReaderPageCurlFrontToTurningLeaf(this, front);
  }

  async ensureReaderPageCurlReady(): Promise<boolean> {
    return ReaderPageTurnOps.ensureReaderPageCurlReady(this);
  }

  async completeSimulationPageTurnMotion(direction: number): Promise<void> {
    return ReaderPageTurnOps.completeSimulationPageTurnMotion(this, direction);
  }

  resetReaderPageCurl(): void {
    ReaderPageTurnOps.resetReaderPageCurl(this);
  }

  animateReaderPageCurlOffset(targetOffset: number, duration: number,
    completingPageTurn: boolean = false): Promise<void> {
    return ReaderPageTurnOps.animateReaderPageCurlOffset(this, targetOffset, duration, completingPageTurn);
  }

  getSimulationSpineColor(): string {
    return ReaderPageTurnOps.getSimulationSpineColor(this);
  }

  getPageTurnDistance(): number {
    return ReaderPageTurnOps.getPageTurnDistance(this);
  }

  getPageSlideAxisOffset(): number {
    return ReaderPageTurnOps.getPageSlideAxisOffset(this);
  }

  setPageSlideAxisOffset(offset: number): void {
    ReaderPageTurnOps.setPageSlideAxisOffset(this, offset);
  }

  shouldRenderSlidingPageTurn(): boolean {
    return ReaderPageTurnOps.shouldRenderSlidingPageTurn(this);
  }

  getPageTurnProgress(): number {
    return ReaderPageTurnOps.getPageTurnProgress(this);
  }

  getCurrentPageTurnX(): number {
    return ReaderPageTurnOps.getCurrentPageTurnX(this);
  }

  getCurrentPageTurnY(): number {
    return ReaderPageTurnOps.getCurrentPageTurnY(this);
  }

  getCurrentPageTurnOpacity(): number {
    return ReaderPageTurnOps.getCurrentPageTurnOpacity(this);
  }

  getSlideIncomingX(direction: number, offsetX: number, width: number = this.getPageTurnWidth()): number {
    return ReaderPageTurnOps.getSlideIncomingX(this, direction, offsetX, width);
  }

  getIncomingSlideX(): number {
    return ReaderPageTurnOps.getIncomingSlideX(this);
  }

  getSlideIncomingY(direction: number, offsetY: number, height: number = this.getPageTurnHeight()): number {
    return ReaderPageTurnOps.getSlideIncomingY(this, direction, offsetY, height);
  }

  getIncomingSlideY(): number {
    return ReaderPageTurnOps.getIncomingSlideY(this);
  }

  resetSlidePageState(): void {
    ReaderPageTurnOps.resetSlidePageState(this);
  }

  clearPageTurnPreviewState(): void {
    ReaderPageTurnOps.clearPageTurnPreviewState(this);
  }

  buildBookPreview(): string {
    return ReaderPageTurnOps.buildBookPreview(this);
  }

  async jumpToAdjacentChapterFirstPage(direction: number): Promise<void> {
    return ReaderPageTurnOps.jumpToAdjacentChapterFirstPage(this, direction);
  }

  async loadNextChapter(showLoading: boolean = false, showBoundaryToast: boolean = false): Promise<void> {
    return ReaderPageTurnOps.loadNextChapter(this, showLoading, showBoundaryToast);
  }

  async loadPrevChapter(toLastPage: boolean = false, showLoading: boolean = false,
    showBoundaryToast: boolean = false): Promise<void> {
    return ReaderPageTurnOps.loadPrevChapter(this, toLastPage, showLoading, showBoundaryToast);
  }
}
//endregion
