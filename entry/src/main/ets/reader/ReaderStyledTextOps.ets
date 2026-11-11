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

export function getReaderTextParagraphGroups(page: ReadBookPage, text: string): ReaderTextParagraphGroup[] {
    const paragraphs = page.getReaderTextParagraphs(text);
    const groups: ReaderTextParagraphGroup[] = [];
    let mergeableParagraphs: ReaderTextParagraph[] = [];
    // 滚动模式把连续的普通段落合并进同一个 Text：该 Text 同时是长按选择的主体，
    // 跨段选择与显示层共用同一布局（对齐横向 V2 整页选中层的思路）。分块按字符数切分、
    // 不做高度贴合，合并不影响分页边界。
    const mergeAcrossParagraphs = page.isReaderNovelContinuousScrollModeActive();
    const flushMergeableParagraphs = (): void => {
      if (mergeableParagraphs.length === 0) return;
      groups.push({
        paragraphs: mergeableParagraphs,
        mergeable: true,
        key: `merged_${mergeableParagraphs[0].index}_${mergeableParagraphs[mergeableParagraphs.length - 1].index}`
      });
      mergeableParagraphs = [];
    };
    for (const paragraph of paragraphs) {
      // Paragraph-comment pills are inline spans in the same Text as ordinary content. Keeping them in a
      // merged group makes ArkUI use one line breaker and one pixel-aligned text box for the whole page,
      // instead of changing the page geometry merely because comments are enabled. Other source actions
      // remain independent controls because their interaction semantics are not paragraph annotations.
      if (page.readerParagraphRendersAsIndependentComponent(paragraph.text)) {
        flushMergeableParagraphs();
        groups.push({
          paragraphs: [paragraph],
          mergeable: false,
          key: `special_${paragraph.key}`
        });
      } else {
        mergeableParagraphs.push(paragraph);
        if (!mergeAcrossParagraphs) flushMergeableParagraphs();
      }
    }
    flushMergeableParagraphs();
    return groups;
}

export function readerParagraphRendersAsIndependentComponent(page: ReadBookPage, text: string): boolean {
    if (LocalBookService.isEpubImageMarker(text) || !!ReaderActionMarker.parse(text)) {
      return true;
    }
    const inlineAction = page.readerInlineSourceActionMatch(text);
    return !!inlineAction && !LeafFns.isReaderParagraphCommentAction(inlineAction.data);
}

export function mergedReaderParagraphText(page: ReadBookPage, paragraphs: ReaderTextParagraph[]): string {
    return paragraphs.map((paragraph: ReaderTextParagraph) => {
      if (!page.hasInlineReaderSourceAction(paragraph.text)) return paragraph.text;
      return `${page.readerInlineSourceActionText(paragraph.text)}${page.readerInlineSourceActionLabel(paragraph.text)}`;
    }).join('\n');
}

export function rememberMergedReaderInlineSourceActionAreas(page: ReadBookPage, paragraphs: ReaderTextParagraph[], selectableKey: string, pageIdentity: string, area: Area): void {
    const left = Number(area.globalPosition.x);
    const top = Number(area.globalPosition.y);
    const width = parseAreaDimension(area.width);
    const height = parseAreaDimension(area.height);
    if (!Number.isFinite(left) || !Number.isFinite(top) || width <= 0 || height <= 0) return;
    page.readerPendingMergedActionBounds.set(selectableKey, {
      paragraphs: paragraphs,
      selectableKey: selectableKey,
      left: left,
      top: top,
      pageIdentity: pageIdentity,
      attempts: 0
    });
    page.scheduleReaderSourceActionBoundsFlush();
}

export function registerMergedReaderInlineSourceActionBounds(page: ReadBookPage, task: ReaderMergedActionBoundsTask, visibleText: string): boolean {
    let hasVisibleMarker = false;
    for (const paragraph of task.paragraphs) {
      const match = page.readerInlineSourceActionMatch(paragraph.text);
      if (match && visibleText.includes(match.marker)) {
        hasVisibleMarker = true;
        break;
      }
    }
    if (!hasVisibleMarker) return true;
    try {
      const manager = page.readerSelectableTextController(task.selectableKey).getLayoutManager();
      if (!manager) {
        if (task.attempts >= 7) console.warn('合并正文段评布局尚未就绪，点击区域注册失败');
        return false;
      }
      let cursor = 0;
      for (let paragraphIndex = 0; paragraphIndex < task.paragraphs.length; paragraphIndex++) {
        const paragraph = task.paragraphs[paragraphIndex];
        const bodyText = page.hasInlineReaderSourceAction(paragraph.text) ?
          page.readerInlineSourceActionText(paragraph.text) : paragraph.text;
        const label = page.hasInlineReaderSourceAction(paragraph.text) ?
          page.readerInlineSourceActionLabel(paragraph.text) : '';
        if (label) {
          const match = page.readerInlineSourceActionMatch(paragraph.text);
          if (match && visibleText.includes(match.marker)) {
            const labelStart = cursor + bodyText.length;
            const labelEnd = labelStart + label.length;
            const boxes: graphicsText.TextBox[] = manager.getRectsForRange({ start: labelStart, end: labelEnd },
              graphicsText.RectWidthStyle.TIGHT, graphicsText.RectHeightStyle.MAX);
            for (const box of boxes) {
              const localLeft = px2vp(box.rect.left);
              const localTop = px2vp(box.rect.top);
              const localRight = px2vp(box.rect.right);
              const localBottom = px2vp(box.rect.bottom);
              page.rememberReaderSourceActionBounds(match.marker, task.left + localLeft, task.top + localTop,
                task.left + localRight, task.top + localBottom);
            }
          }
        }
        cursor += bodyText.length + label.length;
        if (paragraphIndex < task.paragraphs.length - 1) cursor++;
      }
      return true;
    } catch (error) {
      if (task.attempts >= 7) console.warn('合并正文段评点击区域计算失败:', error);
      return false;
    }
}

export function hasInlineReaderSourceAction(page: ReadBookPage, text: string): boolean {
    const match = page.readerInlineSourceActionMatch(text);
    return !!match && (match.start > 0 || match.end < (text || '').length);
}

export function readerInlineSourceActionMatch(page: ReadBookPage, text: string): ReaderActionMatch | null {
    const source = text || '';
    const cached = page.readerActionMatchCache.get(source);
    if (cached) return cached;
    const match = ReaderActionMarker.findFirst(source);
    if (!match) return null;
    page.readerActionMatchCache.set(source, match);
    while (page.readerActionMatchCache.size > 192) {
      const oldest = page.readerActionMatchCache.keys().next().value as string | undefined;
      if (oldest === undefined) break;
      page.readerActionMatchCache.delete(oldest);
    }
    return match;
}

export function readerInlineActionTextController(page: ReadBookPage, text: string): TextController {
    const match = page.readerInlineSourceActionMatch(text);
    const key = match ? match.marker : text;
    let controller = page.readerInlineActionTextControllers.get(key);
    if (!controller) {
      controller = new TextController();
      page.readerInlineActionTextControllers.set(key, controller);
      while (page.readerInlineActionTextControllers.size > 80) {
        const oldest = page.readerInlineActionTextControllers.keys().next().value as string | undefined;
        if (!oldest) break;
        page.readerInlineActionTextControllers.delete(oldest);
      }
    }
    return controller;
}

export function handleReaderInlineActionTextTouch(page: ReadBookPage, text: string, event: TouchEvent): void {
    const match = page.readerInlineSourceActionMatch(text);
    if (!match) return;
    const point = event.changedTouches && event.changedTouches.length > 0 ? event.changedTouches[0] :
      (event.touches && event.touches.length > 0 ? event.touches[0] : null);
    if (!point) return;
    const hit = page.isReaderInlineActionTextPoint(text, Number(point.x), Number(point.y));
    if (event.type === TouchType.Down) {
      page.readerInlineTouchActionMarker = hit ? match.marker : '';
      if (hit) page.beginReaderInteractiveAction();
      return;
    }
    if (event.type === TouchType.Up) {
      const marker = page.readerInlineTouchActionMarker;
      page.readerInlineTouchActionMarker = '';
      if (hit && marker === match.marker) {
        page.beginReaderInteractiveAction();
        page.openReaderSourceAction(marker);
      }
      return;
    }
    if (event.type === TouchType.Cancel) page.readerInlineTouchActionMarker = '';
}

export function isReaderInlineActionTextPoint(page: ReadBookPage, text: string, x: number, y: number): boolean {
    const match = page.readerInlineSourceActionMatch(text);
    if (!match) return false;
    const bounds = page.readerInlineActionLocalBounds(text, page.readerInlineActionExpectedWidth(),
      page.pageViewHeight);
    for (let index = 0; index + 3 < bounds.length; index += 4) {
      if (x >= bounds[index] - page.readerSourceActionHitSlopX &&
        x <= bounds[index + 2] + page.readerSourceActionHitSlopX &&
        y >= bounds[index + 1] - page.readerSourceActionHitSlopY &&
        y <= bounds[index + 3] + page.readerSourceActionHitSlopY) {
        return true;
      }
    }
    try {
      const manager = page.readerInlineActionTextController(text).getLayoutManager();
      const lineCount = manager.getLineCount();
      if (lineCount <= 0) return false;
      const layoutEnd = manager.getLineMetrics(lineCount - 1).endIndex;
      const labelLength = page.readerInlineSourceActionLabel(text).length;
      const position = manager.getGlyphPositionAtCoordinate(x, y).position;
      return position >= Math.max(0, layoutEnd - labelLength - 1) && position <= layoutEnd;
    } catch (_) {
      return false;
    }
}

export function readerInlineActionExpectedWidth(page: ReadBookPage): number {
    const spreadWidth = page.getReaderPageColumnWidth();
    return Math.max(1, spreadWidth - page.getEffectiveReaderMarginLeft() - page.getEffectiveReaderMarginRight());
}

export function readerInlineActionLocalBounds(page: ReadBookPage, text: string, componentWidth: number, componentHeight: number): number[] {
    const match = page.readerInlineSourceActionMatch(text);
    if (!match) return [];
    try {
      const manager = page.readerInlineActionTextController(text).getLayoutManager();
      const lineCount = manager.getLineCount();
      if (lineCount <= 0) return [];
      const lastMetric = manager.getLineMetrics(lineCount - 1);
      const layoutEnd = lastMetric.endIndex;
      const labelLength = page.readerInlineSourceActionLabel(text).length;
      const labelStart = Math.max(0, layoutEnd - labelLength);
      const boxes: graphicsText.TextBox[] = manager.getRectsForRange({ start: labelStart, end: layoutEnd },
        graphicsText.RectWidthStyle.TIGHT, graphicsText.RectHeightStyle.MAX);
      const rawBounds: number[] = [];
      for (const box of boxes) {
        if (box.rect.right > box.rect.left && box.rect.bottom > box.rect.top) {
          rawBounds.push(box.rect.left, box.rect.top, box.rect.right, box.rect.bottom);
        }
      }
      if (rawBounds.length === 0) {
        const estimatedWidth = Math.min(lastMetric.width,
          LeafFns.toMeasurePx(Math.max(28, labelLength * page.readerInlineSourceActionFontSize(text) * 0.58)));
        const top = Math.max(0, lastMetric.baseline - lastMetric.ascent);
        rawBounds.push(Math.max(lastMetric.left, lastMetric.left + lastMetric.width - estimatedWidth), top,
          lastMetric.left + lastMetric.width, top + lastMetric.height);
      }
      let maxRight = 0;
      let maxBottom = 0;
      for (let index = 0; index + 3 < rawBounds.length; index += 4) {
        maxRight = Math.max(maxRight, rawBounds[index + 2]);
        maxBottom = Math.max(maxBottom, rawBounds[index + 3]);
      }
      const pxCoordinates = (componentWidth > 0 && maxRight > componentWidth * 1.5) ||
        (componentHeight > 0 && maxBottom > componentHeight * 1.5);
      if (!pxCoordinates) return rawBounds;
      const bounds: number[] = [];
      for (const value of rawBounds) {
        try {
          bounds.push(px2vp(value));
        } catch (_) {
          bounds.push(value);
        }
      }
      return bounds;
    } catch (_) {
      return [];
    }
}

export function rememberReaderInlineSourceActionArea(page: ReadBookPage, text: string, pageIdentity: string, area: Area): void {
    const match = page.readerInlineSourceActionMatch(text);
    if (!match) return;
    const left = Number(area.globalPosition.x);
    const top = Number(area.globalPosition.y);
    const width = parseAreaDimension(area.width);
    const height = parseAreaDimension(area.height);
    if (!Number.isFinite(left) || !Number.isFinite(top) || width <= 0 || height <= 0) return;
    page.readerPendingInlineActionBounds.set(match.marker, {
      text: text,
      marker: match.marker,
      left: left,
      top: top,
      width: width,
      height: height,
      pageIdentity: pageIdentity,
      attempts: 0
    });
    page.scheduleReaderSourceActionBoundsFlush();
}

export function clearPendingReaderSourceActionBounds(page: ReadBookPage): void {
    page.readerPendingInlineActionBounds.clear();
    page.readerPendingMergedActionBounds.clear();
}

export function scheduleReaderSourceActionBoundsFlush(page: ReadBookPage, delayMs: number = 0): void {
    if (page.readerSourceActionBoundsFlushPending) return;
    page.readerSourceActionBoundsFlushPending = true;
    setTimeout(() => {
      page.readerSourceActionBoundsFlushPending = false;
      page.flushPendingReaderSourceActionBounds();
    }, delayMs);
}

