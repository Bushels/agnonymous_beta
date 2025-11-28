/// Admin role types
enum AdminRoleType {
  moderator('moderator', 'Moderator'),
  admin('admin', 'Admin'),
  superAdmin('super_admin', 'Super Admin');

  final String value;
  final String label;

  const AdminRoleType(this.value, this.label);

  static AdminRoleType fromString(String value) {
    return AdminRoleType.values.firstWhere(
      (role) => role.value == value,
      orElse: () => AdminRoleType.moderator,
    );
  }
}

/// Admin role model
class AdminRole {
  final String id;
  final String userId;
  final AdminRoleType role;
  final String? grantedBy;
  final DateTime grantedAt;

  AdminRole({
    required this.id,
    required this.userId,
    required this.role,
    this.grantedBy,
    required this.grantedAt,
  });

  factory AdminRole.fromMap(Map<String, dynamic> map) {
    return AdminRole(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      role: AdminRoleType.fromString(map['role'] as String),
      grantedBy: map['granted_by'] as String?,
      grantedAt: DateTime.parse(map['granted_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'role': role.value,
      'granted_by': grantedBy,
      'granted_at': grantedAt.toIso8601String(),
    };
  }
}

/// Post verification model
class PostVerification {
  final String id;
  final String postId;
  final String verifiedBy;
  final VerificationType verificationType;
  final String? verificationNotes;
  final List<String>? evidenceLinks;
  final DateTime createdAt;

  PostVerification({
    required this.id,
    required this.postId,
    required this.verifiedBy,
    required this.verificationType,
    this.verificationNotes,
    this.evidenceLinks,
    required this.createdAt,
  });

  factory PostVerification.fromMap(Map<String, dynamic> map) {
    return PostVerification(
      id: map['id'] as String,
      postId: map['post_id'] as String,
      verifiedBy: map['verified_by'] as String,
      verificationType: VerificationType.fromString(map['verification_type'] as String),
      verificationNotes: map['verification_notes'] as String?,
      evidenceLinks: (map['evidence_links'] as List<dynamic>?)?.cast<String>(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'post_id': postId,
      'verified_by': verifiedBy,
      'verification_type': verificationType.value,
      'verification_notes': verificationNotes,
      'evidence_links': evidenceLinks,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Verification types
enum VerificationType {
  verifiedTrue('verified_true', 'Verified True'),
  verifiedFalse('verified_false', 'Verified False'),
  needsInvestigation('needs_investigation', 'Needs Investigation');

  final String value;
  final String label;

  const VerificationType(this.value, this.label);

  static VerificationType fromString(String value) {
    return VerificationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => VerificationType.needsInvestigation,
    );
  }
}
