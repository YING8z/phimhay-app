import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phimhay_app/config/app_config.dart';
import 'package:phimhay_app/config/theme.dart';
import 'package:phimhay_app/models/movie.dart';
import 'package:phimhay_app/screens/movie_detail/movie_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final bool isTab;
  const SearchScreen({super.key, this.isTab = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final Dio _dio = Dio();
  Timer? _debounce;

  bool _isLoading = false;
  List<Movie> _results = [];
  List<String> _suggestions = [];
  bool _hasSearched = false;
  String _filterType = 'Phim';

  @override
  bool get wantKeepAlive => widget.isTab; // Giữ state khi là tab

  @override
  void initState() {
    super.initState();
    if (widget.isTab) return; // IndexedStack — không auto-focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (query.trim().isEmpty) {
        setState(() {
          _results = [];
          _hasSearched = false;
        });
        return;
      }
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final response = await _dio.get(
        '${AppConfig.apiUrl}/Search.php',
        queryParameters: {'q': query, 'type': _filterType == 'Phim' ? 'phim' : 'actor'},
      );
      final data = response.data;
      List<dynamic>? items;
      if (data is Map) {
        items = (data['movies'] ?? data['results']) as List<dynamic>?;
      }
      setState(() {
        _results = items?.map((e) => Movie.fromJson(e as Map<String, dynamic>)).toList() ?? [];
        _hasSearched = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _results = [];
        _hasSearched = true;
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _results = [];
      _hasSearched = false;
    });
    _searchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Cần thiết cho AutomaticKeepAliveClientMixin
    final body = Column(
      children: [
        const SizedBox(height: 12), // Thêm khoảng cách với navbar
        // Search input
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(999),
            ),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm phim yêu thích...',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 16),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 22),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppTheme.textMuted, size: 20),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        // Filter row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _filterChip('Phim', _filterType == 'Phim'),
              const SizedBox(width: 8),
              _filterChip('Diễn viên', _filterType == 'Diễn viên'),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Results / Empty state
        Expanded(
          child: _isLoading
              ? _buildLoadingState()
              : _hasSearched && _results.isEmpty
                  ? _buildEmptyState()
                  : _results.isNotEmpty
                      ? _buildResults()
                      : _buildInitialState(),
        ),
      ],
    );

    if (widget.isTab) return body;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tìm kiếm',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: body,
    );
  }

  Widget _filterChip(String label, bool active) {
    return GestureDetector(
      onTap: () {
        setState(() => _filterType = label);
        if (_searchCtrl.text.trim().isNotEmpty) {
          _performSearch(_searchCtrl.text.trim());
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? Colors.white : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : AppTheme.textSub,
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 72, color: AppTheme.textMuted.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'Tìm kiếm phim yêu thích',
            style: TextStyle(color: AppTheme.textSub, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hàng ngàn bộ phim đang chờ bạn',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 72, color: AppTheme.textMuted.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'Không tìm thấy kết quả',
            style: TextStyle(color: AppTheme.textSub, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Thử tìm kiếm với từ khóa khác',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // Tăng từ 2 lên 3 cột
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.58, // Giảm để card cao hơn, nhỏ hơn
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildResults() {
    return RefreshIndicator(
      onRefresh: () async {
        if (_searchCtrl.text.trim().isNotEmpty) {
          await _performSearch(_searchCtrl.text.trim());
        }
      },
      color: AppTheme.accent,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.58,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final movie = _results[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)));
                    },
                    child: _buildCompactMovieCard(movie),
                  );
                },
                childCount: _results.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  // Card nhỏ gọn cho search
  Widget _buildCompactMovieCard(Movie movie) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: movie.thumbUrl ?? movie.posterUrl ?? '',
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.bgCard,
                    child: const Icon(Icons.movie_outlined, color: AppTheme.textMuted, size: 24),
                  ),
                ),
                // Quality badge
                if ((movie.quality ?? '').isNotEmpty)
                  Positioned(
                    top: 4, right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xE6F5C518),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        movie.quality!.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF1A1100),
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          movie.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
