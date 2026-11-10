# -*- coding: utf-8 -*-
"""
Generate the in-source `//region` folding markers for ReadBook.ets and the root CODE_MAP.md.

The file is a ~24k-line ArkUI V1 monolith. This tool gives AI tools / new
contributors a stable responsibility map without a big-bang rewrite.

Idempotent: every line this tool emits carries a distinctive prefix and is
stripped on re-run, so re-running after the file grows or shifts simply
recomputes fresh line numbers. It only ever ADDS comment lines; all original
code bytes (including any uncommitted edits) are preserved verbatim.

Usage (from repo root):
    python scripts/gen_reader_code_map.py           # dry run: print plan only
    python scripts/gen_reader_code_map.py --apply  # write ReadBook.ets + CODE_MAP.md
"""
import re
import sys

SRC = "entry/src/main/ets/pages/ReadBook.ets"
MAP = "CODE_MAP.md"
APPLY = "--apply" in sys.argv

# ---------------------------------------------------------------- source ----
with open(SRC, "r", encoding="utf-8", newline="") as f:
    raw = f.read()
nl = "\r\n" if "\r\n" in raw else "\n"
lines = raw.split(nl)
trailing_nl = bool(lines) and lines[-1] == ""
if trailing_nl:
    lines = lines[:-1]

EMIT_PREFIX = "// [map]"
# Folding markers use `//region` / `//endregion` (no '#', no space): recognized by
# BOTH VS Code (^\s*//\s*#?region\b) and IntelliJ/DevEco Studio custom folding.
# The loose strip regex above also matches the older `// #region` form so that
# re-running after this change stays idempotent on files written by earlier versions.
STRIP_RE = re.compile(r"^(//\s*#?(end)?region\b|//\s*\[map\])")
lines = [ln for ln in lines if not STRIP_RE.match(ln.strip())]
N = len(lines)

# ------------------------------------------------------------- boundaries ---
# (CONTENT anchor, region name, boundary contract). Anchors are resolved against the
# stripped source, NOT hard-coded line numbers: re-running after P0..P3 extractions
# stays correct even when the file grows or shrinks. Anchor = None (start of file),
# "@Entry" (the component decorator), or a struct method name whose first definition
# marks the region start (must be defined exactly once in ReadBook.ets).
REGIONS = [
    (None, "头部: 导入 / 顶层常量 / 纯函数 / 后台TTS Host适配器",
     "无 @State 依赖; 顶层常量已抽到 reader/ReaderConstants.ets; ReadBookTtsBackgroundHost 仅逐方法委托 page"),
    ("@Entry", "struct 声明与状态字段 (@State / @StorageLink / 私有字段)",
     "仅声明状态, 不含逻辑; ArkUI V1 下 @State 必须留在本 @Component 内, 逻辑外移须走 Controller+Host"),
    ("aboutToAppear", "生命周期 / 全局监听 / @Watch 回调",
     "读写 会话/进度/可见性/焦点 状态; 装配后台控制器、注册(并应注销)全局监听与 @Watch"),
    ("openPendingShortcut", "书籍加载 / 全文缓存 / 后台长时任务 / 屏幕超时 / 加载遮罩",
     "读写 book/chapters/content/缓存/遮罩 状态; 持有后台长时任务与多个成对 timer"),
    ("build", "build / 主内容层 / 悬浮菜单 / 目录·书签·换源·缓存面板",
     "读 主题/排版/章节; 纯渲染 + 面板显隐; 交互只转发到方法, 不写业务状态"),
    ("openLayoutElementSettings", "排版·字符集·替换规则设置 / TTS快捷入口·mini播放器·目录 / 书签 / 正文预处理",
     "读写 设置/目录/书签/TTS浮标显示态; 含 ttsMiniPlayer 等大量 @Builder"),
    ("cleanChapterTitle", "页眉页脚 / 漫画·连续滚动 / 页面度量 / 主题·字体 / 书签 / TTS音色·语速 / 目录搜索",
     "读 排版/主题/字体/章节; 写 字体注册、书签、音色语速、目录滚动条"),
    ("getReaderPaginationBottomInfoBarHeight", "尺寸计算 / 排版变更监听 / 媒体控制条·睡眠定时器 / 触摸·翻页手势",
     "读写 面板尺寸/排版代际/媒体控制/触摸 状态; 定时器成对清理"),
    ("getTapZoneIndex", "点击区域 / 设置面板 / 音色下拉 / 主题自定义 / 交互·眼动·预载设置",
     "写 各类设置项持久化; 修改后触发重排 / 重载 / 重新分页"),
    ("publishTtsFloatingSession", "TTS 浮标会话 / 朗读编排(起播·续播·换章·看门狗) / 后台委托 / 封面 / 高亮清理",
     "核心长链路: ttsReadToken / ttsFocusGeneration / ttsChapterSwitching; 与浮标会话、AVSession 双向同步"),
    ("clearTtsHighlight", "焦点会话 / 正文规范化纯函数群 / 分页测量引擎",
     "含大量可纯化的正文处理(findMeasuredPageEnd 等); 分页测量读排版状态"),
    ("followTtsChunk", "逐句焦点·高亮·进度持久化 / 镜像会话 / TTS翻页 / 动画表面",
     "每句触发 followTtsChunk→高亮重绘→persistTtsReadPosition→浮标 revision++; 镜像会话接管线"),
    ("styledReaderText", "样式化正文 / 段评·源动作·文本选择 / 正则高亮 / V2布局·分页·选区·高亮",
     "读 高亮偏移/正则规则/主题; V2 分页与选区是独立大子系统, 建议优先外移"),
    ("paginateReaderSourceText", "分页缓存 / 翻页·预载·自动翻页 / 翻页动画·卷曲 / 换章",
     "写 currentPageIndex / 翻页动画状态 / 预载; 与 TTS 翻页、镜像手动翻页交织"),
]

