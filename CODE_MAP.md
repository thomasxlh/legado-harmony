# CODE_MAP.md — 阅读页巨型文件导航

> 由 `scripts/gen_reader_code_map.py` 生成，**请勿手工改行号**。文件变动后在仓库根执行 `python scripts/gen_reader_code_map.py --apply` 重算（幂等，只增删注释行，保留所有代码原字节）。
> 面向 AI / 新人：先读本表定位职责域，再跳到 `entry/src/main/ets/pages/ReadBook.ets` 对应行号，避免把单文件整篇塞进上下文。

## 现状（为什么需要这张表）

- `entry/src/main/ets/pages/ReadBook.ets`：**6922 行 / 约 0.4 MB**；单文件内仅 1 个 `@Entry @Component struct ReadBookPage` + 1 个 `ReadBookTtsBackgroundHost` 适配器类。
- 响应式字段（`@State` / `@StorageLink` / `@StorageProp`）见下方「响应式状态域地图」，由脚本实时扫描生成；`@Builder` 33 个仍留在 struct 内（ArkUI DSL 不能外移），业务方法 941 个已抽到 `reader/*Ops.ets`，struct 内只保留 1 行委托；整个 `ets/` 目录 **0 个** `@Observed/@Track/@Provide/@Consume/@ObjectLink`（ArkUI V1 全内联状态）。
- 文件内唯一分区手段是本工具写入的 `//region` / `//endregion`（VS Code 与 IntelliJ/DevEco Studio 都能折叠）；每个区块头还带一行 `// [map] 契约:` 说明本区允许读写哪些状态。
- 已存在的可复用范式：`reader/ReaderPureUtils.ets`（纯函数）、`reader/ReaderTtsBackgroundController.ets` + Host 接口、`components/TtsGlobalCapsule.ets`、`components/ReaderTtsPlayerPanel.ets`、`components/TtsCatalogSheet.ets`（已抽出的 @Component）。

## 职责分区（行号 = 插入 `//region` 标记后的当前值）

| # | 区域 | 起始行 | 结束行 | 边界契约（允许读写哪些状态 / 注意事项） |
|---|------|-------:|-------:|------------------------------------------|
| 1 | 头部: 导入 / 顶层常量 / 纯函数 / 后台TTS Host适配器 | 1 | 403 | 无 @State 依赖; 顶层常量已抽到 reader/ReaderConstants.ets; ReadBookTtsBackgroundHost 仅逐方法委托 page |
| 2 | struct 声明与状态字段 (@State / @StorageLink / 私有字段) | 404 | 1052 | 仅声明状态, 不含逻辑; ArkUI V1 下 @State 必须留在本 @Component 内, 逻辑外移须走 Controller+Host |
| 3 | 生命周期 / 全局监听 / @Watch 回调 | 1053 | 1343 | 读写 会话/进度/可见性/焦点 状态; 装配后台控制器、注册(并应注销)全局监听与 @Watch |
| 4 | 书籍加载 / 全文缓存 / 后台长时任务 / 屏幕超时 / 加载遮罩 | 1344 | 1862 | 读写 book/chapters/content/缓存/遮罩 状态; 持有后台长时任务与多个成对 timer |
| 5 | build / 主内容层 / 悬浮菜单 / 目录·书签·换源·缓存面板 | 1863 | 3295 | 读 主题/排版/章节; 纯渲染 + 面板显隐; 交互只转发到方法, 不写业务状态 |
| 6 | 排版·字符集·替换规则设置 / TTS快捷入口·mini播放器·目录 / 书签 / 正文预处理 | 3296 | 3406 | 读写 设置/目录/书签/TTS浮标显示态; 含 ttsMiniPlayer 等大量 @Builder |
| 7 | 页眉页脚 / 漫画·连续滚动 / 页面度量 / 主题·字体 / 书签 / TTS音色·语速 / 目录搜索 | 3407 | 3716 | 读 排版/主题/字体/章节; 写 字体注册、书签、音色语速、目录滚动条 |
| 8 | 尺寸计算 / 排版变更监听 / 媒体控制条·睡眠定时器 / 触摸·翻页手势 | 3717 | 3987 | 读写 面板尺寸/排版代际/媒体控制/触摸 状态; 定时器成对清理 |
| 9 | 点击区域 / 设置面板 / 音色下拉 / 主题自定义 / 交互·眼动·预载设置 | 3988 | 4564 | 写 各类设置项持久化; 修改后触发重排 / 重载 / 重新分页 |
| 10 | TTS 浮标会话 / 朗读编排(起播·续播·换章·看门狗) / 后台委托 / 封面 / 高亮清理 | 4565 | 4656 | 核心长链路: ttsReadToken / ttsFocusGeneration / ttsChapterSwitching; 与浮标会话、AVSession 双向同步 |
| 11 | 焦点会话 / 正文规范化纯函数群 / 分页测量引擎 | 4657 | 4805 | 含大量可纯化的正文处理(findMeasuredPageEnd 等); 分页测量读排版状态 |
| 12 | 逐句焦点·高亮·进度持久化 / 镜像会话 / TTS翻页 / 动画表面 | 4806 | 5375 | 每句触发 followTtsChunk→高亮重绘→persistTtsReadPosition→浮标 revision++; 镜像会话接管线 |
| 13 | 样式化正文 / 段评·源动作·文本选择 / 正则高亮 / V2布局·分页·选区·高亮 | 5376 | 6650 | 读 高亮偏移/正则规则/主题; V2 分页与选区是独立大子系统, 建议优先外移 |
| 14 | 分页缓存 / 翻页·预载·自动翻页 / 翻页动画·卷曲 / 换章 | 6651 | 6922 | 写 currentPageIndex / 翻页动画状态 / 预载; 与 TTS 翻页、镜像手动翻页交织 |

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
| `reader/ReaderTtsOrchestrationOps.ets` | 65 | 1261 |
| **合计** | **941** | |

## 关键入口方法索引

