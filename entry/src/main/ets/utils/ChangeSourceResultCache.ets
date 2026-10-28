import { Context } from '@kit.AbilityKit';
import preferences from '@ohos.data.preferences';
import { SearchBook } from '../model/data/Book';

export class ChangeSourceCacheData {
  results: SearchBook[] = [];
  searchedSourceUrls: string[] = [];
  /** true 表示上次搜索被中断（换源尝试/关闭面板），重开时可续搜剩余书源。 */
  partial: boolean = false;
}

class ChangeSourceCacheEntry {
  schemaVersion: number = 0;
  key: string = '';
  updatedAt: number = 0;
  results: SearchBook[] = [];
  searchedSourceUrls: string[] = [];
  partial: boolean = false;
  /** 上次落盘时目标书的阅读章节序号；-1 表示旧数据（无此字段）。 */
  chapterIndex: number = -1;
}

class ChangeSourceCacheIndexEntry {
  key: string = '';
  updatedAt: number = 0;
}

export class ChangeSourceResultCache {
  private static readonly STORE_NAME: string = 'change_source_result_cache';
  private static readonly SCHEMA_VERSION: number = 4;
  private static readonly INDEX_KEY: string = 'entry_index_v4';
  private static readonly ENTRY_PREFIX: string = 'entry_v4_';
  private static readonly MAX_BOOKS: number = 30;
  private static readonly MAX_RESULTS_PER_BOOK: number = 50;
  private static readonly MAX_SEARCHED_SOURCES: number = 2000;
  private static readonly MAX_AGE_MS: number = 24 * 60 * 60 * 1000;
  /** 缓存 preferences store 实例，避免每次 save/load 都触发 getPreferences 的文件打开开销；
   *  aboutToDisappear 里的 persistResultsNow 需要尽快完成 put() 同步写入，减少组件销毁时的 race window。 */
  private static cachedStore: preferences.Preferences | null = null;
  private static cachedStoreContext: Context | null = null;
  /** 串行化 save/clear 的索引读改写链：并发时后到的操作基于最新索引，避免互相覆盖丢条目。 */
  private static writeChain: Promise<void> = Promise.resolve();

  private static async ensureStore(context: Context): Promise<preferences.Preferences> {
    if (ChangeSourceResultCache.cachedStore) return ChangeSourceResultCache.cachedStore;
    const store = await preferences.getPreferences(context, ChangeSourceResultCache.STORE_NAME);
    ChangeSourceResultCache.cachedStore = store;
    ChangeSourceResultCache.cachedStoreContext = context;
    return store;
  }

  static invalidateStore(): void {
    ChangeSourceResultCache.cachedStore = null;
    ChangeSourceResultCache.cachedStoreContext = null;
  }

  /** 读取历史结果。chapterIndex 为目标书当前阅读章节：与落盘时不一致说明"当前章节字数"
   *  是旧进度下测的，必须作废（重置为未测量），否则会把上一章的字数显示在最新章节位置上。 */
  static async load(context: Context, bookName: string, bookAuthor: string = '',
    chapterIndex: number = -1): Promise<ChangeSourceCacheData | null> {
    const store = await ChangeSourceResultCache.ensureStore(context);
    const key = ChangeSourceResultCache.buildBookKey(bookName, bookAuthor);
    const raw = await store.get(ChangeSourceResultCache.entryPreferenceKey(key), '');
    const entry = ChangeSourceResultCache.parseEntry(typeof raw === 'string' ? raw : '');
    if (entry && Date.now() - entry.updatedAt <= ChangeSourceResultCache.MAX_AGE_MS) {
      const positionChanged = entry.chapterIndex !== chapterIndex;
      const data = new ChangeSourceCacheData();
      data.results = entry.results.map((item: SearchBook) => {
        const cloned = ChangeSourceResultCache.cloneSearchBook(item);
        if (positionChanged) {
          // 阅读进度变了：当前章节字数与"是否收录"都不可信，留待按新进度重测。
          cloned.currentChapterWordCount = -1;
          cloned.currentChapterReached = true;
        }
        return cloned;
      });
      data.searchedSourceUrls = entry.searchedSourceUrls.slice();
      data.partial = entry.partial;
      return data;
    }
    return null;
  }

