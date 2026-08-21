import 'dart:async';
import 'dart:convert';

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/session_cookie_sync.dart';
import 'local_notice_service.dart';
import 'unread_badge_service.dart';

/// 站点实时未读推送（wss://ecfc.fans/ws），失败自动降级回轮询。
///
/// 抓包自官方 Web：登录后前端直连 `/ws`，消息形如
/// `{"type":"unread-summary","summary":{...,"total":N},...}` 与
/// `{"type":"notification-changed",...}`（此时仅触发一次刷新）。
///
/// - 连接用当前会话 Cookie（[SessionCookieSync.cookieHeader]）。
/// - 连续 [_maxWsFailures] 次握手/断链失败后让位给
///   [UnreadBadgeService] 的 90s 轮询，30 分钟后再尝试 WS。
/// - [ingestTotal] 是所有来源（WS、轮询）共用的入口：负责角标、
///   递增时的本地系统通知与去重。
class RealtimeNotificationService {
  RealtimeNotificationService._();
  static final instance = RealtimeNotificationService._();

  static const _wsUrl = 'wss://ecfc.fans/ws';
  static const _maxWsFailures = 3;
  static const _wsRetryAfterDegrade = Duration(minutes: 30);
  static const _backoff = [1, 2, 4, 8, 15, 30];

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _wsSub;
  Timer? _reconnectTimer;
  Timer? _degradeTimer;

  var _started = false;
  var _disposed = false;
  var _wsFailures = 0;
  var _attempt = 0;
  var _degraded = false;

  int _lastTotal = 0;
  int _lastNotifiedTotal = 0;

  final _totalCtrl = StreamController<int>.broadcast();

  /// 每次确认后的未读总数（WS 或轮询）。
  Stream<int> get totals => _totalCtrl.stream;

  int get lastTotal => _lastTotal;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _disposed = false;
    await LocalNoticeService.instance.ensureInit();
    unawaited(LocalNoticeService.instance.requestPermission());
    unawaited(_connectWs());
  }

  /// 统一入口：新未读总数（WS 推送或轮询结果）。
  Future<void> ingestTotal(int total, {String? preview}) async {
    if (total < 0) total = 0;
    final increased = total > _lastTotal;
    _lastTotal = total;
    if (!_totalCtrl.isClosed) _totalCtrl.add(total);

    try {
      if (await AppBadgePlus.isSupported()) {
        await AppBadgePlus.updateBadge(total);
      }
    } catch (e) {
      debugPrint('AppBadgePlus: $e');
    }

    // 只在「变多」且此前没为更高值通知过时弹通知；
    // total 归零后重置阈值，下一次新消息可再通知。
    if (total == 0) {
      _lastNotifiedTotal = 0;
    } else if (increased && total > _lastNotifiedTotal) {
      _lastNotifiedTotal = total;
      await LocalNoticeService.instance.showUnread(total: total, preview: preview);
    }
  }

  Future<void> _connectWs() async {
    if (_disposed) return;
    try {
      final cookie = await SessionCookieSync.cookieHeader();
      if (cookie == null || cookie.isEmpty) {
        // 未登录：不算失败，10s 后再探一次（等 WebView 落 Cookie）。
        _scheduleReconnect(const Duration(seconds: 10));
        return;
      }

      final channel = IOWebSocketChannel.connect(
        Uri.parse(_wsUrl),
        headers: {'Cookie': cookie},
        pingInterval: const Duration(seconds: 25),
      );
      _channel = channel;

      await channel.ready;
      _wsFailures = 0;
      _attempt = 0;

      _wsSub = channel.stream.listen(
        _onWsMessage,
        onError: (_) => _onWsGone(),
        onDone: _onWsGone,
        cancelOnError: true,
      );

      // 连上后立刻要一次真实值（有的端只在变化时推送）
      unawaited(UnreadBadgeService.instance.refresh());
    } catch (e) {
      debugPrint('RealtimeNotificationService ws: $e');
      _onWsGone();
    }
  }

  void _onWsMessage(dynamic raw) {
    try {
      final text = raw is String ? raw : utf8.decode(raw as List<int>);
      final json = jsonDecode(text);
      if (json is! Map<String, dynamic>) return;
      final type = json['type'];
      if (type == 'unread-summary') {
        final summary = json['summary'];
        if (summary is Map) {
          final t = summary['total'];
          final total = t is num ? t.toInt() : int.tryParse('$t');
          if (total != null) unawaited(ingestTotal(total));
        }
      } else if (type == 'notification-changed') {
        // 变化事件不直接带总数，回拉一次 HTTP 摘要
        unawaited(UnreadBadgeService.instance.refresh());
      }
    } catch (e) {
      debugPrint('RealtimeNotificationService msg: $e');
    }
  }

  void _onWsGone() {
    if (_disposed) return;
    _wsSub?.cancel();
    _wsSub = null;
    _channel = null;
    _wsFailures++;

    if (_wsFailures >= _maxWsFailures) {
      _degraded = true;
      debugPrint('RealtimeNotificationService: WS 不稳定，降级为轮询');
      _degradeTimer?.cancel();
      _degradeTimer = Timer(_wsRetryAfterDegrade, () {
        _degraded = false;
        _wsFailures = 0;
        unawaited(_connectWs());
      });
      return; // 轮询由 UnreadBadgeService 常驻兜底
    }
    final secs = _backoff[_attempt.clamp(0, _backoff.length - 1)];
    _attempt++;
    _scheduleReconnect(Duration(seconds: secs));
  }

  void _scheduleReconnect(Duration delay) {
    if (_disposed || _degraded) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () => unawaited(_connectWs()));
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _degradeTimer?.cancel();
    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    await _totalCtrl.close();
  }
}
