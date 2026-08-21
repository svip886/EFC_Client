import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';

import '../core/constants.dart';
import '../core/deep_link_bus.dart';
import '../services/checkin_quick_action.dart';
import 'app_settings_page.dart';

/// Windows 主壳：WebView2（webview_windows）。
///
/// `webview_flutter` 不支持 Windows，桌面必须用这套实现，否则只会看到灰屏。
class WindowsWebShellPage extends StatefulWidget {
  const WindowsWebShellPage({super.key, this.initialUrl});

  final Uri? initialUrl;

  @override
  State<WindowsWebShellPage> createState() => _WindowsWebShellPageState();
}

class _WindowsWebShellPageState extends State<WindowsWebShellPage> {
  final _controller = WebviewController();
  final _subs = <StreamSubscription>[];
  StreamSubscription<Uri>? _linkSub;

  var _ready = false;
  var _loading = true;
  var _checkinBusy = false;
  String? _error;
  String? _runtimeMissing;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final ver = await WebviewController.getWebViewVersion();
      if (ver == null || ver.isEmpty) {
        if (!mounted) return;
        setState(() {
          _runtimeMissing =
              '未检测到 Microsoft Edge WebView2 运行时，无法显示网页。\n请安装后重启应用。';
          _loading = false;
        });
        return;
      }

      await _controller.initialize();
      await _controller.setBackgroundColor(const Color(0xFFFAFAFA));
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

      // 尽量贴近移动端视口，站点本身有响应式
      try {
        await _controller.setUserAgent(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 EcfcApp/Windows',
        );
      } catch (_) {}

      _subs.add(_controller.loadingState.listen((state) {
        if (!mounted) return;
        if (state == LoadingState.loading) {
          setState(() {
            _loading = true;
            _error = null;
          });
        } else if (state == LoadingState.navigationCompleted) {
          setState(() {
            _loading = false;
          });
          unawaited(_injectShellScripts());
        }
      }));

