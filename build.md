# legado-Harmony 构建 / 安装到手机 / 分发 操作手册

本手册覆盖本机环境下的完整流程：从项目初始化、编译打包（HAP / APP）、安装运行到真机，再到通过蒲公英 / AGC 将应用分发给测试人员。

## 1. 环境准备（一次性）

| 依赖 | 说明 |
| --- | --- |
| DevEco Studio | 本机安装目录记为 `<DEVECO_HOME>`（含 SDK 与 hdc 工具链） |
| `DEVECO_HOME` | 指向 DevEco Studio 安装目录，供命令行工具使用 |
| `devecocli` | HarmonyOS 应用命令行工具（构建 / 运行 / 设备管理 / 日志等） |
| hdc | `<DEVECO_HOME>\sdk\default\openharmony\toolchains\hdc.exe` |

**devecocli 安装**（需 Node.js 18+，DevEco Studio 6.1.0+）：

```powershell
npm install -g @deveco/deveco-cli@latest
```

查看工具版本与可用命令：

```powershell
devecocli --version
devecocli -h
```

> **Windows 提示**：若 PowerShell 提示禁止运行 `devecocli.ps1`，可改用 `devecocli.cmd`，或在普通命令提示符中执行。

## 2. 项目初始化

```powershell
git clone <仓库地址> legado-Harmony
cd legado-Harmony
```

- 应用包名：`legado.intrimple.com`（EntryAbility 启动）
- 工程结构：`build-profile.json5`（签名/SDK 版本）、`entry/`（主模块）、`oh-package.json5`（依赖）
- 若是新脚手架项目，可用 `devecocli create` 生成后替换源码

## 3. 签名配置

HarmonyOS 的签名文件分两类，**用途严格区分，不可混用**：调试证书专用于本地真机调试，发布证书专用于打包分发。本机调试证书绑定了固定 UDID，换设备后会失效；发布证书则用于正式打包和 AGC 分发。

### 3.1 本机调试签名（真机调试用）

编辑 `build-profile.json5` → `signingConfigs`，使用本机调试证书：

```json5
"signingConfigs": [
  {
    "name": "debug",
    "type": "certificate",
    "material": {
      "certpath": "C:\\...\\debug-cert.cer",
      "storePassword": "...",
      "keyAlias": "debug",
      "keyPassword": "...",
      "profile": "C:\\...\\debug-profile.p7b",
      "signAlg": "SHA256withECDSA",
      "storeFile": "C:\\...\\debug-keystore.p12"
    }
  }
]
```

并在 `entry` 模块的 `build-option` 中引用 `"signingConfig": "debug"`。

### 3.2 发布签名（打包分发用）

如果你需要将应用打包分发给他人测试（蒲公英或 AGC），**必须使用发布证书 + 发布 Profile** 进行签名。调试证书打包的 HAP 无法通过蒲公英或 AGC 分发。

**准备材料**（在 AGC 申请）：

1. 登录 AGC，进入 **“证书、APP ID 和 Profile” → “证书”**，上传 DevEco Studio 生成的 CSR 文件申请**发布证书（.cer）**。证书有效期 3 年，每个账号最多可申请 3 个。
2. 进入 **“Profile”** 页面，点击“添加”，类型选择 **“指定设备发布”**（用于蒲公英/HAP 分发）或 **“内部测试”**（用于 AGC 市场分发）。选择发布证书和测试设备，最多可选 100 台设备。
3. 下载生成的 Profile 文件（.p7b）。

**配置发布签名**：

在 `build-profile.json5` 中新增 `release` 签名配置（与 `debug` 并列）：

```json5
"signingConfigs": [
  {
    "name": "release",
    "type": "certificate",
    "material": {
      "certpath": "C:\\...\\release-cert.cer",
      "storePassword": "...",
      "keyAlias": "release",
      "keyPassword": "...",
      "profile": "C:\\...\\release-profile.p7b",
      "signAlg": "SHA256withECDSA",
      "storeFile": "C:\\...\\release-keystore.p12"
    }
  }
]
```

同时在 `products` 中新增 release 产品，或在 `buildOption` 中切换签名配置：

```json5
"products": [
  {
    "name": "default",
    "signingConfig": "debug",
    // ...
  },
  {
    "name": "release",
    "signingConfig": "release",
    // ...
  }
]
```

也可以直接在工程根目录执行 `devecocli signature generate` 自动生成签名材料并写入配置。

> **注意**：如果只在 `hvigorfile.ts` 中通过 `overrides` 加载签名，AGC 上传时可能报 **错误码 993（Profile 文件非法）**，必须将签名配置写入 `build-profile.json5`。

## 4. 连接手机

1. 手机开启 **开发者模式 + USB 调试**（设置 → 关于 → 连点版本号；再开启"USB 调试"）
2. USB 连接电脑，手机上允许调试授权
3. 确认设备已连接：

```powershell
devecocli device list       # 查看已连接设备
devecocli device -h         # 设备管理子命令
```

## 5. 编译打包

### 5.1 构建 HAP 包（调试用）

```powershell
devecocli build --modules entry --build-mode debug
```

