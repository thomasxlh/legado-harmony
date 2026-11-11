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

export function getReaderPaginationBottomInfoBarHeight(page: ReadBookPage): number {
    // Chapter/page metadata is painted as an overlay. Its complete footprint is already included in
    // getReaderContentBottomReserve(), so it must not be added to pagination a second time.
    return 0;
}

export function getReaderBottomInfoBarVisualOffsetY(page: ReadBookPage): number {
    // Lift metadata completely above the gesture-navigation indicator. The matching pagination guard keeps正文
    // clear of the footer at its new visual position.
    return -page.getReaderBottomInfoBarBottomInset();
}

export function readerFloatingBarBottomMargin(page: ReadBookPage): number {
    return page.navBarHeight > 0 ? page.navBarHeight : 8;
}

export function readerFloatingBarWidth(page: ReadBookPage): number {
    const viewportWidth = page.pageViewWidth > 0 ? page.pageViewWidth : 360;
    const availableWidth = Math.max(0, viewportWidth - LeafFns.readerFloatingBarEdgeInset() * 2);
    if (page.readerUsesSideAnchoredControls()) {
      return Math.min(availableWidth, Math.min(520, Math.max(320, viewportWidth * 0.52)));
    }
    return Math.min(viewportWidth, Math.max(240, availableWidth));
}

export function readerSettingsPanelHeight(page: ReadBookPage): number {
    const viewportHeight = page.pageViewHeight > 0 ? page.pageViewHeight : 720;
    return Math.max(1, Math.min(520, viewportHeight - page.readerFloatingPanelBottomInset() - 12));
}

export function readerChapterTrackColor(page: ReadBookPage): string {
    return page.isReaderThemeDark() ? '#2EFFFFFF' : '#1F000000';
}

export function readerUsesSideAnchoredControls(page: ReadBookPage): boolean {
    const viewportWidth = page.pageViewWidth > 0 ? page.pageViewWidth : 360;
    return viewportWidth >= 600;
}

export function readerFloatingBarLeft(page: ReadBookPage): number {
    const viewportWidth = page.pageViewWidth > 0 ? page.pageViewWidth : 360;
    const barWidth = page.readerFloatingBarWidth();
    if (!page.readerUsesSideAnchoredControls()) {
      return Math.max(0, (viewportWidth - barWidth) / 2);
    }
    if (page.readerMenuAnchorSide < 0) {
      return LeafFns.readerFloatingBarEdgeInset();
    }
    return Math.max(LeafFns.readerFloatingBarEdgeInset(),
      viewportWidth - LeafFns.readerFloatingBarEdgeInset() - barWidth);
}

export function readerFloatingBarRight(page: ReadBookPage): number {
    return page.readerFloatingBarLeft() + page.readerFloatingBarWidth();
}

export function readerFloatingBarTranslateX(page: ReadBookPage): number {
    const viewportWidth = page.pageViewWidth > 0 ? page.pageViewWidth : 360;
    const centeredLeft = (viewportWidth - page.readerFloatingBarWidth()) / 2;
    return page.readerFloatingBarLeft() - centeredLeft;
}

export function readerChapterTooltipWidth(page: ReadBookPage): number {
    return Math.min(320, page.readerFloatingBarWidth() * 0.62);
}

export function readerChapterTooltipCenteredLeft(page: ReadBookPage): number {
    const viewportWidth = page.pageViewWidth > 0 ? page.pageViewWidth : 360;
    return (viewportWidth - page.readerChapterTooltipWidth()) / 2;
}

export function readerTtsQuickActionLeft(page: ReadBookPage): number {
    // 宽屏跟随点击侧（readerMenuAnchorSide），窄屏用用户设置 readerTtsQuickActionSide。
    const anchorLeft = page.readerUsesSideAnchoredControls()
      ? page.readerMenuAnchorSide < 0
      : page.readerTtsQuickActionSide < 0;
    return anchorLeft ? LeafFns.readerFloatingBarEdgeInset() : page.readerFloatingBarRight() - 48;
}

export function readerTtsExpandedControlLeft(page: ReadBookPage): number {
    // 与快捷按钮同侧停靠，避免朗读展开时控制条跳到另一侧。
    const anchorLeft = page.readerUsesSideAnchoredControls()
      ? page.readerMenuAnchorSide < 0
      : page.readerTtsQuickActionSide < 0;
    return anchorLeft ? LeafFns.readerFloatingBarEdgeInset()
      : page.readerFloatingBarRight() - LeafFns.readerTtsExpandedControlWidth();
}

export function readerBottomMenuOverlayHeight(page: ReadBookPage): number {
    return (page.readerUseChapterQuickJump ? 120 : 56) + page.readerFloatingBarBottomMargin();
}

export function readerBottomActionOverlayHeight(page: ReadBookPage): number {
    return 56 + page.readerFloatingBarBottomMargin();
}

export function readerFloatingPanelBottomInset(page: ReadBookPage): number {
    // 面板底边统一停在底部操作栏上方 4vp。
    return page.readerBottomActionOverlayHeight() + 4;
}

export function readerTocPanelHeight(page: ReadBookPage): number {
    const viewportHeight = page.pageViewHeight > 0 ? page.pageViewHeight : 720;
    const availableHeight = Math.max(1, viewportHeight - page.readerFloatingPanelBottomInset() - 12);
    const minimumHeight = Math.min(280, availableHeight);
    return Math.min(availableHeight, Math.max(minimumHeight, viewportHeight * 0.81));
}

export function getReaderContentBottomPadding(page: ReadBookPage): number {
    return Math.max(0, page.getEffectiveReaderMarginBottom() + page.getReaderContentBottomReserve());
}

export function getReaderPaginationViewportHeight(page: ReadBookPage): number {
    // pageViewHeight is reported before the declarative bottom-safe-area expansion. Extended reading
    // intentionally lets正文 use that system area, so pagination must include the same navigation inset that
    // the rendered page-turn surface receives. Do not add the top inset: the hidden status bar already starts
    // the reader at y=0, and adding it caused the previous whole-page upward shift.
    const bottomExtension = page.readerExtendToStatusBar ? Math.max(0, page.navBarHeight) : 0;
    return Math.max(1, page.pageViewHeight + bottomExtension);
}

export function getReaderBackgroundViewportHeight(page: ReadBookPage): number {
    // pageViewHeight excludes the explicit text-only status-bar inset when extension is disabled,
    // but already includes it in extended mode. Reuse the page-turn viewport calculation so the
    // static paper, simulation snapshots and curl canvas always fit the exact same full-screen rect.
    return Math.max(1, page.getPageTurnHeight());
}

export function getEffectiveReaderLineHeight(page: ReadBookPage): number {
    return page.readerFontSize + Math.max(0, page.readerLineHeight);
}

export function getReaderPageColumnWidth(page: ReadBookPage): number {
    if (!page.isLandscapeDoublePageActive()) return Math.max(1, page.pageViewWidth);
    // The divider participates in Row layout. Measuring each leaf as exactly half of the spread makes
    // pagination up to 0.5vp wider than the real Text node and can wrap one extra line at render time.
    return Math.max(1, (page.pageViewWidth - READER_DOUBLE_PAGE_DIVIDER_WIDTH) / 2);
}

export function getReaderDoublePageRightOrigin(page: ReadBookPage): number {
    return page.getReaderPageColumnWidth() + READER_DOUBLE_PAGE_DIVIDER_WIDTH;
}

export function readerTextAlignValue(page: ReadBookPage): TextAlign {
    if (page.readerTextAlign === 'start') return TextAlign.Start;
    if (page.readerTextAlign === 'end') return TextAlign.End;
    return TextAlign.JUSTIFY;
}

export function readerGraphicsTextAlignValue(page: ReadBookPage): graphicsText.TextAlign {
    if (page.readerTextAlign === 'start') return graphicsText.TextAlign.LEFT;
    if (page.readerTextAlign === 'end') return graphicsText.TextAlign.RIGHT;
    return graphicsText.TextAlign.JUSTIFY;
}

export function getReaderAdaptiveLetterSpacing(page: ReadBookPage): number {
    const availableWidth = Math.max(1,
      page.getReaderPageColumnWidth() - page.getEffectiveReaderMarginLeft() - page.getEffectiveReaderMarginRight());
    try {
      const widthPx = vp2px(availableWidth);
      // ArkUI ultimately lays a component out on physical pixels, while graphics.text accepts a floating
      // constraint. Distribute only the discarded sub-pixel fraction across a typical line. JUSTIFY still
      // performs the visible horizontal alignment; this tiny non-positive correction keeps both breakers
      // on the same line without changing the user's chosen font size.
      const snappedWidthPx = Math.floor(widthPx);
      const charsPerLine = Math.max(8, Math.floor(availableWidth / Math.max(1, page.readerFontSize)));
      const adaptiveCorrection = Math.max(-0.08, Math.min(0, px2fp((snappedWidthPx - widthPx) / charsPerLine)));
      return page.readerLetterSpacing + adaptiveCorrection;
    } catch (_) {
      return page.readerLetterSpacing;
    }
}

