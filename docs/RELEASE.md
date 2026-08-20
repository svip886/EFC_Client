# GitHub 发布与 CI

客户端由 **Paranoid** 维护，通过 GitHub Releases 分发；与 `ecfc.fans` 站点无隶属关系。

## 仓库约定

| 项 | 值（可在 `lib/core/constants.dart` 修改） |
|---|---|
| Owner | `svip886` |
| Repo | `EFC_Client` |
| URL | https://github.com/svip886/EFC_Client |
| 版本清单（仓库） | [`app/version.json`](../app/version.json) |
| 版本清单（Release 资产） | `version.json`（与 APK 一并上传） |

## 发版流程

1. 改 `pubspec.yaml` 的 `version:`，格式 **`x.y.z+build`**（例 `1.0.1+2`）。  
   - `x.y.z` → `versionName`  
   - `build` → `versionCode`（必须单调递增）
2. 提交并推送。
3. 打 tag 并 push：
   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```
   或在 GitHub → Releases → Draft a new release（创建 tag）。
4. Actions 工作流 [`.github/workflows/release.yml`](../.github/workflows/release.yml) 会：
   - 解析 tag / `pubspec.yaml` 版本  
   - `flutter build apk --release`（当前仅 Android；可后续加 iOS/Windows/Linux）  
   - 生成 `version.json`  
   - 创建/更新 GitHub Release，上传 `app-release.apk` + `version.json`

也可手动：`Actions` → `Release` → `Run workflow`（输入 tag，如 `v1.0.1`）。

## App 检查更新顺序

1. `https://github.com/<owner>/<repo>/releases/latest/download/version.json`  
2. `https://raw.githubusercontent.com/<owner>/<repo>/master/app/version.json`  
3. GitHub API `releases/latest`（读 tag / APK 资产 / body）

## 签名（可选）

当前 release 使用 **debug 签名**（见 `android/app/build.gradle.kts`），仅便于分发测试。  
正式包请配置 `android/key.properties` + 上传 keystore，并在 CI 用 Secrets 注入：

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

（工作流里已留注释位，接入时取消注释即可。）

## 多平台路线

| 平台 | 状态 | 备注 |
|---|---|---|
| Android APK | ✅ CI | 模拟器/侧载 |
| Android App Bundle | 可选 | 上架 Play 时再加 |
| Windows | 预留 | 需 CI `windows-latest` + `flutter build windows` |
| Linux | 预留 | `ubuntu` + 系统依赖 |
| iOS | 预留 | 需 Apple 证书与 macOS runner |
| macOS | 预留 | 同上 |

## 版权

`© Paranoid` — 显示在 App 设置 → 关于。
