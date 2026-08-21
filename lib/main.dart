import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/constants.dart';
import 'core/deep_link_bus.dart';
import 'core/share_intent.dart';
import 'pages/web_shell_page.dart';
import 'pages/windows_web_shell_page.dart';
import 'services/unread_badge_service.dart';
import 'services/realtime_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // 状态栏透明，更贴近全屏 Web
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  await DeepLinkBus.start();
  await ShareIntent.start();
  await UnreadBadgeService.instance.start();
  await RealtimeNotificationService.instance.start();
  runApp(const EcfcApp());
}

class EcfcApp extends StatelessWidget {
  const EcfcApp({super.key});

  @override
  Widget build(BuildContext context) {
    final initial = DeepLinkBus.initialUri;
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2F7DE1),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF2F7DE1),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      // Windows 无 webview_flutter 实现，必须走 WebView2 插件，否则整页灰屏。
      home: useWindowsWebView
          ? WindowsWebShellPage(initialUrl: initial)
          : WebShellPage(initialUrl: initial),
    );
  }
}
