# GitHub 发布与 CI

客户端由 **Paranoid** 维护，通过 GitHub Releases 分发；与 `ecfc.fans` 站点无隶属关系。

## 仓库

| 项 | 值 |
|---|---|
| URL | https://github.com/svip886/EFC_Client |
| Owner / Repo | `svip886` / `EFC_Client`（`lib/core/constants.dart`） |
| 版本清单 | Release 资产 `version.json`；仓库备份 `app/version.json` |

## 发版（能打包即可）

1. 改 `pubspec.yaml`：`version: x.y.z+build`（build 单调递增）
2. 推送并打 tag：
   ```bash
   git tag v1.0.1
   git push origin master --tags
   ```
3. Actions [`release.yml`](../.github/workflows/release.yml) 并行构建并上传：

| 产物 | Runner | 说明 |
|---|---|---|
| `ecfc-*-android.apk` | ubuntu | 可侧载（当前 debug 签名配置见 `android/app/build.gradle.kts`） |
| `ecfc-*-windows-x64.zip` | windows | 解压运行；需系统已装 [WebView2](https://developer.microsoft.com/microsoft-edge/webview2/) |
| `ecfc-*-macos.zip` | macos | 内含 `.app`；未公证，本机可能需右键打开 |
| `ecfc-*-ios-unsigned.zip` | macos | `Payload/Runner.app`，**无签名**；仅构建验证，真机需自行签名 |
| `version.json` | — | App「检查新版本」读取；`downloadUrl` 默认指向 Android APK |

每个平台 **只上传一个主文件**（Android 不再双份 APK）。

也可：`Actions` → `Release` → `Run workflow`。

## App 检查更新顺序

1. `.../releases/latest/download/version.json`
2. raw `app/version.json`
3. GitHub API `releases/latest`

## 本机 Gradle 代理

不要写进仓库 `android/gradle.properties`。本机用：

`%USERPROFILE%\.gradle\gradle.properties`

## 平台说明（当前策略）

- **Android 专有**：系统分享、Shortcuts、桌面小组件、厂商角标 — 其它平台自动降级，不影响 WebView 主壳。
- **iOS/macOS**：已改 Bundle ID `fans.ecfc.app`、显示名、URL Scheme `ecfc`、macOS 网络权限；**不做商店上架/公证**。
- **Windows**：资源信息改为私家E院 / Paranoid。
- 正式签名（Play / App Store / 公证）以后再说。

## 版权

`© Paranoid` — App 设置 → 关于。
