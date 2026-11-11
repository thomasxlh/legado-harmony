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

export function cleanChapterTitle(page: ReadBookPage, title: string): string {
    const original = (title || '').trim();
    const cleaned = original
      .replace(/\s+/g, ' ')
      .replace(/[\s·|｜/／-]*上次(?:阅读|閱讀)(?:[\s:：，,。]*.*)?$/g, '')
      .replace(/^上次(?:阅读|閱讀)[\s:：，,。]*/g, '')
      .trim();
    return cleaned || original;
}

export function updatePendingVerification(page: ReadBookPage): void {
    page.verificationUrl = AppStorage.get<string>('pendingVerificationUrl') || '';
    page.verificationTitle = AppStorage.get<string>('pendingVerificationTitle') || '网页验证';
}

export function openVerificationPage(page: ReadBookPage): void {
    const url = page.verificationUrl || AppStorage.get<string>('pendingVerificationUrl') || '';
    if (!url) return;
    router.pushUrl({
      url: 'pages/VerifyWeb',
      params: {
        url: url,
        title: page.verificationTitle || '网页验证'
      }
    });
}

export function getProgressText(page: ReadBookPage): string {
    if (page.chapters.length === 0) return '';
    if (page.contentPages.length === 0) {
      return `${page.currentChapterIndex + 1}/${page.chapters.length}`;
    }
    const pageText = page.isLandscapeDoublePageActive() ?
      `${page.currentPageIndex + 1}-${Math.min(page.currentPageIndex + 2, page.contentPages.length)}` :
      `${page.currentPageIndex + 1}`;
    return `${page.currentChapterIndex + 1}/${page.chapters.length} · ${pageText}/${page.contentPages.length}`;
}

export function getChapterInfoText(page: ReadBookPage): string {
    if (page.chapters.length === 0) {
      return page.book?.name || '暂无目录';
    }
    const index = page.clampChapterIndex(page.currentChapterIndex);
    const chapter = page.chapters[index];
    return `${index + 1}/${page.chapters.length} ${chapter ? page.getChapterTitle(index) : page.getChapterTitle()}`;
}

export function getReaderHeaderInfoText(page: ReadBookPage): string {
    const mode = page.readerHeaderContentMode;
    if (mode === 'book') return page.book?.name || '未命名书籍';
    if (mode === 'book_chapter') {
      const title = page.getChapterTitle(page.clampChapterIndex(page.currentChapterIndex));
      return `${page.book?.name || '未命名书籍'} · ${title}`;
    }
    if (mode === 'none') return '';
    return page.getChapterTitle(page.clampChapterIndex(page.currentChapterIndex));
}

export function getReaderFooterLeftText(page: ReadBookPage): string {
    if (page.readerFooterLeftMode === 'none') return '';
    if (page.readerFooterLeftMode === 'title') {
      return page.getChapterTitle(page.clampChapterIndex(page.currentChapterIndex));
    }
    return page.getChapterInfoText();
}

export function getReaderFooterProgressValue(page: ReadBookPage): number {
    if (page.readerFooterProgressMode === 'book') {
      return Math.max(0, Math.min(100, ((page.currentChapterIndex + 1) / Math.max(1, page.chapters.length)) * 100));
    }
    return Math.max(0, Math.min(100,
      ((Math.max(0, page.currentPageIndex) + 1) / Math.max(1, page.contentPages.length)) * 100));
}

export function getPageInfoText(page: ReadBookPage): string {
    if (page.contentPages.length === 0) {
      return '1/1';
    }
    const index = Math.max(0, Math.min(page.currentPageIndex, page.contentPages.length - 1));
    if (page.isLandscapeDoublePageActive()) {
      const end = Math.min(index + 2, page.contentPages.length);
      return `${index + 1}-${end}/${page.contentPages.length}`;
    }
    return `${index + 1}/${page.contentPages.length}`;
}

export function getPageText(page: ReadBookPage, pageIndex: number): string {
    if (page.contentPages.length === 0) {
      if (page.content && !page.hasPagedReaderArea()) {
        return '';
      }
      return page.content;
    }
    const index = Math.max(0, Math.min(pageIndex, page.contentPages.length - 1));
    return page.contentPages[index];
}

export function getCurrentPageText(page: ReadBookPage): string {
    return page.getPageText(page.currentPageIndex);
}

export function isLandscapeDoublePageActive(page: ReadBookPage): boolean {
    return page.readerLandscapeDoublePage &&
      page.pageViewWidth > page.pageViewHeight &&
      !page.isReaderContinuousScrollSurfaceActive();
}

export function initializeReaderComicMode(page: ReadBookPage): void {
    const manualMode = page.book?.getVariable('readerComicManualMode') || '';
    const autoDetected = page.book?.getVariable('readerComicAutoDetected') === '1';
    page.readerComicMode = manualMode === 'comic' ||
      (manualMode !== 'text' && (autoDetected || page.readerSourceIndicatesComic()));
    if (page.readerComicMode) {
      page.stopTtsReading();
      page.showSettings = false;
      page.ttsMediaControlsExpanded = false;
    }
    page.enterReaderImmersive();
}

export function readerSourceIndicatesComic(page: ReadBookPage): boolean {
    const source = LeafFns.currentReaderSource();
    if (BookTypeSupport.isImage(page.book)) {
      return true;
    }
    // Legado's "full" imageStyle only controls how inline illustrations fill the
    // reader width. Text sources such as 神魔小说 use it as well, so it must not
    // switch the whole book to the continuous comic renderer.
    if (source && (source.bookSourceType === 2 ||
      /^(?:comic|manga|webtoon)$/i.test(source.contentRule?.imageStyle || ''))) {
      return true;
    }
    const bookIdentity = `${page.book?.kind || ''}\n${page.book?.customTag || ''}`;
    const sourceIdentity = source ? `${source.bookSourceGroup || ''}\n${source.bookSourceName || ''}` : '';
    return /漫画|漫話|条漫|條漫|コミック|comic|manga|manhua|webtoon/i.test(
      `${bookIdentity}\n${sourceIdentity}`);
}

export function detectReaderComicMode(page: ReadBookPage, _source: string): void {
    if (page.readerComicMode || !page.readerSourceIndicatesComic() ||
      page.book?.getVariable('readerComicManualMode') === 'text') return;
    page.readerComicMode = true;
    page.showSettings = false;
    page.ttsMediaControlsExpanded = false;
    page.stopTtsReading();
    page.enterReaderImmersive();
}

export function toggleReaderComicReadingMode(page: ReadBookPage): void {
    if (!page.book) return;
    const next = !page.isReaderComicModeActive();
    page.stopTtsReading();
    page.readerComicMode = next;
    page.book.putVariable('readerComicManualMode', next ? 'comic' : 'text');
    // 继续写入旧字段，兼容已有导入导出数据；实际判定优先读取手动模式字段。
    page.book.putVariable('readerComicMode', next ? '1' : '0');
    AppDatabase.getInstance().updateBook(page.book, false).catch((error: Error) => {
      console.warn('保存阅读模式失败:', error);
    });
    page.showReaderActionMenu = false;
    page.showSettings = false;
    page.ttsMediaControlsExpanded = false;
    page.resetSlidePageEffect();
    page.syncReaderComicPageDataSource();
    if (next) {
      page.scheduleReaderComicScrollRestore();
    }
    page.enterReaderImmersive();
    HdsFeedback.showToast(next ? '已切换为漫画阅读' : '已切换为普通阅读');
}

export function isReaderComicModeActive(page: ReadBookPage): boolean {
    return page.readerComicMode;
}

export function isReaderNovelContinuousScrollModeActive(page: ReadBookPage): boolean {
    return !page.isReaderComicModeActive() && page.readerPageTurnMode === 3 && !page.ttsPagedScrollOverride;
}

export function isReaderContinuousScrollSurfaceActive(page: ReadBookPage): boolean {
    return page.isReaderComicModeActive() || page.isReaderNovelContinuousScrollModeActive();
}

export function readerEffectivePageTurnMode(page: ReadBookPage): number {
    return page.ttsPagedScrollOverride && page.readerPageTurnMode === 3 ? 0 : page.readerPageTurnMode;
}

export function comicBoundaryChapterSwipeDirection(page: ReadBookPage, offsetY: number): number {
    if (!page.isReaderContinuousScrollSurfaceActive() || page.readerComicChapterSwitching || Math.abs(offsetY) < 2) {
      return 0;
    }
    try {
      if (offsetY < 0 && page.currentChapterIndex < page.chapters.length - 1 &&
        page.readerComicScroller.isAtEnd()) {
        return 1;
      }
      if (offsetY > 0 && page.currentChapterIndex > 0 &&
        page.readerComicScroller.currentOffset().yOffset <= 1) {
        return -1;
      }
    } catch (error) {
      console.warn('判断漫画章节滚动边界失败:', error);
    }
    return 0;
}

export function beginReaderComicPan(page: ReadBookPage): void {
    if (page.readerComicChapterSwitching) return;
    page.readerComicPanLastOffsetY = 0;
    page.readerComicPanMoved = false;
    page.readerComicBoundaryProbeNotUntil = 0;
    page.readerComicBoundaryPullOriginY = 0;
    page.resetReaderComicBoundaryFeedback(false);
}

export function updateReaderComicPan(page: ReadBookPage, event: GestureEvent): void {
    if (page.readerComicChapterSwitching) return;
    const previousOffsetY = page.readerComicPanLastOffsetY;
    const deltaY = event.offsetY - previousOffsetY;
    page.readerComicPanLastOffsetY = event.offsetY;
    if (Math.abs(event.offsetY) > 3) page.readerComicPanMoved = true;
    page.readerComicScroller.scrollBy(0, -deltaY);

    // 边界探测需要读取滚动器状态（同步原生调用）；已处于边界拉动状态时保持逐事件更新，
    // 否则每 24ms 探测一次即可。
    const now = Date.now();
    if (page.readerComicBoundaryDirection === 0 && now < page.readerComicBoundaryProbeNotUntil) {
      return;
    }
    page.readerComicBoundaryProbeNotUntil = now + 24;
    const direction = page.comicBoundaryChapterSwipeDirection(event.offsetY);
    if (direction === 0) {
      if (page.readerComicBoundaryDirection !== 0) page.resetReaderComicBoundaryFeedback(true);
      return;
    }
    if (direction !== page.readerComicBoundaryDirection) {
      page.readerComicBoundaryDirection = direction;
      page.readerComicBoundaryPullOriginY = previousOffsetY;
    }
    const distance = Math.min(88, Math.abs(event.offsetY - page.readerComicBoundaryPullOriginY));
    page.readerComicBoundaryPullDistance = distance;
    page.readerComicBoundaryReady = distance >= 48;
    page.readerComicChapterTransitionY = (direction < 0 ? 1 : -1) * Math.min(20, distance * 0.3);
    page.readerComicChapterTransitionOpacity = 1;
}

export function finishReaderComicPan(page: ReadBookPage, event: GestureEvent): void {
    if (page.readerComicChapterSwitching) return;
    const chapterDirection = page.readerComicBoundaryReady ? page.readerComicBoundaryDirection : 0;
    const hadBoundaryPull = page.readerComicBoundaryDirection !== 0;
    if (chapterDirection !== 0) {
      page.readerComicSuppressClickUntil = Date.now() + 360;
      page.switchComicBoundaryChapter(chapterDirection);
    } else {
      if (page.readerComicPanMoved && !hadBoundaryPull) {
        page.readerComicSuppressClickUntil = Date.now() + 220;
        page.readerComicScroller.fling(event.velocityY);
      }
      page.resetReaderComicBoundaryFeedback(true);
    }
    page.readerComicPanLastOffsetY = 0;
    page.readerComicPanMoved = false;
    page.readerComicBoundaryPullOriginY = 0;
}

export function cancelReaderComicPan(page: ReadBookPage): void {
    page.readerComicPanLastOffsetY = 0;
    page.readerComicPanMoved = false;
    page.readerComicBoundaryPullOriginY = 0;
    page.resetReaderComicBoundaryFeedback(true);
}

export function resetReaderComicBoundaryFeedback(page: ReadBookPage, animated: boolean): void {
    page.readerComicBoundaryDirection = 0;
    page.readerComicBoundaryPullDistance = 0;
    page.readerComicBoundaryReady = false;
    if (page.readerComicChapterSwitching) return;
    if (animated) {
      animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
        page.readerComicChapterTransitionY = 0;
        page.readerComicChapterTransitionOpacity = 1;
      });
    } else {
      page.readerComicChapterTransitionY = 0;
      page.readerComicChapterTransitionOpacity = 1;
    }
}

export function readerComicBoundaryHintText(page: ReadBookPage): string {
    const previous = page.readerComicBoundaryDirection < 0;
    if (page.readerComicChapterSwitching) return previous ? '正在加载上一章…' : '正在加载下一章…';
    if (page.readerComicBoundaryReady) return previous ? '松开加载上一章' : '松开加载下一章';
    return previous ? '下拉加载上一章' : '上滑加载下一章';
}

export function switchComicBoundaryChapter(page: ReadBookPage, direction: number): void {
    if (direction === 0 || page.readerComicChapterSwitching) return;
    page.runReaderComicChapterTransition(direction).catch((error: Error) => {
      console.error('滚动切换漫画章节失败:', error);
    });
}

export async function runReaderComicChapterTransition(page: ReadBookPage, direction: number): Promise<void> {
    if (direction === 0 || page.readerComicChapterSwitching) return;
    const startedAt = Date.now();
    const sourceChapterIndex = page.currentChapterIndex;
    page.readerComicChapterSwitching = true;
    page.readerComicBoundaryDirection = direction;
    page.readerComicBoundaryPullDistance = Math.max(48, page.readerComicBoundaryPullDistance);
    page.readerComicBoundaryReady = true;
    animateTo({ duration: 90, curve: Curve.EaseIn }, () => {
      page.readerComicChapterTransitionY = direction > 0 ? -34 : 34;
      page.readerComicChapterTransitionOpacity = 0.18;
    });
    // Cached fetch, content preprocessing and pagination can run while the outgoing chapter
    // performs its short transition. Waiting for the animation first added a fixed stall to
    // every boundary switch even when the previous chapter tail was already prepared.
    const chapterLoad = direction > 0 ? page.loadNextChapter(false, false) :
      page.loadPrevChapter(true, false, false);
    await LeafFns.delay(72);
    try {
      await chapterLoad;
      // loadContent publishes the first incremental V2 page before a deep/last-page restore has necessarily
      // reached its target. Keep the compact boundary hint (rather than exposing the full-screen restore panel)
      // until that authoritative target is ready. The common previous-chapter tail is completed synchronously
      // from the durable page boundaries below, so this normally resolves in the same frame.
      await page.waitForReaderComicBoundaryRestore();
      const switched = page.currentChapterIndex !== sourceChapterIndex;
      page.readerComicChapterTransitionY = switched ? (direction > 0 ? 28 : -28) :
        (direction > 0 ? -20 : 20);
      page.readerComicChapterTransitionOpacity = switched ? 0 : 0.35;
      await LeafFns.delay(8);
      animateTo({ duration: 150, curve: Curve.Friction }, () => {
        page.readerComicChapterTransitionY = 0;
        page.readerComicChapterTransitionOpacity = 1;
      });
      await LeafFns.delay(154);
      console.info(`[ReaderBoundary] direction=${direction} switched=${switched} elapsed=${Date.now() - startedAt}ms`);
    } finally {
      page.readerComicSuppressClickUntil = Date.now() + 320;
      page.suppressReaderTapClick = true;
      page.readerComicChapterSwitching = false;
      page.readerComicBoundaryDirection = 0;
      page.readerComicBoundaryPullDistance = 0;
      page.readerComicBoundaryReady = false;
      page.readerComicBoundaryPullOriginY = 0;
      page.readerComicChapterTransitionY = 0;
      page.readerComicChapterTransitionOpacity = 1;
    }
}