export function flushPendingReaderSourceActionBounds(page: ReadBookPage): void {
    if (page.isPageTurning || page.pageTurnAnimating || page.pageSlideDirection !== 0) {
      page.scheduleReaderSourceActionBoundsFlush(72);
      return;
    }
    const visibleText = page.visibleCurrentPageText();
    const actionDocumentText = page.isReaderNovelContinuousScrollModeActive() ?
      (page.pagedContentText || page.content) : visibleText;
    const inlineRetries: ReaderInlineActionBoundsTask[] = [];
    const mergedRetries: ReaderMergedActionBoundsTask[] = [];
    let remainingBudget = 6;
    for (const entry of page.readerPendingInlineActionBounds.entries()) {
      if (remainingBudget <= 0) break;
      const marker = entry[0];
      const task = entry[1];
      page.readerPendingInlineActionBounds.delete(marker);
      if (actionDocumentText.includes(marker)) {
        const registered = page.registerReaderInlineSourceActionBounds(task.text, task.marker, task.left, task.top,
          task.width, task.height);
        if (!registered && task.attempts < 8) {
          task.attempts++;
          inlineRetries.push(task);
        } else if (!registered) {
          console.warn('正文段评布局尚未就绪，点击区域注册失败');
        }
      }
      remainingBudget--;
    }
    if (remainingBudget > 0) {
      for (const entry of page.readerPendingMergedActionBounds.entries()) {
        if (remainingBudget <= 0) break;
        const selectableKey = entry[0];
        const task = entry[1];
        page.readerPendingMergedActionBounds.delete(selectableKey);
        const registered = page.registerMergedReaderInlineSourceActionBounds(task, actionDocumentText);
        if (!registered && task.attempts < 8) {
          task.attempts++;
          mergedRetries.push(task);
        }
        remainingBudget--;
      }
    }
    for (const task of inlineRetries) page.readerPendingInlineActionBounds.set(task.marker, task);
    for (const task of mergedRetries) page.readerPendingMergedActionBounds.set(task.selectableKey, task);
    if (page.readerPendingInlineActionBounds.size > 0 || page.readerPendingMergedActionBounds.size > 0) {
      page.scheduleReaderSourceActionBoundsFlush(16);
    }
}

export function registerReaderInlineSourceActionBounds(page: ReadBookPage, text: string, marker: string, left: number, top: number, width: number, height: number): boolean {
    if (!marker || !Number.isFinite(left) || !Number.isFinite(top)) return true;
    const localBounds = page.readerInlineActionLocalBounds(text,
      width > 0 ? width : page.readerInlineActionExpectedWidth(), height > 0 ? height : page.pageViewHeight);
    if (localBounds.length < 4) return false;
    const globalBounds: number[] = [];
    for (let index = 0; index + 3 < localBounds.length; index += 4) {
      globalBounds.push(left + localBounds[index], top + localBounds[index + 1],
        left + localBounds[index + 2], top + localBounds[index + 3]);
    }
    page.readerSourceActionAreas.set(marker, globalBounds);
    return true;
}

export function readerInlineSourceActionParagraphData(page: ReadBookPage, paragraph: ReaderTextParagraph): ReaderTextParagraph {
    const text = page.readerInlineSourceActionText(paragraph.text);
    return {
      text: text,
      start: paragraph.start,
      end: paragraph.start + text.length,
      index: paragraph.index,
      isLast: paragraph.isLast,
      key: `${paragraph.key}_inline_${LeafFns.buildTextSliceKey(text)}`
    };
}

export function readerInlineSourceActionText(page: ReadBookPage, text: string): string {
    const match: ReaderActionMatch | null = page.readerInlineSourceActionMatch(text);
    if (!match) return text || '';
    return `${text.substring(0, match.start)}${text.substring(match.end)}`;
}

export function readerInlineSourceActionLabel(page: ReadBookPage, text: string): string {
    const match: ReaderActionMatch | null = page.readerInlineSourceActionMatch(text);
    if (!match) return '';
    const count = (match.data.label || '').match(/(99\+|\d+)\s*$/);
    // Counts use their actual 1/2/3-cell width inside the paragraph. Values above 99 are capped at 99+
    // so large provider counts remain bounded without forcing every smaller pill to the largest width.
    const prefix = '\u2060\u00A0\u00A0◌\u00A0';
    const suffix = '\u00A0\u00A0';
    if (count && count[1]) {
      const rawCount = count[1];
      const numericCount = rawCount === '99+' ? 100 : Number.parseInt(rawCount, 10);
      const label = !Number.isFinite(numericCount) || numericCount <= 0 ? '0' :
        (numericCount > 99 ? '99+' : `${Math.round(numericCount)}`);
      return `${prefix}${label}${suffix}`;
    }
    if (/本章说/.test(match.data.label || '')) return `${prefix}本章说${suffix}`;
    return /段评|评论/.test(match.data.label || '') ? `${prefix}段评${suffix}` : `${prefix}${suffix}`;
}

export function readerInlineSourceActionFontSize(page: ReadBookPage, text: string): number {
    if (!page.readerUsesConfiguredCommentBubble(text)) return Math.max(10, page.readerFontSize - 5);
    return page.readerSourceSettingEnabled('气泡增大') ? Math.max(12, page.readerFontSize - 2) :
      Math.max(10, page.readerFontSize - 5);
}

export function readerInlineSourceActionFontColor(page: ReadBookPage, text: string): string {
    if (!page.readerUsesConfiguredCommentBubble(text)) {
      return page.isReaderThemeDark() ? '#B8D6FF' : '#2A6FCC';
    }
    return page.readerSourceColorSetting('段评字体颜色', '#A7A7A7');
}

export function readerInlineSourceActionBackgroundColor(page: ReadBookPage, text: string): string {
    if (!page.readerUsesConfiguredCommentBubble(text)) {
      return page.isReaderThemeDark() ? '#263A5066' : '#142A6FCC';
    }
    return page.readerSourceColorSetting('段评填充颜色', '#00000000');
}

export function readerInlineSourceActionRadius(page: ReadBookPage, text: string): number {
    if (!page.readerUsesConfiguredCommentBubble(text)) return 9;
    const style = page.readerSourceSettingValue('段评样式') || '0';
    if (style === '3' || style === '4') return 3;
    if (style === '0' || style === '2') return 6;
    return 12;
}

export function readerInlineSourceActionTextShadow(page: ReadBookPage, text: string): ShadowOptions {
    if (!page.readerUsesConfiguredCommentBubble(text)) {
      return { radius: 0, color: '#00000000', offsetX: 0, offsetY: 0 };
    }
    return {
      radius: 0.8,
      color: page.readerSourceColorSetting('段评边框颜色', '#A7A7A7'),
      offsetX: 0,
      offsetY: 0
    };
}

export function readerUsesConfiguredCommentBubble(page: ReadBookPage, text: string): boolean {
    const match = page.readerInlineSourceActionMatch(text);
    if (!match || !/段评|评论|本章说/.test(match.data.label || '')) return false;
    const source = LeafFns.currentReaderSource();
    if (!source) return false;
    page.ensureReaderSourceSettingCache(source);
    return page.readerSourceHasCommentBubbleScript || !!page.readerSourceSettingValue('段评样式');
}

export function readerSourceSettingValue(page: ReadBookPage, key: string): string {
    const source = LeafFns.currentReaderSource();
    if (!source || !key) return '';
    page.ensureReaderSourceSettingCache(source);
    return BookSourceRuntimeSnapshotStore.get(source).getString(key);
}

export function ensureReaderSourceSettingCache(page: ReadBookPage, source: BookSource): void {
    const snapshot = BookSourceRuntimeSnapshotStore.get(source);
    const sourceKey = source.bookSourceUrl || source.bookSourceName || '__anonymous_source__';
    const contentRule = source.contentRule?.content || '';
    const jsLib = source.jsLib || '';
    if (page.readerSourceSettingCacheKey === sourceKey &&
      page.readerSourceSettingCacheRevision === snapshot.signature &&
      page.readerSourceSettingCacheContentRule === contentRule &&
      page.readerSourceSettingCacheJsLib === jsLib) {
      return;
    }
    page.readerSourceSettingCacheKey = sourceKey;
    page.readerSourceSettingCacheRevision = snapshot.signature;
    page.readerSourceSettingCacheContentRule = contentRule;
    page.readerSourceSettingCacheJsLib = jsLib;
    page.readerSourceHasCommentBubbleScript = contentRule.includes('段评样式') || jsLib.includes('段评样式');
}

export function readerSourceSettingEnabled(page: ReadBookPage, key: string): boolean {
    return BookSourceSettingValue.state(page.readerSourceSettingValue(key)) > 0;
}

export function readerSourceColorSetting(page: ReadBookPage, key: string, fallback: string): string {
    const value = page.readerSourceSettingValue(key).trim();
    if (!value) return fallback;
    if (value.toLowerCase() === 'transparent') return '#00000000';
    return /^#[0-9a-f]{3,8}$/i.test(value) ? value : fallback;
}

export function beginReaderInteractiveAction(page: ReadBookPage): void {
    page.readerInteractiveActionUntil = Date.now() + 700;
    page.deferReaderPaginationForInteraction(700);
    page.suppressReaderTapClick = true;
    page.readerTouchActive = false;
    page.readerPanActive = false;
}

export function setReaderTextSelectionActive(page: ReadBookPage, active: boolean): void {
    const next = active && page.isReaderNovelContinuousScrollModeActive();
    if (page.readerTextSelectionActive === next) return;
    page.readerTextSelectionActive = next;
    if (!next) return;
    // Once long press owns the pointer, neither the List nor the parallel chapter-boundary pan may consume handle
    // drags. Cancel any partial boundary feedback produced before the long-press threshold was reached.
    page.cancelReaderComicPan();
    page.readerTouchActive = false;
    page.readerPanActive = false;
    page.suppressReaderTapClick = true;
}

export function hasReaderTextSelection(page: ReadBookPage): boolean {
    return page.readerTextSelectionActive ||
      page.readerV2NativeSelectionFragmentIndex >= 0 ||
      page.readerV2SelectionDisplayStart >= 0;
}

export function handleReaderSelectionDismissTouch(page: ReadBookPage, event: TouchEvent): boolean {
    if (!page.hasReaderTextSelection()) {
      return false;
    }
    const point = event.changedTouches && event.changedTouches.length > 0 ? event.changedTouches[0] :
      (event.touches && event.touches.length > 0 ? event.touches[0] : null);
    if (!point) {
      return false;
    }
    const windowX = Number(point.windowX);
    const windowY = Number(point.windowY);
    const globalX = Number.isFinite(windowX) ? windowX : Number(point.x) + page.readerTapLayerGlobalX;
    const globalY = Number.isFinite(windowY) ? windowY : Number(point.y) + page.readerTapLayerGlobalY;
    if (!Number.isFinite(globalX) || !Number.isFinite(globalY)) {
      return false;
    }
    if (event.type === TouchType.Down) {
      page.readerSelectionDismissDownX = globalX;
      page.readerSelectionDismissDownY = globalY;
      page.readerSelectionDismissDownAt = Date.now();
      page.readerSelectionDismissMoved = false;
      page.readerSelectionDismissArmed = true;
      return true;
    }
    if (event.type === TouchType.Move) {
      if (Math.abs(globalX - page.readerSelectionDismissDownX) > page.readerTapSlop ||
        Math.abs(globalY - page.readerSelectionDismissDownY) > page.readerTapSlop) {
        page.readerSelectionDismissMoved = true;
      }
      return true;
    }
    if (event.type === TouchType.Up) {
      const moved = page.readerSelectionDismissMoved;
      const armed = page.readerSelectionDismissArmed;
      const duration = Date.now() - page.readerSelectionDismissDownAt;
      page.readerSelectionDismissDownX = -1;
      page.readerSelectionDismissDownY = -1;
      page.readerSelectionDismissMoved = false;
      page.readerSelectionDismissArmed = false;
      if (armed && !moved && duration < 380) {
        page.scheduleReaderTextSelectionClear();
      }
      return true;
    }
    page.readerSelectionDismissArmed = false;
    return true;
}

export function isReaderInteractiveActionActive(page: ReadBookPage): boolean {
    return Date.now() < page.readerInteractiveActionUntil;
}

export function rememberReaderSourceActionArea(page: ReadBookPage, marker: string, area: Area): void {
    const position = area.globalPosition;
    page.rememberReaderSourceActionBounds(marker, Number(position.x), Number(position.y),
      Number(position.x) + Number(area.width), Number(position.y) + Number(area.height));
}

export function rememberReaderSourceActionBounds(page: ReadBookPage, marker: string, left: number, top: number, right: number, bottom: number): void {
    if (!marker || !Number.isFinite(left) || !Number.isFinite(top) || !Number.isFinite(right) ||
      !Number.isFinite(bottom) || right <= left || bottom <= top) return;
    const values = page.readerSourceActionAreas.get(marker) || [];
    for (let index = 0; index + 3 < values.length; index += 4) {
      if (Math.abs(values[index] - left) < 1 && Math.abs(values[index + 1] - top) < 1 &&
        Math.abs(values[index + 2] - right) < 1 && Math.abs(values[index + 3] - bottom) < 1) return;
    }
    values.push(left, top, right, bottom);
    const scrollOffsets = page.readerSourceActionScrollOffsets.get(marker) || [];
    scrollOffsets.push(page.currentContinuousReaderScrollOffset());
    while (values.length > 48) {
      values.splice(0, 4);
      if (scrollOffsets.length > 0) scrollOffsets.shift();
    }
    page.readerSourceActionAreas.set(marker, values);
    page.readerSourceActionScrollOffsets.set(marker, scrollOffsets);
    // A comment-heavy chapter can expose well over 40 actions at once. Evicting the earliest
    // registrations here makes the still-visible comments at the beginning of the chapter untappable.
    // The map is cleared with the reader document/chapter lifecycle, so retain a full practical chapter.
    while (page.readerSourceActionAreas.size > 512) {
      const oldest = page.readerSourceActionAreas.keys().next().value as string | undefined;
      if (!oldest) break;
      page.readerSourceActionAreas.delete(oldest);
      page.readerSourceActionScrollOffsets.delete(oldest);
    }
}

export function rememberReaderTapLayerArea(page: ReadBookPage, area: Area): void {
    page.readerTapLayerGlobalX = Number(area.globalPosition.x);
    page.readerTapLayerGlobalY = Number(area.globalPosition.y);
}

