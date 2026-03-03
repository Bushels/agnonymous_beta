import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme.dart';
import '../providers/community_providers.dart';

// --- TRENDING SECTION ---
class TrendingSectionDelegate extends SliverPersistentHeaderDelegate {
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isSmallScreen = MediaQuery.of(context).size.width < 400;

    return Consumer(
      builder: (context, ref, child) {
        final trendingAsync = ref.watch(trendingStatsProvider);
        final sortMode = ref.watch(feedSortModeProvider);

        return Container(
          height: 40.0,
          color: const Color.fromRGBO(31, 41, 55, 0.95),
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 8 : 16,
            vertical: 6,
          ),
          child: Row(
            children: [
              // Sort mode toggle chips
              _SortModeChip(
                label: 'Recent',
                icon: FontAwesomeIcons.clock,
                isSelected: sortMode == FeedSortMode.recent,
                onTap: () => ref.read(feedSortModeProvider.notifier).set(FeedSortMode.recent),
              ),
              const SizedBox(width: 8),
              _SortModeChip(
                label: isSmallScreen ? '\u{1F602}' : 'Top Funny',
                icon: FontAwesomeIcons.faceLaughSquint,
                isSelected: sortMode == FeedSortMode.topFunny,
                onTap: () => ref.read(feedSortModeProvider.notifier).set(FeedSortMode.topFunny),
                color: const Color(0xFFF97316), // Orange for funny
              ),
              const Spacer(),
              // Trending info (only on larger screens)
              if (!isSmallScreen)
                trendingAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (stats) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(FontAwesomeIcons.fire, color: theme.colorScheme.secondary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        stats.trendingCategory,
                        style: TextStyle(
                          color: theme.colorScheme.secondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  double get maxExtent => 40.0;
  @override
  double get minExtent => 40.0;
  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) => true;
}

/// Sort mode chip widget
class _SortModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _SortModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? const Color(0xFF84CC16);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? chipColor : Colors.grey.shade600,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              icon,
              size: 12,
              color: isSelected ? chipColor : Colors.grey.shade400,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? chipColor : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
