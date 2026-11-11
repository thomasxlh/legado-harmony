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

export function openLayoutElementSettings(page: ReadBookPage): void {
    page.showReaderActionMenu = false;
    page.showLayoutElementSettings = true;
}

export function canSelectTxtCharset(page: ReadBookPage): boolean {
    const currentBook = page.book;
    return currentBook !== null && LocalBookService.isLocalBook(currentBook) &&
      currentBook.type === LocalBookService.TYPE_TXT;
}

export function txtCharsetMenuLabel(page: ReadBookPage): string {
    if (!page.book) return '自动';
    const charsetOverride = LocalBookService.getTxtCharsetOverride(page.book);
    return charsetOverride ? LeafFns.txtCharsetLabel(charsetOverride) : '自动';
}

export async function applyTxtCharsetSelection(page: ReadBookPage): Promise<void> {
    if (!page.book || !page.canSelectTxtCharset() || page.txtCharsetApplying) return;
    const targetBook: Book = page.book;
    const selectedCharset = page.txtCharsetDraft;
    if (selectedCharset === LocalBookService.getTxtCharsetOverride(targetBook)) {
      page.showTxtCharsetDialog = false;
      return;
    }
    page.txtCharsetApplying = true;
    try {
      await page.saveReadingProgress();
      page.stopTtsReading();
      await LocalBookService.setTxtCharsetOverride(page.hostContext(), targetBook, selectedCharset);
      page.showTxtCharsetDialog = false;
      page.showMenu = false;
      await page.loadBook();
      AppStorage.setOrCreate('shelfUpdateTime', Date.now());
      const applied = selectedCharset ? LeafFns.txtCharsetLabel(selectedCharset) :
        `自动识别（${LeafFns.txtCharsetLabel(page.book?.charset || '')}）`;
      HdsFeedback.showToast(`已使用 ${applied} 重新解析`);
    } catch (e) {
      console.error('切换 TXT 字符编码失败:', e);
      HdsFeedback.showToast('切换字符编码失败，请尝试其他编码');
    } finally {
      page.txtCharsetApplying = false;
    }
}

export function openCurrentReaderReplaceRules(page: ReadBookPage): void {
    page.prepareReaderReplaceRulesContext();
    page.returningFromReaderReplaceRules = true;
    page.hideReaderPanels();
    router.pushUrl({ url: 'pages/ReaderReplaceRules', params: { previewCurrentChapter: 'true' } });
}

export function prepareReaderReplaceRulesContext(page: ReadBookPage): void {
    const chapter = page.chapters.length > 0 ?
      page.chapters[page.clampChapterIndex(page.currentChapterIndex)] : null;
    const rawTitle = chapter ? page.cleanChapterTitle(chapter.title || '') : '';
    const cached = page.chapters.length > 0 ?
      ReadBookEngine.get().getCachedContent(page.currentChapterIndex) : '';
    const rawContent = cached || page.content || '';
    AppStorage.setOrCreate('readerReplacePreviewTitle', rawTitle);
    AppStorage.setOrCreate('readerReplacePreviewContent', rawContent.substring(0, 20000));
    AppStorage.setOrCreate('readerReplacePreviewBookName', page.book?.name || '');
    AppStorage.setOrCreate('readerReplacePreviewBookAuthor', page.book?.author || '');
    AppStorage.setOrCreate('readerReplacePreviewBookOriginName', page.book?.originName || '');
    AppStorage.setOrCreate('readerReplacePreviewBookOrigin', page.book?.origin || '');
    AppStorage.setOrCreate('readerReplacePreviewBookUrl', page.book?.bookUrl || page.bookUrl);
}

export function openReaderReplaceRuleWithSelection(page: ReadBookPage, selectedText: string): void {
    // 选中内容常带首尾空白与换行，作为字面匹配规则前先去掉，需要精确空白时可在编辑器里手动改回。
    const pattern = (selectedText || '').trim();
    if (!pattern) return;
    page.prepareReaderReplaceRulesContext();
    AppStorage.setOrCreate('readerReplaceRulePrefillPattern', pattern);
    page.returningFromReaderReplaceRules = true;
    page.hideReaderPanels();
    router.pushUrl({
      url: 'pages/ReaderReplaceRules',
      params: { previewCurrentChapter: 'true', prefillReplacePattern: 'true' }
    });
}

