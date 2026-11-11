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

export function clearTtsHighlight(page: ReadBookPage): void {
    // 停止/收尾路径都先清 isTtsSpeaking/ttsAutoContinue 再调用；朗读进行中走到这里
    // 说明镜像拆除等旁路与起播竞态（接管 stopOther 窗口），是需要立即暴露的异常。
    if (page.isTtsSpeaking && page.ttsAutoContinue) {
      console.warn(`[TTS] highlight cleared while speaking: token=${page.ttsReadToken},` +
        `startOffset=${page.ttsTextStartOffset},mirrored=${page.mirroredTtsFocusActive}`);
    }
    if (!page.ttsDisplayText && page.ttsHighlightStart < 0 && page.ttsHighlightEnd < 0 &&
      page.ttsTextStartOffset === 0 && page.readerV2TtsSourceStart < 0) {
      return;
    }
    page.ttsDisplayText = '';
    page.ttsHighlightStart = -1;
    page.ttsHighlightEnd = -1;
    page.ttsTextStartOffset = 0;
    page.readerV2ActiveSpeechText = null;
    page.readerV2TtsSourceStart = -1;
    page.readerV2TtsSourceEnd = -1;
    page.refreshReaderV2TtsOverlay();
    page.publishTtsHighlightRenderChange();
}

export function publishTtsHighlightRenderChange(page: ReadBookPage): void {
    // V2 owns a root-level lightweight focus layer. Its key observes readerV2TtsPaintVersion directly, so the
    // retained正文 page stays mounted while only the yellow rectangles are replaced.
    if (page.shouldUseReaderLayoutV2(page.pagedContentText)) {
      page.readerV2TtsPaintVersion++;
    } else {
      page.ttsHighlightRenderVersion++;
    }
}

export function currentTtsSourceIdentity(page: ReadBookPage): string {
    const source = page.pagedContentText || page.getPagedSourceText();
    return `${page.currentChapterIndex}_${source.length}_${hashText(source)}`;
}

export function invalidateTtsFocusSession(page: ReadBookPage): void {
    page.ttsFocusGeneration++;
    page.ttsFocusChapterIndex = -1;
    page.ttsFocusSourceIdentity = '';
    page.ttsFocusContentLoadSerial = -1;
    page.ttsLastAppliedSourceOffset = -1;
}

export function isCurrentTtsFocusSession(page: ReadBookPage, token: number, generation: number, chapterIndex: number, sourceIdentity: string): boolean {
    return token === page.ttsReadToken && generation === page.ttsFocusGeneration &&
      chapterIndex === page.ttsFocusChapterIndex && chapterIndex === page.currentChapterIndex &&
      !!sourceIdentity && sourceIdentity === page.ttsFocusSourceIdentity &&
      page.ttsFocusContentLoadSerial === page.contentLoadSerial && page.isTtsSpeaking && page.ttsAutoContinue;
}

export function getTtsReadingText(page: ReadBookPage, startOffset: number = -1): string {
    const source = page.pagedContentText || page.getPagedSourceText();
    const pageStart = page.getCurrentPageStartOffset();
    let start = startOffset >= pageStart ? Math.min(Math.round(startOffset), source.length) : pageStart;
    const containingMarker = ReaderActionMarker.findRawRangeContaining(source, start);
    if (containingMarker.length >= 2) start = containingMarker[1];
    page.ttsTextStartOffset = start;
    if (page.shouldUseReaderLayoutV2(source)) {
      const document = page.readerV2Document(page.currentChapterIndex, source);
      if (document) {
        page.readerV2ActiveSpeechText = ReaderV2SpeechText.build(document, start);
        return page.readerV2ActiveSpeechText.text;
      }
    }
    page.readerV2ActiveSpeechText = null;
    return ReaderActionMarker.strip(LocalBookService.stripEpubImageMarkers(source.substring(start), true), true);
}

export function getTtsFocusBreakOffsets(page: ReadBookPage, textLength: number): number[] {
    const result: number[] = [];
    for (const pageStart of page.contentPageStarts) {
      const offset = page.readerV2ActiveSpeechText ? page.readerV2ActiveSpeechText.speechOffsetAt(pageStart) :
        pageStart - page.ttsTextStartOffset;
      if (offset > 0 && offset < textLength) {
        result.push(offset);
      }
    }
    return result;
}

export function getPagedSourceText(page: ReadBookPage): string {
    return page.buildPagedSourceText(page.currentChapterIndex, page.content || '');
}

export function buildPagedSourceText(page: ReadBookPage, chapterIndex: number, content: string): string {
    const title = page.getChapterTitle(chapterIndex).trim();
    // Paragraph comments change both measured line width and paragraph grouping. Build pagination from the
    // effective source state: when the source switch is explicitly off, remove only comment actions while
    // retaining images, videos and unrelated source-provided actions.
    const effectiveContent = LeafFns.readerParagraphCommentsEnabledForPagination() ?
      (content || '') : LeafFns.stripReaderParagraphCommentActions(content || '');
    const leadingAction = ReaderActionMarker.findFirst(effectiveContent);
    const titleAction = leadingAction && leadingAction.start === 0 && leadingAction.data.title === '章评' ?
      leadingAction.marker : '';
    const contentBody = titleAction && leadingAction ?
      effectiveContent.substring(leadingAction.end).replace(/^\s+/, '') :
      effectiveContent;
    const sourceBody = LeafFns.stripDuplicatedChapterTitle(LeafFns.normalizeChapterBody(contentBody), title);
    const body = LeafFns.buildIndentedChapterBody(sourceBody);
    if (LocalBookService.hasEpubImageMarkers(body) &&
      !LocalBookService.stripEpubImageMarkers(body).trim()) {
      return body;
    }
    if (!title) {
      return body;
    }
    return titleAction ? `${title}${titleAction}\n\n${body}` : `${title}\n\n${body}`;
}

export function trimPageStartChar(page: ReadBookPage, value: string): boolean {
    return page.keepParagraphIndent ? LeafFns.isReaderPageStartTrimChar(value) : LeafFns.isReaderTrimChar(value);
}

export function pushReaderPage(page: ReadBookPage, source: string, rawStart: number, rawEnd: number, pages: string[], starts: number[], ends: number[]): void {
    let pageStart = Math.max(0, Math.min(rawStart, source.length));
    let pageEnd = Math.max(pageStart, Math.min(rawEnd, source.length));
    while (pageStart < pageEnd && page.trimPageStartChar(source.charAt(pageStart))) {
      pageStart++;
    }
    while (pageEnd > pageStart && LeafFns.isReaderTrimChar(source.charAt(pageEnd - 1))) {
      pageEnd--;
    }
    const pageText = source.substring(pageStart, pageEnd);
    if (!pageText) {
      return;
    }
    pages.push(pageText);
    starts.push(pageStart);
    ends.push(pageEnd);
}

