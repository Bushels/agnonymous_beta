import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User, AuthChangeEvent;
import 'package:supabase_flutter/supabase_flutter.dart' as supa show AuthState;
import '../models/user_profile.dart';
import '../main.dart' show supabase, logger;

/// Auth state
class AuthState {
  final User? user;
  final UserProfile? profile;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.profile,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null;
  bool get isGuest => user == null;

  AuthState copyWith({
    User? user,
    UserProfile? profile,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Auth state notifier
class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<supa.AuthState>? _authSubscription;
  Timer? _sessionRefreshTimer;

  @override
  AuthState build() {
    // Clean up previous subscription if exists
    _authSubscription?.cancel();
    _sessionRefreshTimer?.cancel();

    // Listen to auth state changes
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      logger.d('Auth state changed: $event');

      switch (event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
          if (session != null) {
            _loadUserProfile(session.user);
          }
          break;
        case AuthChangeEvent.signedOut:
          state = const AuthState();
          break;
        case AuthChangeEvent.passwordRecovery:
          // Password recovery is handled by AuthWrapper in main.dart
          // User will be directed to ResetPasswordScreen
          if (session != null) {
            state = AuthState(user: session.user);
          }
          break;
        default:
          if (session != null) {
            _loadUserProfile(session.user);
          }
      }
    });

    // Clean up subscriptions and timers when provider is disposed
    ref.onDispose(() {
      _authSubscription?.cancel();
      _sessionRefreshTimer?.cancel();
    });

    // Check initial session and load profile
    _initializeSession();

    return const AuthState(isLoading: true);
  }

  /// Initialize session on app start
  Future<void> _initializeSession() async {
    try {
      final session = supabase.auth.currentSession;
      if (session != null) {
        logger.d('Found existing session for user: ${session.user.id}');

        // Check if session needs refresh (expires within 5 minutes)
        final expiresAt = session.expiresAt;
        if (expiresAt != null) {
          final expiresAtDate = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
          final now = DateTime.now();
          final timeUntilExpiry = expiresAtDate.difference(now);

          if (timeUntilExpiry.inMinutes < 5) {
            logger.d('Session expiring soon, refreshing...');
            try {
              await supabase.auth.refreshSession();
            } catch (e) {
              logger.w('Failed to refresh session: $e');
            }
          }
        }

        await _loadUserProfile(session.user);

        // Start periodic session refresh timer (every 10 minutes)
        _startSessionRefreshTimer();
      } else {
        logger.d('No existing session found');
        state = const AuthState(isLoading: false);
      }
    } catch (e) {
      logger.e('Error initializing session: $e');
      state = const AuthState(isLoading: false);
    }
  }

