# 听书（连续朗读）长时间运行 Bug 分析

> 针对问题：「长时间打开听书不关闭」才暴露的 bug —— 卡顿、听书浮标显示异常、
> 听书时翻页不顺畅、逐句高亮卡住等。
> 分析方法：逐条核对 `文件:行号` 原文并回溯 `ReadBook.ets` 调用侧；
> 下方「修复状态」记录本轮在源码中实际落地的精准修复（工作区既有改动完整保留）。
> 行号基准：当前工作区 `C:\Users\riska\ideaProjects\legado-Harmony`。
> **只有「连续朗读 + 跨章保活 + 从不 stop」才暴露**的放在最前；成对清理做得扎实的部分单列「未发现」。

## 结论先行

| 现象（用户可感知） | 最可能的根因 | 严重度 |
|---|---|---|
| 越听越卡、每句起播变慢、磁盘/内存渐涨 | A1 缓存引用计数只增不减 | 高 |
| 高亮越来越提前/滞后、浮标进度错位、翻页不顺 | A2 帧时间线跨章不复位 | 高 |
| 偶尔彻底静音、进度/高亮/浮标全冻结、只能关掉重开 | A3 PCM drain 无绝对超时 | 高 |
| 快速暂停/继续、来电/锁屏后跳句或「无声但显示朗读中」 | A4 suppressEngineStopEvent 布尔竞态 | 高 |
| 浮标一直显示「已中断/已暂停」但声音正常 | A5 焦点标志复位不对称 | 中 |
| 听书时手动翻页后迟迟不续读、高亮卡住 | A6 手动翻页续读无界重试 | 中 |
| 浮标位置诡异、状态文本错乱、跨书残留 | A7 浮标会话状态残留 / 双页镜像 | 中 |
| 换章停顿、逐句掉帧 | A8 每章主线程全量重算 / 每句 PCM 全量拷贝 | 中 |
| 后台挂久后媒体控制失效 | A9 后台心跳自停后未重启 | 中 |

---

## 修复状态（本轮已落地，逐条可回退）

> 每处改动均为小步、可单独 `revert`；未覆盖任何一行既有用户改动。
> 本会话 `devecocli` 不在 PATH，未跑 `devecocli check arkts`，静态检查与真机回归需按文末清单补做。

| 编号 | 状态 | 改动文件与核心机制 |
|---|---|---|
| A3 | ✅ 已修 | `TtsPcmAudioPlayer.ets`：`drain()` 包一层绝对超时看门狗 —— 预算 = 剩余 PCM 帧时长 + 10s 宽限（被 `systemInterrupted` 脏标志卡住时放宽到 5 分钟）；无进展则先停看门狗再 `stop()` 强制解挂并重建 renderer，不伪造音频消费 |
| A1 | ✅ 已修 | `HttpTtsReader.ets`：`protectedCachePaths` 由「只增计数器」改为自带 TTL 的 `CacheLease`（10 分钟过期、64 项硬上限、1 秒节流清扫）；作废预取不再永久保护文件，`pruneCache` 可正常回收 |
| A2 | ✅ 已修 | `SystemTtsReader.ets` + `TtsPcmAudioPlayer.ets`：换章保活复用同一 renderer 时调 `resetPlaybackTimelineForChapterHandoff()` 软清零绝对帧时间线（`rendererFrameOrigin=-1` 让下章重新锚定），不拆 renderer、不动 audio-session owner |
| A4 | ✅ 已修 | `SystemTtsReader.ets`：`suppressEngineStopEvent` 布尔 → 按 `readGeneration` 归属、带 timer id 的抑制窗口（只有持有当前抑制的 timer 能清）；`start()`/`stop()` 前置取消，杜绝跨章残留与快速暂停/继续误抑制 |
| A5 | ✅ 已修（主症状） | `TtsAvAudioPlayer.ets` / `RemoteAudioPlayback.ets`：STOP/RESUME 视为 player 级焦点事件、不被 generation 守卫丢弃；STOP 补 `notifyInterruptedChange()` 并真正 pause + `setState('paused')`；去掉会漏 UNDUCK 的 `setVolume(0.35/1)` 改应用音量 |
| A9 | ✅ 已修 | `ReaderTtsBackgroundController.ets`：`updateTtsAvSessionPlaybackState(PLAY)` 幂等重启 30s 心跳（`startTtsBackgroundHeartbeat()` 自带去重），暂停/继续不再让锁屏媒体控制失同步 |
| A6 | ✅ 已修 | `ReadBook.ets`：手动翻页续读的 48ms 重试链加 `attempt < 100`（≈4.8s）上限，超时不再无限递归、落回原有正常续读路径 |
| A7 | ✅ 已修 | `ReaderTtsFloatingSession.ets`：`clear()` 一并重置 `globalTtsCapsulePositionX/Y` 到默认 (16, -1)，避免跨会话浮标位置残留 |
| A8 | 🟡 部分 | `HttpTtsReader.ets`：`pruneCache` 全目录 `listFileSync` 加 60s 节流；其余（整章 normalize/split/snap 与 PCM 变速挪 taskpool、`setListener` 收敛、AVMetadata 按需更新）按报告 E 第 6 条随 P0 拆分一并做 |
| A5′ | ⏸ 暂缓 | `TtsAvAudioPlayer` 的 `activeAudioSessionOwner` 在 `resume()`/`clearSystemInterrupt()` 与 `play()` finally 之间的跨方法生命周期：低置信、改动面大，叠加到本轮未经真机验证的音频路径风险偏高，留专项真机验证后处理 |