  static save(context: Context, bookName: string, results: SearchBook[], bookAuthor: string = '',
    searchedSourceUrls: string[] = [], partial: boolean = false, chapterIndex: number = -1): Promise<void> {
    return ChangeSourceResultCache.enqueueWrite((): Promise<void> =>
      ChangeSourceResultCache.performSave(context, bookName, results, bookAuthor, searchedSourceUrls, partial, chapterIndex));
  }

  private static enqueueWrite(task: () => Promise<void>): Promise<void> {
    const previous = ChangeSourceResultCache.writeChain;
    const current = previous.then((): Promise<void> => task());
    // 链本身不因单次失败而中断，但错误仍传给本次调用的调用方。
    ChangeSourceResultCache.writeChain = current.catch((): void => {});
    return current;
  }

  private static async performSave(context: Context, bookName: string, results: SearchBook[],
    bookAuthor: string, searchedSourceUrls: string[], partial: boolean, chapterIndex: number): Promise<void> {
    const key = ChangeSourceResultCache.buildBookKey(bookName, bookAuthor);
    if (!key) {
      return;
    }
    const entry = new ChangeSourceCacheEntry();
    entry.schemaVersion = ChangeSourceResultCache.SCHEMA_VERSION;
    entry.key = key;
    entry.updatedAt = Date.now();
    entry.chapterIndex = chapterIndex;
    entry.results = results.slice(0, ChangeSourceResultCache.MAX_RESULTS_PER_BOOK)
      .map((item: SearchBook) => ChangeSourceResultCache.cloneSearchBook(item));
    entry.searchedSourceUrls = searchedSourceUrls
      .slice(0, ChangeSourceResultCache.MAX_SEARCHED_SOURCES)
      .map((value: string): string => value || '')
      .filter((value: string): boolean => !!value);
    entry.partial = partial;

    const store = await ChangeSourceResultCache.ensureStore(context);
    await store.put(ChangeSourceResultCache.entryPreferenceKey(key), JSON.stringify(entry));
    const index = await ChangeSourceResultCache.loadIndex(context);
    const next = new ChangeSourceCacheIndexEntry();
    next.key = key;
    next.updatedAt = entry.updatedAt;
    const merged = [next].concat(index.filter((item: ChangeSourceCacheIndexEntry): boolean => item.key !== key));
    const kept = merged.slice(0, ChangeSourceResultCache.MAX_BOOKS);
    for (const removed of merged.slice(ChangeSourceResultCache.MAX_BOOKS)) {
      await store.delete(ChangeSourceResultCache.entryPreferenceKey(removed.key));
    }
    await store.put(ChangeSourceResultCache.INDEX_KEY, JSON.stringify(kept));
    await store.flush();
  }

  /** 删除某本书的换源结果缓存（清空重搜用）。 */
  static clear(context: Context, bookName: string, bookAuthor: string = ''): Promise<void> {
    return ChangeSourceResultCache.enqueueWrite((): Promise<void> =>
      ChangeSourceResultCache.performClear(context, bookName, bookAuthor));
  }

  private static async performClear(context: Context, bookName: string, bookAuthor: string): Promise<void> {
    const key = ChangeSourceResultCache.buildBookKey(bookName, bookAuthor);
    if (!key) return;
    const store = await ChangeSourceResultCache.ensureStore(context);
    await store.delete(ChangeSourceResultCache.entryPreferenceKey(key));
    const index = await ChangeSourceResultCache.loadIndex(context);
    if (index.some((item: ChangeSourceCacheIndexEntry): boolean => item.key === key)) {
      const kept = index.filter((item: ChangeSourceCacheIndexEntry): boolean => item.key !== key);
      await store.put(ChangeSourceResultCache.INDEX_KEY, JSON.stringify(kept));
    }
    await store.flush();
  }

