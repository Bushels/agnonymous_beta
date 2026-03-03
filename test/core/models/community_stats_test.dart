import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/core/models/community_stats.dart';

void main() {
  group('GlobalStats', () {
    group('fromMap()', () {
      test('constructs correctly from a full map', () {
        final map = {
          'total_posts': 150,
          'total_votes': 3200,
          'total_comments': 890,
        };

        final stats = GlobalStats.fromMap(map);

        expect(stats.totalPosts, 150);
        expect(stats.totalVotes, 3200);
        expect(stats.totalComments, 890);
      });

      test('handles zero values', () {
        final map = {
          'total_posts': 0,
          'total_votes': 0,
          'total_comments': 0,
        };

        final stats = GlobalStats.fromMap(map);

        expect(stats.totalPosts, 0);
        expect(stats.totalVotes, 0);
        expect(stats.totalComments, 0);
      });

      test('handles missing fields by defaulting to 0', () {
        final stats = GlobalStats.fromMap({});

        expect(stats.totalPosts, 0);
        expect(stats.totalVotes, 0);
        expect(stats.totalComments, 0);
      });

      test('handles null values by defaulting to 0', () {
        final map = {
          'total_posts': null,
          'total_votes': null,
          'total_comments': null,
        };

        final stats = GlobalStats.fromMap(map);

        expect(stats.totalPosts, 0);
        expect(stats.totalVotes, 0);
        expect(stats.totalComments, 0);
      });

      test('handles double values by converting to int', () {
        final map = {
          'total_posts': 100.0,
          'total_votes': 500.0,
          'total_comments': 250.0,
        };

        final stats = GlobalStats.fromMap(map);

        expect(stats.totalPosts, 100);
        expect(stats.totalVotes, 500);
        expect(stats.totalComments, 250);
      });

      test('handles large values', () {
        final map = {
          'total_posts': 999999,
          'total_votes': 5000000,
          'total_comments': 2500000,
        };

        final stats = GlobalStats.fromMap(map);

        expect(stats.totalPosts, 999999);
        expect(stats.totalVotes, 5000000);
        expect(stats.totalComments, 2500000);
      });
    });
  });

  group('TrendingStats', () {
    group('fromMap()', () {
      test('constructs correctly from a full map', () {
        final map = {
          'trending_category': 'Markets',
          'most_popular_post_title': 'Canola prices surge to record highs',
        };

        final stats = TrendingStats.fromMap(map);

        expect(stats.trendingCategory, 'Markets');
        expect(
            stats.mostPopularPostTitle, 'Canola prices surge to record highs');
      });

      test('handles missing trending_category with default', () {
        final stats = TrendingStats.fromMap({
          'most_popular_post_title': 'Some post title',
        });

        expect(stats.trendingCategory, 'General');
      });

      test('handles missing most_popular_post_title with default', () {
        final stats = TrendingStats.fromMap({
          'trending_category': 'Farming',
        });

        expect(stats.mostPopularPostTitle, 'No posts yet');
      });

      test('handles null fields with defaults', () {
        final stats = TrendingStats.fromMap({
          'trending_category': null,
          'most_popular_post_title': null,
        });

        expect(stats.trendingCategory, 'General');
        expect(stats.mostPopularPostTitle, 'No posts yet');
      });

      test('handles completely empty map', () {
        final stats = TrendingStats.fromMap({});

        expect(stats.trendingCategory, 'General');
        expect(stats.mostPopularPostTitle, 'No posts yet');
      });

      test('preserves special characters in fields', () {
        final stats = TrendingStats.fromMap({
          'trending_category': 'Input Prices',
          'most_popular_post_title':
              'Urea \$800/tonne - is this the new normal?',
        });

        expect(stats.trendingCategory, 'Input Prices');
        expect(stats.mostPopularPostTitle,
            'Urea \$800/tonne - is this the new normal?');
      });
    });
  });
}
