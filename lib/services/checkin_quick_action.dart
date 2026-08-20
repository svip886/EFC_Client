import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/session_cookie_sync.dart';
import '../models/checkin_status.dart';
import 'checkin_service.dart';
import 'checkin_widget_bridge.dart';

/// 一键挂号结果（给 SnackBar / 小组件用，不写死敏感信息）。
class CheckinQuickResult {
  const CheckinQuickResult._({
    required this.kind,
    this.status,
    this.message,
  });

  final CheckinQuickKind kind;
  final CheckinStatus? status;
  final String? message;

  factory CheckinQuickResult.needLogin() =>
      const CheckinQuickResult._(kind: CheckinQuickKind.needLogin);

  factory CheckinQuickResult.already(CheckinStatus s) => CheckinQuickResult._(
        kind: CheckinQuickKind.already,
        status: s,
        message: '今日已挂号 · 连续 ${s.currentStreak} 天',
      );

  factory CheckinQuickResult.success(CheckinStatus s) => CheckinQuickResult._(
        kind: CheckinQuickKind.success,
        status: s,
        message: '挂号成功 · 连续 ${s.currentStreak} 天 · +${s.points} 挂号费',
      );

  factory CheckinQuickResult.failed(String msg) => CheckinQuickResult._(
        kind: CheckinQuickKind.failed,
        message: msg,
      );

  String get snackbarText {
    switch (kind) {
      case CheckinQuickKind.needLogin:
        return '请先在 App 内登录后再挂号';
      case CheckinQuickKind.already:
      case CheckinQuickKind.success:
      case CheckinQuickKind.failed:
        return message ?? '挂号完成';
    }
  }
}

enum CheckinQuickKind { needLogin, already, success, failed }

/// 同步 Cookie 后调 `GET/POST /api/checkin`，并刷新桌面小组件。
class CheckinQuickAction {
  CheckinQuickAction._();

  /// [preferMood]：服务端若要求 mood，默认用 calm（样本中常见）。
  static Future<CheckinQuickResult> run({String preferMood = 'calm'}) async {
    final hasSession = await SessionCookieSync.syncFromWebView();
    if (!hasSession) {
      await CheckinWidgetBridge.publishLoggedOut();
      return CheckinQuickResult.needLogin();
    }

    final client = await ApiClient.ensureInitialized();
    final svc = CheckinService(client);

    try {
      var status = await svc.status();
      if (status.checkedToday) {
        await CheckinWidgetBridge.publish(status);
        return CheckinQuickResult.already(status);
      }

      try {
        status = await svc.checkin();
      } on ApiException catch (e) {
        // 可能要求 mood：再试一次带默认心情
        if (e.isUnauthorized) {
          await CheckinWidgetBridge.publishLoggedOut();
          return CheckinQuickResult.needLogin();
        }
        status = await svc.checkin(mood: preferMood);
      }

      await CheckinWidgetBridge.publish(status);
      if (status.checkedToday) {
        return CheckinQuickResult.success(status);
      }
      // POST 成功但字段不完整时仍当成功
      return CheckinQuickResult.success(status);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await CheckinWidgetBridge.publishLoggedOut();
        return CheckinQuickResult.needLogin();
      }
      // 已签到类错误
      final msg = e.message;
      if (msg.contains('已') || msg.toLowerCase().contains('already')) {
        try {
          final s = await svc.status();
          await CheckinWidgetBridge.publish(s);
          return CheckinQuickResult.already(s);
        } catch (_) {}
      }
      return CheckinQuickResult.failed(msg.isNotEmpty ? msg : '挂号失败');
    } catch (e) {
      return CheckinQuickResult.failed('挂号失败：$e');
    }
  }

  /// 仅刷新状态到小组件（不 POST）。
  static Future<void> refreshWidgetOnly() async {
    try {
      final hasSession = await SessionCookieSync.syncFromWebView();
      if (!hasSession) {
        await CheckinWidgetBridge.publishLoggedOut();
        return;
      }
      final client = await ApiClient.ensureInitialized();
      final status = await CheckinService(client).status();
      await CheckinWidgetBridge.publish(status);
    } catch (_) {
      // 小组件刷新失败可忽略
    }
  }
}
