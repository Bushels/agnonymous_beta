import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/models/user_profile.dart';

void main() {
  group('UserProfile Model Security Tests', () {
    test(
        'toPublicMap() does not expose email or verification status directly in public scope',
        () {
      final profile = UserProfile(
        id: 'user-123',
        username: 'farmer_joe',
        email: 'joe@example.com',
        emailVerified: true,
        createdAt: DateTime.parse('2026-06-25T12:00:00Z'),
        updatedAt: DateTime.parse('2026-06-25T12:00:00Z'),
      );

      final publicMap = profile.toPublicMap();

      expect(publicMap.containsKey('email'), isFalse,
          reason: 'Public map must not contain email');
      expect(publicMap.containsKey('email_verified'), isFalse,
          reason: 'Public map must not contain email_verified');
    });

    test('toPrivateMap() contains correct email and verification status', () {
      final profile = UserProfile(
        id: 'user-123',
        username: 'farmer_joe',
        email: 'joe@example.com',
        emailVerified: true,
        createdAt: DateTime.parse('2026-06-25T12:00:00Z'),
        updatedAt: DateTime.parse('2026-06-25T12:00:00Z'),
      );

      final privateMap = profile.toPrivateMap();

      expect(privateMap['email'], 'joe@example.com');
      expect(privateMap['email_verified'], isTrue);
    });

    test(
        'fromMap() can construct successfully from public + private combined maps',
        () {
      final publicMap = {
        'id': 'user-123',
        'username': 'farmer_joe',
        'created_at': '2026-06-25T12:00:00Z',
        'updated_at': '2026-06-25T12:00:00Z',
      };

      final privateMap = {
        'email': 'joe@example.com',
        'email_verified': true,
      };

      final combined = {
        ...publicMap,
        ...privateMap,
      };

      final profile = UserProfile.fromMap(combined);

      expect(profile.id, 'user-123');
      expect(profile.username, 'farmer_joe');
      expect(profile.email, 'joe@example.com');
      expect(profile.emailVerified, isTrue);
    });
  });
}
