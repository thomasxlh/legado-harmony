import {
  ThemeBubbleStyles,
  ThemeColorTokens,
  ThemeGlassTokens,
  ThemeIds,
  ThemePack,
  ThemeRadiusTokens,
  ThemeReaderLayoutTokens,
  ThemeReaderTokens,
  ThemeRegexEmphasisModes,
  ThemeRegexEmphasisTokens,
  ThemeVariant
} from './ThemeModels';

export class BuiltinThemeRegistry {
  static readonly DEFAULT_THEME_ID: string = ThemeIds.PLAIN_DEFAULT;
  static readonly THEMES: ThemePack[] = BuiltinThemeRegistry.createThemes();

  static all(): ThemePack[] {
    const result: ThemePack[] = [];
    for (const theme of BuiltinThemeRegistry.THEMES) {
      result.push(BuiltinThemeRegistry.cloneTheme(theme));
    }
    return result;
  }

  static findById(themeId: string): ThemePack {
    const normalized = (themeId || '').trim();
    if (normalized === ThemeIds.CUSTOM) {
      return BuiltinThemeRegistry.customTheme();
    }
    for (const theme of BuiltinThemeRegistry.THEMES) {
      if (theme.id === normalized) {
        return BuiltinThemeRegistry.cloneTheme(theme);
      }
    }
    for (const theme of BuiltinThemeRegistry.THEMES) {
      if (theme.id === BuiltinThemeRegistry.DEFAULT_THEME_ID) {
        return BuiltinThemeRegistry.cloneTheme(theme);
      }
    }
    return BuiltinThemeRegistry.cloneTheme(BuiltinThemeRegistry.THEMES[0]);
  }

  static normalizeId(themeId: string): string {
    const normalized = (themeId || '').trim();
    if (normalized === ThemeIds.CUSTOM) {
      return ThemeIds.CUSTOM;
    }
    for (const theme of BuiltinThemeRegistry.THEMES) {
      if (theme.id === normalized) {
        return normalized;
      }
    }
    return BuiltinThemeRegistry.DEFAULT_THEME_ID;
  }

  static has(themeId: string): boolean {
    const normalized = (themeId || '').trim();
    if (normalized === ThemeIds.CUSTOM) {
      return true;
    }
    for (const theme of BuiltinThemeRegistry.THEMES) {
      if (theme.id === normalized) {
        return true;
      }
    }
    return false;
  }

  static isFree(themeId: string): boolean {
    const normalized = (themeId || '').trim();
    return normalized === ThemeIds.PLAIN_DEFAULT || normalized === BuiltinThemeRegistry.DEFAULT_THEME_ID;
  }

  static normalizeBuiltinId(themeId: string): string {
    const normalized = (themeId || '').trim();
    for (const theme of BuiltinThemeRegistry.THEMES) {
      if (theme.id === normalized) {
        return normalized;
      }
    }
    return BuiltinThemeRegistry.DEFAULT_THEME_ID;
  }

  static customTheme(baseThemeId: string = ''): ThemePack {
    const theme = BuiltinThemeRegistry.findById(BuiltinThemeRegistry.normalizeBuiltinId(baseThemeId));
    theme.id = ThemeIds.CUSTOM;
    theme.name = '自定义主题';
    theme.description = '按浅色与深色模式分别设置启动封面与配色';
    return theme;
  }

  /** Registers a compiled-in theme pack. Reusing an id replaces the previous pack. */
  static register(theme: ThemePack): boolean {
    const themeId = (theme.id || '').trim();
    if (!themeId || !theme.light || !theme.dark) {
      return false;
    }
    theme.id = themeId;
    for (let index = 0; index < BuiltinThemeRegistry.THEMES.length; index++) {
      if (BuiltinThemeRegistry.THEMES[index].id === themeId) {
        BuiltinThemeRegistry.THEMES[index] = BuiltinThemeRegistry.cloneTheme(theme);
        return true;
      }
    }
    BuiltinThemeRegistry.THEMES.push(BuiltinThemeRegistry.cloneTheme(theme));
    return true;
  }

  static registerAll(themes: ThemePack[]): number {
    let registered = 0;
    for (const theme of themes) {
      if (BuiltinThemeRegistry.register(theme)) {
        registered++;
      }
    }
    return registered;
  }

  private static createThemes(): ThemePack[] {
    const themes: ThemePack[] = [];
    themes.push(BuiltinThemeRegistry.plainDefault());
    return themes;
  }

