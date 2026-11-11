# CODE_MAP.md — 阅读页巨型文件导航

> 由 `scripts/gen_reader_code_map.py` 生成，**请勿手工改行号**。文件变动后在仓库根执行 `python scripts/gen_reader_code_map.py --apply` 重算（幂等，只增删注释行，保留所有代码原字节）。
> 面向 AI / 新人：先读本表定位职责域，再跳到 `entry/src/main/ets/pages/ReadBook.ets` 对应行号，避免把 2.4 万行整篇塞进上下文。

## 现状（为什么需要这张表）

- `entry/src/main/ets/pages/ReadBook.ets`：**12088 行 / 约 0.5 MB**；单文件内仅 1 个 `@Entry @Component struct ReadBookPage` + 1 个 `ReadBookTtsBackgroundHost` 适配器类。
- 响应式字段（`@State` / `@StorageLink` / `@StorageProp`）见下方「响应式状态域地图」，由脚本实时扫描生成；`@Builder` 127 个仍留在 struct 内（ArkUI DSL 不能外移），业务方法 941 个已抽到 `reader/*Ops.ets`，struct 内只保留 1 行委托；整个 `ets/` 目录 **0 个** `@Observed/@Track/@Provide/@Consume/@ObjectLink`（ArkUI V1 全内联状态）。
- 文件内唯一分区手段是本工具写入的 `//region` / `//endregion`（VS Code 与 IntelliJ/DevEco Studio 都能折叠）；每个区块头还带一行 `// [map] 契约:` 说明本区允许读写哪些状态。
- 已存在的可复用范式：`reader/ReaderPureUtils.ets`（纯函数）、`reader/ReaderTtsBackgroundController.ets` + Host 接口、`components/TtsGlobalCapsule.ets`、`components/ReaderTtsPlayerPanel.ets`、`components/TtsCatalogSheet.ets`（已抽出的 @Component）。

## 职责分区（行号 = 插入 `//region` 标记后的当前值）

| # | 区域 | 起始行 | 结束行 | 边界契约（允许读写哪些状态 / 注意事项） |
|---|------|-------:|-------:|------------------------------------------|
| 1 | 头部: 导入 / 顶层常量 / 纯函数 / 后台TTS Host适配器 | 1 | 331 | 无 @State 依赖; 顶层常量已抽到 reader/ReaderConstants.ets; ReadBookTtsBackgroundHost 仅逐方法委托 page |
| 2 | struct 声明与状态字段 (@State / @StorageLink / 私有字段) | 332 | 980 | 仅声明状态, 不含逻辑; ArkUI V1 下 @State 必须留在本 @Component 内, 逻辑外移须走 Controller+Host |
| 3 | 生命周期 / 全局监听 / @Watch 回调 | 981 | 1279 | 读写 会话/进度/可见性/焦点 状态; 装配后台控制器、注册(并应注销)全局监听与 @Watch |
| 4 | 书籍加载 / 全文缓存 / 后台长时任务 / 屏幕超时 / 加载遮罩 | 1280 | 2062 | 读写 book/chapters/content/缓存/遮罩 状态; 持有后台长时任务与多个成对 timer |
| 5 | build / 主内容层 / 悬浮菜单 / 目录·书签·换源·缓存面板 | 2063 | 3958 | 读 主题/排版/章节; 纯渲染 + 面板显隐; 交互只转发到方法, 不写业务状态 |
| 6 | 排版·字符集·替换规则设置 / TTS快捷入口·mini播放器·目录 / 书签 / 正文预处理 | 3959 | 4603 | 读写 设置/目录/书签/TTS浮标显示态; 含 ttsMiniPlayer 等大量 @Builder |
| 7 | 页眉页脚 / 漫画·连续滚动 / 页面度量 / 主题·字体 / 书签 / TTS音色·语速 / 目录搜索 | 4604 | 5634 | 读 排版/主题/字体/章节; 写 字体注册、书签、音色语速、目录滚动条 |
| 8 | 尺寸计算 / 排版变更监听 / 媒体控制条·睡眠定时器 / 触摸·翻页手势 | 5635 | 6589 | 读写 面板尺寸/排版代际/媒体控制/触摸 状态; 定时器成对清理 |
| 9 | 点击区域 / 设置面板 / 音色下拉 / 主题自定义 / 交互·眼动·预载设置 | 6590 | 8355 | 写 各类设置项持久化; 修改后触发重排 / 重载 / 重新分页 |
| 10 | TTS 浮标会话 / 朗读编排(起播·续播·换章·看门狗) / 后台委托 / 封面 / 高亮清理 | 8356 | 8631 | 核心长链路: ttsReadToken / ttsFocusGeneration / ttsChapterSwitching; 与浮标会话、AVSession 双向同步 |
| 11 | 焦点会话 / 正文规范化纯函数群 / 分页测量引擎 | 8632 | 8839 | 含大量可纯化的正文处理(findMeasuredPageEnd 等); 分页测量读排版状态 |
| 12 | 逐句焦点·高亮·进度持久化 / 镜像会话 / TTS翻页 / 动画表面 | 8840 | 9561 | 每句触发 followTtsChunk→高亮重绘→persistTtsReadPosition→浮标 revision++; 镜像会话接管线 |
| 13 | 样式化正文 / 段评·源动作·文本选择 / 正则高亮 / V2布局·分页·选区·高亮 | 9562 | 11491 | 读 高亮偏移/正则规则/主题; V2 分页与选区是独立大子系统, 建议优先外移 |
| 14 | 分页缓存 / 翻页·预载·自动翻页 / 翻页动画·卷曲 / 换章 | 11492 | 12088 | 写 currentPageIndex / 翻页动画状态 / 预载; 与 TTS 翻页、镜像手动翻页交织 |

## 已抽离的业务域（`reader/*Ops.ets`）

> 每个业务方法都搬成了 `export function name(page: ReadBookPage, ...)`；`ReadBookPage` 内保留 **原签名 + 1 行委托**，因此调用点（`this.xxx()`）与 `@State` 响应式全部不变。
> 关键点：`import type { ReadBookPage }` 会被 ArkTS 自动降级为纯类型导入，无运行时循环依赖；`@State` 编译成 public getter/setter，外部 `page.field = v` 仍走同一 setter。

| 模块 | 方法数 | 行数 |
|------|------:|-----:|
| `reader/ReaderChromeThemeOps.ets` | 224 | 2725 |
| `reader/ReaderGestureOps.ets` | 92 | 1561 |
| `reader/ReaderHighlightOps.ets` | 45 | 1023 |
| `reader/ReaderLifecycleOps.ets` | 3 | 198 |
| `reader/ReaderLoadCacheOps.ets` | 50 | 1207 |
| `reader/ReaderMenuBuildOps.ets` | 9 | 265 |
| `reader/ReaderPageTurnOps.ets` | 128 | 2736 |
| `reader/ReaderPaginationOps.ets` | 42 | 1176 |
| `reader/ReaderSettingsOps.ets` | 98 | 1421 |
| `reader/ReaderStyledTextOps.ets` | 135 | 2471 |
| `reader/ReaderTextPrepOps.ets` | 50 | 653 |
| `reader/ReaderTtsOrchestrationOps.ets` | 65 | 1262 |
| **合计** | **941** | |

## 关键入口方法索引

