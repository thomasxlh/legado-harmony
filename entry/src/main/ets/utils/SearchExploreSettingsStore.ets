import { Context } from '@kit.AbilityKit';
import preferences from '@ohos.data.preferences';

export class SearchExploreSettings {
  showResultCover: boolean = true;
  useBookshelfCoverGallery: boolean = false;
  showResultTags: boolean = true;
  aggregateSearchResults: boolean = true;
  promptAddToShelfOnBack: boolean = true;
  exactSearch: boolean = false;
  exactSearchMatchAuthor: boolean = true;
  showSearchProgress: boolean = true;
  searchConcurrency: number = 100;
  /** 攒够该数量的搜索结果就提前收工，不再搜剩余书源；0 表示关闭提前收工、搜完全部书源。 */
  stopAfterResults: number = 0;
  selectedSourceGroupsRaw: string = '';
  selectedSourceUrlsRaw: string = '__LEGACY_SOURCE_GROUP_SELECTION__';
  sourceSortRaw: string = '';
  exploreSourceUrl: string = '';
  explorePlatform: string = '';
}

export class SearchExploreSettingsStore {
  static readonly KEY_SHOW_RESULT_COVER: string = 'searchExploreShowResultCover';
  static readonly KEY_USE_BOOKSHELF_COVER_GALLERY: string = 'searchExploreUseBookshelfCoverGallery';
  static readonly KEY_SHOW_RESULT_TAGS: string = 'searchExploreShowResultTags';
  static readonly KEY_AGGREGATE_SEARCH_RESULTS: string = 'searchExploreAggregateResults';
  static readonly KEY_PROMPT_ADD_TO_SHELF_ON_BACK: string = 'searchExplorePromptAddToShelfOnBack';
  static readonly KEY_EXACT_SEARCH: string = 'searchExploreExactSearch';
  static readonly KEY_EXACT_SEARCH_MATCH_AUTHOR: string = 'searchExploreExactSearchMatchAuthor';
  static readonly KEY_SHOW_SEARCH_PROGRESS: string = 'searchExploreShowSearchProgress';
  static readonly KEY_SEARCH_CONCURRENCY: string = 'searchExploreSearchConcurrency';
  static readonly KEY_STOP_AFTER_RESULTS: string = 'searchExploreStopAfterResults';
  static readonly KEY_SELECTED_SOURCE_GROUPS: string = 'searchExploreSelectedSourceGroups';
  static readonly KEY_SELECTED_SOURCE_URLS: string = 'searchExploreSelectedSourceUrls';
  static readonly LEGACY_SOURCE_SELECTION: string = '__LEGACY_SOURCE_GROUP_SELECTION__';
  static readonly KEY_SOURCE_SORT: string = 'searchExploreSourceSort';
  static readonly KEY_EXPLORE_SOURCE_URL: string = 'exploreSourceUrl';
  static readonly KEY_EXPLORE_PLATFORM: string = 'explorePlatform';
  private static readonly STORE_NAME: string = 'search_explore_settings';
  private static readonly DEFAULT_SEARCH_CONCURRENCY: number = 100;
  /** 默认关闭提前收工：默认行为是搜完全部启用书源，"搜索完成"即本轮彻底结束。 */
  private static readonly DEFAULT_STOP_AFTER_RESULTS: number = 0;
  /** 提前收工阈值上限：与 SearchCoordinator 的单次搜索总结果上限保持一致。 */
  private static readonly MAX_STOP_AFTER_RESULTS: number = 300;
  private static readonly LEGACY_DEFAULT_SEARCH_CONCURRENCY: number = 6;
  private static readonly KEY_CONCURRENCY_MIGRATED: string = 'searchExploreConcurrencyMigrated100';
  private static readonly MIN_SEARCH_CONCURRENCY: number = 1;
  private static cachedSettings: SearchExploreSettings | null = null;

