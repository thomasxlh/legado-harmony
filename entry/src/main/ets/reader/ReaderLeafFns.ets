/**
 * 阅读页叶子纯函数集合 —— 从 ReadBook.ets 抽离（P0 第二步）。
 * 这些函数不读取任何 @State / this 状态，只依赖显式参数、模块级 import 与 ArkUI 全局。
 * 调用方通过 `import * as LeafFns` 命名空间引用，避免与页面内同名符号冲突。
 * 由 scripts/gen_reader_code_map.py 生成的 CODE_MAP.md 记录职责分区。
 */

import { LocalBookService } from '../core/book/LocalBookService';
import { ReadBookEngine } from '../core/book/ReadBookEngine';
import { ReaderActionMarker, ReaderActionMatch } from '../core/book/ReaderActionMarker';
import { ReadTextSlice, ReaderPaginationResult, ReaderTextParagraph } from '../core/reader/ReaderPageModels';
import { ReaderCustomFontData, ReaderCustomFontItem, ReaderTxtCharsetOption } from '../core/reader/ReaderSettingsModels';
import { BookChapter, BookSource, HttpTTS } from '../model/data/Book';
import { ThemeRuntime } from '../theme/ThemeRuntime';
import { ImmersiveMaterialRuntime } from '../utils/ImmersiveMaterialRuntime';
import { ReaderFontHelper } from '../utils/ReaderFontHelper';
import { ReaderSettingsStore } from '../utils/ReaderSettingsStore';
import { hashText } from './ReaderPureUtils';
import { SystemTtsReader, TtsVoiceOption } from '../utils/SystemTtsReader';

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
