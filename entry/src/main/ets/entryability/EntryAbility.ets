import { AbilityConstant, UIAbility, Want, Configuration, ConfigurationConstant } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { RecentReadShortcut, RECENT_READ_SHORTCUT_ACTION, OPEN_BOOK_SHORTCUT_ACTION } from '../utils/RecentReadShortcut';
import { CoverGalleryStore } from '../utils/CoverGalleryStore';
import { BookshelfDisplaySettingsStore } from '../utils/BookshelfDisplaySettingsStore';
import { SearchExploreSettingsStore } from '../utils/SearchExploreSettingsStore';
import { ReaderSettingsStore } from '../utils/ReaderSettingsStore';
import { AppThemeSettingsStore } from '../utils/AppThemeSettingsStore';
import { GlassSettingsStore } from '../utils/GlassSettingsStore';
import { AppThemeModeStore } from '../utils/AppThemeModeStore';
import { CustomThemeSchemeStore } from '../utils/CustomThemeSchemeStore';
import { ReaderFontBootstrap } from '../utils/ReaderFontBootstrap';
import { ReaderSystemFontHelper } from '../utils/ReaderSystemFontHelper';
import { TtsSettingsStore } from '../utils/TtsSettingsStore';
import { ReaderProgressCheckpoint } from '../utils/ReaderProgressCheckpoint';
import { CloudSyncService } from '../utils/CloudSyncService';
import { PreferenceCloudSyncService } from '../utils/PreferenceCloudSyncService';
import { ThemeAssetSyncService } from '../utils/ThemeAssetSyncService';
import { ThemeRuntime } from '../theme/ThemeRuntime';
import { ThemeIds } from '../theme/ThemeModels';
import { QuickJsDiagnostics } from '../core/script/QuickJsDiagnostics';
import { TlsTrustStore } from '../core/http/TlsTrustStore';
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';
import { FullTextCacheCancelCoordinator } from '../utils/FullTextCacheCancelCoordinator';
import { lanReaderServer } from '../core/lan/LanReaderServer';

