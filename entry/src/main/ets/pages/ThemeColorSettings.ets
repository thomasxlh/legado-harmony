import { router } from '@kit.ArkUI';
import { syncSystemBars } from '../utils/SystemBars';
import { AppThemeSettings, AppThemeSettingsStore } from '../utils/AppThemeSettingsStore';
import { CustomThemeScheme, CustomThemeSchemeStore } from '../utils/CustomThemeSchemeStore';
import { AdaptiveColorPicker } from '../components/AdaptiveColorPicker';
import { ThemeRuntime } from '../theme/ThemeRuntime';
import { ThemeComponentSourceIds, ThemeIds, ThemePack, ThemeVariant } from '../theme/ThemeModels';
import { ThemeAssetRegistry } from '../theme/ThemeAssetRegistry';
import { ImmersiveBackButton } from '../components/ImmersiveBackButton';
import { AdaptiveSwitch } from '../components/AdaptiveSwitch';
import { ThemeStartupCover } from '../components/ThemeStartupCover';
import { ReaderThemeBackground } from '../components/ReaderThemeBackground';
import { StartupCoverImageStore } from '../utils/StartupCoverImageStore';
import { HdsFeedback } from '../utils/HdsFeedback';

@Component
struct ThemeColorOption {
  @Link color: string;
  @Prop title: string = '';
  @Prop appDarkMode: boolean = false;
  @Prop cardColor: string = '#FFFFFF';
  @Prop primaryTextColor: string = '#1F1F1F';
  @Prop accentColor: string = '#007DFF';
  onColorChange: (color: string) => void = (_color: string): void => {};

  build() {
    Stack() {
      Row() {
        Text(this.title)
          .fontSize(16)
          .fontColor(this.primaryTextColor)
          .layoutWeight(1)
        Row()
          .width(30)
          .height(30)
          .borderRadius(15)
          .backgroundColor(this.color)
          .border({ width: 2, color: this.appDarkMode ? '#55FFFFFF' : '#22000000' })
      }
      .width('calc(100% - 32vp)')
      .height(60)
      .padding({ left: 0, right: 0 })
      .margin({ left: 16, right: 16 })
      .backgroundColor(Color.Transparent)
      .border({ width: { bottom: 0.5 }, color: this.appDarkMode ? '#24FFFFFF' : '#14000000' })
      .alignItems(VerticalAlign.Center)

      AdaptiveColorPicker({
        value: this.color,
        placeholder: this.color,
        appDarkMode: this.appDarkMode,
        accentColor: this.accentColor,
        optionTitle: this.title,
        hideOptionTrigger: true,
        onColorChange: (color: string) => {
          this.color = color;
          this.onColorChange(color);
        }
      })
    }
    .width('100%')
    .margin({ top: 1 })
  }
}

@Entry
@Component
struct ThemeColorSettingsPage {
  @StorageLink('appDarkMode') appDarkMode: boolean = false;
  @StorageLink('themeRevision') themeRevision: number = 0;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('navBarHeight') navBarHeight: number = 0;
  @State selectedMode: string = 'light';
  @State lightAccentColor: string = '#007DFF';
  @State darkAccentColor: string = '#4E9BFF';
  @State lightButtonColor: string = '#007DFF';
  @State darkButtonColor: string = '#3F8CFF';
  @State customBaseThemeId: string = AppThemeSettingsStore.DEFAULT_THEME_ID;
  @State lightSources: ThemeComponentSourceIds = new ThemeComponentSourceIds();
  @State darkSources: ThemeComponentSourceIds = new ThemeComponentSourceIds();
  @State lightStartupImagePath: string = '';
  @State darkStartupImagePath: string = '';
  @State lightStartupTitle: string = '';
  @State darkStartupTitle: string = '';
  @State lightStartupSubtitle: string = '';
  @State darkStartupSubtitle: string = '';
  @State lightMainBackgroundImagePath: string = '';
  @State darkMainBackgroundImagePath: string = '';
  @State lightMainBackgroundOpacity: number = AppThemeSettingsStore.DEFAULT_MAIN_BACKGROUND_OPACITY;
  @State darkMainBackgroundOpacity: number = AppThemeSettingsStore.DEFAULT_MAIN_BACKGROUND_OPACITY;
  @State mainBackgroundGlobal: boolean = true;
  @State mainBackgroundCardOpacity: number = AppThemeSettingsStore.DEFAULT_MAIN_BACKGROUND_CARD_OPACITY;
  private schemeId: string = '';
  @State schemeName: string = '';
  private draftSettings: AppThemeSettings = new AppThemeSettings();
  private saveQueue: Promise<void> = Promise.resolve();
  private closing: boolean = false;
  private settingsLoaded: boolean = false;
  private settingsLoading: boolean = false;

