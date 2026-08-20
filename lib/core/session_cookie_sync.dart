import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'constants.dart';
import 'network/api_client.dart';

/// 把 WebView 里的会话 Cookie 写进 Dio [PersistCookieJar]。
///
/// 主壳登录发生在 WebView；原生 API（未读、挂号等）要同一份
/// `eason_fans_session` 才能工作。页面加载完成后调用 [syncFromWebView]。
class SessionCookieSync {
  SessionCookieSync._();

  static final _webCookies = WebViewCookieManager();
  static String? _lastSessionValue;

  /// 从 WebView Cookie 管理器读取并写入 Dio。
  ///
  /// 返回是否持有会话 Cookie（不保证仍有效，需接口探活）。
  static Future<bool> syncFromWebView() async {
    try {
      final raw = await _webCookies.getCookies(
        domain: Uri.parse(AppConstants.baseUrl),
      );
      if (raw.isEmpty) {
        if (_lastSessionValue != null) {
          final client = await ApiClient.ensureInitialized();
          await client.clearCookies();
          _lastSessionValue = null;
        }
        return false;
      }

      final cookies = <Cookie>[];
      String? session;
      for (final w in raw) {
        final name = w.name.trim();
        final value = w.value;
        if (name.isEmpty) continue;
        final c = Cookie(name, value)
          ..domain = _normalizeDomain(w.domain)
          ..path = w.path.isEmpty ? '/' : w.path
          ..secure = true
          ..httpOnly = name == AppConstants.sessionCookieName;
        cookies.add(c);
        if (name == AppConstants.sessionCookieName && value.isNotEmpty) {
          session = value;
        }
      }

      final client = await ApiClient.ensureInitialized();
      await client.importCookies(cookies);
      _lastSessionValue = session;
      return session != null;
    } catch (e, st) {
      debugPrint('SessionCookieSync: $e\n$st');
      return false;
    }
  }

  /// Android CookieManager 有时把 domain 填成完整 URL，统一成 `.ecfc.fans`。
  static String _normalizeDomain(String domain) {
    var d = domain.trim();
    if (d.startsWith('http://') || d.startsWith('https://')) {
      final host = Uri.tryParse(d)?.host;
      if (host != null && host.isNotEmpty) d = host;
    }
    if (d.contains('ecfc.fans')) {
      return '.ecfc.fans';
    }
    if (d.isEmpty) return '.ecfc.fans';
    return d.startsWith('.') ? d : '.$d';
  }
}
