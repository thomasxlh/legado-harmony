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

export function getTapZoneIndex(page: ReadBookPage, x: number, y: number, width: number, height: number): number {
    const column = Math.max(0, Math.min(2, Math.floor(Math.max(0, x) / Math.max(1, width / 3))));
    const row = Math.max(0, Math.min(2, Math.floor(Math.max(0, y) / Math.max(1, height / 3))));
    return row * 3 + column;
}

export function commitReaderTapZone(page: ReadBookPage, index: number): boolean {
    return page.commitReaderTapAction(page.readerTapZoneActionAt(index));
}

export function commitReaderTapAction(page: ReadBookPage, action: number): boolean {
    if (page.isReaderInteractiveActionActive()) {
      return true;
    }
    switch (action) {
      case 1:
        page.showMenu = true;
        return true;
      case 2:
        page.turnNext();
        return true;
      case 3:
        page.turnPrev();
        return true;
      case 0:
      default:
        return true;
    }
}

export function readerTapZoneActionsList(page: ReadBookPage): number[] {
    const fallback = [3, 3, 3, 3, 1, 2, 2, 2, 2];
    const parts = (page.readerTapZoneActions || '').split(',');
    const result: number[] = [];
    for (let i = 0; i < 9; i++) {
      const parsed = Number(parts[i]);
      result.push(Number.isFinite(parsed) && parsed >= 0 && parsed <= 3 ? Math.round(parsed) : fallback[i]);
    }
    return result;
}

export function readerTapZoneActionAt(page: ReadBookPage, index: number): number {
    const actions = page.readerTapZoneActionsList();
    const safeIndex = Math.max(0, Math.min(8, Math.round(index)));
    return actions[safeIndex];
}

export function cycleTapZoneAction(page: ReadBookPage, index: number): void {
    const actions = page.readerTapZoneActionsList();
    const safeIndex = Math.max(0, Math.min(8, Math.round(index)));
    actions[safeIndex] = (actions[safeIndex] + 1) % 4;
    page.setTapZoneActions(actions.join(','));
}

export function setTapZoneActions(page: ReadBookPage, actions: string): void {
    const normalized = LeafFns.normalizeTapZoneActions(actions);
    page.readerTapZoneActions = normalized;
    ReaderSettingsStore.saveTapZoneActions(page.hostContext(), normalized).catch((e: Error) => {
      console.error('保存点击区域动作失败:', e);
    });
}

export function tapZoneSummaryText(page: ReadBookPage): string {
    const actions = page.readerTapZoneActionsList();
    let menuCount = 0;
    let nextCount = 0;
    let prevCount = 0;
    let noneCount = 0;
    for (const action of actions) {
      if (action === 1) {
        menuCount++;
      } else if (action === 2) {
        nextCount++;
      } else if (action === 3) {
        prevCount++;
      } else {
        noneCount++;
      }
    }
    return `菜单${menuCount} · 下一页${nextCount} · 上一页${prevCount} · 无动作${noneCount}`;
}

export function isReaderTouchMoved(page: ReadBookPage, offsetX: number, offsetY: number): boolean {
    return Math.abs(offsetX) > page.readerTapSlop || Math.abs(offsetY) > page.readerTapSlop;
}

export function consumeSuppressedReaderTapClick(page: ReadBookPage): boolean {
    if (page.isReaderInteractiveActionActive()) {
      page.suppressReaderTapClick = false;
      return true;
    }
    if (page.hasReaderTextSelection()) {
      // A stream whose Down began on an existing selection (armed) dismisses it. The release of the
      // press that created the selection also lands here and must only be swallowed — clearing it
      // would close the freshly shown menu the moment the finger lifts.
      if (page.readerSelectionDismissArmed) {
        page.scheduleReaderTextSelectionClear();
        // Keep suppressing until the selection actually clears, so a repeated tap cannot fall through
        // to a page turn while the highlight is still visible.
        page.suppressReaderTapClick = true;
      }
      return true;
    }
    if (!page.suppressReaderTapClick) {
      return false;
    }
    page.suppressReaderTapClick = false;
    return true;
  }

export function getReaderPageTurnGestureOffset(page: ReadBookPage, offsetX: number, offsetY: number): number {
    return page.isVerticalPageTurnAnimation() ? offsetY : offsetX;
}

export function isPageTurnCommitOffset(page: ReadBookPage, axisOffset: number, axisVelocity: number): boolean {
    const dimension = page.isVerticalPageTurnAnimation() ? page.getPageTurnHeight() : page.getPageTurnWidth();
    const commitDistance = Math.max(page.readerPageTurnCommitDistance, dimension * page.readerPageTurnCommitRatio);
    const total = Math.abs(axisOffset);
    if (total >= commitDistance) {
      return true;
    }
    const flickDistance = Math.max(page.readerPageTurnCommitDistance, dimension * page.readerPageTurnFlickRatio);
    return Math.abs(axisVelocity) >= page.readerPageTurnFlickVelocity && total >= flickDistance;
}

export function isReaderPageTurnCommitGesture(page: ReadBookPage, offsetX: number, offsetY: number, axisVelocity: number = 0): boolean {
    const directionRatio = page.readerPageTurnDirectionRatio;
    if (page.isVerticalPageTurnAnimation()) {
      return Math.abs(offsetY) > Math.abs(offsetX) * directionRatio &&
        page.isPageTurnCommitOffset(offsetY, axisVelocity);
    }
    return Math.abs(offsetX) > Math.abs(offsetY) * directionRatio &&
      page.isPageTurnCommitOffset(offsetX, axisVelocity);
}

export function commitReaderMove(page: ReadBookPage, offsetX: number, offsetY: number, releaseVelocity: number = 0): void {
    if (page.readerPageTurnGestureCommitted) {
      return;
    }
    page.readerPageTurnGestureCommitted = true;
    page.readerGestureTurnGuardUntil = Date.now() + 2500;
    page.readerGestureTurnAllowance = 1;
    // Touch and PanGesture both observe the same pointer stream. Closing both sides here makes
    // whichever callback arrives second a no-op instead of committing a second page.
    page.readerTouchActive = false;
    page.readerPanActive = false;
    if (page.isVerticalPageTurnAnimation()) {
      page.commitReaderVerticalMove(offsetY, releaseVelocity);
      return;
    }
    page.commitReaderHorizontalMove(offsetX, releaseVelocity);
}

export function commitReaderVerticalMove(page: ReadBookPage, offsetY: number, releaseVelocity: number = 0): void {
    if (!page.isVerticalPageTurnAnimation() || page.showToc || page.showSettings ||
      page.chapters.length === 0) {
      return;
    }
    if (offsetY < 0 && page.isPageTurnCommitOffset(offsetY, releaseVelocity)) {
      page.runPageTurnAnimation(1, 'gesture', false, releaseVelocity);
    } else if (offsetY > 0 && page.isPageTurnCommitOffset(offsetY, releaseVelocity)) {
      page.runPageTurnAnimation(-1, 'gesture', false, releaseVelocity);
    } else {
      page.resetSlidePageEffect();
    }
}

export function commitReaderHorizontalMove(page: ReadBookPage, offsetX: number, releaseVelocity: number = 0): void {
    if ((page.readerEffectivePageTurnMode() !== 1 && page.readerEffectivePageTurnMode() !== 2) ||
      page.showToc || page.showSettings ||
      page.chapters.length === 0) {
      return;
    }
    if (offsetX < 0 && page.isPageTurnCommitOffset(offsetX, releaseVelocity)) {
      page.runPageTurnAnimation(1, 'gesture', false, releaseVelocity);
    } else if (offsetX > 0 && page.isPageTurnCommitOffset(offsetX, releaseVelocity)) {
      page.runPageTurnAnimation(-1, 'gesture', false, releaseVelocity);
    } else {
      page.resetSlidePageEffect();
    }
}

