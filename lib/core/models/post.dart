import 'package:agnonymous_beta/models/user_profile.dart' show TruthMeterStatus;

class Post {
  final String id;
  final String title;
  final String content;
  final String category;
  final String? provinceState;
  final String? monetteArea;
  final DateTime createdAt;
  final int commentCount;
  final int voteCount;

  // Gamification & Truth Meter
  final double truthMeterScore;
  final TruthMeterStatus truthMeterStatus;
  final bool adminVerified;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final int thumbsUpCount;
  final int thumbsDownCount;
  final int partialCount;
  final int funnyCount;

  // User/Author info
  final String? userId;
  final bool isAnonymous;
  final String? authorUsername;
  final bool authorVerified;

  // Edit/Delete tracking
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime? editedAt;
  final int editCount;

  // Verification image (required for Input Prices)
  final String? imageUrl;
  final List<String> imageUrls;

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.provinceState,
    this.monetteArea,
    required this.createdAt,
    required this.commentCount,
    required this.voteCount,
    this.truthMeterScore = 0.0,
    this.truthMeterStatus = TruthMeterStatus.unrated,
    this.adminVerified = false,
    this.verifiedAt,
    this.verifiedBy,
    this.thumbsUpCount = 0,
    this.thumbsDownCount = 0,
    this.partialCount = 0,
    this.funnyCount = 0,
    this.userId,
    this.isAnonymous = true,
    this.authorUsername,
    this.authorVerified = false,
    this.isDeleted = false,
    this.deletedAt,
    this.editedAt,
    this.editCount = 0,
    this.imageUrl,
    List<String>? imageUrls,
  }) : imageUrls = imageUrls ?? _normalizeImageUrls(imageUrl, null);

  factory Post.fromMap(Map<String, dynamic> map) {
    final imageUrl = map['image_url'];
    final imageUrls = _normalizeImageUrls(imageUrl, map['image_urls']);

    return Post(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Untitled',
      content: map['content'] ?? '',
      category: map['category'] ?? 'General',
      provinceState: map['province_state'],
      monetteArea: map['monette_area'],
      createdAt: DateTime.parse(map['created_at']),
      commentCount: map['comment_count'] ?? 0,
      voteCount: map['vote_count'] ?? 0,
      truthMeterScore: (map['truth_meter_score'] as num?)?.toDouble() ?? 0.0,
      truthMeterStatus: map['truth_meter_status'] != null
          ? TruthMeterStatus.fromString(map['truth_meter_status'])
          : TruthMeterStatus.unrated,
      adminVerified: map['admin_verified'] ?? false,
      verifiedAt: map['verified_at'] != null
          ? DateTime.parse(map['verified_at'])
          : null,
      verifiedBy: map['verified_by'],
      thumbsUpCount: map['thumbs_up_count'] ?? 0,
      thumbsDownCount: map['thumbs_down_count'] ?? 0,
      partialCount: map['partial_count'] ?? 0,
      funnyCount: map['funny_count'] ?? 0,
      userId: map['user_id'],
      isAnonymous: map['is_anonymous'] ?? true,
      authorUsername: map['author_username'],
      authorVerified: map['author_verified'] ?? false,
      isDeleted: map['is_deleted'] ?? false,
      deletedAt:
          map['deleted_at'] != null ? DateTime.parse(map['deleted_at']) : null,
      editedAt:
          map['edited_at'] != null ? DateTime.parse(map['edited_at']) : null,
      editCount: map['edit_count'] ?? 0,
      imageUrl: imageUrl,
      imageUrls: imageUrls,
    );
  }

  static List<String> _normalizeImageUrls(
    String? imageUrl,
    dynamic imageUrlsValue,
  ) {
    final urls = <String>[];
    if (imageUrlsValue is List) {
      for (final value in imageUrlsValue) {
        final url = value?.toString().trim() ?? '';
        if (url.isNotEmpty) urls.add(url);
      }
    }

    final legacyUrl = imageUrl?.trim() ?? '';
    if (legacyUrl.isNotEmpty && !urls.contains(legacyUrl)) {
      urls.insert(0, legacyUrl);
    }

    return urls;
  }

  /// Check if post has been edited
  bool get wasEdited => editCount > 0;

  /// Get author display name
  String get authorDisplay {
    if (isAnonymous) return authorUsername ?? 'Anonymous';
    return authorUsername ?? 'Unknown User';
  }

  /// Get author badge emoji
  String? get authorBadge {
    if (isAnonymous) return '🎭';
    if (authorVerified) return '✅';
    return '⚠️';
  }
}
