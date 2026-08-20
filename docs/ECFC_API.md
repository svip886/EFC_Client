# 私家E院（ECFC）API 调研笔记

> 调研日期：2026-08-20  
> 站点：https://ecfc.fans  
> 社区入口：https://ecfc.fans/community  
> 参考客户端风格：`fluxdo/`（Linux.do / Discourse 第三方客户端）  
> 样本 JSON：`docs/api-samples/`（已脱敏，不含 session）

## 1. 结论摘要

| 项 | 内容 |
|---|---|
| 产品 | **私家E院 / Eason Fans Club**，陈奕迅中文粉丝社区 |
| 技术栈 | **Next.js App Router** + 自研 REST（**不是 Discourse**） |
| 媒体 | `https://media.ecfc.fans`；部分头像仍见腾讯云 COS |
| 鉴权 | Cookie 会话：`eason_fans_session`（`Domain=.ecfc.fans`，HttpOnly + Secure + SameSite=Lax） |
| 访问策略 | **整站登录墙**：未登录访问业务页 `307` → `/login?next=...`；`/api/*` 多数返回 401 JSON |
| 与 FluxDO | **不能换 baseUrl 复用**。可复用 Flutter 工程习惯、M3 UI、信息流/详情/底栏交互思路 |

未登录错误体示例：

```json
{"ok":false,"code":"UNAUTHORIZED","message":"请先登录"}
```

## 2. 站点信息架构（Web）

### 2.1 主导航

- 首页 `/community`（也作大厅）
- E院广场 `/forum`（帖子列表，分区筛选）
- EasMusic `/music`
- 今日 `/today`
- 娱乐天空 `/entertainment`、`/games`
- 阿士匹灵门诊部 `/clinic`
- 歌·颂、活动中心 `/activities`
- 消息 `/messages`、`/notifications`
- 我的 `/profile`
- 每日挂号（签到）`/checkin`
- 发帖 `/posts/new`
- 帖子详情 `/posts/{postId}`
- 搜索 `/search`
- 设置 `/settings`（网站内设置）
- App 版本清单（客户端自用，公开）：`GET /app/version.json`（样本 `api-samples/app_version.json`；站点需自行部署）

### 2.2 主题

- 全局：`localStorage.ecfc-theme` = `day` | `midnight`
- 论坛移动端：`ecfc-forum-theme` = `plaza` | `xiaochenshu`（小臣书模式）

### 2.3 业务隐喻

医院/挂号话术：每日挂号=签到、挂号费=积分、经验/等级（如 Lv.1 初入E院）、病友=用户。

### 2.4 论坛分区（boards）

| name | slug | 说明（摘自 API） |
|---|---|---|
| 公告区 | `announcements` | 官方公告、站务 |
| 日常吹水 | `daily-chat` | 闲聊打卡 |
| 演唱会 | `concerts` | 巡演/repo |
| 物料交换 | `merch-exchange` | 周边交换 |

## 3. 鉴权

### 3.1 登录

- **页面**：`GET /login`（手机号 / 邮箱 Tab）
- **接口**：`POST /api/auth/login`
- **请求头**：`Content-Type: application/json`
- **凭证**：`credentials: same-origin`（浏览器写入 Cookie）
- **Body**：

```json
{
  "identifierType": "phone",
  "identifier": "+8613xxxxxxxxx",
  "password": "******",
  "phoneCountry": "CN"
}
```

或：

```json
{
  "identifierType": "email",
  "identifier": "user@example.com",
  "password": "******"
}
```

- 手机号前端会归一成 **E.164** 再提交。
- 成功：`Set-Cookie: eason_fans_session=...`，然后跳转 `/welcome` 或 `next`。
- 失败：JSON，`message` / `errors`。

### 3.2 会话

| Cookie | 域 | 属性 |
|---|---|---|
| `eason_fans_session` | `.ecfc.fans` | HttpOnly, Secure, SameSite=Lax |

客户端建议：

1. 使用持久 CookieJar（Dio + cookie_jar / 系统 WebView 登录回写均可）。
2. 每个请求带 Cookie；**无需**额外 `Authorization`（当前未观察到 Bearer）。
3. 启动时 `GET /api/auth/me` 探活；401 则清会话并去登录页。