export function saveReaderLayoutElementSettings(page: ReadBookPage): void {
    ReaderSettingsStore.saveLayoutElementSettings(
      page.hostContext(),
      page.readerUseTtsQuickAction,
      page.readerTtsQuickActionSide,
      page.readerUseChapterQuickJump
    ).catch((e: Error) => {
      console.error('保存阅读布局元素设置失败:', e);
      HdsFeedback.showToast('布局元素设置保存失败');
    });
}

export function readerSourceNeedsLogin(page: ReadBookPage): boolean {
    const source = LeafFns.currentReaderSource();
    if (!source) return false;
    if (page.verificationUrl) return true;
    const loginUrl = String(source.loginUrl || '').trim();
    const loginUi = String(source.loginUi || '').trim();
    const loginCheckJs = String(source.loginCheckJs || '').trim();
    const loginHeader = String(source.loginHeader || '').trim();
    if (loginUrl || loginUi || loginCheckJs || loginHeader) return true;
    const rules = `${source.jsLib || ''}\n${source.searchUrl || ''}\n${source.exploreUrl || ''}\n` +
      `${source.bookInfoRule?.init || ''}\n${source.tocRule?.chapterList || ''}\n${source.contentRule?.content || ''}`;
    return /loginCheck|loginUrl|loginUi|book-source-login|请先登[录陆]|需要登[录陆]|账号登[录陆]|网页登录|登[录陆]后/i.test(rules);
}

export function openReaderSourceLogin(page: ReadBookPage): void {
    const source = LeafFns.currentReaderSource();
    if (!source || !page.readerSourceNeedsLogin()) return;
    page.showReaderActionMenu = false;
    page.showMenu = false;
    if (String(source.loginUi || '').trim()) {
      router.pushUrl({
        url: 'pages/BookSource',
        params: { openLoginSourceUrl: source.bookSourceUrl }
      });
      return;
    }
    const loginEntryUrl = page.verificationUrl || VerificationSupport.resolveBookSourceLoginUrl(source) ||
      VerificationSupport.pickVerificationUrl(source, source.bookSourceUrl);
    if (!loginEntryUrl || !/^https?:\/\//i.test(loginEntryUrl)) {
      HdsFeedback.showToast('未找到可用的网页登录地址，请检查书源登录配置');
      return;
    }
    VerificationSupport.requestVerification(loginEntryUrl, `${source.bookSourceName || '书源'} 登录`, source);
    router.pushUrl({
      url: 'pages/VerifyWeb',
      params: {
        url: loginEntryUrl,
        title: `${source.bookSourceName || '书源'} 登录`,
        requireLoginCookie: 'true'
      }
    });
}

export function readerCanRetry(page: ReadBookPage): boolean {
    return (page.chapters.length === 0 && page.book?.origin !== 'local') || !!page.verificationUrl;
}

export function retryReaderContent(page: ReadBookPage): void {
    page.hideReaderPanels();
    if (page.chapters.length === 0) {
      page.retryFetchChapters();
    } else {
      page.loadContent();
    }
}

export async function handleTtsQuickAction(page: ReadBookPage): Promise<void> {
    if (page.isReaderComicModeActive()) return;
    // The quick-action tap is above the page-turn layer. Consume its trailing click and discard
    // page turns queued while the menu was animating, otherwise they can execute many seconds
    // later between TTS focus turns and move the reader to an older chapter.
    page.suppressReaderTapClick = true;
    page.clearQueuedReaderPageTurns();
    page.ttsMediaControlsExpanded = false;
    // 僵尸会话同步：续播链路中断后 isTtsSpeaking 仍为 true 但朗读器已结束。
    // 先收尾旧会话，让下方分支从当前位置重新开始朗读并重新发布悬浮会话与目录。
    if (page.isTtsSpeaking && !page.ttsReader.isSpeaking() && !page.ttsReader.isPaused() &&
      !page.ttsChapterSwitching && !page.ttsManualPageTurnResumePending) {
      page.finishTtsReading();
    }
    page.loadTtsSettingsAndVoices();
    if (!page.isTtsSpeaking && !page.ttsReader.isSpeaking()) {
      await page.startTtsReadingFromCurrentPosition(true);
      page.ttsMediaControlsExpanded = false;
    } else {
      page.toggleTtsReading();
    }
}

