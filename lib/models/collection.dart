class Collection {
  final int id;
  final String name;
  final String slug;
  final int count;
  final List<String> gradient;
  final String? poster;

  const Collection({
    required this.id,
    required this.name,
    required this.slug,
    this.count = 0,
    this.gradient = const ['#8B5CF6', '#EC4899'],
    this.poster,
  });

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      count: json['count'] ?? 0,
      gradient: _parseGradient(json['gradient']),
      poster: json['poster'],
    );
  }

  static List<String> _parseGradient(dynamic raw) {
    if (raw is List && raw.length >= 2) {
      return [raw[0].toString(), raw[1].toString()];
    }
    return ['#8B5CF6', '#EC4899'];
  }
}
