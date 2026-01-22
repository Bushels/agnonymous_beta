import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/models/user_profile.dart';

void main() {
  group('UserProfile', () {
    final testDate = DateTime(2024, 1, 15, 10, 30);

    test('creates instance with required fields', () {
      final profile = UserProfile(
        id: 'user-123',
        username: 'testuser',
        emailVerified: false,
        createdAt: testDate,
        updatedAt: testDate,
      );

      expect(profile.id, 'user-123');
      expect(profile.username, 'testuser');
      expect(profile.email, isNull);
      expect(profile.emailVerified, false);
      expect(profile.reputationPoints, 0);
      expect(profile.reputationLevel, 0);
      expect(profile.voteWeight, 1.0);
    });

    test('creates instance with all fields', () {
      final profile = UserProfile(
        id: 'user-456',
        username: 'fulluser',
        email: 'test@example.com',
        emailVerified: true,
        createdAt: testDate,
        updatedAt: testDate,
        provinceState: 'Saskatchewan',
        bio: 'Farmer from SK',
        reputationPoints: 500,
        publicReputation: 400,
        anonymousReputation: 100,
        reputationLevel: 4,
        voteWeight: 1.3,
        postCount: 10,
        commentCount: 25,
        voteCount: 100,
      );

      expect(profile.email, 'test@example.com');
      expect(profile.provinceState, 'Saskatchewan');
      expect(profile.bio, 'Farmer from SK');
      expect(profile.reputationPoints, 500);
      expect(profile.publicReputation, 400);
      expect(profile.anonymousReputation, 100);
      expect(profile.reputationLevel, 4);
      expect(profile.voteWeight, 1.3);
      expect(profile.postCount, 10);
      expect(profile.commentCount, 25);
      expect(profile.voteCount, 100);
    });

    group('fromMap', () {
      test('parses valid map correctly', () {
        final map = {
          'id': 'user-789',
          'username': 'mapuser',
          'email': 'map@test.com',
          'email_verified': true,
          'created_at': '2024-01-15T10:30:00.000',
          'updated_at': '2024-01-15T10:30:00.000',
          'province_state': 'Alberta',
          'bio': 'Test bio',
          'reputation_points': 250,
          'public_reputation': 200,
          'anonymous_reputation': 50,
          'reputation_level': 2,
          'vote_weight': 1.1,
          'post_count': 5,
          'comment_count': 15,
          'vote_count': 50,
        };

        final profile = UserProfile.fromMap(map);

        expect(profile.id, 'user-789');
        expect(profile.username, 'mapuser');
        expect(profile.email, 'map@test.com');
        expect(profile.emailVerified, true);
        expect(profile.provinceState, 'Alberta');
        expect(profile.reputationPoints, 250);
        expect(profile.reputationLevel, 2);
        expect(profile.voteWeight, 1.1);
      });

      test('handles null optional fields', () {
        final map = {
          'id': 'user-minimal',
          'username': 'minimaluser',
          'email_verified': false,
          'created_at': '2024-01-15T10:30:00.000',
          'updated_at': '2024-01-15T10:30:00.000',
        };

        final profile = UserProfile.fromMap(map);

        expect(profile.email, isNull);
        expect(profile.provinceState, isNull);
        expect(profile.bio, isNull);
        expect(profile.reputationPoints, 0);
        expect(profile.voteWeight, 1.0);
      });

      test('handles numeric vote_weight as double', () {
        final map = {
          'id': 'user-numeric',
          'username': 'numericuser',
          'created_at': '2024-01-15T10:30:00.000',
          'updated_at': '2024-01-15T10:30:00.000',
          'vote_weight': 2, // int instead of double
        };

        final profile = UserProfile.fromMap(map);
        expect(profile.voteWeight, 2.0);
      });
    });

    group('toMap', () {
      test('converts to map correctly', () {
        final profile = UserProfile(
          id: 'user-tomap',
          username: 'tomapuser',
          email: 'tomap@test.com',
          emailVerified: true,
          createdAt: testDate,
          updatedAt: testDate,
          provinceState: 'Ontario',
          reputationPoints: 100,
        );

        final map = profile.toMap();

        expect(map['id'], 'user-tomap');
        expect(map['username'], 'tomapuser');
        expect(map['email'], 'tomap@test.com');
        expect(map['email_verified'], true);
        expect(map['province_state'], 'Ontario');
        expect(map['reputation_points'], 100);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = UserProfile(
          id: 'user-original',
          username: 'originaluser',
          emailVerified: false,
          createdAt: testDate,
          updatedAt: testDate,
          reputationPoints: 50,
        );

        final copy = original.copyWith(
          username: 'updateduser',
          reputationPoints: 100,
          emailVerified: true,
        );

        expect(copy.id, 'user-original'); // unchanged
        expect(copy.username, 'updateduser');
        expect(copy.reputationPoints, 100);
        expect(copy.emailVerified, true);
      });

      test('preserves original when no changes', () {
        final original = UserProfile(
          id: 'user-preserve',
          username: 'preserveuser',
          emailVerified: true,
          createdAt: testDate,
          updatedAt: testDate,
          reputationPoints: 200,
        );

        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.username, original.username);
        expect(copy.reputationPoints, original.reputationPoints);
      });
    });

    group('levelInfo', () {
      test('returns correct level info', () {
        final profile = UserProfile(
          id: 'user-level',
          username: 'leveluser',
          emailVerified: false,
          createdAt: testDate,
          updatedAt: testDate,
          reputationLevel: 5,
        );

        final levelInfo = profile.levelInfo;

        expect(levelInfo.level, 5);
        expect(levelInfo.title, 'Trusted Reporter');
        expect(levelInfo.voteWeight, 1.5);
      });
    });

    group('pointsToNextLevel', () {
      test('calculates points needed for level 0 user', () {
        final profile = UserProfile(
          id: 'user-pts',
          username: 'ptsuser',
          emailVerified: false,
          createdAt: testDate,
          updatedAt: testDate,
          reputationPoints: 30,
          reputationLevel: 0,
        );

        expect(profile.pointsToNextLevel, 20); // 50 - 30 = 20
      });

      test('calculates points for mid-level user', () {
        final profile = UserProfile(
          id: 'user-mid',
          username: 'miduser',
          emailVerified: false,
          createdAt: testDate,
          updatedAt: testDate,
          reputationPoints: 600,
          reputationLevel: 4,
        );

        expect(profile.pointsToNextLevel, 150); // 750 - 600 = 150
      });
    });

    group('progressToNextLevel', () {
      test('returns 0 progress at level start', () {
        final profile = UserProfile(
          id: 'user-start',
          username: 'startuser',
          emailVerified: false,
          createdAt: testDate,
          updatedAt: testDate,
          reputationPoints: 50,
          reputationLevel: 1,
        );

        expect(profile.progressToNextLevel, 0.0);
      });

      test('returns correct mid-progress', () {
        final profile = UserProfile(
          id: 'user-mid',
          username: 'midprogress',
          emailVerified: false,
          createdAt: testDate,
          updatedAt: testDate,
          reputationPoints: 100, // 50 into range of 100 (50 to 150)
          reputationLevel: 1,
        );

        expect(profile.progressToNextLevel, 0.5);
      });

      test('clamps progress to 1.0 max', () {
        final profile = UserProfile(
          id: 'user-max',
          username: 'maxuser',
          emailVerified: false,
          createdAt: testDate,
          updatedAt: testDate,
          reputationPoints: 200, // More than level 1 range
          reputationLevel: 1,
        );

        expect(profile.progressToNextLevel, 1.0);
      });
    });

    group('equality', () {
      test('equals based on id', () {
        final profile1 = UserProfile(
          id: 'same-id',
          username: 'user1',
          emailVerified: false,
          createdAt: testDate,
          updatedAt: testDate,
        );

        final profile2 = UserProfile(
          id: 'same-id',
          username: 'user2', // different username
          emailVerified: true, // different verified status
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(profile1, equals(profile2));
        expect(profile1.hashCode, profile2.hashCode);
      });

      test('not equal with different ids', () {
        final profile1 = UserProfile(
          id: 'id-1',
          username: 'user',
          emailVerified: false,
          createdAt: testDate,
          updatedAt: testDate,
        );

        final profile2 = UserProfile(
          id: 'id-2',
          username: 'user',
          emailVerified: false,
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(profile1, isNot(equals(profile2)));
      });
    });

    test('toString returns readable format', () {
      final profile = UserProfile(
        id: 'user-str',
        username: 'struser',
        emailVerified: false,
        createdAt: testDate,
        updatedAt: testDate,
        reputationPoints: 150,
        reputationLevel: 2,
      );

      expect(profile.toString(), contains('struser'));
      expect(profile.toString(), contains('150'));
      expect(profile.toString(), contains('2'));
    });
  });

  group('ReputationLevelInfo', () {
    group('fromLevel', () {
      test('returns Seedling for level 0', () {
        final info = ReputationLevelInfo.fromLevel(0);
        expect(info.level, 0);
        expect(info.title, 'Seedling');
        expect(info.emoji, '🌱');
        expect(info.minPoints, 0);
        expect(info.voteWeight, 1.0);
      });

      test('returns Sprout for level 1', () {
        final info = ReputationLevelInfo.fromLevel(1);
        expect(info.level, 1);
        expect(info.title, 'Sprout');
        expect(info.minPoints, 50);
      });

      test('returns Growing for level 2', () {
        final info = ReputationLevelInfo.fromLevel(2);
        expect(info.level, 2);
        expect(info.title, 'Growing');
        expect(info.minPoints, 150);
        expect(info.voteWeight, 1.1);
      });

      test('returns Established for level 3', () {
        final info = ReputationLevelInfo.fromLevel(3);
        expect(info.title, 'Established');
        expect(info.minPoints, 300);
        expect(info.voteWeight, 1.2);
      });

      test('returns Reliable Source for level 4', () {
        final info = ReputationLevelInfo.fromLevel(4);
        expect(info.title, 'Reliable Source');
        expect(info.minPoints, 500);
        expect(info.voteWeight, 1.3);
      });

      test('returns Trusted Reporter for level 5', () {
        final info = ReputationLevelInfo.fromLevel(5);
        expect(info.title, 'Trusted Reporter');
        expect(info.minPoints, 750);
        expect(info.voteWeight, 1.5);
      });

      test('returns Expert Whistleblower for level 6', () {
        final info = ReputationLevelInfo.fromLevel(6);
        expect(info.title, 'Expert Whistleblower');
        expect(info.minPoints, 1000);
        expect(info.voteWeight, 1.7);
      });

      test('returns Truth Guardian for level 7', () {
        final info = ReputationLevelInfo.fromLevel(7);
        expect(info.title, 'Truth Guardian');
        expect(info.minPoints, 1500);
        expect(info.voteWeight, 2.0);
      });

      test('returns Master Investigator for level 8', () {
        final info = ReputationLevelInfo.fromLevel(8);
        expect(info.title, 'Master Investigator');
        expect(info.minPoints, 2500);
        expect(info.voteWeight, 2.5);
      });

      test('returns Legend for level 9', () {
        final info = ReputationLevelInfo.fromLevel(9);
        expect(info.title, 'Legend');
        expect(info.emoji, '👑');
        expect(info.minPoints, 5000);
        expect(info.voteWeight, 3.0);
      });

      test('returns Legend for levels above 9', () {
        final info = ReputationLevelInfo.fromLevel(15);
        expect(info.title, 'Legend');
        expect(info.level, 9);
      });
    });

    group('fromPoints', () {
      test('returns Seedling for 0 points', () {
        final info = ReputationLevelInfo.fromPoints(0);
        expect(info.level, 0);
        expect(info.title, 'Seedling');
      });

      test('returns Sprout for 50 points', () {
        final info = ReputationLevelInfo.fromPoints(50);
        expect(info.level, 1);
        expect(info.title, 'Sprout');
      });

      test('returns Sprout for 149 points', () {
        final info = ReputationLevelInfo.fromPoints(149);
        expect(info.level, 1);
      });

      test('returns Growing for 150 points', () {
        final info = ReputationLevelInfo.fromPoints(150);
        expect(info.level, 2);
        expect(info.title, 'Growing');
      });

      test('returns Established for 300 points', () {
        final info = ReputationLevelInfo.fromPoints(300);
        expect(info.level, 3);
      });

      test('returns Reliable Source for 500 points', () {
        final info = ReputationLevelInfo.fromPoints(500);
        expect(info.level, 4);
      });

      test('returns Trusted Reporter for 750 points', () {
        final info = ReputationLevelInfo.fromPoints(750);
        expect(info.level, 5);
      });

      test('returns Expert Whistleblower for 1000 points', () {
        final info = ReputationLevelInfo.fromPoints(1000);
        expect(info.level, 6);
      });

      test('returns Truth Guardian for 1500 points', () {
        final info = ReputationLevelInfo.fromPoints(1500);
        expect(info.level, 7);
      });

      test('returns Master Investigator for 2500 points', () {
        final info = ReputationLevelInfo.fromPoints(2500);
        expect(info.level, 8);
      });

      test('returns Legend for 5000+ points', () {
        final info = ReputationLevelInfo.fromPoints(5000);
        expect(info.level, 9);
        expect(info.title, 'Legend');
      });

      test('returns Legend for very high points', () {
        final info = ReputationLevelInfo.fromPoints(50000);
        expect(info.level, 9);
      });
    });
  });

  group('TruthMeterStatus', () {
    group('fromString', () {
      test('parses unrated', () {
        final status = TruthMeterStatus.fromString('unrated');
        expect(status, TruthMeterStatus.unrated);
      });

      test('parses rumour', () {
        final status = TruthMeterStatus.fromString('rumour');
        expect(status, TruthMeterStatus.rumour);
      });

      test('parses questionable', () {
        final status = TruthMeterStatus.fromString('questionable');
        expect(status, TruthMeterStatus.questionable);
      });

      test('parses partially_true', () {
        final status = TruthMeterStatus.fromString('partially_true');
        expect(status, TruthMeterStatus.partiallyTrue);
      });

      test('parses likely_true', () {
        final status = TruthMeterStatus.fromString('likely_true');
        expect(status, TruthMeterStatus.likelyTrue);
      });

      test('parses verified_community', () {
        final status = TruthMeterStatus.fromString('verified_community');
        expect(status, TruthMeterStatus.verifiedCommunity);
      });

      test('parses verified_truth', () {
        final status = TruthMeterStatus.fromString('verified_truth');
        expect(status, TruthMeterStatus.verifiedTruth);
      });

      test('returns unrated for unknown string', () {
        final status = TruthMeterStatus.fromString('invalid_status');
        expect(status, TruthMeterStatus.unrated);
      });
    });

    group('properties', () {
      test('unrated has correct properties', () {
        expect(TruthMeterStatus.unrated.value, 'unrated');
        expect(TruthMeterStatus.unrated.label, 'Unrated');
        expect(TruthMeterStatus.unrated.emoji, '❓');
        expect(TruthMeterStatus.unrated.severity, 0);
      });

      test('rumour has correct properties', () {
        expect(TruthMeterStatus.rumour.value, 'rumour');
        expect(TruthMeterStatus.rumour.label, 'Likely False');
        expect(TruthMeterStatus.rumour.severity, 1);
      });

      test('verifiedTruth has highest severity', () {
        expect(TruthMeterStatus.verifiedTruth.severity, 6);
        expect(TruthMeterStatus.verifiedTruth.label, 'Verified Truth');
      });
    });

    group('color', () {
      test('verifiedTruth returns blue', () {
        expect(TruthMeterStatus.verifiedTruth.color, const Color(0xFF2196F3));
      });

      test('verifiedCommunity returns green', () {
        expect(TruthMeterStatus.verifiedCommunity.color, const Color(0xFF4CAF50));
      });

      test('likelyTrue returns light green', () {
        expect(TruthMeterStatus.likelyTrue.color, const Color(0xFF8BC34A));
      });

      test('partiallyTrue returns yellow', () {
        expect(TruthMeterStatus.partiallyTrue.color, const Color(0xFFFFC107));
      });

      test('questionable returns orange', () {
        expect(TruthMeterStatus.questionable.color, const Color(0xFFFF9800));
      });

      test('rumour returns red', () {
        expect(TruthMeterStatus.rumour.color, const Color(0xFFF44336));
      });

      test('unrated returns gray', () {
        expect(TruthMeterStatus.unrated.color, const Color(0xFF9E9E9E));
      });
    });
  });
}
