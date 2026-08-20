package fans.ecfc.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 每日挂号桌面小组件：展示连续天数，点按一键挂号（ecfc://action/checkin）。
 */
class CheckinWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.checkin_widget).apply {
                val title = widgetData.getString("checkin_title", null) ?: "每日挂号"
                val streak = widgetData.getString("checkin_streak", null) ?: "打开 App 同步"
                val sub = widgetData.getString("checkin_sub", null) ?: "点按一键挂号"
                val done = widgetData.getBoolean("checkin_done", false)

                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_streak, streak)
                setTextViewText(R.id.widget_sub, sub)
                setTextViewText(
                    R.id.widget_action,
                    if (done) "查看挂号" else "一键挂号",
                )

                // 整卡：一键挂号动作
                val checkinUri = Uri.parse("ecfc://action/checkin")
                val checkinIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    checkinUri,
                )
                setOnClickPendingIntent(R.id.widget_root, checkinIntent)
                setOnClickPendingIntent(R.id.widget_action, checkinIntent)

                // 标题区也可打开挂号页
                val openPage = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("ecfc://checkin"),
                )
                setOnClickPendingIntent(R.id.widget_title, openPage)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
