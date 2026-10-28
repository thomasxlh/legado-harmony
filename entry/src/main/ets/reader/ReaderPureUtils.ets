import { Book } from '../model/data/Book';

/**
 * 阅读页无状态纯工具函数集合：从 ReadBook.ets 抽取，无任何页面状态依赖。
 */
export const READER_PROGRESS_OFFSET_KEY = 'readProgressCharOffsetV2';
export const READER_PROGRESS_OFFSET_CHAPTER_KEY = 'readProgressCharOffsetChapterV2';

export function hashText(text: string): number {
  let hash = 0;
  for (let i = 0; i < text.length; i++) {
    hash = ((hash * 31) + text.charCodeAt(i)) & 0x7fffffff;
  }
  return hash;
}

export function hashTtsText(value: string): number {
  let hash = 0;
  for (let i = 0; i < value.length; i++) {
    hash = value.charCodeAt(i) + ((hash << 5) - hash);
  }
  return hash;
}

export function parseAreaDimension(value: Length): number {
  if (typeof value === 'number') {
    return value;
  }
  if (typeof value !== 'string') {
    return 0;
  }
  const text = String(value || '').trim();
  const match = text.match(/-?\d+(\.\d+)?/);
  if (!match) {
    return 0;
  }
  const parsed = Number(match[0]);
  return Number.isFinite(parsed) ? parsed : 0;
}

export function savedReaderProgressOffset(book: Book | null, chapterIndex: number): number {
  if (!book) return -1;
  const chapterRaw = book.getVariable(READER_PROGRESS_OFFSET_CHAPTER_KEY);
  const offsetRaw = book.getVariable(READER_PROGRESS_OFFSET_KEY);
  if (!chapterRaw || !offsetRaw) return -1;
  const storedChapter = Number(chapterRaw);
  const storedOffset = Number(offsetRaw);
  if (!Number.isFinite(storedChapter) || Math.round(storedChapter) !== chapterIndex ||
    !Number.isFinite(storedOffset) || storedOffset < 0) {
    return -1;
  }
  return Math.round(storedOffset);
}
