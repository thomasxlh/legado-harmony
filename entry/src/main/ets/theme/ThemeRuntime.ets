import { BuiltinThemeRegistry } from './BuiltinThemeRegistry';
import {
  ThemeBubbleStyles,
  ThemeComponentSourceIds,
  ThemeGlassSurfaceTokens,
  ThemeGlassTokens,
  ThemeIds,
  ThemePack,
  ThemeReaderLayoutTokens,
  ThemeRegexEmphasisModes,
  ThemeVariant
} from './ThemeModels';

export class ThemeRuntime {
  static readonly KEY_GLASS_ENABLED: string = 'glassEnabled';
  static readonly KEY_GLASS_PANEL_BLUR: string = 'glassPanelBlur';
  static readonly KEY_GLASS_POPOVER_BLUR: string = 'glassPopoverBlur';
  static readonly KEY_GLASS_BUTTON_BLUR: string = 'glassButtonBlur';
  static readonly KEY_GLASS_OVERLAY_BLUR: string = 'glassOverlayBlur';
  static readonly KEY_GLASS_MENU_BLUR: string = 'glassMenuBlur';
  static readonly KEY_GLASS_LIGHT_TINT_OPACITY: string = 'glassLightTintOpacity';
  static readonly KEY_GLASS_DARK_TINT_OPACITY: string = 'glassDarkTintOpacity';
  static readonly KEY_GLASS_LIGHT_BORDER_OPACITY: string = 'glassLightBorderOpacity';
  static readonly KEY_GLASS_DARK_BORDER_OPACITY: string = 'glassDarkBorderOpacity';
  static readonly KEY_GLASS_BORDER_WIDTH: string = 'glassBorderWidth';
  static readonly KEY_GLASS_SHADOW_ENABLED: string = 'glassShadowEnabled';
  static readonly KEY_GLASS_LIGHT_SHADOW_OPACITY: string = 'glassLightShadowOpacity';
  static readonly KEY_GLASS_DARK_SHADOW_OPACITY: string = 'glassDarkShadowOpacity';
  static readonly KEY_GLASS_SHADOW_RADIUS: string = 'glassShadowRadius';
  static readonly KEY_GLASS_SHADOW_OFFSET_X: string = 'glassShadowOffsetX';
  static readonly KEY_GLASS_SHADOW_OFFSET_Y: string = 'glassShadowOffsetY';
  static readonly KEY_GLASS_CORNER_RADIUS: string = 'glassCornerRadius';
  static readonly KEY_GLASS_LOW_PERFORMANCE: string = 'glassLowPerformance';
  static readonly KEY_THEME_ID: string = 'appThemeId';
  static readonly KEY_THEME_REVISION: string = 'themeRevision';
  static readonly KEY_FONT_FAMILY: string = 'themeFontFamily';
  static readonly KEY_ICON_PACK_ID: string = 'themeIconPackId';
  static readonly KEY_CUSTOM_BASE_THEME_ID: string = 'appCustomBaseThemeId';
  static readonly KEY_CUSTOM_LIGHT_SOURCES: string = 'appCustomLightThemeSources';
  static readonly KEY_CUSTOM_DARK_SOURCES: string = 'appCustomDarkThemeSources';

  // 主界面背景属于自定义主题方案，浅色/深色各存一张底图与不透明度。
  static readonly KEY_CUSTOM_LIGHT_MAIN_BACKGROUND_IMAGE_PATH: string = 'appCustomLightMainBackgroundImagePath';
  static readonly KEY_CUSTOM_DARK_MAIN_BACKGROUND_IMAGE_PATH: string = 'appCustomDarkMainBackgroundImagePath';
  static readonly KEY_CUSTOM_LIGHT_MAIN_BACKGROUND_OPACITY: string = 'appCustomLightMainBackgroundOpacity';
  static readonly KEY_CUSTOM_DARK_MAIN_BACKGROUND_OPACITY: string = 'appCustomDarkMainBackgroundOpacity';
  // 主界面背景是否铺到主界面以外的页面。
  static readonly KEY_MAIN_BACKGROUND_GLOBAL: string = 'appMainBackgroundGlobal';
  // 铺了背景图时卡片保留的不透明度（0-100）：低于 100 时卡片半透明，让背景图透上来。
  static readonly KEY_MAIN_BACKGROUND_CARD_OPACITY: string = 'appMainBackgroundCardOpacity';
  static readonly DEFAULT_MAIN_BACKGROUND_CARD_OPACITY: number = 85;
  static readonly MIN_MAIN_BACKGROUND_CARD_OPACITY: number = 0;
  static readonly MAX_MAIN_BACKGROUND_CARD_OPACITY: number = 100;
  // 铺开到全部页面时，非主界面页面保留的底色不透明度（0-100）。
  private static readonly GLOBAL_BACKGROUND_PAGE_ALPHA: number = 72;

  static readonly KEY_LIGHT_PAGE_COLOR: string = 'themeLightPageColor';
  static readonly KEY_DARK_PAGE_COLOR: string = 'themeDarkPageColor';
  static readonly KEY_LIGHT_CARD_COLOR: string = 'themeLightCardColor';
  static readonly KEY_DARK_CARD_COLOR: string = 'themeDarkCardColor';
  static readonly KEY_LIGHT_INPUT_COLOR: string = 'themeLightInputColor';
  static readonly KEY_DARK_INPUT_COLOR: string = 'themeDarkInputColor';
  static readonly KEY_LIGHT_PRIMARY_TEXT_COLOR: string = 'themeLightPrimaryTextColor';
  static readonly KEY_DARK_PRIMARY_TEXT_COLOR: string = 'themeDarkPrimaryTextColor';
  static readonly KEY_LIGHT_SUB_TEXT_COLOR: string = 'themeLightSubTextColor';
  static readonly KEY_DARK_SUB_TEXT_COLOR: string = 'themeDarkSubTextColor';
  static readonly KEY_LIGHT_DIVIDER_COLOR: string = 'themeLightDividerColor';
  static readonly KEY_DARK_DIVIDER_COLOR: string = 'themeDarkDividerColor';
  static readonly KEY_LIGHT_ACCENT_COLOR: string = 'themeLightAccentColor';
  static readonly KEY_DARK_ACCENT_COLOR: string = 'themeDarkAccentColor';
  static readonly KEY_LIGHT_BUTTON_COLOR: string = 'themeLightButtonColor';
  static readonly KEY_DARK_BUTTON_COLOR: string = 'themeDarkButtonColor';
  static readonly KEY_LIGHT_DANGER_COLOR: string = 'themeLightDangerColor';
  static readonly KEY_DARK_DANGER_COLOR: string = 'themeDarkDangerColor';
  static readonly KEY_LIGHT_SUCCESS_COLOR: string = 'themeLightSuccessColor';
  static readonly KEY_DARK_SUCCESS_COLOR: string = 'themeDarkSuccessColor';
  static readonly KEY_LIGHT_WARNING_COLOR: string = 'themeLightWarningColor';
  static readonly KEY_DARK_WARNING_COLOR: string = 'themeDarkWarningColor';