  aboutToAppear(): void {
    this.reloadSettings();
    this.syncBars();
  }

  onPageShow(): void {
    this.reloadSettings();
    this.syncBars();
  }

  onBackPress(): boolean {
    this.closeEditor();
    return true;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll() {
        Column() {
          this.sectionTitle('分别设置浅色与深色模式下的启动封面、主界面背景与主题颜色，修改只更新方案预览，需返回主题页手动启用')
          this.schemeNameOptions()
          this.modeOptions()
          this.sectionTitle(`${this.selectedMode === 'dark' ? '深色' : '浅色'}模式 · 启动封面`)
          this.startupCoverOptions()
          this.sectionTitle(`${this.selectedMode === 'dark' ? '深色' : '浅色'}模式 · 主界面背景`)
          this.mainBackgroundOptions()
          this.sectionTitle(`${this.selectedMode === 'dark' ? '深色' : '浅色'}模式 · 自定义颜色`)
          Column() {
            this.colorOptions()
          }
          .width('calc(100% - 24vp)')
          .margin({ left: 12, right: 12, top: 12 })
          .borderRadius(16)
          .clip(true)
          .backgroundColor(this.cardColor())
          this.previewPanel()
        }
        .width('100%')
        .padding({ top: 56 + this.statusBarHeight, bottom: 32 + this.navBarHeight })
      }
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .width('100%')
      .height('100%')
      .align(Alignment.TopStart)
      .backgroundColor(this.pageColor())

      this.titleBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageColor())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  async reloadSettings(): Promise<void> {
    if (this.settingsLoaded || this.settingsLoading) {
      return;
    }
    this.settingsLoading = true;
    try {
      const currentSettings = await AppThemeSettingsStore.load(getContext(this));
      const params = router.getParams() as Record<string, string>;
      this.schemeId = (params['schemeId'] || this.schemeId || '').trim();
      const schemes = await CustomThemeSchemeStore.load(getContext(this), currentSettings);
      let scheme = CustomThemeSchemeStore.find(schemes, this.schemeId);
      if (!scheme && schemes.length > 0) {
        scheme = schemes[0];
        this.schemeId = scheme.id;
      }
      if (!scheme) {
        return;
      }
      this.schemeName = scheme.name;
      const settings = AppThemeSettingsStore.cloneSettings(scheme.settings);
      this.draftSettings = settings;
      this.customBaseThemeId = settings.customBaseThemeId;
      this.lightAccentColor = settings.customLightAccentColor;
      this.darkAccentColor = settings.customDarkAccentColor;
      this.lightButtonColor = settings.customLightButtonColor;
      this.darkButtonColor = settings.customDarkButtonColor;
      this.lightSources = AppThemeSettingsStore.cloneSources(
        settings.customLightSources, settings.customBaseThemeId);
      this.darkSources = AppThemeSettingsStore.cloneSources(
        settings.customDarkSources, settings.customBaseThemeId);
      this.lightStartupImagePath = settings.customLightStartupImagePath;
      this.darkStartupImagePath = settings.customDarkStartupImagePath;
      this.lightStartupTitle = settings.customLightStartupTitle;
      this.darkStartupTitle = settings.customDarkStartupTitle;
      this.lightStartupSubtitle = settings.customLightStartupSubtitle;
      this.darkStartupSubtitle = settings.customDarkStartupSubtitle;
      this.lightMainBackgroundImagePath = settings.customLightMainBackgroundImagePath;
      this.darkMainBackgroundImagePath = settings.customDarkMainBackgroundImagePath;
      this.lightMainBackgroundOpacity = settings.customLightMainBackgroundOpacity;
      this.darkMainBackgroundOpacity = settings.customDarkMainBackgroundOpacity;
      this.mainBackgroundGlobal = settings.mainBackgroundGlobal !== false;
      this.mainBackgroundCardOpacity = AppThemeSettingsStore.normalizeMainBackgroundCardOpacity(
        settings.mainBackgroundCardOpacity);
      this.settingsLoaded = true;
    } catch (e) {
      console.warn('读取主题色设置失败:', e);
    } finally {
      this.settingsLoading = false;
    }
  }

