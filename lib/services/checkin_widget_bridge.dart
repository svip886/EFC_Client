import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/checkin_status.dart';

/// 把挂号状态推到 Android 桌面小组件（home_widget SharedPreferences）。
class CheckinWidgetBridge {
  CheckinWidgetBridge._();

  static const androidName = 'CheckinWidgetProvider';

  static Future<void> publish(CheckinStatus status) async {
    try {
      final title = status.checkedToday ? '今日已挂号' : '尚未挂号';
      final streak = '连续 ${status.currentStreak} 天';
      final sub = status.checkedToday
          ? (status.todayMood != null && status.todayMood!.isNotEmpty
              ? '心情 ${status.todayMood} · Lv.${status.level}'
              : 'Lv.${status.level} · 累计 ${status.totalCheckIns} 次')
          : '点按一键挂号 · Lv.${status.level}';
      await HomeWidget.saveWidgetData<String>('checkin_title', title);
      await HomeWidget.saveWidgetData<String>('checkin_streak', streak);
      await HomeWidget.saveWidgetData<String>('checkin_sub', sub);
      await HomeWidget.saveWidgetData<bool>(
        'checkin_done',
        status.checkedToday,
      );
      await HomeWidget.updateWidget(
        name: androidName,
        androidName: androidName,
      );
    } catch (e) {
      debugPrint('CheckinWidgetBridge.publish: $e');
    }
  }

  static Future<void> publishLoggedOut() async {
    try {
      await HomeWidget.saveWidgetData<String>('checkin_title', '每日挂号');
      await HomeWidget.saveWidgetData<String>('checkin_streak', '未登录');
      await HomeWidget.saveWidgetData<String>('checkin_sub', '打开 App 登录后可挂号');
      await HomeWidget.saveWidgetData<bool>('checkin_done', false);
      await HomeWidget.updateWidget(
        name: androidName,
        androidName: androidName,
      );
    } catch (e) {
      debugPrint('CheckinWidgetBridge.publishLoggedOut: $e');
    }
  }
}
