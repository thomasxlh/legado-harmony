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

export function paginateReaderSourceText(page: ReadBookPage, source: string, chapterIndex: number = page.currentChapterIndex): ReaderPaginationResult {
    const text = source || '';
    if (!text || page.pageViewWidth <= 0 || page.pageViewHeight <= 0) {
      return {
        source: text,
        pages: text ? [text] : [],
        starts: text ? [0] : [],
        ends: text ? [text.length] : []
      };
    }
    if (LocalBookService.hasEpubImageMarkers(text)) {
      return page.paginateReaderImageSourceText(text, chapterIndex);
    }
    if (page.shouldUseReaderLayoutV2(text)) {
      return page.buildReaderV2Pagination(text, chapterIndex);
    }

    const horizontalPadding = page.getEffectiveReaderMarginLeft() + page.getEffectiveReaderMarginRight();
    const verticalPadding = page.getEffectiveReaderMarginTop() + page.getReaderContentBottomPadding() +
      page.getReaderPaginationBottomInfoBarHeight() + page.getReaderPaginationRenderGuardHeight();
    const columnWidth = page.getReaderPageColumnWidth();
    const availableWidth = Math.max(1, columnWidth - horizontalPadding);
    const availableHeight = Math.max(1, page.getReaderPaginationViewportHeight() - verticalPadding);
    const measuredAvailableHeight = LeafFns.toMeasurePx(availableHeight) + LeafFns.getReaderPaginationHeightTolerancePx();
    const pages: string[] = [];
    const starts: number[] = [];
    const ends: number[] = [];
    let cursor = 0;

    while (cursor < text.length) {
      const measuredEnd = page.findMeasuredPageEnd(text, cursor, availableWidth, measuredAvailableHeight, chapterIndex);
      const end = page.fitReaderActionMarkerPageEnd(text, cursor, measuredEnd, availableWidth,
        measuredAvailableHeight, chapterIndex);
      if (end <= cursor) {
        break;
      }
      page.pushReaderPage(text, cursor, end, pages, starts, ends);
      cursor = end;
    }

    return {
      source: text,
      pages: pages.length > 0 ? pages : [text],
      starts: starts.length > 0 ? starts : [0],
      ends: ends.length > 0 ? ends : [text.length]
    };
}

export function getStyledSliceDecoration(page: ReadBookPage, slice: ReadTextSlice): DecorationStyleInterface {
    if (slice.ttsHighlighted || !slice.highlighted) {
      return { type: TextDecorationType.None };
    }
    const style = page.resolvedRegexEmphasis(page.getRegexRuleBySlice(slice));
    if (!style.decorationEnabled) {
      return { type: TextDecorationType.None };
    }
    return {
      type: TextDecorationType.Underline,
      color: style.decorationColor,
      style: LeafFns.regexDecorationStyle(style.decorationStyleId)
    };
}

export function paginateReaderImageSourceText(page: ReadBookPage, source: string, chapterIndex: number = page.currentChapterIndex): ReaderPaginationResult {
    const pages: string[] = [];
    const starts: number[] = [];
    const ends: number[] = [];
    let cursor = 0;
    while (cursor < source.length) {
      const markerStart = source.indexOf(LocalBookService.EPUB_IMAGE_MARKER_PREFIX, cursor);
      if (markerStart < 0) {
        page.appendReaderTextSegmentPages(source, cursor, source.length, chapterIndex, pages, starts, ends);
        break;
      }
      page.appendReaderTextSegmentPages(source, cursor, markerStart, chapterIndex, pages, starts, ends);
      const suffix = source.indexOf(LocalBookService.EPUB_IMAGE_MARKER_SUFFIX,
        markerStart + LocalBookService.EPUB_IMAGE_MARKER_PREFIX.length);
      if (suffix < 0) {
        page.appendReaderTextSegmentPages(source, markerStart, source.length, chapterIndex, pages, starts, ends);
        break;
      }
      const markerEnd = suffix + LocalBookService.EPUB_IMAGE_MARKER_SUFFIX.length;
      pages.push(source.substring(markerStart, markerEnd));
      starts.push(markerStart);
      ends.push(markerEnd);
      cursor = markerEnd;
    }
    return {
      source: source,
      pages: pages.length > 0 ? pages : [source],
      starts: starts.length > 0 ? starts : [0],
      ends: ends.length > 0 ? ends : [source.length]
    };
}

export function appendReaderTextSegmentPages(page: ReadBookPage, source: string, start: number, end: number, chapterIndex: number, pages: string[], starts: number[], ends: number[]): void {
    if (end <= start) return;
    const segment = source.substring(start, end);
    if (!segment.trim()) return;
    const result = page.paginateReaderSourceText(segment, chapterIndex);
    for (let i = 0; i < result.pages.length; i++) {
      pages.push(result.pages[i]);
      starts.push(start + (result.starts[i] || 0));
      ends.push(start + (result.ends[i] || segment.length));
    }
}

export function buildReaderPaginationCacheKey(page: ReadBookPage, chapterIndex: number, source: string): string {
    // V2 uses a deterministic footer guard rather than the asynchronously measured line box, so the first footer
    // area callback cannot invalidate an otherwise identical native Paragraph session during book open.
    const footerHeight = page.shouldUseReaderLayoutV2(source) ?
      Math.round(page.getReaderV2BottomGuard() * 100) / 100 :
      Math.round(page.getReaderBottomInfoBarHeight() * 100) / 100;
    const layoutMode = page.isReaderComicModeActive() ? 'comic' :
      (page.isReaderNovelContinuousScrollModeActive() ? 'continuous' : 'paged');
    const headerReserve = Math.round(page.getReaderHeaderContentReserve() * 100) / 100;
    return `reader_page_v80_${layoutMode}_${chapterIndex}_${page.pageViewWidth}_` +
      `${page.getReaderPaginationViewportHeight()}_` +
      `${headerReserve}_${footerHeight}_${page.readerHeaderEnabled}_${page.readerHeaderContentMode}_` +
      `${page.readerFooterEnabled}_${page.readerFooterLeftMode}_${page.readerFooterProgressMode}_` +
      `${page.readerFooterShowProgressBar}_` +
      `${page.readerExtendToStatusBar}_${page.isLandscapeDoublePageActive()}_${page.readerTypographyCacheIdentity()}_` +
      `${LeafFns.readerParagraphCommentPaginationIdentity()}_` +
      `${source.length}_${hashText(source)}`;
}

export function readerTypographyCacheIdentity(page: ReadBookPage): string {
    const regexIdentity = `${page.readerRegexFontEnabled}_${page.readerRegexFontRulesRaw}_` +
      `${page.readerRegexFontPattern}_${page.readerRegexFontMode}_${page.readerRegexFontFamily}_` +
      `${page.readerRegexFontSize}_${page.readerRegexShadowColor}_${page.themeRevision}_` +
      `${LeafFns.themeRegexEmphasisMode()}_${LeafFns.themeRegexBubbleStyleId()}_reader_action_layout_v5`;
    return `${page.readerFontSize}_${page.readerLetterSpacing}_${page.readerTextAlign}_${page.readerLineHeight}_${page.readerParagraphSpacing}_` +
      `${page.keepParagraphIndent}_` +
      `${page.readerMarginLeft}_${page.readerMarginRight}_${page.readerMarginTop}_${page.readerMarginBottom}_` +
      `${page.readerBodyFontMode}_${page.readerBodyFontFamily}_${page.getBodyReaderFontFamily()}_` +
      `${page.readerTitleFontSize}_${page.readerTitleFontMode}_${page.readerTitleFontFamily}_` +
      `${page.getTitleReaderFontFamily()}_${page.getReaderFontFamily()}_${hashText(regexIdentity)}`;
}

export function getCachedReaderPagination(page: ReadBookPage, chapterIndex: number, source: string): ReaderPaginationResult | null {
    const key = page.buildReaderPaginationCacheKey(chapterIndex, source);
    return page.readerPaginationCache.get(key) || null;
}

export function getOrCreateReaderPagination(page: ReadBookPage, chapterIndex: number, source: string, preferredInitialPageCount: number = 0): ReaderPaginationResult {
    const key = page.buildReaderPaginationCacheKey(chapterIndex, source);
    let result = page.readerPaginationCache.get(key);
    const defaultDesiredPageCount = chapterIndex === page.currentChapterIndex ?
      Math.max(READER_CURRENT_PAGINATION_AHEAD_PAGE_COUNT,
        (page.pendingRestorePageIndex >= 0 ? page.pendingRestorePageIndex : page.currentPageIndex) +
        READER_CURRENT_PAGINATION_AHEAD_PAGE_COUNT) : READER_ADJACENT_PAGINATION_PREVIEW_PAGE_COUNT;
    const desiredPageCount = preferredInitialPageCount > 0 ?
      Math.max(1, Math.round(preferredInitialPageCount)) : defaultDesiredPageCount;
    if (!result) {
      result = page.createIncrementalReaderPagination(source, chapterIndex, desiredPageCount);
      page.readerPaginationCache.set(key, result);
      while (page.readerPaginationCache.size > 3) {
        const oldestKey = page.readerPaginationCache.keys().next().value as string | undefined;
        if (!oldestKey) break;
        page.readerPaginationCache.delete(oldestKey);
      }
    } else if (!result.complete && result.pages.length < desiredPageCount) {
      const missingPageCount = desiredPageCount - result.pages.length;
      // A cached deep restore must remain cooperative too. Otherwise reopening while a partial session is cached
      // reintroduces the same synchronous native-Paragraph burst avoided by the initial creation path.
      const synchronousPageCount = result.v2Session ? Math.min(1, missingPageCount) : missingPageCount;
      page.appendReaderPaginationBatch(result, chapterIndex, synchronousPageCount);
    }
    if (chapterIndex === page.currentChapterIndex) {
      page.updateReaderComicPaginationProgress(chapterIndex, result);
    }
    if (chapterIndex === page.currentChapterIndex && !result.complete) {
      page.scheduleReaderPaginationCompletion(chapterIndex, key, result);
    } else if (result.complete) {
      page.persistReaderPagination(chapterIndex, key, result);
    }
    return result;
}

export function createIncrementalReaderPagination(page: ReadBookPage, source: string, chapterIndex: number, initialPageCount: number): ReaderPaginationResult {
    const text = source || '';
    if (text && page.isReaderNovelContinuousScrollModeActive()) {
      return page.createContinuousReaderPagination(text);
    }
    if (text && page.shouldUseReaderLayoutV2(text)) {
      return page.createIncrementalReaderV2Pagination(text, chapterIndex, initialPageCount);
    }
    if (!text || page.pageViewWidth <= 0 || page.pageViewHeight <= 0) {
      const completeResult = page.paginateReaderSourceText(text, chapterIndex);
      completeResult.cursor = text.length;
      completeResult.complete = true;
      return completeResult;
    }
    const result: ReaderPaginationResult = {
      source: text,
      pages: [],
      starts: [],
      ends: [],
      cursor: 0,
      complete: false
    };
    // Publish only the first visible spread synchronously. Restoring a later page and preparing adjacent
    // chapters continue through the cooperative scheduler instead of measuring many pages in one ArkUI turn.
    const visibleSpreadSize = page.isLandscapeDoublePageActive() ? 2 : 1;
    const initialBatchSize = Math.min(visibleSpreadSize, Math.max(1, initialPageCount));
    // appendReaderPaginationBatch yields after its time budget once it has produced at least one page.
    // On a slower first layout that can leave a double-page spread with only its left page until the
    // next interaction publishes more pagination. Complete the small visible spread here; background
    // pagination remains cooperative and incremental for everything after it.
    while (!result.complete && result.pages.length < initialBatchSize) {
      const previousPageCount = result.pages.length;
      page.appendReaderPaginationBatch(result, chapterIndex, initialBatchSize - previousPageCount);
      if (result.pages.length <= previousPageCount) break;
    }
    return result;
}

export function appendReaderPaginationBatch(page: ReadBookPage, result: ReaderPaginationResult, chapterIndex: number, maxPages: number, timeBudgetMs: number = 8): void {
    if (result.complete || maxPages <= 0) return;
    const batchStartedAt = Date.now();
    const text = result.source || '';
    if (!text || page.pageViewWidth <= 0 || page.pageViewHeight <= 0) {
      result.complete = true;
      result.cursor = text.length;
      return;
    }
    if (result.v2Session) {
      // One native Paragraph page can already consume most of a frame budget on a large tablet. In particular,
      // the previous-chapter preloader requests several pages at once; honouring that count in one callback was
      // enough to trigger THREAD_BLOCK_3S. Every V2 callback produces at most one page and yields before the next.
      LeafFns.appendReaderV2PaginationBatch(result, chapterIndex, Math.min(1, maxPages));
      return;
    }
    const horizontalPadding = page.getEffectiveReaderMarginLeft() + page.getEffectiveReaderMarginRight();
    const verticalPadding = page.getEffectiveReaderMarginTop() + page.getReaderContentBottomPadding() +
      page.getReaderPaginationBottomInfoBarHeight() + page.getReaderPaginationRenderGuardHeight();
    const columnWidth = page.getReaderPageColumnWidth();
    const availableWidth = Math.max(1, columnWidth - horizontalPadding);
    const availableHeight = Math.max(1, page.getReaderPaginationViewportHeight() - verticalPadding);
    const measuredHeight = LeafFns.toMeasurePx(availableHeight) + LeafFns.getReaderPaginationHeightTolerancePx();
    let cursor = Math.max(0, Math.min(result.cursor || 0, text.length));
    let appended = 0;
    while (cursor < text.length && appended < maxPages) {
      while (cursor < text.length && LeafFns.isReaderTrimChar(text.charAt(cursor))) cursor++;
      if (cursor >= text.length) break;

      // Remote sources also use the EPUB image marker for inline illustrations,
      // paragraph-comment SVG bubbles and author cards. Keep those markers intact
      // but paginate them incrementally; completing the whole mixed chapter inside
      // one vSync can block ArkUI long enough for the system watchdog to kill us.
      const imageMarkerStart = text.indexOf(LocalBookService.EPUB_IMAGE_MARKER_PREFIX, cursor);
      let imageMarkerEnd = -1;
      if (imageMarkerStart >= 0) {
        const suffix = text.indexOf(LocalBookService.EPUB_IMAGE_MARKER_SUFFIX,
          imageMarkerStart + LocalBookService.EPUB_IMAGE_MARKER_PREFIX.length);
        if (suffix >= 0) imageMarkerEnd = suffix + LocalBookService.EPUB_IMAGE_MARKER_SUFFIX.length;
      }
      if (imageMarkerStart === cursor && imageMarkerEnd > cursor) {
        page.pushReaderPage(text, cursor, imageMarkerEnd, result.pages, result.starts, result.ends);
        cursor = imageMarkerEnd;
        appended++;
        if (Date.now() - batchStartedAt >= Math.max(1, timeBudgetMs)) break;
        continue;
      }

      const beforeCount = result.pages.length;
      let measuredEnd = 0;
      if (imageMarkerStart > cursor && imageMarkerEnd > imageMarkerStart) {
        const textSegment = text.substring(cursor, imageMarkerStart);
        const segmentEnd = page.findMeasuredPageEnd(textSegment, 0, availableWidth, measuredHeight, chapterIndex);
        measuredEnd = cursor + segmentEnd;
      } else {
        measuredEnd = page.findMeasuredPageEnd(text, cursor, availableWidth, measuredHeight, chapterIndex);
      }
      const end = page.fitReaderActionMarkerPageEnd(text, cursor, measuredEnd, availableWidth,
        measuredHeight, chapterIndex);
      if (end <= cursor) break;
      page.pushReaderPage(text, cursor, end, result.pages, result.starts, result.ends);
      cursor = end;
      if (result.pages.length > beforeCount) appended++;
      if (appended > 0 && Date.now() - batchStartedAt >= Math.max(1, timeBudgetMs)) break;
    }
    while (cursor < text.length && LeafFns.isReaderTrimChar(text.charAt(cursor))) cursor++;
    result.cursor = cursor;
    result.complete = cursor >= text.length;
    CooperativeScheduler.reportSynchronousOperation('reader/pagination-batch', Date.now() - batchStartedAt,
      `pages=${appended},cursor=${cursor}/${text.length}`);
}