export function settingsPanelTitle(page: ReadBookPage): string {
    if (page.settingsPanelTab === 1) return '朗读设置';
    if (page.settingsPanelTab === 2) return '排版设置';
    return '阅读设置';
}

export function readerTypographySelectedLabel(page: ReadBookPage): string {
    if (page.readerTypographySelection === 1) return '字距';
    if (page.readerTypographySelection === 2) return '行距';
    if (page.readerTypographySelection === 3) return '段落间距';
    if (page.readerTypographySelection === 4) return '左边距';
    if (page.readerTypographySelection === 5) return '右边距';
    if (page.readerTypographySelection === 6) return '上边距';
    if (page.readerTypographySelection === 7) return '下边距';
    return '字号';
}

export function readerTextAlignSelectedIndex(page: ReadBookPage): number {
    const index = LeafFns.readerTextAlignValues().indexOf(page.readerTextAlign);
    return index >= 0 ? index : 0;
}

export function setReaderTextAlignByIndex(page: ReadBookPage, index: number): void {
    const values = LeafFns.readerTextAlignValues();
    page.readerTextAlign = index >= 0 && index < values.length ? values[index] : 'justify';
    page.saveReaderLayoutSettings();
}

export function readerTypographyValue(page: ReadBookPage, settingIndex: number): number {
    if (settingIndex === 0) return page.readerTypographyFontSize;
    if (settingIndex === 1) return page.readerTypographyLetterSpacing;
    if (settingIndex === 2) return page.readerTypographyLineHeight;
    if (settingIndex === 3) return page.readerTypographyParagraphSpacing;
    if (settingIndex === 4) return page.readerTypographyMarginLeft;
    if (settingIndex === 5) return page.readerTypographyMarginRight;
    if (settingIndex === 6) return page.readerTypographyMarginTop;
    return page.readerTypographyMarginBottom;
}

export function openReaderTypographyValueInput(page: ReadBookPage): void {
    page.readerTypographyValueDraft = '';
    page.showReaderTypographyValueInput = true;
}

export function applyReaderTypographyValueInput(page: ReadBookPage): void {
    if (!page.showReaderTypographyValueInput) return;
    const value = Number(page.readerTypographyValueDraft);
    if (!page.readerTypographyValueDraft.trim() || !Number.isFinite(value)) {
      page.showReaderTypographyValueInput = false;
      return;
    }
    page.applyReaderTypographyValue(page.readerTypographySelection, value);
    page.showReaderTypographyValueInput = false;
}

export function applyReaderTypographyValue(page: ReadBookPage, settingIndex: number, value: number): void {
    const rounded = Math.round(value);
    if (settingIndex === 0) {
      page.readerTypographyFontSize = Math.max(14, Math.min(rounded, 50));
    } else if (settingIndex === 1) {
      page.readerTypographyLetterSpacing = Math.max(0, Math.min(rounded, 8));
    } else if (settingIndex === 2) {
      page.readerTypographyLineHeight = Math.max(0, Math.min(rounded, 52));
    } else if (settingIndex === 3) {
      page.readerTypographyParagraphSpacing = Math.max(0, Math.min(rounded, 32));
    } else if (settingIndex === 4) {
      page.readerTypographyMarginLeft = Math.max(0, Math.min(rounded, 80));
    } else if (settingIndex === 5) {
      page.readerTypographyMarginRight = Math.max(0, Math.min(rounded, 80));
    } else if (settingIndex === 6) {
      page.readerTypographyMarginTop = Math.max(0, Math.min(rounded, 120));
    } else {
      page.readerTypographyMarginBottom = Math.max(0, Math.min(rounded, 120));
    }
    page.readerTypographyDraftPending = true;
    page.readerTypographyValueRevision++;
    page.scheduleReaderTypographyChange();
}

export function stepReaderTypographyValue(page: ReadBookPage, settingIndex: number, delta: number): void {
    const nextValue = page.readerTypographyValue(settingIndex) + delta;
    page.applyReaderTypographyValue(settingIndex, nextValue);
}

export function syncReaderTypographyDraft(page: ReadBookPage): void {
    page.readerTypographyFontSize = page.readerFontSize;
    page.readerTypographyLetterSpacing = page.readerLetterSpacing;
    page.readerTypographyLineHeight = page.readerLineHeight;
    page.readerTypographyParagraphSpacing = page.readerParagraphSpacing;
    page.readerTypographyMarginLeft = page.readerMarginLeft;
    page.readerTypographyMarginRight = page.readerMarginRight;
    page.readerTypographyMarginTop = page.readerMarginTop;
    page.readerTypographyMarginBottom = page.readerMarginBottom;
    page.readerTypographyValueRevision++;
}

export function commitReaderTypographyDraft(page: ReadBookPage): void {
    if (!page.readerTypographyDraftPending) return;
    page.readerLayoutCommitInProgress = true;
    page.readerFontSize = page.readerTypographyFontSize;
    page.readerLetterSpacing = page.readerTypographyLetterSpacing;
    page.readerLineHeight = page.readerTypographyLineHeight;
    page.readerParagraphSpacing = page.readerTypographyParagraphSpacing;
    page.readerMarginLeft = page.readerTypographyMarginLeft;
    page.readerMarginRight = page.readerTypographyMarginRight;
    page.readerMarginTop = page.readerTypographyMarginTop;
    page.readerMarginBottom = page.readerTypographyMarginBottom;
    page.readerLayoutCommitInProgress = false;
    page.readerTypographyDraftPending = false;
}

export function pageTurnModeSelectedIndex(page: ReadBookPage): number {
    const index = LeafFns.pageTurnModeTypes().indexOf(page.readerPageTurnMode);
    return index >= 0 ? index : 1;
}

export function pageTurnAnimationOptions(page: ReadBookPage): SelectOption[] {
    const options: SelectOption[] = [
      { value: '无动画' },
      { value: '平移' },
      { value: '淡入' },
      { value: '叠页' }
    ];
    if (page.readerPageTurnMode === 2) {
      options.push({ value: '仿真' });
      options.push({ value: '3D仿真' });
    }
    return options;
}

export function pageTurnAnimationTypes(page: ReadBookPage): number[] {
    const types: number[] = [
      ReaderSettingsStore.PAGE_TURN_ANIMATION_NONE,
      ReaderSettingsStore.PAGE_TURN_ANIMATION_SLIDE,
      ReaderSettingsStore.PAGE_TURN_ANIMATION_FADE,
      ReaderSettingsStore.PAGE_TURN_ANIMATION_STACK
    ];
    if (page.readerPageTurnMode === 2) {
      types.push(ReaderSettingsStore.PAGE_TURN_ANIMATION_SIMULATION);
      types.push(ReaderSettingsStore.PAGE_TURN_ANIMATION_3D);
    }
    return types;
}

export function pageTurnAnimationSelectedIndex(page: ReadBookPage): number {
    const types = page.pageTurnAnimationTypes();
    const value = page.normalizePageTurnAnimationType(page.readerPageTurnAnimationType);
    for (let i = 0; i < types.length; i++) {
      if (types[i] === value) {
        return i;
      }
    }
    return 0;
}

export function pageTurnAnimationValue(page: ReadBookPage): string {
    const options = page.pageTurnAnimationOptions();
    const index = page.pageTurnAnimationSelectedIndex();
    const option = options[index];
    return option && typeof option.value === 'string' ? option.value : '无动画';
}

