import { Context } from '@kit.AbilityKit';
import preferences from '@ohos.data.preferences';

/**
 * 换源面板选项（持久化）。
 */
export class ChangeSourceOptionsStore {
  private static readonly STORE_NAME: string = 'change_source_options';
  private static readonly KEY_LOAD_WORD_COUNT: string = 'changeSourceLoadWordCount';

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
}