行号为 `struct ReadBookPage` 内定义位置；`ReadBookTtsBackgroundHost` 在文件前部有同名委托方法，用 `/` 一并列出。多个定义用 `/` 分隔。

| 方法 | 行 |
|------|----|
| `aboutToAppear` | 984 |
| `onPageShow` | 1050 |
| `onBackPress` | 1135 |
| `aboutToDisappear` | 1193 |
| `onPageHide` | 1261 |
| `build` | 2066 |
| `loadBook` | 1307 |
| `loadContent` | 317 / 1489 |
| `saveReadingProgress` | 322 / 5999 |
| `enterReaderImmersive` | 1287 |
| `ttsMiniPlayer` | 4351 |
| `globalTtsMiniPlayer` | 4372 |
| `ttsExpandedMediaControlsBar` | 6127 |
| `ttsQuickSettingsPanel` | 7238 |
| `ttsVoiceDropdownPanel` | 7348 |
| `settingsPanel` | 6668 |
| `publishTtsFloatingSession` | 8359 |
| `publishTtsFloatingVoices` | 8363 |
| `updateTtsFloatingSession` | 8367 |
| `stopTtsFloatingSession` | 8371 |
| `toggleTtsReading` | 282 / 8375 |
| `startTtsReadingFromCurrentPosition` | 286 / 8383 |
| `stopTtsReading` | 293 / 8391 |
| `continueTtsReading` | 8431 |
| `isTtsReadingAtExpectedEnd` | 8435 |
| `armTtsContinuationWatchdog` | 8449 |
| `clearTtsContinuationWatchdog` | 313 / 8453 |
| `advanceTtsReadingToNextChapter` | 8457 |
| `finishTtsReading` | 8461 |
| `prepareTtsForManualPageTurn` | 305 / 8415 |
| `scheduleTtsResumeAfterManualPageTurn` | 309 / 8419 |
| `playPositionFromFloatingSession` | 8603 |
| `startTtsBackgroundRunning` | 8481 |
| `stopTtsBackgroundRunning` | 8485 |
| `updateTtsAvSessionPlaybackState` | 8493 |
| `clearTtsHighlight` | 8635 |
| `publishTtsHighlightRenderChange` | 8639 |
| `currentTtsSourceIdentity` | 8643 |
| `invalidateTtsFocusSession` | 8647 |
| `isCurrentTtsFocusSession` | 8651 |
| `getTtsReadingText` | 8656 |
| `getTtsFocusBreakOffsets` | 8660 |
| `normalizeReaderText` | → `reader/ReaderLeafFns.ets`（已抽离为纯函数） |
| `getPagedSourceText` | 8664 |
| `buildPagedSourceText` | 8668 |
| `findMeasuredPageEnd` | 8699 |
| `refineMeasuredPageEnd` | 8714 |
| `followTtsChunk` | 8846 |
| `noteTtsFocusLatency` | 8851 |
| `applyTtsChunkFocus` | 8855 |
| `syncTtsFocusAfterResume` | 8886 |
| `updateTtsChunkHighlight` | 8894 |
| `republishTtsFocusAfterPageTurn` | 8911 |
| `scheduleTtsFocusSyncAfterPagination` | 8916 |
| `persistTtsReadPosition` | 8924 |
| `restorePersistedTtsFocus` | 8936 |
| `syncMirroredTtsFocus` | 8948 |
| `clearMirroredTtsFocus` | 8952 |
| `takeOverMirroredTtsSession` | 8959 |
| `animateTtsToPage` | 8967 |
| `applyTtsPageTarget` | 8979 |
| `applyTtsPageTurn` | 8995 |
| `styledReaderText` | 9566 |
| `splitSlicesByTtsHighlight` | 10495 |
| `hasActiveTtsHighlight` | 10586 |
| `shouldUseReaderLayoutV2` | 10642 |
| `buildReaderV2Snapshot` | 10646 |
| `refreshReaderV2TtsOverlay` | 11484 |
| `paginateReaderSourceText` | 11495 |
| `turnNext` | 11603 |
| `turnPrev` | 11612 |
| `applyPageTurn` | 11744 |
| `runPageTurnAnimation` | 11757 |
| `prepareMirroredTtsManualPageTurn` | 11762 |
| `cancelMirroredTtsManualPageTurn` | 11770 |
| `drawReaderPageCurl` | 11978 |
| `loadNextChapter` | 12079 |
| `loadPrevChapter` | 12083 |

（共索引 78 个关键方法；未列出的多为 `@Builder` 或仅在表达式中出现。）

## 已抽离的叶子纯函数（`reader/ReaderLeafFns.ets`）

> 以下 131 个 `export function` 由脚本实时读取该模块生成，不读/不写任何 `@State`；改阅读页逻辑前先在此确认是否已有可用纯函数，避免重复实现。