export function scheduleReaderPaginationCompletion(page: ReadBookPage, chapterIndex: number, key: string, result: ReaderPaginationResult): void {
    const serial = ++page.readerPaginationWorkSerial;
    const imageOnlyPagination = LeafFns.isReaderImageOnlySource(result.source);
    const batchDelay = ReaderActionMarker.has(result.source) ?
      READER_INTERACTIVE_PAGINATION_BATCH_DELAY_MS : READER_PAGINATION_BATCH_DELAY_MS;
    const runBatch = (): void => {
      if (!page.readerPageVisible || serial !== page.readerPaginationWorkSerial ||
        chapterIndex !== page.currentChapterIndex ||
        page.readerPaginationCache.get(key) !== result) {
        return;
      }
      // The loading overlay owns all input until the saved page/offset is restored. A stale shelf-touch idle
      // window must not throttle that mandatory pagination into one page every few seconds. Interaction-aware
      // yielding still applies after the first real reader page is visible.
      if (page.readerInitialPageReady && page.isReaderPaginationInteractionBusy()) {
        setTimeout(runBatch, READER_PAGINATION_BUSY_RETRY_DELAY_MS);
        return;
      }
      // Text measurement and paragraph layout both run on the UI thread. Keep each idle batch small and do not
      // publish every intermediate array: repeated @State replacements rebuild the reader while a page is moving.
      const batchStartedAt = Date.now();
      // A pure comic page is already delimited by an image marker and requires no text measurement. Parse a small
      // group per idle slice so large comics finish promptly without turning the whole chapter into one UI task.
      page.appendReaderPaginationBatch(result, chapterIndex, imageOnlyPagination ? 8 : 1);
      const batchElapsedMs = Math.max(0, Date.now() - batchStartedAt);
      if (!page.readerInitialPageReady) {
        // Publish cooperative snapshots only while a saved page/offset is waiting to become available.
        // Normal background pagination remains private and is published once at completion.
        page.publishCurrentReaderPagination(result);
      }
      if (result.complete) {
        page.publishCurrentReaderPagination(result);
        page.persistReaderPagination(chapterIndex, key, result);
        page.updateReaderComicPaginationProgress(chapterIndex, result);
        return;
      }
      page.updateReaderComicPaginationProgress(chapterIndex, result);
      const adaptiveDelay = batchElapsedMs >= CooperativeScheduler.SLOW_OPERATION_MS ?
        Math.min(240, Math.max(batchDelay, batchElapsedMs * 2)) : batchDelay;
      setTimeout(runBatch, adaptiveDelay);
    };
    setTimeout(runBatch, batchDelay);
}

export function isReaderPaginationInteractionBusy(page: ReadBookPage): boolean {
    const deferredPreviousTurn = page.queuedPageTurnDirection < 0 && page.queuedPageTurnCount > 0 &&
      page.currentPageIndex <= 0 && !page.isPreviousChapterTurnReady();
    const queuedTurnBusy = !deferredPreviousTurn && page.pendingRestorePageIndex < 0 &&
      (page.queuedPageTurnCount > 0 || page.queuedPageTurnDirection !== 0);
    return page.showReaderCommentPanel || page.isPageTurning || page.readerPanActive || page.readerTouchActive ||
      page.readerComicPanMoved || page.readerComicBoundaryDirection !== 0 || page.readerComicChapterSwitching ||
      page.pageSlideDirection !== 0 || page.pageTurnAnimating || queuedTurnBusy ||
      Date.now() < page.readerPaginationInteractionIdleUntil;
}

export function deferReaderPaginationForInteraction(page: ReadBookPage, idleDelayMs: number = 420): void {
    page.readerPaginationInteractionIdleUntil = Math.max(page.readerPaginationInteractionIdleUntil,
      Date.now() + Math.max(0, idleDelayMs));
}

export function publishCurrentReaderPagination(page: ReadBookPage, result: ReaderPaginationResult): void {
    if (page.currentChapterIndex < 0 || page.pagedContentText !== result.source) return;
    const keepVisibleReaderReady = page.readerInitialPageReady &&
      page.displayPageChapterIndex === page.currentChapterIndex && page.contentPages.length > 0;
    const pendingRestore = page.pendingRestorePageIndex;
    const secondaryPageIndex = page.currentPageIndex + 1;
    const shouldRefreshCompletedSpread = page.isLandscapeDoublePageActive() &&
      secondaryPageIndex >= page.contentPages.length && secondaryPageIndex < result.pages.length;
    page.contentPages = [...result.pages];
    page.contentPageStarts = [...result.starts];
    page.contentPageEnds = [...result.ends];
    page.restorePendingPageIndex(result.complete === true);
    if (pendingRestore >= 0 && page.pendingRestorePageIndex < 0) {
      page.setCurrentPageText(page.contentPages[page.currentPageIndex] || '');
    } else if (shouldRefreshCompletedSpread) {
      // The current page surface is keyed by its render version. Merely replacing contentPages updates
      // counters, but a retained ForEach surface can keep the formerly empty right page until a turn.
      page.refreshReaderTextRender();
    }
    const restoredTypographyPosition = page.restoreReaderTypographyOffsetIfAvailable(result.complete === true);
    page.readerInitialPageReady = keepVisibleReaderReady ||
      (page.pendingRestorePageIndex < 0 && !page.hasReaderTypographyRestoreOffset());
    if (page.readerInitialPageReady) page.finishReaderInitialOpening();
    const restoredPendingPosition = pendingRestore >= 0 && page.pendingRestorePageIndex < 0;
    if (page.isReaderContinuousScrollSurfaceActive()) {
      if (restoredPendingPosition || restoredTypographyPosition) page.readerComicScrollRestoring = true;
      page.syncReaderComicPageDataSource();
      if (restoredPendingPosition || restoredTypographyPosition) page.scheduleReaderComicScrollRestore();
    }
    page.scheduleTtsFocusSyncAfterPagination();
    if (restoredPendingPosition && !page.isPageTurning && page.queuedPageTurnCount > 0 &&
      page.queuedPageTurnDirection !== 0) {
      // A queued physical tap may have arrived while the previous chapter's authoritative tail was rebuilding.
      // Resume it only after the pending index has resolved, so one tap remains one page turn.
      setTimeout(() => page.runQueuedPageTurnLater(), 0);
    }
}

export function persistReaderPagination(page: ReadBookPage, chapterIndex: number, key: string, result: ReaderPaginationResult): void {
    if (!result.complete || !page.bookUrl || result.starts.length === 0 ||
      result.starts.length !== result.ends.length) {
      return;
    }
    AppDatabase.getInstance().saveReaderPaginationCache(page.bookUrl, chapterIndex, key,
      result.starts, result.ends).catch((error: Error) => {
      console.warn('保存阅读分页缓存失败:', error);
    });
}

export function applyPreparedReaderPagination(page: ReadBookPage, content: string, chapterIndex: number, createIfMissing: boolean): boolean {
    if (!content || !page.hasPagedReaderArea()) return false;
    const source = page.buildPagedSourceText(chapterIndex, content);
    const cached = page.getCachedReaderPagination(chapterIndex, source);
    if (!cached && !createIfMissing) return false;
    // Crossing a chapter only needs its first spread immediately. Measuring eight pages or waiting for the
    // persisted cache before publishing page one makes the completed swipe appear frozen on fast input.
    const result = page.getOrCreateReaderPagination(chapterIndex, source,
      createIfMissing ? READER_ADJACENT_PAGINATION_PREVIEW_PAGE_COUNT : 0);
    page.applyReaderPaginationResult(result, content);
    return true;
}

export async function restorePersistedReaderPagination(page: ReadBookPage, content: string, chapterIndex: number): Promise<boolean> {
    if (!content || !page.bookUrl || !page.hasPagedReaderArea()) return false;
    const source = page.buildPagedSourceText(chapterIndex, content);
    const key = page.buildReaderPaginationCacheKey(chapterIndex, source);
    const v2Layout = page.shouldUseReaderLayoutV2(source);
    // On affected HarmonyOS builds relationalStore.query() performs a substantial synchronous prefix before its
    // Promise is returned. Waiting for an optional V2 boundary cache therefore stalls the opening frame for about
    // two seconds and cannot be bounded by Promise.race. V2 already owns a retained incremental paginator and a
    // durable character offset, so rebuild its small visible window directly; adjacent tails are prepared later.
    if (v2Layout) return false;
    const record = await AppDatabase.getInstance().getReaderPaginationCache(page.bookUrl, chapterIndex, key);
    if (!record || record.starts.length !== record.ends.length) return false;
    let previousEnd = 0;
    for (let i = 0; i < record.starts.length; i++) {
      const start = record.starts[i];
      const end = record.ends[i];
      if (start < 0 || end <= start || end > source.length || start < previousEnd) return false;
      previousEnd = end;
    }
    if (record.starts.length === 0) return false;
    if (v2Layout) {
      // Native Paragraph objects cannot be serialized. Reuse the durable boundaries to locate the saved offset,
      // rebuild only through that visible window, and let the retained V2 session finish the remaining pages later.
      let targetPageIndex = Math.max(0, page.pendingRestorePageIndex);
      if (page.hasReaderTypographyRestoreOffset()) {
        const targetOffset = Math.min(source.length, page.readerTypographyRestoreOffset);
        targetPageIndex = record.ends.length - 1;
        for (let index = 0; index < record.ends.length; index++) {
          if (targetOffset < record.ends[index]) {
            targetPageIndex = index;
            break;
          }
        }
      }
      targetPageIndex = Math.max(0, Math.min(targetPageIndex, record.ends.length - 1));
      page.pendingRestorePageIndex = targetPageIndex;
      const visibleSpreadSize = page.isLandscapeDoublePageActive() ? 2 : 1;
      const result = page.getOrCreateReaderPagination(chapterIndex, source,
        targetPageIndex + visibleSpreadSize);
      // A backward chapter switch needs the real tail, not an incremental first-page placeholder. Rebuilding a
      // very deep saved position synchronously can still trip the UI watchdog, but ordinary chapters on phones
      // are only a few pages. Finish that small durable window now so "previous chapter" lands immediately on
      // its last page; longer chapters continue through the existing cooperative paginator.
      const immediateTailPageLimit = 8;
      const requestedPageCount = Math.min(record.ends.length, targetPageIndex + visibleSpreadSize);
      if (targetPageIndex < immediateTailPageLimit && result.v2Session && !result.complete &&
        result.pages.length < requestedPageCount) {
        while (!result.complete && result.pages.length < requestedPageCount) {
          const before = result.pages.length;
          LeafFns.appendReaderV2PaginationBatch(result, chapterIndex,
            Math.min(2, requestedPageCount - result.pages.length));
          if (result.pages.length <= before) break;
        }
      }
      page.applyReaderPaginationResult(result, content);
      ReaderOpenTrace.mark(page.bookUrl, 'v2-boundary-cache-hit',
        `pages=${record.ends.length} target=${targetPageIndex}`);
      return true;
    }
    const pages: string[] = [];
    for (let index = 0; index < record.starts.length; index++) {
      pages.push(source.substring(record.starts[index], record.ends[index]));
    }
    const result: ReaderPaginationResult = {
      source: source,
      pages: pages,
      starts: record.starts,
      ends: record.ends,
      cursor: source.length,
      complete: true
    };
    page.readerPaginationCache.set(key, result);
    page.updateReaderComicPaginationProgress(chapterIndex, result);
    page.applyReaderPaginationResult(result, content);
    return true;
}

export function isReaderPreloadBlockedByVisibility(page: ReadBookPage): boolean {
    return !page.readerPageVisible && !page.isTtsContinuousPreloadActive();
}

export function preloadNextChapterPaginationLater(page: ReadBookPage, delayMs: number = 520): void {
    if (page.isReaderPreloadBlockedByVisibility() || !page.readerPreloadEnabled || !page.hasPagedReaderArea() ||
      page.currentChapterIndex >= page.chapters.length - 1) {
      return;
    }
    const sourceChapterIndex = page.currentChapterIndex;
    const targetChapterIndex = sourceChapterIndex + 1;
    const sessionBookUrl = page.book?.bookUrl || page.bookUrl;
    const activeKey = `${sessionBookUrl}_${sourceChapterIndex}_${targetChapterIndex}_` +
      `${page.readerTypographyCacheIdentity()}_${LeafFns.readerParagraphCommentPaginationIdentity()}`;
    if (page.adjacentPaginationPreloadActiveSerial === page.adjacentPaginationPreloadSerial &&
      page.adjacentPaginationPreloadActiveKey === activeKey) return;
    const serial = ++page.adjacentPaginationPreloadSerial;
    page.adjacentPaginationPreloadActiveSerial = serial;
    page.adjacentPaginationPreloadActiveKey = activeKey;
    setTimeout(() => {
      if (page.isReaderPreloadBlockedByVisibility() || serial !== page.adjacentPaginationPreloadSerial ||
        !page.isCurrentReaderEngineBook(sessionBookUrl) ||
        (page.currentChapterIndex !== sourceChapterIndex && page.currentChapterIndex !== targetChapterIndex)) {
        return;
      }
      ReadBookEngine.get().peekContent(targetChapterIndex)
        .then(async (body: string): Promise<void> => {
          if (!body || page.isReaderPreloadBlockedByVisibility() || serial !== page.adjacentPaginationPreloadSerial ||
            !page.isCurrentReaderEngineBook(sessionBookUrl) ||
            (page.currentChapterIndex !== sourceChapterIndex && page.currentChapterIndex !== targetChapterIndex)) {
            if (serial === page.adjacentPaginationPreloadSerial && !body) {
              page.adjacentPaginationPreloadActiveSerial = -1;
            }
            return;
          }
          const processed = await page.prepareReaderContentRules(body, targetChapterIndex);
          if (page.isReaderPreloadBlockedByVisibility() || serial !== page.adjacentPaginationPreloadSerial ||
            !page.isCurrentReaderEngineBook(sessionBookUrl) ||
            (page.currentChapterIndex !== sourceChapterIndex && page.currentChapterIndex !== targetChapterIndex)) {
            return;
          }
          const source = page.buildPagedSourceText(targetChapterIndex, processed);
          const key = page.buildReaderPaginationCacheKey(targetChapterIndex, source);
          const result = page.getCachedReaderPagination(targetChapterIndex, source) ||
            page.getOrCreateReaderPagination(targetChapterIndex, source);
          page.scheduleNextChapterPaginationCompletion(sourceChapterIndex, targetChapterIndex, key, result, serial);
        })
        .catch((err: Error) => {
          if (serial === page.adjacentPaginationPreloadSerial) {
            page.adjacentPaginationPreloadActiveSerial = -1;
          }
          console.error('预排版下一章失败:', err);
        });
    }, Math.max(0, delayMs));
}

export function scheduleNextChapterPaginationCompletion(page: ReadBookPage, sourceChapterIndex: number, targetChapterIndex: number, key: string, result: ReaderPaginationResult, serial: number): void {
    if (result.complete) {
      page.persistReaderPagination(targetChapterIndex, key, result);
      return;
    }
    // A cross-chapter turn must not expose the small provisional spread and then replace it with the
    // completed V2 page set after the animation. That changes the visible total from e.g. 2 to 6 and
    // rebuilds the reader immediately after landing, which looks like a vertical layout shake. Finish
    // the retained next-chapter session cooperatively while the current chapter is still visible.
    // Interaction-busy checks below keep native Paragraph work away from an active drag/turn chain.
    const batchDelay = ReaderActionMarker.has(result.source) ?
      READER_INTERACTIVE_PAGINATION_BATCH_DELAY_MS : READER_PAGINATION_BATCH_DELAY_MS;
    const runBatch = (): void => {
      if (page.isReaderPreloadBlockedByVisibility() || serial !== page.adjacentPaginationPreloadSerial ||
        page.currentChapterIndex !== sourceChapterIndex ||
        page.readerPaginationCache.get(key) !== result) {
        // Same hygiene as the previous-chapter session: a silently aborted run must not keep the
        // active-session dedupe claiming this preload is still running.
        if (serial === page.adjacentPaginationPreloadSerial &&
          page.adjacentPaginationPreloadActiveSerial === serial) {
          page.adjacentPaginationPreloadActiveSerial = -1;
        }
        return;
      }
      if (page.isReaderPaginationInteractionBusy()) {
        setTimeout(runBatch, READER_PAGINATION_BUSY_RETRY_DELAY_MS);
        return;
      }
      const startedAt = Date.now();
      page.appendReaderPaginationBatch(result, targetChapterIndex, 1);
      if (result.complete) {
        page.persistReaderPagination(targetChapterIndex, key, result);
        console.info(`[ReaderPreload] next chapter=${targetChapterIndex} pages=${result.pages.length} ` +
          `lastBatch=${Date.now() - startedAt}ms`);
        return;
      }
      const elapsedMs = Math.max(0, Date.now() - startedAt);
      const nextDelay = elapsedMs >= CooperativeScheduler.SLOW_OPERATION_MS ?
        Math.min(240, Math.max(batchDelay, elapsedMs * 2)) : batchDelay;
      setTimeout(runBatch, nextDelay);
    };
    setTimeout(runBatch, 0);
}