  onSettingChanged(): Promise<void> {
    this.saveQueue = this.saveQueue.then(() => this.persistCurrentScheme()).catch((e: Error) => {
      console.warn('保存自定义主题方案失败:', e);
    });
    return this.saveQueue;
  }

  async persistCurrentScheme(): Promise<void> {
    const currentSettings = await AppThemeSettingsStore.load(getContext(this));
    const settings = this.settingsFromState();
    this.draftSettings = settings;
    const scheme = new CustomThemeScheme();
    scheme.id = this.schemeId;
    scheme.name = this.schemeName;
    scheme.settings = settings;
    await CustomThemeSchemeStore.saveScheme(getContext(this), currentSettings, scheme);
  }

  async closeEditor(): Promise<void> {
    if (this.closing) {
      return;
    }
    this.closing = true;
    try {
      await this.onSettingChanged();
      router.back();
    } catch (e) {
      this.closing = false;
      console.warn('返回主题页前保存方案失败:', e);
    }
  }

  settingsFromState(): AppThemeSettings {
    const settings = AppThemeSettingsStore.cloneSettings(this.draftSettings);
    settings.themeId = ThemeIds.CUSTOM;
    settings.customBaseThemeId = this.customBaseThemeId;
    settings.customLightSources = AppThemeSettingsStore.cloneSources(
      this.lightSources, this.customBaseThemeId);
    settings.customDarkSources = AppThemeSettingsStore.cloneSources(
      this.darkSources, this.customBaseThemeId);
    settings.customDarkSources.layoutThemeId = settings.customLightSources.layoutThemeId;
    settings.customLightAccentColor = this.lightAccentColor;
    settings.customDarkAccentColor = this.darkAccentColor;
    settings.customLightButtonColor = this.lightButtonColor;
    settings.customDarkButtonColor = this.darkButtonColor;
    settings.lightAccentColor = this.lightAccentColor;
    settings.darkAccentColor = this.darkAccentColor;
    settings.lightButtonColor = this.lightButtonColor;
    settings.darkButtonColor = this.darkButtonColor;
    settings.customLightStartupImagePath = this.lightStartupImagePath;
    settings.customDarkStartupImagePath = this.darkStartupImagePath;
    settings.customLightStartupTitle = this.lightStartupTitle;
    settings.customDarkStartupTitle = this.darkStartupTitle;
    settings.customLightStartupSubtitle = this.lightStartupSubtitle;
    settings.customDarkStartupSubtitle = this.darkStartupSubtitle;
    settings.customLightMainBackgroundImagePath = this.lightMainBackgroundImagePath;
    settings.customDarkMainBackgroundImagePath = this.darkMainBackgroundImagePath;
    settings.customLightMainBackgroundOpacity = this.lightMainBackgroundOpacity;
    settings.customDarkMainBackgroundOpacity = this.darkMainBackgroundOpacity;
    settings.mainBackgroundGlobal = this.mainBackgroundGlobal;
    settings.mainBackgroundCardOpacity = this.mainBackgroundCardOpacity;
    return AppThemeSettingsStore.cloneSettings(settings);
  }

