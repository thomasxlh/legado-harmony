# CODE_MAP.md — 阅读页巨型文件导航

> 由 `scripts/gen_reader_code_map.py` 生成，**请勿手工改行号**。文件变动后在仓库根执行 `python scripts/gen_reader_code_map.py --apply` 重算（幂等，只增删注释行，保留所有代码原字节）。
> 面向 AI / 新人：先读本表定位职责域，再跳到 `entry/src/main/ets/pages/ReadBook.ets` 对应行号，避免把 2.4 万行整篇塞进上下文。

## 现状（为什么需要这张表）

- `entry/src/main/ets/pages/ReadBook.ets`：**23327 行 / 约 1.0 MB**；单文件内仅 1 个 `@Entry @Component struct ReadBookPage` + 1 个 `ReadBookTtsBackgroundHost` 适配器类。
- `@State` 约 157 个、`@Builder` 127 个、成员方法 1279 个；整个 `ets/` 目录 **0 个** `@Observed/@Track/@Provide/@Consume/@ObjectLink`（ArkUI V1 全内联状态）。
- 文件内唯一分区手段是本工具写入的 `//region` / `//endregion`（VS Code 与 IntelliJ/DevEco Studio 都能折叠）；每个区块头还带一行 `// [map] 契约:` 说明本区允许读写哪些状态。
- 已存在的可复用范式：`reader/ReaderPureUtils.ets`（纯函数）、`reader/ReaderTtsBackgroundController.ets` + Host 接口、`components/TtsGlobalCapsule.ets`、`components/ReaderTtsPlayerPanel.ets`、`components/TtsCatalogSheet.ets`（已抽出的 @Component）。

## 职责分区（行号 = 插入 `//region` 标记后的当前值）

| # | 区域 | 起始行 | 结束行 | 边界契约（允许读写哪些状态 / 注意事项） |
|---|------|-------:|-------:|------------------------------------------|
| 1 | 头部: 导入 / 顶层常量 / 纯函数 / 后台TTS Host适配器 | 1 | 319 | 无 @State 依赖; 顶层常量已抽到 reader/ReaderConstants.ets; ReadBookTtsBackgroundHost 仅逐方法委托 page |
| 2 | struct 声明与状态字段 (@State / @StorageLink / 私有字段) | 320 | 968 | 仅声明状态, 不含逻辑; ArkUI V1 下 @State 必须留在本 @Component 内, 逻辑外移须走 Controller+Host |
| 3 | 生命周期 / 全局监听 / @Watch 回调 | 969 | 1306 | 读写 会话/进度/可见性/焦点 状态; 装配后台控制器、注册(并应注销)全局监听与 @Watch |
| 4 | 书籍加载 / 全文缓存 / 后台长时任务 / 屏幕超时 / 加载遮罩 | 1307 | 2949 | 读写 book/chapters/content/缓存/遮罩 状态; 持有后台长时任务与多个成对 timer |
| 5 | build / 主内容层 / 悬浮菜单 / 目录·书签·换源·缓存面板 | 2950 | 4927 | 读 主题/排版/章节; 纯渲染 + 面板显隐; 交互只转发到方法, 不写业务状态 |
| 6 | 排版·字符集·替换规则设置 / TTS快捷入口·mini播放器·目录 / 书签 / 正文预处理 | 4928 | 5878 | 读写 设置/目录/书签/TTS浮标显示态; 含 ttsMiniPlayer 等大量 @Builder |
| 7 | 页眉页脚 / 漫画·连续滚动 / 页面度量 / 主题·字体 / 书签 / TTS音色·语速 / 目录搜索 | 5879 | 8635 | 读 排版/主题/字体/章节; 写 字体注册、书签、音色语速、目录滚动条 |
| 8 | 尺寸计算 / 排版变更监听 / 媒体控制条·睡眠定时器 / 触摸·翻页手势 | 8636 | 10636 | 读写 面板尺寸/排版代际/媒体控制/触摸 状态; 定时器成对清理 |
| 9 | 点击区域 / 设置面板 / 音色下拉 / 主题自定义 / 交互·眼动·预载设置 | 10637 | 13284 | 写 各类设置项持久化; 修改后触发重排 / 重载 / 重新分页 |
| 10 | TTS 浮标会话 / 朗读编排(起播·续播·换章·看门狗) / 后台委托 / 封面 / 高亮清理 | 13285 | 14415 | 核心长链路: ttsReadToken / ttsFocusGeneration / ttsChapterSwitching; 与浮标会话、AVSession 双向同步 |
| 11 | 焦点会话 / 正文规范化纯函数群 / 分页测量引擎 | 14416 | 15521 | 含大量可纯化的正文处理(findMeasuredPageEnd 等); 分页测量读排版状态 |
| 12 | 逐句焦点·高亮·进度持久化 / 镜像会话 / TTS翻页 / 动画表面 | 15522 | 16939 | 每句触发 followTtsChunk→高亮重绘→persistTtsReadPosition→浮标 revision++; 镜像会话接管线 |
| 13 | 样式化正文 / 段评·源动作·文本选择 / 正则高亮 / V2布局·分页·选区·高亮 | 16940 | 20653 | 读 高亮偏移/正则规则/主题; V2 分页与选区是独立大子系统, 建议优先外移 |
| 14 | 分页缓存 / 翻页·预载·自动翻页 / 翻页动画·卷曲 / 换章 | 20654 | 23327 | 写 currentPageIndex / 翻页动画状态 / 预载; 与 TTS 翻页、镜像手动翻页交织 |

