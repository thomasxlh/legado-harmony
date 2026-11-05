import { Context } from '@kit.AbilityKit';
import preferences from '@ohos.data.preferences';

/**
 * 书源校验配置。字段命名对齐 Android 的 CheckSourceConfig，便于对照与迁移。
 * 这里只记录"要查哪些环节"，具体怎么查由 SearchCoordinator / ExploreReadingValidator 决定。
 */
export class BookSourceCheckOptions {
  /** 'search' 搜索能力 | 'exploreReading' 发现/阅读链路 */
  mode: string = 'search';
  /** 'none' 仅校验 | 'disable' 自动禁用 | 'delete' 自动删除 */
  invalidAction: string = 'none';
  checkDomain: boolean = true;
  checkSearch: boolean = true;
  checkDiscovery: boolean = true;
  checkInfo: boolean = true;
  checkCategory: boolean = true;
  checkContent: boolean = true;
  /** 单个书源的校验总时长上限（秒），超时记「暂时异常」。 */
  timeoutSeconds: number = 180;
}

export class BookSourceCheckOptionsStore {
  static readonly DEFAULT_TIMEOUT_SECONDS: number = 180;
  static readonly MIN_TIMEOUT_SECONDS: number = 10;
  static readonly MAX_TIMEOUT_SECONDS: number = 1800;
  private static readonly STORE_NAME: string = 'book_source_check_options';
  private static readonly KEY_OPTIONS: string = 'optionsV1';
  private static cached: BookSourceCheckOptions | null = null;

  static invalidateCache(): void {
    BookSourceCheckOptionsStore.cached = null;
  }

  static async load(context: Context, force: boolean = false): Promise<BookSourceCheckOptions> {
    if (!force && BookSourceCheckOptionsStore.cached) {
      return BookSourceCheckOptionsStore.clone(BookSourceCheckOptionsStore.cached);
    }
    const options = new BookSourceCheckOptions();
    try {
      const store = await preferences.getPreferences(context, BookSourceCheckOptionsStore.STORE_NAME);
      const raw = await store.get(BookSourceCheckOptionsStore.KEY_OPTIONS, '');
      if (typeof raw === 'string' && raw) {
        const parsed = JSON.parse(raw) as BookSourceCheckOptions;
        if (parsed && typeof parsed === 'object') {
          BookSourceCheckOptionsStore.applyTo(options, parsed);
        }
      }
    } catch (e) {
      console.warn('读取书源校验配置失败:', e);
    }
    BookSourceCheckOptionsStore.applyChain(options);
    BookSourceCheckOptionsStore.cached = BookSourceCheckOptionsStore.clone(options);
    return options;
  }

  static async save(context: Context, options: BookSourceCheckOptions): Promise<void> {
    const normalized = BookSourceCheckOptionsStore.clone(options);
    BookSourceCheckOptionsStore.applyChain(normalized);
    BookSourceCheckOptionsStore.cached = BookSourceCheckOptionsStore.clone(normalized);
    try {
      const store = await preferences.getPreferences(context, BookSourceCheckOptionsStore.STORE_NAME);
      await store.put(BookSourceCheckOptionsStore.KEY_OPTIONS, JSON.stringify(normalized));
      await store.flush();
    } catch (e) {
      console.warn('保存书源校验配置失败:', e);
    }
  }

  /** 界面对外暴露的"当前配置"，读不到时给默认值。 */
  static current(): BookSourceCheckOptions {
    const options = BookSourceCheckOptionsStore.cached ?
      BookSourceCheckOptionsStore.clone(BookSourceCheckOptionsStore.cached) : new BookSourceCheckOptions();
    BookSourceCheckOptionsStore.applyChain(options);
    return options;
  }

  static normalizeTimeout(value: number): number {
    const parsed = Math.round(value);
    if (Number.isNaN(parsed)) {
      return BookSourceCheckOptionsStore.DEFAULT_TIMEOUT_SECONDS;
    }
    return Math.max(BookSourceCheckOptionsStore.MIN_TIMEOUT_SECONDS,
      Math.min(BookSourceCheckOptionsStore.MAX_TIMEOUT_SECONDS, parsed));
  }

  /**
   * 环节依赖链：链路上游关掉后，下游无从校验必须一起关。
   * 发现 → 详情 → 目录 → 正文逐级依赖；关掉搜索则搜索能力校验本身没有意义。
   */
  private static applyChain(options: BookSourceCheckOptions): void {
    if (!options.checkDiscovery) {
      options.checkInfo = false;
    }
    if (!options.checkInfo) {
      options.checkCategory = false;
    }
    if (!options.checkCategory) {
      options.checkContent = false;
    }
    options.timeoutSeconds = BookSourceCheckOptionsStore.normalizeTimeout(options.timeoutSeconds);
  }

  private static applyTo(target: BookSourceCheckOptions, source: BookSourceCheckOptions): void {
    if (source.mode === 'search' || source.mode === 'exploreReading') {
      target.mode = source.mode;
    }
    if (source.invalidAction === 'none' || source.invalidAction === 'disable' ||
      source.invalidAction === 'delete') {
      target.invalidAction = source.invalidAction;
    }
    target.checkDomain = source.checkDomain !== false;
    target.checkSearch = source.checkSearch !== false;
    target.checkDiscovery = source.checkDiscovery !== false;
    target.checkInfo = source.checkInfo !== false;
    target.checkCategory = source.checkCategory !== false;
    target.checkContent = source.checkContent !== false;
    target.timeoutSeconds = BookSourceCheckOptionsStore.normalizeTimeout(
      Number(source.timeoutSeconds) || BookSourceCheckOptionsStore.DEFAULT_TIMEOUT_SECONDS);
  }

  private static clone(item: BookSourceCheckOptions): BookSourceCheckOptions {
    const options = new BookSourceCheckOptions();
    options.mode = item.mode;
    options.invalidAction = item.invalidAction;
    options.checkDomain = item.checkDomain;
    options.checkSearch = item.checkSearch;
    options.checkDiscovery = item.checkDiscovery;
    options.checkInfo = item.checkInfo;
    options.checkCategory = item.checkCategory;
    options.checkContent = item.checkContent;
    options.timeoutSeconds = item.timeoutSeconds;
    return options;
  }
}