export function syncReaderComicPageDataSource(page: ReadBookPage): void {
    const reloaded = page.readerComicPageDataSource.replace(page.contentPages);
    const ratios: number[] = [];
    for (let i = 0; i < page.contentPages.length; i++) {
      ratios.push(page.readerComicImageRatios[i] || 0);
    }
    page.readerComicImageRatios = ratios;
    page.reanchorContinuousReaderScrollAfterReload(reloaded);
}

export function reanchorContinuousReaderScrollAfterReload(page: ReadBookPage, reloaded: boolean): void {
    // 只作用于小说滚动模式：漫画模式有自己的章节切换/恢复时序，且本地漫画分页是单次同步发布，
    // 不会出现阅读中 reload，保持其原有行为以隔离变量。
    if (!reloaded || !page.isReaderNovelContinuousScrollModeActive() || !page.readerInitialPageReady ||
      !page.readerProgressRestoreConfirmed || page.pendingRestorePageIndex >= 0 ||
      page.readerComicScrollRestoring || page.contentPages.length === 0) {
      return;
    }
    const serial = ++page.readerComicReanchorSerial;
    const chapterIndex = page.currentChapterIndex;
    const targetIndex = Math.max(0, Math.min(page.currentPageIndex, page.contentPages.length - 1));
    setTimeout(() => {
      if (serial !== page.readerComicReanchorSerial || chapterIndex !== page.currentChapterIndex ||
        !page.readerPageVisible || page.readerComicScrollRestoring || page.pendingRestorePageIndex >= 0) {
        return;
      }
      try {
        page.readerComicScroller.scrollToIndex(targetIndex, false, ScrollAlign.START);
      } catch (_) {
      }
    }, 48);
}

export function getReaderComicImageHeight(page: ReadBookPage, index: number): number {
    // 尺寸读取期间使用接近图片宽度的短占位，避免解码失败时每张图片都遗留整屏空白。
    const fallbackHeight = Math.max(240, page.pageViewWidth);
    const ratio = index >= 0 && index < page.readerComicImageRatios.length ?
      page.readerComicImageRatios[index] : 0;
    if (ratio <= 0 || page.pageViewWidth <= 0) return fallbackHeight;
    const height = Math.max(120, Math.min(24000, page.pageViewWidth * ratio));
    // ListItem 会分别把浮点 vp 高度转换为物理像素；先对齐到整数像素，避免相邻项反向取整后露底。
    return px2vp(Math.max(1, Math.round(vp2px(height))));
}

export function getReaderComicImageSeamOverlap(page: ReadBookPage, index: number): number {
    return index > 0 && index < page.contentPages.length &&
      LeafFns.isReaderImageOnlyPage(page.contentPages[index - 1]) ? px2vp(1) : 0;
}

export function getReaderComicImageRenderHeight(page: ReadBookPage, index: number): number {
    return page.getReaderComicImageHeight(index) + page.getReaderComicImageSeamOverlap(index);
}

export function getReaderComicImageFit(page: ReadBookPage, index: number): ImageFit {
    const ratio = index >= 0 && index < page.readerComicImageRatios.length ?
      page.readerComicImageRatios[index] : 0;
    // 原图比例尚未返回时保持 Contain；比例已知后容器已经严格等比，Fill 只消除边缘 letterbox。
    return ratio > 0 ? ImageFit.Fill : ImageFit.Contain;
}

export function updateReaderComicImageRatio(page: ReadBookPage, index: number, sourceWidth: number, sourceHeight: number): void {
    if (index < 0 || sourceWidth <= 0 || sourceHeight <= 0 || index >= page.contentPages.length) return;
    const ratio = sourceHeight / sourceWidth;
    if (!Number.isFinite(ratio) || ratio <= 0) return;
    const currentRatio = page.readerComicImageRatios[index] || 0;
    if (Math.abs(currentRatio - ratio) < 0.0001) return;
    const ratios = [...page.readerComicImageRatios];
    while (ratios.length < page.contentPages.length) {
      ratios.push(0);
    }
    ratios[index] = ratio;
    page.readerComicImageRatios = ratios;
    // LazyForEach 不会因为外部的比例数组变化而自动重建已经生成的 ListItem。
    // 显式通知当前图片项刷新，否则初始整屏占位会一直保留，形成图片之间的大块空白。
    page.readerComicPageDataSource.notifyChanged(index);
}

export async function ensureReaderComicImageRatio(page: ReadBookPage, index: number, marker: string): Promise<void> {
    if (index < 0 || index >= page.contentPages.length || page.readerComicImageRatios[index] > 0 ||
      page.contentPages[index] !== marker) {
      return;
    }
    const path = LocalBookService.epubImagePathFromMarker(marker);
    if (!path || /^(?:https?:|data:)/i.test(path)) return;
    const cachedRatio = page.readerComicImageRatioCache.get(path) || 0;
    if (cachedRatio > 0) {
      page.updateReaderComicImageRatio(index, 1, cachedRatio);
      return;
    }
    if (page.readerComicImageRatioLoading.has(path)) return;
    page.readerComicImageRatioLoading.add(path);
    let file: fs.File | null = null;
    let source: image.ImageSource | null = null;
    try {
      file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      source = image.createImageSource(file.fd);
      const info = await source.getImageInfo();
      const width = info.size.width;
      const height = info.size.height;
      if (width > 0 && height > 0) {
        const ratio = height / width;
        page.readerComicImageRatioCache.set(path, ratio);
        if (index < page.contentPages.length && page.contentPages[index] === marker) {
          page.updateReaderComicImageRatio(index, width, height);
        }
      }
    } finally {
      page.readerComicImageRatioLoading.delete(path);
      if (source) {
        try {
          await source.release();
        } catch (_) {
        }
      }
      if (file) {
        try {
          fs.closeSync(file);
        } catch (_) {
        }
      }
    }
}

export function scheduleReaderComicScrollRestore(page: ReadBookPage): void {
    if (!page.isReaderContinuousScrollSurfaceActive() || page.contentPages.length === 0) return;
    const serial = ++page.readerComicScrollRestoreSerial;
    const chapterIndex = page.currentChapterIndex;
    const pageIndex = Math.max(0, Math.min(page.currentPageIndex, page.contentPages.length - 1));
    page.readerComicScrollRestoring = true;
    let attempt = 0;
    const maxAttempts = 5;
    const restore = (): void => {
      if (serial !== page.readerComicScrollRestoreSerial || chapterIndex !== page.currentChapterIndex ||
        !page.isReaderContinuousScrollSurfaceActive()) {
        return;
      }
      try {
        page.readerComicScroller.scrollToIndex(pageIndex, false, ScrollAlign.START);
      } catch (error) {
        console.warn('恢复漫画滚动位置失败:', error);
      }
      setTimeout(() => {
        if (serial !== page.readerComicScrollRestoreSerial || chapterIndex !== page.currentChapterIndex) return;
        const visiblePageIndex = Math.max(0,
          Math.min(page.readerContinuousVisibleStart, page.contentPages.length - 1));
        const lastPagePinnedToBottom = pageIndex === page.contentPages.length - 1 &&
          page.readerContinuousVisibleEnd >= pageIndex;
        if (visiblePageIndex !== pageIndex && !lastPagePinnedToBottom && attempt < maxAttempts) {
          attempt++;
          setTimeout(restore, Math.min(160, 24 + attempt * 24));
          return;
        }
        // Do not let a provisional index callback replace the durable target. Even on devices that do not emit
        // onScrollIndex for an immediate jump, keep the logical page authoritative; the final retry above has
        // already aligned the List as closely as the current viewport permits.
        page.currentPageIndex = pageIndex;
        page.currentPageText = page.contentPages[pageIndex] || '';
        page.readerContinuousReachedEnd = pageIndex === page.contentPages.length - 1;
        page.readerComicScrollRestoring = false;
        if (visiblePageIndex !== pageIndex && !lastPagePinnedToBottom) {
          console.warn(`[ReaderProgress] continuous restore settled without index callback: ` +
            `chapter=${chapterIndex},target=${pageIndex},visible=${visiblePageIndex}`);
        }
      }, attempt === 0 ? 96 : 128);
    };
    setTimeout(restore, 16);
}

export function onReaderComicScrollIndexChanged(page: ReadBookPage, start: number, end: number): void {
    // ArkUI can publish one final List index while the route is being detached. That callback describes the
    // shrinking/unmounted viewport, not a user scroll, and must not replace the page captured by exit/background.
    if (!page.readerPageVisible) return;
    page.readerContinuousVisibleStart = Math.max(0, Math.round(start));
    page.readerContinuousVisibleEnd = Math.max(page.readerContinuousVisibleStart, Math.round(end));
    if (page.readerContinuousVisibleEnd < page.contentPages.length - 1) {
      page.readerContinuousReachedEnd = false;
    }
    page.pruneContinuousReaderSelectionAreas();
    if (!page.isReaderContinuousScrollSurfaceActive() || page.readerComicScrollRestoring ||
      page.pendingRestorePageIndex >= 0 || page.contentPages.length === 0) {
      return;
    }
    const pageIndex = page.readerContinuousReachedEnd &&
      page.readerContinuousVisibleEnd >= page.contentPages.length - 1 ? page.contentPages.length - 1 :
      Math.max(0, Math.min(Math.round(start), page.contentPages.length - 1));
    if (pageIndex === page.currentPageIndex) return;
    page.currentPageIndex = pageIndex;
    page.currentPageText = page.contentPages[pageIndex] || '';
    if (page.contentPages.length - pageIndex <= 4) {
      page.preloadReaderContentLater();
      page.preloadNextChapterPaginationLater(0);
    }
    if (pageIndex <= 3) page.preloadPreviousChapterPaginationLater(0);
    page.scheduleReaderComicProgressSave();
}

export function onReaderContinuousReachEnd(page: ReadBookPage): void {
    if (!page.readerPageVisible || !page.isReaderContinuousScrollSurfaceActive() ||
      page.contentPages.length === 0) return;
    page.readerContinuousReachedEnd = true;
    if (page.readerComicScrollRestoring || page.pendingRestorePageIndex >= 0) return;
    const lastPageIndex = page.contentPages.length - 1;
    if (page.currentPageIndex === lastPageIndex) return;
    page.currentPageIndex = lastPageIndex;
    page.currentPageText = page.contentPages[lastPageIndex] || '';
    page.preloadReaderContentLater();
    page.preloadNextChapterPaginationLater(0);
    page.scheduleReaderComicProgressSave();
}

export function pruneContinuousReaderSelectionAreas(page: ReadBookPage): void {
    const keepStart = Math.max(0, page.readerContinuousVisibleStart - 1);
    const keepEnd = page.readerContinuousVisibleEnd + 1;
    for (const key of Array.from(page.readerSelectableTextAreas.keys())) {
      // 原生选中键与可见段键都要按窗口清理：懒挂载后原生键只在挂载瞬间登记一次，
      // 残留的旧几何会把下一次选择窗口锚到过期位置。
      if (!key.startsWith('reader_continuous_native_') && !key.includes('reader_vertical_scroll_')) continue;
      const pageIndex = page.continuousSelectionPageIndexForKey(key);
      if (pageIndex < 0) continue;
      if (pageIndex >= keepStart && pageIndex <= keepEnd) continue;
      page.readerSelectableTextAreas.delete(key);
      page.readerSelectableTextValues.delete(key);
      page.readerSelectableTextControllers.delete(key);
      page.readerSelectableTextScrollOffsets.delete(key);
    }
}

export function scheduleReaderComicProgressSave(page: ReadBookPage): void {
    page.clearReaderComicProgressSaveTimer();
    page.readerComicProgressSaveTimerId = setTimeout(() => {
      page.readerComicProgressSaveTimerId = -1;
      page.saveReadingProgress();
    }, 350);
}

export function clearReaderComicProgressSaveTimer(page: ReadBookPage): void {
    if (page.readerComicProgressSaveTimerId < 0) return;
    clearTimeout(page.readerComicProgressSaveTimerId);
    page.readerComicProgressSaveTimerId = -1;
}

export function scheduleReaderPagedProgressSave(page: ReadBookPage): void {
    page.clearReaderPagedProgressSaveTimer();
    page.readerPagedProgressSaveTimerId = setTimeout(() => {
      page.readerPagedProgressSaveTimerId = -1;
      page.saveReadingProgress();
    }, 300);
}

export function clearReaderPagedProgressSaveTimer(page: ReadBookPage): void {
    if (page.readerPagedProgressSaveTimerId < 0) return;
    clearTimeout(page.readerPagedProgressSaveTimerId);
    page.readerPagedProgressSaveTimerId = -1;
}

export function clearReaderComicPaginationProgress(page: ReadBookPage): void {
    page.readerComicPaginationParsing = false;
    page.readerComicPaginationParsedPages = 0;
    page.readerComicPaginationTotalPages = 0;
    page.readerComicPaginationSource = '';
}

export function updateReaderComicPaginationProgress(page: ReadBookPage, chapterIndex: number, result: ReaderPaginationResult): void {
    if (chapterIndex !== page.currentChapterIndex) return;
    if (!page.isReaderComicModeActive()) {
      page.clearReaderComicPaginationProgress();
      return;
    }
    let total = page.readerComicPaginationTotalPages;
    if (page.readerComicPaginationSource !== result.source) {
      if (!LeafFns.isReaderImageOnlySource(result.source)) {
        page.clearReaderComicPaginationProgress();
        return;
      }
      page.readerComicPaginationSource = result.source;
      total = LeafFns.countReaderImageMarkers(result.source);
    }
    total = Math.max(total, result.pages.length);
    page.readerComicPaginationTotalPages = total;
    page.readerComicPaginationParsedPages = Math.min(total, result.pages.length);
    page.readerComicPaginationParsing = result.complete !== true &&
      page.readerComicPaginationParsedPages < total;
}

