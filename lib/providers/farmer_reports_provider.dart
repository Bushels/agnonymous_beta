import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/farmer_price_report.dart';

final _logger = Logger(level: Level.debug);

// =============================================================================
// ELEVATOR REPORTS — reports for a specific elevator (uses RPC)
// =============================================================================

/// Parameters for fetching price reports for a specific elevator.
class ElevatorReportsParams {
  final String elevatorId;
  final int days;

  const ElevatorReportsParams({
    required this.elevatorId,
    this.days = 7,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElevatorReportsParams &&
          elevatorId == other.elevatorId &&
          days == other.days;

  @override
  int get hashCode => Object.hash(elevatorId, days);
}

/// Fetches farmer price reports for a specific elevator via the
/// `get_elevator_reports` RPC function.
final elevatorReportsProvider =
    FutureProvider.family<List<FarmerPriceReport>, ElevatorReportsParams>(
  (ref, params) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc('get_elevator_reports', params: {
        'p_elevator_id': params.elevatorId,
        'p_days': params.days,
      });
      final list = List<Map<String, dynamic>>.from(response as List);
      return list.map((e) => FarmerPriceReport.fromMap(e)).toList();
    } catch (e) {
      _logger.e('Error fetching elevator reports', error: e);
      rethrow;
    }
  },
);

// =============================================================================
// MONTHLY SOCIAL PROOF STATS (uses RPC)
// =============================================================================

/// Fetches monthly aggregate report stats for the social proof counter.
/// Pass a region (province code e.g. "SK") or null for all regions.
final monthlyReportStatsProvider =
    FutureProvider.family<MonthlyReportStats, String?>(
  (ref, region) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc('get_monthly_report_stats', params: {
        'p_region': region,
      });
      final list = List<Map<String, dynamic>>.from(response as List);
      if (list.isEmpty) {
        return MonthlyReportStats(
          totalReports: 0,
          totalConfirmations: 0,
          uniqueReporters: 0,
        );
      }
      return MonthlyReportStats.fromMap(list.first);
    } catch (e) {
      _logger.e('Error fetching monthly report stats', error: e);
      rethrow;
    }
  },
);

// =============================================================================
// SUBMIT PRICE REPORT (standalone function)
// =============================================================================

/// Inserts a new farmer price report and returns the created record.
Future<FarmerPriceReport> submitPriceReport(
  SupabaseClient supabase,
  Map<String, dynamic> data,
) async {
  try {
    final response = await supabase
        .from('farmer_price_reports')
        .insert(data)
        .select()
        .single();
    return FarmerPriceReport.fromMap(response);
  } catch (e) {
    _logger.e('Error submitting price report', error: e);
    rethrow;
  }
}

// =============================================================================
// SUBMIT CONFIRMATION (standalone function)
// =============================================================================

/// Inserts a confirmation (confirm or outdated) for a specific price report.
/// Throws a PostgrestException if user already confirmed this report
/// (unique constraint on report_id + confirmer_id).
Future<void> submitConfirmation(
  SupabaseClient supabase, {
  required String reportId,
  required String confirmerId,
  required String type,
}) async {
  try {
    await supabase.from('price_report_confirmations').insert({
      'report_id': reportId,
      'confirmer_id': confirmerId,
      'confirmation_type': type,
    });
  } catch (e) {
    _logger.e('Error submitting confirmation', error: e);
    rethrow;
  }
}

// =============================================================================
// HAS USER CONFIRMED (check for existing confirmation)
// =============================================================================

/// Parameters for checking if a user has already confirmed a report.
class UserConfirmParams {
  final String reportId;
  final String userId;

  const UserConfirmParams({
    required this.reportId,
    required this.userId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserConfirmParams &&
          reportId == other.reportId &&
          userId == other.userId;

  @override
  int get hashCode => Object.hash(reportId, userId);
}

/// Checks whether a user has already submitted a confirmation for a report.
final hasUserConfirmedProvider =
    FutureProvider.family<bool, UserConfirmParams>(
  (ref, params) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase
          .from('price_report_confirmations')
          .select('id')
          .eq('report_id', params.reportId)
          .eq('confirmer_id', params.userId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      _logger.e('Error checking user confirmation', error: e);
      rethrow;
    }
  },
);

// NOTE: elevatorLocationsProvider lives in elevator_locations_provider.dart
// Import it from there when needed for the reporting flow.
