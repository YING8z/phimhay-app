import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phimhay_app/config/theme.dart';
import 'package:phimhay_app/models/movie.dart';

class HeroCarousel extends StatefulWidget {
  final List<Movie> movies;
  final ValueChanged<Movie>? onMovieTap;

  const HeroCarousel({super.key, required this.movies, this.onMovieTap});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  // Kích thước card — khớp với mobile web: clamp(168px, 46vw, 220px)
  static const double _viewportFraction = 0.36;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: _viewportFraction,
      initialPage: 0,
    );
    // Không có autoplay theo yêu cầu
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) => setState(() => _currentPage = page);

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();

    final screenW = MediaQuery.of(context).size.width;
    // Card width tính theo viewportFraction
    final slideW = screenW * _viewportFraction;
    // Chiều cao card = width * 1.5 (ratio 2:3)
    final slideH = slideW * 1.5;
    // Tổng chiều cao section carousel (thêm padding top/bottom để card giữa nổi hơn)
    final sectionH = slideH + 20;

    final m = widget.movies[_currentPage];

    return Column(
      children: [
        // ── Carousel ──
        SizedBox(
          height: sectionH,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.movies.length,
            itemBuilder: (context, index) {
              final movie = widget.movies[index];
              final isActive = index == _currentPage;

              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, _) {
                  // Tính offset của slide so với trang hiện tại
                  final pageOffset = _pageController.position.haveDimensions
                      ? (_pageController.page ?? _currentPage.toDouble()) - index
                      : _currentPage.toDouble() - index;

                  // Scale: giữa = 1.0, bên cạnh = 0.86
                  final scale = (1.0 - pageOffset.abs() * 0.14).clamp(0.86, 1.0);

                  // Góc xoay 3D theo trục Y — giống hiệu ứng coverflow
                  // Slide bên trái nghiêng sang phải (+angle), bên phải nghiêng sang trái (-angle)
                  final rotateY = pageOffset.clamp(-1.0, 1.0) * 0.32; // ~18 độ tối đa

                  // Dịch lên xuống: slide active cao hơn, bên cạnh thấp hơn
                  final translateY = pageOffset.abs() * 8.0; // Giảm độ hạ sâu của các card bên cạnh

                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // perspective
                      ..rotateY(-rotateY)
                      ..scale(scale)
                      ..translate(0.0, translateY),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: GestureDetector(
                        onTap: () {
                          if (isActive) {
                            // Card đang active → mở chi tiết phim
                            widget.onMovieTap?.call(movie);
                          } else {
                            // Card không active → scroll đến card đó
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isActive
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : Colors.white.withValues(alpha: 0.15),
                              width: 2,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      blurRadius: 48,
                                      offset: const Offset(0, 20),
                                    ),
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.06),
                                      blurRadius: 24,
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.55),
                                      blurRadius: 32,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AspectRatio(
                              aspectRatio: 2 / 3,
                              child: CachedNetworkImage(
                                imageUrl: (movie.thumbUrl?.isNotEmpty == true) ? movie.thumbUrl! : (movie.posterUrl ?? ''),
                                fit: BoxFit.cover,
                                memCacheWidth: 600,
                                cacheKey: '${movie.slug}_${movie.id}_hero_v2', // bust cache
                                placeholder: (_, __) => Container(color: AppTheme.bgCard),
                                errorWidget: (_, __, ___) => Container(
                                  color: AppTheme.bgCard,
                                  child: const Icon(Icons.movie, color: AppTheme.textMuted),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // ── Dots ── .m-hero-dots
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.movies.length, (i) {
              final active = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active ? AppTheme.accent : AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(active ? 4 : 999),
                  border: Border.all(
                    color: active ? AppTheme.accent : AppTheme.border,
                  ),
                ),
              );
            }),
          ),
        ),

        // ── Info panel ── .m-hero-info-wrap
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(
            children: [
              // Title
              Text(
                m.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              // Origin
              if ((m.originName ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    m.originName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSub),
                  ),
                ),
              const SizedBox(height: 14),
              // Buttons
              Row(children: [
                Expanded(
                  child: _HeroBtn(
                    label: 'Xem phim',
                    icon: Icons.play_arrow_rounded,
                    primary: true,
                    onTap: () => widget.onMovieTap?.call(m),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HeroBtn(
                    label: 'Thông tin',
                    icon: Icons.info_outline,
                    primary: false,
                    onTap: () => widget.onMovieTap?.call(m),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              // Pills
              Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  if (m.imdbRating != null && m.imdbRating! > 0)
                    _HeroPill(label: 'IMDb ${m.imdbRating!.toStringAsFixed(1)}', gold: true),
                  if ((m.quality ?? '').isNotEmpty)
                    _HeroPill(label: m.quality!.toUpperCase()),
                  if (m.year != null && m.year! > 0)
                    _HeroPill(label: '${m.year}'),
                  if ((m.type ?? '').isNotEmpty && m.type != 'single')
                    _HeroPill(label: _typeLabel(m.type!)),
                  if ((m.episodeCurrent ?? '').isNotEmpty)
                    _HeroPill(label: m.episodeCurrent!),
                ],
              ),
              // Description
              if ((m.description ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    m.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSub,
                      height: 1.55,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'series': return 'Phim bộ';
      case 'hoathinh': return 'Hoạt hình';
      case 'tvshows': return 'TV Shows';
      default: return t;
    }
  }
}

// ── Buttons ──────────────────────────────────────────────────
class _HeroBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback? onTap;

  const _HeroBtn({
    required this.label,
    required this.icon,
    required this.primary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFE59A), Color(0xFFF5C84C)],
                )
              : null,
          color: primary ? null : AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(999),
          border: primary ? null : Border.all(color: AppTheme.border),
          boxShadow: primary
              ? [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.18), blurRadius: 22, offset: const Offset(0, 10))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: primary ? const Color(0xFF1A1A1A) : AppTheme.textPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: primary ? const Color(0xFF1A1A1A) : AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pills ─────────────────────────────────────────────────────
class _HeroPill extends StatelessWidget {
  final String label;
  final bool gold;

  const _HeroPill({required this.label, this.gold = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: gold ? const Color(0x26F5C518) : AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: gold ? const Color(0x66F5C518) : AppTheme.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: gold ? AppTheme.accent : AppTheme.textSub,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
