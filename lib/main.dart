import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/constants.dart';
import 'core/deep_link_bus.dart';
import 'core/share_intent.dart';
import 'pages/web_shell_page.dart';

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
  runApp(const EcfcApp());
}

class EcfcApp extends StatelessWidget {
  const EcfcApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      home: WebShellPage(initialUrl: DeepLinkBus.initialUri),
    );
  }
}
