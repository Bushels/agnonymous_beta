import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../main.dart' show supabase, logger;

/// Leaderboard entry
class LeaderboardEntry {
  final int rank;
  final String username;
  final bool emailVerified;
  final int publicReputation;
  final int reputationPoints;
  final int reputationLevel;
  final double voteWeight;
  final int postCount;
  final int verifiedPostsCount;
  final double? avgAccuracy;

  LeaderboardEntry({
    required this.rank,
    required this.username,
    required this.emailVerified,
    required this.publicReputation,
    required this.reputationPoints,
    required this.reputationLevel,
    required this.voteWeight,
    required this.postCount,
    required this.verifiedPostsCount,
    this.avgAccuracy,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      rank: map['rank'] as int,
      username: map['username'] as String,
      emailVerified: map['email_verified'] as bool? ?? false,
      publicReputation: map['public_reputation'] as int? ?? 0,
      reputationPoints: map['reputation_points'] as int? ?? 0,
      reputationLevel: map['reputation_level'] as int? ?? 0,
      voteWeight: (map['vote_weight'] as num?)?.toDouble() ?? 1.0,
      postCount: map['post_count'] as int? ?? 0,
      verifiedPostsCount: map['verified_posts_count'] as int? ?? 0,
      avgAccuracy: (map['avg_accuracy'] as num?)?.toDouble(),
    );
  }

  ReputationLevelInfo get levelInfo => ReputationLevelInfo.fromLevel(reputationLevel);
}

/// Leaderboard state
class LeaderboardState {
  final List<LeaderboardEntry> entries;
  final bool isLoading;
  final String? error;

  const LeaderboardState({
    this.entries = const [],
    this.isLoading = false,
    this.error,
  });

  LeaderboardState copyWith({
    List<LeaderboardEntry>? entries,
    bool? isLoading,
    String? error,
  }) {
    return LeaderboardState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Leaderboard notifier (Riverpod 3.x Notifier pattern)
class LeaderboardNotifier extends Notifier<LeaderboardState> {
  @override
  LeaderboardState build() {
    // Defer loading to next microtask so state is initialized first
    Future.microtask(() => loadLeaderboard());
    return const LeaderboardState();
  }

  Future<void> loadLeaderboard({int limit = 100}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await supabase
          .from('leaderboard_all_time')
          .select()
          .limit(limit);

      final entries = (response as List<dynamic>)
          .map((e) => LeaderboardEntry.fromMap(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(entries: entries, isLoading: false);
    } catch (e) {
      logger.e('Error loading leaderboard: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load leaderboard',
      );
    }
  }

  Future<void> refresh() => loadLeaderboard();
}

/// Leaderboard provider
final leaderboardProvider = NotifierProvider<LeaderboardNotifier, LeaderboardState>(
  LeaderboardNotifier.new,
);

/// User rank provider (find current user's rank)
final userRankProvider = FutureProvider.family<int?, String>((ref, userId) async {
  try {
    final response = await supabase
        .from('leaderboard_all_time')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return response['rank'] as int?;
  } catch (e) {
    logger.e('Error getting user rank: $e');
    return null;
  }
});
