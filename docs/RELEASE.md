# GitHub 发布与 CI

客户端由 **Paranoid** 维护，通过 GitHub Releases 分发；与 `ecfc.fans` 站点无隶属关系。

## 仓库

| 项 | 值 |
|---|---|
| URL | https://github.com/svip886/EFC_Client |
| Owner / Repo | `svip886` / `EFC_Client`（`lib/core/constants.dart`） |
| 版本清单 | Release 资产 `version.json`；仓库备份 `app/version.json` |

## Android 固定签名（2026-08 起）

Android release 用**固定 keystore** 签名，保证每次 CI 产物签名一致、可直接覆盖升级：

| 项 | 值 |
|---|---|
| keystore | `android/app/ecfc-release.jks`（**不入库**，gitignore） |
| 别名 | `ecfc` |
| 本地配置 | `android/key.properties`（**不入库**，gitignore） |
| 证书 SHA-256 | `b2f2e5ac1bfee2661b408d3352148772f275df981f1c215843accd24577449b1` |

CI 端（`release.yml` Android 任务）从 Secrets 解码生成：

- `ANDROID_KEYSTORE_BASE64`：keystore 文件的 base64
- `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_PASSWORD`：密码
- `ANDROID_KEY_ALIAS`：`ecfc`

本地无 `key.properties` 时自动回退 debug 签名（开发不影响）。

**备份提醒**：`ecfc-release.jks` 与密码丢失 = 无法再覆盖升级（只能换包名重发）。请把 keystore 和密码另存到安全位置。

**注意**：历史上 CI 曾用 runner 随机 debug 签名，旧版本用户升级到固定签名版需**卸载重装一次**（WebView 登录态会丢，需重新登录）。

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
| `ecfc-*-android.apk` | ubuntu | 固定 keystore 签名（见上文），可覆盖升级 |
| `ecfc-*-windows-x64.zip` | windows | 解压运行；需 [WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/) |
| `ecfc-*-macos.zip` | macos | 内含 `.app`；未公证，本机可能需右键打开 |
| `ecfc-*-ios-unsigned.zip` | macos | `Payload/Runner.app`，**无签名**；仅构建验证，真机需自行签名 |
| `version.json` | — | App「检查新版本」读取；`downloadUrl` 默认指向 Android APK |

文件名只带 **对外版本号**（如 `ecfc-1.0.2-android.apk`），**不含** `+build`。  
`pubspec.yaml` 里仍写 `x.y.z+build` 供 Android versionCode 使用。

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
- **Windows**：使用 `webview_windows`（WebView2）。未装 Runtime 时会提示下载；资源信息为私家E院 / Paranoid。
- 正式签名（Play / App Store / 公证）以后再说。

## 版权

`© Paranoid` — App 设置 → 关于。
