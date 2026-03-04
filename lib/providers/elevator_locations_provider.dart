import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/elevator_location.dart';

final _logger = Logger(level: Level.debug);

/// Fetches elevators via the `get_elevators_by_province` RPC function.
/// Filtered by optional province, company, and limit.
final elevatorLocationsProvider =
    FutureProvider.family<List<ElevatorLocation>, ElevatorFilterParams>(
  (ref, params) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc('get_elevators_by_province', params: {
        'p_province': params.province,
        'p_company': params.company,
        'p_limit': params.limit,
      });
      final list = List<Map<String, dynamic>>.from(response as List);
      return list.map((e) => ElevatorLocation.fromMap(e)).toList();
    } catch (e) {
      _logger.e('Error fetching elevator locations', error: e);
      rethrow;
    }
  },
);

/// Parameters for the nearest-elevator spatial query.
class NearestElevatorParams {
  final double lat;
  final double lng;
  final int radiusKm;
  final String? commodity;
  final int limit;

  const NearestElevatorParams({
    required this.lat,
    required this.lng,
    this.radiusKm = 50,
    this.commodity,
    this.limit = 20,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NearestElevatorParams &&
          lat == other.lat &&
          lng == other.lng &&
          radiusKm == other.radiusKm &&
          commodity == other.commodity &&
          limit == other.limit;

  @override
  int get hashCode => Object.hash(lat, lng, radiusKm, commodity, limit);
}

/// Fetches nearest elevators via the `get_nearest_elevators` PostGIS RPC
/// function, sorted by distance from the given lat/lng.
final nearestElevatorsProvider =
    FutureProvider.family<List<NearestElevator>, NearestElevatorParams>(
  (ref, params) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc('get_nearest_elevators', params: {
        'p_lat': params.lat,
        'p_lng': params.lng,
        'p_radius_km': params.radiusKm,
        'p_commodity': params.commodity,
        'p_limit': params.limit,
      });
      final list = List<Map<String, dynamic>>.from(response as List);
      return list.map((e) => NearestElevator.fromMap(e)).toList();
    } catch (e) {
      _logger.e('Error fetching nearest elevators', error: e);
      rethrow;
    }
  },
);

/// Convenience provider: unique list of companies across all elevators.
/// Useful for filter dropdowns on the map screen.
final elevatorCompaniesProvider = FutureProvider<List<String>>(
  (ref) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase
          .from('elevator_locations')
          .select('company')
          .eq('is_active', true)
          .order('company')
          .limit(200);
      final companies = (response as List)
          .map((r) => r['company'] as String)
          .toSet()
          .toList()
        ..sort();
      return companies;
    } catch (e) {
      _logger.e('Error fetching elevator companies', error: e);
      rethrow;
    }
  },
);
