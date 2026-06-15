import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../movie_detail/movie_detail_screen.dart';

class ScheduleScreen extends StatefulWidget {
  final bool isTab;
  const ScheduleScreen({super.key, this.isTab = false});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> with AutomaticKeepAliveClientMixin {
  final Dio _dio = Dio();
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = false;
  String? _error;

  // Category filter
  String _currentFilter = 'all';

  @override
  bool get wantKeepAlive => widget.isTab; // Giữ state khi là tab

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() { _isLoading = true; _error = null; _currentFilter = 'all'; });
    try {
      final res = await _dio.get(
        '${AppConfig.apiUrl}/Schedule.php',
        queryParameters: {'day': 0},
      );
      final data = res.data as Map<String, dynamic>;
      final schedules = (data['schedules'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() { _schedules = schedules; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Không thể tải lịch chiếu'; _isLoading = false; });
    }
  }

  List<Map<String, dynamic>> get _filteredSchedules {
    if (_currentFilter == 'all') return _schedules;
    return _schedules.where((s) {
      final type = (s['type'] ?? '').toString();
      switch (_currentFilter) {
        case 'series': return type == 'series' || type == 'tvshows';
        case 'hoathinh': return type == 'hoathinh';
        default: return true;
      }
    }).toList();
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'series': return 'Phim Bộ';
      case 'hoathinh': return 'Anime';
      case 'tvshows': return 'TV Show';
      default: return t;
    }
  }

  String _filterLabel(String f) {
    switch (f) {
      case 'all': return 'Tất cả';
      case 'series': return 'Phim Bộ';
      case 'hoathinh': return 'Anime';
      default: return f;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Cần thiết cho AutomaticKeepAliveClientMixin
    final body = Column(
      children: [
        // Header "Hôm nay"
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Icon(Icons.today_rounded, size: 18, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(
                'Lịch chiếu hôm nay',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadSchedule,
                child: Icon(Icons.refresh_rounded, size: 20, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
        const Divider(color: AppTheme.border, height: 1),

        // Category filters
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            children: ['all', 'series', 'hoathinh'].map((f) {
              final active = _currentFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _currentFilter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? AppTheme.accent.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: active ? AppTheme.accent.withValues(alpha: 0.4) : AppTheme.border,
                      ),
                    ),
                    child: Text(
                      _filterLabel(f),
                      style: TextStyle(
                        color: active ? AppTheme.gold : AppTheme.textSub,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(color: AppTheme.border, height: 1),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
              : _error != null
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.calendar_today_outlined, size: 56, color: AppTheme.textMuted),
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: AppTheme.textSub)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _loadSchedule(),
                          child: const Text('Thử lại'),
                        ),
                      ]),
                    )
                  : _filteredSchedules.isEmpty
                      ? Center(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(
                              _schedules.isEmpty ? Icons.event_busy_outlined : Icons.search_off_outlined,
                              size: 56, color: AppTheme.textMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _schedules.isEmpty ? 'Không có lịch chiếu ngày này' : 'Không có phim thể loại này',
                              style: const TextStyle(color: AppTheme.textSub, fontSize: 15),
                            ),
                          ]),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadSchedule(),
                          color: AppTheme.accent,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredSchedules.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _filteredSchedules.length) return const SizedBox(height: 80);
                              return _buildScheduleCard(_filteredSchedules[index]);
                            },
                          ),
                        ),
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
          'Lịch Chiếu Phim',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: body,
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> s) {
    final isCompleted = s['is_completed'] == true;
    final airTime = s['air_time']?.toString() ?? '';
    final timeStr = airTime.isNotEmpty && airTime.contains(':')
        ? airTime.substring(0, 5)
        : '--:--';
    final quality = s['quality']?.toString() ?? '';
    final type = s['type']?.toString() ?? '';
    final note = s['note']?.toString() ?? '';
    final epCurrent = s['episode_current']?.toString() ?? '';
    final updatedEpisodes = (s['last_added_episodes'] ?? 0) as int;
    final countryName = s['country_name']?.toString() ?? '';
    final year = s['year'] as int?;

    final slug = s['slug']?.toString() ?? '';
    final name = s['name']?.toString() ?? '';
    final originName = s['origin_name']?.toString() ?? '';
    final thumbUrl = s['thumb_url']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MovieDetailScreen(
              movieId: s['id'] as int? ?? 0,
              slug: slug,
            ),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isCompleted ? AppTheme.border : AppTheme.border),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Poster
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    bottomLeft: Radius.circular(11),
                  ),
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: thumbUrl,
                        width: 100,
                        height: 150,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(width: 100, height: 150, color: AppTheme.bgCard),
                        errorWidget: (_, __, ___) => Container(
                          width: 100, height: 150, color: AppTheme.bgCard,
                          child: const Icon(Icons.movie, color: AppTheme.textMuted),
                        ),
                      ),
                      // Time badge
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xDD030306),
                            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.6)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.access_time_rounded, size: 10, color: AppTheme.gold),
                            const SizedBox(width: 3),
                            Text(
                              timeStr,
                              style: const TextStyle(color: AppTheme.gold, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ]),
                        ),
                      ),
                      if (isCompleted)
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Hoàn thành',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (originName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              originName,
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const SizedBox(height: 6),
                        // Pills row
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (quality.isNotEmpty)
                              _pill(quality, AppTheme.gold.withValues(alpha: 0.12), AppTheme.gold),
                            _pill(
                              _typeLabel(type),
                              AppTheme.accent.withValues(alpha: 0.1),
                              AppTheme.gold,
                            ),
                            if (countryName.isNotEmpty)
                              _pill(countryName, const Color(0x1A10B981), const Color(0xFF10B981)),
                            if (year != null && year > 0)
                              _pill('$year', const Color(0x1AFFFFFF), AppTheme.textSub),
                          ],
                        ),
                        // Note
                        if (note.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 12, color: AppTheme.gold.withValues(alpha: 0.8)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    note,
                                    style: TextStyle(color: AppTheme.gold.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Spacer(),
                        // Action row
                        Container(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Episode text
                              if (isCompleted)
                                const Row(children: [
                                  Icon(Icons.check_circle_rounded, size: 14, color: Colors.greenAccent),
                                  SizedBox(width: 4),
                                  Text('Hoàn thành', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w700)),
                                ])
                              else if (updatedEpisodes > 0)
                                Text(
                                  '+$updatedEpisodes tập mới',
                                  style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w700),
                                )
                              else
                                Text(
                                  epCurrent.isNotEmpty ? epCurrent : 'Đang ra',
                                  style: const TextStyle(color: AppTheme.textSub, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              // Play button
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgSurface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Xem phim',
                                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.play_arrow_rounded, size: 14, color: AppTheme.textPrimary),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _pill(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4), border: Border.all(color: fg.withValues(alpha: 0.2))),
      child: Text(label, style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}