export function getReaderPageLineSpacing(page: ReadBookPage, pageLineHeight: number = page.getEffectiveReaderLineHeight()): number {
    return Math.max(0, pageLineHeight - page.readerFontSize);
}

export function getReaderParagraphBoundarySpacing(page: ReadBookPage, pageLineHeight: number = page.getEffectiveReaderLineHeight()): number {
    return page.getReaderPageLineSpacing(pageLineHeight) + Math.max(0, page.readerParagraphSpacing);
}

export function getMeasuredReaderParagraphBoundarySpacingPx(page: ReadBookPage): number {
    const boundaryPx = LeafFns.toMeasureNonNegativePx(page.getReaderParagraphBoundarySpacing());
    // With visible paragraph spacing every boundary is rendered as an independent Blank. ArkUI lays
    // that component on physical pixels, so a fractional height must be rounded upward rather than
    // represented by an average allowance shared by the whole page.
    return page.readerParagraphSpacing > 0 ? Math.ceil(boundaryPx) : boundaryPx;
}

export function getMeasuredReaderParagraphComponentHeightPx(page: ReadBookPage, metrics: ReaderParagraphMetrics, pageLineHeight: number = page.getEffectiveReaderLineHeight(), componentPixelAligned: boolean = false): number {
    const lineCount = Math.max(1, metrics.lineCount);
    const internalGapCount = Math.max(0, lineCount - 1);
    const shouldPixelAlignComponent = page.readerParagraphSpacing > 0 || componentPixelAligned;
    if (internalGapCount === 0) {
      return shouldPixelAlignComponent ? Math.ceil(metrics.heightPx) : metrics.heightPx;
    }
    const baseLineSpacingPx = LeafFns.toMeasureNonNegativePx(page.getReaderPageLineSpacing());
    const targetLineSpacingPx = LeafFns.toMeasureNonNegativePx(page.getReaderPageLineSpacing(pageLineHeight));
    const glyphRowsHeightPx = Math.max(0, metrics.heightPx - internalGapCount * baseLineSpacingPx);
    const componentHeightPx = glyphRowsHeightPx + internalGapCount * targetLineSpacingPx;
    // Paragraph spacing makes each paragraph an independent Text node. Its complete measured box is
    // pixel-aligned once, while line gaps inside that node remain part of the same layout object.
    return shouldPixelAlignComponent ? Math.ceil(componentHeightPx) : componentHeightPx;
}

export function getMeasuredReaderParagraphBoundarySpacingForLineHeightPx(page: ReadBookPage, pageLineHeight: number, componentBoundaryPixelAligned: boolean = false): number {
    const boundaryPx = LeafFns.toMeasureNonNegativePx(page.getReaderParagraphBoundarySpacing(pageLineHeight));
    return page.readerParagraphSpacing > 0 || componentBoundaryPixelAligned ? Math.ceil(boundaryPx) : boundaryPx;
}

export function getMeasuredReaderPageBodyHeightPx(page: ReadBookPage, metricsList: ReaderParagraphMetrics[], pageLineHeight: number, componentPixelAligned: boolean[] = []): number {
    let paragraphHeightPx = 0;
    let boundaryHeightPx = 0;
    for (let index = 0; index < metricsList.length; index++) {
      paragraphHeightPx += page.getMeasuredReaderParagraphComponentHeightPx(metricsList[index], pageLineHeight,
        componentPixelAligned[index] === true);
    }
    if (metricsList.length > 1) {
      for (let index = 0; index < metricsList.length - 1; index++) {
        boundaryHeightPx += page.getMeasuredReaderParagraphBoundarySpacingForLineHeightPx(pageLineHeight,
          componentPixelAligned[index] === true || componentPixelAligned[index + 1] === true);
      }
    }
    const heightScale = page.getReaderPaginationHeightScale();
    return paragraphHeightPx * heightScale +
      boundaryHeightPx * (page.readerParagraphSpacing > 0 ? 1 : heightScale);
}

export function getReaderAdaptivePageLineHeight(page: ReadBookPage, text: string, chapterIndex: number, pageIndex: number, pageStart: number = -1, documentSource: string = ''): number {
    const baseLineHeight = page.getEffectiveReaderLineHeight();
    if (!text || page.isReaderNovelContinuousScrollModeActive() || LeafFns.isReaderImageOnlyPage(text)) {
      return baseLineHeight;
    }
    const source = documentSource || (chapterIndex === page.currentChapterIndex ? page.pagedContentText : '');
    const resolvedStart = pageStart >= 0 ? pageStart :
      (chapterIndex === page.currentChapterIndex ? page.getPageStartOffset(pageIndex) : -1);
    if (!source || resolvedStart < 0 || LeafFns.isReaderChapterLastPage(text, resolvedStart, source)) {
      return baseLineHeight;
    }

    const horizontalPadding = page.getEffectiveReaderMarginLeft() + page.getEffectiveReaderMarginRight();
    const verticalPadding = page.getEffectiveReaderMarginTop() + page.getReaderContentBottomPadding() +
      page.getReaderPaginationBottomInfoBarHeight() + page.getReaderPaginationRenderGuardHeight();
    const columnWidth = page.getReaderPageColumnWidth();
    const availableWidth = Math.max(1, columnWidth - horizontalPadding);
    const availableHeight = Math.max(1, page.getReaderPaginationViewportHeight() - verticalPadding);
    const cacheKey = `${chapterIndex}_${pageIndex}_${resolvedStart}_${page.pageViewWidth}_${availableHeight}_` +
      `${page.readerTypographyCacheIdentity()}_${hashText(text)}`;
    const cached = page.readerAdaptiveLineHeightCache.get(cacheKey);
    if (cached !== undefined) return cached;

    const availableHeightPx = LeafFns.toMeasurePx(availableHeight);
    const paragraphs = page.getReaderTextParagraphs(text);
    const paragraphMetrics: ReaderParagraphMetrics[] = [];
    const componentPixelAligned: boolean[] = [];
    let adaptableInternalGapCount = 0;
    for (const paragraph of paragraphs) {
      const metrics = page.readerParagraphMetrics(paragraph.text, availableWidth,
        chapterIndex, source, resolvedStart + paragraph.start);
      paragraphMetrics.push(metrics);
      componentPixelAligned.push(page.readerParagraphRendersAsIndependentComponent(paragraph.text));
      // Inline comment bubbles remain part of their paragraph's Text node. Count its ordinary
      // line gaps just like plain text; only standalone action rows and images are fixed blocks.
      const standaloneAction = ReaderActionMarker.parse(paragraph.text) &&
        !page.hasInlineReaderSourceAction(paragraph.text);
      if (!standaloneAction && !LocalBookService.isEpubImageMarker(paragraph.text)) {
        const lineCount = Math.max(1, metrics.lineCount);
        adaptableInternalGapCount += Math.max(0, lineCount - 1);
      }
    }
    const measuredHeightPx = page.getMeasuredReaderPageBodyHeightPx(
      paragraphMetrics, baseLineHeight, componentPixelAligned);
    // Preserve one physical pixel for the final component snap. This is density-independent and therefore does
    // not create a visible vp reserve, but prevents a page made from many paragraph Text nodes from crossing the
    // fixed 8vp bottom boundary after ArkUI rounds its last row.
    const renderSnapGuardPx = 1;
    const remainingHeightPx = Math.max(0, availableHeightPx - measuredHeightPx - renderSnapGuardPx);
    let adaptiveLineHeight = baseLineHeight;
    // All spacing is placed strictly between text lines. Internal text gaps and paragraph boundaries
    // are the only adjustable positions; fixed action/image rows retain their measured height.
    const adaptableGapCount = adaptableInternalGapCount + Math.max(0, paragraphs.length - 1);
    if (adaptableGapCount > 0 && remainingHeightPx > 0.5) {
      const hasIndependentlyRoundedParagraph = componentPixelAligned.some((value: boolean): boolean => value);
      if (page.readerParagraphSpacing > 0 || hasIndependentlyRoundedParagraph) {
        // Each paragraph Text and boundary Blank rounds independently. Search using that same rendered
        // component model; dividing the remainder once can otherwise round every node upward and push
        // the final line through the configured bottom margin.
        let low = baseLineHeight;
        let high = baseLineHeight + Math.max(0, px2vp(remainingHeightPx / adaptableGapCount));
        for (let index = 0; index < 14; index++) {
          const middle = (low + high) / 2;
          if (page.getMeasuredReaderPageBodyHeightPx(paragraphMetrics, middle, componentPixelAligned) <=
            availableHeightPx - renderSnapGuardPx) {
            low = middle;
          } else {
            high = middle;
          }
        }
        try {
          const spacingPx = Math.floor(vp2px(page.getReaderPageLineSpacing(low)));
          adaptiveLineHeight = page.readerFontSize + px2vp(Math.max(0, spacingPx));
        } catch (_) {
          adaptiveLineHeight = low;
        }
      } else {
        adaptiveLineHeight = baseLineHeight + Math.max(0, px2vp(remainingHeightPx / adaptableGapCount));
      }
    }
    page.readerAdaptiveLineHeightCache.set(cacheKey, adaptiveLineHeight);
    while (page.readerAdaptiveLineHeightCache.size > 96) {
      const oldestKey = page.readerAdaptiveLineHeightCache.keys().next().value as string | undefined;
      if (oldestKey === undefined) break;
      page.readerAdaptiveLineHeightCache.delete(oldestKey);
    }
    return adaptiveLineHeight;
}