def def_lines_in_base(name):
    """Return all 0-based indices in the stripped source where `name` is defined."""
    pat = re.compile(r"^  (?:async )?" + re.escape(name) + r"\s*\(")
    return [j for j, ln in enumerate(lines) if pat.match(ln)]


def walk_back_to_block_start(m):
    """From a method def line, walk back over decorators / comments / blank lines."""
    start = m
    while start > 0:
        p = lines[start - 1].strip()
        if (p == "" or p.startswith("@") or p.startswith("//") or
                p.startswith("/*") or p.startswith("*") or p.startswith("*/")):
            start -= 1
        else:
            break
    return start


def resolve_anchor(anchor):
    """Resolve a region boundary to a safe 0-based insertion index.

    Content-based anchors (not line numbers) keep the map correct across shifts.
    If an anchor method is later extracted out of this file, this fails loudly so
    REGIONS can be updated instead of silently inserting markers in the wrong place.
    """
    if anchor is None:
        return 0
    if anchor == "@Entry":
        hits = [j for j, ln in enumerate(lines) if ln.strip().startswith("@Entry")]
        assert len(hits) == 1, "@Entry anchor: expected 1, got %s" % hits
        return hits[0]
    hits = def_lines_in_base(anchor)
    assert len(hits) == 1, ("region anchor %r must be defined exactly once in ReadBook.ets "
                           "(got %s); update REGIONS if the method was extracted" % (anchor, hits))
    return walk_back_to_block_start(hits[0])


boundary_idx = [resolve_anchor(anchor) for anchor, _name, _contract in REGIONS]
for a, b in zip(boundary_idx, boundary_idx[1:]):
    assert b > a, "non-monotonic boundary: %d >= %d" % (a, b)

# --------------------------------------------------------------- build out --
inserts = {}


def add(idx, block):
    inserts.setdefault(idx, []).extend(block)


for k, (_t, name, contract) in enumerate(REGIONS):
    idx = boundary_idx[k]
    block = []
    if k > 0:
        block.append("//endregion")
    block.append("//region " + name)
    block.append(EMIT_PREFIX + " 契约: " + contract)
    if k == 0:
        block.append(EMIT_PREFIX + " 文件地图与拆分蓝图: 见仓库根 CODE_MAP.md (改本文件前先读)")
        block.append(EMIT_PREFIX + " 听书长时运行问题清单: docs/tts-long-running-bugs.md")
    add(idx, block)
