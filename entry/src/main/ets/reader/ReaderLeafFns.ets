/**
 * 阅读页叶子纯函数集合 —— 从 ReadBook.ets 抽离（P0 第二步）。
 * 这些函数不读取任何 @State / this 状态，只依赖显式参数、模块级 import 与 ArkUI 全局。
 * 调用方通过 `import * as LeafFns` 命名空间引用，避免与页面内同名符号冲突。
 * 由 scripts/gen_reader_code_map.py 生成的 CODE_MAP.md 记录职责分区。
 */

import fileUri from '@ohos.file.fileuri';
import graphicsText from '@ohos.graphics.text';
import { LocalBookService } from '../core/book/LocalBookService';
import { ReadBookEngine } from '../core/book/ReadBookEngine';
import { ReaderActionMarker, ReaderActionMatch, ReaderActionData } from '../core/book/ReaderActionMarker';
import { ReadTextSlice, ReaderPaginationResult, ReaderTextParagraph, ReaderV2HighlightRect } from '../core/reader/ReaderPageModels';
import { ReaderCustomFontData, ReaderCustomFontItem, ReaderTxtCharsetOption } from '../core/reader/ReaderSettingsModels';
import { BookChapter, BookSource, HttpTTS } from '../model/data/Book';
import { ThemeRuntime } from '../theme/ThemeRuntime';
import { ImmersiveMaterialRuntime } from '../utils/ImmersiveMaterialRuntime';
import { ReaderFontHelper } from '../utils/ReaderFontHelper';
import { ReaderSettingsStore } from '../utils/ReaderSettingsStore';
import { hashText } from './ReaderPureUtils';
import { SystemTtsReader, TtsVoiceOption } from '../utils/SystemTtsReader';
import { BookSourceRuntimeSnapshotStore } from '../core/book/BookSourceRuntimeSnapshot';
import { CooperativeScheduler } from '../core/concurrency/CooperativeScheduler';
import { ReaderV2PageFragment, ReaderV2PageLayout, ReaderV2RegexBubbleSegment } from '../core/reader/ReaderV2PageLayout';
import { ReaderV2Paginator } from '../core/reader/ReaderV2Paginator';

export function countCachedChapters(chapters: BookChapter[]): number {
  let count = 0;
  for (const chapter of chapters) {
    if (chapter.cacheDate > 0) {
      count++;
    }
  }
  return count;
}

export function countCachedChaptersFrom(chapters: BookChapter[], startIndex: number): number {
  let count = 0;
  for (let index = Math.max(0, startIndex); index < chapters.length; index++) {
    const chapter = chapters[index];
    if (chapter && chapter.cacheDate > 0) {
      count++;
    }
  }
  return count;
}

export function syncRenderedChapterCacheDates(rendered: BookChapter[], engineChapters: BookChapter[]): boolean {
  let changed = false;
  for (const chapter of rendered) {
    const fresh = engineChapters[chapter.index];
    if (!fresh || fresh.cacheDate <= 0 || chapter.cacheDate > 0) {
      continue;
    }
    chapter.cacheDate = fresh.cacheDate;
    changed = true;
  }
  return changed;
}

export function supportsReaderImmersiveMaterial(): boolean {
  return ImmersiveMaterialRuntime.supportsHdsMaterial();
}

export function txtCharsetOptions(): ReaderTxtCharsetOption[] {
  return [
    new ReaderTxtCharsetOption('', '自动识别', '根据文件内容自动判断编码'),
    new ReaderTxtCharsetOption('gb18030', 'GBK / GB18030', '简体中文'),
    new ReaderTxtCharsetOption('utf-8', 'UTF-8', 'Unicode，支持带 BOM 文件'),
    new ReaderTxtCharsetOption('utf-16le', 'UTF-16 LE', 'Unicode 小端序'),
    new ReaderTxtCharsetOption('utf-16be', 'UTF-16 BE', 'Unicode 大端序'),
    new ReaderTxtCharsetOption('big5', 'Big5', '繁体中文'),
    new ReaderTxtCharsetOption('koi8-r', 'KOI8-R', '俄语'),
    new ReaderTxtCharsetOption('euc-kr', 'EUC-KR', '韩语'),
    new ReaderTxtCharsetOption('euc-jp', 'EUC-JP', '日语'),
    new ReaderTxtCharsetOption('shift_jis', 'Shift-JIS', '日语'),
    new ReaderTxtCharsetOption('windows-1250', 'Windows-1250', '中欧语言'),
    new ReaderTxtCharsetOption('ibm866', 'IBM866', '西里尔字符')
  ];
}

export function currentReaderSource(): BookSource | null {
  return ReadBookEngine.get().source;
}

export function ttsOffsetSanitizedText(text: string): string {
  let source = ReaderActionMarker.strip(LocalBookService.stripEpubImageMarkers(text || '', true), true);
  for (const prefix of [ReaderActionMarker.PREFIX, ReaderActionMarker.LEGACY_PREFIX,
    ReaderActionMarker.ORIGINAL_PREFIX]) {
    let start = source.indexOf(prefix);
    while (start >= 0) {
      const lineEnd = source.indexOf('\n', start);
      const end = lineEnd >= 0 ? lineEnd : source.length;
      source = `${source.substring(0, start)}${' '.repeat(end - start)}${source.substring(end)}`;
      start = source.indexOf(prefix, end);
    }
  }
  return source;
}

export function isReaderImageOnlySource(source: string): boolean {
  const text = source || '';
  if (!LocalBookService.hasEpubImageMarkers(text)) return false;
  return LocalBookService.stripEpubImageMarkers(text).trim().length === 0;
}

export function countReaderImageMarkers(source: string): number {
  const text = source || '';
  const prefix = LocalBookService.EPUB_IMAGE_MARKER_PREFIX;
  let count = 0;
  let cursor = 0;
  while (cursor < text.length) {
    const markerStart = text.indexOf(prefix, cursor);
    if (markerStart < 0) break;
    count++;
    cursor = markerStart + prefix.length;
  }
  return count;
}

export function isReaderImageOnlyPage(text: string): boolean {
  return LocalBookService.isEpubImageMarker((text || '').trim());
}

