import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // Thêm import này cho ScrollDirection
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/movie.dart';
import '../../providers/home_provider.dart';
import '../../providers/watch_history_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/header.dart';
import '../../widgets/hero_carousel.dart';
import '../../widgets/movie_rail.dart';
import '../../widgets/chips.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/shimmer_loading.dart';
import '../movie_detail/movie_detail_screen.dart';
import '../search/search_screen.dart';
import '../list/list_screen.dart';
import '../schedule/schedule_screen.dart';
import '../profile/profile_screen.dart';
import '../watch_party/watch_party_screen.dart';
import '../notification/notification_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _navIndex;
  String _selectedChip = 'Đề xuất';
  final ScrollController _scrollController = ScrollController();
  bool _isScrollingDown = false;

  @override
  void initState() {
    super.initState();
    _navIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().fetchHome();
    });
  }

  /// Convert chip name → API filter param
  String _chipToFilter(String chip) {
    switch (chip) {
      case 'Phim bộ': return 'phim-bo';
      case 'Phim lẻ': return 'phim-le';
      case 'Thể loại ▾': return 'the-loai';
      default: return 'all'; // Đề xuất
    }
  }

  /// Gọi lại API khi đổi chip — giữ nguyên vị trí scroll
  void _onChipSelected(String chip) {
    if (chip == _selectedChip) return;
    setState(() => _selectedChip = chip);
    context.read<HomeProvider>().fetchHome(filter: _chipToFilter(chip));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _scrollUpDistance = 0;

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (delta > 0) {
        // Scroll xuống (delta > 0) → zoom ra + reset counter
        _scrollUpDistance = 0;
        if (!_isScrollingDown) setState(() => _isScrollingDown = true);
      } else if (delta < 0) {
        // Scroll lên (delta < 0) → tích lũy, chỉ zoom về khi đủ 200px
        _scrollUpDistance += delta.abs();
        if (_isScrollingDown && _scrollUpDistance > 200) {
          setState(() => _isScrollingDown = false);
        }
      }
    }
    return false;
  }

  void _onMovieTap(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
    );
  }

  void _onNavSelected(int index) {
    if (index == _navIndex) return;

    // Tab "Phim" (index 3) - navigate to last viewed movie
    if (index == 3) {
      final lastMovie = context.read<WatchHistoryProvider>().lastViewedMovie;
      if (lastMovie != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: lastMovie)),
        );
      } else {
        // Hiện thông báo chưa xem phim nào
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Bạn chưa xem phim nào cả',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: AppTheme.bgCard,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _navIndex = index;
      _isScrollingDown = false; // Reset về bình thường khi chuyển tab
    });
  }

  void _onMoreTap(String href, String title) {
    // Phân tích href: /danh-sach/phim-moi, /the-loai/hanh-dong, /quoc-gia/han-quoc
    final parts = href.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.length < 2) return;

    final category = parts[0]; // danh-sach, the-loai, quoc-gia
    final slug = parts[1];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListScreen(
          type: category == 'danh-sach' ? slug : category,
          title: title,
          genre: category == 'the-loai' ? slug : null,
          country: category == 'quoc-gia' ? slug : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // Nội dung tab — padding tránh Header & BottomNav
          NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: Padding(
              padding: EdgeInsets.only(
                top: topPad + 56,
              ),
              child: IndexedStack(
                index: _navIndex,
                children: [
                  _buildHomeTab(),
                  const SearchScreen(isTab: true),
                  const ScheduleScreen(isTab: true),
                  ListScreen(isTab: true),
                  const ProfileScreen(isTab: true),
                ],
              ),
            ),
          ),
          // Header cố định
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Header(
              onSearchTap: () => setState(() => _navIndex = 1), // Chuyển sang tab Tìm kiếm
              onWatchPartyTap: () {
                // Mở màn hình Watch Party (Xem chung)
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WatchPartyScreen()),
                );
              },
              onNotificationTap: () {
                // Mở màn hình Thông báo
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationScreen()),
                );
              },
              onAccountTap: () => setState(() => _navIndex = 4), // Chuyển sang tab Tài khoản
            ),
          ),
          // BottomNav lơ lửng với animation zoom
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedScale(
              scale: _isScrollingDown ? 0.85 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.bottomCenter,
              child: Builder(
                builder: (context) {
                  final auth = context.watch<AuthProvider>();
                  return BottomNav(
                    currentIndex: _navIndex,
                    onTabSelected: _onNavSelected,
                    avatarUrl: auth.isLoggedIn ? (auth.user?['avatar']?.toString()) : null,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return Consumer<HomeProvider>(builder: (context, provider, _) {
      if (provider.isLoading && provider.heroMovies.isEmpty) {
        return ListView(
          children: const [
            SizedBox(height: 12),
            ShimmerHeroCarousel(),
            SizedBox(height: 8),
            ShimmerMovieRail(),
            ShimmerMovieRail(),
          ],
        );
      }
      if (provider.error != null && provider.heroMovies.isEmpty) {
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text('Lỗi: ${provider.error}', style: const TextStyle(color: AppTheme.textSub)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => provider.fetchHome(), child: const Text('Thử lại')),
          ]),
        );
      }
      return RefreshIndicator(
        onRefresh: () {
          provider.invalidateCache();
          return provider.fetchHome(filter: provider.currentFilter, forceRefresh: true);
        },
        color: AppTheme.accent,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 6),
            HeroCarousel(movies: provider.heroMovies, onMovieTap: _onMovieTap),
            Chips(selectedChip: _selectedChip, onChipSelected: _onChipSelected),
            ...provider.sections.map((s) => MovieRail(
              title: s.title,
              moreHref: s.moreHref,
              movies: s.movies,
              showRank: s.rank,
              onMovieTap: _onMovieTap,
              onMoreTap: (href) => _onMoreTap(href, s.title),
            )),
            const SizedBox(height: 80), // Spacer cho BottomNav
          ],
        ),
      );
    });
  }
}