---

## A. 高严重度（长跑主因）

### A1 HTTP TTS 缓存引用计数只增不减 → Map 与磁盘单调增长
**证据**
- `entry/src/main/ets/utils/HttpTtsReader.ets:86` — 每次 `synthesize` 成功带 `filePath` 即 `this.retainCacheFile(audio.filePath);`
- `entry/src/main/ets/utils/HttpTtsReader.ets:861-863` — `protectedCachePaths.set(path, (get(path) || 0) + 1);`
- `entry/src/main/ets/utils/HttpTtsReader.ets:816` — `if (filePath === excludedPath || (this.protectedCachePaths.get(filePath) || 0) > 0) continue;`（受保护文件永不删）
- `entry/src/main/ets/utils/HttpTtsReader.ets:810` — `const files = fs.listFileSync(dir).filter(...)` 每句同步遍历整目录
- `entry/src/main/ets/utils/HttpTtsReader.ets:62` — `MAX_CACHE_FILES = 600` 上限因此失效
- 释放点：`HttpTtsReader.ets:114`（`writeAudio` finally，仅**真正播放**才 -1）、`:185`（`stop()` 全清，连续朗读不走）
- 章末预取也 +1：`SystemTtsReader.ets:960`；作废路径 `SystemTtsReader.ets:949`（`prefetchedCustomJobs.clear()`）、`:997`（`readGeneration` 不符直接 return）都不 -1

**机制**：`HttpTtsReader` 是单例（`:96`）。连续朗读跨章走 `SystemTtsReader.finish()` 的保活分支
（`SystemTtsReader.ets:878-886`，只 `schedulePcmOutputRelease()`，**不** `pcmPlayer.stop()`、**不**清 Map、
**不**清预取队列）。预取被丢弃 / 跳章 / 暂停 / 切音色时，已合成已 retain 的音频永不 release，
`pruneCache` 又对受保护路径 `continue`，于是缓存目录突破 600 持续增长，`:810` 遍历越来越慢。

**现象**：磁盘越来越大、每句合成后停顿递增、GC 抖动、起播变卡；只有彻底 `stop()` 才清零，故短测掩盖。
**修复**：预取作废 / generation 取消 / finish 保活等「未播放」路径配对 `releaseCacheFile`（或改按 audio 对象生命周期的 autorelease / 弱引用，而非 Map 计数）。

### A2 跨章保活 AudioRenderer 帧时间线永不复位 → 高亮漂移 / 翻页不顺
**证据**
- `entry/src/main/ets/pages/ReadBook.ets:14173-14175` — 每次起播恒传 `keepAudioOutputOnFinish: true`
- `entry/src/main/ets/utils/SystemTtsReader.ets:856` — `const keepPcmOutput = notify && this.keepAudioOutputOnFinish && this.ttsPcmPlayType === 0;`
- `entry/src/main/ets/utils/SystemTtsReader.ets:878-886` — 保活分支只 `schedulePcmOutputRelease()`；非保活分支 `:889` 才 `this.pcmPlayer.stop()`
- `entry/src/main/ets/utils/SystemTtsReader.ets:385-398` — 仅 `recycle()` 时重建；`:93` `MAX_CONTINUOUS_PCM_OUTPUT_MS = 4h` 是唯一兜底
- `entry/src/main/ets/utils/TtsPcmAudioPlayer.ets:91-93` — `const startFrame = this.queuedFrames;`（累计绝对帧号）
- `TtsPcmAudioPlayer.ets:636-649` — `clearPlaybackTimeline()` 只在 `stop()`（`:385`）调用，清零 `queuedFrames / queuedContentEndFrame / lastReachedFrame / timelineBaseFrame / rendererFrameOrigin / playbackMarks / writeChain`

