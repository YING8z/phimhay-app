import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:phimhay_app/config/theme.dart';

class ShimmerLoading extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E2030),
      highlightColor: const Color(0xFF2A2D40),
      child: Container(
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ShimmerMovieCard extends StatelessWidget {
  const ShimmerMovieCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerLoading(width: 132, height: 198),
          SizedBox(height: 8),
          ShimmerLoading(width: 110, height: 14, borderRadius: 4),
          SizedBox(height: 4),
          ShimmerLoading(width: 80, height: 12, borderRadius: 4),
        ],
      ),
    );
  }
}

class ShimmerHeroCarousel extends StatefulWidget {
  const ShimmerHeroCarousel({super.key});

  @override
  State<ShimmerHeroCarousel> createState() => _ShimmerHeroCarouselState();
}

class _ShimmerHeroCarouselState extends State<ShimmerHeroCarousel> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E2030),
      highlightColor: const Color(0xFF2A2D40),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              width: double.infinity,
              color: AppTheme.bgCard,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: screenWidth * 0.7,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: screenWidth * 0.4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _shimmerPill(80),
                    const SizedBox(width: 8),
                    _shimmerPill(60),
                    const SizedBox(width: 8),
                    _shimmerPill(50),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerPill(double width) {
    return Container(
      width: width,
      height: 30,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }
}

class ShimmerMovieRail extends StatelessWidget {
  const ShimmerMovieRail({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Shimmer.fromColors(
            baseColor: const Color(0xFF1E2030),
            highlightColor: const Color(0xFF2A2D40),
            child: Container(
              width: 120,
              height: 18,
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 248,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 6,
            itemBuilder: (_, __) => const Padding(
              padding: EdgeInsets.only(right: 12),
              child: ShimmerMovieCard(),
            ),
          ),
        ),
      ],
    );
  }
}
