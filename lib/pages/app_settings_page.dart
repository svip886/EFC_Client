import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_package_info.dart';
import '../core/constants.dart';
import '../services/app_version_service.dart';

/// App 原生设置：关于、检查版本等（与站点 `/settings` 无关）。
class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  AppPackageInfo? _info;
  var _checking = false;
  VersionCheckResult? _lastCheck;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final info = await AppPackageInfo.load();
    if (!mounted) return;
    setState(() => _info = info);
  }

  Future<void> _checkVersion() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _lastCheck = null;
    });
    final result = await AppVersionService.check();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _lastCheck = result;
    });

    if (result.hasUpdate) {
      await _showUpdateDialog(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? '检查完成'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showUpdateDialog(VersionCheckResult result) async {
    final remote = result.remote;
    final force = result.status == VersionCheckStatus.forceUpdate;
    await showDialog<void>(
      context: context,
      barrierDismissible: !force,
      builder: (ctx) {
        return AlertDialog(
          title: Text(force ? '需要更新' : '发现新版本'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '最新：${remote?.latestVersion ?? '-'}'
                '（${remote?.latestBuild ?? '-'}）\n'
                '当前：${result.local.versionLabel}',
              ),
              if (remote?.notes != null && remote!.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(remote.notes!.trim()),
              ],
            ],
          ),
          actions: [
            if (!force)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('稍后'),
              ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final url = remote?.downloadUrl;
                if (url != null && url.isNotEmpty) {
                  await _openUrl(url);
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('未配置下载地址，请从发布渠道获取安装包'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('去更新'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开：$url')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开链接')),
      );
    }
  }

  Future<void> _copyText(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制$label'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = _info;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App 设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader('关于'),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.local_hospital_outlined,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(info?.appName ?? AppConstants.appName),
            subtitle: const Text('私家E院 Flutter 客户端'),
          ),
          ListTile(
            leading: const Icon(Icons.tag_outlined),
            title: const Text('版本'),
            subtitle: Text(info?.versionLabel ?? '读取中…'),
            trailing: IconButton(
              tooltip: '复制版本号',
              icon: const Icon(Icons.copy_outlined),
              onPressed: info == null
                  ? null
                  : () => _copyText('版本号', info.versionLabel),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.apps_outlined),
            title: const Text('应用 ID'),
            subtitle: Text(info?.packageName ?? '…'),
            onLongPress: info == null
                ? null
                : () => _copyText('应用 ID', info.packageName),
          ),
          ListTile(
            leading: const Icon(Icons.public_outlined),
            title: const Text('官方网站'),
            subtitle: Text(AppConstants.baseUrl),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openUrl(AppConstants.baseUrl),
          ),
          const Divider(height: 32),
          const _SectionHeader('更新'),
          ListTile(
            leading: _checking
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: Padding(
                      padding: EdgeInsets.all(2),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.system_update_alt_outlined),
            title: const Text('检查新版本'),
            subtitle: Text(
              _lastCheck?.message ??
                  '从 ${Uri.parse(AppConstants.appVersionManifestUrl).host} 拉取清单',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _checking ? null : _checkVersion,
          ),
          if (_lastCheck?.remote != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '清单最新：${_lastCheck!.remote!.latestVersion}'
                '（build ${_lastCheck!.remote!.latestBuild}）',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          const Divider(height: 32),
          const _SectionHeader('说明'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Text(
              '本页为 App 客户端设置，与网站内「设置」相互独立。'
              '检查更新依赖公开清单：\n${AppConstants.appVersionManifestUrl}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