export function getReaderHeaderInfoBarHeight(): number {
  // 页眉高度必须随系统字体缩放：12fp 单行文本在大字号下行盒会超过固定 18vp，向上下
  // 溢出吃掉仅 4vp 的预留间隙，与正文首行相贴/重叠。仍为确定性公式（不依赖测量回调），
  // 避免首次测量后再次触发整章分页。
  try {
    return Math.max(18, px2vp(Math.max(1, fp2px(12))) * 1.4);
  } catch (_) {
    return 18;
  }
}

export function normalizeReaderBottomInfoBarHeight(height: number): number {
  if (!Number.isFinite(height) || height <= 0) return 0;
  try {
    // ArkUI ultimately lays the line box on physical pixels. Quantizing here avoids tiny decimal
    // area fluctuations creating a layout/repagination loop on fractional-density displays.
    return px2vp(Math.max(1, Math.round(vp2px(height))));
  } catch (_) {
    return Math.round(height * 100) / 100;
  }
}

export function resolveCustomReaderFontFamily(family: string): string {
  if (!family) {
    return '';
  }
  const raw = AppStorage.get<string>('readerCustomFontsRaw') || '';
  if (!raw.trim()) {
    return family;
  }
  try {
    const parsed = JSON.parse(raw) as ReaderCustomFontData | ReaderCustomFontItem[];
    const source = Array.isArray(parsed) ? parsed as ReaderCustomFontItem[] : ((parsed as ReaderCustomFontData).fonts || []);
    for (const item of source) {
      if (!item || !item.filePath) {
        continue;
      }
      const stableFamily = ReaderFontHelper.normalizeFontFamily(item.filePath);
      if (item.familyName === family || stableFamily === family) {
        return stableFamily;
      }
    }
  } catch (e) {
    console.warn('解析阅读自定义字体失败:', e);
  }
  return family;
}

export function replaceReaderCustomFontPath(oldPath: string, newPath: string, familyName: string): void {
  const raw = AppStorage.get<string>('readerCustomFontsRaw') || '';
  if (!raw.trim()) {
    return;
  }
  try {
    const parsed = JSON.parse(raw) as ReaderCustomFontData | ReaderCustomFontItem[];
    const source = Array.isArray(parsed) ? parsed as ReaderCustomFontItem[] : ((parsed as ReaderCustomFontData).fonts || []);
    const data = new ReaderCustomFontData();
    for (const item of source) {
      if (!item || !item.filePath) {
        continue;
      }
      const next = new ReaderCustomFontItem();
      next.filePath = item.filePath === oldPath ? newPath : item.filePath;
      next.familyName = item.filePath === oldPath ? familyName : (item.familyName || ReaderFontHelper.normalizeFontFamily(next.filePath));
      next.sourceName = ReaderFontHelper.resolveDisplayName(item.sourceName, next.filePath);
      data.fonts.push(next);
    }
    AppStorage.setOrCreate<string>('readerCustomFontsRaw', JSON.stringify(data));
  } catch (e) {
    console.warn('更新阅读字体列表失败:', e);
  }
}

export function fileNameFromPath(path: string): string {
  return ReaderFontHelper.fileNameFromPath(path);
}

export function formatBookmarkTime(timestamp: number): string {
  if (timestamp <= 0) return '';
  const date = new Date(timestamp);
  const month = `${date.getMonth() + 1}`.padStart(2, '0');
  const day = `${date.getDate()}`.padStart(2, '0');
  const hour = `${date.getHours()}`.padStart(2, '0');
  const minute = `${date.getMinutes()}`.padStart(2, '0');
  return `${month}-${day} ${hour}:${minute}`;
}

export function markTtsVoiceOptionInstalled(voice: TtsVoiceOption): TtsVoiceOption {
  const option = new TtsVoiceOption();
  option.id = voice.id;
  option.name = voice.name;
  option.online = voice.online;
  option.status = 'INSTALLED';
  option.systemStatus = 'INSTALLED';
  option.style = voice.style;
  option.language = voice.language;
  option.downloadLanguage = voice.downloadLanguage;
  option.gender = voice.gender;
  option.available = true;
  option.downloadable = false;
  return option;
}

export function isKnownTtsVoiceId(id: number): boolean {
  return id === 0 || id === 8 || id === 13 || id === 21;
}

export function ttsCustomVoiceKey(voice: HttpTTS): string {
  return `custom_${voice.id}_${voice.name || ''}`;
}

export function ttsCustomVoiceTitle(voice: HttpTTS): string {
  const state = voice.enabled === false ? ' · 已禁用' : '';
  return `${voice.name || '未命名音色'} · 自定义${state}`;
}

export function ttsVoiceKey(voice: TtsVoiceOption): string {
  return `${voice.id}_${voice.online}_${voice.language || 'zh-CN'}_${voice.style || ''}_${voice.name || ''}`;
}

export function ttsVoiceGenderText(voice: TtsVoiceOption): string {
  const value = (voice.gender || '').toLowerCase();
  if (value === 'male' || value === '男' || value === '男声') {
    return ' · 男声';
  }
  if (value === 'female' || value === '女' || value === '女声') {
    return ' · 女声';
  }
  return '';
}

export function tocScrollbarPointerY(event: GestureEvent): number {
  const finger = event.fingerList.length > 0 ? event.fingerList[0] : undefined;
  return finger ? finger.localY : 0;
}

export function getReaderExtendedBottomSafeInset(): number {
  // The full-screen surface still extends through the system navigation area, but正文 keeps only a small,
  // deterministic visual guard. Do not derive this from asynchronous system-bar insets: that made the same
  // margin setting paginate differently between the live preview and reopening a book.
  return 8;
}

export function getReaderBottomInfoBarContentGap(): number {
  return 8;
}

export function readerFloatingBarEdgeInset(): number {
  return 18;
}

export function readerTtsExpandedControlWidth(): number {
  return 264;
}

export function normalizeTapZoneActions(actions: string): string {
  const fallback = [3, 3, 3, 3, 1, 2, 2, 2, 2];
  const parts = (actions || '').split(',');
  const result: number[] = [];
  for (let i = 0; i < 9; i++) {
    const parsed = Number(parts[i]);
    result.push(Number.isFinite(parsed) && parsed >= 0 && parsed <= 3 ? Math.round(parsed) : fallback[i]);
  }
  return result.join(',');
}

