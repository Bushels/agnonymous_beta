import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../providers/grain_data_provider.dart';
import '../../providers/grain_data_live_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/ticker/fertilizer_ticker.dart';
import '../../widgets/ticker/sparkline_widget.dart';
import '../../features/community/providers/community_providers.dart';
import 'canola_thesis_screen.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final globalStats = ref.watch(globalGrainStatsProvider);
    final pipelineStatus = ref.watch(pipelineStatusProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Greeting header
          SliverToBoxAdapter(
            child: _buildGreetingHeader(authState, pipelineStatus),
          ),

          // Fertilizer ticker
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 8),
              child: FertilizerTicker(),
            ),
          ),

          // Key metrics row
          SliverToBoxAdapter(
            child: _buildKeyMetrics(ref),
          ),

          // Canola thesis deep-dive card
          SliverToBoxAdapter(
            child: _buildCanolaThesisCard(context),
          ),

          // Grain highlights section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'Grain Highlights',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Grain highlight cards
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: globalStats.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: Color(0xFF10B981)),
                  ),
                ),
              ),
              error: (err, _) => SliverToBoxAdapter(
                child: _buildErrorCard('Unable to load grain data'),
              ),
              data: (stats) => SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final stat = stats[index];
                    return _GrainHighlightCard(
                      grain: stat['grain'] as String,
                      totalKtonnes: (stat['total_ktonnes'] as num).toDouble(),
                      index: index,
                    );
                  },
                  childCount: stats.length > 6 ? 6 : stats.length,
                ),
              ),
            ),
          ),

          // Community pulse section
          SliverToBoxAdapter(
            child: _buildCommunityPulse(ref),
          ),

          // Data freshness indicator
          SliverToBoxAdapter(
            child: _buildDataFreshness(pipelineStatus),
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _buildGreetingHeader(AuthState authState, AsyncValue<Map<String, dynamic>?> pipelineStatus) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    final username = authState.profile?.username;
    final province = authState.profile?.provinceState;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF052e16),
            Color(0xFF0F172A),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    username ?? 'Farmer',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              // Province badge
              if (province != null && province.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Text(
                        province,
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms);
  }

  Widget _buildKeyMetrics(WidgetRef ref) {
    final globalStats = ref.watch(globalStatsProvider);
    final trendingStats = ref.watch(trendingStatsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _MetricCard(
              label: 'Total Posts',
              icon: Icons.article_outlined,
              asyncValue: globalStats.whenData(
                (stats) => '${stats.totalPosts}',
              ),
              color: const Color(0xFF84CC16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              label: 'Votes',
              icon: Icons.how_to_vote_outlined,
              asyncValue: globalStats.whenData(
                (stats) => '${stats.totalVotes}',
              ),
              color: const Color(0xFF06B6D4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              label: 'Trending',
              icon: Icons.trending_up,
              asyncValue: trendingStats.whenData(
                (stats) => stats.trendingCategory.isNotEmpty
                    ? stats.trendingCategory
                    : 'N/A',
              ),
              color: const Color(0xFFF59E0B),
              isText: true,
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms, delay: 100.ms).slideY(begin: 0.05);
  }

  Widget _buildCanolaThesisCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: LuxuryGlassContainer(
        blur: 12,
        opacity: 0.08,
        glowColor: const Color(0xFF84CC16),
        glowIntensity: 0.2,
        padding: const EdgeInsets.all(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CanolaThesisScreen(),
            ),
          );
        },
        child: Row(
          children: [
            // Icon container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF84CC16).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.eco,
                color: Color(0xFF84CC16),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Canola Market Intelligence',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Delivery pace, COT positioning, futures curve',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF64748B),
              size: 20,
            ),
          ],
        ),
      ),
    ).animate().fade(duration: 400.ms, delay: 150.ms).slideY(begin: 0.05);
  }

  Widget _buildCommunityPulse(WidgetRef ref) {
    final trendingStats = ref.watch(trendingStatsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Community Pulse',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          GlassContainer(
            blur: 10,
            opacity: 0.08,
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.all(16),
            child: trendingStats.when(
              loading: () => const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
              ),
              error: (_, __) => const Text(
                'Unable to load trending data',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
              data: (stats) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          color: Color(0xFFF59E0B), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Most Active: ${stats.trendingCategory}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (stats.mostPopularPostTitle.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFF84CC16), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            stats.mostPopularPostTitle,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms, delay: 300.ms).slideY(begin: 0.05);
  }

  Widget _buildDataFreshness(AsyncValue<Map<String, dynamic>?> pipelineStatus) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: pipelineStatus.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (status) {
          if (status == null) {
            return Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Data pipeline initializing...',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            );
          }
          final completedAt = DateTime.tryParse(status['completed_at'] ?? '');
          final timeAgo = completedAt != null
              ? _timeAgo(completedAt)
              : 'unknown';
          return Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'CGC data updated $timeAgo',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return GlassContainer(
      blur: 10,
      opacity: 0.08,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 12),
          Text(message, style: const TextStyle(color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dateTime);
  }
}

// --- Grain Highlight Card ---
class _GrainHighlightCard extends ConsumerWidget {
  final String grain;
  final double totalKtonnes;
  final int index;

  const _GrainHighlightCard({
    required this.grain,
    required this.totalKtonnes,
    required this.index,
  });

  // Commodity color mapping
  static const _grainColors = {
    'Wheat': Color(0xFFF59E0B),
    'Canola': Color(0xFF84CC16),
    'Barley': Color(0xFFF97316),
    'Oats': Color(0xFF06B6D4),
    'Corn': Color(0xFFEAB308),
    'Soybeans': Color(0xFF22C55E),
    'Flaxseed': Color(0xFF8B5CF6),
    'Rye': Color(0xFFEC4899),
    'Peas': Color(0xFF14B8A6),
    'Lentils': Color(0xFFA855F7),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _grainColors[grain] ?? const Color(0xFF10B981);
    final formatter = NumberFormat.compact();

    // Fetch recent weekly data for sparkline
    final weeklyData = ref.watch(grainDataProvider({
      'grain': grain,
      'metric': 'Deliveries',
      'limit': 12,
    }));

    return GlassContainer(
      blur: 10,
      opacity: 0.08,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  grain,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.4), blurRadius: 4),
                  ],
                ),
              ),
            ],
          ),

          // Value
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatter.format(totalKtonnes),
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'KT',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          // Sparkline
          weeklyData.when(
            loading: () => SizedBox(
              height: 28,
              child: Center(
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(color.withOpacity(0.3)),
                ),
              ),
            ),
            error: (_, __) => const SizedBox(height: 28),
            data: (data) {
              final sparkData = data
                  .where((r) => r['ktonnes'] != null)
                  .map((r) => (r['ktonnes'] as num).toDouble())
                  .toList()
                  .reversed
                  .toList();

              return TrendSparkline(
                data: sparkData.isNotEmpty ? sparkData : [0, 0],
                width: double.infinity,
                height: 28,
              );
            },
          ),
        ],
      ),
    ).animate()
        .fade(duration: 400.ms, delay: (80 * index).ms)
        .slideY(begin: 0.1);
  }
}

// --- Metric Card ---
class _MetricCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final AsyncValue<String> asyncValue;
  final Color color;
  final bool isText;

  const _MetricCard({
    required this.label,
    required this.icon,
    required this.asyncValue,
    required this.color,
    this.isText = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: 10,
      opacity: 0.08,
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          asyncValue.when(
            loading: () => const SizedBox(
              height: 20,
              width: 40,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(Color(0xFF334155)),
              ),
            ),
            error: (_, __) => const Text(
              '--',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            data: (value) => Text(
              value,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: isText ? 13 : 20,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
