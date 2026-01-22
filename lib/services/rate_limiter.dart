
/// Rate limiter for preventing spam actions like rapid voting
class RateLimiter {
  // Singleton instance
  static final RateLimiter _instance = RateLimiter._internal();
  factory RateLimiter() => _instance;
  RateLimiter._internal();

  // Configuration
  static const int maxVotesPerWindow = 10; // Max votes allowed in time window
  static const Duration timeWindow = Duration(minutes: 1); // Time window for rate limiting
  static const Duration cooldownPeriod = Duration(seconds: 3); // Minimum time between votes on same post

  // Track vote timestamps: postId -> list of vote timestamps
  final Map<String, List<DateTime>> _voteHistory = {};

  // Track last vote time per post to prevent rapid double-voting
  final Map<String, DateTime> _lastVotePerPost = {};

  // Track global vote count for overall throttling
  final List<DateTime> _globalVoteHistory = [];

  /// Check if a vote is allowed for the given post
  /// Returns null if allowed, or an error message if rate limited
  String? canVote(String postId) {
    final now = DateTime.now();

    // Clean up old entries
    _cleanupOldEntries(now);

    // Check cooldown on same post (prevent accidental double-taps)
    final lastVote = _lastVotePerPost[postId];
    if (lastVote != null && now.difference(lastVote) < cooldownPeriod) {
      final remaining = cooldownPeriod - now.difference(lastVote);
      return 'Please wait ${remaining.inSeconds} seconds before voting again on this post.';
    }

    // Check global rate limit
    if (_globalVoteHistory.length >= maxVotesPerWindow) {
      final oldestVote = _globalVoteHistory.first;
      final timeUntilReset = timeWindow - now.difference(oldestVote);
      if (timeUntilReset.isNegative) {
        // Window has passed, clean up
        _globalVoteHistory.clear();
      } else {
        return 'Voting too fast! Please wait ${timeUntilReset.inSeconds} seconds.';
      }
    }

    return null; // Allowed
  }

  /// Record a vote for rate limiting purposes
  void recordVote(String postId) {
    final now = DateTime.now();

    // Record for this post
    _voteHistory.putIfAbsent(postId, () => []);
    _voteHistory[postId]!.add(now);
    _lastVotePerPost[postId] = now;

    // Record globally
    _globalVoteHistory.add(now);
  }

  /// Clean up entries older than the time window
  void _cleanupOldEntries(DateTime now) {
    final cutoff = now.subtract(timeWindow);

    // Clean up post-specific history
    _voteHistory.forEach((postId, timestamps) {
      timestamps.removeWhere((t) => t.isBefore(cutoff));
    });
    _voteHistory.removeWhere((_, timestamps) => timestamps.isEmpty);

    // Clean up global history
    _globalVoteHistory.removeWhere((t) => t.isBefore(cutoff));

    // Clean up last vote per post if older than cooldown
    final cooldownCutoff = now.subtract(cooldownPeriod);
    _lastVotePerPost.removeWhere((_, time) => time.isBefore(cooldownCutoff));
  }

  /// Get remaining votes in current window
  int get remainingVotes {
    _cleanupOldEntries(DateTime.now());
    return maxVotesPerWindow - _globalVoteHistory.length;
  }

  /// Check if currently rate limited
  bool get isRateLimited {
    _cleanupOldEntries(DateTime.now());
    return _globalVoteHistory.length >= maxVotesPerWindow;
  }

  /// Reset all rate limiting (for testing or user logout)
  void reset() {
    _voteHistory.clear();
    _lastVotePerPost.clear();
    _globalVoteHistory.clear();
  }
}

/// Rate limiter specifically for comments
class CommentRateLimiter {
  static final CommentRateLimiter _instance = CommentRateLimiter._internal();
  factory CommentRateLimiter() => _instance;
  CommentRateLimiter._internal();

  static const int maxCommentsPerWindow = 5; // Max comments in time window
  static const Duration timeWindow = Duration(minutes: 2);
  static const Duration cooldownPeriod = Duration(seconds: 5); // Min time between comments

  final List<DateTime> _commentHistory = [];
  DateTime? _lastComment;

  String? canComment() {
    final now = DateTime.now();
    _cleanupOldEntries(now);

    // Check cooldown
    if (_lastComment != null && now.difference(_lastComment!) < cooldownPeriod) {
      final remaining = cooldownPeriod - now.difference(_lastComment!);
      return 'Please wait ${remaining.inSeconds} seconds before commenting again.';
    }

    // Check rate limit
    if (_commentHistory.length >= maxCommentsPerWindow) {
      final oldestComment = _commentHistory.first;
      final timeUntilReset = timeWindow - now.difference(oldestComment);
      return 'Commenting too fast! Please wait ${timeUntilReset.inSeconds} seconds.';
    }

    return null;
  }

  void recordComment() {
    final now = DateTime.now();
    _commentHistory.add(now);
    _lastComment = now;
  }

  void _cleanupOldEntries(DateTime now) {
    final cutoff = now.subtract(timeWindow);
    _commentHistory.removeWhere((t) => t.isBefore(cutoff));
  }

  void reset() {
    _commentHistory.clear();
    _lastComment = null;
  }
}

/// Rate limiter for post creation
class PostRateLimiter {
  static final PostRateLimiter _instance = PostRateLimiter._internal();
  factory PostRateLimiter() => _instance;
  PostRateLimiter._internal();

  static const int maxPostsPerWindow = 3; // Max posts in time window
  static const Duration timeWindow = Duration(minutes: 5);
  static const Duration cooldownPeriod = Duration(seconds: 30); // Min time between posts

  final List<DateTime> _postHistory = [];
  DateTime? _lastPost;

  String? canPost() {
    final now = DateTime.now();
    _cleanupOldEntries(now);

    // Check cooldown
    if (_lastPost != null && now.difference(_lastPost!) < cooldownPeriod) {
      final remaining = cooldownPeriod - now.difference(_lastPost!);
      return 'Please wait ${remaining.inSeconds} seconds before posting again.';
    }

    // Check rate limit
    if (_postHistory.length >= maxPostsPerWindow) {
      final oldestPost = _postHistory.first;
      final timeUntilReset = timeWindow - now.difference(oldestPost);
      return 'Posting too fast! Please wait ${(timeUntilReset.inSeconds / 60).ceil()} minutes.';
    }

    return null;
  }

  void recordPost() {
    final now = DateTime.now();
    _postHistory.add(now);
    _lastPost = now;
  }

  void _cleanupOldEntries(DateTime now) {
    final cutoff = now.subtract(timeWindow);
    _postHistory.removeWhere((t) => t.isBefore(cutoff));
  }

  void reset() {
    _postHistory.clear();
    _lastPost = null;
  }
}
