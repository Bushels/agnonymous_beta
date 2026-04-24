import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../board_theme.dart';
import '../../../services/analytics_service.dart';
import '../community_categories.dart';

// --- CATEGORY CHIPS ---
class CategoryChips extends StatelessWidget {
  final String selectedCategory;
  final Function(String) onCategoryChanged;

  const CategoryChips({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Container(
      height: 62,
      decoration: const BoxDecoration(
        color: Color(0xFF191B14),
        border: Border(
          bottom: BorderSide(color: BoardColors.line),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 16,
          vertical: 10,
        ),
        children: [
          _CategoryChip(
            label: 'All',
            icon: '\u{1F5C2}\uFE0F',
            selected: selectedCategory.isEmpty,
            onTap: () => onCategoryChanged(''),
          ),
          const SizedBox(width: 8),
          ...boardCategories.map((category) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _CategoryChip(
                label: category.name,
                icon: category.icon,
                selected: selectedCategory == category.name,
                onTap: () {
                  AnalyticsService.instance.logCategoryFilter(
                    category: category.name,
                  );
                  onCategoryChanged(category.name);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        label == 'All' ? BoardColors.green : boardCategoryColor(label);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent : const Color(0xFF25271F),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accent : const Color(0xFF424637),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.inter(
                color: selected ? const Color(0xFF101610) : BoardColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
