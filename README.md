# 私家E院 App

[私家E院（ecfc.fans）](https://ecfc.fans/community) 第三方客户端 —— 一个更像原生 App 的社区入口。

**版权：** © Paranoid（客户端本身）  
社区网站版权归其运营方所有，本项目与官方无隶属关系。

## 下载安装

到 [Releases](https://github.com/svip886/EFC_Client/releases/latest) 下载对应平台安装包：

| 平台 | 文件 | 说明 |
|---|---|---|
| Android | `ecfc-<版本>-android.apk` | 直接安装；v1.0.6 起签名固定，**升级直接覆盖安装、不丢登录态** |
| Windows | `ecfc-<版本>-windows-x64.zip` | 解压运行；需 [WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/)（Win11 一般自带） |
| macOS | `ecfc-<版本>-macos.zip` | 未公证，首次打开请**右键 → 打开** |
| iOS | `ecfc-<版本>-ios-unsigned.zip` | 无签名包，需自签后侧载，仅供折腾 |

> 从 v1.0.5 及更早版本升级到 v1.0.6+ 的 Android 用户：旧版签名不稳定，需要**卸载重装一次**（需重新登录）。之后所有版本均可直接覆盖升级。

## 功能

### 消息与通知
- **新消息实时提醒**：连接站点实时通道，有人回复、点赞、私信时弹系统通知，**点击直达消息中心**；网络不稳时自动退回轮询，不漏消息
- **桌面角标**：未读数实时显示在 App 图标上

### 每日挂号（签到）
- **一键挂号**：长按桌面图标（App Shortcuts）直接签到，不用打开网页找入口
- **桌面小组件**：小组件上直接看今日挂号状态、一键完成

### 浏览与分享
- **完整社区体验**：全屏加载官方站，登录一次长久保留（Cookie 由 App 托管）
- **接收分享**：在浏览器/微信里看到帖子链接，分享给私家E院直接打开；纯文字则转为站内搜索
- **Deep Link**：点开 `ecfc.fans` 链接可选择用 App 打开

### App 设置
- 站内点头像，菜单里多了 **App 设置**：检查新版本、关于与版权信息
- **应用内检查更新**：新版本发布后一键跳转下载

## 常见问题

- **收不到通知？** Android 请确认系统设置里允许「私家E院」通知（首次启动会请求权限）；通知只在有**新**未读时提醒，不是每条都弹。
- **登录态丢了？** 覆盖升级不会丢；如果卸载重装或清了 App 数据，需要重新登录网站。
- **Windows 打开灰屏？** 安装 [WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/) 后重开。

## 开发

```powershell
# 环境与镜像见 CLAUDE.md
flutter pub get
flutter run -d <device>
flutter test
flutter build apk --debug
```

ECFC 业务域名**直连**；pub / GitHub 可用本地代理。接口调研见 [docs/ECFC_API.md](docs/ECFC_API.md)。

## 发布

由维护者手动发版（不自动触发）：改 `pubspec.yaml` 版本 → 打 `vX.Y.Z` tag → GitHub Actions 多平台构建并挂 Release。细节见 [docs/RELEASE.md](docs/RELEASE.md)。

检查更新清单：<https://github.com/svip886/EFC_Client/releases/latest/download/version.json>

## 许可证

源代码版权归 Paranoid 所有；未另作说明前请勿用于商业分发。  
使用本客户端访问 ecfc.fans 时，请遵守该站用户协议。