行号为 `struct ReadBookPage` 内定义位置；`ReadBookTtsBackgroundHost` 在文件前部有同名委托方法，用 `/` 一并列出。多个定义用 `/` 分隔。

| 方法 | 行 |
|------|----|
| `aboutToAppear` | 1056 |
| `onPageShow` | 1122 |
| `onBackPress` | 1207 |
| `aboutToDisappear` | 1257 |
| `onPageHide` | 1325 |
| `build` | 1866 |
| `loadBook` | 1358 |
| `loadContent` | 389 / 1533 |
| `saveReadingProgress` | 394 / 3907 |
| `enterReaderImmersive` | 1348 |
| `readerQuickSettingsPanel` | 4206 |
| `settingsPanel` | 4018 |
| `publishTtsFloatingSession` | 4568 |
| `publishTtsFloatingVoices` | 4569 |
| `updateTtsFloatingSession` | 4570 |
| `stopTtsFloatingSession` | 4571 |
| `toggleTtsReading` | 354 / 4572 |
| `startTtsReadingFromCurrentPosition` | 358 / 4575 |
| `stopTtsReading` | 365 / 4583 |
| `continueTtsReading` | 4593 |
| `isTtsReadingAtExpectedEnd` | 4594 |
| `armTtsContinuationWatchdog` | 4600 |
| `clearTtsContinuationWatchdog` | 385 / 4601 |
| `advanceTtsReadingToNextChapter` | 4602 |
| `finishTtsReading` | 4603 |
| `prepareTtsForManualPageTurn` | 377 / 4589 |
| `scheduleTtsResumeAfterManualPageTurn` | 381 / 4590 |
| `playPositionFromFloatingSession` | 4645 |
| `startTtsBackgroundRunning` | 4608 |
| `stopTtsBackgroundRunning` | 4609 |
| `updateTtsAvSessionPlaybackState` | 4611 |
| `clearTtsHighlight` | 4660 |
| `publishTtsHighlightRenderChange` | 4661 |
| `currentTtsSourceIdentity` | 4662 |
| `invalidateTtsFocusSession` | 4663 |
| `isCurrentTtsFocusSession` | 4665 |
| `getTtsReadingText` | 4670 |
| `getTtsFocusBreakOffsets` | 4671 |
| `normalizeReaderText` | → `reader/ReaderLeafFns.ets`（已抽离为纯函数） |
| `getPagedSourceText` | 4672 |
| `buildPagedSourceText` | 4673 |
| `findMeasuredPageEnd` | 4697 |
| `refineMeasuredPageEnd` | 4712 |
| `followTtsChunk` | 4812 |
| `noteTtsFocusLatency` | 4817 |
| `applyTtsChunkFocus` | 4818 |
| `syncTtsFocusAfterResume` | 4825 |
| `updateTtsChunkHighlight` | 4827 |
| `republishTtsFocusAfterPageTurn` | 4837 |
| `scheduleTtsFocusSyncAfterPagination` | 4842 |
| `persistTtsReadPosition` | 4844 |
| `restorePersistedTtsFocus` | 4847 |
| `syncMirroredTtsFocus` | 4850 |
| `clearMirroredTtsFocus` | 4851 |
| `takeOverMirroredTtsSession` | 4856 |
| `animateTtsToPage` | 4858 |
| `applyTtsPageTarget` | 4861 |
| `applyTtsPageTurn` | 4865 |
| `styledReaderText` | 5380 |
| `splitSlicesByTtsHighlight` | 5945 |
| `hasActiveTtsHighlight` | 5987 |
| `shouldUseReaderLayoutV2` | 5992 |
| `buildReaderV2Snapshot` | 5993 |
| `refreshReaderV2TtsOverlay` | 6648 |
| `paginateReaderSourceText` | 6654 |
| `turnNext` | 6720 |
| `turnPrev` | 6729 |
| `applyPageTurn` | 6797 |
| `runPageTurnAnimation` | 6808 |
| `prepareMirroredTtsManualPageTurn` | 6813 |
| `cancelMirroredTtsManualPageTurn` | 6815 |
| `drawReaderPageCurl` | 6885 |
| `loadNextChapter` | 6915 |
| `loadPrevChapter` | 6917 |

