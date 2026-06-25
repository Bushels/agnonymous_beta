import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/globals.dart';
import '../../../models/user_profile.dart';

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

  AuthState copyWith({
    User? user,
    UserProfile? profile,
    bool? isLoading,
    String? error,
    bool clearProfile = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      profile: clearProfile ? null : (profile ?? this.profile),
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<User?>? _authSubscription;

  @override
  AuthState build() {
    _authSubscription = firebaseAuth.authStateChanges().listen((User? firebaseUser) {
      if (firebaseUser != null) {
        if (firebaseUser.isAnonymous) {
          state = AuthState(user: firebaseUser, profile: null, isLoading: false);
        } else {
          _fetchProfile(firebaseUser);
        }
      } else {
        state = const AuthState(user: null, profile: null, isLoading: false);
      }
    });

    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    return const AuthState(isLoading: true);
  }

  Future<void> _fetchProfile(User firebaseUser) async {
    state = state.copyWith(isLoading: true, user: firebaseUser);
    try {
      final doc = await firestore.collection('user_profiles').doc(firebaseUser.uid).get();
      if (!doc.exists) {
        // Fallback: If auth exists but profile document doesn't, create one
        final newProfile = UserProfile(
          id: firebaseUser.uid,
          username: firebaseUser.displayName ?? 'Farmer_${firebaseUser.uid.substring(0, 5)}',
          email: firebaseUser.email,
          emailVerified: firebaseUser.emailVerified,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await firestore.collection('user_profiles').doc(firebaseUser.uid).set(newProfile.toMap());
        state = state.copyWith(profile: newProfile, isLoading: false);
      } else {
        final profile = UserProfile.fromMap(doc.data()!);
        state = state.copyWith(profile: profile, isLoading: false);
      }
    } catch (e) {
      logger.e('Failed to fetch user profile: $e');
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(error: e.message ?? 'Authentication failed', isLoading: false);
      rethrow;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, String username) async {
    state = state.copyWith(isLoading: true, error: null);
    final normalizedUsername = username.trim();
    
    if (normalizedUsername.isEmpty || normalizedUsername.length < 3) {
      state = state.copyWith(error: 'Username must be at least 3 characters', isLoading: false);
      throw 'Username must be at least 3 characters';
    }

    try {
      // Check username uniqueness
      final uniqueQuery = await firestore
          .collection('user_profiles')
          .where('username', isEqualTo: normalizedUsername)
          .limit(1)
          .get();

      if (uniqueQuery.docs.isNotEmpty) {
        state = state.copyWith(error: 'Username is already taken', isLoading: false);
        throw 'Username is already taken';
      }

      // Create Firebase Auth user
      final credential = await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) throw 'Failed to create user account';

      // Update auth display name
      await user.updateDisplayName(normalizedUsername);

      // Create User Profile in Firestore
      final newProfile = UserProfile(
        id: user.uid,
        username: normalizedUsername,
        email: email,
        emailVerified: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await firestore.collection('user_profiles').doc(user.uid).set(newProfile.toMap());
      state = state.copyWith(user: user, profile: newProfile, isLoading: false);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(error: e.message ?? 'Registration failed', isLoading: false);
      rethrow;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await firebaseAuth.signOut();
      // Always sign back in anonymously to keep database security rules happy
      await firebaseAuth.signInAnonymously();
    } catch (e) {
      logger.e('Failed to sign out: $e');
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Add reputation points to signed-in user profile
  Future<void> addReputationPoints(int pointsToAdd, String actionType) async {
    final currentUser = state.user;
    final currentProfile = state.profile;
    if (currentUser == null || currentUser.isAnonymous || currentProfile == null) {
      return;
    }

    final userRef = firestore.collection('user_profiles').doc(currentUser.uid);

    try {
      await firestore.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(userRef);
        if (!docSnapshot.exists) return;

        final currentData = docSnapshot.data()!;
        final oldPoints = currentData['reputation_points'] as int? ?? 0;
        final newPoints = oldPoints + pointsToAdd;

        final newLevelInfo = ReputationLevelInfo.fromPoints(newPoints);

        final updates = <String, dynamic>{
          'reputation_points': newPoints,
          'reputation_level': newLevelInfo.level,
          'vote_weight': newLevelInfo.voteWeight,
          'updated_at': FieldValue.serverTimestamp(),
          if (actionType == 'post') 'post_count': FieldValue.increment(1),
          if (actionType == 'comment') 'comment_count': FieldValue.increment(1),
          if (actionType == 'vote') 'vote_count': FieldValue.increment(1),
        };

        transaction.update(userRef, updates);
      });

      // Fetch the updated profile immediately to update state
      final updatedDoc = await userRef.get();
      if (updatedDoc.exists && ref.mounted) {
        final updatedProfile = UserProfile.fromMap(updatedDoc.data()!);
        state = state.copyWith(profile: updatedProfile);
      }
    } catch (e) {
      logger.e('Failed to update reputation points: $e');
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Simple selector for whether the current user is signed in with a real account
final isSignedInProvider = Provider<bool>((ref) {
  final auth = ref.watch(authProvider);
  return auth.user != null && !auth.user!.isAnonymous;
});