  static async load(context: Context): Promise<SearchExploreSettings> {
    if (SearchExploreSettingsStore.cachedSettings) {
      return SearchExploreSettingsStore.clone(SearchExploreSettingsStore.cachedSettings);
    }
    const store = await preferences.getPreferences(context, SearchExploreSettingsStore.STORE_NAME);
    const settings = new SearchExploreSettings();
    settings.showResultCover = await SearchExploreSettingsStore.getBoolean(
      store, SearchExploreSettingsStore.KEY_SHOW_RESULT_COVER, true);
    settings.useBookshelfCoverGallery = await SearchExploreSettingsStore.getBoolean(
      store, SearchExploreSettingsStore.KEY_USE_BOOKSHELF_COVER_GALLERY, false);
    settings.showResultTags = await SearchExploreSettingsStore.getBoolean(
      store, SearchExploreSettingsStore.KEY_SHOW_RESULT_TAGS, true);
    settings.aggregateSearchResults = await SearchExploreSettingsStore.getBoolean(
      store, SearchExploreSettingsStore.KEY_AGGREGATE_SEARCH_RESULTS, true);
    settings.promptAddToShelfOnBack = await SearchExploreSettingsStore.getBoolean(
      store, SearchExploreSettingsStore.KEY_PROMPT_ADD_TO_SHELF_ON_BACK, true);
    settings.exactSearch = await SearchExploreSettingsStore.getBoolean(
      store, SearchExploreSettingsStore.KEY_EXACT_SEARCH, false);
    settings.exactSearchMatchAuthor = await SearchExploreSettingsStore.getBoolean(
      store, SearchExploreSettingsStore.KEY_EXACT_SEARCH_MATCH_AUTHOR, true);
    settings.showSearchProgress = await SearchExploreSettingsStore.getBoolean(
      store, SearchExploreSettingsStore.KEY_SHOW_SEARCH_PROGRESS, true);
    const storageConcurrency = AppStorage.get<number>(SearchExploreSettingsStore.KEY_SEARCH_CONCURRENCY);
    settings.searchConcurrency = await SearchExploreSettingsStore.getNumber(
      store,
      SearchExploreSettingsStore.KEY_SEARCH_CONCURRENCY,
      typeof storageConcurrency === 'number' ?
        SearchExploreSettingsStore.normalizeSearchConcurrency(storageConcurrency) :
        SearchExploreSettingsStore.DEFAULT_SEARCH_CONCURRENCY);
    // 旧版本默认并发数为 6 且可能已被落盘；默认值改为 100 后做一次性迁移，
    // 落标记避免之后用户手动改回的值在下次启动时被再次覆盖。
    const concurrencyMigrated = await SearchExploreSettingsStore.getBoolean(
      store, SearchExploreSettingsStore.KEY_CONCURRENCY_MIGRATED, false);
    if (!concurrencyMigrated) {
      if (settings.searchConcurrency === SearchExploreSettingsStore.LEGACY_DEFAULT_SEARCH_CONCURRENCY) {
        settings.searchConcurrency = SearchExploreSettingsStore.DEFAULT_SEARCH_CONCURRENCY;
      }
      await store.put(SearchExploreSettingsStore.KEY_CONCURRENCY_MIGRATED, true);
      await store.flush();
    }
    // 提前收工阈值：允许 0（关闭提前收工），不能复用只接受正数的 getNumber。
    settings.stopAfterResults = SearchExploreSettingsStore.normalizeStopAfterResults(
      await SearchExploreSettingsStore.getNonNegativeNumber(store,
        SearchExploreSettingsStore.KEY_STOP_AFTER_RESULTS,
        SearchExploreSettingsStore.DEFAULT_STOP_AFTER_RESULTS));
    settings.selectedSourceGroupsRaw = await SearchExploreSettingsStore.getString(
      store, SearchExploreSettingsStore.KEY_SELECTED_SOURCE_GROUPS, '');
    settings.selectedSourceUrlsRaw = await SearchExploreSettingsStore.getString(
      store, SearchExploreSettingsStore.KEY_SELECTED_SOURCE_URLS,
      SearchExploreSettingsStore.LEGACY_SOURCE_SELECTION);
    settings.sourceSortRaw = await SearchExploreSettingsStore.getString(
      store, SearchExploreSettingsStore.KEY_SOURCE_SORT, '');
    settings.exploreSourceUrl = await SearchExploreSettingsStore.getString(
      store, SearchExploreSettingsStore.KEY_EXPLORE_SOURCE_URL, '');
    settings.explorePlatform = await SearchExploreSettingsStore.getString(
      store, SearchExploreSettingsStore.KEY_EXPLORE_PLATFORM, '');
    SearchExploreSettingsStore.cachedSettings = SearchExploreSettingsStore.clone(settings);
    return settings;
  }

