import { Context } from '@kit.AbilityKit';
import preferences from '@ohos.data.preferences';

/** 一次书源校验的结论快照。失败原因在这里落盘，关掉校验弹窗后仍可回看。 */
export class BookSourceCheckReport {
  bookSourceUrl: string = '';
  /** BookSource.VALIDATION_* 常量。 */
  status: number = 0;
  message: string = '';
  checkedAt: number = 0;
}

/**
 * 校验收据按 URL 存放在独立 Preferences 中，不写 book_sources。
 * 校验原因是运行态诊断信息而非书源定义的一部分，放进同步表会跟云端 schema 漂移，
 * 且书源被删除后残留的收据没有同步价值。
 */
export class BookSourceCheckReportStore {
  private static readonly STORE_NAME: string = 'book_source_check_reports';
  private static readonly KEY_REPORTS: string = 'reportsV1';
  /** 收据总数上限：超出后按 checkedAt 从旧到新淘汰，避免长期使用后无界增长。 */
  private static readonly MAX_REPORTS: number = 800;
  private static cached: BookSourceCheckReport[] | null = null;

  static invalidateCache(): void {
    BookSourceCheckReportStore.cached = null;
  }

  static async load(context: Context, force: boolean = false): Promise<BookSourceCheckReport[]> {
    if (!force && BookSourceCheckReportStore.cached) {
      return BookSourceCheckReportStore.cloneAll(BookSourceCheckReportStore.cached);
    }
    try {
      const store = await preferences.getPreferences(context, BookSourceCheckReportStore.STORE_NAME);
      const raw = await store.get(BookSourceCheckReportStore.KEY_REPORTS, '');
      const reports = BookSourceCheckReportStore.decode(typeof raw === 'string' ? raw : '');
      BookSourceCheckReportStore.cached = reports;
      return BookSourceCheckReportStore.cloneAll(reports);
    } catch (e) {
      console.warn('读取书源校验收据失败:', e);
      BookSourceCheckReportStore.cached = [];
      return [];
    }
  }

  static async save(context: Context, reports: BookSourceCheckReport[]): Promise<void> {
    const normalized = BookSourceCheckReportStore.normalize(reports);
    BookSourceCheckReportStore.cached = normalized;
    try {
      const store = await preferences.getPreferences(context, BookSourceCheckReportStore.STORE_NAME);
      await store.put(BookSourceCheckReportStore.KEY_REPORTS, JSON.stringify(normalized));
      await store.flush();
    } catch (e) {
      console.warn('保存书源校验收据失败:', e);
    }
  }

  /** 批量合并写入：一次校验结束后只落盘一次，避免逐条 flush。 */
  static async upsertMany(context: Context, incoming: BookSourceCheckReport[]): Promise<void> {
    if (incoming.length === 0) {
      return;
    }
    const current = await BookSourceCheckReportStore.load(context);
    const byUrl: Map<string, BookSourceCheckReport> = new Map();
    for (const item of current) {
      if (item.bookSourceUrl) {
        byUrl.set(item.bookSourceUrl, item);
      }
    }
    for (const item of incoming) {
      if (item.bookSourceUrl) {
        byUrl.set(item.bookSourceUrl, BookSourceCheckReportStore.clone(item));
      }
    }
    await BookSourceCheckReportStore.save(context, Array.from(byUrl.values()));
  }

  static async clear(context: Context): Promise<void> {
    BookSourceCheckReportStore.cached = [];
    try {
      const store = await preferences.getPreferences(context, BookSourceCheckReportStore.STORE_NAME);
      await store.put(BookSourceCheckReportStore.KEY_REPORTS, '[]');
      await store.flush();
    } catch (e) {
      console.warn('清空书源校验收据失败:', e);
    }
  }

  /** 书源列表变化后丢弃已不存在书源的收据。 */
  static async prune(context: Context, validUrls: string[]): Promise<void> {
    const current = await BookSourceCheckReportStore.load(context);
    const valid = new Set<string>(validUrls);
    const next = current.filter((item: BookSourceCheckReport) => valid.has(item.bookSourceUrl));
    if (next.length !== current.length) {
      await BookSourceCheckReportStore.save(context, next);
    }
  }

  private static normalize(reports: BookSourceCheckReport[]): BookSourceCheckReport[] {
    const byUrl: Map<string, BookSourceCheckReport> = new Map();
    for (const item of reports) {
      const url = (item.bookSourceUrl || '').trim();
      if (!url) {
        continue;
      }
      const report = new BookSourceCheckReport();
      report.bookSourceUrl = url;
      report.status = Number(item.status) || 0;
      report.message = (item.message || '').trim();
      report.checkedAt = Number(item.checkedAt) || 0;
      byUrl.set(url, report);
    }
    const list = Array.from(byUrl.values());
    if (list.length <= BookSourceCheckReportStore.MAX_REPORTS) {
      return list;
    }
    list.sort((a: BookSourceCheckReport, b: BookSourceCheckReport) => b.checkedAt - a.checkedAt);
    return list.slice(0, BookSourceCheckReportStore.MAX_REPORTS);
  }

  private static decode(raw: string): BookSourceCheckReport[] {
    if (!raw) {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as BookSourceCheckReport[];
      return Array.isArray(parsed) ? BookSourceCheckReportStore.normalize(parsed) : [];
    } catch (e) {
      return [];
    }
  }

  private static clone(item: BookSourceCheckReport): BookSourceCheckReport {
    const report = new BookSourceCheckReport();
    report.bookSourceUrl = item.bookSourceUrl;
    report.status = item.status;
    report.message = item.message;
    report.checkedAt = item.checkedAt;
    return report;
  }

  private static cloneAll(items: BookSourceCheckReport[]): BookSourceCheckReport[] {
    return items.map((item: BookSourceCheckReport) => BookSourceCheckReportStore.clone(item));
  }
}