export function shouldShowTtsMiniPlayer(page: ReadBookPage): boolean {
    return page.showMenu && !page.isReaderComicModeActive() &&
      (page.isTtsSpeaking || page.ttsReader.isSpeaking()) && !page.shouldBlockReaderInteraction();
}

export function shouldShowGlobalTtsMiniPlayer(page: ReadBookPage): boolean {
    return page.showMenu && page.globalTtsActive &&
      !ReaderTtsFloatingSession.isOwner(page.ttsFloatingSessionOwnerId) &&
      !page.isReaderComicModeActive() && !page.shouldBlockReaderInteraction();
}

export function openGlobalTtsCatalog(page: ReadBookPage): void {
    page.ttsCatalogFromLocalChapters = ReaderTtsFloatingSession.catalogTitles().length === 0 &&
      page.isTtsSpeaking && page.chapters.length > 0;
    const titles = page.ttsCatalogTitles();
    if (titles.length === 0) {
      HdsFeedback.showToast('暂未获取到听书目录');
      return;
    }
    page.globalTtsCatalogSource.replace(page.globalTtsCatalogReverseOrder ? titles.slice().reverse() : titles);
    // Re-snapshot at open time so the cache chip reflects chapters cached while this
    // session has been running, instead of the state at session publish time.
    if (!page.ttsCatalogFromLocalChapters) {
      ReaderTtsFloatingSession.updateCatalogCachedFlags(
        page.ttsFloatingSessionOwnerId, page.readerChapterCachedFlags());
    }
    animateTo({ duration: 280, curve: Curve.Friction }, () => {
      page.showGlobalTtsCatalog = true;
    });
    setTimeout(() => {
      if (!page.showGlobalTtsCatalog) return;
      try {
        page.globalTtsCatalogScroller.scrollToIndex(
          page.globalTtsCatalogDisplayIndex(page.ttsCatalogCurrentIndex()), false, ScrollAlign.CENTER);
      } catch (_) {}
    }, 0);
}

export function ttsCatalogTitles(page: ReadBookPage): string[] {
    if (page.ttsCatalogFromLocalChapters) {
      return page.chapters.map((chapter: BookChapter): string => chapter.title || '');
    }
    return ReaderTtsFloatingSession.catalogTitles();
}

export function ttsCatalogCount(page: ReadBookPage): number {
    return page.ttsCatalogFromLocalChapters ? page.chapters.length : ReaderTtsFloatingSession.catalogCount();
}

export function ttsCatalogCurrentIndex(page: ReadBookPage): number {
    return page.ttsCatalogFromLocalChapters ? page.currentChapterIndex : ReaderTtsFloatingSession.catalogIndex();
}

export function ttsCatalogCachedFlag(page: ReadBookPage, canonicalIndex: number): boolean {
    if (page.ttsCatalogFromLocalChapters) {
      return page.readerChapterCachedFlags()[canonicalIndex] === true;
    }
    return ReaderTtsFloatingSession.catalogCachedFlag(canonicalIndex);
}

export function closeGlobalTtsCatalog(page: ReadBookPage): void {
    animateTo({ duration: 210, curve: Curve.EaseIn }, () => {
      page.showGlobalTtsCatalog = false;
    });
}

export function selectGlobalTtsCatalog(page: ReadBookPage, index: number): void {
    page.closeGlobalTtsCatalog();
    const canonicalIndex = page.globalTtsCatalogCanonicalIndex(index);
    if (page.ttsCatalogFromLocalChapters) {
      page.playPositionFromFloatingSession(canonicalIndex, 0).catch((error: Error) => {
        console.warn('朗读目录跳转失败:', error);
      });
      return;
    }
    ReaderTtsFloatingSession.selectCatalogIndex(canonicalIndex);
}

