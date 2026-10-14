# 主题开发指南

轻观如是的主题由编译期 `ThemePack`、运行时 `ThemeRuntime` 和持久化兼容层组成。当前内置主题只保留默认主题 `plain-default`，其余外观由用户自建的自定义主题方案（最多 5 套）承载。主题选择保存稳定的 `themeId` 与用户颜色覆盖值；`Resource` 与图标由资源注册表解析，不进入 Preferences。

## 目录与职责

```text
entry/src/main/ets/theme/
├── ThemeModels.ets             # 主题包、浅深变体和设计令牌模型
├── BuiltinThemeRegistry.ets    # 内置主题与编译期主题注册入口
├── ThemeRuntime.ets            # 将主题发布为扁平 AppStorage 令牌
└── ThemeAssetRegistry.ets      # assetId / iconPackId 到 Resource 的映射

entry/src/main/resources/base/media/
├── theme_logo_plain_default.svg # 默认主题标识
├── theme_logo_custom.svg        # 自定义主题标识
├── regex_frame_*                # 正则气泡端饰（左侧框）
└── regex_cap_*                  # 正则气泡端饰（左右端头）
```

主题包不再随包附带书籍封面、书架边框、文件夹插画和专属导航图标包：底栏统一使用经典图标包，书架封面只使用原始封面与封面图库。

`AppThemeSettingsStore` 是兼容桥：它继续读写原来的浅/深强调色与按钮色，同时保存 `appThemeId`，因此旧版本用户的自定义颜色不会在升级时丢失。

## ThemePack 内容

每个主题包含浅色和深色两个 `ThemeVariant`：

- App 颜色：页面、卡片、输入区、主/次文字、分割线、强调色、按钮色、危险色。
- 阅读外观：纯色回退、背景资源 ID、正文/辅助文字色、内容明暗。
- 正则强调：默认强调模式、气泡预设、强调色、气泡文字色。
- 排版：App 默认字体族。用户选择的自定义字体优先级更高。
- 阅读排版：推荐字号、行距、段距与四边边距；切换主题时写入该主题的独立阅读配置。
- 启动封面：默认主题直接使用 HarmonyOS 系统启动窗口；自定义主题可按明暗模式分别上传自己的竖屏封面与文案，未上传时同样使用系统启动窗口。
- 导航：悬浮底栏图标包 ID。
- 形状：小/中/大圆角、卡片、按钮与气泡圆角。
- 材质：面板、弹层、按钮、遮罩和菜单可分别声明模糊与圆角，并配置明暗色玻璃透明度、边框和阴影。标准玻璃模式使用主题默认值；轻盈、强烈或自定义模式继续优先使用用户设置。

有效值优先级为：

```text
正则规则级设置 > 用户颜色/字体覆盖 > 当前主题浅深变体 > 默认主题回退
```

阅读页保留原有米黄、素白、青绿和自定义配色，并新增稳定索引 `APP_THEME_INDEX`。只有选择“应用主题”时，主题背景图与阅读文字色才生效。

## 新增编译期主题

ArkTS 严格模式下建议使用类实例赋值，不要依赖无类型对象字面量。可以在独立文件中创建 `ThemePack`，再在应用初始化前注册：