export function tapActionLabel(action: number): string {
  switch (action) {
    case 1:
      return '菜单';
    case 2:
      return '下一页';
    case 3:
      return '上一页';
    case 0:
    default:
      return '无动作';
  }
}

export function tapZoneCellColor(action: number): string {
  if (action === 1) {
    return '#332A6FCC';
  }
  if (action === 2) {
    return '#2239A86B';
  }
  if (action === 3) {
    return '#22A85C39';
  }
  return '#14000000';
}

export function readerSettingsScrollBarRightInset(): number {
  // 目录、设置面板与底部操作栏现在共用同一宽度和边缘，不再需要百分比补偿。
  return 0;
}

export function readerTextAlignValues(): string[] {
  return ['justify', 'start', 'end'];
}

export function readerTypographyMin(index: number): number {
  if (index === 0) return 14;
  return 0;
}

export function readerTypographyMax(index: number): number {
  if (index === 0) return 50;
  if (index === 1) return 8;
  if (index === 2) return 52;
  if (index === 3) return 32;
  if (index === 4 || index === 5) return 80;
  return 120;
}

export function pageTurnModeTypes(): number[] {
  return [0, 2, 3];
}

export function screenTimeoutValues(): number[] {
  return [
    ReaderSettingsStore.SCREEN_TIMEOUT_FOLLOW_SYSTEM,
    1,
    5,
    10,
    ReaderSettingsStore.SCREEN_TIMEOUT_ALWAYS_ON
  ];
}

export function screenOrientationValues(): string[] {
  return [
    ReaderSettingsStore.SCREEN_ORIENTATION_SYSTEM,
    ReaderSettingsStore.SCREEN_ORIENTATION_PORTRAIT,
    ReaderSettingsStore.SCREEN_ORIENTATION_LANDSCAPE
  ];
}

export function readerEyeCalibrationPreviewTopVp(): number {
  return 18;
}

export function readerEyeDwellValues(): number[] {
  return [500, 650, 850, 1100, 1400];
}

export function ttsSpeechTextEnd(text: string): number {
  return SystemTtsReader.audibleSpeechEnd(text);
}

export function indentReaderLine(line: string): string {
  if (!line || line.trim().length === 0) {
    return line;
  }
  const trimmed = line.trim();
  // 图片标记是结构数据，不是正文段落；给它添加两个全角空格会被分页器拆成一张不可见的文本页。
  if (LocalBookService.isEpubImageMarker(trimmed)) {
    return trimmed;
  }
  if (line.startsWith('　　')) {
    return line;
  }
  return `　　${line.replace(/^[　\s]+/g, '')}`;
}

export function isReaderTrimChar(value: string): boolean {
  return value === ' ' || value === '\t' || value === '\n' || value === '\r' ||
    value === '\u00A0' || value === '\u3000' || value === '\uFEFF' || value === '\u200B' ||
    value === '\u200C' || value === '\u200D' || value === '\u2060';
}

export function isReaderPageStartTrimChar(value: string): boolean {
  return value === '\n' || value === '\r' || value === '\uFEFF' ||
    value === '\u200B' || value === '\u200C' || value === '\u200D' || value === '\u2060';
}

export function adjustReaderActionMarkerPageEnd(source: string, start: number, rawEnd: number): number {
  const end = Math.max(start + 1, Math.min(rawEnd, source.length));
  let searchStart = start;
  while (searchStart < end) {
    let markerStart = -1;
    for (const prefix of [ReaderActionMarker.PREFIX, ReaderActionMarker.LEGACY_PREFIX,
      ReaderActionMarker.ORIGINAL_PREFIX]) {
      const index = source.indexOf(prefix, searchStart);
      if (index >= 0 && (markerStart < 0 || index < markerStart)) markerStart = index;
    }
    if (markerStart < 0) return end;
    const suffix = source.indexOf(ReaderActionMarker.SUFFIX, markerStart);
    if (suffix < 0) return end;
    const markerEnd = suffix + ReaderActionMarker.SUFFIX.length;
    const previousChar = markerStart > 0 ? source.charAt(markerStart - 1) : '';
    const inlineMarker = markerStart > 0 && previousChar !== '\n' && previousChar !== '\r';
    if (markerStart === end) {
      return inlineMarker ? markerEnd : end;
    }
    if (markerStart > end) return end;
    if (end < markerEnd) {
      return inlineMarker ? markerEnd : (markerStart > start ? markerStart : markerEnd);
    }
    searchStart = markerEnd;
  }
  return end;
}

export function findReaderActionEndingAt(source: string, start: number, end: number): ReaderActionMatch | null {
  let cursor = Math.max(0, start);
  let result: ReaderActionMatch | null = null;
  while (cursor < end) {
    const local = ReaderActionMarker.findFirst(source.substring(cursor, end));
    if (!local) break;
    const absolute = new ReaderActionMatch();
    absolute.marker = local.marker;
    absolute.start = cursor + local.start;
    absolute.end = cursor + local.end;
    absolute.data = local.data;
    if (absolute.end === end) result = absolute;
    cursor = Math.max(cursor + 1, absolute.end);
  }
  return result;
}

export function getReaderPaginationHeightTolerancePx(): number {
  return 0;
}

export function toMeasurePx(value: number): number {
  try {
    return Math.max(1, vp2px(value));
  } catch (_) {
    return Math.max(1, value);
  }
}

export function toMeasureNonNegativePx(value: number): number {
  if (!Number.isFinite(value) || value <= 0) return 0;
  try {
    return Math.max(0, vp2px(value));
  } catch (_) {
    return Math.max(0, value);
  }
}

export function toMeasureFontOffsetPx(value: number): number {
  if (!Number.isFinite(value) || value === 0) return 0;
  try {
    return fp2px(value);
  } catch (_) {
    return value;
  }
}

export function chooseReaderPageBreak(source: string, start: number, best: number): number {
  if (best >= source.length) {
    return source.length;
  }
  const safeBest = Math.max(start + 1, Math.min(best, source.length));
  if (safeBest > start && safeBest < source.length) {
    const previousCode = source.charCodeAt(safeBest - 1);
    const nextCode = source.charCodeAt(safeBest);
    const splitsSurrogatePair = previousCode >= 0xD800 && previousCode <= 0xDBFF &&
      nextCode >= 0xDC00 && nextCode <= 0xDFFF;
    if (splitsSurrogatePair && safeBest - 1 > start) {
      return safeBest - 1;
    }
  }
  return safeBest;
}

