import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:phimhay_app/config/app_config.dart';
import 'package:phimhay_app/config/theme.dart';
import 'package:phimhay_app/models/movie.dart';
import 'package:phimhay_app/providers/auth_provider.dart';
import 'package:phimhay_app/providers/favorite_provider.dart';
import 'package:phimhay_app/providers/reminder_provider.dart';
import 'package:phimhay_app/providers/watch_history_provider.dart';
import 'package:phimhay_app/screens/watch/watch_screen.dart';
import 'package:phimhay_app/screens/notification/notification_screen.dart';
import 'package:phimhay_app/services/api_client.dart';
import 'package:phimhay_app/services/movie_service.dart';
import 'package:phimhay_app/widgets/movie_rail.dart';
import 'package:phimhay_app/widgets/shimmer_loading.dart';
import 'package:phimhay_app/widgets/header.dart';
import 'package:phimhay_app/widgets/bottom_nav.dart';
import 'package:phimhay_app/widgets/noise_overlay.dart';
import 'package:phimhay_app/screens/home/home_screen.dart';
import 'package:phimhay_app/screens/watch_party/watch_party_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final int movieId;
  final String? slug;
  final Movie? movie;

  const MovieDetailScreen({
    super.key,
    this.movieId = 0,
    this.slug,
    this.movie,
  }) : assert(movieId > 0 || movie != null, 'Either movieId or movie must be provided');

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Dio _dio = Dio();
  int _navIndex = 3;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _movieData;
  List<dynamic> _episodes = [];
  bool _isLoggedIn = false; // Auth state — quyết định có check nguồn server hay không

  // BottomNav zoom
  bool _isScrollingDown = false;
  double _scrollUpDistance = 0;
  List<dynamic> _servers = [];
  List<dynamic> _comments = [];
  List<Movie> _relatedMovies = [];
  int _selectedServer = 0;

  // Watch progress — "Xem tiếp"
  final MovieService _movieService = MovieService();
  Map<String, dynamic>? _watchProgress; // {episode_id, ep_slug, server_idx, position, duration, ep_name}

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _isLoggedIn = Provider.of<AuthProvider>(context, listen: false).isLoggedIn;
    _fetchMovieDetail();

    // Lưu movie vào history
    if (widget.movie != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<WatchHistoryProvider>().setLastViewed(widget.movie!);
      });
    }
    // Load reminders from server
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        context.read<ReminderProvider>().fetchReminders();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchMovieDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final movieId = widget.movieId > 0 ? widget.movieId : (widget.movie?.id ?? 0);

    // Use passed-in movie data directly if available
    if (widget.movie != null) {
      _movieData = widget.movie!.toJson();
    }

    try {
      final slug = widget.slug ?? widget.movie?.slug ?? '';
      final endpoint = slug.isNotEmpty
          ? '${AppConfig.apiUrl}/movie_detail.php?slug=$slug'
          : '${AppConfig.apiUrl}/movie_detail.php?slug=${widget.movie?.slug ?? ''}';
      final response = await _dio.get(endpoint);
      final data = response.data is String
          ? jsonDecode(response.data) as Map<String, dynamic>
          : response.data as Map<String, dynamic>;

      if (data['movie'] != null) {
        _movieData = data['movie'] as Map<String, dynamic>;

        // servers + episodes nằm TRONG movie object (theo movie_detail.php)
        final movieObj = _movieData!;
        final rawServers = movieObj['servers'] as List<dynamic>? ?? [];
        final rawEpisodes = movieObj['episodes'] as List<dynamic>? ?? [];

        // Nếu servers trống, thử lấy từ top-level (backward compat)
        _servers  = rawServers.isNotEmpty  ? rawServers  : (data['servers']  as List<dynamic>? ?? []);
        _episodes = rawEpisodes.isNotEmpty ? rawEpisodes : (data['episodes'] as List<dynamic>? ?? []);
      } else {
        _servers  = data['servers']  as List<dynamic>? ?? [];
        _episodes = data['episodes'] as List<dynamic>? ?? [];
      }

      _comments = data['comments'] as List<dynamic>? ?? [];
      final related = data['related'] as List<dynamic>? ?? [];
      _relatedMovies = related
          .map((e) => Movie.fromJson(e as Map<String, dynamic>))
          .toList();
      _isLoading = false;
    } on DioException catch (e) {
      debugPrint('MovieDetail error: ${e.message} | ${e.response?.data}');
      if (_movieData == null) {
        _error = 'Không thể tải thông tin phim';
      } else {
        _error = null;
      }
      _isLoading = false;
    }
    if (mounted) setState(() {});

    // Không check server health — tất cả nguồn đều sống (mobile HLS chạy được hết)

    // Fetch watch progress — "Xem tiếp"
    _fetchWatchProgress(movieId);
  }

  /// Fetch health status từ movie_episodes.php — merge vào _servers theo index
  Future<void> _fetchServerHealth(int movieId) async {
    if (movieId <= 0) return;
    try {
      final res = await _dio.get(
        '${AppConfig.apiUrl}/movie_episodes.php',
        queryParameters: {'movie_id': movieId},
      );
      final data = res.data as Map<String, dynamic>;
      final rawServers = (data['servers'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ?? [];

      if (mounted && rawServers.isNotEmpty && _servers.isNotEmpty) {
        setState(() {});
      }
    } catch (_) {
      // ignore — health là bonus, không ảnh hưởng chức năng chính
    }
  }

  void _onNavSelected(int index) {
    if (index == _navIndex) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(initialIndex: index)),
    );
  }

  /// Tạo room xem chung trực tiếp từ phim chi tiết
  Future<void> _createWatchParty() async {
    final movieId = widget.movieId > 0 ? widget.movieId : (widget.movie?.id ?? (_movieData?['id'] as int? ?? 0));
    if (movieId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy phim'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // Lấy episode đầu tiên (nếu có)
    dynamic firstEp;
    if (_servers.isNotEmpty) {
      final eps = _servers[_selectedServer]['episodes'] as List<dynamic>? ?? [];
      if (eps.isNotEmpty) firstEp = eps[0];
    }
    final epId = firstEp?['id'] ?? 1;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
    );

    try {
      final res = await ApiClient.post(
        '/watch_party.php',
        data: FormData.fromMap({
          'action': 'create_room',
          'movie_id': movieId,
          'episode_id': epId,
        }),
      );
      if (mounted) Navigator.pop(context);

      final data = res.data;
      if (data['success'] == true && data['room_code'] != null) {
        final roomCode = data['room_code'];
        final cookies = await ApiClient.cookieJar.loadForRequest(Uri.parse(AppConfig.baseUrl));
        final cookieManager = CookieManager.instance();
        for (var cookie in cookies) {
          await cookieManager.setCookie(url: WebUri(AppConfig.baseUrl), name: cookie.name, value: cookie.value);
        }
        if (mounted) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(backgroundColor: AppTheme.bg, title: const Text('Phòng xem chung', style: TextStyle(fontSize: 16)), elevation: 0),
              body: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri('${AppConfig.baseUrl}/phong-xem.php?code=$roomCode')),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  supportZoom: false,
                  useWideViewPort: true,
                  loadWithOverviewMode: true,
                ),
                onPermissionRequest: (controller, request) async {
                  return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT,
                  );
                },
              ),
            ),
          ));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Không thể tạo phòng'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi kết nối'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (delta > 0) {
        _scrollUpDistance = 0;
        if (!_isScrollingDown) setState(() => _isScrollingDown = true);
      } else if (delta < 0) {
        _scrollUpDistance += delta.abs();
        if (_isScrollingDown && _scrollUpDistance > 200) {
          setState(() => _isScrollingDown = false);
        }
      }
    }
    return false;
  }

  /// Fetch watch progress từ server — hiển thị banner "Tiếp tục xem"
  Future<void> _fetchWatchProgress(int movieId) async {
    if (movieId <= 0) return;
    try {
      final progress = await _movieService.getWatchProgress(movieId);
      if (progress != null && mounted) {
        final epSlug = (progress['ep_slug'] as String?) ?? '';
        final epId = progress['episode_id'];
        // Hiển thị nếu có episode (id hoặc slug) — không cần pos >= 15
        if (epSlug.isNotEmpty || (epId != null && epId > 0)) {
          setState(() => _watchProgress = progress);
        }
      }
    } catch (_) {
      // Ignore — progress là bonus, không ảnh hưởng chính
    }
  }

  /// Format giây → chuỗi thời gian (giống web formatWatchPosition)
  String _formatPosition(int seconds) {
    if (seconds < 1) return '00:00';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Banner "Tiếp tục xem" — giống web phim.php watch-resume-banner
  Widget _buildResumeBanner(Movie movie) {
    final progress = _watchProgress!;
    final rawEpName = (progress['ep_name'] as String?) ?? '';
    // Bỏ prefix "Tập " nếu có (tránh "Tập Tập 01")
    final epName = rawEpName.replaceAll(RegExp(r'^[Tt]ậ?p?\s*', caseSensitive: false), '').trim();
    final position = (progress['position'] as int?) ?? 0;
    final duration = (progress['duration'] as int?) ?? 0;
    final serverIdx = (progress['server_idx'] as int?) ?? 0;

    // Tính % đã xem
    int percent = 0;
    if (duration > 0) {
      percent = (position / duration * 100).round().clamp(0, 100);
    }

    final movieId = widget.movieId > 0 ? widget.movieId : (widget.movie?.id ?? (_movieData?['id'] as int? ?? 0));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFE11D48), Color(0xFF9F1239)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _resumeWatch(movieId, serverIdx),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon play
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tiếp tục xem',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${epName.isNotEmpty ? 'Tập $epName' : 'Phim'}  •  ${_formatPosition(position)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // Progress bar
                      if (percent > 0) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: percent / 100,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Nút "Xem tiếp"
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Xem tiếp',
                    style: TextStyle(
                      color: Color(0xFF9F1239),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Nhảy đến đúng tập + server + vị trí khi nhấn "Xem tiếp"
  void _resumeWatch(int movieId, int savedServerIdx) {
    final progress = _watchProgress!;
    final savedEpId = progress['episode_id'];
    final savedEpSlug = (progress['ep_slug'] as String?) ?? '';
    final slug = widget.movie?.slug ?? (_movieData?['slug'] ?? '');
    final title = widget.movie?.name ?? (_movieData?['name'] ?? '');

    // Tìm episode từ danh sách đã fetch
    dynamic targetEp;
    if (_servers.isNotEmpty) {
      // Ưu tiên server đã lưu
      final serverIdx = savedServerIdx < _servers.length ? savedServerIdx : 0;
      final eps = _servers[serverIdx]['episodes'] as List<dynamic>? ?? [];
      for (final ep in eps) {
        final epSlug = (ep['ep_slug'] ?? ep['slug'] ?? '').toString();
        final epId = ep['id'];
        if (epSlug == savedEpSlug || epId == savedEpId) {
          targetEp = ep;
          break;
        }
      }
      // Fallback: tìm ở tất cả servers
      if (targetEp == null) {
        for (final server in _servers) {
          final eps = server['episodes'] as List<dynamic>? ?? [];
          for (final ep in eps) {
            final epSlug = (ep['ep_slug'] ?? ep['slug'] ?? '').toString();
            final epId = ep['id'];
            if (epSlug == savedEpSlug || epId == savedEpId) {
              targetEp = ep;
              break;
            }
          }
          if (targetEp != null) break;
        }
      }
    }

    // Fallback cuối: dùng URL trang web
    String url = '';
    if (targetEp != null) {
      final embed = (targetEp['link_embed'] ?? '').toString().trim();
      final m3u8 = (targetEp['link_m3u8'] ?? '').toString().trim();
      url = embed.isNotEmpty ? embed : m3u8;
    }
    if (url.isEmpty) {
      url = '${AppConfig.baseUrl}/phim/$slug';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WatchScreen(
          movieId: movieId,
          episodeId: targetEp?['id'] ?? savedEpId ?? 1,
          serverIdx: savedServerIdx,
          streamUrl: url,
          movieSlug: slug,
          movieTitle: title,
          initialPosition: (progress['position'] as int?) ?? 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // Nội dung chính — CustomScrollView chứa banner + content
          RefreshIndicator(
            onRefresh: _fetchMovieDetail,
            color: AppTheme.accent,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // Spacer cho header (56px) + statusBar
                  SliverToBoxAdapter(
                    child: SizedBox(height: statusBarHeight + 56),
                  ),
                  // Banner
                  if (!_isLoading && _error == null && _movieData != null)
                    SliverToBoxAdapter(
                      child: _buildHeader(Movie.fromJson(_movieData!)),
                    ),
                  // Content
                  if (_isLoading)
                    SliverFillRemaining(child: _buildLoading())
                  else if (_error != null)
                    SliverFillRemaining(child: _buildError())
                  else
                    SliverToBoxAdapter(child: _buildContent()),
                  // Bottom padding cho BottomNav
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 80),
                  ),
                ],
              ),
            ),
          ),
          // Header cố định
          Positioned(
            top: 0, left: 0, right: 0,
            child: Header(
              onSearchTap: () => _onNavSelected(1),
              onWatchPartyTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WatchPartyScreen())),
              onNotificationTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
              },
              onAccountTap: () => _onNavSelected(4),
            ),
          ),
          // BottomNav với zoom animation
          Positioned(
            bottom: 0, left: 0, right: 0,
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

  Widget _buildLoading() {
    return Column(
      children: [
        Container(height: 12), // gap under Header
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: const [
                ShimmerLoading(width: double.infinity, height: 220),
                SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: ShimmerLoading(width: double.infinity, height: 22, borderRadius: 4),
                ),
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: ShimmerLoading(width: 200, height: 16, borderRadius: 4),
                ),
                SizedBox(height: 24),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: ShimmerLoading(width: double.infinity, height: 120, borderRadius: 8),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        Container(height: 12), // gap under Header
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 56, color: AppTheme.textMuted),
                  const SizedBox(height: 16),
                  const Text(
                    'Không thể tải thông tin phim',
                    style: TextStyle(color: AppTheme.textSub, fontSize: 15),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _fetchMovieDetail,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.gold,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Thử lại',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_movieData == null) return _buildError();
    final movie = Movie.fromJson(_movieData!);
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      children: [
        // Tabs
        Container(
          color: AppTheme.bg,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.gold,
            indicatorWeight: 3,
            labelColor: AppTheme.gold,
            unselectedLabelColor: AppTheme.textSub,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            dividerColor: AppTheme.border,
            tabs: const [
              Tab(text: 'Nội dung'),
              Tab(text: 'Tập phim'),
              Tab(text: 'Bình luận'),
              Tab(text: 'Liên quan'),
            ],
          ),
        ),
        // Tab content — dùng SizedBox thay vì Expanded (vì nằm trong CustomScrollView)
        SizedBox(
          height: screenHeight * 0.6,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildContentTab(movie),
              _buildEpisodesTab(),
              _buildCommentsTab(),
              _buildRelatedTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(Movie movie) {
    return Stack(
      children: [
        // Backdrop
        SizedBox(
          height: 300,
          child: Stack(
            children: [
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: movie.posterUrl ?? '',
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                  placeholder: (_, __) => Container(color: AppTheme.bgCard),
                  errorWidget: (_, __, ___) => Container(color: AppTheme.bgCard),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xF70D0F14)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Movie info overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Poster
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: movie.thumbUrl ?? '',
                    width: 100,
                    height: 150,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppTheme.bgCard),
                    errorWidget: (_, __, ___) => Container(
                      color: AppTheme.bgCard,
                      child: const Icon(Icons.movie, color: AppTheme.textMuted),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Title + badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        movie.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if ((movie.originName ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            movie.originName!,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (movie.imdbRating != null && movie.imdbRating! > 0)
                            _detailPill('IMDb ${movie.imdbRating}', const Color(0xFFF5C518), Colors.black),
                          if ((movie.quality ?? '').isNotEmpty)
                            _detailPill(movie.quality ?? '', const Color(0xFF4CAF50), Colors.white),
                          if (movie.year != null && movie.year! > 0)
                            _detailPill('${movie.year}', const Color(0x33FFFFFF), Colors.white70),
                          if ((movie.type ?? '').isNotEmpty)
                            _detailPill(movie.type!, const Color(0x33FFFFFF), Colors.white70),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailPill(String label, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _backButton() {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
      onPressed: () => Navigator.pop(context),
    );
  }

  /// Action bar nổi trên banner — chỉ nút back
  Widget _buildActionBar(Movie movie) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          _backButton(),
        ],
      ),
    );
  }

  // --- Content Tab ---
  Widget _buildContentTab(Movie movie) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner "Tiếp tục xem" ──
          if (_watchProgress != null) _buildResumeBanner(movie),

          // Xem ngay — full width
          _actionBtn(
            label: 'Xem ngay',
            icon: Icons.play_arrow_rounded,
            bgColor: null,
            isGold: true,
            textColor: const Color(0xFF1A1100),
            onTap: () {
              // Lấy tập đầu tiên từ server đang chọn
              dynamic firstEp;
              if (_servers.isNotEmpty) {
                final eps = _servers[_selectedServer]['episodes'] as List<dynamic>? ?? [];
                if (eps.isNotEmpty) firstEp = eps[0];
              }
              if (firstEp == null && _episodes.isNotEmpty) {
                firstEp = _episodes[0];
              }
              if (firstEp != null) {
                _tapEpisode(firstEp, 0);
              } else {
                // Phim lẻ — không có tập, mở trang phim
                final slug  = widget.movie?.slug ?? (_movieData?['slug'] ?? '');
                final title = widget.movie?.name ?? (_movieData?['name'] ?? '');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WatchScreen(
                      movieId:    widget.movie?.id ?? (_movieData?['id'] as int? ?? 0),
                      episodeId:  1,
                      streamUrl:  '${AppConfig.baseUrl}/phim/$slug',
                      movieSlug:  slug,
                      movieTitle: title,
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          // Yêu thích + Nhắc nhở
          Row(
            children: [
              Expanded(
                child: Consumer<FavoriteProvider>(
                  builder: (_, fav, __) => _actionBtn(
                    label: fav.isFavorite(movie.id) ? 'Đã yêu thích' : 'Yêu thích',
                    icon: fav.isFavorite(movie.id)
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    iconColor: fav.isFavorite(movie.id) ? Colors.redAccent : AppTheme.textPrimary,
                    bgColor: const Color(0x1AFFFFFF),
                    textColor: AppTheme.textPrimary,
                    onTap: () => fav.toggleFavorite(movie),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Consumer<ReminderProvider>(
                  builder: (_, rem, __) {
                    final movieSlug = movie.slug ?? (_movieData?['slug'] ?? '') as String;
                    final isReminded = rem.reminders.any((r) => r['slug'] == movieSlug);
                    return _actionBtn(
                      label: isReminded ? 'Đã bật nhắc nhở' : 'Nhắc nhở',
                      icon: isReminded
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_outlined,
                      iconColor: isReminded ? AppTheme.gold : AppTheme.textPrimary,
                      bgColor: const Color(0x1AFFFFFF),
                      textColor: AppTheme.textPrimary,
                      onTap: () async {
                        final auth = context.read<AuthProvider>();
                        if (!auth.isLoggedIn) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Vui lòng đăng nhập để bật nhắc nhở'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        final success = await rem.toggleReminder(
                          movie.id,
                          movieSlug,
                          movie.name,
                          movie.thumbUrl ?? '',
                        );
                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isReminded
                                    ? 'Đã tắt nhắc nhở cho "$movie.name"'
                                    : 'Đã bật nhắc nhở cho "$movie.name"',
                              ),
                              backgroundColor: const Color(0xFF2E7D32),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Description
          const Text(
            'Nội dung phim',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if ((movie.description ?? '').isNotEmpty)
            Text(
              // strip &nbsp; HTML entities
              movie.description!.replaceAll('&nbsp;', ' ').replaceAll(RegExp(r'<[^>]*>'), '').trim(),
              style: const TextStyle(color: AppTheme.textSub, fontSize: 14, height: 1.65),
            ),
          const SizedBox(height: 24),

          // Info table
          const Text(
            'Thông tin phim',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                if ((movie.time ?? '').isNotEmpty && movie.time != '--')
                  _infoRow(Icons.timer_outlined, 'Thời lượng', movie.time!),
                _infoRow(Icons.calendar_today_outlined, 'Năm phát hành', movie.year != null ? '${movie.year}' : '--'),
                _infoRow(Icons.high_quality_outlined, 'Chất lượng', movie.quality ?? '--'),
                _infoRow(Icons.remove_red_eye_outlined, 'Lượt xem', movie.viewCount > 0 ? _formatViews(movie.viewCount) : '--'),
                _infoRow(Icons.translate_rounded, 'Ngôn ngữ', movie.lang ?? '--'),
                // Số tập
                if ((movie.episodeCurrent ?? '').isNotEmpty)
                  _infoRow(Icons.format_list_numbered_rounded, 'Số tập', _episodeText(movie)),
                // Quốc gia
                if (_countriesText().isNotEmpty)
                  _infoRow(Icons.public_rounded, 'Quốc gia', _countriesText()),
                // Diễn viên
                if (_actorsText().isNotEmpty)
                  _infoRow(Icons.people_outline_rounded, 'Diễn viên', _actorsText()),
                if (movie.imdbRating != null && movie.imdbRating! > 0)
                  _infoRow(Icons.star_outline_rounded, 'IMDb', movie.imdbRating!.toStringAsFixed(1)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 80), // Spacer cho BottomNav
        ],
      ),
    );
  }

  String _formatViews(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }

  String _episodeText(Movie movie) {
    final current = movie.episodeCurrent ?? '';
    final total = movie.episodeTotal ?? '';

    // "Hoàn thành (37/37)" → giữ nguyên
    if (current.contains('Hoàn thành')) return current;

    // "37/37" hoặc "37 / 37" → đã hoàn thành, chỉ lấy số đầu
    if (current.contains('/')) {
      final parts = current.split('/');
      final epNum = parts[0].trim().replaceAll(RegExp(r'[^0-9]'), '');
      if (epNum.isNotEmpty && total.isNotEmpty) return '$epNum / $total';
      if (epNum.isNotEmpty) return epNum;
    }

    // Chỉ trả số, không thêm "tập" (vì label đã có "Số tập")
    final currentNum = current.replaceAll(RegExp(r'[^0-9]'), '');
    if (currentNum.isNotEmpty && total.isNotEmpty) return '$currentNum / $total';
    if (currentNum.isNotEmpty) return currentNum;
    if (total.isNotEmpty) return total;
    return '--';
  }

  String _countriesText() {
    final countries = _movieData?['countries'];
    if (countries is List && countries.isNotEmpty) {
      return countries.map((c) => c['name']?.toString() ?? '').where((s) => s.isNotEmpty).join(', ');
    }
    return '';
  }

  String _actorsText() {
    // Ưu tiên actor_vi (đã dịch Hán Việt từ API)
    final actorVi = _movieData?['actor_vi'];
    if (actorVi is String && actorVi.trim().isNotEmpty) return actorVi.trim();
    // Fallback: actor raw
    final raw = _movieData?['actor'] ?? _movieData?['actors'] ?? _movieData?['casts'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).join(', ');
    }
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    // Fallback từ Movie model
    final movie = Movie.fromJson(_movieData!);
    if (movie.actors != null && movie.actors!.isNotEmpty) {
      return movie.actors!.join(', ');
    }
    return '';
  }

  Widget _actionBtn({
    required String label,
    IconData? icon,
    Color? iconColor,
    required Color? bgColor,
    required Color textColor,
    bool isGold = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: isGold
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFE59A), Color(0xFFF5C84C)],
                )
              : null,
          color: isGold ? null : bgColor,
          borderRadius: BorderRadius.circular(999),
          border: isGold ? null : Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: iconColor ?? textColor),
              const SizedBox(width: 8),
            ],
            Text(label, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // --- Episodes Tab ---
  Widget _buildEpisodesTab() {
    if (_servers.isEmpty && _episodes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 56, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text('Chưa có tập phim nào', style: TextStyle(color: AppTheme.textSub, fontSize: 14)),
          ],
        ),
      );
    }

    // Episodes của server đang chọn — API trả ep_name + link_m3u8
    final currentEps = _servers.isNotEmpty && _selectedServer < _servers.length
        ? (_servers[_selectedServer]['episodes'] as List<dynamic>? ?? [])
        : _episodes;

    return Column(
      children: [
        // Server selector — hiện cho mọi user
        if (_servers.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _servers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isActive = index == _selectedServer;
                final sName  = (_servers[index]['server_name'] ?? 'Server ${index + 1}').toString();

                return GestureDetector(
                  onTap: () => setState(() => _selectedServer = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isActive ? AppTheme.accent : AppTheme.border,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      // Dot xanh — tất cả đều sống
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        sName,
                        style: TextStyle(
                          color: isActive ? const Color(0xFF1A1100) : AppTheme.textSub,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),

        if (_servers.isNotEmpty)
          const Divider(color: AppTheme.border, height: 1),

        // Episode grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(14),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
            ),
            itemCount: currentEps.length,
            itemBuilder: (context, index) {
              final ep = currentEps[index];
              // API trả về ep_name — bỏ prefix "Tập " nếu có
              final rawName = ep is Map
                  ? (ep['ep_name'] ?? ep['name'] ?? '${index + 1}').toString()
                  : '${index + 1}';
              final epName = rawName.replaceAll(RegExp(r'^[Tt]ậ?p?\s*', caseSensitive: false), '').trim();
              return GestureDetector(
                onTap: () => _tapEpisode(ep, index),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Center(
                    child: Text(
                      epName,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _tapEpisode(dynamic ep, int index) {
    final epId = ep is Map ? (ep['id'] ?? index) : index;
    final slug  = widget.movie?.slug ?? (_movieData?['slug'] ?? '');
    final title = widget.movie?.name ?? (_movieData?['name'] ?? '');

    // Ưu tiên link_embed, fallback link_m3u8, fallback trang web
    String url = '';
    if (ep is Map) {
      final embed = (ep['link_embed'] ?? '').toString().trim();
      final m3u8  = (ep['link_m3u8']  ?? '').toString().trim();
      url = embed.isNotEmpty ? embed : m3u8;
    }
    if (url.isEmpty) {
      url = '${AppConfig.baseUrl}/phim/$slug';
    }

    final movieId = widget.movieId > 0
        ? widget.movieId
        : (widget.movie?.id ?? (_movieData?['id'] as int? ?? 0));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WatchScreen(
          movieId:    movieId,
          episodeId:  epId,
          serverIdx:  _selectedServer,
          streamUrl:  url,
          movieSlug:  slug,
          movieTitle: title,
        ),
      ),
    );
  }

  // --- Comments Tab ---
  Widget _buildCommentsTab() {
    return Column(
      children: [
        // Add comment
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.bgCard,
                child: Icon(Icons.person_outline, color: AppTheme.textMuted, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Viết bình luận...',
                      hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.send_rounded, color: AppTheme.gold, size: 22),
            ],
          ),
        ),
        const Divider(color: AppTheme.border, height: 1),
        // Comments list
        Expanded(
          child: _comments.isEmpty
              ? const Center(
                  child: Text(
                    'Chưa có bình luận nào',
                    style: TextStyle(color: AppTheme.textSub, fontSize: 14),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _comments.length,
                  separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 1),
                  itemBuilder: (context, index) {
                    final comment = _comments[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.bgCard,
                        child: const Icon(Icons.person, color: AppTheme.textMuted, size: 18),
                      ),
                      title: Text(
                        comment['user'] ?? 'Người dùng',
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        comment['content'] ?? '',
                        style: const TextStyle(color: AppTheme.textSub, fontSize: 13),
                      ),
                      trailing: Text(
                        comment['time'] ?? '',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- Related Tab ---
  Widget _buildRelatedTab() {
    if (_relatedMovies.isEmpty) {
      return const Center(
        child: Text(
          'Không có phim liên quan',
          style: TextStyle(color: AppTheme.textSub, fontSize: 14),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16, bottom: 100), // Thêm padding bottom ở đây
      child: MovieRail(
        title: 'Phim liên quan',
        movies: _relatedMovies,
        onMovieTap: (movie) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MovieDetailScreen(movie: movie),
            ),
          );
        },
      ),
    );
  }
}

