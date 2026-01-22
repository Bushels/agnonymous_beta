/// Fertilizer Ticker Provider
/// State management for the real-time fertilizer price ticker
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/fertilizer_ticker_models.dart';
import '../main.dart' show supabase, logger;
import '../services/anonymous_id_service.dart';

/// Provider for ALL raw ticker entries (historically limited, e.g. 90 days)
final fertilizerTickerEntriesProvider = StreamProvider<List<FertilizerTickerEntry>>((ref) {
  final controller = StreamController<List<FertilizerTickerEntry>>();
  
  Future<void> fetchEntries() async {
    try {
      // Fetch entries from the last 90 days to ensure we cover monthly views + trend context
      final response = await supabase
          .from('fertilizer_ticker_entries')
          .select('*')
          .gte('created_at', DateTime.now().subtract(const Duration(days: 90)).toIso8601String())
          .order('created_at', ascending: false); // Newest first
      
      final data = response as List<dynamic>;
      final entries = data
          .map((json) => FertilizerTickerEntry.fromMap(json as Map<String, dynamic>))
          .toList();
      
      controller.add(entries);
    } catch (e) {
      logger.w('Error fetching ticker entries: $e');
      controller.add([]); 
    }
  }
  
  fetchEntries();
  
  // Real-time subscription
  final channel = supabase
      .channel('fertilizer_ticker_entries_all')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'fertilizer_ticker_entries',
        callback: (payload) {
          logger.d('New entry, refreshing list');
          fetchEntries();
        },
      )
      .subscribe();
  
  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });
  
  return controller.stream;
});

/// Helper class for aggregated region data
class RegionMarketSummary {
  final String provinceState;
  final FertilizerType type;
  final double? avgPricePickedUp;
  final double? avgPriceDelivered;
  final int countPickedUp;
  final int countDelivered;
  final double? minPrice;
  final double? maxPrice;
  final DateTime? lastUpdated;

  RegionMarketSummary({
    required this.provinceState,
    required this.type,
    this.avgPricePickedUp,
    this.avgPriceDelivered,
    required this.countPickedUp,
    required this.countDelivered,
    this.minPrice,
    this.maxPrice,
    this.lastUpdated,
  });

  int get totalCount => countPickedUp + countDelivered;
  
  double? get spread {
    if (avgPricePickedUp != null && avgPriceDelivered != null) {
      return (avgPriceDelivered! - avgPricePickedUp!).abs();
    }
    return null;
  }
}

/// Provider for recent fertilizer ticker entries
final fertilizerTickerRecentProvider = StreamProvider<List<FertilizerTickerEntry>>((ref) {
  final controller = StreamController<List<FertilizerTickerEntry>>();
  
  Future<void> fetchRecent() async {
    try {
      final response = await supabase
          .from('fertilizer_ticker_recent')
          .select('*');
      
      final data = response as List<dynamic>;
      final entries = data
          .map((json) => FertilizerTickerEntry.fromMap(json as Map<String, dynamic>))
          .toList();
      
      controller.add(entries);
    } catch (e) {
      logger.w('Error fetching recent ticker: $e');
      // Return demo data if database is empty or fails
      controller.add([]); // Return empty list on error
    }
  }
  
  // Initial fetch
  fetchRecent();
  
  // Subscribe to real-time updates
  final channel = supabase
      .channel('fertilizer_ticker_recent_updates')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'fertilizer_ticker_entries',
        callback: (payload) {
          logger.d('New ticker entry received, refreshing recent');
          fetchRecent();
        },
      )
      .subscribe();
  
  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });
  
  return controller.stream;
});

/// State for the price submission form
class FertilizerPriceSubmissionState {
  final bool isSubmitting;
  final String? error;
  final bool success;

  const FertilizerPriceSubmissionState({
    this.isSubmitting = false,
    this.error,
    this.success = false,
  });

  FertilizerPriceSubmissionState copyWith({
    bool? isSubmitting,
    String? error,
    bool? success,
  }) {
    return FertilizerPriceSubmissionState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      success: success ?? this.success,
    );
  }
}

/// Notifier for submitting fertilizer prices
class FertilizerPriceSubmissionNotifier extends Notifier<FertilizerPriceSubmissionState> {
  @override
  FertilizerPriceSubmissionState build() {
    return const FertilizerPriceSubmissionState();
  }

  /// Submit a new fertilizer price to the ticker
  Future<bool> submitPrice({
    required FertilizerType fertilizerType,
    required double price,
    required WeightUnit unit,
    required TickerCurrency currency,
    required String provinceState,
    required DeliveryMode deliveryMode,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null, success: false);
    
    try {
      // Get anonymous ID for rate limiting
      final anonId = await AnonymousIdService.getAnonymousId();
      
      // Call the rate-limited RPC function
      await supabase.rpc('submit_fertilizer_ticker_price', params: {
        'p_fertilizer_type': fertilizerType.toDatabase(),
        'p_price': price,
        'p_unit': unit.toDatabase(),
        'p_currency': currency.toDatabase(),
        'p_province_state': provinceState,
        'p_anonymous_user_id': anonId,
        'p_delivery_mode': deliveryMode.toDatabase(),
      });
      
      state = state.copyWith(isSubmitting: false, success: true);
      logger.i('Fertilizer price submitted: ${fertilizerType.code} \$$price in $provinceState');
      return true;
    } catch (e) {
      String errorMessage = 'Failed to submit price';
      
      final errorStr = e.toString();
      if (errorStr.contains('Rate limit')) {
        errorMessage = 'You can only submit one price per type per 24 hours';
      } else if (errorStr.contains('price > 0')) {
        errorMessage = 'Please enter a valid price';
      } else {
        logger.e('Error submitting ticker price: $e');
        errorMessage = 'Something went wrong. Please try again.';
      }
      
      state = state.copyWith(isSubmitting: false, error: errorMessage);
      return false;
    }
  }

  /// Reset the state (e.g., after closing modal)
  void reset() {
    state = const FertilizerPriceSubmissionState();
  }
}

/// Provider for the submission notifier
final fertilizerPriceSubmissionProvider = 
    NotifierProvider<FertilizerPriceSubmissionNotifier, FertilizerPriceSubmissionState>(
  FertilizerPriceSubmissionNotifier.new,
);

// Demo data removed for production build