- 产物：`entry/build/default/outputs/default/entry-default-signed.hap`
- 如需 Release 模式的 HAP：将 `--build-mode debug` 改为 `--build-mode release`
- 成功标志：`BUILD SUCCESSFUL`
- 输出中的 `ArkTS:WARN`（如 `VerifyWeb.ets` 的 `getContext` 弃用提示）为存量无害告警，可忽略

### 5.2 构建 APP 包（发布/分发用）

> **重要**：`devecocli build` 默认构建的是整个产品的 **.app 包**，而不是单个 HAP。要构建 HAP 必须加 `--modules` 参数。

```powershell
# 构建 Release .app 包（对应 IDE 的 Build APP(s)）,取决于配置的模块：
devecocli build --product default --build-mode release
devecocli build --product release --build-mode release
```

- 产物：工程根目录 `build/outputs/{product}/` 下的 `.app` 文件
- 前提：`build-profile.json5` 中已配好**发布签名**，否则生成的包可能无法通过 AGC 校验

### 5.3 打包产物对照表

| 命令 | 产物 | 用途 | 签名要求 |
| --- | --- | --- | --- |
| `devecocli build --modules entry --build-mode debug` | HAP（debug） | 本机真机调试 | 调试证书 |
| `devecocli build --modules entry --build-mode release` | HAP（release） | 蒲公英分发 / 指定设备发布 | 发布证书 |
| `devecocli build --product default --build-mode release` | APP（release） | AGC 内部测试 / 上架 | 发布证书 |

## 6. 安装到手机并启动

```powershell
devecocli run --skip-build    # 使用已有产物直接安装（推荐：build 成功后执行）
devecocli run                 # 重新构建 + 安装 + 启动
```

- 多设备时通过 `--device <序列号>` 指定目标设备
- 安装成功后会自动拉起应用（`start ability successfully`）

### 常见问题

| 现象 | 原因 / 处理 |
| --- | --- |
| `failed to start ability` + `10106102 屏幕锁定` | 手机锁屏导致无法自动启动，**解锁后手动打开 app 即可**，非崩溃 |
| 安装失败：签名错误 | 检查 `build-profile.json5` 签名配置与证书是否匹配、是否过期 |
| `Target device is a real device, but the artifact is not signed` | 真机安装要求 HAP 已完成签名，检查 `build-profile.json5` 中的 `signingConfig` 配置 |
| 找不到设备 | 重新插拔 USB、确认手机调试授权弹窗、`devecocli device list` 确认在线 |
| 改了签名证书后旧包无法覆盖安装 | 先卸载旧包再安装新包 |

## 7. 运行日志排查

```powershell
devecocli log --level E                        # 仅查看 Error 级别日志
devecocli log --follow --bundle-name legado.intrimple.com   # 实时跟踪指定应用日志
devecocli log --crash --bundle-name legado.intrimple.com    # 查看崩溃日志
devecocli log --from 5m --tail 100             # 最近 5 分钟日志，限制 100 条
```

也可直接使用 hdc + hilog：

```powershell
& "<DEVECO_HOME>\sdk\default\openharmony\toolchains\hdc.exe" shell hilog | findstr legado.intrimple.com
```

`devecocli log` 支持按日志级别（D/I/W/E/F）、包名、关键词、时间窗口过滤，并可通过 `--crash` 参数调用系统 Faultlogger 服务读取崩溃日志。

## 8. 日常迭代流程（速查）

```powershell
# 改代码后：
devecocli build --modules entry && devecocli run --skip-build
# 手机锁屏导致启动失败时：解锁手机，手动点开 app
```

## 9. 分发测试人员

本节覆盖将应用分发给他人安装的三条路径，按推荐优先级排列。

### 9.0 分发渠道总览

| 方式 | 包格式 | 签名 | 对方安装方式 | 有效期 | 适用场景 |
| --- | --- | --- | --- | --- | --- |
| **蒲公英（第三方）** | HAP | 发布证书 + 指定设备发布 Profile | 浏览器打开链接下载 | 链接长期有效 | 非技术测试人员，最便捷 |
| **指定设备发布（AGC）** | HAP | 发布证书 + 指定设备发布 Profile | 自建服务器下载 | 由开发者决定 | 内部团队，自控分发节奏 |
| **内部测试（AGC）** | APP | 发布证书 + 内部测试 Profile | 华为应用市场下载 | **90 天** | 体验最接近正式分发 |

### 9.1 蒲公英分发（推荐，操作最简单）

蒲公英（pgyer.com）支持 HarmonyOS HAP 包分发，上传后自动生成下载链接和二维码，测试人员通过浏览器即可下载安装。

**前置条件**：HAP 包必须使用**发布证书 + 指定设备发布 Profile**签名，且目标设备的 UDID 已注册到 AGC 设备列表中。

**操作步骤**：

1. 按 **5.1 节** 生成 Release 模式的 HAP 包：
   ```powershell
   devecocli build --modules entry --build-mode release
   ```