export function retryReaderComicImage(page: ReadBookPage, index: number): void {
    if (!page.readerComicBrokenPages.includes(index)) return;
    page.readerComicBrokenPages = page.readerComicBrokenPages.filter((broken: number): boolean =>
      broken !== index);
    page.readerComicPageDataSource.notifyChanged(index);
}

export function getEffectiveReaderMarginLeft(page: ReadBookPage): number {
    return page.getEffectiveReaderHorizontalMargin(true);
}

export function getEffectiveReaderMarginRight(page: ReadBookPage): number {
    return page.getEffectiveReaderHorizontalMargin(false);
}

export function getEffectiveReaderHorizontalMargin(page: ReadBookPage, left: boolean): number {
    const rawLeft = Math.max(0, page.readerMarginLeft);
    const rawRight = Math.max(0, page.readerMarginRight);
    const total = rawLeft + rawRight;
    if (total <= 0) return 0;
    const columnWidth = page.getReaderPageColumnWidth();
    // Keep enough room for a useful Chinese text line in compact split-screen and double-page
    // layouts. Stored settings remain untouched and automatically recover on a wider viewport.
    const minimumTextWidth = Math.min(columnWidth, Math.max(96, page.readerFontSize * 4.8));
    const allowedTotal = Math.max(0, columnWidth - minimumTextWidth);
    const scale = total > allowedTotal ? allowedTotal / total : 1;
    return (left ? rawLeft : rawRight) * scale;
}

export function getEffectiveReaderMarginTop(page: ReadBookPage): number {
    return page.getEffectiveReaderVerticalMargin(true) + page.getReaderHeaderContentReserve();
}

export function getReaderHeaderOverlayTopInset(page: ReadBookPage): number {
    // 普通阅读容器已经通过 getReaderTopSafePadding() 避让状态栏；叠页/仿真为了让纸张
    // 覆盖全屏而不消费顶部安全区，需要在页眉自身补回这段高度。
    return page.getReaderTopSafePadding() <= 0 ? page.getReaderPageContentTopPadding() : 0;
}

export function getReaderHeaderContentReserve(page: ReadBookPage): number {
    return page.readerHeaderEnabled && !!page.getReaderHeaderInfoText() && !page.isReaderComicModeActive() ?
      LeafFns.getReaderHeaderInfoBarHeight() + 4 : 0;
}

export function getEffectiveReaderMarginBottom(page: ReadBookPage): number {
    return page.getEffectiveReaderVerticalMargin(false);
}

export function getEffectiveReaderVerticalMargin(page: ReadBookPage, top: boolean): number {
    const rawTop = Math.max(0, page.readerMarginTop);
    const rawBottom = Math.max(0, page.readerMarginBottom);
    const total = rawTop + rawBottom;
    if (total <= 0) return 0;
    const viewportHeight = page.getReaderPaginationViewportHeight();
    const minimumTextHeight = Math.min(viewportHeight, Math.max(96, page.getEffectiveReaderLineHeight() * 2));
    // The footer is an overlay and therefore does not reduce the range available to user margins.
    const availableForMargins = Math.max(0, viewportHeight - minimumTextHeight);
    const scale = total > availableForMargins ? availableForMargins / total : 1;
    return (top ? rawTop : rawBottom) * scale;
}

export function getReaderPageTurnStep(page: ReadBookPage): number {
    return page.isLandscapeDoublePageActive() ? 2 : 1;
}

export function normalizeReaderSpreadPageIndex(page: ReadBookPage, pageIndex: number): number {
    const safeIndex = Math.max(0, Math.round(pageIndex));
    return page.isLandscapeDoublePageActive() ? Math.floor(safeIndex / 2) * 2 : safeIndex;
}

export function getSecondaryPageText(page: ReadBookPage, pageIndex: number = page.currentPageIndex): string {
    if (!page.isLandscapeDoublePageActive() || pageIndex + 1 >= page.contentPages.length) {
      return '';
    }
    return page.getPageText(pageIndex + 1);
}

export function currentReaderSurfaceIndex(page: ReadBookPage): number {
    // V2 paints the page through one retained native FrameNode. Alternating the whole ArkUI subtree on every
    // page destroys that node just before the simulation overlay is removed, so a rapid turn can expose one
    // layout frame from the newly-created paragraph tree. Keep one stable V2 surface and only update its page.
    if (page.shouldUseReaderLayoutV2(page.pagedContentText)) return 0;
    return Math.abs(page.currentChapterIndex + page.currentPageIndex) % 2;
}

export function currentReaderSurfaceKeys(page: ReadBookPage): string[] {
    // Page/chapter and TTS focus changes must publish a fresh declarative subtree. Reusing one fixed ForEach item
    // leaves ArkUI holding the previous chapter or the previous set of highlighted spans.
    return [page.currentReaderPageRenderIdentity(page.pageRenderVersion, page.ttsHighlightRenderVersion)];
}

export function currentReaderV2ChapterSurfaceKeys(page: ReadBookPage): string[] {
    // Keep the native canvas stable during an animation, but remount it after the settled page index changes.
    // ArkUI can retain a NodeContainer even after updatePage() receives a new page object; keying by the settled
    // page makes the declarative host and the retained FrameNode advance atomically instead of leaving old正文.
    return [`reader_v2_chapter_${page.currentChapterIndex}_${page.currentPageIndex}_` +
      `${page.readerV2SurfaceGeneration}`];
}

export function visibleCurrentPageText(page: ReadBookPage): string {
    if (!page.shouldRenderSlidingPageTurn()) {
      const pageText = page.getCurrentPageText();
      return pageText || page.currentPageText || page.displayPageText;
    }
    if (page.displayPageChapterIndex === page.currentChapterIndex &&
      page.displayPageIndex === page.currentPageIndex && page.displayPageText) {
      return page.displayPageText;
    }
    const pageText = page.getCurrentPageText();
    return pageText || page.currentPageText;
}

export function syncCurrentPageText(page: ReadBookPage): void {
    page.setCurrentPageText(page.getCurrentPageText());
}

export function setCurrentPageText(page: ReadBookPage, text: string): void {
    const nextText = text || '';
    page.readerTextSelectionSerial++;
    page.clearReaderV2SelectionOverlay();
    if (page.currentPageText !== nextText) {
      page.chapterJumpRenderGeneration++;
    }
    page.readerSourceActionAreas.clear();
    page.readerSourceActionScrollOffsets.clear();
    page.clearPendingReaderSourceActionBounds();
    page.currentPageText = nextText;
    page.displayPageText = nextText;
    page.displayPageChapterIndex = page.currentChapterIndex;
    page.displayPageIndex = page.currentPageIndex;
    page.displayPageRenderKey++;
    page.pageRenderVersion++;
    page.refreshCurrentReaderV2RetainedPages();
}

export function updatePagedReaderArea(page: ReadBookPage, area: Area): void {
    const width = parseAreaDimension(area.width);
    const contentTopPadding = page.getReaderPageContentTopPadding();
    const height = parseAreaDimension(area.height) - contentTopPadding;
    page.readerPageContentTopPaddingSnapshot = contentTopPadding;
    if (width <= 0 || height <= 0) {
      return;
    }
    // A theme rebuild can move the page without changing its size. Keep the measured origin current even when
    // pagination itself does not need to run again, otherwise V2 action hit testing uses a stale vertical offset.
    const globalY: Length = area.globalPosition?.y ?? 0;
    page.readerCommentPageAreaTop = parseAreaDimension(globalY);
    page.readerCommentPageAreaHeight = height;
    if (Math.abs(page.pageViewWidth - width) < 0.5 && Math.abs(page.pageViewHeight - height) < 0.5) {
      return;
    }
    const preservingStoredOffset = !page.readerProgressRestoreConfirmed &&
      (page.hasReaderTypographyRestoreOffset() ||
        (page.readerProgressAnchorChapterIndex === page.currentChapterIndex &&
          page.readerProgressAnchorOffset >= 0));
    const shouldRestoreSavedPage = page.pendingRestorePageIndex >= 0 || preservingStoredOffset;
    const readingOffset = page.getReaderStableReflowOffset();
    if (!shouldRestoreSavedPage && page.readerInitialPageReady && page.contentPages.length > 0) {
      // Window foreground/rotation can briefly report several sizes. Keep the completed visible snapshot and
      // remap this source offset only when the replacement pagination session is complete.
      page.setReaderTypographyRestoreOffset(readingOffset);
    }
    page.pageViewWidth = width;
    page.pageViewHeight = height;
    page.refreshReaderEyeTurnForViewport();
    AppStorage.setOrCreate<number>('readerLastPageViewWidth', width);
    AppStorage.setOrCreate<number>('readerLastPageViewHeight', height);
    page.paginateContent(page.content);
    if (!shouldRestoreSavedPage) {
      page.currentPageIndex = page.normalizeReaderSpreadPageIndex(page.findPageIndexByOffset(readingOffset));
    }
    page.syncCurrentPageText();
    page.preloadNextChapterPaginationLater();
    page.preloadPreviousChapterPaginationLater();
}

export function rememberReaderBottomInfoBarHeight(page: ReadBookPage, area: Area): void {
    const measuredHeight = LeafFns.normalizeReaderBottomInfoBarHeight(parseAreaDimension(area.height));
    if (measuredHeight <= 0 ||
      Math.abs(measuredHeight - page.getReaderBottomInfoBarHeight()) < 0.25) {
      return;
    }
    page.readerBottomInfoBarPendingHeight = measuredHeight;
    if (page.readerBottomInfoBarMeasureTimerId >= 0) return;
    // Coalesce the two footer labels and apply the measurement outside ArkUI's layout callback.
    page.readerBottomInfoBarMeasureTimerId = setTimeout(() => {
      page.readerBottomInfoBarMeasureTimerId = -1;
      const height = page.readerBottomInfoBarPendingHeight;
      page.readerBottomInfoBarPendingHeight = 0;
      page.applyReaderBottomInfoBarMeasuredHeight(height);
    }, 0);
}

export function applyReaderBottomInfoBarMeasuredHeight(page: ReadBookPage, height: number): void {
    if (!Number.isFinite(height) || height <= 0 ||
      Math.abs(height - page.getReaderBottomInfoBarHeight()) < 0.25) {
      return;
    }
    const previousPaginationHeight = page.getReaderContentBottomReserve() +
      page.getReaderPaginationBottomInfoBarHeight();
    const readingOffset = page.getReaderStableReflowOffset();
    page.readerBottomInfoBarMeasuredHeight = height;
    // Reader V2 paints chapter/page metadata as an overlay and always owns one fixed 8vp bottom guard.
    // The first real footer measurement therefore cannot change any V2 page boundary. Rebuilding the retained
    // Paragraph session here used to measure the opening page twice and kept the loading mask visible for seconds.
    if (page.shouldUseReaderLayoutV2(page.pagedContentText || page.getPagedSourceText())) {
      return;
    }
    const nextPaginationHeight = page.getReaderContentBottomReserve() +
      page.getReaderPaginationBottomInfoBarHeight();
    if (Math.abs(previousPaginationHeight - nextPaginationHeight) < 0.25 ||
      !page.hasPagedReaderArea() || !page.content) {
      return;
    }

    page.finishPageTurnAnimation(false);
    page.readerPaginationWorkSerial++;
    page.adjacentPaginationPreloadSerial++;
    page.previousPaginationPreloadSerial++;
    page.readerPaginationCache.clear();
    page.pageTurnPreviewKey = '';
    page.pageTurnPreviewLoadingKey = '';
    page.paginateContent(page.content);
    page.currentPageIndex = page.normalizeReaderSpreadPageIndex(page.findPageIndexByOffset(readingOffset));
    page.syncCurrentPageText();
    page.preloadNextChapterPaginationLater();
    page.preloadPreviousChapterPaginationLater();
}

export function hasPagedReaderArea(page: ReadBookPage): boolean {
    return page.pageViewWidth > 0 && page.pageViewHeight > 0;
}

export function getCurrentPageStartOffset(page: ReadBookPage): number {
    return page.getPageStartOffset(page.currentPageIndex);
}

export function getReaderStableReflowOffset(page: ReadBookPage): number {
    // Opening-time viewport/font calibration can repaginate immediately after TTS has started. The spoken
    // sentence is the authoritative visible position in that state; anchoring the reflow to the old page start
    // can put the rebuilt surface on the neighbouring page and leave the still-valid focus range off-screen.
    if (page.shouldRenderTtsFocus() && page.readerV2TtsSourceStart >= 0) {
      return page.readerV2TtsSourceStart;
    }
    // Initial V2 pagination deliberately publishes only a small window. Until the persisted character offset has
    // been mapped onto authoritative page boundaries, page zero is merely a render placeholder and must never
    // become the anchor of a geometry/calibration repagination.
    if (!page.readerProgressRestoreConfirmed) {
      if (page.hasReaderTypographyRestoreOffset()) return page.readerTypographyRestoreOffset;
      if (page.readerProgressAnchorChapterIndex === page.currentChapterIndex &&
        page.readerProgressAnchorOffset >= 0) {
        return page.readerProgressAnchorOffset;
      }
    }
    return page.getCurrentPageStartOffset();
}

export function getPageStartOffset(page: ReadBookPage, pageIndex: number): number {
    if (page.contentPageStarts.length === 0) {
      return 0;
    }
    const index = Math.max(0, Math.min(pageIndex, page.contentPageStarts.length - 1));
    return Math.max(0, page.contentPageStarts[index]);
}

export function getPageEndOffset(page: ReadBookPage, pageIndex: number): number {
    if (page.contentPageEnds.length === 0) {
      return page.content.length;
    }
    const index = Math.max(0, Math.min(pageIndex, page.contentPageEnds.length - 1));
    return Math.max(page.getPageStartOffset(index), page.contentPageEnds[index]);
}

export function findPageIndexByOffset(page: ReadBookPage, offset: number): number {
    if (page.contentPageStarts.length === 0) {
      return Math.max(0, Math.min(page.currentPageIndex, Math.max(0, page.contentPages.length - 1)));
    }
    const sourceLength = page.pagedContentText ? page.pagedContentText.length : page.content.length;
    const clampedOffset = Math.max(0, Math.min(offset, Math.max(0, sourceLength - 1)));
    for (let i = 0; i < page.contentPageStarts.length; i++) {
      if (clampedOffset >= page.contentPageStarts[i] && clampedOffset < page.contentPageEnds[i]) {
        return i;
      }
      if (i < page.contentPageStarts.length - 1 &&
        clampedOffset >= page.contentPageEnds[i] && clampedOffset < page.contentPageStarts[i + 1]) {
        return i + 1;
      }
    }
    return Math.max(0, page.contentPageStarts.length - 1);
}

