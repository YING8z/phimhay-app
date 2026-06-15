import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phimhay_app/config/theme.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final String? avatarUrl;

  const BottomNav({super.key, required this.currentIndex, required this.onTabSelected, this.avatarUrl});

  static const _tabs = [
    _TabItem(Icons.home_rounded, 'Trang chủ'),
    _TabItem(Icons.search_rounded, 'Tìm kiếm'),
    _TabItem(Icons.calendar_month_outlined, 'Lịch chiếu'),
    _TabItem(Icons.play_circle_outline, 'Phim'),
    _TabItem(Icons.person_outline, 'Tài khoản'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 23,
        left: 12,
        right: 12,
      ),
      child: Container(
        constraints: const BoxConstraints(minWidth: 240),
        decoration: BoxDecoration(
          color: const Color(0xE0141620),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
          boxShadow: const [
            BoxShadow(color: Color(0x80000000), blurRadius: 32, offset: Offset(0, 8)),
            BoxShadow(color: Color(0x0FFFFFFF), blurRadius: 0, offset: Offset(0, -1)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tabW = constraints.maxWidth / _tabs.length;
                  return SizedBox(
                    height: 56,
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          left: currentIndex * tabW + 4,
                          width: tabW - 8,
                          top: 4,
                          bottom: 4,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0x1AF5C518),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(_tabs.length, (i) {
                            final tab = _tabs[i];
                            final active = i == currentIndex;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => onTabSelected(i),
                                behavior: HitTestBehavior.opaque,
                                child: Center(
                                  child: (i == 4 && avatarUrl != null && avatarUrl!.isNotEmpty)
                                    ? Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          ClipOval(
                                            child: CachedNetworkImage(
                                              imageUrl: avatarUrl!,
                                              width: 24, height: 24,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) => Icon(tab.icon, color: active ? AppTheme.accent : AppTheme.textMuted, size: 22),
                                            ),
                                          ),
                                          Positioned(
                                            right: -1, bottom: -1,
                                            child: Container(
                                              width: 8, height: 8,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF22C55E),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: const Color(0xE0141620), width: 1.5),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Icon(tab.icon, color: active ? AppTheme.accent : AppTheme.textMuted, size: 22),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem(this.icon, this.label);
}
