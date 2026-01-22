import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../main.dart' show supabase, Post;
import '../widgets/truth_meter.dart';
import '../screens/post_details_screen.dart';

/// Provider for trending posts
final trendingPostsProvider = FutureProvider<List<Post>>((ref) async {
  // Get posts with highest recent activity (votes + comments in last 7 days)
  final response = await supabase
      .from('posts')
      .select()
      .gte('created_at', DateTime.now().subtract(const Duration(days: 7)).toIso8601String())
      .order('vote_count', ascending: false)
      .order('comment_count', ascending: false)
      .limit(10);

  return (response as List<dynamic>)
      .map((e) => Post.fromMap(e as Map<String, dynamic>))
      .toList();
});

/// Trending posts widget
class TrendingPostsWidget extends ConsumerWidget {
  final int maxPosts;

  const TrendingPostsWidget({
    super.key,
    this.maxPosts = 5,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingPosts = ref.watch(trendingPostsProvider);

    return trendingPosts.when(
      data: (posts) {
        if (posts.isEmpty) {
          return _buildEmptyState();
        }

        final displayPosts = posts.take(maxPosts).toList();

        return Column(
          children: displayPosts.map((post) => _buildTrendingCard(context, post)).toList(),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Failed to load trending posts',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.trending_down, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No trending posts yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to post!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingCard(BuildContext context, Post post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PostDetailsScreen(postId: post.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Truth meter + metadata
                Row(
                  children: [
                    Expanded(
                      child: TruthMeter(
                        status: post.truthMeterStatus,
                        score: post.truthMeterScore,
                        voteCount: post.voteCount,
                        thumbsUp: post.thumbsUpCount,
                        thumbsDown: post.thumbsDownCount,
                        partial: post.partialCount,
                        funny: post.funnyCount,
                        compact: true,
                        showVoteBreakdown: false,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d').format(post.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Title
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                // Content preview
                Text(
                  post.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 12),

                // Footer: Category + engagement stats
                Row(
                  children: [
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        post.category,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Engagement stats
                    _buildStat(Icons.thumb_up, post.thumbsUpCount, Colors.green),
                    const SizedBox(width: 12),
                    _buildStat(Icons.comment, post.commentCount, Colors.blue),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
