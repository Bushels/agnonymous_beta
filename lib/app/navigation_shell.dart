import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/community/providers/community_providers.dart';
import '../features/community/screens/community_feed_screen.dart';

/// Thin wrapper kept so `runApp` has a single entry widget that can be swapped
/// without touching main.dart. V1 has no auth flow — this used to listen for
/// password-recovery deep links; removed in the April 2026 anonymous-board
/// relaunch. Preloading the post list here shaves time off first paint.
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(paginatedPostsProvider);
    return const MainNavigationShell();
  }
}

class MainNavigationShell extends ConsumerWidget {
  const MainNavigationShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const HomeScreen(initialCategory: 'Monette');
  }
}
