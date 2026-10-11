import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppThemeSettings, AppThemeSettingsStore } from '../utils/AppThemeSettingsStore';
import { ReaderSettings, ReaderSettingsStore } from '../utils/ReaderSettingsStore';
import { ReaderThemeHelper } from '../utils/ReaderThemeHelper';
import { syncSystemBars } from '../utils/SystemBars';
import { RecentReadCardUpdater } from '../utils/RecentReadCardUpdater';
import { CustomThemeScheme, CustomThemeSchemeStore } from '../utils/CustomThemeSchemeStore';
import { BuiltinThemeRegistry } from '../theme/BuiltinThemeRegistry';
import { ImmersiveBackButton } from '../components/ImmersiveBackButton';
import { ThemeStartupCover } from '../components/ThemeStartupCover';
import { ReaderThemeBackground } from '../components/ReaderThemeBackground';
import { ThemeAssetRegistry } from '../theme/ThemeAssetRegistry';
import { ThemeIds, ThemePack, ThemeVariant } from '../theme/ThemeModels';
import { ThemeRuntime } from '../theme/ThemeRuntime';
import { AppBackgroundLayer } from '../components/AppBackgroundLayer';
import {
  ReaderRegexBubbleStyleResolver,
  ReaderRegexEmphasisContext,
  ReaderResolvedRegexEmphasis
} from '../model/reader/ReaderRegexFontRule';
import fs from '@ohos.file.fs';
import deviceInfo from '@ohos.deviceInfo';
import { HdsListItem, HdsSwipeActionOptions } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { HdsFeedback } from '../utils/HdsFeedback';

@Entry
@Component
struct ThemeSettingsPage {
  @StorageLink('appDarkMode') appDarkMode: boolean = false;
  @StorageLink('appThemeId') appThemeId: string = AppThemeSettingsStore.DEFAULT_THEME_ID;
  @StorageLink('themeRevision') themeRevision: number = 0;
  @StorageLink('appCustomBaseThemeId') customBaseThemeId: string = AppThemeSettingsStore.DEFAULT_THEME_ID;
  @StorageLink('readerLightThemeIndex') readerLightThemeIndex: number = 0;
  @StorageLink('readerDarkThemeIndex') readerDarkThemeIndex: number = 0;
  @StorageLink('activeCustomThemeSchemeId') activeCustomSchemeId: string = '';
  @StorageLink('activeCustomThemeSchemeRevision') activeCustomSchemeRevision: number = 0;
  @StorageLink('customThemeSchemesRevision') @Watch('onCustomThemeSchemesRevisionChanged')
  customThemeSchemesRevision: number = 0;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @State applyingThemeId: string = '';
  @State customSchemes: CustomThemeScheme[] = [];
  @State showCustomThemeActionMenu: boolean = false;
  @State showRenameCustomThemeDialog: boolean = false;
  @State showDeleteCustomThemeDialog: boolean = false;
  @State actionCustomSchemeId: string = '';
  @State renameCustomThemeName: string = '';
  @State contextMenuX: number = 24;
  @State contextMenuY: number = 120;
  @State contextViewportWidth: number = 360;
  @State contextViewportHeight: number = 720;
  private customSchemeRefreshSerial: number = 0;
  private themeListScroller: ListScroller = new ListScroller();

  aboutToAppear(): void {
    this.loadThemeSettings();
    this.refreshCustomSchemes();
    this.syncBars();
  }

  onPageShow(): void {
    this.refreshCustomSchemes();
    this.syncBars();
  }