  setSchemeName(value: string): void {
    this.schemeName = value;
    this.onSettingChanged();
  }

  currentStartupImagePath(): string {
    return this.selectedMode === 'dark' ? this.darkStartupImagePath : this.lightStartupImagePath;
  }

  currentStartupTitle(): string {
    return this.selectedMode === 'dark' ? this.darkStartupTitle : this.lightStartupTitle;
  }

  currentStartupSubtitle(): string {
    return this.selectedMode === 'dark' ? this.darkStartupSubtitle : this.lightStartupSubtitle;
  }

  setCurrentStartupTitle(value: string): void {
    if (this.selectedMode === 'dark') this.darkStartupTitle = value;
    else this.lightStartupTitle = value;
    this.onSettingChanged();
  }

  setCurrentStartupSubtitle(value: string): void {
    if (this.selectedMode === 'dark') this.darkStartupSubtitle = value;
    else this.lightStartupSubtitle = value;
    this.onSettingChanged();
  }

  currentMainBackgroundImagePath(): string {
    return this.selectedMode === 'dark' ? this.darkMainBackgroundImagePath :
      this.lightMainBackgroundImagePath;
  }

  currentMainBackgroundOpacity(): number {
    return this.selectedMode === 'dark' ? this.darkMainBackgroundOpacity :
      this.lightMainBackgroundOpacity;
  }

  setCurrentMainBackgroundOpacity(value: number): void {
    this.previewMainBackgroundOpacity(value);
    this.onSettingChanged();
  }

  previewMainBackgroundOpacity(value: number): void {
    const normalized = AppThemeSettingsStore.normalizeMainBackgroundOpacity(value);
    if (this.selectedMode === 'dark') this.darkMainBackgroundOpacity = normalized;
    else this.lightMainBackgroundOpacity = normalized;
  }

  setMainBackgroundGlobal(value: boolean): void {
    this.mainBackgroundGlobal = value;
    this.onSettingChanged();
  }

  setMainBackgroundCardOpacity(value: number): void {
    this.mainBackgroundCardOpacity = AppThemeSettingsStore.normalizeMainBackgroundCardOpacity(value);
    this.onSettingChanged();
  }

  async chooseMainBackgroundImage(): Promise<void> {
    try {
      const darkMode = this.selectedMode === 'dark';
      const oldPath = this.currentMainBackgroundImagePath();
      const imagePath = await StartupCoverImageStore.pickAndSaveMainBackground(
        getContext(this), this.schemeId, darkMode);
      if (!imagePath) return;
      if (darkMode) this.darkMainBackgroundImagePath = imagePath;
      else this.lightMainBackgroundImagePath = imagePath;
      await this.onSettingChanged();
      if (oldPath && oldPath !== imagePath) {
        StartupCoverImageStore.remove(getContext(this), oldPath,
          StartupCoverImageStore.MAIN_BACKGROUND_DIR);
      }
      HdsFeedback.showToast(`${darkMode ? '深色' : '浅色'}主界面背景已更新`);
    } catch (e) {
      console.error('上传主界面背景失败:', e);
      HdsFeedback.showToast('上传主界面背景失败，请重试');
    }
  }

  async clearMainBackgroundImage(): Promise<void> {
    const darkMode = this.selectedMode === 'dark';
    const oldPath = this.currentMainBackgroundImagePath();
    if (!oldPath) return;
    if (darkMode) this.darkMainBackgroundImagePath = '';
    else this.lightMainBackgroundImagePath = '';
    await this.onSettingChanged();
    StartupCoverImageStore.remove(getContext(this), oldPath,
      StartupCoverImageStore.MAIN_BACKGROUND_DIR);
    HdsFeedback.showToast('已清除主界面背景');
  }

