# CLAUDE.md

本仓库是 **私家E院（ECFC，https://ecfc.fans）** 的 Flutter 客户端。**项目根目录本身就是 Flutter 工程**（`pubspec.yaml` 就在根下），不要再建 `ecfc_app/` 之类子目录。

## 目录结构

```
.
├── lib/                 # Dart 源码（页面、模型、服务、状态管理）
├── android/ ios/ windows/ macos/ linux/   # 各平台壳工程
├── test/
├── pubspec.yaml / pubspec.lock
├── docs/
│   ├── ECFC_API.md      # ★ ECFC 接口调研文档，持续更新
│   ├── PRODUCT.md       # 产品/技术方向
│   └── api-samples/     # 脱敏后的真实响应样本
└── fluxdo/              # 参考项目（Linux.do 第三方客户端，只读，不要改）
```

## 项目背景

- ECFC **不是 Discourse**，是自研 Next.js 论坛（陈奕迅粉丝社区，昵称「私家E院」）。
- `fluxdo/` 是 UI/工程风格参考（Material 3、Riverpod、底栏+信息流+详情楼层的交互习惯），**接口层完全不通用**，须按 `docs/ECFC_API.md` 重新实现。
- 站点用「医院/挂号」黑话：签到=挂号、积分=挂号费、经验等。

## 网络规则（重要）

| 目标 | 是否走代理 |
|---|---|
| `https://ecfc.fans`（业务 API/资源） | **直连，禁止代理** |
| GitHub / pub.dev / Flutter 官方源 | 可用本地代理 `http://127.0.0.1:10808`，或优先用中国镜像 |

Flutter/pub 中国镜像（网络慢时用）：

```powershell
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
```

## 产品形态（当前）

- **主界面是 WebView 壳**（`lib/pages/web_shell_page.dart`），加载 `https://ecfc.fans/community`。
- 站点已做横竖屏/手机适配；登录与 `eason_fans_session` 由 WebView Cookie 托管。
- 原生 Dio 服务层仍保留在 `lib/services/`，供后续增强；**不要**在未明确需求时再铺一套完整原生论坛 UI。

## 鉴权与核心 API

- 会话 Cookie：`eason_fans_session`（`Domain=.ecfc.fans`，HttpOnly+Secure+SameSite=Lax）
- 登录：Web 内登录即可；原生若调用则为 `POST /api/auth/login`，body `{identifierType, identifier, password, phoneCountry?}`
- 详细接口、字段、分页规则、待补清单：**必须先看 `docs/ECFC_API.md` 再写网络层代码**，不要凭猜测拍字段名。

## 环境（Windows 本机）

| 用途 | 路径 |
|---|---|
| Flutter SDK | `C:\private\project\flutter`（stable 3.47.1，via CN 镜像 bootstrap） |
| JDK 17 | `C:\private\project\jdk17` |
| Android SDK | `C:\private\project\android-sdk` |
| Gradle | `C:\private\project\gradle-8.7` |
| Android 模拟器操作手册 | `C:\private\project\stock\StockGrandCouncil\docs\android-emulator.md`（AVD、adb、安装启动流程通用） |

PowerShell 环境变量模板：

```powershell
$env:JAVA_HOME = "C:\private\project\jdk17"
$env:ANDROID_HOME = "C:\private\project\android-sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:Path = "C:\private\project\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\emulator;C:\private\project\gradle-8.7\bin;" + $env:Path
```

`flutter doctor` 已知待办：Android SDK 需升到 36（当前 35）；Windows 桌面需装 Visual Studio C++ 组件；Web 需配置 Chrome。这些不影响 Android 开发主线，暂不处理。

## 开发命令

```powershell
flutter pub get
flutter run -d <device>
flutter analyze
flutter test
```

## 提交约定

- 不要把 `eason_fans_session` 等真实 Cookie/密码写入仓库或 `docs/api-samples/`。
- 每确认一条新接口，更新 `docs/ECFC_API.md` 对应章节，并追加脱敏样本到 `docs/api-samples/`。

## 发布 / 版本

- 客户端版权：**Paranoid**；发版与检查更新走 GitHub（`docs/RELEASE.md`）。
- 版本号：`pubspec.yaml` 的 `x.y.z+build`；打 `v*` tag 触发 `.github/workflows/release.yml`。
- GitHub 仓库默认 `svip886/EFC_Client`；若变更，同步改 `lib/core/constants.dart` 的 `githubOwner` / `githubRepo`。
- 安装调试包用 `adb install -r`，**禁止卸载**（会清 WebView 登录态）。
