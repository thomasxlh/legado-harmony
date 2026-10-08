import { SearchBook } from '../model/data/Book';
import { SearchResultAggregationStore } from './SearchResultAggregationStore';

/**
 * 搜索结果排序（换源面板与搜索页共用）。
 * 排序规则：最新章节号从大到小，相同则字数从大到小；
 * 字数优先用实测的最新章节字数（chapterWordCount，仅单章，不累加估算总字数），
 * 其次解析书源提供的总字数字段（wordCount，支持"万"单位）；
 * 实测失败（chapterWordCount === 0）的结果沉底，不参与章节号排序。
 */
export class SearchResultSorter {
  /** 整表按换源规则排序：结果本就是同一本书的不同书源（换源面板）。 */
  static sort(books: SearchBook[]): SearchBook[] {
    if (books.length < 2) return books.slice();
    // 字数实测失败（chapterWordCount === 0）的结果整体沉底。
    const normal: SearchBook[] = [];
    const failed: SearchBook[] = [];
    for (const book of books) {
      if (book.chapterWordCount === 0) {
        failed.push(book);
      } else {
        normal.push(book);
      }
    }
    const compare = (a: SearchBook, b: SearchBook): number => {
      const chapterDiff = SearchResultSorter.chapterSortKey(b) - SearchResultSorter.chapterSortKey(a);
      if (chapterDiff !== 0) return chapterDiff;
      return SearchResultSorter.wordSortKey(b) - SearchResultSorter.wordSortKey(a);
    };
    normal.sort(compare);
    if (failed.length === 0) return normal;
    failed.sort(compare);
    return normal.concat(failed);
  }

  /**
   * 同名分组内重排（搜索页）：相关性顺序决定不同书之间的先后，
   * 同一本书的不同书源按换源规则择优；聚合同名结果时组代表自动是最优源。
   */
  static sortWithinSameName(books: SearchBook[]): SearchBook[] {
    if (books.length < 2) return books.slice();
    const clusters = new Map<string, SearchBook[]>();
    const clusterOrder: string[] = [];
    for (const book of books) {
      const key = SearchResultAggregationStore.keyOf(book);
      const cluster = clusters.get(key);
      if (cluster) {
        cluster.push(book);
      } else {
        clusters.set(key, [book]);
        clusterOrder.push(key);
      }
    }
    const result: SearchBook[] = [];
    for (const key of clusterOrder) {
      const cluster = clusters.get(key);
      if (!cluster) continue;
      const sortedCluster = SearchResultSorter.sort(cluster);
      for (const item of sortedCluster) {
        result.push(item);
      }
    }
    return result;
  }

  /** 从最新章节标题提取章节序号：优先"第N章/回/集/节/话/幕"，带"第N卷/部"时按卷折算；无数字返回 -1（排最后）。 */
  static chapterSortKey(book: SearchBook): number {
    const title = book.latestChapterTitle || '';
    if (!title) return -1;
    const chapterMatch = title.match(/第\s*(\d+)\s*[章回集节话幕]/);
    const volumeMatch = title.match(/第\s*(\d+)\s*[卷部]/);
    if (chapterMatch) {
      const chapter = Number(chapterMatch[1]);
      if (!Number.isFinite(chapter)) return -1;
      if (volumeMatch) {
        const volume = Number(volumeMatch[1]);
        return (Number.isFinite(volume) ? volume : 0) * 1000000 + chapter;
      }
      return chapter;
    }
    if (volumeMatch) {
      const volume = Number(volumeMatch[1]);
      return Number.isFinite(volume) ? volume * 1000000 : -1;
    }
    const anyNumber = title.match(/\d+/);
    if (anyNumber) {
      const value = Number(anyNumber[0]);
      return Number.isFinite(value) ? value : -1;
    }
    return -1;
  }

  /** 字数排序键：优先实测最新章节字数，其次解析书源提供的总字数（支持"万"单位）；获取不到返回 -1（视作最小，排最后）。 */
  static wordSortKey(book: SearchBook): number {
    if (book.chapterWordCount > 0) return book.chapterWordCount;
    if (book.chapterWordCount === 0) return -1; // 实测失败
    const raw = book.wordCount || '';
    if (!raw) return -1;
    const wanMatch = raw.match(/([\d.]+)\s*万/);
    if (wanMatch) {
      const value = Number(wanMatch[1]);
      return Number.isFinite(value) ? value * 10000 : -1;
    }
    const numMatch = raw.match(/\d+/);
    if (numMatch) {
      const value = Number(numMatch[0]);
      return Number.isFinite(value) ? value : -1;
    }
    return -1;
  }
}
