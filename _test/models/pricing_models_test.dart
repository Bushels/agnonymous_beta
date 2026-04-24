import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/models/pricing_models.dart';

void main() {
  group('ProductType', () {
    test('displayName returns correct values', () {
      expect(ProductType.fertilizer.displayName, 'Fertilizer');
      expect(ProductType.seed.displayName, 'Seed');
      expect(ProductType.chemical.displayName, 'Chemical');
      expect(ProductType.equipment.displayName, 'Equipment');
    });

    group('fromString', () {
      test('parses valid types correctly', () {
        expect(ProductType.fromString('fertilizer'), ProductType.fertilizer);
        expect(ProductType.fromString('seed'), ProductType.seed);
        expect(ProductType.fromString('chemical'), ProductType.chemical);
        expect(ProductType.fromString('equipment'), ProductType.equipment);
      });

      test('parses uppercase to lowercase', () {
        expect(ProductType.fromString('FERTILIZER'), ProductType.fertilizer);
        expect(ProductType.fromString('Seed'), ProductType.seed);
      });

      test('returns fertilizer as default for invalid input', () {
        expect(ProductType.fromString('invalid'), ProductType.fertilizer);
        expect(ProductType.fromString(''), ProductType.fertilizer);
      });
    });
  });

  group('Product', () {
    final testDate = DateTime(2024, 1, 15);

    test('creates instance with required fields', () {
      final product = Product(
        id: 'prod-123',
        productType: ProductType.fertilizer,
        productName: 'Urea',
        createdAt: testDate,
      );

      expect(product.id, 'prod-123');
      expect(product.productType, ProductType.fertilizer);
      expect(product.productName, 'Urea');
      expect(product.brandName, isNull);
      expect(product.priceEntryCount, 0);
    });

    test('creates instance with all fields', () {
      final product = Product(
        id: 'prod-456',
        productType: ProductType.seed,
        productName: 'Canola',
        brandName: 'Pioneer',
        formulation: 'Treated',
        analysis: 'RR',
        activeIngredient: null,
        cropType: 'Oilseed',
        traitPlatform: 'Roundup Ready',
        subCategory: 'Spring',
        defaultUnit: 'bag',
        priceEntryCount: 15,
        createdAt: testDate,
      );

      expect(product.brandName, 'Pioneer');
      expect(product.cropType, 'Oilseed');
      expect(product.traitPlatform, 'Roundup Ready');
      expect(product.priceEntryCount, 15);
    });

    group('fromMap', () {
      test('parses valid map correctly', () {
        final map = {
          'id': 'prod-map',
          'product_type': 'fertilizer',
          'product_name': 'MAP',
          'brand_name': 'Nutrien',
          'analysis': '11-52-0',
          'formulation': 'Granular',
          'default_unit': 'tonne',
          'price_entry_count': 25,
          'created_at': '2024-01-15T00:00:00.000',
        };

        final product = Product.fromMap(map);

        expect(product.id, 'prod-map');
        expect(product.productType, ProductType.fertilizer);
        expect(product.productName, 'MAP');
        expect(product.brandName, 'Nutrien');
        expect(product.analysis, '11-52-0');
        expect(product.priceEntryCount, 25);
      });

      test('handles null optional fields', () {
        final map = {
          'id': 'prod-minimal',
          'product_type': 'chemical',
          'product_name': 'Roundup',
          'created_at': '2024-01-15T00:00:00.000',
        };

        final product = Product.fromMap(map);

        expect(product.brandName, isNull);
        expect(product.formulation, isNull);
        expect(product.analysis, isNull);
        expect(product.priceEntryCount, 0);
      });
    });

    group('toMap', () {
      test('converts to map correctly', () {
        final product = Product(
          id: 'prod-tomap',
          productType: ProductType.fertilizer,
          productName: 'DAP',
          brandName: 'CF Industries',
          analysis: '18-46-0',
          defaultUnit: 'tonne',
          createdAt: testDate,
        );

        final map = product.toMap();

        expect(map['product_type'], 'fertilizer');
        expect(map['product_name'], 'DAP');
        expect(map['brand_name'], 'CF Industries');
        expect(map['analysis'], '18-46-0');
        // Note: toMap doesn't include id
        expect(map.containsKey('id'), isFalse);
      });
    });

    group('displayName', () {
      test('returns product name only when no extras', () {
        final product = Product(
          id: 'prod-1',
          productType: ProductType.fertilizer,
          productName: 'Urea',
          createdAt: testDate,
        );

        expect(product.displayName, 'Urea');
      });

      test('includes analysis when present', () {
        final product = Product(
          id: 'prod-2',
          productType: ProductType.fertilizer,
          productName: 'MAP',
          analysis: '11-52-0',
          createdAt: testDate,
        );

        expect(product.displayName, 'MAP 11-52-0');
      });

      test('includes brand in parentheses', () {
        final product = Product(
          id: 'prod-3',
          productType: ProductType.fertilizer,
          productName: 'Urea',
          brandName: 'Nutrien',
          createdAt: testDate,
        );

        expect(product.displayName, 'Urea (Nutrien)');
      });

      test('includes both analysis and brand', () {
        final product = Product(
          id: 'prod-4',
          productType: ProductType.fertilizer,
          productName: 'MAP',
          analysis: '11-52-0',
          brandName: 'Nutrien',
          createdAt: testDate,
        );

        expect(product.displayName, 'MAP 11-52-0 (Nutrien)');
      });
    });
  });

  group('Retailer', () {
    final testDate = DateTime(2024, 1, 15);

    test('creates instance with required fields', () {
      final retailer = Retailer(
        id: 'ret-123',
        name: 'Co-op Agro',
        city: 'Regina',
        provinceState: 'Saskatchewan',
        createdAt: testDate,
      );

      expect(retailer.id, 'ret-123');
      expect(retailer.name, 'Co-op Agro');
      expect(retailer.city, 'Regina');
      expect(retailer.provinceState, 'Saskatchewan');
      expect(retailer.country, 'Canada'); // default
      expect(retailer.priceEntryCount, 0);
    });

    test('creates instance with all fields', () {
      final retailer = Retailer(
        id: 'ret-456',
        name: 'Nutrien Ag Solutions',
        chainId: 'nutrien',
        chainName: 'Nutrien',
        city: 'Saskatoon',
        provinceState: 'Saskatchewan',
        country: 'Canada',
        address: '123 Main St',
        priceEntryCount: 50,
        createdAt: testDate,
      );

      expect(retailer.chainId, 'nutrien');
      expect(retailer.chainName, 'Nutrien');
      expect(retailer.address, '123 Main St');
      expect(retailer.priceEntryCount, 50);
    });

    group('fromMap', () {
      test('parses valid map correctly', () {
        final map = {
          'id': 'ret-map',
          'name': 'Richardson Pioneer',
          'chain_id': 'richardson',
          'chain_name': 'Richardson',
          'city': 'Yorkton',
          'province_state': 'Saskatchewan',
          'country': 'Canada',
          'price_entry_count': 30,
          'created_at': '2024-01-15T00:00:00.000',
        };

        final retailer = Retailer.fromMap(map);

        expect(retailer.id, 'ret-map');
        expect(retailer.name, 'Richardson Pioneer');
        expect(retailer.chainName, 'Richardson');
        expect(retailer.city, 'Yorkton');
        expect(retailer.priceEntryCount, 30);
      });

      test('handles missing created_at', () {
        final map = {
          'id': 'ret-nodate',
          'name': 'Local Dealer',
          'city': 'Moose Jaw',
          'province_state': 'Saskatchewan',
        };

        final retailer = Retailer.fromMap(map);
        expect(retailer.createdAt, isNotNull);
      });

      test('defaults country to Canada', () {
        final map = {
          'id': 'ret-nocountry',
          'name': 'Dealer',
          'city': 'Edmonton',
          'province_state': 'Alberta',
          'created_at': '2024-01-15T00:00:00.000',
        };

        final retailer = Retailer.fromMap(map);
        expect(retailer.country, 'Canada');
      });
    });

    group('toMap', () {
      test('converts to map correctly', () {
        final retailer = Retailer(
          id: 'ret-tomap',
          name: 'Parrish & Heimbecker',
          city: 'Swift Current',
          provinceState: 'Saskatchewan',
          country: 'Canada',
          createdAt: testDate,
        );

        final map = retailer.toMap();

        expect(map['name'], 'Parrish & Heimbecker');
        expect(map['city'], 'Swift Current');
        expect(map['province_state'], 'Saskatchewan');
        expect(map['country'], 'Canada');
      });
    });

    test('displayName formats correctly', () {
      final retailer = Retailer(
        id: 'ret-display',
        name: 'Cargill Ag',
        city: 'Winnipeg',
        provinceState: 'Manitoba',
        createdAt: testDate,
      );

      expect(retailer.displayName, 'Cargill Ag - Winnipeg, Manitoba');
    });
  });

  group('PriceEntry', () {
    final testDate = DateTime(2024, 1, 15);

    test('creates instance with required fields', () {
      final entry = PriceEntry(
        id: 'price-123',
        productId: 'prod-123',
        retailerId: 'ret-123',
        price: 850.00,
        unit: 'tonne',
        currency: 'CAD',
        priceDate: testDate,
        createdAt: testDate,
      );

      expect(entry.id, 'price-123');
      expect(entry.price, 850.00);
      expect(entry.unit, 'tonne');
      expect(entry.currency, 'CAD');
      expect(entry.isAnonymous, true); // default
      expect(entry.thumbsUpCount, 0);
    });

    group('fromMap', () {
      test('parses valid map correctly', () {
        final map = {
          'id': 'price-map',
          'product_id': 'prod-1',
          'retailer_id': 'ret-1',
          'price': 925.50,
          'unit': 'tonne',
          'currency': 'CAD',
          'price_date': '2024-01-15T00:00:00.000',
          'is_anonymous': false,
          'notes': 'Cash price',
          'thumbs_up_count': 5,
          'thumbs_down_count': 1,
          'created_at': '2024-01-15T00:00:00.000',
        };

        final entry = PriceEntry.fromMap(map);

        expect(entry.price, 925.50);
        expect(entry.isAnonymous, false);
        expect(entry.notes, 'Cash price');
        expect(entry.thumbsUpCount, 5);
        expect(entry.thumbsDownCount, 1);
      });

      test('handles integer price as double', () {
        final map = {
          'id': 'price-int',
          'product_id': 'prod-1',
          'retailer_id': 'ret-1',
          'price': 900, // int instead of double
          'unit': 'tonne',
          'price_date': '2024-01-15T00:00:00.000',
          'created_at': '2024-01-15T00:00:00.000',
        };

        final entry = PriceEntry.fromMap(map);
        expect(entry.price, 900.0);
      });

      test('defaults currency to CAD', () {
        final map = {
          'id': 'price-nocurrency',
          'product_id': 'prod-1',
          'retailer_id': 'ret-1',
          'price': 800.0,
          'unit': 'tonne',
          'price_date': '2024-01-15T00:00:00.000',
          'created_at': '2024-01-15T00:00:00.000',
        };

        final entry = PriceEntry.fromMap(map);
        expect(entry.currency, 'CAD');
      });
    });

    group('formattedPrice', () {
      test('formats CAD correctly', () {
        final entry = PriceEntry(
          id: 'price-cad',
          productId: 'prod-1',
          retailerId: 'ret-1',
          price: 850.00,
          unit: 'tonne',
          currency: 'CAD',
          priceDate: testDate,
          createdAt: testDate,
        );

        expect(entry.formattedPrice, 'C\$850.00/tonne');
      });

      test('formats USD correctly', () {
        final entry = PriceEntry(
          id: 'price-usd',
          productId: 'prod-1',
          retailerId: 'ret-1',
          price: 725.50,
          unit: 'ton',
          currency: 'USD',
          priceDate: testDate,
          createdAt: testDate,
        );

        expect(entry.formattedPrice, 'US\$725.50/ton');
      });

      test('formats with decimal places', () {
        final entry = PriceEntry(
          id: 'price-decimal',
          productId: 'prod-1',
          retailerId: 'ret-1',
          price: 12.5,
          unit: 'L',
          currency: 'CAD',
          priceDate: testDate,
          createdAt: testDate,
        );

        expect(entry.formattedPrice, 'C\$12.50/L');
      });
    });

    group('fromFullView', () {
      test('parses joined data correctly', () {
        final map = {
          'id': 'price-full',
          'product_id': 'prod-1',
          'retailer_id': 'ret-1',
          'price': 875.00,
          'unit': 'tonne',
          'currency': 'CAD',
          'price_date': '2024-01-15T00:00:00.000',
          'is_anonymous': true,
          'thumbs_up_count': 3,
          'thumbs_down_count': 0,
          'created_at': '2024-01-15T00:00:00.000',
          // Product fields
          'product_type': 'fertilizer',
          'product_name': 'Urea',
          'brand_name': 'CF Industries',
          'analysis': '46-0-0',
          // Retailer fields
          'retailer_name': 'Nutrien',
          'retailer_city': 'Regina',
          'retailer_province_state': 'Saskatchewan',
          'chain_name': 'Nutrien AG',
        };

        final entry = PriceEntry.fromFullView(map);

        expect(entry.price, 875.00);
        expect(entry.product, isNotNull);
        expect(entry.product!.productName, 'Urea');
        expect(entry.product!.analysis, '46-0-0');
        expect(entry.retailer, isNotNull);
        expect(entry.retailer!.name, 'Nutrien');
        expect(entry.retailer!.city, 'Regina');
      });
    });
  });

  group('PriceStats', () {
    test('creates instance with default values', () {
      const stats = PriceStats();

      expect(stats.avgPrice, isNull);
      expect(stats.minPrice, isNull);
      expect(stats.maxPrice, isNull);
      expect(stats.entryCount, 0);
    });

    test('creates instance with all values', () {
      final stats = PriceStats(
        avgPrice: 850.0,
        minPrice: 800.0,
        maxPrice: 900.0,
        entryCount: 25,
        latestPrice: 875.0,
        latestDate: DateTime(2024, 1, 15),
      );

      expect(stats.avgPrice, 850.0);
      expect(stats.minPrice, 800.0);
      expect(stats.maxPrice, 900.0);
      expect(stats.entryCount, 25);
      expect(stats.latestPrice, 875.0);
    });

    group('fromMap', () {
      test('parses valid map correctly', () {
        final map = {
          'avg_price': 825.5,
          'min_price': 750.0,
          'max_price': 900.0,
          'entry_count': 15,
          'latest_price': 850.0,
          'latest_date': '2024-01-15T00:00:00.000',
        };

        final stats = PriceStats.fromMap(map);

        expect(stats.avgPrice, 825.5);
        expect(stats.minPrice, 750.0);
        expect(stats.maxPrice, 900.0);
        expect(stats.entryCount, 15);
        expect(stats.latestPrice, 850.0);
        expect(stats.latestDate, isNotNull);
      });

      test('handles null values', () {
        final map = <String, dynamic>{};

        final stats = PriceStats.fromMap(map);

        expect(stats.avgPrice, isNull);
        expect(stats.minPrice, isNull);
        expect(stats.maxPrice, isNull);
        expect(stats.entryCount, 0);
      });

      test('handles integer values as double', () {
        final map = {
          'avg_price': 850, // int
          'min_price': 800, // int
          'max_price': 900, // int
          'entry_count': 10,
        };

        final stats = PriceStats.fromMap(map);

        expect(stats.avgPrice, 850.0);
        expect(stats.minPrice, 800.0);
        expect(stats.maxPrice, 900.0);
      });
    });
  });

  group('PriceAlert', () {
    final testDate = DateTime(2024, 1, 15);

    test('creates instance with required fields', () {
      final alert = PriceAlert(
        id: 'alert-123',
        userId: 'user-123',
        alertType: 'below',
        createdAt: testDate,
      );

      expect(alert.id, 'alert-123');
      expect(alert.userId, 'user-123');
      expect(alert.alertType, 'below');
      expect(alert.isActive, true); // default
      expect(alert.triggerCount, 0);
    });

    test('creates instance with all fields', () {
      final alert = PriceAlert(
        id: 'alert-456',
        userId: 'user-456',
        productId: 'prod-123',
        productType: 'fertilizer',
        provinceState: 'Saskatchewan',
        targetPrice: 800.0,
        alertType: 'below',
        isActive: true,
        lastTriggered: testDate,
        triggerCount: 3,
        createdAt: testDate,
      );

      expect(alert.productId, 'prod-123');
      expect(alert.productType, 'fertilizer');
      expect(alert.provinceState, 'Saskatchewan');
      expect(alert.targetPrice, 800.0);
      expect(alert.triggerCount, 3);
    });

    group('fromMap', () {
      test('parses valid map correctly', () {
        final map = {
          'id': 'alert-map',
          'user_id': 'user-map',
          'product_id': 'prod-1',
          'product_type': 'fertilizer',
          'province_state': 'Alberta',
          'target_price': 750.0,
          'alert_type': 'above',
          'is_active': true,
          'trigger_count': 5,
          'created_at': '2024-01-15T00:00:00.000',
        };

        final alert = PriceAlert.fromMap(map);

        expect(alert.id, 'alert-map');
        expect(alert.productType, 'fertilizer');
        expect(alert.targetPrice, 750.0);
        expect(alert.alertType, 'above');
        expect(alert.triggerCount, 5);
      });

      test('handles null optional fields', () {
        final map = {
          'id': 'alert-minimal',
          'user_id': 'user-1',
          'alert_type': 'any',
          'created_at': '2024-01-15T00:00:00.000',
        };

        final alert = PriceAlert.fromMap(map);

        expect(alert.productId, isNull);
        expect(alert.targetPrice, isNull);
        expect(alert.lastTriggered, isNull);
        expect(alert.isActive, true);
      });

      test('parses lastTriggered when present', () {
        final map = {
          'id': 'alert-triggered',
          'user_id': 'user-1',
          'alert_type': 'below',
          'last_triggered': '2024-01-10T00:00:00.000',
          'created_at': '2024-01-01T00:00:00.000',
        };

        final alert = PriceAlert.fromMap(map);

        expect(alert.lastTriggered, isNotNull);
        expect(alert.lastTriggered!.day, 10);
      });
    });

    group('toMap', () {
      test('converts to map correctly', () {
        final alert = PriceAlert(
          id: 'alert-tomap',
          userId: 'user-tomap',
          productId: 'prod-1',
          productType: 'seed',
          provinceState: 'Manitoba',
          targetPrice: 500.0,
          alertType: 'below',
          isActive: true,
          createdAt: testDate,
        );

        final map = alert.toMap();

        expect(map['product_id'], 'prod-1');
        expect(map['product_type'], 'seed');
        expect(map['province_state'], 'Manitoba');
        expect(map['target_price'], 500.0);
        expect(map['alert_type'], 'below');
        expect(map['is_active'], true);
        // Note: toMap doesn't include id, user_id, or created_at
        expect(map.containsKey('id'), isFalse);
        expect(map.containsKey('user_id'), isFalse);
      });
    });
  });
}