add(N, ["//endregion"])  # close last region at EOF

out = []
for i in range(N + 1):
    for c in inserts.get(i, []):
        out.append(c)
    if i < N:
        out.append(lines[i])

# ---------------------------------------------------- recompute line numbers -
def def_lines(name):
    pat = re.compile(r"^  (?:async )?" + re.escape(name) + r"\s*\(")
    return [j for j, ln in enumerate(out, 1) if pat.match(ln)]


region_start = [j for j, ln in enumerate(out, 1) if ln.startswith("//region ")]

ANCHORS = [
    "aboutToAppear", "onPageShow", "onBackPress", "aboutToDisappear", "onPageHide", "build",
    "loadBook", "loadContent", "saveReadingProgress", "enterReaderImmersive",
    "ttsMiniPlayer", "globalTtsMiniPlayer", "ttsExpandedMediaControlsBar",
    "ttsQuickSettingsPanel", "ttsVoiceDropdownPanel", "settingsPanel",
    "publishTtsFloatingSession", "publishTtsFloatingVoices", "updateTtsFloatingSession",
    "stopTtsFloatingSession", "toggleTtsReading", "startTtsReadingFromCurrentPosition",
    "stopTtsReading", "continueTtsReading", "isTtsReadingAtExpectedEnd",
    "armTtsContinuationWatchdog", "clearTtsContinuationWatchdog",
    "advanceTtsReadingToNextChapter", "finishTtsReading", "prepareTtsForManualPageTurn",
    "scheduleTtsResumeAfterManualPageTurn", "playPositionFromFloatingSession",
    "startTtsBackgroundRunning", "stopTtsBackgroundRunning", "updateTtsAvSessionPlaybackState",
    "clearTtsHighlight", "publishTtsHighlightRenderChange", "currentTtsSourceIdentity",
    "invalidateTtsFocusSession", "isCurrentTtsFocusSession", "getTtsReadingText",
    "getTtsFocusBreakOffsets", "normalizeReaderText", "getPagedSourceText", "buildPagedSourceText",
    "findMeasuredPageEnd", "refineMeasuredPageEnd", "followTtsChunk", "noteTtsFocusLatency",
    "applyTtsChunkFocus", "syncTtsFocusAfterResume", "updateTtsChunkHighlight",
    "republishTtsFocusAfterPageTurn", "scheduleTtsFocusSyncAfterPagination",
    "persistTtsReadPosition", "restorePersistedTtsFocus", "syncMirroredTtsFocus",
    "clearMirroredTtsFocus", "takeOverMirroredTtsSession", "animateTtsToPage",
    "applyTtsPageTarget", "applyTtsPageTurn", "styledReaderText", "splitSlicesByTtsHighlight",
    "hasActiveTtsHighlight", "shouldUseReaderLayoutV2", "buildReaderV2Snapshot",
    "refreshReaderV2TtsOverlay", "paginateReaderSourceText", "turnNext", "turnPrev",
    "applyPageTurn", "runPageTurnAnimation", "prepareMirroredTtsManualPageTurn",
    "cancelMirroredTtsManualPageTurn", "drawReaderPageCurl", "loadNextChapter", "loadPrevChapter",
]

# ----------------------------------------------------------------- dry run --
added = len(out) - N
if not APPLY:
    print("DRY RUN (no files written)")
    print("source lines before      :", N)
    print("comment lines to add     :", added)
    print("source lines after       :", len(out))
    print("newline style            :", repr(nl))
    print("region count             :", len(REGIONS))
    print("\n-- boundaries (insert-before line / original text / region) --")
    for k, (anchor, name, _c) in enumerate(REGIONS):
        idx = boundary_idx[k]
        orig = lines[idx][:70] if idx < N else "<EOF>"
        print("  %-34s | L%-6d | %-70s | %s" % (str(anchor), idx + 1, orig, name[:30]))
    print("\n-- region start lines (post-insert) --", region_start)
    print("-- sample anchors (post-insert) --")
    for a in ["aboutToAppear", "build", "startTtsReadingFromCurrentPosition",
              "followTtsChunk", "paginateReaderSourceText", "loadNextChapter"]:
        print("  %-38s %s" % (a, def_lines(a)))
    sys.exit(0)