export function preloadPreviousChapterPaginationLater(page: ReadBookPage, delayMs: number = 760): void {
    if (!page.readerPageVisible || !page.hasPagedReaderArea() || page.currentChapterIndex <= 0) return;
    const sourceChapterIndex = page.currentChapterIndex;
    const targetChapterIndex = sourceChapterIndex - 1;
    // "Preload" off disables speculative network requests, but a chapter the user just left is already cached.
    // Its tail pagination is required for a correct instant backward turn and is safe to prepare locally.
    if (!page.readerPreloadEnabled && !ReadBookEngine.get().hasCachedContent(targetChapterIndex)) return;
    const sessionBookUrl = page.book?.bookUrl || page.bookUrl;
    const activeKey = `${sessionBookUrl}_${sourceChapterIndex}_${targetChapterIndex}_` +
      `${page.readerTypographyCacheIdentity()}_${LeafFns.readerParagraphCommentPaginationIdentity()}`;
    // Page 2/3 hooks can request the same previous chapter repeatedly. Restarting the retained V2 session on
    // every local turn prevented it from ever reaching the real last page before the user swiped backwards.
    if (page.previousPaginationPreloadActiveSerial === page.previousPaginationPreloadSerial &&
      page.previousPaginationPreloadActiveKey === activeKey) return;
    const serial = ++page.previousPaginationPreloadSerial;
    page.previousPaginationPreloadActiveSerial = serial;
    page.previousPaginationPreloadActiveKey = activeKey;
    setTimeout(() => {
      if (!page.readerPageVisible || serial !== page.previousPaginationPreloadSerial ||
        !page.isCurrentReaderEngineBook(sessionBookUrl) ||
        page.currentChapterIndex !== sourceChapterIndex) return;
      ReadBookEngine.get().peekContent(targetChapterIndex)
        .then(async (body: string): Promise<void> => {
          if (!body || !page.readerPageVisible || serial !== page.previousPaginationPreloadSerial ||
            !page.isCurrentReaderEngineBook(sessionBookUrl) ||
            page.currentChapterIndex !== sourceChapterIndex) {
            if (serial === page.previousPaginationPreloadSerial && !body) {
              page.previousPaginationPreloadActiveSerial = -1;
            }
            return;
          }
          const processed = await page.prepareReaderContentRules(body, targetChapterIndex);
          if (!page.readerPageVisible || serial !== page.previousPaginationPreloadSerial ||
            !page.isCurrentReaderEngineBook(sessionBookUrl) ||
            page.currentChapterIndex !== sourceChapterIndex) {
            return;
          }
          const source = page.buildPagedSourceText(targetChapterIndex, processed);
          const key = page.buildReaderPaginationCacheKey(targetChapterIndex, source);
          const result = page.getCachedReaderPagination(targetChapterIndex, source) ||
            page.getOrCreateReaderPagination(targetChapterIndex, source);
          page.schedulePreviousChapterPaginationCompletion(sourceChapterIndex, targetChapterIndex, key, result,
            serial);
        })
        .catch((error: Error) => {
          if (serial === page.previousPaginationPreloadSerial) {
            page.previousPaginationPreloadActiveSerial = -1;
          }
          console.error('预排版上一章失败:', error);
        });
    }, Math.max(0, delayMs));
}

export function schedulePreviousChapterPaginationCompletion(page: ReadBookPage, sourceChapterIndex: number, targetChapterIndex: number, key: string, result: ReaderPaginationResult, serial: number): void {
    if (result.complete) {
      page.persistReaderPagination(targetChapterIndex, key, result);
      page.resumeDeferredPreviousChapterTurn(sourceChapterIndex);
      return;
    }
    // Going backwards must land on the real last page. V2 used to stop here after producing only
    // the two-page turn preview, so the first backward chapter turn had to finish the whole chapter
    // after the gesture and exposed the "restore progress" overlay. Complete the retained native
    // pagination cooperatively while the current chapter is being read; a small two-page idle slice keeps
    // the UI responsive and makes the previous tail immediately available when the user turns back.
    const batchDelay = ReaderActionMarker.has(result.source) ?
      READER_INTERACTIVE_PAGINATION_BATCH_DELAY_MS : READER_PAGINATION_BATCH_DELAY_MS;
    const runBatch = (): void => {
      if (!page.readerPageVisible || serial !== page.previousPaginationPreloadSerial ||
        page.currentChapterIndex !== sourceChapterIndex ||
        page.readerPaginationCache.get(key) !== result) {
        // Losing the retained cache entry (LRU eviction, a global pagination-cache clear, a chapter jump)
        // kills this session. Clear the active-session marker too, otherwise the dedupe in
        // preloadPreviousChapterPaginationLater keeps treating the dead session as alive and every later
        // swipe becomes a silent no-op with the user's turn stuck in the queue forever.
        if (serial === page.previousPaginationPreloadSerial &&
          page.previousPaginationPreloadActiveSerial === serial) {
          page.previousPaginationPreloadActiveSerial = -1;
        }
        return;
      }
      if (page.isReaderPaginationInteractionBusy()) {
        setTimeout(runBatch, READER_PAGINATION_BUSY_RETRY_DELAY_MS);
        return;
      }
      const startedAt = Date.now();
      // appendReaderPaginationBatch limits Reader V2 to one native Paragraph page per callback. The larger count
      // remains useful for the legacy text measurer, whose explicit time budget yields inside the loop.
      page.appendReaderPaginationBatch(result, targetChapterIndex, 3, 10);
      if (result.complete) {
        page.persistReaderPagination(targetChapterIndex, key, result);
        console.info(`[ReaderPreload] previous chapter=${targetChapterIndex} pages=${result.pages.length} ` +
          `lastBatch=${Date.now() - startedAt}ms`);
        // A slow drag may already be exposing the temporary incoming leaf. Replace it with the
        // confirmed tail before the curl snapshot is captured/released; never leave the provisional
        // first spread on the back of a backward cross-chapter turn.
        if (page.pageSlideDirection < 0 && page.pageTurnCrossChapterHandoff &&
          page.pageTurnIncomingChapterIndex === targetChapterIndex) {
          const preview = page.buildAdjacentPageTurnPreview(-1, targetChapterIndex, result.source);
          if (preview.text) page.applyPageTurnPreview(preview);
        }
        page.resumeDeferredPreviousChapterTurn(sourceChapterIndex);
        return;
      }
      const elapsedMs = Math.max(0, Date.now() - startedAt);
      const nextDelay = elapsedMs >= CooperativeScheduler.SLOW_OPERATION_MS ?
        Math.min(160, Math.max(32, elapsedMs * 2)) : Math.min(batchDelay, 24);
      setTimeout(runBatch, nextDelay);
    };
    setTimeout(runBatch, 0);
}

export function paginateContent(page: ReadBookPage, sourceContent?: string, chapterIndex: number = page.currentChapterIndex): void {
    const content = sourceContent !== undefined ? sourceContent : page.content;
    if (!content) {
      page.clearReaderComicPaginationProgress();
      page.contentPages = [];
      page.pagedContentText = '';
      page.contentPageStarts = [];
      page.contentPageEnds = [];
      page.setCurrentPageText('');
      return;
    }

    if (!page.hasPagedReaderArea()) {
      page.clearReaderComicPaginationProgress();
      page.contentPages = [];
      page.pagedContentText = '';
      page.contentPageStarts = [];
      page.contentPageEnds = [];
      page.setCurrentPageText(content);
      return;
    }

    const safeChapterIndex = page.clampChapterIndex(chapterIndex);
    const pagedSource = page.buildPagedSourceText(safeChapterIndex, content);
    const result = page.getOrCreateReaderPagination(safeChapterIndex, pagedSource);
    page.applyReaderPaginationResult(result, content);
}

export function applyReaderPaginationResult(page: ReadBookPage, result: ReaderPaginationResult, fallbackContent: string): void {
    const initialPageWasReady = page.readerInitialPageReady;
    const keepVisibleReaderReady = initialPageWasReady &&
      page.displayPageChapterIndex === page.currentChapterIndex && page.contentPages.length > 0;
    if (keepVisibleReaderReady && !result.complete && page.pagedContentText === result.source) {
      // Do not replace a completed on-screen page set with the first one/two pages of a new incremental session.
      // That transient snapshot made a foreground resume visibly jump from e.g. 3-4/8 to 1-2/2 before returning.
      // scheduleReaderPaginationCompletion() still owns the private result and publishes it once complete.
      return;
    }
    const pages: string[] = result.pages.length > 0 ? result.pages : [fallbackContent];
    const hasAuthoritativePageBoundary = result.pages.length > 0 && result.starts.length > 0 &&
      result.ends.length > 0;
    if (!result.complete && page.pendingRestorePageIndex < 0 && page.currentPageIndex >= pages.length) {
      // Incremental pagination (especially chapters containing paragraph-comment markers) may initially expose
      // only page one. Preserve the authoritative page until enough boundaries have been rebuilt instead of
      // clamping it to zero and later persisting that temporary fallback as the reading progress.
      page.pendingRestorePageIndex = page.currentPageIndex;
    }
    page.pagedContentText = result.source;
    // Render from a snapshot. Incremental pagination continues in its private cache and is published once complete,
    // so background layout cannot mutate or replace the visible page collection every few milliseconds.
    page.contentPages = [...pages];
    page.contentPageStarts = result.starts.length > 0 ? [...result.starts] : [0];
    page.contentPageEnds = result.ends.length > 0 ? [...result.ends] : [page.pagedContentText.length];
    // The synthetic fallback above is only a hidden render placeholder while V2 has not produced its first
    // measured boundary. Treating its full-source end as a real one-page pagination maps every persisted
    // character offset to page zero and permanently discards a saved deep/last-page position.
    if (hasAuthoritativePageBoundary) page.restorePendingPageIndex(result.complete === true);
    if (page.currentPageIndex >= pages.length) {
      page.currentPageIndex = Math.max(0, pages.length - 1);
    }
    const pageIndex = page.normalizeReaderSpreadPageIndex(
      Math.max(0, Math.min(page.currentPageIndex, Math.max(0, pages.length - 1)))
    );
    page.currentPageIndex = pageIndex;
    page.setCurrentPageText(pages[pageIndex] || '');
    if (hasAuthoritativePageBoundary) {
      page.restoreReaderTypographyOffsetIfAvailable(result.complete === true);
    }
    // Incremental pagination may initially contain only page one. Do not expose that temporary page while
    // the saved position is still waiting for enough page boundaries to be rebuilt.
    page.readerInitialPageReady = keepVisibleReaderReady ||
      (page.pendingRestorePageIndex < 0 && !page.hasReaderTypographyRestoreOffset());
    if (page.readerInitialPageReady) page.finishReaderInitialOpening();
    if (!initialPageWasReady && page.readerInitialPageReady && page.bookUrl) {
      ReaderOpenTrace.finish(page.bookUrl);
    }
    page.syncReaderComicPageDataSource();
    page.scheduleReaderComicScrollRestore();
    page.scheduleTtsFocusSyncAfterPagination();
}

export function setAutoPageTurnActive(page: ReadBookPage, enabled: boolean): void {
    if (!enabled) {
      page.autoPageTurnActive = false;
      return;
    }
    if (page.isTtsSpeaking || page.ttsReader.isSpeaking() || ReaderTtsFloatingSession.isActive()) {
      HdsFeedback.showToast('朗读中无法开启自动翻页');
      return;
    }
    if (page.chapters.length === 0) {
      HdsFeedback.showToast('书籍尚未加载完成');
      return;
    }
    page.autoPageTurnActive = true;
}

export function configureAutoPageTurnController(page: ReadBookPage): void {
    const options: AutoPageTurnOptions = {
      intervalMs: page.autoPageTurnIntervalSec * 1000,
      isBlocked: (): boolean => page.isAutoPageTurnBlocked(),
      onTurn: (): void => page.handleAutoPageTurnExpire(),
      onTick: (remainingMs: number, intervalMs: number, userPaused: boolean): void => {
        const fraction = intervalMs > 0 ?
          Math.max(0, Math.min(1, remainingMs / intervalMs)) : 1;
        if (Math.abs(fraction - page.autoPageTurnRingProgress) > 0.002) {
          page.autoPageTurnRingProgress = fraction;
        }
        if (userPaused !== page.autoPageTurnUserPaused) {
          page.autoPageTurnUserPaused = userPaused;
        }
      }
    };
    page.autoPageTurnController.configure(options);
}

export function startAutoPageTurn(page: ReadBookPage): void {
    page.configureAutoPageTurnController();
    page.autoPageTurnController.start(page.autoPageTurnIntervalSec * 1000);
}

export function stopAutoPageTurn(page: ReadBookPage, showToast: boolean): void {
    page.autoPageTurnController.stop();
    page.autoPageTurnRingProgress = 1;
    page.autoPageTurnUserPaused = false;
    if (page.autoPageTurnActive) {
      page.autoPageTurnActive = false;
    }
    if (showToast) {
      HdsFeedback.showToast('已达书末，自动翻页已停止');
    }
}

export function resetAutoPageTurnCountdown(page: ReadBookPage): void {
    if (!page.autoPageTurnActive || !page.autoPageTurnController.isRunning() ||
      page.autoPageTurnController.isUserPaused()) {
      return;
    }
    page.autoPageTurnController.reset();
}

export function isAutoPageTurnBlocked(page: ReadBookPage): boolean {
    return !page.readerPageVisible ||
      page.showMenu || page.showToc || page.showSettings || page.showReaderActionMenu ||
      page.showBookmarkActionMenu || page.showAutoPageTurnIntervalDialog || page.showTapZoneSettings ||
      page.showChangeSourceDialog || page.showReaderCommentPanel || page.showReaderEyeCalibration ||
      page.readerTextSelectionActive || page.isLoading || !page.readerInitialPageReady ||
      page.isTtsSpeaking || page.ttsReader.isSpeaking() || ReaderTtsFloatingSession.isActive() ||
      page.isPageTurning || page.pageTurnAnimating || page.readerComicChapterSwitching ||
      page.queuedPageTurnCount > 0;
}

export function isAtReaderBookEnd(page: ReadBookPage): boolean {
    return page.chapters.length > 0 &&
      page.currentChapterIndex >= page.chapters.length - 1 &&
      page.isCurrentReaderPaginationComplete() &&
      page.currentPageIndex + page.getReaderPageTurnStep() >= page.contentPages.length;
}

export function handleAutoPageTurnExpire(page: ReadBookPage): void {
    if (!page.autoPageTurnActive || page.isPageTurning || page.isLoading) {
      return;
    }
    if (!page.canTurnPage(1)) {
      if (page.isAtReaderBookEnd()) {
        page.stopAutoPageTurn(true);
      }
      return;
    }
    page.turnNext().catch((error: Error): void => {
      console.warn('[AutoPageTurn] page turn failed:', error.message);
    });
}

export function scrollReaderComicByPage(page: ReadBookPage, direction: number): void {
    if (!page.isReaderContinuousScrollSurfaceActive() || page.contentPages.length === 0) return;
    let targetIndex = page.currentPageIndex + (direction > 0 ? 1 : -1);
    if (direction > 0 && targetIndex >= page.contentPages.length) {
      page.ensureCurrentReaderPaginationAhead(targetIndex + 1);
      targetIndex = page.currentPageIndex + 1;
    }
    if (targetIndex >= 0 && targetIndex < page.contentPages.length) {
      page.readerComicScroller.scrollToIndex(targetIndex, true, ScrollAlign.START);
      return;
    }
    if (direction > 0) {
      // contentPages is an incremental snapshot. Its temporary tail is not the chapter tail until the retained
      // pagination session reports complete; crossing here can skip pages which are appended a moment later.
      if (!page.isCurrentReaderPaginationComplete()) return;
      page.loadNextChapter(false, true);
    } else {
      if (!page.isPreviousChapterTurnReady()) {
        page.pendingScrollPreviousChapterTurn = true;
        page.preloadPreviousChapterPaginationLater(0);
        return;
      }
      page.loadPrevChapter(true, false, true);
    }
}

