import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/core/models/post.dart';
import 'package:agnonymous_beta/models/user_profile.dart' show TruthMeterStatus;

void main() {
  group('Post', () {
    group('fromMap()', () {
      test('constructs correctly from a map with all fields', () {
        final map = {
          'id': 'post-123',
          'title': 'Grain prices rising',
          'content': 'Canola hit record highs this week.',
          'category': 'Markets',
          'province_state': 'SK',
          'created_at': '2026-03-01T12:00:00Z',
          'comment_count': 5,
          'vote_count': 12,
          'truth_meter_score': 85.5,
          'truth_meter_status': 'likely_true',
          'admin_verified': true,
          'verified_at': '2026-03-02T08:00:00Z',
          'verified_by': 'admin-1',
          'thumbs_up_count': 10,
          'thumbs_down_count': 1,
          'partial_count': 2,
          'funny_count': 3,
          'user_id': 'user-456',
          'is_anonymous': false,
          'author_username': 'FarmerJoe',
          'author_verified': true,
          'is_deleted': false,
          'deleted_at': null,
          'edited_at': '2026-03-01T14:00:00Z',
          'edit_count': 1,
          'image_url': 'https://example.com/receipt.jpg',
        };

        final post = Post.fromMap(map);

        expect(post.id, 'post-123');
        expect(post.title, 'Grain prices rising');
        expect(post.content, 'Canola hit record highs this week.');
        expect(post.category, 'Markets');
        expect(post.provinceState, 'SK');
        expect(post.createdAt, DateTime.parse('2026-03-01T12:00:00Z'));
        expect(post.commentCount, 5);
        expect(post.voteCount, 12);
        expect(post.truthMeterScore, 85.5);
        expect(post.truthMeterStatus, TruthMeterStatus.likelyTrue);
        expect(post.adminVerified, true);
        expect(post.verifiedAt, DateTime.parse('2026-03-02T08:00:00Z'));
        expect(post.verifiedBy, 'admin-1');
        expect(post.thumbsUpCount, 10);
        expect(post.thumbsDownCount, 1);
        expect(post.partialCount, 2);
        expect(post.funnyCount, 3);
        expect(post.userId, 'user-456');
        expect(post.isAnonymous, false);
        expect(post.authorUsername, 'FarmerJoe');
        expect(post.authorVerified, true);
        expect(post.isDeleted, false);
        expect(post.deletedAt, isNull);
        expect(post.editedAt, DateTime.parse('2026-03-01T14:00:00Z'));
        expect(post.editCount, 1);
        expect(post.imageUrl, 'https://example.com/receipt.jpg');
      });

      test('handles missing/null optional fields with defaults', () {
        final map = {
          'id': 'post-minimal',
          'created_at': '2026-01-15T09:30:00Z',
        };

        final post = Post.fromMap(map);

        expect(post.id, 'post-minimal');
        expect(post.title, 'Untitled');
        expect(post.content, '');
        expect(post.category, 'General');
        expect(post.provinceState, isNull);
        expect(post.createdAt, DateTime.parse('2026-01-15T09:30:00Z'));
        expect(post.commentCount, 0);
        expect(post.voteCount, 0);
        expect(post.truthMeterScore, 0.0);
        expect(post.truthMeterStatus, TruthMeterStatus.unrated);
        expect(post.adminVerified, false);
        expect(post.verifiedAt, isNull);
        expect(post.verifiedBy, isNull);
        expect(post.thumbsUpCount, 0);
        expect(post.thumbsDownCount, 0);
        expect(post.partialCount, 0);
        expect(post.funnyCount, 0);
        expect(post.userId, isNull);
        expect(post.isAnonymous, true);
        expect(post.authorUsername, isNull);
        expect(post.authorVerified, false);
        expect(post.isDeleted, false);
        expect(post.deletedAt, isNull);
        expect(post.editedAt, isNull);
        expect(post.editCount, 0);
        expect(post.imageUrl, isNull);
      });

      test('handles null id gracefully (defaults to empty string)', () {
        final map = {
          'id': null,
          'created_at': '2026-02-01T00:00:00Z',
        };

        final post = Post.fromMap(map);
        expect(post.id, '');
      });

      test('parses truth_meter_status string correctly', () {
        final statuses = {
          'unrated': TruthMeterStatus.unrated,
          'rumour': TruthMeterStatus.rumour,
          'questionable': TruthMeterStatus.questionable,
          'partially_true': TruthMeterStatus.partiallyTrue,
          'likely_true': TruthMeterStatus.likelyTrue,
          'verified_community': TruthMeterStatus.verifiedCommunity,
          'verified_truth': TruthMeterStatus.verifiedTruth,
        };

        for (final entry in statuses.entries) {
          final post = Post.fromMap({
            'created_at': '2026-01-01T00:00:00Z',
            'truth_meter_status': entry.key,
          });
          expect(post.truthMeterStatus, entry.value,
              reason: 'Status "${entry.key}" should map to ${entry.value}');
        }
      });

      test('handles unknown truth_meter_status by defaulting to unrated', () {
        final post = Post.fromMap({
          'created_at': '2026-01-01T00:00:00Z',
          'truth_meter_status': 'some_unknown_status',
        });
        expect(post.truthMeterStatus, TruthMeterStatus.unrated);
      });

      test('handles truth_meter_score as int (cast to double)', () {
        final post = Post.fromMap({
          'created_at': '2026-01-01T00:00:00Z',
          'truth_meter_score': 75,
        });
        expect(post.truthMeterScore, 75.0);
      });
    });

    group('authorDisplay', () {
      test('returns "Anonymous" when isAnonymous is true', () {
        final post = Post.fromMap({
          'created_at': '2026-01-01T00:00:00Z',
          'is_anonymous': true,
          'author_username': 'ShouldNotShow',
        });
        expect(post.authorDisplay, 'Anonymous');
      });

      test('returns username when not anonymous and username is set', () {
        final post = Post.fromMap({
          'created_at': '2026-01-01T00:00:00Z',
          'is_anonymous': false,
          'author_username': 'PrairieFarmer',
        });
        expect(post.authorDisplay, 'PrairieFarmer');
      });

      test('returns "Unknown User" when not anonymous and username is null',
          () {
        final post = Post.fromMap({
          'created_at': '2026-01-01T00:00:00Z',
          'is_anonymous': false,
          'author_username': null,
        });
        expect(post.authorDisplay, 'Unknown User');
      });
    });

    group('authorBadge', () {
      test('returns mask emoji when anonymous', () {
        final post = Post.fromMap({
          'created_at': '2026-01-01T00:00:00Z',
          'is_anonymous': true,
        });
        expect(post.authorBadge, '\u{1F3AD}'); // mask emoji
      });

      test('returns checkmark emoji when not anonymous and verified', () {
        final post = Post.fromMap({
          'created_at': '2026-01-01T00:00:00Z',
          'is_anonymous': false,
          'author_verified': true,
        });
        expect(post.authorBadge, '\u2705'); // checkmark emoji
      });

      test('returns warning emoji when not anonymous and not verified', () {
        final post = Post.fromMap({
          'created_at': '2026-01-01T00:00:00Z',
          'is_anonymous': false,
          'author_verified': false,
        });
        expect(post.authorBadge, '\u26A0\uFE0F'); // warning emoji
      });
    });

    group('wasEdited', () {
      test('returns true when editCount is greater than 0', () {
        final post = Post.fromMap({
          'created_at': '2026-01-01T00:00:00Z',
          'edit_count': 2,
        });
        expect(post.wasEdited, true);
      });

      test('returns false when editCount is 0', () {
        final post = Post.fromMap({
          'created_at': '2026-01-01T00:00:00Z',
          'edit_count': 0,
        });
        expect(post.wasEdited, false);
      });

      test('returns false when editCount is not provided (defaults to 0)', () {
        final post = Post.fromMap({
          'created_at': '2026-01-01T00:00:00Z',
        });
        expect(post.wasEdited, false);
      });
    });
  });
}
