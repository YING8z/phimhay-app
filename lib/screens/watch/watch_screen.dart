import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:dio/dio.dart';
import 'package:media_kit/media_kit.dart' show Player, Media;
import 'package:media_kit_video/media_kit_video.dart' show Video, VideoController, NoVideoControls;
import 'package:phimhay_app/config/app_config.dart';
import 'package:phimhay_app/config/theme.dart';
import 'package:phimhay_app/providers/auth_provider.dart';
import 'package:phimhay_app/services/api_client.dart';
import 'package:provider/provider.dart';
import 'package:phimhay_app/services/movie_service.dart';
import 'package:phimhay_app/widgets/bottom_nav.dart';
import 'package:phimhay_app/widgets/header.dart';
import 'package:phimhay_app/screens/home/home_screen.dart';
import 'package:phimhay_app/screens/watch_party/watch_party_screen.dart';
import 'package:phimhay_app/screens/search/search_screen.dart';
import 'package:phimhay_app/screens/notification/notification_screen.dart';
import 'package:phimhay_app/screens/watch_room/watch_room_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Loại player hiện tại
enum _PlayerMode { hls, embed }

class WatchScreen extends StatefulWidget {
  final int movieId;
  final dynamic episodeId;   // id của episode đang phát
  final int serverIdx;
  final String? streamUrl;   // fallback nếu API không có
  final String? movieSlug;
  final String? movieTitle;
  final int initialPosition; // Giây đã xem (để seek khi mở)

