# 听书长跑回归报告（模拟器）

> 对应分析：[tts-long-running-bugs.md](./tts-long-running-bugs.md)
> 回归日期：2026-11-11（Asia/Shanghai）
> 设备：`hdc` emulator `127.0.0.1:5555`（OpenHarmony 7.0.0.107 SP8，模拟器，**非真机**）
> 应用：`legado.intrimple.com`，已签名 HAP `entry-default-signed.hap` 安装后启动；主进程 PID 20998 + `:render` 21342
> 朗读引擎：系统 HiAI 离线 TTS → PCM → `AudioRenderer`（`ttsPcmPlayType=0`）

## 结论先行

两轮自动化回归均**全绿**：用户描述的「长时间听书不关闭 + 听书时翻页」场景在模拟器上
未出现卡顿、浮标异常、翻页不续读、高亮卡死、静音冻结或崩溃。
针对 A1–A9 的修复路径被真实朗读日志覆盖；A8/A5′ 的「剩余项」经源码复核为**伪优化 / 非 bug**，
已在源码注释与本文档中固化，不再列为待办（详见 [tts-long-running-bugs.md](./tts-long-running-bugs.md) F 节）。

复现命令与可移植脚本见文末「复跑」一节。

---

## 回归 1：生命周期 churn（后台 / 锁屏 / 手动翻页）

脚本：`scripts/device_regression.sh`，20 轮，07:39:29 → 07:47:14（约 7 分 45 秒）。
每轮：Home 切后台 → 3s → `aa start` 回前台 → 4s → Power 灭屏 → 3s → Power 亮屏 → 4s →
两次 swipe 手动翻页 → 记录进程存活数。

| 指标 | 结果 |
|---|---|
| 完成轮数 | 20/20 |
| app 主进程 + `:render` | 全程存活（PID 20998 / 21342），末轮 `app processes=2` |
| 本 app 崩溃 / cppcrash / JS crash | 0 |
| 本 app appfreeze / ANR / THREAD_BLOCK | 0（`legado.intrimple.com` + 冻结/ANR/崩溃关键词命中 0 行） |
| `ArkTS:ERROR` | 0 |
| hilog 总量 | 396439 行 / 48.8 MB |
| `[TTS]` 朗读日志 | 0 |
| 系统 appfreeze 噪声 | `appfreeze` 关键词命中 57 行；其中带 `bundleName` 标记的 12 行全部为 `com.ohos.sceneboard`（系统桌面），本 app 命中 0 行 |
| 系统 ANR 噪声 | `ANR` 关键词命中 1 行，本 app 命中 0 行 |

**判定**：Home/锁屏 churn 会被系统按设计挂起音频，因此 `[TTS]=0` 属预期，
这一轮**不覆盖连续朗读音频**，只回答「反复切后台/锁屏/翻页后应用不崩、进程不丢、翻页仍生效」。
回归结束后 `dumpLayout` 仍显示阅读页 `548/943 488、换命  1/1`，翻页指令确实生效。

---

## 回归 2：前台连续朗读 + 翻页（用户主场景）

脚本：`scripts/foreground_regression.sh`，30 轮，07:56:26 → 08:01:05（约 4 分 40 秒）。
**不 Home、不 Power**（避免挂起音频）。前置条件：点阅读页右下角快速朗读按钮
（[1133,2181]）启动真实 TTS，`hilog -x` 已确认 77 条 `[TTS]` 后再开跑。
每轮：swipe 手动翻页 → 3s；每 5 轮反向翻页；每 7 轮点中心显隐菜单（挤压浮标）；
每轮用 `hilog -x | grep -c '[TTS]'` 记录朗读活跃度；轮末 3s。

| 指标 | 结果 | 说明 |
|---|---|---|
| 完成轮数 | 30/30 | `capture stopped` 正常收尾 |
| hilog 总量 | 121498 行 / 16.2 MB | |
| `[TTS]` 行 | 4007 | 每轮快照 400+~460 条，**全程未中断** |
| `speak start` | 156 | |
| `speak complete` | 153 | |
| `pcm data buffered` | 3240 | PCM 持续产出 |
| `system pcm segment ready` | 153 | |
| `TTS-Turn` | 72 | 手动翻页续读路径被反复触发 |
| `pcm drain waiting` | 1 | `contentEnd=50640,transportEnd=52010`，正常排空，**无超时/force-reset** → A3 看门狗在岗且不误伤 |
| `keeping pcm output for chapter handoff` | 1 | A2 换章保活 |
| `reusing pcm output across chapter handoff` | 1 | A2 时间线重锚 |
| `audio session activated` / `deactivated` | 36 / 36 | 1:1，设计行为（见下） |
| `capsule` / `floating` / `highlight` | 329 / 24 / 2 | 浮标/胶囊持续工作 |
| `HiAI_OfflineTtsService` | 4531 | 系统合成引擎活跃 |
| **ERROR 级 `[TTS]` 行** | **0** | |
| `speak error` / `ensure engine failed` / `speak throw` | 0 / 0 / 0 | |
| `recoverStalledSpeak` / `unexpected engine onStop` | 0 / 0 | A4 抑制窗口无异常 |
| `force-reset` / `watchdog timeout` | 0 / 0 | A3 未触发强制解挂 |
| 本 app 崩溃 / appfreeze / cppcrash / JS crash / ArkTS:ERROR | 0 | |

**判定**：用户真实场景「长时间听书 + 翻页」在模拟器上全绿。
A1（缓存 TTL）、A2（换章保活+时间线重锚）、A3（drain 看门狗）、A4（generation 化抑制）、
A5（焦点恢复）、A6（翻页续读 4.8s 上限）、A7（浮标坐标重置）、A9（后台心跳幂等）
的修复路径均被真实朗读日志覆盖，未出现无声、卡顿、高亮冻结或浮标错乱。