  private static plainDefault(): ThemePack {
    const theme = BuiltinThemeRegistry.theme(
      ThemeIds.PLAIN_DEFAULT,
      '默认主题',
      '无纹理、低装饰、清晰耐看的基础主题',
      'sans-serif',
      'classic'
    );
    theme.light = BuiltinThemeRegistry.variant(
      BuiltinThemeRegistry.colors('#F7F7F7', '#FFFFFF', '#F0F0F0', '#202124', '#73777F', '#E2E2E2',
        '#5B6573', '#505967', '#C93F3F'),
      BuiltinThemeRegistry.reader('#FAFAFA', '', '#262626', '#777777', 'light'),
      BuiltinThemeRegistry.regex(ThemeBubbleStyles.CAPSULE, '#E7E9EC', '#34383D')
    );
    theme.dark = BuiltinThemeRegistry.variant(
      BuiltinThemeRegistry.colors('#111111', '#1B1B1B', '#262626', '#F0F0F0', '#A0A0A0', '#343434',
        '#AAB2BD', '#737D8A', '#E86A6A'),
      BuiltinThemeRegistry.reader('#161616', '', '#E1E1E1', '#9A9A9A', 'dark'),
      BuiltinThemeRegistry.regex(ThemeBubbleStyles.CAPSULE, '#34383D', '#E4E7EB')
    );
    theme.radius = BuiltinThemeRegistry.radius(4, 8, 12, 8, 16, 8);
    theme.readerLayout = BuiltinThemeRegistry.readerLayout(20, 12, 0, 18, 18, 18, 18);
    return theme;
  }

  private static theme(id: string, name: string, description: string, fontFamily: string,
    iconPackId: string): ThemePack {
    const theme = new ThemePack();
    theme.schemaVersion = 3;
    theme.id = id;
    theme.name = name;
    theme.description = description;
    theme.typography.appFontFamily = fontFamily;
    theme.navigation.iconPackId = iconPackId;
    theme.startup.styleId = id;
    return theme;
  }

  private static readerLayout(fontSize: number, lineHeight: number, paragraphSpacing: number,
    marginLeft: number, marginRight: number, marginTop: number, marginBottom: number,
    letterSpacing: number = 0): ThemeReaderLayoutTokens {
    const layout = new ThemeReaderLayoutTokens();
    layout.fontSize = fontSize;
    layout.letterSpacing = letterSpacing;
    layout.lineHeight = lineHeight;
    layout.paragraphSpacing = paragraphSpacing;
    layout.marginLeft = marginLeft;
    layout.marginRight = marginRight;
    layout.marginTop = marginTop;
    layout.marginBottom = marginBottom;
    return layout;
  }

  private static colors(pageColor: string, cardColor: string, inputColor: string, primaryTextColor: string,
    subTextColor: string, dividerColor: string, accentColor: string, buttonColor: string,
    dangerColor: string, successColor: string = '', warningColor: string = ''): ThemeColorTokens {
    const colors = new ThemeColorTokens();
    colors.pageColor = pageColor;
    colors.cardColor = cardColor;
    colors.inputColor = inputColor;
    colors.primaryTextColor = primaryTextColor;
    colors.subTextColor = subTextColor;
    colors.dividerColor = dividerColor;
    colors.accentColor = accentColor;
    colors.buttonColor = buttonColor;
    colors.dangerColor = dangerColor;
    // 成功/警示色是后补的语义 token：主题未逐包指定时沿用 token 默认值，
    // 需要区分时可显式传入（与 dangerColor 同一约定）。
    if (successColor) {
      colors.successColor = successColor;
    }
    if (warningColor) {
      colors.warningColor = warningColor;
    }
    return colors;
  }

  private static reader(backgroundColor: string, backgroundAssetId: string, textColor: string,
    subTextColor: string, contentTone: string): ThemeReaderTokens {
    const reader = new ThemeReaderTokens();
    reader.backgroundColor = backgroundColor;
    reader.backgroundAssetId = backgroundAssetId;
    reader.backgroundImageFit = 'cover';
    reader.textColor = textColor;
    reader.subTextColor = subTextColor;
    reader.contentTone = contentTone;
    return reader;
  }

  private static regex(bubbleStyle: string, emphasisColor: string,
    emphasisTextColor: string): ThemeRegexEmphasisTokens {
    const regex = new ThemeRegexEmphasisTokens();
    regex.emphasisMode = ThemeRegexEmphasisModes.BUBBLE;
    regex.bubbleStyle = bubbleStyle;
    regex.emphasisColor = emphasisColor;
    regex.emphasisTextColor = emphasisTextColor;
    return regex;
  }