### 3.3 其它鉴权相关

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/auth/me` | 当前用户摘要 |
| POST | `/api/auth/logout` | 退出 |
| GET | `/api/users/me` | 完整资料（含敏感字段，客户端需谨慎展示） |

`GET /api/auth/me` 成功示例见 `api-samples/api_me.json`：

```json
{
  "user": {
    "id": "cl...",
    "uid": 11572,
    "username": "Paranoid",
    "nickname": "Paranoid",
    "avatarUrl": "https://media.ecfc.fans/...",
    "level": 1,
    "experience": 5,
    "role": "USER",
    "canPlayFullMusic": false
  }
}
```

## 4. 通用约定

- **Base URL**：`https://ecfc.fans`
- **JSON**：请求/响应以 JSON 为主；404 有时返回 HTML（Next 页面），客户端需按 `Content-Type` 与 status 判断。
- **时间**：ISO-8601 UTC 字符串，例如 `2026-08-11T09:09:17.648Z`（展示转本地）。
- **ID**：业务主键多为 CUID/UUID 风格字符串；展示用数字 `uid`。
- **图片**：正文内联标记示例：`[[content-image:https://media.ecfc.fans/media/content/...webp]]`；上传相关：`POST /api/uploads/content-image`（待补全字段）。
- **分页**：
  - 列表常见：`page`、`pageSize`、`hasMore` / `total` / `totalPages`
  - 论坛 feed：`/api/forum/feed?sort=latest&page=1&pageSize=20`
  - 帖内评论：页面 URL query `commentPage`、`commentSort`（`latest`|`hot`）；详情接口一次可带 `replies` 数组（样本约 50 条，完整分页策略待继续抓包确认）

## 5. 核心 API

### 5.1 首页大厅

`GET /api/home`

返回聚合：`posts`、`messages`、`activities`、`concerts`、`tracks`、`albums`、`stats`、`dailyMusic`、`siteStats`、`todayEvents`、`entertainmentRanking` 等。  
样本：`api-samples/api_home.json`。

相关：

- `GET /api/home/entertainment-ranking`
- `GET /api/today` → `{ date, events, canSubmit }`

### 5.2 论坛 Feed（主列表）

`GET /api/forum/feed`

| Query | 说明 |
|---|---|
| `sort` | `latest` / `replies` / `hot` 等 |
| `page` | 从 1 开始 |
| `pageSize` | 如 20 |
| `board` | 分区 slug，如 `daily-chat` |
| `filter` | 如 `featured` |

响应要点：

```json
{
  "boards": [{ "id", "name", "slug", "description", "postCount", "isAnnouncement" }],
  "selectedBoard": null,
  "posts": [ /* PostListItem */ ],
  "total": 2291,
  "totalPages": 115,
  "page": 1,
  "pagination": {},
  "permissions": {}
}
```

样本：`api-samples/forum_feed_sample.json`。

### 5.3 帖子列表（简化）

`GET /api/posts?page=1&pageSize=20&sort=latest`

```json
{ "posts": [ /* ... */ ], "page": 1, "hasMore": true }
```

列表项常见字段：`id, title, content(摘要), likeCount, favoriteCount, replyCount, viewCount, isPinned, isFeatured, createdAt, author, board, stickerUrl, likedByMe?`。  
样本：`api-samples/api_posts_latest.json`。

### 5.4 分区

`GET /api/boards` → `{ boards: [...] }`  
字段含：`id, name, slug, description, coverUrl, sortOrder, postCount, followerCount, isHot, isRecommended, categoryId, parentId`。  
样本：`api-samples/api_boards.json`。

### 5.5 帖子详情

- 页面：`/posts/{postId}`
- `GET /api/posts/{postId}` → `{ post: PostDetail }`
- 进入详情时前端会：`POST /api/posts/{postId}/view`
- 点赞：`POST /api/posts/{postId}/like`（切换语义待确认）
- 收藏：前端有 FavoriteButton（路径待从 chunk 精确确认，可能为 `/api/posts/{id}/favorite`）

