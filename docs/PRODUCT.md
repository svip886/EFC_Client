# 私家E院 App — 产品与技术方向

## 目标

为 [私家E院（ecfc.fans）](https://ecfc.fans/community) 做 Flutter 客户端。

**当前主方案：WebView 壳**。官方站点已是成熟的 Next.js 响应式 Web（手机/平板/横竖屏、登录墙、Cookie 会话、小臣书模式等），App 优先嵌入站点，而不是复刻一套原生 UI。`docs/ECFC_API.md` 与 `lib/services/*` 仍保留，供后续原生增强（推送、快捷挂号、桌面小组件等）使用。

## 明确不做

- 不把 FluxDO 改成换域名使用（Discourse 专用层过重）。
- 不在仓库保存用户 session / 密码。
- 不强制接入音乐版权全曲能力（Web 有 `canPlayFullMusic` 限制）。
- 不以「像素级复刻 Web」为目标做原生列表（维护成本高、易落后站点）。

## 工程布局

```
C:\private\project\app\ecfc\
  docs\                 # API / 产品文档（本目录）
  fluxdo\               # 参考实现（只读参考）
  lib\ android\ ios\ ...# 正式 Flutter 工程（根目录本身即工程，无子目录）
```

## 主界面（WebView 壳）

- 入口：`https://ecfc.fans/community`（未登录由站点跳转 `/login`）
- 站内域名 `*.ecfc.fans` / `media.ecfc.fans` 在 WebView 内打开
- 外链、`mailto:` / `tel:` 走系统浏览器或对应 App
- 全屏 WebView，不叠原生前进/后退/首页栏；系统返回键优先 Web 历史后退
- 会话：WebView Cookie 持久化（`eason_fans_session`），与 Dio CookieJar 暂不强制同步
- 横竖屏：系统全开，布局交给站点

## 已落地原生增强

- **Deep Link**：`https://ecfc.fans/*`、`ecfc://forum|checkin|notifications`（`app_links` + Manifest intent-filter；完整 App Links 需站点部署 `assetlinks.json`）
- **App Shortcuts**：长按图标 → E院广场 / 每日挂号 / 消息
- **品牌**：`applicationId=fans.ecfc.app`，蓝色启动闪屏，自适应图标前景

## 明确不做（体验冲突）

- **原生下拉刷新**：`RefreshIndicator` 包裹 WebView 会抢走站内滚动，已移除；刷新交给站点自身或错误页「重试」

## 滚动边界

- WebView `overScrollMode = never`，并注入 `overscroll-behavior: none`，避免顶/底回弹时站点 fixed 导航栏跟着晃

## 可选后续增强

- 推送通知、角标（需后端设备注册）
- Web Cookie 与 Dio CookieJar 同步后的轻量原生页 / 小组件
- 正式 App Links（`https://ecfc.fans/.well-known/assetlinks.json`）
- 外部分享接收（系统分享链接进 WebView）

## 文案与品牌

- 应用名：**私家E院**
- 可保留社区黑话：挂号、挂号费、病友

## 运行与调试

- Android 模拟器流程：参考 `C:\private\project\stock\StockGrandCouncil\docs\android-emulator.md`
- Flutter SDK：`C:\private\project\flutter`
- ECFC 网络：**直连**；pub/Gradle/Git 依赖可用 `127.0.0.1:10808`