export function scheduleReaderLayoutChange(page: ReadBookPage): void {
    if (page.readerLayoutApplyTimerId >= 0) {
      clearTimeout(page.readerLayoutApplyTimerId);
    }
    const scheduledChapterIndex = page.currentChapterIndex;
    page.readerLayoutApplyTimerId = setTimeout(() => {
      page.readerLayoutApplyTimerId = -1;
      // 章末切换的加载窗口内不回放旧布局事务：跨章重排会清掉新章预载分页并干扰 pendingRestorePageIndex 落页。
      if (page.currentChapterIndex !== scheduledChapterIndex) {
        page.saveReaderLayoutSettings();
        page.saveReadConfig();
        return;
      }
      page.applyPendingReaderLayoutChange();
    }, 1000);
}

export function scheduleReaderTypographyChange(page: ReadBookPage): void {
    if (page.readerLayoutApplyTimerId >= 0) {
      clearTimeout(page.readerLayoutApplyTimerId);
    }
    const scheduledChapterIndex = page.currentChapterIndex;
    page.readerLayoutApplyTimerId = setTimeout(() => {
      page.readerLayoutApplyTimerId = -1;
      page.commitReaderTypographyDraft();
      if (page.currentChapterIndex !== scheduledChapterIndex) {
        page.saveReaderLayoutSettings();
        page.saveReadConfig();
        return;
      }
      page.applyPendingReaderLayoutChange();
    }, 120);
}

export function applyPendingReaderLayoutChange(page: ReadBookPage): void {
    const readingOffset = page.getReaderStableReflowOffset();
    page.setReaderTypographyRestoreOffset(readingOffset);
    page.invalidateReaderTypographyLayout();
    page.refreshReaderTextRender();
    page.paginateContent(page.content);
    page.scheduleReaderLayoutStabilization(readingOffset);
    page.preloadNextChapterPaginationLater();
    page.saveReaderLayoutSettings();
    page.saveReadConfig();
    page.saveReadingProgress();
}

export function scheduleReaderLayoutStabilization(page: ReadBookPage, readingOffset: number): void {
    if (page.readerLayoutStabilizeTimerId >= 0) clearTimeout(page.readerLayoutStabilizeTimerId);
    const chapterIndex = page.currentChapterIndex;
    const bookUrl = page.book?.bookUrl || page.bookUrl;
    const identity = `${page.readerTypographyCacheIdentity()}_${page.pageViewWidth}_` +
      `${page.getReaderPaginationViewportHeight()}_${page.readerExtendToStatusBar}`;
    page.readerLayoutStabilizeTimerId = setTimeout(() => {
      page.readerLayoutStabilizeTimerId = -1;
      const currentIdentity = `${page.readerTypographyCacheIdentity()}_${page.pageViewWidth}_` +
        `${page.getReaderPaginationViewportHeight()}_${page.readerExtendToStatusBar}`;
      if (!page.readerPageVisible || page.currentChapterIndex !== chapterIndex ||
        (page.book?.bookUrl || page.bookUrl) !== bookUrl || currentIdentity !== identity) return;
      page.setReaderTypographyRestoreOffset(readingOffset);
      page.invalidateReaderTypographyLayout();
      page.refreshReaderTextRender();
      page.paginateContent(page.content);
      page.preloadNextChapterPaginationLater();
      page.preloadPreviousChapterPaginationLater();
    }, 80);
}

export function invalidateReaderTypographyLayout(page: ReadBookPage): void {
    // A typography update changes both wrapping and component heights. Invalidate every derived layer and stop
    // cooperative batches created with the previous settings; otherwise an old background batch can publish its
    // page array after the live preview has already switched to the new geometry.
    page.finishPageTurnAnimation(false);
    // The retained NodeContainer does not reliably adopt a replacement NodeController while its keyed ForEach
    // host stays unchanged. Since the controllers below are deliberately detached, remount that host as part of
    // the same transaction; otherwise a theme/background change can leave the visible node bound to the cleared
    // controller until the next page turn publishes another surface.
    page.readerV2SurfaceGeneration++;
    page.readerPaginationWorkSerial++;
    page.adjacentPaginationPreloadSerial++;
    page.previousPaginationPreloadSerial++;
    page.readerPaginationCache.clear();
    page.readerV2PageSetCache.clear();
    page.readerV2DocumentCache.clear();
    page.readerV2SelectionStyledTextCache.clear();
    page.readerV2ActiveDocument = null;
    page.readerV2ActiveSnapshot = null;
    for (const controller of page.readerV2Controllers.values()) controller.updatePage(null);
    page.readerV2Controllers.clear();
    const selectableKeys = Array.from(page.readerSelectableTextControllers.keys());
    for (const key of selectableKeys) {
      if (key.startsWith('reader_v2_native_page_')) page.readerSelectableTextControllers.delete(key);
    }
    page.readerParagraphMetricsCache.clear();
    page.readerAdaptiveLineHeightCache.clear();
    page.readerTextParagraphsCache.clear();
    page.pageTurnPreviewKey = '';
    page.pageTurnPreviewLoadingKey = '';
    page.clearPendingReaderSourceActionBounds();
    page.readerSourceActionAreas.clear();
    page.readerSourceActionScrollOffsets.clear();
}

export function flushPendingReaderLayoutChange(page: ReadBookPage, repaginate: boolean = true): void {
    if (page.readerLayoutApplyTimerId < 0 && !page.readerTypographyDraftPending) return;
    if (page.readerLayoutApplyTimerId >= 0) clearTimeout(page.readerLayoutApplyTimerId);
    page.readerLayoutApplyTimerId = -1;
    page.commitReaderTypographyDraft();
    if (repaginate && page.readerPageVisible) {
      page.applyPendingReaderLayoutChange();
      return;
    }
    page.saveReaderLayoutSettings();
    page.saveReadConfig();
}

export function refreshReaderTextRender(page: ReadBookPage): void {
    page.pageRenderVersion++;
    page.pageTurnIncomingRenderVersion++;
}

export function forceCurrentReaderPageRender(page: ReadBookPage): void {
    page.chapterJumpRenderGeneration++;
    page.pageRenderVersion++;
}

export function cancelReaderPaginationWork(page: ReadBookPage, releaseNativeCaches: boolean): void {
    page.readerPaginationWorkSerial++;
    page.adjacentPaginationPreloadSerial++;
    page.previousPaginationPreloadSerial++;
    page.readerPaginationCache.clear();
    if (!releaseNativeCaches) return;
    page.readerV2PageSetCache.clear();
    page.readerV2DocumentCache.clear();
    page.readerV2SelectionStyledTextCache.clear();
    page.readerV2ActiveDocument = null;
    page.readerV2ActiveSnapshot = null;
    for (const controller of page.readerV2Controllers.values()) controller.updatePage(null);
    page.readerV2Controllers.clear();
    const selectableKeys = Array.from(page.readerSelectableTextControllers.keys());
    for (const key of selectableKeys) {
      if (key.startsWith('reader_v2_native_page_')) page.readerSelectableTextControllers.delete(key);
    }
}

