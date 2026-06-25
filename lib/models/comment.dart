class Comment {
  final int id;
  final int movieId;
  final int userId;
  final String username;
  final String? avatar;
  final String content;
  final DateTime? createdAt;
  final bool spoiler;
  final int? parentId;
  final String? guestName;
  final int? rating;
  final List<Comment> replies;

  const Comment({
    required this.id,
    required this.movieId,
    required this.userId,
    required this.username,
    this.avatar,
    required this.content,
    this.createdAt,
    this.spoiler = false,
    this.parentId,
    this.guestName,
    this.rating,
    this.replies = const [],
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final repliesRaw = json['replies'];
    final repliesList = repliesRaw is List
        ? repliesRaw.map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList()
        : <Comment>[];

    return Comment(
      id: json['id'] ?? json['_id'] ?? 0,
      movieId: json['movie_id'] ?? json['movieId'] ?? 0,
      userId: json['user_id'] ?? json['userId'] ?? 0,
      username: json['author'] ?? json['username'] ?? json['user_name'] ?? json['user']?['name'] ?? '',
      avatar: json['avatar'] ?? json['user_avatar'],
      content: json['content'] ?? json['comment'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      spoiler: json['spoiler'] == true || json['spoiler'] == 1,
      parentId: json['parent_id'],
      guestName: json['guest_name'],
      rating: json['rating'],
      replies: repliesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'movie_id': movieId,
      'user_id': userId,
      'username': username,
      'avatar': avatar,
      'content': content,
      'created_at': createdAt?.toIso8601String(),
      'spoiler': spoiler,
      'parent_id': parentId,
      'guest_name': guestName,
      'rating': rating,
    };
  }
}
