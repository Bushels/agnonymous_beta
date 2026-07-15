import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/globals.dart';
import '../../../core/models/models.dart';
import '../community_categories.dart';
import 'auth_provider.dart';
import 'watch_provider.dart';

// --- PAGINATION STATE ---
// Category-specific Paginated State Class (immutable for efficient rebuilds)
class CategoryPostsState {
  final List<Post> posts;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;
  final DocumentSnapshot? lastDocument;

  const CategoryPostsState({
    this.posts = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
    this.lastDocument,
  });

  CategoryPostsState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
    DocumentSnapshot? lastDocument,
  }) {
    return CategoryPostsState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error ?? this.error,
      lastDocument: lastDocument ?? this.lastDocument,
    );
  }
}

class PaginatedPostsState {
  final Map<String, CategoryPostsState> categoryStates;
  final String searchQuery;
  final String feedSortMode; // 'latest' or 'active'
  final String cuntSortMode; // 'latest' or 'highestLoss'
  final String? error;

  const PaginatedPostsState({
    this.categoryStates = const {},
    this.searchQuery = '',
    this.feedSortMode = 'latest',
    this.cuntSortMode = 'latest',
    this.error,
  });

  PaginatedPostsState copyWith({
    Map<String, CategoryPostsState>? categoryStates,
    String? searchQuery,
    String? feedSortMode,
    String? cuntSortMode,
    String? error,
  }) {
    return PaginatedPostsState(
      categoryStates: categoryStates ?? this.categoryStates,
      searchQuery: searchQuery ?? this.searchQuery,
      feedSortMode: feedSortMode ?? this.feedSortMode,
      cuntSortMode: cuntSortMode ?? this.cuntSortMode,
      error: error ?? this.error,
    );
  }

  CategoryPostsState getCategoryState(String category) {
    return categoryStates[category] ?? const CategoryPostsState();
  }
}

// Notifier for Category-specific Pagination Logic
class PaginatedPostsNotifier extends Notifier<PaginatedPostsState> {
  final int _pageSize = 50; // 50 posts per category for better coverage
  StreamSubscription? _postsSubscription;
  bool _hasRegistryAccess = false;

  @override
  PaginatedPostsState build() {
    final searchQuery = ref.watch(searchQueryProvider);
    final feedSort = ref.watch(feedSortModeProvider);
    final cuntSort = ref.watch(cuntSortProvider);
    _hasRegistryAccess = ref.watch(hasRegistryAccessProvider);

    _initRealTime();

    // Defer loading to next microtask so state is initialized first
    Future.microtask(() => loadPostsForCategory('all', isInitial: true));

    // Listen to watches updates to keep the "watched" feed list reactive
    ref.listen(watchedThreadsProvider, (previous, next) {
      final watchedState = state.categoryStates['watched'];
      if (watchedState != null) {
        final watchedIds = next.threads.keys.toSet();
        final updatedPosts =
            watchedState.posts.where((p) => watchedIds.contains(p.id)).toList();

        final updatedCategoryStates =
            Map<String, CategoryPostsState>.from(state.categoryStates);
        updatedCategoryStates['watched'] = watchedState.copyWith(
          posts: updatedPosts,
        );
        state = state.copyWith(categoryStates: updatedCategoryStates);
      }
    });

    // Clean up realtime subscription when disposed
    ref.onDispose(() {
      _postsSubscription?.cancel();
    });

    return PaginatedPostsState(
      searchQuery: searchQuery,
      feedSortMode: feedSort == FeedSortMode.active ? 'active' : 'latest',
      cuntSortMode:
          cuntSort == CuntSortMode.highestLoss ? 'highestLoss' : 'latest',
    );
  }

  void setSearchQuery(String category, String query) {
    ref.read(searchQueryProvider.notifier).set(query);
  }

  void setFeedSortMode(String category, String sortMode) {
    ref.read(feedSortModeProvider.notifier).set(
          sortMode == 'active' ? FeedSortMode.active : FeedSortMode.recent,
        );
  }

  void setCuntSortMode(String category, String sortMode) {
    ref.read(cuntSortProvider.notifier).set(
          sortMode == 'highestLoss'
              ? CuntSortMode.highestLoss
              : CuntSortMode.latest,
        );
  }

