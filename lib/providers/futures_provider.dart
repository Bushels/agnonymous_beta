import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agnonymous_beta/core/utils/globals.dart';
import 'package:logger/logger.dart';

final _logger = Logger(level: Level.debug);

/// ICE/CBOT Futures price providers.
/// Reads from the `futures_prices` table populated by the fetch-futures-prices
/// Edge Function (Barchart.com scraper).

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class FuturesPrice {
  final String id;
  final String commodity;
  final String exchange;
  final String contractMonth;
  final String? contractCode;
  final DateTime tradeDate;
  final double? lastPrice;
  final double? changeAmount;
  final double? changePercent;
  final double? openPrice;
  final double? highPrice;
  final double? lowPrice;
  final double? settlePrice;
  final double? prevClose;
  final int? volume;
  final int? openInterest;
  final bool isFrontMonth;
  final String currency;
  final String? priceUnit;
  final DateTime? fetchedAt;
  final DateTime? createdAt;

  const FuturesPrice({
    required this.id,
    required this.commodity,
    required this.exchange,
    required this.contractMonth,
    this.contractCode,
    required this.tradeDate,
    this.lastPrice,
    this.changeAmount,
    this.changePercent,
    this.openPrice,
    this.highPrice,
    this.lowPrice,
    this.settlePrice,
    this.prevClose,
    this.volume,
    this.openInterest,
    this.isFrontMonth = false,
    this.currency = 'CAD',
    this.priceUnit,
    this.fetchedAt,
    this.createdAt,
  });

  factory FuturesPrice.fromMap(Map<String, dynamic> map) {
    return FuturesPrice(
      id: map['id'] as String,
      commodity: map['commodity'] as String,
      exchange: map['exchange'] as String,
      contractMonth: map['contract_month'] as String,
      contractCode: map['contract_code'] as String?,
      tradeDate: DateTime.parse(map['trade_date'] as String),
      lastPrice: _toDouble(map['last_price']),
      changeAmount: _toDouble(map['change_amount']),
      changePercent: _toDouble(map['change_percent']),
      openPrice: _toDouble(map['open_price']),
      highPrice: _toDouble(map['high_price']),
      lowPrice: _toDouble(map['low_price']),
      settlePrice: _toDouble(map['settle_price']),
      prevClose: _toDouble(map['prev_close']),
      volume: _toInt(map['volume']),
      openInterest: _toInt(map['open_interest']),
      isFrontMonth: (map['is_front_month'] as bool?) ?? false,
      currency: (map['currency'] as String?) ?? 'CAD',
      priceUnit: map['price_unit'] as String?,
      fetchedAt: map['fetched_at'] != null
          ? DateTime.parse(map['fetched_at'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  /// Safely convert a dynamic value (int, double, String, or null) to double.
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed;
    }
    return null;
  }

  /// Safely convert a dynamic value (int, String, or null) to int.
  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

class FuturesParams {
  final String commodity;
  final int numDays;

  const FuturesParams({
    required this.commodity,
    this.numDays = 30,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FuturesParams &&
          commodity == other.commodity &&
          numDays == other.numDays;

  @override
  int get hashCode => Object.hash(commodity, numDays);
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Latest N days of front-month price history for a commodity.
/// Calls the `get_front_month_price` RPC function.
final frontMonthPriceProvider =
    FutureProvider.family<List<FuturesPrice>, FuturesParams>(
        (ref, params) async {
  try {
    final response = await supabase.rpc('get_front_month_price', params: {
      'target_commodity': params.commodity,
      'num_days': params.numDays,
    });
    return (response as List)
        .map((row) => FuturesPrice.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  } catch (e) {
    _logger.e('Error fetching front-month prices', error: e);
    rethrow;
  }
});

/// All active contract months with latest price for building the futures curve.
/// Calls the `get_contract_curve` RPC function.
final contractCurveProvider =
    FutureProvider.family<List<FuturesPrice>, String>((ref, commodity) async {
  try {
    final response = await supabase.rpc('get_contract_curve', params: {
      'target_commodity': commodity,
    });
    return (response as List)
        .map((row) => FuturesPrice.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  } catch (e) {
    _logger.e('Error fetching contract curve', error: e);
    rethrow;
  }
});

/// Latest front-month row for a commodity (single price snapshot).
/// Direct query — does not use an RPC function.
final latestFuturesPriceProvider =
    FutureProvider.family<FuturesPrice?, String>((ref, commodity) async {
  try {
    final response = await supabase
        .from('futures_prices')
        .select()
        .eq('commodity', commodity)
        .eq('is_front_month', true)
        .order('trade_date', ascending: false)
        .limit(1)
        .maybeSingle();
    if (response == null) return null;
    return FuturesPrice.fromMap(Map<String, dynamic>.from(response));
  } catch (e) {
    _logger.e('Error fetching latest futures price', error: e);
    return null;
  }
});

/// Pipeline status for the Barchart futures data source.
final futuresPipelineStatusProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final response = await supabase
        .from('data_pipeline_logs')
        .select()
        .eq('source_name', 'barchart_futures')
        .eq('status', 'success')
        .order('completed_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return response;
  } catch (e) {
    _logger.e('Error fetching futures pipeline status', error: e);
    return null;
  }
});
