class Movie {
  final int id;
  final String slug;
  final String name;
  final String? originName;
  final String? thumbUrl;
  final String? posterUrl;
  final int? year;
  final String? quality;
  final String? episodeCurrent;
  final String? episodeTotal;
  final String? type;
  final int viewCount;
  final String? lang;
  final double? imdbRating;
  final double? rating;
  final String? time;
  final String? description;
  final List<String>? actors;

  const Movie({
    required this.id,
    required this.slug,
    required this.name,
    this.originName,
    this.thumbUrl,
    this.posterUrl,
    this.year,
    this.quality,
    this.episodeCurrent,
    this.episodeTotal,
    this.type,
    this.viewCount = 0,
    this.lang,
    this.imdbRating,
    this.rating,
    this.time,
    this.description,
    this.actors,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] ?? json['_id'] ?? 0,
      slug: json['slug'] ?? '',
      name: json['name'] ?? '',
      originName: json['origin_name'],
      thumbUrl: json['thumb_url'],
      posterUrl: json['poster_url'],
      year: json['year'] is int
          ? json['year']
          : (json['year'] != null ? int.tryParse(json['year'].toString()) : null),
      quality: json['quality'],
      episodeCurrent: json['episode_current'],
      episodeTotal: json['episode_total'],
      type: json['type'],
      viewCount: json['view_count'] ?? json['viewCount'] ?? 0,
      lang: json['lang'],
      imdbRating: (json['imdb_rating'] ?? json['imdbRating'])?.toDouble(),
      rating: (json['rating'] ?? json['vote_average'])?.toDouble(),
      time: json['time'],
      description: json['description'] ?? json['content'],
      actors: _parseActors(json['actor'] ?? json['actors'] ?? json['casts']),
    );
  }

  static List<String>? _parseActors(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) {
      final list = raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      return list.isEmpty ? null : list;
    }
    if (raw is String && raw.trim().isNotEmpty) {
      // "Diễn viên 1, Diễn viên 2, Diễn viên 3"
      return raw.split(RegExp(r'[,|/]')).map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'name': name,
      'origin_name': originName,
      'thumb_url': thumbUrl,
      'poster_url': posterUrl,
      'year': year,
      'quality': quality,
      'episode_current': episodeCurrent,
      'episode_total': episodeTotal,
      'type': type,
      'view_count': viewCount,
      'lang': lang,
      'imdb_rating': imdbRating,
      'rating': rating,
      'time': time,
      'description': description,
      'actor': actors,
    };
  }

  @override
  String toString() => name;
}