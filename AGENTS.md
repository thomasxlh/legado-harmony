<!-- code-review-graph MCP tools -->
## MCP Tools: code-review-graph

**This project has a knowledge graph. Start with the code-review-graph
MCP tools to narrow scope, then read the source.** The graph is cheaper than scanning files and
gives you structural context (callers, dependents, test coverage) that file search cannot.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes_tool` or `query_graph_tool` instead of Grep
- **Understanding impact**: `get_impact_radius_tool` instead of manually tracing imports
- **Code review**: `detect_changes_tool` + `get_review_context_tool` instead of reading entire files
- **Finding relationships**: `query_graph_tool` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview_tool` + `list_communities_tool`

### Verify in the source

- Narrow scope with the graph, then read the source. Do not change code from graph output alone.
- For any non-trivial change, read the implementation and the relevant tests before concluding.
- Verify the exact source when touching behavior, database logic, migrations, retries, fallbacks,
  recovery, or compatibility code.
- When the graph and the source disagree, the source wins. The graph may be stale or may not
  model that relationship.
- An empty graph result can mean "not indexed" or "not statically visible", not "does not exist".

### Key Tools

| Tool | Use when |
| ------ | ---------- |
| `detect_changes_tool` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context_tool` | Need source snippets for review — token-efficient |
| `get_impact_radius_tool` | Understanding blast radius of a change |
| `get_affected_flows_tool` | Finding which execution paths are impacted |
| `query_graph_tool` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes_tool` | Finding functions/classes by name or keyword |
| `get_architecture_overview_tool` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes_tool` for code review.
3. Use `get_affected_flows_tool` to understand impact.
4. Use `query_graph_tool` pattern="tests_for" to check coverage.
<!-- /code-review-graph MCP tools -->

<!-- cloud-asset-sync debugging lessons (2026-10-26, theme_assets 1017/jsonParse 修复) -->
## 端云 ASSET 资产同步：踩坑实录与定稿结论

背景：市场版 4.1.0 主题图片云同步双向全坏（上传 1017、下载 uri 翻倍/jsonParse fail），排查历时多天、多轮真机抓日志才定位。以下结论已全部真机验证（debug→测试环境完整回环通过），后续改 theme_assets 相关代码前必读。

### 1. Asset 字段格式（定稿，勿改）

- **uri** = 规范形式 `file://<bundleName>/data/storage/el2/distributedfiles/<相对路径>`（`ThemeAssetSyncService.canonicalUri`）
- **path** = `distributedFilesDir` 下相对路径，如 `theme_assets/<assetKey>`
- 裸绝对路径（`/data/storage/...`）只在应用自身 mount namespace 可见，CloudKitSA 等系统服务跨进程解析不了 → 上传必 1017 `"path is not exist"`（`RecordAssetToUploadAsset ... canonical and check path failed`）→ 云端只留 mode=temp 孤儿记录，fetch 永不返回。
- 云端附件元数据损坏（jsonParse fail）的旧行无法救回二进制，只能识别为 relocated 重刷重传覆盖。

### 2. 引擎行为（实测）

- 上传两阶段：createTempRecords（mode=temp batchCreate，先建临时记录）→ 资产二进制上传 → 定稿。fetch **不含 temp 记录**——「上传成功但 fetch 查不到」先查是不是卡在 temp 阶段。
- 下载组 uri = 规范前缀 + 云端存的 path；行内 uri 翻倍 = 云端存了带前缀的值（格式错的典型症状）。
- 云同步恢复顺序：books → bookSources（分页、最慢，~3-5 分钟）→ bookGroups/searchKeywords/bookmarks/appPreferences/themeAssets。**themeAssets 的上传/下载都在启动后几分钟才发生**，短窗口抓包抓不到。
- 引擎失败会把行标 abnormal=y；行删除原生传播，无需墓碑行。
- `SyncInhibitedD: queryDataByFileId` 的 jsonParse fail 是 clouddrive 内部噪声，与 app 资产无关，别被带偏。

### 3. 环境事实

- **debug 包连测试环境（AGC 开发环境），可直接 hdc 安装做完整回环验证**（上传+恢复下载+界面显示全流程都测过）；release 连生产环境。早期「debug 挂载缺失无法上传资产」的结论是错的——当时就是格式 bug。
- 市场 app 的 hilog 可直接看（domain 0x0000）；release 沙箱 hdc 不可读；自签 release 包无法覆盖安装市场包（9568322 签名不一致），只能走 AGC 邀请测试。
- versionCode 必须大于市场版本（当前市场 4001099，工作区 4001100）。
- 7 张云表（books/bookSources/bookGroups/searchKeywords/bookmarks/appPreferences/themeAssets）开发、生产环境要各配一遍；theme_assets.file 为 ASSET 类型，需云空间 6.3.1+。

### 4. 抓日志方法（这次能破案的关键）

- **无间隙连续抓取**：先 `Start-Process $hdc -ArgumentList "shell","hilog" -RedirectStandardOutput <file> -WindowStyle Hidden` 后台常驻，再执行 `bm clean -d` → `aa start`。分段抓取曾两次错过 3 分钟后才发生的上传尝试。
- `hilog -r` 清缓冲后，日志里会回放 pre-wipe 旧进程内容——**按时间戳过滤，别只按 PID 过滤**。
- 关键 tag：clouddrive `A00147/[Cloud-7.0.0.303]Sync`（batchCreateAsset/batchUpdateResult/batchDownloadAssets）、CloudKitSA `C04315`（canonical check）、app 自身 domain `A00000`。
- PowerShell 陷阱：`Start-Process` 不能同时给 `-NoNewWindow` 和 `-WindowStyle`；`Select-String` 直接吃文件路径比管道快。
- 静态检查命令是 `devecocli check arkts <file>`（不是 `arkts_check`）；发布链：`devecocli build --product release --build-mode release` → hvigorw `assembleApp -p product=release -p buildMode=release`，之后解包 `.app` 核对 pack.info 版本号、grep `modules.abc` 确认新代码已打入。

### 5. 排查教训

- 「上传成功」要证据链闭环：batchUpdateResult success 只是引擎写行成功，还要 fetch 返回 + 资产可下载 + 文件落地 + 界面显示，缺一环都算没验证。
- 假设要及时用实验推翻：mount 分析（debugtmp 无挂载）曾把 1017 错误归因于安装形态，延误了「格式本身错了」这个真因；规范格式在 debug 上一次通过直接证伪了旧结论。
- 官方文档（rdb_cloud_dev/crossdevice/commontype）没有 Asset 格式的具体示例，只有语义约束（uri=绝对系统路径、path=沙箱相对路径、资产须在分布式文件路径下）——真机日志才是唯一的格式裁判。
<!-- /cloud-asset-sync debugging lessons -->