export function fitReaderActionMarkerPageEnd(page: ReadBookPage, source: string, start: number, rawEnd: number, availableWidth: number, availableHeight: number, chapterIndex: number): number {
    const adjustedEnd = LeafFns.adjustReaderActionMarkerPageEnd(source, start, rawEnd);
    if (adjustedEnd === rawEnd || adjustedEnd <= start) return adjustedEnd;
    // An inline marker is atomic. Appending it after the measured text can create a new rendered line,
    // so validate that enlarged range instead of assuming the payload-free measurement still fits.
    if (page.measureReaderTextHeight(source.substring(start, adjustedEnd), availableWidth, chapterIndex,
      source, start) <= availableHeight) {
      return adjustedEnd;
    }
    const marker = LeafFns.findReaderActionEndingAt(source, start, adjustedEnd);
    if (!marker || marker.start <= start) return Math.max(start + 1, rawEnd);
    return page.readerInlineActionCarryStart(source, start, marker.start, availableWidth, chapterIndex);
}

export function readerInlineActionCarryStart(page: ReadBookPage, source: string, pageStart: number, markerStart: number, availableWidth: number, chapterIndex: number): number {
    const prefix = source.substring(pageStart, markerStart);
    const paragraphs = page.getReaderTextParagraphs(prefix);
    const last = paragraphs.length > 0 ? paragraphs[paragraphs.length - 1] : null;
    if (last && last.text) {
      const absoluteParagraphStart = pageStart + last.start;
      const metrics = page.readerParagraphMetrics(last.text, availableWidth, chapterIndex, source,
        absoluteParagraphStart);
      if (metrics.lineEnds.length > 1) {
        const previousLineEnd = metrics.lineEnds[metrics.lineEnds.length - 2];
        const lineStart = absoluteParagraphStart + previousLineEnd;
        if (lineStart > pageStart && lineStart < markerStart) return lineStart;
      }
      if (absoluteParagraphStart > pageStart && absoluteParagraphStart < markerStart) return absoluteParagraphStart;
    }
    // Very short first paragraphs have no earlier line boundary. Carry one complete Unicode character with
    // the pill so the next page still renders it inline instead of exposing a standalone action row.
    let carryStart = markerStart - 1;
    if (carryStart > pageStart && carryStart < source.length) {
      const code = source.charCodeAt(carryStart);
      if (code >= 0xDC00 && code <= 0xDFFF) carryStart--;
    }
    return Math.max(pageStart + 1, carryStart);
}

