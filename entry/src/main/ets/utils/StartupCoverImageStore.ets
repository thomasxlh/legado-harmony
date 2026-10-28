import { Context } from '@kit.AbilityKit';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import { ThemeAssetSyncService } from './ThemeAssetSyncService';

export class StartupCoverImageStore {
  static readonly STARTUP_DIR: string = 'theme_startups';
  static readonly MAIN_BACKGROUND_DIR: string = 'main_backgrounds';

  static async pickAndSave(context: Context, schemeId: string, darkMode: boolean): Promise<string> {
    const safeId = (schemeId || 'custom').replace(/[^a-zA-Z0-9_-]/g, '_');
    const mode = darkMode ? 'dark' : 'light';
    return StartupCoverImageStore.pickInto(
      context, StartupCoverImageStore.STARTUP_DIR, `${safeId}_${mode}`);
  }

  static async pickAndSaveMainBackground(
    context: Context,
    schemeId: string,
    darkMode: boolean
  ): Promise<string> {
    const safeId = (schemeId || 'custom').replace(/[^a-zA-Z0-9_-]/g, '_');
    const mode = darkMode ? 'dark' : 'light';
    return StartupCoverImageStore.pickInto(
      context, StartupCoverImageStore.MAIN_BACKGROUND_DIR, `${safeId}_${mode}`);
  }

  static async pickInto(context: Context, dirName: string, tag: string): Promise<string> {
    const options: picker.PhotoSelectOptions = new picker.PhotoSelectOptions();
    options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    const result = await new picker.PhotoViewPicker(context).select(options);
    if (!result || result.photoUris.length === 0) return '';
    const source = result.photoUris[0];
    const dir = `${context.filesDir}/${dirName}`;
    try {
      await fs.mkdir(dir, true);
    } catch (_) {
    }
    const safeTag = (tag || 'custom').replace(/[^a-zA-Z0-9_-]/g, '_');
    const path = `${dir}/${safeTag}_${Date.now()}${StartupCoverImageStore.extension(source)}`;
    const copySource = source.startsWith('/') ? fileUri.getUriFromPath(source) : source;
    await fs.copy(copySource, fileUri.getUriFromPath(path));
    ThemeAssetSyncService.reconcileNow().catch((): void => {
    });
    return fileUri.getUriFromPath(path);
  }

  // 把另一档已设置的图复制成当前档的新文件（各自独立，互不影响清除），并返回新文件的
  // file:// URI。用于「用浅色图作深色默认 / 反之」这类一键套用，避免两档共享同一文件。
  static async copyExisting(
    context: Context,
    sourceUri: string,
    dirName: string,
    tag: string
  ): Promise<string> {
    if (!sourceUri) return '';
    const source = sourceUri.startsWith('file://') ?
      decodeURIComponent(sourceUri.substring(7)) : sourceUri;
    if (!fs.accessSync(source)) return '';
    const dir = `${context.filesDir}/${dirName}`;
    try {
      await fs.mkdir(dir, true);
    } catch (_) {
    }
    const safeTag = (tag || 'custom').replace(/[^a-zA-Z0-9_-]/g, '_');
    const path = `${dir}/${safeTag}_${Date.now()}${StartupCoverImageStore.extension(source)}`;
    fs.copyFile(source, path);
    ThemeAssetSyncService.reconcileNow().catch((): void => {
    });
    return fileUri.getUriFromPath(path);
  }

  static remove(context: Context, uri: string, dirName: string = StartupCoverImageStore.STARTUP_DIR): void {
    if (!uri) return;
    try {
      const path = uri.startsWith('file://') ? decodeURIComponent(uri.substring(7)) : uri;
      if (path.startsWith(`${context.filesDir}/${dirName}/`) && fs.accessSync(path)) {
        fs.unlinkSync(path);
      }
    } catch (e) {
      console.warn('删除自定义图片失败:', e);
    }
  }

  private static extension(value: string): string {
    const lower = (value || '').toLowerCase();
    if (lower.includes('.png')) return '.png';
    if (lower.includes('.webp')) return '.webp';
    if (lower.includes('.bmp')) return '.bmp';
    if (lower.includes('.gif')) return '.gif';
    return '.jpg';
  }
}