  Future<void> loadPostsForCategory(String category,
      {bool isInitial = false, bool isRefresh = false}) async {
    final categoryState = state.getCategoryState(category);

    if (isRegistryCategory(category) && !_hasRegistryAccess) {
      final updatedCategoryStates =
          Map<String, CategoryPostsState>.from(state.categoryStates);
      updatedCategoryStates[category] = const CategoryPostsState(
        posts: [],
        isLoading: false,
        hasMore: false,
        currentPage: 0,
      );
      state = state.copyWith(categoryStates: updatedCategoryStates);
      return;
    }

    if (categoryState.isLoading || (!categoryState.hasMore && !isRefresh)) {
      return;
    }

    final pageToLoad = isRefresh || isInitial ? 0 : categoryState.currentPage;

    // Update this category's loading state
    final updatedCategoryStates =
        Map<String, CategoryPostsState>.from(state.categoryStates);
    updatedCategoryStates[category] =
        categoryState.copyWith(isLoading: true, error: null);
    state = state.copyWith(categoryStates: updatedCategoryStates);

    try {
      logger.d('Fetching posts for category: $category, page: $pageToLoad');

      Query query = firestore
          .collection('posts')
          .where('is_deleted', isEqualTo: false)
          .where('pending_review', isEqualTo: false);

      // Apply category filter for specific categories, skip for "all"
      if (category == 'watched') {
        final watchedIds = ref
            .read(watchedThreadsProvider)
            .threads
            .values
            .where((thread) =>
                _hasRegistryAccess || !isRegistryCategory(thread.category))
            .map((thread) => thread.postId)
            .toList();
        if (watchedIds.isEmpty) {
          final updatedCategoryStates =
              Map<String, CategoryPostsState>.from(state.categoryStates);
          updatedCategoryStates[category] = CategoryPostsState(
            posts: const [],
            isLoading: false,
            hasMore: false,
            currentPage: 0,
            lastDocument: null,
          );
          state = state.copyWith(categoryStates: updatedCategoryStates);
          return;
        }
        final limitedIds = watchedIds.take(30).toList();
        query = query.where(FieldPath.documentId, whereIn: limitedIds);
      } else {
        if (category == 'all' && !_hasRegistryAccess) {
          query = query.where(
            'category',
            whereIn: publicBoardCategoryNames,
          );
        } else if (category != 'all') {
          query = query.where('category', isEqualTo: category);
        }
      }

      // Apply search query filter if not empty
      if (state.searchQuery.isNotEmpty) {
        final cleanQuery = state.searchQuery.trim().toLowerCase();
        final words = cleanQuery.split(RegExp(r'\s+'));
        if (words.isNotEmpty && words.first.length >= 2) {
          query = query.where('search_keywords', arrayContains: words.first);
        }
      }

      // Apply ordering/sorting
      if (category == 'C.U.N.T.' || category == 'Scams') {
        if (state.cuntSortMode == 'highestLoss') {
          query = query
              .orderBy('loss_amount', descending: true)
              .orderBy('created_at', descending: true);
        } else {
          query = query.orderBy('created_at', descending: true);
        }
      } else {
        if (state.feedSortMode == 'active') {
          query = query
              .orderBy('comment_count', descending: true)
              .orderBy('created_at', descending: true);
        } else {
          query = query.orderBy('created_at', descending: true);
        }
      }

      if (!isRefresh &&
          !isInitial &&
          categoryState.lastDocument != null &&
          category != 'watched') {
        query = query.startAfterDocument(categoryState.lastDocument!);
      }

      final querySnapshot = await query.limit(_pageSize).get();
      final docs = querySnapshot.docs;

      final newPosts = docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        if (data['created_at'] is Timestamp) {
          data['created_at'] =
              (data['created_at'] as Timestamp).toDate().toIso8601String();
        }
        if (data['edited_at'] is Timestamp) {
          data['edited_at'] =
              (data['edited_at'] as Timestamp).toDate().toIso8601String();
        }
        if (data['deleted_at'] is Timestamp) {
          data['deleted_at'] =
              (data['deleted_at'] as Timestamp).toDate().toIso8601String();
        }
        if (data['verified_at'] is Timestamp) {
          data['verified_at'] =
              (data['verified_at'] as Timestamp).toDate().toIso8601String();
        }
        return Post.fromMap(data);
      }).toList();