      _subs.add(_controller.onLoadError.listen((status) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = '页面加载失败（$status）';
        });
      }));

      // 拦截将要导航的 URL（含新窗口/外链尽量在 load 前处理）
      _subs.add(_controller.url.listen((url) {
        final uri = Uri.tryParse(url);
        if (uri == null) return;
        if (AppConstants.isAppAction(uri)) {
          unawaited(_handleAppAction(uri));
          // 不再硬 loadUrl(homeUri)：与即将 push 的设置页抢占 WebView2
          // 渲染线程会导致 Windows 崩溃。改由设置页返回后统一 resume。
          return;
        }
        if (_shouldOpenExternally(uri)) {
          unawaited(_openExternal(uri));
        }
      }));

      final start = widget.initialUrl ??
          DeepLinkBus.initialUri ??
          AppConstants.homeUri;

      if (AppConstants.isAppAction(start)) {
        await _controller.loadUrl(
          AppConstants.uriForPath(AppConstants.checkinPath).toString(),
        );
        unawaited(_handleAppAction(start));
      } else {
        await _controller.loadUrl(start.toString());
      }

      _linkSub = DeepLinkBus.stream.listen((uri) {
        if (!mounted) return;
        if (!AppConstants.isAppAction(uri) &&
            uri == DeepLinkBus.initialUri &&
            uri == start &&
            widget.initialUrl == null) {
          return;
        }
        unawaited(_navigateTo(uri));
      });

      if (!mounted) return;
      setState(() => _ready = true);
    } on PlatformException catch (e) {
      debugPrint('Windows WebView init failed: $e');
      if (!mounted) return;
      setState(() {
        _error = e.message ?? e.code;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Windows WebView init failed: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _linkSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _injectShellScripts() async {
    try {
      await _controller.executeScript(_shellInjectJs);
    } catch (_) {}
  }

  // 与 Android 壳同一套菜单注入
  static const _shellInjectJs = r'''
(function () {
  if (window.__ecfcShellInjected) {
    try { window.__ecfcInjectAvatarMenu && window.__ecfcInjectAvatarMenu(); } catch (e) {}
    return;
  }
  window.__ecfcShellInjected = true;
  try {
    if (!document.getElementById('ecfc-overscroll-fix')) {
      var s = document.createElement('style');
      s.id = 'ecfc-overscroll-fix';
      s.textContent = 'html, body { overscroll-behavior: none; overscroll-behavior-y: none; }'
        + ' #ecfc-app-settings-item, .ecfc-app-settings-item {'
        + '  display:flex; align-items:center; width:100%; box-sizing:border-box;'
        + '  padding:8px 12px; margin:0; border:0; background:transparent; cursor:pointer;'
        + '  font: inherit; color: inherit; text-align:left; text-decoration:none;'
        + ' }';
      var root = document.head || document.documentElement || document.body;
      if (root) root.appendChild(s);
    }
  } catch (e) {}
  function openAppSettings(ev) {
    try { if (ev) { ev.preventDefault(); ev.stopPropagation(); } } catch (e) {}
    try { window.location.href = 'https://ecfc.fans/__app/settings'; } catch (e) {}
    return false;
  }
  function textOf(el) {
    return (el && (el.innerText || el.textContent) || '').replace(/\s+/g, ' ').trim();
  }
  function looksLikeAvatarMenu(node) {
    if (!node || node.nodeType !== 1) return false;
    if (node.id === 'ecfc-app-settings-item') return false;
    var t = textOf(node);
    if (t.length > 80) return false;
    var hits = 0;
    if (t.indexOf('个人病历') >= 0) hits++;
    if (t.indexOf('消息中心') >= 0) hits++;
    if (t.indexOf('账号安全') >= 0) hits++;
    if (t.indexOf('退出登录') >= 0 || t.indexOf('退出') >= 0) hits++;
    return hits >= 2;
  }
  function findMenuRoot() {
    var candidates = document.querySelectorAll(
      '[role="menu"], [data-radix-menu-content], [data-radix-dropdown-menu-content],'
      + '[data-state="open"], div[class*="Dropdown"], div[class*="dropdown"],'
      + 'div[class*="Popover"], div[class*="popover"], div[class*="Menu"]'
    );
    for (var i = 0; i < candidates.length; i++) {
      if (looksLikeAvatarMenu(candidates[i])) return candidates[i];
    }
    var all = document.querySelectorAll('div, ul, nav, section');
    var best = null, bestScore = 0;
    for (var j = 0; j < all.length; j++) {
      var el = all[j];
      if (!looksLikeAvatarMenu(el)) continue;
      var r = el.getBoundingClientRect();
      if (r.width < 80 || r.width > 420 || r.height < 40 || r.height > 480) continue;
      var score = (textOf(el).indexOf('退出登录') >= 0 ? 3 : 0) + 1;
      if (score > bestScore) { bestScore = score; best = el; }
    }
    return best;
  }
  function findLogoutRow(menu) {
    var nodes = menu.querySelectorAll('a, button, div, span, li, [role="menuitem"]');
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i];
      var t = textOf(n);
      if (t === '退出登录' || t === '退出' || t.indexOf('退出登录') === 0) {
        return n.closest('[role="menuitem"]') || n.closest('a') || n.closest('button') || n;
      }
    }
    return null;
  }
  function cloneRowStyle(from, to) {
    try {
      var cs = window.getComputedStyle(from);
      to.style.display = cs.display || 'flex';
      to.style.alignItems = cs.alignItems || 'center';
      to.style.width = '100%';
      to.style.boxSizing = 'border-box';
      to.style.padding = cs.padding;
      to.style.margin = cs.margin;
      to.style.fontSize = cs.fontSize;
      to.style.fontWeight = cs.fontWeight;
      to.style.lineHeight = cs.lineHeight;
      to.style.color = cs.color;
      to.style.background = 'transparent';
      to.style.border = 'none';
      to.style.cursor = 'pointer';
      to.style.textAlign = 'left';
      if (from.className) to.className = from.className;
    } catch (e) {}
  }
  function injectAvatarMenu() {
    try {
      if (document.getElementById('ecfc-app-settings-item')) return true;
      var menu = findMenuRoot();
      if (!menu) return false;
      var logout = findLogoutRow(menu);
      var item = document.createElement(logout && logout.tagName === 'A' ? 'a' : 'button');
      item.id = 'ecfc-app-settings-item';
      item.className = 'ecfc-app-settings-item';
      item.setAttribute('role', 'menuitem');
      item.setAttribute('type', 'button');
      item.textContent = 'App 设置';
      if (item.tagName === 'A') item.setAttribute('href', 'https://ecfc.fans/__app/settings');
      if (logout) cloneRowStyle(logout, item);
      item.addEventListener('click', openAppSettings, true);
      if (logout && logout.parentNode) logout.parentNode.insertBefore(item, logout);
      else menu.appendChild(item);
      return true;
    } catch (e) { return false; }
  }
  window.__ecfcInjectAvatarMenu = injectAvatarMenu;
  var scheduled = null;
  function schedule() {
    if (scheduled) return;
    scheduled = setTimeout(function () { scheduled = null; injectAvatarMenu(); }, 50);
  }
  try {
    new MutationObserver(schedule).observe(document.documentElement || document.body, { childList: true, subtree: true });
  } catch (e) {}
  document.addEventListener('click', function () {
    setTimeout(injectAvatarMenu, 0);
    setTimeout(injectAvatarMenu, 80);
    setTimeout(injectAvatarMenu, 200);
  }, true);
  injectAvatarMenu();
})();
''';

  bool _shouldOpenExternally(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'mailto' || scheme == 'tel' || scheme == 'sms') return true;
    if (scheme == 'http' || scheme == 'https') {
      return !AppConstants.isAllowedHost(uri.host);
    }
    return scheme.isNotEmpty &&
        scheme != 'about' &&
        scheme != 'data' &&
        scheme != 'blob';
  }

  Future<void> _openExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开外部链接')),
      );
    }
  }

  Future<void> _navigateTo(Uri uri) async {
    if (AppConstants.isAppAction(uri)) {
      await _handleAppAction(uri);
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    await _controller.loadUrl(uri.toString());
  }

  Future<void> _handleAppAction(Uri uri) async {
    if (uri.path == AppConstants.appActionCheckin ||
        uri.path.startsWith('${AppConstants.appActionCheckin}/')) {
      await _runQuickCheckin();
      return;
    }
    if (uri.path == AppConstants.appActionSettings ||
        uri.path.startsWith('${AppConstants.appActionSettings}/')) {
      await _openAppSettings();
    }
  }

  Future<void> _openAppSettings() async {
    if (!mounted) return;
    // WebView2 与同进程的 Material 页面叠加时，swapping surface 上去
    // 会闪退。先 suspend 让出渲染，返回后 resume。
    var suspended = false;
    try {
      await _controller.suspend();
      suspended = true;
    } catch (e) {
      debugPrint('webview suspend: $e');
    }
    try {
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const AppSettingsPage()),
      );
    } finally {
      if (suspended) {
        try {
          await _controller.resume();
        } catch (e) {
          debugPrint('webview resume: $e');
          // resume 失败时尝试重新加载首页兜底
          if (mounted) {
            unawaited(_controller.loadUrl(AppConstants.homeUri.toString()));
          }
        }
      }
    }
  }

  Future<void> _runQuickCheckin() async {
    if (_checkinBusy) return;
    setState(() => _checkinBusy = true);
    try {
      final result = await CheckinQuickAction.run();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.snackbarText),
          behavior: SnackBarBehavior.floating,
        ),
      );
      switch (result.kind) {
        case CheckinQuickKind.needLogin:
          await _controller.loadUrl(
            AppConstants.uriForPath(
              '/login?next=${Uri.encodeComponent(AppConstants.checkinPath)}',
            ).toString(),
          );
        case CheckinQuickKind.already:
        case CheckinQuickKind.success:
        case CheckinQuickKind.failed:
          await _controller.loadUrl(
            AppConstants.uriForPath(AppConstants.checkinPath).toString(),
          );
      }
    } finally {
      if (mounted) setState(() => _checkinBusy = false);
    }
  }

  Future<void> _reload() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    await _controller.reload();
  }

  Future<void> _goHome() async {
    await _navigateTo(AppConstants.homeUri);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_runtimeMissing != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.web_asset_off, size: 48),
                const SizedBox(height: 12),
                Text(_runtimeMissing!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => launchUrl(
                    Uri.parse(
                      'https://developer.microsoft.com/microsoft-edge/webview2/',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('下载 WebView2 Runtime'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          if (_ready)
            Webview(
              _controller,
              permissionRequested: (url, kind, _) async {
                // 默认拒绝敏感权限，站点一般不需要
                return WebviewPermissionDecision.deny;
              },
            )
          else
            const Center(child: CircularProgressIndicator()),
          if (_loading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_checkinBusy)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text('正在挂号…'),
                  ),
                ),
              ),
            ),
          if (_error != null)
            ColoredBox(
              color: theme.colorScheme.surface,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off, size: 48),
                      const SizedBox(height: 12),
                      const Text('加载失败'),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        children: [
                          FilledButton(
                            onPressed: () => unawaited(_reload()),
                            child: const Text('重试'),
                          ),
                          OutlinedButton(
                            onPressed: () => unawaited(_goHome()),
                            child: const Text('回首页'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 是否在 Windows 桌面使用专用 WebView 实现。
bool get useWindowsWebView =>
    !kIsWeb && Platform.isWindows;