export function globalTtsCatalogCanonicalIndex(page: ReadBookPage, displayIndex: number): number {
    const count = page.ttsCatalogCount();
    return page.globalTtsCatalogReverseOrder ? count - 1 - displayIndex : displayIndex;
}

export function globalTtsCatalogDisplayIndex(page: ReadBookPage, canonicalIndex: number): number {
    const count = page.ttsCatalogCount();
    return page.globalTtsCatalogReverseOrder ? count - 1 - canonicalIndex : canonicalIndex;
}

export function isGlobalTtsCatalogChapterCached(page: ReadBookPage, displayIndex: number): boolean {
    return page.ttsCatalogCachedFlag(page.globalTtsCatalogCanonicalIndex(displayIndex));
}

export function readerChapterCachedFlags(page: ReadBookPage): boolean[] {
    const flags: boolean[] = [];
    for (let index = 0; index < page.chapters.length; index++) {
      flags.push(page.book !== null && page.book.origin !== 'local' &&
        page.chapters[index].cacheDate > 0);
    }
    return flags;
}

export function toggleGlobalTtsCatalogOrder(page: ReadBookPage): void {
    page.globalTtsCatalogReverseOrder = !page.globalTtsCatalogReverseOrder;
    const titles = page.ttsCatalogTitles();
    page.globalTtsCatalogSource.replace(page.globalTtsCatalogReverseOrder ? titles.slice().reverse() : titles);
    setTimeout(() => {
      if (!page.showGlobalTtsCatalog) return;
      try {
        page.globalTtsCatalogScroller.scrollToIndex(
          page.globalTtsCatalogDisplayIndex(page.ttsCatalogCurrentIndex()), false, ScrollAlign.CENTER);
      } catch (_) {}
    }, 0);
}

export function openGlobalTtsReaderPage(page: ReadBookPage): void {
    const bookUrl = page.globalTtsBookUrl || AppStorage.get<string>('globalTtsBookUrl') || '';
    if (!bookUrl) {
      HdsFeedback.showToast('未能定位当前朗读书籍');
      return;
    }
    router.pushUrl({ url: 'pages/ReadBook', params: { bookUrl: bookUrl } }).catch((error: Error) => {
      console.warn('从听书面板返回朗读书籍阅读页失败:', error);
    });
}

export async function jumpToGlobalTtsPosition(page: ReadBookPage): Promise<void> {
    if (page.globalTtsBookUrl && page.bookUrl && page.globalTtsBookUrl !== page.bookUrl) {
      page.openGlobalTtsReaderPage();
      return;
    }
    const chapterIndex = page.activeMirroredTtsChapterIndex();
    if (chapterIndex < 0) {
      HdsFeedback.showToast('暂未获取到朗读位置');
      return;
    }
    const anchor = Math.max(0, Math.round(page.globalTtsOffsetStart));
    if (chapterIndex !== page.currentChapterIndex) {
      const loaded = await page.loadContent(true, chapterIndex);
      if (!loaded || page.currentChapterIndex !== chapterIndex) {
        return;
      }
    }
    const pageIndex = page.normalizeReaderSpreadPageIndex(page.findPageIndexByOffset(anchor));
    if (pageIndex < 0 || pageIndex >= page.contentPages.length) {
      return;
    }
    if (pageIndex !== page.currentPageIndex) {
      page.finishPageTurnAnimation();
      page.currentPageIndex = pageIndex;
      page.syncCurrentPageText();
    }
}

export function ttsCurrentSentence(page: ReadBookPage): string {
    if (page.ttsHighlightStart < 0 || page.ttsHighlightEnd <= page.ttsHighlightStart || !page.ttsDisplayText) {
      return '';
    }
    const source = page.ttsPanelOffsetSource();
    return LeafFns.cleanTtsPanelSlice(source.substring(page.ttsHighlightStart, page.ttsHighlightEnd));
}