export function preloadReaderContent(page: ReadBookPage): void {
    // 锁屏/后台连续朗读时 onPageHide 会把 readerPageVisible 置 false，若照常短路返回，
    // 每到章末才现场联网取正文（正文拉取超时上限 45s），听书切章出现长静默等待。
    // 连续朗读期间放行正文预载；排版预载（pagination）仍依赖可见阅读区域，由各自入口自行短路。
    if ((!page.readerPageVisible && !page.isTtsContinuousPreloadActive()) ||
      page.chapters.length === 0 || !page.readerPreloadEnabled) {
      return;
    }
    // Current-page recovery is user-visible work. Do not let speculative adjacent Paragraph sessions compete
    // with it; retry once the authoritative current page has been published.
    if (!page.readerInitialPageReady) {
      page.preloadReaderContentLater(240);
      return;
    }
    const engine = ReadBookEngine.get();
    if (!page.isCurrentReaderEngineBook()) return;
    engine.preloadAround(page.currentChapterIndex, LeafFns.normalizePreloadChapterCount(page.readerPreloadChapterCount), 0);
    page.preloadNextChapterPaginationLater();
    page.preloadPreviousChapterPaginationLater();
}

export function isTtsContinuousPreloadActive(page: ReadBookPage): boolean {
    return page.isTtsSpeaking && page.ttsAutoContinue;
}

export function preloadReaderContentLater(page: ReadBookPage, delayMs: number = 240): void {
    setTimeout(() => {
      page.preloadReaderContent();
    }, Math.max(0, delayMs));
}

export function canTurnPage(page: ReadBookPage, direction: number): boolean {
    if (page.chapters.length === 0) {
      return false;
    }
    if (page.pendingRestorePageIndex >= 0) return false;
    if (direction > 0) {
      const targetPageIndex = page.currentPageIndex + page.getReaderPageTurnStep();
      if (targetPageIndex >= page.contentPages.length) {
        page.ensureCurrentReaderPaginationAhead(targetPageIndex + 2);
      }
      if (page.currentPageIndex + page.getReaderPageTurnStep() < page.contentPages.length) return true;
      // Only a completed pagination result owns an authoritative chapter tail. A fast queue can otherwise consume
      // the provisional last spread and enter the next chapter while V2 is still appending hidden pages.
      if (!page.isCurrentReaderPaginationComplete()) {
        // The completion loop may have died (superseded/hidden during TTS playback). Re-arm it so the
        // next cross-chapter swipe can succeed instead of silently no-opping forever.
        page.resumeCurrentReaderPaginationCompletion();
        return false;
      }
      return page.currentChapterIndex < page.chapters.length - 1;
    }
    if (page.currentPageIndex > 0) return true;
    if (page.currentChapterIndex <= 0) return false;
    // 跨章前翻与向前跨章、滚动模式同策略：立即提交章节切换。落在真实的最后一页由 loadPrevChapter 的
    // pendingRestorePageIndex(MAX_SAFE_INTEGER) 机制保证——增量排版补齐尾页后才复位，等待期间翻页提示页覆盖屏幕。
    return true;
}

export function isPreviousChapterTurnReady(page: ReadBookPage): boolean {
    if (!page.hasPagedReaderArea() || page.currentChapterIndex <= 0) return true;
    if (!page.isCurrentReaderEngineBook()) return false;
    const targetChapterIndex = page.currentChapterIndex - 1;
    const body = ReadBookEngine.get().getCachedContent(targetChapterIndex);
    if (!body) return false;
    const prepared = page.getPreparedReaderContent(body, targetChapterIndex);
    if (!prepared && ReaderContentPreprocessor.hasActiveContentRules(page.readerReplaceRules)) return false;
    const source = page.buildPagedSourceText(targetChapterIndex, prepared || body);
    return page.getCachedReaderPagination(targetChapterIndex, source)?.complete === true;
}

export function resumeDeferredPreviousChapterTurn(page: ReadBookPage, sourceChapterIndex: number): void {
    if (page.currentChapterIndex !== sourceChapterIndex || !page.isPreviousChapterTurnReady()) return;
    if (page.pendingScrollPreviousChapterTurn && page.isReaderContinuousScrollSurfaceActive()) {
      page.pendingScrollPreviousChapterTurn = false;
      page.loadPrevChapter(true, false, true);
      return;
    }
    if (!page.isPageTurning && page.queuedPageTurnDirection < 0 && page.queuedPageTurnCount > 0) {
      page.runQueuedPageTurnLater();
    }
}

export async function waitForReaderChapterTailSettled(page: ReadBookPage, timeoutMs: number = 12000): Promise<void> {
    if (page.pendingRestorePageIndex < 0 && !page.hasReaderTypographyRestoreOffset()) return;
    const startedAtChapterIndex = page.currentChapterIndex;
    const deadline = Date.now() + Math.max(0, timeoutMs);
    while (Date.now() < deadline && page.readerPageVisible &&
      (page.pendingRestorePageIndex >= 0 || page.hasReaderTypographyRestoreOffset())) {
      if (page.currentChapterIndex !== startedAtChapterIndex) return;
      // 加载失败/需要网页验证的提示正文只有一页，不会再排版出尾页，立即落地展示。
      if (page.content.includes('章节正文加载失败') || page.content.includes('完成网页验证')) break;
      await LeafFns.delay(16);
    }
    if (page.pendingRestorePageIndex < 0 && !page.hasReaderTypographyRestoreOffset()) return;
    console.warn(`[ReaderTurn] previous-chapter tail not ready (timedOut=${Date.now() >= deadline}), ` +
      `chapter=${page.currentChapterIndex}, pages=${page.contentPages.length}`);
    // 兜底：落到当前已知的最后一页。与本地翻页恢复锚点的清理方式保持一致。
    page.currentPageIndex = Math.max(0, page.contentPages.length - 1);
    page.pendingRestorePageIndex = -1;
    page.setReaderTypographyRestoreOffset(-1);
    page.readerInitialPageReady = true;
    page.finishReaderInitialOpening();
}

export function showReaderTailWaitingLeafIfGeneric(page: ReadBookPage): void {
    if (page.pageSlideDirection >= 0 || !page.pageTurnIncomingText) return;
    const targetChapterIndex = page.currentChapterIndex;
    if (page.pageTurnIncomingChapterIndex !== targetChapterIndex) return;
    if (page.pageTurnIncomingText !== page.getPageTurnLoadingText(targetChapterIndex)) return;
    const title = page.getChapterTitle(targetChapterIndex).trim();
    const waiting = ReadBookEngine.get().getCachedContent(targetChapterIndex) ?
      '上一章排版中，请稍候...' : '正在加载上一章...';
    page.setPageTurnIncomingState(page.pageTurnIncomingPageIndex,
      title ? `${title}\n\n${waiting}` : waiting, true, targetChapterIndex);
}

export function ensureCurrentReaderPaginationAhead(page: ReadBookPage, requiredPageCount: number): void {
    if (!page.pagedContentText) return;
    const result = page.currentReaderPaginationResult();
    if (!result) return;
    if (!result.complete && result.pages.length < requiredPageCount) {
      // Normally the idle worker stays well ahead. This is only a boundary fallback for exceptionally fast input.
      page.appendReaderPaginationBatch(result, page.currentChapterIndex,
        Math.max(1, requiredPageCount - result.pages.length));
    }
    if (result.pages.length > page.contentPages.length) page.publishCurrentReaderPagination(result);
    if (result.complete) {
      const key = page.buildReaderPaginationCacheKey(page.currentChapterIndex, page.pagedContentText);
      page.persistReaderPagination(page.currentChapterIndex, key, result);
    }
}

export function currentReaderPaginationResult(page: ReadBookPage): ReaderPaginationResult | null {
    if (!page.pagedContentText || !page.hasPagedReaderArea()) return null;
    const key = page.buildReaderPaginationCacheKey(page.currentChapterIndex, page.pagedContentText);
    const result = page.readerPaginationCache.get(key) || null;
    if (result) {
      // Keep the active chapter newer than speculative adjacent entries. Losing the owning session at a fast
      // chapter boundary makes the visible snapshot look complete even though more pages still exist.
      page.readerPaginationCache.delete(key);
      page.readerPaginationCache.set(key, result);
    }
    return result;
}

export function createContinuousReaderPagination(page: ReadBookPage, source: string): ReaderPaginationResult {
    const pages: string[] = [];
    const starts: number[] = [];
    const ends: number[] = [];
    // A continuous List does not need screen-exact page heights. Splitting by a bounded source window keeps each
    // lazy Text surface cheap while preserving paragraph/action boundaries and exact source offsets for progress,
    // selection and TTS. This avoids native Paragraph measurement entirely during open and adjacent preloading.
    const targetLength = 1800;
    const minimumBreakLength = Math.round(targetLength * 0.55);
    const maximumForwardBreak = Math.round(targetLength * 0.35);
    let cursor = 0;
    while (cursor < source.length) {
      while (cursor < source.length && page.trimPageStartChar(source.charAt(cursor))) cursor++;
      if (cursor >= source.length) break;
      let end = Math.min(source.length, cursor + targetLength);
      if (end < source.length) {
        const backwardBreak = source.lastIndexOf('\n', end);
        if (backwardBreak >= cursor + minimumBreakLength) {
          end = backwardBreak;
        } else {
          const forwardBreak = source.indexOf('\n', end);
          if (forwardBreak > end && forwardBreak <= end + maximumForwardBreak) end = forwardBreak;
        }
        // Comment/action payloads are atomic. If the target falls inside or immediately before a marker, carry the
        // whole marker into the same chunk so raw payload text can never leak into rendering or speech.
        end = LeafFns.adjustReaderActionMarkerPageEnd(source, cursor, end);
      }
      if (end <= cursor) end = Math.min(source.length, cursor + targetLength);
      page.pushReaderPage(source, cursor, end, pages, starts, ends);
      cursor = Math.max(cursor + 1, end);
    }
    if (pages.length === 0 && source) {
      pages.push(source);
      starts.push(0);
      ends.push(source.length);
    }
    return {
      source: source,
      pages: pages,
      starts: starts,
      ends: ends,
      cursor: source.length,
      complete: true
    };
}

export function isCurrentReaderPaginationComplete(page: ReadBookPage): boolean {
    if (!page.hasPagedReaderArea() || !page.pagedContentText) return true;
    const result = page.currentReaderPaginationResult();
    // paginateContent always registers the active result. If it is temporarily absent, fail closed at the
    // chapter boundary instead of treating an unverified visible snapshot as authoritative.
    return result?.complete === true;
}

export async function applyPageTurn(page: ReadBookPage, direction: number, targetPreview: PageTurnPreview | null = null, commitText: boolean = true): Promise<void> {
    const capturedLocalTarget = !!targetPreview && targetPreview.chapterIndex === page.currentChapterIndex &&
      (!targetPreview.documentSource || targetPreview.documentSource === page.pagedContentText);
    let localPageIndex = -1;
    if (capturedLocalTarget && targetPreview) {
      const capturedPageIndex = page.normalizeReaderSpreadPageIndex(Math.max(0, targetPreview.pageIndex));
      if (capturedPageIndex >= page.contentPages.length) {
        page.ensureCurrentReaderPaginationAhead(capturedPageIndex + page.getReaderPageTurnStep());
      }
      // The target was frozen before the animation. If its pagination window is still rebuilding, never reinterpret
      // the changed currentPageIndex as a chapter boundary; that turns one local page into a whole-chapter skip.
      if (capturedPageIndex >= page.contentPages.length) return;
      if (page.pendingRestorePageIndex >= 0 || page.hasReaderTypographyRestoreOffset()) {
        // A background snapshot may have preserved the page that was visible at animation start. The explicit user
        // turn now supersedes that anchor; leaving it alive restores the old page a moment after the animation.
        page.pendingRestorePageIndex = -1;
        page.setReaderTypographyRestoreOffset(-1);
        page.readerInitialPageReady = true;
        page.finishReaderInitialOpening();
      }
      localPageIndex = capturedPageIndex;
    } else {
      localPageIndex = page.getLocalPageTurnTargetPageIndex(direction);
    }
    if (localPageIndex >= 0) {
      // A valid explicit turn is authoritative even when the initial restore finished before this gesture began.
      // Without this assignment an offset-based restore could keep every later checkpoint pinned to the old page.
      page.readerProgressRestoreConfirmed = true;
    }
    if (direction > 0) {
      if (localPageIndex >= 0) {
        page.applyLocalPageTurnTarget(localPageIndex, targetPreview, commitText);
        if (page.contentPages.length - page.currentPageIndex <= 3) {
          page.preloadReaderContentLater();
          page.preloadNextChapterPaginationLater(0);
        }
        page.scheduleReaderPagedProgressSave();
      } else {
        if (!page.isCurrentReaderPaginationComplete()) {
          page.resumeCurrentReaderPaginationCompletion();
          return;
        }
        await page.loadNextChapter();
      }
      return;
    }

    if (localPageIndex >= 0) {
      page.applyLocalPageTurnTarget(localPageIndex, targetPreview, commitText);
      if (page.currentPageIndex <= 2) {
        page.preloadReaderContentLater();
      }
      page.scheduleReaderPagedProgressSave();
    } else {
      // 与向前跨章、滚动模式同策略：立即提交章节切换。提示页（“上一章排版中/加载中”）在等待期间
      // 覆盖屏幕，尾页排版完成后 pendingRestorePageIndex 复位、自动落在真实的最后一页。
      await page.loadPrevChapter(true);
      page.showReaderTailWaitingLeafIfGeneric();
      await page.waitForReaderChapterTailSettled();
      page.scheduleReaderPagedProgressSave();
    }
}

export function applyLocalPageTurnTarget(page: ReadBookPage, targetPageIndex: number, targetPreview: PageTurnPreview | null = null, commitText: boolean = true): void {
    const safePageIndex = Math.max(0, Math.min(targetPageIndex, Math.max(0, page.contentPages.length - 1)));
    page.currentPageIndex = safePageIndex;
    if (!commitText) {
      return;
    }
    if (targetPreview && targetPreview.chapterIndex === page.currentChapterIndex &&
      targetPreview.pageIndex === safePageIndex && targetPreview.text) {
      page.setCurrentPageText(targetPreview.text);
      page.refreshReaderTextRender();
      return;
    }
    if (page.pageTurnIncomingChapterIndex === page.currentChapterIndex &&
      page.pageTurnIncomingPageIndex === safePageIndex && page.pageTurnIncomingText) {
      page.setCurrentPageText(page.pageTurnIncomingText);
      page.refreshReaderTextRender();
      return;
    }
    page.syncCurrentPageText();
    page.refreshReaderTextRender();
}

export function capturePageTurnCommitTarget(page: ReadBookPage, direction: number): PageTurnPreview | null {
    const localPageIndex = page.getLocalPageTurnTargetPageIndex(direction);
    if (localPageIndex >= 0) {
      return {
        text: page.getPageText(localPageIndex),
        secondaryText: page.getSecondaryPageText(localPageIndex),
        pageIndex: localPageIndex,
        chapterIndex: page.currentChapterIndex,
        pageStart: page.getPageStartOffset(localPageIndex),
        secondaryPageStart: page.isLandscapeDoublePageActive() ? page.getPageStartOffset(localPageIndex + 1) : -1,
        documentSource: page.pagedContentText
      };
    }
    if (page.pageTurnIncomingText) {
      return {
        text: page.pageTurnIncomingText,
        secondaryText: page.pageTurnIncomingSecondaryText,
        pageIndex: page.pageTurnIncomingPageIndex,
        chapterIndex: page.pageTurnIncomingChapterIndex,
        pageStart: page.pageTurnIncomingPageStart,
        secondaryPageStart: page.pageTurnIncomingSecondaryPageStart,
        documentSource: page.pageTurnIncomingDocumentSource
      };
    }
    return null;
}

