import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ecfc_models.dart';
import '../pages/post_detail_page.dart';

/// 帖子卡片，风格参考 FluxDO 的 topic_card：
/// 分区角标 + 标题 + 作者行 + 浏览/回复/赞 统计。
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post});

  final EcfcPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostDetailPage(postId: post.id, title: post.title),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (post.isPinned) _Tag(text: '置顶', color: theme.colorScheme.tertiary),
                  if (post.isFeatured) _Tag(text: '精华', color: theme.colorScheme.secondary),
                  if (post.board != null)
                    _Tag(text: post.board!.name, color: theme.colorScheme.primary),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                post.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundImage: post.author.avatarUrl != null
                        ? NetworkImage(post.author.avatarUrl!)
                        : null,
                    child: post.author.avatarUrl == null
                        ? Text(
                            post.author.nickname.isNotEmpty
                                ? post.author.nickname.substring(0, 1)
                                : '?',
                            style: const TextStyle(fontSize: 12),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      post.author.nickname,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatTime(post.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatIcon(icon: Icons.remove_red_eye_outlined, value: post.viewCount),
                  const SizedBox(width: 16),
                  _StatIcon(icon: Icons.forum_outlined, value: post.replyCount),
                  const SizedBox(width: 16),
                  _StatIcon(
                    icon: post.likedByMe
                        ? Icons.favorite
                        : Icons.favorite_border,
                    value: post.likeCount,
                    color: post.likedByMe ? Colors.redAccent : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime time) {
    final local = time.toLocal();
    final now = DateTime.now();
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return DateFormat('HH:mm').format(local);
    }
    return DateFormat('MM/dd').format(local);
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatIcon extends StatelessWidget {
  const _StatIcon({required this.icon, required this.value, this.color});

  final IconData icon;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Text('$value', style: theme.textTheme.bodySmall?.copyWith(color: c)),
      ],
    );
  }
}
