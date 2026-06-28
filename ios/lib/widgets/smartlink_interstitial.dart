import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phimhay_app/services/smartlink_service.dart';

class SmartLinkInterstitial extends StatefulWidget {
  final VoidCallback onComplete;
  const SmartLinkInterstitial({super.key, required this.onComplete});

  @override
  State<SmartLinkInterstitial> createState() => _SmartLinkInterstitialState();
}

class _SmartLinkInterstitialState extends State<SmartLinkInterstitial>
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
          Center(
            child: GestureDetector(
              onTap: () => SmartLinkService.openSmartLink(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_offer, color: Colors.amber, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'ƯU ĐÃI ĐẶC BIỆT',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.amber.shade700, Colors.orange.shade600]),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'XEM NGAY →',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
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