# ------------------------------------------------------------------- write --
new_raw = nl.join(out) + (nl if trailing_nl else "")
with open(SRC, "w", encoding="utf-8", newline="") as f:
    f.write(new_raw)

# Build CODE_MAP.md -----------------------------------------------------------
L = []
w = L.append
w("# CODE_MAP.md — 阅读页巨型文件导航")
w("")
w("> 由 `scripts/gen_reader_code_map.py` 生成，**请勿手工改行号**。文件变动后在仓库根执行 "
  "`python scripts/gen_reader_code_map.py --apply` 重算（幂等，只增删注释行，保留所有代码原字节）。")
w("> 面向 AI / 新人：先读本表定位职责域，再跳到 `entry/src/main/ets/pages/ReadBook.ets` 对应行号，"
  "避免把 2.4 万行整篇塞进上下文。")
w("")
w("## 现状（为什么需要这张表）")
w("")
w("- `entry/src/main/ets/pages/ReadBook.ets`：**%d 行 / 约 1.0 MB**；单文件内仅 "
  "1 个 `@Entry @Component struct ReadBookPage` + 1 个 `ReadBookTtsBackgroundHost` 适配器类。" % len(out))
w("- 响应式字段（`@State` / `@StorageLink` / `@StorageProp`）见下方「响应式状态域地图」，由脚本实时扫描生成；"
  "`@Builder` 约 127 个、成员方法约 1168 个（P0 抽走 131 个叶子纯函数后）；"
  "整个 `ets/` 目录 **0 个** `@Observed/@Track/@Provide/@Consume/@ObjectLink`（ArkUI V1 全内联状态）。")
w("- 文件内唯一分区手段是本工具写入的 `//region` / `//endregion`（VS Code 与 IntelliJ/DevEco Studio "
  "都能折叠）；每个区块头还带一行 `// [map] 契约:` 说明本区允许读写哪些状态。")
w("- 已存在的可复用范式：`reader/ReaderPureUtils.ets`（纯函数）、"
  "`reader/ReaderTtsBackgroundController.ets` + Host 接口、`components/TtsGlobalCapsule.ets`、"
  "`components/ReaderTtsPlayerPanel.ets`、`components/TtsCatalogSheet.ets`（已抽出的 @Component）。")
w("")
w("## 职责分区（行号 = 插入 `//region` 标记后的当前值）")
w("")
w("| # | 区域 | 起始行 | 结束行 | 边界契约（允许读写哪些状态 / 注意事项） |")
w("|---|------|-------:|-------:|------------------------------------------|")
for k, (_t, name, contract) in enumerate(REGIONS):
    start = region_start[k]
    end = (region_start[k + 1] - 1) if k + 1 < len(region_start) else len(out)
    w("| %d | %s | %d | %d | %s |" % (k + 1, name, start, end, contract))
w("")
w("## 关键入口方法索引")
w("")
w("行号为 `struct ReadBookPage` 内定义位置；`ReadBookTtsBackgroundHost` 在文件前部有同名委托方法，"
  "用 `/` 一并列出。多个定义用 `/` 分隔。")
w("")
w("| 方法 | 行 |")
w("|------|----|")
found = 0
# Methods extracted to reader/ReaderLeafFns.ets are still worth indexing, but
# point the reader at their new home instead of silently dropping the row.
MOVED_MODULE = "entry/src/main/ets/reader/ReaderLeafFns.ets"
try:
    _moved_src = open(MOVED_MODULE, encoding="utf-8").read()
    MOVED_EXPORTS = set(re.findall(r"^export function ([\w$]+)\s*\(", _moved_src, re.M))