  private static variant(colors: ThemeColorTokens, reader: ThemeReaderTokens,
    regexEmphasis: ThemeRegexEmphasisTokens): ThemeVariant {
    const variant = new ThemeVariant();
    variant.colors = colors;
    variant.reader = reader;
    variant.regexEmphasis = regexEmphasis;
    return variant;
  }

  private static radius(small: number, medium: number, large: number, card: number, button: number,
    bubble: number): ThemeRadiusTokens {
    const radius = new ThemeRadiusTokens();
    radius.small = small;
    radius.medium = medium;
    radius.large = large;
    radius.card = card;
    radius.button = button;
    radius.bubble = bubble;
    return radius;
  }

  private static cloneTheme(source: ThemePack): ThemePack {
    const theme = new ThemePack();
    theme.schemaVersion = source.schemaVersion;
    theme.id = source.id;
    theme.name = source.name;
    theme.description = source.description;
    theme.light = BuiltinThemeRegistry.cloneVariant(source.light);
    theme.dark = BuiltinThemeRegistry.cloneVariant(source.dark);
    theme.typography.appFontFamily = source.typography.appFontFamily;
    theme.readerLayout = BuiltinThemeRegistry.readerLayout(source.readerLayout.fontSize,
      source.readerLayout.lineHeight, source.readerLayout.paragraphSpacing, source.readerLayout.marginLeft,
      source.readerLayout.marginRight, source.readerLayout.marginTop, source.readerLayout.marginBottom,
      source.readerLayout.letterSpacing);
    theme.navigation.iconPackId = source.navigation.iconPackId;
    theme.startup.styleId = source.startup.styleId;
    theme.radius = BuiltinThemeRegistry.radius(source.radius.small, source.radius.medium, source.radius.large,
      source.radius.card, source.radius.button, source.radius.bubble);
    theme.glass = BuiltinThemeRegistry.cloneGlass(source.glass || new ThemeGlassTokens());
    return theme;
  }

  private static cloneGlass(source: ThemeGlassTokens): ThemeGlassTokens {
    const glass = new ThemeGlassTokens();
    glass.enabled = source.enabled;
    glass.panel.blurRadius = source.panel.blurRadius;
    glass.panel.cornerRadius = source.panel.cornerRadius;
    glass.popover.blurRadius = source.popover.blurRadius;
    glass.popover.cornerRadius = source.popover.cornerRadius;
    glass.button.blurRadius = source.button.blurRadius;
    glass.button.cornerRadius = source.button.cornerRadius;
    glass.overlay.blurRadius = source.overlay.blurRadius;
    glass.overlay.cornerRadius = source.overlay.cornerRadius;
    glass.menu.blurRadius = source.menu.blurRadius;
    glass.menu.cornerRadius = source.menu.cornerRadius;
    glass.lightTintOpacity = source.lightTintOpacity;
    glass.darkTintOpacity = source.darkTintOpacity;
    glass.lightBorderOpacity = source.lightBorderOpacity;
    glass.darkBorderOpacity = source.darkBorderOpacity;
    glass.borderWidth = source.borderWidth;
    glass.shadowEnabled = source.shadowEnabled;
    glass.lightShadowOpacity = source.lightShadowOpacity;
    glass.darkShadowOpacity = source.darkShadowOpacity;
    glass.shadowRadius = source.shadowRadius;
    glass.shadowOffsetX = source.shadowOffsetX;
    glass.shadowOffsetY = source.shadowOffsetY;
    glass.adaptiveColor = source.adaptiveColor;
    glass.materialScale = source.materialScale;
    return glass;
  }

  private static cloneVariant(source: ThemeVariant): ThemeVariant {
    return BuiltinThemeRegistry.variant(
      BuiltinThemeRegistry.colors(source.colors.pageColor, source.colors.cardColor, source.colors.inputColor,
        source.colors.primaryTextColor, source.colors.subTextColor, source.colors.dividerColor,
        source.colors.accentColor, source.colors.buttonColor, source.colors.dangerColor,
        source.colors.successColor, source.colors.warningColor),
      BuiltinThemeRegistry.reader(source.reader.backgroundColor, source.reader.backgroundAssetId,
        source.reader.textColor, source.reader.subTextColor, source.reader.contentTone),
      BuiltinThemeRegistry.regex(source.regexEmphasis.bubbleStyle, source.regexEmphasis.emphasisColor,
        source.regexEmphasis.emphasisTextColor)
    );
  }
}