export function restoreReaderTypographyOffsetIfAvailable(page: ReadBookPage, paginationComplete: boolean): boolean {
    if (!page.hasReaderTypographyRestoreOffset() || page.contentPageEnds.length === 0) return false;
    const targetOffset = page.readerTypographyRestoreOffset;
    const lastEnd = page.contentPageEnds[page.contentPageEnds.length - 1];
    if (!paginationComplete && targetOffset >= lastEnd) return false;
    const pageIndex = page.normalizeReaderSpreadPageIndex(page.findPageIndexByOffset(targetOffset));
    page.currentPageIndex = Math.max(0, Math.min(pageIndex, Math.max(0, page.contentPages.length - 1)));
    page.pendingRestorePageIndex = -1;
    page.setReaderTypographyRestoreOffset(-1);
    // The persisted character offset has now been mapped to an authoritative page. From this point on,
    // checkpoints may follow the visible page instead of the immutable database anchor captured at open time.
    page.readerProgressRestoreConfirmed = true;
    page.readerInitialPageReady = true;
    page.finishReaderInitialOpening();
    page.setCurrentPageText(page.contentPages[page.currentPageIndex] || '');
    return true;
}

export function setReaderTypographyRestoreOffset(page: ReadBookPage, offset: number): void {
    page.readerTypographyRestoreOffset = offset;
    page.readerTypographyRestoreOffsetChapterIndex = offset >= 0 ? page.currentChapterIndex : -1;
}

export function hasReaderTypographyRestoreOffset(page: ReadBookPage): boolean {
    if (page.readerTypographyRestoreOffset < 0) return false;
    if (page.readerTypographyRestoreOffsetChapterIndex === page.currentChapterIndex) return true;
    console.warn(`[Reader] dropped cross-chapter typography restore offset: ` +
      `tag=${page.readerTypographyRestoreOffsetChapterIndex}, chapter=${page.currentChapterIndex}, ` +
      `offset=${page.readerTypographyRestoreOffset}`);
    page.readerTypographyRestoreOffset = -1;
    page.readerTypographyRestoreOffsetChapterIndex = -1;
    return false;
}

export function getBackgroundColor(page: ReadBookPage): string {
    return page.currentReaderTheme().backgroundColor;
}

export function getBackgroundAssetId(page: ReadBookPage): string {
    return page.currentReaderTheme().backgroundAssetId || '';
}

export function getBackgroundImageFit(page: ReadBookPage): ImageFit {
    const fit = page.currentReaderTheme().backgroundImageFit;
    if (fit === 'contain') {
      return ImageFit.Contain;
    }
    if (fit === 'fill') {
      return ImageFit.Fill;
    }
    return ImageFit.Cover;
}

export function hasBackgroundImage(page: ReadBookPage): boolean {
    return !!page.currentReaderTheme().backgroundImageUri || !!page.getBackgroundAssetId();
}

export function readerContentLayerColor(page: ReadBookPage): string {
    return page.hasBackgroundImage() ? '#00000000' : page.getBackgroundColor();
}

export function getTextColor(page: ReadBookPage): string {
    return page.currentReaderTheme().textColor;
}

export function currentReaderThemeIndex(page: ReadBookPage): number {
    return page.appDarkMode ? page.readerDarkThemeIndex : page.readerLightThemeIndex;
}

export function currentReaderThemes(page: ReadBookPage): ReaderThemeItem[] {
    const custom = page.currentCustomThemeScheme();
    return ReaderThemeHelper.themes(
      page.appDarkMode,
      custom.backgroundColor,
      custom.textColor,
      page.currentCustomThemeBackgroundImageUri(),
      custom.backgroundImageFit
    );
}

export function currentReaderTheme(page: ReadBookPage): ReaderThemeItem {
    return ReaderThemeHelper.themeAt(
      page.appDarkMode,
      page.currentReaderThemeIndex(),
      page.currentCustomThemeBackgroundColor(),
      page.currentCustomThemeTextColor(),
      page.currentCustomThemeBackgroundImageUri(),
      page.currentCustomThemeScheme().backgroundImageFit
    );
}

export function currentCustomThemeBackgroundColor(page: ReadBookPage): string {
    return page.currentCustomThemeScheme().backgroundColor;
}

export function currentCustomThemeTextColor(page: ReadBookPage): string {
    return page.currentCustomThemeScheme().textColor;
}

export function currentCustomThemeBackgroundImageUri(page: ReadBookPage): string {
    const current = page.currentCustomThemeScheme();
    return current.backgroundType === 'image' ? current.backgroundImageUri : '';
}

export function currentCustomThemeBackgroundTypeIndex(page: ReadBookPage): number {
    return page.currentCustomThemeScheme().backgroundType === 'image' ? 1 : 0;
}

export function customThemeData(page: ReadBookPage): ReaderCustomThemeData {
    return ReaderCustomThemeHelper.parse(
      page.readerCustomThemesRaw,
      page.readerLightCustomThemeBackgroundColor,
      page.readerLightCustomThemeTextColor,
      page.readerDarkCustomThemeBackgroundColor,
      page.readerDarkCustomThemeTextColor
    );
}

export function currentCustomThemeScheme(page: ReadBookPage): ReaderCustomThemeScheme {
    return ReaderCustomThemeHelper.selected(page.customThemeData(), page.appDarkMode);
}

export function currentCustomThemeSchemes(page: ReadBookPage): ReaderCustomThemeScheme[] {
    return ReaderCustomThemeHelper.schemesForMode(page.customThemeData(), page.appDarkMode);
}

export function currentCustomThemeSelectedIndex(page: ReadBookPage): number {
    const schemes = page.currentCustomThemeSchemes();
    const selectedId = page.currentCustomThemeScheme().id;
    const index = schemes.findIndex((item: ReaderCustomThemeScheme) => item.id === selectedId);
    return Math.max(0, index);
}

export function customThemeOptions(page: ReadBookPage): SelectOption[] {
    const options: SelectOption[] = [];
    for (const item of page.currentCustomThemeSchemes()) {
      const option: SelectOption = { value: item.name };
      options.push(option);
    }
    return options;
}

export function customThemeFitSelectedIndex(page: ReadBookPage): number {
    const fit = page.currentCustomThemeScheme().backgroundImageFit;
    return fit === 'contain' ? 1 : (fit === 'fill' ? 2 : 0);
}

export function isReaderThemeDark(page: ReadBookPage): boolean {
    const tone = page.currentReaderTheme().contentTone;
    if (tone === 'dark' || tone === 'light') {
      return tone === 'dark';
    }
    return page.isDarkHexColor(page.getBackgroundColor());
}

export function isDarkHexColor(dark: boolean, color: string): boolean {
    const normalized = (color || '').trim();
    if (!/^#[0-9a-fA-F]{6}$/.test(normalized)) {
      return dark;
    }
    const red = parseInt(normalized.substring(1, 3), 16);
    const green = parseInt(normalized.substring(3, 5), 16);
    const blue = parseInt(normalized.substring(5, 7), 16);
    return red * 0.299 + green * 0.587 + blue * 0.114 < 128;
}

export function getReaderFontFamily(page: ReadBookPage): string {
    const family = page.resolveReaderFontFamily();
    if (family !== page.lastLoggedReaderFontFamily) {
      page.lastLoggedReaderFontFamily = family;
      console.info(`阅读正文使用字体: ${family}`);
    }
    return family;
}

export function getBodyReaderFontFamily(page: ReadBookPage): string {
    return page.resolveStyledReaderFontFamily(page.readerBodyFontMode, page.readerBodyFontFamily);
}

export function getTitleReaderFontFamily(page: ReadBookPage): string {
    if (page.readerTitleFontMode === 'global' && !page.readerTitleFontFamily) {
      return page.getReaderFontFamily();
    }
    return page.resolveStyledReaderFontFamily(page.readerTitleFontMode, page.readerTitleFontFamily);
}

export function getRegexReaderFontFamily(page: ReadBookPage): string {
    return page.resolveStyledReaderFontFamily(page.readerRegexFontMode, page.readerRegexFontFamily);
}

export function resolveStyledReaderFontFamily(page: ReadBookPage, mode: string, family: string): string {
    if (mode === 'system') {
      return page.getSystemReaderFontFamily();
    }
    if (mode === 'custom' && family) {
      return LeafFns.resolveCustomReaderFontFamily(family);
    }
    return page.getReaderFontFamily();
}

export function registerCustomReaderFontFamily(page: ReadBookPage, family: string): void {
    if (!family) {
      return;
    }
    const raw = AppStorage.get<string>('readerCustomFontsRaw') || '';
    if (!raw.trim()) {
      return;
    }
    try {
      const parsed = JSON.parse(raw) as ReaderCustomFontData | ReaderCustomFontItem[];
      const source = Array.isArray(parsed) ? parsed as ReaderCustomFontItem[] : ((parsed as ReaderCustomFontData).fonts || []);
      for (const item of source) {
        if (!item || !item.filePath) {
          continue;
        }
        const stableFamily = ReaderFontHelper.normalizeFontFamily(item.filePath);
        if (item.familyName !== family && stableFamily !== family) {
          continue;
        }
        const fontItem = new ReaderFontItem();
        fontItem.familyName = stableFamily;
        fontItem.filePath = item.filePath;
        fontItem.sourceName = ReaderFontHelper.resolveDisplayName(item.sourceName, item.filePath);
        ReaderFontHelper.registerFont(page.getUIContext(), fontItem);
        return;
      }
    } catch (e) {
      console.warn('解析阅读自定义字体失败:', e);
    }
}

export function registerStyledCustomReaderFonts(page: ReadBookPage): void {
    if (page.readerBodyFontMode === 'custom') {
      page.registerCustomReaderFontFamily(page.readerBodyFontFamily);
    }
    if (page.readerTitleFontMode === 'custom') {
      page.registerCustomReaderFontFamily(page.readerTitleFontFamily);
    }
    if (page.readerRegexFontMode === 'custom') {
      page.registerCustomReaderFontFamily(page.readerRegexFontFamily);
    }
    const rules = page.getRegexRules();
    for (const rule of rules) {
      if (rule.fontMode === 'custom') {
        page.registerCustomReaderFontFamily(rule.fontFamily);
      }
    }
}

export function resolveReaderFontFamily(page: ReadBookPage): string {
    if (page.activeReaderFontFamily) {
      return page.activeReaderFontFamily;
    }
    if (page.readerActiveFontFamily) {
      return page.readerActiveFontFamily;
    }
    return page.readerFontFamily || ThemeRuntime.fontFamily() || page.getSystemReaderFontFamily();
}

export function getSystemReaderFontFamily(page: ReadBookPage): string {
    return page.readerSystemFontFamily || ReaderSystemFontHelper.currentFromStorage(page.getUIContext());
}

export function isReaderFontReady(page: ReadBookPage): boolean {
    return !!page.activeReaderFontFamily || !!page.readerActiveFontFamily;
}

export function clearReaderFontState(page: ReadBookPage): void {
    page.activeReaderFontFamily = '';
    page.readerFontRegistered = false;
    page.readerActiveFontFamily = '';
    page.readerStoredFontRegistered = false;
    page.readerFontRenderReady = false;
    page.applyReaderApplicationFont(page.getSystemReaderFontFamily());
}

export async function registerReaderFont(page: ReadBookPage): Promise<boolean> {
    if (!page.readerFontFilePath) {
      page.clearReaderFontState();
      return false;
    }
    return await page.registerReaderFontAsync('readbook-sync-request');
}

export async function registerReaderFontBySettings(page: ReadBookPage, fontFamily: string, fontFilePath: string, fontSourceName: string): Promise<boolean> {
    if (!fontFilePath) {
      page.clearReaderFontState();
      return false;
    }
    page.readerFontFamily = fontFamily || ReaderFontHelper.normalizeFontFamily(fontFilePath);
    page.readerFontFilePath = fontFilePath;
    AppStorage.setOrCreate<string>('readerFontSourceName', fontSourceName || LeafFns.fileNameFromPath(fontFilePath));
    return await page.registerReaderFontAsync('readbook-register-by-settings');
}

export async function registerReaderFontAsync(page: ReadBookPage, source: string): Promise<boolean> {
    if (!page.readerFontFilePath) {
      page.clearReaderFontState();
      return false;
    }
    const requestedPath = page.readerFontFilePath;
    const registered = await ReaderFontBootstrap.registerFromSettings(page.hostContext(), page.getUIContext(), source);
    if (!page.readerFontFilePath) {
      page.clearReaderFontState();
      return false;
    }
    if (requestedPath !== page.readerFontFilePath) {
      return false;
    }
    if (!registered) {
      if (page.readerFontFilePath) {
        page.readerFontRegistered = false;
        page.readerStoredFontRegistered = false;
        page.readerActiveFontFamily = '';
        page.activeReaderFontFamily = '';
        page.readerFontRenderReady = false;
      }
      return false;
    }
    const activeFamily = AppStorage.get<string>('readerActiveFontFamily') || '';
    const activePath = AppStorage.get<string>('readerFontFilePath') || page.readerFontFilePath;
    if (activePath && activePath !== page.readerFontFilePath) {
      LeafFns.replaceReaderCustomFontPath(page.readerFontFilePath, activePath, ReaderFontHelper.normalizeFontFamily(activePath));
      page.readerFontFilePath = activePath;
    }
    const stableFamily = activePath ? ReaderFontHelper.normalizeFontFamily(activePath) : page.readerFontFamily;
    if (stableFamily && page.readerFontFamily !== stableFamily) {
      page.readerFontFamily = stableFamily;
    }
    page.activateRegisteredReaderFont(activeFamily);
    page.refreshReaderTextRender();
    page.paginateContent(page.content);
    return true;
}

export function activateRegisteredReaderFont(page: ReadBookPage, familyName: string): void {
    if (page.readerFontRegistered && page.activeReaderFontFamily === familyName) {
      page.readerFontRenderReady = false;
      page.refreshRegisteredReaderFontLater(familyName, 80);
      page.refreshRegisteredReaderFontLater(familyName, 240);
      return;
    }
    page.readerActiveFontFamily = familyName;
    page.readerStoredFontRegistered = true;
    page.readerFontRegistered = true;
    page.activeReaderFontFamily = familyName;
    page.readerFontRenderReady = false;
    setTimeout(() => {
      page.activeReaderFontFamily = familyName;
      page.readerFontRegistered = true;
      page.readerActiveFontFamily = familyName;
      page.readerStoredFontRegistered = true;
      page.refreshReaderTextRender();
      page.paginateContent(page.content);
    }, 0);
    page.refreshRegisteredReaderFontLater(familyName, 80);
    page.refreshRegisteredReaderFontLater(familyName, 240);
}