except OSError:
    _moved_src = ""
    MOVED_EXPORTS = set()
for a in ANCHORS:
    dl = def_lines(a)
    if dl:
        found += 1
        w("| `%s` | %s |" % (a, " / ".join(str(x) for x in dl)))
    elif a in MOVED_EXPORTS:
        found += 1
        w("| `%s` | → `reader/ReaderLeafFns.ets`（已抽离为纯函数） |" % a)
w("")
w("（共索引 %d 个关键方法；未列出的多为 `@Builder` 或仅在表达式中出现。）" % found)
w("")
w("## 已抽离的叶子纯函数（`reader/ReaderLeafFns.ets`）")
w("")
w("> 以下 %d 个 `export function` 由脚本实时读取该模块生成，不读/不写任何 `@State`；"
  "改阅读页逻辑前先在此确认是否已有可用纯函数，避免重复实现。" % len(MOVED_EXPORTS))
w("")
w("| # | 函数 | 所在行 |")
w("|---|------|-------:|")
moved_defs = []
for _i, _ln in enumerate(_moved_src.split("\n")):
    _m = re.match(r"^export function ([\w$]+)\s*\(", _ln)
    if _m:
        moved_defs.append((_i + 1, _m.group(1)))
for _n, (_ln, _name) in enumerate(moved_defs, 1):
    w("| %d | `%s` | %d |" % (_n, _name, _ln))
w("")

# ---- Responsive-state domain map (scanned live from `out`, never stale) -----
# Ordered (keyword, ...) rules; FIRST match wins. Keys are lower-cased field
# names. Keeping the table here (near the source-of-truth scan) makes it cheap to
# re-classify a newly added @State with a new prefix. This is a navigation aid,
# not a spec: a few settings may land in a neighbouring domain.
DOMAIN_RULES = [
    ("TTS 朗读会话 / 浮标 / 逐句高亮", [
        "globaltts", "isttsspeaking", "isttspaused", "ttspagedscrolloverride",
        "ttsmediacontrolsexpanded", "ttsdisplaytext", "ttshighlight", "ttssleeptimer",
        "mirroredttsfocus", "showglobalttscatalog", "readerv2ttspaintversion",
        "readerv2selectionpaintversion"]),
    ("TTS 音色 / 语速设置", [
        "ttsperson", "ttsonline", "ttsstyle", "ttslanguage", "ttsspeed",
        "ttsinstalledvoice", "ttscustomvoice", "ttsvoices", "ttsselectedvoice",
        "ttsdownloadingvoice", "showttsvoicedropdown", "ttsvoicerowpressedkey"]),
    ("目录 TOC", ["toc"]),
    ("段评 / 评论面板", ["readercommentpanel"]),
    ("自动翻页 / 屏幕 / 快捷设置", [
        "autopageturn", "readerscreen", "readerextendtostatusbar", "readeruse",
        "readerquickbookmark", "readertapzone", "readervolumeturn", "readerlandscape"]),
    ("翻页动画 / 手势", [
        "pagetransition", "pageslide", "pageturnin", "pageturnanimating",
        "bookmarkpull", "readerpagecurlsnapshotready"]),
    ("书签", ["bookmark"]),
    ("分页 / V2 布局 / 选区", [
        "contentpages", "currentpageindex", "currentpagetext", "displaypage",
        "pagerenderversion", "chapterjumprendergeneration", "readerv2",
        "pageview", "readerinitialpage", "readerbottominfobar",
        "statusbarsafeheight", "storedstatusbarheight", "navbarheight",
        "readerwebfetchruntimeneeded", "readertextselectionactive"]),
    ("漫画模式", ["readercomic"]),
    ("眼动翻页", ["readereye", "areyeturn"]),
    ("字体 / 正则字体", ["font"]),
    ("主题 / 夜间模式", [
        "theme", "appdarkmode", "appthememode", "applightaccentcolor",
        "appdarkaccentcolor", "applightbuttoncolor", "appdarkbuttoncolor"]),
    ("封面 / 书架", ["bookshelf", "covergallery"]),
    ("书籍 / 章节 / 缓存 / 换源", [
        "book", "chapters", "content", "currentchapterindex", "verification",
        "fulltextcach", "readercache", "showreadercachedialog",
        "showreaderchaptercachedialog", "launchshortcutnonce",
        "showchangesourcedialog", "loadstatus", "isloading",
        "readerloadingslow", "readerreplacerules"]),
    ("菜单 / 显隐 / 设置弹窗", [
        "show", "menu", "settingspaneltab", "txtcharset", "showreaderactionmenu",
        "showlayoutelementsettings", "readerdaynight", "readermenuchorside",
        "hdsmaterialrenderbranch"]),
    ("阅读排版与交互设置 (通用)", ["reader", "keepparagraphindent"]),
]


