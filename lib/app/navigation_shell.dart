import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_auth show AuthState;
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;
import '../core/utils/globals.dart';
import '../features/community/providers/community_providers.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/dashboard/home_dashboard_screen.dart';
import '../screens/market/markets_screen.dart';
import '../create_post_screen.dart';
import '../features/community/screens/community_feed_screen.dart';
import '../widgets/glass_bottom_nav.dart';

/// Wrapper widget that handles auth state changes for deep links
/// Detects password recovery and email verification events
class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  StreamSubscription<supabase_auth.AuthState>? _authSubscription;
  bool _hasHandledDeepLink = false;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _setupAuthListener() {
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      logger.d('Auth state change: $event');

      // Only handle each deep link once
      if (_hasHandledDeepLink) return;

      if (event == AuthChangeEvent.passwordRecovery) {
        _hasHandledDeepLink = true;
        logger.i('Password recovery event detected, navigating to reset screen');

        // Navigate to reset password screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
              (route) => false,
            );
          }
        });
      } else if (event == AuthChangeEvent.userUpdated) {
        // Check if email was just verified
        final user = data.session?.user;
        if (user != null && user.emailConfirmedAt != null) {
          logger.i('Email verification confirmed');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // === PRELOAD POSTS: Start loading posts as soon as possible ===
    // This triggers the provider initialization before MainNavigationShell renders
    ref.read(paginatedPostsProvider);

    // === SKIP FLUTTER LOADING SCREEN ===
    // The HTML loading indicator already provides visual feedback during load.
    // Go straight to the main app - auth resolves in background.
    return const MainNavigationShell();
  }
}

// --- MAIN NAVIGATION SHELL ---
class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    if (index == 2) {
      // Center "+" button opens create post screen as overlay
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreatePostScreen()),
      );
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: IndexedStack(
          key: ValueKey<int>(_currentIndex),
          index: _currentIndex,
          children: const [
            HomeDashboardScreen(),  // Data overview dashboard
            MarketsScreen(),        // Grains, fertilizer, crop stats
            SizedBox(),             // Placeholder for center button (never shown)
            HomeScreen(),           // Community feed
            ProfileScreen(),        // Profile & settings
          ],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: GlassBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavItem(icon: FontAwesomeIcons.chartLine, label: 'Dashboard'),
          BottomNavItem(icon: FontAwesomeIcons.wheatAwn, label: 'Markets'),
          BottomNavItem(icon: FontAwesomeIcons.plus, label: 'Post', isSpecial: true),
          BottomNavItem(icon: FontAwesomeIcons.comments, label: 'Community'),
          BottomNavItem(icon: FontAwesomeIcons.user, label: 'Profile'),
        ],
      ),
    );
  }
}