export function applyReaderScreenOrientation(page: ReadBookPage, orientation: string = page.readerScreenOrientation): void {
    const normalized = ReaderSettingsStore.normalizeScreenOrientation(orientation);
    const serial = ++page.readerScreenOrientationSerial;
    let preferred = window.Orientation.UNSPECIFIED;
    if (normalized === ReaderSettingsStore.SCREEN_ORIENTATION_PORTRAIT) {
      preferred = window.Orientation.PORTRAIT;
    } else if (normalized === ReaderSettingsStore.SCREEN_ORIENTATION_LANDSCAPE) {
      preferred = window.Orientation.LANDSCAPE;
    }
    window.getLastWindow(page.hostContext()).then((mainWindow: window.Window) => {
      if (serial !== page.readerScreenOrientationSerial) return;
      return mainWindow.setPreferredOrientation(preferred);
    }).catch((error: Error) => {
      console.warn('应用阅读屏幕方向失败:', error);
    });
}

export function resetReaderScreenOrientation(page: ReadBookPage): void {
    page.applyReaderScreenOrientation(ReaderSettingsStore.SCREEN_ORIENTATION_SYSTEM);
}

export function syncReaderPageHeightForContentTopPadding(page: ReadBookPage): void {
    const nextTopPadding = page.getReaderPageContentTopPadding();
    // The system-bar switch itself changes the reader area's measured height. Do not pre-add/subtract the
    // same inset here: onAreaChange will publish the new text viewport, and applying both adjustments makes
    // extended mode exactly one status-bar too tall (causing the last paragraph to be clipped).
    page.readerPageContentTopPaddingSnapshot = nextTopPadding;
}

export function scheduleReaderExtendLayoutRefresh(page: ReadBookPage, readingOffset: number = -1): void {
    if (readingOffset >= 0 && page.readerExtendLayoutReadingOffset < 0) {
      page.readerExtendLayoutReadingOffset = readingOffset;
    }
    page.enterReaderImmersive();
    page.syncReaderPageHeightForContentTopPadding();
    if (page.readerEntryInitializing || !page.content || !page.hasPagedReaderArea()) return;

    // A system-bar mode change rebuilds the safe-area geometry asynchronously. Stop and invalidate
    // every old curl surface immediately; otherwise a gesture started before the new area arrives can
    // combine the old wallpaper snapshot with the new text viewport for one visibly jumping frame.
    page.invalidateReaderTypographyLayout();
    page.refreshReaderTextRender();

    if (page.readerExtendLayoutRefreshTimerId >= 0) {
      clearTimeout(page.readerExtendLayoutRefreshTimerId);
    }
    const scheduledChapterIndex = page.currentChapterIndex;
    page.readerExtendLayoutRefreshTimerId = setTimeout(() => {
      page.readerExtendLayoutRefreshTimerId = -1;
      if (!page.readerPageVisible || !page.content || page.currentChapterIndex !== scheduledChapterIndex) {
        page.readerExtendLayoutReadingOffset = -1;
        return;
      }
      const restoreOffset = page.readerExtendLayoutReadingOffset >= 0 ?
        page.readerExtendLayoutReadingOffset : page.getReaderStableReflowOffset();
      page.readerExtendLayoutReadingOffset = -1;
      page.setReaderTypographyRestoreOffset(restoreOffset);
      page.invalidateReaderTypographyLayout();
      page.refreshReaderTextRender();
      page.paginateContent(page.content);
      page.currentPageIndex = page.normalizeReaderSpreadPageIndex(page.findPageIndexByOffset(restoreOffset));
      page.syncCurrentPageText();
      page.scheduleReaderLayoutStabilization(restoreOffset);
      page.preloadNextChapterPaginationLater();
      page.preloadPreviousChapterPaginationLater();
      page.saveReadingProgress();
    }, 80);
}

export function scheduleReaderThemeRefresh(page: ReadBookPage): void {
    if (page.readerThemeRefreshOffset < 0) {
      page.readerThemeRefreshOffset = page.getReaderStableReflowOffset();
    }
    const scheduledChapterIndex = page.currentChapterIndex;
    if (page.readerThemeRefreshTimerId >= 0) {
      clearTimeout(page.readerThemeRefreshTimerId);
    }
    // EntryAbility republishes appDarkMode and themeRevision as two observable updates while applying
    // a color mode. Debounce one frame so both updates share one pagination and one retained-page rebuild.
    page.readerThemeRefreshTimerId = setTimeout(() => {
      page.readerThemeRefreshTimerId = -1;
      const readingOffset = page.readerThemeRefreshOffset >= 0 ?
        page.readerThemeRefreshOffset : page.getReaderStableReflowOffset();
      page.readerThemeRefreshOffset = -1;
      if (!page.readerPageVisible || !page.content) {
        return;
      }
      // 主题刷新捕获的偏移属于调度时的章节；章末切换后回放会把旧章深位置写进新章坐标系。
      if (page.currentChapterIndex !== scheduledChapterIndex) {
        return;
      }
      page.enterReaderImmersive();
      page.setReaderTypographyRestoreOffset(readingOffset);
      page.invalidateReaderTypographyLayout();
      page.refreshReaderTextRender();
      page.paginateContent(page.content);
      page.scheduleReaderLayoutStabilization(readingOffset);
      page.saveReadingProgress();
      if (page.showReaderCommentPanel) {
        page.syncReaderCommentPanelWebTheme();
      }
      page.onTtsCoverSettingsChanged();
    }, 32);
}

export function updateVolumeKeySubscription(page: ReadBookPage): void {
    page.unregisterVolumeKeyTurn();
    if (!page.readerVolumeTurnPage || !page.readerPageVisible || page.isTtsSpeaking ||
      page.ttsReader.isSpeaking() || ReaderTtsFloatingSession.isActive()) {
      return;
    }
    page.registerVolumeKeyTurn();
}

export function registerVolumeKeyTurn(page: ReadBookPage): void {
    page.volumeUpCallback = (_event: KeyEvent) => {
      page.handleVolumeKeyTurn(-1);
    };
    page.volumeDownCallback = (_event: KeyEvent) => {
      page.handleVolumeKeyTurn(1);
    };
    try {
      inputConsumer.on('keyPressed', {
        key: KeyCode.KEYCODE_VOLUME_UP,
        action: Action.DOWN,
        isRepeat: false
      }, page.volumeUpCallback);
      inputConsumer.on('keyPressed', {
        key: KeyCode.KEYCODE_VOLUME_DOWN,
        action: Action.DOWN,
        isRepeat: false
      }, page.volumeDownCallback);
    } catch (err) {
      console.error('注册音量键翻页失败:', err);
      page.volumeUpCallback = undefined;
      page.volumeDownCallback = undefined;
    }
}

export function unregisterVolumeKeyTurn(page: ReadBookPage): void {
    try {
      if (page.volumeUpCallback) {
        inputConsumer.off('keyPressed', page.volumeUpCallback);
      }
      if (page.volumeDownCallback) {
        inputConsumer.off('keyPressed', page.volumeDownCallback);
      }
    } catch (err) {
      console.error('取消音量键翻页失败:', err);
    }
    page.volumeUpCallback = undefined;
    page.volumeDownCallback = undefined;
}

export function handleVolumeKeyTurn(page: ReadBookPage, direction: number): void {
    if (!page.readerVolumeTurnPage || !page.readerPageVisible || page.isTtsSpeaking ||
      page.ttsReader.isSpeaking() || ReaderTtsFloatingSession.isActive() || page.showMenu || page.showToc ||
      page.showSettings || page.isLoading || page.chapters.length === 0) {
      return;
    }
    if (page.isReaderContinuousScrollSurfaceActive()) {
      page.scrollReaderComicByPage(direction);
      return;
    }
    if (direction > 0) {
      page.turnNext();
    } else {
      page.turnPrev();
    }
}

export function clampChapterIndex(page: ReadBookPage, index: number): number {
    if (page.chapters.length === 0) return 0;
    return Math.max(0, Math.min(index, page.chapters.length - 1));
}

export function getMenuChapterDisplayIndex(page: ReadBookPage): number {
    return page.menuChapterSliderActive ? page.menuChapterPreviewIndex : page.currentChapterIndex;
}

export function handleMenuChapterSliderChange(page: ReadBookPage, value: number, mode: SliderChangeMode): void {
    page.menuChapterPreviewIndex = page.clampChapterIndex(Math.round(value));
    page.menuChapterSliderActive = true;
    page.menuChapterTooltipVisible = mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving;
    if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
      page.menuChapterTooltipVisible = false;
      page.confirmMenuChapterJump(page.menuChapterPreviewIndex);
    }
}

