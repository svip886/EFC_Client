import 'package:package_info_plus/package_info_plus.dart';

/// 当前安装包信息（缓存一次）。
class AppPackageInfo {
  AppPackageInfo._({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
  });

  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;

  int get build => int.tryParse(buildNumber) ?? 0;

  String get versionLabel => '$version ($buildNumber)';

  static AppPackageInfo? _cached;

  static Future<AppPackageInfo> load() async {
    if (_cached != null) return _cached!;
    final p = await PackageInfo.fromPlatform();
    return _cached = AppPackageInfo._(
      appName: p.appName.isNotEmpty ? p.appName : '私家E院',
      packageName: p.packageName,
      version: p.version,
      buildNumber: p.buildNumber,
    );
  }
}
