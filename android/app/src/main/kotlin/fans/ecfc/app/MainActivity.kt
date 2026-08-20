package fans.ecfc.app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 承接系统分享（ACTION_SEND text/plain）与既有 Deep Link。
 *
 * 冷启动：缓存 EXTRA_TEXT，Dart 侧 [getInitialShare] 取一次。
 * 热启动：singleTask + onNewIntent → 主动 invoke [onShare]。
 */
class MainActivity : FlutterActivity() {
    private val channelName = "fans.ecfc.app/share"
    private var methodChannel: MethodChannel? = null
    private var initialShare: String? = null
    private var flutterReady = false

    override fun onCreate(savedInstanceState: Bundle?) {
        // 必须在 super 之前读 intent：冷启动时 Dart 可能很快来取
        captureShare(intent)?.let { initialShare = it }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialShare" -> {
                    result.success(initialShare)
                    initialShare = null
                    flutterReady = true
                }
                else -> result.notImplemented()
            }
        }
        flutterReady = true
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val text = captureShare(intent) ?: return
        if (flutterReady && methodChannel != null) {
            methodChannel?.invokeMethod("onShare", text)
        } else {
            initialShare = text
        }
    }

    private fun captureShare(intent: Intent?): String? {
        if (intent == null) return null
        if (intent.action != Intent.ACTION_SEND) return null
        val type = intent.type ?: return null
        if (!type.startsWith("text/")) return null
        return intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()?.takeIf { it.isNotEmpty() }
    }
}
