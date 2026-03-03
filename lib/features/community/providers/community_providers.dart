import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/globals.dart';
import '../../../core/models/models.dart';

// --- PAGINATION STATE ---
// Category-specific Paginated State Class (immutable for efficient rebuilds)
class CategoryPostsState {
  final List<Post> posts;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;

  const CategoryPostsState({
    this.posts = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
  });

  CategoryPostsState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
  }) {
    return CategoryPostsState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error ?? this.error,
    );
  }
}

class PaginatedPostsState {
  final Map<String, CategoryPostsState> categoryStates;
  final String? error;

  const PaginatedPostsState({
    this.categoryStates = const {},
    this.error,
  });

  PaginatedPostsState copyWith({
    Map<String, CategoryPostsState>? categoryStates,
    String? error,
  }) {
    return PaginatedPostsState(
      categoryStates: categoryStates ?? this.categoryStates,
      error: error ?? this.error,
    );
  }

  CategoryPostsState getCategoryState(String category) {
    return categoryStates[category] ?? const CategoryPostsState();
  }
}

// Notifier for Category-specific Pagination Logic
class PaginatedPostsNotifier extends Notifier<PaginatedPostsState> {
  final int _pageSize = 50;  // 50 posts per category for better coverage
  RealtimeChannel? _postsChannel;

  @override
  PaginatedPostsState build() {
    _initRealTime();

    // Defer loading to next microtask so state is initialized first
    // This prevents the circular dependency error where loadPostsForCategory
    // tries to access state before build() returns the initial state
    Future.microtask(() => loadPostsForCategory('all', isInitial: true));

    // Clean up realtime subscription when disposed
    ref.onDispose(() {
      _postsChannel?.unsubscribe();
    });

    return const PaginatedPostsState();
  }

  Future<void> loadPostsForCategory(String category, {bool isInitial = false, bool isRefresh = false}) async {
    final categoryState = state.getCategoryState(category);

    if (categoryState.isLoading || (!categoryState.hasMore && !isRefresh)) return;

    final pageToLoad = isRefresh || isInitial ? 0 : categoryState.currentPage;

    // Update this category's loading state
    final updatedCategoryStates = Map<String, CategoryPostsState>.from(state.categoryStates);
    updatedCategoryStates[category] = categoryState.copyWith(isLoading: true, error: null);
    state = state.copyWith(categoryStates: updatedCategoryStates);

    try {
      logger.d('Fetching posts for category: $category, page: $pageToLoad');

      var query = supabase
          .from('posts')
          .select('*')
          .neq('is_deleted', true); // Filter out deleted posts (handles null as non-deleted)

      // Apply category filter for specific categories, skip for "all"
      if (category != 'all') {
        query = query.eq('category', category);
      }

      final data = await query
          .order('created_at', ascending: false)
          .range(pageToLoad * _pageSize, (pageToLoad + 1) * _pageSize - 1);

      final newPosts = (data as List)
          .map((map) => Post.fromMap(map))
          .where((post) => !post.isDeleted) // Double-check filter in Dart
          .toList();

      logger.d('Category: $category, Page $pageToLoad: Loaded ${newPosts.length} posts');

      final List<Post> updatedPosts;
      if (isRefresh) {
        // On refresh, merge new posts with old, prioritizing new ones to show updates.
        final newPostsMap = {for (var p in newPosts) p.id: p};
        final oldPostsFiltered = categoryState.posts.where((p) => !newPostsMap.containsKey(p.id));
        updatedPosts = [...newPosts, ...oldPostsFiltered];
        updatedPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Ensure order is correct
      } else {
        // For initial load or load more, just add new posts that aren't already there.
        final existingIds = categoryState.posts.map((p) => p.id).toSet();
        final filteredNewPosts = newPosts.where((p) => !existingIds.contains(p.id)).toList();
        updatedPosts = isInitial
            ? filteredNewPosts
            : [...categoryState.posts, ...filteredNewPosts];
      }

      final newCategoryState = categoryState.copyWith(
        posts: updatedPosts,
        isLoading: false,
        hasMore: newPosts.length == _pageSize,
        currentPage: pageToLoad + 1,
      );

      final finalCategoryStates = Map<String, CategoryPostsState>.from(state.categoryStates);
      finalCategoryStates[category] = newCategoryState;
      state = state.copyWith(categoryStates: finalCategoryStates);

      logger.d('Updated state: ${newCategoryState.posts.length} posts, hasMore: ${newCategoryState.hasMore}');
    } catch (e, stackTrace) {
      logger.e('Error loading posts for category $category', error: e, stackTrace: stackTrace);
      final errorCategoryStates = Map<String, CategoryPostsState>.from(state.categoryStates);
      errorCategoryStates[category] = categoryState.copyWith(isLoading: false, error: e.toString());
      state = state.copyWith(categoryStates: errorCategoryStates);
    }
  }

