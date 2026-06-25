import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Helper widget để render SVG icons từ assets
class AppSvgIcon extends StatelessWidget {
  final String assetName;
  final double size;
  final Color? color;

  const AppSvgIcon(
    this.assetName, {
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/svg_ui_controls/$assetName',
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}