export function ttsCurrentSentenceForPanel(page: ReadBookPage): string {
    const sentence = page.ttsCurrentSentence();
    if (sentence) {
      return sentence;
    }
    const chunk = page.ttsLastFocusChunk;
    if (chunk && chunk.text) {
      return LeafFns.cleanTtsPanelSlice(chunk.text);
    }
    return '';
}

export function ttsQuickSentencePreview(page: ReadBookPage): string {
    const source = LeafFns.cleanTtsPanelSlice(page.ttsPanelOffsetSource());
    if (source) {
      return source;
    }
    const sentence = page.ttsCurrentSentence();
    const fallback = LeafFns.cleanTtsPanelSlice(LeafFns.ttsOffsetSanitizedText(page.content)).substring(0, 3000);
    return sentence || fallback || '正在准备当前页的朗读内容…';
}

export function ttsPanelTextBefore(page: ReadBookPage): string {
    const source = page.ttsPanelOffsetSource();
    if (page.ttsHighlightStart <= 0) return '';
    return LeafFns.cleanTtsPanelSlice(
      source.substring(Math.max(0, page.ttsHighlightStart - 600), page.ttsHighlightStart));
}

export function ttsPanelTextAfter(page: ReadBookPage): string {
    const source = page.ttsPanelOffsetSource();
    const start = page.ttsHighlightEnd > page.ttsHighlightStart ? page.ttsHighlightEnd : 0;
    return LeafFns.cleanTtsPanelSlice(source.substring(start, Math.min(source.length, start + 900)));
}

export function ttsPanelOffsetSource(page: ReadBookPage): string {
    return LeafFns.ttsOffsetSanitizedText(page.ttsDisplayText || page.currentPageText || '');
}

export function ttsPanelFollowingText(page: ReadBookPage): string {
    const before = page.ttsPanelTextBefore();
    const current = page.ttsCurrentSentence();
    const after = page.ttsPanelTextAfter();
    return [before, current, after].filter((value: string): boolean => !!value).join('\n');
}

export function ttsQuickProgressLabel(page: ReadBookPage): string {
    return `第 ${page.currentChapterIndex + 1}/${Math.max(1, page.chapters.length)} 章 · ` +
      `第 ${page.currentPageIndex + 1}/${Math.max(1, page.contentPages.length)} 页`;
}

export function ttsQuickProgress(page: ReadBookPage): number {
    const chapterCount = Math.max(1, page.chapters.length);
    const pageCount = Math.max(1, page.contentPages.length);
    return Math.max(0, Math.min(100,
      ((page.currentChapterIndex + (page.currentPageIndex + 1) / pageCount) / chapterCount) * 100));
}

export function showBookmarkActions(page: ReadBookPage, bookmark: Bookmark, event: GestureEvent): void {
    if (event.fingerList.length > 0) {
      const finger = event.fingerList[0];
      page.bookmarkActionMenuX = finger.globalX;
      page.bookmarkActionMenuY = finger.globalY;
    }
    page.pendingBookmarkAction = bookmark;
    page.showBookmarkActionMenu = true;
}

export function closeBookmarkActionMenu(page: ReadBookPage): void {
    page.showBookmarkActionMenu = false;
    page.pendingBookmarkAction = null;
}

export function bookmarkActionMenuLeft(page: ReadBookPage, menuWidth: number): number {
    const viewportWidth = page.pageViewWidth > 0 ? page.pageViewWidth : 360;
    return Math.max(12, Math.min(page.bookmarkActionMenuX - 18, viewportWidth - menuWidth - 12));
}

export function bookmarkActionMenuTop(page: ReadBookPage, menuHeight: number): number {
    const viewportHeight = page.pageViewHeight > 0 ? page.pageViewHeight : 720;
    const below = page.bookmarkActionMenuY + 12;
    if (below + menuHeight <= viewportHeight - 12) {
      return below;
    }
    return Math.max(page.getReaderTopSafePadding() + 8, page.bookmarkActionMenuY - menuHeight - 12);
}

export function getTocCover(page: ReadBookPage): string {
    return page.book ? page.book.getDisplayCover() : '';
}

