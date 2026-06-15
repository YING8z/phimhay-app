class Comment {
  final int id;
  final int movieId;
  final int userId;
  final String username;
  final String? avatar;
  final String content;
  final DateTime? createdAt;

  const Comment({
    required this.id,
    required this.movieId,
    required this.userId,
    required this.username,
    this.avatar,
    required this.content,
    this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? json['_id'] ?? 0,
      movieId: json['movie_id'] ?? json['movieId'] ?? 0,
      userId: json['user_id'] ?? json['userId'] ?? 0,
      username: json['username'] ?? json['user_name'] ?? json['user']['name'] ?? '',
      avatar: json['avatar'] ?? json['user_avatar'],
      content: json['content'] ?? json['comment'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
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
    };
  }
}
