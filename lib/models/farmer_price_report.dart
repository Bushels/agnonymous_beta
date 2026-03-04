// Models for the Farmer Price Reporting feature (Wave 2 Part 4).
// Maps to the `farmer_price_reports`, `price_report_confirmations`,
// and `get_monthly_report_stats` RPC in Supabase.

/// Safe conversion helper: handles num, String, int, and null -> double.
double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

/// A farmer-submitted price report for an elevator bid.
class FarmerPriceReport {
  final String id;
  final String reporterId;
  final String? elevatorLocationId;
  final String elevatorName;
  final String commodity;
  final String? grade;
  final double reportedBidCad;
  final String bidUnit; // 'bushel' or 'tonne'
  final String? notes;
  final int confirmCount;
  final int outdatedCount;
  final bool isPromoted;
  final DateTime reportedAt;
  final DateTime? createdAt;

  // Joined fields from RPC results (get_elevator_reports)
  final String? reporterDisplayName;
  final int? reporterReputationLevel;

  FarmerPriceReport({
    required this.id,
    required this.reporterId,
    this.elevatorLocationId,
    required this.elevatorName,
    required this.commodity,
    this.grade,
    required this.reportedBidCad,
    this.bidUnit = 'bushel',
    this.notes,
    this.confirmCount = 0,
    this.outdatedCount = 0,
    this.isPromoted = false,
    required this.reportedAt,
    this.createdAt,
    this.reporterDisplayName,
    this.reporterReputationLevel,
  });

  factory FarmerPriceReport.fromMap(Map<String, dynamic> map) {
    return FarmerPriceReport(
      id: map['id'] as String,
      reporterId: (map['reporter_id'] as String?) ?? '',
      elevatorLocationId: map['elevator_location_id'] as String?,
      elevatorName: (map['elevator_name'] as String?) ?? '',
      commodity: map['commodity'] as String,
      grade: map['grade'] as String?,
      reportedBidCad: _toDouble(map['reported_bid_cad']),
      bidUnit: (map['bid_unit'] as String?) ?? 'bushel',
      notes: map['notes'] as String?,
      confirmCount: (map['confirm_count'] as int?) ?? 0,
      outdatedCount: (map['outdated_count'] as int?) ?? 0,
      isPromoted: (map['is_promoted'] as bool?) ?? false,
      reportedAt: map['reported_at'] != null
          ? DateTime.parse(map['reported_at'] as String)
          : DateTime.now(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      reporterDisplayName: map['reporter_display_name'] as String?,
      reporterReputationLevel: map['reporter_reputation_level'] as int?,
    );
  }

  /// Returns a map for inserting a new price report into
  /// `farmer_price_reports`. Excludes auto-generated columns.
  Map<String, dynamic> toInsertMap() {
    return {
      'reporter_id': reporterId,
      if (elevatorLocationId != null) 'elevator_location_id': elevatorLocationId,
      'elevator_name': elevatorName,
      'commodity': commodity,
      if (grade != null) 'grade': grade,
      'reported_bid_cad': reportedBidCad,
      'bid_unit': bidUnit,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }

  /// Formatted bid price, e.g. "C$14.25/bu" or "C$520.00/t".
  String get formattedBid {
    final unit = bidUnit == 'bushel' ? 'bu' : 't';
    return 'C\$${reportedBidCad.toStringAsFixed(2)}/$unit';
  }

  /// Relative time-ago string, e.g. "2h ago", "Yesterday", "3d ago".
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(reportedAt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inHours < 48) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  /// Whether this report is considered reliable based on community votes.
  /// A report is reliable if it has 3+ confirmations and confirmations
  /// outnumber outdated votes.
  bool get isReliable => confirmCount >= 3 && outdatedCount < confirmCount;
}

/// A confirmation or outdated vote on a farmer price report.
class PriceReportConfirmation {
  final String id;
  final String reportId;
  final String confirmerId;
  final String confirmationType; // 'confirm' or 'outdated'
  final DateTime? createdAt;

  PriceReportConfirmation({
    required this.id,
    required this.reportId,
    required this.confirmerId,
    required this.confirmationType,
    this.createdAt,
  });

  factory PriceReportConfirmation.fromMap(Map<String, dynamic> map) {
    return PriceReportConfirmation(
      id: map['id'] as String,
      reportId: map['report_id'] as String,
      confirmerId: map['confirmer_id'] as String,
      confirmationType: map['confirmation_type'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  /// Returns a map for inserting a confirmation.
  /// Excludes id and created_at (auto-generated).
  Map<String, dynamic> toInsertMap() {
    return {
      'report_id': reportId,
      'confirmer_id': confirmerId,
      'confirmation_type': confirmationType,
    };
  }
}

/// Monthly aggregate stats for social proof display.
class MonthlyReportStats {
  final int totalReports;
  final int totalConfirmations;
  final int uniqueReporters;

  MonthlyReportStats({
    required this.totalReports,
    required this.totalConfirmations,
    required this.uniqueReporters,
  });

  factory MonthlyReportStats.fromMap(Map<String, dynamic> map) {
    return MonthlyReportStats(
      totalReports: (map['total_reports'] as int?) ?? 0,
      totalConfirmations: (map['total_confirmations'] as int?) ?? 0,
      uniqueReporters: (map['unique_reporters'] as int?) ?? 0,
    );
  }
}