export async function confirmMenuChapterJump(page: ReadBookPage, targetIndex: number): Promise<void> {
    if (page.menuChapterConfirming) {
      return;
    }
    const normalizedIndex = page.clampChapterIndex(targetIndex);
    if (normalizedIndex === page.currentChapterIndex) {
      page.resetMenuChapterPreview();
      return;
    }
    page.menuChapterConfirming = true;
    try {
      const result = await promptAction.showDialog({
        title: '确认跳转章节',
        message: `是否跳转到「${page.getChapterTitle(normalizedIndex)}」？`,
        buttons: [
          { text: '取消', color: page.getSubTextColor() },
          { text: '跳转', color: page.accentColor() }
        ]
      });
      if (result.index === 1) {
        await page.jumpToMenuChapter(normalizedIndex);
      } else {
        page.resetMenuChapterPreview();
      }
    } catch (error) {
      console.error('确认跳转章节失败:', error);
      page.resetMenuChapterPreview();
    } finally {
      page.menuChapterConfirming = false;
    }
}

export function resetMenuChapterPreview(page: ReadBookPage): void {
    page.menuChapterPreviewIndex = page.currentChapterIndex;
    page.menuChapterSliderActive = false;
    page.menuChapterTooltipVisible = false;
}

export async function jumpToMenuChapter(page: ReadBookPage, targetIndex: number): Promise<void> {
    const normalizedIndex = page.clampChapterIndex(targetIndex);
    if (normalizedIndex === page.currentChapterIndex) {
      page.menuChapterPreviewIndex = page.currentChapterIndex;
      page.menuChapterSliderActive = false;
      page.menuChapterTooltipVisible = false;
      return;
    }
    try {
      await page.jumpToReaderPositionKeepingTts(normalizedIndex, 0);
    } finally {
      page.menuChapterPreviewIndex = page.currentChapterIndex;
      page.menuChapterSliderActive = false;
      page.menuChapterTooltipVisible = false;
    }
}

export async function jumpToAdjacentChapterFromMenu(page: ReadBookPage, direction: number): Promise<void> {
    await page.jumpToAdjacentChapterFirstPage(direction);
    page.menuChapterPreviewIndex = page.currentChapterIndex;
    page.menuChapterSliderActive = false;
    page.menuChapterTooltipVisible = false;
}

export function restorePendingPageIndex(page: ReadBookPage, paginationComplete: boolean = true): void {
    if (page.pendingRestorePageIndex < 0) {
      return;
    }
    const maxPage = Math.max(0, page.contentPages.length - 1);
    if (!paginationComplete && page.pendingRestorePageIndex > maxPage) {
      return;
    }
    page.currentPageIndex = page.normalizeReaderSpreadPageIndex(
      Math.max(0, Math.min(page.pendingRestorePageIndex, maxPage))
    );
    page.pendingRestorePageIndex = -1;
    page.readerProgressRestoreConfirmed = true;
}

export function canSaveReadingProgress(page: ReadBookPage): boolean {
    if (page.isLoading || page.isPagedReaderAwaitingPagination() || page.pendingRestorePageIndex >= 0) {
      return false;
    }
    return page.pageViewWidth > 0 && page.pageViewHeight > 0 && page.contentPages.length > 0;
}

export function committedLocalPageTurnCheckpointPageIndex(page: ReadBookPage): number {
    // During an animated turn the incoming page is already the committed visual destination, while
    // currentPageIndex is intentionally updated only after the motion finishes. Home can freeze that handoff for
    // long enough that a lifecycle checkpoint would otherwise persist the page behind the animation (often page
    // zero). Only trust a same-chapter target owned by the current immutable pagination snapshot.
    if (!page.isPageTurning || !page.pageTurnIncomingText ||
      page.pageTurnIncomingChapterIndex !== page.currentChapterIndex) {
      return -1;
    }
    if (page.pageTurnIncomingDocumentSource &&
      page.pageTurnIncomingDocumentSource !== page.pagedContentText) {
      return -1;
    }
    const pageIndex = page.normalizeReaderSpreadPageIndex(page.pageTurnIncomingPageIndex);
    if (pageIndex < 0 || pageIndex >= page.contentPages.length) {
      return -1;
    }
    return pageIndex;
}

export function settleCommittedLocalPageTurnForCheckpoint(page: ReadBookPage): void {
    const targetPageIndex = page.committedLocalPageTurnCheckpointPageIndex();
    if (targetPageIndex < 0) return;
    // Backgrounding may suspend the animation timer indefinitely. Settle the already-accepted local turn now so
    // both a retained reader surface and a cold restart agree with the lifecycle checkpoint. The suspended async
    // turn can safely apply the same captured target again when the app resumes.
    page.currentPageIndex = targetPageIndex;
    page.readerProgressRestoreConfirmed = true;
    page.commitVisibleCurrentPageText(page.getPageText(targetPageIndex));
    page.finishPageTurnAnimation(false);
}