  const WatchScreen({
    super.key,
    required this.movieId,
    required this.episodeId,
    this.serverIdx = 0,
    this.streamUrl,
    this.movieSlug,
    this.movieTitle,
    this.initialPosition = 0,
  });

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> with WidgetsBindingObserver {
  final Dio _dio = Dio();
  final MovieService _movieService = MovieService();
  InAppWebViewController? _webController;
  Player? _hlsPlayer;
  VideoController? _videoController;
  static const _pipChannel = MethodChannel('phimhay/pip');
  bool _pipAvailable = false;

  bool _isLoading = true;
  String? _error;
  _PlayerMode _playerMode = _PlayerMode.embed;
  String _currentUrl = '';

  // Danh sách servers + episodes lấy từ API
  List<Map<String, dynamic>> _servers = [];
  List<Map<String, dynamic>> _flatEps = [];
  int _selectedServer = 0;
  dynamic _currentEpId;
  String _currentEpName = '';

  // Controls overlay
  bool _showControls = true;
  bool _showSkipIntro = false;
  StreamSubscription<Duration>? _positionSub;
  bool _playerReady = false; // true khi media đã load xong
  StreamSubscription<bool>? _playingSub;

  // Custom player controls (giống watch room host controls)
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  static const List<double> _speeds = [0.5, 1.0, 1.5, 2.0, 3.0];
  double _volume = 100.0;
  bool _isMuted = false;
  bool _isDragging = false;
  bool _showVolumeInline = false;
  double _dragValue = 0;
  int _lastPositionUpdate = 0;
  Duration _currentPos = Duration.zero;
  Duration _currentDur = Duration.zero;

  // Đồng hồ hiện thị giờ VN (luôn hiện, không ẩn theo tap)
  Timer? _clockTimer;

  // Watch progress tracking
  Timer? _saveProgressTimer;
  int _currentPosition = 0;
  int _currentDuration = 0;
  Map<String, dynamic>? _savedProgress;

  @override
  void initState() {
    super.initState();
    _checkPipAvailability();
    WidgetsBinding.instance.addObserver(this);
    _currentEpId = widget.episodeId;
    _showControlsWithAutoHide(); // hiện controls khi vào, auto ẩn sau 4s
    // Bắt đầu đồng hồ VN — tick mỗi 200ms để không bị lệch giờ
    _clockTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
    _selectedServer = widget.serverIdx;

    // Nếu có initialPosition → dùng ngay, không cần load từ API
    if (widget.initialPosition > 0) {
      _currentPosition = widget.initialPosition;
    }

    _fetchEpisodes();
    _loadWatchProgress();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  // ── Load watch progress từ DB ────────────────────────
  Future<void> _loadWatchProgress() async {
    if (widget.movieId <= 0) return;
    try {
      final progress = await _movieService.getWatchProgress(widget.movieId);
      if (progress != null && mounted) {
        _savedProgress = progress;
        // Chỉ override position nếu không có initialPosition
        if (widget.initialPosition <= 0) {
          _currentPosition = (progress['position'] as int?) ?? 0;
        }
        _currentDuration = (progress['duration'] as int?) ?? 0;

        // Nếu episodes đã load xong mà chưa restore → restore ngay
        if (_servers.isNotEmpty) {
          setState(() => _restoreFromProgress());
        }
      }
    } catch (_) {}
  }

  // ── Restore server/episode từ saved progress (gọi sau khi có episodes) ──
  void _restoreFromProgress() {
    final progress = _savedProgress;
    if (progress == null || _servers.isEmpty) return;

    final savedSourceUrl = (progress['source_url'] as String?)?.trim() ?? '';
    final savedEpId = progress['episode_id'];
    final savedServerIdx = (progress['server_idx'] as int?) ?? 0;

    // Ưu tiên 1: Match source_url chính xác
    if (savedSourceUrl.isNotEmpty) {
      for (int si = 0; si < _servers.length; si++) {
        final eps = (_servers[si]['episodes'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        for (final ep in eps) {
          final m3u8 = (ep['link_m3u8'] ?? '').toString().trim();
          final embed = (ep['link_embed'] ?? '').toString().trim();
          if (m3u8 == savedSourceUrl || embed == savedSourceUrl) {
            _selectedServer = si;
            _currentEpId = ep['id'];
            return;
          }
        }
      }
    }

    // Ưu tiên 2: Match episode_id trên bất kỳ server nào
    if (savedEpId != null && savedEpId > 0) {
      for (int si = 0; si < _servers.length; si++) {
        final eps = (_servers[si]['episodes'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        final found = eps.where((e) => e['id'] == savedEpId).toList();
        if (found.isNotEmpty) {
          _selectedServer = si;
          _currentEpId = savedEpId;
          return;
        }
      }
    }

    // Fallback: dùng server_idx cũ
    if (savedServerIdx > 0 && savedServerIdx < _servers.length) {
      _selectedServer = savedServerIdx;
    }
  }

  // ── Save watch progress định kỳ ────────────────────
  void _startProgressTimer() {
    _saveProgressTimer?.cancel();
    _saveProgressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _saveCurrentProgress();
    });
  }

  // Lưu progress ngay lập tức với position cho trước (dùng khi chuyển server)
  Future<void> _saveProgressImmediate(int position) async {
    if (widget.movieId <= 0) return;
    if (_watchRoomActive) return;

    String? epSlug;
    final eps = _currentServerEps;
    for (final ep in eps) {
      if (ep['id'] == _currentEpId) {
        epSlug = (ep['ep_slug'] ?? ep['slug'] ?? '').toString();
        break;
      }
    }

    await _movieService.saveWatchProgress(
      movieId: widget.movieId,
      episodeId: _currentEpId is int ? _currentEpId : null,
      epSlug: epSlug,
      serverIdx: _selectedServer,
      position: position,
      duration: _currentDuration,
      sourceType: _playerMode == _PlayerMode.hls ? 'hls' : 'embed',
      sourceUrl: _currentUrl,
    );
  }

  Future<void> _saveCurrentProgress() async {
    if (widget.movieId <= 0) return;
    // Watch room đang mở → không lưu (tránh ghi đè)
    if (_watchRoomActive) return;
    // Chưa seek xong → không lưu
    if (!_seekCompleted && _currentPosition > 15) return;
    int pos = 0;
    int dur = 0;
    if (_playerMode == _PlayerMode.hls && _hlsPlayer != null) {
      pos = _hlsPlayer!.state.position.inSeconds;
      dur = _hlsPlayer!.state.duration.inSeconds;
    } else if (_playerMode == _PlayerMode.embed && _webController != null) {
      try {
        final posResult = await _webController!.evaluateJavascript(
          source: "document.querySelector('video')?.currentTime || 0",
        );
        if (posResult != null) pos = (posResult as num).toInt();
        final durResult = await _webController!.evaluateJavascript(
          source: "document.querySelector('video')?.duration || 0",
        );
        if (durResult != null) dur = (durResult as num).toInt();
      } catch (_) {}
    }

    // Tìm ep_slug từ episode hiện tại
    String? epSlug;
    final eps = _currentServerEps;
    for (final ep in eps) {
      if (ep['id'] == _currentEpId) {
        epSlug = (ep['ep_slug'] ?? ep['slug'] ?? '').toString();
        break;
      }
    }

    // Luôn lưu (kể cả pos = 0) để cập nhật episode + server
    await _movieService.saveWatchProgress(
      movieId: widget.movieId,
      episodeId: _currentEpId is int ? _currentEpId : null,
      epSlug: epSlug,
      serverIdx: _selectedServer,
      position: pos,
      duration: dur > 0 ? dur : _currentDuration,
      sourceType: _playerMode == _PlayerMode.hls ? 'hls' : 'embed',
      sourceUrl: _currentUrl,
    );

    // Cập nhật vị trí đã lưu
    _lastSavedPosition = pos;
  }

  // ── Save khi thoát ───────────────────────────────────
  Future<void> _saveProgressOnExit() async {
    _saveProgressTimer?.cancel();
    await _saveCurrentProgress();
  }

  Future<void> _checkPipAvailability() async {
    try {
      _pipAvailable = await _pipChannel.invokeMethod('isPipAvailable') ?? false;
    } catch (_) {
      _pipAvailable = false;
    }
    // Lắng nghe callback từ iOS native
    _pipChannel.setMethodCallHandler((call) async {
      if (call.method == 'onPipStarted') {
        debugPrint('PiP: native callback — pausing main video');
        _hlsPlayer?.pause();
      }
    });
    if (mounted) setState(() {});
  }

  bool _pipActive = false; // Guard: PiP đang active → không auto start lại
  Timer? _pipPollTimer;   // Poll PiP position mỗi 1s

  /// Bắt đầu poll PiP position (gọi khi PiP start)
  void _startPipPoll() {
    _pipPollTimer?.cancel();
    _pipPollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final isActive = await _pipChannel.invokeMethod('isPipActive') ?? false;
        if (!isActive && _pipActive) {
          // PiP đã tắt → lấy position cuối cùng → seek video chính
          _pipActive = false;
          _pipPollTimer?.cancel();
          final position = await _pipChannel.invokeMethod('getPipPosition') ?? 0.0;
          debugPrint('PiP: ★★ poll detected stopped — position=$position');
          if (position > 0 && _hlsPlayer != null) {
            await _hlsPlayer!.seek(Duration(seconds: (position as double).toInt()));
            _hlsPlayer!.play();
            debugPrint('PiP: ★★ seeked to ${position}s and playing');
          }
        }
      } catch (_) {}
    });
  }

  /// Setup PiP controller — gọi 1 lần khi video load xong (iOS cần AVPlayer sẵn)
  Future<void> _setupPip() async {
    if (!_pipAvailable || _currentUrl.isEmpty) return;
    // Pass vị trí hiện tại để PiP không chạy từ đầu
    final position = _hlsPlayer?.state.position.inSeconds.toDouble() ?? 0;
    try {
      await _pipChannel.invokeMethod('setupPip', {
        'url': _currentUrl,
        'position': position,
      });
    } catch (_) {}
  }

  /// Bật PiP — pass vị trí hiện tại + bắt đầu poll position
  Future<void> _startPip() async {
    final position = _hlsPlayer?.state.position.inSeconds.toDouble() ?? 0;
    _pipActive = true;
    try {
      final result = await _pipChannel.invokeMethod('startPip', {'position': position});
      debugPrint('PiP: startPip result=$result, position=$position');
      _startPipPoll();
    } catch (e) {
      debugPrint('PiP: startPip ERROR=$e');
      _pipActive = false;
    }
  }

  /// Update PiP URL khi chuyển tập
  Future<void> _updatePipUrl() async {
    if (!_pipAvailable || _currentUrl.isEmpty) return;
    try {
      await _pipChannel.invokeMethod('updatePipUrl', {'url': _currentUrl});
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Quay lại app → restore audio session + volume
      if (_hlsPlayer != null) {
        // Restore volume theo user setting
        _hlsPlayer!.setVolume(_isMuted ? 0.0 : _volume);
      }

      // Quay lại app → nếu PiP vừa tắt → seek video đến vị trí mới
      if (_pipActive) {
        _pipActive = false;
        _pipPollTimer?.cancel();
        _pipChannel.invokeMethod('getPipPosition').then((pos) {
          final position = (pos as double?) ?? 0;
          if (position > 0 && _hlsPlayer != null) {
            _hlsPlayer!.seek(Duration(seconds: position.toInt())).then((_) {
              _hlsPlayer!.setVolume(_isMuted ? 0.0 : _volume);
              _hlsPlayer!.play();
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    _autoHideControlsTimer?.cancel();
    _clockTimer?.cancel();
    _positionSub?.cancel();
    _playingSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _saveProgressOnExit();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _hlsPlayer?.dispose();
    _webController?.dispose();
    super.dispose();
  }

  // ── Fetch episodes ────────────────────────────────
  Future<void> _fetchEpisodes() async {
    if (widget.movieId <= 0) {
      _initFallbackPlayer();
      return;
    }
    try {
      final res = await _dio.get(
        '${AppConfig.apiUrl}/movie_episodes.php',
        queryParameters: {'movie_id': widget.movieId},
      );
      final data = res.data as Map<String, dynamic>;
      final rawServers  = (data['servers']  as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final rawEpisodes = (data['episodes'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

      if (!mounted) return;

      _servers = rawServers;
      _flatEps = rawEpisodes;

      // Không check health — tất cả nguồn đều sống (mobile HLS chạy được hết)
      // Reset status từ DB → tất cả là 'ok'
      for (final s in _servers) {
        s['status'] = 'ok';
      }

      if (_selectedServer >= _servers.length) _selectedServer = 0;

      setState(() {});

      // Restore server/episode từ saved progress (sau khi có episodes)
      _restoreFromProgress();

      _initPlayerFromEpisode();
    } catch (_) {
      if (!mounted) return;
      _initFallbackPlayer();
    }
  }

  void _initFallbackPlayer() {
    final url = (widget.streamUrl ?? '').trim();
    if (url.isNotEmpty) {
      _currentUrl = url;
      final isM3u8 = url.contains('.m3u8');
      if (isM3u8) _initHlsPlayer(url);
      if (mounted) setState(() { _playerMode = isM3u8 ? _PlayerMode.hls : _PlayerMode.embed; _isLoading = false; });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initPlayerFromEpisode() {
    final eps = _currentServerEps;
    Map<String, dynamic>? currentEp;
    if (eps.isNotEmpty) {
      try {
        currentEp = eps.firstWhere(
          (e) => e['id'] == _currentEpId || e['ep_name'] == _currentEpId,
        );
      } catch (_) {}
      currentEp ??= eps.isNotEmpty ? eps[0] : null;
    }

    if (currentEp != null) {
      _currentEpId = currentEp['id'];
      _currentEpName = (currentEp['ep_name'] ?? currentEp['name'] ?? '').toString();
      final m3u8 = (currentEp['link_m3u8'] ?? '').toString().trim();
      final embed = (currentEp['link_embed'] ?? '').toString().trim();
      _currentEmbedUrl = embed; // lưu để fallback khi HLS fail

      // Ưu tiên HLS cho tất cả (mobile chạy được hết)
      if (m3u8.isNotEmpty) {
        _currentUrl = m3u8;
        _initHlsPlayer(m3u8);
        if (mounted) setState(() { _playerMode = _PlayerMode.hls; _isLoading = false; });
      } else if (embed.isNotEmpty) {
        _currentUrl = embed;
        if (mounted) setState(() { _playerMode = _PlayerMode.embed; _isLoading = false; });
      } else {
        _initFallbackPlayer();
      }
    } else {
      _initFallbackPlayer();
    }
  }

  Timer? _healthCheckTimer;
  String _currentEmbedUrl = ''; // fallback embed URL cho episode hiện tại

  int _lastSavedPosition = 0; // Track vị trí đã lưu để detect seek
  bool _seekCompleted = false; // Flag để track seek đã hoàn thành
  bool _watchRoomActive = false; // Watch room đang mở → chặn save
  StreamSubscription<Duration>? _durationSub; // Lắng nghe duration

  void _initHlsPlayer(String url) {
    _hlsPlayer ??= Player();
    _videoController ??= VideoController(_hlsPlayer!);
    _healthCheckTimer?.cancel();
    _positionSub?.cancel();
    _playingSub?.cancel();
    _durationSub?.cancel();
    _playerReady = false;
    _seekCompleted = _currentPosition <= 15; // Nếu không cần seek → true ngay

    // Lắng nghe position để hiện/ẩn skip intro + detect seek + update custom controls
    _positionSub = _hlsPlayer!.stream.position.distinct().listen((pos) {
      final shouldShow = pos.inSeconds >= 10 && pos.inSeconds <= 120;
      if (shouldShow != _showSkipIntro && mounted) {
        setState(() => _showSkipIntro = shouldShow);
      }

      // Update custom controls position (throttle UI update mỗi 500ms)
      if (mounted && !_isDragging) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastPositionUpdate > 500) {
          _lastPositionUpdate = now;
          _currentPos = pos;
          setState(() {});
        }
      }

      // Detect seek: nếu position nhảy > 5s so với lần lưu trước → lưu ngay
      final diff = (pos.inSeconds - _lastSavedPosition).abs();
      if (diff > 5 && pos.inSeconds > 0) {
        _lastSavedPosition = pos.inSeconds;
        _saveCurrentProgress();
      }
    });

    // Lắng nghe playing state → hiện Video khi bắt đầu phát + update custom controls
    // CHẶN auto-play nếu chưa seek xong
    _playingSub = _hlsPlayer!.stream.playing.listen((playing) {
      if (playing && !_playerReady && mounted) {
        setState(() => _playerReady = true);
      }
      // Nếu đang play nhưng chưa seek xong → pause lại
      if (playing && !_seekCompleted && mounted) {
        _hlsPlayer!.pause();
      }
      // Update custom controls
      if (mounted) {
        setState(() => _isPlaying = playing);
      }
    });

    // Lắng nghe duration → media đã load xong → seek ngay + update custom controls
    _durationSub = _hlsPlayer!.stream.duration.distinct().listen((dur) {
      if (dur.inSeconds > 0 && !_seekCompleted && _currentPosition > 15 && mounted) {
        _seekToPosition();
      }
      // Update custom controls duration
      if (mounted) {
        setState(() => _currentDur = dur);
      }
    });

    // Buffering listener - chỉ play khi seek đã hoàn thành
    _hlsPlayer!.stream.buffering.listen((buffering) {
      if (!buffering && mounted && !_hlsPlayer!.state.playing && _seekCompleted) {
        _hlsPlayer!.play();
      }
    });

    // Web: dùng proxy để tránh CORS | Mobile: dùng URL trực tiếp
    final mediaUrl = kIsWeb ? AppConfig.proxyHlsUrl(url) : url;
    final mediaHeaders = kIsWeb
        ? <String, String>{} // Proxy đã handle headers
        : {
            'Referer': AppConfig.baseUrl,
            'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
          };

    _hlsPlayer!.open(
      Media(mediaUrl, httpHeaders: mediaHeaders),
    ).then((_) {
      if (!mounted) return;
      _playerReady = true;
      setState(() => _isLoading = false);

      // Setup PiP controller (iOS) — tạo AVPlayer sẵn khi video load
      _setupPip();

      // Nếu không cần seek → play ngay
      if (_currentPosition <= 15) {
        _seekCompleted = true;
        _hlsPlayer!.play();
      }
      // Nếu cần seek → đợi duration listener xử lý

      _startProgressTimer();
      _reportHealth('ok');
    }).catchError((e) {
      _fallbackToEmbed();
    });

    // Health check: nếu sau 8s player vẫn stuck ở 0 → fallback embed
    _healthCheckTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || _hlsPlayer == null) return;
      final pos = _hlsPlayer!.state.position.inSeconds;
      final playing = _hlsPlayer!.state.playing;
      if (pos == 0 && !playing) {
        _fallbackToEmbed();
      }
    });
  }

  /// Seek đến _currentPosition - gọi khi duration đã available
  Future<void> _seekToPosition() async {
    if (_seekCompleted || _currentPosition <= 15) return;

    // Pause để chặn auto-play
    _hlsPlayer!.pause();
    await Future.delayed(const Duration(milliseconds: 200));

    // Seek
    await _hlsPlayer!.seek(Duration(seconds: _currentPosition));
    await Future.delayed(const Duration(milliseconds: 300));

    // Seek xong → cho phép save + play
    _seekCompleted = true;
    if (mounted) {
      _hlsPlayer!.play();
    }
  }

  /// HLS fail → thử server khác (logged in) hoặc embed (logged out)
  void _fallbackToEmbed() {
    _healthCheckTimer?.cancel();
    if (!mounted) return;

    // Fallback embed trước, nếu không có → thử server khác
    if (_currentEmbedUrl.isNotEmpty) {
      setState(() {
        _playerMode = _PlayerMode.embed;
        _currentUrl = _currentEmbedUrl;
        _isLoading = true;
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('HLS không khả dụng, chuyển sang chế độ nhúng...'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      _markBrokenAndSwitch();
    }
  }

  void _reportHealth(String status) {
    if (_servers.isEmpty || _selectedServer >= _servers.length) return;
    final serverName = _servers[_selectedServer]['server_name']?.toString() ?? '';
    if (serverName.isEmpty) return;
    _movieService.saveServerHealth(
      movieId: widget.movieId,
      episodeId: _currentEpId is int ? _currentEpId : null,
      serverName: serverName,
      status: status,
    );
  }

  void _markBrokenAndSwitch() {
    if (!mounted || _servers.isEmpty) return;

    for (int i = 0; i < _servers.length; i++) {
      if (i == _selectedServer) continue;
      setState(() {
        _selectedServer = i;
        _isLoading = true;
        _error = null;
      });
      _initPlayerFromEpisode();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nguồn lỗi, chuyển sang ${_servers[i]['server_name'] ?? 'nguồn khác'}...'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _error = 'Tất cả nguồn đều không hoạt động');
  }

  // ── Lấy episodes của server đang chọn ─────────────
  List<Map<String, dynamic>> get _currentServerEps {
    if (_servers.isNotEmpty && _selectedServer < _servers.length) {
      return (_servers[_selectedServer]['episodes'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ?? [];
    }
    if (_flatEps.isNotEmpty) {
      final sname = _servers.isNotEmpty
          ? (_servers[_selectedServer]['server_name'] ?? '')
          : '';
      if (sname.isNotEmpty) {
        return _flatEps.where((e) => e['server_name'] == sname).toList();
      }
      return _flatEps;
    }
    return [];
  }

  // ── Chuyển server — giữ nguyên vị trí xem ─────────
  void _switchServer(int newServerIdx) {
    if (newServerIdx == _selectedServer) return;
    if (newServerIdx < 0 || newServerIdx >= _servers.length) return;

    // Lấy vị trí hiện tại TRƯỚC KHI chuyển server
    int currentPosition = 0;
    if (_playerMode == _PlayerMode.hls && _hlsPlayer != null) {
      currentPosition = _hlsPlayer!.state.position.inSeconds;
    } else if (_playerMode == _PlayerMode.embed && _webController != null) {
      currentPosition = _currentPosition;
    }
    if (currentPosition <= 0) currentPosition = _currentPosition;

    // Lưu progress ngay lập tức (bypass _seekCompleted check)
    _saveProgressImmediate(currentPosition);

    // Tìm tập tương ứng trên server mới (theo ep_slug hoặc index)
    final currentEps = _currentServerEps;
    Map<String, dynamic>? matchingEp;

    if (_currentEpId != null && currentEps.isNotEmpty) {
      // Tìm tập đang xem trên server cũ
      final currentEp = currentEps.where((e) => e['id'] == _currentEpId).toList();
      if (currentEp.isNotEmpty) {
        final currentSlug = (currentEp.first['ep_slug'] ?? '').toString();
        final currentIndex = currentEps.indexOf(currentEp.first);

        // Tìm trên server mới theo ep_slug trước
        final newEps = (_servers[newServerIdx]['episodes'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ?? [];
        if (currentSlug.isNotEmpty) {
          final bySlug = newEps.where((e) => e['ep_slug'] == currentSlug).toList();
          if (bySlug.isNotEmpty) matchingEp = bySlug.first;
        }
        // Fallback: tìm theo index
        if (matchingEp == null && currentIndex < newEps.length) {
          matchingEp = newEps[currentIndex];
        }
      }
    }

    setState(() {
      _selectedServer = newServerIdx;
      _currentPosition = currentPosition; // Giữ nguyên vị trí
    });

    // Nếu tìm thấy tập tương ứng → chuyển và giữ nguyên vị trí
    if (matchingEp != null) {
      _switchEpisode(matchingEp, keepPosition: true);
    }
  }

  // ── Chuyển tập ────────────────────────────────────
  void _switchEpisode(Map<String, dynamic> ep, {bool keepPosition = false}) {
    // Lưu progress tập hiện tại trước khi chuyển
    if (!keepPosition) _saveCurrentProgress();

    final epId = ep['id'];
    final m3u8 = (ep['link_m3u8'] ?? '').toString().trim();
    final embed = (ep['link_embed'] ?? '').toString().trim();
    _currentEmbedUrl = embed; // lưu để fallback

    // Ưu tiên HLS cho tất cả (mobile chạy được hết)
    final bool useHls = m3u8.isNotEmpty;
    final String url = m3u8.isNotEmpty ? m3u8 : embed;

    if (url.isEmpty) return;

    setState(() {
      _currentEpId = epId;
      _currentEpName = (ep['ep_name'] ?? ep['name'] ?? '').toString();
      _isLoading = true;
      _error = null;
      _currentUrl = url;
      _playerReady = false;
      _playerMode = useHls ? _PlayerMode.hls : _PlayerMode.embed;
      if (!keepPosition) {
        _currentPosition = 0; // Reset position cho tập mới
        _lastSavedPosition = 0;
      }
    });

    if (useHls) {
      _hlsPlayer?.stop(); // Dừng player cũ
      _initHlsPlayer(url);
      // Update PiP URL cho iOS (chuyển tập → PiP cũng phải update)
      _updatePipUrl();
    }

    // Tắt loading sau một khoảng thời gian ngắn hoặc khi player sẵn sàng
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  // Auto ẩn controls sau 4s
  Timer? _autoHideControlsTimer;
  void _showControlsWithAutoHide() {
    _autoHideControlsTimer?.cancel();
    setState(() => _showControls = true);
    _autoHideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  // ── Build ──────────────────────────────────────────
  final GlobalKey _playerKey = GlobalKey();
  bool _isLandscape = false;

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    // Auto fullscreen khi xoay ngang
    if (isLandscape != _isLandscape) {
      _isLandscape = isLandscape;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isLandscape) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: !isLandscape,
        child: isLandscape
            ? Stack(children: [
                Positioned.fill(child: _buildPlayer()),
                Positioned(
                  top: 8, left: 8,
                  child: GestureDetector(
                    onTap: () {
                      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
                      Future.delayed(const Duration(milliseconds: 300), () {
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitUp,
                          DeviceOrientation.landscapeLeft,
                          DeviceOrientation.landscapeRight,
                        ]);
                      });
                    },
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),
                // Episode selector button (bên phải giữa màn hình)
                if (_showControls && _servers.isNotEmpty)
                  Positioned(
                    top: 0, bottom: 0, right: 12,
                    child: Center(
                      child: GestureDetector(
                        onTap: _showEpisodeSheet,
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(Icons.list_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                  ),
              ])
            : Column(children: [
                // Header
                Header(
                  onSearchTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                  onWatchPartyTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WatchPartyScreen())),
                  onNotificationTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
                  onAccountTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen(initialIndex: 4))),
                ),
                // Player
                AspectRatio(aspectRatio: 16 / 9, child: _buildPlayer()),
                // Info + Episodes (padding đáy cho BottomNav)
                Expanded(
                  child: Stack(
                    children: [
                      _buildInfoAndEpisodes(),
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Builder(
                          builder: (context) {
                            final auth = context.watch<AuthProvider>();
                            return BottomNav(
                              currentIndex: 3,
                              onTabSelected: (index) {
                                if (index == 3) return;
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => HomeScreen(initialIndex: index)),
                                );
                              },
                              avatarUrl: auth.isLoggedIn ? (auth.user?['avatar']?.toString()) : null,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
      ),
    );
  }

  Future<void> _createWatchParty() async {
    final movieId = widget.movieId;
    final epId = _currentEpId;
    if (movieId <= 0) return;

    // DỪNG video trước, rồi lấy position
    if (_playerMode == _PlayerMode.hls && _hlsPlayer != null) {
      _hlsPlayer!.pause();
      await Future.delayed(const Duration(milliseconds: 200));
    } else if (_playerMode == _PlayerMode.embed && _webController != null) {
      try {
        await _webController!.evaluateJavascript(
          source: "document.querySelector('video')?.pause();",
        );
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (_) {}
    }

    // Lấy position SAU khi pause
    int pos = 0;
    if (_playerMode == _PlayerMode.hls && _hlsPlayer != null) {
      pos = _hlsPlayer!.state.position.inSeconds;
    } else if (_playerMode == _PlayerMode.embed && _webController != null) {
      try {
        final r = await _webController!.evaluateJavascript(
          source: "document.querySelector('video')?.currentTime || 0",
        );
        if (r != null) pos = (r as num).toInt();
      } catch (_) {}
    }

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
          'position': pos,
        }),
      );
      if (mounted) Navigator.pop(context);
      final data = res.data;
      if (data['success'] == true && data['room_code'] != null) {
        final roomCode = data['room_code'];

        // Chặn save + dừng timer/listener
        _watchRoomActive = true;
        _saveProgressTimer?.cancel();
        _positionSub?.cancel();
        _playingSub?.cancel();
        await _saveCurrentProgress();

        // Pause player NGAY
        _hlsPlayer?.pause();
        _webController?.evaluateJavascript(
          source: "document.querySelector('video')?.pause();",
        );

        // Mở WatchRoomScreen native — truyền position để seek ngay
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WatchRoomScreen(roomCode: roomCode, initialPosition: pos),
            ),
          );

          // Quay lại từ watch party → reload progress mới nhất + seek
          if (mounted) {
            _watchRoomActive = false;
            _startProgressTimer();
            await _loadWatchProgress();
            if (_hlsPlayer != null && _currentPosition > 3) {
              _seekCompleted = false;
              await _hlsPlayer!.seek(Duration(seconds: _currentPosition));
              _seekCompleted = true;
              _lastSavedPosition = _currentPosition;
            }
          }
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Không thể tạo phòng')));
      }
    } catch (e) {
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi kết nối'))); }
    }
  }

  // ── Info + Episodes (chỉ hiện ở portrait) ─────────
  Widget _buildInfoAndEpisodes() {
    return Column(
      children: [
        // Info bar
        Container(
          color: const Color(0xFF0D0F14),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.movieTitle ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Nút xem chung
              GestureDetector(
                onTap: _createWatchParty,
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.people_outline_rounded, color: AppTheme.accent, size: 14),
                    const SizedBox(width: 4),
                    const Text('Xem chung', style: TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
              // Badge player mode
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _playerMode == _PlayerMode.hls ? Colors.green.withValues(alpha: 0.2) : const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _playerMode == _PlayerMode.hls ? 'HLS' : 'Embed',
                  style: TextStyle(
                    color: _playerMode == _PlayerMode.hls ? Colors.greenAccent : Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Server selector — hiện cho mọi user
        if (_servers.length > 1) _buildServerSelector(),
        const Divider(color: Color(0x22FFFFFF), height: 1),
        // Episode list header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Row(
            children: [
              const Text('Chọn tập', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              const Spacer(),
            ],
          ),
        ),
        // Episodes grid
        Expanded(
          child: _buildEpisodeGrid(),
        ),
      ],
    );
  }

  // ── Player — hybrid HLS / WebView ─────────────────
  Widget _buildPlayer() {
    return Stack(
        fit: StackFit.expand,
        children: [
          // ── HLS native player (media_kit) — dùng NoVideoControls, custom controls bên dưới ──
          if (_playerMode == _PlayerMode.hls && _videoController != null && _playerReady)
            SizedBox.expand(
              child: Video(controller: _videoController!, controls: NoVideoControls),
            ),

          // ── Black overlay khi PiP đang active — ẩn video gốc ──
          if (_pipActive)
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.picture_in_picture_rounded, color: Colors.white38, size: 48),
                  SizedBox(height: 8),
                  Text('Đang phát trong PiP', style: TextStyle(color: Colors.white54, fontSize: 14)),
                ]),
              ),
            ),

          // ── Buffering indicator (hiện khi HLS đang load nhưng chưa phát) ──
          if (_playerMode == _PlayerMode.hls && _hlsPlayer != null && !_playerReady && !_isLoading)
            const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 3),
                SizedBox(height: 12),
                Text('Đang tải video...', style: TextStyle(color: Colors.white54, fontSize: 13)),
              ]),
            ),

          // ── WebView embed ──
          if (_playerMode == _PlayerMode.embed && _error == null)
            InAppWebView(
              key: ValueKey('embed_$_currentEpId'),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                allowUniversalAccessFromFileURLs: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                useWideViewPort: true,
                loadWithOverviewMode: true,
                builtInZoomControls: false,
                displayZoomControls: false,
              ),
              initialUrlRequest: URLRequest(
                url: WebUri(_currentUrl.isNotEmpty
                    ? _currentUrl
                    : widget.streamUrl ?? '${AppConfig.baseUrl}/phim/${widget.movieSlug ?? ''}'),
              ),
              onWebViewCreated: (c) => _webController = c,
              onLoadStart: (_, __) { if (mounted) setState(() => _isLoading = true); },
              onLoadStop:  (_, __) {
                if (mounted) setState(() => _isLoading = false);
                if (_currentPosition > 15 && _webController != null) {
                  _webController!.evaluateJavascript(
                    source: "var v=document.querySelector('video'); if(v){v.currentTime=$_currentPosition; v.play().catch(()=>{});}",
                  );
                }
                _startProgressTimer();
                _reportHealth('ok');
              },
              onReceivedError: (_, __, ___) {
                if (mounted) setState(() { _error = 'Không thể tải video'; _isLoading = false; });
              },
            ),

          // ── Gesture zones: trái (tap+double-tap = lùi 10s), giữa (tap = toggle), phải (tap+double-tap = tới 10s) ──
          if (_playerMode == _PlayerMode.hls && _playerReady)
            Row(
              children: [
                // LEFT zone: tap = lùi 10s, double-tap = lùi 10s
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      final pos = _hlsPlayer?.state.position ?? Duration.zero;
                      _hlsPlayer?.seek(pos - const Duration(seconds: 10));
                      if (!_showControls) _showControlsWithAutoHide();
                    },
                    onDoubleTap: () {
                      final pos = _hlsPlayer?.state.position ?? Duration.zero;
                      _hlsPlayer?.seek(pos - const Duration(seconds: 10));
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
                // CENTER zone: tap = toggle controls
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      if (_showControls) {
                        setState(() => _showControls = false);
                        _autoHideControlsTimer?.cancel();
                      } else {
                        _showControlsWithAutoHide();
                      }
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
                // RIGHT zone: tap = tới 10s, double-tap = tới 10s
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      final pos = _hlsPlayer?.state.position ?? Duration.zero;
                      _hlsPlayer?.seek(pos + const Duration(seconds: 10));
                      if (!_showControls) _showControlsWithAutoHide();
                    },
                    onDoubleTap: () {
                      final pos = _hlsPlayer?.state.position ?? Duration.zero;
                      _hlsPlayer?.seek(pos + const Duration(seconds: 10));
                    },
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),

          // ── Custom overlay controls ──
          if (_showControls && _playerMode == _PlayerMode.hls && _playerReady) ...[
            // Rewind/Forward icons — căn giữa mỗi nửa video (chỉ visual)
            IgnorePointer(
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                  const Expanded(child: SizedBox()), // trống giữa cho play/pause
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Play/Pause ở giữa
            Center(child: _buildCenterControls()),
            // Bottom bar: timeline + time + speed + volume + PiP + fullscreen
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildBottomBar(),
            ),
            // Nút Skip Intro (góc phải dưới, trên bottom bar)
            if (_showSkipIntro)
              Positioned(
                bottom: 60, right: 12,
                child: _skipIntroButton(),
              ),
          ],

          // ── Tên phim + tập góc trái trên — chỉ hiện khi fullscreen ──
          if (_isLandscape)
            Positioned(
              top: 8, left: 56,
              child: _buildMovieInfoOverlay(),
            ),

          // ── Đồng hồ VN góc phải trên — chỉ hiện khi fullscreen ──
          if (_isLandscape)
            Positioned(
              top: 8, right: 8,
              child: _buildClockWidget(),
            ),

          // ── Loading ──
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 3),
            ),

          // ── Error ──
          if (_error != null)
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.white38),
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh, color: AppTheme.accent),
                  label: const Text('Thử lại', style: TextStyle(color: AppTheme.accent)),
                ),
              ]),
            ),
        ],
      );
  }

  Widget _skipIntroButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_hlsPlayer == null) return;
        final current = _hlsPlayer!.state.position.inSeconds;
        _hlsPlayer!.seek(Duration(seconds: current + 120));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.fast_forward_rounded, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text(
              'Bỏ qua 2 phút',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ── Episode Sheet (fullscreen) ────────────────────────────

  /// Format episode name: "1" → "1", "01" → "01", "tập 1" → "1", "Tập tập 01" → "01"
  String _formatEpName(String raw) {
    var name = raw.trim();
    // Bỏ prefix "tập ", "Tập ", "TẬP " (có thể lặp nhiều lần)
    name = name.replaceAll(RegExp(r'^[Tt]ậ?p?\s*', caseSensitive: false), '').trim();
    // Nếu rỗng → trả về raw
    return name.isEmpty ? raw : name;
  }

  void _showEpisodeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1C21),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.3,
          expand: false,
          builder: (ctx, scrollController) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                return Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Title + Server tabs
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.playlist_play_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Chọn tập',
                                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          // Server tabs — tất cả nguồn đều sống
                          if (_servers.length > 1) ...[
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _servers.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final server = entry.value;
                                  final serverName = server['server_name']?.toString() ?? 'Server ${idx + 1}';
                                  final isActive = idx == _selectedServer;

                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _switchServer(idx);
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? AppTheme.accent.withValues(alpha: 0.15)
                                            : Colors.white.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isActive ? AppTheme.accent : Colors.white24,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Dot xanh — tất cả đều sống
                                          Container(
                                            width: 6, height: 6,
                                            decoration: BoxDecoration(
                                              color: isActive ? AppTheme.accent : Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            serverName,
                                            style: TextStyle(
                                              color: isActive ? AppTheme.accent : Colors.white70,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    // Episodes grid
                    Expanded(
                      child: _buildEpisodeList(scrollController),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEpisodeList(ScrollController scrollController) {
    final eps = _currentServerEps;
    if (eps.isEmpty) {
      return const Center(
        child: Text('Không có tập nào', style: TextStyle(color: Colors.white54)),
      );
    }

    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisExtent: 44,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: eps.length,
      itemBuilder: (ctx, i) {
        final ep = eps[i];
        final epId = ep['id'];
        final rawName = ep['ep_name']?.toString() ?? '';
        final displayName = _formatEpName(rawName);
        final isActive = epId == _currentEpId;

        return GestureDetector(
          onTap: () {
            Navigator.pop(ctx);
            _switchEpisode(ep);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.accent.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive
                    ? AppTheme.accent.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                // Đang xem indicator
                if (isActive) ...[
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Tên tập
                Expanded(
                  child: Text(
                    'Tập $displayName',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Custom Controls (giống watch room host controls) ──────

  /// Đồng hồ giờ VN — luôn hiện ở góc phải trên video
  /// Tên phim + tập — luôn hiện góc trái trên video
  Widget _buildMovieInfoOverlay() {
    final movieName = widget.movieTitle ?? '';
    final rawEp = _currentEpName;
    if (movieName.isEmpty && rawEp.isEmpty) return const SizedBox.shrink();
    // Bỏ prefix "Tập"/"tap" nếu có trong epName để tránh lặp
    final epClean = rawEp.replaceAll(RegExp(r'^[Tt]ậ?p?\s*', caseSensitive: false), '').trim();
    final title = epClean.isNotEmpty ? '$movieName | Tập $epClean' : movieName;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Xiao Phim',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockWidget() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final yyyy = now.year.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$h:$m:$s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            '$dd/$mm/$yyyy',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls() {
    // Chỉ còn play/pause ở giữa, rewind/forward đã ra 2 bên
    return GestureDetector(
      onTap: () {
        if (_isPlaying) {
          _hlsPlayer?.pause();
        } else {
          _hlsPlayer?.play();
        }
      },
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
        ),
        child: Icon(
          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white, size: 34,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final progress = _currentDur.inSeconds > 0
        ? _currentPos.inSeconds / _currentDur.inSeconds
        : 0.0;
    final displayValue = _isDragging ? _dragValue : progress;

    return Container(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4, top: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timeline slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
              thumbColor: AppTheme.accent,
              overlayColor: AppTheme.accent.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: displayValue.clamp(0.0, 1.0),
              onChangeStart: (value) {
                _isDragging = true;
                _dragValue = value;
              },
              onChanged: (value) {
                _dragValue = value;
                setState(() {});
              },
              onChangeEnd: (value) {
                _isDragging = false;
                final newPos = Duration(seconds: (value * _currentDur.inSeconds).toInt());
                _hlsPlayer?.seek(newPos);
              },
            ),
          ),
          // Time + Speed + Volume + PiP + Fullscreen
          Row(
            children: [
              Text(
                _formatDuration(_isDragging ? Duration(seconds: (_dragValue * _currentDur.inSeconds).toInt()) : _currentPos),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
              ),
              Text(
                ' / ${_formatDuration(_currentDur)}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontFamily: 'monospace'),
              ),
              const Spacer(),
              // Speed control
              GestureDetector(
                onTap: _cycleSpeed,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _playbackSpeed != 1.0
                        ? AppTheme.accent.withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'x$_playbackSpeed',
                    style: TextStyle(
                      color: _playbackSpeed != 1.0 ? Colors.black : Colors.white,
                      fontSize: 11, fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Volume — tap → expand inline slider, long press → mute
              GestureDetector(
                onLongPress: _toggleMute,
                onTap: () => setState(() => _showVolumeInline = !_showVolumeInline),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isMuted || _volume == 0
                            ? Icons.volume_off_rounded
                            : _volume < 50
                                ? Icons.volume_down_rounded
                                : Icons.volume_up_rounded,
                        color: _isMuted || _volume == 0 ? Colors.redAccent : Colors.white,
                        size: 16,
                      ),
                      if (_showVolumeInline) ...[
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 80,
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                              activeTrackColor: AppTheme.accent,
                              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                              thumbColor: AppTheme.accent,
                              overlayColor: AppTheme.accent.withValues(alpha: 0.1),
                            ),
                            child: Slider(
                              value: _volume,
                              min: 0,
                              max: 100,
                              divisions: 20,
                              onChanged: (val) {
                                setState(() {
                                  _volume = val;
                                  _isMuted = val == 0;
                                  _hlsPlayer?.setVolume(val);
                                });
                              },
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${_volume.round()}',
                            style: TextStyle(
                              color: _volume <= 0 ? Colors.redAccent : Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // PiP button (chỉ hiện khi có PiP)
              if (_pipAvailable) ...[
                GestureDetector(
                  onTap: _startPip,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.picture_in_picture_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Fullscreen
              GestureDetector(
                onTap: _toggleFullscreen,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    _isLandscape ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                    color: Colors.white, size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _cycleSpeed() {
    final idx = _speeds.indexOf(_playbackSpeed);
    final nextIdx = (idx + 1) % _speeds.length;
    setState(() {
      _playbackSpeed = _speeds[nextIdx];
      _hlsPlayer?.setRate(_playbackSpeed);
    });
  }

  void _toggleMute() {
    final currentVol = _hlsPlayer?.state.volume ?? 100.0;
    if (currentVol > 0) {
      _volume = currentVol;
      _isMuted = true;
      _hlsPlayer?.setVolume(0.0);
    } else {
      _isMuted = false;
      _hlsPlayer?.setVolume(_volume > 0 ? _volume : 100.0);
    }
    setState(() {});
  }

  void _toggleFullscreen() {
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      Future.delayed(const Duration(milliseconds: 300), () {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      });
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _showVolumeSlider() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'volume',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, _, __) => const SizedBox(),
      transitionBuilder: (ctx, anim, _, __) {
        return FadeTransition(
          opacity: anim,
          child: Stack(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(color: Colors.transparent),
              ),
              Positioned(
                bottom: 80,
                right: 16,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 200,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2026),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: StatefulBuilder(
                      builder: (context, setDialogState) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _volume <= 0 ? Icons.volume_off_rounded
                                    : _volume < 50 ? Icons.volume_down_rounded
                                    : Icons.volume_up_rounded,
                                color: _volume <= 0 ? Colors.redAccent : AppTheme.accent,
                                size: 18,
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                    activeTrackColor: AppTheme.accent,
                                    inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                                    thumbColor: AppTheme.accent,
                                    overlayColor: AppTheme.accent.withValues(alpha: 0.15),
                                  ),
                                  child: Slider(
                                    value: _volume,
                                    min: 0,
                                    max: 100,
                                    divisions: 20,
                                    onChanged: (val) {
                                      setDialogState(() => _volume = val);
                                      setState(() {
                                        _isMuted = val == 0;
                                        _hlsPlayer?.setVolume(val);
                                      });
                                    },
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 32,
                                child: Text(
                                  '${_volume.round()}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: _volume <= 0 ? Colors.redAccent : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _retry() {
    setState(() { _error = null; _isLoading = true; _playerReady = false; });
    if (_playerMode == _PlayerMode.hls && _hlsPlayer != null) {
      final retryUrl = kIsWeb ? AppConfig.proxyHlsUrl(_currentUrl) : _currentUrl;
      _hlsPlayer!.open(Media(retryUrl));
    } else if (_currentUrl.isNotEmpty) {
      _webController?.loadUrl(urlRequest: URLRequest(url: WebUri(_currentUrl)));
    }
  }

  // ── Server selector — tất cả nguồn đều sống ──────────
  Widget _buildServerSelector() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        itemCount: _servers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = _servers[i];
          final isActive = i == _selectedServer;

          return GestureDetector(
            onTap: () => _switchServer(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.accent : const Color(0xFF1E2130),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isActive ? AppTheme.accent : const Color(0x22FFFFFF),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  s['server_name']?.toString() ?? 'Server ${i + 1}',
                  style: TextStyle(
                    color: isActive ? const Color(0xFF1A1100) : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Server health badge ───────────────────────────
  Widget _serverHealthBadge(Map<String, dynamic> server) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 7, height: 7,
        decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        'Nguồn ổn định',
        style: TextStyle(
          color: Colors.greenAccent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ]);
  }

  // ── Episode grid ──────────────────────────────────
  Widget _buildEpisodeGrid() {
    final eps = _currentServerEps;
    if (eps.isEmpty && _flatEps.isEmpty) {
      return const Center(
        child: Text('Đang tải tập phim...', style: TextStyle(color: Colors.white38, fontSize: 13)),
      );
    }

    final list = eps.isNotEmpty ? eps : _flatEps;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1.4,
      ),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final ep = list[i];
        final epId = ep['id'];
        final isActive = epId == _currentEpId ||
            (epId == null && i == 0 && _currentEpId == widget.episodeId);
        final label = (ep['ep_name'] ?? ep['name'] ?? '${i + 1}').toString();

        return GestureDetector(
          onTap: () => _switchEpisode(ep),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isActive ? AppTheme.accent : const Color(0xFF1E2130),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isActive ? AppTheme.accent : const Color(0x22FFFFFF),
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? const Color(0xFF1A1100) : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
  }
}
