import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'constants.dart';
import 'deep_link_bus.dart';

/// Android `ACTION_SEND`（text/plain）接入。
///
/// 冷启动用 [getInitialShare]，热启动由原生 `onShare` 回调推送。
/// 解析结果统一进 [DeepLinkBus]。
class ShareIntent {
  ShareIntent._();

  static const _channel = MethodChannel('fans.ecfc.app/share');
  static var _started = false;

  static Future<void> start() async {
    if (_started) return;
    _started = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShare') {
        final text = call.arguments is String ? call.arguments as String : null;
        _emit(text);
      }
    });

    try {
      final initial = await _channel.invokeMethod<String>('getInitialShare');
      _emit(initial);
    } catch (e) {
      debugPrint('ShareIntent initial: $e');
    }
  }

  static void _emit(String? text) {
    final uri = AppConstants.resolveSharedContent(text);
    if (uri != null) {
      DeepLinkBus.emit(uri);
    }
  }
}