      if (category == 'watched') {
        newPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      logger.d(
          'Category: $category, Page $pageToLoad: Loaded ${newPosts.length} posts');

      final List<Post> updatedPosts;
      if (isRefresh) {
        // On refresh, merge new posts with old, prioritizing new ones to show updates.
        final newPostsMap = {for (var p in newPosts) p.id: p};
        final oldPostsFiltered =
            categoryState.posts.where((p) => !newPostsMap.containsKey(p.id));
        updatedPosts = [...newPosts, ...oldPostsFiltered];
        updatedPosts.sort((a, b) =>
            b.createdAt.compareTo(a.createdAt)); // Ensure order is correct
      } else {
        // For initial load or load more, just add new posts that aren't already there.
        final existingIds = categoryState.posts.map((p) => p.id).toSet();
        final filteredNewPosts =
            newPosts.where((p) => !existingIds.contains(p.id)).toList();
        updatedPosts = isInitial
            ? filteredNewPosts
            : [...categoryState.posts, ...filteredNewPosts];
      }

      final newCategoryState = categoryState.copyWith(
        posts: updatedPosts,
        isLoading: false,
        hasMore: category == 'watched' ? false : newPosts.length == _pageSize,
        currentPage: pageToLoad + 1,
        lastDocument: docs.isNotEmpty ? docs.last : null,
      );

      final finalCategoryStates =
          Map<String, CategoryPostsState>.from(state.categoryStates);
      finalCategoryStates[category] = newCategoryState;
      state = state.copyWith(categoryStates: finalCategoryStates);

      logger.d(
          'Updated state: ${newCategoryState.posts.length} posts, hasMore: ${newCategoryState.hasMore}');
    } catch (e, stackTrace) {
      logger.e('Error loading posts for category $category',
          error: e, stackTrace: stackTrace);
      final errorCategoryStates =
          Map<String, CategoryPostsState>.from(state.categoryStates);
      errorCategoryStates[category] =
          categoryState.copyWith(isLoading: false, error: e.toString());
      state = state.copyWith(categoryStates: errorCategoryStates);
    }
  }

  void loadMoreForCategory(String category) => loadPostsForCategory(category);
  Future<void> refreshCategory(String category) =>
      loadPostsForCategory(category, isRefresh: true);

  // Method to ensure category is loaded
  void ensureCategoryLoaded(String category) {
    logger.d('Ensuring category loaded: $category');

    if (!state.categoryStates.containsKey(category)) {
      logger.d('Loading initial posts for category: $category');
      loadPostsForCategory(category, isInitial: true);
    } else {
      final categoryState = state.getCategoryState(category);

      // If we have no posts and not loading, try to reload
      if (categoryState.posts.isEmpty &&
          !categoryState.isLoading &&
          categoryState.error == null) {
        logger.d('Category is empty and not loading, reloading: $category');
        loadPostsForCategory(category, isInitial: true);
      }
    }
  }

  void _initRealTime() {
    _postsSubscription?.cancel();
    Query<Map<String, dynamic>> query = firestore
        .collection('posts')
        .where('is_deleted', isEqualTo: false)
        .where('pending_review', isEqualTo: false);

    if (!_hasRegistryAccess) {
      query = query.where(
        'category',
        whereIn: publicBoardCategoryNames,
      );
    }

    _postsSubscription = query
        .orderBy('created_at', descending: true)
        .limit(_pageSize)
        .snapshots()
        .listen((snapshot) {
      logger.d('Real-time post update received from Firestore');

      final newPosts = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        if (data['created_at'] is Timestamp) {
          data['created_at'] =
              (data['created_at'] as Timestamp).toDate().toIso8601String();
        }
        if (data['edited_at'] is Timestamp) {
          data['edited_at'] =
              (data['edited_at'] as Timestamp).toDate().toIso8601String();
        }
        if (data['deleted_at'] is Timestamp) {
          data['deleted_at'] =
              (data['deleted_at'] as Timestamp).toDate().toIso8601String();
        }
        if (data['verified_at'] is Timestamp) {
          data['verified_at'] =
              (data['verified_at'] as Timestamp).toDate().toIso8601String();
        }
        return Post.fromMap(data);
      }).toList();

      final updatedCategoryStates =
          Map<String, CategoryPostsState>.from(state.categoryStates);

      // Update "all" category
      final allState = state.getCategoryState('all');
      var allNewPosts = newPosts;
      if (state.searchQuery.isNotEmpty) {
        final cleanQuery = state.searchQuery.trim().toLowerCase();
        final words = cleanQuery.split(RegExp(r'\s+'));
        if (words.isNotEmpty && words.first.length >= 2) {
          final firstWord = words.first;
          allNewPosts = allNewPosts
              .where((p) => p.searchKeywords?.contains(firstWord) ?? false)
              .toList();
        }
      }
      updatedCategoryStates['all'] = allState.copyWith(
        posts: allNewPosts,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );

      // Update other loaded categories
      for (final entry in updatedCategoryStates.entries) {
        final cat = entry.key;
        if (cat == 'all') continue;

        final catState = entry.value;
        var filteredNewPosts =
            newPosts.where((p) => p.category == cat).toList();

        // If a search query is active, only merge posts that match the search keywords
        if (state.searchQuery.isNotEmpty) {
          final cleanQuery = state.searchQuery.trim().toLowerCase();
          final words = cleanQuery.split(RegExp(r'\s+'));
          if (words.isNotEmpty && words.first.length >= 2) {
            final firstWord = words.first;
            filteredNewPosts = filteredNewPosts
                .where((p) => p.searchKeywords?.contains(firstWord) ?? false)
                .toList();
          }
        }

        if (cat == 'watched') {
          final watchedIds =
              ref.read(watchedThreadsProvider).threads.keys.toSet();
          filteredNewPosts =
              newPosts.where((p) => watchedIds.contains(p.id)).toList();
        }

        // Merge into category
        final mergedPostsMap = {for (var p in filteredNewPosts) p.id: p};
        final remainingPosts =
            catState.posts.where((p) => !mergedPostsMap.containsKey(p.id));
        final updatedCatPosts = [...filteredNewPosts, ...remainingPosts];
        updatedCatPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        updatedCategoryStates[cat] = catState.copyWith(
          posts: updatedCatPosts,
        );
      }

      state = state.copyWith(categoryStates: updatedCategoryStates);
    }, onError: (e) {
      logger.e('Error in real-time posts subscription: $e');
    });
  }
}

