import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/farm_profile.dart';
import '../models/crop_plan.dart';

final _logger = Logger(level: Level.debug);

/// Current user's farm profile (null if not set up).
final farmProfileProvider = FutureProvider<FarmProfile?>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  try {
    final response = await supabase
        .from('farm_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return FarmProfile.fromMap(response);
  } catch (e) {
    _logger.e('Error fetching farm profile', error: e);
    rethrow;
  }
});

/// Current user's crop plans for their farm profile.
final cropPlansProvider = FutureProvider<List<CropPlan>>((ref) async {
  final supabase = Supabase.instance.client;
  final farmProfile = await ref.watch(farmProfileProvider.future);
  if (farmProfile == null) return [];

  try {
    final response = await supabase
        .from('crop_plans')
        .select()
        .eq('farm_profile_id', farmProfile.id)
        .order('commodity');

    return (response as List)
        .map((e) => CropPlan.fromMap(e as Map<String, dynamic>))
        .toList();
  } catch (e) {
    _logger.e('Error fetching crop plans', error: e);
    rethrow;
  }
});

/// Provincial cost defaults for a given province.
/// Used to pre-populate cost fields during onboarding.
final provincialDefaultsProvider =
    FutureProvider.family<List<ProvincialCostDefault>, String>(
  (ref, province) async {
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase.rpc('get_provincial_defaults', params: {
        'p_province': province,
        'p_crop_year': '2025-2026',
      });

      return (response as List)
          .map((e) =>
              ProvincialCostDefault.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.e('Error fetching provincial defaults', error: e);
      rethrow;
    }
  },
);

/// Whether current user has a farm profile set up.
final hasFarmProfileProvider = FutureProvider<bool>((ref) async {
  final profile = await ref.watch(farmProfileProvider.future);
  return profile != null;
});