export async function runPageTurnAnimation(page: ReadBookPage, direction: number, style: string, fromQueue: boolean = false, releaseVelocity: number = 0): Promise<void> {
    page.resetAutoPageTurnCountdown();
    if (!fromQueue && Date.now() < page.readerGestureTurnGuardUntil) {
      if (style === 'gesture' && page.readerGestureTurnAllowance > 0) {
        page.readerGestureTurnAllowance = 0;
      } else {
        return;
      }
    }
    if (page.isPageTurning) {
      // Touch.Up and PanGesture.onActionEnd can both report the same physical swipe.
      // commitReaderMove already de-duplicates them, so one subsequent physical swipe can safely be queued.
      // Keep a tiny bounded queue so rapid input flows into the next animation instead of being swallowed.
      // Two slots cover animation/chapter handoff jitter without letting a long input backlog run away.
      if (page.queuedPageTurnDirection === direction && page.queuedPageTurnStyle === style) {
        page.queuedPageTurnCount = Math.min(2, page.queuedPageTurnCount + 1);
        page.queuedPageTurnVelocity = Math.max(page.queuedPageTurnVelocity, releaseVelocity);
      } else {
        page.queuedPageTurnDirection = direction;
        page.queuedPageTurnStyle = style;
        page.queuedPageTurnCount = 1;
        page.queuedPageTurnVelocity = releaseVelocity;
      }
      return;
    }
    if (page.pendingRestorePageIndex >= 0) {
      // Loading the previous chapter can publish a small V2 window before its real tail is rebuilt. Keep input
      // queued until restorePendingPageIndex resolves; accepting a new turn here skips the still-hidden pages.
      if (page.queuedPageTurnDirection === direction && page.queuedPageTurnStyle === style) {
        page.queuedPageTurnCount = Math.min(2, page.queuedPageTurnCount + 1);
        page.queuedPageTurnVelocity = Math.max(page.queuedPageTurnVelocity, releaseVelocity);
      } else {
        page.queuedPageTurnDirection = direction;
        page.queuedPageTurnStyle = style;
        page.queuedPageTurnCount = 1;
        page.queuedPageTurnVelocity = releaseVelocity;
      }
      return;
    }
    if (!page.canTurnPage(direction)) {
      page.queuedPageTurnDirection = 0;
      page.queuedPageTurnStyle = '';
      page.queuedPageTurnCount = 0;
      page.queuedPageTurnVelocity = 0;
      page.resetSlidePageEffect();
      if (direction > 0 && page.chapters.length > 0 &&
        page.currentChapterIndex >= page.chapters.length - 1 &&
        page.getLocalPageTurnTargetPageIndex(1) < 0) {
        HdsFeedback.showToast('本书已阅读完成');
      }
      return;
    }
    const turnRequestStartedAt = Date.now();
    const resumeMirroredTtsAfterTurn = page.isMirroringActiveTtsForCurrentBook();
    const resumeTtsAfterTurn = page.ttsManualPageTurnResumePending ||
      page.isTtsSpeaking || page.ttsReader.isSpeaking();
    let ttsPrepareElapsed = 0;
    if (resumeMirroredTtsAfterTurn) {
      page.prepareMirroredTtsManualPageTurn();
    } else if (resumeTtsAfterTurn) {
      // Stop only synthesis/audio. Do not synchronously refresh AVSession metadata or clear the
      // highlighted subtree before the visual turn; both operations are much more expensive than
      // the animation itself. Rapid/queued turns share one deferred restart at the final page.
      page.prepareTtsForManualPageTurn();
      ttsPrepareElapsed = Math.max(0, Date.now() - turnRequestStartedAt);
    }
    const visualStartedAt = Date.now();
    // Text pagination runs on the UI thread. Reserve the whole visual turn plus a short handoff window so an
    // idle batch cannot slip between two queued curls and move the paragraph tree on their shared boundary.
    page.deferReaderPaginationForInteraction(700);
    page.isPageTurning = true;
    let turnCompleted = false;
    try {
      if (!page.isPageTurnAnimationEnabled()) {
        await page.runNoAnimationPageTurn(direction);
      } else if (style === 'slide' || style === 'gesture') {
        await page.runSlidePageTurn(direction, fromQueue && style === 'gesture', releaseVelocity);
      } else {
        await page.runTapPageTurn(direction);
      }
      turnCompleted = true;
    } finally {
      page.isPageTurning = false;
    }
    page.deferReaderPaginationForInteraction(220);
    if (resumeTtsAfterTurn) {
      console.info(`[TTS-Turn] visual ${turnCompleted ? 'completed' : 'cancelled'} in ` +
        `${Math.max(0, Date.now() - visualStartedAt)}ms,request=${Math.max(0, Date.now() - turnRequestStartedAt)}ms,` +
        `prepare=${ttsPrepareElapsed}ms,chapter=${page.currentChapterIndex},` +
        `page=${page.currentPageIndex},queued=${page.queuedPageTurnCount}`);
    }
    page.runQueuedPageTurnLater();
    if (resumeMirroredTtsAfterTurn) {
      page.scheduleMirroredTtsResumeAfterManualPageTurn();
    } else if (resumeTtsAfterTurn) {
      page.scheduleTtsResumeAfterManualPageTurn();
    }
}

export function prepareMirroredTtsManualPageTurn(page: ReadBookPage): void {
    if (page.mirroredTtsManualTurnTimerId >= 0) {
      clearTimeout(page.mirroredTtsManualTurnTimerId);
      page.mirroredTtsManualTurnTimerId = -1;
    }
    page.mirroredTtsManualTurnPending = true;
    page.mirroredTtsManualTurnSerial++;
    // Invalidate a focus sync that may currently be awaiting chapter content.
    page.mirroredTtsFocusSyncSerial++;
}

export function scheduleMirroredTtsResumeAfterManualPageTurn(page: ReadBookPage): void {
    if (!page.mirroredTtsManualTurnPending) return;
    if (page.mirroredTtsManualTurnTimerId >= 0) clearTimeout(page.mirroredTtsManualTurnTimerId);
    const serial = ++page.mirroredTtsManualTurnSerial;
    page.mirroredTtsManualTurnTimerId = setTimeout(() => {
      page.mirroredTtsManualTurnTimerId = -1;
      if (serial !== page.mirroredTtsManualTurnSerial || !page.mirroredTtsManualTurnPending) return;
      if (page.isPageTurning || page.queuedPageTurnCount > 0 || page.queuedPageTurnDirection !== 0 ||
        !page.isReaderPageTurnPositionReadyForTts()) {
        page.scheduleMirroredTtsResumeAfterManualPageTurn();
        return;
      }
      const chapterIndex = page.currentChapterIndex;
      const pageIndex = page.currentPageIndex;
      const pageStartOffset = page.getPageStartOffset(pageIndex);
      ReaderTtsFloatingSession.jumpToPosition(chapterIndex, pageIndex, pageStartOffset)
        .then((committed: boolean) => {
          if (serial !== page.mirroredTtsManualTurnSerial) return;
          // 提交成功后即视为本次手动翻页完成，但先进入“脱离跟随”冷却：冷却期间朗读进度
          // 继续前进也不会把视图拽回朗读句，让用户有时间翻看前后文。冷却结束后才平滑跟随。
          page.mirroredTtsManualTurnPending = false;
          if (!committed) {
            // 后台朗读宿主已不可用（positionAction 未注册）：保留镜像页手动翻页结果，
            // 不能按旧全局锚点回拖页面。
            console.warn('后台朗读宿主不可用，手动翻页位置未提交');
            return;
          }
          page.mirroredTtsFollowSuppressUntil = Date.now() + 4000;
          page.scheduleMirroredTtsResumeAfterSuppress();
        })
        .catch((error: Error) => {
          if (serial !== page.mirroredTtsManualTurnSerial) return;
          page.mirroredTtsManualTurnPending = false;
          // 提交失败时全局锚点仍是旧值，回拖会把刚翻好的页面拉回旧章节。
          console.warn('手动翻页提交后台朗读位置失败:', error);
        });
    }, 48);
}

export function cancelMirroredTtsManualPageTurn(page: ReadBookPage): void {
    page.mirroredTtsManualTurnSerial++;
    page.mirroredTtsManualTurnPending = false;
    page.mirroredTtsFollowSuppressUntil = 0;
    if (page.mirroredTtsManualTurnTimerId >= 0) {
      clearTimeout(page.mirroredTtsManualTurnTimerId);
      page.mirroredTtsManualTurnTimerId = -1;
    }
}

export function scheduleMirroredTtsResumeAfterSuppress(page: ReadBookPage): void {
    const serial = ++page.mirroredTtsManualTurnSerial;
    setTimeout(() => {
      if (serial !== page.mirroredTtsManualTurnSerial) return;
      if (page.mirroredTtsManualTurnPending || page.mirroredTtsFollowSuppressUntil > Date.now()) {
        page.scheduleMirroredTtsResumeAfterSuppress();
        return;
      }
      if (!page.isMirroringActiveTtsForCurrentBook()) return;
      page.syncMirroredTtsFocus()
        .then(() => page.scheduleCurrentTtsFocusRepublishAfterPageTurn())
        .catch((error: Error) => {
          console.warn('手动翻页冷却后重新同步后台朗读焦点失败:', error);
        });
    }, 250);
}

export function runQueuedPageTurnLater(page: ReadBookPage): void {
    const direction = page.queuedPageTurnDirection;
    const style = page.queuedPageTurnStyle;
    const releaseVelocity = page.queuedPageTurnVelocity;
    if (direction === 0 || page.queuedPageTurnCount <= 0) return;
    if (page.pendingRestorePageIndex >= 0) return;
    const generation = page.queuedPageTurnGeneration;
    page.queuedPageTurnCount--;
    if (page.queuedPageTurnCount <= 0) {
      page.queuedPageTurnDirection = 0;
      page.queuedPageTurnStyle = '';
      page.queuedPageTurnVelocity = 0;
    }
    setTimeout(() => {
      if (generation !== page.queuedPageTurnGeneration) return;
      page.runPageTurnAnimation(direction, style, true, releaseVelocity);
    }, 0);
}

export function clearQueuedReaderPageTurns(page: ReadBookPage): void {
    page.queuedPageTurnGeneration++;
    page.queuedPageTurnDirection = 0;
    page.queuedPageTurnStyle = '';
    page.queuedPageTurnCount = 0;
    page.queuedPageTurnVelocity = 0;
    page.pendingScrollPreviousChapterTurn = false;
    page.queuedPageTurnGeneration++;
}

export async function runNoAnimationPageTurn(page: ReadBookPage, direction: number): Promise<void> {
    page.readerTouchActive = false;
    page.readerPanActive = false;
    page.resetSlidePageState();
    const localPageIndex = page.getLocalPageTurnTargetPageIndex(direction);
    if (localPageIndex >= 0) {
      page.currentPageIndex = localPageIndex;
      const targetText = page.getPageText(localPageIndex);
      page.commitVisibleCurrentPageText(targetText);
      page.finishPageTurnAnimation(false);
      if (direction > 0 && page.contentPages.length - page.currentPageIndex <= 3) {
        page.preloadReaderContentLater();
        page.preloadNextChapterPaginationLater(0);
      } else if (direction < 0 && page.currentPageIndex <= 2) {
        page.preloadReaderContentLater();
      }
      page.scheduleReaderPagedProgressSave();
      page.commitCurrentPageTextLater(page.currentChapterIndex, page.currentPageIndex, targetText);
      return;
    }

    if (direction > 0) {
      if (page.isCurrentReaderPaginationComplete()) await page.loadNextChapter();
    } else {
      await page.loadPrevChapter(true);
      await page.waitForReaderChapterTailSettled();
    }
    const targetText = page.getCurrentPageText();
    page.finishPageTurnAnimation(false);
    page.commitVisibleCurrentPageText(targetText, true);
    page.commitCurrentPageTextLater(page.currentChapterIndex, page.currentPageIndex, targetText);
}

export function commitVisibleCurrentPageText(page: ReadBookPage, text: string = page.visibleCurrentPageText(), forceRender: boolean = false): void {
    const nextText = text || '';
    if (!forceRender && page.currentPageText === nextText && page.displayPageText === nextText &&
      page.displayPageChapterIndex === page.currentChapterIndex && page.displayPageIndex === page.currentPageIndex) {
      return;
    }
    page.readerTextSelectionSerial++;
    page.setReaderTextSelectionActive(false);
    page.clearReaderV2SelectionOverlay();
    page.readerSourceActionAreas.clear();
    page.readerSourceActionScrollOffsets.clear();
    page.clearPendingReaderSourceActionBounds();
    page.currentPageText = nextText;
    page.displayPageText = nextText;
    page.displayPageChapterIndex = page.currentChapterIndex;
    page.displayPageIndex = page.currentPageIndex;
    page.displayPageRenderKey++;
    page.forceCurrentReaderPageRender();
    // V2 keeps one native FrameNode across horizontal turns. Updating only the declarative page state can leave
    // that retained node painting the previous page until another frame happens to rebuild the surrounding tree,
    // which is especially visible at a cross-chapter handoff. Publish the exact settled page immediately.
    page.refreshCurrentReaderV2RetainedPages();
}

export function commitVisibleCurrentPageTextLater(page: ReadBookPage, chapterIndex: number, pageIndex: number): void {
    page.commitCurrentPageTextLater(chapterIndex, pageIndex, '');
}

export function commitCurrentPageTextLater(page: ReadBookPage, chapterIndex: number, pageIndex: number, expectedText: string): void {
    page.commitCurrentPageTextAfterDelay(chapterIndex, pageIndex, expectedText, 0);
}

export function commitCurrentPageTextAfterDelay(page: ReadBookPage, chapterIndex: number, pageIndex: number, expectedText: string, delayMs: number): void {
    setTimeout(() => {
      if (page.currentChapterIndex === chapterIndex && page.currentPageIndex === pageIndex) {
        const liveText = page.getCurrentPageText();
        const pageText = liveText || expectedText;
        page.commitVisibleCurrentPageText(pageText);
      }
    }, delayMs);
}

export async function runLegacyPageTurn(page: ReadBookPage, direction: number): Promise<void> {
    const targetPreview = page.capturePageTurnCommitTarget(direction);
    const subtleOffset = direction > 0 ? -10 : 10;
    page.pageSlideDirection = 0;
    page.pageTransitionOpacity = 1;
    page.pageTurnIncomingOpacity = 1;
    page.setPageTurnIncomingState(page.currentPageIndex, '', false);
    page.clearPageTurnPreviewState();
    animateTo({ duration: 120, curve: Curve.EaseOut }, () => {
      page.setPageSlideAxisOffset(subtleOffset);
    });
    await LeafFns.delay(130);
    await page.applyPageTurn(direction, targetPreview, false);
    await page.finishAnimatedPageTurn();
}

export async function runTapPageTurn(page: ReadBookPage, direction: number): Promise<void> {
    const distance = page.getPageTurnDistance();
    page.prepareSlidePageTurn(direction, 0);
    const targetPreview = page.capturePageTurnCommitTarget(direction);
    if (page.usesReaderPageCurlCanvas()) {
      await page.completeSimulationPageTurnMotion(direction);
    } else {
      const duration = 220;
      animateTo({ duration: duration, curve: page.pageTurnAnimationCurve() }, () => {
        page.setPageSlideAxisOffset(direction > 0 ? -distance : distance);
        page.pageTransitionOpacity = 1;
      });
      await LeafFns.delay(duration + 10);
    }
    await page.applyPageTurn(direction, targetPreview, false);
    await page.finishAnimatedPageTurn();
}

export async function runSlidePageTurn(page: ReadBookPage, direction: number, queuedGesture: boolean = false, releaseVelocity: number = 0): Promise<void> {
    const distance = page.getPageTurnDistance();
    page.prepareSlidePageTurn(direction, page.getPageSlideAxisOffset());
    const targetPreview = page.capturePageTurnCommitTarget(direction);
    const targetOffset = direction > 0 ? -distance : distance;
    const remaining = Math.abs(targetOffset - page.getPageSlideAxisOffset());
    if (page.usesReaderPageCurlCanvas()) {
      await page.completeSimulationPageTurnMotion(direction);
    } else {
      const duration = LeafFns.readerSlideCompletionDuration(remaining, distance, releaseVelocity, queuedGesture);
      animateTo({ duration: duration, curve: page.pageTurnAnimationCurve() }, () => {
        page.setPageSlideAxisOffset(targetOffset);
        page.pageTransitionOpacity = 1;
      });
      await LeafFns.delay(duration + 10);
    }
    await page.applyPageTurn(direction, targetPreview, false);
    await page.finishAnimatedPageTurn();
}

