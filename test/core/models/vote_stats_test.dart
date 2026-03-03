import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/core/models/vote_stats.dart';

void main() {
  group('VoteStats', () {
    group('fromMap()', () {
      test('constructs correctly from a full map', () {
        final map = {
          'thumbs_up_votes': 10,
          'partial_votes': 5,
          'thumbs_down_votes': 3,
          'funny_votes': 7,
        };

        final stats = VoteStats.fromMap(map);

        expect(stats.thumbsUpVotes, 10);
        expect(stats.partialVotes, 5);
        expect(stats.thumbsDownVotes, 3);
        expect(stats.funnyVotes, 7);
      });

      test('handles missing fields by defaulting to 0', () {
        final stats = VoteStats.fromMap({});

        expect(stats.thumbsUpVotes, 0);
        expect(stats.partialVotes, 0);
        expect(stats.thumbsDownVotes, 0);
        expect(stats.funnyVotes, 0);
      });

      test('handles null values by defaulting to 0', () {
        final map = {
          'thumbs_up_votes': null,
          'partial_votes': null,
          'thumbs_down_votes': null,
          'funny_votes': null,
        };

        final stats = VoteStats.fromMap(map);

        expect(stats.thumbsUpVotes, 0);
        expect(stats.partialVotes, 0);
        expect(stats.thumbsDownVotes, 0);
        expect(stats.funnyVotes, 0);
      });

      test('handles double values by converting to int', () {
        final map = {
          'thumbs_up_votes': 10.0,
          'partial_votes': 5.0,
          'thumbs_down_votes': 3.0,
          'funny_votes': 7.0,
        };

        final stats = VoteStats.fromMap(map);

        expect(stats.thumbsUpVotes, 10);
        expect(stats.partialVotes, 5);
        expect(stats.thumbsDownVotes, 3);
        expect(stats.funnyVotes, 7);
      });
    });

    group('totalVotes', () {
      test('correctly sums all vote types', () {
        final stats = VoteStats.fromMap({
          'thumbs_up_votes': 10,
          'partial_votes': 5,
          'thumbs_down_votes': 3,
          'funny_votes': 7,
        });

        expect(stats.totalVotes, 25);
      });

      test('returns 0 when all votes are 0', () {
        final stats = VoteStats.fromMap({});

        expect(stats.totalVotes, 0);
      });

      test('handles single vote type', () {
        final stats = VoteStats.fromMap({
          'thumbs_up_votes': 42,
        });

        expect(stats.totalVotes, 42);
      });

      test('correctly sums large numbers', () {
        final stats = VoteStats.fromMap({
          'thumbs_up_votes': 1000,
          'partial_votes': 2000,
          'thumbs_down_votes': 3000,
          'funny_votes': 4000,
        });

        expect(stats.totalVotes, 10000);
      });
    });

    group('constructor', () {
      test('calculates totalVotes from named parameters', () {
        final stats = VoteStats(
          thumbsUpVotes: 15,
          partialVotes: 8,
          thumbsDownVotes: 2,
          funnyVotes: 5,
        );

        expect(stats.totalVotes, 30);
      });
    });
  });
}