export function readerHeaderContentValues(): string[] {
  return ['chapter', 'book', 'book_chapter', 'none'];
}

export function readerFooterLeftValues(): string[] {
  return ['chapter', 'title', 'none'];
}

export function readerFooterProgressValues(): string[] {
  return ['page', 'percentage', 'chapter', 'book', 'none'];
}

export function delay(ms: number): Promise<void> {
  return new Promise<void>((resolve) => {
    setTimeout(() => resolve(), ms);
  });
}

export function readerInlineSourceActionFontFamily(): string {
  // A monospace face makes every digit occupy exactly one cell. Together with the 1/2/3-character
  // count classes this gives pagination and rendering the same three deterministic pill widths.
  return 'monospace';
}

export function readerCommentPanelDragHandleHeight(): number {
  return 44;
}

export function readerSelectableTextKey(kind: string, pageRenderIdentity: string, contentRenderVersion: number,
  ttsRenderVersion: number, paragraph: ReaderTextParagraph): string {
  return `${pageRenderIdentity}_${contentRenderVersion}_${ttsRenderVersion}_${kind}_${paragraph.key}`;
}

export function getRegexFrameHorizontalPaddingForStyle(styleId: string): number {
  if (styleId === 'rose-frame') return 18;
  if (styleId === 'celadon-slip') return 16;
  if (styleId === 'strawberry-ribbon' || styleId === 'moon-halo') return 16;
  if (styleId === 'crimson-stamp' || styleId === 'warm-scroll') return 15;
  if (styleId === 'sword-talisman') return 16;
  if (styleId === 'qingluan-jade') return 18;
  if (styleId === 'pipi-soft-paw') return 18;
  return 14;
}

export function getRegexFrameVerticalPaddingForStyle(styleId: string): number {
  if (styleId === 'rose-frame' || styleId === 'celadon-slip') return 7;
  if (styleId === 'strawberry-ribbon' || styleId === 'moon-halo') return 6;
  if (styleId === 'sword-talisman') return 6;
  if (styleId === 'qingluan-jade') return 7;
  if (styleId === 'pipi-soft-paw') return 7;
  return 5;
}

export function themeRegexEmphasisMode(): string {
  return ThemeRuntime.regexEmphasisMode();
}

export function themeRegexBubbleStyleId(): string {
  return ThemeRuntime.regexBubbleStyle();
}

export function hasOverlappedRegexSlice(slices: ReadTextSlice[], start: number, end: number): boolean {
  for (const slice of slices) {
    if (start < slice.end && end > slice.start) {
      return true;
    }
  }
  return false;
}

export function buildTextSliceKey(text: string): string {
  const value = text || '';
  const first = value.substring(0, Math.min(12, value.length));
  const last = value.substring(Math.max(0, value.length - 12));
  return `${value.length}_${hashText(first + last)}`;
}

export function syncReaderV2PaginationResult(result: ReaderPaginationResult): void {
  const session = result.v2Session;
  if (!session) return;
  const pageSet = session.pageSet;
  const pages: string[] = [];
  const starts: number[] = [];
  const ends: number[] = [];
  for (let index = 0; index < pageSet.pages.length; index++) {
    const page = pageSet.pages[index];
    const start = index === 0 ? 0 : Math.max(starts[index - 1], page.sourceStart);
    const nextStart = index + 1 < pageSet.pages.length ? pageSet.pages[index + 1].sourceStart :
      (pageSet.complete ? result.source.length : page.sourceEnd);
    const end = Math.max(start, Math.min(result.source.length, nextStart > start ? nextStart : page.sourceEnd));
    page.sourceStart = start;
    page.sourceEnd = end;
    starts.push(start);
    ends.push(end);
    pages.push(result.source.substring(start, end));
  }
  if (pages.length === 0 && result.source && pageSet.complete) {
    pages.push(result.source);
    starts.push(0);
    ends.push(result.source.length);
  }
  result.pages = pages;
  result.starts = starts;
  result.ends = ends;
  result.cursor = ends.length > 0 ? ends[ends.length - 1] : 0;
  result.complete = pageSet.complete;
}

export function normalizePreloadChapterCount(count: number): number {
  return Math.max(1, Math.min(Math.round(count), 10));
}

export function sourceUsesWebFetchRuntime(source: BookSource | null): boolean {
  if (!source) return false;
  let serialized = '';
  try {
    serialized = JSON.stringify(source) || '';
  } catch (_) {
    serialized = source.rawSourceJson || '';
  }
  return /["']?webView["']?\s*:\s*(?:true|["']true["']|1)(?:\s*[,}])?/i.test(serialized);
}

export function parseReaderChapterRange(raw: string, total: number): number[] {
  const value = (raw || '').trim();
  if (!value || total <= 0) return [];
  const normalized = value.replace(/[，、；;]/g, ',').replace(/[～至]/g, '-');
  const result = new Set<number>();
  for (const part of normalized.split(/[\s,]+/)) {
    if (!part) continue;
    const range = part.match(/^(\d+)\s*-\s*(\d+)$/);
    if (range) {
      const start = Number.parseInt(range[1], 10);
      const end = Number.parseInt(range[2], 10);
      if (start < 1 || end < 1 || start > total || end > total) return [];
      const low = Math.min(start, end);
      const high = Math.max(start, end);
      for (let chapterNumber = low; chapterNumber <= high; chapterNumber++) {
        result.add(chapterNumber - 1);
      }
      continue;
    }
    if (!/^\d+$/.test(part)) return [];
    const chapterNumber = Number.parseInt(part, 10);
    if (chapterNumber < 1 || chapterNumber > total) return [];
    result.add(chapterNumber - 1);
  }
  return Array.from(result).sort((left: number, right: number) => left - right);
}

export function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    setTimeout(() => resolve(), ms);
  });
}

