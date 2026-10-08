import { Context } from '@kit.AbilityKit';
import preferences from '@ohos.data.preferences';

/**
 * 换源面板选项（持久化）。
 */
export class ChangeSourceOptionsStore {
  private static readonly STORE_NAME: string = 'change_source_options';
  private static readonly KEY_LOAD_WORD_COUNT: string = 'changeSourceLoadWordCount';
  /** 置顶书源 URL 列表（换源时优先搜索）。 */
  private static readonly KEY_PINNED_SOURCE_URLS: string = 'changeSourcePinnedSourceUrls';

  /** 是否在换源列表中实测最新章节字数（默认关闭，测量需逐源拉取正文，较慢）。 */
  static async getLoadWordCount(context: Context): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, ChangeSourceOptionsStore.STORE_NAME);
      const value = await store.get(ChangeSourceOptionsStore.KEY_LOAD_WORD_COUNT, false);
      return value === true;
    } catch (_) {
      return false;
    }
  }

  static async setLoadWordCount(context: Context, value: boolean): Promise<void> {
    const store = await preferences.getPreferences(context, ChangeSourceOptionsStore.STORE_NAME);
    await store.put(ChangeSourceOptionsStore.KEY_LOAD_WORD_COUNT, value === true);
    await store.flush();
  }

  /** 获取置顶书源 URL 列表（按置顶顺序）。 */
  static async getPinnedSourceUrls(context: Context): Promise<string[]> {
    try {
      const store = await preferences.getPreferences(context, ChangeSourceOptionsStore.STORE_NAME);
      const raw = await store.get(ChangeSourceOptionsStore.KEY_PINNED_SOURCE_URLS, '') as string;
      if (!raw || typeof raw !== 'string') return [];
      return raw.split('\n').map((item: string) => item.trim()).filter((item: string) => !!item);
    } catch (_) {
      return [];
    }
  }

  static async setPinnedSourceUrls(context: Context, urls: string[]): Promise<void> {
    const unique: string[] = [];
    const seen = new Set<string>();
    for (const raw of urls || []) {
      const url = (raw || '').trim();
      if (url && !seen.has(url)) {
        seen.add(url);
        unique.push(url);
      }
    }
    const store = await preferences.getPreferences(context, ChangeSourceOptionsStore.STORE_NAME);
    await store.put(ChangeSourceOptionsStore.KEY_PINNED_SOURCE_URLS, unique.join('\n'));
    await store.flush();
  }

  static async togglePinnedSource(context: Context, sourceUrl: string): Promise<string[]> {
    const pinned = await ChangeSourceOptionsStore.getPinnedSourceUrls(context);
    const trimmed = (sourceUrl || '').trim();
    if (!trimmed) return pinned;
    const index = pinned.indexOf(trimmed);
    if (index >= 0) {
      pinned.splice(index, 1);
    } else {
      pinned.unshift(trimmed);
    }
    await ChangeSourceOptionsStore.setPinnedSourceUrls(context, pinned);
    ChangeSourceOptionsStore.syncPinnedToStorage(pinned);
    return pinned;
  }

  /** 把 pinned 列表同步到 AppStorage，SearchCoordinator 从这里读以优先搜索。 */
  static syncPinnedToStorage(urls: string[]): void {
    AppStorage.setOrCreate('changeSourcePinnedSourceUrls', (urls || []).join('\n'));
  }

  /** 从 AppStorage 或 preferences 读取 pinned 列表。 */
  static getPinnedFromStorage(): string[] {
    const raw = AppStorage.get<string>('changeSourcePinnedSourceUrls') || '';
    return raw.split('\n').map((item: string) => item.trim()).filter((item: string) => !!item);
  }
}