export async function finishAnimatedPageTurn(page: ReadBookPage): Promise<void> {
    const chapterIndex = page.currentChapterIndex;
    const pageIndex = page.currentPageIndex;
    const targetText = page.getCurrentPageText();
    // The incoming surface is already at the viewport origin. Commit and lay out the new current surface behind it,
    // then remove the incoming surface on the next frame. Removing it first caused an intermittent background flash.
    const keepIncomingVisible = page.pageSlideDirection !== 0 && !!page.pageTurnIncomingText;
    page.commitVisibleCurrentPageText(targetText);
    if (keepIncomingVisible) {
      // Cross-chapter pages may contain many bubble ImageSpans. Keep the already-complete preview on top
      // for a few frames while the new current render group is rasterized behind it.
      await LeafFns.delay(page.pageTurnCrossChapterHandoff ? 48 : 16);
      if (chapterIndex !== page.currentChapterIndex || pageIndex !== page.currentPageIndex) return;
    }
    page.finishPageTurnAnimation(false);
    page.commitCurrentPageTextLater(chapterIndex, pageIndex, targetText);
}

export function prepareIncomingPageTurn(page: ReadBookPage, direction: number): void {
    page.updatePageTurnIncomingForDirection(direction);
    page.pageTurnIncomingX = 0;
    page.pageTurnIncomingOpacity = 1;
}

export function prepareSlidePageTurn(page: ReadBookPage, direction: number, offset: number): void {
    const distance = page.getPageTurnDistance();
    const clampedOffset = Math.max(-distance, Math.min(distance, offset));
    page.pageSlideDirection = direction;
    page.setPageSlideAxisOffset(clampedOffset);
    page.pageTransitionOpacity = 1;
    page.pageTurnIncomingOpacity = 1;
    page.prepareIncomingPageTurn(direction);
    page.requestReaderPageCurlCapture();
}

export function finishPageTurnAnimation(page: ReadBookPage, releaseTurnLock: boolean = true): void {
    page.readerCurlStartRegion = ReaderEmulationFlipRegion.MIDDLE;
    page.resetReaderPageCurl();
    page.pageTransitionX = 0;
    page.pageTransitionOpacity = 1;
    page.pageSlideOffsetX = 0;
    page.pageSlideOffsetY = 0;
    page.pageSlideDirection = 0;
    page.pageTurnIncomingX = 0;
    page.pageTurnIncomingOpacity = 1;
    page.setPageTurnIncomingState(page.currentPageIndex, '', false);
    page.clearPageTurnPreviewState();
    if (releaseTurnLock) page.isPageTurning = false;
}

export function finishPageTurnAnimationLater(page: ReadBookPage): void {
    const serial = ++page.slideResetSerial;
    setTimeout(() => {
      if (serial === page.slideResetSerial) {
        page.finishPageTurnAnimation();
        page.refreshReaderTextRender();
      }
    }, 0);
}

export function setPageTurnIncomingState(page: ReadBookPage, pageIndex: number, text: string, animating: boolean = true, chapterIndex: number = page.currentChapterIndex, secondaryText: string = '', pageStart: number = -1, secondaryPageStart: number = -1, documentSource: string = ''): void {
    const safeText = text || '';
    const safeSecondaryText = secondaryText || '';
    const safeDocumentSource = documentSource || '';
    const nextAnimating = animating && !!safeText;
    if (page.pageTurnIncomingPageIndex !== pageIndex || page.pageTurnIncomingChapterIndex !== chapterIndex ||
      page.pageTurnIncomingText !== safeText || page.pageTurnIncomingSecondaryText !== safeSecondaryText ||
      page.pageTurnIncomingPageStart !== pageStart ||
      page.pageTurnIncomingSecondaryPageStart !== secondaryPageStart ||
      page.pageTurnIncomingDocumentSource !== safeDocumentSource || page.pageTurnAnimating !== nextAnimating) {
      page.pageTurnIncomingRenderVersion++;
    }
    page.pageTurnIncomingPageIndex = pageIndex;
    page.pageTurnIncomingChapterIndex = chapterIndex;
    page.pageTurnIncomingText = safeText;
    page.pageTurnIncomingSecondaryText = safeSecondaryText;
    page.pageTurnIncomingPageStart = pageStart;
    page.pageTurnIncomingSecondaryPageStart = secondaryPageStart;
    page.pageTurnIncomingDocumentSource = safeDocumentSource;
    page.pageTurnAnimating = nextAnimating;
}

export function getPageTurnTargetText(page: ReadBookPage, direction: number): string {
    const localPageIndex = page.getLocalPageTurnTargetPageIndex(direction);
    if (localPageIndex >= 0) {
      return page.getPageText(localPageIndex);
    }

    const targetChapterIndex = page.getAdjacentPageTurnChapterIndex(direction);
    if (targetChapterIndex >= 0) {
      const preview = page.buildCachedAdjacentPageTurnPreview(direction, targetChapterIndex);
      return preview.text || page.getPageTurnLoadingText(targetChapterIndex);
    }
    return '';
}

export function getPageTurnTargetPageIndex(page: ReadBookPage, direction: number = 0): number {
    const localPageIndex = page.getLocalPageTurnTargetPageIndex(direction);
    if (localPageIndex >= 0) {
      return localPageIndex;
    }
    return direction === 0 ? page.currentPageIndex : page.pageTurnIncomingPageIndex;
}

export function getLocalPageTurnTargetPageIndex(page: ReadBookPage, direction: number): number {
    const step = page.getReaderPageTurnStep();
    if (direction > 0 && page.currentPageIndex + step >= page.contentPages.length) {
      page.ensureCurrentReaderPaginationAhead(page.currentPageIndex + step + 2);
    }
    if (direction > 0 && page.currentPageIndex + step < page.contentPages.length) {
      return page.currentPageIndex + step;
    }
    if (direction < 0 && page.currentPageIndex > 0) {
      return Math.max(0, page.currentPageIndex - step);
    }
    return -1;
}

export function getAdjacentPageTurnChapterIndex(page: ReadBookPage, direction: number): number {
    if (direction > 0 && page.currentPageIndex + page.getReaderPageTurnStep() >= page.contentPages.length &&
      page.isCurrentReaderPaginationComplete() && page.currentChapterIndex < page.chapters.length - 1) {
      return page.currentChapterIndex + 1;
    }
    if (direction < 0 && page.currentPageIndex <= 0 && page.currentChapterIndex > 0) {
      return page.currentChapterIndex - 1;
    }
    return -1;
}

export function updatePageTurnIncomingForDirection(page: ReadBookPage, direction: number): void {
    const localPageIndex = page.getLocalPageTurnTargetPageIndex(direction);
    if (localPageIndex >= 0) {
      page.pageTurnCrossChapterHandoff = false;
      page.pageTurnPreviewKey = `local_${localPageIndex}`;
      page.setPageTurnIncomingState(localPageIndex, page.getPageText(localPageIndex), true,
        page.currentChapterIndex, page.getSecondaryPageText(localPageIndex),
        page.getPageStartOffset(localPageIndex),
        page.isLandscapeDoublePageActive() ? page.getPageStartOffset(localPageIndex + 1) : -1,
        page.pagedContentText);
      return;
    }

    const targetChapterIndex = page.getAdjacentPageTurnChapterIndex(direction);
    if (targetChapterIndex < 0) {
      page.pageTurnCrossChapterHandoff = false;
      page.setPageTurnIncomingState(page.currentPageIndex, '', false);
      return;
    }
    page.pageTurnCrossChapterHandoff = true;

    const key = page.buildPageTurnPreviewKey(direction, targetChapterIndex);
    if (page.pageTurnPreviewKey === key && page.pageTurnIncomingText &&
      page.pageTurnIncomingChapterIndex === targetChapterIndex) {
      return;
    }
    if (page.pageTurnPreviewKey !== key) {
      page.pageTurnPreviewKey = key;
    }

    const preview = page.buildCachedAdjacentPageTurnPreview(direction, targetChapterIndex);
    if (preview.text) {
      page.applyPageTurnPreview(preview);
      return;
    }

    page.setPageTurnIncomingState(0, page.getPageTurnLoadingText(targetChapterIndex), true, targetChapterIndex);
    page.loadAdjacentPageTurnPreview(direction, targetChapterIndex, key);
}

export function buildPageTurnPreviewKey(page: ReadBookPage, direction: number, chapterIndex: number): string {
    return `${direction}_${chapterIndex}_${page.pageViewWidth}_${page.pageViewHeight}_` +
      `${page.readerExtendToStatusBar}_${page.getReaderPageContentTopPadding()}_` +
      `${page.isLandscapeDoublePageActive()}_${page.readerTypographyCacheIdentity()}`;
}

export function buildCachedAdjacentPageTurnPreview(page: ReadBookPage, direction: number, chapterIndex: number): PageTurnPreview {
    if (!page.isCurrentReaderEngineBook()) {
      return { text: '', pageIndex: 0, chapterIndex: chapterIndex };
    }
    const body = ReadBookEngine.get().getCachedContent(chapterIndex);
    if (!body) {
      return { text: '', pageIndex: 0, chapterIndex: chapterIndex };
    }
    const prepared = page.getPreparedReaderContent(body, chapterIndex);
    if (!prepared && ReaderContentPreprocessor.hasActiveContentRules(page.readerReplaceRules)) {
      return { text: '', pageIndex: 0, chapterIndex: chapterIndex };
    }
    return page.buildAdjacentPageTurnPreview(direction, chapterIndex, prepared || body);
}

export function buildAdjacentPageTurnPreview(page: ReadBookPage, direction: number, chapterIndex: number, preparedBody: string): PageTurnPreview {
    const source = page.buildPagedSourceText(chapterIndex, preparedBody);
    const result = page.getOrCreateReaderPagination(chapterIndex, source);
    if (result.pages.length === 0) {
      return { text: '', pageIndex: 0, chapterIndex: chapterIndex };
    }
    // For a backward chapter turn, result.pages.length is authoritative only after pagination is
    // complete. A cooperative V2 session initially contains the first spread, so treating its last
    // currently-known page as the chapter tail makes simulation mode preview page one and then jump
    // to the real last page after commit.
    if (direction < 0 && !result.complete) {
      return { text: '', pageIndex: 0, chapterIndex: chapterIndex };
    }
    const pageIndex = direction > 0 ? 0 : page.normalizeReaderSpreadPageIndex(result.pages.length - 1);
    return {
      text: result.pages[pageIndex],
      secondaryText: page.isLandscapeDoublePageActive() ? (result.pages[pageIndex + 1] || '') : '',
      pageIndex: pageIndex,
      chapterIndex: chapterIndex,
      pageStart: result.starts[pageIndex] ?? 0,
      secondaryPageStart: page.isLandscapeDoublePageActive() ? (result.starts[pageIndex + 1] ?? -1) : -1,
      documentSource: result.source
    };
}

export function getPageTurnLoadingText(page: ReadBookPage, chapterIndex: number): string {
    const title = page.getChapterTitle(chapterIndex).trim();
    return title ? `${title}\n\n正在加载章节内容...` : '正在加载章节内容...';
}

export function applyPageTurnPreview(page: ReadBookPage, preview: PageTurnPreview): void {
    page.setPageTurnIncomingState(preview.pageIndex, preview.text, true, preview.chapterIndex,
      preview.secondaryText || '', preview.pageStart ?? -1, preview.secondaryPageStart ?? -1,
      preview.documentSource || '');
    page.pageTurnIncomingOpacity = 1;
    page.requestReaderPageCurlCapture();
}

export function loadAdjacentPageTurnPreview(page: ReadBookPage, direction: number, chapterIndex: number, key: string): void {
    if (page.pageTurnPreviewLoadingKey === key) {
      return;
    }
    const sessionBookUrl = page.book?.bookUrl || page.bookUrl;
    if (!page.isCurrentReaderEngineBook(sessionBookUrl)) return;
    page.pageTurnPreviewLoadingKey = key;
    ReadBookEngine.get().peekContent(chapterIndex)
      .then(async (body: string): Promise<void> => {
        if (!page.isCurrentReaderEngineBook(sessionBookUrl) || page.pageTurnPreviewKey !== key ||
          page.pageSlideDirection !== direction) {
          return;
        }
        const prepared = await page.prepareReaderContentRules(body, chapterIndex);
        if (!page.isCurrentReaderEngineBook(sessionBookUrl) || page.pageTurnPreviewKey !== key ||
          page.pageSlideDirection !== direction) return;
        const preview = page.buildAdjacentPageTurnPreview(direction, chapterIndex, prepared);
        if (preview.text) {
          page.applyPageTurnPreview(preview);
        }
      })
      .catch((err: Error) => {
        console.error('加载翻页预览失败:', err);
      })
      .finally(() => {
        if (page.pageTurnPreviewLoadingKey === key) {
          page.pageTurnPreviewLoadingKey = '';
        }
      });
}

export function isCurrentReaderEngineBook(page: ReadBookPage, expectedBookUrl: string = page.book?.bookUrl || page.bookUrl): boolean {
    return !!expectedBookUrl && ReadBookEngine.get().book?.bookUrl === expectedBookUrl;
}

export function updateSlidePageEffect(page: ReadBookPage, offset: number): void {
    if (page.isPageTurning) {
      return;
    }
    if (!page.isPageTurnAnimationEnabled()) {
      page.resetSlidePageState();
      return;
    }
    const distance = page.getPageTurnDistance();
    const clamped = Math.max(-distance, Math.min(distance, offset));
    if (Math.abs(clamped) < 1) {
      page.resetSlidePageState();
      return;
    }
    const direction = clamped < 0 ? 1 : -1;
    if (!page.canTurnPage(direction)) {
      page.resetSlidePageState();
      return;
    }
    page.pageSlideDirection = direction;
    page.setPageSlideAxisOffset(clamped);
    page.pageTransitionOpacity = 1;
    page.pageTurnIncomingOpacity = 1;
    page.updatePageTurnIncomingForDirection(direction);
    page.requestReaderPageCurlCapture();
}

export function updateLegacySlidePageEffect(page: ReadBookPage, offset: number): void {
    const distance = page.getPageTurnDistance();
    const clamped = Math.max(-distance, Math.min(distance, offset));
    if (Math.abs(clamped) < 1) {
      page.resetSlidePageState();
      return;
    }
    const direction = clamped < 0 ? 1 : -1;
    if (!page.canTurnPage(direction)) {
      page.resetSlidePageState();
      return;
    }
    const subtleOffset = Math.min(10, Math.max(2, Math.abs(clamped) * 0.08));
    page.pageSlideDirection = 0;
    page.setPageSlideAxisOffset(direction > 0 ? -subtleOffset : subtleOffset);
    page.pageTransitionOpacity = 1;
    page.pageTurnIncomingOpacity = 1;
    page.setPageTurnIncomingState(page.currentPageIndex, '', false);
    page.clearPageTurnPreviewState();
}

export function rollbackSlidePageEffect(page: ReadBookPage): void {
    const offset = Math.abs(page.getPageSlideAxisOffset());
    if (offset < 0.5) {
      page.resetSlidePageState();
      return;
    }
    const distance = page.getPageTurnDistance();
    const duration = Math.max(80, Math.min(180, Math.round(180 * offset / distance)));
    const serial = ++page.slideResetSerial;
    if (page.usesReaderPageCurlCanvas()) {
      page.rollbackReaderPageCurl(duration, serial).catch((error: Error) => {
        console.warn('回弹仿真翻页失败:', error);
        if (page.slideResetSerial === serial && !page.isPageTurning) page.resetSlidePageState();
      });
      return;
    }
    animateTo({ duration: duration, curve: Curve.EaseOut }, () => {
      page.setPageSlideAxisOffset(0);
      page.pageTransitionOpacity = 1;
      page.pageTurnIncomingOpacity = 1;
    });
    setTimeout(() => {
      if (page.slideResetSerial === serial && !page.isPageTurning) {
        page.resetSlidePageState();
      }
    }, duration + 20);
}