export function screenTimeoutSelectedIndex(page: ReadBookPage): number {
    const values = LeafFns.screenTimeoutValues();
    const current = ReaderSettingsStore.normalizeScreenTimeoutMinutes(page.readerScreenTimeoutMinutes);
    for (let i = 0; i < values.length; i++) {
      if (values[i] === current) {
        return i;
      }
    }
    return 0;
}

export function screenOrientationSelectedIndex(page: ReadBookPage): number {
    const value = ReaderSettingsStore.normalizeScreenOrientation(page.readerScreenOrientation);
    const values = LeafFns.screenOrientationValues();
    for (let i = 0; i < values.length; i++) {
      if (values[i] === value) return i;
    }
    return 0;
}

export function readerEyeTurnPromptVisible(page: ReadBookPage): boolean {
    return (page.readerEyeTurnStatus || '').indexOf('向上看，翻下一页') >= 0;
}

export function readerEyeTurnPromptTop(page: ReadBookPage): number {
    const viewportHeight = page.pageViewHeight > 0 ? page.pageViewHeight : 720;
    return Math.max(48, viewportHeight - page.getReaderContentBottomReserve() -
      page.getEffectiveReaderMarginBottom() - 48);
}

export function readerEyeCalibrationTargetTopVp(page: ReadBookPage): number {
    const overlayHeight = page.readerEyeCalibrationOverlayHeight > 0 ?
      page.readerEyeCalibrationOverlayHeight : Math.max(1, page.pageViewHeight);
    // Keep both targets clear of the system bars so they stay visible and reachable.
    const top = 4 + Math.max(0, page.statusBarSafeHeight);
    const bottom = Math.max(top, overlayHeight - 28 - Math.max(0, page.navBarHeight));
    const progress = Math.max(0, Math.min(1, (page.readerEyeCalibrationTargetY + 1) / 2));
    return top + (bottom - top) * progress;
}

export function readerEyeCalibrationPreviewWidthVp(page: ReadBookPage): number {
    const overlayWidth = page.readerEyeCalibrationOverlayWidth > 0 ?
      page.readerEyeCalibrationOverlayWidth : Math.max(1, page.pageViewWidth);
    const overlayHeight = page.readerEyeCalibrationOverlayHeight > 0 ?
      page.readerEyeCalibrationOverlayHeight : Math.max(1, page.pageViewHeight);
    return Math.max(150, Math.min(300, overlayWidth - 48, overlayHeight * 0.40 / 0.75));
}

export function readerEyeCalibrationPreviewHeightVp(page: ReadBookPage): number {
    return page.readerEyeCalibrationPreviewWidthVp() * 0.75;
}

export function readerEyeCalibrationPreviewLeftVp(page: ReadBookPage): number {
    const overlayWidth = page.readerEyeCalibrationOverlayWidth > 0 ?
      page.readerEyeCalibrationOverlayWidth : Math.max(1, page.pageViewWidth);
    return Math.max(0, (overlayWidth - page.readerEyeCalibrationPreviewWidthVp()) / 2);
}

export function readerEyeCalibrationPreviewHint(page: ReadBookPage): string {
    if (!page.readerEyeCalibrationCapturing) return '请让完整面部位于虚线框内';
    if (page.readerEyeTurnStatus.indexOf('未检测到') >= 0) return '未检测到面部，请调整距离和角度';
    if (page.readerEyeTurnStatus.indexOf('不稳定') >= 0) return '请保证正面光线充足';
    return '面部保持在框内，仅在本机处理';
}

export function readerEyeCalibrationInstruction(page: ReadBookPage): string {
    const label = page.currentReaderEyeCalibrationTargetLabel();
    return `第 ${page.readerEyeCalibrationStep + 1}/3 步：注视${label}目标点`;
}

export function switchPageTurnMode(page: ReadBookPage, mode: number): void {
    if (page.readerPageTurnMode === mode) {
      return;
    }
    page.setReaderTextSelectionActive(false);
    page.stopTtsReading();
    page.readerPageTurnMode = mode;
    if (mode === 0 && (Math.round(page.readerPageTurnAnimationType) ===
      ReaderSettingsStore.PAGE_TURN_ANIMATION_SIMULATION ||
      Math.round(page.readerPageTurnAnimationType) === ReaderSettingsStore.PAGE_TURN_ANIMATION_3D)) {
      page.readerPageTurnAnimationType = ReaderSettingsStore.PAGE_TURN_ANIMATION_STACK;
      page.resetSlidePageEffect();
      ReaderSettingsStore.savePageTurnAnimationType(page.hostContext(), page.readerPageTurnAnimationType)
        .catch((e: Error) => {
          console.error('降级上下滑动翻页动画失败:', e);
        });
    }
    ReaderSettingsStore.savePageTurnMode(page.hostContext(), mode).catch((e: Error) => {
      console.error('保存翻页方式失败:', e);
    });
    page.currentPageIndex = 0;
    page.pendingRestorePageIndex = 0;
    page.paginateContent(page.content);
    page.saveReadingProgress();
    page.saveReadConfig();
}

export function setReaderPageTurnAnimationType(page: ReadBookPage, index: number): void {
    const types = page.pageTurnAnimationTypes();
    const type = index >= 0 && index < types.length ? types[index] : ReaderSettingsStore.PAGE_TURN_ANIMATION_SLIDE;
    page.readerPageTurnAnimationType = page.normalizePageTurnAnimationType(type);
    page.resetSlidePageEffect();
    ReaderSettingsStore.savePageTurnAnimationType(page.hostContext(), page.readerPageTurnAnimationType).catch((e: Error) => {
      console.error('保存翻页动画失败:', e);
    });
    page.saveReadConfig();
}

export function normalizePageTurnAnimationType(page: ReadBookPage, type: number): number {
    const value = Math.round(type);
    if (page.readerPageTurnMode === 0 && (value === ReaderSettingsStore.PAGE_TURN_ANIMATION_SIMULATION ||
      value === ReaderSettingsStore.PAGE_TURN_ANIMATION_3D)) {
      return ReaderSettingsStore.PAGE_TURN_ANIMATION_STACK;
    }
    if (value === ReaderSettingsStore.PAGE_TURN_ANIMATION_NONE ||
      value === ReaderSettingsStore.PAGE_TURN_ANIMATION_SLIDE ||
      value === ReaderSettingsStore.PAGE_TURN_ANIMATION_FADE ||
      value === ReaderSettingsStore.PAGE_TURN_ANIMATION_STACK ||
      value === ReaderSettingsStore.PAGE_TURN_ANIMATION_SIMULATION ||
      value === ReaderSettingsStore.PAGE_TURN_ANIMATION_3D) {
      return value;
    }
    return ReaderSettingsStore.PAGE_TURN_ANIMATION_SLIDE;
}

export function isPageTurnAnimationEnabled(page: ReadBookPage): boolean {
    return page.normalizePageTurnAnimationType(page.readerPageTurnAnimationType) !== ReaderSettingsStore.PAGE_TURN_ANIMATION_NONE;
}

export function saveReaderLayoutSettings(page: ReadBookPage): void {
    ReaderSettingsStore.saveLayoutSettings(
      page.hostContext(),
      page.readerFontSize,
      page.readerLineHeight,
      page.readerParagraphSpacing,
      page.readerMarginLeft,
      page.readerMarginRight,
      page.readerMarginTop,
      page.readerMarginBottom,
      page.readerLetterSpacing,
      page.readerTextAlign
    ).catch((e: Error) => {
      console.warn('保存阅读排版设置失败:', e);
    });
}

