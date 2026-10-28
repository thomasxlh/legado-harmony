import { ThemeIds } from './ThemeModels';

export class ThemeAssetRegistry {
  static readonly ICON_PACK_CLASSIC: string = 'classic';

  static readonly TAB_BOOKSHELF: string = 'bookshelf';
  static readonly TAB_EXPLORE: string = 'explore';
  static readonly TAB_SEARCH: string = 'search';
  static readonly TAB_MINE: string = 'mine';

  static readerBackground(_assetId: string): ResourceStr {
    return '';
  }

  static readerBackgroundDecoration(_assetId: string): ResourceStr {
    return '';
  }

  static readerBackgroundTrailingDecoration(_assetId: string): ResourceStr {
    return '';
  }

  static readerBackgroundTrailingRotation(_assetId: string): number {
    return 180;
  }

  static readerBackgroundBorderColor(_assetId: string): string {
    return '';
  }

  static readerBackgroundBorderWidth(_assetId: string): number {
    return 1;
  }

  static navigationIcon(_iconPackId: string, tabId: string): Resource {
    return ThemeAssetRegistry.classicNavigationIcon(ThemeAssetRegistry.normalizeTabId(tabId));
  }

  static themeLogo(themeId: string): Resource {
    switch ((themeId || '').trim().toLowerCase()) {
      case ThemeIds.CUSTOM:
        return $r('app.media.theme_logo_custom');
      default:
        return $r('app.media.theme_logo_plain_default');
    }
  }

  static regexBubbleFrame(styleId: string): ResourceStr {
    switch ((styleId || '').trim().toLowerCase()) {
      case 'classic-glass': return $r('app.media.regex_frame_classic_glass');
      case 'warm-scroll': return $r('app.media.regex_frame_warm_scroll');
      case 'forest-dew': return $r('app.media.regex_frame_forest_dew');
      case 'ink-brush': return $r('app.media.regex_frame_ink_brush');
      case 'neon-pulse': return $r('app.media.regex_frame_neon_pulse');
      case 'strawberry-ribbon': return $r('app.media.regex_frame_strawberry_ribbon');
      case 'crimson-stamp': return $r('app.media.regex_frame_crimson_stamp');
      case 'celadon-slip': return $r('app.media.regex_frame_celadon_slip');
      case 'rose-frame': return $r('app.media.regex_frame_rose_letter');
      case 'moon-halo': return $r('app.media.regex_frame_moon_halo');
      case 'sword-talisman': return $r('app.media.regex_frame_sword_talisman');
      case 'qingluan-jade': return $r('app.media.regex_frame_qingluan_jade');
      case 'pipi-soft-paw': return $r('app.media.regex_frame_pipi_soft_paw');
      default: return '';
    }
  }

  static hasRegexBubbleFrame(styleId: string): boolean {
    return !!ThemeAssetRegistry.regexBubbleFrame(styleId);
  }

  static regexBubbleCap(styleId: string): ResourceStr {
    switch ((styleId || '').trim().toLowerCase()) {
      case 'classic-glass': return $r('app.media.regex_cap_classic_glass');
      case 'warm-scroll': return $r('app.media.regex_cap_warm_scroll');
      case 'forest-dew': return $r('app.media.regex_cap_forest_dew');
      case 'ink-brush': return $r('app.media.regex_cap_ink_brush');
      case 'neon-pulse': return $r('app.media.regex_cap_neon_pulse');
      case 'strawberry-ribbon': return $r('app.media.regex_cap_strawberry_ribbon');
      case 'crimson-stamp': return $r('app.media.regex_cap_crimson_stamp');
      case 'celadon-slip': return $r('app.media.regex_cap_celadon_slip');
      case 'rose-frame': return $r('app.media.regex_cap_rose_letter');
      case 'moon-halo': return $r('app.media.regex_cap_moon_halo');
      case 'sword-talisman': return $r('app.media.regex_cap_sword_talisman');
      case 'qingluan-jade': return $r('app.media.regex_cap_qingluan_jade');
      case 'pipi-soft-paw': return $r('app.media.regex_cap_pipi_soft_paw');
      default: return '';
    }
  }

  static hasRegexBubbleCap(styleId: string): boolean {
    return !!ThemeAssetRegistry.regexBubbleCap(styleId);
  }

  static normalizeBackgroundAssetId(_assetId: string): string {
    return '';
  }

  static normalizeIconPackId(_iconPackId: string): string {
    return ThemeAssetRegistry.ICON_PACK_CLASSIC;
  }

  static normalizeTabId(tabId: string): string {
    const normalized = (tabId || '').trim().toLowerCase();
    if (normalized === ThemeAssetRegistry.TAB_EXPLORE ||
      normalized === ThemeAssetRegistry.TAB_SEARCH ||
      normalized === ThemeAssetRegistry.TAB_MINE) {
      return normalized;
    }
    return ThemeAssetRegistry.TAB_BOOKSHELF;
  }

  private static classicNavigationIcon(tabId: string): Resource {
    switch (tabId) {
      case ThemeAssetRegistry.TAB_EXPLORE:
        return $r('app.media.ic_tab_explore');
      case ThemeAssetRegistry.TAB_SEARCH:
        return $r('app.media.ic_tab_search');
      case ThemeAssetRegistry.TAB_MINE:
        return $r('app.media.ic_tab_mine');
      default:
        return $r('app.media.ic_tab_bookshelf');
    }
  }
}