  private static async loadIndex(context: Context): Promise<ChangeSourceCacheIndexEntry[]> {
    const store = await ChangeSourceResultCache.ensureStore(context);
    const raw = await store.get(ChangeSourceResultCache.INDEX_KEY, '');
    if (typeof raw !== 'string' || !raw) return [];
    try {
      const parsed = JSON.parse(raw) as Object;
      if (!Array.isArray(parsed)) return [];
      const result: ChangeSourceCacheIndexEntry[] = [];
      const items: Object[] = parsed as Object[];
      for (const item of items) {
        if (!item || typeof item !== 'object' || Array.isArray(item)) continue;
        const record = item as Record<string, Object>;
        const entry = new ChangeSourceCacheIndexEntry();
        entry.key = String(record['key'] || '');
        entry.updatedAt = Number(record['updatedAt'] || 0);
        if (entry.key) result.push(entry);
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  private static parseEntry(raw: string): ChangeSourceCacheEntry | null {
    if (!raw) return null;
    try {
      const parsed = JSON.parse(raw) as ChangeSourceCacheEntry;
      if (!parsed || parsed.schemaVersion !== ChangeSourceResultCache.SCHEMA_VERSION ||
        !Array.isArray(parsed.results)) return null;
      if (!Array.isArray(parsed.searchedSourceUrls)) {
        parsed.searchedSourceUrls = [];
      }
      // 历史数据可能含 null/非对象元素，逐个校验后再交给 cloneSearchBook，
      // 避免 load() 里 map 访问属性时抛 TypeError。
      const rawResults: Object[] = parsed.results as Object[];
      const results: SearchBook[] = [];
      for (const item of rawResults) {
        if (!item || typeof item !== 'object') continue;
        results.push(ChangeSourceResultCache.cloneSearchBook(item as SearchBook));
      }
      parsed.results = results;
      parsed.partial = parsed.partial === true;
      const storedIndex = Number(parsed.chapterIndex);
      parsed.chapterIndex = Number.isFinite(storedIndex) ? storedIndex : -1;
      return parsed;
    } catch (_) {
      return null;
    }
  }

  private static buildBookKey(bookName: string, bookAuthor: string): string {
    const normalized = `${ChangeSourceResultCache.normalize(bookName)}\n${ChangeSourceResultCache.normalize(bookAuthor)}`;
    return normalized.trim() ? ChangeSourceResultCache.hashKey(normalized) : '';
  }

  private static normalize(value: string): string {
    return (value || '').trim().replace(/\s+/g, '').toLowerCase();
  }

  private static hashKey(value: string): string {
    let hash = 2166136261;
    for (let index = 0; index < value.length; index++) {
      hash ^= value.charCodeAt(index);
      hash = Math.imul(hash, 16777619);
    }
    return (hash >>> 0).toString(16).padStart(8, '0');
  }

  private static entryPreferenceKey(key: string): string {
    return `${ChangeSourceResultCache.ENTRY_PREFIX}${key}`;
  }

  private static cloneSearchBook(source: SearchBook): SearchBook {
    const target = new SearchBook();
    target.bookUrl = source.bookUrl || '';
    target.origin = source.origin || '';
    target.originName = source.originName || '';
    target.type = source.type || 0;
    target.name = source.name || '';
    target.author = source.author || '';
    target.kind = '';
    target.status = source.status || '';
    target.coverUrl = source.coverUrl || '';
    target.intro = '';
    target.latestChapterTitle = source.latestChapterTitle || '';
    target.wordCount = source.wordCount || '';
    target.updateTime = source.updateTime || '';
    target.tocUrl = source.tocUrl || '';
    target.variable = source.variable || '';
    target.bookSourceComment = '';
    target.customOrder = source.customOrder || 0;
    target.weight = source.weight || 0;
    const measured = Number(source.chapterWordCount);
    target.chapterWordCount = Number.isFinite(measured) ? measured : -1;
    const measuredCurrent = Number(source.currentChapterWordCount);
    target.currentChapterWordCount = Number.isFinite(measuredCurrent) ? measuredCurrent : -1;
    const latestIndex = Number(source.latestChapterIndex);
    target.latestChapterIndex = Number.isFinite(latestIndex) ? latestIndex : -1;
    target.currentChapterReached = source.currentChapterReached !== false;
    return target;
  }
}