export function setReaderLandscapeDoublePage(page: ReadBookPage, enabled: boolean): void {
    page.readerLandscapeDoublePage = enabled;
    ReaderSettingsStore.saveLandscapeDoublePage(page.hostContext(), enabled).catch((e: Error) => {
      console.error('保存双翻页设置失败:', e);
    });
}

export function setReaderScreenOrientationByIndex(page: ReadBookPage, index: number): void {
    const values = LeafFns.screenOrientationValues();
    page.readerScreenOrientation = index >= 0 && index < values.length ? values[index] :
      ReaderSettingsStore.SCREEN_ORIENTATION_SYSTEM;
    page.applyReaderScreenOrientation();
    ReaderSettingsStore.saveScreenOrientation(page.hostContext(), page.readerScreenOrientation).catch((e: Error) => {
      console.error('保存阅读屏幕方向失败:', e);
    });
}

export function applyReaderThemeIndex(page: ReadBookPage, index: number): void {
    const nextThemeIndex = ReaderThemeHelper.normalizeIndex(index);
    if (nextThemeIndex === page.currentReaderThemeIndex()) {
      return;
    }
    if (page.appDarkMode) {
      page.readerDarkThemeIndex = nextThemeIndex;
    } else {
      page.readerLightThemeIndex = nextThemeIndex;
    }
    page.saveReaderThemeSettings();
    page.saveReadConfig();
}

export function saveReaderThemeSettings(page: ReadBookPage): void {
    ReaderSettingsStore.saveThemeSettings(
      page.hostContext(),
      page.readerLightThemeIndex,
      page.readerDarkThemeIndex,
      page.readerLightCustomThemeBackgroundColor,
      page.readerLightCustomThemeTextColor,
      page.readerDarkCustomThemeBackgroundColor,
      page.readerDarkCustomThemeTextColor,
      page.appDarkMode,
      page.readerCustomThemesRaw
    ).catch((e: Error) => {
      console.warn('保存阅读配色设置失败:', e);
    });
}

export function setCurrentThemeBackgroundColor(page: ReadBookPage, color: string): void {
    const value = LeafFns.normalizeColor(color, page.currentCustomThemeBackgroundColor());
    const data = page.customThemeData();
    ReaderCustomThemeHelper.selected(data, page.appDarkMode).backgroundColor = value;
    page.persistCustomThemeData(data);
}

export function setCurrentThemeTextColor(page: ReadBookPage, color: string): void {
    const value = LeafFns.normalizeColor(color, page.currentCustomThemeTextColor());
    const data = page.customThemeData();
    ReaderCustomThemeHelper.selected(data, page.appDarkMode).textColor = value;
    page.persistCustomThemeData(data);
}

export function persistCustomThemeData(page: ReadBookPage, data: ReaderCustomThemeData): void {
    const selected = ReaderCustomThemeHelper.selected(data, page.appDarkMode);
    if (page.appDarkMode) {
      page.readerDarkCustomThemeBackgroundColor = selected.backgroundColor;
      page.readerDarkCustomThemeTextColor = selected.textColor;
    } else {
      page.readerLightCustomThemeBackgroundColor = selected.backgroundColor;
      page.readerLightCustomThemeTextColor = selected.textColor;
    }
    page.readerCustomThemesRaw = ReaderCustomThemeHelper.stringify(data);
    page.saveReaderThemeSettings();
    page.saveReadConfig();
}

export function addCustomTheme(page: ReadBookPage): void {
    const data = page.customThemeData();
    const item = ReaderCustomThemeHelper.add(data, page.appDarkMode);
    page.customThemeNameDraft = item.name;
    page.persistCustomThemeData(data);
}

export function closeReaderCustomThemeDeleteConfirm(page: ReadBookPage): void {
    page.showReaderCustomThemeDeleteConfirm = false;
    page.readerCustomThemeDeleteDialogSession.close(page.getUIContext());
}

export function deleteCurrentCustomTheme(page: ReadBookPage): void {
    const data = page.customThemeData();
    if (ReaderCustomThemeHelper.schemesForMode(data, page.appDarkMode).length <= 1) {
      HdsFeedback.showToast('至少保留一套自定义背景');
      return;
    }
    ReaderCustomThemeHelper.removeSelected(data, page.appDarkMode);
    page.customThemeNameDraft = ReaderCustomThemeHelper.selected(data, page.appDarkMode).name;
    page.persistCustomThemeData(data);
}

export function selectCustomTheme(page: ReadBookPage, index: number): void {
    const data = page.customThemeData();
    const schemes = ReaderCustomThemeHelper.schemesForMode(data, page.appDarkMode);
    if (index < 0 || index >= schemes.length) {
      return;
    }
    ReaderCustomThemeHelper.select(data, page.appDarkMode, schemes[index].id);
    page.customThemeNameDraft = schemes[index].name;
    page.persistCustomThemeData(data);
}

export function renameCurrentCustomTheme(page: ReadBookPage, name: string): void {
    const data = page.customThemeData();
    const current = ReaderCustomThemeHelper.selected(data, page.appDarkMode);
    const value = (name || '').trim().substring(0, 20);
    if (!value) {
      page.customThemeNameDraft = current.name;
      return;
    }
    current.name = value;
    page.customThemeNameDraft = value;
    page.persistCustomThemeData(data);
}

export async function chooseCurrentCustomThemeImage(page: ReadBookPage): Promise<void> {
    const data = page.customThemeData();
    const current = ReaderCustomThemeHelper.selected(data, page.appDarkMode);
    try {
      const imageUri = await ReaderBackgroundImageStore.pickAndSave(page.hostContext(), current.id);
      if (!imageUri) {
        return;
      }
      current.backgroundImageUri = imageUri;
      current.backgroundType = 'image';
      page.persistCustomThemeData(data);
    } catch (e) {
      console.error('选择阅读背景图片失败:', e);
      HdsFeedback.showToast('选择背景图片失败');
    }
}

export function clearCurrentCustomThemeImage(page: ReadBookPage): void {
    const data = page.customThemeData();
    const current = ReaderCustomThemeHelper.selected(data, page.appDarkMode);
    current.backgroundImageUri = '';
    current.backgroundType = 'color';
    page.persistCustomThemeData(data);
}

export function setCurrentCustomThemeBackgroundType(page: ReadBookPage, index: number): void {
    const data = page.customThemeData();
    ReaderCustomThemeHelper.selected(data, page.appDarkMode).backgroundType = index === 1 ? 'image' : 'color';
    page.persistCustomThemeData(data);
}

export function setCurrentCustomThemeImageFit(page: ReadBookPage, index: number): void {
    const fits = ['cover', 'contain', 'fill'];
    const data = page.customThemeData();
    ReaderCustomThemeHelper.selected(data, page.appDarkMode).backgroundImageFit = fits[index] || 'cover';
    page.persistCustomThemeData(data);
}

export function saveReaderInteractionSettings(page: ReadBookPage): void {
    ReaderSettingsStore.saveReadingInteractionSettings(
      page.hostContext(),
      page.readerVolumeTurnPage,
      page.readerScreenTimeoutMinutes,
      page.readerExtendToStatusBar
    ).catch((e: Error) => {
      console.error('保存阅读交互设置失败:', e);
    });
}

export function setReaderVolumeTurnPage(page: ReadBookPage, enabled: boolean): void {
    page.readerVolumeTurnPage = enabled;
    page.updateVolumeKeySubscription();
    page.saveReaderInteractionSettings();
    page.saveReadConfig();
}