export async function saveReadingProgress(page: ReadBookPage, notifyShelf: boolean = false): Promise<void> {
    if (!page.book || page.chapters.length === 0) {
      return;
    }
    // A retained reader page can receive aboutToDisappear after its replacement has already attached. Its
    // snapshot belongs to the old visual page even when both instances opened the same book URL.
    if (!ReaderProgressCheckpoint.canWrite(page.ttsFloatingSessionOwnerId)) {
      console.info('[ReaderProgress] ignored save from superseded reader page');
      return;
    }
    const engine = ReadBookEngine.get();
    const stableVisibleProgress = page.canSaveReadingProgress();
    let chapterIndex = page.clampChapterIndex(page.currentChapterIndex);
    let pageIndex = Math.max(0, Math.min(page.currentPageIndex, Math.max(0, page.contentPages.length - 1)));
    let characterOffset = Math.max(0, page.getPageStartOffset(pageIndex));
    let progressPageCount = page.currentChapterProgressPageCount();
    let lastReadPageText = page.getShelfLastReadPageText(pageIndex);
    let lastReadPageImage = page.getShelfLastReadPageImage(pageIndex);
    const completedVisibleProgress = stableVisibleProgress && page.readerInitialPageReady &&
      page.pendingRestorePageIndex < 0 && !page.hasReaderTypographyRestoreOffset() &&
      page.isCurrentReaderPaginationComplete();
    if (stableVisibleProgress && (page.readerProgressRestoreConfirmed || completedVisibleProgress)) {
      // Keep an immutable visible-position anchor. During a typography/source-interaction rebuild the incremental
      // paginator temporarily owns only its first pages and marks pendingRestorePageIndex. A lifecycle checkpoint
      // in that window must save the page the user actually saw, not zero or an older database value.
      page.readerProgressAnchorChapterIndex = chapterIndex;
      page.readerProgressAnchorPageIndex = pageIndex;
      page.readerProgressAnchorOffset = characterOffset;
      page.readerProgressAnchorPageCount = progressPageCount;
      page.readerProgressAnchorPageText = lastReadPageText;
      page.readerProgressAnchorPageImage = lastReadPageImage;
    } else if (page.readerProgressAnchorChapterIndex >= 0) {
      chapterIndex = page.clampChapterIndex(page.readerProgressAnchorChapterIndex);
      pageIndex = Math.max(0, page.readerProgressAnchorPageIndex);
      characterOffset = page.readerProgressAnchorOffset;
      progressPageCount = Math.max(1, page.readerProgressAnchorPageCount);
      lastReadPageText = page.readerProgressAnchorPageText;
      lastReadPageImage = page.readerProgressAnchorPageImage;
    } else {
      return;
    }
    // 朗读进行中：阅读进度取正在朗读的句子锚点，而不是当前页状态。后台宿主（侧滑返回
    // 书架后的旧阅读页实例）卸载后自动翻页动画停摆，currentPageIndex 停留在退出页；
    // 用它保存会让“书架听书一段时间→关闭浮标→重进阅读页”回退到旧页（页数未更新）。
    // 句级偏移与页恢复（findPageIndexByOffset）兼容，落点即最后朗读句所在页。
    if (page.isTtsSpeaking && !page.isTtsPaused) {
      const ttsChapterRaw = page.book.getVariable('ttsReadChapterIndex');
      const ttsOffsetRaw = page.book.getVariable('ttsReadOffsetStart');
      const ttsChapter = Number(ttsChapterRaw);
      const ttsOffset = Number(ttsOffsetRaw);
      if (ttsChapterRaw && ttsOffsetRaw && Number.isFinite(ttsChapter) &&
        Math.round(ttsChapter) === chapterIndex && Number.isFinite(ttsOffset) && ttsOffset >= 0) {
        const anchorOffset = Math.round(ttsOffset);
        const anchorPageIndex = page.normalizeReaderSpreadPageIndex(page.findPageIndexByOffset(anchorOffset));
        if (anchorPageIndex >= 0 && anchorPageIndex < page.contentPages.length) {
          pageIndex = anchorPageIndex;
          lastReadPageText = page.getShelfLastReadPageText(pageIndex);
          lastReadPageImage = page.getShelfLastReadPageImage(pageIndex);
        }
        characterOffset = anchorOffset;
      }
    }
    if (!Book.hasStartedReading(page.book) && chapterIndex <= 0 && pageIndex <= 0) {
      if (engine.book?.bookUrl === page.book.bookUrl) {
        engine.curIdx = chapterIndex;
        engine.curPos = pageIndex;
      }
      return;
    }
    page.book.durChapterIndex = chapterIndex;
    page.book.durChapterPos = pageIndex;
    const now = Date.now();
    page.book.durChapterTitle = page.chapters[chapterIndex]?.title || page.book.durChapterTitle;
    page.book.durChapterTime = now;
    page.book.putVariable('readStarted', '1');
    page.book.putVariable('lastReadTime', `${now}`);
    page.book.putVariable('readProgressChapterIndex', `${chapterIndex}`);
    page.book.putVariable('readProgressPageCount', `${progressPageCount}`);
    if (characterOffset >= 0) {
      page.book.putVariable(READER_PROGRESS_OFFSET_KEY, `${characterOffset}`);
      page.book.putVariable(READER_PROGRESS_OFFSET_CHAPTER_KEY, `${chapterIndex}`);
    }
    // The old reader page can finish an asynchronous save after the next book has
    // already opened. Never let that stale page replace the singleton engine's book.
    if (engine.book?.bookUrl === page.book.bookUrl) {
      engine.curIdx = chapterIndex;
      engine.curPos = pageIndex;
      engine.book = page.book;
    }
    const bookUrl = page.book.bookUrl;
    const chapterTitle = page.book.durChapterTitle;
    // 正文片段/图片已移入本地快照表。这里剥离旧版本或云端下行行残留的这两个键，
    // 防止 1600 字符正文继续随 books 行上云（云空间占用随同步次数累积的根因）。
    page.book.removeVariable('lastReadPageText');
    page.book.removeVariable('lastReadPageImage');
    const variable = page.book.variable;
    const snapshotPageText = lastReadPageText;
    const snapshotPageImage = lastReadPageImage;
    const syncRelevant = !!page.book.origin && page.book.origin !== 'local';
    const shouldRefreshRecentCard = chapterIndex !== page.lastRecentReadCardChapterIndex;
    page.lastRecentReadCardChapterIndex = chapterIndex;
    const previous = page.readingProgressSaveQueue.catch(() => {
    });
    const next = previous.then(async () => {
      if (!ReaderProgressCheckpoint.canWrite(page.ttsFloatingSessionOwnerId)) {
        console.info('[ReaderProgress] ignored queued save from superseded reader page');
        return;
      }
      const db = AppDatabase.getInstance();
      await db.updateBookReadingProgress(
        bookUrl, chapterTitle, chapterIndex, pageIndex, now, variable, syncRelevant);
      // Shelf "continue reading" preview lives in a local-only table so the page body
      // text never rides the synced books row up to cloud space.
      await db.saveBookShelfSnapshot(bookUrl, snapshotPageText, snapshotPageImage);
      // Page turns are saved frequently, while the retained bookshelf page is still alive underneath the reader.
      // Publishing shelfUpdateTime here would rebuild every hidden shelf card and decode all theme cover fallbacks on
      // every turn. Persist the progress immediately, but notify the shelf only when leaving the reader.
      if (notifyShelf) AppStorage.setOrCreate('shelfUpdateTime', Date.now());
      if (notifyShelf || shouldRefreshRecentCard) {
        page.reloadRecentReadCardLater(shouldRefreshRecentCard);
      }
    });
    page.readingProgressSaveQueue = next;
    try {
      await next;
    } catch (e) {
      console.error('保存阅读进度失败:', e);
    }
}

export function reloadRecentReadCardLater(page: ReadBookPage, force: boolean = false): void {
    const now = Date.now();
    if (!force && now - page.lastRecentReadCardReloadAt < 30000) {
      return;
    }
    page.lastRecentReadCardReloadAt = now;
    const context = page.hostContext() as common.UIAbilityContext;
    setTimeout(() => {
      RecentReadCardUpdater.reload(context).catch((err: Error) => {
        console.error('刷新最近阅读卡片失败:', err);
      });
    }, 0);
}

export function currentChapterProgressPageCount(page: ReadBookPage): number {
    if (page.contentPages.length === 0) {
      return 0;
    }
    if (page.hasPagedReaderArea() && page.pagedContentText) {
      const pagination = page.getCachedReaderPagination(page.currentChapterIndex, page.pagedContentText);
      if (pagination && !pagination.complete) {
        // 增量分页尚未完成时，总页数并不可靠；下一次翻页或离开页面时会重新保存。
        return 0;
      }
    }
    return page.contentPages.length;
}

export function getShelfLastReadPageText(page: ReadBookPage, pageIndex: number): string {
    const pageText = ReaderActionMarker.strip(
      LocalBookService.stripEpubImageMarkers(page.getPageText(pageIndex) || '', false), false
    )
      .replace(/\r\n?/g, '\n')
      .replace(/[ \t]+\n/g, '\n')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
    return (pageText || '（图片页）').substring(0, 1600);
}

export function handleTtsExpandedControl(page: ReadBookPage, index: number): void {
    if (index === 0) {
      page.cycleTtsSleepTimer();
    } else if (index === 1 && page.canPlayPreviousTtsChapter()) {
      page.playPreviousChapterFromMediaSession();
    } else if (index === 2) {
      page.toggleTtsReading();
      page.showMenu = true;
    } else if (index === 3 && page.canPlayNextTtsChapter()) {
      page.playNextChapterFromMediaSession();
    } else if (index === 4) {
      page.cycleTtsSpeed();
    } else if (index === 5) {
      page.ttsMediaControlsExpanded = false;
      page.showMenu = true;
      page.syncTtsSystemMediaControls();
    }
}

export function cycleTtsSleepTimer(page: ReadBookPage): void {
    const options: number[] = [0, 15, 30, 60, 90, 120];
    const currentIndex = options.indexOf(page.ttsSleepTimerMinutes);
    const nextMinutes = options[(currentIndex + 1) % options.length];
    page.setTtsSleepTimer(nextMinutes);
}

export function setTtsSleepTimer(page: ReadBookPage, minutes: number): void {
    page.clearTtsSleepTimer();
    if (minutes <= 0) {
      HdsFeedback.showToast('已关闭朗读定时');
      return;
    }
    page.ttsSleepTimerMinutes = minutes;
    page.ttsSleepTimerRemainingSeconds = minutes * 60;
    page.updateTtsFloatingSession();
    page.ttsSleepTimerEndAt = Date.now() + minutes * 60 * 1000;
    page.ttsSleepTimerId = setInterval(() => {
      const remaining = Math.max(0, Math.ceil((page.ttsSleepTimerEndAt - Date.now()) / 1000));
      page.ttsSleepTimerRemainingSeconds = remaining;
      ReaderTtsFloatingSession.updateTimer(
        page.ttsFloatingSessionOwnerId, page.ttsSleepTimerMinutes, remaining);
      if (remaining <= 0) {
        page.clearTtsSleepTimer();
        page.stopTtsReading();
        HdsFeedback.showToast('朗读定时结束，已停止朗读');
      }
    }, 1000);
    HdsFeedback.showToast(`将在 ${minutes} 分钟后停止朗读`);
}

export function clearTtsSleepTimer(page: ReadBookPage): void {
    if (page.ttsSleepTimerId >= 0) {
      clearInterval(page.ttsSleepTimerId);
      page.ttsSleepTimerId = -1;
    }
    page.ttsSleepTimerEndAt = 0;
    page.ttsSleepTimerMinutes = 0;
    page.ttsSleepTimerRemainingSeconds = 0;
    page.updateTtsFloatingSession();
}