```ts
import { BuiltinThemeRegistry } from './BuiltinThemeRegistry';
import { ThemePack, ThemeVariant } from './ThemeModels';

const theme = new ThemePack();
theme.id = 'my-theme';
theme.name = '我的主题';
theme.description = '主题说明';
theme.typography.appFontFamily = 'sans-serif';
theme.navigation.iconPackId = 'rounded';
theme.readerLayout.fontSize = 20;
theme.readerLayout.lineHeight = 13;
theme.readerLayout.paragraphSpacing = 11;
theme.readerLayout.marginLeft = 22;
theme.readerLayout.marginRight = 22;
theme.readerLayout.marginTop = 22;
theme.readerLayout.marginBottom = 22;

const light = new ThemeVariant();
light.colors.pageColor = '#F5F5F5';
light.colors.cardColor = '#FFFFFF';
light.colors.inputColor = '#F0F2F5';
light.colors.primaryTextColor = '#1F1F1F';
light.colors.subTextColor = '#777777';
light.colors.dividerColor = '#E0E0E0';
light.colors.accentColor = '#4C7DFF';
light.colors.buttonColor = '#3D6FE8';
light.colors.dangerColor = '#D94C4C';
light.reader.backgroundColor = '#F8F3E8';
light.reader.textColor = '#302A22';
light.reader.subTextColor = '#756B5E';
light.reader.contentTone = 'light';
light.regexEmphasis.emphasisMode = 'bubble';
light.regexEmphasis.bubbleStyle = 'qq-soft';
light.regexEmphasis.emphasisColor = '#DCE7FF';
light.regexEmphasis.emphasisTextColor = '#243B6B';
theme.light = light;

// 深色变体必须单独配置；不要直接复用 light 引用。
const dark = new ThemeVariant();
// ...填写 dark.colors / dark.reader / dark.regexEmphasis
theme.dark = dark;

BuiltinThemeRegistry.register(theme);
```

主题 ID 必须稳定且唯一。注册相同 ID 会替换已注册定义，便于模块化主题包覆盖默认值。

## 阅读背景

内置主题只提供阅读底色（`reader.backgroundColor`），不再随包附带背景图或角落装饰。阅读页背景图始终来自用户自己的选择与封面图库；`ReaderThemeBackground` 保留了对 `backgroundAssetId` 装饰资源的渲染能力，但当前没有任何内置主题使用它。

## 启动封面与冷启动

HarmonyOS 的 `startWindowIcon` 与 `startWindowBackground` 不可缺省，因此 `startWindowIcon` 指向一张全透明图片 `start_window_blank.png`：冷启动不再先闪一下桌面图标。

- 自定义主题上传了启动封面，或填写了主/副标题时，`EntryAbility` 加载 `pages/Startup`，由 `ThemeStartupCover` 绘制封面与文案。
- 两者都为空时不绘制业务启动页，`EntryAbility` 直接加载 `pages/Index`。
- 封面主/副标题默认留空，只有用户显式填写才展示。历史上被强制写入的默认值「轻观如是」会在 `AppThemeSettingsStore` 读取时迁移为空字符串。

## 主界面背景

自定义背景跟随自定义主题方案，浅色与深色各存一张底图；默认主题不使用背景图：

- 存储：`AppThemeSettings` 的 `customLightMainBackgroundImagePath`、`customDarkMainBackgroundImagePath` 与对应的 `customLightMainBackgroundOpacity`、`customDarkMainBackgroundOpacity`（10–100），控制是否铺到全部页面的 `mainBackgroundGlobal`（默认开启），以及卡片不透明度 `mainBackgroundCardOpacity`（0–100，默认 85）。它们随方案一起落在 `CustomThemeSchemeStore` 里，启用某套方案即切换背景；云端同步只带设置，不带本机图片文件。
- 渲染：公共组件 `components/AppBackgroundLayer.ets` 负责在最底层先铺一层页面底色，再按不透明度叠加背景图。除阅读页、启动封面与主题配色编辑页外，每个页面都在根容器最底层挂载它；书架主界面传 `always: true` 恒显示，其余页面受 `mainBackgroundGlobal` 控制。
- 底色：主界面用 `ThemeRuntime.mainPageColor(darkMode)`（有背景图时全透明），其它页面用 `ThemeRuntime.pageColorBehind(darkMode)`（开启全局背景时改为半透明，保留一层底色保证文字可读）。当前主题不是自定义主题，或该模式没有背景图时，两者都与 `pageColor()` 一致。
- 卡片：卡片与列表项底色用 `ThemeRuntime.cardColorBehind(darkMode)`。铺了背景图时它会按 `mainBackgroundCardOpacity` 变成半透明，让背景图从卡片后面透上来；没有背景图或不透明度为 100 时与 `cardColor()` 完全一致。100 表示卡片仍是实心色，调得越低透得越多，文字、封面与边框始终保持不透明，所以可读性由这一项兜底。
- 入口：自定义主题编辑页按浅色/深色分别提供「主界面背景」区块，可上传/更换/清除背景图、调节背景不透明度与卡片不透明度，并可关闭「应用到全部页面」，图片落在 `filesDir/main_backgrounds`。
- 新增需要透出背景的容器时，使用 `ThemeRuntime.mainPageColor()`／`ThemeRuntime.pageColorBehind()` 而不是 `ThemeRuntime.pageColor()`；新增卡片类容器时用 `ThemeRuntime.cardColorBehind()`；新增页面时在根容器最底层挂 `AppBackgroundLayer()`。