export function setReaderEyeTurnEnabled(page: ReadBookPage, enabled: boolean): void {
    const serial = ++page.readerEyePermissionRequestSerial;
    if (!enabled) {
      page.readerEyeTurnEnabled = false;
      page.readerEyeTurnStatus = '未启用';
      page.showReaderEyeCalibration = false;
      page.stopArEyeTurnHost();
    page.readerEyeTurnController.stop().catch((error: Error): void => {
        console.warn('[EyeTurn] disable release failed:', error.message);
      });
      page.saveReaderEyeTurnSettings();
      return;
    }
    page.readerEyeTurnStatus = '正在请求相机权限';
    EyeTurnController.requestPermission(page.hostContext() as common.UIAbilityContext)
      .then((granted: boolean): void => {
        if (serial !== page.readerEyePermissionRequestSerial) return;
        if (!granted) {
          page.readerEyeTurnEnabled = false;
          page.readerEyeTurnStatus = '未获得相机权限';
          HdsFeedback.showToast('需要相机权限才能使用眼动翻页');
          page.saveReaderEyeTurnSettings();
          return;
        }
        page.readerEyeTurnEnabled = true;
        page.readerEyeTurnStatus = '正在启动眼动识别';
        page.saveReaderEyeTurnSettings();
        if (!page.currentReaderEyeCalibrationRaw()) {
          page.openReaderEyeCalibration();
        }
        // Conditional XComponent mounting happens after this state update; its onLoad callback starts the camera.
        setTimeout((): void => page.startReaderEyeTurnIfReady(), 0);
      })
      .catch((error: Error): void => {
        if (serial !== page.readerEyePermissionRequestSerial) return;
        page.readerEyeTurnEnabled = false;
        page.readerEyeTurnStatus = '相机权限请求失败';
        HdsFeedback.showToast(`眼动翻页启用失败：${error.message}`);
        page.saveReaderEyeTurnSettings();
      });
}

export function saveReaderEyeTurnSettings(page: ReadBookPage): void {
    ReaderSettingsStore.saveEyeTurnSettings(
      page.hostContext(),
      page.readerEyeTurnEnabled,
      page.readerEyeTurnPortraitCalibration,
      page.readerEyeTurnLandscapeCalibration,
      page.readerEyeTurnPreviousEnabled,
      page.readerEyeTurnNextEnabled,
      page.readerEyeTurnPreviousDwellMs,
      page.readerEyeTurnNextDwellMs
    ).catch((error: Error): void => {
      console.warn('[EyeTurn] save settings failed:', error.message);
    });
    page.saveReadConfig();
}

export function setReaderEyeTurnDirectionEnabled(page: ReadBookPage, previous: boolean, enabled: boolean): void {
    if (previous) page.readerEyeTurnPreviousEnabled = enabled;
    else page.readerEyeTurnNextEnabled = enabled;
    page.configureReaderEyeTurnController();
    page.saveReaderEyeTurnSettings();
}

export function setReaderEyeDwell(page: ReadBookPage, previous: boolean, index: number): void {
    const values = LeafFns.readerEyeDwellValues();
    const value = index >= 0 && index < values.length ? values[index] : 850;
    if (previous) page.readerEyeTurnPreviousDwellMs = value;
    else page.readerEyeTurnNextDwellMs = value;
    page.configureReaderEyeTurnController();
    page.saveReaderEyeTurnSettings();
}

export function isReaderEyeLandscape(page: ReadBookPage): boolean {
    // `pageViewWidth` can be the width of one pane in landscape double-page mode, which is smaller than the page
    // height and previously saved a landscape calibration into the portrait slot. Display geometry represents the
    // physical screen orientation and must be the primary source for camera calibration selection.
    try {
      const currentDisplay = display.getDefaultDisplaySync();
      if (currentDisplay.width > 0 && currentDisplay.height > 0) {
        return currentDisplay.width > currentDisplay.height;
      }
    } catch (_error) {
      // Fall through to the measured reader viewport on devices without synchronous display geometry.
    }
    if (page.pageViewWidth > 0 && page.pageViewHeight > 0) {
      return page.pageViewWidth > page.pageViewHeight;
    }
    return false;
}

export function currentReaderEyeCalibrationRaw(page: ReadBookPage): string {
    // AR Engine reports the gaze direction directly, so a per-device pitch/iris
    // calibration is neither needed nor meaningful. A synthetic centre/top/bottom
    // mapping plus the controller's runtime baseline is enough; the top/centre/bottom
    // recall calibration stays for the camera fallback only.
    if (page.arEngineFaceActive) return AR_EYE_CALIBRATION_RAW;
    const landscape = page.isReaderEyeLandscape();
    const preferred = landscape ? page.readerEyeTurnLandscapeCalibration : page.readerEyeTurnPortraitCalibration;
    // Keep existing users functional after fixing the old double-page orientation misclassification. The next
    // explicit calibration is persisted into the correct orientation slot.
    const stored = preferred ||
      (landscape ? page.readerEyeTurnPortraitCalibration : page.readerEyeTurnLandscapeCalibration);
    // No stored calibration must not disable eye-turning: the default iris mapping plus
    // the runtime baseline is already usable, and calibration stays optional.
    return stored || DEFAULT_EYE_CALIBRATION_RAW;
}

export function configureReaderEyeTurnController(page: ReadBookPage): void {
    const landscape = page.isReaderEyeLandscape();
    page.readerEyeTurnConfiguredLandscape = landscape;
    const calibrationRaw = page.currentReaderEyeCalibrationRaw();
    page.readerEyeTurnController.configure(
      calibrationRaw,
      page.readerEyeTurnNextDwellMs,
      (status: string): void => {
        if (page.readerEyeTurnStatus !== status) page.readerEyeTurnStatus = status;
      },
      (sample: EyeTurnSample): void => page.consumeReaderEyeCalibrationSample(sample),
      (direction: number): void => {
        if (direction <= 0) {
          page.readerEyeTurnStatus = '请回看屏幕中央';
          return;
        }
        if (!page.readerEyeTurnCanTrigger()) return;
        page.runPageTurnAnimation(1, 'tap').catch((error: Error): void => {
          console.warn('[EyeTurn] page turn failed:', error.message);
        });
      },
      (): boolean => {
        const allowed = page.readerEyeTurnCanTrigger();
        if (!allowed) console.info('[EyeTurn] turn blocked: ' + page.readerEyeTurnBlockReason());
        return allowed;
      }
    );
}

export function startReaderEyeTurnIfReady(page: ReadBookPage): void {
    if (!page.readerEyeTurnEnabled || !page.readerPageVisible || !page.readerEyeTurnSurfaceId) {
      console.info(`[EyeTurn] start skipped enabled=${page.readerEyeTurnEnabled} ` +
        `visible=${page.readerPageVisible} surface=${page.readerEyeTurnSurfaceId ? 'set' : 'EMPTY'}`);
      return;
    }
    page.configureReaderEyeTurnController();
    // AR Engine takes exclusive control of the camera, so the legacy camera
    // pipeline must not start in parallel: it would lose the camera, leaving
    // the preview and calibration without frames.
    page.startArEyeTurnHostIfAvailable();
}