  static readonly KEY_LIGHT_READER_BACKGROUND_COLOR: string = 'themeLightReaderBackgroundColor';
  static readonly KEY_DARK_READER_BACKGROUND_COLOR: string = 'themeDarkReaderBackgroundColor';
  static readonly KEY_LIGHT_READER_BACKGROUND_ASSET_ID: string = 'themeLightReaderBackgroundAssetId';
  static readonly KEY_DARK_READER_BACKGROUND_ASSET_ID: string = 'themeDarkReaderBackgroundAssetId';
  static readonly KEY_LIGHT_READER_BACKGROUND_IMAGE_FIT: string = 'themeLightReaderBackgroundImageFit';
  static readonly KEY_DARK_READER_BACKGROUND_IMAGE_FIT: string = 'themeDarkReaderBackgroundImageFit';
  static readonly KEY_LIGHT_READER_TEXT_COLOR: string = 'themeLightReaderTextColor';
  static readonly KEY_DARK_READER_TEXT_COLOR: string = 'themeDarkReaderTextColor';
  static readonly KEY_LIGHT_READER_SUB_TEXT_COLOR: string = 'themeLightReaderSubTextColor';
  static readonly KEY_DARK_READER_SUB_TEXT_COLOR: string = 'themeDarkReaderSubTextColor';
  static readonly KEY_LIGHT_READER_CONTENT_TONE: string = 'themeLightReaderContentTone';
  static readonly KEY_DARK_READER_CONTENT_TONE: string = 'themeDarkReaderContentTone';

  static readonly KEY_LIGHT_REGEX_EMPHASIS_MODE: string = 'themeLightRegexEmphasisMode';
  static readonly KEY_DARK_REGEX_EMPHASIS_MODE: string = 'themeDarkRegexEmphasisMode';
  static readonly KEY_LIGHT_REGEX_BUBBLE_STYLE: string = 'themeLightRegexBubbleStyle';
  static readonly KEY_DARK_REGEX_BUBBLE_STYLE: string = 'themeDarkRegexBubbleStyle';
  static readonly KEY_LIGHT_REGEX_EMPHASIS_COLOR: string = 'themeLightRegexEmphasisColor';
  static readonly KEY_DARK_REGEX_EMPHASIS_COLOR: string = 'themeDarkRegexEmphasisColor';
  static readonly KEY_LIGHT_REGEX_EMPHASIS_TEXT_COLOR: string = 'themeLightRegexEmphasisTextColor';
  static readonly KEY_DARK_REGEX_EMPHASIS_TEXT_COLOR: string = 'themeDarkRegexEmphasisTextColor';

  static readonly KEY_RADIUS_SMALL: string = 'themeRadiusSmall';
  static readonly KEY_RADIUS_MEDIUM: string = 'themeRadiusMedium';
  static readonly KEY_RADIUS_LARGE: string = 'themeRadiusLarge';
  static readonly KEY_RADIUS_CARD: string = 'themeRadiusCard';
  static readonly KEY_RADIUS_BUTTON: string = 'themeRadiusButton';
  static readonly KEY_RADIUS_BUBBLE: string = 'themeRadiusBubble';

  static applyTheme(themeId: string, lightAccentOverride: string = '', darkAccentOverride: string = '',
    lightButtonOverride: string = '', darkButtonOverride: string = '', customBaseThemeId: string = ''): ThemePack {
    const normalizedThemeId = BuiltinThemeRegistry.normalizeId(themeId);
    const baseThemeId = BuiltinThemeRegistry.normalizeBuiltinId(customBaseThemeId);
    const theme = normalizedThemeId === ThemeIds.CUSTOM ?
      BuiltinThemeRegistry.customTheme(baseThemeId) : BuiltinThemeRegistry.findById(normalizedThemeId);
    ThemeRuntime.setString(ThemeRuntime.KEY_CUSTOM_BASE_THEME_ID, baseThemeId);
    ThemeRuntime.applyPack(theme, lightAccentOverride, darkAccentOverride, lightButtonOverride, darkButtonOverride);
    return theme;
  }

  static applyPack(theme: ThemePack, lightAccentOverride: string = '', darkAccentOverride: string = '',
    lightButtonOverride: string = '', darkButtonOverride: string = ''): void {
    const fallback = BuiltinThemeRegistry.findById(BuiltinThemeRegistry.DEFAULT_THEME_ID);
    const themeId = (theme.id || '').trim() || BuiltinThemeRegistry.DEFAULT_THEME_ID;
    ThemeRuntime.setString(ThemeRuntime.KEY_THEME_ID, themeId);
    ThemeRuntime.setString(ThemeRuntime.KEY_FONT_FAMILY,
      (theme.typography.appFontFamily || '').trim() || fallback.typography.appFontFamily);
    ThemeRuntime.setString(ThemeRuntime.KEY_ICON_PACK_ID,
      (theme.navigation.iconPackId || '').trim() || fallback.navigation.iconPackId);

    ThemeRuntime.publishVariant(false, theme.light, fallback.light, lightAccentOverride, lightButtonOverride);
    ThemeRuntime.publishVariant(true, theme.dark, fallback.dark, darkAccentOverride, darkButtonOverride);

    ThemeRuntime.setNumber(ThemeRuntime.KEY_RADIUS_SMALL,
      ThemeRuntime.normalizeRadius(theme.radius.small, fallback.radius.small));
    ThemeRuntime.setNumber(ThemeRuntime.KEY_RADIUS_MEDIUM,
      ThemeRuntime.normalizeRadius(theme.radius.medium, fallback.radius.medium));
    ThemeRuntime.setNumber(ThemeRuntime.KEY_RADIUS_LARGE,
      ThemeRuntime.normalizeRadius(theme.radius.large, fallback.radius.large));
    ThemeRuntime.setNumber(ThemeRuntime.KEY_RADIUS_CARD,
      ThemeRuntime.normalizeRadius(theme.radius.card, fallback.radius.card));
    ThemeRuntime.setNumber(ThemeRuntime.KEY_RADIUS_BUTTON,
      ThemeRuntime.normalizeRadius(theme.radius.button, fallback.radius.button));
    ThemeRuntime.setNumber(ThemeRuntime.KEY_RADIUS_BUBBLE,
      ThemeRuntime.normalizeRadius(theme.radius.bubble, fallback.radius.bubble));

    const revision = AppStorage.get<number>(ThemeRuntime.KEY_THEME_REVISION) ?? 0;
    AppStorage.setOrCreate(ThemeRuntime.KEY_THEME_REVISION, revision + 1);
  }

  static currentThemeId(): string {
    const stored = ThemeRuntime.storageString(ThemeRuntime.KEY_THEME_ID, BuiltinThemeRegistry.DEFAULT_THEME_ID);
    return BuiltinThemeRegistry.normalizeId(stored);
  }

  static startupThemeId(darkMode: boolean = AppStorage.get<boolean>('appDarkMode') || false): string {
    if (ThemeRuntime.currentThemeId() === ThemeIds.CUSTOM) {
      return ThemeRuntime.customSourceTheme('startup', darkMode).startup.styleId;
    }
    return ThemeRuntime.currentPack().startup.styleId;
  }

  static themeRevision(): number {
    return AppStorage.get<number>(ThemeRuntime.KEY_THEME_REVISION) ?? 0;
  }