def classify_state(name):
    low = name.lower()
    for domain, keys in DOMAIN_RULES:
        for k in keys:
            if k in low:
                return domain
    return "其他 / 通用"


STATE_ROWS = []
for _ln, _text in enumerate(out, 1):
    if not re.match(r"^  @(State|StorageLink|StorageProp)\b", _text):
        continue
    _deco = ("@StorageLink" if "@StorageLink" in _text else
             "@StorageProp" if "@StorageProp" in _text else "@State")
    _km = re.search(r"@Storage(?:Link|Prop)\(\s*'([^']+)'\s*\)", _text)
    _key = _km.group(1) if _km else ""
    _watches = re.findall(r"@Watch\(\s*'([^']+)'\s*\)", _text)
    # One declaration wraps the field onto the next line; join the
    # continuation line so the name/type/@Watch stay parseable.
    _full = _text
    if not re.search(r"([\w$]+)\s*:", _full):
        _j = _ln  # 1-based line number in `out`
        if _j < len(out):
            _full += " " + out[_j].strip()
    _nm = re.search(r"([\w$]+)\s*:", _full)
    _name = _nm.group(1) if _nm else "?"
    _after = _full[_nm.end():] if _nm else ""
    _typ = _after.split("=")[0].split(";")[0].strip() or "?"
    _priv = bool(re.search(r"\bprivate\s+" + re.escape(_name) + r"\s*:", _text))
    STATE_ROWS.append((_ln, _deco, _key, _watches, _name, _typ, _priv,
                       classify_state(_name)))

_n_state = sum(1 for r in STATE_ROWS if r[1] == "@State")
_n_link = sum(1 for r in STATE_ROWS if r[1] == "@StorageLink")
_n_prop = sum(1 for r in STATE_ROWS if r[1] == "@StorageProp")
_DCOUNT = {}
for r in STATE_ROWS:
    _DCOUNT[r[7]] = _DCOUNT.get(r[7], 0) + 1

w("## 响应式状态域地图（@State / @StorageLink / @StorageProp）")
w("")
w("> 由脚本实时扫描 `ReadBook.ets`（行号已含 `//region` 标记）生成；共 %d 个响应式字段"
  "（`@State` %d / `@StorageLink` %d / `@StorageProp` %d）。"
  "「域」由生成器内的 `DOMAIN_RULES` 关键字规则首匹配启发式判定，可按需调整；"
  "抽取任何逻辑前先按域定位其读写邻居，并用 `ops_grep` 复核触达的 @State 集合。"
  % (len(STATE_ROWS), _n_state, _n_link, _n_prop))
w("")
w("| 域 | 字段数 |")
w("|----|-------:|")
for _d in sorted(_DCOUNT, key=lambda x: (-_DCOUNT[x], x)):
    w("| %s | %d |" % (_d, _DCOUNT[_d]))
w("")
w("| 行 | 域 | 装饰器 | 存储键 | @Watch | 字段 | 类型 | private |")
w("|---:|----|--------|--------|---------|------|------|---------|")
for (_ln, _deco, _key, _watches, _name, _typ, _priv, _domain) in STATE_ROWS:
    w("| %d | %s | `%s` | %s | %s | `%s` | %s | %s |" % (
        _ln, _domain, _deco,
        ("`%s`" % _key) if _key else "—",
        ", ".join("`%s`" % x for x in _watches) if _watches else "—",
        _name,
        "`%s`" % _typ.replace("|", "\\|"),
        "是" if _priv else "—"))
