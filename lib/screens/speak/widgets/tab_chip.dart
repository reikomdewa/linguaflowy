import 'package:flutter/material.dart';

class TabChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isFilter;
  final VoidCallback onTap;

  const TabChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.isFilter = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color bg = isSelected
        ? (isDark ? Colors.white : theme.primaryColor)
        : (isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.05));

    final Color text = isSelected
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.7));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 14)),
            if (isFilter) ...[
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: text.withOpacity(isSelected ? 0.7 : 0.5)),
            ],
          ],
        ),
      ),
    );
  }
}