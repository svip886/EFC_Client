import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/app_package_info.dart';
import '../core/constants.dart';

/// 远端版本清单（GitHub Release / 仓库 JSON）。
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

  /// 从 GitHub Releases API `latest` 响应构造。
  factory AppVersionManifest.fromGithubRelease(Map<String, dynamic> json) {
    final tag = '${json['tag_name'] ?? ''}'.trim();
    final version = tag.startsWith('v') || tag.startsWith('V')
        ? tag.substring(1)
        : tag;

    // tag 可带 build：1.0.2+12
    var name = version;
    var build = 0;
    final plus = version.split('+');
    if (plus.length >= 2) {
      name = plus.first;
      build = int.tryParse(plus[1]) ?? 0;
    }

    String? apkUrl;
    final assets = json['assets'];
    if (assets is List) {
      for (final a in assets) {
        if (a is! Map) continue;
        final n = '${a['name'] ?? ''}'.toLowerCase();
        final url = a['browser_download_url'];
        if (url is! String || url.isEmpty) continue;
        if (n.endsWith('.apk') && apkUrl == null) {
          apkUrl = url;
        }
      }
    }

    final body = json['body'];
    final notes = body is String && body.trim().isNotEmpty ? body.trim() : null;
    final htmlUrl = json['html_url'];

    return AppVersionManifest(
      latestVersion: name,
      latestBuild: build,
      notes: notes,
      downloadUrl: apkUrl ??
          (htmlUrl is String ? htmlUrl : AppConstants.githubReleasesUrl),
      force: false,
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
  upToDate,
  updateAvailable,
  forceUpdate,
  unavailable,
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

/// 检查 App 版本：GitHub Release 优先，兼容仓库内 version.json。
class AppVersionService {
  AppVersionService._();

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'ecfc-app-version-check',
      },
      validateStatus: (_) => true,
      followRedirects: true,
      maxRedirects: 5,
    ),
  );

  static Future<VersionCheckResult> check() async {
    final local = await AppPackageInfo.load();

    // 1) Release 资产 version.json（CI 发布时上传）
    final fromAsset = await _tryManifestJson(AppConstants.appVersionManifestUrl);
    if (fromAsset != null) {
      return _compare(local, fromAsset);
    }

    // 2) 仓库 raw app/version.json
    final fromRaw =
        await _tryManifestJson(AppConstants.appVersionManifestRawUrl);
    if (fromRaw != null) {
      return _compare(local, fromRaw);
    }

    // 3) GitHub API latest release
    final fromApi = await _tryGithubLatestRelease();
    if (fromApi != null) {
      return _compare(local, fromApi);
    }

    return VersionCheckResult(
      status: VersionCheckStatus.unavailable,
      local: local,
      message:
          '暂无可用版本信息。请确认 GitHub 仓库 ${AppConstants.githubOwner}/${AppConstants.githubRepo} 已发布 Release。',
    );
  }

  static Future<AppVersionManifest?> _tryManifestJson(String url) async {
    try {
      final resp = await _dio.get<dynamic>(url);
      final code = resp.statusCode ?? 0;
      if (code < 200 || code >= 300) return null;
      final map = _asStringKeyMap(resp.data);
      if (map == null) return null;
      final m = AppVersionManifest.fromJson(map);
      if (m.latestBuild <= 0 && m.latestVersion.isEmpty) return null;
      return m;
    } catch (e) {
      debugPrint('AppVersionService manifest $url: $e');
      return null;
    }
  }

  static Future<AppVersionManifest?> _tryGithubLatestRelease() async {
    try {
      final resp =
          await _dio.get<dynamic>(AppConstants.githubLatestReleaseApiUrl);
      final code = resp.statusCode ?? 0;
      if (code == 404) return null;
      if (code < 200 || code >= 300) return null;
      final map = _asStringKeyMap(resp.data);
      if (map == null) return null;

      // 若 assets 含 version.json，再拉一次更准
      final assets = map['assets'];
      if (assets is List) {
        for (final a in assets) {
          if (a is! Map) continue;
          final name = '${a['name'] ?? ''}'.toLowerCase();
          final url = a['browser_download_url'];
          if (name == 'version.json' && url is String) {
            final nested = await _tryManifestJson(url);
            if (nested != null) return nested;
          }
        }
      }

      final m = AppVersionManifest.fromGithubRelease(map);
      if (m.latestVersion.isEmpty) return null;
      return m;
    } catch (e) {
      debugPrint('AppVersionService github api: $e');
      return null;
    }
  }

  static Map<String, dynamic>? _asStringKeyMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {}
    }
    return null;
  }

  static VersionCheckResult _compare(
    AppPackageInfo local,
    AppVersionManifest remote,
  ) {
    if (remote.latestBuild <= 0 && remote.latestVersion.isEmpty) {
      return VersionCheckResult(
        status: VersionCheckStatus.invalid,
        local: local,
        remote: remote,
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

    final newerBuild = remote.latestBuild > localBuild;
    final newerName = remote.latestVersion.isNotEmpty &&
        remote.latestVersion != local.version &&
        _isNewerVersionName(remote.latestVersion, local.version);

    if (newerBuild ||
        (remote.latestBuild == localBuild && newerName) ||
        (remote.latestBuild <= 0 && newerName)) {
      return VersionCheckResult(
        status: remote.force
            ? VersionCheckStatus.forceUpdate
            : VersionCheckStatus.updateAvailable,
        local: local,
        remote: remote,
        message:
            '发现新版本 ${remote.latestVersion}${remote.latestBuild > 0 ? '（${remote.latestBuild}）' : ''}',
      );
    }

    return VersionCheckResult(
      status: VersionCheckStatus.upToDate,
      local: local,
      remote: remote,
      message: '已是最新版本',
    );
  }

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
