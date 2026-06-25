import 'movie.dart';

class HomeSection {
  final String type;
  final String title;
  final String? moreHref;
  final bool rank;
  final List<Movie> movies;

  const HomeSection({
    required this.type,
    required this.title,
    this.moreHref,
    this.rank = false,
    this.movies = const [],
  });

  factory HomeSection.fromJson(Map<String, dynamic> json) {
    final moviesRaw = json['movies'] ?? json['items'] ?? json['data'] ?? [];
    return HomeSection(
      type: json['type'] ?? '',
      title: json['title'] ?? json['name'] ?? '',
      moreHref: json['more_href'] ?? json['moreHref'],
      rank: json['rank'] ?? json['is_rank'] ?? false,
      movies: (moviesRaw as List<dynamic>)
          .map((e) => Movie.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'title': title,
      'more_href': moreHref,
      'rank': rank,
      'items': movies.map((e) => e.toJson()).toList(),
    };
  }
}