export function getTocBookInitial(page: ReadBookPage): string {
    const name = (page.book?.name || '书').trim();
    return name.length > 0 ? name.substring(0, 1) : '书';
}

export function getChapterTitle(page: ReadBookPage, chapterIndex: number = page.currentChapterIndex): string {
    if (page.chapters.length === 0) return '暂无目录';
    const chapter = page.chapters[page.clampChapterIndex(chapterIndex)];
    const title = chapter ? page.cleanChapterTitle(chapter.title) : '';
    return ReaderReplaceRuleStore.applyTitle(title, page.readerReplaceRules, page.book);
}

export function applyReaderContentRules(page: ReadBookPage, content: string): string {
    return ReaderReplaceRuleStore.applyContent(content, page.readerReplaceRules, page.book);
}

export function readerPreparedContentKey(page: ReadBookPage, content: string, chapterIndex: number): string {
    return `${chapterIndex}_${content.length}_${hashText(content)}_${page.readerReplaceRules.length}_` +
      `${page.readerReplaceRulesUpdateTime}`;
}

export function getPreparedReaderContent(page: ReadBookPage, content: string, chapterIndex: number): string {
    return page.readerPreparedContentCache.get(page.readerPreparedContentKey(content, chapterIndex)) || '';
}

export async function prepareReaderContentRules(page: ReadBookPage, content: string, chapterIndex: number): Promise<string> {
    if (!content) return '';
    const key = page.readerPreparedContentKey(content, chapterIndex);
    const cached = page.readerPreparedContentCache.get(key);
    if (cached !== undefined) return cached;
    const startedAt = Date.now();
    const processed = ReaderActionMarker.limit(
      await ReaderContentPreprocessor.apply(content, page.readerReplaceRules, page.book));
    const elapsedMs = Math.max(0, Date.now() - startedAt);
    if (elapsedMs >= CooperativeScheduler.DANGEROUS_OPERATION_MS) {
      console.info(`[ReaderPreprocessor] worker elapsed=${elapsedMs}ms input=${content.length}`);
    }
    page.readerPreparedContentCache.set(key, processed);
    while (page.readerPreparedContentCache.size > 8) {
      const oldestKey = page.readerPreparedContentCache.keys().next().value as string | undefined;
      if (!oldestKey) break;
      page.readerPreparedContentCache.delete(oldestKey);
    }
    // Do not begin native paragraph measurement in the same event-loop turn that publishes a
    // potentially large TaskPool result.
    await CooperativeScheduler.yieldToEventLoop();
    return processed;
}

export async function reloadReaderReplaceRules(page: ReadBookPage, repaginate: boolean): Promise<void> {
    const nextRules = await ReaderReplaceRuleStore.load(page.hostContext(), true);
    const rulesChanged = JSON.stringify(nextRules) !== JSON.stringify(page.readerReplaceRules);
    page.readerReplaceRules = nextRules;
    if (!rulesChanged) {
      return;
    }
    page.readerPaginationCache.clear();
    page.readerPreparedContentCache.clear();
    page.adjacentPaginationPreloadSerial++;
    page.pageTurnPreviewKey = '';
    page.pageTurnPreviewLoadingKey = '';
    if (!repaginate || !page.book || page.chapters.length === 0) {
      return;
    }
    page.pendingRestorePageIndex = Math.max(page.pendingRestorePageIndex, page.currentPageIndex);
    const raw = ReadBookEngine.get().getCachedContent(page.currentChapterIndex);
    if (!raw) {
      return;
    }
    const processed = await page.prepareReaderContentRules(raw, page.currentChapterIndex);
    const ttsContentChanged = processed !== page.content;
    page.content = processed;
    page.paginateContent(processed, page.currentChapterIndex);
    page.refreshReaderTextRender();
    if (ttsContentChanged && page.isTtsSpeaking && !page.isTtsPaused && !page.ttsChapterSwitching) {
      page.startTtsReadingFromCurrentPosition(false).catch((error: Error) => {
        console.warn('替换规则变更后重建朗读失败:', error);
      });
    }
}
