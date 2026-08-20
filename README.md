# 私家E院 App

非官方 [私家E院（ecfc.fans）](https://ecfc.fans/community) Flutter 客户端。  
主界面为 WebView 壳，附带 Deep Link、一键挂号、桌面小组件、未读角标等原生增强。

**版权：** © Paranoid（客户端）  
社区网站版权归其运营方所有，本项目与官方无隶属关系。

## 功能

- 全屏嵌入官方响应式站点（登录态由 WebView Cookie 托管）
- Deep Link / App Shortcuts / 系统分享接收
- 一键挂号 + 每日挂号桌面小组件
- 未读角标（轮询通知摘要）
- App 设置：关于、版权、GitHub 检查更新

## 开发

```powershell
# 环境见 CLAUDE.md
flutter pub get
flutter run -d <device>
flutter test
flutter build apk --debug
```

ECFC 业务域名请**直连**；pub / GitHub 可用本地代理。

## 发布

见 [docs/RELEASE.md](docs/RELEASE.md)。

简要：

1. 修改 `pubspec.yaml` → `version: x.y.z+build`
2. `git tag vX.Y.Z && git push origin vX.Y.Z`
3. GitHub Actions 产出 APK + `version.json` 到 Releases

检查更新读取：

- `https://github.com/Paranoid/ecfc/releases/latest/download/version.json`
- 回退：`app/version.json`（raw）与 GitHub API

> 若仓库不在 `Paranoid/ecfc`，请改 `lib/core/constants.dart` 中的 `githubOwner` / `githubRepo`。

## 许可证

源代码版权归 Paranoid 所有；未另作说明前请勿擅自分发商业用途构建。  
使用本客户端访问 ecfc.fans 时，请遵守该站用户协议。