export function startArEyeTurnHostIfAvailable(page: ReadBookPage): void {
    if (!READER_EYE_TURN_AR_ENABLED) {
      page.startReaderEyeTurnCamera();
      return;
    }
    // Page turns re-enter this path; keep a single AR session alive instead of
    // rebuilding it on every call.
    if (page.arEyeTurnHost || page.arEyeTurnHostLoading) return;
    page.arEyeTurnHostLoading = true;
    import('../core/reader/ArEngineEyeTracker').then((ar): void => {
      if (!page.readerEyeTurnEnabled || !page.readerPageVisible) {
        page.arEyeTurnHostLoading = false;
        return;
      }
      if (!ar.ArEngineEyeTracker.isAvailable()) {
        page.arEyeTurnHostLoading = false;
        page.startReaderEyeTurnCamera();
        return;
      }
      ar.createArEngineEyeTurnHost((signal: ArEyeSignal): void => {
        if (signal.blink > 0.65) return;
        const score = signal.lookDown - signal.lookUp;
        page.readerEyeTurnController.submitExternalScore(score, signal.confidence);
      }, (active: boolean): void => {
        page.arEngineFaceActive = active;
        // Switching the signal source also switches the calibration strategy.
        page.configureReaderEyeTurnController();
        if (active) {
          if (!page.showReaderEyeCalibration) {
            // AR now owns the camera, so release the camera pipeline.
            page.readerEyeTurnController.stop().catch((): void => {});
          }
        } else {
          // AR failed to start; fall back to the camera unless it already runs.
          page.startReaderEyeTurnCamera();
        }
      }).then((host: ArEyeTurnHost | null): void => {
        page.arEyeTurnHostLoading = false;
        if (!host) {
          page.startReaderEyeTurnCamera();
          return;
        }
        if (!page.readerEyeTurnEnabled || !page.readerPageVisible) {
          host.stop();
          return;
        }
        page.stopArEyeTurnHost();
        page.arEyeTurnHost = host;
        page.arEyeTurnHostMounted = true;
      }).catch((error: Error): void => {
        page.arEyeTurnHostLoading = false;
        console.warn('[EyeTurn] AR host unavailable:', error.message);
        page.startReaderEyeTurnCamera();
      });
    }).catch((error: Error): void => {
      // AR Engine is not present on this device; the camera path keeps working.
      page.arEyeTurnHostLoading = false;
      console.warn('[EyeTurn] AR kit not available:', error.message);
      page.startReaderEyeTurnCamera();
    });
}

export function startReaderEyeTurnCamera(page: ReadBookPage): void {
    if (!page.readerEyeTurnEnabled || !page.readerPageVisible || !page.readerEyeTurnSurfaceId) return;
    if (page.readerEyeTurnController.isRunning()) return;
    page.readerEyeTurnController.start(
      page.hostContext() as common.UIAbilityContext,
      page.readerEyeTurnSurfaceId
    ).catch((error: Error): void => {
      page.readerEyeTurnStatus = `眼动识别启动失败：${error.message}`;
    });
}

export function readerEyeTurnSignalReady(page: ReadBookPage): boolean {
    return page.arEngineFaceActive || page.readerEyeTurnController.isRunning();
}

export function stopArEyeTurnHost(page: ReadBookPage): void {
    const host = page.arEyeTurnHost;
    page.arEyeTurnHost = null;
    page.arEyeTurnHostMounted = false;
    page.arEngineFaceActive = false;
    if (host) host.stop();
}

export function refreshReaderEyeTurnForViewport(page: ReadBookPage): void {
    if (!page.readerEyeTurnEnabled) return;
    const landscape = page.isReaderEyeLandscape();
    if (landscape === page.readerEyeTurnConfiguredLandscape) return;
    page.configureReaderEyeTurnController();
    if (!page.currentReaderEyeCalibrationRaw()) {
      page.readerEyeTurnStatus = landscape ? '横屏需要校准' : '竖屏需要校准';
    }
}

export function readerEyeTurnCanTrigger(page: ReadBookPage): boolean {
    // Any reader overlay pauses eye-turning: menus, the settings/action panels and the
    // comment panel all sit above the text, so a gaze turn there would act on content the
    // reader cannot see.
    return page.readerEyeTurnEnabled && page.readerPageVisible && !page.showReaderEyeCalibration &&
      !page.showMenu && !page.showToc && !page.showSettings && !page.showReaderActionMenu &&
      !page.showBookmarkActionMenu && !page.showTapZoneSettings && !page.showChangeSourceDialog &&
      !page.showReaderCommentPanel && !page.readerTextSelectionActive && !page.isLoading &&
      page.readerInitialPageReady && page.readerEffectivePageTurnMode() !== 3 &&
      !page.isReaderPaginationInteractionBusy();
}

export function readerEyeTurnBlockReason(page: ReadBookPage): string {
    if (!page.readerEyeTurnEnabled) return 'disabled';
    if (!page.readerPageVisible) return 'pageHidden';
    if (page.showReaderEyeCalibration) return 'calibration';
    if (page.showMenu) return 'menu';
    if (page.showToc) return 'toc';
    if (page.showSettings) return 'settings';
    if (page.showReaderActionMenu) return 'actionMenu';
    if (page.showBookmarkActionMenu) return 'bookmarkMenu';
    if (page.showTapZoneSettings) return 'tapZone';
    if (page.showChangeSourceDialog) return 'changeSource';
    if (page.readerTextSelectionActive) return 'textSelection';
    if (page.isLoading) return 'loading';
    if (!page.readerInitialPageReady) return 'pageNotReady';
    if (page.readerEffectivePageTurnMode() === 3) return 'scrollMode';
    if (page.showReaderCommentPanel) return 'commentPanel';
    if (page.isPageTurning) return 'isPageTurning';
    if (page.pageTurnAnimating) return 'pageTurnAnimating';
    if (page.readerPanActive) return 'readerPanActive';
    if (page.readerTouchActive) return 'readerTouchActive';
    if (page.readerComicChapterSwitching) return 'comicSwitching';
    if (page.pageSlideDirection !== 0) return 'pageSlide';
    if (page.queuedPageTurnCount > 0 || page.queuedPageTurnDirection !== 0) return 'queuedTurn';
    if (Date.now() < page.readerPaginationInteractionIdleUntil) return 'interactionIdle';
    if (page.isReaderPaginationInteractionBusy()) return 'paginationBusy';
    return 'ok';
}

export function openReaderEyeCalibration(page: ReadBookPage): void {
    page.clearReaderEyeCalibrationTimer();
    page.readerEyeCalibrationLandscape = page.isReaderEyeLandscape();
    page.readerEyeCalibrationStep = 0;
    page.readerEyeCalibrationCapturing = false;
    page.readerEyeCalibrationProgress = 0;
    page.readerEyeCalibrationTargetY = 0;
    page.readerEyeCalibrationPoints = [];
    page.readerEyeCalibrationSequenceStartedAt = 0;
    page.readerEyeCalibrationStartupAt = 0;
    page.readerEyeTurnController.setCalibrationMode(true);
    page.showMenu = false;
    page.showSettings = false;
    page.showReaderEyeCalibration = true;
}

export function beginReaderEyeCalibrationCapture(page: ReadBookPage): void {
    page.clearReaderEyeCalibrationTimer();
    page.readerEyeTurnController.setCalibrationMode(true);
    page.readerEyeCalibrationPoints = [];
    page.readerEyeCalibrationProgress = 0;
    page.readerEyeCalibrationStep = 0;
    page.readerEyeCalibrationTargetY = 0;
    page.readerEyeCalibrationPhaseStartedAt = 0;
    page.readerEyeCalibrationSequenceStartedAt = 0;
    page.readerEyeCalibrationStartupAt = Date.now();
    page.readerEyeCalibrationCapturing = false;
    page.readerEyeCalibrationSessionActive = true;
    // Calibration must not turn pages: keep the controller in calibration mode for the
    // whole session (zones, prompts and turns are all suppressed while it is set).
    page.readerEyeTurnController.setCalibrationMode(true);
    page.readerEyeTurnStatus = '请看向白色目标点，然后点击「开始采样」';
    if (!page.readerEyeTurnSignalReady()) page.startReaderEyeTurnIfReady();
}