// --- RIVERPOD PROVIDERS ---
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) {
    state = query;
  }
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

// Provider Declaration
final paginatedPostsProvider =
    NotifierProvider<PaginatedPostsNotifier, PaginatedPostsState>(
  PaginatedPostsNotifier.new,
);

/// Sort mode for the post feed
enum FeedSortMode { recent, active }

/// Provider for current feed sort mode
final feedSortModeProvider =
    NotifierProvider<FeedSortModeNotifier, FeedSortMode>(
        FeedSortModeNotifier.new);

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

final commentsProvider =
    StreamProvider.family<List<Comment>, String>((ref, postId) {
  final stream = firestore
      .collection('comments')
      .where('post_id', isEqualTo: postId)
      .where('is_deleted', isEqualTo: false)
      .orderBy('created_at', descending: false)
      .snapshots();

  return stream.map((snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      if (data['created_at'] is Timestamp) {
        data['created_at'] =
            (data['created_at'] as Timestamp).toDate().toIso8601String();
      }
      if (data['deleted_at'] is Timestamp) {
        data['deleted_at'] =
            (data['deleted_at'] as Timestamp).toDate().toIso8601String();
      }
      if (data['edited_at'] is Timestamp) {
        data['edited_at'] =
            (data['edited_at'] as Timestamp).toDate().toIso8601String();
      }
      return Comment.fromMap(data);
    }).toList();
  });
});