export function currentContinuousReaderScrollOffset(page: ReadBookPage): number {
    if (!page.isReaderNovelContinuousScrollModeActive()) return 0;
    // onAreaChange 在滚动期间随位置变化逐帧触发，可见块的两个 Text 每帧都会记录区域。
    // currentOffset() 是同步原生查询；同一帧内的回调共享一次读取即可，8ms 窗口内复用。
    const now = Date.now();
    if (now - page.readerContinuousScrollOffsetMemoAt < 8) {
      return page.readerContinuousScrollOffsetMemo;
    }
    try {
      const offset = Number(page.readerComicScroller.currentOffset().yOffset);
      page.readerContinuousScrollOffsetMemo = Number.isFinite(offset) ? offset : 0;
    } catch (_) {
      page.readerContinuousScrollOffsetMemo = 0;
    }
    page.readerContinuousScrollOffsetMemoAt = now;
    return page.readerContinuousScrollOffsetMemo;
}

export function rememberContinuousReaderPointer(page: ReadBookPage, event: TouchEvent): void {
    const point = event.changedTouches && event.changedTouches.length > 0 ? event.changedTouches[0] :
      (event.touches && event.touches.length > 0 ? event.touches[0] : null);
    if (!point) return;
    const windowX = Number(point.windowX);
    const windowY = Number(point.windowY);
    const globalX = Number.isFinite(windowX) ? windowX : Number(point.x) + page.readerTapLayerGlobalX;
    const globalY = Number.isFinite(windowY) ? windowY : Number(point.y) + page.readerTapLayerGlobalY;
    if (!Number.isFinite(globalX) || !Number.isFinite(globalY)) return;
    page.readerContinuousPointerGlobalX = globalX;
    page.readerContinuousPointerGlobalY = globalY;
    page.readerContinuousPointerAt = Date.now();
    if (!page.isReaderNovelContinuousScrollModeActive()) return;
    if (page.hasReaderTextSelection()) {
      page.readerContinuousSelectionMoved = true;
      page.cancelContinuousReaderSelectionTimer();
      // The selection owns this pointer stream: a short tap dismisses it, a drag adjusts the native
      // range. Neither may reach the List, the chapter-boundary pan or the tap zones.
      page.handleReaderSelectionDismissTouch(event);
      return;
    }
    if (event.type === TouchType.Down) {
      page.readerSelectionDismissArmed = false;
      page.cancelContinuousReaderSelectionTimer();
      page.readerContinuousSelectionDownX = globalX;
      page.readerContinuousSelectionDownY = globalY;
      page.readerContinuousSelectionDownAt = Date.now();
      page.readerContinuousSelectionMoved = false;
      page.readerContinuousSelectionTimerId = setTimeout(() => {
        page.readerContinuousSelectionTimerId = -1;
        if (!page.readerPageVisible || !page.isReaderNovelContinuousScrollModeActive()) return;
        page.selectReaderTextAtPoint(page.readerContinuousSelectionDownX, page.readerContinuousSelectionDownY);
      }, 420);
      return;
    }
    if (event.type === TouchType.Move &&
      (Math.abs(globalX - page.readerContinuousSelectionDownX) > page.readerTapSlop ||
       Math.abs(globalY - page.readerContinuousSelectionDownY) > page.readerTapSlop)) {
      page.readerContinuousSelectionMoved = true;
      page.cancelContinuousReaderSelectionTimer();
      return;
    }
    if (event.type === TouchType.Up) {
      page.cancelContinuousReaderSelectionTimer();
      const duration = Date.now() - page.readerContinuousSelectionDownAt;
      if (!page.readerContinuousSelectionMoved && duration < 380) {
        page.handleContinuousReaderShortTap(globalX, globalY);
      }
      return;
    }
    if (event.type === TouchType.Cancel) {
      page.readerContinuousSelectionMoved = true;
      page.cancelContinuousReaderSelectionTimer();
    }
}

export function handleContinuousReaderShortTap(page: ReadBookPage, globalX: number, globalY: number): void {
    if (page.hasReaderTextSelection()) {
      page.scheduleReaderTextSelectionClear();
      return;
    }
    const marker = page.readerSourceActionAtPoint(globalX, globalY);
    if (marker) {
      page.beginReaderInteractiveAction();
      page.openReaderSourceAction(marker);
      return;
    }
    if (page.consumeSuppressedReaderTapClick()) return;
    if (Date.now() >= page.readerComicSuppressClickUntil &&
      !page.showMenu && !page.showToc && !page.showSettings) {
      page.showMenu = true;
    }
}

export function cancelContinuousReaderSelectionTimer(page: ReadBookPage): void {
    if (page.readerContinuousSelectionTimerId < 0) return;
    clearTimeout(page.readerContinuousSelectionTimerId);
    page.readerContinuousSelectionTimerId = -1;
}

export function readerContinuousGesturePoint(page: ReadBookPage, event: GestureEvent): number[] {
    if (Date.now() - page.readerContinuousPointerAt <= 1200 &&
      Number.isFinite(page.readerContinuousPointerGlobalX) && Number.isFinite(page.readerContinuousPointerGlobalY)) {
      return [page.readerContinuousPointerGlobalX, page.readerContinuousPointerGlobalY];
    }
    if (event.fingerList && event.fingerList.length > 0) {
      const finger = event.fingerList[0];
      const x = Number(finger.globalX);
      const y = Number(finger.globalY);
      if (Number.isFinite(x) && Number.isFinite(y)) return [x, y];
    }
    return [];
}

export function readerSourceActionAtPoint(page: ReadBookPage, globalX: number, globalY: number): string {
    const visibleText = page.isReaderNovelContinuousScrollModeActive() ?
      (page.pagedContentText || page.content) : page.visibleCurrentPageText();
    for (const entry of page.readerSourceActionAreas.entries()) {
      const marker = entry[0];
      const bounds = entry[1];
      const scrollOffsets = page.readerSourceActionScrollOffsets.get(marker) || [];
      const currentScrollOffset = page.currentContinuousReaderScrollOffset();
      if (!visibleText.includes(marker) || bounds.length < 4) continue;
      for (let index = 0; index + 3 < bounds.length; index += 4) {
        const registeredScrollOffset = scrollOffsets[Math.floor(index / 4)] || 0;
        const scrollDelta = currentScrollOffset - registeredScrollOffset;
        const top = bounds[index + 1] - scrollDelta;
        const bottom = bounds[index + 3] - scrollDelta;
        if (globalX >= bounds[index] - page.readerSourceActionHitSlopX &&
          globalX <= bounds[index + 2] + page.readerSourceActionHitSlopX &&
          globalY >= top - page.readerSourceActionHitSlopY &&
          globalY <= bottom + page.readerSourceActionHitSlopY) {
          return marker;
        }
      }
    }
    return '';
}

export function openReaderSourceAction(page: ReadBookPage, marker: string): void {
    const now = Date.now();
    if (now - page.readerSourceActionOpenedAt < 500) return;
    const action: ReaderActionData | null = ReaderActionMarker.parse(marker);
    const source = LeafFns.currentReaderSource();
    if (action && source) {
      action.url = ReaderInteractionProviderRegistry.expandAction(source, action.url);
    }
    if (action && source && ReaderActionMarker.sourceScript(action.url)) {
      page.openReaderSourceScriptAction(source, action, marker);
      return;
    }
    if (!action || !/^https?:\/\//i.test(action.url)) {
      HdsFeedback.showToast('书源操作地址无效');
      return;
    }
    page.readerSourceActionOpenedAt = now;
    const title = action.title || action.label || '网页内容';
    const commentMode = LeafFns.isReaderCommentAction(action);
    if (commentMode) {
      if (source) {
        VerificationSupport.requestVerification(action.url, title, source);
      }
      page.openReaderCommentPanel(action.url, title, marker);
      return;
    }
    if (source) {
      VerificationSupport.requestVerification(action.url, title, source);
    }
    router.pushUrl({
      url: 'pages/VerifyWeb',
      params: {
        url: action.url,
        title: title,
        requireLoginCookie: 'false',
        readerCommentMode: 'false'
      }
    }).catch((error: Error) => {
      page.readerSourceActionOpenedAt = 0;
      console.error('打开网页失败:', error);
      HdsFeedback.showToast(`打开失败：${error.message || '路由跳转异常'}`);
    });
}

export async function openReaderSourceScriptAction(page: ReadBookPage, source: BookSource, action: ReaderActionData, marker: string): Promise<void> {
    const code = ReaderActionMarker.sourceScript(action.url);
    if (!code || !page.book) {
      HdsFeedback.showToast('书源操作无效');
      return;
    }
    const runtime = BookSourceStageWebRuntime.get();
    if (!await runtime.waitUntilAvailable(8000)) {
      HdsFeedback.showToast('书源脚本运行环境未就绪');
      return;
    }
    const request = new StageWebRuntimeRequest();
    // Reader action scripts communicate through side effects (java.showBrowser setting the
    // requestedUrl) and legitimately return nothing. The CONTENT stage treats an empty script
    // result as a failed content extraction and throws, so run actions in their own stage that
    // keeps the same request budget without that rule.
    request.applyStageBudget(SourceRuntimeStage.READER_ACTION);
    request.source = source;
    request.book = page.book;
    request.chapter = page.chapters.length > 0 ? page.chapters[page.clampChapterIndex(page.currentChapterIndex)] : null;
    request.baseUrl = request.chapter?.url || page.book.bookUrl || source.bookSourceUrl;
    request.code = code;
    request.readerActionMode = true;
    request.maxRequestCount = 3;
    request.maxResponseBytes = 2 * 1024 * 1024;
    request.maxTotalResponseBytes = 3 * 1024 * 1024;
    page.readerSourceActionOpenedAt = Date.now();
    try {
      const result = await runtime.execute(request);
      const target = (result.requestedUrl || '').trim();
      if (!/^https?:\/\//i.test(target)) {
        HdsFeedback.showToast('书源操作未返回有效地址');
        page.readerSourceActionOpenedAt = 0;
        return;
      }
      VerificationSupport.requestVerification(target, action.title || action.label || '段评', source);
      page.openReaderCommentPanel(target, action.title || action.label || '段评', marker,
        result.requestedHtml || '');
    } catch (error) {
      page.readerSourceActionOpenedAt = 0;
      const message = error instanceof Error ? error.message : String(error || '');
      // Content cached by an older app version can carry markers whose embedded script was
      // truncated by the old extraction regex. The runtime then fails at parse time; point the
      // reader at the chapter refresh instead of a bare script error.
      const staleScript = /SyntaxError|Unexpected|invalid|未终止|脚本执行失败/i.test(message);
      HdsFeedback.showToast(`评论加载失败${message ? `：${message}` : ''}` + (staleScript ? '\n本章正文可能是旧版缓存，请在目录中刷新本章后重试' : ''));
    }
}

export function openReaderCommentPanel(page: ReadBookPage, url: string, title: string, marker: string, sourceHtml: string = ''): void {
    if (!WebRuntimeAvailability.isAvailable()) {
      // 段评面板依赖 ArkWeb；宿主缺失时挂载 Web 会抛错并白屏，直接拒绝打开。
      HdsFeedback.showToast('当前设备不支持网页组件，无法打开段评');
      return;
    }
    const normalizedUrl = (url || '').trim();
    if (!/^https?:\/\//i.test(normalizedUrl)) {
      HdsFeedback.showToast('评论地址无效');
      return;
    }
    page.readerSourceActionOpenedAt = Date.now();
    page.readerCommentPanelLoadSerial++;
    if (page.readerCommentPanelReadyTimerId >= 0) {
      clearTimeout(page.readerCommentPanelReadyTimerId);
      page.readerCommentPanelReadyTimerId = -1;
    }
    page.readerCommentPanelTitle = title || '段评';
    page.readerCommentPanelHeightRatio = 0.6;
    page.readerCommentPanelHeightValue = page.readerCommentPanelHeightForRatio(0.6);
    page.readerCommentPanelDragStartRatio = 0.6;
    const providerPanel = ReaderInteractionProviderRegistry.buildPanel(normalizedUrl);
    if (sourceHtml) {
      page.readerCommentPanelHtmlLoaded = false;
      page.readerCommentPanelHtml = sourceHtml;
      page.readerCommentPanelBaseUrl = normalizedUrl;
      page.readerCommentPanelUrl = 'about:blank';
    } else if (providerPanel) {
      page.readerCommentPanelHtmlLoaded = false;
      page.readerCommentPanelHtml = providerPanel.html;
      page.readerCommentPanelBaseUrl = providerPanel.baseUrl;
      page.readerCommentPanelUrl = 'about:blank';
    } else {
      page.readerCommentPanelHtml = '';
      page.readerCommentPanelBaseUrl = '';
      page.readerCommentPanelUrl = normalizedUrl;
    }
    page.readerCommentPanelMarker = marker;
    page.readerCommentPanelProgress = 0;
    page.readerCommentPanelLoading = true;
    const markerBottom = page.getReaderSourceActionAnchorBottom(marker);
    page.readerCommentPanelAnchorBottom = markerBottom > 0 ? markerBottom :
      (page.readerCommentPageAreaTop >= 0 ? (page.readerCommentPageAreaTop + page.readerCommentPageAreaHeight) : -1);
    page.showReaderCommentPanel = true;
}

export function loadReaderCommentPanelHtmlIfNeeded(page: ReadBookPage): boolean {
    if (!page.showReaderCommentPanel || !page.readerCommentPanelHtml || page.readerCommentPanelHtmlLoaded) {
      return false;
    }
    page.readerCommentPanelHtmlLoaded = true;
    try {
      const baseUrl = page.readerCommentPanelBaseUrl || 'about:blank';
      page.readerCommentPanelController.loadData(page.readerCommentPanelHtml, 'text/html', 'UTF-8', baseUrl, baseUrl);
      // Some ArkWeb versions do not emit a second onPageEnd for loadData. The embedded page owns its
      // network loading state, so reveal it after the document has been handed to the controller.
      page.scheduleReaderCommentPanelHostReady(180);
      return true;
    } catch (error) {
      page.readerCommentPanelHtmlLoaded = false;
      console.warn('加载原生评论面板失败:', error);
      page.scheduleReaderCommentPanelHostReady(0);
      return false;
    }
}