export function txtCharsetLabel(charset: string): string {
  const normalized = (charset || '').toLowerCase().replace(/_/g, '-');
  for (const option of txtCharsetOptions()) {
    if (option.value.replace(/_/g, '-') === normalized) return option.label;
  }
  return charset ? charset.toUpperCase() : '自动识别';
}

export function cleanTtsPanelSlice(text: string): string {
  return (text || '')
    .replace(/[ \t]{2,}/g, ' ')
    .replace(/[ \t]*\n[ \t]*/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

export function getReaderPageHorizontalPadding(text: string, fallback: number): number {
  return isReaderImageOnlyPage(text) ? 0 : fallback;
}

export function getReaderPageVerticalPadding(text: string, fallback: number): number {
  return isReaderImageOnlyPage(text) ? 0 : fallback;
}

export function normalizeColor(color: string, fallback: string): string {
  const trimmed = (color || '').trim();
  const normalized = trimmed.startsWith('#') ? trimmed : `#${trimmed}`;
  if (/^#[0-9a-fA-F]{6}$/.test(normalized)) {
    return normalized.toUpperCase();
  }
  const fallbackTrimmed = (fallback || '').trim();
  const normalizedFallback = fallbackTrimmed.startsWith('#') ? fallbackTrimmed : `#${fallbackTrimmed}`;
  return /^#[0-9a-fA-F]{6}$/.test(normalizedFallback) ? normalizedFallback.toUpperCase() : '#333333';
}

export function shouldPreferTtsVoiceOption(candidate: TtsVoiceOption, current: TtsVoiceOption): boolean {
  if (candidate.available !== current.available) {
    return candidate.available;
  }
  if (isKnownTtsVoiceId(candidate.id) !== isKnownTtsVoiceId(current.id)) {
    return isKnownTtsVoiceId(candidate.id);
  }
  if (candidate.downloadable !== current.downloadable) {
    return candidate.downloadable;
  }
  return !current.style && !!candidate.style;
}

export function ttsVoiceTitle(voice: TtsVoiceOption): string {
  if (voice.status === 'default') {
    return `${voice.name} · 系统默认`;
  }
  const suffix = voice.online === 0 ? '在线' : '离线';
  const gender = ttsVoiceGenderText(voice);
  const state = voice.available ? '' : (voice.downloadable ? ' · 需下载' : ' · 不可用');
  return `${voice.name} · ${suffix}${gender}${state}`;
}

export function normalizeTtsLanguage(language: string): string {
  const value = (language || 'zh-CN').trim().replace(/_/g, '-').toLowerCase();
  if (value === 'zh' || value === 'zh-cn' || value.startsWith('zh-hans')) {
    return 'zh-CN';
  }
  if (value === 'en' || value === 'en-us') {
    return 'en-US';
  }
  return value || 'zh-CN';
}

export function getReaderSafeAreaEdges(): SafeAreaEdge[] {
  // Keep one stable full-screen coordinate system for every theme. Background artwork may cover the system
  // bars, but its presence must never decide where正文 starts. Dynamically adding/removing TOP here left
  // ArkUI with retained safe-area geometry after a theme switch (plain themes then painted under the status
  // bar). The content column below owns the text inset explicitly.
  return [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM];
}

export function readerPanelTransition(): TransitionEffect {
  const appear = TransitionEffect.translate({ y: 52 })
    .combine(TransitionEffect.scale({ x: 0.985, y: 0.985, centerX: '50%', centerY: '100%' }))
    .combine(TransitionEffect.opacity(0))
    .animation({ duration: 300, curve: Curve.Friction });
  const disappear = TransitionEffect.translate({ y: 28 })
    .combine(TransitionEffect.scale({ x: 0.99, y: 0.99, centerX: '50%', centerY: '100%' }))
    .combine(TransitionEffect.opacity(0))
    .animation({ duration: 190, curve: Curve.EaseIn });
  return TransitionEffect.asymmetric(appear, disappear);
}

export function readerSettingsContentTransition(direction: number): TransitionEffect {
  const horizontalOffset = direction < 0 ? -28 : 28;
  const appear = TransitionEffect.translate({ x: horizontalOffset })
    .combine(TransitionEffect.opacity(0))
    .animation({ duration: 260, curve: Curve.Friction });
  const disappear = TransitionEffect.translate({ x: horizontalOffset * 0.65 })
    .combine(TransitionEffect.opacity(0))
    .animation({ duration: 160, curve: Curve.EaseIn });
  return TransitionEffect.asymmetric(appear, disappear);
}

export function isReaderChapterLastPage(text: string, pageStart: number, documentSource: string): boolean {
  let pageEnd = Math.max(0, Math.min(documentSource.length, pageStart + (text || '').length));
  while (pageEnd < documentSource.length && isReaderTrimChar(documentSource.charAt(pageEnd))) pageEnd++;
  return pageEnd >= documentSource.length;
}

export function readerSettingsContentRightPadding(): number {
  return Math.max(0, 20 - readerSettingsScrollBarRightInset());
}

export function readerTypographyOptions(): SelectOption[] {
  return [
    { value: '字号' },
    { value: '字距' },
    { value: '行距' },
    { value: '段落间距' },
    { value: '左边距' },
    { value: '右边距' },
    { value: '上边距' },
    { value: '下边距' }
  ];
}

export function readerTextAlignOptions(): SelectOption[] {
  return [{ value: '两端对齐' }, { value: '左对齐' }, { value: '右对齐' }];
}

export function pageTurnModeOptions(): SelectOption[] {
  return [
    { value: '上下滑动' },
    { value: '横向滑动' },
    { value: '滚动阅读' }
  ];
}

export function pageTurnModeByIndex(index: number): number {
  const types = pageTurnModeTypes();
  return index >= 0 && index < types.length ? types[index] : 2;
}

export function screenTimeoutOptions(): SelectOption[] {
  return [
    { value: '跟随系统' },
    { value: '1分钟' },
    { value: '5分钟' },
    { value: '10分钟' },
    { value: '常亮' }
  ];
}

export function screenOrientationOptions(): SelectOption[] {
  return [
    { value: '跟随系统' },
    { value: '强制竖屏' },
    { value: '强制横屏' }
  ];
}

export function readerSelectOptionValue(options: SelectOption[], index: number): ResourceStr {
  if (index >= 0 && index < options.length) {
    return options[index].value;
  }
  return options.length > 0 ? options[0].value : '';
}

export function readerPreloadChapterOptions(): SelectOption[] {
  const options: SelectOption[] = [];
  for (let index = 1; index <= 10; index++) {
    options.push({ value: `${index}章` });
  }
  return options;
}

export function readerEyeDwellOptions(): SelectOption[] {
  return [
    { value: '0.5秒' },
    { value: '0.65秒' },
    { value: '0.85秒' },
    { value: '1.1秒' },
    { value: '1.4秒' }
  ];
}

export function readerEyeDwellSelectedIndex(value: number): number {
  const values = readerEyeDwellValues();
  let selected = 0;
  let distance = Number.MAX_SAFE_INTEGER;
  for (let index = 0; index < values.length; index++) {
    const nextDistance = Math.abs(values[index] - value);
    if (nextDistance < distance) {
      selected = index;
      distance = nextDistance;
    }
  }
  return selected;
}

export function readerEyeCalibrationMedian(values: number[]): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((left: number, right: number): number => left - right);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle];
}

