import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/deep_link_bus.dart';

/// 系统本地通知封装（Android/iOS/macOS/Windows/Linux）。
///
/// - Android：渠道 `ecfc_notifications`，Android 13+ 运行时权限由
///   [requestPermission] 申请。
/// - 点击通知时把 payload（一个 `ecfc://` 或 https 链接）交给
///   [DeepLinkBus] 路由回 Web 壳。
class LocalNoticeService {
  LocalNoticeService._();
  static final LocalNoticeService instance = LocalNoticeService._();

  static const _channelId = 'ecfc_notifications';
  static const _channelName = '消息通知';
  static const _channelDesc = '私家E院未读消息提醒';

  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

  Future<bool> ensureInit() async {
    if (_ready) return true;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const windows = WindowsInitializationSettings(
      appName: '私家E院',
      appUserModelId: 'fans.ecfc.app',
      guid: 'e0b9f3a4-2f4a-4c2d-9c1a-6d7ec1a4f9b7',
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      windows: windows,
      linux: LinuxInitializationSettings(defaultActionName: '打开'),
    );
    try {
      final ok = await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (resp) {
          final payload = resp.payload;
          if (payload != null && payload.isNotEmpty) {
            final uri = Uri.tryParse(payload);
            if (uri != null) DeepLinkBus.emit(uri);
          }
        },
      );
      _ready = ok ?? true;

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
        ),
      );
      return _ready;
    } catch (e) {
      debugPrint('LocalNoticeService init: $e');
      return false;
    }
  }

  /// 申请通知权限（Android 13+ / iOS / macOS）。不阻塞失败。
  Future<void> requestPermission() async {
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('LocalNoticeService permission: $e');
    }
  }

  /// 弹一条未读消息通知。[total] 用于去重外的聚合文案。
  Future<void> showUnread({required int total, String? preview}) async {
    if (!await ensureInit()) return;
    final body = (preview != null && preview.isNotEmpty)
        ? preview
        : '你有 $total 条未读消息';
    try {
      await _plugin.show(
        id: 1001,
        title: '私家E院 新消息',
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
            ticker: '新消息',
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
          windows: WindowsNotificationDetails(),
        ),
        payload: 'ecfc://notifications',
      );
    } catch (e) {
      debugPrint('LocalNoticeService show: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
