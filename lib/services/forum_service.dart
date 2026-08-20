import '../core/network/api_client.dart';
import '../models/ecfc_models.dart';

class ForumFeedResult {
  final List<EcfcBoard> boards;
  final List<EcfcPost> posts;
  final int total;
  final int totalPages;
  final int page;

  const ForumFeedResult({
    required this.boards,
    required this.posts,
    required this.total,
    required this.totalPages,
    required this.page,
  });
}

/// 广场 / 帖子 / 回复。见 docs/ECFC_API.md §5.2 §5.5 §5.6。
class ForumService {
  ForumService(this._client);

  final ApiClient _client;

  Future<ForumFeedResult> feed({
    String sort = 'latest',
    int page = 1,
    int pageSize = 20,
    String? board,
  }) async {
    final resp = await _client.get(
      '/api/forum/feed',
      query: {
        'sort': sort,
        'page': page,
        'pageSize': pageSize,
        if (board != null) 'board': board,
      },
    );
    final data = resp.data as Map<String, dynamic>;
    final boards = (data['boards'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => EcfcBoard.fromJson(e.cast<String, dynamic>()))
        .toList();
    final posts = (data['posts'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => EcfcPost.fromJson(e.cast<String, dynamic>()))
        .toList();
    return ForumFeedResult(
      boards: boards,
      posts: posts,
      total: (data['total'] as num?)?.toInt() ?? posts.length,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
      page: (data['page'] as num?)?.toInt() ?? page,
    );
  }

  Future<EcfcPostDetail> postDetail(String postId) async {
    final resp = await _client.get('/api/posts/$postId');
    final data = resp.data as Map<String, dynamic>;
    return EcfcPostDetail.fromJson(
      (data['post'] as Map).cast<String, dynamic>(),
    );
  }

  /// 进入详情页时上报浏览量，失败静默忽略（非关键路径）。
  Future<void> reportView(String postId) async {
    try {
      await _client.post('/api/posts/$postId/view');
    } catch (_) {
      // 浏览量上报失败不影响阅读体验。
    }
  }

  Future<void> likePost(String postId) async {
    await _client.post('/api/posts/$postId/like');
  }

  Future<void> likeReply(String replyId) async {
    await _client.post('/api/replies/$replyId/like');
  }

  Future<void> createReply({
    required String postId,
    required String content,
    String? parentId,
  }) async {
    await _client.post(
      '/api/posts/$postId/replies',
      data: {
        'content': content,
        'parentId': parentId,
        'imageUrls': const [],
        'mentions': const [],
      },
    );
  }
}