export function scheduleReaderCommentPanelHostReady(page: ReadBookPage, delayMs: number): void {
    if (page.readerCommentPanelReadyTimerId >= 0) clearTimeout(page.readerCommentPanelReadyTimerId);
    const serial = page.readerCommentPanelLoadSerial;
    page.readerCommentPanelReadyTimerId = setTimeout(() => {
      page.readerCommentPanelReadyTimerId = -1;
      if (!page.showReaderCommentPanel || serial !== page.readerCommentPanelLoadSerial) return;
      page.syncReaderCommentPanelWebTheme().finally(() => {
        if (page.showReaderCommentPanel && serial === page.readerCommentPanelLoadSerial) {
          page.readerCommentPanelLoading = false;
        }
      });
    }, Math.max(0, delayMs));
}

export function closeReaderCommentPanel(page: ReadBookPage): void {
    page.readerCommentPanelLoadSerial++;
    if (page.readerCommentPanelReadyTimerId >= 0) {
      clearTimeout(page.readerCommentPanelReadyTimerId);
      page.readerCommentPanelReadyTimerId = -1;
    }
    page.showReaderCommentPanel = false;
    page.readerCommentPanelUrl = '';
    page.readerCommentPanelMarker = '';
    page.readerCommentPanelAnchorBottom = -1;
    page.readerCommentPanelProgress = 0;
    page.readerCommentPanelLoading = false;
    page.readerCommentPanelHtml = '';
    page.readerCommentPanelBaseUrl = '';
    page.readerCommentPanelHtmlLoaded = false;
    page.readerCommentPanelHeightRatio = 0.6;
    page.readerCommentPanelHeightValue = page.readerCommentPanelHeightForRatio(0.6);
    page.readerCommentPanelDragStartRatio = 0.6;
    page.readerCommentPanelController = new webview.WebviewController();
    page.readerSourceActionOpenedAt = 0;
}

export async function syncReaderCommentPanelWebTheme(page: ReadBookPage): Promise<void> {
    if (!page.showReaderCommentPanel || !page.readerCommentPanelUrl) return;
    const scheme = page.appDarkMode ? 'dark' : 'light';
    const dark = page.appDarkMode ? 'true' : 'false';
    const script = `(function(){var scheme='${scheme}',dark=${dark};` +
      `var root=document.documentElement;if(root){root.style.colorScheme=scheme;` +
      `root.setAttribute('data-legado-color-scheme',scheme);}` +
      `var body=document.body,themeToggle=document.getElementById('themeToggle');` +
      `if(body&&themeToggle&&typeof window.toggleCmtTheme==='function'){` +
      `var pageDark=body.classList.contains('dark');` +
      `if(pageDark!==dark){window.toggleCmtTheme();}` +
      `try{window.localStorage.setItem('cmt-theme',scheme);}catch(_){}` +
      `body.classList.toggle('dark',dark);}` +
      `window.__LEGADO_COLOR_SCHEME__=scheme;window.__LEGADO_DARK_MODE__=dark;` +
      `window.dispatchEvent(new CustomEvent('legado-color-scheme-change',` +
      `{detail:{colorScheme:scheme,dark:dark}}));return scheme;})()`;
    try {
      await page.readerCommentPanelController.runJavaScript(script);
    } catch (error) {
      console.warn('同步评论面板深浅色模式失败:', error);
    }
}

export function readerCommentPanelHeight(page: ReadBookPage): number {
    return page.readerCommentPanelHeightValue;
}

export function readerCommentPanelHeightForRatio(page: ReadBookPage, ratio: number): number {
    const viewportHeight = page.readerCommentPageAreaHeight > 0 ? page.readerCommentPageAreaHeight :
      (page.pageViewHeight > 0 ? page.pageViewHeight : 720);
    return Math.max(1, viewportHeight *
      Math.max(0.6, Math.min(0.9, ratio)));
}

export function readerCommentPanelContentHeight(page: ReadBookPage): number {
    return Math.max(1, page.readerCommentPanelHeight() - LeafFns.readerCommentPanelDragHandleHeight());
}

export function handleReaderCommentPanelDragTouch(page: ReadBookPage, event: TouchEvent): void {
    const point = event.changedTouches.length > 0 ? event.changedTouches[0] :
      (event.touches.length > 0 ? event.touches[0] : null);
    if (!point) return;
    const windowY = Number(point.windowY);
    if (event.type === TouchType.Down) {
      page.readerCommentPanelDragging = true;
      page.readerCommentPanelDragStartRatio = page.readerCommentPanelHeightRatio;
      page.readerCommentPanelDragStartWindowY = windowY;
      return;
    }
    if (event.type === TouchType.Move && page.readerCommentPanelDragging) {
      const viewportHeight = Math.max(1, page.readerCommentPageAreaHeight || page.pageViewHeight);
      const nextRatio = page.readerCommentPanelDragStartRatio -
        (windowY - page.readerCommentPanelDragStartWindowY) / viewportHeight;
      page.readerCommentPanelHeightRatio = Math.max(0.6, Math.min(0.9, nextRatio));
      page.readerCommentPanelHeightValue = page.readerCommentPanelHeightForRatio(
        page.readerCommentPanelHeightRatio);
      return;
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      page.readerCommentPanelDragging = false;
    }
}

export function getReaderSourceActionAnchorBottom(page: ReadBookPage, marker: string): number {
    const bounds = page.readerSourceActionAreas.get(marker) || [];
    if (bounds.length < 4) return -1;
    const offsets = page.readerSourceActionScrollOffsets.get(marker) || [];
    const registeredOffset = offsets.length > 0 ? offsets[offsets.length - 1] : 0;
    return bounds[bounds.length - 1] - (page.currentContinuousReaderScrollOffset() - registeredOffset);
}

export function getReaderEpubImageHeight(page: ReadBookPage): number {
    const availableHeight = page.getReaderPaginationViewportHeight() -
      page.getReaderPaginationBottomInfoBarHeight();
    return Math.max(120, availableHeight);
}

export function readerSelectableTextController(page: ReadBookPage, key: string): TextController {
    let controller = page.readerSelectableTextControllers.get(key);
    if (!controller) {
      controller = new TextController();
      page.readerSelectableTextControllers.set(key, controller);
      // A continuous chapter may mount several rich Text nodes while the two retained paged
      // surfaces still own native selection controllers. Evicting at the old 160-entry limit
      // could drop a controller that was still attached to a visible Text. Looking it up again
      // then created a detached controller whose LayoutManager was undefined, so long-press
      // selection silently failed. Chapter/layout lifecycles clear these maps; keep enough live
      // controllers for the mounted window and prune them together with their measured areas.
      while (page.readerSelectableTextControllers.size > 1024) {
        const oldest = page.readerSelectableTextControllers.keys().next().value as string | undefined;
        if (!oldest) break;
        page.readerSelectableTextControllers.delete(oldest);
      }
    }
    return controller;
}

export function rememberReaderSelectableText(page: ReadBookPage, key: string, text: string, area: Area, controller: TextController | null = null): void {
    const position = area.globalPosition;
    const left = Number(position.x);
    const top = Number(position.y);
    const right = left + Number(area.width);
    const bottom = top + Number(area.height);
    if (!key || !text || !Number.isFinite(left) || !Number.isFinite(top) ||
      !Number.isFinite(right) || !Number.isFinite(bottom) || right <= left || bottom <= top) return;
    // 滚动停止后可能收到几何完全相同的重复 onAreaChange；保留原条目即可，
    // 省掉三次 Map 写入和一次滚动偏移读取。
    const previousRect = page.readerSelectableTextAreas.get(key);
    if (previousRect && previousRect.length === 4 && previousRect[0] === left && previousRect[1] === top &&
      previousRect[2] === right && previousRect[3] === bottom &&
      page.readerSelectableTextValues.get(key) === text) {
      return;
    }
    page.readerSelectableTextAreas.set(key, [left, top, right, bottom]);
    page.readerSelectableTextValues.set(key, text);
    page.readerSelectableTextScrollOffsets.set(key, page.currentContinuousReaderScrollOffset());
    if (controller) {
      // Area callbacks identify controllers that are attached to the current render tree.
      // Refresh their insertion order so the bounded cache cannot evict a visible page.
      page.readerSelectableTextControllers.delete(key);
      page.readerSelectableTextControllers.set(key, controller);
    }
    while (page.readerSelectableTextAreas.size > 512) {
      const oldest = page.readerSelectableTextAreas.keys().next().value as string | undefined;
      if (!oldest) break;
      page.readerSelectableTextAreas.delete(oldest);
      page.readerSelectableTextValues.delete(oldest);
      page.readerSelectableTextScrollOffsets.delete(oldest);
    }
}

export function selectReaderTextAtGlobalPoint(page: ReadBookPage, event: GestureEvent): void {
    const point = page.readerContinuousGesturePoint(event);
    if (point.length < 2) return;
    page.selectReaderTextAtPoint(point[0], point[1]);
}

export function selectReaderTextAtPoint(page: ReadBookPage, globalX: number, globalY: number): void {
    // A recognised long press must never fall through to a tap-zone page turn, even if the
    // system selection menu needs a later layout retry.
    page.readerTextSelectionUntil = Date.now() + 900;
    page.suppressReaderTapClick = true;
    page.readerTouchActive = false;
    page.readerPanActive = false;
    page.setReaderTextSelectionActive(page.isReaderNovelContinuousScrollModeActive());
    const serial = ++page.readerTextSelectionSerial;
    // Continuous novel mode renders ordinary selectable ArkUI Text items, even when the same chapter would use
    // the V2 canvas in paged mode. Routing its long press into the unmounted V2 transparent controller leaves no
    // selection menu; address the Text controller that actually owns the visible list item instead.
    if (!page.isReaderNovelContinuousScrollModeActive() && page.shouldUseReaderLayoutV2(page.pagedContentText)) {
      page.selectReaderV2TextAtGlobalPoint(globalX, globalY, serial, 0);
      return;
    }
    // 滚动模式与翻页模式同策略：直接命中最小的可见段落 Text，在其控制器上做原生选择，
    // 手柄/高亮/取字与显示层共用同一份布局，不存在覆盖层排版的漂移。
    page.selectLegacyReaderTextAtGlobalPoint(globalX, globalY, serial, 0);
}

export function selectLegacyReaderTextAtGlobalPoint(page: ReadBookPage, globalX: number, globalY: number, serial: number, attempt: number): void {
    if (serial !== page.readerTextSelectionSerial) return;
    const currentIdentity = page.currentReaderPageRenderIdentity(page.pageRenderVersion,
      page.ttsHighlightRenderVersion);
    const continuousNovel = page.isReaderNovelContinuousScrollModeActive();
    const currentScrollOffset = continuousNovel ? page.currentContinuousReaderScrollOffset() : 0;
    let selectedKey = '';
    let selectedArea: number[] = [];
    let selectedAreaSize = Number.POSITIVE_INFINITY;
    for (const entry of page.readerSelectableTextAreas.entries()) {
      const key = entry[0];
      const area = entry[1];
      if ((!continuousNovel && !key.startsWith(currentIdentity)) || area.length < 4) continue;
      if (continuousNovel && !page.isVisibleContinuousSelectionKey(key)) continue;
      const registeredScrollOffset = continuousNovel ? (page.readerSelectableTextScrollOffsets.get(key) || 0) : 0;
      const scrollDelta = currentScrollOffset - registeredScrollOffset;
      const adjustedTop = area[1] - scrollDelta;
      const adjustedBottom = area[3] - scrollDelta;
      if (globalX >= area[0] && globalX <= area[2] && globalY >= adjustedTop && globalY <= adjustedBottom) {
        const areaSize = (area[2] - area[0]) * (adjustedBottom - adjustedTop);
        if (areaSize < selectedAreaSize) {
          selectedKey = key;
          selectedArea = [area[0], adjustedTop, area[2], adjustedBottom];
          selectedAreaSize = areaSize;
        }
      }
    }
    if (!selectedKey || selectedArea.length < 4) {
      page.retryReaderTextSelection(serial, attempt,
        (nextAttempt: number): void => page.selectLegacyReaderTextAtGlobalPoint(
          globalX, globalY, serial, nextAttempt));
      return;
    }
    const text = page.readerSelectableTextValues.get(selectedKey) || '';
    const localX = globalX - selectedArea[0];
    if (!page.showReaderTextSelection(selectedKey, text,
      Math.max(0, localX), globalY - selectedArea[1])) {
      page.retryReaderTextSelection(serial, attempt,
        (nextAttempt: number): void => page.selectLegacyReaderTextAtGlobalPoint(
          globalX, globalY, serial, nextAttempt));
    }
}

export function isVisibleContinuousSelectionKey(page: ReadBookPage, key: string): boolean {
    const keepStart = Math.max(0, page.readerContinuousVisibleStart - 1);
    const keepEnd = page.readerContinuousVisibleEnd + 1;
    for (let pageIndex = keepStart; pageIndex <= keepEnd; pageIndex++) {
      if (key.includes(`reader_vertical_scroll_${page.currentChapterIndex}_${pageIndex}`)) return true;
    }
    return false;
}

export function retryReaderTextSelection(page: ReadBookPage, serial: number, attempt: number, action: (attempt: number) => void): void {
    if (attempt >= 3) {
      page.setReaderTextSelectionActive(false);
      return;
    }
    const delayMs = attempt === 0 ? 16 : 40;
    setTimeout(() => {
      if (serial !== page.readerTextSelectionSerial || !page.readerPageVisible) return;
      action(attempt + 1);
    }, delayMs);
}

export function continuousSelectionPageIndexForKey(page: ReadBookPage, key: string): number {
    const nativePrefix = `reader_continuous_native_${page.currentChapterIndex}_`;
    if (key.startsWith(nativePrefix)) {
      const suffix = key.substring(nativePrefix.length);
      const separator = suffix.indexOf('_');
      const value = Number(separator >= 0 ? suffix.substring(0, separator) : suffix);
      return Number.isFinite(value) ? Math.round(value) : -1;
    }
    const legacyPrefix = `reader_vertical_scroll_${page.currentChapterIndex}_`;
    const start = key.indexOf(legacyPrefix);
    if (start < 0) return -1;
    const suffix = key.substring(start + legacyPrefix.length);
    const match = suffix.match(/^\d+/);
    return match ? Number(match[0]) : -1;
}

