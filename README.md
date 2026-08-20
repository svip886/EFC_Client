# 私家E院 App

非官方 [私家E院（ecfc.fans）](https://ecfc.fans/community) Flutter 客户端。  
主界面为 WebView 壳，附带 Deep Link、一键挂号、桌面小组件、未读角标等原生增强。

**版权：** © Paranoid（客户端）  
社区网站版权归其运营方所有，本项目与官方无隶属关系。

## 功能

- 全屏嵌入官方响应式站点（登录态由 WebView Cookie 托管）
- Deep Link / App Shortcuts / 系统分享接收（Android 优先）
- 一键挂号 + 每日挂号桌面小组件（Android）
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

1. 修改 `pubspec.yaml` → `version: x.y.z+build`
2. `git tag vX.Y.Z && git push origin master --tags`
3. GitHub Actions 产出：
   - `ecfc-<version>-android.apk`
   - `ecfc-<version>-windows-x64.zip`（需 WebView2）
   - `ecfc-<version>-macos.zip`
   - `ecfc-<version>-ios-unsigned.zip`（无签名，仅构建验证）
   - `version.json`

文件名**不含** `+build`（构建号只写在 `pubspec` / version.json 字段里）。

检查更新：

- https://github.com/svip886/EFC_Client/releases/latest/download/version.json

仓库：https://github.com/svip886/EFC_Client

## 许可证

源代码版权归 Paranoid 所有；未另作说明前请勿擅自分发商业用途构建。  
使用本客户端访问 ecfc.fans 时，请遵守该站用户协议。
