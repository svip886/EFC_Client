import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/network/api_exception.dart';
import '../models/ecfc_models.dart';
import '../providers/service_providers.dart';

/// 帖子详情：正文 + 楼层列表，风格参考 FluxDO topic_detail_page。
class PostDetailPage extends ConsumerStatefulWidget {
  const PostDetailPage({super.key, required this.postId, this.title});

  final String postId;
  final String? title;

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  EcfcPostDetail? _detail;
  bool _loading = true;
  String? _error;
  final _replyController = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final service = ref.read(forumServiceProvider);
    try {
      final detail = await service.postDetail(widget.postId);
      setState(() => _detail = detail);
      // 上报浏览量，静默失败即可。
      unawaited(service.reportView(widget.postId));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '加载失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(forumServiceProvider).createReply(
            postId: widget.postId,
            content: content,
          );
      _replyController.clear();
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? '帖子详情')),
      body: _buildBody(),
      bottomNavigationBar: _detail == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        decoration: const InputDecoration(
                          hintText: '回复帖子',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _sendReply(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      onPressed: _sending ? null : _sendReply,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    final detail = _detail!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            detail.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundImage: detail.author.avatarUrl != null
                    ? NetworkImage(detail.author.avatarUrl!)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(detail.author.nickname),
              const Spacer(),
              Text(DateFormat('MM/dd HH:mm').format(detail.createdAt.toLocal())),
            ],
          ),
          const Divider(height: 24),
          _ContentText(content: detail.content),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.remove_red_eye_outlined, size: 16, color: Theme.of(context).colorScheme.outline),
              const SizedBox(width: 4),
              Text('${detail.viewCount}'),
              const SizedBox(width: 16),
              Icon(Icons.forum_outlined, size: 16, color: Theme.of(context).colorScheme.outline),
              const SizedBox(width: 4),
              Text('${detail.replyCount}'),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  try {
                    await ref.read(forumServiceProvider).likePost(detail.id);
                    if (mounted) await _load();
                  } on ApiException catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  }
                },
                icon: const Icon(Icons.favorite_border),
                label: Text('${detail.likeCount}'),
              ),
            ],
          ),
          const Divider(height: 32),
          Text(
            '回复 ${detail.replyCount}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final reply in detail.replies) _ReplyTile(reply: reply),
        ],
      ),
    );
  }
}

class _ContentText extends StatelessWidget {
  const _ContentText({required this.content});

  final String content;

  /// 解析 `[[content-image:URL]]` 标记，其余按纯文本展示。
  /// 详见 docs/ECFC_API.md §4。
  static final _imagePattern = RegExp(r'\[\[content-image:([^\]]+)\]\]');

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];
    int last = 0;
    for (final match in _imagePattern.allMatches(content)) {
      if (match.start > last) {
        parts.add(_text(content.substring(last, match.start)));
      }
      final url = match.group(1)!;
      parts.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      );
      last = match.end;
    }
    if (last < content.length) {
      parts.add(_text(content.substring(last)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: parts);
  }

  Widget _text(String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Text(text, style: const TextStyle(height: 1.5));
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({required this.reply});

  final EcfcReply reply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundImage: reply.author.avatarUrl != null
                    ? NetworkImage(reply.author.avatarUrl!)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(reply.author.nickname, style: theme.textTheme.bodyMedium),
              const Spacer(),
              Text(
                DateFormat('MM/dd HH:mm').format(reply.createdAt.toLocal()),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(reply.content),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.favorite_border, size: 14, color: theme.colorScheme.outline),
              const SizedBox(width: 4),
              Text('${reply.likeCount}', style: theme.textTheme.bodySmall),
            ],
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }
}
