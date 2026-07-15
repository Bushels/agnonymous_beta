import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/globals.dart';
import '../../../models/user_profile.dart';
import '../../../services/anonymous_id_service.dart';

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
  StreamSubscription<DocumentSnapshot>? _profileSubscription;

  @override
  AuthState build() {
    _authSubscription =
        firebaseAuth.authStateChanges().listen((User? firebaseUser) {
      // Clear cached anonymous device ID on any authentication state change
      try {
        AnonymousIdService.clearCache();
      } catch (e) {
        logger.e('Failed to clear anonymous cache on auth change: $e');
      }

      _profileSubscription?.cancel();
      _profileSubscription = null;

      if (firebaseUser != null) {
        if (firebaseUser.isAnonymous) {
          state =
              AuthState(user: firebaseUser, profile: null, isLoading: false);
        } else {
          _listenToProfile(firebaseUser);
        }
      } else {
        state = const AuthState(user: null, profile: null, isLoading: false);
      }
    });

    ref.onDispose(() {
      _authSubscription?.cancel();
      _profileSubscription?.cancel();
    });

    return const AuthState(isLoading: true);
  }

  void _listenToProfile(User firebaseUser) {
    _profileSubscription?.cancel();
    state = state.copyWith(isLoading: true, user: firebaseUser);

    _profileSubscription = firestore
        .collection('user_profiles')
        .doc(firebaseUser.uid)
        .snapshots()
        .listen((publicDoc) async {
      if (!publicDoc.exists) {
        // Initialize public and private profile documents if they don't exist yet
        try {
          final newProfile = UserProfile(
            id: firebaseUser.uid,
            username: firebaseUser.displayName ??
                'Farmer_${firebaseUser.uid.substring(0, 5)}',
            email: firebaseUser.email,
            emailVerified: firebaseUser.emailVerified,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final batch = firestore.batch();
          batch.set(firestore.collection('user_profiles').doc(firebaseUser.uid),
              newProfile.toPublicMap());
          batch.set(
              firestore
                  .collection('user_profiles')
                  .doc(firebaseUser.uid)
                  .collection('private')
                  .doc('info'),
              newProfile.toPrivateMap());
          batch.set(
              firestore
                  .collection('usernames')
                  .doc(newProfile.username.toLowerCase()),
              {'uid': firebaseUser.uid});
          await batch.commit();
        } catch (e) {
          logger.e('Failed to initialize user profile documents: $e');
        }
        return;
      }

      try {
        final publicData = publicDoc.data()!;

        // Self-healing migration for legacy email fields in public profile document
        if (publicData.containsKey('email') ||
            publicData.containsKey('email_verified')) {
          final email = publicData['email'];
          final emailVerified = publicData['email_verified'] ?? false;

          final privateDocRef = firestore
              .collection('user_profiles')
              .doc(firebaseUser.uid)
              .collection('private')
              .doc('info');

          final batch = firestore.batch();
          batch.set(
              privateDocRef,
              {
                'email': email,
                'email_verified': emailVerified,
              },
              SetOptions(merge: true));

          batch.update(
              firestore.collection('user_profiles').doc(firebaseUser.uid), {
            'email': FieldValue.delete(),
            'email_verified': FieldValue.delete(),
          });

          await batch.commit();
          return; // The snapshot listener will trigger again with the clean public document
        }

        final privateDoc = await firestore
            .collection('user_profiles')
            .doc(firebaseUser.uid)
            .collection('private')
            .doc('info')
            .get();

        final privateData = privateDoc.exists ? privateDoc.data() : null;
        final combinedData = Map<String, dynamic>.from(publicData);
        if (privateData != null) {
          combinedData['email'] = privateData['email'];
          combinedData['email_verified'] = privateData['email_verified'];
        } else {
          combinedData['email_verified'] = false;
        }

        final profile = UserProfile.fromMap(combinedData);
        state = state.copyWith(profile: profile, isLoading: false);
      } catch (e) {
        logger.e('Error parsing combined user profile: $e');
        state = state.copyWith(error: e.toString(), isLoading: false);
      }
    }, onError: (e) {
      logger.e('Profile subscription error: $e');
      state = state.copyWith(error: e.toString(), isLoading: false);
    });
  }

  Future<void> syncEmailVerification() async {
    final currentUser = firebaseAuth.currentUser;
    if (currentUser != null && !currentUser.isAnonymous) {
      await currentUser.reload();
      final latestUser = firebaseAuth.currentUser;
      if (latestUser != null) {
        // Firestore rules read email_verified from the ID token, not only from
        // the refreshed FirebaseUser object.
        await latestUser.getIdToken(true);
        final privateRef = firestore
            .collection('user_profiles')
            .doc(latestUser.uid)
            .collection('private')
            .doc('info');

        await privateRef.set({
          'email': latestUser.email,
          'email_verified': latestUser.emailVerified,
        }, SetOptions(merge: true));

        if (state.profile != null) {
          state = state.copyWith(
            profile: state.profile!.copyWith(
              emailVerified: latestUser.emailVerified,
            ),
          );
        }
      }
    }
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await firebaseAuth.signInWithEmailAndPassword(
          email: email, password: password);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
          error: e.message ?? 'Authentication failed', isLoading: false);
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
      state = state.copyWith(
          error: 'Username must be at least 3 characters', isLoading: false);
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
        state = state.copyWith(
            error: 'Username is already taken', isLoading: false);
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

      // Send Firebase Auth email verification
      await user.sendEmailVerification();

      // Create User Profile in Firestore (Split into Public and Private docs)
      final newProfile = UserProfile(
        id: user.uid,
        username: normalizedUsername,
        email: email,
        emailVerified: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final batch = firestore.batch();
      batch.set(firestore.collection('user_profiles').doc(user.uid),
          newProfile.toPublicMap());
      batch.set(
          firestore
              .collection('user_profiles')
              .doc(user.uid)
              .collection('private')
              .doc('info'),
          newProfile.toPrivateMap());
      batch.set(
          firestore
              .collection('usernames')
              .doc(newProfile.username.toLowerCase()),
          {'uid': user.uid});
      await batch.commit();

      state = state.copyWith(user: user, profile: newProfile, isLoading: false);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
          error: e.message ?? 'Registration failed', isLoading: false);
      rethrow;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    _profileSubscription?.cancel();
    _profileSubscription = null;
    try {
      await firebaseAuth.signOut();
      // Always sign back in anonymously to keep database security rules happy
      await firebaseAuth.signInAnonymously();
    } catch (e) {
      logger.e('Failed to sign out: $e');
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Add reputation points to signed-in user profile (no-op: handled securely by Cloud Functions)
  Future<void> addReputationPoints(int pointsToAdd, String actionType) async {
    // If we need to sync verification status
    if (actionType == 'sync_verification') {
      await syncEmailVerification();
    }
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Simple selector for whether the current user is signed in with a real account
final isSignedInProvider = Provider<bool>((ref) {
  final auth = ref.watch(authProvider);
  return auth.user != null && !auth.user!.isAnonymous;
});

/// Stream provider checking if the current user has an admin role document in Firestore
final isAdminProvider = StreamProvider<bool>((ref) {
  final auth = ref.watch(authProvider);
  final user = auth.user;
  if (user == null || user.isAnonymous) {
    return Stream.value(false);
  }
  return firestore
      .collection('admin_roles')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.exists);
});

/// Registry access requires a verified email account or an explicit admin role.
final hasRegistryAccessProvider = Provider<bool>((ref) {
  final auth = ref.watch(authProvider);
  final user = auth.user;
  final isVerifiedAccount = user != null &&
      !user.isAnonymous &&
      (user.emailVerified || auth.profile?.emailVerified == true);
  final isAdmin = ref.watch(isAdminProvider).value ?? false;
  return isVerifiedAccount || isAdmin;
});