（共索引 74 个关键方法；未列出的多为 `@Builder` 或仅在表达式中出现。）

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
| 409 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `bookUrl` | `string` | — |
| 410 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `book` | `Book \| null` | — |
| 411 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `chapters` | `BookChapter[]` | — |
| 412 | 目录 TOC | `@State` | — | — | `tocVisibleChapters` | `BookChapter[]` | — |
| 413 | 目录 TOC | `@State` | — | — | `tocWindowStart` | `number` | — |
| 414 | 目录 TOC | `@State` | — | — | `tocQuickJumpArmed` | `boolean` | — |
| 415 | 目录 TOC | `@State` | — | — | `tocQuickJumpInputVisible` | `boolean` | — |
| 416 | 目录 TOC | `@State` | — | — | `tocQuickJumpDraft` | `string` | — |
| 417 | 目录 TOC | `@State` | — | — | `tocSearchVisible` | `boolean` | — |
| 418 | 目录 TOC | `@State` | — | — | `tocSearchQuery` | `string` | — |
| 419 | 目录 TOC | `@State` | — | — | `tocSearchChapterIndexes` | `number[]` | — |
| 420 | 目录 TOC | `@State` | — | — | `tocSearchLoading` | `boolean` | — |
| 421 | 目录 TOC | `@State` | — | — | `tocSearchResultActive` | `boolean` | — |
| 422 | 目录 TOC | `@State` | — | — | `tocReverseOrder` | `boolean` | — |
| 423 | 目录 TOC | `@State` | — | — | `tocOrderRevision` | `number` | — |
| 424 | 目录 TOC | `@State` | — | — | `tocDatabaseChapterCount` | `number` | — |
| 425 | 目录 TOC | `@State` | — | — | `tocListViewportHeight` | `number` | — |
| 426 | 目录 TOC | `@State` | — | — | `tocFirstVisibleGlobalIndex` | `number` | — |
| 427 | 目录 TOC | `@State` | — | — | `tocVisibleItemCount` | `number` | — |
| 428 | 目录 TOC | `@State` | — | — | `tocScrollbarDragging` | `boolean` | — |
| 429 | 目录 TOC | `@State` | — | — | `tocScrollbarDragOffset` | `number` | — |
| 434 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `currentChapterIndex` | `number` | — |
| 435 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `menuChapterPreviewIndex` | `number` | — |
| 436 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `menuChapterSliderActive` | `boolean` | — |
| 437 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `menuChapterTooltipVisible` | `boolean` | — |
| 438 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `menuChapterConfirming` | `boolean` | — |
| 439 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `content` | `string` | — |
| 440 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `readerReplaceRules` | `ReaderReplaceRule[]` | — |
| 441 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | `onReaderLoadingChanged` | `isLoading` | `boolean` | — |
| 443 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `readerLoadingSlow` | `boolean` | — |
| 445 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `showMenu` | `boolean` | — |
| 446 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `hdsMaterialRenderBranch` | `boolean` | — |
| 447 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `readerDayNightLongPressHandled` | `boolean` | — |
| 449 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `readerMenuAnchorSide` | `number` | — |
| 450 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `showReaderActionMenu` | `boolean` | — |
| 451 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `showLayoutElementSettings` | `boolean` | — |
| 457 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | `onSystemDialogFlagChanged` | `showTxtCharsetDialog` | `boolean` | — |
| 458 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `txtCharsetDraft` | `string` | — |
| 459 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `txtCharsetApplying` | `boolean` | — |
| 460 | 段评 / 评论面板 | `@State` | — | — | `showReaderCommentPanel` | `boolean` | — |
| 461 | 段评 / 评论面板 | `@State` | — | — | `readerCommentPanelTitle` | `string` | — |
| 462 | 段评 / 评论面板 | `@State` | — | — | `readerCommentPanelUrl` | `string` | — |
| 463 | 段评 / 评论面板 | `@State` | — | — | `readerCommentPanelProgress` | `number` | — |
| 464 | 段评 / 评论面板 | `@State` | — | — | `readerCommentPanelLoading` | `boolean` | — |
| 465 | 段评 / 评论面板 | `@State` | — | — | `readerCommentPanelHeightRatio` | `number` | — |
| 466 | 段评 / 评论面板 | `@State` | — | — | `readerCommentPanelHeightValue` | `number` | — |
| 475 | 目录 TOC | `@State` | — | — | `showToc` | `boolean` | — |
| 476 | 目录 TOC | `@State` | — | — | `tocPanelTab` | `number` | — |
| 477 | 书签 | `@State` | — | — | `bookmarks` | `Bookmark[]` | — |
| 478 | 书签 | `@State` | — | — | `bookmarkMultiSelectMode` | `boolean` | — |
| 479 | 书签 | `@State` | — | — | `selectedBookmarkUrls` | `string[]` | — |
| 480 | 书签 | `@State` | — | — | `showBookmarkActionMenu` | `boolean` | — |
| 481 | 书签 | `@State` | — | — | `pendingBookmarkAction` | `Bookmark \| null` | — |
| 482 | 书签 | `@State` | — | — | `bookmarkActionMenuX` | `number` | — |
| 483 | 书签 | `@State` | — | — | `bookmarkActionMenuY` | `number` | — |
| 484 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `showSettings` | `boolean` | — |
| 485 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | `onSystemDialogFlagChanged` | `showTapZoneSettings` | `boolean` | — |
| 486 | 主题 / 夜间模式 | `@State` | — | `onSystemDialogFlagChanged` | `showReaderCustomThemeDeleteConfirm` | `boolean` | — |
| 487 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `settingsPanelTab` | `number` | — |
| 488 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerTypographySelection` | `number` | — |
| 489 | 菜单 / 显隐 / 设置弹窗 | `@State` | — | — | `showReaderTypographyValueInput` | `boolean` | — |
| 490 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerTypographyValueDraft` | `string` | — |
| 491 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `loadStatus` | `string` | — |
| 492 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `verificationUrl` | `string` | — |
| 493 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `verificationTitle` | `string` | — |
| 494 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `showChangeSourceDialog` | `boolean` | — |
| 495 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `pendingSwitchedBook` | `Book \| null` | — |
| 496 | 分页 / V2 布局 / 选区 | `@State` | — | — | `contentPages` | `string[]` | — |
| 497 | 分页 / V2 布局 / 选区 | `@State` | — | — | `currentPageIndex` | `number` | — |
| 498 | 分页 / V2 布局 / 选区 | `@State` | — | — | `currentPageText` | `string` | — |
| 499 | 分页 / V2 布局 / 选区 | `@State` | — | — | `displayPageText` | `string` | — |
| 500 | 分页 / V2 布局 / 选区 | `@State` | — | — | `displayPageChapterIndex` | `number` | — |
| 501 | 分页 / V2 布局 / 选区 | `@State` | — | — | `displayPageIndex` | `number` | — |
| 502 | 分页 / V2 布局 / 选区 | `@State` | — | — | `displayPageRenderKey` | `number` | — |
| 503 | 分页 / V2 布局 / 选区 | `@State` | — | — | `pageRenderVersion` | `number` | — |
| 504 | 分页 / V2 布局 / 选区 | `@State` | — | — | `chapterJumpRenderGeneration` | `number` | — |
| 505 | 分页 / V2 布局 / 选区 | `@State` | — | — | `readerV2SurfaceGeneration` | `number` | — |
| 506 | 分页 / V2 布局 / 选区 | `@State` | — | — | `pageViewWidth` | `number` | — |
| 507 | 分页 / V2 布局 / 选区 | `@State` | — | — | `pageViewHeight` | `number` | — |
| 508 | 分页 / V2 布局 / 选区 | `@State` | — | — | `readerBottomInfoBarMeasuredHeight` | `number` | — |
| 509 | 分页 / V2 布局 / 选区 | `@State` | — | — | `readerInitialPageReady` | `boolean` | — |
| 510 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerInitialOpening` | `boolean` | — |
| 511 | 分页 / V2 布局 / 选区 | `@State` | — | — | `readerWebFetchRuntimeNeeded` | `boolean` | — |
| 512 | 漫画模式 | `@State` | — | — | `readerComicMode` | `boolean` | — |
| 513 | 漫画模式 | `@State` | — | — | `readerComicImageRatios` | `number[]` | — |
| 515 | 漫画模式 | `@State` | — | — | `readerComicBrokenPages` | `number[]` | — |
| 516 | 漫画模式 | `@State` | — | — | `readerComicPaginationParsing` | `boolean` | — |
| 517 | 漫画模式 | `@State` | — | — | `readerComicPaginationParsedPages` | `number` | — |
| 518 | 漫画模式 | `@State` | — | — | `readerComicPaginationTotalPages` | `number` | — |
| 519 | 漫画模式 | `@State` | — | — | `readerComicChapterSwitching` | `boolean` | — |
| 520 | 漫画模式 | `@State` | — | — | `readerComicBoundaryDirection` | `number` | — |
| 521 | 漫画模式 | `@State` | — | — | `readerComicBoundaryPullDistance` | `number` | — |
| 522 | 漫画模式 | `@State` | — | — | `readerComicBoundaryReady` | `boolean` | — |
| 523 | 漫画模式 | `@State` | — | — | `readerComicChapterTransitionY` | `number` | — |
| 524 | 漫画模式 | `@State` | — | — | `readerComicChapterTransitionOpacity` | `number` | — |
| 526 | 分页 / V2 布局 / 选区 | `@State` | — | — | `statusBarSafeHeight` | `number` | — |
| 527 | 分页 / V2 布局 / 选区 | `@StorageProp` | `statusBarHeight` | `onStoredStatusBarHeightChanged` | `storedStatusBarHeight` | `number` | — |
| 528 | 分页 / V2 布局 / 选区 | `@StorageProp` | `navBarHeight` | — | `navBarHeight` | `number` | — |
| 529 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `isTtsSpeaking` | `boolean` | — |
| 530 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `isTtsPaused` | `boolean` | — |
| 531 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `ttsPagedScrollOverride` | `boolean` | — |
| 532 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `ttsMediaControlsExpanded` | `boolean` | — |
| 533 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `ttsDisplayText` | `string` | — |
| 534 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `ttsHighlightStart` | `number` | — |
| 535 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `ttsHighlightEnd` | `number` | — |
| 536 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `ttsHighlightRenderVersion` | `number` | — |
| 537 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `readerV2TtsPaintVersion` | `number` | — |
| 538 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `readerV2SelectionPaintVersion` | `number` | — |
| 539 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `ttsSleepTimerMinutes` | `number` | — |
| 540 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `ttsSleepTimerRemainingSeconds` | `number` | — |
| 541 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsActive` | `onGlobalTtsActiveChanged` | `globalTtsActive` | `boolean` | — |
| 542 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsPaused` | — | `globalTtsPaused` | `boolean` | — |
| 543 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsBookName` | — | `globalTtsBookName` | `string` | — |
| 544 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsChapterTitle` | — | `globalTtsChapterTitle` | `string` | — |
| 545 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsMode` | — | `globalTtsMode` | `string` | — |
| 546 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsChapterProgress` | — | `globalTtsChapterProgress` | `string` | — |
| 547 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsCanPrevious` | — | `globalTtsCanPrevious` | `boolean` | — |
| 548 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsCanNext` | — | `globalTtsCanNext` | `boolean` | — |
| 549 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsBookUrl` | — | `globalTtsBookUrl` | `string` | — |
| 550 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsChapterIndex` | — | `globalTtsChapterIndex` | `number` | — |
| 551 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsOffsetStart` | — | `globalTtsOffsetStart` | `number` | — |
| 552 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsOffsetEnd` | — | `globalTtsOffsetEnd` | `number` | — |
| 553 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@StorageLink` | `globalTtsRevision` | `onGlobalTtsRevisionChanged` | `globalTtsRevision` | `number` | — |
| 554 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `showGlobalTtsCatalog` | `boolean` | — |
| 555 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `globalTtsCatalogReverseOrder` | `boolean` | — |
| 618 | TTS 朗读会话 / 浮标 / 逐句高亮 | `@State` | — | — | `mirroredTtsFocusActive` | `boolean` | — |
| 713 | 翻页动画 / 手势 | `@State` | — | — | `readerPageCurlSnapshotReady` | `boolean` | — |
| 714 | 翻页动画 / 手势 | `@State` | — | — | `pageTransitionX` | `number` | — |
| 715 | 翻页动画 / 手势 | `@State` | — | — | `pageTransitionOpacity` | `number` | — |
| 716 | 翻页动画 / 手势 | `@State` | — | — | `pageSlideOffsetX` | `number` | — |
| 717 | 翻页动画 / 手势 | `@State` | — | — | `pageSlideOffsetY` | `number` | — |
| 718 | 翻页动画 / 手势 | `@State` | — | — | `bookmarkPullOffsetY` | `number` | — |
| 719 | 翻页动画 / 手势 | `@State` | — | — | `bookmarkPullActive` | `boolean` | — |
| 720 | 翻页动画 / 手势 | `@State` | — | — | `bookmarkPullReady` | `boolean` | — |
| 721 | 翻页动画 / 手势 | `@State` | — | — | `pageSlideDirection` | `number` | — |
| 722 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnAnimating` | `boolean` | — |
| 723 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnIncomingText` | `string` | — |
| 724 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnIncomingSecondaryText` | `string` | — |
| 725 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnIncomingX` | `number` | — |
| 726 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnIncomingOpacity` | `number` | — |
| 727 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnIncomingPageIndex` | `number` | — |
| 728 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnIncomingChapterIndex` | `number` | — |
| 729 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnIncomingPageStart` | `number` | — |
| 730 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnIncomingSecondaryPageStart` | `number` | — |
| 731 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnIncomingDocumentSource` | `string` | — |
| 732 | 翻页动画 / 手势 | `@State` | — | — | `pageTurnIncomingRenderVersion` | `number` | — |
| 778 | 分页 / V2 布局 / 选区 | `@State` | — | — | `readerTextSelectionActive` | `boolean` | — |
| 785 | 分页 / V2 布局 / 选区 | `@State` | — | — | `readerV2NativeSelectionHostVersion` | `number` | — |
| 796 | 分页 / V2 布局 / 选区 | `@State` | — | — | `readerV2NativeSelectionOffsetX` | `number` | — |
| 797 | 分页 / V2 布局 / 选区 | `@State` | — | — | `readerV2NativeSelectionOffsetY` | `number` | — |
| 839 | 字体 / 正则字体 | `@StorageLink` | `readerFontSize` | `onReadLayoutChanged` | `readerFontSize` | `number` | — |
| 840 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerLetterSpacing` | `onReadLayoutChanged` | `readerLetterSpacing` | `number` | — |
| 841 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerTextAlign` | `onReadLayoutChanged` | `readerTextAlign` | `string` | — |
| 842 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerLineHeight` | `onReadLayoutChanged` | `readerLineHeight` | `number` | — |
| 843 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerParagraphSpacing` | `onReadLayoutChanged` | `readerParagraphSpacing` | `number` | — |
| 845 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerKeepParagraphIndent` | `onReadLayoutChanged` | `keepParagraphIndent` | `boolean` | — |
| 846 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerMarginLeft` | `onReadLayoutChanged` | `readerMarginLeft` | `number` | — |
| 847 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerMarginRight` | `onReadLayoutChanged` | `readerMarginRight` | `number` | — |
| 848 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerMarginTop` | `onReadLayoutChanged` | `readerMarginTop` | `number` | — |
| 849 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerMarginBottom` | `onReadLayoutChanged` | `readerMarginBottom` | `number` | — |
| 850 | 主题 / 夜间模式 | `@StorageLink` | `readerLightThemeIndex` | `onReaderThemeChanged` | `readerLightThemeIndex` | `number` | — |
| 851 | 主题 / 夜间模式 | `@StorageLink` | `readerDarkThemeIndex` | `onReaderThemeChanged` | `readerDarkThemeIndex` | `number` | — |
| 852 | 主题 / 夜间模式 | `@StorageLink` | `readerLightCustomThemeBackgroundColor` | `onReaderThemeChanged` | `readerLightCustomThemeBackgroundColor` | `string` | — |
| 853 | 主题 / 夜间模式 | `@StorageLink` | `readerLightCustomThemeTextColor` | `onReaderThemeChanged` | `readerLightCustomThemeTextColor` | `string` | — |
| 854 | 主题 / 夜间模式 | `@StorageLink` | `readerDarkCustomThemeBackgroundColor` | `onReaderThemeChanged` | `readerDarkCustomThemeBackgroundColor` | `string` | — |
| 855 | 主题 / 夜间模式 | `@StorageLink` | `readerDarkCustomThemeTextColor` | `onReaderThemeChanged` | `readerDarkCustomThemeTextColor` | `string` | — |
| 856 | 主题 / 夜间模式 | `@StorageLink` | `readerCustomThemesRaw` | `onReaderThemeChanged` | `readerCustomThemesRaw` | `string` | — |
| 857 | 主题 / 夜间模式 | `@State` | — | — | `customThemeNameDraft` | `string` | — |
| 858 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerPageTurnMode` | — | `readerPageTurnMode` | `number` | — |
| 859 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerPageTurnAnimationType` | `onReaderPageTurnAnimationChanged` | `readerPageTurnAnimationType` | `number` | — |
| 860 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerLandscapeDoublePage` | `onReaderLandscapeDoublePageChanged` | `readerLandscapeDoublePage` | `boolean` | — |
| 861 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerScreenOrientation` | `onReaderScreenOrientationChanged` | `readerScreenOrientation` | `string` | — |
| 863 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerTapZoneActions` | — | `readerTapZoneActions` | `string` | — |
| 864 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerVolumeTurnPage` | `onReaderVolumeTurnPageChanged` | `readerVolumeTurnPage` | `boolean` | — |
| 865 | 眼动翻页 | `@StorageLink` | `readerEyeTurnEnabled` | — | `readerEyeTurnEnabled` | `boolean` | — |
| 866 | 眼动翻页 | `@StorageLink` | `readerEyeTurnPortraitCalibration` | — | `readerEyeTurnPortraitCalibration` | `string` | — |
| 867 | 眼动翻页 | `@StorageLink` | `readerEyeTurnLandscapeCalibration` | — | `readerEyeTurnLandscapeCalibration` | `string` | — |
| 868 | 眼动翻页 | `@StorageLink` | `readerEyeTurnPreviousEnabled` | — | `readerEyeTurnPreviousEnabled` | `boolean` | — |
| 869 | 眼动翻页 | `@StorageLink` | `readerEyeTurnNextEnabled` | — | `readerEyeTurnNextEnabled` | `boolean` | — |
| 870 | 眼动翻页 | `@StorageLink` | `readerEyeTurnPreviousDwellMs` | — | `readerEyeTurnPreviousDwellMs` | `number` | — |
| 871 | 眼动翻页 | `@StorageLink` | `readerEyeTurnNextDwellMs` | — | `readerEyeTurnNextDwellMs` | `number` | — |
| 873 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerAutoPageTurnActive` | `onAutoPageTurnActiveChanged` | `autoPageTurnActive` | `boolean` | — |
| 874 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerAutoPageTurnIntervalSec` | `onAutoPageTurnIntervalChanged` | `autoPageTurnIntervalSec` | `number` | — |
| 876 | 自动翻页 / 屏幕 / 快捷设置 | `@State` | — | — | `autoPageTurnRingProgress` | `number` | — |
| 877 | 自动翻页 / 屏幕 / 快捷设置 | `@State` | — | — | `autoPageTurnUserPaused` | `boolean` | — |
| 880 | 自动翻页 / 屏幕 / 快捷设置 | `@State` | — | `onSystemDialogFlagChanged` | `showAutoPageTurnIntervalDialog` | `boolean` | — |
| 881 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerScreenTimeoutMinutes` | — | `readerScreenTimeoutMinutes` | `number` | — |
| 883 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerExtendToStatusBar` | `onReaderExtendToStatusBarChanged` | `readerExtendToStatusBar` | `boolean` | — |
| 884 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerPreloadEnabled` | `onReaderPreloadChanged` | `readerPreloadEnabled` | `boolean` | — |
| 885 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerPreloadChapterCount` | `onReaderPreloadChanged` | `readerPreloadChapterCount` | `number` | — |
| 886 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerUseTtsQuickAction` | — | `readerUseTtsQuickAction` | `boolean` | — |
| 887 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerTtsQuickActionSide` | — | `readerTtsQuickActionSide` | `number` | — |
| 888 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerUseChapterQuickJump` | — | `readerUseChapterQuickJump` | `boolean` | — |
| 889 | 自动翻页 / 屏幕 / 快捷设置 | `@StorageLink` | `readerQuickBookmarkEnabled` | — | `readerQuickBookmarkEnabled` | `boolean` | — |
| 890 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerHeaderEnabled` | `onReaderChromeChanged` | `readerHeaderEnabled` | `boolean` | — |
| 891 | 书籍 / 章节 / 缓存 / 换源 | `@StorageLink` | `readerHeaderContentMode` | `onReaderChromeChanged` | `readerHeaderContentMode` | `string` | — |
| 892 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerFooterEnabled` | `onReaderChromeChanged` | `readerFooterEnabled` | `boolean` | — |
| 893 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerFooterLeftMode` | `onReaderChromeChanged` | `readerFooterLeftMode` | `string` | — |
| 894 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerFooterProgressMode` | `onReaderChromeChanged` | `readerFooterProgressMode` | `string` | — |
| 895 | 菜单 / 显隐 / 设置弹窗 | `@StorageLink` | `readerFooterShowProgressBar` | `onReaderChromeChanged` | `readerFooterShowProgressBar` | `boolean` | — |
| 896 | 书籍 / 章节 / 缓存 / 换源 | `@StorageLink` | `readerReplaceRulesUpdateTime` | `onReaderReplaceRulesChanged` | `readerReplaceRulesUpdateTime` | `number` | — |
| 897 | 字体 / 正则字体 | `@StorageLink` | `readerFontFamily` | `onReaderFontChanged` | `readerFontFamily` | `string` | — |
| 898 | 字体 / 正则字体 | `@StorageLink` | `readerFontFilePath` | `onReaderFontChanged` | `readerFontFilePath` | `string` | — |
| 899 | 字体 / 正则字体 | `@StorageLink` | `readerSystemFontFamily` | `onReaderActiveFontChanged` | `readerSystemFontFamily` | `string` | — |
| 900 | 字体 / 正则字体 | `@StorageLink` | `readerActiveFontFamily` | `onReaderActiveFontChanged` | `readerActiveFontFamily` | `string` | — |
| 901 | 字体 / 正则字体 | `@StorageLink` | `readerFontRegistered` | `onReaderActiveFontChanged` | `readerStoredFontRegistered` | `boolean` | — |
| 902 | 字体 / 正则字体 | `@StorageLink` | `readerBodyFontMode` | `onReaderFontStyleChanged` | `readerBodyFontMode` | `string` | — |
| 903 | 字体 / 正则字体 | `@StorageLink` | `readerBodyFontFamily` | `onReaderFontStyleChanged` | `readerBodyFontFamily` | `string` | — |
| 904 | 字体 / 正则字体 | `@StorageLink` | `readerTitleFontMode` | `onReaderFontStyleChanged` | `readerTitleFontMode` | `string` | — |
| 905 | 字体 / 正则字体 | `@StorageLink` | `readerTitleFontFamily` | `onReaderFontStyleChanged` | `readerTitleFontFamily` | `string` | — |
| 906 | 字体 / 正则字体 | `@StorageLink` | `readerTitleFontSize` | `onReaderFontStyleChanged` | `readerTitleFontSize` | `number` | — |
| 907 | 字体 / 正则字体 | `@StorageLink` | `readerRegexFontEnabled` | `onReaderFontStyleChanged` | `readerRegexFontEnabled` | `boolean` | — |
| 908 | 字体 / 正则字体 | `@StorageLink` | `readerRegexFontPattern` | `onReaderFontStyleChanged` | `readerRegexFontPattern` | `string` | — |
| 909 | 字体 / 正则字体 | `@StorageLink` | `readerRegexFontMode` | `onReaderFontStyleChanged` | `readerRegexFontMode` | `string` | — |
| 910 | 字体 / 正则字体 | `@StorageLink` | `readerRegexFontFamily` | `onReaderFontStyleChanged` | `readerRegexFontFamily` | `string` | — |
| 911 | 字体 / 正则字体 | `@StorageLink` | `readerRegexFontSize` | `onReaderFontStyleChanged` | `readerRegexFontSize` | `number` | — |
| 912 | 阅读排版与交互设置 (通用) | `@StorageLink` | `readerRegexShadowColor` | `onReaderFontStyleChanged` | `readerRegexShadowColor` | `string` | — |
| 913 | 字体 / 正则字体 | `@StorageLink` | `readerRegexFontRulesRaw` | `onReaderFontStyleChanged` | `readerRegexFontRulesRaw` | `string` | — |
| 914 | 字体 / 正则字体 | `@State` | — | — | `activeReaderFontFamily` | `string` | — |
| 915 | 字体 / 正则字体 | `@State` | — | — | `readerFontRegistered` | `boolean` | — |
| 916 | 字体 / 正则字体 | `@State` | — | — | `readerFontRenderReady` | `boolean` | — |
| 917 | 主题 / 夜间模式 | `@StorageLink` | `appDarkMode` | `onReaderColorModeChanged` | `appDarkMode` | `boolean` | — |
| 918 | 主题 / 夜间模式 | `@StorageLink` | `appThemeMode` | — | `appThemeMode` | `string` | — |
| 919 | 主题 / 夜间模式 | `@StorageLink` | `themeRevision` | `onReaderThemeChanged` | `themeRevision` | `number` | — |
| 920 | 主题 / 夜间模式 | `@StorageLink` | `appLightAccentColor` | — | `appLightAccentColor` | `string` | — |
| 921 | 主题 / 夜间模式 | `@StorageLink` | `appDarkAccentColor` | — | `appDarkAccentColor` | `string` | — |
| 922 | 主题 / 夜间模式 | `@StorageLink` | `appLightButtonColor` | — | `appLightButtonColor` | `string` | — |
| 923 | 主题 / 夜间模式 | `@StorageLink` | `appDarkButtonColor` | — | `appDarkButtonColor` | `string` | — |
| 924 | 封面 / 书架 | `@StorageLink` | `bookshelfCoverAlbums` | `onTtsCoverSettingsChanged` | `bookshelfCoverAlbums` | `string` | — |
| 925 | 封面 / 书架 | `@StorageLink` | `bookshelfLightCoverAlbumId` | `onTtsCoverSettingsChanged` | `bookshelfLightCoverAlbumId` | `string` | — |
| 926 | 封面 / 书架 | `@StorageLink` | `bookshelfDarkCoverAlbumId` | `onTtsCoverSettingsChanged` | `bookshelfDarkCoverAlbumId` | `string` | — |
| 927 | 封面 / 书架 | `@StorageLink` | `bookshelfCoverApplyScope` | `onTtsCoverSettingsChanged` | `bookshelfCoverApplyScope` | `string` | — |
| 928 | 封面 / 书架 | `@StorageLink` | `bookshelfCoverTargetBooks` | `onTtsCoverSettingsChanged` | `bookshelfCoverTargetBooks` | `string` | — |
| 929 | 封面 / 书架 | `@StorageLink` | `bookshelfIgnoreSourceCover` | `onTtsCoverSettingsChanged` | `bookshelfIgnoreSourceCover` | `boolean` | — |
| 930 | 封面 / 书架 | `@StorageLink` | `bookshelfCoverMode` | `onTtsCoverSettingsChanged` | `bookshelfCoverMode` | `string` | — |
| 931 | 封面 / 书架 | `@StorageLink` | `coverGalleryUpdateTime` | `onTtsCoverSettingsChanged` | `coverGalleryUpdateTime` | `number` | — |
| 932 | TTS 音色 / 语速设置 | `@StorageLink` | `ttsPerson` | — | `ttsPerson` | `number` | — |
| 933 | TTS 音色 / 语速设置 | `@StorageLink` | `ttsOnline` | — | `ttsOnline` | `number` | — |
| 934 | TTS 音色 / 语速设置 | `@StorageLink` | `ttsStyle` | — | `ttsStyle` | `string` | — |
| 935 | TTS 音色 / 语速设置 | `@StorageLink` | `ttsLanguage` | — | `ttsLanguage` | `string` | — |
| 936 | TTS 音色 / 语速设置 | `@StorageLink` | `ttsSpeed` | — | `ttsSpeed` | `number` | — |
| 937 | TTS 音色 / 语速设置 | `@StorageLink` | `ttsInstalledVoiceKeys` | — | `ttsInstalledVoiceKeys` | `string` | — |
| 938 | TTS 音色 / 语速设置 | `@StorageLink` | `ttsCustomVoiceId` | — | `ttsCustomVoiceId` | `string` | — |
| 939 | TTS 音色 / 语速设置 | `@StorageLink` | `ttsCustomVoices` | `onTtsCustomVoicesChanged` | `ttsCustomVoices` | `string` | — |
| 940 | 书籍 / 章节 / 缓存 / 换源 | `@StorageLink` | `launchShortcutNonce` | `onLaunchShortcutChanged` | `launchShortcutNonce` | `number` | — |
| 941 | 书籍 / 章节 / 缓存 / 换源 | `@StorageLink` | `fullTextCacheCancelNonce` | `onFullTextCacheCancelNonceChanged` | `fullTextCacheCancelNonce` | `number` | — |
| 942 | TTS 音色 / 语速设置 | `@State` | — | — | `ttsVoices` | `TtsVoiceOption[]` | — |
| 943 | TTS 音色 / 语速设置 | `@State` | — | — | `ttsCustomVoiceOptions` | `HttpTTS[]` | — |
| 944 | TTS 音色 / 语速设置 | `@State` | — | — | `ttsSelectedVoiceKey` | `string` | — |
| 945 | TTS 音色 / 语速设置 | `@State` | — | — | `ttsVoicesLoading` | `boolean` | — |
| 946 | TTS 音色 / 语速设置 | `@State` | — | — | `ttsDownloadingVoiceKey` | `string` | — |
| 947 | TTS 音色 / 语速设置 | `@State` | — | — | `showTtsVoiceDropdown` | `boolean` | — |
| 948 | TTS 音色 / 语速设置 | `@State` | — | — | `ttsVoiceRowPressedKey` | `string` | — |
| 949 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `fullTextCaching` | `boolean` | — |
| 950 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `fullTextCacheDone` | `number` | — |
| 951 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `fullTextCacheTotal` | `number` | — |
| 952 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `fullTextCacheStatus` | `string` | — |
| 953 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | `onSystemDialogFlagChanged` | `showReaderCacheDialog` | `boolean` | — |
| 954 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | `onSystemDialogFlagChanged` | `showReaderChapterCacheDialog` | `boolean` | — |
| 955 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `readerCacheChapters` | `BookChapter[]` | — |
| 956 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `readerCacheStatus` | `string` | — |
| 957 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `readerCacheRangeDraft` | `string` | — |
| 958 | 书籍 / 章节 / 缓存 / 换源 | `@State` | — | — | `readerCacheRangeCaching` | `boolean` | — |
| 991 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerTypographyValueRevision` | `number` | — |
| 992 | 字体 / 正则字体 | `@State` | — | — | `readerTypographyFontSize` | `number` | — |
| 993 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerTypographyLetterSpacing` | `number` | — |
| 994 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerTypographyLineHeight` | `number` | — |
| 995 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerTypographyParagraphSpacing` | `number` | — |
| 996 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerTypographyMarginLeft` | `number` | — |
| 997 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerTypographyMarginRight` | `number` | — |
| 998 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerTypographyMarginTop` | `number` | — |
| 999 | 阅读排版与交互设置 (通用) | `@State` | — | — | `readerTypographyMarginBottom` | `number` | — |
| 1031 | 眼动翻页 | `@State` | — | — | `arEyeTurnHostMounted` | `boolean` | — |
| 1036 | 眼动翻页 | `@State` | — | — | `readerEyeTurnStatus` | `string` | — |
| 1037 | 眼动翻页 | `@State` | — | — | `showReaderEyeCalibration` | `boolean` | — |
| 1038 | 眼动翻页 | `@State` | — | — | `readerEyeCalibrationStep` | `number` | — |
| 1039 | 眼动翻页 | `@State` | — | — | `readerEyeCalibrationCapturing` | `boolean` | — |
| 1040 | 眼动翻页 | `@State` | — | — | `readerEyeCalibrationProgress` | `number` | — |
| 1041 | 眼动翻页 | `@State` | — | — | `readerEyeCalibrationTargetY` | `number` | — |
| 1042 | 眼动翻页 | `@State` | — | — | `readerEyeCalibrationOverlayWidth` | `number` | — |
| 1043 | 眼动翻页 | `@State` | — | — | `readerEyeCalibrationOverlayHeight` | `number` | — |
| 1048 | 眼动翻页 | `@State` | — | — | `readerEyeCalibrationSessionActive` | `boolean` | — |

## 共享状态警告（改代码前必读）

1. **V1 状态不能跨文件**：`@State` 必须留在 `@Component` 内。把逻辑抽到普通类时，必须照抄 `ReaderTtsBackgroundController` 的 `Controller + Host 接口` 模式（Host 持有 struct 引用，逐方法委托），不能让新类直接持有 `@State`。
2. **@Builder 提 @Component 会切断联动**：提成独立 `@Component` 后需用 `@Link/@Prop` 或 `AppStorage/@StorageLink` 接通数据；否则状态变更不再刷新 UI。
3. **隐式共享是最大耦合源**：已抽离的方法仍通过 `page.xxx` 直接读写同一批 `@State`，没有参数边界；`page` 只是显式传参，不是新状态容器。任何进一步抽取前先靠本表 + `ops_grep` 确认该方法触达的状态集合。
4. **边界判定别数括号**：`ReadBook.ets` 中方法一律以 2 空格缩进的 `}` 收尾；数括号会被正则字面量（如 `/^https?:\/\//i` 里的 `//`）当成行注释而误判，导致方法被截断、struct 提前闭合、整片级联报错。缩进锚定才可靠。
5. **长跑 TTS 跨章保活**：`finish()` 走 `keepAudioOutputOnFinish` 分支时曾不清帧时间线/缓存引用计数；A1–A9 主要修复已落地（换章软重置帧时间线、CacheLease TTL、drain 看门狗等），详见 `docs/tts-long-running-bugs.md`「修复状态」。