export function findMeasuredPageEnd(page: ReadBookPage, source: string, start: number, availableWidth: number, availableHeight: number, chapterIndex: number = page.currentChapterIndex): number {
    let safeStart = Math.max(0, Math.min(start, source.length));
    while (safeStart < source.length && LeafFns.isReaderTrimChar(source.charAt(safeStart))) {
      safeStart++;
    }
    if (safeStart >= source.length) {
      return source.length;
    }

    // All content uses the same block paginator. The previous pure-text path could repeatedly rebuild every
    // earlier paragraph when paragraph spacing was enabled, while interactive text already measured complete
    // paragraphs once. Keeping one algorithm makes the inexpensive path available to every source.
    const blockWindowEnd = Math.min(source.length, safeStart + Math.max(4000,
      page.getReaderLayoutWindowSize(availableWidth, availableHeight)));
    const blockEnd = page.findBlockParagraphPageEnd(source, safeStart, blockWindowEnd,
      availableWidth, availableHeight, chapterIndex);
    if (blockEnd > safeStart) return blockEnd;

    // The precise paragraph path intentionally falls back when interactive markers are present because its
    // shortened display label no longer has a 1:1 source offset. Never binary-search the rest of the whole
    // chapter in that case: each probe would rebuild every following comment bubble and dense chapters can
    // block ArkUI for several seconds. The layout window is already at least twice the estimated visible text,
    // so it preserves the exact bubble-aware measurement while keeping every probe local to the current page.
    const layoutWindowEnd = Math.min(source.length,
      safeStart + page.getReaderLayoutWindowSize(availableWidth, availableHeight));
    let low = safeStart + 1;
    let high = layoutWindowEnd;
    let best = low;
    while (low <= high) {
      const mid = Math.floor((low + high) / 2);
      const candidate = source.substring(safeStart, mid);
      if (page.measureReaderTextHeight(candidate, availableWidth, chapterIndex, source, safeStart) <=
        availableHeight) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    const end = LeafFns.chooseReaderPageBreak(source, safeStart, best);
    return Math.max(safeStart + 1, end);
}

export function findBlockParagraphPageEnd(page: ReadBookPage, source: string, start: number, windowEnd: number, availableWidth: number, availableHeight: number, chapterIndex: number = page.currentChapterIndex): number {
    const layoutText = source.substring(start, Math.max(start + 1, windowEnd));
    const paragraphs = page.getReaderTextParagraphs(layoutText);
    let usedHeight = 0;
    let best = start;
    let previousIndependent = false;
    for (let index = 0; index < paragraphs.length; index++) {
      const paragraph = paragraphs[index];
      const paragraphStart = start + paragraph.start;
      const paragraphEnd = start + paragraph.end;
      const independent = page.readerParagraphRendersAsIndependentComponent(paragraph.text);
      const beforeSpacing = index > 0 ? page.getMeasuredReaderParagraphBoundarySpacingForLineHeightPx(
        page.getEffectiveReaderLineHeight(), previousIndependent || independent) *
        (page.readerParagraphSpacing > 0 ? 1 : page.getReaderPaginationHeightScale()) : 0;
      const paragraphHeight = page.measureReaderSingleParagraphHeight(paragraph.text, availableWidth,
        chapterIndex, source, paragraphStart);
      if (usedHeight + beforeSpacing + paragraphHeight <= availableHeight) {
        usedHeight += beforeSpacing + paragraphHeight;
        best = paragraphEnd;
        previousIndependent = independent;
        continue;
      }

      // Use the space left after the complete paragraphs instead of moving the whole next paragraph to the
      // following page. Comment-heavy sources frequently append a marker to every paragraph; treating all of
      // those paragraphs as atomic left several visible lines empty at the bottom of every page.
      const remainingHeight = Math.max(0, availableHeight - usedHeight - beforeSpacing);
      if (remainingHeight <= 0 && best > start) return best;

      // One native layout gives exact line ends for an ordinary paragraph and for the visible text before
      // an inline action. Rebuilding that paragraph for every binary-search probe is both slower and a source
      // of long main-thread stalls.
      const inlineAction = ReaderActionMarker.findFirst(paragraph.text);
      const directText = inlineAction && inlineAction.start > 0 ?
        paragraph.text.substring(0, inlineAction.start) : paragraph.text;
      const canUseDirectLineOffsets = !!directText &&
        !page.hasMeasuredThemeRegexDecoration(directText, source, paragraphStart);
      if (canUseDirectLineOffsets) {
        const plainEnd = page.findSingleParagraphLineEnd(directText, availableWidth, remainingHeight,
          chapterIndex, source, paragraphStart);
        if (plainEnd > 0 && plainEnd < directText.length) {
          const directEnd = LeafFns.chooseReaderPageBreak(source, paragraphStart, paragraphStart + plainEnd);
          return Math.max(paragraphStart + 1, directEnd);
        }
        if (inlineAction && plainEnd >= directText.length) {
          // The text fits but its fixed-width pill does not. The old generic binary search rebuilt the same
          // interactive paragraph many times. Carry its last line with the marker using the already cached
          // plain-text line metrics; one deterministic decision replaces O(log marker-payload) layouts.
          return page.readerInlineActionCarryStart(source, paragraphStart,
            paragraphStart + inlineAction.start, availableWidth, chapterIndex);
        }
      }

      // Keep marker boundaries atomic while finding the largest fitting source range, so compact action payloads
      // can never leak into rendered text when the text portion of an interactive paragraph is split across pages.
      let low = paragraphStart + 1;
      let high = paragraphEnd;
      let paragraphBest = paragraphStart;
      while (low <= high) {
        const mid = Math.floor((low + high) / 2);
        const candidateEnd = Math.min(paragraphEnd,
          LeafFns.adjustReaderActionMarkerPageEnd(source, paragraphStart, mid));
        const candidate = source.substring(paragraphStart, candidateEnd);
        if (page.measureReaderSingleParagraphHeight(candidate, availableWidth, chapterIndex,
          source, paragraphStart) <= remainingHeight) {
          paragraphBest = Math.max(paragraphBest, candidateEnd);
          low = mid + 1;
        } else {
          high = mid - 1;
        }
      }
      if (paragraphBest <= paragraphStart && best > start) return best;
      const breakEnd = LeafFns.chooseReaderPageBreak(source, paragraphStart, paragraphBest);
      const adjustedBreakEnd = LeafFns.adjustReaderActionMarkerPageEnd(source, paragraphStart, breakEnd);
      if (adjustedBreakEnd > breakEnd && page.measureReaderSingleParagraphHeight(
        source.substring(paragraphStart, adjustedBreakEnd), availableWidth, chapterIndex, source, paragraphStart) >
        remainingHeight) {
        const marker = LeafFns.findReaderActionEndingAt(source, paragraphStart, adjustedBreakEnd);
        if (marker && marker.start > paragraphStart) {
          return page.readerInlineActionCarryStart(source, paragraphStart, marker.start, availableWidth, chapterIndex);
        }
      }
      return Math.max(paragraphStart + 1, adjustedBreakEnd);
    }
    return best;
}

export function findSingleParagraphLineEnd(page: ReadBookPage, text: string, availableWidth: number, availableHeight: number, chapterIndex: number, documentSource: string, absoluteStart: number): number {
    if (!text || availableHeight <= 0) return -1;
    const metrics = page.readerParagraphMetrics(text, availableWidth, chapterIndex, documentSource, absoluteStart);
    const heightScale = page.getReaderPaginationHeightScale();
    let end = -1;
    for (let index = 0; index < metrics.lineEnds.length; index++) {
      const lineBottom = (metrics.lineBottomsPx[index] || metrics.heightPx) * heightScale;
      if (lineBottom > availableHeight) break;
      end = Math.max(end, metrics.lineEnds[index]);
    }
    return end;
}

export function refineMeasuredPageEnd(page: ReadBookPage, source: string, start: number, initialEnd: number, availableWidth: number, availableHeight: number, chapterIndex: number = page.currentChapterIndex): number {
    let best = Math.max(start + 1, Math.min(initialEnd, source.length));
    if (best >= source.length) {
      return source.length;
    }
    if (!page.doesMeasuredReaderPageFit(source, start, best, availableWidth, availableHeight, chapterIndex)) {
      return best;
    }

    let step = Math.max(16, Math.min(512, best - start));
    let upper = Math.min(source.length, best + step);
    while (upper < source.length &&
      page.doesMeasuredReaderPageFit(source, start, upper, availableWidth, availableHeight, chapterIndex)) {
      best = upper;
      step = Math.min(step * 2, 4096);
      upper = Math.min(source.length, best + step);
    }
    if (upper === source.length &&
      page.doesMeasuredReaderPageFit(source, start, upper, availableWidth, availableHeight, chapterIndex)) {
      return source.length;
    }

    let low = best + 1;
    let high = Math.max(low, upper - 1);
    while (low <= high) {
      const mid = Math.floor((low + high) / 2);
      if (page.doesMeasuredReaderPageFit(source, start, mid, availableWidth, availableHeight, chapterIndex)) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    const end = LeafFns.chooseReaderPageBreak(source, start, best);
    return Math.max(start + 1, end);
}

export function doesMeasuredReaderPageFit(page: ReadBookPage, source: string, start: number, end: number, availableWidth: number, availableHeight: number, chapterIndex: number = page.currentChapterIndex): boolean {
    const safeEnd = Math.max(start + 1, Math.min(end, source.length));
    return page.measureReaderTextHeight(source.substring(start, safeEnd), availableWidth, chapterIndex,
      source, start) <= availableHeight;
}

export function findParagraphLayoutPageEnd(page: ReadBookPage, source: string, start: number, availableWidth: number, availableHeight: number, chapterIndex: number = page.currentChapterIndex): number {
    const windowEnd = Math.min(source.length, start + page.getReaderLayoutWindowSize(availableWidth, availableHeight));
    const layoutText = source.substring(start, windowEnd);
    if (!layoutText) {
      return -1;
    }
    if (page.readerParagraphSpacing > 0 && /\n/.test(layoutText)) {
      return -1;
    }
    // Placeholder spans occupy a paragraph index but do not correspond to a
    // source-text character. Use the precise height-search path for decorated
    // theme bubbles so line metric indexes are never mistaken for source
    // offsets.
    if (page.hasMeasuredThemeRegexDecoration(layoutText, source, start)) {
      return -1;
    }
    if (ReaderActionMarker.has(layoutText)) {
      return -1;
    }
    try {
      const paragraph = page.buildMeasuredReaderParagraph(layoutText, availableWidth, chapterIndex, source, start);
      const metrics = paragraph.getLineMetrics();
      if (metrics.length === 0) {
        return -1;
      }

      const safeHeight = Math.max(1, availableHeight - 1);
      let end = -1;
      for (let i = 0; i < metrics.length; i++) {
        const metric = metrics[i];
        if ((metric.topHeight + metric.height) * page.getReaderPaginationHeightScale() > safeHeight) {
          break;
        }
        end = Math.max(end, metric.endIndex);
      }

      if (end <= 0) {
        const firstRange = paragraph.getActualTextRange(0, true);
        end = Math.max(1, firstRange.end);
      }
      if (end >= layoutText.length && windowEnd < source.length) {
        return -1;
      }
      return Math.max(start + 1, Math.min(source.length, start + end));
    } catch (error) {
      console.error('官方段落布局分页失败，回退到文本测量分页:', error);
      return -1;
    }
}

export function getReaderLayoutWindowSize(page: ReadBookPage, availableWidth: number, availableHeight: number): number {
    const charsPerLine = Math.max(8, Math.floor(availableWidth / Math.max(1, page.readerFontSize * 0.95)));
    const visibleLines = Math.max(1, Math.ceil(availableHeight / page.getEffectiveReaderLineHeight()));
    return Math.min(12000, Math.max(800, charsPerLine * (visibleLines + 6) * 2));
}

export function getReaderPaginationRenderGuardHeight(page: ReadBookPage): number {
    // A merged Text is measured and rendered as one pixel-aligned box, so it needs no extra reserve. Visible
    // paragraph spacing creates many independently rounded Text/Blank components; keep a tiny aggregate guard
    // for that mode only. This prevents the observed 2-3px footer crossing without restoring the old full-line
    // hidden reserve.
    return page.readerParagraphSpacing > 0 ? 4 : 0;
}

export function getReaderTextParagraphs(page: ReadBookPage, text: string): ReaderTextParagraph[] {
    const cached = page.readerTextParagraphsCache.get(text);
    if (cached) return cached;
    const source = (text || '')
      .replace(/\r\n/g, '\n')
      .replace(/\n{3,}/g, '\n\n');
    const paragraphs: ReaderTextParagraph[] = [];
    const separatorRegex = /\n+/g;
    let start = 0;
    let index = 0;
    let match = separatorRegex.exec(source);
    while (match) {
      if (match.index > start) {
        const paragraphText = source.substring(start, match.index);
        paragraphs.push({
          text: paragraphText,
          start: start,
          end: match.index,
          index: index,
          isLast: false,
          key: `paragraph_${index}_${start}_${match.index}_${LeafFns.buildTextSliceKey(paragraphText)}`
        });
        index++;
      }
      start = match.index + match[0].length;
      match = separatorRegex.exec(source);
    }
    if (start < source.length) {
      const paragraphText = source.substring(start);
      paragraphs.push({
        text: paragraphText,
        start: start,
        end: source.length,
        index: index,
        isLast: false,
        key: `paragraph_${index}_${start}_${source.length}_${LeafFns.buildTextSliceKey(paragraphText)}`
      });
    }
    if (paragraphs.length === 0) {
      paragraphs.push({
        text: source,
        start: 0,
        end: source.length,
        index: 0,
        isLast: true,
        key: `paragraph_empty_${LeafFns.buildTextSliceKey(source)}`
      });
      page.cacheReaderTextParagraphs(text, paragraphs);
      return paragraphs;
    }
    const lastIndex = paragraphs.length - 1;
    for (let i = 0; i < paragraphs.length; i++) {
      paragraphs[i].isLast = i === lastIndex;
      paragraphs[i].index = i;
    }
    page.cacheReaderTextParagraphs(text, paragraphs);
    return paragraphs;
}

export function cacheReaderTextParagraphs(page: ReadBookPage, text: string, paragraphs: ReaderTextParagraph[]): void {
    if (!text) return;
    page.readerTextParagraphsCache.set(text, paragraphs);
    while (page.readerTextParagraphsCache.size > 12) {
      const oldest = page.readerTextParagraphsCache.keys().next().value as string | undefined;
      if (oldest === undefined) break;
      page.readerTextParagraphsCache.delete(oldest);
    }
}

export function measureReaderTextHeight(page: ReadBookPage, text: string, availableWidth: number, chapterIndex: number = page.currentChapterIndex, documentSource: string = text, absoluteStart: number = 0): number {
    if (!text) {
      return 0;
    }
    const paragraphs = page.getReaderTextParagraphs(text);
    // With paragraph spacing disabled the renderer joins every ordinary/comment paragraph into one Text node.
    // Measuring them as separate native Paragraph objects adds the paragraph engine's terminal line spacing at
    // every newline, even though ArkUI's onlyBetweenLines mode adds it only once inside the merged component.
    // Comment-heavy pages could therefore lose several real lines at the bottom despite a zero bottom margin.
    const rendersAsOneText = page.readerParagraphSpacing <= 0 && paragraphs.length > 1 &&
      paragraphs.every((paragraph: ReaderTextParagraph): boolean =>
        !page.readerParagraphRendersAsIndependentComponent(paragraph.text));
    if (rendersAsOneText) {
      return page.measureReaderSingleParagraphHeight(text, availableWidth, chapterIndex, documentSource,
        absoluteStart);
    }
    if (paragraphs.length > 1) {
      let paragraphHeight = 0;
      let boundaryHeight = 0;
      for (let index = 0; index < paragraphs.length; index++) {
        const paragraph = paragraphs[index];
        const independent = page.readerParagraphRendersAsIndependentComponent(paragraph.text);
        const metrics = page.readerParagraphMetrics(paragraph.text, availableWidth, chapterIndex,
          documentSource, absoluteStart + paragraph.start);
        paragraphHeight += page.getMeasuredReaderParagraphComponentHeightPx(metrics,
          page.getEffectiveReaderLineHeight(), independent);
        if (!paragraph.isLast) {
          const nextIndependent = page.readerParagraphRendersAsIndependentComponent(paragraphs[index + 1].text);
          boundaryHeight += page.getMeasuredReaderParagraphBoundarySpacingForLineHeightPx(
            page.getEffectiveReaderLineHeight(), independent || nextIndependent);
        }
      }
      const heightScale = page.getReaderPaginationHeightScale();
      return paragraphHeight * heightScale + boundaryHeight *
        (page.readerParagraphSpacing > 0 ? 1 : heightScale);
    }
    return page.measureReaderSingleParagraphHeight(text, availableWidth, chapterIndex, documentSource, absoluteStart);
}

export function measureReaderSingleParagraphHeight(page: ReadBookPage, text: string, availableWidth: number, chapterIndex: number = page.currentChapterIndex, documentSource: string = text, absoluteStart: number = 0): number {
    const metrics = page.readerParagraphMetrics(text, availableWidth, chapterIndex, documentSource, absoluteStart);
    const rawHeight = page.getMeasuredReaderParagraphComponentHeightPx(metrics, page.getEffectiveReaderLineHeight(),
      page.readerParagraphRendersAsIndependentComponent(text));
    return rawHeight * page.getReaderPaginationHeightScale();
}

export function getReaderPaginationHeightScale(page: ReadBookPage): number {
    const identity = page.readerPaginationHeightCalibrationIdentity();
    if (identity !== page.readerPaginationHeightScaleIdentity) {
      page.readerPaginationHeightScaleIdentity = identity;
      page.readerPaginationHeightScale = READER_PAGINATION_HEIGHT_SCALE_CACHE.get(identity) || 1;
      page.readerPaginationHeightCalibrationResolvedIdentity =
        READER_PAGINATION_HEIGHT_SCALE_CACHE.has(identity) ? identity : '';
    }
    return Math.max(0.55, Math.min(1.15, page.readerPaginationHeightScale));
}

export function calibrateReaderPaginationHeightFromMergedText(page: ReadBookPage, paragraphs: ReaderTextParagraph[], chapterIndex: number, pageStart: number, documentSource: string, pageLineHeight: number, area: Area): void {
    // 连续滚动模式没有"页贴视口"的几何，块在屏幕上的位置随滚动任意变化，
    // 这两类按页面几何推导排版缩放的校准不适用；误触发还会在阅读中整章重排。
    if (page.isReaderContinuousScrollSurfaceActive()) return;
    // 旧章卸载中的渲染块会携带旧 chapterIndex 触发 onAreaChange；加载窗口内的校准会清掉
    // 新章预载分页并回写跨章恢复锚点（章末“跳末页再弹回首页”竞态），必须直接跳过。
    if (chapterIndex !== page.currentChapterIndex || page.readerContentLoadInFlight > 0) return;
    const independentParagraphLayout = page.readerParagraphSpacing > 0;
    if ((!independentParagraphLayout && paragraphs.length < 3) || pageStart < 0 || !documentSource) {
      return;
    }
    if (independentParagraphLayout && (paragraphs.length !== 1 ||
      page.shouldUseTitleStyle(paragraphs[0].text, chapterIndex))) return;
    const identity = page.readerPaginationHeightCalibrationIdentity();
    const currentScale = page.getReaderPaginationHeightScale();
    if (page.readerPaginationHeightCalibrationResolvedIdentity === identity) return;
    const width = parseAreaDimension(area.width);
    const actualHeight = parseAreaDimension(area.height);
    if (width <= 0 || actualHeight <= 0) return;

    let rawParagraphHeightPx = 0;
    let boundaryHeightPx = 0;
    let previousIndependent = false;
    for (let index = 0; index < paragraphs.length; index++) {
      const paragraph = paragraphs[index];
      const independent = page.readerParagraphRendersAsIndependentComponent(paragraph.text);
      const metrics = page.readerParagraphMetrics(paragraph.text, width, chapterIndex, documentSource,
        pageStart + paragraph.start);
      rawParagraphHeightPx += page.getMeasuredReaderParagraphComponentHeightPx(metrics,
        pageLineHeight, independent);
      if (index > 0) {
        boundaryHeightPx += page.getMeasuredReaderParagraphBoundarySpacingForLineHeightPx(
          pageLineHeight, previousIndependent || independent);
      }
      previousIndependent = independent;
    }
    if (rawParagraphHeightPx <= 0) return;
    const actualHeightPx = LeafFns.toMeasurePx(actualHeight);
    const rawTotalHeightPx = rawParagraphHeightPx + boundaryHeightPx;
    const targetScale = Math.max(0.55, Math.min(1.15, independentParagraphLayout ?
      actualHeightPx / rawParagraphHeightPx : actualHeightPx / rawTotalHeightPx));
    page.readerPaginationHeightCalibrationResolvedIdentity = identity;
    if (!Number.isFinite(targetScale) || Math.abs(targetScale - currentScale) < 0.012) {
      cacheReaderPaginationHeightScale(identity, currentScale);
      return;
    }

    page.readerPaginationHeightScale = targetScale;
    cacheReaderPaginationHeightScale(identity, targetScale);
    console.warn(`[ReaderPaginationCalibration] actual=${Math.round(actualHeightPx)} ` +
      `raw=${Math.round(rawTotalHeightPx)} lineHeight=${pageLineHeight.toFixed(2)} ` +
      `scale=${targetScale.toFixed(4)}`);
    const readingOffset = page.getReaderStableReflowOffset();
    page.setReaderTypographyRestoreOffset(readingOffset);
    page.readerPaginationWorkSerial++;
    page.adjacentPaginationPreloadSerial++;
    page.previousPaginationPreloadSerial++;
    page.readerPaginationCache.clear();
    page.readerAdaptiveLineHeightCache.clear();
    page.pageTurnPreviewKey = '';
    page.pageTurnPreviewLoadingKey = '';
    page.refreshReaderTextRender();
    page.paginateContent(page.content);
}

export function scheduleReaderPaginationBottomFitCalibration(page: ReadBookPage, paragraphs: ReaderTextParagraph[], chapterIndex: number, pageStart: number, area: Area): void {
    // 页底贴合校准按"块的屏幕底部 vs 视口底部预留线"判断溢出，只在分页模式成立；
    // 滚动模式里块的屏幕位置由滚动进度决定，该比较必然失真，还会在阅读中触发整章重排。
    if (page.isReaderContinuousScrollSurfaceActive()) return;
    if (page.readerParagraphSpacing <= 0 || paragraphs.length !== 1 || !paragraphs[0].isLast ||
      chapterIndex !== page.currentChapterIndex || pageStart < 0) return;
    const globalTop = parseAreaDimension(area.globalPosition?.y ?? 0);
    const actualHeight = parseAreaDimension(area.height);
    if (actualHeight <= 0) return;
    const actualBottom = globalTop + actualHeight;
    const taskIdentity = `${page.readerPaginationHeightCalibrationIdentity()}_${chapterIndex}_${pageStart}`;
    if (page.readerPaginationBottomFitTimerId >= 0) clearTimeout(page.readerPaginationBottomFitTimerId);
    page.readerPaginationBottomFitTimerId = setTimeout(() => {
      page.readerPaginationBottomFitTimerId = -1;
      if (chapterIndex !== page.currentChapterIndex || pageStart !== page.getCurrentPageStartOffset() ||
        page.readerContentLoadInFlight > 0) return;
      if (taskIdentity !== page.readerPaginationBottomFitIdentity) {
        page.readerPaginationBottomFitIdentity = taskIdentity;
        page.readerPaginationBottomFitAttempts = 0;
      }
      if (page.readerPaginationBottomFitAttempts >= 3) return;
      const desiredBottom = page.readerCommentPageAreaTop + page.pageViewHeight -
        page.getReaderContentBottomReserve();
      const overflow = actualBottom - desiredBottom;
      if (!Number.isFinite(overflow) || overflow <= 0.5) return;

      const identity = page.readerPaginationHeightCalibrationIdentity();
      const currentScale = page.getReaderPaginationHeightScale();
      const correction = Math.max(0.02, Math.min(0.08, overflow / Math.max(1, page.pageViewHeight)));
      const nextScale = Math.max(0.55, Math.min(1.15, currentScale + correction));
      if (nextScale <= currentScale + 0.001) return;
      page.readerPaginationBottomFitAttempts++;
      page.readerPaginationHeightScale = nextScale;
      page.readerPaginationHeightScaleIdentity = identity;
      page.readerPaginationHeightCalibrationResolvedIdentity = identity;
      cacheReaderPaginationHeightScale(identity, nextScale);
      console.warn(`[ReaderPaginationBottomFit] overflow=${overflow.toFixed(2)} ` +
        `scale=${currentScale.toFixed(4)}->${nextScale.toFixed(4)}`);
      const readingOffset = page.getReaderStableReflowOffset();
      page.setReaderTypographyRestoreOffset(readingOffset);
      page.readerPaginationWorkSerial++;
      page.adjacentPaginationPreloadSerial++;
      page.previousPaginationPreloadSerial++;
      page.readerPaginationCache.clear();
      page.readerAdaptiveLineHeightCache.clear();
      page.pageTurnPreviewKey = '';
      page.pageTurnPreviewLoadingKey = '';
      page.refreshReaderTextRender();
      page.paginateContent(page.content);
    }, 180);
}

export function readerPaginationHeightCalibrationIdentity(page: ReadBookPage): string {
    return `${page.readerTypographyCacheIdentity()}_${LeafFns.readerParagraphCommentPaginationIdentity()}`;
}

export function readerParagraphMetrics(page: ReadBookPage, text: string, availableWidth: number, chapterIndex: number = page.currentChapterIndex, documentSource: string = text, absoluteStart: number = 0): ReaderParagraphMetrics {
    if (!text) return { heightPx: 0, lineEnds: [], lineBottomsPx: [], lineCount: 0 };
    const key = `${chapterIndex}_${absoluteStart}_${Math.round(availableWidth * 10)}_` +
      `${page.readerTypographyCacheIdentity()}_${LeafFns.buildTextSliceKey(documentSource)}_` +
      `${text.length}_${hashText(text)}`;
    const cached = page.readerParagraphMetricsCache.get(key);
    if (cached) return cached;

    let result: ReaderParagraphMetrics;
    // parse() also succeeds when a marker is appended to ordinary paragraph text. Only a truly
    // standalone action renders as the fixed-height button row; inline comment bubbles remain a
    // multi-line Text component and must go through native paragraph measurement below.
    if (ReaderActionMarker.parse(text) && !page.hasInlineReaderSourceAction(text)) {
      result = {
        heightPx: LeafFns.toMeasurePx(Math.max(page.getEffectiveReaderLineHeight(), 32)),
        lineEnds: [text.length],
        lineBottomsPx: [LeafFns.toMeasurePx(Math.max(page.getEffectiveReaderLineHeight(), 32))],
        lineCount: 1
      };
      page.cacheReaderParagraphMetrics(key, result);
      return result;
    }
    const measuredText = page.readerActionMeasurementText(text, documentSource, absoluteStart);
    try {
      const layoutParagraphs = page.getReaderTextParagraphs(text);
      const measureMergedText = page.readerParagraphSpacing <= 0 && layoutParagraphs.length > 1 &&
        layoutParagraphs.every((paragraph: ReaderTextParagraph): boolean =>
          !page.readerParagraphRendersAsIndependentComponent(paragraph.text));
      const paragraph = measureMergedText ?
        page.buildMeasuredMergedReaderParagraph(layoutParagraphs, availableWidth, chapterIndex, documentSource,
          absoluteStart) :
        page.buildMeasuredReaderParagraph(text, availableWidth, chapterIndex, documentSource, absoluteStart);
      const nativeMetrics = paragraph.getLineMetrics();
      if (nativeMetrics.length > 0) {
        const lineEnds: number[] = [];
        const lineBottomsPx: number[] = [];
        for (let index = 0; index < nativeMetrics.length; index++) {
          const metric = nativeMetrics[index];
          lineEnds.push(metric.endIndex);
          // LineMetrics exposes the laid-out row top and height directly. baseline + descent describes glyph
          // metrics and can retain extra font space for custom fonts; adding that once for every independent
          // paragraph accumulated several visible blank lines on comment-heavy pages.
          lineBottomsPx.push(Math.max(0, metric.topHeight + metric.height));
        }
        // Use the paragraph engine's authoritative component height. ArkUI Text uses the same native paragraph
        // box, whereas reconstructing the full box from a glyph baseline is especially inaccurate when regex
        // fonts and inline comment pills are mixed in one paragraph.
        const height = Math.max(0, paragraph.getHeight());
        if (height > 0) {
          result = {
            heightPx: height,
            lineEnds: lineEnds,
            lineBottomsPx: lineBottomsPx,
            lineCount: nativeMetrics.length
          };
          page.cacheReaderParagraphMetrics(key, result);
          return result;
        }
      }
    } catch (error) {
      console.error('官方段落布局测量阅读文本高度失败，回退到组件测量:', error);
    }
    const fallbackStyle = page.getParagraphFallbackMeasureStyle(measuredText, chapterIndex);
    const options: MeasureOptions = {
        textContent: measuredText,
        constraintWidth: Math.max(1, availableWidth),
        fontSize: fallbackStyle.fontSize,
        fontFamily: fallbackStyle.fontFamily,
        lineHeight: page.getEffectiveReaderLineHeight(),
        letterSpacing: page.getReaderAdaptiveLetterSpacing(),
      fontWeight: FontWeight.Normal,
      textAlign: page.readerTextAlignValue(),
      wordBreak: WordBreak.BREAK_WORD
    };
    try {
      const size = page.getUIContext().getMeasureUtils().measureTextSize(options);
      const height = Number(size.height);
      if (height > 0) {
        const fallbackLineHeightPx = LeafFns.toMeasurePx(page.getEffectiveReaderLineHeight());
        result = {
          heightPx: height,
          lineEnds: [],
          lineBottomsPx: [],
          lineCount: Math.max(1, Math.round(height / Math.max(1, fallbackLineHeightPx)))
        };
        page.cacheReaderParagraphMetrics(key, result);
        return result;
      }
    } catch (error) {
      console.error('测量阅读文本高度失败:', error);
    }
    const charsPerLine = Math.max(8, Math.floor(availableWidth / Math.max(1, page.readerFontSize * 1.08)));
    const lines = Math.max(1, Math.ceil(measuredText.length / charsPerLine));
    result = {
      heightPx: LeafFns.toMeasurePx(lines * page.getEffectiveReaderLineHeight()),
      lineEnds: [],
      lineBottomsPx: [],
      lineCount: lines
    };
    page.cacheReaderParagraphMetrics(key, result);
    return result;
}

export function cacheReaderParagraphMetrics(page: ReadBookPage, key: string, metrics: ReaderParagraphMetrics): void {
    page.readerParagraphMetricsCache.set(key, metrics);
    while (page.readerParagraphMetricsCache.size > 640) {
      const oldestKey = page.readerParagraphMetricsCache.keys().next().value as string | undefined;
      if (!oldestKey) break;
      page.readerParagraphMetricsCache.delete(oldestKey);
    }
}

export function readerActionMeasurementText(page: ReadBookPage, text: string, documentSource: string, absoluteStart: number): string {
    const value = text || '';
    const source = documentSource || value;
    const rangeStart = Math.max(0, Math.min(absoluteStart, source.length));
    const rangeEnd = Math.min(source.length, rangeStart + value.length);
    let searchStart = rangeStart;
    let localCursor = 0;
    let result = '';
    while (searchStart < rangeEnd) {
      let markerStart = -1;
      for (const prefix of [ReaderActionMarker.PREFIX, ReaderActionMarker.LEGACY_PREFIX,
        ReaderActionMarker.ORIGINAL_PREFIX]) {
        const index = source.indexOf(prefix, searchStart);
        if (index >= 0 && (markerStart < 0 || index < markerStart)) markerStart = index;
      }
      if (markerStart < 0 || markerStart >= rangeEnd) break;
      const suffix = source.indexOf(ReaderActionMarker.SUFFIX, markerStart);
      if (suffix < 0) break;
      const markerEnd = suffix + ReaderActionMarker.SUFFIX.length;
      const localStart = Math.max(0, markerStart - rangeStart);
      const localEnd = Math.max(localStart, Math.min(value.length, markerEnd - rangeStart));
      result += value.substring(localCursor, localStart);
      const marker = source.substring(markerStart, markerEnd);
      const previousChar = markerStart > 0 ? source.charAt(markerStart - 1) : '';
      const inlineMarker = markerStart > 0 && previousChar !== '\n' && previousChar !== '\r';
      result += inlineMarker ? page.readerInlineSourceActionLabel(marker) :
        (ReaderActionMarker.parse(marker)?.label || '打开');
      localCursor = localEnd;
      if (markerEnd >= rangeEnd) break;
      searchStart = markerEnd;
    }
    if (localCursor === 0) return value;
    return `${result}${value.substring(localCursor)}`;
}

export function buildReaderMeasureTextStyle(page: ReadBookPage, fontSize: number, fontFamily: string): graphicsText.TextStyle {
    return {
      // ArkUI Text.fontSize(number) is expressed in fp. Keep font conversion separate from the vp geometry
      // used by widths, margins and line spacing.
      fontSize: LeafFns.toMeasureFontPx(fontSize),
      letterSpacing: LeafFns.toMeasureFontOffsetPx(page.getReaderAdaptiveLetterSpacing()),
      fontFamilies: [fontFamily || page.getBodyReaderFontFamily()],
      fontWeight: graphicsText.FontWeight.W400,
      halfLeading: false,
      heightOnly: true,
      heightScale: 1,
      locale: 'zh-Hans'
    };
}

export function buildMeasuredReaderParagraph(page: ReadBookPage, text: string, availableWidth: number, chapterIndex: number = page.currentChapterIndex, documentSource: string = text, absoluteStart: number = 0): graphicsText.Paragraph {
    const bodyStyle = page.buildReaderMeasureTextStyle(page.readerFontSize, page.getBodyReaderFontFamily());
    const paragraphStyle: graphicsText.ParagraphStyle = {
      textStyle: bodyStyle,
      align: page.readerGraphicsTextAlignValue(),
      textDirection: graphicsText.TextDirection.LTR,
      wordBreak: graphicsText.WordBreak.BREAK_WORD,
      // Keep native page measurement on the same bounded breaker as the ArkUI Text nodes.
      breakStrategy: graphicsText.BreakStrategy.GREEDY,
      trailingSpaceOptimized: true,
      lineSpacing: LeafFns.toMeasureNonNegativePx(Math.max(0, page.readerLineHeight)),
      includeFontPadding: false
    };
    const builder = new graphicsText.ParagraphBuilder(paragraphStyle, graphicsText.FontCollection.getGlobalInstance());
    page.addMeasuredReaderText(builder, text || '', chapterIndex, bodyStyle, documentSource, absoluteStart);
    const paragraph = builder.build();
    paragraph.layoutSync(LeafFns.toMeasurePx(availableWidth));
    return paragraph;
}

export function buildMeasuredMergedReaderParagraph(page: ReadBookPage, paragraphs: ReaderTextParagraph[], availableWidth: number, chapterIndex: number, documentSource: string, absoluteStart: number): graphicsText.Paragraph {
    const bodyStyle = page.buildReaderMeasureTextStyle(page.readerFontSize, page.getBodyReaderFontFamily());
    const paragraphStyle: graphicsText.ParagraphStyle = {
      textStyle: bodyStyle,
      align: page.readerGraphicsTextAlignValue(),
      textDirection: graphicsText.TextDirection.LTR,
      wordBreak: graphicsText.WordBreak.BREAK_WORD,
      breakStrategy: graphicsText.BreakStrategy.GREEDY,
      trailingSpaceOptimized: true,
      lineSpacing: LeafFns.toMeasureNonNegativePx(Math.max(0, page.readerLineHeight)),
      includeFontPadding: false
    };
    const builder = new graphicsText.ParagraphBuilder(paragraphStyle, graphicsText.FontCollection.getGlobalInstance());
    for (let index = 0; index < paragraphs.length; index++) {
      const paragraph = paragraphs[index];
      if (index > 0) {
        builder.pushStyle(bodyStyle);
        builder.addText('\n');
        builder.popStyle();
      }
      page.addMeasuredReaderText(builder, paragraph.text, chapterIndex, bodyStyle, documentSource,
        absoluteStart + paragraph.start);
    }
    const result = builder.build();
    result.layoutSync(LeafFns.toMeasurePx(availableWidth));
    return result;
}

export function addMeasuredReaderText(page: ReadBookPage, builder: graphicsText.ParagraphBuilder, text: string, chapterIndex: number, bodyStyle: graphicsText.TextStyle, documentSource: string = text, absoluteStart: number = 0): void {
    if (page.shouldUseTitleStyle(text, chapterIndex)) {
      const title = page.getChapterTitle(chapterIndex).trim();
      const titleLength = Math.min(title.length, text.length);
      const titleStyle = page.buildReaderMeasureTextStyle(page.readerTitleFontSize, page.getTitleReaderFontFamily());
      builder.pushStyle(titleStyle);
      builder.addText(text.substring(0, titleLength));
      builder.popStyle();
      const rest = text.substring(titleLength);
      if (rest) {
        // Inline provider actions can be stored immediately after the reader-generated title. Measuring the
        // compact marker as ordinary text disagrees with the rendered action pill and makes title pages
        // substantially more expensive to paginate.
        const inlineAction = LeafFns.findMeasuredReaderInlineAction(rest, documentSource,
          absoluteStart + titleLength);
        if (inlineAction) {
          page.addMeasuredReaderInlineActionText(builder, rest, chapterIndex, bodyStyle, documentSource,
            absoluteStart + titleLength, inlineAction);
        } else {
          page.addMeasuredRegexReaderText(builder, rest, bodyStyle, documentSource, absoluteStart + titleLength);
        }
      }
      return;
    }
    const inlineAction = LeafFns.findMeasuredReaderInlineAction(text, documentSource, absoluteStart);
    if (inlineAction) {
      page.addMeasuredReaderInlineActionText(builder, text, chapterIndex, bodyStyle, documentSource,
        absoluteStart, inlineAction);
      return;
    }
    page.addMeasuredRegexReaderText(builder, text, bodyStyle, documentSource, absoluteStart);
}

export function addMeasuredReaderInlineActionText(page: ReadBookPage, builder: graphicsText.ParagraphBuilder, text: string, chapterIndex: number, bodyStyle: graphicsText.TextStyle, documentSource: string, absoluteStart: number, match: ReaderActionMatch): void {
    const markerStart = Math.max(0, Math.min(match.start, text.length));
    const markerEnd = Math.max(markerStart, Math.min(match.end, text.length));
    const before = text.substring(0, markerStart);
    const after = match.end <= text.length ? text.substring(markerEnd) : '';
    if (before) {
      page.addMeasuredRegexReaderText(builder, before, bodyStyle, documentSource, absoluteStart);
    }
    const actionStyle = page.buildReaderMeasureTextStyle(
      page.readerInlineSourceActionFontSize(match.marker), LeafFns.readerInlineSourceActionFontFamily());
    builder.pushStyle(actionStyle);
    builder.addText(page.readerInlineSourceActionLabel(match.marker));
    builder.popStyle();
    if (after) {
      page.addMeasuredRegexReaderText(builder, after, bodyStyle, documentSource, absoluteStart + match.end);
    }
}

export function addMeasuredRegexReaderText(page: ReadBookPage, builder: graphicsText.ParagraphBuilder, text: string, bodyStyle: graphicsText.TextStyle, documentSource: string = text, absoluteStart: number = 0): void {
    if (!page.readerRegexFontEnabled) {
      builder.pushStyle(bodyStyle);
      builder.addText(text);
      builder.popStyle();
      return;
    }
    const slices = page.getRegexTextSlicesForDocumentRange(text, documentSource, absoluteStart);
    for (const slice of slices) {
      const style = slice.highlighted ?
        page.buildReaderMeasureTextStyle(page.getRegexSliceFontSize(slice), page.getRegexSliceFontFamily(slice)) :
        bodyStyle;
      if (page.shouldUseFullThemeRegexDecoration(slice)) {
        page.addMeasuredRegexBubbleCap(builder, slice);
      }
      builder.pushStyle(style);
      builder.addText(slice.text);
      builder.popStyle();
      if (page.shouldUseFullThemeRegexDecoration(slice)) {
        page.addMeasuredRegexBubbleCap(builder, slice);
      }
    }
}

export function addMeasuredRegexBubbleCap(page: ReadBookPage, builder: graphicsText.ParagraphBuilder, slice: ReadTextSlice): void {
    const capSize = LeafFns.toMeasurePx(page.getRegexBubbleCapSize(slice));
    builder.addPlaceholder({
      width: capSize,
      height: capSize,
      align: graphicsText.PlaceholderAlignment.CENTER_OF_ROW_BOX,
      baseline: graphicsText.TextBaseline.IDEOGRAPHIC,
      baselineOffset: 0
    });
}

export function hasMeasuredThemeRegexDecoration(page: ReadBookPage, text: string, documentSource: string, absoluteStart: number): boolean {
    if (!page.readerRegexFontEnabled || !text) {
      return false;
    }
    const slices = page.getRegexTextSlicesForDocumentRange(text, documentSource, absoluteStart);
    for (const slice of slices) {
      if (page.shouldUseFullThemeRegexDecoration(slice)) {
        return true;
      }
    }
    return false;
}

export function getParagraphFallbackMeasureStyle(page: ReadBookPage, text: string, chapterIndex: number): ReaderParagraphMeasureFallback {
    if (page.shouldUseTitleStyle(text, chapterIndex)) {
      return {
        fontSize: page.readerTitleFontSize,
        fontFamily: page.getTitleReaderFontFamily()
      };
    }
    if (page.readerRegexFontEnabled) {
      const slices = page.getRegexTextSlices(text);
      for (const slice of slices) {
        if (slice.highlighted) {
          return {
            fontSize: page.getRegexSliceFontSize(slice),
            fontFamily: page.getRegexSliceFontFamily(slice)
          };
        }
      }
    }
    return {
      fontSize: page.readerFontSize,
      fontFamily: page.getBodyReaderFontFamily()
    };
}

export function getRenderedReaderParagraphLineBoxPx(page: ReadBookPage, text: string, chapterIndex: number, documentSource: string = text, absoluteStart: number = 0): number {
    // ArkUI's actual glyph row is slightly taller than the configured fp size even with font padding
    // disabled. The factor matches Text's tight row box while avoiding custom font ascent inflation.
    let lineBoxPx = LeafFns.toMeasureFontPx(page.readerFontSize) * 1.09;
    if (page.shouldUseTitleStyle(text, chapterIndex)) {
      lineBoxPx = Math.max(lineBoxPx, LeafFns.toMeasureFontPx(page.readerTitleFontSize) * 1.09);
    }
    if (page.readerRegexFontEnabled) {
      const slices = page.getRegexTextSlicesForDocumentRange(text, documentSource, absoluteStart);
      for (const slice of slices) {
        if (!slice.highlighted) continue;
        lineBoxPx = Math.max(lineBoxPx, LeafFns.toMeasureFontPx(page.getRegexSliceFontSize(slice)) * 1.09);
        if (page.shouldUseFullThemeRegexDecoration(slice)) {
          lineBoxPx = Math.max(lineBoxPx, LeafFns.toMeasurePx(page.getRegexBubbleCapSize(slice)));
        }
      }
    }
    const inlineAction = LeafFns.findMeasuredReaderInlineAction(text, documentSource, absoluteStart);
    if (inlineAction) {
      lineBoxPx = Math.max(lineBoxPx,
        LeafFns.toMeasureFontPx(page.readerInlineSourceActionFontSize(inlineAction.marker)) * 1.09);
    }
    return Math.max(1, lineBoxPx);
}