export function readerSoftLineJoiner(previous: string, next: string): string {
  const left = (previous || '').trim();
  const right = (next || '').trim();
  if (!left || !right || /[-‐‑‒–—]$/.test(left)) {
    return '';
  }
  return /[A-Za-z0-9,.:;\'"）)\]]$/.test(left) && /^[A-Za-z0-9]/.test(right) ? ' ' : '';
}

export function shouldMergeReaderSoftLine(previous: string, nextRaw: string): boolean {
  const prev = (previous || '').trim();
  const next = (nextRaw || '').trim();
  if (ReaderActionMarker.has(prev) || ReaderActionMarker.has(next)) {
    return false;
  }
  if (!prev || !next) {
    return false;
  }
  if (/^[　\s]/.test(nextRaw)) {
    return false;
  }
  if (/^[第卷章节回番外序楔引]\s*[\d一二三四五六七八九十百千万零〇壹贰叁肆伍陆柒捌玖拾]/.test(next)) {
    return false;
  }
  if (/^[，,。！？!?；;：:、」』”）)]/.test(next)) {
    return true;
  }
  if (/[。！？!?；;」』”）)]$/.test(prev)) {
    return false;
  }
  return prev.length < 48 && next.length < 48;
}

export function isReaderEdgeTrimChar(value: string): boolean {
  return isReaderTrimChar(value) || value === '\u3000';
}

export function findMeasuredReaderInlineAction(text: string, documentSource: string,
  absoluteStart: number): ReaderActionMatch | null {
  const source = documentSource || text || '';
  const rangeStart = Math.max(0, Math.min(absoluteStart, source.length));
  const match = ReaderActionMarker.findFirst(source.substring(rangeStart));
  if (!match || match.start < 0 || match.start >= (text || '').length) return null;
  const markerStart = rangeStart + match.start;
  const previousChar = markerStart > 0 ? source.charAt(markerStart - 1) : '';
  return markerStart > 0 && previousChar !== '\n' && previousChar !== '\r' ? match : null;
}

export function toMeasureFontPx(value: number): number {
  try {
    return Math.max(1, fp2px(value));
  } catch (_) {
    return toMeasurePx(value);
  }
}

export function readerHeaderContentOptions(): SelectOption[] {
  return [{ value: '当前章节标题' }, { value: '书名' }, { value: '书名 + 章节标题' }, { value: '不显示' }];
}

export function readerFooterLeftOptions(): SelectOption[] {
  return [{ value: '章节序号 + 标题' }, { value: '章节标题' }, { value: '不显示' }];
}

export function readerFooterProgressOptions(): SelectOption[] {
  return [{ value: '当前页 / 总页数' }, { value: '阅读百分比' }, { value: '章节进度' }, { value: '全书进度' }, { value: '不显示' }];
}

export function readerPageRenderIdentity(prefix: string, chapterIndex: number, pageIndex: number, renderVersion: number,
  ttsRenderVersion: number, text: string, displayKey: number = 0): string {
  return `${prefix}_${chapterIndex}_${pageIndex}_${displayKey}_${renderVersion}_${ttsRenderVersion}_` +
    `${buildTextSliceKey(text || '')}`;
}

export function readerSelectablePageTextKey(pageRenderIdentity: string, contentRenderVersion: number,
  ttsRenderVersion: number, text: string): string {
  return `${pageRenderIdentity}_${contentRenderVersion}_${ttsRenderVersion}_merged_${buildTextSliceKey(text)}`;
}

export function readerParagraphCommentSettingState(): number {
  const source = currentReaderSource();
  if (!source) return 0;
  return BookSourceRuntimeSnapshotStore.get(source).settingState([
    '段评开关', 'fqpara', 'yunpara', 'paras', '评论开关', '章评开关'
  ]);
}

export function isReaderParagraphCommentAction(data: ReaderActionData): boolean {
  const identity = `${data.label || ''}\n${data.title || ''}\n${data.url || ''}`;
  return /段评|章评|本章说|评论|comment|review|para_idea|idea_comment|legado-provider-action/i.test(identity);
}