  void loadMoreForCategory(String category) => loadPostsForCategory(category);
  Future<void> refreshCategory(String category) => loadPostsForCategory(category, isRefresh: true);

  // Method to ensure category is loaded
  void ensureCategoryLoaded(String category) {
    logger.d('Ensuring category loaded: $category');

    if (!state.categoryStates.containsKey(category)) {
      logger.d('Loading initial posts for category: $category');
      loadPostsForCategory(category, isInitial: true);
    } else {
      final categoryState = state.getCategoryState(category);

      // If we have no posts and not loading, try to reload
      if (categoryState.posts.isEmpty && !categoryState.isLoading && categoryState.error == null) {
        logger.d('Category is empty and not loading, reloading: $category');
        loadPostsForCategory(category, isInitial: true);
      }
    }
  }

  void _initRealTime() {
    // Subscribe to new posts being inserted
    _postsChannel = supabase
        .channel('new_posts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            logger.d('New post inserted, refreshing categories');
            // Refresh all loaded categories for new posts
            for (final category in state.categoryStates.keys) {
              refreshCategory(category);
            }
          },
        )
        // Subscribe to updates on posts (e.g., comment_count or vote_count changes)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            logger.d('Real-time post update received');
            final newMap = payload.newRecord;
            final updatedPost = Post.fromMap(newMap);
            logger.d('Updating post ${updatedPost.id}');

            // Update the post in all loaded category states where it exists
            final updatedCategoryStates = Map<String, CategoryPostsState>.from(state.categoryStates);
            for (final entry in updatedCategoryStates.entries) {
              final cat = entry.key;
              final catState = entry.value;
              final postIndex = catState.posts.indexWhere((p) => p.id == updatedPost.id);
              if (postIndex != -1) {
                final updatedPosts = List<Post>.from(catState.posts);
                updatedPosts[postIndex] = updatedPost;  // Replace with updated post
                updatedCategoryStates[cat] = catState.copyWith(posts: updatedPosts);
                logger.d('Updated post in category "$cat"');
              }
            }
            state = state.copyWith(categoryStates: updatedCategoryStates);
                    },
        )
        .subscribe();
  }

}

// --- RIVERPOD PROVIDERS ---
// Provider Declaration
final paginatedPostsProvider = NotifierProvider<PaginatedPostsNotifier, PaginatedPostsState>(
  PaginatedPostsNotifier.new,
);

/// Sort mode for the post feed
enum FeedSortMode { recent, topFunny }

/// Provider for current feed sort mode
final feedSortModeProvider = NotifierProvider<FeedSortModeNotifier, FeedSortMode>(FeedSortModeNotifier.new);

class FeedSortModeNotifier extends Notifier<FeedSortMode> {
  @override
  FeedSortMode build() => FeedSortMode.recent;

  void set(FeedSortMode mode) {
    state = mode;
  }
}