export function refreshRegisteredReaderFontLater(page: ReadBookPage, familyName: string, delayMs: number): void {
    setTimeout(() => {
      if (!familyName || page.activeReaderFontFamily !== familyName) {
        return;
      }
      page.readerFontRenderReady = true;
      console.info(`阅读字体延迟刷新: family=${familyName}, delay=${delayMs}`);
      page.refreshReaderTextRender();
      page.paginateContent(page.content);
    }, delayMs);
}

export function applyLoadedReaderSettings(page: ReadBookPage, settings: ReaderSettings): void {
    page.readerFontSize = settings.fontSize;
    page.readerLetterSpacing = settings.letterSpacing;
    page.readerTextAlign = settings.textAlign;
    page.readerLineHeight = settings.lineHeight;
    page.readerParagraphSpacing = settings.paragraphSpacing;
    page.keepParagraphIndent = settings.keepParagraphIndent;
    page.readerMarginLeft = settings.marginLeft;
    page.readerMarginRight = settings.marginRight;
    page.readerMarginTop = settings.marginTop;
    page.readerMarginBottom = settings.marginBottom;
    page.readerLightThemeIndex = settings.lightThemeIndex;
    page.readerDarkThemeIndex = settings.darkThemeIndex;
    page.readerLightCustomThemeBackgroundColor = settings.lightCustomThemeBackgroundColor;
    page.readerLightCustomThemeTextColor = settings.lightCustomThemeTextColor;
    page.readerDarkCustomThemeBackgroundColor = settings.darkCustomThemeBackgroundColor;
    page.readerDarkCustomThemeTextColor = settings.darkCustomThemeTextColor;
    page.readerCustomThemesRaw = settings.customThemesRaw || '';
    page.customThemeNameDraft = page.currentCustomThemeScheme().name;
    page.readerPageTurnMode = settings.pageTurnMode;
    page.readerPageTurnAnimationType = settings.pageTurnAnimationType;
    page.readerLandscapeDoublePage = settings.landscapeDoublePage;
    page.readerScreenOrientation = settings.screenOrientation;
    page.readerTapZoneActions = settings.tapZoneActions;
    page.readerVolumeTurnPage = settings.volumeTurnPage;
    page.readerEyeTurnEnabled = settings.eyeTurnEnabled;
    page.readerEyeTurnPortraitCalibration = settings.eyeTurnPortraitCalibration || '';
    page.readerEyeTurnLandscapeCalibration = settings.eyeTurnLandscapeCalibration || '';
    page.readerEyeTurnPreviousEnabled = settings.eyeTurnPreviousEnabled;
    page.readerEyeTurnNextEnabled = settings.eyeTurnNextEnabled;
    page.readerEyeTurnPreviousDwellMs = settings.eyeTurnPreviousDwellMs || 850;
    page.readerEyeTurnNextDwellMs = settings.eyeTurnNextDwellMs || 650;
    page.readerScreenTimeoutMinutes = settings.screenTimeoutMinutes;
    page.applyReaderScreenTimeout();
    page.readerExtendToStatusBar = settings.extendToStatusBar;
    page.readerPreloadEnabled = settings.preloadEnabled;
    page.readerPreloadChapterCount = settings.preloadChapterCount;
    page.readerUseTtsQuickAction = settings.useTtsQuickAction;
    page.readerTtsQuickActionSide = settings.ttsQuickActionSide;
    page.readerUseChapterQuickJump = settings.useChapterQuickJump;
    page.readerQuickBookmarkEnabled = settings.quickBookmarkEnabled;
    page.readerHeaderEnabled = settings.readerHeaderEnabled;
    page.readerHeaderContentMode = settings.readerHeaderContentMode;
    page.readerFooterEnabled = settings.readerFooterEnabled;
    page.readerFooterLeftMode = settings.readerFooterLeftMode;
    page.readerFooterProgressMode = settings.readerFooterProgressMode;
    page.readerFooterShowProgressBar = settings.readerFooterShowProgressBar;
    page.readerFontFamily = settings.fontFamily || '';
    page.readerFontFilePath = settings.fontFilePath || '';
    AppStorage.setOrCreate<string>('readerFontSourceName', settings.fontSourceName || '系统默认');
    AppStorage.setOrCreate<string>('readerFontMode', settings.fontMode || (settings.fontFilePath ? 'custom' : 'system'));
    page.readerSystemFontFamily = settings.systemFontFamily || ReaderSystemFontHelper.currentFromStorage(page.getUIContext());
    AppStorage.setOrCreate<string>('readerSystemFontFamily', page.readerSystemFontFamily);
    AppStorage.setOrCreate<string>('readerCustomFontsRaw', settings.customFontsRaw || '');
    page.readerBodyFontMode = settings.bodyFontMode || 'global';
    page.readerBodyFontFamily = settings.bodyFontFamily || '';
    page.readerTitleFontMode = settings.titleFontMode || 'global';
    page.readerTitleFontFamily = settings.titleFontFamily || '';
    page.readerTitleFontSize = settings.titleFontSize || 22;
    page.readerRegexFontEnabled = settings.regexFontEnabled;
    page.readerRegexFontPattern = settings.regexFontPattern || '';
    page.readerRegexFontMode = settings.regexFontMode || 'global';
    page.readerRegexFontFamily = settings.regexFontFamily || '';
    page.readerRegexFontSize = settings.regexFontSize || 20;
    page.readerRegexShadowColor = settings.regexShadowColor || '';
    page.readerRegexFontRulesRaw = settings.regexFontRulesRaw || '';
    page.registerStyledCustomReaderFonts();
}

export function applyReaderApplicationFont(page: ReadBookPage, familyName: string): void {
    try {
      page.hostContext().getApplicationContext().setFont(familyName || '');
    } catch (e) {
      console.warn('应用阅读字体失败:', e);
    }
}

export function saveReaderFontSettings(page: ReadBookPage): void {
    ReaderSettingsStore.saveFontSettings(
      page.hostContext(),
      page.readerFontFamily,
      page.readerFontFilePath,
      AppStorage.get<string>('readerFontSourceName') || '系统默认',
      AppStorage.get<string>('readerFontMode') || (page.readerFontFilePath ? 'custom' : 'system'),
      AppStorage.get<string>('readerSystemFontFamily') || page.getSystemReaderFontFamily(),
      AppStorage.get<string>('readerCustomFontsRaw') || ''
    ).catch((e: Error) => {
      console.warn('保存阅读字体设置失败:', e);
    });
}

export function getTocTitleColor(page: ReadBookPage, chapter: BookChapter, index: number): string {
    if (index === page.currentChapterIndex) {
      return page.accentColor();
    }
    if (chapter.cacheDate > 0) {
      return page.isReaderThemeDark() ? '#DDEFE5' : '#244B35';
    }
    return page.isReaderThemeDark() ? '#B8BDC7' : '#333333';
}

export function setReaderContent(page: ReadBookPage, text: string): void {
    page.content = text;
    page.paginateContent(text);
}

export function openTocPanel(page: ReadBookPage): void {
    page.tocPanelTab = 0;
    page.tocSearchVisible = false;
    page.tocSearchQuery = '';
    page.tocSearchChapterIndexes = [];
    page.tocSearchLoading = false;
    page.tocSearchResultActive = false;
    page.tocSearchRequestSerial++;
    page.tocDatabaseChapterCount = page.chapters.length;
    page.tocFirstVisibleGlobalIndex = page.currentChapterIndex;
    page.tocQuickJumpArmed = false;
    page.tocQuickJumpInputVisible = false;
    page.tocQuickJumpDraft = '';
    page.cancelBookmarkMultiSelect();
    page.setTocWindowAround(page.currentChapterIndex, ScrollAlign.CENTER);
    page.showToc = true;
    page.showMenu = false;
    page.scrollTocToCurrentChapter(false);
    page.loadBookmarks();
    page.loadTocDatabaseChapterCount();
}

export async function refreshTocFromPanel(page: ReadBookPage): Promise<void> {
    const searchQuery = page.tocSearchQuery;
    await page.retryFetchChapters();
    page.tocDatabaseChapterCount = page.chapters.length;
    if (page.tocSearchVisible && page.tocSearchResultActive && searchQuery.trim()) {
      await page.submitTocSearch();
    } else {
      page.setTocWindowAround(page.currentChapterIndex, ScrollAlign.CENTER);
      page.scrollTocToCurrentChapter(false);
    }
    HdsFeedback.showToast('目录已刷新');
}

export async function loadBookmarks(page: ReadBookPage): Promise<void> {
    const bookUrl = page.book?.bookUrl || page.bookUrl;
    if (!bookUrl) {
      page.bookmarks = [];
      return;
    }
    try {
      const db = AppDatabase.getInstance();
      await db.initWithContext(page.hostContext());
      page.bookmarks = await db.getBookmarks(bookUrl);
    } catch (e) {
      console.warn('加载书签失败:', e);
      page.bookmarks = [];
    }
}

export function currentPageBookmark(page: ReadBookPage): Bookmark | undefined {
    return page.bookmarks.find((bookmark: Bookmark) =>
      bookmark.chapterIndex === page.currentChapterIndex && bookmark.pageIndex === page.currentPageIndex);
}

export function isCurrentPageBookmarked(page: ReadBookPage): boolean {
    return page.currentPageBookmark() !== undefined;
}

export async function toggleCurrentPageBookmark(page: ReadBookPage): Promise<void> {
    const existing = page.currentPageBookmark();
    if (existing) {
      await page.deleteBookmark(existing);
      return;
    }
    await page.addCurrentBookmark();
}

export function bookmarkPullHintText(page: ReadBookPage): string {
    if (page.isCurrentPageBookmarked()) {
      return page.bookmarkPullReady ? '松开删除书签' : '下拉删除书签';
    }
    return page.bookmarkPullReady ? '松开添加书签' : '下拉添加书签';
}

export function bookmarkPullHintColor(page: ReadBookPage): string {
    return page.bookmarkPullReady ? page.accentColor() : page.getTextColor();
}

export function readerBookmarkMarkerTopOffset(page: ReadBookPage): number {
    if (page.readerExtendToStatusBar) return 0;
    return page.hasBackgroundImage() || page.isStackPageTurnAnimation() ||
      page.is3DPageTurnAnimation() ? page.statusBarSafeHeight : 0;
}

export async function addCurrentBookmark(page: ReadBookPage): Promise<void> {
    if (!page.book || page.chapters.length === 0) {
      HdsFeedback.showToast('当前没有可添加的阅读位置');
      return;
    }
    const pageIndex = Math.max(0, page.currentPageIndex);
    try {
      const db = AppDatabase.getInstance();
      await db.initWithContext(page.hostContext());
      const existing = await db.getBookmarkAt(page.book.bookUrl, page.currentChapterIndex, pageIndex);
      if (existing) {
        HdsFeedback.showToast('当前阅读位置已添加书签');
        return;
      }
      const bookmark = new Bookmark();
      bookmark.bookUrl = page.book.bookUrl;
      bookmark.bookName = page.book.name;
      bookmark.bookAuthor = page.book.author;
      bookmark.chapterIndex = page.currentChapterIndex;
      bookmark.chapterName = page.getChapterTitle(page.currentChapterIndex);
      bookmark.pageIndex = pageIndex;
      bookmark.startPos = page.getPageStartOffset(pageIndex);
      bookmark.endPos = page.getPageEndOffset(pageIndex);
      bookmark.content = page.bookmarkContentPreview(pageIndex);
      bookmark.createTime = Date.now();
      await db.insertBookmark(bookmark);
      await page.loadBookmarks();
      HdsFeedback.showToast('书签已添加');
    } catch (e) {
      console.error('添加书签失败:', e);
      HdsFeedback.showToast('添加书签失败');
    }
}

export function bookmarkContentPreview(page: ReadBookPage, pageIndex: number): string {
    const text = page.getPageText(pageIndex).replace(/\s+/g, ' ').trim();
    return text.length > 90 ? `${text.substring(0, 90)}…` : text;
}

export async function deleteBookmark(page: ReadBookPage, bookmark: Bookmark): Promise<void> {
    try {
      const db = AppDatabase.getInstance();
      await db.initWithContext(page.hostContext());
      await db.deleteBookmark(bookmark.bookmarkUrl);
      page.bookmarks = page.bookmarks.filter((item: Bookmark) => item.bookmarkUrl !== bookmark.bookmarkUrl);
      page.selectedBookmarkUrls = page.selectedBookmarkUrls.filter((url: string) => url !== bookmark.bookmarkUrl);
      if (page.bookmarkMultiSelectMode && page.bookmarks.length === 0) {
        page.cancelBookmarkMultiSelect();
      }
      HdsFeedback.showToast('书签已删除');
    } catch (e) {
      console.error('删除书签失败:', e);
      HdsFeedback.showToast('删除书签失败');
    }
}

export function enterBookmarkMultiSelect(page: ReadBookPage, bookmarkUrl: string): void {
    page.bookmarkMultiSelectMode = true;
    if (!page.selectedBookmarkUrls.includes(bookmarkUrl)) {
      page.selectedBookmarkUrls = [...page.selectedBookmarkUrls, bookmarkUrl];
    }
    setTimeout(() => {
      try {
        page.bookmarkScroller.closeAllSwipeActions();
      } catch (error) {
        console.warn('关闭书签滑动操作失败:', error);
      }
    }, 0);
}

export function isBookmarkSelected(page: ReadBookPage, bookmarkUrl: string): boolean {
    return page.selectedBookmarkUrls.includes(bookmarkUrl);
}

export function toggleBookmarkSelection(page: ReadBookPage, bookmarkUrl: string): void {
    if (page.selectedBookmarkUrls.includes(bookmarkUrl)) {
      page.selectedBookmarkUrls = page.selectedBookmarkUrls.filter((url: string) => url !== bookmarkUrl);
    } else {
      page.selectedBookmarkUrls = [...page.selectedBookmarkUrls, bookmarkUrl];
    }
}

export function toggleSelectAllBookmarks(page: ReadBookPage): void {
    if (page.selectedBookmarkUrls.length === page.bookmarks.length) {
      page.selectedBookmarkUrls = [];
    } else {
      page.selectedBookmarkUrls = page.bookmarks.map((bookmark: Bookmark): string => bookmark.bookmarkUrl);
    }
}

export function cancelBookmarkMultiSelect(page: ReadBookPage): void {
    page.bookmarkMultiSelectMode = false;
    page.selectedBookmarkUrls = [];
}

