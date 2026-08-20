/// 全局常量：与 docs/ECFC_API.md 保持一致，改动前先更新文档。
class AppConstants {
  AppConstants._();

  /// ECFC 站点根地址。业务请求一律直连，不走系统代理。
  static const String baseUrl = 'https://ecfc.fans';

  /// App 启动默认落地页（站点自身负责未登录跳转 /login）。
  static const String homePath = '/community';

  /// 媒体 CDN（图片等静态资源）。
  static const String mediaUrl = 'https://media.ecfc.fans';

  /// 自定义 scheme（Shortcuts / 调试 Deep Link）。
  static const String appScheme = 'ecfc';

  /// 会话 Cookie 名称（HttpOnly；WebView 自动托管）。
  static const String sessionCookieName = 'eason_fans_session';

  static const String appName = '私家E院';

  /// 客户端版权（非站点版权）。
  static const String appCopyright = 'Paranoid';
  static const String appCopyrightLine = '© Paranoid';

  /// GitHub 发布仓库（检查更新 / Release 下载）。
  /// 若 fork 或改名，只改这两处即可。
  static const String githubOwner = 'svip886';
  static const String githubRepo = 'EFC_Client';

  static String get githubRepoUrl =>
      'https://github.com/$githubOwner/$githubRepo';

  static String get githubReleasesUrl => '$githubRepoUrl/releases';

  /// 版本清单优先顺序见 [AppVersionService]：
  /// 1) Release 资产 version.json
  /// 2) 仓库 raw app/version.json
  /// 3) GitHub API latest release
  static String get appVersionManifestUrl =>
      'https://github.com/$githubOwner/$githubRepo/releases/latest/download/version.json';

  static String get appVersionManifestRawUrl =>
      'https://raw.githubusercontent.com/$githubOwner/$githubRepo/master/app/version.json';

  static String get githubLatestReleaseApiUrl =>
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

  /// 快捷入口路径。
  static const String forumPath = '/forum';
  static const String checkinPath = '/checkin';
  static const String notificationsPath = '/notifications';

  /// App 内部动作前缀（不交给 WebView 加载）。
  /// 例：`/__app/checkin` = 一键挂号 API。
  static const String appActionPrefix = '/__app';
  static const String appActionCheckin = '/__app/checkin';
  static const String appActionSettings = '/__app/settings';

  /// 允许在 WebView 内打开的主机（含子域）。
  static bool isAllowedHost(String? host) {
    if (host == null || host.isEmpty) return false;
    final h = host.toLowerCase();
    return h == 'ecfc.fans' ||
        h.endsWith('.ecfc.fans') ||
        h == 'media.ecfc.fans';
  }

  static Uri get homeUri => Uri.parse('$baseUrl$homePath');

  static Uri uriForPath(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$p');
  }

  /// 将 Deep Link / Shortcut Intent 规范为可在 WebView 打开的 https URL。
  ///
  /// 支持：
  /// - `https://ecfc.fans/...`、`http://ecfc.fans/...`
  /// - `ecfc://forum` → `https://ecfc.fans/forum`
  /// - `ecfc:///checkin` → `https://ecfc.fans/checkin`
  /// - `ecfc://action/settings` → `/__app/settings`（原生 App 设置）
  static Uri? normalizeLaunchUri(Uri? uri) {
    if (uri == null) return null;

    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https') {
      if (!isAllowedHost(uri.host)) return null;
      // 统一 https
      return uri.replace(scheme: 'https');
    }

    if (scheme == appScheme) {
      // ecfc://forum/extra → /forum/extra
      // ecfc:///path → /path
      // ecfc://action/checkin → /__app/checkin（一键挂号）
      final buf = StringBuffer();
      if (uri.host.isNotEmpty) {
        buf.write('/${uri.host}');
      }
      if (uri.path.isNotEmpty && uri.path != '/') {
        if (!uri.path.startsWith('/')) buf.write('/');
        buf.write(uri.path);
      }
      var path = buf.toString();
      if (path.isEmpty || path == '/') path = homePath;

      // 别名：一键挂号 / App 设置
      if (path == '/action/checkin' ||
          path == '/checkin/do' ||
          path == '/checkin/quick') {
        path = appActionCheckin;
      }
      if (path == '/action/settings' ||
          path == '/app/settings' ||
          path == '/settings/app') {
        path = appActionSettings;
      }

      return Uri(
        scheme: 'https',
        host: 'ecfc.fans',
        path: path,
        query: uri.hasQuery ? uri.query : null,
        fragment: uri.fragment.isEmpty ? null : uri.fragment,
      );
    }

    return null;
  }

  /// 是否为 App 内部动作 URL（由壳处理，不 loadRequest）。
  static bool isAppAction(Uri uri) {
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        !isAllowedHost(uri.host)) {
      return false;
    }
    return uri.path == appActionCheckin ||
        uri.path.startsWith('$appActionPrefix/');
  }

  /// 解析系统分享进来的纯文本 / 链接。
  ///
  /// - 文中含 `ecfc.fans` / `ecfc://` 链接 → 打开对应页
  /// - 否则 → `/search?q=...`（截断过长文本）
  static Uri? resolveSharedContent(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;

    // 先尝试整段就是 URI
    final asUri = Uri.tryParse(text);
    if (asUri != null && asUri.hasScheme) {
      final n = normalizeLaunchUri(asUri);
      if (n != null) return n;
    }

    // 从正文里抠 http(s) / ecfc 链接（分享时常夹带标题）
    final urlRe = RegExp(
      r'(?:https?://|ecfc://)[^\s<>"{}|\\^`\[\]）】]+',
      caseSensitive: false,
    );
    for (final m in urlRe.allMatches(text)) {
      var candidate = m.group(0)!;
      // 去掉中文标点尾巴
      candidate = candidate.replaceAll(RegExp(r'[，。；、！？,.!?;:]+$'), '');
      final uri = Uri.tryParse(candidate);
      final n = normalizeLaunchUri(uri);
      if (n != null) return n;
    }

    final q = text.length > 200 ? text.substring(0, 200) : text;
    return Uri.https('ecfc.fans', '/search', {'q': q});
  }
}