  /// Start a timer to periodically check and refresh the session
  void _startSessionRefreshTimer() {
    _sessionRefreshTimer?.cancel();
    // Check session every 10 minutes
    _sessionRefreshTimer = Timer.periodic(const Duration(minutes: 10), (_) async {
      final session = supabase.auth.currentSession;
      if (session == null) {
        _sessionRefreshTimer?.cancel();
        return;
      }

      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        final expiresAtDate = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
        final now = DateTime.now();
        final timeUntilExpiry = expiresAtDate.difference(now);

        // Refresh if session expires within 15 minutes
        if (timeUntilExpiry.inMinutes < 15) {
          logger.d('Session expiring in ${timeUntilExpiry.inMinutes} minutes, refreshing...');
          try {
            await supabase.auth.refreshSession();
            logger.d('Session refreshed successfully');
          } catch (e) {
            logger.w('Failed to refresh session: $e');
          }
        }
      }
    });
  }

  Future<void> _loadUserProfile(User user) async {
    try {
      // Try to fetch existing profile
      final response = await supabase
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        // Profile exists, load it
        final profile = UserProfile.fromMap(response);
        state = AuthState(user: user, profile: profile);
      } else {
        // Profile doesn't exist - create it
        logger.w('Profile missing for user ${user.id}, creating one...');
        await _createMissingProfile(user);
      }
    } catch (e) {
      logger.e('Error loading user profile: $e');
      // Try to create profile as fallback
      try {
        await _createMissingProfile(user);
      } catch (createError) {
        logger.e('Failed to create missing profile: $createError');
        state = AuthState(user: user, error: 'Failed to load profile');
      }
    }
  }

  /// Create a missing profile for an authenticated user
  Future<void> _createMissingProfile(User user) async {
    final username = user.userMetadata?['username'] as String? ??
        'user_${user.id.substring(0, 8)}';
    final provinceState = user.userMetadata?['province_state'] as String?;

    try {
      await supabase.from('user_profiles').insert({
        'id': user.id,
        'username': username,
        'email': user.email,
        'email_verified': user.emailConfirmedAt != null,
        'province_state': provinceState,
        'reputation_points': 0,
        'public_reputation': 0,
        'anonymous_reputation': 0,
        'post_count': 0,
        'comment_count': 0,
        'vote_count': 0,
      });

      logger.i('Created missing profile for user ${user.id}');

      // Now load the newly created profile
      final response = await supabase
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .single();

      final profile = UserProfile.fromMap(response);
      state = AuthState(user: user, profile: profile);
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      // If insert fails due to conflict (409, duplicate, 23505), profile may already exist
      if (errorStr.contains('duplicate') ||
          errorStr.contains('23505') ||
          errorStr.contains('409') ||
          errorStr.contains('conflict')) {
        logger.w('Profile conflict for user ${user.id}, trying to load existing...');
        // Try to load existing profile
        try {
          final response = await supabase
              .from('user_profiles')
              .select()
              .eq('id', user.id)
              .maybeSingle();

          if (response != null) {
            final profile = UserProfile.fromMap(response);
            state = AuthState(user: user, profile: profile);
          } else {
            // Profile doesn't exist but we got a conflict - username might be taken
            // Generate a unique username and try again
            final uniqueUsername = 'user_${user.id.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch % 10000}';
            await supabase.from('user_profiles').insert({
              'id': user.id,
              'username': uniqueUsername,
              'email': user.email,
              'email_verified': user.emailConfirmedAt != null,
              'province_state': user.userMetadata?['province_state'] as String?,
              'reputation_points': 0,
              'public_reputation': 0,
              'anonymous_reputation': 0,
              'post_count': 0,
              'comment_count': 0,
              'vote_count': 0,
            });

            final newResponse = await supabase
                .from('user_profiles')
                .select()
                .eq('id', user.id)
                .single();
            final profile = UserProfile.fromMap(newResponse);
            state = AuthState(user: user, profile: profile);
          }
        } catch (loadError) {
          logger.e('Failed to resolve profile conflict: $loadError');
          state = AuthState(user: user, error: 'Failed to create profile');
        }
      } else {
        rethrow;
      }
    }
  }

  /// Sign up with email and password
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    String? provinceState,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Sign up with Supabase Auth
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'province_state': provinceState,
        },
      );

      if (authResponse.user == null) {
        throw Exception('Sign up failed');
      }

      // User profile will be created automatically by database trigger
      // Load the profile
      await _loadUserProfile(authResponse.user!);

      state = state.copyWith(isLoading: false);
    } catch (e) {
      logger.e('Sign up error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Sign up failed: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final authResponse = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Sign in failed');
      }

      await _loadUserProfile(authResponse.user!);

      state = state.copyWith(isLoading: false);
    } catch (e) {
      logger.e('Sign in error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Sign in failed: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
      state = const AuthState();
    } catch (e) {
      logger.e('Sign out error: $e');
      state = state.copyWith(error: 'Sign out failed: ${e.toString()}');
    }
  }

  /// Refresh user profile
  Future<void> refreshProfile() async {
    final user = state.user;
    if (user != null) {
      await _loadUserProfile(user);
    }
  }

  /// Update user profile
  Future<void> updateProfile({
    String? username,
    String? bio,
    String? provinceState,
  }) async {
    if (state.profile == null) return;

    try {
      final updates = <String, dynamic>{};
      if (username != null) updates['username'] = username;
      if (bio != null) updates['bio'] = bio;
      if (provinceState != null) updates['province_state'] = provinceState;

      await supabase
          .from('user_profiles')
          .update(updates)
          .eq('id', state.profile!.id);

      await refreshProfile();
    } catch (e) {
      logger.e('Update profile error: $e');
      state = state.copyWith(error: 'Failed to update profile');
      rethrow;
    }
  }
}

/// Auth provider
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// Convenience provider for current user
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

/// Convenience provider for current user profile
final currentUserProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(authProvider).profile;
});

/// Is authenticated provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

/// Is guest provider
final isGuestProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isGuest;
});