export async function deleteSelectedBookmarks(page: ReadBookPage): Promise<void> {
    const urls = [...page.selectedBookmarkUrls];
    if (urls.length === 0) return;
    try {
      const db = AppDatabase.getInstance();
      await db.initWithContext(page.hostContext());
      await db.deleteBookmarks(urls);
      page.bookmarks = page.bookmarks.filter((bookmark: Bookmark) => !urls.includes(bookmark.bookmarkUrl));
      page.cancelBookmarkMultiSelect();
      HdsFeedback.showToast(`已删除 ${urls.length} 条书签`);
    } catch (e) {
      console.error('批量删除书签失败:', e);
      HdsFeedback.showToast('批量删除书签失败');
    }
}

export async function jumpToBookmark(page: ReadBookPage, bookmark: Bookmark): Promise<void> {
    const targetChapterIndex = page.clampChapterIndex(bookmark.chapterIndex);
    page.showToc = false;
    page.showMenu = false;
    await page.jumpToReaderPositionKeepingTts(targetChapterIndex, Math.max(0, bookmark.pageIndex));
}

export function openSettingsPanel(page: ReadBookPage): void {
    if (page.isReaderComicModeActive()) return;
    page.showReaderActionMenu = false;
    page.settingsPanelTab = 0;
    page.showToc = false;
    page.showTtsVoiceDropdown = false;
    page.showSettings = true;
    page.showMenu = false;
}

export function openTtsSettingsPanel(page: ReadBookPage): void {
    if (page.isReaderComicModeActive()) return;
    page.showReaderActionMenu = false;
    page.settingsPanelTab = 1;
    page.showToc = false;
    page.showTtsVoiceDropdown = false;
    page.showSettings = true;
    page.showMenu = false;
    page.loadTtsSettingsAndVoices();
}

export function openTypographySettingsPanel(page: ReadBookPage): void {
    if (page.isReaderComicModeActive()) return;
    if (!page.readerTypographyDraftPending) page.syncReaderTypographyDraft();
    page.showReaderTypographyValueInput = false;
    page.showReaderActionMenu = false;
    page.settingsPanelTab = 2;
    page.showToc = false;
    page.showTtsVoiceDropdown = false;
    page.showSettings = true;
    page.showMenu = false;
}

export function closeSettingsPanelKeepMenu(page: ReadBookPage): void {
    page.flushPendingReaderLayoutChange(true);
    page.showTtsVoiceDropdown = false;
    page.showSettings = false;
    page.showMenu = true;
}

export async function loadTtsSettingsAndVoices(page: ReadBookPage): Promise<void> {
    try {
      const settings = await TtsSettingsStore.load(page.hostContext());
      page.applyLoadedTtsSettings(settings);
    } catch (e) {
      console.warn('读取朗读设置失败:', e);
    }
    page.normalizeDefaultTtsVoice();
    page.ttsSelectedVoiceKey = page.currentTtsVoiceKey();
    page.loadTtsVoices();
}

export function applyLoadedTtsSettings(page: ReadBookPage, settings: TtsSettings): void {
    page.ttsPerson = settings.person;
    page.ttsOnline = settings.online;
    page.ttsStyle = settings.style;
    page.ttsLanguage = settings.language;
    page.ttsSpeed = settings.speed;
    page.ttsInstalledVoiceKeys = settings.installedVoiceKeys;
    page.ttsCustomVoiceId = settings.customVoiceId;
    page.ttsCustomVoices = settings.customVoices;
    page.ttsCustomVoiceOptions = SystemTtsReader.parseCustomVoices(settings.customVoices);
}

export function normalizeDefaultTtsVoice(page: ReadBookPage): void {
    if (page.ttsOnline === 0 && page.ttsPerson === 0 && !page.ttsStyle &&
      LeafFns.sameTtsLanguage(page.ttsLanguage || 'zh-CN', 'zh-CN')) {
      page.ttsOnline = 1;
      page.saveTtsSettings();
    }
}

export function currentTtsSettings(page: ReadBookPage): TtsSettings {
    const settings = new TtsSettings();
    settings.person = page.ttsPerson;
    settings.online = page.ttsOnline;
    settings.style = page.ttsStyle;
    settings.language = page.ttsLanguage;
    settings.speed = page.ttsSpeed;
    settings.installedVoiceKeys = page.ttsInstalledVoiceKeys;
    settings.customVoiceId = page.ttsCustomVoiceId;
    settings.customVoices = page.ttsCustomVoices;
    return settings;
}

export function saveTtsSettings(page: ReadBookPage): void {
    const settings = page.currentTtsSettings();
    TtsSettingsStore.applyToStorage(settings);
    TtsSettingsStore.save(page.hostContext(), settings).catch((e: Error) => {
      console.warn('保存朗读设置失败:', e);
    });
}

export async function loadTtsVoices(page: ReadBookPage): Promise<void> {
    if (page.ttsVoicesLoading) {
      return;
    }
    page.ttsVoicesLoading = true;
    try {
      const voices = await SystemTtsReader.listAvailableVoices();
      page.ttsVoices = page.applyInstalledTtsVoiceOverrides(LeafFns.mergeWithDefaultTtsVoice(voices));
      const currentCustomVoice = page.findCurrentCustomTtsVoice();
      if (currentCustomVoice) {
        page.ttsSelectedVoiceKey = LeafFns.ttsCustomVoiceKey(currentCustomVoice);
        return;
      }
      const currentVoice = page.findCurrentTtsVoice();
      if (currentVoice && currentVoice.available) {
        page.ttsSelectedVoiceKey = LeafFns.ttsVoiceKey(currentVoice);
      } else {
        page.applyTtsVoice(page.firstAvailableTtsVoice(), false);
      }
    } catch (e) {
      page.ttsVoices = [LeafFns.defaultTtsVoice()];
      page.ttsPerson = 0;
      page.ttsOnline = 1;
      page.ttsStyle = '';
      page.ttsLanguage = 'zh-CN';
      page.ttsCustomVoiceId = '';
      page.saveTtsSettings();
      page.ttsSelectedVoiceKey = page.currentTtsVoiceKey();
      console.warn('加载朗读音色失败:', e);
    } finally {
      page.ttsVoicesLoading = false;
      page.publishTtsFloatingVoices();
    }
}

export function firstAvailableTtsVoice(page: ReadBookPage): TtsVoiceOption {
    return page.ttsVoices.find((voice: TtsVoiceOption) => voice.available) || page.ttsVoices[0] ||
      LeafFns.defaultTtsVoice();
}

export function applyInstalledTtsVoiceOverrides(page: ReadBookPage, voices: TtsVoiceOption[]): TtsVoiceOption[] {
    const options: TtsVoiceOption[] = [];
    for (const voice of voices) {
      options.push(page.isLocallyInstalledTtsVoice(voice) ? LeafFns.markTtsVoiceOptionInstalled(voice) : voice);
    }
    return options;
}

export function isLocallyInstalledTtsVoice(page: ReadBookPage, voice: TtsVoiceOption): boolean {
    const key = LeafFns.installedTtsVoiceKey(voice);
    return !!key && page.ttsInstalledVoiceKeys.split('\n').includes(key);
}

export function isTtsSessionManuallyPaused(page: ReadBookPage): boolean {
    return page.isTtsPaused || page.ttsReader.isPaused();
}

export function applyTtsVoice(page: ReadBookPage, voice: TtsVoiceOption, restartSpeaking: boolean): void {
    if (!voice.available) {
      HdsFeedback.showToast(voice.downloadable ? '请到朗读设置下载该音色' : '该系统音色当前不可用');
      return;
    }
    const shouldResume = restartSpeaking && !page.isTtsSessionManuallyPaused() &&
      (page.isTtsSpeaking || page.ttsReader.isSpeaking());
    if (shouldResume) {
      page.stopTtsReading();
    }
    page.ttsPerson = voice.id;
    page.ttsOnline = voice.online;
    page.ttsStyle = voice.style;
    page.ttsLanguage = voice.language;
    page.ttsCustomVoiceId = '';
    page.ttsSelectedVoiceKey = LeafFns.ttsVoiceKey(voice);
    page.saveTtsSettings();
    if (shouldResume) {
      page.startTtsReadingFromCurrentPosition(false).catch((e: Error) => {
        console.warn('切换朗读音色后恢复朗读失败:', e);
      });
    }
}

export function applyTtsSpeed(page: ReadBookPage, value: number): void {
    const nextSpeed = Math.max(0.5, Math.min(3, Math.round(value * 10) / 10));
    if (Math.abs(page.ttsSpeed - nextSpeed) < 0.01) {
      return;
    }
    page.ttsSpeed = nextSpeed;
    // Keep the retained/global control panel in sync in the same UI turn. updateDetails() also
    // publishes this value, but that call can be skipped while a mirrored reader page is visible.
    AppStorage.setOrCreate('globalTtsSpeed', nextSpeed);
    page.scheduleTtsSpeedSettingsSave();
    page.updateTtsFloatingSession();
    if (page.isTtsSpeaking || page.ttsReader.isSpeaking()) {
      page.scheduleTtsSpeedAvSessionUpdate();
      page.scheduleActiveTtsSpeedRestart();
    }
}

export function scheduleActiveTtsSpeedRestart(page: ReadBookPage): void {
    if (page.ttsSpeedRestartTimerId >= 0) {
      clearTimeout(page.ttsSpeedRestartTimerId);
    }
    const serial = ++page.ttsSpeedRestartSerial;
    page.ttsSpeedRestartTimerId = setTimeout(() => {
      page.ttsSpeedRestartTimerId = -1;
      if (serial !== page.ttsSpeedRestartSerial || page.isTtsPaused || page.ttsReader.isPaused() ||
        (!page.isTtsSpeaking && !page.ttsReader.isSpeaking())) {
        return;
      }
      const focusStart = page.readerV2TtsSourceStart >= 0 ? page.readerV2TtsSourceStart :
        (page.ttsLastFocusChunk ? page.readerV2TtsSourceOffset(page.ttsLastFocusChunk.start) :
          page.getCurrentPageStartOffset());
      page.ttsAutoContinue = false;
      page.ttsReadToken++;
      page.ttsReader.stop();
      page.startTtsReadingFromCurrentPosition(false, false, -1, focusStart, true).catch((error: Error) => {
        if (serial !== page.ttsSpeedRestartSerial) return;
        console.warn('实时应用朗读倍速失败:', error);
        page.finishTtsReading();
      });
    }, 100);
}

export function scheduleTtsSpeedSettingsSave(page: ReadBookPage): void {
    if (page.ttsSpeedSaveTimerId >= 0) {
      clearTimeout(page.ttsSpeedSaveTimerId);
    }
    page.ttsSpeedSaveTimerId = setTimeout(() => {
      page.ttsSpeedSaveTimerId = -1;
      page.saveTtsSettings();
    }, 300);
}

export function scheduleTtsSpeedAvSessionUpdate(page: ReadBookPage): void {
    if (page.ttsSpeedAvSessionTimerId >= 0) {
      clearTimeout(page.ttsSpeedAvSessionTimerId);
    }
    page.ttsSpeedAvSessionTimerId = setTimeout(() => {
      page.ttsSpeedAvSessionTimerId = -1;
      if (page.isTtsSpeaking || page.ttsReader.isSpeaking()) {
        page.updateTtsAvSessionPlaybackState(page.ttsAvPlaybackState()).catch((e: Error) => {
          console.warn('更新朗读倍速媒体状态失败:', e);
        });
      }
    }, 300);
}

export function flushPendingTtsSpeedSettings(page: ReadBookPage): void {
    if (page.ttsSpeedSaveTimerId >= 0) {
      clearTimeout(page.ttsSpeedSaveTimerId);
      page.ttsSpeedSaveTimerId = -1;
      page.saveTtsSettings();
    }
    if (page.ttsSpeedAvSessionTimerId >= 0) {
      clearTimeout(page.ttsSpeedAvSessionTimerId);
      page.ttsSpeedAvSessionTimerId = -1;
    }
    if (page.ttsSpeedRestartTimerId >= 0) {
      clearTimeout(page.ttsSpeedRestartTimerId);
      page.ttsSpeedRestartTimerId = -1;
    }
    page.ttsSpeedRestartSerial++;
}

export function currentTtsVoiceKey(page: ReadBookPage): string {
    const customVoice = page.findCurrentCustomTtsVoice();
    if (customVoice) {
      return LeafFns.ttsCustomVoiceKey(customVoice);
    }
    const matched = page.findCurrentTtsVoice();
    return matched ? LeafFns.ttsVoiceKey(matched) :
      `${page.ttsPerson}_${page.ttsOnline}_${page.ttsLanguage || 'zh-CN'}_${page.ttsStyle || ''}_`;
}

export function findCurrentTtsVoice(page: ReadBookPage): TtsVoiceOption | undefined {
    return page.ttsVoices.find((voice: TtsVoiceOption) => page.isCurrentTtsVoice(voice));
}

export function isCurrentTtsVoice(page: ReadBookPage, voice: TtsVoiceOption): boolean {
    if (page.ttsCustomVoiceId) {
      return false;
    }
    return voice.id === page.ttsPerson && voice.online === page.ttsOnline &&
      (voice.style || '') === (page.ttsStyle || '') &&
      LeafFns.sameTtsLanguage(voice.language || 'zh-CN', page.ttsLanguage || 'zh-CN');
}

export function applyCustomTtsVoice(page: ReadBookPage, voice: HttpTTS, restartSpeaking: boolean): void {
    if (voice.enabled === false) {
      HdsFeedback.showToast('该自定义音色已禁用');
      return;
    }
    const shouldResume = restartSpeaking && !page.isTtsSessionManuallyPaused() &&
      (page.isTtsSpeaking || page.ttsReader.isSpeaking());
    if (shouldResume) {
      page.stopTtsReading();
    }
    page.ttsCustomVoiceId = String(voice.id);
    page.ttsSelectedVoiceKey = LeafFns.ttsCustomVoiceKey(voice);
    page.saveTtsSettings();
    if (shouldResume) {
      page.startTtsReadingFromCurrentPosition(false).catch((e: Error) => {
        console.warn('切换自定义朗读音色后恢复朗读失败:', e);
      });
    }
}

export function findCurrentCustomTtsVoice(page: ReadBookPage): HttpTTS | undefined {
    const selectedId = (page.ttsCustomVoiceId || '').trim();
    if (!selectedId) {
      return undefined;
    }
    return page.ttsCustomVoiceOptions.find((voice: HttpTTS) => String(voice.id) === selectedId);
}

export function isCurrentCustomTtsVoice(page: ReadBookPage, voice: HttpTTS): boolean {
    return (page.ttsCustomVoiceId || '') === String(voice.id);
}

