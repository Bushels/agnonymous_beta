import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

/// Authentication service handling user signup, signin, and profile management
class AuthService {
  final SupabaseClient _supabase;
  final Logger _logger;

  AuthService(this._supabase, this._logger);

  /// Check if username is available (case-insensitive)
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final result = await _supabase.rpc('is_username_available', params: {
        'username_to_check': username,
      });
      return result as bool;
    } catch (e) {
      _logger.e('Error checking username availability', error: e);
      return false;
    }
  }

  /// Validate username format
  String? validateUsername(String username) {
    if (username.isEmpty) {
      return 'Username cannot be empty';
    }
    if (username.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (username.length > 30) {
      return 'Username must be 30 characters or less';
    }
    // Check format: alphanumeric, underscore, hyphen only
    final validFormat = RegExp(r'^[a-zA-Z0-9_-]+$');
    if (!validFormat.hasMatch(username)) {
      return 'Username can only contain letters, numbers, underscore and hyphen';
    }
    return null;
  }

  /// Validate email format
  String? validateEmail(String email) {
    if (email.isEmpty) {
      return 'Email cannot be empty';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validate password
  String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password cannot be empty';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  /// Sign up new user with email, password, and username
  Future<AppUser?> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      _logger.i('Signing up user with email: $email, username: $username');

      // 1. Create auth user
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw 'Failed to create account. Please try again.';
      }

      final authUserId = authResponse.user!.id;
      _logger.d('Auth user created: $authUserId');

      // 2. Create user profile in users table
      final userMap = await _supabase.from('users').insert({
        'auth_user_id': authUserId,
        'username': username,
        'email_verified': false,
        'points': 0,
        'reputation_score': 0,
        'badges': [],
        'default_anonymous': true, // Default to anonymous posting
        'show_verified_badge': true,
      }).select().single();

      _logger.i('User profile created successfully');

      return AppUser.fromMap(userMap);
    } catch (e) {
      _logger.e('Error during signup', error: e);
      rethrow;
    }
  }

  /// Sign in existing user
  Future<AppUser?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('Signing in user with email: $email');

      // 1. Sign in with Supabase auth
      final authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw 'Invalid email or password';
      }

      final authUserId = authResponse.user!.id;
      _logger.d('Auth successful: $authUserId');

      // 2. Get user profile
      final userMap = await _supabase
          .from('users')
          .select()
          .eq('auth_user_id', authUserId)
          .single();

      _logger.i('User profile loaded successfully');

      return AppUser.fromMap(userMap);
    } catch (e) {
      _logger.e('Error during signin', error: e);
      rethrow;
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      _logger.i('Signing out user');
      await _supabase.auth.signOut();
      _logger.i('Sign out successful');
    } catch (e) {
      _logger.e('Error during signout', error: e);
      rethrow;
    }
  }

  /// Get current user profile (if authenticated)
  Future<AppUser?> getCurrentUser() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        _logger.d('No authenticated user');
        return null;
      }

      _logger.d('Getting profile for auth user: ${authUser.id}');

      final userMap = await _supabase
          .from('users')
          .select()
          .eq('auth_user_id', authUser.id)
          .single();

      return AppUser.fromMap(userMap);
    } catch (e) {
      _logger.e('Error getting current user', error: e);
      return null;
    }
  }

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    try {
      _logger.i('Sending password reset email to: $email');
      await _supabase.auth.resetPasswordForEmail(email);
      _logger.i('Password reset email sent');
    } catch (e) {
      _logger.e('Error sending password reset', error: e);
      rethrow;
    }
  }

  /// Resend email verification
  Future<void> resendVerificationEmail() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || user.email == null) {
        throw 'No user signed in';
      }

      _logger.i('Resending verification email to: ${user.email}');

      // Supabase automatically sends verification email on signup
      // To resend, we need to use the resend endpoint
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: user.email!,
      );

      _logger.i('Verification email resent');
    } catch (e) {
      _logger.e('Error resending verification email', error: e);
      rethrow;
    }
  }

  /// Update user profile
  Future<AppUser> updateProfile({
    required String userId,
    String? displayName,
    String? bio,
    bool? defaultAnonymous,
    bool? showVerifiedBadge,
  }) async {
    try {
      _logger.i('Updating profile for user: $userId');

      final updates = <String, dynamic>{};
      if (displayName != null) updates['display_name'] = displayName;
      if (bio != null) updates['bio'] = bio;
      if (defaultAnonymous != null) updates['default_anonymous'] = defaultAnonymous;
      if (showVerifiedBadge != null) updates['show_verified_badge'] = showVerifiedBadge;

      final userMap = await _supabase
          .from('users')
          .update(updates)
          .eq('id', userId)
          .select()
          .single();

      _logger.i('Profile updated successfully');

      return AppUser.fromMap(userMap);
    } catch (e) {
      _logger.e('Error updating profile', error: e);
      rethrow;
    }
  }

  /// Change username (must check availability first)
  Future<AppUser> changeUsername({
    required String userId,
    required String newUsername,
  }) async {
    try {
      _logger.i('Changing username for user: $userId to: $newUsername');

      // Validate username format
      final validationError = validateUsername(newUsername);
      if (validationError != null) {
        throw validationError;
      }

      // Check availability
      final available = await isUsernameAvailable(newUsername);
      if (!available) {
        throw 'Username is already taken';
      }

      // Update username
      final userMap = await _supabase
          .from('users')
          .update({'username': newUsername})
          .eq('id', userId)
          .select()
          .single();

      _logger.i('Username changed successfully');

      return AppUser.fromMap(userMap);
    } catch (e) {
      _logger.e('Error changing username', error: e);
      rethrow;
    }
  }

  /// Get user display info by user ID
  Future<UserDisplayInfo?> getUserDisplayInfo(String userId) async {
    try {
      final result = await _supabase.rpc('get_user_display_info', params: {
        'user_id_param': userId,
      });

      if (result == null || (result is List && result.isEmpty)) {
        return null;
      }

      final map = result is List ? result.first : result;
      return UserDisplayInfo.fromMap(map as Map<String, dynamic>);
    } catch (e) {
      _logger.e('Error getting user display info', error: e);
      return null;
    }
  }

  /// Check if current user is authenticated (not guest)
  bool get isAuthenticated => _supabase.auth.currentUser != null;

  /// Check if current user is guest (anonymous/not logged in)
  bool get isGuest => _supabase.auth.currentUser == null;

  /// Get current auth session
  Session? get currentSession => _supabase.auth.currentSession;
}
