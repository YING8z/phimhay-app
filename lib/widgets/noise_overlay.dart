import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class NoiseOverlay extends StatelessWidget {
  final double opacity;

  const NoiseOverlay({super.key, this.opacity = 0.15});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: NoisePainter(opacity: opacity),
      child: Container(),
    );
  }
}

class NoisePainter extends CustomPainter {
  final double opacity;
  final Random _random = Random(42); // Seed cố định để noise không đổi mỗi frame

  NoisePainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Vẽ nhiều chấm nhỏ random để tạo hiệu ứng grain
    for (var i = 0; i < (size.width * size.height / 4).toInt(); i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      final brightness = _random.nextDouble();

      paint.color = Color.fromRGBO(
        255,
        255,
        255,
        brightness * opacity,
      );

      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(NoisePainter oldDelegate) => false;
}
