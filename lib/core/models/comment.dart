class Comment {
  final String id;
  final String content;
  final DateTime createdAt;

  // User/Author info
  final String? userId;
  final bool isAnonymous;
  final String? authorUsername;
  final bool authorVerified;

  // Edit/Delete tracking
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime? editedAt;

  Comment({
    required this.id,
    required this.content,
    required this.createdAt,
    this.userId,
    this.isAnonymous = true,
    this.authorUsername,
    this.authorVerified = false,
    this.isDeleted = false,
    this.deletedAt,
    this.editedAt,
  });

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'],
      content: map['content'],
      createdAt: DateTime.parse(map['created_at']),
      userId: map['user_id'],
      isAnonymous: map['is_anonymous'] ?? true,
      authorUsername: map['author_username'],
      authorVerified: map['author_verified'] ?? false,
      isDeleted: map['is_deleted'] ?? false,
      deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at']) : null,
      editedAt: map['edited_at'] != null ? DateTime.parse(map['edited_at']) : null,
    );
  }

  /// Check if comment has been edited
  bool get wasEdited => editedAt != null;

  /// Get author display name
  String get authorDisplay {
    if (isAnonymous) return 'Anonymous';
    return authorUsername ?? 'Unknown User';
  }

  /// Get author badge emoji
  String? get authorBadge {
    if (isAnonymous) return '🎭';
    if (authorVerified) return '✅';
    return '⚠️';
  }
}