### 关于 `audio session activated/deactivated` 36 对

这不是抖动或泄漏。`start()`（`SystemTtsReader.ets:499`）每次用全新 owner
`system-tts-<serial>` 调 `TtsAudioSession.acquire()`；`finish()`（`:901`）无条件
`releaseSystemAudioSession()`。`TtsAudioSession.release()` 在 owners 集合清空后启动 300ms
去激活 debounce：翻页/换章间隔 >300ms 时打出一对 deactivate→activate，<300ms 时被
`cancelPendingDeactivate()` 合并。每轮翻页周期约 8s，与 36 对/30 轮吻合。
30 轮回归中朗读全程未中断，证明这套 1:1 acquire/release 生命周期无音频空洞。
`finish()` 里原先「keep audio-session owner」的注释与代码矛盾，已修正为准确描述。

---

## 源码复核结论（替代原「待办」）

| 项 | 原报告状态 | 复核结论 |
|---|---|---|
| A8 `setListener` 收敛 | 待做 | **伪优化，禁止**。每次 `start()` 重新 `engine.setListener()` 是替换语义（不累积、无泄漏）；回调捕获 `generation` 正是跨章防串音所需。若上提到 `ensureEngine()`（仅新建 engine 时注册），复用 engine 会冻结首章 generation → 整章无声。已在 `bindEngineListener()` 前加注释固化 |
| A8 `AVMetadata` 按需更新 | 待做 | **不适用**。全库 `entry/src/main/ets/**/*.ets`（230 文件）grep `setAVMetadata\|setMetadata\|AVMetadata\|updateMetadata\|setAVPlaybackState\|activateAVSession` 0 命中，本代码库无对应实现 |
| A8 整章 normalize/split/snap + PCM 变速挪 taskpool | 待做 | 维持暂缓：纯性能优化、需专项基准，且回归未观测到掉帧；见「残留风险」 |
| A5′ `TtsAvAudioPlayer.activeAudioSessionOwner` 生命周期 | 暂缓 | **非 bug，无需改代码**。owner 有效时已在 `TtsAudioSession.owners`（`acquire` 是 `Set.add` 幂等）；owner 为空时 `acquire` 直接 return；`stop()` 已置 `interruptPaused=false/paused=false` 使 resume/clearSystemInterrupt 早退，不会用 stale owner 复活。该播放器仅用于自定义 HTTP 音色，本次系统 PCM 回归未走该路径 |
| `finish()` 注释「保留 audio-session owner」 | — | 注释与代码矛盾（会诱导后人引入 owners Set 泄漏），已修正 |

---

## 残留风险（诚实交付）

1. **模拟器 ≠ 真机**：HiAI 离线 TTS、AudioRenderer 路由、蓝牙/来电/锁屏焦点策略在真机上行为可能不同。
   仍需真机「连续朗读 ≥ 2 小时 + 多次锁屏/来电/切后台/手动翻页」回归。
2. **自定义 HTTP 音色路径未覆盖**：本环境未配置自定义音色，`TtsAvAudioPlayer` / `HttpTtsReader`
   的 A5′ 路径仅经源码复核，未经运行时验证。
3. **UI 视觉未自动判读**：本会话模型无图像输入、无 vision provider，浮标/高亮的「显示异常」
   靠 `uitest dumpLayout` 的 bounds 与 `[TTS]` 日志间接驱动，未做逐像素/逐帧视觉比对。
4. **A8 性能项未做基准**：整章文本 normalize/split/snap 与 PCM 变速仍在主线程；30 轮回归未观测到
   掉帧，但未做长时（≥2h）帧率/内存曲线采样。
5. **生命周期轮不覆盖音频**：Home/Power 会挂起音频，连续朗读覆盖以回归 2 为准。

---

## 复跑

两个脚本已可移植化：`HDC` / `HDC_HOME` / `HDC_TARGET` / `BUNDLE` / `ROUNDS` /
`WORKSPACE` / 日志路径 / swipe 坐标均可用环境变量覆盖；启动前用 `hdc list targets`
精确匹配 target（hdc 对未知 connect-key 也返回 0，故不能只看 shell 退出码）；
`hilog` 后台跟随进程由 `trap` 在退出时自动清理。

```bash
# 0) 列出设备、确认 app 已安装且 TTS 已开始朗读
HDC="/c/sandbox/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe"
"$HDC" list targets
"$HDC" -t 127.0.0.1:5555 shell "hilog -x" | grep "\[TTS\]" | tail

# 1) 生命周期 churn（20 轮，验证不崩/进程存活）
bash scripts/device_regression.sh 20

# 2) 前台连续朗读 + 翻页（30 轮，验证主场景；跑前先确保 TTS 正在播放）
bash scripts/foreground_regression.sh 30

# 自定义环境示例
HDC_TARGET="emulator-5554" BUNDLE="legado.intrimple.com" \
  bash scripts/foreground_regression.sh 10

# 3) 事后扫描（PowerShell / bash 均可，按关键词计数）
#    [TTS] / speak start / pcm drain waiting / force-reset / appfreeze /
#    ArkTS:ERROR / 本 bundle 的 crash 行
```

日志落在 `scripts/_regression_*.log` / `scripts/_fg_*.log`（`*.log` 已被 `.gitignore` 忽略，
提交前删除临时 `_*.log` 即可）。UI 驱动坐标按 1280×2832 屏幕标定，换分辨率需覆盖
`SWIPE_FROM` / `SWIPE_TO` / `SWIPE_NEXT` / `SWIPE_BACK` / `TAP_XY`。
