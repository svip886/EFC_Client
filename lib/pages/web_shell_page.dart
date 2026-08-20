import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../core/constants.dart';
import '../core/deep_link_bus.dart';
import '../core/session_cookie_sync.dart';
import '../services/checkin_quick_action.dart';
import '../services/unread_badge_service.dart';

/// 私家E院主壳：全屏 WebView 承载官方响应式站点。
///
/// - 系统返回键优先 Web 历史
/// - Deep Link / Shortcuts / 一键挂号经 [DeepLinkBus] 导航
class WebShellPage extends StatefulWidget {
  const WebShellPage({super.key, this.initialUrl});

  final Uri? initialUrl;

  @override
  State<WebShellPage> createState() => _WebShellPageState();
}

class _WebShellPageState extends State<WebShellPage> {
  late final WebViewController _controller;
  StreamSubscription<Uri>? _linkSub;
  var _loading = true;
  var _progress = 0;
  var _checkinBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFAFAFA))
      // 关闭边界 overscroll，避免顶/底回弹带动站点 fixed 导航栏一起晃。
      ..setOverScrollMode(WebViewOverScrollMode.never)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _progress = p);
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _progress = 100;
            });
            unawaited(_injectOverscrollCss());
            // 登录/跳转后把会话灌进 Dio，并刷新角标 / 挂号小组件
            unawaited(() async {
              await SessionCookieSync.syncFromWebView();
              await UnreadBadgeService.instance.refresh();
              await CheckinQuickAction.refreshWidgetOnly();
            }());
          },
          onWebResourceError: (err) {
            if (err.isForMainFrame == true && mounted) {
              setState(() {
                _loading = false;
                _error = err.description.isNotEmpty
                    ? err.description
                    : '页面加载失败';
              });
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (AppConstants.isAppAction(uri)) {
              unawaited(_handleAppAction(uri));
              return NavigationDecision.prevent;
            }
            if (_shouldOpenExternally(uri)) {
              unawaited(_openExternal(uri));
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    unawaited(_configureAndroid());

    final start = widget.initialUrl ??
        DeepLinkBus.initialUri ??
        AppConstants.homeUri;

    if (AppConstants.isAppAction(start)) {
      // 冷启动就是一键挂号：先打开挂号页，再跑 API
      unawaited(_controller.loadRequest(AppConstants.uriForPath(AppConstants.checkinPath)));
      unawaited(_handleAppAction(start));
    } else {
      unawaited(_controller.loadRequest(start));
    }

    _linkSub = DeepLinkBus.stream.listen((uri) {
      if (!mounted) return;
      // 跳过与冷启动重复的那条（非 App Action）
      if (!AppConstants.isAppAction(uri) &&
          uri == DeepLinkBus.initialUri &&
          uri == start &&
          widget.initialUrl == null) {
        return;
      }
      unawaited(_navigateTo(uri));
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _configureAndroid() async {
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      await AndroidWebViewController.enableDebugging(false);
      await platform.setMediaPlaybackRequiresUserGesture(false);
      final cookieManager = AndroidWebViewCookieManager(
        const PlatformWebViewCookieManagerCreationParams(),
      );
      await cookieManager.setAcceptThirdPartyCookies(platform, true);
    }
  }

  /// Chromium 弹性 overscroll 兜底：即使原生 View 已 never，部分版本仍会拉伸 DOM。
  Future<void> _injectOverscrollCss() async {
    try {
      await _controller.runJavaScript('''
(function () {
  if (document.getElementById('ecfc-overscroll-fix')) return;
  var s = document.createElement('style');
  s.id = 'ecfc-overscroll-fix';
  s.textContent = 'html, body { overscroll-behavior: none; overscroll-behavior-y: none; }';
  var root = document.head || document.documentElement || document.body;
  if (root) root.appendChild(s);
})();
''');
    } catch (_) {
      // 页面卸载中注入失败可忽略
    }
  }

  bool _shouldOpenExternally(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'mailto' || scheme == 'tel' || scheme == 'sms') {
      return true;
    }
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
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开链接：${uri.toString()}')),
        );
      }
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
      _progress = 0;
    });
    await _controller.loadRequest(uri);
  }

  Future<void> _handleAppAction(Uri uri) async {
    if (uri.path == AppConstants.appActionCheckin ||
        uri.path.startsWith('${AppConstants.appActionCheckin}/')) {
      await _runQuickCheckin();
      return;
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
          await _controller.loadRequest(
            AppConstants.uriForPath(
              '/login?next=${Uri.encodeComponent(AppConstants.checkinPath)}',
            ),
          );
        case CheckinQuickKind.already:
        case CheckinQuickKind.success:
        case CheckinQuickKind.failed:
          await _controller.loadRequest(
            AppConstants.uriForPath(AppConstants.checkinPath),
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
      _progress = 0;
    });
    await _controller.reload();
  }

  Future<void> _goHome() async {
    await _navigateTo(AppConstants.homeUri);
  }

  Future<bool> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldLeave = await _handleBack();
        if (shouldLeave && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_loading || _progress < 100)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _progress > 0 && _progress < 100
                        ? _progress / 100
                        : null,
                    minHeight: 2,
                  ),
                ),
              if (_checkinBusy)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('正在挂号…'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (_error != null)
                _ErrorOverlay(
                  message: _error!,
                  onRetry: () => unawaited(_reload()),
                  onHome: () => unawaited(_goHome()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({
    required this.message,
    required this.onRetry,
    required this.onHome,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 12),
              Text(
                '加载失败',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                children: [
                  FilledButton(onPressed: onRetry, child: const Text('重试')),
                  OutlinedButton(onPressed: onHome, child: const Text('回首页')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
