import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cash_price.dart';

final _logger = Logger(level: Level.debug);

/// Fetches cash prices from the `local_cash_prices` table via the
/// `get_cash_prices` RPC function, filtered by optional commodity,
/// province, source, and date range.
final localCashPricesProvider =
    FutureProvider.family<List<CashPrice>, CashPriceParams>(
  (ref, params) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc('get_cash_prices', params: {
        'p_commodity': params.commodity,
        'p_province': params.province,
        'p_source': params.source,
        'p_days': params.days,
      });
      final list = List<Map<String, dynamic>>.from(response as List);
      return list.map((e) => CashPrice.fromMap(e)).toList();
    } catch (e) {
      _logger.e('Error fetching cash prices', error: e);
      rethrow;
    }
  },
);

/// Convenience provider that returns the latest bid for a single commodity
/// (most recent price within the last 7 days).
final latestBidProvider = FutureProvider.family<CashPrice?, String>(
  (ref, commodity) async {
    final prices = await ref.watch(
      localCashPricesProvider(
        CashPriceParams(commodity: commodity, days: 7),
      ).future,
    );
    return prices.isNotEmpty ? prices.first : null;
  },
);

/// Available commodities in the cash prices table (for filter dropdowns).
final cashPriceCommoditiesProvider = FutureProvider<List<String>>(
  (ref) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase
          .from('local_cash_prices')
          .select('commodity')
          .order('commodity')
          .limit(100);
      final commodities = (response as List)
          .map((r) => r['commodity'] as String)
          .toSet()
          .toList()
        ..sort();
      return commodities;
    } catch (e) {
      _logger.e('Error fetching cash price commodities', error: e);
      rethrow;
    }
  },
);

/// Available provinces in the cash prices table (for filter dropdowns).
final cashPriceProvincesProvider = FutureProvider<List<String>>(
  (ref) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase
          .from('local_cash_prices')
          .select('location_province')
          .order('location_province')
          .limit(50);
      final provinces = (response as List)
          .map((r) => r['location_province'] as String)
          .toSet()
          .toList()
        ..sort();
      return provinces;
    } catch (e) {
      _logger.e('Error fetching cash price provinces', error: e);
      rethrow;
    }
  },
);
