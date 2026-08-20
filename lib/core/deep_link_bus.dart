import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'constants.dart';

/// 冷启动 / 热启动 Deep Link 总线。
///
/// Android Intent（https / ecfc://）与 App Shortcuts 都汇到这里，
/// [WebShellPage] 订阅后 `loadRequest`。
class DeepLinkBus {
  DeepLinkBus._();

  static final _controller = StreamController<Uri>.broadcast();
  static final _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;
  static Uri? _initial;
  static var _started = false;

  static Stream<Uri> get stream => _controller.stream;

  /// 冷启动时拿到的首条链接（可能为 null）。
  static Uri? get initialUri => _initial;

  static Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      final raw = await _appLinks.getInitialLink();
      _initial = AppConstants.normalizeLaunchUri(raw);
      if (_initial != null) {
        _controller.add(_initial!);
      }
    } catch (e) {
      debugPrint('DeepLinkBus initial: $e');
    }

    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        final n = AppConstants.normalizeLaunchUri(uri);
        if (n != null) _controller.add(n);
      },
      onError: (Object e) => debugPrint('DeepLinkBus stream: $e'),
    );
  }

  /// 测试或内部跳转也可手动推一条。
  static void emit(Uri uri) {
    final n = AppConstants.normalizeLaunchUri(uri) ?? uri;
    _controller.add(n);
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