  static async save(context: Context, settings: SearchExploreSettings): Promise<void> {
    const previous = SearchExploreSettingsStore.cachedSettings ?
      SearchExploreSettingsStore.clone(SearchExploreSettingsStore.cachedSettings) : null;
    SearchExploreSettingsStore.cachedSettings = SearchExploreSettingsStore.clone(settings);
    const store = await preferences.getPreferences(context, SearchExploreSettingsStore.STORE_NAME);
    await store.put(SearchExploreSettingsStore.KEY_SHOW_RESULT_COVER, settings.showResultCover);
    await store.put(SearchExploreSettingsStore.KEY_USE_BOOKSHELF_COVER_GALLERY, settings.useBookshelfCoverGallery);
    await store.put(SearchExploreSettingsStore.KEY_SHOW_RESULT_TAGS, settings.showResultTags);
    await store.put(SearchExploreSettingsStore.KEY_AGGREGATE_SEARCH_RESULTS, settings.aggregateSearchResults);
    await store.put(SearchExploreSettingsStore.KEY_PROMPT_ADD_TO_SHELF_ON_BACK, settings.promptAddToShelfOnBack);
    await store.put(SearchExploreSettingsStore.KEY_EXACT_SEARCH, settings.exactSearch);
    await store.put(SearchExploreSettingsStore.KEY_EXACT_SEARCH_MATCH_AUTHOR, settings.exactSearchMatchAuthor);
    await store.put(SearchExploreSettingsStore.KEY_SHOW_SEARCH_PROGRESS, settings.showSearchProgress);
    await store.put(SearchExploreSettingsStore.KEY_SEARCH_CONCURRENCY,
      SearchExploreSettingsStore.normalizeSearchConcurrency(settings.searchConcurrency));
    await store.put(SearchExploreSettingsStore.KEY_STOP_AFTER_RESULTS,
      SearchExploreSettingsStore.normalizeStopAfterResults(settings.stopAfterResults));
    await store.put(SearchExploreSettingsStore.KEY_SELECTED_SOURCE_GROUPS, settings.selectedSourceGroupsRaw);
    await store.put(SearchExploreSettingsStore.KEY_SELECTED_SOURCE_URLS, settings.selectedSourceUrlsRaw);
    await store.put(SearchExploreSettingsStore.KEY_SOURCE_SORT, settings.sourceSortRaw);
    await store.put(SearchExploreSettingsStore.KEY_EXPLORE_SOURCE_URL, settings.exploreSourceUrl);
    await store.put(SearchExploreSettingsStore.KEY_EXPLORE_PLATFORM, settings.explorePlatform);
    await store.flush();
  }

  static async saveExploreSelection(
    context: Context,
    exploreSourceUrl: string,
    explorePlatform: string
  ): Promise<void> {
    if (SearchExploreSettingsStore.cachedSettings) {
      SearchExploreSettingsStore.cachedSettings.exploreSourceUrl = exploreSourceUrl;
      SearchExploreSettingsStore.cachedSettings.explorePlatform = explorePlatform;
    }
    AppStorage.setOrCreate(SearchExploreSettingsStore.KEY_EXPLORE_SOURCE_URL, exploreSourceUrl);
    AppStorage.setOrCreate(SearchExploreSettingsStore.KEY_EXPLORE_PLATFORM, explorePlatform);
    const store = await preferences.getPreferences(context, SearchExploreSettingsStore.STORE_NAME);
    await store.put(SearchExploreSettingsStore.KEY_EXPLORE_SOURCE_URL, exploreSourceUrl);
    await store.put(SearchExploreSettingsStore.KEY_EXPLORE_PLATFORM, explorePlatform);
    await store.flush();
  }

