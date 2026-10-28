import { Context } from '@kit.AbilityKit';
import preferences from '@ohos.data.preferences';

export class BookSourceSubscription {
  url: string = '';
  lastSyncTime: number = 0;
  lastSyncCount: number = 0;
  lastSyncError: string = '';
  constructor(url: string = '') {
    this.url = url;
  }
}

interface SubscriptionRawItem {
  url: string;
  lastSyncTime: number;
  lastSyncCount: number;
  lastSyncError: string;
}

/**
 * 书源订阅列表：记录通过 URL 导入过的书源地址，供订阅源管理界面一键更新同步。
 * 存储形态与 ReaderReplaceRuleStore 一致（preferences + JSON 数组）。
 */
export class BookSourceSubscriptionStore {
  private static readonly STORE_NAME: string = 'book_source_subscriptions';
  private static readonly KEY: string = 'subscriptionsV1';
  private static cached: BookSourceSubscription[] | null = null;

  static invalidateCache(): void {
    BookSourceSubscriptionStore.cached = null;
  }

  static isValidUrl(url: string): boolean {
    return /^https?:\/\//i.test((url || '').trim());
  }

  /**
   * 订阅去重键：忽略协议（http/_https_）、host 大小写与默认端口、尾斜杠，
   * 其余路径与查询参数保留原样参与比较。
   */
  static normalizeKey(url: string): string {
    const trimmed = (url || '').trim();
    const match = trimmed.match(/^https?:\/\/([^/?#]+)([^#]*)/i);
    if (!match) {
      return trimmed.toLowerCase();
    }
    const host = match[1].toLowerCase().replace(/:(80|443)$/, '');
    let path = match[2] || '';
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return `//${host}${path}`;
  }

  static async load(context: Context, force: boolean = false): Promise<BookSourceSubscription[]> {
    if (!force && BookSourceSubscriptionStore.cached) {
      return BookSourceSubscriptionStore.clone(BookSourceSubscriptionStore.cached);
    }
    const store = await preferences.getPreferences(context, BookSourceSubscriptionStore.STORE_NAME);
    const value = await store.get(BookSourceSubscriptionStore.KEY, '');
    const raw = typeof value === 'string' ? value : '';
    const subs = BookSourceSubscriptionStore.decode(raw);
    BookSourceSubscriptionStore.cached = BookSourceSubscriptionStore.clone(subs);
    return subs;
  }

  static async save(context: Context, subs: BookSourceSubscription[]): Promise<void> {
    BookSourceSubscriptionStore.cached = BookSourceSubscriptionStore.clone(subs);
    const store = await preferences.getPreferences(context, BookSourceSubscriptionStore.STORE_NAME);
    await store.put(BookSourceSubscriptionStore.KEY, JSON.stringify(subs));
    await store.flush();
  }

  private static decode(raw: string): BookSourceSubscription[] {
    if (!raw) return [];
    try {
      const items = JSON.parse(raw) as SubscriptionRawItem[];
      if (!Array.isArray(items)) return [];
      const subs: BookSourceSubscription[] = [];
      for (const item of items) {
        if (!item || typeof item.url !== 'string' || !item.url) continue;
        const sub = new BookSourceSubscription(item.url);
        sub.lastSyncTime = Number(item.lastSyncTime || 0);
        if (!Number.isFinite(sub.lastSyncTime)) sub.lastSyncTime = 0;
        sub.lastSyncCount = Number(item.lastSyncCount || 0);
        if (!Number.isFinite(sub.lastSyncCount)) sub.lastSyncCount = 0;
        sub.lastSyncError = typeof item.lastSyncError === 'string' ? item.lastSyncError : '';
        subs.push(sub);
      }
      return subs;
    } catch (_) {
      return [];
    }
  }

  private static clone(subs: BookSourceSubscription[]): BookSourceSubscription[] {
    return subs.map((sub: BookSourceSubscription) => {
      const copy = new BookSourceSubscription(sub.url);
      copy.lastSyncTime = sub.lastSyncTime;
      copy.lastSyncCount = sub.lastSyncCount;
      copy.lastSyncError = sub.lastSyncError;
      return copy;
    });
  }
}
