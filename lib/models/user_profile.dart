import 'package:flutter/material.dart';

/// User profile model with reputation and gamification data
class UserProfile {
  final String id;
  final String username;
  final String? email;  // Nullable for anonymous users
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? provinceState;
  final String? bio;

  // Reputation & Gamification
  final int reputationPoints;
  final int publicReputation;
  final int anonymousReputation;
  final int reputationLevel;
  final double voteWeight;

  // Statistics
  final int postCount;
  final int commentCount;
  final int voteCount;

  UserProfile({
    required this.id,
    required this.username,
    this.email,  // Optional for anonymous users
    required this.emailVerified,
    required this.createdAt,
    required this.updatedAt,
    this.provinceState,
    this.bio,
    this.reputationPoints = 0,
    this.publicReputation = 0,
    this.anonymousReputation = 0,
    this.reputationLevel = 0,
    this.voteWeight = 1.0,
    this.postCount = 0,
    this.commentCount = 0,
    this.voteCount = 0,
  });

  /// Create from Supabase map
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      username: map['username'] as String,
      email: map['email'] as String?,  // Nullable for anonymous users
      emailVerified: map['email_verified'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      provinceState: map['province_state'] as String?,
      bio: map['bio'] as String?,
      reputationPoints: map['reputation_points'] as int? ?? 0,
      publicReputation: map['public_reputation'] as int? ?? 0,
      anonymousReputation: map['anonymous_reputation'] as int? ?? 0,
      reputationLevel: map['reputation_level'] as int? ?? 0,
      voteWeight: (map['vote_weight'] as num?)?.toDouble() ?? 1.0,
      postCount: map['post_count'] as int? ?? 0,
      commentCount: map['comment_count'] as int? ?? 0,
      voteCount: map['vote_count'] as int? ?? 0,
    );
  }

  /// Convert to map for Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'email_verified': emailVerified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'province_state': provinceState,
      'bio': bio,
      'reputation_points': reputationPoints,
      'public_reputation': publicReputation,
      'anonymous_reputation': anonymousReputation,
      'reputation_level': reputationLevel,
      'vote_weight': voteWeight,
      'post_count': postCount,
      'comment_count': commentCount,
      'vote_count': voteCount,
    };
  }

  /// Create a copy with updated fields
  UserProfile copyWith({
    String? id,
    String? username,
    String? email,
    bool? emailVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? provinceState,
    String? bio,
    int? reputationPoints,
    int? publicReputation,
    int? anonymousReputation,
    int? reputationLevel,
    double? voteWeight,
    int? postCount,
    int? commentCount,
    int? voteCount,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      provinceState: provinceState ?? this.provinceState,
      bio: bio ?? this.bio,
      reputationPoints: reputationPoints ?? this.reputationPoints,
      publicReputation: publicReputation ?? this.publicReputation,
      anonymousReputation: anonymousReputation ?? this.anonymousReputation,
      reputationLevel: reputationLevel ?? this.reputationLevel,
      voteWeight: voteWeight ?? this.voteWeight,
      postCount: postCount ?? this.postCount,
      commentCount: commentCount ?? this.commentCount,
      voteCount: voteCount ?? this.voteCount,
    );
  }

  /// Get reputation level info
  ReputationLevelInfo get levelInfo => ReputationLevelInfo.fromLevel(reputationLevel);

  /// Points needed for next level
  int get pointsToNextLevel {
    final nextLevelThreshold = ReputationLevelInfo.fromLevel(reputationLevel + 1).minPoints;
    return nextLevelThreshold - reputationPoints;
  }

  /// Progress to next level (0.0 to 1.0)
  double get progressToNextLevel {
    final currentLevelThreshold = levelInfo.minPoints;
    final nextLevelThreshold = ReputationLevelInfo.fromLevel(reputationLevel + 1).minPoints;
    final range = nextLevelThreshold - currentLevelThreshold;
    final progress = reputationPoints - currentLevelThreshold;
    return (progress / range).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UserProfile(username: $username, reputation: $reputationPoints, level: $reputationLevel)';
  }
}

/// Reputation level information
class ReputationLevelInfo {
  final int level;
  final String title;
  final String emoji;
  final int minPoints;
  final double voteWeight;
  final List<String> perks;

  const ReputationLevelInfo({
    required this.level,
    required this.title,
    required this.emoji,
    required this.minPoints,
    required this.voteWeight,
    required this.perks,
  });