export function cycleTtsSpeed(page: ReadBookPage): void {
    const speeds: number[] = [0.8, 1.0, 1.2, 1.5, 2.0, 3.0];
    let nextIndex = speeds.findIndex((speed: number) => speed > page.ttsSpeed + 0.01);
    if (nextIndex < 0) {
      nextIndex = 0;
    }
    page.applyTtsSpeed(speeds[nextIndex]);
    HdsFeedback.showToast(`朗读倍速 ${speeds[nextIndex].toFixed(1)}x`);
}

export function shouldShowTtsMediaControls(page: ReadBookPage): boolean {
    return !page.isReaderComicModeActive() && page.ttsMediaControlsExpanded &&
      (page.isTtsSpeaking || page.ttsReader.isSpeaking()) &&
      page.showMenu && !page.showToc && !page.showSettings && !page.shouldBlockReaderInteraction();
}

export function canPlayPreviousTtsChapter(page: ReadBookPage): boolean {
    return page.chapters.length > 0 && page.currentChapterIndex > 0;
}

export function canPlayNextTtsChapter(page: ReadBookPage): boolean {
    return page.chapters.length > 0 && page.currentChapterIndex < page.chapters.length - 1;
}

export function disabledButtonColor(page: ReadBookPage): string {
    return page.isReaderThemeDark() ? '#44515A66' : '#C8CDD4';
}

export function canHandleReaderPageTurnPan(page: ReadBookPage): boolean {
    return !page.showMenu && !page.showToc && !page.showSettings &&
      page.chapters.length > 0 && !page.isReaderInteractiveActionActive();
}

export function handleReaderPagedContentClick(page: ReadBookPage, event: ClickEvent): void {
    if (page.consumeSuppressedReaderTapClick() || page.showMenu || page.showToc || page.showSettings ||
      page.shouldBlockReaderInteraction()) {
      return;
    }
    const x = Number(event.x);
    const y = Number(event.y);
    if (page.readerEffectivePageTurnMode() === 1) {
      page.updateReaderMenuAnchorByPoint(x);
      page.showMenu = true;
      return;
    }
    page.commitReaderTapByPoint(x, y);
}

export function handleReaderPanStart(page: ReadBookPage, event: GestureEvent): void {
    if (page.readerPageTurnGestureCommitted) {
      return;
    }
    if (!page.canHandleReaderPageTurnPan()) {
      return;
    }
    page.captureReaderCurlStartRegion(event);
    page.readerPanActive = true;
    page.deferReaderPaginationForInteraction();
    page.readerTouchMoved = false;
    page.suppressReaderTapClick = false;
    page.slideResetSerial++;
}

export function canHandleBookmarkPull(page: ReadBookPage, offsetX: number, offsetY: number): boolean {
    return page.readerQuickBookmarkEnabled && page.readerEffectivePageTurnMode() !== 0 &&
      offsetY >= page.readerBookmarkPullStartDistance &&
      offsetY > Math.abs(offsetX) * page.readerBookmarkPullDirectionRatio;
}

export function bookmarkPullCommitDistance(page: ReadBookPage): number {
    const viewportHeight = page.pageViewHeight > 0 ? page.pageViewHeight : 640;
    return Math.max(160, Math.min(220, viewportHeight * 0.24));
}

export function canCommitBookmarkPull(page: ReadBookPage, offsetX: number, offsetY: number): boolean {
    return page.readerQuickBookmarkEnabled && page.readerEffectivePageTurnMode() !== 0 &&
      offsetY >= page.bookmarkPullCommitDistance() &&
      offsetY > Math.abs(offsetX) * page.readerBookmarkPullDirectionRatio;
}

export function updateBookmarkPullEffect(page: ReadBookPage, offsetX: number, offsetY: number): void {
    page.bookmarkPullActive = true;
    const effectiveOffset = Math.max(0, offsetY - page.readerBookmarkPullStartDistance);
    page.bookmarkPullOffsetY = Math.min(128, effectiveOffset * 0.65);
    page.bookmarkPullReady = page.canCommitBookmarkPull(offsetX, offsetY);
    page.readerTouchMoved = true;
    page.suppressReaderTapClick = true;
    page.pageSlideOffsetX = 0;
    page.pageSlideOffsetY = 0;
    page.pageSlideDirection = 0;
}

export function finishBookmarkPull(page: ReadBookPage, commit: boolean): void {
    const shouldToggle = commit && page.bookmarkPullReady;
    page.bookmarkPullReady = false;
    page.bookmarkPullActive = false;
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      page.bookmarkPullOffsetY = 0;
    });
    if (shouldToggle) {
      page.toggleCurrentPageBookmark();
    }
}

export function handleReaderPanUpdate(page: ReadBookPage, event: GestureEvent): void {
    if (page.readerPageTurnGestureCommitted) {
      return;
    }
    if (!page.canHandleReaderPageTurnPan()) {
      return;
    }
    if (!page.readerPanActive) {
      page.handleReaderPanStart(event);
    }
    const offsetX = event.offsetX;
    const offsetY = event.offsetY;
    if (page.isPageTurning) {
      if (page.isReaderTouchMoved(offsetX, offsetY)) {
        page.readerTouchMoved = true;
        page.suppressReaderTapClick = true;
      }
      return;
    }
    if (page.bookmarkPullActive || page.canHandleBookmarkPull(offsetX, offsetY)) {
      page.updateBookmarkPullEffect(offsetX, offsetY);
      return;
    }
    if (!page.isPageTurnAnimationEnabled()) {
      return;
    }
    if (page.isReaderTouchMoved(offsetX, offsetY)) {
      page.readerTouchMoved = true;
      page.suppressReaderTapClick = true;
    }
    page.updateSlidePageEffect(page.getReaderPageTurnGestureOffset(offsetX, offsetY));
}

export function handleReaderPanEnd(page: ReadBookPage, event: GestureEvent): void {
    if (!page.readerPanActive) {
      return;
    }
    page.readerPanActive = false;
    page.deferReaderPaginationForInteraction();
    if (page.bookmarkPullActive) {
      page.readerTouchMoved = true;
      page.suppressReaderTapClick = true;
      page.finishBookmarkPull(page.canCommitBookmarkPull(event.offsetX, event.offsetY));
      return;
    }
    const offsetX = event.offsetX;
    const offsetY = event.offsetY;
    const axisVelocity = page.isVerticalPageTurnAnimation() ? event.velocityY : event.velocityX;
    const releasedVelocity = Number.isFinite(axisVelocity) ? Math.abs(axisVelocity) : 0;
    if (page.isReaderPageTurnCommitGesture(offsetX, offsetY, releasedVelocity)) {
      page.readerTouchMoved = true;
      page.suppressReaderTapClick = true;
      page.commitReaderMove(offsetX, offsetY, releasedVelocity);
      return;
    }
    if (page.readerTouchMoved || page.isReaderTouchMoved(offsetX, offsetY)) {
      page.suppressReaderTapClick = true;
      page.rollbackSlidePageEffect();
      return;
    }
    page.resetSlidePageEffect();
}

export function handleReaderPanCancel(page: ReadBookPage): void {
    if (!page.readerPanActive) {
      return;
    }
    page.readerPanActive = false;
    page.deferReaderPaginationForInteraction();
    if (page.bookmarkPullActive) {
      page.suppressReaderTapClick = true;
      page.finishBookmarkPull(false);
      return;
    }
    if (Math.abs(page.getPageSlideAxisOffset()) > 0.5) {
      page.suppressReaderTapClick = true;
      page.rollbackSlidePageEffect();
      return;
    }
    page.resetSlidePageEffect();
}

