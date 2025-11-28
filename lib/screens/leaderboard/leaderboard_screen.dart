import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/leaderboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/reputation_badge.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardState = ref.watch(leaderboardProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Leaderboard',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(leaderboardProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF111827), Color(0xFF1F2937)],
              ),
            ),
          ),

          SafeArea(
            child: leaderboardState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : leaderboardState.error != null
                    ? _buildErrorView(leaderboardState.error!, ref)
                    : _buildLeaderboardContent(
                        context,
                        ref,
                        leaderboardState.entries,
                        currentUser?.id,
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            error,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.read(leaderboardProvider.notifier).refresh();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84CC16),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardContent(
    BuildContext context,
    WidgetRef ref,
    List<LeaderboardEntry> entries,
    String? currentUserId,
  ) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.leaderboard_outlined,
              size: 64,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              'No leaderboard data yet',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to earn reputation!',
              style: GoogleFonts.inter(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Find current user entry
    LeaderboardEntry? currentUserEntry;
    if (currentUserId != null) {
      try {
        currentUserEntry = entries.firstWhere(
          (e) => e.username.contains(currentUserId.substring(0, 8)), // Simplified matching logic
          orElse: () => entries.first, // Fallback, though logic should be robust
        );
        // Correct matching logic if possible, or rely on ID if available in entry
        // For now assuming username match or separate provider lookup
      } catch (_) {}
    }

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    if (entries.length >= 3)
                      _buildPodium(entries.take(3).toList()),
                    const SizedBox(height: 24),
                    Text(
                      'TOP CONTRIBUTORS',
                      style: GoogleFonts.inter(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = entries[index + 3];
                    final isCurrentUser = currentUserId != null &&
                        entry.username.contains(currentUserId.substring(0, 8));

                    return _buildLeaderboardRow(entry, isCurrentUser);
                  },
                  childCount: entries.length > 3 ? entries.length - 3 : 0,
                ),
              ),
            ),
            // Add padding at bottom for the sticky user rank bar
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),

        // Sticky User Rank Bar
        if (currentUserId != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildCurrentUserRankBar(context, ref, currentUserId),
          ),
      ],
    );
  }

  Widget _buildCurrentUserRankBar(BuildContext context, WidgetRef ref, String userId) {
    final userRankAsync = ref.watch(userRankProvider(userId));

    return userRankAsync.when(
      data: (rank) {
        if (rank == null) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111827).withOpacity(0.95),
            border: Border(
              top: BorderSide(
                color: const Color(0xFF84CC16).withOpacity(0.3),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84CC16).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF84CC16)),
                  ),
                  child: Text(
                    'Your Rank: #$rank',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF84CC16),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Keep contributing to rise up!',
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPodium(List<LeaderboardEntry> topThree) {
    return SizedBox(
      height: 240, // Fixed height for alignment
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          if (topThree.length > 1)
            Expanded(child: _buildPodiumPlace(topThree[1], 2, 140)),
          // 1st place
          if (topThree.isNotEmpty)
            Expanded(child: _buildPodiumPlace(topThree[0], 1, 180)),
          // 3rd place
          if (topThree.length > 2)
            Expanded(child: _buildPodiumPlace(topThree[2], 3, 110)),
        ],
      ),
    );
  }

  Widget _buildPodiumPlace(LeaderboardEntry entry, int place, double height) {
    final colors = {
      1: const Color(0xFFFFD700), // Gold
      2: const Color(0xFFC0C0C0), // Silver
      3: const Color(0xFFCD7F32), // Bronze
    };

    final color = colors[place] ?? Colors.grey;
    final isFirst = place == 1;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Avatar/Emoji
        Container(
          padding: EdgeInsets.all(isFirst ? 4 : 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: isFirst ? 24 : 18,
            backgroundColor: const Color(0xFF1F2937),
            child: Text(
              entry.levelInfo.emoji,
              style: TextStyle(fontSize: isFirst ? 24 : 18),
            ),
          ),
        ),
        const SizedBox(height: 8),
        
        // Username
        Text(
          entry.username.length > 8
              ? '${entry.username.substring(0, 8)}...'
              : entry.username,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: isFirst ? 14 : 12,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        
        // Points
        Text(
          '${entry.reputationPoints} pts',
          style: GoogleFonts.inter(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        // Podium Step
        Container(
          width: double.infinity,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.3),
                color.withOpacity(0.05),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            border: Border(
              top: BorderSide(color: color.withOpacity(0.8), width: 2),
              left: BorderSide(color: color.withOpacity(0.3), width: 1),
              right: BorderSide(color: color.withOpacity(0.3), width: 1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#$place',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: isFirst ? 32 : 24,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: color.withOpacity(0.8),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardRow(LeaderboardEntry entry, bool isCurrentUser) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? const Color(0xFF84CC16).withOpacity(0.1)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser
              ? const Color(0xFF84CC16).withOpacity(0.5)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 30,
            child: Text(
              '#${entry.rank}',
              style: GoogleFonts.outfit(
                color: isCurrentUser ? const Color(0xFF84CC16) : Colors.grey.shade500,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),

          // Level badge
          ReputationBadge(
            levelInfo: entry.levelInfo,
            showTitle: false,
            compact: true,
          ),
          const SizedBox(width: 12),

          // Username & verification
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.username,
                        style: GoogleFonts.inter(
                          color: isCurrentUser
                              ? const Color(0xFF84CC16)
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.emailVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified,
                        size: 14,
                        color: Colors.blue,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      entry.levelInfo.title,
                      style: GoogleFonts.inter(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      ' \u2022 ',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    Text(
                      '${entry.postCount} posts',
                      style: GoogleFonts.inter(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Points
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.reputationPoints}',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'pts',
                style: GoogleFonts.inter(
                  color: Colors.grey.shade500,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