// Keep legacy provider for compatibility with other components that might still use it
final postsProvider = StreamProvider<List<Post>>((ref) {
  final paginatedState = ref.watch(paginatedPostsProvider);
  final allPosts = paginatedState.getCategoryState('all').posts;
  return Stream.value(allPosts);
});

final commentsProvider = StreamProvider.family<List<Comment>, String>((ref, postId) {
  final stream = supabase
      .from('comments')
      .stream(primaryKey: ['id'])
      .eq('post_id', postId)
      .order('created_at', ascending: true);

  return stream.map((listOfMaps) {
    return listOfMaps
        .map((map) => Comment.fromMap(map))
        .where((comment) => !comment.isDeleted) // Filter out deleted comments
        .toList();
  });
});

final voteStatsProvider = StreamProvider.family<VoteStats, String>((ref, postId) {
  final controller = StreamController<VoteStats>();

  Future<void> fetchStats() async {
    try {
      final response = await supabase.rpc('get_post_vote_stats', params: {'post_id_in': postId});
      Map<String, dynamic> dataMap = {};
      if (response is List && response.isNotEmpty) {
        dataMap = response[0] as Map<String, dynamic>;
      } else if (response is Map<String, dynamic>) {
        dataMap = response;
      }
      controller.add(VoteStats.fromMap(dataMap));
    } catch (e) {
      if (const bool.fromEnvironment('dart.vm.product') == false) {
        debugPrint('Error fetching vote stats: $e');
      }
      controller.add(VoteStats(thumbsUpVotes: 0, partialVotes: 0, thumbsDownVotes: 0, funnyVotes: 0));
    }
  }

  fetchStats();

  final channel = supabase
      .channel('public:truth_votes:$postId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'truth_votes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'post_id',
          value: postId,
        ),
        callback: (payload) {
          fetchStats();
        },
      )
      .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});

final globalStatsProvider = StreamProvider<GlobalStats>((ref) {
  final controller = StreamController<GlobalStats>();

  Future<void> fetchStats() async {
    try {
      final response = await supabase.rpc('get_global_stats');
      Map<String, dynamic> dataMap = {};
      if (response is List && response.isNotEmpty) {
        dataMap = response[0] as Map<String, dynamic>;
      } else if (response is Map<String, dynamic>) {
        dataMap = response;
      }
      final stats = GlobalStats.fromMap(dataMap);
      logger.d('Global Stats - Posts: ${stats.totalPosts}, Votes: ${stats.totalVotes}, Comments: ${stats.totalComments}');
      controller.add(stats);
    } catch (e) {
      logger.w('Error fetching global stats: $e');
      controller.add(GlobalStats(totalPosts: 0, totalVotes: 0, totalComments: 0));
    }
  }

  fetchStats();

  // Listen to all table changes
  final channel = supabase
      .channel('global_stats_changes')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'posts',
        callback: (payload) => fetchStats(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'truth_votes',
        callback: (payload) => fetchStats(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'comments',
        callback: (payload) => fetchStats(),
      )
      .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});

final trendingStatsProvider = FutureProvider<TrendingStats>((ref) async {
  // This will cause the provider to rebuild when posts change
  ref.watch(postsProvider);

  try {
    final response = await supabase.rpc('get_trending_stats');

    logger.d('Fetched trending stats');

    if (response == null) {
      return TrendingStats(
        trendingCategory: 'General',
        mostPopularPostTitle: 'No posts yet',
      );
    }

    // Handle the response properly
    Map<String, dynamic> data;
    if (response is List && response.isNotEmpty) {
      data = response[0] as Map<String, dynamic>;
    } else if (response is Map<String, dynamic>) {
      data = response;
    } else {
      return TrendingStats(
        trendingCategory: 'General',
        mostPopularPostTitle: 'No posts yet',
      );
    }

    return TrendingStats.fromMap(data);
  } catch (e) {
    logger.w('Error fetching trending stats: $e');
    return TrendingStats(
      trendingCategory: 'General',
      mostPopularPostTitle: 'No posts yet',
    );
  }
});
