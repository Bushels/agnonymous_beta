import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pricing_models.dart';
import '../main.dart' show supabase, logger;

// ============================================
// PRODUCTS PROVIDER
// ============================================

/// State for product search results
class ProductSearchState {
  final List<Product> results;
  final bool isLoading;
  final String? error;

  const ProductSearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
  });

  ProductSearchState copyWith({
    List<Product>? results,
    bool? isLoading,
    String? error,
  }) {
    return ProductSearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Products search notifier
class ProductsNotifier extends Notifier<ProductSearchState> {
  @override
  ProductSearchState build() {
    return const ProductSearchState();
  }

  /// Search products with fuzzy matching
  Future<List<Product>> searchProducts(
    String query, {
    ProductType? productType,
  }) async {
    if (query.length < 2) return [];

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await supabase.rpc('search_products_smart', params: {
        'search_term': query,
        'product_type_in': productType?.name,
      });

      final products = (response as List<dynamic>)
          .map((e) => Product.fromMap(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(results: products, isLoading: false);
      return products;
    } catch (e) {
      logger.e('Error searching products: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to search products',
      );
      return [];
    }
  }

  /// Get products by type
  Future<List<Product>> getProductsByType(ProductType type) async {
    try {
      final response = await supabase
          .from('products')
          .select()
          .eq('product_type', type.name)
          .order('price_entry_count', ascending: false)
          .limit(50);

      return (response as List<dynamic>)
          .map((e) => Product.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      logger.e('Error fetching products by type: $e');
      return [];
    }
  }

  /// Create a new product
  Future<Product?> createProduct({
    required ProductType productType,
    required String productName,
    String? brandName,
    String? formulation,
    String? analysis,
    String? activeIngredient,
    String? cropType,
    String? traitPlatform,
    String? subCategory,
    String? defaultUnit,
  }) async {
    try {
      final response = await supabase.from('products').insert({
        'product_type': productType.name,
        'product_name': productName,
        'brand_name': brandName,
        'formulation': formulation,
        'analysis': analysis,
        'active_ingredient': activeIngredient,
        'crop_type': cropType,
        'trait_platform': traitPlatform,
        'sub_category': subCategory,
        'default_unit': defaultUnit,
        'created_by': supabase.auth.currentUser?.id,
      }).select().single();

      logger.i('Created new product: $productName');
      return Product.fromMap(response);
    } catch (e) {
      logger.e('Error creating product: $e');
      return null;
    }
  }

  void clearResults() {
    state = const ProductSearchState();
  }
}

final productsProvider = NotifierProvider<ProductsNotifier, ProductSearchState>(
  ProductsNotifier.new,
);

// ============================================
// RETAILERS PROVIDER
// ============================================

/// State for retailer search results
class RetailerSearchState {
  final List<Retailer> results;
  final bool isLoading;
  final String? error;

  const RetailerSearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
  });

  RetailerSearchState copyWith({
    List<Retailer>? results,
    bool? isLoading,
    String? error,
  }) {
    return RetailerSearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Retailers search notifier
class RetailersNotifier extends Notifier<RetailerSearchState> {
  @override
  RetailerSearchState build() {
    return const RetailerSearchState();
  }

  /// Search retailers with fuzzy matching
  Future<List<Retailer>> searchRetailers(
    String query, {
    required String provinceState,
    String? city,
  }) async {
    if (query.length < 2) return [];

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await supabase.rpc('search_retailers_smart', params: {
        'search_term': query,
        'province_state_in': provinceState,
        'city_in': city,
      });

      final retailers = (response as List<dynamic>).map((e) {
        final map = e as Map<String, dynamic>;
        return Retailer(
          id: map['id'] as String,
          name: map['name'] as String,
          city: map['city'] as String,
          provinceState: map['province_state'] as String,
          chainName: map['chain_name'] as String?,
          createdAt: DateTime.now(),
        );
      }).toList();

      state = state.copyWith(results: retailers, isLoading: false);
      return retailers;
    } catch (e) {
      logger.e('Error searching retailers: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to search retailers',
      );
      return [];
    }
  }

  /// Get retailers in a province/state
  Future<List<Retailer>> getRetailersByLocation(String provinceState) async {
    try {
      final response = await supabase
          .from('retailers')
          .select()
          .eq('province_state', provinceState)
          .isFilter('duplicate_of', null)
          .order('price_entry_count', ascending: false)
          .limit(50);

      return (response as List<dynamic>)
          .map((e) => Retailer.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      logger.e('Error fetching retailers: $e');
      return [];
    }
  }

  /// Create a new retailer
  Future<Retailer?> createRetailer({
    required String name,
    required String city,
    required String provinceState,
    String? address,
    String? chainId,
  }) async {
    try {
      final response = await supabase.from('retailers').insert({
        'name': name,
        'city': city,
        'province_state': provinceState,
        'address': address,
        'chain_id': chainId,
        'country': _isCanadianProvince(provinceState) ? 'Canada' : 'USA',
        'created_by': supabase.auth.currentUser?.id,
      }).select().single();

      logger.i('Created new retailer: $name in $city, $provinceState');
      return Retailer.fromMap(response);
    } catch (e) {
      logger.e('Error creating retailer: $e');
      return null;
    }
  }

  bool _isCanadianProvince(String provinceState) {
    const canadianProvinces = {
      'Alberta', 'British Columbia', 'Manitoba', 'New Brunswick',
      'Newfoundland and Labrador', 'Northwest Territories', 'Nova Scotia',
      'Nunavut', 'Ontario', 'Prince Edward Island', 'Quebec',
      'Saskatchewan', 'Yukon'
    };
    return canadianProvinces.contains(provinceState);
  }

  void clearResults() {
    state = const RetailerSearchState();
  }
}

final retailersProvider = NotifierProvider<RetailersNotifier, RetailerSearchState>(
  RetailersNotifier.new,
);

// ============================================
// PRICE ENTRIES PROVIDER
// ============================================

/// State for price entries
class PriceEntriesState {
  final List<PriceEntry> entries;
  final PriceStats? stats;
  final bool isLoading;
  final String? error;

  const PriceEntriesState({
    this.entries = const [],
    this.stats,
    this.isLoading = false,
    this.error,
  });

  PriceEntriesState copyWith({
    List<PriceEntry>? entries,
    PriceStats? stats,
    bool? isLoading,
    String? error,
  }) {
    return PriceEntriesState(
      entries: entries ?? this.entries,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Price entries notifier
class PriceEntriesNotifier extends Notifier<PriceEntriesState> {
  @override
  PriceEntriesState build() {
    return const PriceEntriesState();
  }

  /// Submit a new price entry
  Future<PriceEntry?> submitPriceEntry({
    required String productId,
    required String retailerId,
    required double price,
    required String unit,
    required String currency,
    DateTime? priceDate,
    String? notes,
    bool isAnonymous = true,
    String? postId,
  }) async {
    try {
      final response = await supabase.from('price_entries').insert({
        'product_id': productId,
        'retailer_id': retailerId,
        'price': price,
        'unit': unit,
        'currency': currency,
        'price_date': (priceDate ?? DateTime.now()).toIso8601String().split('T')[0],
        'notes': notes,
        'is_anonymous': isAnonymous,
        'user_id': supabase.auth.currentUser?.id,
        'post_id': postId,
      }).select().single();

      logger.i('Submitted price entry: \$$price/$unit');
      return PriceEntry.fromMap(response);
    } catch (e) {
      logger.e('Error submitting price entry: $e');
      return null;
    }
  }

  /// Get price entries for a product
  Future<void> loadPriceEntriesForProduct(
    String productId, {
    String? provinceState,
    int limit = 50,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Build query with filters before transforms
      dynamic baseQuery = supabase.from('price_entries_full').select();
      final filteredQuery = provinceState != null
          ? baseQuery.eq('product_id', productId).eq('retailer_province_state', provinceState)
          : baseQuery.eq('product_id', productId);

      final response = await filteredQuery
          .order('price_date', ascending: false)
          .limit(limit);

      final entries = (response as List<dynamic>)
          .map((e) => PriceEntry.fromFullView(e as Map<String, dynamic>))
          .toList();

      // Get stats
      final statsResponse = await supabase.rpc('get_price_stats', params: {
        'product_id_in': productId,
        'province_state_in': provinceState,
        'days_back': 90,
      });

      PriceStats? stats;
      if (statsResponse != null && (statsResponse as List).isNotEmpty) {
        stats = PriceStats.fromMap(statsResponse[0] as Map<String, dynamic>);
      }

      state = state.copyWith(entries: entries, stats: stats, isLoading: false);
    } catch (e) {
      logger.e('Error loading price entries: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load prices',
      );
    }
  }

  /// Get recent price entries (for feed)
  Future<List<PriceEntry>> getRecentPrices({
    String? provinceState,
    ProductType? productType,
    int limit = 20,
    String sortBy = 'date', // 'date' or 'price'
    bool ascending = false,
  }) async {
    try {
      // Build query with filters before transforms
      dynamic baseQuery = supabase.from('price_entries_full').select();

      if (provinceState != null) {
        baseQuery = baseQuery.eq('retailer_province_state', provinceState);
      }

      if (productType != null) {
        baseQuery = baseQuery.eq('product_type', productType.name);
      }

      if (sortBy == 'price') {
        baseQuery = baseQuery.order('price', ascending: ascending);
      } else {
        baseQuery = baseQuery.order('created_at', ascending: ascending);
      }

      final response = await baseQuery
          .limit(limit);

      return (response as List<dynamic>)
          .map((e) => PriceEntry.fromFullView(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      logger.e('Error fetching recent prices: $e');
      return [];
    }
  }

  /// Get price stats for a product
  Future<PriceStats?> getPriceStats(
    String productId, {
    String? provinceState,
    int daysBack = 90,
  }) async {
    try {
      final response = await supabase.rpc('get_price_stats', params: {
        'product_id_in': productId,
        'province_state_in': provinceState,
        'days_back': daysBack,
      });

      if (response != null && (response as List).isNotEmpty) {
        return PriceStats.fromMap(response[0] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      logger.e('Error fetching price stats: $e');
      return null;
    }
  }

  void clearEntries() {
    state = const PriceEntriesState();
  }
}

final priceEntriesProvider = NotifierProvider<PriceEntriesNotifier, PriceEntriesState>(
  PriceEntriesNotifier.new,
);

// ============================================
// PRICE ALERTS PROVIDER
// ============================================

/// State for price alerts
class PriceAlertsState {
  final List<PriceAlert> alerts;
  final bool isLoading;
  final String? error;

  const PriceAlertsState({
    this.alerts = const [],
    this.isLoading = false,
    this.error,
  });

  PriceAlertsState copyWith({
    List<PriceAlert>? alerts,
    bool? isLoading,
    String? error,
  }) {
    return PriceAlertsState(
      alerts: alerts ?? this.alerts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Price alerts notifier
class PriceAlertsNotifier extends Notifier<PriceAlertsState> {
  @override
  PriceAlertsState build() {
    // Defer loading to next microtask to avoid circular dependency
    Future.microtask(() => loadAlerts());
    return const PriceAlertsState(isLoading: true);
  }

  /// Load user's price alerts
  Future<void> loadAlerts() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      state = const PriceAlertsState();
      return;
    }

    state = const PriceAlertsState(isLoading: true);

    try {
      final response = await supabase
          .from('price_alerts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final alerts = (response as List<dynamic>)
          .map((e) => PriceAlert.fromMap(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(alerts: alerts, isLoading: false);
    } catch (e) {
      logger.e('Error loading alerts: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load alerts',
      );
    }
  }

  /// Create a new price alert
  Future<PriceAlert?> createAlert({
    String? productId,
    String? productType,
    String? provinceState,
    double? targetPrice,
    required String alertType, // 'below', 'above', 'any'
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await supabase.from('price_alerts').insert({
        'user_id': userId,
        'product_id': productId,
        'product_type': productType,
        'province_state': provinceState,
        'target_price': targetPrice,
        'alert_type': alertType,
        'is_active': true,
      }).select().single();

      final alert = PriceAlert.fromMap(response);
      state = state.copyWith(alerts: [alert, ...state.alerts]);

      logger.i('Created price alert');
      return alert;
    } catch (e) {
      logger.e('Error creating alert: $e');
      return null;
    }
  }

  /// Toggle alert active status
  Future<void> toggleAlert(String alertId) async {
    try {
      final alertIndex = state.alerts.indexWhere((a) => a.id == alertId);
      if (alertIndex == -1) return;

      final currentAlert = state.alerts[alertIndex];
      final newIsActive = !currentAlert.isActive;

      await supabase
          .from('price_alerts')
          .update({'is_active': newIsActive})
          .eq('id', alertId);

      final updatedAlerts = [...state.alerts];
      updatedAlerts[alertIndex] = PriceAlert(
        id: currentAlert.id,
        userId: currentAlert.userId,
        productId: currentAlert.productId,
        productType: currentAlert.productType,
        provinceState: currentAlert.provinceState,
        targetPrice: currentAlert.targetPrice,
        alertType: currentAlert.alertType,
        isActive: newIsActive,
        lastTriggered: currentAlert.lastTriggered,
        triggerCount: currentAlert.triggerCount,
        createdAt: currentAlert.createdAt,
      );

      state = state.copyWith(alerts: updatedAlerts);
    } catch (e) {
      logger.e('Error toggling alert: $e');
    }
  }

  /// Delete an alert
  Future<void> deleteAlert(String alertId) async {
    try {
      await supabase.from('price_alerts').delete().eq('id', alertId);

      state = state.copyWith(
        alerts: state.alerts.where((a) => a.id != alertId).toList(),
      );

      logger.i('Deleted price alert');
    } catch (e) {
      logger.e('Error deleting alert: $e');
    }
  }
}

final priceAlertsProvider = NotifierProvider<PriceAlertsNotifier, PriceAlertsState>(
  PriceAlertsNotifier.new,
);

// ============================================
// UTILITY PROVIDERS
// ============================================

/// Detect currency based on province/state
String detectCurrency(String provinceState) {
  const canadianProvinces = {
    'Alberta', 'British Columbia', 'Manitoba', 'New Brunswick',
    'Newfoundland and Labrador', 'Northwest Territories', 'Nova Scotia',
    'Nunavut', 'Ontario', 'Prince Edward Island', 'Quebec',
    'Saskatchewan', 'Yukon'
  };
  return canadianProvinces.contains(provinceState) ? 'CAD' : 'USD';
}

/// Format price with currency symbol
String formatPrice(double price, String currency) {
  final symbol = currency == 'CAD' ? 'C\$' : 'US\$';
  return '$symbol${price.toStringAsFixed(2)}';
}

/// Get units for product type
List<String> getUnitsForProductType(ProductType type) {
  switch (type) {
    case ProductType.fertilizer:
      return ['tonne', 'lb', 'bag', 'kg'];
    case ProductType.seed:
      return ['bag', 'acre', 'bu', 'lb', 'unit'];
    case ProductType.chemical:
      return ['gallon', 'litre', 'acre', 'jug', 'case'];
    case ProductType.equipment:
      return ['each', 'hour', 'acre', 'day'];
  }
}
