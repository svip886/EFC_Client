/// 与 `docs/ECFC_API.md` §3.3、§6 对应。
class EcfcUser {
  final String id;
  final int uid;
  final String username;
  final String nickname;
  final String? avatarUrl;
  final int level;
  final int experience;
  final String role;
  final bool canPlayFullMusic;

  const EcfcUser({
    required this.id,
    required this.uid,
    required this.username,
    required this.nickname,
    required this.level,
    required this.experience,
    required this.role,
    this.avatarUrl,
    this.canPlayFullMusic = false,
  });

  factory EcfcUser.fromJson(Map<String, dynamic> json) {
    return EcfcUser(
      id: json['id'] as String? ?? '',
      uid: (json['uid'] as num?)?.toInt() ?? 0,
      username: json['username'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      level: (json['level'] as num?)?.toInt() ?? 1,
      experience: (json['experience'] as num?)?.toInt() ?? 0,
      role: json['role'] as String? ?? 'USER',
      canPlayFullMusic: json['canPlayFullMusic'] as bool? ?? false,
    );
  }
}

/// 帖子作者信息（列表/详情内嵌，字段比 [EcfcUser] 少 username，多 nickname/头像）。
class EcfcAuthor {
  final String id;
  final int? uid;
  final String nickname;
  final String? avatarUrl;
  final int level;

  const EcfcAuthor({
    required this.id,
    required this.nickname,
    required this.level,
    this.uid,
    this.avatarUrl,
  });

  factory EcfcAuthor.fromJson(Map<String, dynamic> json) {
    // avatarUrl 有时在顶层，有时在 profile/Profile 里，取第一个非空的。
    String? avatar = json['avatarUrl'] as String?;
    final profile = json['profile'] ?? json['Profile'];
    if (avatar == null && profile is Map) {
      avatar = profile['avatarUrl'] as String?;
    }
    return EcfcAuthor(
      id: json['id'] as String? ?? '',
      uid: (json['uid'] as num?)?.toInt(),
      nickname: json['nickname'] as String? ?? '已注销用户',
      avatarUrl: avatar,
      level: (json['level'] as num?)?.toInt() ?? 1,
    );
  }
}

class EcfcBoard {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final int postCount;
  final bool isAnnouncement;

  const EcfcBoard({
    required this.id,
    required this.name,
    required this.slug,
    required this.postCount,
    this.description,
    this.isAnnouncement = false,
  });

  factory EcfcBoard.fromJson(Map<String, dynamic> json) {
    return EcfcBoard(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      postCount: (json['postCount'] as num?)?.toInt() ?? 0,
      isAnnouncement: json['isAnnouncement'] as bool? ?? false,
    );
  }
}

class EcfcBoardRef {
  final String name;
  final String slug;

  const EcfcBoardRef({required this.name, required this.slug});

  factory EcfcBoardRef.fromJson(Map<String, dynamic> json) {
    return EcfcBoardRef(
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
    );
  }
}

/// 广场列表 / feed 里的帖子条目。
class EcfcPost {
  final String id;
  final String title;
  final String? content;
  final int likeCount;
  final int favoriteCount;
  final int replyCount;
  final int viewCount;
  final bool isPinned;
  final bool isFeatured;
  final DateTime createdAt;
  final EcfcAuthor author;
  final EcfcBoardRef? board;
  final bool likedByMe;

  const EcfcPost({
    required this.id,
    required this.title,
    required this.likeCount,
    required this.favoriteCount,
    required this.replyCount,
    required this.viewCount,
    required this.isPinned,
    required this.isFeatured,
    required this.createdAt,
    required this.author,
    this.content,
    this.board,
    this.likedByMe = false,
  });

  factory EcfcPost.fromJson(Map<String, dynamic> json) {
    return EcfcPost(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String?,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      favoriteCount: (json['favoriteCount'] as num?)?.toInt() ?? 0,
      replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      isPinned: json['isPinned'] as bool? ?? false,
      isFeatured: json['isFeatured'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      author: EcfcAuthor.fromJson(
        (json['author'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      board: json['board'] is Map
          ? EcfcBoardRef.fromJson((json['board'] as Map).cast<String, dynamic>())
          : null,
      likedByMe: json['likedByMe'] as bool? ?? false,
    );
  }
}

class EcfcReply {
  final String id;
  final String content;
  final String? parentId;
  final int likeCount;
  final bool isPinned;
  final EcfcAuthor author;
  final DateTime createdAt;
  final String? ipRegion;

  const EcfcReply({
    required this.id,
    required this.content,
    required this.likeCount,
    required this.isPinned,
    required this.author,
    required this.createdAt,
    this.parentId,
    this.ipRegion,
  });

  factory EcfcReply.fromJson(Map<String, dynamic> json) {
    return EcfcReply(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      parentId: json['parentId'] as String?,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      isPinned: json['isPinned'] as bool? ?? false,
      author: EcfcAuthor.fromJson(
        (json['author'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      ipRegion: json['ipRegion'] as String?,
    );
  }
}

/// 帖子详情（`GET /api/posts/{id}` 返回体中的 `post` 字段）。
class EcfcPostDetail {
  final String id;
  final String title;
  final String content;
  final int viewCount;
  final int likeCount;
  final int replyCount;
  final int favoriteCount;
  final bool isPinned;
  final bool isFeatured;
  final bool isLocked;
  final DateTime createdAt;
  final EcfcAuthor author;
  final EcfcBoardRef? board;
  final List<EcfcReply> replies;

  const EcfcPostDetail({
    required this.id,
    required this.title,
    required this.content,
    required this.viewCount,
    required this.likeCount,
    required this.replyCount,
    required this.favoriteCount,
    required this.isPinned,
    required this.isFeatured,
    required this.isLocked,
    required this.createdAt,
    required this.author,
    required this.replies,
    this.board,
  });

  factory EcfcPostDetail.fromJson(Map<String, dynamic> json) {
    final repliesRaw = json['replies'] as List? ?? const [];
    return EcfcPostDetail(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
      favoriteCount: (json['favoriteCount'] as num?)?.toInt() ?? 0,
      isPinned: json['isPinned'] as bool? ?? false,
      isFeatured: json['isFeatured'] as bool? ?? false,
      isLocked: json['isLocked'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      author: EcfcAuthor.fromJson(
        (json['author'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      board: json['board'] is Map
          ? EcfcBoardRef.fromJson((json['board'] as Map).cast<String, dynamic>())
          : null,
      replies: repliesRaw
          .whereType<Map>()
          .map((e) => EcfcReply.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}