  async chooseStartupImage(): Promise<void> {
    try {
      const darkMode = this.selectedMode === 'dark';
      const oldPath = this.currentStartupImagePath();
      const imagePath = await StartupCoverImageStore.pickAndSave(getContext(this), this.schemeId, darkMode);
      if (!imagePath) return;
      if (darkMode) this.darkStartupImagePath = imagePath;
      else this.lightStartupImagePath = imagePath;
      await this.onSettingChanged();
      if (oldPath && oldPath !== imagePath) StartupCoverImageStore.remove(getContext(this), oldPath);
      HdsFeedback.showToast(`${darkMode ? '深色' : '浅色'}启动封面已更新`);
    } catch (e) {
      console.error('上传自定义启动封面失败:', e);
      HdsFeedback.showToast('上传启动封面失败，请重试');
    }
  }

  async resetStartupImage(): Promise<void> {
    const darkMode = this.selectedMode === 'dark';
    const oldPath = this.currentStartupImagePath();
    if (!oldPath) return;
    if (darkMode) this.darkStartupImagePath = '';
    else this.lightStartupImagePath = '';
    await this.onSettingChanged();
    StartupCoverImageStore.remove(getContext(this), oldPath);
    HdsFeedback.showToast('已清除自定义启动封面');
  }

  customPreviewTheme(): ThemePack {
    return AppThemeSettingsStore.customTheme(
      this.settingsFromState(),
      this.selectedMode === 'dark'
    );
  }

  customPreviewVariant(): ThemeVariant {
    const theme = this.customPreviewTheme();
    return this.selectedMode === 'dark' ? theme.dark : theme.light;
  }

  setCurrentAccentColor(color: string): void {
    const normalized = AppThemeSettingsStore.normalizeColor(color, this.currentAccentColor());
    if (this.selectedMode === 'dark') {
      this.darkAccentColor = normalized;
    } else {
      this.lightAccentColor = normalized;
    }
    this.onSettingChanged();
  }

  setCurrentButtonColor(color: string): void {
    const normalized = AppThemeSettingsStore.normalizeColor(color, this.currentButtonColor());
    if (this.selectedMode === 'dark') {
      this.darkButtonColor = normalized;
    } else {
      this.lightButtonColor = normalized;
    }
    this.onSettingChanged();
  }

  currentAccentColor(): string {
    return this.selectedMode === 'dark' ? this.darkAccentColor : this.lightAccentColor;
  }

  currentButtonColor(): string {
    return this.selectedMode === 'dark' ? this.darkButtonColor : this.lightButtonColor;
  }

  pageColor(): string {
    return ThemeRuntime.pageColor(this.appDarkMode);
  }

  cardColor(): string {
    return ThemeRuntime.cardColor(this.appDarkMode);
  }

  inputColor(): string {
    return ThemeRuntime.inputColor(this.appDarkMode);
  }

  primaryTextColor(): string {
    return ThemeRuntime.primaryTextColor(this.appDarkMode);
  }

  subTextColor(): string {
    return ThemeRuntime.subTextColor(this.appDarkMode);
  }

  syncBars(): void {
    syncSystemBars(getContext(this), this.appDarkMode, this.pageColor());
  }

