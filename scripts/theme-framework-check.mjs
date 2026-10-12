import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const etsRoot = path.join(root, 'entry', 'src', 'main', 'ets');
const mediaRoot = path.join(root, 'entry', 'src', 'main', 'resources', 'base', 'media');

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), 'utf8');
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const models = read('entry/src/main/ets/theme/ThemeModels.ets');
const registry = read('entry/src/main/ets/theme/BuiltinThemeRegistry.ets');
const runtime = read('entry/src/main/ets/theme/ThemeRuntime.ets');
const assets = read('entry/src/main/ets/theme/ThemeAssetRegistry.ets');
const readerThemes = read('entry/src/main/ets/utils/ReaderThemeHelper.ets');
const regexModel = read('entry/src/main/ets/model/reader/ReaderRegexFontRule.ets');
const regexSettings = read('entry/src/main/ets/pages/ReaderFontSettings.ets');
const reader = read('entry/src/main/ets/pages/ReadBook.ets');
const readerBackgroundComponent = read('entry/src/main/ets/components/ReaderThemeBackground.ets');
const indexPage = read('entry/src/main/ets/pages/Index.ets');
const bookModel = read('entry/src/main/ets/model/data/Book.ts');
const themePage = read('entry/src/main/ets/pages/ThemeSettings.ets');
const readerSettingsPage = read('entry/src/main/ets/pages/Settings.ets');
const ttsSettingsPage = read('entry/src/main/ets/pages/TtsSettings.ets');
const themeStore = read('entry/src/main/ets/utils/AppThemeSettingsStore.ets');
const readerStore = read('entry/src/main/ets/utils/ReaderSettingsStore.ets');
const moduleConfig = read('entry/src/main/module.json5');
const bookshelfSortHelper = read('entry/src/main/ets/utils/BookshelfSortHelper.ets');
const recentReadCardData = read('entry/src/main/ets/utils/RecentReadCardData.ets');
const themeColorPage = read('entry/src/main/ets/pages/ThemeColorSettings.ets');
const customSchemeStore = read('entry/src/main/ets/utils/CustomThemeSchemeStore.ets');
const otherSettingsPage = read('entry/src/main/ets/pages/OtherSettings.ets');
const bookSourcePage = read('entry/src/main/ets/pages/BookSource.ets');
const searchCoordinator = read('entry/src/main/ets/core/book/SearchCoordinator.ts');
const fontBootstrap = read('entry/src/main/ets/utils/ReaderFontBootstrap.ets');
const entryAbility = read('entry/src/main/ets/entryability/EntryAbility.ets');
const pages = JSON.parse(read('entry/src/main/resources/base/profile/main_pages.json'));