export default class EntryAbility extends UIAbility {
  private appliedColorMode: number = -1;
  private modeDependentThemeKey: string = '';
  private themeBootstrapPromise: Promise<void> = Promise.resolve();
  private readerBootstrapPromise: Promise<void> = Promise.resolve();
  private deferredStartupScheduled: boolean = false;
  private mainWindowStage: window.WindowStage | null = null;
  private assetRestoreReapplyTimer: number = -1;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    AppStorage.setOrCreate('startupT0', Date.now());
    AppStorage.setOrCreate('appCacheDir', this.context.cacheDir);
    AppStorage.setOrCreate('appFilesDir', this.context.filesDir);
    AppStorage.setOrCreate('pendingBookSourceImportUri', '');
    AppStorage.setOrCreate('pendingBookSourceImportUrl', '');
    AppStorage.setOrCreate('pendingBookSourceImportNonce', 0);
    AppStorage.setOrCreate('bookSourceCheckOpenNonce', 0);
    AppStorage.setOrCreate('shelfUpdateTime', 0);
    AppStorage.setOrCreate('pendingLocalBookImportUri', '');
    AppStorage.setOrCreate('pendingLocalBookImportNonce', 0);
    AppStorage.setOrCreate('pendingLocalBookImportFormat', '');
    AppStorage.setOrCreate('pendingLocalBookImportName', '');
    AppStorage.setOrCreate('globalTtsCapsulePositionX', 16);
    AppStorage.setOrCreate('globalTtsCapsulePositionY', -1);
    AppStorage.setOrCreate('globalTtsTextBefore', '');
    AppStorage.setOrCreate('globalTtsCurrentText', '');
    AppStorage.setOrCreate('globalTtsTextAfter', '');
    TlsTrustStore.load(this.context).catch((e: Error) => {
      hilog.warn(0x0000, 'testTag', 'Load TLS trust settings failed: %{public}s', JSON.stringify(e));
    });
    hilog.info(0x0000, 'testTag', 'StartupTrace onCreate %{public}d', Date.now());
    PersistentStorage.persistProp('appThemeMode', 'system');
    AppThemeModeStore.load(this.context).then((mode: string) => {
      AppThemeModeStore.applyToStorage(mode);
      this.applyThemeColorMode(mode, this.context.config);
    }).catch((e: Error) => {
      hilog.warn(0x0000, 'testTag', 'Sync app theme mode failed: %{public}s', JSON.stringify(e));
      this.syncSystemColorMode(this.context.config);
    });
    AppStorage.setOrCreate('readerSystemFontFamily', ReaderSystemFontHelper.FALLBACK_SYSTEM_FONT_FAMILY);
    AppStorage.setOrCreate('readerActiveFontFamily', '');
    AppStorage.setOrCreate('readerFontRegistered', false);
    PersistentStorage.persistProp('readerPageTurnMode', 1);
    PersistentStorage.persistProp('readerPreloadEnabled', true);
    PersistentStorage.persistProp('readerPreloadChapterCount', 1);
    PersistentStorage.persistProp('readerUseTtsQuickAction', true);
    PersistentStorage.persistProp('readerUseChapterQuickJump', true);
    PersistentStorage.persistProp('fullTextCacheCancelNonce', 0);
    PersistentStorage.persistProp('fullTextCacheCancelSignal', '');
    PersistentStorage.persistProp('readerBodyFontMode', 'global');
    PersistentStorage.persistProp('readerBodyFontFamily', '');
    PersistentStorage.persistProp('readerTitleFontMode', 'global');
    PersistentStorage.persistProp('readerTitleFontFamily', '');
    PersistentStorage.persistProp('readerTitleFontSize', 22);
    PersistentStorage.persistProp('readerRegexFontEnabled', false);
    PersistentStorage.persistProp('readerRegexFontPattern', '');
    PersistentStorage.persistProp('readerRegexFontMode', 'global');
    PersistentStorage.persistProp('readerRegexFontFamily', '');
    PersistentStorage.persistProp('readerRegexFontSize', 20);
    PersistentStorage.persistProp('readerRegexShadowColor', '');
    PersistentStorage.persistProp('readerRegexFontRulesRaw', '');
    PersistentStorage.persistProp('lanReaderEnabled', false);
    PersistentStorage.persistProp('lanReaderPassword', '');
    AppStorage.setOrCreate('lanReaderAddress', '');
    AppStorage.setOrCreate('lanReaderStatus', '已关闭');
    AppStorage.setOrCreate('lanReaderToken', '');
    AppStorage.setOrCreate('lanReaderBackgroundStatus', '未启动');
    if (AppStorage.get<number>('statusBarHeight') === undefined) {
      AppStorage.setOrCreate('statusBarHeight', 32);
    }
    if (AppStorage.get<number>('navBarHeight') === undefined) {
      AppStorage.setOrCreate('navBarHeight', 0);
    }
    PersistentStorage.persistProp('bookshelfSortMode', 'recentRead');
    PersistentStorage.persistProp('ttsPerson', 0);
    PersistentStorage.persistProp('ttsOnline', 1);
    PersistentStorage.persistProp('ttsStyle', '');
    PersistentStorage.persistProp('ttsLanguage', 'zh-CN');
    PersistentStorage.persistProp('ttsSpeed', 1);
    PersistentStorage.persistProp('ttsInstalledVoiceKeys', '');
    PersistentStorage.persistProp('ttsCustomVoiceId', '');
    PersistentStorage.persistProp('ttsCustomVoices', '');
    PersistentStorage.persistProp('ttsOfflineSdkModeMigrated', false);
    if (!AppStorage.get<boolean>('ttsOfflineSdkModeMigrated')) {
      if (AppStorage.get<number>('ttsOnline') === 0 &&
        (AppStorage.get<number>('ttsPerson') ?? 0) === 0 &&
        !(AppStorage.get<string>('ttsStyle') || '') &&
        ((AppStorage.get<string>('ttsLanguage') || 'zh-CN') === 'zh-CN')) {
        AppStorage.setOrCreate('ttsOnline', 1);
      }
      AppStorage.setOrCreate('ttsOfflineSdkModeMigrated', true);
    }
    PersistentStorage.persistProp('readerPageTurnAnimation', true);
    PersistentStorage.persistProp('readerPageTurnAnimationType', 1);
    PersistentStorage.persistProp('readerVolumeTurnPage', false);
    PersistentStorage.persistProp('readerKeepScreenOn', false);
    PersistentStorage.persistProp('readerExtendToStatusBar', false);
    PersistentStorage.persistProp('readerLastPageViewWidth', 0);
    PersistentStorage.persistProp('readerLastPageViewHeight', 0);
    PersistentStorage.persistProp('bookshelfShowTags', true);
    PersistentStorage.persistProp('bookshelfShowSource', true);
    PersistentStorage.persistProp('bookshelfShowIntro', true);
    PersistentStorage.persistProp('bookshelfShowFullIntro', false);
    PersistentStorage.persistProp('bookshelfShowProgressBar', true);
    PersistentStorage.persistProp('bookshelfShowLastReadTime', true);
    PersistentStorage.persistProp('bookshelfShowLastReadChapter', true);
    PersistentStorage.persistProp('bookshelfLayoutMode', 'compact');
    PersistentStorage.persistProp('bookshelfLastReadLeafMode', 'adaptive');
    PersistentStorage.persistProp('bookshelfBookOpenAnimation', true);
    PersistentStorage.persistProp('bookshelfCoverAlbums', '');
    PersistentStorage.persistProp('bookshelfLightCoverAlbumId', '');
    PersistentStorage.persistProp('bookshelfDarkCoverAlbumId', '');
    PersistentStorage.persistProp('bookshelfCoverApplyScope', 'all');
    PersistentStorage.persistProp('bookshelfCoverTargetBooks', '');
    PersistentStorage.persistProp('bookshelfIgnoreSourceCover', false);
    PersistentStorage.persistProp('bookshelfCoverMode', 'sequence');
    PersistentStorage.persistProp('searchExploreShowResultCover', true);
    PersistentStorage.persistProp('searchExploreUseBookshelfCoverGallery', false);
    PersistentStorage.persistProp('searchExploreShowResultTags', true);
    PersistentStorage.persistProp('searchExploreAggregateResults', true);
    PersistentStorage.persistProp('searchExplorePromptAddToShelfOnBack', true);
    PersistentStorage.persistProp('searchExploreExactSearch', false);
    PersistentStorage.persistProp('searchExploreExactSearchMatchAuthor', true);
    PersistentStorage.persistProp('searchExploreShowSearchProgress', true);
    PersistentStorage.persistProp('searchExploreSearchConcurrency', 100);
    PersistentStorage.persistProp('searchExploreSelectedSourceGroups', '');
    PersistentStorage.persistProp('searchExploreSourceSort', '');
    PersistentStorage.persistProp('bookSourceOrderRevision', 0);
    PersistentStorage.persistProp('appLightAccentColor', '#007DFF');
    PersistentStorage.persistProp('appDarkAccentColor', '#4E9BFF');
    PersistentStorage.persistProp('appLightButtonColor', '#007DFF');
    PersistentStorage.persistProp('appDarkButtonColor', '#3F8CFF');
    // Immersive light strength: adaptive follows the system by default.
    PersistentStorage.persistProp('immersiveLightLevel', 'adaptive');
    // 底部 Tab 选中色：留空表示跟随主题强调色，浅色与深色模式各存一份。
    PersistentStorage.persistProp('appTabBarLightColor', '');
    PersistentStorage.persistProp('appTabBarDarkColor', '');
    // 底部 Tab 未选中色：留空表示跟随主题次级文字色，浅色与深色模式各存一份。
    PersistentStorage.persistProp('appTabBarUnselectedLightColor', '');
    PersistentStorage.persistProp('appTabBarUnselectedDarkColor', '');
    PersistentStorage.persistProp('explorePlatform', '');
    PersistentStorage.persistProp('exploreSourceUrl', '');
    CoverGalleryStore.load(this.context).then((snapshot) => {
      CoverGalleryStore.applyToStorage(snapshot);
      return CoverGalleryStore.save(this.context, snapshot);
    }).catch((e: Error) => {
      hilog.warn(0x0000, 'testTag', 'Sync cover gallery settings failed: %{public}s', JSON.stringify(e));
    });
    BookshelfDisplaySettingsStore.load(this.context).then((settings) => {
      BookshelfDisplaySettingsStore.applyToStorage(settings);
    }).catch((e: Error) => {
      hilog.warn(0x0000, 'testTag', 'Sync bookshelf display settings failed: %{public}s', JSON.stringify(e));
    });
    SearchExploreSettingsStore.load(this.context).then((settings) => {
      SearchExploreSettingsStore.applyToStorage(settings);
    }).catch((e: Error) => {
      hilog.warn(0x0000, 'testTag', 'Sync search explore settings failed: %{public}s', JSON.stringify(e));
    });
    TtsSettingsStore.load(this.context).then((settings) => {
      TtsSettingsStore.applyToStorage(settings);
    }).catch((e: Error) => {
      hilog.warn(0x0000, 'testTag', 'Sync tts settings failed: %{public}s', JSON.stringify(e));
    });
    const appThemePromise = AppThemeSettingsStore.load(this.context).then((settings) => {
      AppThemeSettingsStore.applyToStorage(settings);
    }).catch((e: Error) => {
      hilog.warn(0x0000, 'testTag', 'Sync app theme settings failed: %{public}s', JSON.stringify(e));
    });
    const glassPromise = GlassSettingsStore.load(this.context).then((settings) => {
      GlassSettingsStore.applyToStorage(settings);
    }).catch((e: Error) => {
      hilog.warn(0x0000, 'testTag', 'Sync glass settings failed: %{public}s', JSON.stringify(e));
    });
    // Theme and glass affect the first frame, but they are independent and can be restored in parallel.
    // 主界面背景属于自定义主题方案，随主题设置一起恢复。
    this.themeBootstrapPromise = Promise.all([appThemePromise, glassPromise]).then(() => {});
    // Reader preferences and custom font registration are not needed to paint Index/Startup. Keep their I/O warm,
    // but do not make the first application content wait for them.
    this.readerBootstrapPromise = ReaderSettingsStore.load(this.context).then((settings) => {
      ReaderSettingsStore.applyToStorage(settings);
      if (AppStorage.get<boolean>('lanReaderEnabled')) {
        return lanReaderServer.start(this.context);
      }
      return Promise.resolve();
    }).catch((e: Error) => {
      hilog.warn(0x0000, 'testTag', 'Sync reader settings failed: %{public}s', JSON.stringify(e));
    });
    // 云端偏好下行应用后重放到运行中的界面：applyRemote 只写回 Preferences，
    // 当前主题/深色模式等 AppStorage 镜像要靠这里重新装载，否则恢复要等下次启动。
    PreferenceCloudSyncService.setStoreRestoredListener((storeName: string) => {
      this.applyRestoredPreferenceStore(storeName);
    });
    // 阅读偏好/主题设置的端云同步桥：注册各偏好 store 的变更监听与云同步
    // 会话回调。attach 幂等，失败只影响偏好上云，不影响主流程。
    PreferenceCloudSyncService.attach(this.context).catch((e: Error) => {
      hilog.warn(0x0000, 'testTag', 'Attach preference cloud sync failed: %{public}s', e.message);
    });
    // 主题/背景图片的端云同步桥：注册会话回调并安排启动对账（镜像入库/下行落盘）。
    // attach 幂等，失败只影响图片上云，不影响主流程。
    ThemeAssetSyncService.attach(this.context);
    // 资产下行落盘后重绑当前方案的图片路径：图片文件可能晚于方案行到达，
    // Image 不会因文件后来出现而自动重试，需要清空路径键后重新应用一次。
    ThemeAssetSyncService.setOnAssetsRestored((): void => {
      this.scheduleCustomSchemeImageReapplyAfterAssetRestore();
    });
    this.handleLaunchWant(want);
  }

  onDestroy(): void {
    lanReaderServer.stop().catch(() => undefined);
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.mainWindowStage = windowStage;
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    hilog.info(0x0000, 'testTag', 'StartupTrace onWindowStageCreate %{public}d', Date.now());

    this.themeBootstrapPromise.finally(() => {
      this.loadStartupContent(windowStage);
    });
  }

  private loadStartupContent(windowStage: window.WindowStage): void {
    const darkMode = AppStorage.get<boolean>('appDarkMode') || false;
    const activeThemeId = AppStorage.get<string>(AppThemeSettingsStore.KEY_THEME_ID) ||
      AppThemeSettingsStore.DEFAULT_THEME_ID;
    const customStartupImage = activeThemeId === ThemeIds.CUSTOM ?
      (AppStorage.get<string>(darkMode ?
        AppThemeSettingsStore.KEY_CUSTOM_DARK_STARTUP_IMAGE_PATH :
        AppThemeSettingsStore.KEY_CUSTOM_LIGHT_STARTUP_IMAGE_PATH) || '') : '';
    const customStartupText = activeThemeId === ThemeIds.CUSTOM ?
      ((AppStorage.get<string>(darkMode ?
        AppThemeSettingsStore.KEY_CUSTOM_DARK_STARTUP_TITLE :
        AppThemeSettingsStore.KEY_CUSTOM_LIGHT_STARTUP_TITLE) || '') +
      (AppStorage.get<string>(darkMode ?
        AppThemeSettingsStore.KEY_CUSTOM_DARK_STARTUP_SUBTITLE :
        AppThemeSettingsStore.KEY_CUSTOM_LIGHT_STARTUP_SUBTITLE) || '')) : '';
    // 启动窗口图标已改为全透明图片，这里只决定是否需要业务启动页：没有封面
    // 也没有文案时直接加载首页，避免多一次无意义的页面切换。
    const usesSystemStartup = ThemeRuntime.startupThemeId(darkMode) === ThemeIds.PLAIN_DEFAULT &&
      !customStartupImage && !customStartupText.trim();
    const hasPendingImport = !!AppStorage.get<string>('pendingBookSourceImportUri') ||
      !!AppStorage.get<string>('pendingLocalBookImportUri');
    const initialPage = usesSystemStartup && !hasPendingImport ? 'pages/Index' : 'pages/Startup';
    windowStage.loadContent(initialPage, (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(0x0000, 'testTag', 'StartupTrace %{public}s content loaded %{public}d',
        initialPage, Date.now());
      this.syncStartupWindow(windowStage);
      this.scheduleDeferredStartupInitialization();
    });
  }

  private scheduleDeferredStartupInitialization(): void {
    if (this.deferredStartupScheduled) return;
    this.deferredStartupScheduled = true;
    // Let the first frame commit before registering a potentially large custom font file.
    setTimeout(() => {
      QuickJsDiagnostics.initialize(this.context).catch((error: Error) => {
        hilog.warn(0x0000, 'QuickJS', 'Migration initialization failed: %{public}s', error.message);
      });
      this.readerBootstrapPromise
        .then(() => ReaderFontBootstrap.registerFromSettings(
          this.context, null, 'ability-after-first-content'))
        .catch((e: Error) => {
          hilog.warn(0x0000, 'testTag', 'Deferred reader bootstrap failed: %{public}s', JSON.stringify(e));
        });
    }, 80);
  }

  onWindowStageDestroy(): void {
    this.mainWindowStage = null;
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground');
    AppStorage.setOrCreate<number>('appLifecycleForegroundRevision', Date.now());
    if (AppStorage.get<boolean>('lanReaderEnabled') && !lanReaderServer.isRunning()) {
      lanReaderServer.start(this.context).catch((e: Error) => {
        hilog.warn(0x0000, 'testTag', 'Restart LAN reader failed: %{public}s', JSON.stringify(e));
      });
    }
    // 云同步为受控去抖模式：回到前台时择机合并上传本地变更。先跑一轮主题图片
    // 对账（镜像新增图片、应用云端下行），让本轮会话带上这些行变更。
    ThemeAssetSyncService.reconcileNow().finally(() => {
      CloudSyncService.requestAutoSync();
    });
    this.syncSystemColorMode(this.context.config);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'testTag', 'Ability onNewWant %{public}s', JSON.stringify(launchParam));
    const launchTarget = this.handleLaunchWant(want);
    if (launchTarget && this.mainWindowStage) {
      const targetUrl = launchTarget === 'bookSource' ? 'pages/BookSource' :
        (launchTarget === 'audioBook' ? 'pages/AudioBook' : 'pages/Startup');
      this.mainWindowStage.getMainWindow().then((mainWindow: window.Window) => {
        const appRouter = mainWindow.getUIContext().getRouter();
        const state = appRouter.getState();
        if (this.routeMatches(state.name, state.path, targetUrl)) {
          return Promise.resolve();
        }
        if (launchTarget === 'audioBook') {
          return appRouter.pushUrl({
            url: targetUrl,
            params: {
              bookUrl: AppStorage.get<string>('pendingAudioBookUrl') || '',
              audioPanelAction: ''
            }
          });
        }
        return appRouter.pushUrl({ url: targetUrl });
      }).catch((e: Error) => {
        hilog.warn(0x0000, 'testTag', 'Open external file failed: %{public}s', JSON.stringify(e));
      });
    }
  }

  onBackground(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground');
    // Page.onPageShow is shared by real route returns and a simple Home/lock-screen resume. Publish a
    // background revision so retained pages do not treat the foreground transition as a settings change.
    AppStorage.setOrCreate<number>('appLifecycleBackgroundRevision', Date.now());
    ReaderProgressCheckpoint.request('ability-background').catch((e: Error) => {
      hilog.warn(0x0000, 'testTag', 'Background progress checkpoint failed: %{public}s', JSON.stringify(e));
    });
    // 退后台时合并上传一次本地变更：这是本轮最后一次上传机会（听书进度更新不会
    // 实时上云），因此绕过去抖窗口；受去抖丢弃的历史请求由服务内部补传。
    // 先跑一轮主题图片对账，把本轮会话内新增/变更的图片行并入这次上传。
    ThemeAssetSyncService.reconcileNow().finally(() => {
      CloudSyncService.requestAutoSync(true);
    });
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    this.syncSystemColorMode(newConfig);
  }

  private syncSystemColorMode(config: Configuration): void {
    const mode = AppStorage.get<string>('appThemeMode') || 'system';
    this.applyThemeColorMode(mode, config);
  }

  private applyThemeColorMode(mode: string, config: Configuration): void {
    const normalizedMode = AppThemeModeStore.normalizeMode(mode);
    AppStorage.setOrCreate('appThemeMode', normalizedMode);
    if (normalizedMode === 'dark') {
      AppStorage.setOrCreate('appDarkMode', true);
      this.setApplicationColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      this.refreshModeDependentTheme(true);
      return;
    }
    if (normalizedMode === 'light') {
      AppStorage.setOrCreate('appDarkMode', false);
      this.setApplicationColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      this.refreshModeDependentTheme(false);
      return;
    }
    this.setApplicationColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    const darkMode = config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    AppStorage.setOrCreate('appDarkMode', darkMode);
    this.refreshModeDependentTheme(darkMode);
  }

  private refreshModeDependentTheme(darkMode: boolean): void {
    // Foregrounding the ability does not imply that the effective theme changed.
    // Re-publishing an unchanged custom theme increments themeRevision and forces
    // every visible ArkUI form to rebuild, which can reset native text editors.
    const themeKey = `${ThemeRuntime.currentThemeId()}:${darkMode ? 'dark' : 'light'}`;
    if (this.modeDependentThemeKey === themeKey) {
      return;
    }
    this.modeDependentThemeKey = themeKey;
    AppThemeSettingsStore.reapplyCustomForMode(darkMode);
    try {
      this.context.getApplicationContext().setFont(ThemeRuntime.fontFamily());
    } catch (e) {
      hilog.warn(0x0000, 'testTag', 'Apply mode-dependent theme font failed: %{public}s', JSON.stringify(e));
    }
  }

  private setApplicationColorMode(colorMode: number): void {
    if (this.appliedColorMode === colorMode) {
      return;
    }
    this.appliedColorMode = colorMode;
    this.context.getApplicationContext().setColorMode(colorMode);
  }

  /**
   * 云端偏好下行应用完成后，把有 AppStorage 镜像的 store 重新装载并应用到
   * 运行中的界面（当前主题、深色模式、玻璃效果、朗读速度等）。
   * applyRemote 仅在云端行与本机内容确实不同时触发，不会无差别重发主题、
   * 重置正在编辑的表单。无镜像的 store（自定义方案库、净化规则等）缓存已
   * 在 applyRemote 失效，页面下次读取自动取到云端值，无需重放。
   */
  private applyRestoredPreferenceStore(storeName: string): void {
    const context = this.context;
    if (storeName === 'app_theme_mode') {
      AppThemeModeStore.load(context).then((mode: string) => {
        AppThemeModeStore.applyToStorage(mode);
        this.syncSystemColorMode(context.config);
      }).catch((e: Error) => {
        hilog.warn(0x0000, 'testTag', 'Apply restored theme mode failed: %{public}s', e.message);
      });
      return;
    }
    if (storeName === 'app_theme_settings') {
      AppThemeSettingsStore.load(context).then((settings) => {
        AppThemeSettingsStore.applyToStorage(settings);
        // 同步 modeDependentThemeKey，避免下次前台刷新把刚恢复的主题再重发一遍。
        const darkMode = AppStorage.get<boolean>('appDarkMode') || false;
        this.modeDependentThemeKey = `${ThemeRuntime.currentThemeId()}:${darkMode ? 'dark' : 'light'}`;
        try {
          context.getApplicationContext().setFont(ThemeRuntime.fontFamily());
        } catch (e) {
          hilog.warn(0x0000, 'testTag', 'Apply restored theme font failed: %{public}s', JSON.stringify(e));
        }
      }).catch((e: Error) => {
        hilog.warn(0x0000, 'testTag', 'Apply restored theme settings failed: %{public}s', e.message);
      });
      return;
    }
    if (storeName === 'reader_settings') {
      ReaderSettingsStore.load(context).then((settings) => {
        ReaderSettingsStore.applyToStorage(settings);
      }).catch((e: Error) => {
        hilog.warn(0x0000, 'testTag', 'Apply restored reader settings failed: %{public}s', e.message);
      });
      return;
    }
    if (storeName === 'glass_settings') {
      GlassSettingsStore.load(context).then((settings) => {
        GlassSettingsStore.applyToStorage(settings);
      }).catch((e: Error) => {
        hilog.warn(0x0000, 'testTag', 'Apply restored glass settings failed: %{public}s', e.message);
      });
      return;
    }
    if (storeName === 'bookshelf_display_settings') {
      BookshelfDisplaySettingsStore.load(context).then((settings) => {
        BookshelfDisplaySettingsStore.applyToStorage(settings);
      }).catch((e: Error) => {
        hilog.warn(0x0000, 'testTag', 'Apply restored bookshelf display failed: %{public}s', e.message);
      });
      return;
    }
    if (storeName === 'cover_gallery_settings') {
      CoverGalleryStore.load(context).then((snapshot) => {
        CoverGalleryStore.applyToStorage(snapshot);
      }).catch((e: Error) => {
        hilog.warn(0x0000, 'testTag', 'Apply restored cover gallery failed: %{public}s', e.message);
      });
      return;
    }
    if (storeName === 'search_explore_settings') {
      SearchExploreSettingsStore.load(context).then((settings) => {
        SearchExploreSettingsStore.applyToStorage(settings);
      }).catch((e: Error) => {
        hilog.warn(0x0000, 'testTag', 'Apply restored search explore settings failed: %{public}s', e.message);
      });
      return;
    }
    if (storeName === 'tts_settings') {
      TtsSettingsStore.load(context).then((settings) => {
        TtsSettingsStore.applyToStorage(settings);
      }).catch((e: Error) => {
        hilog.warn(0x0000, 'testTag', 'Apply restored tts settings failed: %{public}s', e.message);
      });
      return;
    }
    if (storeName === 'custom_theme_schemes') {
      // 自定义主题方案（含浅色/深色各自的启动封面与主界面背景）是独立同步 store，
      // 单独编辑方案只改它、不碰 app_theme_settings。云端下行后必须把当前启用方案
      // 的图片路径重新写回 AppStorage，否则即使图片资产已同步，封面/背景也不会显示。
      this.applyActiveCustomSchemeToStorage();
      return;
    }
  }

  /** 把当前启用的自定义方案重新应用到运行中的界面（含开机图/主界面背景路径）。 */
  private applyActiveCustomSchemeToStorage(): void {
    const context = this.context;
    AppThemeSettingsStore.load(context).then(async (settings) => {
      const schemes = await CustomThemeSchemeStore.load(context, settings);
      const activeId = AppStorage.get<string>(CustomThemeSchemeStore.STORAGE_ACTIVE_SCHEME_ID) || '';
      const scheme = CustomThemeSchemeStore.find(schemes, activeId);
      if (scheme && settings.themeId === ThemeIds.CUSTOM) {
        let applied = AppThemeSettingsStore.activateTheme(ThemeIds.CUSTOM, settings);
        applied = AppThemeSettingsStore.applyCustomSnapshot(applied, scheme.settings);
        applied.themeApplyLayoutEnabled = false;
        AppThemeSettingsStore.applyToStorage(applied);
      }
    }).catch((e: Error) => {
      hilog.warn(0x0000, 'testTag', 'Apply restored custom theme scheme failed: %{public}s', e.message);
    });
  }

  /**
   * theme_assets 资产下行落盘后调用：方案行的下行应用可能早于图片文件落盘，Image
   * 组件对缺失文件的加载失败不会随文件出现而自动重试。先把四个图片路径键清空一拍，
   * 再重新应用完整主题值，让 Image 以变化的源串重新加载现已存在的图片。
   */
  private scheduleCustomSchemeImageReapplyAfterAssetRestore(): void {
    if (this.assetRestoreReapplyTimer >= 0) {
      return;
    }
    this.assetRestoreReapplyTimer = setTimeout(() => {
      this.assetRestoreReapplyTimer = -1;
      const imageKeys: string[] = [
        AppThemeSettingsStore.KEY_CUSTOM_LIGHT_STARTUP_IMAGE_PATH,
        AppThemeSettingsStore.KEY_CUSTOM_DARK_STARTUP_IMAGE_PATH,
        AppThemeSettingsStore.KEY_CUSTOM_LIGHT_MAIN_BACKGROUND_IMAGE_PATH,
        AppThemeSettingsStore.KEY_CUSTOM_DARK_MAIN_BACKGROUND_IMAGE_PATH
      ];
      for (const key of imageKeys) {
        AppStorage.setOrCreate(key, '');
      }
      setTimeout(() => {
        this.applyActiveCustomSchemeToStorage();
      }, 50);
    }, 50);
  }

  private handleLaunchWant(want: Want): string {
    hilog.info(0x0000, 'testTag',
      'Launch want action=%{public}s type=%{public}s uri=%{private}s params=%{public}s',
      want.action || '', want.type || '', want.uri || '', this.wantParameterKeys(want));
    const externalUri = this.externalFileUri(want);
    const externalName = this.externalFileNameHint(want, externalUri);
    const externalFormat = externalUri ? this.externalFileFormat(want, externalUri, externalName) : '';
    if (externalUri && externalFormat === 'json') {
      AppStorage.setOrCreate('pendingBookSourceImportUri', externalUri);
      const nonce = AppStorage.get<number>('pendingBookSourceImportNonce') || 0;
      AppStorage.setOrCreate('pendingBookSourceImportNonce', nonce + 1);
      return 'bookSource';
    }
    if (externalUri && (externalFormat === 'txt' || externalFormat === 'epub')) {
      AppStorage.setOrCreate('pendingLocalBookImportUri', externalUri);
      AppStorage.setOrCreate('pendingLocalBookImportFormat', externalFormat);
      AppStorage.setOrCreate('pendingLocalBookImportName', externalName);
      const nonce = AppStorage.get<number>('pendingLocalBookImportNonce') || 0;
      AppStorage.setOrCreate('pendingLocalBookImportNonce', nonce + 1);
      return 'localBook';
    }
    const params = this.getLaunchParams(want);
    if (params['bookSourceCheckAction'] === 'open') {
      AppStorage.setOrCreate('bookSourceCheckOpenNonce', Date.now());
      return 'bookSource';
    }
    if (params['audioBookAction'] === 'openPanel' && params['bookUrl']) {
      AppStorage.setOrCreate('pendingAudioBookUrl', params['bookUrl']);
      return 'audioBook';
    }
    if (params['cacheAction'] === 'cancelFullTextCache') {
      FullTextCacheCancelCoordinator.request(params['cacheTaskKey'] || '', params['bookUrl'] || '');
      return '';
    }
    const action = params['shortcutAction'];
    if (action === RECENT_READ_SHORTCUT_ACTION) {
      RecentReadShortcut.request();
      return '';
    }
    if (action === OPEN_BOOK_SHORTCUT_ACTION) {
      const bookUrl = params['bookUrl'];
      if (bookUrl) {
        RecentReadShortcut.requestBook(bookUrl);
      }
    }
    return '';
  }

  private externalFileFormat(want: Want, uri: string, fileNameHint: string): string {
    const uriExtension = this.externalFileExtension(uri);
    const nameExtension = this.externalFileExtension(fileNameHint);
    const extension = this.isSupportedExternalExtension(uriExtension) ? uriExtension : nameExtension;
    if (this.isSupportedExternalExtension(extension)) return extension;
    const type = (want.type || '').toLowerCase();
    if (type === 'application/json' || type === 'text/json' || type === 'application/x-json' ||
      type === 'general.json') return 'json';
    if (type === 'general.epub' || type === 'application/epub+zip' ||
      type === 'application/x-epub+zip') return 'epub';
    const sniffed = this.sniffExternalFileFormat(uri);
    if (sniffed) return sniffed;
    if (type === 'general.plain-text' || type === 'text/plain' || type === 'general.text') return 'txt';
    return '';
  }

  private externalFileUri(want: Want): string {
    const directUri = this.externalFileUriFromValue(want.uri);
    if (directUri) return directUri;
    const parameters = want.parameters;
    if (!parameters) return '';
    const preferredKeys = ['ability.params.stream', 'ohos.extra.param.key.stream', 'uri', 'fileUri', 'shareUri'];
    for (const key of preferredKeys) {
      const preferredUri = this.externalFileUriFromValue(parameters[key]);
      if (preferredUri) return preferredUri;
    }
    for (const key of Object.keys(parameters)) {
      const candidate = this.externalFileUriFromValue(parameters[key]);
      if (candidate) return candidate;
    }
    return '';
  }

  private externalFileUriFromValue(value: Object | undefined): string {
    if (typeof value === 'string') {
      const text = value.trim();
      if (this.isExternalFileUri(text)) return text;
      if ((text.startsWith('[') && text.endsWith(']')) || (text.startsWith('{') && text.endsWith('}'))) {
        try {
          return this.externalFileUriFromValue(JSON.parse(text) as Object);
        } catch (_) {
        }
      }
      return '';
    }
    if (Array.isArray(value)) {
      const items = value as Object[];
      for (let i = 0; i < items.length; i++) {
        const item: Object = items[i];
        const candidate = this.externalFileUriFromValue(item);
        if (candidate) return candidate;
      }
      return '';
    }
    if (value && typeof value === 'object') {
      const record = value as Record<string, Object>;
      for (const key of Object.keys(record)) {
        const candidate = this.externalFileUriFromValue(record[key]);
        if (candidate) return candidate;
      }
    }
    return '';
  }

  private isExternalFileUri(value: string): boolean {
    const lower = value.toLowerCase();
    return lower.startsWith('file://') || lower.startsWith('datashare://') ||
      lower.startsWith('content://') || value.startsWith('/');
  }

  private externalFileNameHint(want: Want, uri: string): string {
    const uriExtension = this.externalFileExtension(uri);
    if (this.isSupportedExternalExtension(uriExtension)) return this.externalFileName(uri);
    const parameters = want.parameters;
    if (!parameters) return '';
    const preferredKeys = ['fileName', 'filename', 'displayName', 'name', 'title',
      'ohos.extra.param.key.contentTitle'];
    for (const key of preferredKeys) {
      const hint = this.externalFileNameFromValue(parameters[key]);
      if (hint) return hint;
    }
    for (const key of Object.keys(parameters)) {
      const hint = this.externalFileNameFromValue(parameters[key]);
      if (hint) return hint;
    }
    return '';
  }

  private externalFileNameFromValue(value: Object | undefined): string {
    if (typeof value === 'string') {
      const text = value.trim();
      return this.isSupportedExternalExtension(this.externalFileExtension(text)) ?
        this.externalFileName(text) : '';
    }
    if (Array.isArray(value)) {
      const items = value as Object[];
      for (let i = 0; i < items.length; i++) {
        const item: Object = items[i];
        const hint = this.externalFileNameFromValue(item);
        if (hint) return hint;
      }
    }
    return '';
  }

  private sniffExternalFileFormat(uri: string): string {
    let file: fs.File | null = null;
    try {
      file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const buffer = new ArrayBuffer(8192);
      const readLength = fs.readSync(file.fd, buffer, { offset: 0, length: buffer.byteLength });
      if (readLength >= 4) {
        const bytes = new Uint8Array(buffer, 0, readLength);
        if (bytes[0] === 0x50 && bytes[1] === 0x4B &&
          ((bytes[2] === 0x03 && bytes[3] === 0x04) || (bytes[2] === 0x05 && bytes[3] === 0x06))) {
          return 'epub';
        }
        const text = util.TextDecoder.create('utf-8').decodeWithStream(bytes, { stream: false })
          .replace(/^\uFEFF/, '').trim();
        if (text.startsWith('{') || text.startsWith('[')) return 'json';
        return 'txt';
      }
    } catch (e) {
      hilog.warn(0x0000, 'testTag', 'Sniff external file failed: %{public}s', JSON.stringify(e));
    } finally {
      if (file) {
        try {
          fs.closeSync(file);
        } catch (_) {
        }
      }
    }
    return '';
  }

  private isSupportedExternalExtension(extension: string): boolean {
    return extension === 'json' || extension === 'txt' || extension === 'epub';
  }

  private externalFileName(uriOrName: string): string {
    const clean = uriOrName.split('?')[0].split('#')[0];
    let decoded = clean;
    try {
      decoded = decodeURIComponent(clean);
    } catch (_) {
    }
    return decoded.substring(Math.max(decoded.lastIndexOf('/'), decoded.lastIndexOf('\\')) + 1);
  }

  private externalFileExtension(uri: string): string {
    const cleanUri = uri.split('?')[0].split('#')[0];
    let decoded = cleanUri;
    try {
      decoded = decodeURIComponent(cleanUri);
    } catch (_) {
    }
    const fileName = decoded.substring(decoded.lastIndexOf('/') + 1).toLowerCase();
    const dot = fileName.lastIndexOf('.');
    return dot >= 0 ? fileName.substring(dot + 1) : '';
  }

  private wantParameterKeys(want: Want): string {
    return want.parameters ? Object.keys(want.parameters).join(',') : '';
  }

  private routeMatches(name: string, path: string, targetUrl: string): boolean {
    const targetName = targetUrl.substring(targetUrl.lastIndexOf('/') + 1);
    return name === targetName || path === targetUrl || path.endsWith(`/${targetName}`);
  }

  private getLaunchParams(want: Want): Record<string, string> {
    const result: Record<string, string> = {};
    const parameters = want.parameters;
    if (!parameters) {
      return result;
    }

    const shortcutAction = parameters['shortcutAction'];
    if (typeof shortcutAction === 'string') {
      result['shortcutAction'] = shortcutAction;
    }
    const bookUrl = parameters['bookUrl'];
    if (typeof bookUrl === 'string') {
      result['bookUrl'] = bookUrl;
    }
    const cacheAction = parameters['cacheAction'];
    if (typeof cacheAction === 'string') {
      result['cacheAction'] = cacheAction;
    }
    const cacheTaskKey = parameters['cacheTaskKey'];
    if (typeof cacheTaskKey === 'string') {
      result['cacheTaskKey'] = cacheTaskKey;
    }
    const bookSourceCheckAction = parameters['bookSourceCheckAction'];
    if (typeof bookSourceCheckAction === 'string') {
      result['bookSourceCheckAction'] = bookSourceCheckAction;
    }
    const audioBookAction = parameters['audioBookAction'];
    if (typeof audioBookAction === 'string') {
      result['audioBookAction'] = audioBookAction;
    }

    const cardParams = parameters['params'];
    if (typeof cardParams === 'string') {
      try {
        const parsed = JSON.parse(cardParams) as Record<string, Object>;
        const parsedAction = parsed['shortcutAction'];
        if (typeof parsedAction === 'string') {
          result['shortcutAction'] = parsedAction;
        }
        const parsedBookUrl = parsed['bookUrl'];
        if (typeof parsedBookUrl === 'string') {
          result['bookUrl'] = parsedBookUrl;
        }
        const parsedCacheAction = parsed['cacheAction'];
        if (typeof parsedCacheAction === 'string') {
          result['cacheAction'] = parsedCacheAction;
        }
        const parsedCacheTaskKey = parsed['cacheTaskKey'];
        if (typeof parsedCacheTaskKey === 'string') {
          result['cacheTaskKey'] = parsedCacheTaskKey;
        }
        const parsedBookSourceCheckAction = parsed['bookSourceCheckAction'];
        if (typeof parsedBookSourceCheckAction === 'string') {
          result['bookSourceCheckAction'] = parsedBookSourceCheckAction;
        }
      } catch (e) {
        hilog.warn(0x0000, 'testTag', 'Parse card params failed: %{public}s', JSON.stringify(e));
      }
    }
    return result;
  }

  private syncStartupWindow(windowStage: window.WindowStage): void {
    setTimeout(() => {
      windowStage.getMainWindow().then((mainWindow) => {
        const darkMode = AppStorage.get<boolean>('appDarkMode') || false;
        const bg = ThemeRuntime.pageColor(darkMode);
        mainWindow.setWindowBackgroundColor(bg);
        mainWindow.setWindowLayoutFullScreen(true);
        mainWindow.setWindowSystemBarEnable(['navigation', 'status']);
        mainWindow.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          isStatusBarLightIcon: darkMode,
          statusBarContentColor: ThemeRuntime.primaryTextColor(darkMode),
          navigationBarColor: bg,
          isNavigationBarLightIcon: darkMode,
          navigationBarContentColor: ThemeRuntime.primaryTextColor(darkMode)
        });
      }).catch((err: Error) => {
        hilog.warn(0x0000, 'testTag', 'Startup window sync failed: %{public}s', JSON.stringify(err));
      });
    }, 0);
  }

}