export function tocGlobalIndex(page: ReadBookPage, localIndex: number): number {
    if (page.isTocSearchActive()) {
      return page.tocSearchChapterIndexes[localIndex] ?? 0;
    }
    const displayIndex = page.tocWindowStart + localIndex;
    return page.tocReverseOrder ? page.chapters.length - 1 - displayIndex : displayIndex;
}

export function tocChapterAtDisplayIndex(page: ReadBookPage, displayIndex: number): BookChapter {
    const canonicalIndex = page.tocReverseOrder ? page.chapters.length - 1 - displayIndex : displayIndex;
    return page.chapters[canonicalIndex];
}

export function toggleTocOrder(page: ReadBookPage): void {
    page.tocReverseOrder = !page.tocReverseOrder;
    page.tocOrderRevision++;
    page.tocSearchRequestSerial++;
    page.tocSearchQuery = '';
    page.tocSearchChapterIndexes = [];
    page.tocSearchLoading = false;
    page.tocSearchResultActive = false;
    page.scrollTocToCurrentChapter(false);
}

export function selectableCustomTtsVoices(page: ReadBookPage): HttpTTS[] {
    return page.ttsCustomVoiceOptions.filter((voice: HttpTTS) => voice.enabled !== false);
}

export function selectableSystemTtsVoices(page: ReadBookPage): TtsVoiceOption[] {
    return page.ttsVoices.filter((voice: TtsVoiceOption) => voice.available || voice.downloadable);
}

export async function downloadTtsVoice(page: ReadBookPage, voice: TtsVoiceOption): Promise<void> {
    if (!SystemTtsReader.supportsVoiceDownload()) {
      HdsFeedback.showToast('当前系统版本不支持下载系统音色，请升级系统后重试');
      return;
    }
    if (page.ttsDownloadingVoiceKey) {
      HdsFeedback.showToast('正在下载音色，请稍候');
      return;
    }
    page.ttsDownloadingVoiceKey = LeafFns.ttsVoiceKey(voice);
    try {
      HdsFeedback.showToast(`开始下载 ${voice.name}`);
      await SystemTtsReader.downloadVoice(voice);
      page.markTtsVoiceInstalled(voice);
      page.ttsVoices = page.applyInstalledTtsVoiceOverrides(page.ttsVoices);
      const downloaded = page.ttsVoices.find((item: TtsVoiceOption) =>
        LeafFns.isSameTtsVoiceOption(item, voice) && item.available) || LeafFns.markTtsVoiceOptionInstalled(voice);
      page.applyTtsVoice(downloaded, true);
      HdsFeedback.showToast(`已启用 ${downloaded.name}`);
    } catch (error) {
      const message = error instanceof Error ? error.message : '请稍后重试';
      HdsFeedback.showToast(`音色下载失败：${message}`);
    } finally {
      page.ttsDownloadingVoiceKey = '';
    }
}

export function markTtsVoiceInstalled(page: ReadBookPage, voice: TtsVoiceOption): void {
    const key = LeafFns.installedTtsVoiceKey(voice);
    if (!key || page.isLocallyInstalledTtsVoice(voice)) {
      return;
    }
    page.ttsInstalledVoiceKeys = page.ttsInstalledVoiceKeys ? `${page.ttsInstalledVoiceKeys}\n${key}` : key;
    page.saveTtsSettings();
}

export function selectedTtsVoiceTitle(page: ReadBookPage): string {
    const customVoice = page.findCurrentCustomTtsVoice();
    if (customVoice && customVoice.enabled !== false) {
      return LeafFns.ttsCustomVoiceTitle(customVoice);
    }
    const systemVoice = page.findCurrentTtsVoice();
    if (systemVoice && systemVoice.available) {
      return LeafFns.ttsVoiceTitle(systemVoice);
    }
    const customVoices = page.selectableCustomTtsVoices();
    if (customVoices.length > 0) {
      return LeafFns.ttsCustomVoiceTitle(customVoices[0]);
    }
    const systemVoices = page.selectableSystemTtsVoices();
    return systemVoices.length > 0 ? LeafFns.ttsVoiceTitle(systemVoices[0]) : '暂无可用音色';
}

export function ttsQuickVoiceOptions(page: ReadBookPage): SelectOption[] {
    const options: SelectOption[] = [];
    for (const voice of page.selectableCustomTtsVoices()) {
      options.push({ value: LeafFns.ttsCustomVoiceTitle(voice) });
    }
    for (const voice of page.selectableSystemTtsVoices()) {
      options.push({ value: LeafFns.ttsVoiceTitle(voice) });
    }
    if (options.length === 0) {
      options.push({ value: '暂无可用音色' });
    }
    return options;
}

export function ttsQuickVoiceLabels(page: ReadBookPage): string[] {
    return page.ttsQuickVoiceOptions().map((option: SelectOption): string => `${option.value}`);
}

export function ttsQuickVoiceSelectedIndex(page: ReadBookPage): number {
    const customVoices = page.selectableCustomTtsVoices();
    const customIndex = customVoices.findIndex((voice: HttpTTS) => page.isCurrentCustomTtsVoice(voice));
    if (customIndex >= 0) return customIndex;
    const systemVoices = page.selectableSystemTtsVoices();
    const systemIndex = systemVoices.findIndex((voice: TtsVoiceOption) => page.isCurrentTtsVoice(voice));
    if (systemIndex >= 0) return customVoices.length + systemIndex;
    return 0;
}

export function selectTtsQuickVoice(page: ReadBookPage, index: number): void {
    if (index < 0) return;
    const customVoices = page.selectableCustomTtsVoices();
    if (index < customVoices.length) {
      page.applyCustomTtsVoice(customVoices[index], true);
      return;
    }
    const systemVoices = page.selectableSystemTtsVoices();
    const systemIndex = index - customVoices.length;
    if (systemIndex >= 0 && systemIndex < systemVoices.length) {
      page.applyTtsVoice(systemVoices[systemIndex], true);
    }
}

export function isTocSearchActive(page: ReadBookPage): boolean {
    return page.tocSearchVisible && page.tocSearchResultActive;
}

export function toggleTocSearch(page: ReadBookPage): void {
    if (page.tocSearchVisible) {
      page.tocSearchVisible = false;
      page.tocSearchQuery = '';
      page.tocSearchChapterIndexes = [];
      page.tocSearchLoading = false;
      page.tocSearchResultActive = false;
      page.tocSearchRequestSerial++;
      page.setTocWindowAround(page.currentChapterIndex, ScrollAlign.CENTER);
      page.scrollTocToCurrentChapter(false);
      return;
    }
    page.tocSearchVisible = true;
    page.tocQuickJumpArmed = false;
    page.tocQuickJumpInputVisible = false;
    page.tocQuickJumpDraft = '';
    setTimeout(() => {
      focusControl.requestFocus('tocChapterSearchInput');
    }, 50);
}

export async function submitTocSearch(page: ReadBookPage): Promise<void> {
    const keyword = page.tocSearchQuery.trim();
    if (!keyword) {
      page.clearTocSearchResult();
      return;
    }
    const requestSerial = ++page.tocSearchRequestSerial;
    const bookUrl = page.book?.bookUrl || page.bookUrl;
    page.tocSearchLoading = true;
    try {
      let matches: BookChapter[] = [];
      let totalCount = page.chapters.length;
      let searchSource = '内存';
      if (page.chapters.length > 0) {
        const normalizedKeyword = keyword.toLowerCase();
        matches = page.chapters.filter((chapter: BookChapter) =>
          (chapter.title || '').toLowerCase().includes(normalizedKeyword));
      } else {
        searchSource = '数据库';
        const db = AppDatabase.getInstance();
        await db.initWithContext(page.hostContext());
        matches = await db.searchBookChapters(bookUrl, keyword);
        totalCount = await db.getBookChapterCount(bookUrl);
      }
      if (requestSerial !== page.tocSearchRequestSerial || !page.tocSearchVisible) return;
      if (page.tocReverseOrder) {
        matches = matches.slice().reverse();
      }
      const indexes: number[] = [];
      for (const chapter of matches) {
        indexes.push(chapter.index);
      }
      page.tocDatabaseChapterCount = totalCount;
      page.tocSearchChapterIndexes = indexes;
      page.tocVisibleChapters = matches;
      page.tocWindowStart = 0;
      page.tocSearchResultActive = true;
      page.tocFirstVisibleGlobalIndex = indexes.length > 0 ? indexes[0] : 0;
      page.tocVisibleItemCount = 1;
      console.info(`[TOC] ${searchSource}目录搜索: keyword=${keyword}, total=${totalCount}, matches=${matches.length}`);
      setTimeout(() => {
        if (matches.length > 0) {
          page.tocScroller.scrollToIndex(0, false, ScrollAlign.START);
        }
      }, 0);
    } catch (e) {
      console.warn('目录搜索失败:', e);
      if (requestSerial === page.tocSearchRequestSerial) {
        HdsFeedback.showToast('目录搜索失败');
      }
    } finally {
      if (requestSerial === page.tocSearchRequestSerial) {
        page.tocSearchLoading = false;
      }
    }
}

export function clearTocSearchResult(page: ReadBookPage): void {
    page.tocSearchRequestSerial++;
    page.tocSearchQuery = '';
    page.tocSearchLoading = false;
    page.tocSearchResultActive = false;
    page.tocSearchChapterIndexes = [];
    const localIndex = page.setTocWindowAround(page.currentChapterIndex, ScrollAlign.CENTER);
    setTimeout(() => {
      try {
        page.tocScroller.scrollToIndex(localIndex, false, ScrollAlign.CENTER);
      } catch (e) {
        console.warn('清空目录搜索后恢复定位失败:', e);
      }
    }, 0);
}

export async function loadTocDatabaseChapterCount(page: ReadBookPage): Promise<void> {
    const bookUrl = page.book?.bookUrl || page.bookUrl;
    if (!bookUrl) return;
    try {
      const db = AppDatabase.getInstance();
      await db.initWithContext(page.hostContext());
      page.tocDatabaseChapterCount = Math.max(await db.getBookChapterCount(bookUrl), page.chapters.length);
    } catch (e) {
      console.warn('读取数据库章节总数失败:', e);
    }
}

export function updateTocScrollbarPosition(page: ReadBookPage, start: number, end: number): void {
    const localStart = Math.max(0, start);
    page.tocFirstVisibleGlobalIndex = page.tocGlobalIndex(localStart);
    page.tocVisibleItemCount = Math.max(1, end - start + 1);
}

export function tocShouldShowVirtualScrollbar(page: ReadBookPage): boolean {
    return page.tocListViewportHeight > 0 && page.tocDatabaseChapterCount > page.tocVisibleItemCount;
}

export function tocScrollbarThumbLength(page: ReadBookPage): number {
    return VirtualListScrollbar.thumbLength(page.tocListViewportHeight,
      page.tocDatabaseChapterCount, page.tocVisibleItemCount);
}

export function tocScrollbarThumbOffset(page: ReadBookPage): number {
    const thumbLength = page.tocScrollbarThumbLength();
    const firstVisibleIndex = page.tocReverseOrder ?
      page.tocDatabaseChapterCount - 1 - page.tocFirstVisibleGlobalIndex : page.tocFirstVisibleGlobalIndex;
    return VirtualListScrollbar.thumbOffset(page.tocListViewportHeight, thumbLength,
      page.tocDatabaseChapterCount, firstVisibleIndex, page.tocVisibleItemCount);
}

export function tocDisplayedScrollbarThumbOffset(page: ReadBookPage): number {
    return page.tocScrollbarDragging ? page.tocScrollbarDragOffset : page.tocScrollbarThumbOffset();
}

export function beginTocScrollbarDrag(page: ReadBookPage, event: GestureEvent): void {
    const thumbLength = page.tocScrollbarThumbLength();
    const currentOffset = page.tocScrollbarThumbOffset();
    const pointerY = LeafFns.tocScrollbarPointerY(event);
    page.tocScrollbarDragging = true;
    page.tocScrollbarDragOffset = currentOffset;
    if (pointerY >= currentOffset && pointerY <= currentOffset + thumbLength) {
      page.tocScrollbarPointerAnchor = pointerY - currentOffset;
    } else {
      page.tocScrollbarPointerAnchor = thumbLength / 2;
      page.updateTocScrollbarFromPointer(pointerY);
    }
}

export function updateTocScrollbarDrag(page: ReadBookPage, event: GestureEvent): void {
    if (!page.tocScrollbarDragging) return;
    page.updateTocScrollbarFromPointer(LeafFns.tocScrollbarPointerY(event));
}

export function endTocScrollbarDrag(page: ReadBookPage, event: GestureEvent): void {
    if (!page.tocScrollbarDragging) return;
    page.updateTocScrollbarFromPointer(LeafFns.tocScrollbarPointerY(event));
    page.tocScrollbarDragging = false;
    page.flushTocScrollbarTarget();
}

export function cancelTocScrollbarDrag(page: ReadBookPage): void {
    page.tocScrollbarDragging = false;
    page.tocScrollbarPendingIndex = -1;
    if (page.tocScrollbarUpdateTimer >= 0) {
      clearTimeout(page.tocScrollbarUpdateTimer);
      page.tocScrollbarUpdateTimer = -1;
    }
}

export function jumpTocScrollbarToPointer(page: ReadBookPage, event: GestureEvent): void {
    page.tocScrollbarPointerAnchor = page.tocScrollbarThumbLength() / 2;
    page.updateTocScrollbarFromPointer(LeafFns.tocScrollbarPointerY(event));
}

export function updateTocScrollbarFromPointer(page: ReadBookPage, pointerY: number): void {
    const thumbLength = page.tocScrollbarThumbLength();
    const offset = VirtualListScrollbar.clampThumbOffset(page.tocListViewportHeight, thumbLength,
      pointerY - page.tocScrollbarPointerAnchor);
    page.tocScrollbarDragOffset = offset;
    const targetIndex = VirtualListScrollbar.firstVisibleIndex(page.tocListViewportHeight, thumbLength,
      page.tocDatabaseChapterCount, page.tocVisibleItemCount, offset);
    const targetChapterIndex = page.tocReverseOrder ?
      page.tocDatabaseChapterCount - 1 - targetIndex : targetIndex;
    page.tocFirstVisibleGlobalIndex = targetChapterIndex;
    if (page.tocScrollbarDragging) {
      page.queueTocScrollbarTarget(targetChapterIndex, TOC_SCROLLBAR_DRAG_UPDATE_INTERVAL_MS);
      return;
    }
    page.queueTocScrollbarTarget(targetChapterIndex);
}

export function flushTocScrollbarTarget(page: ReadBookPage): void {
    if (page.tocScrollbarUpdateTimer >= 0) {
      clearTimeout(page.tocScrollbarUpdateTimer);
      page.tocScrollbarUpdateTimer = -1;
    }
    const pending = page.tocScrollbarPendingIndex;
    page.tocScrollbarPendingIndex = -1;
    page.applyTocScrollbarTarget(pending);
}

