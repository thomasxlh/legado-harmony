import { Book, BookSource, SearchBook } from '../../model/data/Book';
import { AppDatabase } from '../../model/data/AppDatabase';
import { WebBookService } from './WebBookService';

/**
 * 实测搜索结果最新章节的正文字数：取目录最后一章的正文长度，并顺带回填最新章节标题。
 * 换源面板与搜索页共用；单条最多 3 次网络请求，由调用方控制并发、超时与会话取消。
 */
export class ChapterWordCountMeasurer {
  static async measureOne(db: AppDatabase, candidate: SearchBook, shouldAbort: () => boolean): Promise<boolean> {
    const before = candidate.chapterWordCount;
    try {
      const source: BookSource | null = candidate.origin ? await db.getBookSource(candidate.origin) : null;
      if (shouldAbort()) return false;
      if (!source) {
        candidate.chapterWordCount = 0;
        return before !== 0;
      }
      const book = new Book();
      book.bookUrl = candidate.bookUrl;
      book.tocUrl = candidate.tocUrl;
      book.origin = candidate.origin;
      book.originName = candidate.originName;
      book.name = candidate.name;
      book.author = candidate.author;
      book.variable = candidate.variable || '';
      book.type = candidate.type || 0;
      const service = new WebBookService();
      if (!book.tocUrl) {
        const info = await service.getBookInfo(source, book);
        if (shouldAbort()) return false;
        if (info && info.tocUrl) book.tocUrl = info.tocUrl;
      }
      const chapters = await service.getChapterList(source, book, 0, false);
      if (shouldAbort()) return false;
      if (chapters.length === 0) {
        candidate.chapterWordCount = 0;
        return before !== 0;
      }
      const chapter = chapters[chapters.length - 1];
      const content = await service.getContent(source, book, chapter);
      if (shouldAbort()) return false;
      const length = (content || '').length;
      candidate.chapterWordCount = length > 0 ? length : 0;
      if (chapter.title) candidate.latestChapterTitle = chapter.title;
      return true;
    } catch (e) {
      if (shouldAbort()) return false;
      console.warn('测量最新章节字数失败:', e);
      candidate.chapterWordCount = 0;
      return before !== 0;
    }
  }
}
