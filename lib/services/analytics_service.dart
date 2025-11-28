import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Analytics service for tracking user events and screen views.
/// Uses Firebase Analytics for comprehensive app analytics.
/// Gracefully handles the case when Firebase isn't available.
class AnalyticsService {
  static AnalyticsService? _instance;
  FirebaseAnalytics? _analytics;
  FirebaseAnalyticsObserver? _observer;
  bool _isInitialized = false;

  AnalyticsService._() {
    _initializeAnalytics();
  }

  void _initializeAnalytics() {
    try {
      _analytics = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
      _isInitialized = true;
      if (kDebugMode) {
        print('Analytics: Firebase Analytics initialized successfully');
      }
    } catch (e) {
      _isInitialized = false;
      if (kDebugMode) {
        print('Analytics: Firebase Analytics not available - $e');
      }
    }
  }

  /// Get the singleton instance
  static AnalyticsService get instance {
    _instance ??= AnalyticsService._();
    return _instance!;
  }

  /// Get the analytics observer for navigation tracking
  /// Returns a no-op observer if Firebase isn't available
  NavigatorObserver get observer =>
      _observer ?? NavigatorObserver();

  /// Log a screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
      if (kDebugMode) {
        print('Analytics: Screen view logged - $screenName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Analytics error logging screen view: $e');
      }
    }
  }

  /// Log when a user creates a post
  Future<void> logPostCreated({
    required String category,
    required bool isAnonymous,
    String? provinceState,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'post_created',
        parameters: {
          'category': category,
          'is_anonymous': isAnonymous.toString(),
          'province_state': provinceState ?? 'not_specified',
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('Analytics error logging post_created: $e');
      }
    }
  }

  /// Log when a user submits an input price
  Future<void> logInputPriceSubmitted({
    required String productType,
    required String provinceState,
    required String currency,
    String? retailerName,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'input_price_submitted',
        parameters: {
          'product_type': productType,
          'province_state': provinceState,
          'currency': currency,
          'retailer_name': retailerName ?? 'unknown',
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('Analytics error logging input_price_submitted: $e');
      }
    }
  }

  /// Log when a user casts a vote
  Future<void> logVoteCast({
    required String voteType,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'vote_cast',
        parameters: {
          'vote_type': voteType,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('Analytics error logging vote_cast: $e');
      }
    }
  }

  /// Log when a user posts a comment
  Future<void> logCommentPosted() async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(name: 'comment_posted');
    } catch (e) {
      if (kDebugMode) {
        print('Analytics error logging comment_posted: $e');
      }
    }
  }

  /// Log when a user signs up
  Future<void> logSignUp({
    required String method,
    String? provinceState,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logSignUp(signUpMethod: method);
      if (provinceState != null) {
        await _analytics!.logEvent(
          name: 'signup_location',
          parameters: {'province_state': provinceState},
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Analytics error logging sign_up: $e');
      }
    }
  }

  /// Log when a user logs in
  Future<void> logLogin({required String method}) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logLogin(loginMethod: method);
    } catch (e) {
      if (kDebugMode) {
        print('Analytics error logging login: $e');
      }
    }
  }

  /// Log category filter usage
  Future<void> logCategoryFilter({required String category}) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'category_filter',
        parameters: {'category': category},
      );
    } catch (e) {
      if (kDebugMode) {
        print('Analytics error logging category_filter: $e');
      }
    }
  }

  /// Log search usage
  Future<void> logSearch({required String searchTerm}) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logSearch(searchTerm: searchTerm);
    } catch (e) {
      if (kDebugMode) {
        print('Analytics error logging search: $e');
      }
    }
  }

  /// Log when user views a post detail
  Future<void> logPostView({
    required String postId,
    required String category,
  }) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'post_view',
        parameters: {
          'post_id': postId,
          'category': category,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('Analytics error logging post_view: $e');
      }
    }
  }

  /// Set user property for province/state
  Future<void> setUserLocation(String provinceState) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.setUserProperty(
        name: 'province_state',
        value: provinceState,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Analytics error setting user location: $e');
      }
    }
  }

  /// Set user ID for tracking (only for authenticated users)
  Future<void> setUserId(String? userId) async {
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.setUserId(id: userId);
    } catch (e) {
      if (kDebugMode) {
        print('Analytics error setting user id: $e');
      }
    }
  }
}