## 拆分蓝图（P0 → P3，每步小提交 + 真机回归，禁止大爆炸重写）

- **P0（已完成）**：顶层常量 → `reader/ReaderConstants.ets`（25 常量 + 1 缓存函数）；**131 个叶子纯函数** → `reader/ReaderLeafFns.ets`，调用方用 `import * as LeafFns` 命名空间引用；自底向上 5 批抽取后重扫 `pure=8` 全为结构性排除，纯函数抽离已收敛到不动点。
- **P0.5（已完成）**：941 个业务方法按 //region 抽到 12 个 `reader/*Ops.ets`，struct 内只留 1 行委托；`private` 字段与 `private` 方法改为可见（运行时擦除、零行为影响），`export struct ReadBookPage` 供 ops 模块做纯类型导入。ReadBook.ets 从 24417 → 6922 行（-17495）。核验：真 ArkTS 编译通过 + 941/941 方法体逐字回环一致 + 6 轮真机前后台回归 0 错误。
- **P1（进行中）**：127 个 `@Builder` 按面板提独立 `@Component`（`readerTtsQuickActionButton`、`ttsExpandedMediaControlsBar`、`ttsQuickSettingsPanel` 等）。这会切断 ArkUI V1 的隐式联动，须用 `@Link/@Prop` 或 `@StorageLink` 重建数据通路，且只能靠真机视觉回归验证。
- **P2（未做）**：分页测量引擎 / TTS 编排 / 焦点·镜像 各自提 Controller+Host 类；本步已把它们的**代码**挪出巨型文件，剩下的工作是切状态边界。
- 目标：每单元 ≤ 1500–2000 行 / ≤ 100 KB，边界靠**显式接口**而非共享 `@State`。
- 执行节奏：**纯函数 → 常量 → UI 子组件 → 分页 → TTS 编排 → 焦点/镜像**；每步 `devecocli check arkts <file>` + 真机回归后再进下一步。

## 相关文档

- 听书长时间运行 Bug 分析（卡顿 / 浮标异常 / 翻页不顺 / 高亮卡住）：[docs/tts-long-running-bugs.md](docs/tts-long-running-bugs.md)
- 端云资产同步踩坑：见 `AGENTS.md` 内 `cloud-asset-sync debugging lessons` 段。
