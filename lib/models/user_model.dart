import 'package:flutter/foundation.dart';

/// User model representing an authenticated user in the system
class AppUser {
  final String id;
  final String authUserId; // Supabase auth.users ID
  final String username;
  final String usernameLowercase;
  final String? displayName;
  final String? bio;
  final bool emailVerified;
  final int points;
  final int reputationScore;
  final List<String> badges;
  final bool defaultAnonymous;
  final bool showVerifiedBadge;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastSeenAt;

  const AppUser({
    required this.id,
    required this.authUserId,
    required this.username,
    required this.usernameLowercase,
    this.displayName,
    this.bio,
    required this.emailVerified,
    required this.points,
    required this.reputationScore,
    required this.badges,
    required this.defaultAnonymous,
    required this.showVerifiedBadge,
    required this.createdAt,
    required this.updatedAt,
    required this.lastSeenAt,
  });

  /// Get display name (falls back to username if not set)
  String get effectiveDisplayName => displayName ?? username;

  /// Check if user has a specific badge
  bool hasBadge(String badgeName) => badges.contains(badgeName);

  /// Create from Supabase JSON
  factory AppUser.fromMap(Map<String, dynamic> map) {
    // Parse badges from JSONB
    List<String> badgesList = [];
    if (map['badges'] != null) {
      if (map['badges'] is List) {
        badgesList = (map['badges'] as List).map((e) => e.toString()).toList();
      } else if (map['badges'] is String) {
        // Sometimes JSONB comes as string, try to parse
        try {
          final decoded = map['badges'];
          if (decoded is List) {
            badgesList = decoded.map((e) => e.toString()).toList();
          }
        } catch (e) {
          if (kDebugMode) print('Error parsing badges: $e');
        }
      }
    }

    return AppUser(
      id: map['id'] as String,
      authUserId: map['auth_user_id'] as String,
      username: map['username'] as String,
      usernameLowercase: map['username_lowercase'] as String,
      displayName: map['display_name'] as String?,
      bio: map['bio'] as String?,
      emailVerified: map['email_verified'] == true,
      points: (map['points'] ?? 0) as int,
      reputationScore: (map['reputation_score'] ?? 0) as int,
      badges: badgesList,
      defaultAnonymous: map['default_anonymous'] == true,
      showVerifiedBadge: map['show_verified_badge'] != false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      lastSeenAt: DateTime.parse(map['last_seen_at'] as String),
    );
  }

  /// Convert to map for Supabase updates
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'auth_user_id': authUserId,
      'username': username,
      'username_lowercase': usernameLowercase,
      'display_name': displayName,
      'bio': bio,
      'email_verified': emailVerified,
      'points': points,
      'reputation_score': reputationScore,
      'badges': badges,
      'default_anonymous': defaultAnonymous,
      'show_verified_badge': showVerifiedBadge,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_seen_at': lastSeenAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  AppUser copyWith({
    String? id,
    String? authUserId,
    String? username,
    String? usernameLowercase,
    String? displayName,
    String? bio,
    bool? emailVerified,
    int? points,
    int? reputationScore,
    List<String>? badges,
    bool? defaultAnonymous,
    bool? showVerifiedBadge,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSeenAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      authUserId: authUserId ?? this.authUserId,
      username: username ?? this.username,
      usernameLowercase: usernameLowercase ?? this.usernameLowercase,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      emailVerified: emailVerified ?? this.emailVerified,
      points: points ?? this.points,
      reputationScore: reputationScore ?? this.reputationScore,
      badges: badges ?? this.badges,
      defaultAnonymous: defaultAnonymous ?? this.defaultAnonymous,
      showVerifiedBadge: showVerifiedBadge ?? this.showVerifiedBadge,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return 'AppUser(username: $username, verified: $emailVerified, points: $points)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppUser &&
        other.id == id &&
        other.username == username &&
        other.emailVerified == emailVerified;
  }

  @override
  int get hashCode => id.hashCode ^ username.hashCode ^ emailVerified.hashCode;
}

/// Simplified user info for display on posts/comments
class UserDisplayInfo {
  final String username;
  final String displayName;
  final bool verified;
  final int points;
  final List<String> badges;

  const UserDisplayInfo({
    required this.username,
    required this.displayName,
    required this.verified,
    required this.points,
    required this.badges,
  });

  factory UserDisplayInfo.fromMap(Map<String, dynamic> map) {
    List<String> badgesList = [];
    if (map['badges'] != null && map['badges'] is List) {
      badgesList = (map['badges'] as List).map((e) => e.toString()).toList();
    }

    return UserDisplayInfo(
      username: map['username'] as String,
      displayName: map['display_name'] as String,
      verified: map['verified'] == true,
      points: (map['points'] ?? 0) as int,
      badges: badgesList,
    );
  }
}