2. 登录蒲公英官网，点击“发布应用”，上传签名后的 HAP 包。
3. 上传时需一并提供签名证书（`.p12`）及密码。
4. 上传完成后，蒲公英自动生成**下载链接和二维码**，分享给测试人员即可。
5. 测试人员在 HarmonyOS 设备的浏览器中打开链接，点击下载，系统自动识别 HAP 安装包并安装。

> **注意**：若测试设备的 UDID 未包含在 Profile 中，安装会失败。需先在 AGC 的“设备”页面添加 UDID，再重新申请 Profile 并重新打包。

### 9.2 AGC 指定设备发布（自行部署分发）

指定设备发布允许你将 HAP 包上传至自己的服务器或第三方云，测试人员从链接下载安装。**无需提交华为应用市场审核**，安装设备上限 100 台，仅支持分发中国大陆地区。

**前置条件**：
- 目标设备的 UDID 已注册到 AGC。获取 UDID 命令：
  ```powershell
  hdc shell bm get --udid
  ```
  连接设备后执行，返回的 64 位字符串即为 UDID。
- 已在 AGC 申请**指定设备发布 Profile**（类型选择“指定设备发布”）。

**操作步骤**：

1. 在 AGC 的“设备”页面添加测试设备 UDID。支持单个添加或下载模板批量导入。
2. 在 AGC 的“Profile”页面创建指定设备发布 Profile，选择发布证书和已注册的测试设备。
3. 按 **3.2 节** 配置发布签名，按 **5.1 节** 生成 Release HAP。
4. 将签名后的 HAP 包**上传至你自己的服务器或第三方云**（需 HTTPS 链接）。
5. 将下载链接分享给测试人员，对方在已注册 UDID 的设备上下载安装。

> **有效期说明**：指定设备发布的版本有效期由你自行控制（只要服务器上的文件不删除即可）。但 Profile 本身有有效期（通常 90 天），到期后需重新申请 Profile 并重新打包。

### 9.3 AGC 内部测试（通过华为应用市场分发）

内部测试通过**测试人员的华为账号**授权，**不需要收集 UDID**。测试人员在华为应用市场的“内部测试”专区下载安装，体验最接近正式分发。邀请测试最大有效期**90 天**，到期后必须递增 `versionCode` 重新发布。

**前置条件**：已上传 `.app` 包至 AGC。

**操作步骤**：

**第 1 步：上传 .app 包**

```powershell
devecocli build --product default --build-mode release
```

登录 AGC，进入 **“应用上架 > 软件包管理”**，点击“上传”，**“使用场景”选择“仅测试”**，上传 `.app` 文件。

**第 2 步：创建测试版本**

进入 **“应用测试 > 版本列表”**，点击“创建测试版本”，**“测试阶段”选择“邀请测试”**。

**第 3 步：配置测试信息**

- **版本号**：`versionCode` 必须高于所有已发布版本。
- **测试时间**：设置开始和结束时间，最大 90 天。
- **软件包**：选择刚上传的 `.app` 包。
- **测试人员**：添加测试群组或指定测试用户的**华为账号**，也可生成邀请链接分享。最多支持 50 个测试群组，累计去重总数不超过 10000 人。
- **隐私政策**、**测试说明**等必填项。

**第 4 步：提交并分发**

提交后等待**极速审核**。审核通过后，测试人员会收到邀请邮件/短信，点击链接接受邀请后，即可在**华为应用市场 → 我的 → 内部测试**中下载安装。

> **90 天过期问题**：内测包安装到设备满 90 天后无法启动。续期方式是**递增 `versionCode`**，重新打包并发布新的测试版本。同时需确保 Profile 文件在有效期内，过期需重新申请。

### 9.4 分发前检查清单

- [ ] HAP/APP 包使用**发布证书**签名（非调试证书）
- [ ] Profile 类型正确（蒲公英/指定设备 → “指定设备发布”；AGC 内部测试 → “内部测试”）
- [ ] 测试设备 UDID 已注册到 AGC（蒲公英/指定设备发布方式）
- [ ] `versionCode` 已递增
- [ ] `build-profile.json5` 中签名配置已写入（非 `hvigorfile.ts` 覆盖）
- [ ] Profile 未过期、未失效

## 10. 常见错误排查

| 错误码/现象 | 原因 | 处理 |
| --- | --- | --- |
| **993**（Profile 文件非法） | 签名配置未写入 `build-profile.json5`，或在 `hvigorfile.ts` 中覆盖加载 | 将签名配置移到 `build-profile.json5` 的 `products` → `signingConfig` 中 |
| **993** | Profile 已被删除或与当前应用不匹配 | 在 AGC 重新申请 Profile，替换本地文件后重新打包上传 |
| **993** | 打包使用的是调试证书而非发布证书 | 确认 `signingConfig` 指向的是配置了发布证书的签名 |
| **10106102** | 屏幕锁定，无法自动启动 | 解锁手机，手动打开应用，非崩溃 |
| **100021** | 安装包与设备不匹配 | 确认设备类型（手机/平板/PC）与 AGC 中 Profile 的设备类型一致 |
| 真机安装提示未签名 | HAP 产物未签名 | 检查 `build-profile.json5` 中 `signingConfig` 是否引用了正确的签名配置 |