export async function rollbackReaderPageCurl(page: ReadBookPage, duration: number, serial: number): Promise<void> {
    const ready = await page.ensureReaderPageCurlReady();
    if (!ready) {
      if (page.slideResetSerial === serial && !page.isPageTurning) page.resetSlidePageState();
      return;
    }
    await page.animateReaderPageCurlOffset(0, duration);
    if (page.slideResetSerial === serial && !page.isPageTurning) page.resetSlidePageState();
}

export function resetSlidePageEffect(page: ReadBookPage): void {
    page.resetSlidePageState();
}

export function getVisiblePageTurnIncomingText(page: ReadBookPage): string {
    if (!page.shouldRenderSlidingPageTurn()) {
      return '';
    }
    if (page.pageTurnIncomingText) {
      return page.pageTurnIncomingText;
    }
    if (page.pageSlideDirection === 0) {
      return '';
    }
    return page.getPageTurnTargetText(page.pageSlideDirection);
}

export function getVisiblePageTurnIncomingOpacity(page: ReadBookPage): number {
    if (!page.shouldRenderSlidingPageTurn()) {
      return 0;
    }
    const type = page.effectivePageTurnAnimationType();
    if (type === ReaderSettingsStore.PAGE_TURN_ANIMATION_FADE) {
      return Math.max(0, Math.min(1, page.pageTurnIncomingOpacity * page.getPageTurnProgress()));
    }
    if (type === ReaderSettingsStore.PAGE_TURN_ANIMATION_STACK) {
      return page.pageTurnIncomingOpacity;
    }
    return page.pageTurnIncomingOpacity;
}

export function getPageTurnWidth(page: ReadBookPage): number {
    return Math.max(1, page.pageViewWidth > 0 ? page.pageViewWidth : 360);
}

export function getPageTurnHeight(page: ReadBookPage): number {
    const contentHeight = page.pageViewHeight > 0 ? page.pageViewHeight : 640;
    // The declarative page-turn surface expands through the bottom system safe area. pageViewHeight is measured
    // before that expansion, so omitting the navigation inset scales a full-height snapshot into a shorter canvas
    // and makes the entire page visibly squeeze upward while it is turning.
    return Math.max(1, contentHeight + page.getReaderPageContentTopPadding() + Math.max(0, page.navBarHeight));
}

export function isVerticalPageTurnAnimation(page: ReadBookPage): boolean {
    return page.readerEffectivePageTurnMode() === 0 && !page.usesReaderPageCurlCanvas();
}

export function effectivePageTurnAnimationType(page: ReadBookPage): number {
    return page.normalizePageTurnAnimationType(page.readerPageTurnAnimationType);
}

export function isStackPageTurnAnimation(page: ReadBookPage): boolean {
    return page.effectivePageTurnAnimationType() === ReaderSettingsStore.PAGE_TURN_ANIMATION_STACK;
}

export function isSimulationPageTurnAnimation(page: ReadBookPage): boolean {
    return page.effectivePageTurnAnimationType() === ReaderSettingsStore.PAGE_TURN_ANIMATION_SIMULATION;
}

export function is3DPageTurnAnimation(page: ReadBookPage): boolean {
    return page.effectivePageTurnAnimationType() === ReaderSettingsStore.PAGE_TURN_ANIMATION_3D;
}

export function usesReaderPageCurlCanvas(page: ReadBookPage): boolean {
    return page.isSimulationPageTurnAnimation() || page.is3DPageTurnAnimation();
}

export function readerFlapPaperColor(page: ReadBookPage): string {
    const color = page.getBackgroundColor();
    if (!color) {
      return '#FFFFFF';
    }
    return color.length >= 9 && color.toUpperCase().endsWith('00') ? '#FFFFFF' : color;
}

export function captureReaderCurlStartRegion(page: ReadBookPage, event: GestureEvent): void {
    page.readerCurlStartRegion = ReaderEmulationFlipRegion.MIDDLE;
    if (!page.is3DPageTurnAnimation() || !event || !event.fingerList || event.fingerList.length === 0) {
      return;
    }
    const localY = event.fingerList[0].localY;
    const height = page.getPageTurnHeight();
    // 中部起手走竖直折线，上/下部起手走折角。
    if (localY < height / 3) {
      page.readerCurlStartRegion = ReaderEmulationFlipRegion.TOP;
    } else if (localY > height * 2 / 3) {
      page.readerCurlStartRegion = ReaderEmulationFlipRegion.BOTTOM;
    } else {
      page.readerCurlStartRegion = ReaderEmulationFlipRegion.MIDDLE;
    }
}

export function pageTurnAnimationCurve(page: ReadBookPage): Curve {
    return page.isSimulationPageTurnAnimation() || page.is3DPageTurnAnimation() ?
      Curve.EaseInOut : Curve.EaseOut;
}

export function getReaderPageCurlCanvasHeight(page: ReadBookPage): number {
    // Prefer the actual captured component height. It stays correct for gesture-navigation variants, split-screen
    // windows and devices whose bottom avoid area differs from the globally cached navigation height.
    return page.readerPageCurlSnapshotHeight > 0 ? page.readerPageCurlSnapshotHeight : page.getPageTurnHeight();
}

export function readerPageCurlKey(page: ReadBookPage): string {
    return `${page.pageSlideDirection}_${page.currentChapterIndex}_${page.currentPageIndex}_` +
      `${page.pageRenderVersion}_${page.ttsHighlightRenderVersion}_${page.pageTurnIncomingChapterIndex}_` +
      `${page.pageTurnIncomingPageIndex}_${page.pageTurnIncomingRenderVersion}_` +
      `${page.isLandscapeDoublePageActive() ? 1 : 0}_${page.getPageTurnWidth()}_${page.getPageTurnHeight()}_` +
      `${page.getReaderPageContentTopPadding()}_${page.navBarHeight}_${page.readerExtendToStatusBar ? 1 : 0}`;
}

export function drawReaderPageCurl(page: ReadBookPage): void {
    if (!page.readerPageCurlCanvasReady || !page.readerPageCurlSnapshotReady ||
      !page.readerPageCurlFront || page.pageSlideDirection === 0) {
      return;
    }
    if (page.is3DPageTurnAnimation()) {
      // 3D 仿真只卷曲当前页，目标页由底层声明式页面呈现，因此不需要背页位图。
      page.readerEmulationFlipPainter.draw(page.readerPageCurlContext, page.readerPageCurlFront,
        page.readerPageCurlBack, page.getPageTurnWidth(), page.getReaderPageCurlCanvasHeight(),
        page.getPageTurnProgress(), page.pageSlideDirection, page.readerCurlStartRegion,
        page.isLandscapeDoublePageActive(), page.getReaderPageColumnWidth(),
        page.getReaderDoublePageRightOrigin(), 1 / page.getUIContext().vp2px(1),
        page.readerFlapPaperColor());
      return;
    }
    if (!page.readerPageCurlBack) {
      return;
    }
    page.readerPageCurlPainter.draw(page.readerPageCurlContext, page.readerPageCurlFront,
      page.readerPageCurlBack, page.getPageTurnWidth(), page.getReaderPageCurlCanvasHeight(),
      page.getPageTurnProgress(), page.pageSlideDirection, page.isLandscapeDoublePageActive(),
      page.isReaderThemeDark(), page.getReaderPageColumnWidth(), page.getReaderDoublePageRightOrigin());
}

export function requestReaderPageCurlCapture(page: ReadBookPage): void {
    if (!page.readerPageVisible || !page.usesReaderPageCurlCanvas() ||
      page.pageSlideDirection === 0 || !page.shouldRenderSlidingPageTurn()) {
      return;
    }
    const key = page.readerPageCurlKey();
    if (key === page.readerPageCurlCaptureKey &&
      (page.readerPageCurlSnapshotReady || page.readerPageCurlCapturePending)) {
      // The gesture/animator already paints after publishing the latest offset. Repainting here
      // made every double-page drag update submit the same expensive textured mesh twice.
      return;
    }
    page.readerPageCurlCaptureKey = key;
    page.readerPageCurlCapturePending = true;
    page.readerPageCurlSnapshotReady = false;
    const serial = ++page.readerPageCurlCaptureSerial;
    setTimeout(() => {
      page.captureReaderPageCurlSnapshots(serial, key).catch((error: Error) => {
        if (serial === page.readerPageCurlCaptureSerial) {
          page.readerPageCurlCapturePending = false;
        }
        console.warn('生成仿真翻页快照失败:', error);
      });
    }, 0);
}

export async function captureReaderPageCurlSnapshots(page: ReadBookPage, serial: number, key: string): Promise<void> {
    for (let attempt = 0; attempt < 30 && page.pageTurnPreviewLoadingKey; attempt++) {
      if (serial !== page.readerPageCurlCaptureSerial || key !== page.readerPageCurlCaptureKey) return;
      await LeafFns.delay(20);
    }
    // Let the incoming cross-chapter preview and its ImageSpans finish one layout pass before rasterizing.
    await LeafFns.delay(page.pageTurnCrossChapterHandoff ? 32 : 0);
    // The retained V2 current component keeps a stable id across pages. Unlike the old temporary capture node,
    // that id already exists in the same task that commits a queued turn, so snapshot.get() could succeed before
    // its controller has painted the newly-settled page. Wait one render frame and capture the page the user
    // actually sees, not the previous texture still owned by RenderService.
    await LeafFns.delay(16);
    if (serial !== page.readerPageCurlCaptureSerial || key !== page.readerPageCurlCaptureKey ||
      page.pageSlideDirection === 0) return;
    const snapshot = page.getUIContext().getComponentSnapshot();
    const suffix = page.isLandscapeDoublePageActive() ? 'double' : 'single';
    let front: image.PixelMap | null = null;
    let back: image.PixelMap | null = null;
    // A tap can request the snapshot in the same task that publishes the simulation subtree.
    // The component IDs become available on a following render frame, so retry transient 100001
    // failures instead of letting tap turns miss the curl while drag turns happen to work.
    for (let attempt = 0; attempt < 24; attempt++) {
      try {
        // The paper front must be the exact settled component already visible to the user. Rebuilding a second
        // native Paragraph solely for capture can resolve to a neighbouring physical-pixel origin and produces
        // a small but repeatable vertical jump at the start of every rapid turn.
        front = await snapshot.get(page.currentReaderSnapshotComponentId(), {
          scale: READER_PAGE_CURL_SNAPSHOT_SCALE,
          waitUntilRenderFinished: false
        });
        back = await snapshot.get(`reader_page_curl_back_${suffix}`, {
          scale: READER_PAGE_CURL_SNAPSHOT_SCALE,
          waitUntilRenderFinished: false
        });
        if (page.isLandscapeDoublePageActive()) {
          await page.cropReaderPageCurlFrontToTurningLeaf(front);
        }
        break;
      } catch (error) {
        if (front) front.release().catch(() => {});
        if (back) back.release().catch(() => {});
        front = null;
        back = null;
        if (serial !== page.readerPageCurlCaptureSerial || key !== page.readerPageCurlCaptureKey ||
          page.pageSlideDirection === 0) return;
        if (attempt >= 23) throw new Error(`获取仿真翻页快照失败: ${error}`);
        await LeafFns.delay(16);
      }
    }
    if (!front || !back) return;
    let snapshotHeight = page.getPageTurnHeight();
    try {
      const frontInfo = await front.getImageInfo();
      snapshotHeight = px2vp(Math.max(1,
        frontInfo.size.height / READER_PAGE_CURL_SNAPSHOT_SCALE));
    } catch (error) {
      console.warn('读取仿真翻页快照尺寸失败，使用页面布局高度:', error);
    }
    if (serial !== page.readerPageCurlCaptureSerial || key !== page.readerPageCurlCaptureKey ||
      page.pageSlideDirection === 0) {
      front.release().catch(() => {});
      back.release().catch(() => {});
      return;
    }
    const oldFront = page.readerPageCurlFront;
    const oldBack = page.readerPageCurlBack;
    page.readerPageCurlFront = front;
    page.readerPageCurlBack = back;
    page.readerPageCurlSnapshotHeight = snapshotHeight;
    page.readerPageCurlCapturePending = false;
    page.readerPageCurlSnapshotReady = true;
    page.drawReaderPageCurl();
    // RenderService can still own the previous texture for the frame currently being submitted.
    // Releasing it in the same task intermittently invalidates that frame during rapid queued turns.
    setTimeout(() => {
      if (oldFront) oldFront.release().catch(() => {});
      if (oldBack) oldBack.release().catch(() => {});
    }, 48);
}

export async function cropReaderPageCurlFrontToTurningLeaf(page: ReadBookPage, front: image.PixelMap): Promise<void> {
    const info = await front.getImageInfo();
    const fullWidthPx = Math.max(1, info.size.width);
    const fullHeightPx = Math.max(1, info.size.height);
    const viewportWidth = Math.max(1, page.getPageTurnWidth());
    const leafWidth = Math.max(1, page.getReaderPageColumnWidth());
    const origin = page.pageSlideDirection > 0 ? page.getReaderDoublePageRightOrigin() : 0;
    const cropX = Math.max(0, Math.min(fullWidthPx - 1,
      Math.round(fullWidthPx * origin / viewportWidth)));
    const requestedWidth = Math.max(1, Math.round(fullWidthPx * leafWidth / viewportWidth));
    const cropWidth = Math.max(1, Math.min(requestedWidth, fullWidthPx - cropX));
    await front.crop({
      x: cropX,
      y: 0,
      size: {
        width: cropWidth,
        height: fullHeightPx
      }
    });
}

export async function ensureReaderPageCurlReady(page: ReadBookPage): Promise<boolean> {
    if (!page.usesReaderPageCurlCanvas() || page.pageSlideDirection === 0) return false;
    page.requestReaderPageCurlCapture();
    let key = page.readerPageCurlCaptureKey;
    let keyChangeCount = 0;
    for (let attempt = 0; attempt < 120; attempt++) {
      if (page.pageSlideDirection === 0) return false;
      const latestKey = page.readerPageCurlCaptureKey;
      if (latestKey !== key) {
        // An uncached adjacent chapter first publishes a loading leaf and then replaces it with the prepared
        // destination page. That replacement deliberately starts a new capture with a new render-version key;
        // follow it instead of treating the valid cross-chapter handoff as a snapshot failure.
        key = latestKey;
        keyChangeCount++;
        if (keyChangeCount > 4) return false;
        attempt = 0;
      }
      const crossChapterPreviewLoading = page.pageTurnCrossChapterHandoff && !!page.pageTurnPreviewLoadingKey;
      const crossChapterPreviewReady = !page.pageTurnCrossChapterHandoff ||
        !!page.pageTurnIncomingDocumentSource;
      if (page.readerPageCurlSnapshotReady && key === page.readerPageCurlCaptureKey &&
        crossChapterPreviewReady) return true;
      // captureReaderPageCurlSnapshots clears the pending flag when the platform snapshot request fails.
      // Do not keep the turn locked for the remainder of the old 1.9s polling window after a terminal failure.
      // While an adjacent preview is still loading, a completed placeholder capture is not a terminal result:
      // applyPageTurnPreview will publish the real leaf and start the authoritative replacement capture.
      if (!page.readerPageCurlCapturePending && !crossChapterPreviewLoading) return false;
      await LeafFns.delay(16);
    }
    return false;
}

export async function completeSimulationPageTurnMotion(page: ReadBookPage, direction: number): Promise<void> {
    // 后台/锁屏连续朗读时页面不可见：仿真快照既无可见意义也常拿不到（RenderService 已暂停），
    // 原实现仍空转 ensureReaderPageCurlReady 最长约 1.9s，拖慢后台每次自动翻页；回前台时
    // 积压成快速追赶的连续翻页，表现为高亮跳变与翻页卡顿。不可见时直接跳过仿真动画，
    // 由调用方立即提交目标页。
    if (!page.readerPageVisible) {
      return;
    }
    const ready = await page.ensureReaderPageCurlReady();
    if (!ready) {
      // Snapshot services can be temporarily unavailable after foregrounding or during a rapid turn chain.
      // Preserve a visible, bounded transition instead of committing an apparently animation-less page.
      console.warn('仿真翻页快照未就绪，使用轻量过渡完成本次翻页');
      const fallbackOffset = direction > 0 ? -18 : 18;
      animateTo({ duration: 130, curve: Curve.EaseOut }, () => {
        page.pageTransitionX = fallbackOffset;
        page.pageTransitionOpacity = 0.18;
      });
      await LeafFns.delay(140);
      return;
    }
    const distance = page.getPageTurnDistance();
    const targetOffset = direction > 0 ? -distance : distance;
    const remaining = Math.abs(targetOffset - page.getPageSlideAxisOffset());
    // A long symmetric EaseInOut made the last part of the sheet appear to stop before the
    // incoming page was committed. Finish with a shorter, momentum-preserving edge motion.
    const duration = Math.max(110, Math.min(340, Math.round(340 * remaining / distance)));
    await page.animateReaderPageCurlOffset(targetOffset, duration, true);
}