  static pageColor(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).colors.pageColor;
    return ThemeRuntime.colorFromStorage(darkMode ? ThemeRuntime.KEY_DARK_PAGE_COLOR :
      ThemeRuntime.KEY_LIGHT_PAGE_COLOR, fallback);
  }

  /**
   * 主界面背景跟随自定义主题方案：只有启用自定义主题时才生效，默认主题不使用背景图。
   */
  static mainBackgroundImagePath(darkMode: boolean = AppStorage.get<boolean>('appDarkMode') || false): string {
    if (ThemeRuntime.currentThemeId() !== ThemeIds.CUSTOM) {
      return '';
    }
    return AppStorage.get<string>(darkMode ?
      ThemeRuntime.KEY_CUSTOM_DARK_MAIN_BACKGROUND_IMAGE_PATH :
      ThemeRuntime.KEY_CUSTOM_LIGHT_MAIN_BACKGROUND_IMAGE_PATH) || '';
  }

  static mainBackgroundOpacity(darkMode: boolean = AppStorage.get<boolean>('appDarkMode') || false): number {
    const value = AppStorage.get<number>(darkMode ?
      ThemeRuntime.KEY_CUSTOM_DARK_MAIN_BACKGROUND_OPACITY :
      ThemeRuntime.KEY_CUSTOM_LIGHT_MAIN_BACKGROUND_OPACITY);
    const numeric = typeof value === 'number' && Number.isFinite(value) ? value : 100;
    return ThemeRuntime.clampNumber(numeric, 10, 100);
  }

  /**
   * 主界面背景是否生效：只有启用自定义主题且方案里配了背景图时才生效。
   */
  static usesMainBackground(darkMode: boolean = AppStorage.get<boolean>('appDarkMode') || false): boolean {
    if (ThemeRuntime.currentThemeId() !== ThemeIds.CUSTOM) {
      return false;
    }
    return !!ThemeRuntime.mainBackgroundImagePath(darkMode);
  }

  /**
   * 是否把主界面背景铺到全部页面。关闭时只有书架主界面有背景，其它页面保持纯色底色。
   */
  static usesGlobalBackground(darkMode: boolean = AppStorage.get<boolean>('appDarkMode') || false): boolean {
    if (!ThemeRuntime.usesMainBackground(darkMode)) {
      return false;
    }
    return AppStorage.get<boolean>(ThemeRuntime.KEY_MAIN_BACKGROUND_GLOBAL) !== false;
  }

  /**
   * 主界面页面底色：自定义主题设置了背景图时改为全透明，让底层背景图透出；
   * 未设置时与 pageColor 完全一致，避免影响书架以外的任何界面。
   */
  static mainPageColor(darkMode: boolean = AppStorage.get<boolean>('appDarkMode') || false): string {
    if (ThemeRuntime.usesMainBackground(darkMode)) {
      return '#00000000';
    }
    return ThemeRuntime.pageColor(darkMode);
  }

  /**
   * 非主界面的页面底色：开启「应用到全部页面」后改为半透明，让当前页面底层铺的那张
   * 背景图透出来，同时保留一层底色保证文字可读；未开启时与 pageColor 一致。
   */
  static pageColorBehind(darkMode: boolean = AppStorage.get<boolean>('appDarkMode') || false): string {
    if (!ThemeRuntime.usesGlobalBackground(darkMode)) {
      return ThemeRuntime.pageColor(darkMode);
    }
    const color = ThemeRuntime.pageColor(darkMode);
    const rgb = /^#[0-9a-fA-F]{8}$/.test(color) ? color.substring(3) : color.substring(1);
    return `#${ThemeRuntime.opacityHex(ThemeRuntime.GLOBAL_BACKGROUND_PAGE_ALPHA)}${rgb.toUpperCase()}`;
  }

  /**
   * 卡片不透明度（0-100）：100 表示卡片仍是实心色，越低背景图透得越多。
   */
  static mainBackgroundCardOpacity(): number {
    const value = AppStorage.get<number>(ThemeRuntime.KEY_MAIN_BACKGROUND_CARD_OPACITY);
    const numeric = typeof value === 'number' && Number.isFinite(value) ? value :
      ThemeRuntime.DEFAULT_MAIN_BACKGROUND_CARD_OPACITY;
    return ThemeRuntime.clampNumber(numeric, ThemeRuntime.MIN_MAIN_BACKGROUND_CARD_OPACITY,
      ThemeRuntime.MAX_MAIN_BACKGROUND_CARD_OPACITY);
  }

  /**
   * 卡片/列表项底色：铺了背景图时按「卡片不透明度」改为半透明，让背景图从卡片后面
   * 透上来；没有背景图或不透明度为 100 时与 cardColor 完全一致。
   */
  static cardColorBehind(darkMode: boolean = AppStorage.get<boolean>('appDarkMode') || false): string {
    if (!ThemeRuntime.usesMainBackground(darkMode)) {
      return ThemeRuntime.cardColor(darkMode);
    }
    const opacity = ThemeRuntime.mainBackgroundCardOpacity();
    if (opacity >= ThemeRuntime.MAX_MAIN_BACKGROUND_CARD_OPACITY) {
      return ThemeRuntime.cardColor(darkMode);
    }
    const color = ThemeRuntime.cardColor(darkMode);
    const rgb = /^#[0-9a-fA-F]{8}$/.test(color) ? color.substring(3) : color.substring(1);
    return `#${ThemeRuntime.opacityHex(opacity)}${rgb.toUpperCase()}`;
  }

  static cardColor(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).colors.cardColor;
    return ThemeRuntime.colorFromStorage(darkMode ? ThemeRuntime.KEY_DARK_CARD_COLOR :
      ThemeRuntime.KEY_LIGHT_CARD_COLOR, fallback);
  }

  static topBarColor(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).colors.cardColor;
    const color = ThemeRuntime.normalizeColor(ThemeRuntime.cardColor(darkMode), fallback);
    return ThemeRuntime.dropdownPanelColor(darkMode, color, 'overlay');
  }

  static topBarBlur(): number {
    return ThemeRuntime.glassBlur('overlay', 18);
  }

  static inputColor(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).colors.inputColor;
    return ThemeRuntime.colorFromStorage(darkMode ? ThemeRuntime.KEY_DARK_INPUT_COLOR :
      ThemeRuntime.KEY_LIGHT_INPUT_COLOR, fallback);
  }

  static primaryTextColor(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).colors.primaryTextColor;
    return ThemeRuntime.colorFromStorage(darkMode ? ThemeRuntime.KEY_DARK_PRIMARY_TEXT_COLOR :
      ThemeRuntime.KEY_LIGHT_PRIMARY_TEXT_COLOR, fallback);
  }

  static subTextColor(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).colors.subTextColor;
    return ThemeRuntime.colorFromStorage(darkMode ? ThemeRuntime.KEY_DARK_SUB_TEXT_COLOR :
      ThemeRuntime.KEY_LIGHT_SUB_TEXT_COLOR, fallback);
  }

  static dividerColor(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).colors.dividerColor;
    return ThemeRuntime.colorFromStorage(darkMode ? ThemeRuntime.KEY_DARK_DIVIDER_COLOR :
      ThemeRuntime.KEY_LIGHT_DIVIDER_COLOR, fallback);
  }

  static accentColor(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).colors.accentColor;
    return ThemeRuntime.colorFromStorage(darkMode ? ThemeRuntime.KEY_DARK_ACCENT_COLOR :
      ThemeRuntime.KEY_LIGHT_ACCENT_COLOR, fallback);
  }

  static accentSurfaceColor(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).colors.accentColor;
    const accent = ThemeRuntime.normalizeColor(ThemeRuntime.accentColor(darkMode), fallback);
    return `#${darkMode ? '33' : '1F'}${accent.substring(1)}`;
  }

  /**
   * 给定背景色（#RRGGBB / #AARRGGBB），返回在其上可读的前景色：
   * 亮底返回深色文字，暗底返回白色文字。用于强调色按钮、色块 chip 等场景，
   * 避免固定白字在浅色强调色（如深色模式浅灰蓝、用户自定义浅色）上对比度不足。
   */
  static readableTextColorOn(backgroundColor: string): string {
    const color = (backgroundColor || '').trim();
    const hex = /^#[0-9a-fA-F]{8}$/.test(color) ? color.substring(3) :
      (/^#[0-9a-fA-F]{6}$/.test(color) ? color.substring(1) : '');
    if (!hex) {
      return '#FFFFFF';
    }
    const r = parseInt(hex.substring(0, 2), 16) / 255;
    const g = parseInt(hex.substring(2, 4), 16) / 255;
    const b = parseInt(hex.substring(4, 6), 16) / 255;
    const linearR = r <= 0.03928 ? r / 12.92 : Math.pow((r + 0.055) / 1.055, 2.4);
    const linearG = g <= 0.03928 ? g / 12.92 : Math.pow((g + 0.055) / 1.055, 2.4);
    const linearB = b <= 0.03928 ? b / 12.92 : Math.pow((b + 0.055) / 1.055, 2.4);
    const luminance = 0.2126 * linearR + 0.7152 * linearG + 0.0722 * linearB;
    return luminance > 0.35 ? '#1F2329' : '#FFFFFF';
  }

  /**
   * 强调色色块上的文字颜色：强调色偏亮（如深色模式的 #AAB2BD）时返回深色文字，
   * 否则返回白色。页面通过 onAccentColor() 包装方法消费。
   */
  static onAccentTextColor(darkMode: boolean): string {
    return ThemeRuntime.readableTextColorOn(ThemeRuntime.accentColor(darkMode));
  }

  /**
   * 全屏模态遮罩统一 token：弹层/对话框遮罩一律用它，
   * 取代散落在各页面的 #80000000 / #78000000 / #99000000 等多种硬编码遮罩。
   * 轻量级半透明提示层（如 TTS 面板后透出内容）不适用本 token。
   */
  static scrimColor(darkMode: boolean): string {
    return darkMode ? '#99000000' : '#80000000';
  }

  static glassPanelColor(darkMode: boolean, baseColor: string = '', surface: string = 'panel'): string {
    const fallback = ThemeRuntime.cardColor(darkMode);
    const color = ThemeRuntime.normalizeColor(baseColor || fallback, fallback);
    if (!ThemeRuntime.glassEnabled()) {
      return color;
    }
    const glass = ThemeRuntime.currentGlass();
    const opacity = ThemeRuntime.usesThemeGlassDefaults() ?
      (darkMode ? glass.darkTintOpacity : glass.lightTintOpacity) :
      ThemeRuntime.numberFromStorage(darkMode ? ThemeRuntime.KEY_GLASS_DARK_TINT_OPACITY :
        ThemeRuntime.KEY_GLASS_LIGHT_TINT_OPACITY, darkMode ? 78 : 85, 0, 100);
    return `#${ThemeRuntime.opacityHex(opacity)}${color.substring(1)}`;
  }

  static dropdownPanelColor(darkMode: boolean, baseColor: string = '', surface: string = 'popover'): string {
    const fallback = ThemeRuntime.cardColor(darkMode);
    const color = ThemeRuntime.normalizeColor(baseColor || fallback, fallback);
    if (!ThemeRuntime.glassEnabled()) {
      return color;
    }
    const glass = ThemeRuntime.currentGlass();
    const panelOpacity = ThemeRuntime.usesThemeGlassDefaults() ?
      (darkMode ? glass.darkTintOpacity : glass.lightTintOpacity) :
      ThemeRuntime.numberFromStorage(darkMode ? ThemeRuntime.KEY_GLASS_DARK_TINT_OPACITY :
        ThemeRuntime.KEY_GLASS_LIGHT_TINT_OPACITY, darkMode ? 78 : 85, 0, 100);
    return `#${ThemeRuntime.opacityHex(Math.round(panelOpacity * 0.47))}${color.substring(1)}`;
  }

  static glassBorderColor(darkMode: boolean, surface: string = 'panel'): string {
    const glass = ThemeRuntime.currentGlass();
    const opacity = ThemeRuntime.usesThemeGlassDefaults() ?
      (darkMode ? glass.darkBorderOpacity : glass.lightBorderOpacity) :
      ThemeRuntime.numberFromStorage(darkMode ? ThemeRuntime.KEY_GLASS_DARK_BORDER_OPACITY :
        ThemeRuntime.KEY_GLASS_LIGHT_BORDER_OPACITY, darkMode ? 22 : 65, 0, 100);
    return `#${ThemeRuntime.opacityHex(opacity)}FFFFFF`;
  }

  static glassShadowColor(darkMode: boolean, surface: string = 'panel'): string {
    if (!ThemeRuntime.glassShadowEnabled()) {
      return '#00000000';
    }
    const glass = ThemeRuntime.currentGlass();
    const opacity = ThemeRuntime.usesThemeGlassDefaults() ?
      (darkMode ? glass.darkShadowOpacity : glass.lightShadowOpacity) :
      ThemeRuntime.numberFromStorage(darkMode ? ThemeRuntime.KEY_GLASS_DARK_SHADOW_OPACITY :
        ThemeRuntime.KEY_GLASS_LIGHT_SHADOW_OPACITY, darkMode ? 44 : 17, 0, 100);
    return `#${ThemeRuntime.opacityHex(opacity)}000000`;
  }

  static glassEnabled(): boolean {
    return ThemeRuntime.currentGlass().enabled &&
      (AppStorage.get<boolean>(ThemeRuntime.KEY_GLASS_ENABLED) ?? true) &&
      !(AppStorage.get<boolean>(ThemeRuntime.KEY_GLASS_LOW_PERFORMANCE) ?? false);
  }

  static glassShadowEnabled(surface: string = 'panel'): boolean {
    return ThemeRuntime.glassEnabled() &&
      ThemeRuntime.currentGlass().shadowEnabled &&
      (AppStorage.get<boolean>(ThemeRuntime.KEY_GLASS_SHADOW_ENABLED) ?? true);
  }

  static glassBlur(surface: string = 'panel', fallback: number = 22): number {
    if (!ThemeRuntime.glassEnabled()) {
      return 0;
    }
    if (ThemeRuntime.usesThemeGlassDefaults()) {
      const glass = ThemeRuntime.currentGlass();
      return ThemeRuntime.clampNumber(ThemeRuntime.glassSurface(glass, surface).blurRadius * glass.materialScale,
        0, 40);
    }
    return ThemeRuntime.numberFromStorage(ThemeRuntime.glassBlurStorageKey(surface), fallback, 0, 40);
  }

  static glassBorderWidth(surface: string = 'panel'): number {
    if (ThemeRuntime.usesThemeGlassDefaults()) {
      return ThemeRuntime.clampNumber(ThemeRuntime.currentGlass().borderWidth, 0, 2);
    }
    return ThemeRuntime.numberFromStorage(ThemeRuntime.KEY_GLASS_BORDER_WIDTH, 1, 0, 2);
  }

  static glassCornerRadius(fallback: number = 16, surface: string = 'panel'): number {
    if (ThemeRuntime.usesThemeGlassDefaults()) {
      return ThemeRuntime.clampNumber(ThemeRuntime.glassSurface(ThemeRuntime.currentGlass(), surface).cornerRadius,
        0, 32);
    }
    return ThemeRuntime.numberFromStorage(ThemeRuntime.KEY_GLASS_CORNER_RADIUS, fallback, 0, 32);
  }

  static glassShadowRadius(surface: string = 'panel'): number {
    if (!ThemeRuntime.glassShadowEnabled()) {
      return 0;
    }
    if (ThemeRuntime.usesThemeGlassDefaults()) {
      return ThemeRuntime.clampNumber(ThemeRuntime.currentGlass().shadowRadius, 0, 30);
    }
    return ThemeRuntime.numberFromStorage(ThemeRuntime.KEY_GLASS_SHADOW_RADIUS, 18, 0, 30);
  }

  static glassShadowOffsetX(surface: string = 'panel'): number {
    if (ThemeRuntime.usesThemeGlassDefaults()) {
      return ThemeRuntime.clampNumber(ThemeRuntime.currentGlass().shadowOffsetX, -12, 12);
    }
    return ThemeRuntime.numberFromStorage(ThemeRuntime.KEY_GLASS_SHADOW_OFFSET_X, 0, -12, 12);
  }

  static glassShadowOffsetY(surface: string = 'panel'): number {
    if (ThemeRuntime.usesThemeGlassDefaults()) {
      return ThemeRuntime.clampNumber(ThemeRuntime.currentGlass().shadowOffsetY, -12, 12);
    }
    return ThemeRuntime.numberFromStorage(ThemeRuntime.KEY_GLASS_SHADOW_OFFSET_Y, 6, -12, 12);
  }

  private static numberFromStorage(key: string, fallback: number, min: number, max: number): number {
    const value = AppStorage.get<number>(key) ?? fallback;
    return Math.max(min, Math.min(max, value));
  }

  private static clampNumber(value: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, value));
  }

  private static usesThemeGlassDefaults(): boolean {
    const preset = (AppStorage.get<string>('glassPreset') || 'standard').trim().toLowerCase();
    return preset === 'standard';
  }

  private static currentGlass(): ThemeGlassTokens {
    if (ThemeRuntime.currentThemeId() === ThemeIds.CUSTOM) {
      return ThemeRuntime.customSourceTheme('glass').glass || new ThemeGlassTokens();
    }
    return ThemeRuntime.currentPack().glass || new ThemeGlassTokens();
  }

  private static glassSurface(glass: ThemeGlassTokens, surface: string): ThemeGlassSurfaceTokens {
    const normalized = (surface || '').trim().toLowerCase();
    if (normalized === 'popover') return glass.popover;
    if (normalized === 'button') return glass.button;
    if (normalized === 'overlay') return glass.overlay;
    if (normalized === 'menu') return glass.menu;
    return glass.panel;
  }

  private static glassBlurStorageKey(surface: string): string {
    const normalized = (surface || '').trim().toLowerCase();
    if (normalized === 'popover') return ThemeRuntime.KEY_GLASS_POPOVER_BLUR;
    if (normalized === 'button') return ThemeRuntime.KEY_GLASS_BUTTON_BLUR;
    if (normalized === 'overlay') return ThemeRuntime.KEY_GLASS_OVERLAY_BLUR;
    if (normalized === 'menu') return ThemeRuntime.KEY_GLASS_MENU_BLUR;
    return ThemeRuntime.KEY_GLASS_PANEL_BLUR;
  }

  private static opacityHex(opacity: number): string {
    const value = Math.max(0, Math.min(255, Math.round(opacity * 2.55)));
    return value.toString(16).padStart(2, '0').toUpperCase();
  }

  static buttonColor(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).colors.buttonColor;
    return ThemeRuntime.colorFromStorage(darkMode ? ThemeRuntime.KEY_DARK_BUTTON_COLOR :
      ThemeRuntime.KEY_LIGHT_BUTTON_COLOR, fallback);
  }

  static dangerColor(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).colors.dangerColor;
    return ThemeRuntime.colorFromStorage(darkMode ? ThemeRuntime.KEY_DARK_DANGER_COLOR :
      ThemeRuntime.KEY_LIGHT_DANGER_COLOR, fallback);
  }

  /**
   * 成功/生效态（替换规则命中、校验通过等）。
   * 与 dangerColor 完全同一套机制：主题包按浅色/深色分别给值，可被自定义主题覆盖。
   */
  static successColor(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).colors.successColor;
    return ThemeRuntime.colorFromStorage(darkMode ? ThemeRuntime.KEY_DARK_SUCCESS_COLOR :
      ThemeRuntime.KEY_LIGHT_SUCCESS_COLOR, fallback);
  }

  /**
   * 警示/待确认态（规则部分匹配、云同步"确认中"等）。
   * 同 successColor，按模式分别取值。
   */
  static warningColor(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).colors.warningColor;
    return ThemeRuntime.colorFromStorage(darkMode ? ThemeRuntime.KEY_DARK_WARNING_COLOR :
      ThemeRuntime.KEY_LIGHT_WARNING_COLOR, fallback);
  }

  static fontFamily(): string {
    if (ThemeRuntime.currentThemeId() === ThemeIds.CUSTOM) {
      return ThemeRuntime.customSourceTheme('typography').typography.appFontFamily || 'sans-serif';
    }
    const fallback = ThemeRuntime.currentPack().typography.appFontFamily || 'sans-serif';
    return ThemeRuntime.storageString(ThemeRuntime.KEY_FONT_FAMILY, fallback);
  }

  static iconPackId(): string {
    if (ThemeRuntime.currentThemeId() === ThemeIds.CUSTOM) {
      return ThemeRuntime.customSourceTheme('navigation').navigation.iconPackId || 'classic';
    }
    const fallback = ThemeRuntime.currentPack().navigation.iconPackId || 'classic';
    return ThemeRuntime.storageString(ThemeRuntime.KEY_ICON_PACK_ID, fallback);
  }

  static readerLayout(darkMode: boolean = AppStorage.get<boolean>('appDarkMode') || false): ThemeReaderLayoutTokens {
    if (ThemeRuntime.currentThemeId() === ThemeIds.CUSTOM) {
      // Layout is a theme-level preference. Color mode may change the reader
      // surface, but must not switch font size, spacing or page margins.
      return ThemeRuntime.customSourceTheme('layout', false).readerLayout;
    }
    return ThemeRuntime.currentPack().readerLayout;
  }

  static readerBackgroundColor(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).reader.backgroundColor;
    return ThemeRuntime.colorFromStorage(darkMode ? ThemeRuntime.KEY_DARK_READER_BACKGROUND_COLOR :
      ThemeRuntime.KEY_LIGHT_READER_BACKGROUND_COLOR, fallback);
  }

  static readerBackgroundAssetId(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).reader.backgroundAssetId;
    return ThemeRuntime.storageStringAllowEmpty(darkMode ? ThemeRuntime.KEY_DARK_READER_BACKGROUND_ASSET_ID :
      ThemeRuntime.KEY_LIGHT_READER_BACKGROUND_ASSET_ID, fallback);
  }

  static readerBackgroundImageAssetId(darkMode: boolean): string {
    return ThemeRuntime.readerBackgroundAssetId(darkMode);
  }

  static readerBackgroundImageFit(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).reader.backgroundImageFit || 'cover';
    const stored = ThemeRuntime.storageString(darkMode ? ThemeRuntime.KEY_DARK_READER_BACKGROUND_IMAGE_FIT :
      ThemeRuntime.KEY_LIGHT_READER_BACKGROUND_IMAGE_FIT, fallback);
    return ThemeRuntime.normalizeImageFit(stored, fallback);
  }

  static readerTextColor(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).reader.textColor;
    return ThemeRuntime.colorFromStorage(darkMode ? ThemeRuntime.KEY_DARK_READER_TEXT_COLOR :
      ThemeRuntime.KEY_LIGHT_READER_TEXT_COLOR, fallback);
  }

  static readerSubTextColor(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).reader.subTextColor;
    return ThemeRuntime.colorFromStorage(darkMode ? ThemeRuntime.KEY_DARK_READER_SUB_TEXT_COLOR :
      ThemeRuntime.KEY_LIGHT_READER_SUB_TEXT_COLOR, fallback);
  }

  static readerContentTone(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).reader.contentTone;
    const stored = ThemeRuntime.storageString(darkMode ? ThemeRuntime.KEY_DARK_READER_CONTENT_TONE :
      ThemeRuntime.KEY_LIGHT_READER_CONTENT_TONE, fallback);
    return ThemeRuntime.normalizeContentTone(stored, fallback);
  }

  static regexEmphasisMode(): string {
    return ThemeRuntime.regexEmphasisModeFor(AppStorage.get<boolean>('appDarkMode') ?? false);
  }

  static regexEmphasisModeFor(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).regexEmphasis.emphasisMode;
    const stored = ThemeRuntime.storageString(darkMode ? ThemeRuntime.KEY_DARK_REGEX_EMPHASIS_MODE :
      ThemeRuntime.KEY_LIGHT_REGEX_EMPHASIS_MODE, fallback);
    return ThemeRuntime.normalizeEmphasisMode(stored, fallback);
  }

  static regexBubbleStyle(): string {
    return ThemeRuntime.regexBubbleStyleFor(AppStorage.get<boolean>('appDarkMode') ?? false);
  }

  static regexBubbleStyleFor(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).regexEmphasis.bubbleStyle;
    const stored = ThemeRuntime.storageString(darkMode ? ThemeRuntime.KEY_DARK_REGEX_BUBBLE_STYLE :
      ThemeRuntime.KEY_LIGHT_REGEX_BUBBLE_STYLE, fallback);
    return ThemeRuntime.normalizeBubbleStyle(stored, fallback);
  }

  static regexEmphasisColor(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).regexEmphasis.emphasisColor;
    return ThemeRuntime.colorFromStorage(darkMode ? ThemeRuntime.KEY_DARK_REGEX_EMPHASIS_COLOR :
      ThemeRuntime.KEY_LIGHT_REGEX_EMPHASIS_COLOR, fallback);
  }

  static regexEmphasisTextColor(darkMode: boolean): string {
    const fallback = ThemeRuntime.fallbackVariant(darkMode).regexEmphasis.emphasisTextColor;
    return ThemeRuntime.colorFromStorage(darkMode ? ThemeRuntime.KEY_DARK_REGEX_EMPHASIS_TEXT_COLOR :
      ThemeRuntime.KEY_LIGHT_REGEX_EMPHASIS_TEXT_COLOR, fallback);
  }

  static smallRadius(): number {
    if (ThemeRuntime.currentThemeId() === ThemeIds.CUSTOM) {
      return ThemeRuntime.customSourceTheme('radius').radius.small;
    }
    return ThemeRuntime.radiusFromStorage(ThemeRuntime.KEY_RADIUS_SMALL, ThemeRuntime.currentPack().radius.small);
  }

  static mediumRadius(): number {
    if (ThemeRuntime.currentThemeId() === ThemeIds.CUSTOM) {
      return ThemeRuntime.customSourceTheme('radius').radius.medium;
    }
    return ThemeRuntime.radiusFromStorage(ThemeRuntime.KEY_RADIUS_MEDIUM, ThemeRuntime.currentPack().radius.medium);
  }

  static largeRadius(): number {
    if (ThemeRuntime.currentThemeId() === ThemeIds.CUSTOM) {
      return ThemeRuntime.customSourceTheme('radius').radius.large;
    }
    return ThemeRuntime.radiusFromStorage(ThemeRuntime.KEY_RADIUS_LARGE, ThemeRuntime.currentPack().radius.large);
  }

  static cardRadius(): number {
    if (ThemeRuntime.currentThemeId() === ThemeIds.CUSTOM) {
      return ThemeRuntime.customSourceTheme('radius').radius.card;
    }
    return ThemeRuntime.radiusFromStorage(ThemeRuntime.KEY_RADIUS_CARD, ThemeRuntime.currentPack().radius.card);
  }

  static buttonRadius(): number {
    if (ThemeRuntime.currentThemeId() === ThemeIds.CUSTOM) {
      return ThemeRuntime.customSourceTheme('radius').radius.button;
    }
    return ThemeRuntime.radiusFromStorage(ThemeRuntime.KEY_RADIUS_BUTTON, ThemeRuntime.currentPack().radius.button);
  }

  static bubbleRadius(): number {
    if (ThemeRuntime.currentThemeId() === ThemeIds.CUSTOM) {
      return ThemeRuntime.customSourceTheme('radius').radius.bubble;
    }
    return ThemeRuntime.radiusFromStorage(ThemeRuntime.KEY_RADIUS_BUBBLE, ThemeRuntime.currentPack().radius.bubble);
  }

  private static publishVariant(darkMode: boolean, variant: ThemeVariant, fallback: ThemeVariant,
    accentOverride: string, buttonOverride: string): void {
    const pageColor = ThemeRuntime.normalizeColor(variant.colors.pageColor, fallback.colors.pageColor);
    const cardColor = ThemeRuntime.normalizeColor(variant.colors.cardColor, fallback.colors.cardColor);
    const inputColor = ThemeRuntime.normalizeColor(variant.colors.inputColor, fallback.colors.inputColor);
    const primaryTextColor = ThemeRuntime.normalizeColor(variant.colors.primaryTextColor,
      fallback.colors.primaryTextColor);
    const subTextColor = ThemeRuntime.normalizeColor(variant.colors.subTextColor, fallback.colors.subTextColor);
    const dividerColor = ThemeRuntime.normalizeColor(variant.colors.dividerColor, fallback.colors.dividerColor);
    const accentColor = ThemeRuntime.normalizeColor(accentOverride || variant.colors.accentColor,
      fallback.colors.accentColor);
    const buttonColor = ThemeRuntime.normalizeColor(buttonOverride || variant.colors.buttonColor,
      fallback.colors.buttonColor);
    const dangerColor = ThemeRuntime.normalizeColor(variant.colors.dangerColor, fallback.colors.dangerColor);
    const successColor = ThemeRuntime.normalizeColor(variant.colors.successColor, fallback.colors.successColor);
    const warningColor = ThemeRuntime.normalizeColor(variant.colors.warningColor, fallback.colors.warningColor);
    const readerBackgroundColor = ThemeRuntime.normalizeColor(variant.reader.backgroundColor,
      fallback.reader.backgroundColor);
    const readerTextColor = ThemeRuntime.normalizeColor(variant.reader.textColor, fallback.reader.textColor);
    const readerSubTextColor = ThemeRuntime.normalizeColor(variant.reader.subTextColor,
      fallback.reader.subTextColor);
    const regexColor = ThemeRuntime.normalizeColor(variant.regexEmphasis.emphasisColor,
      fallback.regexEmphasis.emphasisColor);
    const regexTextColor = ThemeRuntime.normalizeColor(variant.regexEmphasis.emphasisTextColor,
      fallback.regexEmphasis.emphasisTextColor);
    const regexMode = ThemeRuntime.normalizeEmphasisMode(variant.regexEmphasis.emphasisMode,
      fallback.regexEmphasis.emphasisMode);
    const bubbleStyle = ThemeRuntime.normalizeBubbleStyle(variant.regexEmphasis.bubbleStyle,
      fallback.regexEmphasis.bubbleStyle);

    if (darkMode) {
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_PAGE_COLOR, pageColor);
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_CARD_COLOR, cardColor);
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_INPUT_COLOR, inputColor);
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_PRIMARY_TEXT_COLOR, primaryTextColor);
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_SUB_TEXT_COLOR, subTextColor);
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_DIVIDER_COLOR, dividerColor);
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_ACCENT_COLOR, accentColor);
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_BUTTON_COLOR, buttonColor);
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_DANGER_COLOR, dangerColor);
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_SUCCESS_COLOR, successColor);
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_WARNING_COLOR, warningColor);
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_READER_BACKGROUND_COLOR, readerBackgroundColor);
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_READER_BACKGROUND_ASSET_ID,
        (variant.reader.backgroundAssetId || '').trim());
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_READER_BACKGROUND_IMAGE_FIT,
        ThemeRuntime.normalizeImageFit(variant.reader.backgroundImageFit, fallback.reader.backgroundImageFit));
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_READER_TEXT_COLOR, readerTextColor);
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_READER_SUB_TEXT_COLOR, readerSubTextColor);
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_READER_CONTENT_TONE,
        ThemeRuntime.normalizeContentTone(variant.reader.contentTone, fallback.reader.contentTone));
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_REGEX_EMPHASIS_MODE, regexMode);
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_REGEX_BUBBLE_STYLE, bubbleStyle);
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_REGEX_EMPHASIS_COLOR, regexColor);
      ThemeRuntime.setString(ThemeRuntime.KEY_DARK_REGEX_EMPHASIS_TEXT_COLOR, regexTextColor);
      AppStorage.setOrCreate('appDarkAccentColor', accentColor);
      AppStorage.setOrCreate('appDarkButtonColor', buttonColor);
      return;
    }

    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_PAGE_COLOR, pageColor);
    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_CARD_COLOR, cardColor);
    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_INPUT_COLOR, inputColor);
    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_PRIMARY_TEXT_COLOR, primaryTextColor);
    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_SUB_TEXT_COLOR, subTextColor);
    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_DIVIDER_COLOR, dividerColor);
    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_ACCENT_COLOR, accentColor);
    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_BUTTON_COLOR, buttonColor);
    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_DANGER_COLOR, dangerColor);
    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_SUCCESS_COLOR, successColor);
    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_WARNING_COLOR, warningColor);
    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_READER_BACKGROUND_COLOR, readerBackgroundColor);
    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_READER_BACKGROUND_ASSET_ID,
      (variant.reader.backgroundAssetId || '').trim());
    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_READER_BACKGROUND_IMAGE_FIT,
      ThemeRuntime.normalizeImageFit(variant.reader.backgroundImageFit, fallback.reader.backgroundImageFit));
    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_READER_TEXT_COLOR, readerTextColor);
    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_READER_SUB_TEXT_COLOR, readerSubTextColor);
    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_READER_CONTENT_TONE,
      ThemeRuntime.normalizeContentTone(variant.reader.contentTone, fallback.reader.contentTone));
    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_REGEX_EMPHASIS_MODE, regexMode);
    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_REGEX_BUBBLE_STYLE, bubbleStyle);
    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_REGEX_EMPHASIS_COLOR, regexColor);
    ThemeRuntime.setString(ThemeRuntime.KEY_LIGHT_REGEX_EMPHASIS_TEXT_COLOR, regexTextColor);
    AppStorage.setOrCreate('appLightAccentColor', accentColor);
    AppStorage.setOrCreate('appLightButtonColor', buttonColor);
  }

  private static currentPack(): ThemePack {
    const themeId = AppStorage.get<string>(ThemeRuntime.KEY_THEME_ID) || BuiltinThemeRegistry.DEFAULT_THEME_ID;
    if (themeId === ThemeIds.CUSTOM) {
      const baseThemeId = AppStorage.get<string>(ThemeRuntime.KEY_CUSTOM_BASE_THEME_ID) ||
        BuiltinThemeRegistry.DEFAULT_THEME_ID;
      return BuiltinThemeRegistry.customTheme(baseThemeId);
    }
    return BuiltinThemeRegistry.findById(themeId);
  }

  private static customSourceTheme(
    category: string,
    darkMode: boolean = AppStorage.get<boolean>('appDarkMode') || false
  ): ThemePack {
    const fallback = AppStorage.get<string>(ThemeRuntime.KEY_CUSTOM_BASE_THEME_ID) ||
      BuiltinThemeRegistry.DEFAULT_THEME_ID;
    const sources = ThemeRuntime.customSources(darkMode, fallback);
    let themeId = fallback;
    if (category === 'startup') themeId = sources.startupThemeId;
    else if (category === 'palette') themeId = sources.paletteThemeId;
    else if (category === 'reader') themeId = sources.readerThemeId;
    else if (category === 'bubble') themeId = sources.bubbleThemeId;
    else if (category === 'navigation') themeId = sources.navigationThemeId;
    else if (category === 'book') themeId = sources.bookThemeId;
    else if (category === 'typography') themeId = sources.typographyThemeId;
    else if (category === 'layout') themeId = sources.layoutThemeId;
    else if (category === 'radius') themeId = sources.radiusThemeId;
    else if (category === 'glass') themeId = sources.glassThemeId;
    return BuiltinThemeRegistry.findById(themeId);
  }

  private static customSources(darkMode: boolean, fallbackThemeId: string): ThemeComponentSourceIds {
    const fallback = BuiltinThemeRegistry.normalizeBuiltinId(fallbackThemeId);
    const raw = AppStorage.get<string>(darkMode ? ThemeRuntime.KEY_CUSTOM_DARK_SOURCES :
      ThemeRuntime.KEY_CUSTOM_LIGHT_SOURCES) || '';
    let source = new ThemeComponentSourceIds();
    if (raw) {
      try {
        source = JSON.parse(raw) as ThemeComponentSourceIds;
      } catch (_) {
        source = new ThemeComponentSourceIds();
      }
    }
    const normalized = new ThemeComponentSourceIds();
    normalized.startupThemeId = BuiltinThemeRegistry.normalizeBuiltinId(source.startupThemeId || fallback);
    normalized.paletteThemeId = BuiltinThemeRegistry.normalizeBuiltinId(source.paletteThemeId || fallback);
    normalized.readerThemeId = BuiltinThemeRegistry.normalizeBuiltinId(source.readerThemeId || fallback);
    normalized.bubbleThemeId = BuiltinThemeRegistry.normalizeBuiltinId(source.bubbleThemeId || fallback);
    normalized.navigationThemeId = BuiltinThemeRegistry.normalizeBuiltinId(source.navigationThemeId || fallback);
    normalized.bookThemeId = BuiltinThemeRegistry.normalizeBuiltinId(source.bookThemeId || fallback);
    normalized.typographyThemeId = BuiltinThemeRegistry.normalizeBuiltinId(source.typographyThemeId || fallback);
    normalized.layoutThemeId = BuiltinThemeRegistry.normalizeBuiltinId(source.layoutThemeId || fallback);
    normalized.radiusThemeId = BuiltinThemeRegistry.normalizeBuiltinId(source.radiusThemeId || fallback);
    normalized.glassThemeId = BuiltinThemeRegistry.normalizeBuiltinId(source.glassThemeId || fallback);
    return normalized;
  }

  private static fallbackVariant(darkMode: boolean): ThemeVariant {
    const theme = ThemeRuntime.currentPack();
    return darkMode ? theme.dark : theme.light;
  }

  private static normalizeColor(value: string, fallback: string): string {
    const text = (value || '').trim();
    if (/^#[0-9a-fA-F]{6}$/.test(text)) {
      return text.toUpperCase();
    }
    if (/^[0-9a-fA-F]{6}$/.test(text)) {
      return `#${text.toUpperCase()}`;
    }
    const fallbackText = (fallback || '').trim();
    return /^#[0-9a-fA-F]{6}$/.test(fallbackText) ? fallbackText.toUpperCase() : '#000000';
  }

  private static normalizeEmphasisMode(value: string, fallback: string): string {
    const mode = (value || '').trim();
    if (mode === ThemeRegexEmphasisModes.NONE || mode === ThemeRegexEmphasisModes.TEXT ||
      mode === ThemeRegexEmphasisModes.HIGHLIGHT || mode === ThemeRegexEmphasisModes.BUBBLE) {
      return mode;
    }
    const fallbackMode = (fallback || '').trim();
    if (fallbackMode === ThemeRegexEmphasisModes.NONE || fallbackMode === ThemeRegexEmphasisModes.TEXT ||
      fallbackMode === ThemeRegexEmphasisModes.HIGHLIGHT || fallbackMode === ThemeRegexEmphasisModes.BUBBLE) {
      return fallbackMode;
    }
    return ThemeRegexEmphasisModes.HIGHLIGHT;
  }

  private static normalizeBubbleStyle(value: string, fallback: string): string {
    const style = (value || '').trim();
    if (style === ThemeBubbleStyles.QQ_SOFT || style === ThemeBubbleStyles.QQ_SOLID ||
      style === ThemeBubbleStyles.CAPSULE || style === ThemeBubbleStyles.PAPER ||
      style === ThemeBubbleStyles.NEON || style === ThemeBubbleStyles.CLASSIC_GLASS ||
      style === ThemeBubbleStyles.WARM_SCROLL || style === ThemeBubbleStyles.FOREST_DEW ||
      style === ThemeBubbleStyles.INK_BRUSH || style === ThemeBubbleStyles.NEON_PULSE ||
      style === ThemeBubbleStyles.STRAWBERRY_RIBBON ||
      style === ThemeBubbleStyles.CRIMSON_STAMP || style === ThemeBubbleStyles.CELADON_SLIP ||
      style === ThemeBubbleStyles.ROSE_FRAME || style === ThemeBubbleStyles.MOON_HALO ||
      style === ThemeBubbleStyles.SWORD_TALISMAN || style === ThemeBubbleStyles.QINGLUAN_JADE ||
      style === ThemeBubbleStyles.PIPI_SOFT_PAW) {
      return style;
    }
    const fallbackStyle = (fallback || '').trim();
    if (fallbackStyle === ThemeBubbleStyles.QQ_SOFT || fallbackStyle === ThemeBubbleStyles.QQ_SOLID ||
      fallbackStyle === ThemeBubbleStyles.CAPSULE || fallbackStyle === ThemeBubbleStyles.PAPER ||
      fallbackStyle === ThemeBubbleStyles.NEON || fallbackStyle === ThemeBubbleStyles.CLASSIC_GLASS ||
      fallbackStyle === ThemeBubbleStyles.WARM_SCROLL || fallbackStyle === ThemeBubbleStyles.FOREST_DEW ||
      fallbackStyle === ThemeBubbleStyles.INK_BRUSH || fallbackStyle === ThemeBubbleStyles.NEON_PULSE ||
      fallbackStyle === ThemeBubbleStyles.STRAWBERRY_RIBBON ||
      fallbackStyle === ThemeBubbleStyles.CRIMSON_STAMP || fallbackStyle === ThemeBubbleStyles.CELADON_SLIP ||
      fallbackStyle === ThemeBubbleStyles.ROSE_FRAME || fallbackStyle === ThemeBubbleStyles.MOON_HALO ||
      fallbackStyle === ThemeBubbleStyles.SWORD_TALISMAN ||
      fallbackStyle === ThemeBubbleStyles.QINGLUAN_JADE ||
      fallbackStyle === ThemeBubbleStyles.PIPI_SOFT_PAW) {
      return fallbackStyle;
    }
    return ThemeBubbleStyles.QQ_SOFT;
  }

  private static normalizeContentTone(value: string, fallback: string): string {
    const tone = (value || '').trim();
    if (tone === 'light' || tone === 'dark') {
      return tone;
    }
    return fallback === 'dark' ? 'dark' : 'light';
  }

  private static normalizeImageFit(value: string, fallback: string): string {
    const fit = (value || '').trim();
    if (fit === 'cover' || fit === 'contain' || fit === 'fill') {
      return fit;
    }
    const fallbackFit = (fallback || '').trim();
    if (fallbackFit === 'cover' || fallbackFit === 'contain' || fallbackFit === 'fill') {
      return fallbackFit;
    }
    return 'cover';
  }

  private static normalizeRadius(value: number, fallback: number): number {
    if (!Number.isFinite(value)) {
      return Math.max(0, Math.min(Math.round(fallback), 48));
    }
    return Math.max(0, Math.min(Math.round(value), 48));
  }

  private static colorFromStorage(key: string, fallback: string): string {
    return ThemeRuntime.normalizeColor(ThemeRuntime.storageString(key, fallback), fallback);
  }

  private static radiusFromStorage(key: string, fallback: number): number {
    return ThemeRuntime.normalizeRadius(AppStorage.get<number>(key) ?? fallback, fallback);
  }

  private static storageString(key: string, fallback: string): string {
    const value = AppStorage.get<string>(key);
    return value === undefined || !value ? fallback : value;
  }

  private static storageStringAllowEmpty(key: string, fallback: string): string {
    const value = AppStorage.get<string>(key);
    return value === undefined ? fallback : value;
  }

  private static setString(key: string, value: string): void {
    AppStorage.setOrCreate(key, value);
  }

  private static setNumber(key: string, value: number): void {
    AppStorage.setOrCreate(key, value);
  }
}
