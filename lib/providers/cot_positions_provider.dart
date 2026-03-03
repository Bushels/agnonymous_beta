import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agnonymous_beta/core/utils/globals.dart';

/// CFTC Commitments of Traders (COT) data providers.
/// Reads from the `cot_positions` table populated by the fetch-cot-data Edge Function.

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class CotPosition {
  final String id;
  final DateTime reportDate;
  final String commodity;
  final String exchange;
  final String reportType;
  final int? commercialLong;
  final int? commercialShort;
  final int? commercialNet;
  final int? nonCommercialLong;
  final int? nonCommercialShort;
  final int? nonCommercialNet;
  final int? nonCommercialSpreads;
  final int? openInterest;
  final int? commercialNetChange;
  final int? nonCommercialNetChange;
  final int? openInterestChange;
  final DateTime? createdAt;

  const CotPosition({
    required this.id,
    required this.reportDate,
    required this.commodity,
    required this.exchange,
    this.reportType = 'combined_futures_options',
    this.commercialLong,
    this.commercialShort,
    this.commercialNet,
    this.nonCommercialLong,
    this.nonCommercialShort,
    this.nonCommercialNet,
    this.nonCommercialSpreads,
    this.openInterest,
    this.commercialNetChange,
    this.nonCommercialNetChange,
    this.openInterestChange,
    this.createdAt,
  });

  factory CotPosition.fromMap(Map<String, dynamic> map) {
    return CotPosition(
      id: map['id'] as String,
      reportDate: DateTime.parse(map['report_date'] as String),
      commodity: map['commodity'] as String,
      exchange: map['exchange'] as String,
      reportType:
          (map['report_type'] as String?) ?? 'combined_futures_options',
      commercialLong: map['commercial_long'] as int?,
      commercialShort: map['commercial_short'] as int?,
      commercialNet: map['commercial_net'] as int?,
      nonCommercialLong: map['non_commercial_long'] as int?,
      nonCommercialShort: map['non_commercial_short'] as int?,
      nonCommercialNet: map['non_commercial_net'] as int?,
      nonCommercialSpreads: map['non_commercial_spreads'] as int?,
      openInterest: map['open_interest'] as int?,
      commercialNetChange: map['commercial_net_change'] as int?,
      nonCommercialNetChange: map['non_commercial_net_change'] as int?,
      openInterestChange: map['open_interest_change'] as int?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

class CotParams {
  final String commodity;
  final int numWeeks;

  const CotParams({
    required this.commodity,
    this.numWeeks = 12,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CotParams &&
          commodity == other.commodity &&
          numWeeks == other.numWeeks;

  @override
  int get hashCode => Object.hash(commodity, numWeeks);
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Latest N weeks of COT positions for a commodity.
final cotPositionsProvider =
    FutureProvider.family<List<CotPosition>, CotParams>(
        (ref, params) async {
  try {
    final response = await supabase.rpc('get_latest_cot_positions', params: {
      'commodity_filter': params.commodity,
      'num_weeks': params.numWeeks,
    });
    return (response as List)
        .map((row) => CotPosition.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  } catch (e) {
    logger.e('Error fetching COT positions', error: e);
    rethrow;
  }
});

/// Weekly net changes for a commodity (for sparklines / trend display).
final cotNetChangeProvider =
    FutureProvider.family<List<Map<String, dynamic>>, CotParams>(
        (ref, params) async {
  try {
    final response = await supabase.rpc('get_cot_net_change', params: {
      'target_commodity': params.commodity,
      'num_weeks': params.numWeeks,
    });
    return List<Map<String, dynamic>>.from(response as List);
  } catch (e) {
    logger.e('Error fetching COT net changes', error: e);
    rethrow;
  }
});

/// Pipeline status for the CFTC COT data source.
final cotPipelineStatusProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final response = await supabase
        .from('data_pipeline_logs')
        .select()
        .eq('source_name', 'cftc_cot_weekly')
        .eq('status', 'success')
        .order('completed_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return response;
  } catch (e) {
    logger.e('Error fetching COT pipeline status', error: e);
    return null;
  }
});