  static applyToStorage(settings: SearchExploreSettings): void {
    SearchExploreSettingsStore.cachedSettings = SearchExploreSettingsStore.clone(settings);
    AppStorage.setOrCreate(SearchExploreSettingsStore.KEY_SHOW_RESULT_COVER, settings.showResultCover);
    AppStorage.setOrCreate(
      SearchExploreSettingsStore.KEY_USE_BOOKSHELF_COVER_GALLERY,
      settings.useBookshelfCoverGallery);
    AppStorage.setOrCreate(SearchExploreSettingsStore.KEY_SHOW_RESULT_TAGS, settings.showResultTags);
    AppStorage.setOrCreate(
      SearchExploreSettingsStore.KEY_AGGREGATE_SEARCH_RESULTS,
      settings.aggregateSearchResults);
    AppStorage.setOrCreate(
      SearchExploreSettingsStore.KEY_PROMPT_ADD_TO_SHELF_ON_BACK,
      settings.promptAddToShelfOnBack);
    AppStorage.setOrCreate(SearchExploreSettingsStore.KEY_EXACT_SEARCH, settings.exactSearch);
    AppStorage.setOrCreate(
      SearchExploreSettingsStore.KEY_EXACT_SEARCH_MATCH_AUTHOR,
      settings.exactSearchMatchAuthor);
    AppStorage.setOrCreate(SearchExploreSettingsStore.KEY_SHOW_SEARCH_PROGRESS, settings.showSearchProgress);
    AppStorage.setOrCreate(SearchExploreSettingsStore.KEY_SEARCH_CONCURRENCY,
      SearchExploreSettingsStore.normalizeSearchConcurrency(settings.searchConcurrency));
    AppStorage.setOrCreate(SearchExploreSettingsStore.KEY_STOP_AFTER_RESULTS,
      SearchExploreSettingsStore.normalizeStopAfterResults(settings.stopAfterResults));
    AppStorage.setOrCreate(SearchExploreSettingsStore.KEY_SELECTED_SOURCE_GROUPS, settings.selectedSourceGroupsRaw);
    AppStorage.setOrCreate(SearchExploreSettingsStore.KEY_SELECTED_SOURCE_URLS, settings.selectedSourceUrlsRaw);
    AppStorage.setOrCreate(SearchExploreSettingsStore.KEY_SOURCE_SORT, settings.sourceSortRaw);
    AppStorage.setOrCreate(SearchExploreSettingsStore.KEY_EXPLORE_SOURCE_URL, settings.exploreSourceUrl);
    AppStorage.setOrCreate(SearchExploreSettingsStore.KEY_EXPLORE_PLATFORM, settings.explorePlatform);
  }

  static getSearchConcurrency(): number {
    const cached = SearchExploreSettingsStore.cachedSettings?.searchConcurrency;
    if (typeof cached === 'number' && cached > 0) {
      return cached;
    }
    const value = AppStorage.get<number>(SearchExploreSettingsStore.KEY_SEARCH_CONCURRENCY);
    return typeof value === 'number' && value > 0 ?
      SearchExploreSettingsStore.normalizeSearchConcurrency(value) :
      SearchExploreSettingsStore.DEFAULT_SEARCH_CONCURRENCY;
  }

  static normalizeSearchConcurrency(value: number): number {
    const parsed = Math.round(value);
    if (Number.isNaN(parsed)) {
      return SearchExploreSettingsStore.DEFAULT_SEARCH_CONCURRENCY;
    }
    return Math.max(SearchExploreSettingsStore.MIN_SEARCH_CONCURRENCY, parsed);
  }

  /** 0 合法（关闭提前收工）；非法值回落到默认值，过大值夹到单次搜索上限。 */
  static normalizeStopAfterResults(value: number): number {
    const parsed = Math.round(value);
    if (!Number.isFinite(parsed) || parsed < 0) {
      return SearchExploreSettingsStore.DEFAULT_STOP_AFTER_RESULTS;
    }
    return Math.min(parsed, SearchExploreSettingsStore.MAX_STOP_AFTER_RESULTS);
  }