**机制**：`playbackMarks` 以绝对帧为键、靠 `lastReachedFrame` 派发逐句高亮；这些帧号在整个连续会话（1~3 小时即 16kHz×3h≈1.7 亿帧）内**从不复位**。
后台限流、锁屏、音频路由切换、underrun 造成的帧漂移跨章累加，且 `ReadBook.ets:15037-15043` 的焦点代际校验
（token/generation/chapter/sourceIdentity/contentLoadSerial）挡不住时间线本身的漂移。

**现象**：高亮越来越提前/滞后、浮标进度错位、自动翻页与朗读错位。代码注释与 4h 上限说明作者已知此退化。
**修复**：换章边界做「软重置」帧时间线（清零 `queuedFrames / lastReachedFrame / playbackMarks`，**保留 renderer 实例**以维持保活初衷），或把 4h 上限改成按累计帧/章数触发 `recycle()`。

### A3 PCM drain / 帧等待无绝对超时 → 永久静音卡死
**证据**
- `entry/src/main/ets/utils/TtsPcmAudioPlayer.ets:168` — `while (generation === this.playGeneration && this.renderer === renderer) {`
- `:230` `waitUntilPlaybackFrameReached` 同形 while；`:264` `await this.delay(40);`
- `:456-477` `waitUntilRendererRunning`：renderer 卡非 RUNNING 且无 interrupt/resume 事件时，把 `check` 反复 push 进 `playbackWaiters` 而无人 resolve
- `:173-175` 注释自承部分设备「leave drain() pending」；`:249-251` 注释自承「framePos stops at an underrun」
- `:257` 墙钟兜底 + `:197-223` 120ms settle 是多重启发式叠加，任一失效即 drain 永不返回

**机制**：跨章保活时 `playGeneration / renderer` 长时不变，等待只靠设备回调推进。长时间运行把偶发的
来电 / 切后台 / 蓝牙切换 / underrun 从极低概率累积成必然。drain 不返回 → `finish()` 不触发 → 章末续播
（`ReadBook.ets:14393` `continueTtsReading`）不触发 → 看门狗 `TTS_CONTINUATION_WATCHDOG_MS=150000`
（`:159`）最终 `finishTtsReading()`，但在此之前整段静音、进度与高亮全冻结。

**现象**：连续听多章后某次中断，读到最后一句彻底静音、浮标/进度/高亮冻结，只能关掉重开。
**修复**：给 `drain` / `waitUntilPlaybackFrameReached` 加按「剩余 PCM 时长」计算的**绝对超时看门狗**，
超时强制 `settleRendererDrain` 并重建 renderer，不依赖设备回调。这与 A2 的软重置可一并设计。

### A4 suppressEngineStopEvent 单一布尔 + 无追踪 500ms 定时器 → 跳句 / 静默卡死
**证据**
- `SystemTtsReader.ets:624` `this.suppressEngineStopEvent = true; this.engine.stop();`
- `:628-630` `setTimeout(() => { this.suppressEngineStopEvent = false; }, 500);`（无 id、不 clear、复位不校验 `readGeneration`）
- `:1572-1581` `recoverStalledSpeak()` 内再起一个同样的 500ms 定时器
- `:542-544` `onStop` 里 `if (this.suppressEngineStopEvent) { return; }` 全局开关
- `:411` 每章 `readGeneration++`；`:551` 漏进的 `unexpected engine onStop` 会触发 `completeCurrentChunk / recoverStalledSpeak`
- `:549-550` 注释点名「锁屏朗读无声卡死而 UI 仍显示朗读中」

**机制**：①快速暂停后 500ms 内继续，旧 timer 仍压住/放过不该抑制的 onStop；②pause 与 watchdog 恢复各起一个 timer，
先触发的清 flag，第二个自停 onStop 漏进 → 跳句/重复推进/高亮卡住；③跨 generation：上一章 pause 的旧 timer 未触发时
新章引擎自发 onStop 被旧 flag 吞。长时间运行 + 多次暂停/后台切换显著放大。