export function showReaderTextSelection(page: ReadBookPage, key: string, text: string, localX: number, localY: number): boolean {
    if (!text) return false;
    try {
      const controller = page.readerSelectableTextController(key);
      const layout = controller.getLayoutManager();
      // GestureEvent and Area coordinates are reported in vp, while the native text
      // typography queried by LayoutManager uses physical pixels.
      let position = 0;
      if (layout) {
        position = layout.getGlyphPositionAtCoordinate(vp2px(localX), vp2px(localY)).position;
      } else if (page.isReaderNovelContinuousScrollModeActive()) {
        // TextController.getLayoutManager() is undefined for selectable Text inside List on
        // affected HarmonyOS builds. Use the same graphics paragraph engine as pagination to
        // resolve the glyph, then select on the visible rich Text controller itself.
        const widthVp = Math.max(1, page.getReaderPageColumnWidth() -
          page.getEffectiveReaderMarginLeft() - page.getEffectiveReaderMarginRight());
        position = ReaderV2Paginator.glyphPositionForPlainText(text,
          page.readerV2ActiveSnapshot || page.buildReaderV2Snapshot(),
          LeafFns.toMeasurePx(widthVp), vp2px(localX), vp2px(localY));
      } else {
        return false;
      }
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
      page.readerTextSelectionUntil = Date.now() + 900;
      page.suppressReaderTapClick = true;
      page.readerTouchActive = false;
      page.readerPanActive = false;
      controller.setTextSelection(start, end, { menuPolicy: MenuPolicy.SHOW });
      return true;
    } catch (error) {
      console.info('正文长按选择布局尚未就绪，准备重试:', error);
      return false;
    }
}

export function shouldUseFullThemeRegexDecoration(page: ReadBookPage, slice: ReadTextSlice): boolean {
    if (!slice.highlighted) return false;
    const style = page.resolvedRegexEmphasis(page.getRegexRuleBySlice(slice));
    return style.bubbleDecorationEnabled && ThemeAssetRegistry.hasRegexBubbleCap(style.bubbleStyleId);
}

export function getRegexSliceBubbleStyleId(page: ReadBookPage, slice: ReadTextSlice): string {
    return page.resolvedRegexEmphasis(page.getRegexRuleBySlice(slice)).bubbleStyleId;
}

export function getRegexBubbleCapSize(page: ReadBookPage, slice: ReadTextSlice): number {
    return Math.max(15, Math.min(22, page.getRegexSliceFontSize(slice) * 0.72));
}

export function shouldUseRegexParagraphFrame(page: ReadBookPage, paragraph: ReaderTextParagraph, pageStart: number = -1): boolean {
    return !!page.getRegexParagraphFrameStyleId(paragraph, pageStart);
}

export function getRegexParagraphFrame(page: ReadBookPage, paragraph: ReaderTextParagraph, pageStart: number = -1): ResourceStr {
    return ThemeAssetRegistry.regexBubbleFrame(page.getRegexParagraphFrameStyleId(paragraph, pageStart));
}

export function getRegexParagraphFrameStyleId(page: ReadBookPage, paragraph: ReaderTextParagraph, pageStart: number = -1): string {
    page.getRegexRules();
    const cacheKey = `${page.readerRegexFontEnabled ? '1' : '0'}_${page.cachedRegexRulesKey}_` +
      `${page.pageRenderVersion}_${pageStart}_${paragraph.key}`;
    if (page.regexFrameStyleCache.has(cacheKey)) {
      return page.regexFrameStyleCache.get(cacheKey) || '';
    }
    let styleId = '';
    if (page.readerRegexFontEnabled && paragraph.text.trim()) {
      const absoluteStart = pageStart < 0 ? -1 : pageStart + paragraph.start;
      styleId = page.getRegexFrameStyleIdFromSlices(page.getRegexTextSlicesAt(paragraph.text, absoluteStart));
    }
    if (page.regexFrameStyleCache.size >= 512) {
      page.regexFrameStyleCache.clear();
    }
    page.regexFrameStyleCache.set(cacheKey, styleId);
    return styleId;
}

export function getRegexParagraphFrameStyleIdForText(page: ReadBookPage, text: string): string {
    if (!page.readerRegexFontEnabled || !text.trim()) {
      return '';
    }
    return page.getRegexFrameStyleIdFromSlices(page.getRegexTextSlices(text));
}

export function getRegexFrameStyleIdFromSlices(page: ReadBookPage, slices: ReadTextSlice[]): string {
    let ruleIndex = -1;
    for (const slice of slices) {
      if (slice.highlighted) {
        if (ruleIndex < 0) {
          ruleIndex = slice.ruleIndex;
        } else if (ruleIndex !== slice.ruleIndex) {
          return '';
        }
      } else if (slice.text.trim()) {
        return '';
      }
    }
    const rules = page.getRegexRules();
    if (ruleIndex < 0 || ruleIndex >= rules.length) {
      return '';
    }
    const style = page.resolvedRegexEmphasis(rules[ruleIndex]);
    if (!style.bubbleDecorationEnabled) {
      return '';
    }
    return ThemeAssetRegistry.hasRegexBubbleFrame(style.bubbleStyleId) ? style.bubbleStyleId : '';
}

export function getRegexFrameHorizontalPadding(page: ReadBookPage, paragraph: ReaderTextParagraph, pageStart: number = -1): number {
    return LeafFns.getRegexFrameHorizontalPaddingForStyle(page.getRegexParagraphFrameStyleId(paragraph, pageStart));
}

export function getRegexFrameVerticalPadding(page: ReadBookPage, paragraph: ReaderTextParagraph, pageStart: number = -1): number {
    return LeafFns.getRegexFrameVerticalPaddingForStyle(page.getRegexParagraphFrameStyleId(paragraph, pageStart));
}

export function getRegexFrameBackgroundColor(page: ReadBookPage, paragraph: ReaderTextParagraph, pageStart: number = -1): string {
    const styleId = page.getRegexParagraphFrameStyleId(paragraph, pageStart);
    if (styleId === 'classic-glass') return page.isReaderThemeDark() ? '#162D6EA3' : '#104B9DE1';
    if (styleId === 'warm-scroll') return page.isReaderThemeDark() ? '#183C2B1E' : '#18E8CFA5';
    if (styleId === 'forest-dew') return page.isReaderThemeDark() ? '#163C6750' : '#1478A98A';
    if (styleId === 'ink-brush') return page.isReaderThemeDark() ? '#18283038' : '#105F6B74';
    if (styleId === 'neon-pulse') return page.isReaderThemeDark() ? '#1811162A' : '#1000D5FF';
    if (styleId === 'strawberry-ribbon') return page.isReaderThemeDark() ? '#18263544' : '#14F1B6BC';
    if (styleId === 'crimson-stamp') return page.isReaderThemeDark() ? '#188D211C' : '#109A2923';
    if (styleId === 'celadon-slip') return page.isReaderThemeDark() ? '#1828342D' : '#14E6EEE7';
    if (styleId === 'rose-frame') return page.isReaderThemeDark() ? '#182B171C' : '#14F8E7E1';
    if (styleId === 'moon-halo') return page.isReaderThemeDark() ? '#180A1627' : '#12DCEBFF';
    if (styleId === 'sword-talisman') return page.isReaderThemeDark() ? '#1822302B' : '#16476963';
    if (styleId === 'qingluan-jade') return page.isReaderThemeDark() ? '#1A263735' : '#18E3EBE7';
    if (styleId === 'pipi-soft-paw') return page.isReaderThemeDark() ? '#1A332721' : '#18FFF4E8';
    return '#00000000';
}

export function getRegexFrameBorderColor(page: ReadBookPage, paragraph: ReaderTextParagraph, pageStart: number = -1): string {
    const styleId = page.getRegexParagraphFrameStyleId(paragraph, pageStart);
    if (styleId === 'classic-glass') return '#804B9DE1';
    if (styleId === 'warm-scroll') return '#8CA9753D';
    if (styleId === 'forest-dew') return '#824F8063';
    if (styleId === 'ink-brush') return page.isReaderThemeDark() ? '#995F6B74' : '#8A283038';
    if (styleId === 'neon-pulse') return '#A000D5FF';
    if (styleId === 'strawberry-ribbon') return '#8FE1767D';
    if (styleId === 'crimson-stamp') return '#9A9A2923';
    if (styleId === 'celadon-slip') return '#94A96B5C';
    if (styleId === 'rose-frame') return '#A0A84550';
    if (styleId === 'moon-halo') return '#9678B9F3';
    if (styleId === 'sword-talisman') return '#9A6E817B';
    if (styleId === 'qingluan-jade') return '#A2B4935C';
    if (styleId === 'pipi-soft-paw') return page.isReaderThemeDark() ? '#9AE8A06F' : '#9AC46F45';
    return '#00000000';
}

export function getRegexFrameBorderWidth(page: ReadBookPage, paragraph: ReaderTextParagraph, pageStart: number = -1): number {
    const styleId = page.getRegexParagraphFrameStyleId(paragraph, pageStart);
    return styleId === 'neon-pulse' || styleId === 'ink-brush' ? 1.5 : 1;
}

export function getRegexFrameBorderStyle(page: ReadBookPage, paragraph: ReaderTextParagraph, pageStart: number = -1): BorderStyle {
    const styleId = page.getRegexParagraphFrameStyleId(paragraph, pageStart);
    if (styleId === 'forest-dew' || styleId === 'strawberry-ribbon') return BorderStyle.Dotted;
    if (styleId === 'ink-brush' || styleId === 'crimson-stamp') return BorderStyle.Dashed;
    return BorderStyle.Solid;
}

export function getRegexFrameBorderRadius(page: ReadBookPage, paragraph: ReaderTextParagraph, pageStart: number = -1): number {
    const styleId = page.getRegexParagraphFrameStyleId(paragraph, pageStart);
    if (styleId === 'forest-dew') return 18;
    if (styleId === 'classic-glass' || styleId === 'strawberry-ribbon') return 12;
    if (styleId === 'rose-frame' || styleId === 'moon-halo') return 10;
    if (styleId === 'sword-talisman') return 4;
    if (styleId === 'qingluan-jade') return 12;
    if (styleId === 'pipi-soft-paw') return 16;
    if (styleId === 'neon-pulse') return 5;
    return 1;
}

export function getRegexFrameHorizontalSlice(page: ReadBookPage, paragraph: ReaderTextParagraph, pageStart: number = -1): number {
    const styleId = page.getRegexParagraphFrameStyleId(paragraph, pageStart);
    if (styleId === 'rose-frame') return 46;
    if (styleId === 'celadon-slip') return 32;
    if (styleId === 'strawberry-ribbon' || styleId === 'crimson-stamp') return 40;
    if (styleId === 'sword-talisman') return 38;
    if (styleId === 'qingluan-jade') return 44;
    if (styleId === 'pipi-soft-paw') return 44;
    return 34;
}

export function getRegexFrameVerticalSlice(page: ReadBookPage, paragraph: ReaderTextParagraph, pageStart: number = -1): number {
    const styleId = page.getRegexParagraphFrameStyleId(paragraph, pageStart);
    if (styleId === 'rose-frame') return 28;
    if (styleId === 'celadon-slip') return 24;
    if (styleId === 'sword-talisman') return 24;
    if (styleId === 'qingluan-jade') return 28;
    if (styleId === 'pipi-soft-paw') return 28;
    return 22;
}

export function getTitleTextSlices(page: ReadBookPage, paragraph: ReaderTextParagraph, chapterIndex: number, ttsHighlightActive: boolean = true): ReadTextSlice[] {
    const title = page.getChapterTitle(chapterIndex);
    const titleText = paragraph.text.substring(0, Math.min(title.length, paragraph.text.length));
    return page.splitSliceByTtsHighlight({
      text: titleText,
      start: 0,
      end: titleText.length,
      highlighted: false,
      ruleIndex: -1,
      key: `title_plain_${LeafFns.buildTextSliceKey(titleText)}`
    }, paragraph.start, 0, ttsHighlightActive);
}

export function getTitleBodyTextSlices(page: ReadBookPage, paragraph: ReaderTextParagraph, chapterIndex: number, ttsHighlightActive: boolean = true, pageStart: number = -1, documentSource: string = page.pagedContentText): ReadTextSlice[] {
    const titleLength = Math.min(page.getChapterTitle(chapterIndex).length, paragraph.text.length);
    const bodyText = paragraph.text.substring(titleLength);
    return page.splitSlicesByTtsHighlight(
      page.getRegexTextSlicesAt(bodyText, pageStart < 0 ? -1 : pageStart + paragraph.start + titleLength,
        documentSource),
      paragraph.start, titleLength,
      ttsHighlightActive);
}

export function handleTocCurrentPositionClick(page: ReadBookPage): void {
    if (page.tocQuickJumpArmed) {
      page.tocQuickJumpDraft = '';
      page.tocQuickJumpInputVisible = true;
      page.tocQuickJumpArmed = false;
      setTimeout(() => {
        focusControl.requestFocus('tocQuickJumpChapterInput');
      }, 50);
      return;
    }
    page.scrollTocToCurrentChapter();
    page.tocQuickJumpArmed = true;
}

export function submitTocQuickJump(page: ReadBookPage): void {
    if (page.chapters.length === 0) {
      HdsFeedback.showToast('暂无可定位的章节');
      return;
    }
    const chapterNumber = Number.parseInt(page.tocQuickJumpDraft, 10);
    if (!Number.isFinite(chapterNumber) || chapterNumber < 1 || chapterNumber > page.chapters.length) {
      HdsFeedback.showToast(`章节序号范围为 1～${page.chapters.length}，请重新输入`);
      setTimeout(() => {
        focusControl.requestFocus('tocQuickJumpChapterInput');
      }, 50);
      return;
    }
    page.tocQuickJumpInputVisible = false;
    page.tocQuickJumpDraft = '';
    page.tocQuickJumpArmed = false;
    page.scrollTocToChapter(chapterNumber - 1, ScrollAlign.CENTER);
}

