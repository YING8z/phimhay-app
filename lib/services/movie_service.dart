import '../models/comment.dart';
import '../models/movie.dart';
import 'api_client.dart';

class MovieService {
  /// Fetch movie detail by slug from api/movie_detail.php
  Future<Map<String, dynamic>> getDetail(String slug) async {
    final res = await ApiClient.get('/movie_detail.php', params: {'slug': slug});
    return res.data as Map<String, dynamic>;
  }

  /// Fetch detail and return Movie object
  Future<Movie> getMovie(String slug) async {
    final data = await getDetail(slug);
    return Movie.fromJson(data['movie'] as Map<String, dynamic>);
  }

  /// Fetch related movies (from detail endpoint)
  Future<List<Movie>> getRelated(String slug) async {
    final data = await getDetail(slug);
    final related = data['related'] ?? [];
    if (related is List) {
      return related.map((e) => Movie.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Get episodes grouped by server
  Future<List<Map<String, dynamic>>> getEpisodes(int movieId) async {
    final res = await ApiClient.get('/movie_episodes.php', params: {'movie_id': movieId.toString()});
    final data = res.data;
    return (data['servers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  /// Fetch comments for a movie
  Future<List<Comment>> getComments(int movieId) async {
    final res = await ApiClient.get('/Comment.php', params: {'movie_id': movieId.toString()});
    final data = res.data;
    final comments = data['comments'] ?? [];
    if (comments is List) {
      return comments.map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Post a comment
  Future<bool> postComment(int movieId, String content, {int? rating}) async {
    final res = await ApiClient.post('/Comment.php', data: {
      'movie_id': movieId,
      'content': content,
      if (rating != null) 'rating': rating,
    });
    return res.data['success'] == true;
  }

  /// Get watch progress for a movie
  Future<Map<String, dynamic>?> getWatchProgress(int movieId) async {
    try {
      final res = await ApiClient.get('/WatchProgress.php', params: {'movie_id': movieId.toString()});
      final data = res.data as Map<String, dynamic>;
      if (data['success'] == true && data['progress'] != null) {
        return data['progress'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Save server health status
  Future<bool> saveServerHealth({
    required int movieId,
    int? episodeId,
    required String serverName,
    required String status, // 'ok' or 'broken'
  }) async {
    try {
      final res = await ApiClient.post('/SaveServerHealth.php', data: {
        'movie_id': movieId,
        if (episodeId != null) 'episode_id': episodeId,
        'server_name': serverName,
        'status': status,
      });
      return res.data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Save watch progress for a movie
  Future<bool> saveWatchProgress({
    required int movieId,
    int? episodeId,
    String? epSlug,
    int serverIdx = 0,
    int position = 0,
    int duration = 0,
    String? sourceType,
    String? sourceUrl,
  }) async {
    try {
      final res = await ApiClient.post('/WatchProgress.php', data: {
        'movie_id': movieId,
        if (episodeId != null) 'episode_id': episodeId,
        if (epSlug != null && epSlug.isNotEmpty) 'ep_slug': epSlug,
        'server_idx': serverIdx,
        'position': position,
        'duration': duration,
        if (sourceType != null && sourceType.isNotEmpty) 'source_type': sourceType,
        if (sourceUrl != null && sourceUrl.isNotEmpty) 'source_url': sourceUrl,
      });
      return res.data['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