## 关键入口方法索引

行号为 `struct ReadBookPage` 内定义位置；`ReadBookTtsBackgroundHost` 在文件前部有同名委托方法，用 `/` 一并列出。多个定义用 `/` 分隔。

| 方法 | 行 |
|------|----|
| `aboutToAppear` | 972 |
| `onPageShow` | 1038 |
| `onBackPress` | 1123 |
| `aboutToDisappear` | 1220 |
| `onPageHide` | 1288 |
| `build` | 2953 |
| `loadBook` | 1385 |
| `loadContent` | 305 / 1702 |
| `saveReadingProgress` | 310 / 9516 |
| `enterReaderImmersive` | 1324 |
| `ttsMiniPlayer` | 5499 |
| `globalTtsMiniPlayer` | 5520 |
| `ttsExpandedMediaControlsBar` | 9797 |
| `ttsQuickSettingsPanel` | 11470 |
| `ttsVoiceDropdownPanel` | 11580 |
| `settingsPanel` | 10833 |
| `publishTtsFloatingSession` | 13288 |
| `publishTtsFloatingVoices` | 13325 |
| `updateTtsFloatingSession` | 13338 |
| `stopTtsFloatingSession` | 13366 |
| `toggleTtsReading` | 270 / 13373 |
| `startTtsReadingFromCurrentPosition` | 274 / 13444 |
| `stopTtsReading` | 281 / 13617 |
| `continueTtsReading` | 13817 |
| `isTtsReadingAtExpectedEnd` | 13863 |
| `armTtsContinuationWatchdog` | 13944 |
| `clearTtsContinuationWatchdog` | 301 / 13958 |
| `advanceTtsReadingToNextChapter` | 13966 |
| `finishTtsReading` | 14036 |
| `prepareTtsForManualPageTurn` | 293 / 13705 |
| `scheduleTtsResumeAfterManualPageTurn` | 297 / 13743 |
| `playPositionFromFloatingSession` | 14233 |
| `startTtsBackgroundRunning` | 14096 |
| `stopTtsBackgroundRunning` | 14100 |
| `updateTtsAvSessionPlaybackState` | 14112 |
| `clearTtsHighlight` | 14419 |
| `publishTtsHighlightRenderChange` | 14441 |
| `currentTtsSourceIdentity` | 14451 |
| `invalidateTtsFocusSession` | 14456 |
| `isCurrentTtsFocusSession` | 14464 |
| `getTtsReadingText` | 14472 |
| `getTtsFocusBreakOffsets` | 14490 |
| `normalizeReaderText` | 14502 |
| `getPagedSourceText` | 14509 |
| `buildPagedSourceText` | 14513 |
| `findMeasuredPageEnd` | 14640 |
| `refineMeasuredPageEnd` | 14787 |
| `followTtsChunk` | 15528 |
| `noteTtsFocusLatency` | 15542 |
| `applyTtsChunkFocus` | 15553 |
| `syncTtsFocusAfterResume` | 15656 |
| `updateTtsChunkHighlight` | 15722 |
| `republishTtsFocusAfterPageTurn` | 15785 |
| `scheduleTtsFocusSyncAfterPagination` | 15812 |
| `persistTtsReadPosition` | 15865 |
| `restorePersistedTtsFocus` | 15906 |
| `syncMirroredTtsFocus` | 15950 |
| `clearMirroredTtsFocus` | 16027 |
| `takeOverMirroredTtsSession` | 16036 |
| `animateTtsToPage` | 16119 |
| `applyTtsPageTarget` | 16214 |
| `applyTtsPageTurn` | 16280 |
| `styledReaderText` | 16944 |
| `splitSlicesByTtsHighlight` | 18961 |
| `hasActiveTtsHighlight` | 19411 |
| `shouldUseReaderLayoutV2` | 19496 |
| `buildReaderV2Snapshot` | 19501 |
| `refreshReaderV2TtsOverlay` | 20610 |
| `paginateReaderSourceText` | 20657 |
| `turnNext` | 21449 |
| `turnPrev` | 21458 |
| `applyPageTurn` | 21825 |
| `runPageTurnAnimation` | 21938 |
| `prepareMirroredTtsManualPageTurn` | 22038 |
| `cancelMirroredTtsManualPageTurn` | 22088 |
| `drawReaderPageCurl` | 22741 |
| `loadNextChapter` | 23298 |
| `loadPrevChapter` | 23312 |