w("")
w("## 共享状态警告（改代码前必读）")
w("")
w("1. **V1 状态不能跨文件**：`@State` 必须留在 `@Component` 内。把逻辑抽到普通类时，"
  "必须照抄 `ReaderTtsBackgroundController` 的 `Controller + Host 接口` 模式（Host 持有 struct 引用，逐方法委托），"
  "不能让新类直接持有 `@State`。")
w("2. **@Builder 提 @Component 会切断联动**：提成独立 `@Component` 后需用 `@Link/@Prop` 或 "
  "`AppStorage/@StorageLink` 接通数据；否则状态变更不再刷新 UI。")
w("3. **隐式共享是最大耦合源**：1279 个方法几乎都通过 `this.xxx` 直接读写同一批 `@State`，"
  "没有参数边界。任何抽取前先靠本表 + `ops_grep` 确认该方法触达的状态集合。")
w("4. **长跑 TTS 跨章保活**：`finish()` 走 `keepAudioOutputOnFinish` 分支时曾不清帧时间线/缓存引用计数；"
  "A1–A9 主要修复已落地（换章软重置帧时间线、CacheLease TTL、drain 看门狗等），"
  "详见 `docs/tts-long-running-bugs.md`「修复状态」。")
w("")
w("## 拆分蓝图（P0 → P3，每步小提交 + 真机回归，禁止大爆炸重写）")
w("")
w("- **P0（零风险）**：顶层常量 → `reader/ReaderConstants.ets`（25 常量 + 1 缓存函数）；"
  "**131 个叶子纯函数**（含静态工厂 `defaultTtsVoice` 与正文规范化群）→ `reader/ReaderLeafFns.ets`，"
  "调用方用 `import * as LeafFns` 命名空间引用；自底向上 5 批抽取后重扫 `pure=8` 全为结构性排除，"
  "纯函数抽离已收敛到不动点。ReadBook.ets 从 24417 → %d 行（-%d）。真 ArkTS 编译通过。" % (len(out), 24417 - len(out)))
w("- **P1**：127 个 `@Builder` 按面板提独立 `@Component`（`ttsMiniPlayer`、`ttsExpandedMediaControlsBar`、"
  "`ttsQuickSettingsPanel` 等）；分页测量引擎（`clearTtsHighlight` → `followTtsChunk` 区间）→ `ReaderPaginator` 类。")
w("- **P2**：TTS 朗读编排（`publishTtsFloatingSession` → `clearTtsHighlight` 区间）→ `TtsReadingCoordinator + Host`；"
  "逐句焦点/高亮/翻页（`followTtsChunk` → `styledReaderText` 区间）→ `TtsFocusController`。")
w("- **P3**：镜像会话 / V2 布局子系统 / 翻页动画各自独立。")
w("- 目标：每单元 ≤ 1500–2000 行 / ≤ 100 KB，边界靠**显式接口**而非共享 `@State`。")
w("- 执行节奏：**纯函数 → 常量 → UI 子组件 → 分页 → TTS 编排 → 焦点/镜像**；"
  "每步 `devecocli check arkts <file>` + 真机回归后再进下一步。")
w("")
w("## 相关文档")
w("")
w("- 听书长时间运行 Bug 分析（卡顿 / 浮标异常 / 翻页不顺 / 高亮卡住）："
  "[docs/tts-long-running-bugs.md](docs/tts-long-running-bugs.md)")
w("- 端云资产同步踩坑：见 `AGENTS.md` 内 `cloud-asset-sync debugging lessons` 段。")
w("")

with open(MAP, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(L))

print("APPLIED")
print("  %s: %d -> %d lines (+%d comment lines)" % (SRC, N, len(out), added))
print("  %s: written (%d region rows, %d anchor rows)" % (MAP, len(REGIONS), found))
