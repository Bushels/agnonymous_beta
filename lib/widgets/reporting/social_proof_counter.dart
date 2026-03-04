import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/farmer_reports_provider.dart';
import '../glass_container.dart';

/// Social proof counter showing monthly reporting stats.
///
/// Displays the total number of price reports this month and how many
/// unique farmers have contributed. Uses [monthlyReportStatsProvider]
/// to fetch live data. Wrapped in a [GlassContainer] with a subtle
/// green border.
class SocialProofCounter extends ConsumerWidget {
  /// Optional province code to filter stats (e.g. "SK", "AB", "MB").
  /// Pass null for nationwide stats.
  final String? region;

  const SocialProofCounter({
    super.key,
    this.region,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(monthlyReportStatsProvider(region));

    return statsAsync.when(
      data: (stats) => _buildCounter(stats.totalReports, stats.uniqueReporters),
      loading: () => _buildCounter(null, null),
      error: (_, __) => _buildCounter(0, 0),
    );
  }

  Widget _buildCounter(int? totalReports, int? uniqueReporters) {
    final isLoading = totalReports == null;

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      border: Border.all(
        color: const Color(0xFF84CC16).withValues(alpha: 0.15),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF84CC16).withValues(alpha: 0.1),
            ),
            child: const Icon(
              Icons.people_outline,
              color: Color(0xFF84CC16),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          // Stats text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLoading)
                  Container(
                    height: 16,
                    width: 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                else
                  Text(
                    '$totalReports ${totalReports == 1 ? 'price' : 'prices'} reported this month',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 4),
                if (isLoading)
                  Container(
                    height: 12,
                    width: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                else
                  Text(
                    '$uniqueReporters ${uniqueReporters == 1 ? 'farmer' : 'farmers'} contributing',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms);
  }
}
