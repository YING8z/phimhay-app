import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/update_service.dart';
import '../../widgets/update_dialog.dart';

class SplashScreen extends StatefulWidget {
  final Widget child;
  const SplashScreen({super.key, required this.child});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scale;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // Dismiss splash + check update
    Future.delayed(const Duration(milliseconds: 2500), () async {
      if (mounted) setState(() => _ready = true);

      // Check update sau khi splash xong
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          final updateInfo = await UpdateService().checkUpdate();
          if (updateInfo.hasUpdate && mounted) {
            await UpdateDialog.show(context, updateInfo);
          }
        } catch (_) {}
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content — visible after splash
        AnimatedOpacity(
          opacity: _ready ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: widget.child,
        ),
        // Splash overlay
        if (!_ready)
          Container(
            color: AppTheme.bg,
            child: FadeTransition(
              opacity: _fadeIn,
              child: ScaleTransition(
                scale: _scale,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/logo2.png',
                        width: 180,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Text('Xiao Phim', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppTheme.gold, letterSpacing: -1)),
                      ),
                      const SizedBox(height: 24),
                      // 3 bouncing dots
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          return _Dot(i);
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Dot extends StatefulWidget {
  final int index;
  const _Dot(this.index);

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: (widget.index * 200).toInt()), () {
      if (mounted) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Transform.scale(
          scale: _anim.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ),
      ),
    );
  }
}