## 悬浮底栏图标包

图标包固定包含 `bookshelf`、`explore`、`search`、`mine` 四个 24×24 单色 SVG。路径使用纯黑填充，由 ArkUI 的 `fillColor` 注入主题色。

新增图标包后，在 `ThemeAssetRegistry.navigationIcon()` 增加映射，并把 `ThemePack.navigation.iconPackId` 指向新 ID。桌面 App 图标使用 HarmonyOS 动态图标能力，是独立的用户选择；主题切换不会静默修改桌面图标。

## 正则气泡

规则 schema v3 支持：

- `emphasisMode`：`inherit`、`none`、`text`、`highlight`、`bubble`。
- `bubbleStyleId`：支持 `inherit`、`qq-soft`、`qq-solid`、`capsule`、`paper`、`neon`，以及十三种主题专属样式：`classic-glass`、`warm-scroll`、`forest-dew`、`ink-brush`、`neon-pulse`、`strawberry-ribbon`、`crimson-stamp`、`celadon-slip`、`rose-frame`、`moon-halo`、`sword-talisman`、`qingluan-jade`、`pipi-soft-paw`。当 `emphasisMode = inherit` 时，正文强制使用当前主题的气泡形状、端饰和主题色，忽略规则中残留的样式字段；只有 `emphasisMode = custom` 时规则级气泡样式才生效。
- `emphasisColor`：留空时跟随主题，设置后作为规则级覆盖。

旧的 `highlightColorEnabled`、`shadowColor` 与规则级 `bubbleStyleId` 仍会读取和输出，用于升级和降级兼容。“跟随主题”把强调模式、气泡形状、端饰和主题色作为一个整体继承；“自定义”才允许分别启用文字色、高亮色块、气泡，以及选择气泡样式与颜色。所有气泡模式的正则命中统一使用行内 `ContainerSpan`：命中文字、主题背景、多层 `textShadow` 与左右镜像端饰属于同一个行内单元，不再根据匹配是否覆盖整段切换渲染方式。十三套端饰分别表达玻璃星芒、卷轴、叶片露珠、墨迹印章、霓虹电路、草莓缎带、赤墨档案章、宋式回纹、玫瑰角花、月色鹤影、朱砂剑符、青鸾玉令和皮皮软爪；主题专属样式不再统一追加下划线。强调效果不会改变正文源文本或 TTS 索引，TTS 当前朗读高亮拥有最高显示优先级。

## 验证清单

- 浅色、深色、跟随系统三种模式均检查一次。
- 冷启动后主题 ID、颜色覆盖和自定义字体保持不变。
- 无启动封面与文案时冷启动直接进入书架；设置后先展示封面且不出现桌面图标。
- 启用带主界面背景的自定义主题后，检查书架与二级页面（设置、书源、封面库等）的滚动、弹层与输入框是否仍然可读；切回默认主题时背景应立即消失。
- 关闭「应用到全部页面」后确认只有书架保留背景，其余页面回到纯色底色。
- 图片背景下检查当前页、进入页与横向翻页动画。
- 在旧正则 JSON、schema v2、非法正则、零长度正则下检查阅读页。
- 同时开启正则气泡与 TTS，确认 TTS 高亮覆盖气泡。
- API 23 的悬浮 HdsTabs 与兼容 Tabs 都检查四个图标。
- 运行调试 HAP 构建：

```powershell
$env:DEVECO_SDK_HOME = 'C:\Program Files\Huawei\DevEco Studio\sdk'
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' --mode module -p module=entry@default -p product=default assembleHap --no-daemon
```