| # | 函数 | 所在行 |
|---|------|-------:|
| 1 | `countCachedChapters` | 27 |
| 2 | `countCachedChaptersFrom` | 37 |
| 3 | `syncRenderedChapterCacheDates` | 48 |
| 4 | `supportsReaderImmersiveMaterial` | 61 |
| 5 | `txtCharsetOptions` | 65 |
| 6 | `currentReaderSource` | 82 |
| 7 | `ttsOffsetSanitizedText` | 86 |
| 8 | `isReaderImageOnlySource` | 101 |
| 9 | `countReaderImageMarkers` | 107 |
| 10 | `isReaderImageOnlyPage` | 121 |
| 11 | `getReaderHeaderInfoBarHeight` | 125 |
| 12 | `normalizeReaderBottomInfoBarHeight` | 136 |
| 13 | `resolveCustomReaderFontFamily` | 147 |
| 14 | `replaceReaderCustomFontPath` | 173 |
| 15 | `fileNameFromPath` | 198 |
| 16 | `formatBookmarkTime` | 202 |
| 17 | `markTtsVoiceOptionInstalled` | 212 |
| 18 | `isKnownTtsVoiceId` | 228 |
| 19 | `ttsCustomVoiceKey` | 232 |
| 20 | `ttsCustomVoiceTitle` | 236 |
| 21 | `ttsVoiceKey` | 241 |
| 22 | `ttsVoiceGenderText` | 245 |
| 23 | `tocScrollbarPointerY` | 256 |
| 24 | `getReaderExtendedBottomSafeInset` | 261 |
| 25 | `getReaderBottomInfoBarContentGap` | 268 |
| 26 | `readerFloatingBarEdgeInset` | 272 |
| 27 | `readerTtsExpandedControlWidth` | 276 |
| 28 | `normalizeTapZoneActions` | 280 |
| 29 | `tapActionLabel` | 291 |
| 30 | `tapZoneCellColor` | 305 |
| 31 | `readerSettingsScrollBarRightInset` | 318 |
| 32 | `readerTextAlignValues` | 323 |
| 33 | `readerTypographyMin` | 327 |
| 34 | `readerTypographyMax` | 332 |
| 35 | `pageTurnModeTypes` | 341 |
| 36 | `screenTimeoutValues` | 345 |
| 37 | `screenOrientationValues` | 355 |
| 38 | `readerEyeCalibrationPreviewTopVp` | 363 |
| 39 | `readerEyeDwellValues` | 367 |
| 40 | `ttsSpeechTextEnd` | 371 |
| 41 | `indentReaderLine` | 375 |
| 42 | `isReaderTrimChar` | 390 |
| 43 | `isReaderPageStartTrimChar` | 396 |
| 44 | `adjustReaderActionMarkerPageEnd` | 401 |
| 45 | `findReaderActionEndingAt` | 429 |
| 46 | `getReaderPaginationHeightTolerancePx` | 446 |
| 47 | `toMeasurePx` | 450 |
| 48 | `toMeasureNonNegativePx` | 458 |
| 49 | `toMeasureFontOffsetPx` | 467 |
| 50 | `chooseReaderPageBreak` | 476 |
| 51 | `readerHeaderContentValues` | 493 |
| 52 | `readerFooterLeftValues` | 497 |
| 53 | `readerFooterProgressValues` | 501 |
| 54 | `delay` | 505 |
| 55 | `readerInlineSourceActionFontFamily` | 511 |
| 56 | `readerCommentPanelDragHandleHeight` | 517 |
| 57 | `readerSelectableTextKey` | 521 |
| 58 | `getRegexFrameHorizontalPaddingForStyle` | 526 |
| 59 | `getRegexFrameVerticalPaddingForStyle` | 537 |
| 60 | `themeRegexEmphasisMode` | 546 |
| 61 | `themeRegexBubbleStyleId` | 550 |
| 62 | `hasOverlappedRegexSlice` | 554 |
| 63 | `buildTextSliceKey` | 563 |
| 64 | `syncReaderV2PaginationResult` | 570 |
| 65 | `normalizePreloadChapterCount` | 601 |
| 66 | `sourceUsesWebFetchRuntime` | 605 |
| 67 | `parseReaderChapterRange` | 616 |
| 68 | `sleep` | 643 |
| 69 | `txtCharsetLabel` | 649 |
| 70 | `cleanTtsPanelSlice` | 657 |
| 71 | `getReaderPageHorizontalPadding` | 665 |
| 72 | `getReaderPageVerticalPadding` | 669 |
| 73 | `normalizeColor` | 673 |
| 74 | `shouldPreferTtsVoiceOption` | 684 |
| 75 | `ttsVoiceTitle` | 697 |
| 76 | `normalizeTtsLanguage` | 707 |
| 77 | `getReaderSafeAreaEdges` | 718 |
| 78 | `readerPanelTransition` | 726 |
| 79 | `readerSettingsContentTransition` | 738 |
| 80 | `isReaderChapterLastPage` | 749 |
| 81 | `readerSettingsContentRightPadding` | 755 |
| 82 | `readerTypographyOptions` | 759 |
| 83 | `readerTextAlignOptions` | 772 |
| 84 | `pageTurnModeOptions` | 776 |
| 85 | `pageTurnModeByIndex` | 784 |
| 86 | `screenTimeoutOptions` | 789 |
| 87 | `screenOrientationOptions` | 799 |
| 88 | `readerSelectOptionValue` | 807 |
| 89 | `readerPreloadChapterOptions` | 814 |
| 90 | `readerEyeDwellOptions` | 822 |
| 91 | `readerEyeDwellSelectedIndex` | 832 |
| 92 | `readerEyeCalibrationMedian` | 846 |
| 93 | `readerSoftLineJoiner` | 853 |
| 94 | `shouldMergeReaderSoftLine` | 862 |
| 95 | `isReaderEdgeTrimChar` | 886 |
| 96 | `findMeasuredReaderInlineAction` | 890 |
| 97 | `toMeasureFontPx` | 901 |
| 98 | `readerHeaderContentOptions` | 909 |
| 99 | `readerFooterLeftOptions` | 913 |
| 100 | `readerFooterProgressOptions` | 917 |
| 101 | `readerPageRenderIdentity` | 921 |
| 102 | `readerSelectablePageTextKey` | 927 |
| 103 | `readerParagraphCommentSettingState` | 932 |
| 104 | `isReaderParagraphCommentAction` | 940 |
| 105 | `isReaderCommentAction` | 945 |
| 106 | `getReaderEpubImageUri` | 951 |
| 107 | `cloneStyledSlice` | 962 |
| 108 | `appendReaderV2PaginationBatch` | 975 |
| 109 | `readerV2DisplayHighlightRects` | 985 |
| 110 | `readerV2RegexBubbleShadow` | 1024 |
| 111 | `readerV2FragmentLineMetrics` | 1034 |
| 112 | `readerV2DisplayOffsetForPageSelection` | 1042 |
| 113 | `readerV2FragmentIndexForSelectionOffset` | 1056 |
| 114 | `regexDecorationStyle` | 1065 |
| 115 | `readerSlideCompletionDuration` | 1073 |
| 116 | `installedTtsVoiceKey` | 1091 |
| 117 | `sameTtsLanguage` | 1096 |
| 118 | `readerEyeCalibrationSpread` | 1100 |
| 119 | `mergeSoftWrappedChapterLines` | 1107 |
| 120 | `trimReaderContentText` | 1143 |
| 121 | `readerParagraphCommentsEnabledForPagination` | 1156 |
| 122 | `readerParagraphCommentPaginationIdentity` | 1162 |
| 123 | `stripReaderParagraphCommentActions` | 1167 |
| 124 | `isSameTtsVoiceOption` | 1192 |
| 125 | `isSameTtsDisplayVoice` | 1203 |
| 126 | `normalizeReaderText` | 1211 |
| 127 | `normalizeChapterBody` | 1218 |
| 128 | `stripDuplicatedChapterTitle` | 1225 |
| 129 | `defaultTtsVoice` | 1237 |
| 130 | `mergeWithDefaultTtsVoice` | 1248 |
| 131 | `buildIndentedChapterBody` | 1262 |

## 响应式状态域地图（@State / @StorageLink / @StorageProp）

> 由脚本实时扫描 `ReadBook.ets`（行号已含 `//region` 标记）生成；共 282 个响应式字段（`@State` 178 / `@StorageLink` 102 / `@StorageProp` 2）。「域」由生成器内的 `DOMAIN_RULES` 关键字规则首匹配启发式判定，可按需调整；抽取任何逻辑前先按域定位其读写邻居，并用 `ops_grep` 复核触达的 @State 集合。

| 域 | 字段数 |
|----|-------:|
| 阅读排版与交互设置 (通用) | 30 |
| TTS 朗读会话 / 浮标 / 逐句高亮 | 28 |
| 书籍 / 章节 / 缓存 / 换源 | 28 |
| 分页 / V2 布局 / 选区 | 22 |
| 字体 / 正则字体 | 21 |
| 目录 TOC | 20 |
| 翻页动画 / 手势 | 20 |
| 眼动翻页 | 17 |
| 菜单 / 显隐 / 设置弹窗 | 17 |
| 主题 / 夜间模式 | 16 |
| TTS 音色 / 语速设置 | 15 |
| 自动翻页 / 屏幕 / 快捷设置 | 14 |
| 漫画模式 | 12 |
| 封面 / 书架 | 8 |
| 书签 | 7 |
| 段评 / 评论面板 | 7 |