  @Builder
  titleBar() {
    Row() {
      ImmersiveBackButton({ iconColor: this.primaryTextColor(), darkMode: this.appDarkMode,
        buttonSize: 40, containerWidth: 56, materialScale: 0.83, compactLayout: true,
        onBack: () => this.closeEditor() })
      Text(this.schemeName.trim() || '自定义主题')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.primaryTextColor())
        .layoutWeight(1)
    }
    .width('100%')
    .height(56 + this.statusBarHeight)
    .padding({ top: this.statusBarHeight })
    .backgroundColor(ThemeRuntime.topBarColor(this.appDarkMode))
    .backdropBlur(ThemeRuntime.topBarBlur())
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor(this.subTextColor())
      .width('100%')
      .padding({ left: 16, right: 16, top: 20, bottom: 8 })
  }

  @Builder
  schemeNameOptions() {
    Column({ space: 6 }) {
      Text('主题名称')
        .fontSize(12)
        .fontColor(this.subTextColor())
        .width('100%')
      TextInput({ placeholder: '输入主题名称', text: this.schemeName })
        .width('100%')
        .height(42)
        .maxLength(20)
        .fontColor(this.primaryTextColor())
        .placeholderColor(this.subTextColor())
        .backgroundColor(this.inputColor())
        .borderRadius(10)
        .onChange((value: string) => this.setSchemeName(value))
    }
    .width('calc(100% - 24vp)')
    .padding(14)
    .margin({ left: 12, right: 12, bottom: 12 })
    .borderRadius(16)
    .backgroundColor(this.cardColor())
  }

  @Builder
  modeOptions() {
    Row({ space: 8 }) {
      this.modeButton('浅色模式', 'light')
      this.modeButton('深色模式', 'dark')
    }
    .width('calc(100% - 24vp)')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .margin({ left: 12, right: 12 })
    .borderRadius(16)
    .clip(true)
    .backgroundColor(this.cardColor())
  }

  @Builder
  modeButton(title: string, mode: string) {
    Stack({ alignContent: Alignment.Center }) {
      Text(title)
        .fontSize(14)
        .fontColor(this.selectedMode === mode ? '#FFFFFF' : this.primaryTextColor())
    }
      .layoutWeight(1)
      .height(38)
      .borderRadius(19)
      .backgroundColor(this.selectedMode === mode ? this.currentAccentColor() : this.inputColor())
      .onClick(() => {
        this.selectedMode = mode;
      })
  }

  @Builder
  colorOptions() {
    if (this.selectedMode === 'dark') {
      ThemeColorOption({
        title: '按钮色',
        color: $darkButtonColor,
        appDarkMode: this.appDarkMode,
        cardColor: this.cardColor(),
        primaryTextColor: this.primaryTextColor(),
        accentColor: this.darkAccentColor,
        onColorChange: (color: string) => {
          this.setCurrentButtonColor(color);
        }
      })
      ThemeColorOption({
        title: '强调色',
        color: $darkAccentColor,
        appDarkMode: this.appDarkMode,
        cardColor: this.cardColor(),
        primaryTextColor: this.primaryTextColor(),
        accentColor: this.darkAccentColor,
        onColorChange: (color: string) => {
          this.setCurrentAccentColor(color);
        }
      })
    } else {
      ThemeColorOption({
        title: '按钮色',
        color: $lightButtonColor,
        appDarkMode: this.appDarkMode,
        cardColor: this.cardColor(),
        primaryTextColor: this.primaryTextColor(),
        accentColor: this.lightAccentColor,
        onColorChange: (color: string) => {
          this.setCurrentButtonColor(color);
        }
      })
      ThemeColorOption({
        title: '强调色',
        color: $lightAccentColor,
        appDarkMode: this.appDarkMode,
        cardColor: this.cardColor(),
        primaryTextColor: this.primaryTextColor(),
        accentColor: this.lightAccentColor,
        onColorChange: (color: string) => {
          this.setCurrentAccentColor(color);
        }
      })
    }
  }

  @Builder
  startupCoverOptions() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Button(this.currentStartupImagePath() ? '更换自定义封面' : '上传自定义封面',
          { type: ButtonType.Normal })
          .height(38)
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor(this.currentButtonColor())
          .layoutWeight(1)
          .onClick(() => this.chooseStartupImage())
        if (this.currentStartupImagePath()) {
          Button('恢复默认封面', { type: ButtonType.Normal })
            .height(38)
            .fontSize(13)
            .fontColor(this.currentAccentColor())
            .backgroundColor(this.inputColor())
            .layoutWeight(1)
            .onClick(() => this.resetStartupImage())
        }
      }
      .width('100%')

      Column({ space: 6 }) {
        Text('主标题')
          .fontSize(12)
          .fontColor(this.subTextColor())
          .width('100%')
        TextInput({ placeholder: '可留空', text: this.currentStartupTitle() })
          .width('100%')
          .height(42)
          .maxLength(24)
          .fontColor(this.primaryTextColor())
          .placeholderColor(this.subTextColor())
          .backgroundColor(this.inputColor())
          .borderRadius(10)
          .onChange((value: string) => this.setCurrentStartupTitle(value))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text('副标题')
          .fontSize(12)
          .fontColor(this.subTextColor())
          .width('100%')
        TextInput({ placeholder: '可留空', text: this.currentStartupSubtitle() })
          .width('100%')
          .height(42)
          .maxLength(48)
          .fontColor(this.primaryTextColor())
          .placeholderColor(this.subTextColor())
          .backgroundColor(this.inputColor())
          .borderRadius(10)
          .onChange((value: string) => this.setCurrentStartupSubtitle(value))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('calc(100% - 24vp)')
    .padding(14)
    .margin({ left: 12, right: 12 })
    .borderRadius(16)
    .backgroundColor(this.cardColor())
  }

  @Builder
  mainBackgroundOptions() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Button(this.currentMainBackgroundImagePath() ? '更换背景图' : '上传背景图',
          { type: ButtonType.Normal })
          .height(38)
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor(this.currentButtonColor())
          .layoutWeight(1)
          .onClick(() => this.chooseMainBackgroundImage())
        if (this.currentMainBackgroundImagePath()) {
          Button('清除背景', { type: ButtonType.Normal })
            .height(38)
            .fontSize(13)
            .fontColor(this.currentAccentColor())
            .backgroundColor(this.inputColor())
            .layoutWeight(1)
            .onClick(() => this.clearMainBackgroundImage())
        }
      }
      .width('100%')

      Column({ space: 4 }) {
        Row() {
          Text('不透明度')
            .fontSize(12)
            .fontColor(this.subTextColor())
            .layoutWeight(1)
          Text(`${this.currentMainBackgroundOpacity()}%`)
            .fontSize(12)
            .fontColor(this.subTextColor())
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        Slider({
          value: this.currentMainBackgroundOpacity(),
          min: AppThemeSettingsStore.MIN_MAIN_BACKGROUND_OPACITY,
          max: AppThemeSettingsStore.MAX_MAIN_BACKGROUND_OPACITY,
          step: 1,
          style: SliderStyle.OutSet
        })
          .width('100%')
          .trackThickness(4)
          .selectedColor(this.currentAccentColor())
          .trackColor(this.inputColor())
          .blockColor(this.currentAccentColor())
          .onChange((value: number, mode: SliderChangeMode) => {
            this.previewMainBackgroundOpacity(value);
            if (mode === SliderChangeMode.End) {
              this.setCurrentMainBackgroundOpacity(value);
            }
          })
      }
      .width('100%')

      if (this.currentMainBackgroundImagePath()) {
        Stack() {
          Image(this.currentMainBackgroundImagePath())
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .opacity(this.currentMainBackgroundOpacity() / 100)
            .draggable(false)
        }
        .width('100%')
        .height(96)
        .borderRadius(12)
        .clip(true)
        .backgroundColor(this.pageColor())
      }

      Row({ space: 10 }) {
        Column({ space: 2 }) {
          Text('应用到全部页面')
            .fontSize(13)
            .fontColor(this.primaryTextColor())
            .alignSelf(ItemAlign.Start)
          Text('关闭后只有书架主界面铺这张背景图，其余页面保持纯色底色。')
            .fontSize(11)
            .fontColor(this.subTextColor())
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        AdaptiveSwitch({ isOn: this.mainBackgroundGlobal, selectedColor: this.currentAccentColor(),
          onChange: (value: boolean) => this.setMainBackgroundGlobal(value) })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 4 }) {
        Row() {
          Text('卡片不透明度')
            .fontSize(12)
            .fontColor(this.subTextColor())
            .layoutWeight(1)
          Text(`${this.mainBackgroundCardOpacity}%`)
            .fontSize(12)
            .fontColor(this.subTextColor())
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        Slider({
          value: this.mainBackgroundCardOpacity,
          min: AppThemeSettingsStore.MIN_MAIN_BACKGROUND_CARD_OPACITY,
          max: AppThemeSettingsStore.MAX_MAIN_BACKGROUND_CARD_OPACITY,
          step: 1,
          style: SliderStyle.OutSet
        })
          .width('100%')
          .trackThickness(4)
          .selectedColor(this.currentAccentColor())
          .trackColor(this.inputColor())
          .blockColor(this.currentAccentColor())
          .onChange((value: number, mode: SliderChangeMode) => {
            if (mode === SliderChangeMode.End) {
              this.setMainBackgroundCardOpacity(value);
            }
          })
      }
      .width('100%')

      Text('背景图铺在页面底层，启用本方案后生效；默认主题不使用背景图。')
        .fontSize(11)
        .fontColor(this.subTextColor())
        .width('100%')
    }
    .width('calc(100% - 24vp)')
    .padding(14)
    .margin({ left: 12, right: 12, top: 12 })
    .borderRadius(16)
    .backgroundColor(this.cardColor())
  }

  @Builder
  previewPanel() {
    Column() {
      Text(`${this.selectedMode === 'dark' ? '深色' : '浅色'}模式预览`)
        .fontSize(13)
        .fontColor(this.subTextColor())
        .width('100%')
        .margin({ bottom: 12 })

      ThemeStartupCover({
        themeId: this.customPreviewTheme().startup.styleId,
        darkMode: this.selectedMode === 'dark',
        compact: true,
        animated: false,
        customImagePath: this.currentStartupImagePath(),
        titleOverride: this.currentStartupTitle(),
        subtitleOverride: this.currentStartupSubtitle(),
        explicitText: true
      })
      .width('100%')
      .height(150)
      .borderRadius(this.customPreviewTheme().radius.medium)
      .margin({ bottom: 12 })
      .clip(true)

      Row({ space: 10 }) {
        Stack() {
          ReaderThemeBackground({
            surfaceColor: this.customPreviewVariant().reader.backgroundColor,
            backgroundAssetId: this.customPreviewVariant().reader.backgroundAssetId,
            compact: true
          })
          Text('阅读')
            .fontSize(14)
            .fontFamily(this.customPreviewTheme().typography.appFontFamily)
            .fontColor(this.customPreviewVariant().reader.textColor)
        }
        .width(70)
        .height(58)
        .borderRadius(this.customPreviewTheme().radius.medium)
        .clip(true)

        Column({ space: 7 }) {
          Row({ space: 6 }) {
            Blank()
              .height(8)
              .layoutWeight(1)
              .borderRadius(4)
              .backgroundColor(this.customPreviewVariant().colors.primaryTextColor)
            Blank()
              .width(28)
              .height(8)
              .borderRadius(4)
              .backgroundColor(this.customPreviewVariant().colors.subTextColor)
          }
          Text('强调气泡')
            .fontSize(12)
            .fontColor(this.customPreviewVariant().regexEmphasis.emphasisTextColor)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .borderRadius(this.customPreviewTheme().radius.bubble)
            .backgroundColor(this.customPreviewVariant().regexEmphasis.emphasisColor)
          Row({ space: 8 }) {
            ForEach(['bookshelf', 'explore', 'search', 'mine'], (tabId: string) => {
              Image(ThemeAssetRegistry.navigationIcon(
                this.customPreviewTheme().navigation.iconPackId, tabId))
                .width(17)
                .height(17)
                .fillColor(this.customPreviewVariant().colors.accentColor)
            }, (tabId: string) => `custom_preview_${this.selectedMode}_${tabId}`)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding(12)
      .borderRadius(this.customPreviewTheme().radius.medium)
      .backgroundColor(this.customPreviewVariant().colors.inputColor)

      Row({ space: 12 }) {
        Button('主要按钮')
          .height(40)
          .layoutWeight(1)
          .fontColor('#FFFFFF')
          .backgroundColor(this.currentButtonColor())
        Text('强调文字')
          .fontSize(15)
          .fontColor(this.currentAccentColor())
          .layoutWeight(1)
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor(this.cardColor())
    .margin({ top: 12 })
  }

}