（共索引 78 个关键方法；未列出的多为 `@Builder` 或仅在表达式中出现。）

## 共享状态警告（改代码前必读）

1. **V1 状态不能跨文件**：`@State` 必须留在 `@Component` 内。把逻辑抽到普通类时，必须照抄 `ReaderTtsBackgroundController` 的 `Controller + Host 接口` 模式（Host 持有 struct 引用，逐方法委托），不能让新类直接持有 `@State`。
2. **@Builder 提 @Component 会切断联动**：提成独立 `@Component` 后需用 `@Link/@Prop` 或 `AppStorage/@StorageLink` 接通数据；否则状态变更不再刷新 UI。
3. **隐式共享是最大耦合源**：1279 个方法几乎都通过 `this.xxx` 直接读写同一批 `@State`，没有参数边界。任何抽取前先靠本表 + `ops_grep` 确认该方法触达的状态集合。
4. **长跑 TTS 跨章保活**：`finish()` 走 `keepAudioOutputOnFinish` 分支时曾不清帧时间线/缓存引用计数；A1–A9 主要修复已落地（换章软重置帧时间线、CacheLease TTL、drain 看门狗等），详见 `docs/tts-long-running-bugs.md`「修复状态」。

## 拆分蓝图（P0 → P3，每步小提交 + 真机回归，禁止大爆炸重写）

- **P0（零风险，先做）**：顶层常量 + Host 适配器 → `ReaderConstants.ets` / `ReadBookTtsBackgroundHost.ets`；真纯函数（正文规范化里不依赖 `this` 的部分）并入 `reader/ReaderPureUtils.ets`。**已完成：顶层常量已抽到 `reader/ReaderConstants.ets`（P0 第一步）。**
- **P1**：127 个 `@Builder` 按面板提独立 `@Component`（`ttsMiniPlayer`、`ttsExpandedMediaControlsBar`、`ttsQuickSettingsPanel` 等）；分页测量引擎（`clearTtsHighlight` → `followTtsChunk` 区间）→ `ReaderPaginator` 类。
- **P2**：TTS 朗读编排（`publishTtsFloatingSession` → `clearTtsHighlight` 区间）→ `TtsReadingCoordinator + Host`；逐句焦点/高亮/翻页（`followTtsChunk` → `styledReaderText` 区间）→ `TtsFocusController`。
- **P3**：镜像会话 / V2 布局子系统 / 翻页动画各自独立。
- 目标：每单元 ≤ 1500–2000 行 / ≤ 100 KB，边界靠**显式接口**而非共享 `@State`。
- 执行节奏：**纯函数 → 常量 → UI 子组件 → 分页 → TTS 编排 → 焦点/镜像**；每步 `devecocli check arkts <file>` + 真机回归后再进下一步。

## 相关文档

- 听书长时间运行 Bug 分析（卡顿 / 浮标异常 / 翻页不顺 / 高亮卡住）：[docs/tts-long-running-bugs.md](docs/tts-long-running-bugs.md)
- 端云资产同步踩坑：见 `AGENTS.md` 内 `cloud-asset-sync debugging lessons` 段。