**修复**：改带 `generation/token` 的计数或时间戳判断，`onStop` 校验 generation；500ms timer 存 id 并在
`stop` / 新 `start` 时 `clearTimeout`（顺带解决 `L1` 未追踪 setTimeout）。

---

## B. 中严重度（浮标 / 翻页 / 高亮 / 卡顿）

### A5 焦点标志复位不对称 → 浮标显示异常
**证据**
- `entry/src/main/ets/utils/TtsAvAudioPlayer.ets:400` PAUSE(FORCE) 置 `interruptPaused = true`；只有同 generation RESUME 或下次 `play`（`:35`）才清
- `:383` `if (generation !== this.playGeneration || player !== this.player) return;` 丢弃落在两句间隙的 RESUME
- `:408` STOP 只清标志不 resume 不 notify；`:211` `isInterrupted()` 把脏标志暴露给浮标
- `TtsPcmAudioPlayer.ets:837` 输出设备切换后注释明确「不自动 resume，需用户从浮标点」
- `RemoteAudioPlayback.ets:227` DUCK 改应用音量 0.35，只靠 UNDUCK（`:232`）/ RESUME（`:247`）恢复；`:243` STOP 只清标志，
  若 SHARE PAUSE（`:238`）已暂停 player 则停在 paused 无声且进度冻结
- `TtsAvAudioPlayer.ets:200/:233` `resume/clearSystemInterrupt` 额外 `TtsAudioSession.acquire(this.activeAudioSessionOwner)` 无配对 release；
  owner 已被 `:126-128` 清成 `''` 时 `TtsAudioSession.ets:10` `if (!owner) return;` 直接返回 → 恢复时 session 未重新激活

**现象**：来电/锁屏/切后台/蓝牙断连回来声音正常，但浮标一直「已中断/已暂停」需手动点一下；被导航 duck 后永久小声。
**修复**：焦点重获 / RESUME 统一清标志并 `notifyInterruptedChange`；STOP 真正 pause 并 `setState`；
恢复路径复用 play 的 owner 生命周期，acquire/release 严格成对；`RemoteAudioPlayback` 与其他播放器一致不改应用音量。

### A6 手动翻页续读无界重试 → 「听书时翻页不顺畅 / 高亮卡住」
**证据** `entry/src/main/ets/pages/ReadBook.ets:14322-14363`
```
14329 |       if (this.isPageTurning || this.queuedPageTurnCount > 0 || this.queuedPageTurnDirection !== 0 ||
14330 |         !this.isReaderPageTurnPositionReadyForTts()) {
14331 |         this.scheduleTtsResumeAfterManualPageTurn();
14332 |         return;
14333 |       }
...
14362 |     }, 48);
```
每 48ms 递归重试，**无次数/总时长上限**，只靠 `ttsManualPageTurnResumeSerial` 失效退出。
`isReaderPageTurnPositionReadyForTts()`（`:14365`）依赖 `pendingRestorePageIndex >= 0`、
`hasReaderTypographyRestoreOffset()`、分页完成等条件；长跑中若分页测量/字体恢复/预载任一环节持续不就绪，
朗读会一直停在「等待翻页落位」，表现为翻页后不出声、高亮卡住。
另：`:16588-16613` `republishTtsFocusAfterPageTurn` 是 32/64ms × attempt<6 重试链，注释自承是「有声无高亮」来源；
`:16459-16518` `syncTtsFocusAfterResume` 的回前台落位有 8s deadline（`onPageShow` 设），超时后高亮不再追齐。

**修复**：给 48ms 重试链加绝对 deadline（如 3~5s）与最大次数，超时降级为「从当前可见页首重起播」并 toast；
把 `republish` 重试与分页完成事件挂接，而非纯定时器。

### A7 浮标会话状态残留 / 双页镜像 → 浮标位置与状态错乱
**证据**
- `entry/src/main/ets/utils/ReaderTtsFloatingSession.ets:384-433` `clear()` 重置了 `globalTtsActive/Paused/.../ChapterProgress` 等，
  **未重置** `globalTtsCapsulePositionX/Y`
