import '../models/home_section.dart';
import '../models/movie.dart';
import 'api_client.dart';

class HomeService {
  /// Fetch home data - returns heroMovies + sections
  /// filter: all (default), phim-bo, phim-le, the-loai
  Future<Map<String, dynamic>> fetchHomeRaw({String filter = 'all'}) async {
    final res = await ApiClient.get('/home.php', params: {
      'filter': filter,
      '_t': DateTime.now().millisecondsSinceEpoch ~/ 60000,
    });
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw ApiException('Invalid response from server', statusCode: res.statusCode);
  }

  /// Fetch sections only
  Future<List<HomeSection>> fetchSections() async {
    final data = await fetchHomeRaw();
    final sections = data['sections'] ?? [];
    if (sections is List) {
      return sections.map((e) => HomeSection.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Fetch featured hero movies
  Future<List<Movie>> fetchHeroMovies() async {
    final data = await fetchHomeRaw();
    final heroes = data['heroMovies'] ?? [];
    if (heroes is List) {
      return heroes.map((e) => Movie.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }
}