`PostDetail` 关键字段：

- 元数据：`id, title, content, summary, contentType, status, moderationStatus, isPinned, isFeatured, isLocked, isDeleted, ...`
- 计数：`viewCount, likeCount, replyCount, favoriteCount, shareCount`
- 关联：`author`, `board`, `media[]`, **`replies[]`**
- 时间：`createdAt, updatedAt, publishedAt`

正文为**纯文本 + 自定义图片标记**，不是 Discourse cooked HTML。

样本：`api-samples/post_detail.json`。

### 5.6 回复

**创建回复**（从详情页 JS）：

`POST /api/posts/{postId}/replies`

```json
{
  "content": "回复文本",
  "parentId": null,
  "imageUrls": [],
  "mentions": [],
  "stickerId": null
}
```

- `parentId`：盖楼时为父回复 id  
- 成功响应含 `success` 与回复对象（以线上为准）

**回复点赞**：

`POST /api/replies/{replyId}/like`

**注意**：`GET /api/posts/{id}/replies` 返回 **405**。当前观测是详情接口内嵌 `replies`；前端用 `commentPage` / `commentSort` 做页面级翻页（RSC/导航），原生客户端若一次 `replies` 不足 `replyCount`，需要继续抓「翻页是否改变 API 响应」或是否有其它分页端点。

`Reply` 字段示例：`id, content, parentId, likeCount, isPinned, author, createdAt, ipRegion, stickerId, moderationStatus, ...`

### 5.7 发帖

- 页面：`/posts/new`
- 上传：`POST /api/uploads/content-image`
- 发帖 `POST` 路径/Body：待补（打开发帖页提交时抓 Network）

### 5.8 签到（每日挂号）

`GET /api/checkin` — 状态与统计，样本 `api-samples/api_checkin.json`。

要点字段：

- `checkedToday`, `todayCheckIn`（points/exp/mood/streakDay/...）
- `currentStreak`, `longestStreak`, `totalCheckIns`
- `points`, `exp`/`experience`, `level`
- `moodStats[]`, `checkinMoodEnabled`

相关：

- `GET /api/points/today`
- `GET /api/checkin/messages?date=YYYY-MM-DD&sort=latest&scope=public|friends&page=1&pageSize=7`
- 执行签到的 `POST /api/checkin` Body（mood/message）待补全（避免重复签到未强行 POST）
  - App 一键挂号：先 `GET` 若未 `checkedToday` 再 `POST`（空 body，失败则再试 `{mood:"calm"}`）

### 5.9 搜索

`GET /api/search?q={keyword}&type=all|posts&page=1`

响应分区：`users`, `posts`, `boards`, `tags`, `albums`, `songs`。  
样本：`api-samples/api_search_all.json`。

### 5.10 通知

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/notifications/unread-summary` | 未读计数拆分 |
| GET | `/api/notifications/popup` | 弹窗 |
| GET | `/api/notifications?page=&pageSize=` | 列表 |
| POST | `/api/notifications/mark-moderation-read` | 进入帖子时前端会调 |

`unread-summary` 字段：`notifications, system, replies, likes, wall, feedbackReplies, feedback, friendRequests, directMessages, messages, total`。

### 5.11 好友 / 私信（二期）

- `GET /api/friends/list?limit=20`
- `POST /api/friends/request` `{ "uid": number }`
- `POST/DELETE` `/api/friends/requests/{id}/...`
- `GET/POST` `/api/friend-groups`
- `GET/POST` `/api/direct-conversations`、`.../messages`、`.../read`、`.../clear`
- `GET /api/friends/mentions?q=`

### 5.12 其它

- `GET /api/stickers/center?mode=picker`
- `POST /api/entertainment/undercover-star/rooms/join`
- 管理：`/api/admin/page-layouts/{key}`（无需在用户端实现）

## 6. 推荐客户端数据模型（Flutter）

```dart
// 示意，非最终代码
class EcfcUser {
  final String id;
  final int uid;
  final String username;
  final String nickname;
  final String? avatarUrl;
  final int level;
  final int experience;
  final String role;
  final bool canPlayFullMusic;
}

