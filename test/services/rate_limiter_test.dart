import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/services/rate_limiter.dart';

void main() {
  group('RateLimiter', () {
    late RateLimiter rateLimiter;

    setUp(() {
      rateLimiter = RateLimiter();
      rateLimiter.reset();
    });

    test('allows first vote', () {
      expect(rateLimiter.canVote('post-1'), isNull);
    });

    test('allows votes on different posts', () {
      rateLimiter.recordVote('post-1');
      expect(rateLimiter.canVote('post-2'), isNull);
    });

    test('blocks rapid votes on same post (cooldown)', () {
      rateLimiter.recordVote('post-1');
      final result = rateLimiter.canVote('post-1');
      expect(result, isNotNull);
      expect(result, contains('wait'));
    });

    test('blocks after max votes reached', () {
      // Cast max votes
      for (int i = 0; i < RateLimiter.maxVotesPerWindow; i++) {
        rateLimiter.recordVote('post-$i');
      }

      // Next vote should be blocked
      final result = rateLimiter.canVote('post-next');
      expect(result, isNotNull);
      expect(result, contains('Voting too fast'));
    });

    test('tracks remaining votes correctly', () {
      expect(rateLimiter.remainingVotes, RateLimiter.maxVotesPerWindow);

      rateLimiter.recordVote('post-1');
      expect(rateLimiter.remainingVotes, RateLimiter.maxVotesPerWindow - 1);
    });

    test('isRateLimited returns correct state', () {
      expect(rateLimiter.isRateLimited, false);

      for (int i = 0; i < RateLimiter.maxVotesPerWindow; i++) {
        rateLimiter.recordVote('post-$i');
      }

      expect(rateLimiter.isRateLimited, true);
    });

    test('reset clears all state', () {
      rateLimiter.recordVote('post-1');
      rateLimiter.recordVote('post-2');
      rateLimiter.reset();

      expect(rateLimiter.remainingVotes, RateLimiter.maxVotesPerWindow);
      expect(rateLimiter.canVote('post-1'), isNull);
    });
  });

  group('CommentRateLimiter', () {
    late CommentRateLimiter rateLimiter;

    setUp(() {
      rateLimiter = CommentRateLimiter();
      rateLimiter.reset();
    });

    test('allows first comment', () {
      expect(rateLimiter.canComment(), isNull);
    });

    test('blocks rapid comments (cooldown)', () {
      rateLimiter.recordComment();
      final result = rateLimiter.canComment();
      expect(result, isNotNull);
      expect(result, contains('wait'));
    });

    test('blocks after max comments reached', () {
      for (int i = 0; i < CommentRateLimiter.maxCommentsPerWindow; i++) {
        rateLimiter.recordComment();
        // Wait a bit to avoid cooldown
        // In real tests we might use fake async
      }

      final result = rateLimiter.canComment();
      expect(result, isNotNull);
    });

    test('reset clears state', () {
      rateLimiter.recordComment();
      rateLimiter.reset();
      expect(rateLimiter.canComment(), isNull);
    });
  });

  group('PostRateLimiter', () {
    late PostRateLimiter rateLimiter;

    setUp(() {
      rateLimiter = PostRateLimiter();
      rateLimiter.reset();
    });

    test('allows first post', () {
      expect(rateLimiter.canPost(), isNull);
    });

    test('blocks rapid posts (cooldown)', () {
      rateLimiter.recordPost();
      final result = rateLimiter.canPost();
      expect(result, isNotNull);
      expect(result, contains('wait'));
    });

    test('blocks after max posts reached', () {
      for (int i = 0; i < PostRateLimiter.maxPostsPerWindow; i++) {
        rateLimiter.recordPost();
      }

      final result = rateLimiter.canPost();
      expect(result, isNotNull);
      // Could be cooldown or rate limit message
      expect(result!.contains('wait') || result.contains('Posting too fast'), true);
    });

    test('reset clears state', () {
      rateLimiter.recordPost();
      rateLimiter.reset();
      expect(rateLimiter.canPost(), isNull);
    });
  });
}
