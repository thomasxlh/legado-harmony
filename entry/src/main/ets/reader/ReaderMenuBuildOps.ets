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

export function handleReaderHdsAction(page: ReadBookPage, index: number, fromToc: boolean, fromSettings: boolean = false): void {
    if (page.isReaderComicModeActive() && (index === 1 || index === 2)) {
      return;
    }
    if (index === 0) {
      if (fromToc) {
        page.cancelBookmarkMultiSelect();
        page.showToc = false;
        page.showMenu = true;
      } else if (fromSettings) {
        page.showSettings = false;
        page.openTocPanel();
      } else {
        page.openTocPanel();
      }
      return;
    }
    if (index === 3) {
      // 日夜项由其自身的点击/长按手势处理，避免 HdsTabs 再次触发导致双重切换。
      return;
    }
    if (fromToc) {
      page.showToc = false;
    }
    if (index === 1) {
      if (fromSettings && page.settingsPanelTab === 0) {
        page.closeSettingsPanelKeepMenu();
      } else {
        page.openSettingsPanel();
      }
      return;
    }
    if (index === 2) {
      if (fromSettings && page.settingsPanelTab === 2) {
        page.closeSettingsPanelKeepMenu();
      } else {
        page.openTypographySettingsPanel();
      }
      return;
    }
}

export function readerDayNightIcon(page: ReadBookPage): Resource {
    const mode = AppThemeModeStore.normalizeMode(page.appThemeMode);
    if (mode === 'system') {
      return $r('sys.symbol.circle_lefthalf_inset_filled');
    }
    return mode === 'dark' ? $r('sys.symbol.moon') : $r('sys.symbol.sun_max');
}

export function toggleReaderDayNightMode(page: ReadBookPage): void {
    const currentMode = AppThemeModeStore.normalizeMode(page.appThemeMode);
    const currentDark = currentMode === 'dark' || (currentMode === 'system' && page.appDarkMode);
    page.applyReaderThemeMode(currentDark ? 'light' : 'dark');
}

export function setReaderAutoMode(page: ReadBookPage): void {
    page.applyReaderThemeMode('system');
}

export function handleReaderDayNightClick(page: ReadBookPage): void {
    if (page.readerDayNightLongPressHandled) {
      page.readerDayNightLongPressHandled = false;
      return;
    }
    page.toggleReaderDayNightMode();
}

export function handleReaderDayNightLongPress(page: ReadBookPage): void {
    page.readerDayNightLongPressHandled = true;
    page.setReaderAutoMode();
}

export function applyReaderThemeMode(page: ReadBookPage, nextMode: string): void {
    const context = page.hostContext() as common.UIAbilityContext;
    const systemDarkMode =
      context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    const nextDarkMode = nextMode === 'dark' || (nextMode === 'system' && systemDarkMode);
    const colorMode = nextMode === 'dark' ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK :
      (nextMode === 'light' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT :
        ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);

    // 先同步模式来源，避免 setColorMode 触发的 ConfigurationUpdate 读到旧值，
    // 又把刚选择的浅色模式覆盖回系统深色模式。
    AppThemeModeStore.applyToStorage(nextMode);
    if (page.appDarkMode !== nextDarkMode) {
      page.appDarkMode = nextDarkMode;
    }
    context.getApplicationContext().setColorMode(colorMode);

    AppThemeModeStore.save(context, nextMode).catch((e: Error) => {
      console.warn('保存日间/夜间/自动模式失败:', e);
    });
    HdsFeedback.showToast(nextMode === 'light' ? '已切换至日间模式' : (nextMode === 'dark' ? '已切换至夜间模式' : '已切换至自动模式'));
}

export function bookmarkSwipeActions(page: ReadBookPage, bookmark: Bookmark): HdsSwipeActionOptions {
    return { icons: [
      { icon: new SymbolGlyphModifier($r('sys.symbol.checkmark_circle')), backgroundColor: page.buttonColor(), iconOptions: { accessibilityText: '多选' }, onAction: () => page.enterBookmarkMultiSelect(bookmark.bookmarkUrl) },
      { icon: new SymbolGlyphModifier($r('sys.symbol.trash')), backgroundColor: ThemeRuntime.dangerColor(page.appDarkMode), iconOptions: { accessibilityText: '删除书签' }, onAction: () => page.deleteBookmark(bookmark) }
    ] };
}

export async function openChangeSourceDialog(page: ReadBookPage): Promise<void> {
    if (!page.book || !page.book.name) {
      HdsFeedback.showToast('当前书籍信息不完整');
      return;
    }
    // 换源要按"当前阅读章节"实测各源字数：先刷新阅读进度，
    // 否则翻页后 350ms 的节流保存还没跑，面板会拿旧 durChapterIndex 去测。
    // durChapterIndex 在首个 await 之前就已同步写入，无需等落库完成。
    page.saveReadingProgress();
    page.showMenu = false;
    page.showToc = false;
    page.showSettings = false;
    page.showChangeSourceDialog = true;
}
