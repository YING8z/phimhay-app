import 'package:flutter/material.dart';
import 'package:phimhay_app/config/theme.dart';
import 'package:phimhay_app/models/movie.dart';
import 'package:phimhay_app/widgets/movie_card.dart';
import 'package:phimhay_app/widgets/top_rank_card.dart';

class MovieRail extends StatelessWidget {
  final String title;
  final String? moreHref;
  final List<Movie> movies;
  final bool showRank;
  final ValueChanged<Movie>? onMovieTap;
  final ValueChanged<String>? onMoreTap;

  const MovieRail({
    super.key,
    required this.title,
    this.moreHref,
    required this.movies,
    this.showRank = false,
    this.onMovieTap,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section header — .m-rail-header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  // .m-rail-title: font-size 16, font-weight 800
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              if (moreHref != null)
                GestureDetector(
                  onTap: () => onMoreTap?.call(moreHref!),
                  child: const Text(
                    'Xem tất cả →',
                    style: TextStyle(
                      // .m-rail-more: font-size 12, font-weight 600, color accent
                      color: AppTheme.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Horizontal scroll
        SizedBox(
          height: showRank
              ? 132 * 1.5 + 8 + 50 + 14  // TopRankCard: poster + gap + rank+title
              : 132 * 1.5 + 8 + 34 + 14, // MovieCard: poster + gap + title + origin
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            physics: const BouncingScrollPhysics(),
            itemCount: movies.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final movie = movies[index];
              if (showRank) {
                return TopRankCard(
                  movie: movie,
                  rank: index + 1,
                  onTap: () => onMovieTap?.call(movie),
                );
              }
              return MovieCard(
                movie: movie,
                rank: 0,
                onTap: () => onMovieTap?.call(movie),
              );
            },
          ),
        ),
      ],
    );
  }
}
