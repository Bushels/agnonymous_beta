class GlobalStats {
  final int totalPosts;
  final int totalVotes;
  final int totalComments;

  GlobalStats({
    required this.totalPosts,
    required this.totalVotes,
    required this.totalComments,
  });

  factory GlobalStats.fromMap(Map<String, dynamic> map) {
    return GlobalStats(
      totalPosts: (map['total_posts'] ?? 0).toInt(),
      totalVotes: (map['total_votes'] ?? 0).toInt(),
      totalComments: (map['total_comments'] ?? 0).toInt(),
    );
  }
}

class TrendingStats {
  final String trendingCategory;
  final String mostPopularPostTitle;

  TrendingStats({
    required this.trendingCategory,
    required this.mostPopularPostTitle,
  });

  factory TrendingStats.fromMap(Map<String, dynamic> map) {
    return TrendingStats(
      trendingCategory: map['trending_category'] ?? 'General',
      mostPopularPostTitle: map['most_popular_post_title'] ?? 'No posts yet',
    );
  }
}
