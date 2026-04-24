import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../board_theme.dart';
import '../providers/community_providers.dart';

// --- TRENDING SECTION ---
class TrendingSectionDelegate extends SliverPersistentHeaderDelegate {
  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isSmallScreen = MediaQuery.of(context).size.width < 400;

    return Consumer(
      builder: (context, ref, child) {
        final trendingAsync = ref.watch(trendingStatsProvider);
        final sortMode = ref.watch(feedSortModeProvider);

        return Container(
          height: 52.0,
          color: const Color(0xFF191B14),
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 12 : 18,
            vertical: 8,
          ),
          child: Row(
            children: [
              // Sort mode toggle chips
              _SortModeChip(
                label: 'Recent',
                icon: FontAwesomeIcons.clock,
                isSelected: sortMode == FeedSortMode.recent,
                onTap: () => ref
                    .read(feedSortModeProvider.notifier)
                    .set(FeedSortMode.recent),
              ),
              const SizedBox(width: 8),
              _SortModeChip(
                label: 'Active',
                icon: FontAwesomeIcons.commentDots,
                isSelected: sortMode == FeedSortMode.active,
                onTap: () => ref
                    .read(feedSortModeProvider.notifier)
                    .set(FeedSortMode.active),
                color: BoardColors.monette,
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
                      FaIcon(FontAwesomeIcons.fire,
                          color: BoardColors.amber, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        stats.trendingCategory,
                        style: TextStyle(
                          color: BoardColors.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
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
  double get maxExtent => 52.0;
  @override
  double get minExtent => 52.0;
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
    final chipColor = color ?? BoardColors.green;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : const Color(0xFF25271F),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? chipColor : const Color(0xFF424637),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              icon,
              size: 12,
              color: isSelected ? const Color(0xFF101610) : chipColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected ? const Color(0xFF101610) : BoardColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
