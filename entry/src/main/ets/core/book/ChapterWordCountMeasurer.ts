import { Book, BookChapter, BookSource, SearchBook } from '../../model/data/Book';
import { AppDatabase } from '../../model/data/AppDatabase';
import { WebBookService } from './WebBookService';

/** 需要额外测量字数的章节引用：换源时传目标书当前阅读章节（index + 标题）。 */
export class ChapterMeasureTarget {
  index: number = 0;
  title: string = '';
}

/**
 * 实测搜索结果的章节正文字数：默认取目录最后一章（并顺带回填最新章节标题），
 * 传入 currentChapter 时同时测量指定章节（换源场景即当前阅读章节）。
 * 换源面板与搜索页共用；单条最多 4 次网络请求，由调用方控制并发、超时与会话取消。
 */
export class ChapterWordCountMeasurer {
  static async measureOne(
    db: AppDatabase,
    candidate: SearchBook,
    shouldAbort: () => boolean,
    currentChapter?: ChapterMeasureTarget
  ): Promise<boolean> {
    const before = candidate.chapterWordCount;
    const beforeCurrent = candidate.currentChapterWordCount;
    try {
      const source: BookSource | null = candidate.origin ? await db.getBookSource(candidate.origin) : null;
      if (shouldAbort()) return false;
      if (!source) {
        candidate.chapterWordCount = 0;
        candidate.currentChapterWordCount = 0;
        return before !== 0 || beforeCurrent !== 0;
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
        candidate.currentChapterWordCount = 0;
        return before !== 0 || beforeCurrent !== 0;
      }
      const chapter = chapters[chapters.length - 1];
      candidate.latestChapterIndex = chapters.length - 1;
      const content = await service.getContent(source, book, chapter);
      if (shouldAbort()) return false;
      const length = (content || '').length;
      candidate.chapterWordCount = length > 0 ? length : 0;
      if (chapter.title) candidate.latestChapterTitle = chapter.title;
      if (currentChapter) {
        // 当前章节测量失败不影响已测得的最新章节字数，单独捕获。
        try {
          const target = ChapterWordCountMeasurer.pickCurrentChapter(chapters, currentChapter);
          if (!target) {
            // 目录未收录当前阅读章节（最新章都在阅读进度之前）：无需再拉正文，直接标记未收录。
            candidate.currentChapterReached = false;
            candidate.currentChapterWordCount = 0;
          } else if (target === chapter) {
            // 与最新一章相同（连载追平或只差序章）：复用已测结果，省一次请求。
            candidate.currentChapterWordCount = candidate.chapterWordCount;
          } else {
            const currentContent = await service.getContent(source, book, target);
            if (shouldAbort()) return false;
            const currentLength = (currentContent || '').length;
            candidate.currentChapterWordCount = currentLength > 0 ? currentLength : 0;
          }
        } catch (e) {
          if (shouldAbort()) return false;
          console.warn('测量当前章节字数失败:', e);
          candidate.currentChapterWordCount = 0;
        }
      }
      return true;
    } catch (e) {
      if (shouldAbort()) return false;
      console.warn('测量最新章节字数失败:', e);
      candidate.chapterWordCount = 0;
      candidate.currentChapterWordCount = 0;
      return before !== 0 || beforeCurrent !== 0;
    }
  }

  /** 定位当前阅读章节：先按标题精确匹配（各源目录章节命名有差异），
   *  匹配不到且目录长度未到阅读进度（index 超界）时返回 null 表示未收录。 */
  private static pickCurrentChapter(
    chapters: BookChapter[],
    target: ChapterMeasureTarget
  ): BookChapter | null {
    const title = (target.title || '').trim();
    if (title) {
      for (const chapter of chapters) {
        if (chapter.title && chapter.title.trim() === title) {
          return chapter;
        }
      }
    }
    if (target.index > chapters.length - 1) {
      return null;
    }
    return chapters[Math.max(0, target.index)];
  }
}
