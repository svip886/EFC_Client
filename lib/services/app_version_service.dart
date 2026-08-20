import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/app_package_info.dart';
import '../core/constants.dart';

/// 远端版本清单（由站点或 CDN 托管的 JSON）。
class AppVersionManifest {
  const AppVersionManifest({
    required this.latestVersion,
    required this.latestBuild,
    this.minBuild,
    this.notes,
    this.downloadUrl,
    this.force = false,
  });

  final String latestVersion;
  final int latestBuild;
  final int? minBuild;
  final String? notes;
  final String? downloadUrl;
  final bool force;

  factory AppVersionManifest.fromJson(Map<String, dynamic> json) {
    return AppVersionManifest(
      latestVersion: '${json['latestVersion'] ?? json['version'] ?? ''}',
      latestBuild: _asInt(json['latestBuild'] ?? json['build']) ?? 0,
      minBuild: _asInt(json['minBuild']),
      notes: json['notes'] is String ? json['notes'] as String : null,
      downloadUrl: json['downloadUrl'] is String
          ? json['downloadUrl'] as String
          : (json['url'] is String ? json['url'] as String : null),
      force: json['force'] == true,
    );
  }

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

enum VersionCheckStatus {
  /// 已是最新
  upToDate,

  /// 有新版本
  updateAvailable,

  /// 低于最低版本（建议强制更新）
  forceUpdate,

  /// 清单不存在 / 网络失败
  unavailable,

  /// 清单格式无效
  invalid,
}

class VersionCheckResult {
  const VersionCheckResult({
    required this.status,
    required this.local,
    this.remote,
    this.message,
  });

  final VersionCheckStatus status;
  final AppPackageInfo local;
  final AppVersionManifest? remote;
  final String? message;

  bool get hasUpdate =>
      status == VersionCheckStatus.updateAvailable ||
      status == VersionCheckStatus.forceUpdate;
}

/// 检查 App 版本（与站点 Web 版本无关）。
class AppVersionService {
  AppVersionService._();

  /// 不带 Cookie 的轻量 Dio，避免会话干扰公开清单。
  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      headers: const {'Accept': 'application/json'},
      validateStatus: (_) => true,
      // 版本检查直连，跟随重定向
      followRedirects: true,
      maxRedirects: 3,
    ),
  );

  static Future<VersionCheckResult> check() async {
    final local = await AppPackageInfo.load();
    try {
      final resp = await _dio.get<dynamic>(AppConstants.appVersionManifestUrl);
      final code = resp.statusCode ?? 0;
      if (code == 404 || code == 403) {
        return VersionCheckResult(
          status: VersionCheckStatus.unavailable,
          local: local,
          message: '尚未配置版本清单（${AppConstants.appVersionManifestUrl}）',
        );
      }
      if (code < 200 || code >= 300) {
        return VersionCheckResult(
          status: VersionCheckStatus.unavailable,
          local: local,
          message: '检查失败（HTTP $code）',
        );
      }

      final data = resp.data;
      Map<String, dynamic>? map;
      if (data is Map<String, dynamic>) {
        map = data;
      } else if (data is Map) {
        map = data.cast<String, dynamic>();
      }
      if (map == null) {
        return VersionCheckResult(
          status: VersionCheckStatus.invalid,
          local: local,
          message: '版本清单格式无效',
        );
      }

      final remote = AppVersionManifest.fromJson(map);
      if (remote.latestBuild <= 0 && remote.latestVersion.isEmpty) {
        return VersionCheckResult(
          status: VersionCheckStatus.invalid,
          local: local,
          message: '版本清单缺少 latestBuild / latestVersion',
        );
      }

      final localBuild = local.build;
      final minBuild = remote.minBuild ?? 0;
      if (minBuild > 0 && localBuild < minBuild) {
        return VersionCheckResult(
          status: VersionCheckStatus.forceUpdate,
          local: local,
          remote: remote,
          message: '当前版本过旧，请更新到 ${remote.latestVersion}',
        );
      }

      if (remote.latestBuild > localBuild ||
          (remote.latestBuild == localBuild &&
              remote.latestVersion.isNotEmpty &&
              remote.latestVersion != local.version &&
              _isNewerVersionName(remote.latestVersion, local.version))) {
        return VersionCheckResult(
          status: remote.force
              ? VersionCheckStatus.forceUpdate
              : VersionCheckStatus.updateAvailable,
          local: local,
          remote: remote,
          message: '发现新版本 ${remote.latestVersion}（${remote.latestBuild}）',
        );
      }

      return VersionCheckResult(
        status: VersionCheckStatus.upToDate,
        local: local,
        remote: remote,
        message: '已是最新版本',
      );
    } catch (e, st) {
      debugPrint('AppVersionService.check: $e\n$st');
      return VersionCheckResult(
        status: VersionCheckStatus.unavailable,
        local: local,
        message: '网络异常，暂时无法检查更新',
      );
    }
  }

  /// 极简 semver 比较：1.0.1 > 1.0.0；比不过则 false。
  static bool _isNewerVersionName(String remote, String local) {
    List<int> parts(String v) => v
        .split(RegExp(r'[^0-9]+'))
        .where((s) => s.isNotEmpty)
        .map((s) => int.tryParse(s) ?? 0)
        .toList();
    final a = parts(remote);
    final b = parts(local);
    final n = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}