const expectedThemes = ['plain-default'];
for (const themeId of expectedThemes) {
  assert(models.includes(`'${themeId}'`), `Theme id is missing from ThemeModels: ${themeId}`);
  assert(registry.includes(`ThemeIds.`), 'Builtin registry is not using stable ThemeIds');
}
assert(models.includes("static readonly CUSTOM: string = 'custom'"), 'Custom theme id is missing');
assert(models.includes("static readonly CUSTOM: string = 'custom'"), 'Custom theme id is missing');
assert((registry.match(/themes\.push\(/g) || []).length >= expectedThemes.length,
  `Builtin registry must publish at least ${expectedThemes.length} themes`);
assert(registry.includes('static register(theme: ThemePack)'), 'Compiled theme registration API is missing');

const resourceNames = [...assets.matchAll(/\$r\('app\.media\.([^']+)'\)/g)].map(match => match[1]);
for (const resourceName of resourceNames) {
  const found = fs.readdirSync(mediaRoot).some(fileName => path.parse(fileName).name === resourceName);
  assert(found, `ThemeAssetRegistry references a missing resource: ${resourceName}`);
}

// Cold start must not flash the launcher icon before the custom startup cover.
// startWindowIcon cannot be omitted, so it points at a fully transparent image.
assert(moduleConfig.includes('"startWindowIcon": "$media:start_window_blank"'),
  'Start window icon must use the transparent placeholder');
assert(!/"startWindowIcon": "\$media:icon"/.test(moduleConfig),
  'Start window must not reuse the launcher icon');
assert(fs.existsSync(path.join(mediaRoot, 'start_window_blank.png')),
  'Transparent start window icon resource is missing');
assert(entryAbility.includes('customStartupText'),
  'Cold start must skip the startup page when neither cover nor text is configured');

// Startup cover text is opt-in: the legacy forced default title must be gone.
assert(!themeStore.includes("customLightStartupTitle: string = '开源读书'"),
  'Startup cover title must default to empty');
assert(themeStore.includes('migrateStartupText'), 'Legacy startup title migration is missing');
assert(themeColorPage.includes('setSchemeName'), 'Custom theme name editing is missing');

// Main page background follows the custom theme scheme, light and dark separately.
assert(themeStore.includes('customLightMainBackgroundImagePath') &&
  themeStore.includes('customDarkMainBackgroundImagePath') &&
  themeStore.includes('KEY_CUSTOM_LIGHT_MAIN_BACKGROUND_OPACITY') &&
  themeStore.includes('normalizeMainBackgroundOpacity'),
  'Main background settings are missing from the custom theme scheme');
assert(!entryAbility.includes('MainBackgroundStore') &&
  !fs.existsSync('entry/src/main/ets/utils/MainBackgroundStore.ets'),
  'The global main background store must stay removed');
assert(indexPage.includes("AppBackgroundLayer({ always: true })") &&
  indexPage.includes('ThemeRuntime.mainPageColor(this.appDarkMode)'),
  'Main page must render the scheme background behind transparent page surfaces');
assert(runtime.includes('static mainPageColor(darkMode: boolean =') &&
  runtime.includes('static mainBackgroundImagePath(darkMode: boolean =') &&
  runtime.includes('static pageColorBehind(darkMode: boolean =') &&
  runtime.includes('static cardColorBehind(darkMode: boolean =') &&
  runtime.includes('static mainBackgroundCardOpacity()') &&
  runtime.includes('static usesGlobalBackground(darkMode: boolean =') &&
  runtime.includes('ThemeRuntime.currentThemeId() !== ThemeIds.CUSTOM'),
  'Theme runtime main background helpers must be scheme aware');
assert(themeColorPage.includes('mainBackgroundOptions()') &&
  themeColorPage.includes('pickAndSaveMainBackground(') &&
  themeColorPage.includes('setCurrentMainBackgroundOpacity') &&
  themeColorPage.includes('setMainBackgroundGlobal') &&
  themeColorPage.includes('setMainBackgroundCardOpacity') &&
  themeColorPage.includes('AdaptiveSwitch({ isOn: this.mainBackgroundGlobal'),
  'Custom theme editor must expose the per-mode main background editor and its global switch');
assert(customSchemeStore.includes('customLightMainBackgroundImagePath'),
  'Cloud sync must keep the device-local main background binding');
assert(themeStore.includes('KEY_MAIN_BACKGROUND_GLOBAL') &&
  themeStore.includes('mainBackgroundGlobal') &&
  themeStore.includes('KEY_MAIN_BACKGROUND_CARD_OPACITY') &&
  themeStore.includes('normalizeMainBackgroundCardOpacity'),
  'The global background switch and card opacity are missing from the custom theme scheme');

// Cards and list items must let the wallpaper through instead of staying opaque,
// otherwise the global background looks like a border around a black panel.
const cardColoredPages = ['Index.ets', 'SearchResultGroup.ets', 'Settings.ets'];
for (const fileName of cardColoredPages) {
  const source = read(`entry/src/main/ets/pages/${fileName}`);
  assert(source.includes('ThemeRuntime.cardColorBehind('),
    `Page cards must use the translucent card color: ${fileName}`);
}
const indexTabSurfaces = (indexPage.match(/return ThemeRuntime\.mainPageColor\(this\.appDarkMode\);/g) || []);
assert(indexTabSurfaces.length >= 4,
  'Bookshelf, explore, search and mine tabs must let the background through');

// Only the default theme and the custom theme keep a logo; every builtin
// theme pack was removed with the theme store.
const expectedLogos = ['theme_logo_plain_default', 'theme_logo_custom'];
const themeLogoFiles = fs.readdirSync(mediaRoot).filter(fileName => /^theme_logo_.*\.svg$/.test(fileName));
assert(themeLogoFiles.length === expectedLogos.length,
  'Only the default and custom theme logos may remain');
for (const logoName of expectedLogos) {
  assert(fs.existsSync(path.join(mediaRoot, `${logoName}.svg`)), `Theme logo is missing: ${logoName}`);
}
for (const fileName of themeLogoFiles) {
  const source = fs.readFileSync(path.join(mediaRoot, fileName), 'utf8');
  assert(/viewBox="0 0 64 64"/.test(source), `Invalid theme logo viewBox: ${fileName}`);
  assert(!/(<script|<image|<use|href=|url\(|<filter)/i.test(source), `Unsafe SVG feature in ${fileName}`);
}
assert(assets.includes('static themeLogo(themeId: string)'), 'Theme logo resolver is missing');

const bubbleStyles = ['qq-soft', 'qq-solid', 'capsule', 'paper', 'neon', 'sword-talisman', 'qingluan-jade',
  'pipi-soft-paw'];
for (const styleId of bubbleStyles) {
  assert(models.includes(`'${styleId}'`), `Bubble style is missing from ThemeModels: ${styleId}`);
  assert(regexModel.includes(`'${styleId}'`), `Bubble resolver/codec is missing style: ${styleId}`);
  assert(regexSettings.includes(`'${styleId}'`), `Reader font settings cannot select style: ${styleId}`);
}
assert(regexModel.includes('schemaVersion: number = 3'), 'Regex rule schema must be version 3');
assert(regexSettings.includes('ReaderRegexFontCodec.decode'), 'Settings page must use the shared regex codec');
assert(reader.includes('ReaderRegexFontCodec.decode'), 'Reader page must use the shared regex codec');
assert(reader.includes('if (slice.ttsHighlighted)'), 'TTS highlight precedence is missing');
assert(reader.includes('start >= displayText.length || regex.lastIndex >= displayText.length'),
  'Reader zero-length regex guard is missing');
assert(regexSettings.includes('start >= text.length || regex.lastIndex >= text.length'),
  'Preview zero-length regex guard is missing');

assert(readerThemes.includes('APP_THEME_INDEX: number = 4'), 'Reader app-theme compatibility index is missing');
assert(runtime.includes("KEY_THEME_REVISION"), 'Theme runtime revision broadcast is missing');
assert(readerBackgroundComponent.includes('ThemeAssetRegistry.readerBackgroundDecoration'),
  'Responsive reader background decoration resolver is not connected');
assert(reader.includes('ReaderThemeBackground({') && reader.includes('customImageFit: this.getBackgroundImageFit()'),
  'Reader root surface does not draw the responsive theme background');
assert(readerBackgroundComponent.includes('.objectFit(ImageFit.Contain)') &&
  readerBackgroundComponent.includes('readerBackgroundBorderColor'),
  'Builtin reader backgrounds must preserve ornament proportions and draw a responsive native border');
assert(indexPage.includes('ThemeRuntime.iconPackId()'), 'Floating tab bar does not resolve the active icon pack');
for (const tabId of ['bookshelf', 'explore', 'search', 'mine']) {
  assert(indexPage.includes(`this.navigationIcon('${tabId}')`), `Floating tab icon is not themed: ${tabId}`);
}
assert(indexPage.includes('this.shelfSortButton()') &&
  indexPage.includes('shelfSortDropdown()') &&
  indexPage.includes("this.sortDropdownItem('新阅读', 'recentRead')") &&
  !indexPage.includes("this.sortChip('新阅读', 'recentRead')"),
  'Bookshelf sorting must use a compact dropdown selector');
assert(indexPage.includes('shelfScopeSegment()') &&
  indexPage.includes('expandedShelfScopeSegment()') &&
  indexPage.includes("this.scopeDropdownItem('网络', 'network')") &&
  indexPage.includes("this.scopeDropdownItem('本地', 'local')") &&
  !indexPage.includes("this.scopeChip('网络', 'network')"),
  'Bookshelf network/local switch must use the compact dropdown selector');
assert((indexPage.includes("this.actionItem('多选'") ||
  indexPage.includes("this.contextActionItem($r('sys.symbol.checkmark_circle'), '多选'")) &&
  indexPage.includes('this.bookMultiSelectBar()'),
  'Bookshelf multi-select entry and action bar must stay connected');
assert(indexPage.includes("this.shelfGroupChip('未分组', -1)") && indexPage.includes("Text('＋')"),
  'Bookshelf group bar must include ungrouped and add-group actions');
const settingsPageSource = indexPage.slice(indexPage.indexOf('struct SettingsPage'));
assert(settingsPageSource.includes('.backgroundColor(ThemeRuntime.mainPageColor(this.appDarkMode))') ||
  settingsPageSource.includes('.backgroundColor(this.pageColor())'),
  'Mine page background is not connected to the active theme');
assert(!settingsPageSource.includes(".backgroundColor(this.appDarkMode ? '#101113' : '#F5F5F5')"),
  'Mine page still contains the legacy fixed background color');
assert(settingsPageSource.includes('ThemeRuntime.primaryTextColor') &&
  settingsPageSource.includes('ThemeRuntime.subTextColor'),
  'Mine page semantic text colors are not connected to ThemeRuntime');
assert(settingsPageSource.includes('menuItem(icon: Resource, title: string, showDivider: boolean, onClick: () => void)') &&
  settingsPageSource.includes('SymbolGlyph(icon)') &&
  settingsPageSource.includes("SymbolGlyph($r('sys.symbol.chevron_right'))") &&
  settingsPageSource.includes('Divider()') &&
  settingsPageSource.includes('dividerColor()'),
  'Mine page menu items must use official symbols and themed dividers');
assert(fontBootstrap.includes('ThemeRuntime.fontFamily()'), 'Cold-start font bootstrap ignores the theme font');
assert(entryAbility.includes('this.themeBootstrapPromise.finally') &&
  entryAbility.includes('this.scheduleDeferredStartupInitialization()') &&
  entryAbility.includes("'ability-after-first-content'"),
  'Theme bootstrap and first content must finish before font bootstrap');
assert(themeStore.includes('KEY_THEME_ID') && themeStore.includes('createForTheme'),
  'Theme id persistence or theme selection factory is missing');
assert(models.includes("static readonly CUSTOM: string = 'custom'"), 'Custom theme id is missing');
assert(themeStore.includes('KEY_CUSTOM_LIGHT_ACCENT_COLOR') &&
  themeStore.includes('settings.lightAccentColor),') &&
  themeStore.includes('activateTheme(themeId: string, previous: AppThemeSettings)'),
  'Custom colors are not persisted, migrated, or preserved across builtin theme changes');
assert(themeStore.includes('loadMigratedReaderAppearance') &&
  themeStore.includes('ReaderThemeHelper.themeAt') &&
  themeStore.includes('persistCustomSnapshot'),
  'Existing reader backgrounds are not migrated into the initial custom theme snapshot');
assert(themePage.includes('AppThemeSettingsStore.customTheme(scheme.settings, this.appDarkMode)') &&
  themePage.includes('this.activeVariant(theme).reader.backgroundColor'),
  'Custom theme preview does not use the persisted reader background');
assert(!themeColorPage.includes("'pages/FontSettings'") &&
  !themeStore.includes('updateCustomFont') && !themeStore.includes('updateCustomDesktopIcon'),
  'Theme and appearance must remain independent from fonts and desktop icons');
assert(themePage.includes('this.customThemeSectionTitle()') &&
  themePage.includes("url: 'pages/ThemeColorSettings'"),
  'Theme page does not expose the custom theme before builtin themes');
assert(themeColorPage.includes('settings.themeId = ThemeIds.CUSTOM') &&
  themeColorPage.includes('settings.customLightAccentColor = this.lightAccentColor'),
  'Color edits do not automatically activate and update the custom theme');
assert(!otherSettingsPage.includes("router.pushUrl({ url: 'pages/ThemeColorSettings' })"),
  'Other settings still exposes the removed legacy theme-color entry');
assert(themePage.includes('ReaderThemeHelper.APP_THEME_INDEX'), 'Theme selection does not enable the app reader theme');
assert(themePage.includes('settings.fontFilePath'), 'Custom font override is not protected during theme selection');
assert(themePage.includes('ThemeAssetRegistry.themeLogo(theme.id)') &&
  !themePage.includes("Text('Aa')") &&
  !themePage.includes('颜色、阅读背景、正则气泡与悬浮底栏已统一'),
  'Current theme summary must use the theme logo without the legacy description');
assert(runtime.includes('static accentSurfaceColor(darkMode: boolean)'),
  'Theme runtime does not expose a themed selected-surface color');
assert(ttsSettingsPage.includes('? this.accentColor() : this.inputColor()') &&
  (ttsSettingsPage.includes('.backgroundColor(this.inputColor())') ||
    ttsSettingsPage.includes('fillColor: this.inputColor()')),
  'TTS voice or speed controls are not connected to theme surfaces');
assert(!readerSettingsPage.includes("this.appDarkMode ? '#24272D' : '#F0F2F5'"),
  'Reader settings still contains legacy fixed control backgrounds');
for (const marginName of ['Left', 'Right', 'Top', 'Bottom']) {
  assert(readerStore.includes(`KEY_MARGIN_${marginName.toUpperCase()}`) &&
    reader.includes(`readerMargin${marginName}`),
    `Reader ${marginName.toLowerCase()} margin is not persisted or applied`);
}
assert(readerSettingsPage.includes('this.typographyStepper()') &&
  readerSettingsPage.includes("{ value: '左边距' }") &&
  readerSettingsPage.includes("{ value: '右边距' }") &&
  readerSettingsPage.includes("{ value: '上边距' }") &&
  readerSettingsPage.includes("{ value: '下边距' }") &&
  readerSettingsPage.includes('adjustCurrentTypographySetting'),
  'Reader typography dropdown/stepper does not expose all four margins');
assert(reader.includes('this.getEffectiveReaderMarginLeft() + this.getEffectiveReaderMarginRight()') &&
  reader.includes('this.getEffectiveReaderMarginTop() + this.getReaderContentBottomPadding()') &&
  reader.includes('this.getEffectiveReaderMarginBottom() + this.getReaderContentBottomReserve()'),
  'Reader pagination does not account for configured margins');
// Body rendering and pagination must resolve alignment from the same reader
// setting.  The reader intentionally supports start/end/justify now, so do
// not require the old hard-coded JUSTIFY literals here.
assert(reader.includes('readerTextAlignValue(): TextAlign') &&
  reader.includes("if (this.readerTextAlign === 'start') return TextAlign.Start") &&
  reader.includes("if (this.readerTextAlign === 'end') return TextAlign.End") &&
  reader.includes('.textAlign(this.readerTextAlignValue())') &&
  reader.includes('readerGraphicsTextAlignValue(): graphicsText.TextAlign') &&
  reader.includes("if (this.readerTextAlign === 'start') return graphicsText.TextAlign.LEFT") &&
  reader.includes("if (this.readerTextAlign === 'end') return graphicsText.TextAlign.RIGHT") &&
  reader.includes('align: this.readerGraphicsTextAlignValue()') &&
  reader.includes('input.textAlign = this.readerTextAlign'),
  'Reader body rendering and pagination measurement must use the shared text alignment setting');
assert(reader.includes('const safeBest = Math.max(start + 1, Math.min(best, source.length))') &&
  !reader.includes('Math.floor((best - start) * 0.96)'),
  'Reader pagination must not roll back a full line merely to prefer sentence boundaries');
assert(reader.includes('buildReaderMeasureTextStyle(this.readerFontSize, this.getBodyReaderFontFamily())') &&
  reader.includes('fontFamily: this.getBodyReaderFontFamily()'),
  'Reader pagination measurement must use the same body font as rendering');
assert(reader.includes('this.readerTypographySettingsPanel()') &&
  reader.includes('readerTypographyCombinedSettings()') &&
  reader.includes("{ value: '左边距' }") &&
  reader.includes("{ value: '右边距' }") &&
  reader.includes("{ value: '上边距' }") &&
  reader.includes("{ value: '下边距' }") &&
  reader.includes('applyReaderTypographyValue') &&
  reader.includes('commitReaderTypographyDraft'),
  'In-reader settings do not provide the shared typography controls');
assert(bookModel.includes('static hasStartedReading(book: Book | null)') &&
  bookModel.includes("book.getVariable('readStarted')"),
  'Book model must provide a shared started-reading check');
assert(reader.includes("this.book.putVariable('readStarted', '1')") &&
  reader.includes('!Book.hasStartedReading(this.book) && chapterIndex <= 0 && pageIndex <= 0') &&
  reader.includes('if (Book.hasStartedReading(this.book))'),
  'Reader must not persist first-open progress before the reader turns forward');
assert(indexPage.includes('Book.hasStartedReading(book)') &&
  bookshelfSortHelper.includes('!Book.hasStartedReading(book)') &&
  recentReadCardData.includes('!Book.hasStartedReading(book)'),
  'Bookshelf and recent-read surfaces must treat unopened first pages as unread');
assert(readerSettingsPage.includes("this.selectItem('翻页方式'") &&
  reader.includes("this.readerSelectSettingItem('翻页方式'") &&
  !readerSettingsPage.includes('this.pageTurnOptions()') &&
  !reader.includes('pageTurnModeButton('),
  'Page-turn mode must use dropdown selectors in both settings entries');
assert(readerSettingsPage.includes('if (this.readerPageTurnMode === 2)') &&
  readerSettingsPage.includes('this.tapZoneSettingItem()') &&
  readerSettingsPage.includes('ReaderSettingsStore.saveTapZoneActions') &&
  readerSettingsPage.includes('TapZoneSettingsDialogContent({') &&
  reader.includes('TapZoneSettingsDialogContent({'),
  'Reading settings must expose the shared tap-zone action editor for click page turning');
assert(bookSourcePage.includes('checkOptionsDialog()') &&
  bookSourcePage.includes("this.checkActionOption('自动禁用'") &&
  bookSourcePage.includes("this.checkActionOption('自动删除'") &&
  bookSourcePage.includes('handleCheckedSourceCompletion') &&
  searchCoordinator.includes('await options.onSourceComplete'),
  'Book source validation must support immediate disable/delete actions per completed source');
assert(indexPage.includes("TextInput({ placeholder: '输入书源关键词'") &&
  indexPage.includes("Button('搜索')") &&
  indexPage.includes('this.exploreSourceDropdown()') &&
  !indexPage.includes('builder: this.exploreSourcePopup') &&
  indexPage.includes('applyExploreSourceFilter') &&
  indexPage.includes('getFilteredExploreSourceOptions()'),
  'Explore source dropdown must support keyword filtering from an explicit search button');
assert(!themePage.includes("'衬线字体'") && !themePage.includes("'清晰字体'") &&
  !themePage.includes("'水墨图标'") && !themePage.includes("'主题图标'") &&
  !themePage.includes('themeFeatureChips') && !themePage.includes('featureChip(') &&
  !themePage.includes("this.advancedEntry('字体管理'") &&
  !themePage.includes("this.advancedEntry('桌面图标'"),
  'Theme page must not expose font descriptions, font management, or desktop icon entries');
assert(pages.src.includes('pages/ThemeSettings'), 'Theme settings page is not registered');
assert(moduleConfig.includes('"orientation": "auto_rotation_restricted"'),
  'Entry ability orientation must respect the system rotation lock');

const requiredFiles = [
  'theme/ThemeModels.ets', 'theme/BuiltinThemeRegistry.ets', 'theme/ThemeRuntime.ets',
  'theme/ThemeAssetRegistry.ets', 'components/ReaderThemeBackground.ets', 'pages/ThemeSettings.ets'
];
for (const relativePath of requiredFiles) {
  assert(fs.existsSync(path.join(etsRoot, relativePath)), `Required theme file is missing: ${relativePath}`);
}

// The main background is drawn by one shared layer, so every page that is not
// the reader, the startup cover or the color editor has to mount it.
const backgroundLayer = read('entry/src/main/ets/components/AppBackgroundLayer.ets');
assert(backgroundLayer.includes('export struct AppBackgroundLayer') &&
  backgroundLayer.includes("StorageLink('appMainBackgroundGlobal')") &&
  backgroundLayer.includes("StorageLink('appCustomLightMainBackgroundImagePath')"),
  'Shared background layer must read the scheme background from storage');
const pageRoot = path.join(etsRoot, 'pages');
const backgroundExcludedPages = ['ReadBook.ets', 'Startup.ets', 'ThemeColorSettings.ets'];
let backgroundPageCount = 0;
for (const fileName of fs.readdirSync(pageRoot).filter(fileName => fileName.endsWith('.ets'))) {
  const source = fs.readFileSync(path.join(pageRoot, fileName), 'utf8');
  const usesLayer = /^[ \t]+AppBackgroundLayer\(/m.test(source);
  if (backgroundExcludedPages.includes(fileName)) {
    assert(!usesLayer, `Page must not draw the shared background layer: ${fileName}`);
    continue;
  }
  assert(usesLayer, `Page is missing the shared background layer: ${fileName}`);
  assert(source.includes("from '../components/AppBackgroundLayer'"),
    `Page does not import the shared background layer: ${fileName}`);
  backgroundPageCount++;
}
assert(backgroundPageCount >= 30, `Too few pages mount the shared background layer: ${backgroundPageCount}`);

for (const fileName of fs.readdirSync(pageRoot).filter(fileName => fileName.endsWith('.ets'))) {
  const source = fs.readFileSync(path.join(pageRoot, fileName), 'utf8');
  if (source.includes('pageColor(): string')) {
    assert(source.includes('ThemeRuntime.pageColor'), `Page color is not connected to ThemeRuntime: ${fileName}`);
  }
}

// A struct member that shadows an ArkUI attribute breaks the compiler, so the
// theme helpers must keep names that no CommonAttribute owns.
const shadowingNames = ['backgroundImage', 'backgroundOpacity', 'background', 'backgroundColor',
  'opacity', 'width', 'height', 'border', 'padding', 'margin', 'mask', 'overlay', 'shadow', 'blur',
  'clip', 'offset', 'position', 'scale', 'rotate', 'translate', 'visibility', 'zIndex', 'enabled',
  'draggable', 'focusable', 'transition', 'align', 'alignSelf', 'alignItems', 'alignContent'];
const shadowFiles = [path.join(etsRoot, 'components'), pageRoot];
for (const scanRoot of shadowFiles) {
  for (const fileName of fs.readdirSync(scanRoot).filter(name => name.endsWith('.ets'))) {
    const source = fs.readFileSync(path.join(scanRoot, fileName), 'utf8');
    if (!source.includes('@Component')) continue;
    for (const name of shadowingNames) {
      assert(!new RegExp(`^[ \\t]*(?:private |public |protected )?${name}\\s*\\(`, 'm').test(source),
        `Struct member shadows the ArkUI attribute ${name}(): ${fileName}`);
    }
  }
}

console.log(`Theme framework check passed: ${expectedThemes.length} builtin theme, ` +
  `${themeLogoFiles.length} theme logos, ` +
  `${bubbleStyles.length} bubble styles.`);
