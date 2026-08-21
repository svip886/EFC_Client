import 'dart:async';

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/widgets.dart';

import '../core/network/api_client.dart';
import '../core/session_cookie_sync.dart';
import 'realtime_notification_service.dart';

/// 轮询未读摘要并更新桌面角标。
///
/// 依赖 [SessionCookieSync] 把 Web 登录态灌进 Dio。
/// 未登录 / 401 / 无角标能力时静默跳过。
class UnreadBadgeService with WidgetsBindingObserver {
  UnreadBadgeService._();
  static final instance = UnreadBadgeService._();

  static const _interval = Duration(seconds: 90);
  Timer? _timer;
  var _started = false;
  var _tickInFlight = false;
  int _lastTotal = 0;

  int get lastTotal => _lastTotal;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_interval, (_) => unawaited(refresh()));
    // 延后首轮，等 WebView 登录页有机会落 Cookie
    Future<void>.delayed(const Duration(seconds: 4), refresh);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refresh());
    }
  }

  Future<void> refresh() async {
    if (_tickInFlight) return;
    _tickInFlight = true;
    try {
      final hasSession = await SessionCookieSync.syncFromWebView();
      if (!hasSession) {
        await _setBadge(0);
        return;
      }

      final client = await ApiClient.ensureInitialized();
      final resp = await client.getSoft('/api/notifications/unread-summary');
      final status = resp.statusCode ?? 0;
      if (status == 401 || status == 403) {
        await _setBadge(0);
        return;
      }
      if (status < 200 || status >= 300) return;

      final data = resp.data;
      var total = 0;
      if (data is Map) {
        final t = data['total'];
        if (t is int) {
          total = t;
        } else if (t is num) {
          total = t.toInt();
        } else if (t is String) {
          total = int.tryParse(t) ?? 0;
        }
      }
      await RealtimeNotificationService.instance.ingestTotal(total);
      _lastTotal = total < 0 ? 0 : total;
    } catch (e) {
      debugPrint('UnreadBadgeService: $e');
    } finally {
      _tickInFlight = false;
    }
  }

  Future<void> _setBadge(int total) async {
    _lastTotal = total;
    try {
      final supported = await AppBadgePlus.isSupported();
      if (!supported) return;
      if (total <= 0) {
        await AppBadgePlus.updateBadge(0);
      } else {
        await AppBadgePlus.updateBadge(total);
      }
    } catch (e) {
      debugPrint('AppBadgePlus: $e');
    }
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    _started = false;
  }
}