  /// Get level info from level number
  static ReputationLevelInfo fromLevel(int level) {
    switch (level) {
      case 0:
        return const ReputationLevelInfo(
          level: 0,
          title: 'Seedling',
          emoji: '🌱',
          minPoints: 0,
          voteWeight: 1.0,
          perks: ['Basic posting and voting'],
        );
      case 1:
        return const ReputationLevelInfo(
          level: 1,
          title: 'Sprout',
          emoji: '🌿',
          minPoints: 50,
          voteWeight: 1.0,
          perks: ['Basic posting and voting'],
        );
      case 2:
        return const ReputationLevelInfo(
          level: 2,
          title: 'Growing',
          emoji: '🌾',
          minPoints: 150,
          voteWeight: 1.1,
          perks: ['Vote weight: 1.1x'],
        );
      case 3:
        return const ReputationLevelInfo(
          level: 3,
          title: 'Established',
          emoji: '🌳',
          minPoints: 300,
          voteWeight: 1.2,
          perks: ['Vote weight: 1.2x'],
        );
      case 4:
        return const ReputationLevelInfo(
          level: 4,
          title: 'Reliable Source',
          emoji: '⭐',
          minPoints: 500,
          voteWeight: 1.3,
          perks: ['Vote weight: 1.3x'],
        );
      case 5:
        return const ReputationLevelInfo(
          level: 5,
          title: 'Trusted Reporter',
          emoji: '⭐⭐',
          minPoints: 750,
          voteWeight: 1.5,
          perks: ['Vote weight: 1.5x', 'Can nominate posts for admin review'],
        );
      case 6:
        return const ReputationLevelInfo(
          level: 6,
          title: 'Expert Whistleblower',
          emoji: '⭐⭐⭐',
          minPoints: 1000,
          voteWeight: 1.7,
          perks: ['Vote weight: 1.7x', 'Can see partial voter stats'],
        );
      case 7:
        return const ReputationLevelInfo(
          level: 7,
          title: 'Truth Guardian',
          emoji: '🏅',
          minPoints: 1500,
          voteWeight: 2.0,
          perks: ['Vote weight: 2.0x', 'Can request admin verification'],
        );
      case 8:
        return const ReputationLevelInfo(
          level: 8,
          title: 'Master Investigator',
          emoji: '🏅🏅',
          minPoints: 2500,
          voteWeight: 2.5,
          perks: ['Vote weight: 2.5x', 'Eligible for moderator role'],
        );
      case 9:
        return const ReputationLevelInfo(
          level: 9,
          title: 'Legend',
          emoji: '👑',
          minPoints: 5000,
          voteWeight: 3.0,
          perks: ['Vote weight: 3.0x', 'Top leaderboard tier', 'Maximum influence'],
        );
      default:
        return const ReputationLevelInfo(
          level: 9,
          title: 'Legend',
          emoji: '👑',
          minPoints: 5000,
          voteWeight: 3.0,
          perks: ['Vote weight: 3.0x', 'Top leaderboard tier'],
        );
    }
  }

  /// Get level from points
  static ReputationLevelInfo fromPoints(int points) {
    if (points >= 5000) return fromLevel(9);
    if (points >= 2500) return fromLevel(8);
    if (points >= 1500) return fromLevel(7);
    if (points >= 1000) return fromLevel(6);
    if (points >= 750) return fromLevel(5);
    if (points >= 500) return fromLevel(4);
    if (points >= 300) return fromLevel(3);
    if (points >= 150) return fromLevel(2);
    if (points >= 50) return fromLevel(1);
    return fromLevel(0);
  }
}

/// Truth meter status for posts
enum TruthMeterStatus {
  unrated('unrated', 'Unrated', '❓', 0),
  rumour('rumour', 'Likely False', '🚨', 1),
  questionable('questionable', 'Questionable', '⚠️', 2),
  partiallyTrue('partially_true', 'Partially True', '🟡', 3),
  likelyTrue('likely_true', 'Likely True', '✓', 4),
  verifiedCommunity('verified_community', 'Verified by Community', '✓✓', 5),
  verifiedTruth('verified_truth', 'Verified Truth', '🛡️', 6);

  final String value;
  final String label;
  final String emoji;
  final int severity;

  const TruthMeterStatus(this.value, this.label, this.emoji, this.severity);

  static TruthMeterStatus fromString(String value) {
    return TruthMeterStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TruthMeterStatus.unrated,
    );
  }

  /// Get color for this status
  Color get color {
    switch (this) {
      case TruthMeterStatus.verifiedTruth:
        return const Color(0xFF2196F3); // Blue
      case TruthMeterStatus.verifiedCommunity:
        return const Color(0xFF4CAF50); // Green
      case TruthMeterStatus.likelyTrue:
        return const Color(0xFF8BC34A); // Light Green
      case TruthMeterStatus.partiallyTrue:
        return const Color(0xFFFFC107); // Yellow
      case TruthMeterStatus.questionable:
        return const Color(0xFFFF9800); // Orange
      case TruthMeterStatus.rumour:
        return const Color(0xFFF44336); // Red
      case TruthMeterStatus.unrated:
        return const Color(0xFF9E9E9E); // Gray
    }
  }
}