  /**
   * 提前收工阈值：0 表示搜完全部书源。
   * 与 getSearchConcurrency 同构：优先读缓存，再回落到 AppStorage。
   */
  static getStopAfterResults(): number {
    const cached = SearchExploreSettingsStore.cachedSettings?.stopAfterResults;
    if (typeof cached === 'number' && cached >= 0) {
      return SearchExploreSettingsStore.normalizeStopAfterResults(cached);
    }
    const value = AppStorage.get<number>(SearchExploreSettingsStore.KEY_STOP_AFTER_RESULTS);
    return typeof value === 'number' && value >= 0 ?
      SearchExploreSettingsStore.normalizeStopAfterResults(value) :
      SearchExploreSettingsStore.DEFAULT_STOP_AFTER_RESULTS;
  }

  private static async getBoolean(
    store: preferences.Preferences,
    key: string,
    fallback: boolean
  ): Promise<boolean> {
    const value = await store.get(key, fallback);
    return typeof value === 'boolean' ? value : fallback;
  }

  private static clone(source: SearchExploreSettings): SearchExploreSettings {
    const settings = new SearchExploreSettings();
    settings.showResultCover = source.showResultCover;
    settings.useBookshelfCoverGallery = source.useBookshelfCoverGallery;
    settings.showResultTags = source.showResultTags;
    settings.aggregateSearchResults = source.aggregateSearchResults !== false;
    settings.promptAddToShelfOnBack = source.promptAddToShelfOnBack;
    settings.exactSearch = source.exactSearch;
    settings.exactSearchMatchAuthor = source.exactSearchMatchAuthor;
    settings.showSearchProgress = source.showSearchProgress;
    settings.searchConcurrency = SearchExploreSettingsStore.normalizeSearchConcurrency(source.searchConcurrency);
    settings.stopAfterResults = SearchExploreSettingsStore.normalizeStopAfterResults(source.stopAfterResults);
    settings.selectedSourceGroupsRaw = source.selectedSourceGroupsRaw;
    settings.selectedSourceUrlsRaw = source.selectedSourceUrlsRaw || '';
    settings.sourceSortRaw = source.sourceSortRaw;
    settings.exploreSourceUrl = source.exploreSourceUrl;
    settings.explorePlatform = source.explorePlatform || '';
    return settings;
  }

  private static async getString(
    store: preferences.Preferences,
    key: string,
    fallback: string
  ): Promise<string> {
    const value = await store.get(key, fallback);
    return typeof value === 'string' ? value : fallback;
  }

  private static async getNonNegativeNumber(
    store: preferences.Preferences,
    key: string,
    fallback: number
  ): Promise<number> {
    const value = await store.get(key, fallback);
    if (typeof value === 'number' && Number.isFinite(value) && value >= 0) {
      return value;
    }
    // preferences 偶尔以字符串存数字，兼容读取但同样要求非负。
    if (typeof value === 'string' && value.trim() !== '') {
      const parsed = Number(value);
      if (Number.isFinite(parsed) && parsed >= 0) {
        return parsed;
      }
    }
    return fallback;
  }

  private static async getNumber(
    store: preferences.Preferences,
    key: string,
    fallback: number
  ): Promise<number> {
    const value = await store.get(key, fallback);
    if (typeof value === 'number' && !isNaN(value) && value > 0) {
      return SearchExploreSettingsStore.normalizeSearchConcurrency(value);
    }
    if (typeof value === 'string') {
      const parsed = Number(value);
      if (!Number.isNaN(parsed) && parsed > 0) {
        return SearchExploreSettingsStore.normalizeSearchConcurrency(parsed);
      }
    }
    return fallback;
  }

  private static syncFieldsChanged(left: SearchExploreSettings, right: SearchExploreSettings): boolean {
    return left.showResultCover !== right.showResultCover ||
      left.useBookshelfCoverGallery !== right.useBookshelfCoverGallery ||
      left.showResultTags !== right.showResultTags ||
      left.aggregateSearchResults !== right.aggregateSearchResults ||
      left.promptAddToShelfOnBack !== right.promptAddToShelfOnBack ||
      left.exactSearch !== right.exactSearch ||
      left.exactSearchMatchAuthor !== right.exactSearchMatchAuthor ||
      left.showSearchProgress !== right.showSearchProgress ||
      left.stopAfterResults !== right.stopAfterResults ||
      left.selectedSourceUrlsRaw !== right.selectedSourceUrlsRaw;
  }
}
