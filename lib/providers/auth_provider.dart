import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User, AuthChangeEvent, Session;
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
    // Clean up on dispose
    ref.onDispose(() {
      _authSubscription?.cancel();
      _sessionRefreshTimer?.cancel();
    });

    // Set up listener for when user actually logs in
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      // Only respond to explicit sign in/out events
      if (event == AuthChangeEvent.signedIn && session != null) {
        _loadUserProfile(session.user);
      } else if (event == AuthChangeEvent.signedOut) {
        state = const AuthState();
      } else if (event == AuthChangeEvent.passwordRecovery && session != null) {
        state = AuthState(user: session.user);
      }
    });

    // Check initial session
    _initializeSession();

    return const AuthState(isLoading: true);
  }

  Future<void> _initializeSession() async {
    // === OPTIMISTIC SESSION CHECK ===
    // Check local session synchronously first - no network call needed
    final session = supabase.auth.currentSession;

    if (session == null) {
      // No session locally - immediately show login (fastest path)
      logger.d('No existing session - showing login screen immediately');
      state = const AuthState(isLoading: false);
      return;
    }

    // Force sign out ONLY if user is anonymous (legacy/stale sessions)
    if (session.user.isAnonymous == true) {
      logger.i('Found anonymous session, forcing sign out');
      state = const AuthState(isLoading: false);
      signOut(); // Don't await - let it happen in background
      return;
    }

    // === OPTIMISTIC UI: Show user as authenticated immediately ===
    // This allows the main UI to render while we load the profile
    logger.d('Found existing session for user: ${session.user.id} - showing UI optimistically');
    state = AuthState(user: session.user, isLoading: false);

    // === BACKGROUND TASKS: Load profile and refresh session without blocking UI ===
    _loadUserProfileInBackground(session.user);
    _refreshSessionIfNeeded(session);
    _startSessionRefreshTimer();
  }

  /// Refresh session in background if it's close to expiry
  void _refreshSessionIfNeeded(Session session) {
    final expiresAt = session.expiresAt;
    if (expiresAt != null) {
      final expiresAtDate = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
      final timeUntilExpiry = expiresAtDate.difference(DateTime.now());

      if (timeUntilExpiry.inMinutes < 5) {
        logger.d('Session expiring soon, refreshing in background');
        // Fire and forget - we don't need the result
        supabase.auth.refreshSession().then((_) {}).catchError((e) {
          logger.w('Background session refresh failed: $e');
        });
      }
    }
  }

  /// Load user profile in background without blocking UI
  Future<void> _loadUserProfileInBackground(User user) async {
    try {
      final response = await supabase
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(milliseconds: 1500)); // Reduced timeout

      if (response != null) {
        final profile = UserProfile.fromMap(response);
        // Only update state if user is still the same (avoid race conditions)
        if (state.user?.id == user.id) {
          state = AuthState(user: user, profile: profile);
        }
      } else {
        // Profile doesn't exist - create in background
        _createMissingProfile(user).catchError((e) {
          logger.e('Failed to create missing profile: $e');
        });
      }
    } catch (e) {
      logger.w('Background profile load failed: $e');
      // User is still authenticated, just without profile details
      // Try to create/load profile in background
      _createMissingProfile(user).catchError((createError) {
        logger.e('Failed to create missing profile: $createError');
      });
    }
  }

  void _startSessionRefreshTimer() {
    _sessionRefreshTimer?.cancel();
    _sessionRefreshTimer = Timer.periodic(const Duration(minutes: 10), (_) async {
      final session = supabase.auth.currentSession;
      if (session == null) {
        _sessionRefreshTimer?.cancel();
        return;
      }
      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        final expiresAtDate = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
        final timeUntilExpiry = expiresAtDate.difference(DateTime.now());
        if (timeUntilExpiry.inMinutes < 15) {
          try {
            await supabase.auth.refreshSession();
          } catch (_) {}
        }
      }
    });
  }

  Future<void> _loadUserProfile(User user) async {
    try {
      // Reduced timeout - profile loading should be fast
      final response = await supabase
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(milliseconds: 1500));

      if (response != null) {
        final profile = UserProfile.fromMap(response);
        state = AuthState(user: user, profile: profile);
        _startSessionRefreshTimer();
      } else {
        // Profile doesn't exist - set user state first, create profile in background
        state = AuthState(user: user);
        _createMissingProfile(user).catchError((e) {
          logger.e('Failed to create missing profile: $e');
        });
      }
    } catch (e) {
      logger.e('Error loading user profile: $e');
      // Still set user state so app can function
      state = AuthState(user: user);
      // Try to create/load profile in background
      _createMissingProfile(user).catchError((createError) {
        logger.e('Failed to create missing profile: $createError');
      });
    }
  }

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

      final response = await supabase
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .single();

      final profile = UserProfile.fromMap(response);
      state = AuthState(user: user, profile: profile);
      _startSessionRefreshTimer();
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('duplicate') ||
          errorStr.contains('23505') ||
          errorStr.contains('409') ||
          errorStr.contains('conflict')) {
        try {
          final response = await supabase
              .from('user_profiles')
              .select()
              .eq('id', user.id)
              .maybeSingle();

          if (response != null) {
            final profile = UserProfile.fromMap(response);
            state = AuthState(user: user, profile: profile);
            _startSessionRefreshTimer();
          } else {
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
            _startSessionRefreshTimer();
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

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    String? provinceState,
    String? emailRedirectTo,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: emailRedirectTo,
        data: {
          'username': username,
          'province_state': provinceState,
        },
      );

      if (authResponse.user == null) {
        throw Exception('Sign up failed');
      }

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

  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
      state = const AuthState();
    } catch (e) {
      logger.e('Sign out error: $e');
      state = state.copyWith(error: 'Sign out failed: ${e.toString()}');
    }
  }

  Future<void> refreshProfile() async {
    final user = state.user;
    if (user != null) {
      await _loadUserProfile(user);
    }
  }

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

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

final currentUserProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(authProvider).profile;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final isGuestProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isGuest;
});
