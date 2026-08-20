import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'constants.dart';

/// 冷启动 / 热启动 Deep Link 总线。
///
/// Android Intent（https / ecfc://）、App Shortcuts、系统分享都汇到这里，
/// [WebShellPage] 订阅后 `loadRequest`。
///
/// 在首个监听者挂上之前 [emit] 的目标会写入 [initialUri]，避免广播流丢事件。
class DeepLinkBus {
  DeepLinkBus._();

  static final _controller = StreamController<Uri>.broadcast();
  static final _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;
  static Uri? _initial;
  static var _started = false;
  static var _listenerCount = 0;

  static Stream<Uri> get stream {
    late StreamController<Uri> wrapper;
    wrapper = StreamController<Uri>.broadcast(
      onListen: () {
        _listenerCount++;
        final sub = _controller.stream.listen(
          wrapper.add,
          onError: wrapper.addError,
          onDone: wrapper.close,
        );
        wrapper.onCancel = () async {
          _listenerCount = (_listenerCount - 1).clamp(0, 1 << 30);
          await sub.cancel();
        };
      },
    );
    return wrapper.stream;
  }

  /// 冷启动时拿到的首条链接（可能为 null）。
  static Uri? get initialUri => _initial;

  static Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      final raw = await _appLinks.getInitialLink();
      final n = AppConstants.normalizeLaunchUri(raw);
      if (n != null) {
        _initial ??= n;
        _controller.add(n);
      }
    } catch (e) {
      debugPrint('DeepLinkBus initial: $e');
    }

    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        final n = AppConstants.normalizeLaunchUri(uri);
        if (n != null) _push(n);
      },
      onError: (Object e) => debugPrint('DeepLinkBus stream: $e'),
    );
  }

  /// 测试或内部跳转 / 系统分享也可手动推一条。
  static void emit(Uri uri) {
    final target = AppConstants.normalizeLaunchUri(uri) ??
        (uri.scheme == 'https' && AppConstants.isAllowedHost(uri.host)
            ? uri
            : null);
    if (target == null) return;
    _push(target);
  }

  static void _push(Uri uri) {
    if (_listenerCount == 0) {
      _initial = uri;
    }
    _controller.add(uri);
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