export function handleReaderTouch(page: ReadBookPage, event: TouchEvent): void {
    if (page.showMenu || page.showToc || page.showSettings || page.chapters.length === 0) {
      return;
    }
    page.resetAutoPageTurnCountdown();
    const point = event.changedTouches && event.changedTouches.length > 0 ? event.changedTouches[0] :
      (event.touches && event.touches.length > 0 ? event.touches[0] : null);
    if (!point) {
      return;
    }
    if (Date.now() < page.readerTextSelectionUntil) {
      page.readerTouchActive = false;
      page.readerPanActive = false;
      page.suppressReaderTapClick = true;
      return;
    }
    const x = point.x;
    const y = point.y;
    const globalX: number = Number(point.x) + page.readerTapLayerGlobalX;
    const globalY: number = Number(point.y) + page.readerTapLayerGlobalY;
    // TouchObject.x/y are reported in window coordinates on current HarmonyOS devices even when the listener is
    // attached to the full-page interaction layer. V2 geometry is page-local, so derive that coordinate from the
    // explicit window point and the measured interaction-layer origin. This also remains correct in split screen.
    const readerLocalX = Number(point.windowX) - page.readerTapLayerGlobalX;
    const readerLocalY = Number(point.windowY) - page.readerTapLayerGlobalY - page.readerV2SurfaceTopOffset();
    if (event.type === TouchType.Down) {
      page.deferReaderPaginationForInteraction();
      // A fresh pointer stream must not inherit the short click guard from the previous source action.
      page.readerInteractiveActionUntil = 0;
      page.readerTouchActionMarker = '';
      page.readerInlineTouchActionMarker = '';
      page.updateReaderMenuAnchorByPoint(x);
      page.readerTouchStartX = x;
      page.readerTouchStartY = y;
      page.readerTouchLastX = x;
      page.readerTouchLastY = y;
      page.readerTouchActive = true;
      page.readerPageTurnGestureCommitted = false;
      page.readerGestureTurnGuardUntil = 0;
      page.readerGestureTurnAllowance = 0;
      page.readerTouchMoved = false;
      page.suppressReaderTapClick = false;
      page.readerSelectionDismissArmed = page.hasReaderTextSelection();
      page.slideResetSerial++;
      // An explicitly rendered action owns its exact hit region. Page-turn tap zones only run
      // when no action was hit, so justified line-end comments remain accessible near an edge.
      const actionMarker = page.shouldUseReaderLayoutV2(page.pagedContentText) ?
        page.readerV2ActionAtLocalPoint(readerLocalX, readerLocalY) :
        page.readerSourceActionAtPoint(globalX, globalY);
      if (actionMarker) {
        page.readerTouchActionMarker = actionMarker;
        page.beginReaderInteractiveAction();
        return;
      }
      return;
    }
    const sourceActionTouchActive = !!page.readerTouchActionMarker || !!page.readerInlineTouchActionMarker;
    if (page.isReaderInteractiveActionActive() && !sourceActionTouchActive) {
      page.readerTouchActive = false;
      page.suppressReaderTapClick = true;
      page.resetSlidePageEffect();
      return;
    }
    if (sourceActionTouchActive && event.type === TouchType.Move) {
      page.readerTouchLastX = x;
      page.readerTouchLastY = y;
      const offsetX = x - page.readerTouchStartX;
      const offsetY = y - page.readerTouchStartY;
      if (page.isReaderTouchMoved(offsetX, offsetY)) {
        page.readerTouchActionMarker = '';
        page.readerInlineTouchActionMarker = '';
        page.readerInteractiveActionUntil = 0;
        page.readerTouchActive = true;
        page.readerTouchMoved = true;
        page.suppressReaderTapClick = true;
        if (!page.readerPanActive && page.canHandleReaderPageTurnPan()) {
          page.readerPanActive = true;
          page.slideResetSerial++;
        }
      }
      return;
    }
    if (page.readerTouchActionMarker) {
      if (event.type === TouchType.Up) {
        const marker = page.readerTouchActionMarker;
        page.readerTouchActionMarker = '';
        page.beginReaderInteractiveAction();
        // The action already claimed this pointer on Down. Move handling above clears that claim once the
        // gesture exceeds the page tap slop, so requiring a second exact hit on Up only makes small comment
        // pills intermittently fail when a real finger drifts by a few pixels. Commit the surviving owner.
        page.openReaderSourceAction(marker);
      } else if (event.type === TouchType.Cancel) {
        page.readerTouchActionMarker = '';
      }
      return;
    }
    if (!page.readerTouchActive) {
      return;
    }
    if (event.type === TouchType.Move) {
      page.readerTouchLastX = x;
      page.readerTouchLastY = y;
      const offsetX = x - page.readerTouchStartX;
      const offsetY = y - page.readerTouchStartY;
      if (!page.isPageTurnAnimationEnabled()) {
        return;
      }
      if (page.isReaderTouchMoved(offsetX, offsetY)) {
        page.readerTouchMoved = true;
        page.suppressReaderTapClick = true;
      }
      // PanGesture owns page-turn progress. Drawing from Touch.Move too rendered every
      // physical move twice and let Touch.Up race PanGesture.onActionEnd.
      return;
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      page.readerTouchLastX = x;
      page.readerTouchLastY = y;
      page.readerTouchActive = false;
      page.deferReaderPaginationForInteraction();
      if (page.isPageTurnAnimationEnabled()) {
        return;
      }
      page.finishReaderHorizontalTouch(event.type === TouchType.Up);
    }
}

export async function jumpToReaderPositionKeepingTts(page: ReadBookPage, targetChapterIndex: number, targetPageIndex: number): Promise<void> {
    if (page.isMirroringActiveTtsForCurrentBook()) {
      await ReaderTtsFloatingSession.jumpToPosition(
        page.clampChapterIndex(targetChapterIndex), Math.max(0, Math.round(targetPageIndex)));
      return;
    }
    const wasPaused = page.isTtsSessionManuallyPaused();
    const sessionActive = page.isTtsSpeaking || page.ttsReader.isSpeaking();
    const shouldResume = sessionActive && !wasPaused;
    if (sessionActive) {
      if (shouldResume) {
        page.stopTtsReaderForChapterSwitch();
        await page.updateTtsAvSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_BUFFERING);
      } else {
        page.prepareTtsForManualPageTurn();
      }
    }
    page.currentPageIndex = Math.max(0, targetPageIndex);
    page.pendingRestorePageIndex = page.currentPageIndex;
    await page.loadContent(false, page.clampChapterIndex(targetChapterIndex));
    await page.saveReadingProgress();
    if (shouldResume) {
      await page.startTtsReadingFromCurrentPosition(false);
    } else if (wasPaused) {
      page.scheduleTtsResumeAfterManualPageTurn();
      await page.updateTtsAvSessionPlaybackState(avSession.PlaybackState.PLAYBACK_STATE_PAUSE);
    }
}

export function updateReaderMenuAnchorByPoint(page: ReadBookPage, x: number): void {
    if (!page.readerUsesSideAnchoredControls()) {
      return;
    }
    const viewportWidth = Math.max(1, page.pageViewWidth || page.getPageTurnWidth());
    page.readerMenuAnchorSide = x < viewportWidth / 2 ? -1 : 1;
}

export function finishReaderHorizontalTouch(page: ReadBookPage, canCommitTap: boolean = true): void {
    const offsetX = page.readerTouchLastX - page.readerTouchStartX;
    const offsetY = page.readerTouchLastY - page.readerTouchStartY;
    if (page.isReaderPageTurnCommitGesture(offsetX, offsetY)) {
      page.readerTouchMoved = true;
      page.suppressReaderTapClick = true;
      page.commitReaderMove(offsetX, offsetY);
      return;
    }
    if (page.readerTouchMoved || page.isReaderTouchMoved(offsetX, offsetY)) {
      page.suppressReaderTapClick = true;
      page.rollbackSlidePageEffect();
      return;
    }
    if (canCommitTap && !page.isPageTurnAnimationEnabled() && page.commitReaderTapByPoint(page.readerTouchLastX,
      page.readerTouchLastY)) {
      page.suppressReaderTapClick = true;
      page.resetSlidePageEffect();
      return;
    }
    page.resetSlidePageEffect();
}

export function commitReaderTapByPoint(page: ReadBookPage, x: number, y: number): boolean {
    if (page.isReaderInteractiveActionActive()) {
      return true;
    }
    if (page.hasReaderTextSelection()) {
      // Same arming rule as consumeSuppressedReaderTapClick: only a press that started on an existing
      // selection may dismiss it. The release of the press that created the selection ends here
      // untouched, so holding the long press longer than the 900ms guard still keeps the menu alive.
      if (page.readerSelectionDismissArmed) {
        page.scheduleReaderTextSelectionClear();
      }
      return true;
    }
    if (page.isPageTurnAnimationEnabled() && page.readerEffectivePageTurnMode() !== 0 &&
      page.readerEffectivePageTurnMode() !== 2) {
      return false;
    }
    const width = Math.max(1, page.pageViewWidth || page.getPageTurnWidth());
    const height = Math.max(1, page.pageViewHeight || page.getPageTurnHeight());
    if (page.readerEffectivePageTurnMode() === 2) {
      return page.commitReaderTapZone(page.getTapZoneIndex(x, y, width, height));
    }
    if (y < height * 0.3) {
      page.turnPrev();
      return true;
    }
    if (y > height * 0.7) {
      page.turnNext();
      return true;
    }
    if (x < width / 3) {
      page.turnPrev();
      return true;
    }
    if (x > width * 2 / 3) {
      page.turnNext();
      return true;
    }
    page.updateReaderMenuAnchorByPoint(x);
    page.showMenu = true;
    return true;
}