- `TtsGlobalCapsule.ets:22-23` `@StorageLink('globalTtsCapsulePositionX/Y')`，`:114-124` PanGesture 直接写全局坐标并持久化 → 跨会话残留
- `TtsGlobalCapsule.ets:19-21` `paused/mode/chapterProgress` 全来自 AppStorage，发布方漏更新即状态错乱；
  `:33-43` `capsuleLeft/Top` 的 clamp 依赖 `viewportWidth/Height/topInset/bottomInset` 传参，旋转/分屏后若宿主未更新传参则浮标可能越界
- `ReaderTtsFloatingSession.ets:277-291` `updatePosition()` 每个变化区间都 `notifyChanged()` → `globalTtsRevision++`
  → `ReadBook.ets:1131-1149` `onGlobalTtsRevisionChanged()` 每句触发「镜像接管/同步」；`:488-500` 十几个 `@StorageLink` 双向联动
- `ReadBook.ets:1291-1294` 本页是 owner 时 `aboutToDisappear()` **不** `stopTtsReading()`、**不** `shutdown()`，
  静态闭包（`:3-22`）长期持有整个 page；重开阅读页会走 `:16738+` 镜像会话路径，两个 page 同时消费 revision

**现象**：浮标停在奇怪位置、「已暂停/朗读中」文本与实际不符、重开书后浮标指向旧书进度。
**修复**：`clear()` 一并重置拖动坐标（或按 bookUrl 分会话存坐标）；owner 销毁但保活时显式 detach 大对象回调、
由后台控制器持有最小状态；镜像页只读、不回写 revision。

### A8 每章/每句主线程重活 → 卡顿、换章停顿
**证据**
- 每章全量重算：`SystemTtsReader.ets:404-435 / :1638-1660 / :1887-1914 / :2393-2419 / :2422-2451` —
  `normalizeText` 逐字符 `result +=`、`sanitizeStructuralSpeechArtifacts` `text.split('\n').map` 全行数组+逐行正则、
  `splitSystemText` 整章扫描、`splitSystemChunksAtPageBreaks + snapPageBreakOffset` 每 chunk×每 focusBreakOffset×radius20×2 嵌套循环；
  `focusBreakOffsets` 来自 `ReadBook.ets:14172 getTtsFocusBreakOffsets(text.length)`
- 每句 PCM 多处全量拷贝：`SystemTtsReader.ets:591 audioData.slice(0)`、`:1354 pcm.slice(0)`、`:1395 pcm.slice(...)`；
  `:1376-1381` 两个 while 每 frame `getInt16`（单句可达 72 万次）；`HttpTtsReader.ets:644-695` resample/downmix/trim 同步逐帧循环
- `HttpTtsReader.ets:289` 每句 `writeCacheFile` 后 `pruneCache` → `:810 fs.listFileSync` 整目录（与 A1 叠加）
- 监听器累积：`SystemTtsReader.ets:496/:500-501` 每章对复用 engine 重复 `setListener`（`:1588` watchdog 恢复再来一次），
  finish/stop 从不 unset；闭包捕获 `this` 与失效 generation，若平台为累加语义则随章数线性增长
- `ReaderTtsBackgroundController.ets:402-427 / :450-475` 每次状态更新与每 30s 心跳（`:162-171`）都全量
  `refreshTtsMediaImage() + setAVMetadata() + setAVPlaybackState()`，duration 按整章 `getTtsCharCountSource().length`（`:568-572`）重算

**修复**：整章 normalize/split/snap 与 PCM 变速/downmix 挪 taskpool 或改增量；合并链式 slice / 就地处理 / 分段采样；
`setListener` 收敛到 engine 新建时；`pruneCache` 节流或异步；AVMetadata 只在字段实际变化时更新。

### A9 后台心跳自停后可能未重启
**证据** `entry/src/main/ets/reader/ReaderTtsBackgroundController.ets:181-197`
```
183 | if (!this.ttsBackgroundDesired || (!host.isTtsSpeakingState() && !host.getTtsReader().isSpeaking())) {
184 |   this.stopTtsBackgroundHeartbeat();
185 |   return;
186 | }
```
暂停 / 章间无声空窗时心跳自停且 `ttsBackgroundHeartbeatId = -1`；
`:162-171` 只在 `startTtsBackgroundRunning()`（`:94-134`，`:102/:119`）里启动。
复播路径 `ReadBook.ets:13949-13998 toggleTtsReading()` 的 resume 分支只调
`updateTtsAvSessionPlaybackState(PLAY)`（`:13967`），未重新 `startTtsBackgroundRunning()`。