export function startReaderEyeCalibrationPhaseSampling(page: ReadBookPage): void {
    if (!page.showReaderEyeCalibration ||
      page.readerEyeCalibrationStep >= READER_EYE_CALIBRATION_PHASE_COUNT) return;
    page.readerEyeCalibrationStartupAt = Date.now();
    page.readerEyeCalibrationPhaseStartedAt = 0;
    page.readerEyeCalibrationProgress = 0;
    page.readerEyeCalibrationCapturing = true;
    page.readerEyeTurnStatus = '请保持视线不动';
    page.scheduleReaderEyeCalibrationTick(80);
}

export function currentReaderEyeCalibrationTargetLabel(page: ReadBookPage): string {
    if (page.readerEyeCalibrationStep === 0) return '中央';
    if (page.readerEyeCalibrationStep === 1) return '底部';
    return '顶部';
}

export function consumeReaderEyeCalibrationSample(page: ReadBookPage, sample: EyeTurnSample): void {
    if (!page.showReaderEyeCalibration || !page.readerEyeCalibrationCapturing) return;
    if (page.readerEyeCalibrationLandscape !== page.isReaderEyeLandscape()) {
      page.abortReaderEyeCalibrationAttempt('校准过程中屏幕方向发生变化，请重新开始');
      HdsFeedback.showToast('校准过程中屏幕方向发生变化，请重新开始');
      return;
    }
    const phaseStartedAt = page.readerEyeCalibrationPhaseStartedAt;
    if (phaseStartedAt <= 0) return;
    const capturedAt = sample.capturedAt > 0 ? sample.capturedAt : Date.now();
    const phaseElapsed = capturedAt - phaseStartedAt;
    // The reader aims before tapping, so the whole window is usable.
    if (phaseElapsed < 0 || phaseElapsed > READER_EYE_CALIBRATION_HOLD_MS) return;
    if (!sample.eyeAvailable) return;
    const point = new ReaderEyeCalibrationPoint();
    point.score = sample.rawScore;
    point.pitch = sample.pitch;
    point.eyeRatio = sample.eyeRatio;
    point.eyeAvailable = true;
    point.targetY = page.readerEyeCalibrationTargetY;
    point.phase = page.readerEyeCalibrationStep;
    point.confidence = sample.confidence;
    page.readerEyeCalibrationPoints.push(point);
}

export function scheduleReaderEyeCalibrationTick(page: ReadBookPage, delayMs: number = READER_EYE_CALIBRATION_TICK_MS): void {
    if (!page.readerEyeCalibrationCapturing || !page.showReaderEyeCalibration) return;
    page.clearReaderEyeCalibrationTimer();
    page.readerEyeCalibrationTimerId = setTimeout((): void => {
      page.readerEyeCalibrationTimerId = -1;
      page.updateReaderEyeCalibrationSequence();
    }, delayMs);
}

export function updateReaderEyeCalibrationSequence(page: ReadBookPage): void {
    if (!page.readerEyeCalibrationCapturing || !page.showReaderEyeCalibration) return;
    if (page.readerEyeCalibrationLandscape !== page.isReaderEyeLandscape()) {
      page.abortReaderEyeCalibrationAttempt('屏幕方向已变化，请重新开始');
      return;
    }
    const now = Date.now();
    if (!page.readerEyeTurnSignalReady()) {
      if (now - page.readerEyeCalibrationStartupAt > 8000) {
        page.abortReaderEyeCalibrationAttempt('眼动识别启动超时，请重试');
        return;
      }
      page.readerEyeTurnStatus = '正在启动眼动识别';
      page.scheduleReaderEyeCalibrationTick(120);
      return;
    }
    if (page.readerEyeCalibrationPhaseStartedAt <= 0) {
      page.readerEyeCalibrationPhaseStartedAt = now;
      page.scheduleReaderEyeCalibrationTick();
      return;
    }
    const phaseElapsed = now - page.readerEyeCalibrationPhaseStartedAt;
    if (phaseElapsed < READER_EYE_CALIBRATION_HOLD_MS) {
      page.readerEyeCalibrationProgress = Math.max(0, Math.min(100,
        phaseElapsed * 100 / READER_EYE_CALIBRATION_HOLD_MS));
      page.scheduleReaderEyeCalibrationTick();
      return;
    }
    // Sampling done: stop and wait for the reader to tap for the next fixation.
    page.readerEyeCalibrationCapturing = false;
    page.readerEyeCalibrationProgress = 100;
    page.readerEyeCalibrationPhaseStartedAt = 0;
    page.clearReaderEyeCalibrationTimer();
    page.readerEyeCalibrationStep++;
    if (page.readerEyeCalibrationStep >= READER_EYE_CALIBRATION_PHASE_COUNT) {
      page.readerEyeCalibrationStep = READER_EYE_CALIBRATION_PHASE_COUNT - 1;
      page.finishReaderEyeCalibrationFromFixation();
      return;
    }
    page.readerEyeCalibrationTargetY = page.readerEyeCalibrationStep === 1 ? 1 : -1;
    page.readerEyeTurnStatus = `请看向${page.currentReaderEyeCalibrationTargetLabel()}目标点，然后点击「开始采样」`;
}