export function resetReaderPageCurl(page: ReadBookPage): void {
    page.readerPageCurlCaptureSerial++;
    page.readerPageCurlCapturePending = false;
    page.readerPageCurlCaptureKey = '';
    page.readerPageCurlSnapshotReady = false;
    page.readerPageCurlAnimationSerial++;
    const activeAnimator = page.readerPageCurlAnimator;
    page.readerPageCurlAnimator = null;
    if (activeAnimator) activeAnimator.cancel();
    page.readerPageCurlOffset = 0;
    page.readerPageCurlSnapshotHeight = 0;
    const front = page.readerPageCurlFront;
    const back = page.readerPageCurlBack;
    page.readerPageCurlFront = null;
    page.readerPageCurlBack = null;
    // Keep the last raster alive for a few frames after hiding the curl Canvas. The RS submission is
    // asynchronous; a zero-delay release races its final draw and can expose a transient unformatted page.
    setTimeout(() => {
      if (front) front.release().catch(() => {});
      if (back) back.release().catch(() => {});
    }, 48);
}

export function animateReaderPageCurlOffset(page: ReadBookPage, targetOffset: number, duration: number, completingPageTurn: boolean = false): Promise<void> {
    const activeAnimator = page.readerPageCurlAnimator;
    page.readerPageCurlAnimator = null;
    if (activeAnimator) activeAnimator.cancel();
    const serial = ++page.readerPageCurlAnimationSerial;
    const startOffset = page.getPageSlideAxisOffset();
    return new Promise<void>((resolve) => {
      let settled = false;
      let watchdogId = -1;
      const settle = (): void => {
        if (settled) return;
        settled = true;
        if (watchdogId >= 0) clearTimeout(watchdogId);
        resolve();
      };
      let pageCurlAnimator: AnimatorResult;
      try {
        pageCurlAnimator = Animator.create({
          duration: Math.max(1, duration),
          easing: completingPageTurn ? 'cubic-bezier(0.18, 0.68, 0.32, 0.98)' :
            'cubic-bezier(0.65, 0, 0.35, 1)',
          delay: 0,
          fill: 'forwards',
          direction: 'normal',
          iterations: 1,
          begin: startOffset,
          end: targetOffset
        });
      } catch (error) {
        console.warn('创建仿真翻页动画失败，提交目标帧:', error);
        page.setPageSlideAxisOffset(targetOffset);
        settle();
        return;
      }
      page.readerPageCurlAnimator = pageCurlAnimator;
      pageCurlAnimator.onFrame = (value: number): void => {
        if (serial !== page.readerPageCurlAnimationSerial) return;
        page.setPageSlideAxisOffset(value);
      };
      pageCurlAnimator.onFinish = (): void => {
        if (serial === page.readerPageCurlAnimationSerial) {
          page.setPageSlideAxisOffset(targetOffset);
          page.readerPageCurlAnimator = null;
        }
        settle();
      };
      pageCurlAnimator.onCancel = (): void => {
        if (page.readerPageCurlAnimator === pageCurlAnimator) page.readerPageCurlAnimator = null;
        settle();
      };
      // A few platform versions can lose Animator.onFinish after the window is resumed. Do not leave page-turn
      // input locked indefinitely; commit the exact target frame shortly after the declared duration.
      watchdogId = setTimeout(() => {
        if (serial === page.readerPageCurlAnimationSerial) {
          page.setPageSlideAxisOffset(targetOffset);
          if (page.readerPageCurlAnimator === pageCurlAnimator) page.readerPageCurlAnimator = null;
        }
        settle();
      }, Math.max(1, duration) + 96);
      try {
        pageCurlAnimator.play();
      } catch (error) {
        console.warn('启动仿真翻页动画失败，提交目标帧:', error);
        page.setPageSlideAxisOffset(targetOffset);
        settle();
      }
    });
}

export function getSimulationSpineColor(page: ReadBookPage): string {
    return page.isReaderThemeDark() ? '#66000000' : '#36000000';
}

export function getPageTurnDistance(page: ReadBookPage): number {
    return page.isVerticalPageTurnAnimation() ? page.getPageTurnHeight() : page.getPageTurnWidth();
}

export function getPageSlideAxisOffset(page: ReadBookPage): number {
    if (page.usesReaderPageCurlCanvas()) return page.readerPageCurlOffset;
    return page.isVerticalPageTurnAnimation() ? page.pageSlideOffsetY : page.pageSlideOffsetX;
}

export function setPageSlideAxisOffset(page: ReadBookPage, offset: number): void {
    if (page.usesReaderPageCurlCanvas()) {
      page.readerPageCurlOffset = offset;
      page.drawReaderPageCurl();
      return;
    }
    if (page.isVerticalPageTurnAnimation()) {
      page.pageSlideOffsetX = 0;
      page.pageSlideOffsetY = offset;
      page.drawReaderPageCurl();
      return;
    }
    page.pageSlideOffsetX = offset;
    page.pageSlideOffsetY = 0;
    page.drawReaderPageCurl();
}

export function shouldRenderSlidingPageTurn(page: ReadBookPage): boolean {
    return page.isPageTurnAnimationEnabled() && page.pageSlideDirection !== 0 &&
      (page.pageTurnAnimating || page.canTurnPage(page.pageSlideDirection));
}

export function getPageTurnProgress(page: ReadBookPage): number {
    const distance = page.getPageTurnDistance();
    if (distance <= 0) {
      return 0;
    }
    return Math.max(0, Math.min(1, Math.abs(page.getPageSlideAxisOffset()) / distance));
}

export function getCurrentPageTurnX(page: ReadBookPage): number {
    if (!page.shouldRenderSlidingPageTurn()) {
      return page.pageTransitionX + page.pageSlideOffsetX;
    }
    if (page.isVerticalPageTurnAnimation()) {
      return 0;
    }
    const type = page.effectivePageTurnAnimationType();
    // 淡入原地淡出、叠页与 3D 仿真都由各自的动画层接管视觉位移，当前页不再做水平平移。
    if (type === ReaderSettingsStore.PAGE_TURN_ANIMATION_FADE ||
      type === ReaderSettingsStore.PAGE_TURN_ANIMATION_STACK ||
      type === ReaderSettingsStore.PAGE_TURN_ANIMATION_3D) {
      return 0;
    }
    return page.pageTransitionX + page.pageSlideOffsetX;
}

export function getCurrentPageTurnY(page: ReadBookPage): number {
    if (!page.shouldRenderSlidingPageTurn()) {
      return page.pageSlideOffsetY;
    }
    if (!page.isVerticalPageTurnAnimation()) {
      return 0;
    }
    const type = page.effectivePageTurnAnimationType();
    if (type === ReaderSettingsStore.PAGE_TURN_ANIMATION_FADE) {
      return 0;
    }
    if (type === ReaderSettingsStore.PAGE_TURN_ANIMATION_STACK) {
      return 0;
    }
    return page.pageSlideOffsetY;
}

export function getCurrentPageTurnOpacity(page: ReadBookPage): number {
    if (!page.shouldRenderSlidingPageTurn()) {
      return page.pageTransitionOpacity;
    }
    const type = page.effectivePageTurnAnimationType();
    if (type === ReaderSettingsStore.PAGE_TURN_ANIMATION_FADE) {
      return Math.max(0.12, 1 - page.getPageTurnProgress());
    }
    if (type === ReaderSettingsStore.PAGE_TURN_ANIMATION_STACK) {
      return 1;
    }
    if (page.usesReaderPageCurlCanvas() && !page.isLandscapeDoublePageActive()) {
      // 卷曲类型由画布上的快照绘制纸张,实时页面必须让位,否则会与快照叠出重影(官方示例同样会隐藏当前页)。
      // 快照就绪前保持可见,避免空白帧;双页时左列仍需实时页面,故不在此隐藏。
      return page.readerPageCurlSnapshotReady ? 0 : page.pageTransitionOpacity;
    }
    return page.pageTransitionOpacity;
}

export function getSlideIncomingX(page: ReadBookPage, direction: number, offsetX: number, width: number = page.getPageTurnWidth()): number {
    const type = page.effectivePageTurnAnimationType();
    // 仿真与 3D 仿真都让目标页固定铺满窗口，由卷曲画布或 3D 翻转层负责过渡。
    if (type === ReaderSettingsStore.PAGE_TURN_ANIMATION_SIMULATION ||
      type === ReaderSettingsStore.PAGE_TURN_ANIMATION_FADE ||
      type === ReaderSettingsStore.PAGE_TURN_ANIMATION_3D) {
      return 0;
    }
    if (type === ReaderSettingsStore.PAGE_TURN_ANIMATION_STACK) {
      return direction > 0 ? width + offsetX : offsetX - width;
    }
    return direction > 0 ? width + offsetX : offsetX - width;
}

export function getIncomingSlideX(page: ReadBookPage): number {
    if (page.pageSlideDirection === 0 || page.isVerticalPageTurnAnimation()) {
      return 0;
    }
    return page.getSlideIncomingX(page.pageSlideDirection, page.pageSlideOffsetX);
}

export function getSlideIncomingY(page: ReadBookPage, direction: number, offsetY: number, height: number = page.getPageTurnHeight()): number {
    const type = page.effectivePageTurnAnimationType();
    if (type === ReaderSettingsStore.PAGE_TURN_ANIMATION_SIMULATION ||
      type === ReaderSettingsStore.PAGE_TURN_ANIMATION_FADE ||
      type === ReaderSettingsStore.PAGE_TURN_ANIMATION_3D) {
      return 0;
    }
    if (type === ReaderSettingsStore.PAGE_TURN_ANIMATION_STACK) {
      return direction > 0 ? height + offsetY : offsetY - height;
    }
    return direction > 0 ? height + offsetY : offsetY - height;
}

export function getIncomingSlideY(page: ReadBookPage): number {
    if (page.pageSlideDirection === 0 || !page.isVerticalPageTurnAnimation()) {
      return 0;
    }
    return page.getSlideIncomingY(page.pageSlideDirection, page.pageSlideOffsetY);
}

export function resetSlidePageState(page: ReadBookPage): void {
    page.resetReaderPageCurl();
    page.pageSlideOffsetX = 0;
    page.pageSlideOffsetY = 0;
    page.pageSlideDirection = 0;
    page.pageTransitionOpacity = 1;
    page.pageTurnIncomingX = 0;
    page.pageTurnIncomingOpacity = 1;
    page.setPageTurnIncomingState(page.currentPageIndex, '', false);
    page.clearPageTurnPreviewState();
}

export function clearPageTurnPreviewState(page: ReadBookPage): void {
    page.pageTurnPreviewKey = '';
    page.pageTurnPreviewLoadingKey = '';
    page.pageTurnCrossChapterHandoff = false;
}

export function buildBookPreview(page: ReadBookPage): string {
    if (!page.book) return '';

    let text = `${page.book.name}\n\n作者：${page.book.author || '未知'}\n来源：${page.book.originName || page.book.origin}`;
    if (page.book.latestChapterTitle) {
      text += `\n最新章节：${page.book.latestChapterTitle}`;
    }
    if (page.book.intro) {
      text += `\n\n简介：${page.book.intro}`;
    }
    if (page.book.origin !== 'local') {
      page.updatePendingVerification();
      if (page.verificationUrl) {
        text += '\n\n当前书源需要先完成网页验证。请点击右上角“更多操作”，选择“登录”，完成后返回，再从该菜单选择“重试”。';
      } else {
        text += '\n\n当前书源暂未解析出目录。请点击右上角“更多操作”，选择“重试”重新获取，或在书源管理中为该书源补充目录规则。';
        const stageError = AppStorage.get<string>('bookSourceStageLastError') || '';
        if (stageError) text += `\n诊断：${stageError}`;
      }
    }
    return text;
}

export async function jumpToAdjacentChapterFirstPage(page: ReadBookPage, direction: number): Promise<void> {
    // Reopening the currently narrated book creates a new reader page while the hidden
    // original page still owns TTS. Route the chapter bar command to that owner; changing
    // only this mirrored page is immediately overwritten by the owner's position update.
    if (page.isMirroringActiveTtsForCurrentBook()) {
      if (direction < 0 && !page.globalTtsCanPrevious) {
        HdsFeedback.showToast('已经是第一章');
        return;
      }
      if (direction > 0 && !page.globalTtsCanNext) {
        HdsFeedback.showToast('本书已阅读完成');
        return;
      }
      if (direction > 0) {
        ReaderTtsFloatingSession.next();
      } else {
        ReaderTtsFloatingSession.previous();
      }
      return;
    }
    const targetChapterIndex = page.currentChapterIndex + (direction > 0 ? 1 : -1);
    if (targetChapterIndex < 0) {
      HdsFeedback.showToast('已经是第一章');
      return;
    }
    if (targetChapterIndex >= page.chapters.length) {
      HdsFeedback.showToast('本书已阅读完成');
      return;
    }

    const wasTtsPaused = page.isTtsSessionManuallyPaused();
    const ttsSessionActive = page.isTtsSpeaking || page.ttsReader.isSpeaking();
    const shouldResumeTts = ttsSessionActive && !wasTtsPaused;
    if (ttsSessionActive) {
      if (shouldResumeTts) {
        page.stopTtsReaderForChapterSwitch();
        await page.updateTtsAvSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_BUFFERING);
      } else {
        page.prepareTtsForManualPageTurn();
      }
    }
    page.finishPageTurnAnimation();
    page.isLoading = true;
    page.loadStatus = '正在切换章节...';
    await LeafFns.delay(0);
    try {
      page.currentPageIndex = 0;
      page.pendingRestorePageIndex = 0;
      await page.loadContent(true, targetChapterIndex, true);
      if (page.currentChapterIndex !== targetChapterIndex) {
        return;
      }

      page.currentPageIndex = 0;
      page.pendingRestorePageIndex = -1;
      const targetPageText = page.contentPages[0] || page.content || '';
      page.setCurrentPageText(targetPageText);
      page.finishPageTurnAnimation();
      page.refreshReaderTextRender();
      await LeafFns.delay(16);
    } finally {
      page.isLoading = false;
      page.loadStatus = '';
    }
    page.saveReadingProgress();
    if (shouldResumeTts) {
      await page.startTtsReadingFromCurrentPosition(false);
    } else if (wasTtsPaused) {
      page.scheduleTtsResumeAfterManualPageTurn();
      await page.updateTtsAvSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
    }
}

export async function loadNextChapter(page: ReadBookPage, showLoading: boolean = false, showBoundaryToast: boolean = false): Promise<void> {
    if (page.currentChapterIndex >= page.chapters.length - 1) {
      if (showBoundaryToast) {
        HdsFeedback.showToast('本书已阅读完成');
      }
      return;
    }
    const targetChapterIndex = page.currentChapterIndex + 1;
    page.currentPageIndex = 0;
    page.pendingRestorePageIndex = 0;
    await page.loadContent(!showLoading, targetChapterIndex, true);
    page.saveReadingProgress();
}

export async function loadPrevChapter(page: ReadBookPage, toLastPage: boolean = false, showLoading: boolean = false, showBoundaryToast: boolean = false): Promise<void> {
    if (page.currentChapterIndex <= 0) {
      if (showBoundaryToast) {
        HdsFeedback.showToast('已经是第一章');
      }
      return;
    }
    const targetChapterIndex = page.currentChapterIndex - 1;
    page.currentPageIndex = 0;
    page.pendingRestorePageIndex = toLastPage ? Number.MAX_SAFE_INTEGER : 0;
    await page.loadContent(!showLoading, targetChapterIndex);
    page.saveReadingProgress();
}