export function queueTocScrollbarTarget(page: ReadBookPage, targetIndex: number, delayMs: number = 16): void {
    page.tocScrollbarPendingIndex = targetIndex;
    if (page.tocScrollbarUpdateTimer >= 0) return;
    page.tocScrollbarUpdateTimer = setTimeout(() => {
      page.tocScrollbarUpdateTimer = -1;
      const pending = page.tocScrollbarPendingIndex;
      page.tocScrollbarPendingIndex = -1;
      page.applyTocScrollbarTarget(pending);
    }, delayMs);
}

export function applyTocScrollbarTarget(page: ReadBookPage, targetIndex: number): void {
    if (targetIndex < 0) return;
    if (page.isTocSearchActive()) {
      const localIndex = page.nearestTocSearchResultIndex(targetIndex);
      if (localIndex < 0) return;
      page.tocFirstVisibleGlobalIndex = page.tocSearchChapterIndexes[localIndex] ?? targetIndex;
      try {
        page.tocScroller.scrollToIndex(localIndex, false, ScrollAlign.START);
      } catch (e) {
        console.warn('拖动目录滚动条定位搜索结果失败:', e);
      }
      return;
    }
    if (page.chapters.length === 0) return;
    const target = Math.max(0, Math.min(targetIndex, page.chapters.length - 1));
    const requestSerial = ++page.tocPositionRequestSerial;
    page.tocPositioning = true;
    const localIndex = page.setTocWindowAround(target, ScrollAlign.START);
    setTimeout(() => {
      if (requestSerial !== page.tocPositionRequestSerial) return;
      try {
        page.tocScroller.scrollToIndex(localIndex, false, ScrollAlign.START);
      } catch (e) {
        console.warn('拖动目录滚动条定位章节失败:', e);
      } finally {
        if (requestSerial === page.tocPositionRequestSerial) page.tocPositioning = false;
      }
    }, 0);
}

export function nearestTocSearchResultIndex(page: ReadBookPage, targetIndex: number): number {
    const indexes = page.tocSearchChapterIndexes;
    if (indexes.length === 0) return -1;
    let low = 0;
    let high = indexes.length - 1;
    while (low < high) {
      const mid = Math.floor((low + high) / 2);
      if (page.tocReverseOrder ? indexes[mid] > targetIndex : indexes[mid] < targetIndex) low = mid + 1;
      else high = mid;
    }
    if (low > 0 && Math.abs(indexes[low - 1] - targetIndex) <= Math.abs(indexes[low] - targetIndex)) {
      return low - 1;
    }
    return low;
}

export function scrollTocVisibleEdge(page: ReadBookPage, toEnd: boolean): void {
    if (!page.isTocSearchActive()) {
      const firstChapterIndex = page.tocReverseOrder ? page.chapters.length - 1 : 0;
      const lastChapterIndex = page.tocReverseOrder ? 0 : page.chapters.length - 1;
      page.scrollTocToChapter(toEnd ? lastChapterIndex : firstChapterIndex,
        toEnd ? ScrollAlign.END : ScrollAlign.START);
      return;
    }
    if (page.tocVisibleChapters.length === 0) {
      return;
    }
    const localIndex = toEnd ? page.tocVisibleChapters.length - 1 : 0;
    setTimeout(() => {
      try {
        page.tocScroller.scrollToIndex(localIndex, true, toEnd ? ScrollAlign.END : ScrollAlign.START);
      } catch (e) {
        console.warn('定位目录搜索结果失败:', e);
      }
    }, 0);
}

export function setTocWindowAround(page: ReadBookPage, index: number, align: ScrollAlign): number {
    page.tocLoadingPreviousPage = false;
    page.tocLoadingNextPage = false;
    if (page.chapters.length === 0) {
      page.tocWindowStart = 0;
      page.tocVisibleChapters = [];
      return 0;
    }
    const canonicalTarget = Math.max(0, Math.min(index, page.chapters.length - 1));
    const target = page.tocReverseOrder ? page.chapters.length - 1 - canonicalTarget : canonicalTarget;
    let start = target - Math.floor(TOC_WINDOW_PAGE_SIZE / 2);
    if (align === ScrollAlign.START) {
      start = target;
    } else if (align === ScrollAlign.END) {
      start = target - TOC_WINDOW_PAGE_SIZE + 1;
    }
    start = Math.max(0, Math.min(start, Math.max(0, page.chapters.length - TOC_WINDOW_PAGE_SIZE)));
    const end = Math.min(page.chapters.length, start + TOC_WINDOW_PAGE_SIZE);
    const visibleChapters: BookChapter[] = [];
    for (let displayIndex = start; displayIndex < end; displayIndex++) {
      visibleChapters.push(page.tocChapterAtDisplayIndex(displayIndex));
    }
    page.tocWindowStart = start;
    page.tocVisibleChapters = visibleChapters;
    return target - start;
}

export function loadNextTocPage(page: ReadBookPage): void {
    if (page.isTocSearchActive() || page.tocPositioning || page.tocLoadingNextPage) {
      return;
    }
    const loadedEnd = page.tocWindowStart + page.tocVisibleChapters.length;
    if (loadedEnd >= page.chapters.length) {
      return;
    }
    page.tocLoadingNextPage = true;
    const nextEnd = Math.min(page.chapters.length, loadedEnd + TOC_WINDOW_PAGE_SIZE);
    const nextChapters: BookChapter[] = [];
    for (let displayIndex = loadedEnd; displayIndex < nextEnd; displayIndex++) {
      nextChapters.push(page.tocChapterAtDisplayIndex(displayIndex));
    }
    page.tocVisibleChapters = page.tocVisibleChapters.concat(nextChapters);
    setTimeout(() => {
      page.tocLoadingNextPage = false;
    }, 0);
}

export function loadPreviousTocPage(page: ReadBookPage): void {
    if (page.isTocSearchActive() || page.tocPositioning || page.tocLoadingPreviousPage ||
      page.tocWindowStart <= 0) {
      return;
    }
    page.tocLoadingPreviousPage = true;
    const oldStart = page.tocWindowStart;
    const nextStart = Math.max(0, oldStart - TOC_WINDOW_PAGE_SIZE);
    const added = oldStart - nextStart;
    const previousChapters: BookChapter[] = [];
    for (let displayIndex = nextStart; displayIndex < oldStart; displayIndex++) {
      previousChapters.push(page.tocChapterAtDisplayIndex(displayIndex));
    }
    page.tocWindowStart = nextStart;
    page.tocVisibleChapters = previousChapters.concat(page.tocVisibleChapters);
    setTimeout(() => {
      try {
        page.tocScroller.scrollToIndex(added, false, ScrollAlign.START);
      } catch (e) {
        console.warn('向前加载目录失败:', e);
      } finally {
        page.tocLoadingPreviousPage = false;
      }
    }, 0);
}

export function scrollTocToCurrentChapter(page: ReadBookPage, smooth: boolean = true): void {
    if (page.chapters.length === 0) {
      return;
    }
    const index = Math.max(0, Math.min(page.currentChapterIndex, page.chapters.length - 1));
    page.scrollTocToChapter(index, ScrollAlign.CENTER, smooth);
}

export function scrollTocToChapter(page: ReadBookPage, index: number, align: ScrollAlign, smooth: boolean = true): void {
    if (page.chapters.length === 0) {
      return;
    }
    const targetIndex = Math.max(0, Math.min(index, page.chapters.length - 1));
    const requestSerial = ++page.tocPositionRequestSerial;
    page.tocPositioning = true;
    const localIndex = page.setTocWindowAround(targetIndex, align);
    setTimeout(() => {
      if (requestSerial !== page.tocPositionRequestSerial) {
        return;
      }
      try {
        page.tocScroller.scrollToIndex(localIndex, smooth, align);
      } catch (e) {
        console.warn('定位目录章节失败:', e);
      } finally {
        setTimeout(() => {
          if (requestSerial === page.tocPositionRequestSerial) {
            page.tocPositioning = false;
          }
        }, 0);
      }
    }, 50);
}

export function getSubTextColor(page: ReadBookPage): string {
    return page.currentReaderTheme().subTextColor;
}

export function readerControlIconColor(page: ReadBookPage): string {
    return page.isReaderThemeDark() ? '#FFFFFFFF' : '#FF202124';
}

export function accentColor(dark: boolean): string {
    return ThemeRuntime.accentColor(dark);
}

export function buttonColor(dark: boolean): string {
    return ThemeRuntime.buttonColor(dark);
}

export function dangerColor(dark: boolean): string {
    return ThemeRuntime.dangerColor(dark);
}

export function readerPanelScrollBarColor(page: ReadBookPage): string {
    return page.isReaderThemeDark() ? '#668A8F98' : '#667A6F63';
}

export function readerChipIdleColor(page: ReadBookPage): string {
    return page.isReaderThemeDark() ? '#24272D' : '#EEF0F3';
}

export function customThemeFieldColor(dark: boolean): string {
    return dark ? '#24FFFFFF' : '#12000000';
}

export function tocSelectedBackgroundColor(page: ReadBookPage): string {
    const color = page.accentColor();
    if (/^#[0-9A-Fa-f]{6}$/.test(color)) {
      return `#11${color.substring(1)}`;
    }
    return page.appDarkMode ? '#112A6FCC' : '#11007DFF';
}

export function readerGlassPanelColor(page: ReadBookPage): string {
    return ThemeRuntime.glassPanelColor(page.isReaderThemeDark(), page.getBackgroundColor());
}

export function readerGlassBorderColor(page: ReadBookPage): string {
    return ThemeRuntime.glassBorderColor(page.isReaderThemeDark());
}

export function readerGlassShadowColor(page: ReadBookPage): string {
    return ThemeRuntime.glassShadowColor(page.isReaderThemeDark());
}

export function readerSolidPanelColor(page: ReadBookPage): string {
    return page.isReaderThemeDark() ? '#191B1F' : '#FFFFFF';
}

export function getReaderPageTurnSurfaceSafeAreaEdges(page: ReadBookPage): SafeAreaEdge[] {
    // Simulation and stack paper always animate in the full-screen coordinate system. Their text layer owns
    // the status-bar inset separately, so expanding the paper never changes正文 pagination.
    return (page.isStackPageTurnAnimation() || page.isSimulationPageTurnAnimation() ||
      page.is3DPageTurnAnimation()) &&
      !page.readerExtendToStatusBar ?
      [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM] : [SafeAreaEdge.BOTTOM];
}

export function getReaderTopSafePadding(page: ReadBookPage): number {
    if (page.isReaderComicModeActive()) {
      return 0;
    }
    // 扩展模式会隐藏状态栏，正文直接从屏幕顶部起算，不为已隐藏的状态栏保留高度。
    if (page.readerExtendToStatusBar) {
      return 0;
    }
    // 仿真与叠页纸张都需要贯穿整个屏幕，因此只由动画页内部补偿文字坐标。普通、滑动和淡入
    // 翻页则在正文容器上统一避让状态栏。
    if (!page.isReaderContinuousScrollSurfaceActive() &&
      (page.isStackPageTurnAnimation() || page.isSimulationPageTurnAnimation() ||
        page.is3DPageTurnAnimation())) {
      return 0;
    }
    return page.statusBarSafeHeight;
}

export function getReaderPageContentTopPadding(page: ReadBookPage): number {
    return !page.isReaderContinuousScrollSurfaceActive() && !page.readerExtendToStatusBar &&
      (page.isStackPageTurnAnimation() || page.isSimulationPageTurnAnimation() ||
        page.is3DPageTurnAnimation()) ?
      page.statusBarSafeHeight : 0;
}

export function getTopControlSafePadding(page: ReadBookPage): number {
    return Math.max(page.statusBarSafeHeight, 32);
}

export function getTopOverlayHeight(page: ReadBookPage): number {
    return 56 + page.getTopControlSafePadding();
}

export function getReaderContentBottomReserve(page: ReadBookPage): number {
    // The reader surface extends through the system navigation area. Reserve the footer line plus its visual
    // lift so the last正文 row cannot be painted underneath metadata moved above the gesture indicator.
    if (!page.readerFooterEnabled || page.isReaderComicModeActive()) return 0;
    return Math.max(8, page.getReaderBottomInfoBarHeight() + page.getReaderBottomInfoBarBottomInset() +
      LeafFns.getReaderBottomInfoBarContentGap());
}

export function getReaderBottomInfoBarHeight(page: ReadBookPage): number {
    const fallbackHeight = 12 + (page.readerFooterShowProgressBar ? 5 : 0);
    if (page.readerBottomInfoBarMeasuredHeight > 0) {
      return Math.max(page.readerBottomInfoBarMeasuredHeight, fallbackHeight);
    }
    // Used only for the first layout pass. The rendered Text reports its real one-line box below,
    // including the current device's font scale, and immediately replaces this conversion.
    try {
      // 12fp 单行文本的行盒按字号缩放并含行高系数；进度条（2vp）+ 间距（3vp）不随字体缩放。
      return px2vp(Math.max(1, fp2px(12))) * 1.4 + (page.readerFooterShowProgressBar ? 5 : 0);
    } catch (_) {
      return fallbackHeight;
    }
}

export function getReaderBottomInfoBarBottomInset(page: ReadBookPage): number {
    // Only lift the footer enough to sit immediately above the gesture indicator. Use half of the reported
    // navigation inset and keep the result in a narrow range so large three-button areas cannot create a gap.
    return Math.max(6, Math.min(8, Math.max(0, page.navBarHeight) * 0.5));
}

export function getReaderV2BottomGuard(page: ReadBookPage): number {
    // Native Paragraph pagination is created before the footer's first area callback. Use the deterministic
    // fallback line height here so measuring the real Text never invalidates a retained pagination session.
    if (!page.readerFooterEnabled || page.isReaderComicModeActive()) return 0;
    let footerHeight = 12 + (page.readerFooterShowProgressBar ? 5 : 0);
    try {
      // 旧公式只按 12fp 字号估算且丢掉了进度条的 +5vp，守卫偏小 5-10vp：V2 分页的
      // 最后一行会压到页脚进度条/文字上。改为行盒（字号×行高系数）+ 进度条分别估算。
      footerHeight = px2vp(Math.max(1, fp2px(12))) * 1.4 + (page.readerFooterShowProgressBar ? 5 : 0);
    } catch (_) {
      footerHeight = 12 + (page.readerFooterShowProgressBar ? 5 : 0);
    }
    return Math.max(8, footerHeight + page.getReaderBottomInfoBarBottomInset() +
      LeafFns.getReaderBottomInfoBarContentGap());
}
