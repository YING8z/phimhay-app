import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SmartLinkService {
  static const String smartLinkUrl =
      'https://www.effectivecpmnetwork.com/zvpzew7f?key=e6ff631d2c2c150960e10784647ba0d8';

  static int _windowCount = 0;
  static int _lastResetEpoch = 0;
  static int _lastShowEpoch = 0;
  static bool _initialized = false;

  static const int _maxPerWindow = 15;
  static const int _windowMs = 7200000;
  static const int _cooldownMs = 45000;

  static int get _now => DateTime.now().millisecondsSinceEpoch;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _windowCount = prefs.getInt('sl_window_count') ?? 0;
      _lastResetEpoch = prefs.getInt('sl_last_reset') ?? 0;
      _lastShowEpoch = prefs.getInt('sl_last_show') ?? 0;
      _checkWindowReset();
    } catch (_) {}
  }

  static void _checkWindowReset() {
    if (_now - _lastResetEpoch >= _windowMs) {
      _windowCount = 0;
      _lastResetEpoch = _now;
      _persist();
    }
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('sl_window_count', _windowCount);
      await prefs.setInt('sl_last_reset', _lastResetEpoch);
      await prefs.setInt('sl_last_show', _lastShowEpoch);
    } catch (_) {}
  }

  static bool canShow() {
    _checkWindowReset();
    return _windowCount < _maxPerWindow &&
        (_now - _lastShowEpoch) >= _cooldownMs;
  }

  static int get remaining => _maxPerWindow - _windowCount;

  static Future<void> record() async {
    _windowCount++;
    _lastShowEpoch = _now;
    await _persist();
  }

  static Future<void> openSmartLink(BuildContext context) async {
    try {
      await launchUrl(
        Uri.parse(smartLinkUrl),
        mode: LaunchMode.inAppWebView,
      );
    } catch (_) {
      try {
        await launchUrl(
          Uri.parse(smartLinkUrl),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {}
    }
  }

  static Future<void> showInterstitialIfNeeded(
    BuildContext context, {
    VoidCallback? onDone,
    bool force = false,
  }) async {
    if (!force && !canShow()) {
      onDone?.call();
      return;
    }
    if (!context.mounted) {
      onDone?.call();
      return;
    }

    await record();

    if (!context.mounted) {
      onDone?.call();
      return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => _SmartLinkOverlay(
          onComplete: () {
            Navigator.pop(context);
            onDone?.call();
          },
        ),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }
}

class _SmartLinkOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const _SmartLinkOverlay({required this.onComplete});

  @override
  State<_SmartLinkOverlay> createState() => _SmartLinkOverlayState();
}

class _SmartLinkOverlayState extends State<_SmartLinkOverlay>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _seconds = 5;
  bool _canSkip = false;
  bool _disposed = false;
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..forward();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed) {
        t.cancel();
        return;
      }
      setState(() {
        _seconds--;
        if (_seconds <= 0) {
          _canSkip = true;
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_offer, color: Colors.amber, size: 64),
                SizedBox(height: 16),
                Text(
                  'ƯU ĐÃI ĐẶC BIỆT',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'KHUYẾN MÃI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: _canSkip
                ? GestureDetector(
                    onTap: widget.onComplete,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white54, width: 1),
                      ),
                      child: const Text(
                        'Bỏ qua ▸',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Bỏ qua sau ${_seconds}s',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => LinearProgressIndicator(
                value: _anim.value,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.amber),
                minHeight: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