  onCustomThemeSchemesRevisionChanged(): void {
    this.refreshCustomSchemes();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      AppBackgroundLayer()
      List({ space: 12, scroller: this.themeListScroller }) {
        // List padding is fixed to the viewport in ArkUI. Use real list items
        // for the safe-area gaps so they scroll away with the content.
        ListItem() {
          Row() {
          }
            .width('100%')
            .height(this.statusBarHeight + 58)
        }
        ListItem() {
          this.sectionTitle('默认主题')
        }
        ListItem() {
          this.themeCard(BuiltinThemeRegistry.findById(ThemeIds.PLAIN_DEFAULT))
        }
        ListItem() {
          this.customThemeSectionTitle()
        }
        ForEach(this.customSchemes, (scheme: CustomThemeScheme) => {
          if (deviceInfo.sdkApiVersion >= 26) {
            HdsListItem({
              customItemBuilder: () => {
                this.themeCard(this.customTheme(scheme), scheme.id)
              },
              swipeActionOptions: this.themeSwipeActions(scheme)
            })
          } else {
            ListItem() {
              this.themeCard(this.customTheme(scheme), scheme.id)
            }
            .swipeAction({
              end: {
                builder: () => {
                  this.customThemeDeleteSwipeAction(scheme)
                },
                actionAreaDistance: 64,
                onAction: () => this.deleteCustomThemeFromSwipe(scheme)
              },
              edgeEffect: SwipeEdgeEffect.Spring
            })
          }
        }, (scheme: CustomThemeScheme) => `${scheme.id}_${scheme.revision}`)
        ListItem() {
          Row() {
          }
            .width('100%')
            .height(Math.max(20, this.navBarHeight + 8))
        }
      }
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .width('100%')
      .height('100%')
      // The list itself must own the system-safe-area expansion. Expanding
      // only its parent leaves the List viewport clipped to the safe area.
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .padding({
        left: 14,
        right: 14
      })
      .scrollBar(BarState.Off)
      .backgroundColor(this.pageColorBehind())

      // Pinned over the edge-to-edge list so scrolled content remains visible
      // beneath the status/title area instead of being clipped by it.
      this.titleBar()

      if (this.showCustomThemeActionMenu) {
        this.customThemeActionMenu()
      }
      if (this.showRenameCustomThemeDialog) {
        this.renameCustomThemeDialog()
      }
      if (this.showDeleteCustomThemeDialog) {
        this.deleteCustomThemeDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageColorBehind())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.updateContextViewport(newValue);
    })
  }

  private themeSwipeActions(scheme: CustomThemeScheme): HdsSwipeActionOptions {
    return { icons: [{
      icon: new SymbolGlyphModifier($r('sys.symbol.trash')),
      backgroundColor: ThemeRuntime.dangerColor(this.appDarkMode),
      iconOptions: { accessibilityText: '删除主题' },
      onAction: () => this.deleteCustomThemeFromSwipe(scheme)
    }] };
  }

  async loadThemeSettings(): Promise<void> {
    try {
      const settings = await AppThemeSettingsStore.load(getContext(this));
      AppThemeSettingsStore.applyToStorage(settings);
      this.appThemeId = settings.themeId;
      const readerSettings = await ReaderSettingsStore.load(getContext(this));
      ReaderSettingsStore.applyToStorage(readerSettings);
    } catch (e) {
      console.warn('加载主题设置失败:', e);
    }
  }

  async refreshCustomSchemes(): Promise<void> {
    const serial = ++this.customSchemeRefreshSerial;
    try {
      const settings = await AppThemeSettingsStore.load(getContext(this));
      const schemes = await CustomThemeSchemeStore.load(getContext(this), settings);
      if (serial === this.customSchemeRefreshSerial) {
        this.customSchemes = schemes;
      }
    } catch (e) {
      console.warn('加载自定义主题方案失败:', e);
    }
  }

  async selectTheme(themeId: string, customSchemeId: string = ''): Promise<void> {
    if (this.applyingThemeId) {
      return;
    }
    const customScheme = themeId === ThemeIds.CUSTOM ?
      CustomThemeSchemeStore.find(this.customSchemes, customSchemeId) : null;
    if (themeId === ThemeIds.CUSTOM && !customScheme) {
      return;
    }
    if (themeId === this.appThemeId && themeId !== ThemeIds.CUSTOM) {
      return;
    }
    this.applyingThemeId = customSchemeId || themeId;
    try {
      const theme = customScheme ? this.customTheme(customScheme) : BuiltinThemeRegistry.findById(themeId);
      const previous: AppThemeSettings = await AppThemeSettingsStore.load(getContext(this));
      let settings: AppThemeSettings = AppThemeSettingsStore.activateTheme(themeId, previous);
      if (customScheme) {
        settings = AppThemeSettingsStore.applyCustomSnapshot(settings, customScheme.settings);
      }
      // 主题不再捆绑排版与封面，切换时保留阅读器当前的排版与书籍封面设置。
      settings.themeApplyLayoutEnabled = false;
      AppThemeSettingsStore.applyToStorage(settings);
      await AppThemeSettingsStore.save(getContext(this), settings);
      if (customScheme) {
        await CustomThemeSchemeStore.setActiveScheme(getContext(this), customScheme);
        this.activeCustomSchemeId = customScheme.id;
        this.activeCustomSchemeRevision = customScheme.revision;
      }
      this.appThemeId = settings.themeId;
      const readerSettings = await ReaderSettingsStore.switchThemeProfile(
        getContext(this), previous.themeId, settings.themeId);
      await ReaderSettingsStore.saveThemeSettings(getContext(this), ReaderThemeHelper.APP_THEME_INDEX,
        ReaderThemeHelper.APP_THEME_INDEX, readerSettings.lightCustomThemeBackgroundColor,
        readerSettings.lightCustomThemeTextColor, readerSettings.darkCustomThemeBackgroundColor,
        readerSettings.darkCustomThemeTextColor, this.appDarkMode, readerSettings.customThemesRaw);
      this.readerLightThemeIndex = ReaderThemeHelper.APP_THEME_INDEX;
      this.readerDarkThemeIndex = ReaderThemeHelper.APP_THEME_INDEX;
      await this.applyThemeFontWhenAvailable();
      this.refreshRecentReadCard();
      this.syncBars();
      HdsFeedback.showToast(`已应用「${theme.name}」主题`);
    } catch (e) {
      console.error('应用主题失败:', e);
      HdsFeedback.showToast('应用主题失败，请稍后重试');
    } finally {
      this.applyingThemeId = '';
    }
  }

  async applyThemeFontWhenAvailable(): Promise<void> {
    const settings: ReaderSettings = await ReaderSettingsStore.load(getContext(this));
    if (settings.fontFilePath && this.fontFileExists(settings.fontFilePath)) {
      return;
    }
    try {
      getContext(this).getApplicationContext().setFont(ThemeRuntime.fontFamily());
    } catch (e) {
      console.warn('应用主题默认字体失败:', e);
    }
  }

  fontFileExists(filePath: string): boolean {
    if (!filePath) {
      return false;
    }
    try {
      return fs.accessSync(filePath);
    } catch (e) {
      return false;
    }
  }

  refreshRecentReadCard(): void {
    const context = getContext(this) as common.UIAbilityContext;
    RecentReadCardUpdater.reload(context).catch((e: Error) => {
      console.warn('主题切换后刷新最近阅读卡片失败:', e);
    });
  }

  customTheme(scheme: CustomThemeScheme): ThemePack {
    const theme = AppThemeSettingsStore.customTheme(scheme.settings, this.appDarkMode);
    theme.name = scheme.name;
    theme.description = '浅色与深色分别设置启动封面与配色';
    return theme;
  }

  activeVariant(theme: ThemePack): ThemeVariant {
    return this.appDarkMode ? theme.dark : theme.light;
  }

  isSelected(theme: ThemePack, customSchemeId: string = ''): boolean {
    if (theme.id === ThemeIds.CUSTOM) {
      const scheme = CustomThemeSchemeStore.find(this.customSchemes, customSchemeId);
      return this.appThemeId === ThemeIds.CUSTOM && this.activeCustomSchemeId === customSchemeId &&
        !!scheme && scheme.revision === this.activeCustomSchemeRevision;
    }
    return theme.id === this.appThemeId;
  }

  pageColor(): string {
    return ThemeRuntime.pageColor(this.appDarkMode);
  }

  // 背景铺到全部页面时，页面底色改为半透明，让底层的主题背景图透出来。
  pageColorBehind(): string {
    return ThemeRuntime.pageColorBehind(this.appDarkMode);
  }

  cardColor(): string {
    return ThemeRuntime.cardColorBehind(this.appDarkMode);
  }

  titleBarSurfaceColor(): string {
    return ThemeRuntime.topBarColor(this.appDarkMode);
  }

  primaryTextColor(): string {
    return ThemeRuntime.primaryTextColor(this.appDarkMode);
  }

  subTextColor(): string {
    return ThemeRuntime.subTextColor(this.appDarkMode);
  }
  /** 删除/错误等危险操作的语义色：跟随主题，浅色/深色分别取值。 */
  dangerColor(): string {
    return ThemeRuntime.dangerColor(this.appDarkMode);
  }

  accentColor(): string {
    return ThemeRuntime.accentColor(this.appDarkMode);
  }

  syncBars(): void {
    syncSystemBars(getContext(this), this.appDarkMode, this.pageColor());
  }

  @Builder
  titleBar() {
    Row() {
      ImmersiveBackButton({ iconColor: this.primaryTextColor(), darkMode: this.appDarkMode,
        buttonSize: 40, containerWidth: 56, materialScale: 0.83, compactLayout: true,
        onBack: () => router.back() })
      Text('主题')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.primaryTextColor())
        .layoutWeight(1)
    }
    .width('100%')
    // The status-bar inset belongs to the pinned title itself, avoiding an
    // additional opaque strip above it while keeping controls out of the
    // system status area.
    .height(56 + this.statusBarHeight)
    .padding({ top: this.statusBarHeight, right: 12 })
    .backgroundColor(this.titleBarSurfaceColor())
    .backdropBlur(ThemeRuntime.topBarBlur())
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor(this.subTextColor())
      .width('100%')
      .padding({ left: 2, top: 6, bottom: 0 })
  }

  @Builder
  customThemeSectionTitle() {
    Row({ space: 10 }) {
      Text(`自定义主题 · ${this.customSchemes.length}/${CustomThemeSchemeStore.MAX_SCHEMES}`)
        .fontSize(13)
        .fontColor(this.subTextColor())
        .layoutWeight(1)
      Button('添加方案')
        .height(30)
        .fontSize(12)
        .fontColor(this.customSchemes.length < CustomThemeSchemeStore.MAX_SCHEMES ?
          '#FFFFFF' : this.subTextColor())
        .backgroundColor(this.customSchemes.length < CustomThemeSchemeStore.MAX_SCHEMES ?
          this.accentColor() : this.cardColor())
        .enabled(this.customSchemes.length < CustomThemeSchemeStore.MAX_SCHEMES)
        .onClick(() => {
          this.addCustomScheme();
        })
    }
    .width('100%')
    .padding({ left: 2, top: 6, bottom: 0 })
    .alignItems(VerticalAlign.Center)
  }

  async addCustomScheme(): Promise<void> {
    try {
      const settings = await AppThemeSettingsStore.load(getContext(this));
      const added = await CustomThemeSchemeStore.add(getContext(this), settings);
      if (!added) {
        HdsFeedback.showToast('最多只能创建 5 套自定义主题');
        return;
      }
      await this.refreshCustomSchemes();
      HdsFeedback.showToast(`已添加「${added.name}」`);
    } catch (e) {
      console.error('添加自定义主题方案失败:', e);
      HdsFeedback.showToast('添加方案失败，请稍后重试');
    }
  }

  @Builder
  customThemeDeleteSwipeAction(scheme: CustomThemeScheme) {
    Column({ space: 4 }) {
      SymbolGlyph($r('sys.symbol.trash'))
        .fontSize(22)
        .fontColor(['#FFFFFF'])
      Text('删除')
        .fontSize(11)
        .fontColor('#FFFFFF')
    }
    .width(64)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(ThemeRuntime.dangerColor(this.appDarkMode))
    .onClick(() => {
      this.deleteCustomThemeFromSwipe(scheme);
    })
  }

  @Builder
  customThemeActionMenu() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.appDarkMode ? '#52000000' : '#26FFFFFF')
        .backdropBlur(ThemeRuntime.glassBlur('popover', 18))
        .onClick(() => this.closeCustomThemeActions())
      Column() {
        this.contextActionItem($r('sys.symbol.square_and_pencil'), '重命名', this.primaryTextColor(), () => {
          const scheme = this.actionCustomScheme();
          if (!scheme) return;
          this.renameCustomThemeName = scheme.name;
          this.showCustomThemeActionMenu = false;
          this.showRenameCustomThemeDialog = true;
        })
        this.contextActionItem($r('sys.symbol.trash'), '删除', this.dangerColor(), () => {
          this.showCustomThemeActionMenu = false;
          this.requestDeleteCustomTheme(this.actionCustomSchemeId);
        })
      }
      .width(148)
      .padding({ top: 6, bottom: 6 })
      .backgroundColor(ThemeRuntime.glassPanelColor(this.appDarkMode, '', 'panel'))
      .borderRadius(ThemeRuntime.glassCornerRadius(14, 'panel'))
      .backdropBlur(ThemeRuntime.glassBlur('panel', 22))
      .border({
        width: ThemeRuntime.glassBorderWidth('panel'),
        color: ThemeRuntime.glassBorderColor(this.appDarkMode, 'panel')
      })
      .shadow({
        radius: ThemeRuntime.glassShadowRadius('panel'),
        color: ThemeRuntime.glassShadowColor(this.appDarkMode, 'panel'),
        offsetX: ThemeRuntime.glassShadowOffsetX('panel'),
        offsetY: ThemeRuntime.glassShadowOffsetY('panel')
      })
      .position({
        x: this.contextMenuLeft(148),
        y: this.contextMenuTop(104)
      })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  contextActionItem(icon: Resource, label: string, color: string, action: () => void) {
    Row({ space: 10 }) {
      SymbolGlyph(icon)
        .fontSize(18)
        .fontColor([color])
        .width(24)
      Text(label)
        .fontSize(15)
        .fontColor(color)
        .layoutWeight(1)
    }
    .width('100%')
    .height(46)
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    .onClick(action)
  }

  @Builder
  renameCustomThemeDialog() {
    Column() {
      Column({ space: 16 }) {
        Text('重命名自定义主题')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
        TextInput({ placeholder: '输入方案名称', text: this.renameCustomThemeName })
          .width('100%')
          .height(42)
          .fontColor(this.primaryTextColor())
          .placeholderColor(this.subTextColor())
          .backgroundColor(ThemeRuntime.inputColor(this.appDarkMode))
          .borderRadius(10)
          .onChange((value: string) => {
            this.renameCustomThemeName = value;
          })
        Row({ space: 12 }) {
          Button('取消', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(42)
            .borderRadius(10)
            .backgroundColor(this.cardColor())
            .fontColor(this.primaryTextColor())
            .onClick(() => this.closeRenameCustomThemeDialog())
          Button('保存', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(42)
            .borderRadius(10)
            .backgroundColor(this.accentColor())
            .fontColor('#FFFFFF')
            .enabled(!!this.renameCustomThemeName.trim())
            .onClick(() => this.renameCustomTheme())
        }
        .width('100%')
      }
      .width('calc(100% - 48vp)')
      .constraintSize({ maxWidth: 360 })
      .padding(20)
      .borderRadius(ThemeRuntime.glassCornerRadius(18, 'panel'))
      .backgroundColor(ThemeRuntime.glassPanelColor(this.appDarkMode, '', 'panel'))
      .backdropBlur(ThemeRuntime.glassBlur('panel', 22))
      .border({
        width: ThemeRuntime.glassBorderWidth('panel'),
        color: ThemeRuntime.glassBorderColor(this.appDarkMode, 'panel')
      })
      .shadow({
        radius: ThemeRuntime.glassShadowRadius('panel'),
        color: ThemeRuntime.glassShadowColor(this.appDarkMode, 'panel'),
        offsetX: ThemeRuntime.glassShadowOffsetX('panel'),
        offsetY: ThemeRuntime.glassShadowOffsetY('panel')
      })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.appDarkMode ? '#76000000' : '#52000000')
    .backdropBlur(ThemeRuntime.glassBlur('popover', 18))
  }

  @Builder
  deleteCustomThemeDialog() {
    Column() {
      Column({ space: 14 }) {
        Text('删除自定义主题')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
        Text(`确定删除「${this.actionCustomScheme()?.name || '该方案'}」吗？此操作无法撤销。`)
          .fontSize(14)
          .fontColor(this.subTextColor())
          .width('100%')
        Row({ space: 12 }) {
          Button('取消', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(42)
            .borderRadius(10)
            .backgroundColor(this.cardColor())
            .fontColor(this.primaryTextColor())
            .onClick(() => this.closeDeleteCustomThemeDialog())
          Button('删除', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(42)
            .borderRadius(10)
            .backgroundColor(this.dangerColor())
            .fontColor('#FFFFFF')
            .onClick(() => this.confirmDeleteCustomTheme())
        }
        .width('100%')
      }
      .width('calc(100% - 48vp)')
      .constraintSize({ maxWidth: 360 })
      .padding(20)
      .borderRadius(ThemeRuntime.glassCornerRadius(18, 'panel'))
      .backgroundColor(ThemeRuntime.glassPanelColor(this.appDarkMode, '', 'panel'))
      .backdropBlur(ThemeRuntime.glassBlur('panel', 22))
      .border({
        width: ThemeRuntime.glassBorderWidth('panel'),
        color: ThemeRuntime.glassBorderColor(this.appDarkMode, 'panel')
      })
      .shadow({
        radius: ThemeRuntime.glassShadowRadius('panel'),
        color: ThemeRuntime.glassShadowColor(this.appDarkMode, 'panel'),
        offsetX: ThemeRuntime.glassShadowOffsetX('panel'),
        offsetY: ThemeRuntime.glassShadowOffsetY('panel')
      })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.appDarkMode ? '#76000000' : '#52000000')
    .backdropBlur(ThemeRuntime.glassBlur('popover', 18))
  }

  openCustomThemeActions(schemeId: string, event?: GestureEvent): void {
    const finger = event && event.fingerList.length > 0 ? event.fingerList[0] : undefined;
    if (finger) {
      this.contextMenuX = finger.globalX;
      this.contextMenuY = finger.globalY;
    }
    this.actionCustomSchemeId = schemeId;
    this.showCustomThemeActionMenu = true;
  }

  closeCustomThemeActions(): void {
    this.showCustomThemeActionMenu = false;
    this.actionCustomSchemeId = '';
  }

  actionCustomScheme(): CustomThemeScheme | null {
    return CustomThemeSchemeStore.find(this.customSchemes, this.actionCustomSchemeId);
  }

  updateContextViewport(area: Area): void {
    const width = Number(area.width);
    const height = Number(area.height);
    if (Number.isFinite(width) && width > 0) this.contextViewportWidth = width;
    if (Number.isFinite(height) && height > 0) this.contextViewportHeight = height;
  }

  contextMenuLeft(menuWidth: number): number {
    return Math.max(12, Math.min(this.contextMenuX - 18, this.contextViewportWidth - menuWidth - 12));
  }

  contextMenuTop(menuHeight: number): number {
    const below = this.contextMenuY + 12;
    if (below + menuHeight <= this.contextViewportHeight - 12) return below;
    return Math.max(this.statusBarHeight + 8, this.contextMenuY - menuHeight - 12);
  }

  closeRenameCustomThemeDialog(): void {
    this.showRenameCustomThemeDialog = false;
    this.renameCustomThemeName = '';
    this.actionCustomSchemeId = '';
  }

  async renameCustomTheme(): Promise<void> {
    const scheme = this.actionCustomScheme();
    const name = this.renameCustomThemeName.trim();
    if (!scheme || !name) return;
    try {
      const settings = await AppThemeSettingsStore.load(getContext(this));
      const renamed = await CustomThemeSchemeStore.rename(getContext(this), settings, scheme.id, name);
      if (!renamed) {
        HdsFeedback.showToast('名称为空、重复或方案不存在');
        return;
      }
      this.closeRenameCustomThemeDialog();
      await this.refreshCustomSchemes();
      HdsFeedback.showToast('自定义主题已重命名');
    } catch (e) {
      console.error('重命名自定义主题失败:', e);
      HdsFeedback.showToast('重命名失败，请稍后重试');
    }
  }

  requestDeleteCustomTheme(schemeId: string): void {
    if (this.customSchemes.length <= 1) {
      this.closeCustomThemeActions();
      HdsFeedback.showToast('至少需要保留一套自定义主题');
      return;
    }
    this.actionCustomSchemeId = schemeId;
    this.showDeleteCustomThemeDialog = true;
  }

  closeDeleteCustomThemeDialog(): void {
    this.showDeleteCustomThemeDialog = false;
    this.actionCustomSchemeId = '';
  }

  async confirmDeleteCustomTheme(): Promise<void> {
    const schemeId = this.actionCustomSchemeId;
    this.showDeleteCustomThemeDialog = false;
    await this.deleteCustomThemeScheme(schemeId);
  }

  async deleteCustomThemeFromSwipe(scheme: CustomThemeScheme): Promise<void> {
    await this.deleteCustomThemeScheme(scheme.id);
  }

  async deleteCustomThemeScheme(schemeId: string): Promise<void> {
    const scheme = CustomThemeSchemeStore.find(this.customSchemes, schemeId);
    if (!scheme) return;
    if (this.customSchemes.length <= 1) {
      this.closeCustomThemeSwipeActions();
      HdsFeedback.showToast('至少需要保留一套自定义主题');
      return;
    }
    try {
      if (this.appThemeId === ThemeIds.CUSTOM && this.activeCustomSchemeId === schemeId) {
        await this.selectTheme(ThemeIds.PLAIN_DEFAULT);
        if (this.appThemeId === ThemeIds.CUSTOM) {
          return;
        }
      }
      const settings = await AppThemeSettingsStore.load(getContext(this));
      const deleted = await CustomThemeSchemeStore.delete(getContext(this), settings, schemeId);
      if (!deleted) {
        HdsFeedback.showToast('删除失败，至少需要保留一套方案');
        return;
      }
      this.actionCustomSchemeId = '';
      await this.refreshCustomSchemes();
      HdsFeedback.showToast(`已删除「${scheme.name}」`);
    } catch (e) {
      console.error('删除自定义主题失败:', e);
      HdsFeedback.showToast('删除失败，请稍后重试');
    }
  }

  closeCustomThemeSwipeActions(): void {
    setTimeout(() => {
      try {
        this.themeListScroller.closeAllSwipeActions();
      } catch (e) {
        console.warn('关闭自定义主题滑动操作失败:', e);
      }
    }, 0);
  }

  @Builder
  themeCard(theme: ThemePack, customSchemeId: string = '') {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Image(ThemeAssetRegistry.themeLogo(theme.id))
          .width(42)
          .height(42)
          .borderRadius(theme.radius.medium)
          .objectFit(ImageFit.Contain)
          .draggable(false)

        Column({ space: 3 }) {
          Text(theme.name)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontFamily(theme.typography.appFontFamily)
            .fontColor(this.activeVariant(theme).colors.primaryTextColor)
          Text(theme.description)
            .fontSize(12)
            .fontColor(this.activeVariant(theme).colors.subTextColor)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.isSelected(theme, customSchemeId)) {
          Text('已启用')
            .fontSize(12)
            .fontColor('#FFFFFF')
            .padding({ left: 9, right: 9, top: 4, bottom: 4 })
            .borderRadius(12)
            .backgroundColor(this.activeVariant(theme).colors.accentColor)
        } else if (this.applyingThemeId === (customSchemeId || theme.id)) {
          Text('应用中')
            .fontSize(12)
            .fontColor(this.activeVariant(theme).colors.accentColor)
        } else if (this.isCustomSchemePending(theme, customSchemeId)) {
          Text('待应用')
            .fontSize(12)
            .fontColor(this.activeVariant(theme).colors.accentColor)
            .padding({ left: 9, right: 9, top: 4, bottom: 4 })
            .borderRadius(12)
            .backgroundColor(this.activeVariant(theme).colors.inputColor)
        }
      }
      .width('100%')

      this.themeVisualPreview(theme, customSchemeId)
      if (theme.id === ThemeIds.CUSTOM) {
        Row() {
          Text('上传启动封面或填写文案后，冷启动会展示该封面')
            .fontSize(11)
            .fontColor(this.activeVariant(theme).colors.subTextColor)
            .layoutWeight(1)
          Button('编辑主题')
            .height(32)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .backgroundColor(this.activeVariant(theme).colors.buttonColor)
            .onClick(() => {
              router.pushUrl({
                url: 'pages/ThemeColorSettings',
                params: { schemeId: customSchemeId }
              });
            })
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(14)
    .borderRadius(theme.radius.card)
    .backgroundColor(this.activeVariant(theme).colors.cardColor)
    .border({
      width: this.isSelected(theme, customSchemeId) ? 2 : 1,
      color: this.isSelected(theme, customSchemeId) ? this.activeVariant(theme).colors.accentColor :
        this.activeVariant(theme).colors.dividerColor
    })
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction((event: GestureEvent) => {
          if (customSchemeId) {
            this.openCustomThemeActions(customSchemeId, event);
          }
        })
    )
    .onClick(() => {
      this.handleThemeCardClick(theme, customSchemeId);
    })
  }

  isCustomSchemePending(theme: ThemePack, customSchemeId: string): boolean {
    return theme.id === ThemeIds.CUSTOM && this.appThemeId === ThemeIds.CUSTOM &&
      this.activeCustomSchemeId === customSchemeId && !this.isSelected(theme, customSchemeId);
  }

  handleThemeCardClick(theme: ThemePack, customSchemeId: string = ''): void {
    this.selectTheme(theme.id, customSchemeId);
  }

  @Builder
  themeVisualPreview(theme: ThemePack, customSchemeId: string = '') {
    Column({ space: 9 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        ThemeStartupCover({
          themeId: theme.startup.styleId,
          darkMode: this.appDarkMode,
          compact: true,
          animated: false,
          customImagePath: this.customPreviewStartupImage(customSchemeId),
          titleOverride: this.customPreviewStartupTitle(customSchemeId),
          subtitleOverride: this.customPreviewStartupSubtitle(customSchemeId),
          explicitText: !!customSchemeId
        })
      }
      .width('100%')
      .height(126)
      .borderRadius(theme.radius.medium)
      .clip(true)

      Row({ space: 10 }) {
      Stack() {
        ReaderThemeBackground({
          surfaceColor: this.activeVariant(theme).reader.backgroundColor,
          backgroundAssetId: this.activeVariant(theme).reader.backgroundAssetId,
          compact: true
        })
        Text('阅读')
          .fontSize(13)
          .fontFamily(theme.typography.appFontFamily)
          .fontColor(this.activeVariant(theme).reader.textColor)
      }
      .width(76)
      .height(58)
      .borderRadius(theme.radius.medium)
      .clip(true)

      Column({ space: 7 }) {
        Row({ space: 6 }) {
          Blank()
            .height(8)
            .layoutWeight(1)
            .borderRadius(4)
            .backgroundColor(this.activeVariant(theme).colors.primaryTextColor)
          Blank()
            .width(32)
            .height(8)
            .borderRadius(4)
            .backgroundColor(this.activeVariant(theme).colors.subTextColor)
        }
        Text() {
          ContainerSpan() {
            ImageSpan(ThemeAssetRegistry.regexBubbleCap(this.activeVariant(theme).regexEmphasis.bubbleStyle))
              .width(16)
              .height(16)
              .objectFit(ImageFit.Contain)
              .verticalAlign(ImageSpanAlignment.CENTER)
            Span(this.themeRegexPreviewLabel(theme))
              .fontSize(12)
              .fontColor(this.themeRegexPreview(theme).textColor)
              .textShadow(this.themeRegexPreviewShadow(theme))
              .decoration({ type: TextDecorationType.None })
            ImageSpan(ThemeAssetRegistry.regexBubbleCap(this.activeVariant(theme).regexEmphasis.bubbleStyle))
              .width(16)
              .height(16)
              .objectFit(ImageFit.Contain)
              .verticalAlign(ImageSpanAlignment.CENTER)
              .rotate({ angle: 180 })
          }
          .textBackgroundStyle(this.themeRegexPreviewBackground(theme))
        }
        Row({ space: 5 }) {
          ForEach(['bookshelf', 'explore', 'search', 'mine'], (tabId: string) => {
            Image(ThemeAssetRegistry.navigationIcon(theme.navigation.iconPackId, tabId))
              .width(16)
              .height(16)
              .fillColor(this.activeVariant(theme).colors.accentColor)
              .draggable(false)
          }, (tabId: string) => `${theme.id}_${tabId}`)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .width('100%')
    .padding(10)
    .borderRadius(theme.radius.medium)
    .backgroundColor(this.activeVariant(theme).colors.inputColor)
  }

  customPreviewStartupImage(customSchemeId: string): string {
    const scheme = CustomThemeSchemeStore.find(this.customSchemes, customSchemeId);
    if (!scheme) return '';
    return this.appDarkMode ? scheme.settings.customDarkStartupImagePath :
      scheme.settings.customLightStartupImagePath;
  }

  customPreviewStartupTitle(customSchemeId: string): string {
    const scheme = CustomThemeSchemeStore.find(this.customSchemes, customSchemeId);
    if (!scheme) return '';
    return this.appDarkMode ? scheme.settings.customDarkStartupTitle :
      scheme.settings.customLightStartupTitle;
  }

  customPreviewStartupSubtitle(customSchemeId: string): string {
    const scheme = CustomThemeSchemeStore.find(this.customSchemes, customSchemeId);
    if (!scheme) return '';
    return this.appDarkMode ? scheme.settings.customDarkStartupSubtitle :
      scheme.settings.customLightStartupSubtitle;
  }

  themeRegexPreview(theme: ThemePack): ReaderResolvedRegexEmphasis {
    const variant = this.activeVariant(theme);
    const context = new ReaderRegexEmphasisContext();
    context.inheritedMode = variant.regexEmphasis.emphasisMode;
    context.inheritedBubbleStyleId = variant.regexEmphasis.bubbleStyle;
    context.inheritedColor = variant.regexEmphasis.emphasisColor;
    context.inheritedTextColor = variant.regexEmphasis.emphasisTextColor;
    context.accentColor = variant.colors.accentColor;
    context.surfaceColor = variant.reader.backgroundColor;
    context.normalTextColor = variant.reader.textColor;
    context.darkMode = variant.reader.contentTone === 'dark';
    return ReaderRegexBubbleStyleResolver.resolve(null, context);
  }

  themeRegexPreviewLabel(theme: ThemePack): string {
    return '强调气泡';
  }

  themeRegexPreviewBackground(theme: ThemePack): TextBackgroundStyle {
    const style = this.themeRegexPreview(theme);
    if (!style.backgroundEnabled) return {};
    return {
      color: style.backgroundColor,
      radius: {
        topLeft: style.radiusTopLeft,
        topRight: style.radiusTopRight,
        bottomLeft: style.radiusBottomLeft,
        bottomRight: style.radiusBottomRight
      }
    };
  }

  themeRegexPreviewShadow(theme: ThemePack): ShadowOptions | ShadowOptions[] {
    const style = this.themeRegexPreview(theme);
    if (style.textShadows.length > 0) return style.textShadows;
    return {
      radius: style.textShadowRadius,
      color: style.textShadowColor,
      offsetX: style.textShadowOffsetX,
      offsetY: style.textShadowOffsetY
    };
  }

}