export function getStyledParagraphTextSlices(page: ReadBookPage, paragraph: ReaderTextParagraph, ttsHighlightActive: boolean = true, pageStart: number = -1, documentSource: string = page.pagedContentText): ReadTextSlice[] {
    return page.splitSlicesByTtsHighlight(
      page.getRegexTextSlicesAt(paragraph.text, pageStart < 0 ? -1 : pageStart + paragraph.start, documentSource),
      paragraph.start, 0,
      ttsHighlightActive);
}

export function splitSlicesByTtsHighlight(page: ReadBookPage, slices: ReadTextSlice[], paragraphStart: number, segmentOffset: number, ttsHighlightActive: boolean = true): ReadTextSlice[] {
    const result: ReadTextSlice[] = [];
    for (const slice of slices) {
      result.push(...page.splitSliceByTtsHighlight(slice, paragraphStart, segmentOffset, ttsHighlightActive));
    }
    return result;
}

export function splitSliceByTtsHighlight(page: ReadBookPage, slice: ReadTextSlice, paragraphStart: number, segmentOffset: number, ttsHighlightActive: boolean = true): ReadTextSlice[] {
    const sliceStart = segmentOffset + slice.start;
    const sliceEnd = segmentOffset + slice.end;
    const localHighlightStart = page.ttsHighlightStart - paragraphStart;
    const localHighlightEnd = page.ttsHighlightEnd - paragraphStart;
    if (!ttsHighlightActive || !page.shouldRenderTtsFocus() || page.ttsHighlightStart < 0 ||
      page.ttsHighlightEnd <= page.ttsHighlightStart || localHighlightEnd <= sliceStart ||
      localHighlightStart >= sliceEnd) {
      return [LeafFns.cloneStyledSlice(slice, sliceStart, sliceEnd, slice.text, false, 'plain')];
    }

    const overlapStart = Math.max(sliceStart, localHighlightStart);
    const overlapEnd = Math.min(sliceEnd, localHighlightEnd);
    const result: ReadTextSlice[] = [];
    if (overlapStart > sliceStart) {
      const beforeText = slice.text.substring(0, overlapStart - sliceStart);
      result.push(LeafFns.cloneStyledSlice(slice, sliceStart, overlapStart, beforeText, false, 'before_tts'));
    }
    const highlightText = slice.text.substring(overlapStart - sliceStart, overlapEnd - sliceStart);
    result.push(LeafFns.cloneStyledSlice(slice, overlapStart, overlapEnd, highlightText, true, 'tts'));
    if (overlapEnd < sliceEnd) {
      const afterText = slice.text.substring(overlapEnd - sliceStart);
      result.push(LeafFns.cloneStyledSlice(slice, overlapEnd, sliceEnd, afterText, false, 'after_tts'));
    }
    return result;
}

export function getStyledSliceFontColor(page: ReadBookPage, slice: ReadTextSlice): string {
    if (slice.ttsHighlighted) {
      return page.getTtsHighlightTextColor();
    }
    if (slice.highlighted) {
      return page.resolvedRegexEmphasis(page.getRegexRuleBySlice(slice)).textColor;
    }
    return page.getTextColor();
}

export function getStyledSliceBackgroundStyle(page: ReadBookPage, slice: ReadTextSlice): TextBackgroundStyle {
    if (slice.ttsHighlighted) {
      return { color: page.getTtsHighlightColor(), radius: 4 };
    }
    if (!slice.highlighted) {
      return {};
    }
    const style = page.resolvedRegexEmphasis(page.getRegexRuleBySlice(slice));
    if (!style.backgroundEnabled) {
      return {};
    }
    return {
      color: style.backgroundColor,
      radius: {
        topLeft: style.radiusTopLeft,
        topRight: style.radiusTopRight,
        bottomLeft: style.radiusBottomLeft,
        bottomRight: style.radiusBottomRight
      }
    };
}

export function getStyledSliceTextShadow(page: ReadBookPage, slice: ReadTextSlice): ShadowOptions | ShadowOptions[] {
    if (slice.ttsHighlighted || !slice.highlighted) {
      return { radius: 0, color: '#00000000', offsetX: 0, offsetY: 0 };
    }
    const style = page.resolvedRegexEmphasis(page.getRegexRuleBySlice(slice));
    if (style.textShadows.length > 0) {
      return style.textShadows;
    }
    return {
      radius: style.textShadowRadius,
      color: style.textShadowColor,
      offsetX: style.textShadowOffsetX,
      offsetY: style.textShadowOffsetY
    };
}

export function shouldUseTitleStyle(page: ReadBookPage, text: string, chapterIndex: number = page.currentChapterIndex): boolean {
    const title = page.getChapterTitle(chapterIndex).trim();
    return !!title && (text || '').startsWith(title);
}

export function shouldUseRegexStyle(page: ReadBookPage, text: string): boolean {
    return page.hasRegexMatch(text);
}

export function hasRegexMatch(page: ReadBookPage, text: string): boolean {
    if (!page.readerRegexFontEnabled) {
      return false;
    }
    const rules = page.getRegexRules();
    for (const rule of rules) {
      if (!rule.pattern.trim()) {
        continue;
      }
      try {
        if (new RegExp(rule.pattern).test(text || '')) {
          return true;
        }
      } catch (e) {
      }
    }
    return false;
}

export function getRegexRules(page: ReadBookPage): ReaderRegexFontRule[] {
    const key = `${page.readerRegexFontRulesRaw}\n${page.readerRegexFontPattern}\n${page.readerRegexFontMode}\n` +
      `${page.readerRegexFontFamily}\n${page.readerRegexFontSize}\n${page.readerRegexShadowColor}`;
    if (key === page.cachedRegexRulesKey) {
      return page.cachedRegexRules;
    }
    const legacy = new ReaderRegexLegacySettings();
    legacy.pattern = page.readerRegexFontPattern;
    legacy.fontMode = page.readerRegexFontMode;
    legacy.fontFamily = page.readerRegexFontFamily;
    legacy.fontSize = page.readerRegexFontSize;
    legacy.shadowColor = page.readerRegexShadowColor;
    page.cachedRegexRules = ReaderRegexFontCodec.decode(page.readerRegexFontRulesRaw, legacy);
    page.cachedRegexRulesKey = key;
    return page.cachedRegexRules;
}

export function themeRegexEmphasisColor(dark: boolean): string {
    return ThemeRuntime.regexEmphasisColor(dark);}

export function readerRegexEmphasisContext(page: ReadBookPage): ReaderRegexEmphasisContext {
    const context = new ReaderRegexEmphasisContext();
    context.inheritedMode = LeafFns.themeRegexEmphasisMode();
    context.inheritedBubbleStyleId = LeafFns.themeRegexBubbleStyleId();
    context.inheritedColor = page.themeRegexEmphasisColor();
    context.inheritedTextColor = ThemeRuntime.regexEmphasisTextColor(page.appDarkMode);
    context.accentColor = page.accentColor();
    context.surfaceColor = page.getBackgroundColor();
    context.normalTextColor = page.getTextColor();
    context.darkMode = page.isReaderThemeDark();
    return context;
}

export function resolvedRegexEmphasis(page: ReadBookPage, rule: ReaderRegexFontRule | null): ReaderResolvedRegexEmphasis {
    return ReaderRegexBubbleStyleResolver.resolve(rule, page.readerRegexEmphasisContext());
}

export function getRegexTextSlices(page: ReadBookPage, text: string): ReadTextSlice[] {
    const displayText = text || '';
    const rules = page.getRegexRules();
    if (!page.readerRegexFontEnabled || rules.length === 0) {
      return [{
        text: displayText,
        start: 0,
        end: displayText.length,
        highlighted: false,
        ruleIndex: -1,
        key: `plain_regex_${LeafFns.buildTextSliceKey(displayText)}`
      }];
    }
    try {
      const matched: ReadTextSlice[] = [];
      for (let ruleIndex = 0; ruleIndex < rules.length; ruleIndex++) {
        const rule = rules[ruleIndex];
        if (!rule.pattern.trim()) {
          continue;
        }
        let regex: RegExp;
        try {
          regex = new RegExp(rule.pattern, 'g');
        } catch (e) {
          continue;
        }
        let match = regex.exec(displayText);
        while (match && match.index >= 0) {
          const start = Math.max(0, match.index);
          const end = Math.max(start, Math.min(displayText.length, match.index + (match[0] || '').length));
          if (end <= start) {
            if (start >= displayText.length || regex.lastIndex >= displayText.length) {
              break;
            }
            regex.lastIndex = Math.max(regex.lastIndex + 1, start + 1);
            match = regex.exec(displayText);
            continue;
          }
          if (!LeafFns.hasOverlappedRegexSlice(matched, start, end)) {
            const matchText = displayText.substring(start, end);
            matched.push({
              text: matchText,
              start: start,
              end: end,
              highlighted: true,
              ruleIndex: ruleIndex,
              key: `regex_hit_${ruleIndex}_${start}_${end}_${LeafFns.buildTextSliceKey(matchText)}`
            });
          }
          regex.lastIndex = Math.max(regex.lastIndex, end);
          match = regex.exec(displayText);
        }
      }
      if (matched.length === 0) {
        return [{
          text: displayText,
          start: 0,
          end: displayText.length,
          highlighted: false,
          ruleIndex: -1,
          key: `plain_regex_${LeafFns.buildTextSliceKey(displayText)}`
        }];
      }
      matched.sort((a: ReadTextSlice, b: ReadTextSlice) => a.start - b.start);
      const slices: ReadTextSlice[] = [];
      let cursor = 0;
      for (const item of matched) {
        const start = Math.max(cursor, item.start);
        const end = Math.max(start, item.end);
        if (start > cursor) {
          const beforeText = displayText.substring(cursor, start);
          slices.push({
            text: beforeText,
            start: cursor,
            end: start,
            highlighted: false,
            ruleIndex: -1,
            key: `regex_plain_${cursor}_${start}_${LeafFns.buildTextSliceKey(beforeText)}`
          });
        }
        const matchText = displayText.substring(start, end);
        slices.push({
          text: matchText,
          start: start,
          end: end,
          highlighted: true,
          ruleIndex: item.ruleIndex,
          key: `regex_hit_${item.ruleIndex}_${start}_${end}_${LeafFns.buildTextSliceKey(matchText)}`
        });
        cursor = end;
      }
      if (cursor < displayText.length) {
        const afterText = displayText.substring(cursor);
        slices.push({
          text: afterText,
          start: cursor,
          end: displayText.length,
          highlighted: false,
          ruleIndex: -1,
          key: `regex_plain_${cursor}_${displayText.length}_${LeafFns.buildTextSliceKey(afterText)}`
        });
      }
      return slices;
    } catch (e) {
      return [{
        text: displayText,
        start: 0,
        end: displayText.length,
        highlighted: false,
        ruleIndex: -1,
        key: `plain_regex_error_${LeafFns.buildTextSliceKey(displayText)}`
      }];
    }
}

export function getRegexTextSlicesAt(page: ReadBookPage, text: string, absoluteStart: number, documentSource: string = page.pagedContentText): ReadTextSlice[] {
    const displayText = text || '';
    const source = documentSource || '';
    if (absoluteStart < 0 || !source) {
      return page.getRegexTextSlices(displayText);
    }
    return page.getRegexTextSlicesForDocumentRange(displayText, source, absoluteStart);
}