| 行 | 域 | 装饰器 | 存储键 | @Watch | 字段 | 类型 | private |
|---:|----|--------|--------|---------|------|------|---------|
| 337 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `bookUrl` | `string` | — |
| 338 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `book` | `Book \| null` | — |
| 339 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `chapters` | `BookChapter[]` | — |
| 340 | 目录 TOC | `@State` | — | — | `tocVisibleChapters` | `BookChapter[]` | — |
| 341 | 目录 TOC | `@State` | — | — | `tocWindowStart` | `number` | — |
| 342 | 目录 TOC | `@State` | — | — | `tocQuickJumpArmed` | `boolean` | — |
| 343 | 目录 TOC | `@State` | — | — | `tocQuickJumpInputVisible` | `boolean` | — |
| 344 | 目录 TOC | `@State` | — | — | `tocQuickJumpDraft` | `string` | — |
| 345 | 目录 TOC | `@State` | — | — | `tocSearchVisible` | `boolean` | — |
| 346 | 目录 TOC | `@State` | — | — | `tocSearchQuery` | `string` | — |
| 347 | 目录 TOC | `@State` | — | — | `tocSearchChapterIndexes` | `number[]` | — |
| 348 | 目录 TOC | `@State` | — | — | `tocSearchLoading` | `boolean` | — |
| 349 | 目录 TOC | `@State` | — | — | `tocSearchResultActive` | `boolean` | — |
| 350 | 目录 TOC | `@State` | — | — | `tocReverseOrder` | `boolean` | — |
| 351 | 目录 TOC | `@State` | — | — | `tocOrderRevision` | `number` | — |
| 352 | 目录 TOC | `@State` | — | — | `tocDatabaseChapterCount` | `number` | — |
| 353 | 目录 TOC | `@State` | — | — | `tocListViewportHeight` | `number` | — |
| 354 | 目录 TOC | `@State` | — | — | `tocFirstVisibleGlobalIndex` | `number` | — |
| 355 | 目录 TOC | `@State` | — | — | `tocVisibleItemCount` | `number` | — |
| 356 | 目录 TOC | `@State` | — | — | `tocScrollbarDragging` | `boolean` | — |
| 357 | 目录 TOC | `@State` | — | — | `tocScrollbarDragOffset` | `number` | — |
| 362 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `currentChapterIndex` | `number` | — |
| 363 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `menuChapterPreviewIndex` | `number` | — |
| 364 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `menuChapterSliderActive` | `boolean` | — |
| 365 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `menuChapterTooltipVisible` | `boolean` | — |
| 366 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `menuChapterConfirming` | `boolean` | — |
| 367 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `content` | `string` | — |
| 368 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `readerReplaceRules` | `ReaderReplaceRule[]` | — |
| 369 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | `onReaderLoadingChanged` | `isLoading` | `boolean` | — |
| 371 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `readerLoadingSlow` | `boolean` | — |
| 373 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `showMenu` | `boolean` | — |
| 374 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `hdsMaterialRenderBranch` | `boolean` | — |
| 375 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `readerDayNightLongPressHandled` | `boolean` | — |
| 377 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `readerMenuAnchorSide` | `number` | — |
| 378 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `showReaderActionMenu` | `boolean` | — |
| 379 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `showLayoutElementSettings` | `boolean` | — |
| 385 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | `onSystemDialogFlagChanged` | `showTxtCharsetDialog` | `boolean` | — |
| 386 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `txtCharsetDraft` | `string` | — |
| 387 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `txtCharsetApplying` | `boolean` | — |
| 388 | 段评 / 评论面板 | `@State` | — | — | `showReaderCommentPanel` | `boolean` | — |
| 389 | 段评 / 评论面板 | `@State` | — | — | `readerCommentPanelTitle` | `string` | — |
| 390 | 段评 / 评论面板 | `@State` | — | — | `readerCommentPanelUrl` | `string` | — |
| 391 | 段评 / 评论面板 | `@State` | — | — | `readerCommentPanelProgress` | `number` | — |
| 392 | 段评 / 评论面板 | `@State` | — | — | `readerCommentPanelLoading` | `boolean` | — |
| 393 | 段评 / 评论面板 | `@State` | — | — | `readerCommentPanelHeightRatio` | `number` | — |
| 394 | 段评 / 评论面板 | `@State` | — | — | `readerCommentPanelHeightValue` | `number` | — |
| 403 | 目录 TOC | `@State` | — | — | `showToc` | `boolean` | — |
| 404 | 目录 TOC | `@State` | — | — | `tocPanelTab` | `number` | — |
| 405 | 书签 | `@State` | — | — | `bookmarks` | `Bookmark[]` | — |
| 406 | 书签 | `@State` | — | — | `bookmarkMultiSelectMode` | `boolean` | — |
| 407 | 书签 | `@State` | — | — | `selectedBookmarkUrls` | `string[]` | — |
| 408 | 书签 | `@State` | — | — | `showBookmarkActionMenu` | `boolean` | — |
| 409 | 书签 | `@State` | — | — | `pendingBookmarkAction` | `Bookmark \| null` | — |
| 410 | 书签 | `@State` | — | — | `bookmarkActionMenuX` | `number` | — |
| 411 | 书签 | `@State` | — | — | `bookmarkActionMenuY` | `number` | — |
| 412 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `showSettings` | `boolean` | — |
| 413 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | `onSystemDialogFlagChanged` | `showTapZoneSettings` | `boolean` | — |
| 414 | 主题 / 夜间模式 | `@State` | — | `onSystemDialogFlagChanged` | `showReaderCustomThemeDeleteConfirm` | `boolean` | — |
| 415 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `settingsPanelTab` | `number` | — |
| 416 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerTypographySelection` | `number` | — |
| 417 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `showReaderTypographyValueInput` | `boolean` | — |
| 418 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerTypographyValueDraft` | `string` | — |
| 419 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `loadStatus` | `string` | — |
| 420 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `verificationUrl` | `string` | — |
| 421 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `verificationTitle` | `string` | — |
| 422 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `showChangeSourceDialog` | `boolean` | — |
| 423 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `pendingSwitchedBook` | `Book \| null` | — |
| 424 | 分页 / V2 布局 / 选区 | `@State` | — | — | `contentPages` | `string[]` | — |
| 425 | 分页 / V2 布局 / 选区 | `@State` | — | — | `currentPageIndex` | `number` | — |
| 426 | 分页 / V2 布局 / 选区 | `@State` | — | — | `currentPageText` | `string` | — |
| 427 | 分页 / V2 布局 / 选区 | `@State` | — | — | `displayPageText` | `string` | — |
| 428 | 分页 / V2 布局 / 选区 | `@State` | — | — | `displayPageChapterIndex` | `number` | — |
| 429 | 分页 / V2 布局 / 选区 | `@State` | — | — | `displayPageIndex` | `number` | — |
| 430 | 分页 / V2 布局 / 选区 | `@State` | — | — | `displayPageRenderKey` | `number` | — |
| 431 | 分页 / V2 布局 / 选区 | `@State` | — | — | `pageRenderVersion` | `number` | — |
| 432 | 分页 / V2 布局 / 选区 | `@State` | — | — | `chapterJumpRenderGeneration` | `number` | — |
| 433 | 分页 / V2 布局 / 选区 | `@State` | — | — | `readerV2SurfaceGeneration` | `number` | — |
| 434 | 分页 / V2 布局 / 选区 | `@State` | — | — | `pageViewWidth` | `number` | — |
| 435 | 分页 / V2 布局 / 选区 | `@State` | — | — | `pageViewHeight` | `number` | — |
| 436 | 分页 / V2 布局 / 选区 | `@State` | — | — | `readerBottomInfoBarMeasuredHeight` | `number` | — |
| 437 | 分页 / V2 布局 / 选区 | `@State` | — | — | `readerInitialPageReady` | `boolean` | — |
| 438 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerInitialOpening` | `boolean` | — |
| 439 | 分页 / V2 布局 / 选区 | `@State` | — | — | `readerWebFetchRuntimeNeeded` | `boolean` | — |
| 440 | 漫画模式 | `@State` | — | — | `readerComicMode` | `boolean` | — |
| 441 | 漫画模式 | `@State` | — | — | `readerComicImageRatios` | `number[]` | — |
| 443 | 漫画模式 | `@State` | — | — | `readerComicBrokenPages` | `number[]` | — |
| 444 | 漫画模式 | `@State` | — | — | `readerComicPaginationParsing` | `boolean` | — |
| 445 | 漫画模式 | `@State` | — | — | `readerComicPaginationParsedPages` | `number` | — |
| 446 | 漫画模式 | `@State` | — | — | `readerComicPaginationTotalPages` | `number` | — |
| 447 | 漫画模式 | `@State` | — | — | `readerComicChapterSwitching` | `boolean` | — |
| 448 | 漫画模式 | `@State` | — | — | `readerComicBoundaryDirection` | `number` | — |
| 449 | 漫画模式 | `@State` | — | — | `readerComicBoundaryPullDistance` | `number` | — |
| 450 | 漫画模式 | `@State` | — | — | `readerComicBoundaryReady` | `boolean` | — |
| 451 | 漫画模式 | `@State` | — | — | `readerComicChapterTransitionY` | `number` | — |
| 452 | 漫画模式 | `@State` | — | — | `readerComicChapterTransitionOpacity` | `number` | — |
| 454 | 分页 / V2 布局 / 选区 | `@State` | — | — | `statusBarSafeHeight` | `number` | — |
| 455 | 分页 / V2 布局 / 选区 | `@StorageProp` | `statusBarHeight` | `onStoredStatusBarHeightChanged` | `storedStatusBarHeight` | `number` | — |
| 456 | 分页 / V2 布局 / 选区 | `@StorageProp` | `navBarHeight` | — | `navBarHeight` | `number` | — |
| 457 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `isTtsSpeaking` | `boolean` | — |
| 458 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `isTtsPaused` | `boolean` | — |
| 459 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `ttsPagedScrollOverride` | `boolean` | — |
| 460 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `ttsMediaControlsExpanded` | `boolean` | — |
| 461 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `ttsDisplayText` | `string` | — |
| 462 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `ttsHighlightStart` | `number` | — |
| 463 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `ttsHighlightEnd` | `number` | — |
| 464 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `ttsHighlightRenderVersion` | `number` | — |
| 465 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `readerV2TtsPaintVersion` | `number` | — |
| 466 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `readerV2SelectionPaintVersion` | `number` | — |
| 467 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `ttsSleepTimerMinutes` | `number` | — |
| 468 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `ttsSleepTimerRemainingSeconds` | `number` | — |
| 469 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsActive` | `onGlobalTtsActiveChanged` | `globalTtsActive` | `boolean` | — |
| 470 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsPaused` | — | `globalTtsPaused` | `boolean` | — |
| 471 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsBookName` | — | `globalTtsBookName` | `string` | — |
| 472 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsChapterTitle` | — | `globalTtsChapterTitle` | `string` | — |
| 473 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsMode` | — | `globalTtsMode` | `string` | — |
| 474 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsChapterProgress` | — | `globalTtsChapterProgress` | `string` | — |
| 475 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsCanPrevious` | — | `globalTtsCanPrevious` | `boolean` | — |
| 476 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsCanNext` | — | `globalTtsCanNext` | `boolean` | — |
| 477 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsBookUrl` | — | `globalTtsBookUrl` | `string` | — |
| 478 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsChapterIndex` | — | `globalTtsChapterIndex` | `number` | — |
| 479 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsOffsetStart` | — | `globalTtsOffsetStart` | `number` | — |
| 480 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsOffsetEnd` | — | `globalTtsOffsetEnd` | `number` | — |
| 481 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsRevision` | `onGlobalTtsRevisionChanged` | `globalTtsRevision` | `number` | — |
| 482 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `showGlobalTtsCatalog` | `boolean` | — |
| 483 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `globalTtsCatalogReverseOrder` | `boolean` | — |
| 546 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `mirroredTtsFocusActive` | `boolean` | — |
| 641 | 翻页动画 / 手势 | `@State` | — | — | `readerPageCurlSnapshotReady` | `boolean` | — |
| 642 | 翻页动画 / 手势 | `@State` | — | — | `pageTransitionX` | `number` | — |
| 643 | 翻页动画 / 手势 | `@State` | — | — | `pageTransitionOpacity` | `number` | — |
| 644 | 翻页动画 / 手势 | `@State` | — | — | `pageSlideOffsetX` | `number` | — |
| 645 | 翻页动画 / 手势 | `@State` | — | — | `pageSlideOffsetY` | `number` | — |
| 646 | 翻页动画 / 手势 | `@State` | — | — | `bookmarkPullOffsetY` | `number` | — |
| 647 | 翻页动画 / 手势 | `@State` | — | — | `bookmarkPullActive` | `boolean` | — |
| 648 | 翻页动画 / 手势 | `@State` | — | — | `bookmarkPullReady` | `boolean` | — |
| 649 | 翻页动画 / 手势 | `@State` | — | — | `pageSlideDirection` | `number` | — |
| 650 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnAnimating` | `boolean` | — |
| 651 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnIncomingText` | `string` | — |
| 652 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnIncomingSecondaryText` | `string` | — |
| 653 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnIncomingX` | `number` | — |
| 654 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnIncomingOpacity` | `number` | — |
| 655 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnIncomingPageIndex` | `number` | — |
| 656 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnIncomingChapterIndex` | `number` | — |
| 657 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnIncomingPageStart` | `number` | — |
| 658 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnIncomingSecondaryPageStart` | `number` | — |
| 659 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnIncomingDocumentSource` | `string` | — |
| 660 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnIncomingRenderVersion` | `number` | — |
| 706 | 分页 / V2 布局 / 选区 | `@State` | — | — | `readerTextSelectionActive` | `boolean` | — |
| 713 | 分页 / V2 布局 / 选区 | `@State` | — | — | `readerV2NativeSelectionHostVersion` | `number` | — |
| 724 | 分页 / V2 布局 / 选区 | `@State` | — | — | `readerV2NativeSelectionOffsetX` | `number` | — |
| 725 | 分页 / V2 布局 / 选区 | `@State` | — | — | `readerV2NativeSelectionOffsetY` | `number` | — |
| 767 | 字体 / 正则字体 | `@StorageLink` | `readerFontSize` | `onReadLayoutChanged` | `readerFontSize` | `number` | — |
| 768 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerLetterSpacing` | `onReadLayoutChanged` | `readerLetterSpacing` | `number` | — |
| 769 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerTextAlign` | `onReadLayoutChanged` | `readerTextAlign` | `string` | — |
| 770 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerLineHeight` | `onReadLayoutChanged` | `readerLineHeight` | `number` | — |
| 771 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerParagraphSpacing` | `onReadLayoutChanged` | `readerParagraphSpacing` | `number` | — |
| 773 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerKeepParagraphIndent` | `onReadLayoutChanged` | `keepParagraphIndent` | `boolean` | — |
| 774 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerMarginLeft` | `onReadLayoutChanged` | `readerMarginLeft` | `number` | — |
| 775 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerMarginRight` | `onReadLayoutChanged` | `readerMarginRight` | `number` | — |
| 776 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerMarginTop` | `onReadLayoutChanged` | `readerMarginTop` | `number` | — |
| 777 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerMarginBottom` | `onReadLayoutChanged` | `readerMarginBottom` | `number` | — |
| 778 | 主题 / 夜间模式 | `@StorageLink` | `readerLightThemeIndex` | `onReaderThemeChanged` | `readerLightThemeIndex` | `number` | — |
| 779 | 主题 / 夜间模式 | `@StorageLink` | `readerDarkThemeIndex` | `onReaderThemeChanged` | `readerDarkThemeIndex` | `number` | — |
| 780 | 主题 / 夜间模式 | `@StorageLink` | `readerLightCustomThemeBackgroundColor` | `onReaderThemeChanged` | `readerLightCustomThemeBackgroundColor` | `string` | — |
| 781 | 主题 / 夜间模式 | `@StorageLink` | `readerLightCustomThemeTextColor` | `onReaderThemeChanged` | `readerLightCustomThemeTextColor` | `string` | — |
| 782 | 主题 / 夜间模式 | `@StorageLink` | `readerDarkCustomThemeBackgroundColor` | `onReaderThemeChanged` | `readerDarkCustomThemeBackgroundColor` | `string` | — |
| 783 | 主题 / 夜间模式 | `@StorageLink` | `readerDarkCustomThemeTextColor` | `onReaderThemeChanged` | `readerDarkCustomThemeTextColor` | `string` | — |
| 784 | 主题 / 夜间模式 | `@StorageLink` | `readerCustomThemesRaw` | `onReaderThemeChanged` | `readerCustomThemesRaw` | `string` | — |
| 785 | 主题 / 夜间模式 | `@State` | — | — | `customThemeNameDraft` | `string` | — |
| 786 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerPageTurnMode` | — | `readerPageTurnMode` | `number` | — |
| 787 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerPageTurnAnimationType` | `onReaderPageTurnAnimationChanged` | `readerPageTurnAnimationType` | `number` | — |
| 788 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerLandscapeDoublePage` | `onReaderLandscapeDoublePageChanged` | `readerLandscapeDoublePage` | `boolean` | — |
| 789 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerScreenOrientation` | `onReaderScreenOrientationChanged` | `readerScreenOrientation` | `string` | — |
| 791 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerTapZoneActions` | — | `readerTapZoneActions` | `string` | — |
| 792 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerVolumeTurnPage` | `onReaderVolumeTurnPageChanged` | `readerVolumeTurnPage` | `boolean` | — |
| 793 | 眼动翻页 | `@StorageLink` | `readerEyeTurnEnabled` | — | `readerEyeTurnEnabled` | `boolean` | — |
| 794 | 眼动翻页 | `@StorageLink` | `readerEyeTurnPortraitCalibration` | — | `readerEyeTurnPortraitCalibration` | `string` | — |
| 795 | 眼动翻页 | `@StorageLink` | `readerEyeTurnLandscapeCalibration` | — | `readerEyeTurnLandscapeCalibration` | `string` | — |
| 796 | 眼动翻页 | `@StorageLink` | `readerEyeTurnPreviousEnabled` | — | `readerEyeTurnPreviousEnabled` | `boolean` | — |
| 797 | 眼动翻页 | `@StorageLink` | `readerEyeTurnNextEnabled` | — | `readerEyeTurnNextEnabled` | `boolean` | — |
| 798 | 眼动翻页 | `@StorageLink` | `readerEyeTurnPreviousDwellMs` | — | `readerEyeTurnPreviousDwellMs` | `number` | — |
| 799 | 眼动翻页 | `@StorageLink` | `readerEyeTurnNextDwellMs` | — | `readerEyeTurnNextDwellMs` | `number` | — |
| 801 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerAutoPageTurnActive` | `onAutoPageTurnActiveChanged` | `autoPageTurnActive` | `boolean` | — |
| 802 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerAutoPageTurnIntervalSec` | `onAutoPageTurnIntervalChanged` | `autoPageTurnIntervalSec` | `number` | — |
| 804 | 自动翻页 / 屏幕 / 快捷设置 | `@State` | — | — | `autoPageTurnRingProgress` | `number` | — |
| 805 | 自动翻页 / 屏幕 / 快捷设置 | `@State` | — | — | `autoPageTurnUserPaused` | `boolean` | — |
| 808 | 自动翻页 / 屏幕 / 快捷设置 | `@State` | — | `onSystemDialogFlagChanged` | `showAutoPageTurnIntervalDialog` | `boolean` | — |
| 809 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerScreenTimeoutMinutes` | — | `readerScreenTimeoutMinutes` | `number` | — |
| 811 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerExtendToStatusBar` | `onReaderExtendToStatusBarChanged` | `readerExtendToStatusBar` | `boolean` | — |
| 812 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerPreloadEnabled` | `onReaderPreloadChanged` | `readerPreloadEnabled` | `boolean` | — |
| 813 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerPreloadChapterCount` | `onReaderPreloadChanged` | `readerPreloadChapterCount` | `number` | — |
| 814 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerUseTtsQuickAction` | — | `readerUseTtsQuickAction` | `boolean` | — |
| 815 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerTtsQuickActionSide` | — | `readerTtsQuickActionSide` | `number` | — |
| 816 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerUseChapterQuickJump` | — | `readerUseChapterQuickJump` | `boolean` | — |
| 817 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerQuickBookmarkEnabled` | — | `readerQuickBookmarkEnabled` | `boolean` | — |
| 818 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerHeaderEnabled` | `onReaderChromeChanged` | `readerHeaderEnabled` | `boolean` | — |
| 819 | 书籍 / 章节 / 缓存 / 换源 | `@StorageLink` | `readerHeaderContentMode` | `onReaderChromeChanged` | `readerHeaderContentMode` | `string` | — |
| 820 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerFooterEnabled` | `onReaderChromeChanged` | `readerFooterEnabled` | `boolean` | — |
| 821 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerFooterLeftMode` | `onReaderChromeChanged` | `readerFooterLeftMode` | `string` | — |
| 822 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerFooterProgressMode` | `onReaderChromeChanged` | `readerFooterProgressMode` | `string` | — |
| 823 | 菜单 / 显隐 / 设置弹窗 | `@StorageLink` | `readerFooterShowProgressBar` | `onReaderChromeChanged` | `readerFooterShowProgressBar` | `boolean` | — |
| 824 | 书籍 / 章节 / 缓存 / 换源 | `@StorageLink` | `readerReplaceRulesUpdateTime` | `onReaderReplaceRulesChanged` | `readerReplaceRulesUpdateTime` | `number` | — |
| 825 | 字体 / 正则字体 | `@StorageLink` | `readerFontFamily` | `onReaderFontChanged` | `readerFontFamily` | `string` | — |
| 826 | 字体 / 正则字体 | `@StorageLink` | `readerFontFilePath` | `onReaderFontChanged` | `readerFontFilePath` | `string` | — |
| 827 | 字体 / 正则字体 | `@StorageLink` | `readerSystemFontFamily` | `onReaderActiveFontChanged` | `readerSystemFontFamily` | `string` | — |
| 828 | 字体 / 正则字体 | `@StorageLink` | `readerActiveFontFamily` | `onReaderActiveFontChanged` | `readerActiveFontFamily` | `string` | — |
| 829 | 字体 / 正则字体 | `@StorageLink` | `readerFontRegistered` | `onReaderActiveFontChanged` | `readerStoredFontRegistered` | `boolean` | — |
| 830 | 字体 / 正则字体 | `@StorageLink` | `readerBodyFontMode` | `onReaderFontStyleChanged` | `readerBodyFontMode` | `string` | — |
| 831 | 字体 / 正则字体 | `@StorageLink` | `readerBodyFontFamily` | `onReaderFontStyleChanged` | `readerBodyFontFamily` | `string` | — |
| 832 | 字体 / 正则字体 | `@StorageLink` | `readerTitleFontMode` | `onReaderFontStyleChanged` | `readerTitleFontMode` | `string` | — |
| 833 | 字体 / 正则字体 | `@StorageLink` | `readerTitleFontFamily` | `onReaderFontStyleChanged` | `readerTitleFontFamily` | `string` | — |
| 834 | 字体 / 正则字体 | `@StorageLink` | `readerTitleFontSize` | `onReaderFontStyleChanged` | `readerTitleFontSize` | `number` | — |
| 835 | 字体 / 正则字体 | `@StorageLink` | `readerRegexFontEnabled` | `onReaderFontStyleChanged` | `readerRegexFontEnabled` | `boolean` | — |
| 836 | 字体 / 正则字体 | `@StorageLink` | `readerRegexFontPattern` | `onReaderFontStyleChanged` | `readerRegexFontPattern` | `string` | — |
| 837 | 字体 / 正则字体 | `@StorageLink` | `readerRegexFontMode` | `onReaderFontStyleChanged` | `readerRegexFontMode` | `string` | — |
| 838 | 字体 / 正则字体 | `@StorageLink` | `readerRegexFontFamily` | `onReaderFontStyleChanged` | `readerRegexFontFamily` | `string` | — |
| 839 | 字体 / 正则字体 | `@StorageLink` | `readerRegexFontSize` | `onReaderFontStyleChanged` | `readerRegexFontSize` | `number` | — |
| 840 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerRegexShadowColor` | `onReaderFontStyleChanged` | `readerRegexShadowColor` | `string` | — |
| 841 | 字体 / 正则字体 | `@StorageLink` | `readerRegexFontRulesRaw` | `onReaderFontStyleChanged` | `readerRegexFontRulesRaw` | `string` | — |
| 842 | 字体 / 正则字体 | `@State` | — | — | `activeReaderFontFamily` | `string` | — |
| 843 | 字体 / 正则字体 | `@State` | — | — | `readerFontRegistered` | `boolean` | — |
| 844 | 字体 / 正则字体 | `@State` | — | — | `readerFontRenderReady` | `boolean` | — |
| 845 | 主题 / 夜间模式 | `@StorageLink` | `appDarkMode` | `onReaderColorModeChanged` | `appDarkMode` | `boolean` | — |
| 846 | 主题 / 夜间模式 | `@StorageLink` | `appThemeMode` | — | `appThemeMode` | `string` | — |
| 847 | 主题 / 夜间模式 | `@StorageLink` | `themeRevision` | `onReaderThemeChanged` | `themeRevision` | `number` | — |
| 848 | 主题 / 夜间模式 | `@StorageLink` | `appLightAccentColor` | — | `appLightAccentColor` | `string` | — |
| 849 | 主题 / 夜间模式 | `@StorageLink` | `appDarkAccentColor` | — | `appDarkAccentColor` | `string` | — |
| 850 | 主题 / 夜间模式 | `@StorageLink` | `appLightButtonColor` | — | `appLightButtonColor` | `string` | — |
| 851 | 主题 / 夜间模式 | `@StorageLink` | `appDarkButtonColor` | — | `appDarkButtonColor` | `string` | — |
| 852 | 封面 / 书架 | `@StorageLink` | `bookshelfCoverAlbums` | `onTtsCoverSettingsChanged` | `bookshelfCoverAlbums` | `string` | — |
| 853 | 封面 / 书架 | `@StorageLink` | `bookshelfLightCoverAlbumId` | `onTtsCoverSettingsChanged` | `bookshelfLightCoverAlbumId` | `string` | — |
| 854 | 封面 / 书架 | `@StorageLink` | `bookshelfDarkCoverAlbumId` | `onTtsCoverSettingsChanged` | `bookshelfDarkCoverAlbumId` | `string` | — |
| 855 | 封面 / 书架 | `@StorageLink` | `bookshelfCoverApplyScope` | `onTtsCoverSettingsChanged` | `bookshelfCoverApplyScope` | `string` | — |
| 856 | 封面 / 书架 | `@StorageLink` | `bookshelfCoverTargetBooks` | `onTtsCoverSettingsChanged` | `bookshelfCoverTargetBooks` | `string` | — |
| 857 | 封面 / 书架 | `@StorageLink` | `bookshelfIgnoreSourceCover` | `onTtsCoverSettingsChanged` | `bookshelfIgnoreSourceCover` | `boolean` | — |
| 858 | 封面 / 书架 | `@StorageLink` | `bookshelfCoverMode` | `onTtsCoverSettingsChanged` | `bookshelfCoverMode` | `string` | — |
| 859 | 封面 / 书架 | `@StorageLink` | `coverGalleryUpdateTime` | `onTtsCoverSettingsChanged` | `coverGalleryUpdateTime` | `number` | — |
| 860 | TTS 音色 / 语速设置 | `@StorageLink` | `ttsPerson` | — | `ttsPerson` | `number` | — |
| 861 | TTS 音色 / 语速设置 | `@StorageLink` | `ttsOnline` | — | `ttsOnline` | `number` | — |
| 862 | TTS 音色 / 语速设置 | `@StorageLink` | `ttsStyle` | — | `ttsStyle` | `string` | — |
| 863 | TTS 音色 / 语速设置 | `@StorageLink` | `ttsLanguage` | — | `ttsLanguage` | `string` | — |
| 864 | TTS 音色 / 语速设置 | `@StorageLink` | `ttsSpeed` | — | `ttsSpeed` | `number` | — |
| 865 | TTS 音色 / 语速设置 | `@StorageLink` | `ttsInstalledVoiceKeys` | — | `ttsInstalledVoiceKeys` | `string` | — |
| 866 | TTS 音色 / 语速设置 | `@StorageLink` | `ttsCustomVoiceId` | — | `ttsCustomVoiceId` | `string` | — |
| 867 | TTS 音色 / 语速设置 | `@StorageLink` | `ttsCustomVoices` | `onTtsCustomVoicesChanged` | `ttsCustomVoices` | `string` | — |
| 868 | 书籍 / 章节 / 缓存 / 换源 | `@StorageLink` | `launchShortcutNonce` | `onLaunchShortcutChanged` | `launchShortcutNonce` | `number` | — |
| 869 | 书籍 / 章节 / 缓存 / 换源 | `@StorageLink` | `fullTextCacheCancelNonce` | `onFullTextCacheCancelNonceChanged` | `fullTextCacheCancelNonce` | `number` | — |
| 870 | TTS 音色 / 语速设置 | `@State` | — | — | `ttsVoices` | `TtsVoiceOption[]` | — |
| 871 | TTS 音色 / 语速设置 | `@State` | — | — | `ttsCustomVoiceOptions` | `HttpTTS[]` | — |
| 872 | TTS 音色 / 语速设置 | `@State` | — | — | `ttsSelectedVoiceKey` | `string` | — |
| 873 | TTS 音色 / 语速设置 | `@State` | — | — | `ttsVoicesLoading` | `boolean` | — |
| 874 | TTS 音色 / 语速设置 | `@State` | — | — | `ttsDownloadingVoiceKey` | `string` | — |
| 875 | TTS 音色 / 语速设置 | `@State` | — | — | `showTtsVoiceDropdown` | `boolean` | — |
| 876 | TTS 音色 / 语速设置 | `@State` | — | — | `ttsVoiceRowPressedKey` | `string` | — |
| 877 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `fullTextCaching` | `boolean` | — |
| 878 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `fullTextCacheDone` | `number` | — |
| 879 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `fullTextCacheTotal` | `number` | — |
| 880 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `fullTextCacheStatus` | `string` | — |
| 881 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | `onSystemDialogFlagChanged` | `showReaderCacheDialog` | `boolean` | — |
| 882 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | `onSystemDialogFlagChanged` | `showReaderChapterCacheDialog` | `boolean` | — |
| 883 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `readerCacheChapters` | `BookChapter[]` | — |
| 884 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `readerCacheStatus` | `string` | — |
| 885 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `readerCacheRangeDraft` | `string` | — |
| 886 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `readerCacheRangeCaching` | `boolean` | — |
| 919 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerTypographyValueRevision` | `number` | — |
| 920 | 字体 / 正则字体 | `@State` | — | — | `readerTypographyFontSize` | `number` | — |
| 921 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerTypographyLetterSpacing` | `number` | — |
| 922 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerTypographyLineHeight` | `number` | — |
| 923 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerTypographyParagraphSpacing` | `number` | — |
| 924 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerTypographyMarginLeft` | `number` | — |
| 925 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerTypographyMarginRight` | `number` | — |
| 926 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerTypographyMarginTop` | `number` | — |
| 927 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerTypographyMarginBottom` | `number` | — |
| 959 | 眼动翻页 | `@State` | — | — | `arEyeTurnHostMounted` | `boolean` | — |
| 964 | 眼动翻页 | `@State` | — | — | `readerEyeTurnStatus` | `string` | — |
| 965 | 眼动翻页 | `@State` | — | — | `showReaderEyeCalibration` | `boolean` | — |
| 966 | 眼动翻页 | `@State` | — | — | `readerEyeCalibrationStep` | `number` | — |
| 967 | 眼动翻页 | `@State` | — | — | `readerEyeCalibrationCapturing` | `boolean` | — |
| 968 | 眼动翻页 | `@State` | — | — | `readerEyeCalibrationProgress` | `number` | — |
| 969 | 眼动翻页 | `@State` | — | — | `readerEyeCalibrationTargetY` | `number` | — |
| 970 | 眼动翻页 | `@State` | — | — | `readerEyeCalibrationOverlayWidth` | `number` | — |
| 971 | 眼动翻页 | `@State` | — | — | `readerEyeCalibrationOverlayHeight` | `number` | — |
| 976 | 眼动翻页 | `@State` | — | — | `readerEyeCalibrationSessionActive` | `boolean` | — |

## 共享状态警告（改代码前必读）

1. **V1 状态不能跨文件**：`@State` 必须留在 `@Component` 内。把逻辑抽到普通类时，必须照抄 `ReaderTtsBackgroundController` 的 `Controller + Host 接口` 模式（Host 持有 struct 引用，逐方法委托），不能让新类直接持有 `@State`。
2. **@Builder 提 @Component 会切断联动**：提成独立 `@Component` 后需用 `@Link/@Prop` 或 `AppStorage/@StorageLink` 接通数据；否则状态变更不再刷新 UI。
3. **隐式共享是最大耦合源**：已抽离的方法仍通过 `page.xxx` 直接读写同一批 `@State`，没有参数边界；`page` 只是显式传参，不是新状态容器。任何进一步抽取前先靠本表 + `ops_grep` 确认该方法触达的状态集合。
4. **边界判定别数括号**：`ReadBook.ets` 中方法一律以 2 空格缩进的 `}` 收尾；数括号会被正则字面量（如 `/^https?:\/\//i` 里的 `//`）当成行注释而误判，导致方法被截断、struct 提前闭合、整片级联报错。缩进锚定才可靠。
5. **长跑 TTS 跨章保活**：`finish()` 走 `keepAudioOutputOnFinish` 分支时曾不清帧时间线/缓存引用计数；A1–A9 主要修复已落地（换章软重置帧时间线、CacheLease TTL、drain 看门狗等），详见 `docs/tts-long-running-bugs.md`「修复状态」。

