import 'package:flutter/material.dart';
import 'package:phimhay_app/config/theme.dart';

class Chips extends StatelessWidget {
  final String selectedChip;
  final ValueChanged<String> onChipSelected;

  static const chips = ['Đề xuất', 'Phim bộ', 'Phim lẻ', 'Thể loại ▾'];

  const Chips({
    super.key,
    required this.selectedChip,
    required this.onChipSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        physics: const BouncingScrollPhysics(),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final chip = chips[index];
          final isSelected = chip == selectedChip;
          return GestureDetector(
            onTap: () => onChipSelected(chip),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.textPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? AppTheme.textPrimary : Colors.white70,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  chip,
                  style: TextStyle(
                    color: isSelected ? AppTheme.bg : AppTheme.textSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