export function getRegexTextSlicesForDocumentRange(page: ReadBookPage, text: string, documentSource: string, absoluteStart: number): ReadTextSlice[] {
    const displayText = text || '';
    const source = documentSource || displayText;
    if (!displayText || absoluteStart < 0 || !source) {
      return page.getRegexTextSlices(displayText);
    }
    page.getRegexRules();
    const documentRulesKey = `${page.readerRegexFontEnabled ? '1' : '0'}_${page.cachedRegexRulesKey}`;
    if (page.cachedDocumentRegexSource !== source ||
      page.cachedDocumentRegexRulesKey !== documentRulesKey) {
      page.cachedDocumentRegexSource = source;
      page.cachedDocumentRegexRulesKey = documentRulesKey;
      page.cachedDocumentRegexSlices = page.getRegexTextSlices(source);
    }
    const absoluteEnd = Math.min(source.length, absoluteStart + displayText.length);
    const result: ReadTextSlice[] = [];
    let low = 0;
    let high = page.cachedDocumentRegexSlices.length;
    while (low < high) {
      const middle = Math.floor((low + high) / 2);
      if (page.cachedDocumentRegexSlices[middle].end <= absoluteStart) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    for (let index = low; index < page.cachedDocumentRegexSlices.length; index++) {
      const slice = page.cachedDocumentRegexSlices[index];
      if (slice.start >= absoluteEnd) break;
      const overlapStart = Math.max(slice.start, absoluteStart);
      const overlapEnd = Math.min(slice.end, absoluteEnd);
      if (overlapEnd <= overlapStart) continue;
      const localStart = overlapStart - absoluteStart;
      const localEnd = overlapEnd - absoluteStart;
      const sliceText = displayText.substring(localStart, localEnd);
      result.push({
        text: sliceText,
        start: localStart,
        end: localEnd,
        highlighted: slice.highlighted,
        ruleIndex: slice.ruleIndex,
        key: `document_regex_${slice.ruleIndex}_${overlapStart}_${overlapEnd}_` +
          `${LeafFns.buildTextSliceKey(sliceText)}`
      });
    }
    return result.length > 0 ? result : page.getRegexTextSlices(displayText);
}

export function getRegexRuleBySlice(page: ReadBookPage, slice: ReadTextSlice): ReaderRegexFontRule | null {
    const rules = page.getRegexRules();
    if (!slice.highlighted || slice.ruleIndex < 0 || slice.ruleIndex >= rules.length) {
      return null;
    }
    return rules[slice.ruleIndex];
}

export function getRegexSliceFontSize(page: ReadBookPage, slice: ReadTextSlice): number {
    const rule = page.getRegexRuleBySlice(slice);
    return rule ? rule.fontSize : page.readerRegexFontSize;
}

export function getRegexSliceFontFamily(page: ReadBookPage, slice: ReadTextSlice): string {
    const rule = page.getRegexRuleBySlice(slice);
    return rule ? page.resolveStyledReaderFontFamily(rule.fontMode, rule.fontFamily) : page.getRegexReaderFontFamily();
}

export function getReadingTextSlices(page: ReadBookPage, text: string): ReadTextSlice[] {
    const displayText = page.getReadingRenderText(text);
    const start = page.ttsHighlightStart;
    const end = page.ttsHighlightEnd;
    if (!page.shouldRenderTtsFocus() || !page.ttsDisplayText || start < 0 || end <= start ||
      displayText !== page.ttsDisplayText) {
      return [{
        text: displayText,
        start: 0,
        end: displayText.length,
        highlighted: false,
        ruleIndex: -1,
        key: `plain_${LeafFns.buildTextSliceKey(displayText)}`
      }];
    }
    const clampedStart = Math.max(0, Math.min(start, displayText.length));
    const clampedEnd = Math.max(clampedStart, Math.min(end, displayText.length));
    const slices: ReadTextSlice[] = [];
    if (clampedStart > 0) {
      slices.push({
        text: displayText.substring(0, clampedStart),
        start: 0,
        end: clampedStart,
        highlighted: false,
        ruleIndex: -1,
        key: `before_${clampedStart}_${LeafFns.buildTextSliceKey(displayText.substring(0, clampedStart))}`
      });
    }
    const highlightedText = displayText.substring(clampedStart, clampedEnd);
    slices.push({
      text: highlightedText,
      start: clampedStart,
      end: clampedEnd,
      highlighted: true,
      ruleIndex: -1,
      key: `highlight_${clampedStart}_${clampedEnd}_${LeafFns.buildTextSliceKey(highlightedText)}`
    });
    if (clampedEnd < displayText.length) {
      const afterText = displayText.substring(clampedEnd);
      slices.push({
        text: afterText,
        start: clampedEnd,
        end: displayText.length,
        highlighted: false,
        ruleIndex: -1,
        key: `after_${clampedEnd}_${LeafFns.buildTextSliceKey(afterText)}`
      });
    }
    return slices;
}

export function getReadingTextSlicesInRange(page: ReadBookPage, text: string, start: number, end: number): ReadTextSlice[] {
    const displayText = text || '';
    if (!page.shouldRenderTtsFocus() || start < 0 || end <= start) {
      return [{
        text: displayText,
        start: 0,
        end: displayText.length,
        highlighted: false,
        ruleIndex: -1,
        key: `plain_${LeafFns.buildTextSliceKey(displayText)}`
      }];
    }
    const clampedStart = Math.max(0, Math.min(start, displayText.length));
    const clampedEnd = Math.max(clampedStart, Math.min(end, displayText.length));
    const slices: ReadTextSlice[] = [];
    if (clampedStart > 0) {
      const beforeText = displayText.substring(0, clampedStart);
      slices.push({
        text: beforeText,
        start: 0,
        end: clampedStart,
        highlighted: false,
        ruleIndex: -1,
        key: `before_${clampedStart}_${LeafFns.buildTextSliceKey(beforeText)}`
      });
    }
    const highlightedText = displayText.substring(clampedStart, clampedEnd);
    slices.push({
      text: highlightedText,
      start: clampedStart,
      end: clampedEnd,
      highlighted: true,
      ruleIndex: -1,
      key: `highlight_${clampedStart}_${clampedEnd}_${LeafFns.buildTextSliceKey(highlightedText)}`
    });
    if (clampedEnd < displayText.length) {
      const afterText = displayText.substring(clampedEnd);
      slices.push({
        text: afterText,
        start: clampedEnd,
        end: displayText.length,
        highlighted: false,
        ruleIndex: -1,
        key: `after_${clampedEnd}_${LeafFns.buildTextSliceKey(afterText)}`
      });
    }
    return slices;
}

export function hasActiveTtsHighlight(page: ReadBookPage, text: string): boolean {
    // 先判断 TTS 焦点态再归一化正文：getReadingRenderText 会做两遍全文正则替换，
    // 滚动模式下每个新渲染的文本块都会调用到这里，非朗读时必须零成本返回。
    if (!page.shouldRenderTtsFocus() || !page.ttsDisplayText ||
      page.ttsHighlightStart < 0 || page.ttsHighlightEnd <= page.ttsHighlightStart) {
      return false;
    }
    const displayText = page.getReadingRenderText(text);
    return displayText === page.ttsDisplayText;
}

export function getReadingRenderText(page: ReadBookPage, text: string): string {
    const normalized = (text || '')
      .replace(/\r\n/g, '\n')
      .replace(/\n{3,}/g, '\n\n')
      .trim();
    if (page.shouldRenderTtsFocus() && page.ttsDisplayText && normalized === page.ttsDisplayText) {
      return page.ttsDisplayText;
    }
    return text || '';
}

export function getTtsHighlightColor(page: ReadBookPage): string {
    return page.isReaderThemeDark() ? '#5A4A24' : '#FFE58A';
}

export function getTtsHighlightTextColor(page: ReadBookPage): string {
    return page.isReaderThemeDark() ? '#FFF4BF' : '#2F261D';
}

export function hideReaderPanels(page: ReadBookPage): void {
    page.flushPendingReaderLayoutChange(true);
    page.menuChapterPreviewIndex = page.currentChapterIndex;
    page.menuChapterSliderActive = false;
    page.menuChapterTooltipVisible = false;
    page.showReaderActionMenu = false;
    page.showReaderCacheDialog = false;
    page.showReaderChapterCacheDialog = false;
    page.showLayoutElementSettings = false;
    if (!page.txtCharsetApplying) page.showTxtCharsetDialog = false;
    page.showMenu = false;
    page.showTtsVoiceDropdown = false;
    page.showSettings = false;
    page.showReaderCustomThemeDeleteConfirm = false;
    if (page.showReaderCommentPanel) {
      page.closeReaderCommentPanel();
    }
}

export function shouldUseReaderLayoutV2(page: ReadBookPage, source: string = page.pagedContentText || page.content): boolean {
    return !!source && !page.isReaderContinuousScrollSurfaceActive() &&
      !LocalBookService.hasEpubImageMarkers(source) && !page.isReaderComicModeActive();
}

export function buildReaderV2Snapshot(page: ReadBookPage): ReaderV2LayoutSnapshot {
    const input = new ReaderV2LayoutInput();
    input.viewportWidthPx = LeafFns.toMeasurePx(page.getReaderPageColumnWidth());
    input.viewportHeightPx = LeafFns.toMeasurePx(page.getReaderPaginationViewportHeight());
    // The measured reader viewport already begins below the status bar in normal mode. Immersive mode begins at
    // screen y=0. Therefore both modes use local y=0 and must not subtract the status inset a second time.
    input.safeTopPx = 0;
    input.safeBottomPx = 0;
    input.extendToStatusBar = page.readerExtendToStatusBar;
    input.marginLeftPx = LeafFns.toMeasurePx(page.getEffectiveReaderMarginLeft());
    input.marginRightPx = LeafFns.toMeasurePx(page.getEffectiveReaderMarginRight());
    input.marginTopPx = LeafFns.toMeasurePx(page.getEffectiveReaderMarginTop());
    input.marginBottomPx = LeafFns.toMeasurePx(page.getEffectiveReaderMarginBottom());
    // Footer metadata is an overlay, but it is lifted above the gesture indicator. Reserve the same deterministic
    // footprint in native Paragraph pagination so the final正文 line stays clear of the raised footer.
    input.bottomGuardPx = LeafFns.toMeasurePx(page.getReaderV2BottomGuard());
    input.columnCount = 1;
    input.columnGapPx = 0;
    input.fontSizePx = LeafFns.toMeasureFontPx(page.readerFontSize);
    input.titleFontSizePx = LeafFns.toMeasureFontPx(page.readerTitleFontSize);
    input.lineSpacingPx = LeafFns.toMeasureNonNegativePx(page.readerLineHeight);
    input.paragraphSpacingPx = LeafFns.toMeasureNonNegativePx(page.readerParagraphSpacing);
    input.letterSpacingPx = LeafFns.toMeasureFontOffsetPx(page.getReaderAdaptiveLetterSpacing());
    input.textAlign = page.readerTextAlign;
    input.bodyFontFamily = page.getBodyReaderFontFamily();
    input.titleFontFamily = page.getTitleReaderFontFamily();
    input.textColor = ReaderV2Color.parse(page.getTextColor(), 0xFF202124);
    input.commentTextColor = ReaderV2Color.parse(
      page.readerSourceColorSetting('段评字体颜色', page.isReaderThemeDark() ? '#B8D6FF' : '#2A6FCC'),
      page.isReaderThemeDark() ? 0xFFB8D6FF : 0xFF2A6FCC);
    input.commentBackgroundColor = ReaderV2Color.parse(
      page.readerSourceColorSetting('段评填充颜色', page.isReaderThemeDark() ? '#263A5066' : '#142A6FCC'),
      page.isReaderThemeDark() ? 0x66263A50 : 0x142A6FCC);
    const commentLarge = page.readerSourceSettingEnabled('气泡增大');
    input.commentFontSizePx = LeafFns.toMeasureFontPx(commentLarge ?
      Math.max(12, page.readerFontSize - 2) : Math.max(10, page.readerFontSize - 5));
    input.commentRadiusPx = LeafFns.toMeasurePx(page.readerV2CommentRadius());
    input.commentHitSlopXPx = LeafFns.toMeasurePx(page.readerSourceActionHitSlopX);
    input.commentHitSlopYPx = LeafFns.toMeasurePx(page.readerSourceActionHitSlopY);
    input.commentsEnabled = true;
    input.regexEnabled = page.readerRegexFontEnabled;
    input.styleIdentity = `${page.readerTypographyCacheIdentity()}_${LeafFns.readerParagraphCommentPaginationIdentity()}_` +
      `${page.getBackgroundColor()}_${page.getTextColor()}`;
    return ReaderV2LayoutSnapshot.create(input);
}

export function readerV2CommentRadius(page: ReadBookPage): number {
    const style = page.readerSourceSettingValue('段评样式') || '0';
    if (style === '3' || style === '4') return 3;
    if (style === '0' || style === '2') return 6;
    return 9;
}

export function buildReaderV2RegexStyles(page: ReadBookPage, document: ReaderV2Document): ReaderV2SpanStyleRange[] {
    if (!page.readerRegexFontEnabled || !document.displayText) return [];
    const slices = page.getRegexTextSlices(document.displayText);
    const result: ReaderV2SpanStyleRange[] = [];
    for (const slice of slices) {
      if (!slice.highlighted || slice.end <= slice.start) continue;
      const resolved = page.resolvedRegexEmphasis(page.getRegexRuleBySlice(slice));
      const style = new ReaderV2SpanStyleRange(slice.start, slice.end);
      style.fontSizePx = LeafFns.toMeasureFontPx(page.getRegexSliceFontSize(slice));
      style.fontFamily = page.getRegexSliceFontFamily(slice);
      style.color = ReaderV2Color.parse(page.getStyledSliceFontColor(slice),
        ReaderV2Color.parse(page.getTextColor(), 0xFF202124));
      style.backgroundEnabled = resolved.backgroundEnabled;
      style.backgroundColor = ReaderV2Color.parse(resolved.backgroundColor, 0x00000000);
      style.radiusTopLeftPx = LeafFns.toMeasurePx(resolved.radiusTopLeft);
      style.radiusTopRightPx = LeafFns.toMeasurePx(resolved.radiusTopRight);
      style.radiusBottomRightPx = LeafFns.toMeasurePx(resolved.radiusBottomRight);
      style.radiusBottomLeftPx = LeafFns.toMeasurePx(resolved.radiusBottomLeft);
      style.shadowEnabled = resolved.textShadowRadius > 0;
      style.shadowColor = ReaderV2Color.parse(resolved.textShadowColor, 0x00000000);
      style.shadowRadiusPx = LeafFns.toMeasurePx(Math.max(0, resolved.textShadowRadius));
      style.shadowOffsetXPx = LeafFns.toMeasurePx(Math.max(0, resolved.textShadowOffsetX));
      style.shadowOffsetYPx = LeafFns.toMeasurePx(Math.max(0, resolved.textShadowOffsetY));
      style.decorationEnabled = resolved.bubbleDecorationEnabled &&
        ThemeAssetRegistry.hasRegexBubbleCap(resolved.bubbleStyleId);
      style.decorationStyleId = style.decorationEnabled ? resolved.bubbleStyleId : '';
      style.decorationSizePx = style.decorationEnabled ?
        LeafFns.toMeasurePx(Math.max(15, Math.min(22, page.getRegexSliceFontSize(slice) * 0.72))) : 0;
      result.push(style);
    }
    return result;
}

export function buildReaderV2Pagination(page: ReadBookPage, source: string, chapterIndex: number): ReaderPaginationResult {
    const snapshot = page.buildReaderV2Snapshot();
    const document = ReaderV2DocumentParser.parse(source, chapterIndex, page.getChapterTitle(chapterIndex));
    const session = ReaderV2Paginator.start(document, snapshot, page.buildReaderV2RegexStyles(document));
    while (!session.pageSet.complete) {
      if (ReaderV2Paginator.appendPages(session, 32) <= 0) break;
    }
    const result: ReaderPaginationResult = {
      source: source,
      pages: [],
      starts: [],
      ends: [],
      cursor: 0,
      complete: session.pageSet.complete,
      v2Session: session
    };
    page.registerReaderV2PaginationSession(source, chapterIndex, session);
    LeafFns.syncReaderV2PaginationResult(result);
    return result;
}

export function createIncrementalReaderV2Pagination(page: ReadBookPage, source: string, chapterIndex: number, initialPageCount: number): ReaderPaginationResult {
    const snapshot = page.buildReaderV2Snapshot();
    const document = ReaderV2DocumentParser.parse(source, chapterIndex, page.getChapterTitle(chapterIndex));
    const session = ReaderV2Paginator.start(document, snapshot, page.buildReaderV2RegexStyles(document));
    const result: ReaderPaginationResult = {
      source: source,
      pages: [],
      starts: [],
      ends: [],
      cursor: 0,
      complete: session.pageSet.complete,
      v2Session: session
    };
    page.registerReaderV2PaginationSession(source, chapterIndex, session);
    const visibleSpreadSize = page.isLandscapeDoublePageActive() ? 2 : 1;
    // Never rebuild synchronously from the chapter start to a deep saved position. A single V2 page can include
    // native paragraph measurement, so restoring hundreds of pages in this lifecycle call can trip the UI watchdog.
    // Publish only the first visible spread here; the retained session restores the saved position cooperatively.
    const requestedPageCount = Math.min(Math.max(1, initialPageCount), visibleSpreadSize);
    const rawTargetOffset = chapterIndex === page.currentChapterIndex &&
      page.hasReaderTypographyRestoreOffset() ? page.readerTypographyRestoreOffset : -1;
    const targetOffset = rawTargetOffset < 0 ? -1 : Math.min(source.length, Math.max(0, rawTargetOffset));
    if (chapterIndex === page.currentChapterIndex && rawTargetOffset >= 0) {
      page.setReaderTypographyRestoreOffset(targetOffset);
    }
    while (!result.complete && result.pages.length < requestedPageCount) {
      const previousPageCount = result.pages.length;
      LeafFns.appendReaderV2PaginationBatch(result, chapterIndex, 1);
      if (result.pages.length <= previousPageCount) break;
    }
    ReaderOpenTrace.mark(page.bookUrl, 'v2-initial-window-ready',
      `pages=${result.pages.length} complete=${result.complete} offset=${targetOffset}`);
    return result;
}

export function registerReaderV2PaginationSession(page: ReadBookPage, source: string, chapterIndex: number, session: ReaderV2PaginationSession): void {
    const key = page.buildReaderPaginationCacheKey(chapterIndex, source);
    page.readerV2PageSetCache.set(key, session.pageSet);
    page.readerV2DocumentCache.set(key, session.document);
    while (page.readerV2PageSetCache.size > 3) {
      const oldest = page.readerV2PageSetCache.keys().next().value as string | undefined;
      if (!oldest) break;
      page.readerV2PageSetCache.delete(oldest);
      page.readerV2DocumentCache.delete(oldest);
    }
    if (chapterIndex === page.currentChapterIndex) {
      page.readerV2ActiveDocument = session.document;
      page.readerV2ActiveSnapshot = session.snapshot;
    }
}

export function readerV2PageSet(page: ReadBookPage, chapterIndex: number, source: string): ReaderV2PageSet | null {
    if (!source) return null;
    const key = page.buildReaderPaginationCacheKey(chapterIndex, source);
    const cached = page.readerV2PageSetCache.get(key);
    if (cached) return cached;
    // The pagination result owns the retained native session. Its small lookup cache can be evicted independently
    // while adjacent chapters are prepared; falling back to the owning session prevents a valid page boundary
    // from being rendered as a blank NodeContainer until the reader is reopened.
    const result = page.readerPaginationCache.get(key);
    return result?.v2Session?.pageSet || null;
}

export function readerV2Document(page: ReadBookPage, chapterIndex: number, source: string): ReaderV2Document | null {
    if (!source) return null;
    const key = page.buildReaderPaginationCacheKey(chapterIndex, source);
    const cached = page.readerV2DocumentCache.get(key);
    if (cached) return cached;
    return page.readerPaginationCache.get(key)?.v2Session?.document || null;
}

export function readerV2Page(page: ReadBookPage, chapterIndex: number, pageIndex: number, source: string): ReaderV2PageLayout | null {
    const pageSet = page.readerV2PageSet(chapterIndex, source);
    if (!pageSet || pageIndex < 0 || pageIndex >= pageSet.pages.length) return null;
    return pageSet.pages[pageIndex];
}

export function readerTextEditMenuOptions(page: ReadBookPage, textProvider: () => string): EditMenuOptions {
    return {
      onCreateMenu: (items: TextMenuItem[]): TextMenuItem[] => {
        const replaceItem: TextMenuItem = {
          id: TextMenuItemId.of(READER_REPLACE_MENU_ITEM_ID),
          content: '替换'
        };
        const copyIndex = items.findIndex((menuItem: TextMenuItem) =>
          menuItem.id.equals(TextMenuItemId.COPY));
        if (copyIndex >= 0) {
          items.splice(copyIndex, 0, replaceItem);
        } else {
          items.unshift(replaceItem);
        }
        return items;
      },
      onMenuItemClick: (item: TextMenuItem, range: TextRange): boolean => {
        if (item.id.equals(TextMenuItemId.of(READER_REPLACE_MENU_ITEM_ID))) {
          // range 是选区在当前 Text 节点全文中的下标，textProvider 与各节点登记可选文本时用的是同一份内容。
          const selectedText = textProvider().substring(range.start ?? 0, range.end ?? 0);
          page.scheduleReaderTextSelectionClear();
          page.openReaderReplaceRuleWithSelection(selectedText);
          return true;
        }
        // Let Harmony execute Copy/Translate/Share/Search first, then clear the native selection owned by Text.
        // Merely closing the menu leaves the highlight and handles alive until the page is destroyed.
        page.scheduleReaderTextSelectionClear();
        return false;
      }
    };
}

export function scheduleReaderTextSelectionClear(page: ReadBookPage): void {
    if (page.readerTextSelectionClearPending) return;
    page.readerTextSelectionClearPending = true;
    const serial = ++page.readerTextSelectionSerial;
    setTimeout(() => {
      // The flag must be released even when a newer selection superseded this clear, otherwise the
      // early return above would wedge and no later dismissal could ever run.
      page.readerTextSelectionClearPending = false;
      if (serial !== page.readerTextSelectionSerial) return;
      const controllers: Set<TextController> = new Set<TextController>();
      for (const controller of page.readerSelectableTextControllers.values()) controllers.add(controller);
      for (const controller of page.readerInlineActionTextControllers.values()) controllers.add(controller);
      for (const controller of controllers) {
        try {
          controller.closeSelectionMenu();
          controller.setTextSelection(-1, -1, { menuPolicy: MenuPolicy.HIDE });
        } catch (_) {
        }
      }
      page.clearReaderV2SelectionOverlay();
      page.setReaderTextSelectionActive(false);
      page.readerTextSelectionUntil = 0;
      page.suppressReaderTapClick = false;
      page.readerSelectionDismissArmed = false;
    }, 80);
}

export function republishCurrentReaderPageAfterBackground(page: ReadBookPage): void {
    if (page.contentPages.length === 0 || page.pendingRestorePageIndex >= 0 ||
      page.hasReaderTypographyRestoreOffset()) return;
    const pageText = page.getCurrentPageText();
    // Footer progress is declarative state, while V2正文 is retained by a native FrameNode. After a Home/resume
    // transition the controller can still point at the right page object even though RenderService retained the
    // last animation/capture submission. Re-publish both layers from the same authoritative page index and force
    // the lightweight native node to rebuild even when the page object identity has not changed.
    page.currentPageText = pageText;
    page.displayPageText = pageText;
    page.displayPageChapterIndex = page.currentChapterIndex;
    page.displayPageIndex = page.currentPageIndex;
    page.displayPageRenderKey++;
    page.forceCurrentReaderPageRender();
    page.refreshCurrentReaderV2RetainedPages(true);
}

export function currentReaderV2TtsOverlayKeys(page: ReadBookPage, paintVersion: number): string[] {
    if (!page.shouldUseReaderLayoutV2(page.pagedContentText) || !page.shouldRenderTtsFocus() ||
      page.readerV2TtsSourceStart < 0 || page.readerV2TtsSourceEnd <= page.readerV2TtsSourceStart) return [];
    return [`reader_v2_tts_${page.currentChapterIndex}_${page.currentPageIndex}_${paintVersion}`];
}

export function currentReaderV2SelectionSurfaceKeys(page: ReadBookPage, hostVersion: number): string[] {
    if (!page.shouldUseReaderLayoutV2(page.pagedContentText) ||
      page.readerV2NativeSelectionChapterIndex !== page.currentChapterIndex ||
      page.readerV2NativeSelectionPageIndex < page.currentPageIndex ||
      page.readerV2NativeSelectionPageIndex > page.currentPageIndex +
        (page.isLandscapeDoublePageActive() ? 1 : 0) ||
      page.readerV2NativeSelectionFragmentIndex < 0) return [];
    return [`reader_v2_selection_surface_${page.readerV2NativeSelectionChapterIndex}_` +
      `${page.readerV2NativeSelectionPageIndex}_${page.readerV2NativeSelectionFragmentIndex}_` +
      `${hostVersion}`];
}

export function currentReaderV2SelectionOverlayKeys(page: ReadBookPage, paintVersion: number): string[] {
    if (!page.shouldUseReaderLayoutV2(page.pagedContentText) ||
      page.readerV2SelectionChapterIndex !== page.currentChapterIndex ||
      page.readerV2SelectionPageIndex < page.currentPageIndex ||
      page.readerV2SelectionPageIndex > page.currentPageIndex +
        (page.isLandscapeDoublePageActive() ? 1 : 0) ||
      page.readerV2SelectionDisplayStart < 0 ||
      page.readerV2SelectionDisplayEnd <= page.readerV2SelectionDisplayStart) return [];
    return [`reader_v2_selection_paint_${page.readerV2SelectionChapterIndex}_` +
      `${page.readerV2SelectionPageIndex}_${paintVersion}`];
}

export function readerV2SurfaceTopOffset(page: ReadBookPage): number {
    // Simulation/stack pages are laid out in a full-screen sheet and inset the live正文 with explicit top
    // padding. onAreaChange still reports the unpadded sheet origin for both the page and tap layer, so their
    // global-position delta can be zero even though painted glyphs start below the status bar. Keep that
    // declarative padding in the hit-test origin; otherwise every long press resolves roughly one line lower.
    const contentTopPadding = page.getReaderPageContentTopPadding();
    const measuredOffset = page.readerCommentPageAreaTop - page.readerTapLayerGlobalY;
    if (page.readerCommentPageAreaTop >= 0 && Number.isFinite(measuredOffset)) {
      return Math.max(contentTopPadding, measuredOffset);
    }
    return contentTopPadding;
}

export function clearReaderV2SelectionOverlay(page: ReadBookPage): void {
    const hasNativeHost = page.readerV2NativeSelectionFragmentIndex >= 0;
    if (page.readerV2SelectionDisplayStart < 0 && page.readerV2SelectionDisplayEnd < 0 && !hasNativeHost) return;
    page.readerV2SelectionChapterIndex = -1;
    page.readerV2SelectionPageIndex = -1;
    page.readerV2SelectionDisplayStart = -1;
    page.readerV2SelectionDisplayEnd = -1;
    page.readerV2NativeSelectionChapterIndex = -1;
    page.readerV2NativeSelectionPageIndex = -1;
    page.readerV2NativeSelectionFragmentIndex = -1;
    page.readerV2NativeSelectionRole = '';
    page.readerV2NativeSelectionPendingStart = -1;
    page.readerV2NativeSelectionPendingEnd = -1;
    page.readerV2NativeSelectionPendingSerial = -1;
    if (page.readerV2NativeSelectionRecalibrateTimerId >= 0) {
      clearTimeout(page.readerV2NativeSelectionRecalibrateTimerId);
      page.readerV2NativeSelectionRecalibrateTimerId = -1;
    }
    page.readerV2NativeSelectionActiveStart = -1;
    page.readerV2NativeSelectionActiveEnd = -1;
    page.readerV2NativeSelectionOffsetX = 0;
    page.readerV2NativeSelectionOffsetY = 0;
    page.readerV2NativeSelectionHostVersion++;
    page.readerV2SelectionPaintVersion++;
}

export function readerV2LocatedPagePoint(page: ReadBookPage, xVp: number, yVp: number): number[] {
    let pageIndex = page.currentPageIndex;
    let localX = xVp;
    if (page.isLandscapeDoublePageActive()) {
      const dividerLeft = Math.max(0, (page.pageViewWidth - READER_DOUBLE_PAGE_DIVIDER_WIDTH) / 2);
      if (xVp > dividerLeft + READER_DOUBLE_PAGE_DIVIDER_WIDTH) {
        pageIndex++;
        localX = xVp - dividerLeft - READER_DOUBLE_PAGE_DIVIDER_WIDTH;
      }
    }
    return [pageIndex, LeafFns.toMeasurePx(localX), LeafFns.toMeasurePx(yVp), 1];
}

export function readerV2TtsSourceOffset(page: ReadBookPage, speechOffset: number): number {
    return page.readerV2ActiveSpeechText ? page.readerV2ActiveSpeechText.sourceOffsetAt(speechOffset) :
      page.ttsTextStartOffset + speechOffset;
}

export function refreshReaderV2TtsOverlay(page: ReadBookPage): void {
    // The declarative overlay is republished by readerV2TtsPaintVersion. Do not rely on a retained
    // RenderNode invalidation here: on affected devices it only becomes visible after turning a page.
}

export async function exitReaderPage(page: ReadBookPage): Promise<void> {
    if (page.readerExitProgressSaved) {
      return;
    }
    // Freeze scroll-derived progress before awaiting the database write. During the route transition List can emit
    // a shorter visible range (notably 3..3 for a short final item that was pinned below 3..4), which otherwise
    // downgrades a saved 5/5 position to 4/5 immediately before the exit checkpoint is serialized.
    page.readerPageVisible = false;
    page.clearReaderPagedProgressSaveTimer();
    page.hideReaderPanels();
    if (page.openedFromShortcut) {
      page.readerExitProgressSaved = true;
      page.saveReadingProgress(true).catch((error: Error) => {
        console.error('快捷入口返回时保存进度失败:', error);
      });
      try {
        if (page.shortcutReplacedPreviousPage) {
          await router.replaceUrl({ url: 'pages/Index' });
        } else {
          router.back();
        }
      } catch (e) {
        console.error('快捷入口返回书架失败:', e);
      }
      return;
    }
    try {
      await page.saveReadingProgress(true);
      page.readerExitProgressSaved = true;
    } catch (e) {
      console.error('返回阅读页时保存进度失败:', e);
    }
    if (page.openedWithShelfAnimation) {
      AppStorage.setOrCreate('shelfBookCloseAnimationUrl', page.bookUrl);
      AppStorage.setOrCreate('shelfBookCloseAnimationNonce', Date.now());
    }
    router.back();
}