export function finishReaderEyeCalibrationFromFixation(page: ReadBookPage): void {
    const centerRatios: number[] = [];
    const bottomRatios: number[] = [];
    const topRatios: number[] = [];
    const centerPitches: number[] = [];
    for (const point of page.readerEyeCalibrationPoints) {
      if (!point.eyeAvailable) continue;
      if (point.phase === 0) {
        centerRatios.push(point.eyeRatio);
        centerPitches.push(point.pitch);
      } else if (point.phase === 1) {
        bottomRatios.push(point.eyeRatio);
      } else if (point.phase === 2) {
        topRatios.push(point.eyeRatio);
      }
    }
    const minimum = READER_EYE_CALIBRATION_MIN_PHASE_SAMPLES;
    if (centerRatios.length < minimum || bottomRatios.length < minimum || topRatios.length < minimum) {
      page.failReaderEyeCalibration(`有效样本不足（中央 ${centerRatios.length}／底部 ${bottomRatios.length}／顶部 ${topRatios.length}），请正对屏幕重试`);
      return;
    }
    const topRatio = LeafFns.readerEyeCalibrationMedian(topRatios);
    const bottomRatio = LeafFns.readerEyeCalibrationMedian(bottomRatios);
    // On this hardware the reading position and the bottom line are nearly identical in iris
    // terms, while the top line is clearly distinct. So the TOP fixation becomes the zero
    // crossing and the bottom/reading level the positive end; the turn then fires when the
    // gaze leaves that level upwards.
    const travel = bottomRatio - topRatio;
    const centerSpread = LeafFns.readerEyeCalibrationSpread(centerRatios);
    const bottomSpread = LeafFns.readerEyeCalibrationSpread(bottomRatios);
    const topSpread = LeafFns.readerEyeCalibrationSpread(topRatios);
    console.warn(`[EyeTurnProbe] calibration top=${topRatio.toFixed(4)} bottom=${bottomRatio.toFixed(4)} ` +
      `travel=${travel.toFixed(4)} center=${LeafFns.readerEyeCalibrationMedian(centerRatios).toFixed(4)} ` +
      `spread=${centerSpread.toFixed(4)}/${bottomSpread.toFixed(4)}/${topSpread.toFixed(4)} ` +
      `samples=${centerRatios.length}/${bottomRatios.length}/${topRatios.length}`);
    if (Math.abs(travel) < READER_EYE_CALIBRATION_MIN_DELTA) {
      page.failReaderEyeCalibration(`眼动差异不足（顶部 ${topRatio.toFixed(4)}／底部 ${bottomRatio.toFixed(4)}），请分别注视正文顶部和底部并保持住后重试`);
      return;
    }
    if (bottomSpread > Math.abs(travel) / 2.5 || topSpread > Math.abs(travel) / 2.5) {
      page.failReaderEyeCalibration('校准过程中视线不够稳定，请重新对准目标点并保持不动');
      return;
    }
    const eyeCenter = topRatio;
    const bottomDelta = travel;
    // The top side needs its own span; keep it a bounded fraction of the measured travel.
    const topDelta = (travel >= 0 ? -1 : 1) * Math.max(0.004, Math.abs(travel) * 0.15);
    const calibration = new EyeTurnCalibration();
    calibration.version = 3;
    calibration.top = -1;
    calibration.center = 0;
    calibration.bottom = 1;
    calibration.pitchCenter = LeafFns.readerEyeCalibrationMedian(centerPitches);
    calibration.pitchScale = 0;
    calibration.pitchTopDelta = 0;
    calibration.pitchBottomDelta = 0;
    calibration.eyeCenter = eyeCenter;
    calibration.eyeScale = (bottomDelta - topDelta) / 2;
    calibration.eyeTopDelta = topDelta;
    calibration.eyeBottomDelta = bottomDelta;
    calibration.eyeWeight = 1;
    calibration.pitchWeight = 0;
    // This mapping is anchored on the measured top fixation, so the runtime must not
    // re-centre it (that used to cancel the reading position out to zero).
    calibration.absolute = true;
    if (!calibration.isValid()) {
      page.failReaderEyeCalibration('眼动变化不足，请正对屏幕重新校准');
      return;
    }
    const raw = calibration.encode();
    if (page.readerEyeCalibrationLandscape) page.readerEyeTurnLandscapeCalibration = raw;
    else page.readerEyeTurnPortraitCalibration = raw;
    page.showReaderEyeCalibration = false;
    page.readerEyeCalibrationSessionActive = false;
    page.readerEyeTurnController.setCalibrationMode(false);
    page.readerEyeTurnStatus = '眼动翻页已就绪';
    page.configureReaderEyeTurnController();
    page.saveReaderEyeTurnSettings();
    HdsFeedback.showToast('眼动翻页校准完成');
}

export function failReaderEyeCalibration(page: ReadBookPage, message: string): void {
    page.readerEyeCalibrationSessionActive = false;
    page.readerEyeTurnController.setCalibrationMode(false);
    page.readerEyeCalibrationStep = 0;
    page.readerEyeCalibrationProgress = 0;
    page.readerEyeCalibrationTargetY = 0;
    page.readerEyeCalibrationSequenceStartedAt = 0;
    page.readerEyeTurnStatus = message;
    HdsFeedback.showToast(message);
}

export function abortReaderEyeCalibrationAttempt(page: ReadBookPage, message: string): void {
    page.readerEyeCalibrationSessionActive = false;
    page.clearReaderEyeCalibrationTimer();
    page.readerEyeTurnController.setCalibrationMode(false);
    page.readerEyeCalibrationCapturing = false;
    page.readerEyeCalibrationStep = 0;
    page.readerEyeCalibrationProgress = 0;
    page.readerEyeCalibrationTargetY = 0;
    page.readerEyeCalibrationSequenceStartedAt = 0;
    page.readerEyeTurnStatus = message;
}

export function clearReaderEyeCalibrationTimer(page: ReadBookPage): void {
    if (page.readerEyeCalibrationTimerId >= 0) {
      clearTimeout(page.readerEyeCalibrationTimerId);
      page.readerEyeCalibrationTimerId = -1;
    }
}

export function cancelReaderEyeCalibration(page: ReadBookPage): void {
    page.clearReaderEyeCalibrationTimer();
    page.readerEyeCalibrationCapturing = false;
    page.showReaderEyeCalibration = false;
    page.readerEyeTurnController.setCalibrationMode(false);
    if (!page.currentReaderEyeCalibrationRaw()) {
      page.readerEyeTurnEnabled = false;
      page.readerEyeTurnStatus = '未启用';
      page.stopArEyeTurnHost();
    page.readerEyeTurnController.stop().catch((error: Error): void => {
        console.warn('[EyeTurn] cancel calibration release failed:', error.message);
      });
      page.saveReaderEyeTurnSettings();
    }
}

export function setReaderScreenTimeoutByIndex(page: ReadBookPage, index: number): void {
    const values = LeafFns.screenTimeoutValues();
    page.readerScreenTimeoutMinutes = index >= 0 && index < values.length ?
      values[index] :
      ReaderSettingsStore.SCREEN_TIMEOUT_FOLLOW_SYSTEM;
    page.applyReaderScreenTimeout();
    page.saveReaderInteractionSettings();
    page.saveReadConfig();
}

export function setReaderExtendToStatusBar(page: ReadBookPage, enabled: boolean): void {
    if (page.readerExtendToStatusBar === enabled) return;
    const readingOffset = page.getReaderStableReflowOffset();
    page.readerExtendLayoutReadingOffset = readingOffset;
    page.readerExtendToStatusBar = enabled;
    page.syncReaderPageHeightForContentTopPadding();
    // StorageLink watchers can be delivered in a later UI task. Calling the coalesced refresh here
    // makes the switch responsive, while a subsequent watch notification only restarts the same timer.
    page.scheduleReaderExtendLayoutRefresh(readingOffset);
    page.saveReaderInteractionSettings();
    page.saveReadConfig();
}

export function setKeepParagraphIndent(page: ReadBookPage, enabled: boolean): void {
    if (page.keepParagraphIndent === enabled) return;
    page.keepParagraphIndent = enabled;
    // StorageLink 的 @Watch 会触发重排；这里同步持久化，保证下次进入阅读时生效。
    ReaderSettingsStore.saveKeepParagraphIndent(page.hostContext(), enabled).catch((e: Error) => {
      console.warn('保存保留段首缩进设置失败:', e);
    });
}

export function setReaderPreloadEnabled(page: ReadBookPage, enabled: boolean): void {
    page.readerPreloadEnabled = enabled;
    ReaderSettingsStore.savePreloadEnabled(page.hostContext(), enabled).catch((e: Error) => {
      console.error('保存预缓存开关失败:', e);
    });
    if (enabled) {
      page.preloadReaderContentLater();
    }
    page.saveReadConfig();
}

export function setReaderPreloadChapterCount(page: ReadBookPage, count: number): void {
    const value = Math.max(1, Math.min(Math.round(count), 10));
    page.readerPreloadChapterCount = value;
    ReaderSettingsStore.savePreloadChapterCount(page.hostContext(), value).catch((e: Error) => {
      console.error('保存预缓存章节数失败:', e);
    });
    page.preloadReaderContentLater();
    page.saveReadConfig();
}

export function setReaderQuickBookmarkEnabled(page: ReadBookPage, enabled: boolean): void {
    page.readerQuickBookmarkEnabled = enabled;
    if (!enabled && page.bookmarkPullActive) {
      page.finishBookmarkPull(false);
    }
    ReaderSettingsStore.saveQuickBookmarkEnabled(page.hostContext(), enabled).catch((e: Error) => {
      console.error('保存快速添加书签设置失败:', e);
    });
    page.saveReadConfig();
}