## 拆分蓝图（P0 → P3，每步小提交 + 真机回归，禁止大爆炸重写）

- **P0（已完成）**：顶层常量 → `reader/ReaderConstants.ets`（25 常量 + 1 缓存函数）；**131 个叶子纯函数** → `reader/ReaderLeafFns.ets`，调用方用 `import * as LeafFns` 命名空间引用；自底向上 5 批抽取后重扫 `pure=8` 全为结构性排除，纯函数抽离已收敛到不动点。
- **P0.5（已完成）**：941 个业务方法按 //region 抽到 12 个 `reader/*Ops.ets`，struct 内只留 1 行委托；`private` 字段与 `private` 方法改为可见（运行时擦除、零行为影响），`export struct ReadBookPage` 供 ops 模块做纯类型导入。ReadBook.ets 从 24417 → 12088 行（-12329）。核验：真 ArkTS 编译通过 + 941/941 方法体逐字回环一致 + 6 轮真机前后台回归 0 错误。
- **P1（未做）**：127 个 `@Builder` 按面板提独立 `@Component`（`ttsMiniPlayer`、`ttsExpandedMediaControlsBar`、`ttsQuickSettingsPanel` 等）。这会切断 ArkUI V1 的隐式联动，须用 `@Link/@Prop` 或 `@StorageLink` 重建数据通路，且只能靠真机视觉回归验证。
- **P2（未做）**：分页测量引擎 / TTS 编排 / 焦点·镜像 各自提 Controller+Host 类；本步已把它们的**代码**挪出巨型文件，剩下的工作是切状态边界。
- 目标：每单元 ≤ 1500–2000 行 / ≤ 100 KB，边界靠**显式接口**而非共享 `@State`。
- 执行节奏：**纯函数 → 常量 → UI 子组件 → 分页 → TTS 编排 → 焦点/镜像**；每步 `devecocli check arkts <file>` + 真机回归后再进下一步。

## 相关文档

- 听书长时间运行 Bug 分析（卡顿 / 浮标异常 / 翻页不顺 / 高亮卡住）：[docs/tts-long-running-bugs.md](docs/tts-long-running-bugs.md)
- 端云资产同步踩坑：见 `AGENTS.md` 内 `cloud-asset-sync debugging lessons` 段。