class EcfcBoard {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final int postCount;
  final bool? isAnnouncement;
}

class EcfcPost {
  final String id;
  final String title;
  final String? content; // 列表可能是摘要
  final int likeCount;
  final int replyCount;
  final int viewCount;
  final int? favoriteCount;
  final bool isPinned;
  final bool isFeatured;
  final DateTime createdAt;
  final EcfcUser author;
  final EcfcBoard board;
  final bool? likedByMe;
  final List<EcfcReply>? replies; // 详情
  final List<dynamic>? media;
}
```

内容渲染：

1. 按段落拆分 `content`
2. 识别 `[[content-image:URL]]` → 图片组件
3. 链接用 `url_launcher`；站内 `/posts/xxx` deep link 进详情

## 7. MVP 范围（对齐 FluxDO 风格）

目标：**新 Flutter 工程**（不 fork Discourse 专用代码），UI 靠近 FluxDO：Material 3、动态取色、底栏、帖子卡片信息流、详情楼层、下拉刷新。

| 优先级 | 功能 | API |
|---|---|---|
| P0 | 登录 / 会话恢复 / 退出 | auth/* |
| P0 | 底栏：广场、挂号、消息、我的 | — |
| P0 | 广场列表 + 分区/排序 | forum/feed, boards |
| P0 | 帖子详情 + 回复列表 + 发回复 | posts/{id}, posts/{id}/replies |
| P0 | 签到状态展示与签到 | checkin |
| P1 | 搜索 | search |
| P1 | 通知列表与未读角标 | notifications/* |
| P1 | 点赞/收藏 | like/favorite |
| P2 | 发帖 + 图片上传 | posts + uploads |
| P2 | 好友/私信 | friends/*, direct-conversations/* |
| P3 | 音乐/游戏/活动 | 对应模块 |

Android 调试环境对齐：`C:\private\project\stock\StockGrandCouncil\docs\android-emulator.md`  
（JDK `C:\private\project\jdk17`，SDK `C:\private\project\android-sdk`，AVD `jjc_api34`）。

## 8. 网络注意

- **访问 ECFC 不要走本地代理**（用户环境要求）；拉 GitHub/Flutter 依赖可用 `http://127.0.0.1:10808`。
- User-Agent 使用正常移动浏览器 UA 即可；未见 Cloudflare 挑战（与 linux.do 不同）。
- Cookie 域为 `.ecfc.fans`，请求 host 用 `ecfc.fans`。

## 9. 待补清单

- [ ] `POST /api/checkin` 请求体（mood / message）
- [ ] 发帖 `POST` 路径与字段（boardId, title, content, media）
- [ ] `POST /api/uploads/content-image` multipart 字段名
- [ ] 帖内回复分页的确定 API（或确认仅首包 N 条）
- [ ] 收藏/取消收藏精确路径与响应
- [ ] 热门页 `/trending` 对应 API
- [ ] WebSocket `/ws` 是否用于通知
- [ ] 注册、找回密码流程（若 App 需要）

## 10. 本地样本索引

| 文件 | 内容 |
|---|---|
| `api-samples/api_me.json` | 当前用户 |
| `api-samples/api_users_me.json` | 资料（email/phone 已打码） |
| `api-samples/api_home.json` | 首页聚合 |
| `api-samples/api_boards.json` | 分区 |
| `api-samples/forum_feed_sample.json` | 广场 feed |
| `api-samples/api_posts_latest.json` | 帖子列表 |
| `api-samples/post_detail.json` | 详情含 replies |
| `api-samples/api_checkin.json` | 签到状态 |
| `api-samples/api_points_today.json` | 今日积分 |
| `api-samples/notifications_sample.json` | 通知 |
| `api-samples/api_search_all.json` | 搜索 |
| `api-samples/community_dom.json` | 社区页 DOM 摘要 |
| `api-samples/cookies_summary.json` | Cookie 元数据（无值） |

---

**维护约定**：每确认一条新接口，更新本文对应小节，并在 `api-samples/` 追加脱敏 JSON；**禁止**把 `eason_fans_session` 写入仓库。