**现象**：长时间后台 + 多次暂停/继续后，30s 保活心跳不再触发 `syncTtsSystemMediaControls()`，
系统媒体控制 / 锁屏信息逐渐失同步。
**修复**：`updateTtsAvSessionPlaybackState(PLAY)` 或 `resume()` 成功后确保心跳运行（幂等 `startTtsBackgroundHeartbeat()`）。

---

## C. 低严重度 / 观察项
- `SystemTtsReader.ets:628/:1578` 500ms、`:1602` 0ms、`:1634` sleep 的 setTimeout 无 id 不可取消（与 A4 叠加放大）。
- `SystemTtsReader.ets:165` `prefetchedCustomJobs` Map 在 `finish()` 不清（`stop():677` 才清），自定义音色下最多留 3 个含 ArrayBuffer 的 Promise；非无限增长。
- `HttpTtsReader.ets:63-64 / :460` 静态 `sharedRuntimes`（持 QuickJS 上下文）与 `rateBuckets` 按 voiceKey 缓存无失效，有界于不同 voiceKey 数。
- `HttpTtsReader.ets:224/:749/:1105-1111` `delayCancelable` 的 setTimeout 不存 id，stop 无法 clear（≤1.8s 残留，被 generation 挡掉）。
- `TtsAvAudioPlayer.ets:458 / :462 / :466` `player.off('stateChange')` 未回传原 callback，配对性依赖平台实现。
- `TtsPcmAudioPlayer.ets:638-644` 跨章绝对帧号单调递增（数值 < 2^53 安全，仅记录，见 A2）。

---

## D. 明确「未发现」（避免过度归因）
成对清理基本功扎实，以下类别**没有**典型每句泄漏：
- `setInterval` / 递归重试无限增长：`SystemTtsReader.ets` 全文件无 setInterval；`speakWatchdogId`（`:1503-1527`）与
  `pcmOutputReleaseTimerId`（`:898-918`）都先 clear 再 set；`recoverStalledSpeak` 有 `currentFocusRetryCount>=2` 上限（`:1547`）。
- chunks / systemReadySegments / systemCurrentPcmBuffers 无限增长：无，`start:469/stop:705/finish:876` 都
  `resetSystemPcmPipeline:1271-1281`，`continueSystemPcmSynthesis:1248` 有 `SYSTEM_TTS_MAX_BUFFERED_SEGMENTS=3` 背压。
- HTTP 请求 / AVPlayer / AudioRenderer / fd / PixelMap 泄漏：无（`HttpTtsReader.ets:240 push 配 :292 filter + :294 destroy`、
  `:183-191 stop 全 destroy`、`writeCacheFile` 有 `closeSync`；`TtsAvAudioPlayer` openSync 配 closeFile；
  `TtsPcmAudioPlayer.ets:713/717/721 on 配 :736/743/750 off`；`ReaderTtsBackgroundController.refreshTtsMediaImage:477-515`
  有 raw 相同早退 + serial 防竞态 + `releaseTtsMediaPixelMap`）。
- `TtsAudioSession.owners` Set 泄漏：无（每章 acquire/release 对称 `:486-495 / :920-926`）。
- 异步回调整体代际防护较全（`onStart/onComplete/onStop/onError/onData` 各带 `readGeneration + currentRequestId` 双校验），
  主要缺口就是 A4 的布尔。
- `TtsSettingsStore.ets` / `TtsFocusLatencyMonitor.ets` 未发现长时问题（后者 samples 上限 30 + reset）。

---

## E. 建议修复顺序
1. **A3**：给 drain / 帧等待加绝对超时看门狗（解决「彻底静音只能重开」）。
2. **A1**：预取作废 / generation 取消 / finish 保活路径补 `releaseCacheFile`（解决磁盘与卡顿单调增长）。
3. **A2 + A4**：换章软重置帧时间线；`suppressEngineStopEvent` 改 generation 化并追踪 timer id。
4. **A5 / A9**：统一焦点恢复语义（标志 + owner + 心跳重启）。
5. **A6 / A7**：翻页续读与浮标会话加 deadline / 重置坐标。
6. **A8**：重活挪 taskpool / 增量 / 节流（性能，可随拆分 P0→P3 一并做）。

> 每条都应在真机「连续朗读 ≥ 2 小时 + 多次锁屏/来电/切后台/手动翻页」回归；静态检查命令为
> `devecocli check arkts <file>`。相关的 AI 友好化拆分节奏见仓库根 `CODE_MAP.md`。
