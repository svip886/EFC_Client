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

  /// 快捷入口路径。
  static const String forumPath = '/forum';
  static const String checkinPath = '/checkin';
  static const String notificationsPath = '/notifications';

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
}