final voteStatsProvider =
    StreamProvider.family<VoteStats, String>((ref, postId) {
  final stream = firestore.collection('posts').doc(postId).snapshots();
  return stream.map((snapshot) {
    if (!snapshot.exists) {
      return VoteStats(
        thumbsUpVotes: 0,
        partialVotes: 0,
        thumbsDownVotes: 0,
        funnyVotes: 0,
      );
    }
    final data = snapshot.data() as Map<String, dynamic>;
    return VoteStats(
      thumbsUpVotes: data['thumbs_up_count'] ?? 0,
      partialVotes: data['partial_count'] ?? 0,
      thumbsDownVotes: data['thumbs_down_count'] ?? 0,
      funnyVotes: data['funny_count'] ?? 0,
    );
  });
});

final globalStatsProvider = StreamProvider<GlobalStats>((ref) {
  final stream = firestore.collection('stats').doc('global').snapshots();
  return stream.map((snapshot) {
    if (!snapshot.exists) {
      return GlobalStats(totalPosts: 0, totalVotes: 0, totalComments: 0);
    }
    final data = snapshot.data() as Map<String, dynamic>;
    return GlobalStats(
      totalPosts: data['total_posts'] ?? 0,
      totalVotes: data['total_votes'] ?? 0,
      totalComments: data['total_comments'] ?? 0,
    );
  });
});

final trendingStatsProvider = FutureProvider<TrendingStats>((ref) async {
  // Watch posts to recalculate when posts are updated
  final paginatedState = ref.watch(paginatedPostsProvider);
  final posts = paginatedState.getCategoryState('all').posts;

  if (posts.isEmpty) {
    return TrendingStats(
      trendingCategory: 'General',
      mostPopularPostTitle: 'No posts yet',
    );
  }

  // Calculate trending category
  final categoryCounts = <String, int>{};
  for (final post in posts) {
    categoryCounts[post.category] = (categoryCounts[post.category] ?? 0) + 1;
  }

  var trendingCategory = 'General';
  var maxCategoryCount = 0;
  categoryCounts.forEach((category, occurrences) {
    if (occurrences > maxCategoryCount) {
      maxCategoryCount = occurrences;
      trendingCategory = category;
    }
  });

  // Calculate most popular post (highest comments + votes)
  Post? mostPopularPost;
  var maxScore = -1;
  for (final post in posts) {
    final score = post.commentCount + post.voteCount;
    if (score > maxScore) {
      maxScore = score;
      mostPopularPost = post;
    }
  }

  return TrendingStats(
    trendingCategory: trendingCategory,
    mostPopularPostTitle: mostPopularPost?.title ?? 'No posts yet',
  );
});

final pendingRegistryReportCountProvider = StreamProvider<int>((ref) {
  final isAdmin = ref.watch(isAdminProvider).value ?? false;
  if (!isAdmin) return Stream.value(0);

  return firestore
      .collection('posts')
      .where('category', whereIn: registryCategoryNames)
      .where('is_deleted', isEqualTo: false)
      .where('pending_review', isEqualTo: true)
      .snapshots()
      .map((snapshot) => snapshot.size);
});

enum CuntSortMode { latest, highestLoss }

class CuntSortNotifier extends Notifier<CuntSortMode> {
  @override
  CuntSortMode build() => CuntSortMode.latest;

  void set(CuntSortMode mode) {
    state = mode;
  }
}

final cuntSortProvider =
    NotifierProvider<CuntSortNotifier, CuntSortMode>(CuntSortNotifier.new);

class HiddenPostsNotifier extends Notifier<Set<String>> {
  static const _storageKey = 'hidden_posts_list_v1';

  @override
  Set<String> build() {
    Future.microtask(_load);
    return const {};
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKey) ?? [];
      state = list.toSet();
    } catch (e) {
      logger.e('Failed to load hidden posts: $e');
    }
  }

  Future<void> hidePost(String postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKey) ?? [];
      if (!list.contains(postId)) {
        list.add(postId);
        await prefs.setStringList(_storageKey, list);
        state = list.toSet();
      }
    } catch (e) {
      logger.e('Failed to hide post: $e');
    }
  }
}

final hiddenPostsProvider =
    NotifierProvider<HiddenPostsNotifier, Set<String>>(HiddenPostsNotifier.new);