export function isReaderCommentAction(action: ReaderActionData): boolean {
  const metadata = `${action.label || ''}\n${action.title || ''}`;
  if (/段评|章评|神评论|评论|本章说/.test(metadata)) return true;
  return /\/(?:get_review|get_para_review|para_idea)(?:[/?#]|$)|[?&](?:review|comment)=/i.test(action.url || '');
}

export function getReaderEpubImageUri(marker: string): string {
  const path = LocalBookService.epubImagePathFromMarker(marker);
  if (!path) return '';
  if (/^(?:https?:|data:|file:)/i.test(path)) return path;
  try {
    return fileUri.getUriFromPath(path);
  } catch (_) {
    return path;
  }
}

export function cloneStyledSlice(source: ReadTextSlice, start: number, end: number, text: string, ttsHighlighted: boolean,
  keyPrefix: string): ReadTextSlice {
  return {
    text: text,
    start: start,
    end: end,
    highlighted: source.highlighted,
    ruleIndex: source.ruleIndex,
    ttsHighlighted: ttsHighlighted,
    key: `${keyPrefix}_${start}_${end}_${source.ruleIndex}_${buildTextSliceKey(text)}`
  };
}

export function appendReaderV2PaginationBatch(result: ReaderPaginationResult, chapterIndex: number, maxPages: number): void {
  const session = result.v2Session;
  if (!session || result.complete || maxPages <= 0) return;
  const startedAt = Date.now();
  const appended = ReaderV2Paginator.appendPages(session, maxPages);
  syncReaderV2PaginationResult(result);
  CooperativeScheduler.reportSynchronousOperation('reader/v2-pagination-batch', Date.now() - startedAt,
    `chapter=${chapterIndex},pages=${appended},total=${result.pages.length}`);
}

export function readerV2DisplayHighlightRects(page: ReaderV2PageLayout, absoluteStart: number,
  absoluteEnd: number, keyPrefix: string): ReaderV2HighlightRect[] {
  if (absoluteEnd <= absoluteStart) return [];
  const result: ReaderV2HighlightRect[] = [];
  for (let fragmentIndex = 0; fragmentIndex < page.fragments.length; fragmentIndex++) {
    const fragment = page.fragments[fragmentIndex];
    if (!fragment.paragraph || absoluteEnd <= fragment.displayStart ||
      absoluteStart >= fragment.displayEnd) continue;
    const localStart = Math.max(0, absoluteStart - fragment.displayStart);
    const localEnd = Math.min(fragment.localEnd - fragment.localStart,
      absoluteEnd - fragment.displayStart);
    if (localEnd <= localStart) continue;
    const boxes = fragment.paragraph.getRectsForRange({ start: localStart, end: localEnd },
      graphicsText.RectWidthStyle.TIGHT, graphicsText.RectHeightStyle.TIGHT);
    for (let boxIndex = 0; boxIndex < boxes.length; boxIndex++) {
      const rect = boxes[boxIndex].rect;
      const left = Math.max(fragment.clipRect.left, fragment.paragraphX + rect.left);
      const right = Math.min(fragment.clipRect.right, fragment.paragraphX + rect.right);
      const glyphTop = fragment.paragraphY + rect.top;
      const glyphBottom = fragment.paragraphY + rect.bottom;
      // TIGHT Paragraph boxes follow the actual painted glyphs. Give selection a small symmetric inset around
      // those boxes; the system Text background uses its lower line box and makes the same glyph look too high.
      const verticalPadding = keyPrefix === 'selection' ?
        Math.max(1, Math.min(3, (glyphBottom - glyphTop) * 0.08)) : 0;
      const top = Math.max(fragment.clipRect.top, glyphTop - verticalPadding);
      const bottom = Math.min(fragment.clipRect.bottom, glyphBottom + verticalPadding);
      if (right <= left || bottom <= top) continue;
      result.push({
        leftPx: left,
        topPx: top,
        widthPx: right - left,
        heightPx: bottom - top,
        key: `${keyPrefix}_${page.identity}_${fragmentIndex}_${boxIndex}_${absoluteStart}_${absoluteEnd}`
      });
    }
  }
  return result;
}

export function readerV2RegexBubbleShadow(segment: ReaderV2RegexBubbleSegment): ShadowOptions {
  if (!segment.shadowEnabled) return { radius: 0, color: Color.Transparent, offsetX: 0, offsetY: 0 };
  return {
    radius: px2vp(segment.shadowRadiusPx),
    color: segment.shadowColor,
    offsetX: px2vp(segment.shadowOffsetXPx),
    offsetY: px2vp(segment.shadowOffsetYPx)
  };
}

export function readerV2FragmentLineMetrics(fragment: ReaderV2PageFragment): graphicsText.LineMetrics[] {
  try {
    return fragment.paragraph ? fragment.paragraph.getLineMetrics() : [];
  } catch (_) {
    return [];
  }
}

export function readerV2DisplayOffsetForPageSelection(page: ReaderV2PageLayout, selectionOffset: number): number {
  const target = Math.max(0, Math.min(page.selectionText.length, selectionOffset));
  let previousDisplayEnd = page.displayStart;
  for (const fragment of page.fragments) {
    if (target < fragment.selectionPageStart) return previousDisplayEnd;
    if (target <= fragment.selectionPageEnd) {
      return fragment.displayStart + Math.max(0,
        Math.min(fragment.displayEnd - fragment.displayStart, target - fragment.selectionPageStart));
    }
    previousDisplayEnd = fragment.displayEnd;
  }
  return page.displayEnd;
}

export function readerV2FragmentIndexForSelectionOffset(page: ReaderV2PageLayout, offset: number): number {
  if (!page.selectionText) return -1;
  const target = Math.max(0, Math.min(page.selectionText.length, offset));
  for (let index = 0; index < page.fragments.length; index++) {
    if (target < page.fragments[index].selectionPageEnd) return index;
  }
  return page.fragments.length > 0 ? page.fragments.length - 1 : -1;
}

export function regexDecorationStyle(styleId: string): TextDecorationStyle {
  if (styleId === 'double') return TextDecorationStyle.DOUBLE;
  if (styleId === 'dotted') return TextDecorationStyle.DOTTED;
  if (styleId === 'dashed') return TextDecorationStyle.DASHED;
  if (styleId === 'wavy') return TextDecorationStyle.WAVY;
  return TextDecorationStyle.SOLID;
}

export function readerSlideCompletionDuration(remaining: number, distance: number, releaseVelocity: number,
  queuedGesture: boolean): number {
  const safeDistance = Math.max(1, distance);
  const remainingRatio = Math.max(0, Math.min(1, remaining / safeDistance));
  if (queuedGesture) {
    return Math.max(70, Math.min(100, Math.round(100 * remainingRatio)));
  }
  let durationCap = 160;
  if (releaseVelocity >= 2800) {
    durationCap = 90;
  } else if (releaseVelocity >= 1400) {
    durationCap = 115;
  } else if (releaseVelocity >= 700) {
    durationCap = 140;
  }
  return Math.max(90, Math.min(durationCap, Math.round(160 * remainingRatio)));
}

export function installedTtsVoiceKey(voice: TtsVoiceOption): string {
  const style = isKnownTtsVoiceId(voice.id) ? '' : (voice.style || '');
  return `${voice.id}_${voice.online}_${normalizeTtsLanguage(voice.language || 'zh-CN')}_${style}`;
}

export function sameTtsLanguage(left: string, right: string): boolean {
  return normalizeTtsLanguage(left) === normalizeTtsLanguage(right);
}

export function readerEyeCalibrationSpread(values: number[]): number {
  if (values.length === 0) return 0;
  const median = readerEyeCalibrationMedian(values);
  return readerEyeCalibrationMedian(
    values.map((value: number): number => Math.abs(value - median)));
}

export function mergeSoftWrappedChapterLines(text: string): string {
  if (!text || text.indexOf('\n') < 0) {
    return text;
  }
  const rawLines = text.split('\n');
  const result: string[] = [];
  let current = '';
  for (const rawLine of rawLines) {
    const line = rawLine.trim();
    if (!line) {
      if (current) {
        result.push(current);
        current = '';
      }
      if (result.length > 0 && result[result.length - 1] !== '') {
        result.push('');
      }
      continue;
    }
    if (!current) {
      current = line;
      continue;
    }
    if (shouldMergeReaderSoftLine(current, rawLine)) {
      current += readerSoftLineJoiner(current, line) + line;
    } else {
      result.push(current);
      current = line;
    }
  }
  if (current) {
    result.push(current);
  }
  return result.join('\n').replace(/\n{3,}/g, '\n\n').trim();
}

export function trimReaderContentText(text: string): string {
  const source = text || '';
  let start = 0;
  let end = source.length;
  while (start < end && isReaderEdgeTrimChar(source.charAt(start))) {
    start++;
  }
  while (end > start && isReaderEdgeTrimChar(source.charAt(end - 1))) {
    end--;
  }
  return source.substring(start, end);
}

export function readerParagraphCommentsEnabledForPagination(): boolean {
  // An absent setting means the source has no user-facing switch (or uses comments by default), so retain
  // markers. Only an explicit disabled value is allowed to remove source content.
  return readerParagraphCommentSettingState() >= 0;
}

export function readerParagraphCommentPaginationIdentity(): string {
  const state = readerParagraphCommentSettingState();
  return state > 0 ? 'comment_on' : (state < 0 ? 'comment_off' : 'comment_auto');
}

export function stripReaderParagraphCommentActions(value: string): string {
  const source = value || '';
  if (!ReaderActionMarker.has(source)) return source;
  let cursor = 0;
  let result = '';
  while (cursor < source.length) {
    let markerStart = -1;
    for (const prefix of [ReaderActionMarker.PREFIX, ReaderActionMarker.LEGACY_PREFIX,
      ReaderActionMarker.ORIGINAL_PREFIX]) {
      const index = source.indexOf(prefix, cursor);
      if (index >= 0 && (markerStart < 0 || index < markerStart)) markerStart = index;
    }
    if (markerStart < 0) break;
    const suffixStart = source.indexOf(ReaderActionMarker.SUFFIX, markerStart);
    if (suffixStart < 0) break;
    const markerEnd = suffixStart + ReaderActionMarker.SUFFIX.length;
    const marker = source.substring(markerStart, markerEnd);
    const action = ReaderActionMarker.parse(marker);
    result += source.substring(cursor, markerStart);
    if (!action || !isReaderParagraphCommentAction(action)) result += marker;
    cursor = markerEnd;
  }
  return cursor > 0 ? `${result}${source.substring(cursor)}` : source;
}

export function isSameTtsVoiceOption(left: TtsVoiceOption, right: TtsVoiceOption): boolean {
  if (left.id !== right.id || left.online !== right.online ||
    !sameTtsLanguage(left.language || 'zh-CN', right.language || 'zh-CN')) {
    return false;
  }
  if (isKnownTtsVoiceId(left.id)) {
    return true;
  }
  return (left.style || '') === (right.style || '');
}

export function isSameTtsDisplayVoice(left: TtsVoiceOption, right: TtsVoiceOption): boolean {
  if (ttsVoiceTitle(left) === ttsVoiceTitle(right)) {
    return true;
  }
  return (left.name || '') === (right.name || '') && left.online === right.online &&
    sameTtsLanguage(left.language || 'zh-CN', right.language || 'zh-CN');
}

export function normalizeReaderText(text: string): string {
  return trimReaderContentText((text || '')
    .replace(/\r\n/g, '\n')
    .replace(/\u00A0/g, ' ')
    .replace(/\n{3,}/g, '\n\n'));
}

export function normalizeChapterBody(text: string): string {
  return mergeSoftWrappedChapterLines(trimReaderContentText((text || '')
    .replace(/\r\n/g, '\n')
    .replace(/\u00A0/g, ' ')
    .replace(/\n{3,}/g, '\n\n')));
}

export function stripDuplicatedChapterTitle(body: string, title: string): string {
  if (!body || !title) {
    return body;
  }
  const lines = body.split('\n');
  const firstLine = (lines[0] || '').replace(/^[　\s]+/g, '').trim();
  if (firstLine !== title) {
    return body;
  }
  return trimReaderContentText(lines.slice(1).join('\n').replace(/^\n+/, ''));
}

export function defaultTtsVoice(): TtsVoiceOption {
  const option = new TtsVoiceOption();
  option.id = 0;
  option.name = '默认音色';
  option.online = 1;
  option.status = 'default';
  option.language = 'zh-CN';
  option.available = true;
  return option;
}

export function mergeWithDefaultTtsVoice(voices: TtsVoiceOption[]): TtsVoiceOption[] {
  const options: TtsVoiceOption[] = [defaultTtsVoice()];
  for (const voice of voices) {
    const existingIndex = options.findIndex((item: TtsVoiceOption) =>
      isSameTtsVoiceOption(item, voice) || isSameTtsDisplayVoice(item, voice));
    if (existingIndex < 0) {
      options.push(voice);
    } else if (shouldPreferTtsVoiceOption(voice, options[existingIndex])) {
      options[existingIndex] = voice;
    }
  }
  return options;
}

export function buildIndentedChapterBody(text: string): string {
  const normalized = normalizeChapterBody(text);
  if (!normalized) {
    return '';
  }
  return normalized
    .split('\n')
    .map((line: string) => indentReaderLine(line))
    .join('\n');
}
