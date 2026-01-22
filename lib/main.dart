import 'dart:async';
import 'dart:ui';
import 'package:agnonymous_beta/create_post_screen.dart';
import 'package:agnonymous_beta/services/anonymous_id_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_auth show AuthState;
import 'package:logger/logger.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/leaderboard/leaderboard_screen.dart';
import 'providers/auth_provider.dart';
import 'models/user_profile.dart' show TruthMeterStatus;
import 'services/analytics_service.dart';
import 'services/rate_limiter.dart';
// VoteButtons no longer used - voting is handled inline in LuxuryPostCard
import 'widgets/luxury_post_card.dart';
import 'widgets/ticker/fertilizer_ticker.dart';
import 'widgets/ticker/fertilizer_price_modal.dart';
import 'providers/presence_provider.dart';
import 'dart:math' as math;
import 'widgets/truth_meter.dart' as truth_widget;
import 'widgets/truth_meter.dart' as truth_widget;
import 'package:flutter_animate/flutter_animate.dart';
import 'screens/market/market_dashboard_screen.dart'; // Add Markets import
import 'screens/settings/settings_screen.dart'; // Settings screen

// Conditional imports for web-only functionality
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// --- SUPABASE CLIENT ---
final supabase = Supabase.instance.client;

// --- LOGGER ---
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
    printTime: false,
  ),
  level: kReleaseMode ? Level.warning : Level.debug,
);

// --- HTML SANITIZATION ---
final htmlUnescape = HtmlUnescape();

/// Sanitize user input to prevent XSS attacks
String sanitizeInput(String input) {
  // Remove any HTML tags
  String sanitized = input.replaceAll(RegExp(r'<[^>]*>'), '');
  // Decode HTML entities
  sanitized = htmlUnescape.convert(sanitized);
  // Trim whitespace
  sanitized = sanitized.trim();
  return sanitized;
}

String? getWebEnvironmentVariable(String key) {
  if (kIsWeb) {
    try {
      // Access window.ENV from JavaScript using dart:js_interop
      final global = web.window as JSObject;
      if (global.has('ENV')) {
        final env = global.getProperty('ENV'.toJS) as JSObject?;
        if (env != null && env.has(key)) {
          final val = env.getProperty(key.toJS) as JSString?;
          return val?.toDart;
        }
      }
    } catch (e) {
      logger.w('Failed to read web environment variable $key: $e');
    }
  }
  return null;
}

// --- CONSTANTS ---
const List<String> PROVINCES_STATES = [
  // --- Canadian Provinces & Territories (alphabetical) ---
  'Alberta',
  'British Columbia',
  'Manitoba',
  'New Brunswick',
  'Newfoundland and Labrador',
  'Northwest Territories',
  'Nova Scotia',
  'Nunavut',
  'Ontario',
  'Prince Edward Island',
  'Quebec',
  'Saskatchewan',
  'Yukon',
  // --- USA States (alphabetical) ---
  'Alabama',
  'Alaska',
  'Arizona',
  'Arkansas',
  'California',
  'Colorado',
  'Connecticut',
  'Delaware',
  'Florida',
  'Georgia',
  'Hawaii',
  'Idaho',
  'Illinois',
  'Indiana',
  'Iowa',
  'Kansas',
  'Kentucky',
  'Louisiana',
  'Maine',
  'Maryland',
  'Massachusetts',
  'Michigan',
  'Minnesota',
  'Mississippi',
  'Missouri',
  'Montana',
  'Nebraska',
  'Nevada',
  'New Hampshire',
  'New Jersey',
  'New Mexico',
  'New York',
  'North Carolina',
  'North Dakota',
  'Ohio',
  'Oklahoma',
  'Oregon',
  'Pennsylvania',
  'Rhode Island',
  'South Carolina',
  'South Dakota',
  'Tennessee',
  'Texas',
  'Utah',
  'Vermont',
  'Virginia',
  'Washington',
  'West Virginia',
  'Wisconsin',
  'Wyoming',
  // --- USA Territories ---
  'District of Columbia',
  'Puerto Rico',
  'Guam',
  'U.S. Virgin Islands',
  // --- Other ---
  'Other/International',
];

// --- DATA MODELS ---
// TruthMeterStatus is imported from models/user_profile.dart

class Post {
  final String id;
  final String title;
  final String content;
  final String category;
  final String? provinceState;
  final DateTime createdAt;
  final int commentCount;
  final int voteCount;

  // Gamification & Truth Meter
  final double truthMeterScore;
  final TruthMeterStatus truthMeterStatus;
  final bool adminVerified;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final int thumbsUpCount;
  final int thumbsDownCount;
  final int partialCount;
  final int funnyCount;

  // User/Author info
  final String? userId;
  final bool isAnonymous;
  final String? authorUsername;
  final bool authorVerified;

  // Edit/Delete tracking
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime? editedAt;
  final int editCount;

  // Verification image (required for Input Prices)
  final String? imageUrl;

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.provinceState,
    required this.createdAt,
    required this.commentCount,
    required this.voteCount,
    this.truthMeterScore = 0.0,
    this.truthMeterStatus = TruthMeterStatus.unrated,
    this.adminVerified = false,
    this.verifiedAt,
    this.verifiedBy,
    this.thumbsUpCount = 0,
    this.thumbsDownCount = 0,
    this.partialCount = 0,
    this.funnyCount = 0,
    this.userId,
    this.isAnonymous = true,
    this.authorUsername,
    this.authorVerified = false,
    this.isDeleted = false,
    this.deletedAt,
    this.editedAt,
    this.editCount = 0,
    this.imageUrl,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Untitled',
      content: map['content'] ?? '',
      category: map['category'] ?? 'General',
      provinceState: map['province_state'],
      createdAt: DateTime.parse(map['created_at']),
      commentCount: map['comment_count'] ?? 0,
      voteCount: map['vote_count'] ?? 0,
      truthMeterScore: (map['truth_meter_score'] as num?)?.toDouble() ?? 0.0,
      truthMeterStatus: map['truth_meter_status'] != null
          ? TruthMeterStatus.fromString(map['truth_meter_status'])
          : TruthMeterStatus.unrated,
      adminVerified: map['admin_verified'] ?? false,
      verifiedAt: map['verified_at'] != null ? DateTime.parse(map['verified_at']) : null,
      verifiedBy: map['verified_by'],
      thumbsUpCount: map['thumbs_up_count'] ?? 0,
      thumbsDownCount: map['thumbs_down_count'] ?? 0,
      partialCount: map['partial_count'] ?? 0,
      funnyCount: map['funny_count'] ?? 0,
      userId: map['user_id'],
      isAnonymous: map['is_anonymous'] ?? true,
      authorUsername: map['author_username'],
      authorVerified: map['author_verified'] ?? false,
      isDeleted: map['is_deleted'] ?? false,
      deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at']) : null,
      editedAt: map['edited_at'] != null ? DateTime.parse(map['edited_at']) : null,
      editCount: map['edit_count'] ?? 0,
      imageUrl: map['image_url'],
    );
  }

  /// Check if post has been edited
  bool get wasEdited => editCount > 0;

  /// Get author display name
  String get authorDisplay {
    if (isAnonymous) return 'Anonymous';
    return authorUsername ?? 'Unknown User';
  }

  /// Get author badge emoji
  String? get authorBadge {
    if (isAnonymous) return '🎭';
    if (authorVerified) return '✅';
    return '⚠️';
  }
}

class Comment {
  final String id;
  final String content;
  final DateTime createdAt;

  // User/Author info
  final String? userId;
  final bool isAnonymous;
  final String? authorUsername;
  final bool authorVerified;

  // Edit/Delete tracking
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime? editedAt;

  Comment({
    required this.id,
    required this.content,
    required this.createdAt,
    this.userId,
    this.isAnonymous = true,
    this.authorUsername,
    this.authorVerified = false,
    this.isDeleted = false,
    this.deletedAt,
    this.editedAt,
  });

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'],
      content: map['content'],
      createdAt: DateTime.parse(map['created_at']),
      userId: map['user_id'],
      isAnonymous: map['is_anonymous'] ?? true,
      authorUsername: map['author_username'],
      authorVerified: map['author_verified'] ?? false,
      isDeleted: map['is_deleted'] ?? false,
      deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at']) : null,
      editedAt: map['edited_at'] != null ? DateTime.parse(map['edited_at']) : null,
    );
  }

  /// Check if comment has been edited
  bool get wasEdited => editedAt != null;

  /// Get author display name
  String get authorDisplay {
    if (isAnonymous) return 'Anonymous';
    return authorUsername ?? 'Unknown User';
  }

  /// Get author badge emoji
  String? get authorBadge {
    if (isAnonymous) return '🎭';
    if (authorVerified) return '✅';
    return '⚠️';
  }
}class VoteStats {
  final int thumbsUpVotes;
  final int partialVotes;
  final int thumbsDownVotes;
  final int funnyVotes;
  final int totalVotes;

  VoteStats({
    required this.thumbsUpVotes,
    required this.partialVotes,
    required this.thumbsDownVotes,
    required this.funnyVotes,
  }) : totalVotes = thumbsUpVotes + partialVotes + thumbsDownVotes + funnyVotes;

  factory VoteStats.fromMap(Map<String, dynamic> map) {
    return VoteStats(
      thumbsUpVotes: (map['thumbs_up_votes'] ?? 0).toInt(),
      partialVotes: (map['partial_votes'] ?? 0).toInt(),
      thumbsDownVotes: (map['thumbs_down_votes'] ?? 0).toInt(),
      funnyVotes: (map['funny_votes'] ?? 0).toInt(),
    );
  }
}

class GlobalStats {
  final int totalPosts;
  final int totalVotes;
  final int totalComments;

  GlobalStats({
    required this.totalPosts,
    required this.totalVotes,
    required this.totalComments,
  });

  factory GlobalStats.fromMap(Map<String, dynamic> map) {
    return GlobalStats(
      totalPosts: (map['total_posts'] ?? 0).toInt(),
      totalVotes: (map['total_votes'] ?? 0).toInt(),
      totalComments: (map['total_comments'] ?? 0).toInt(),
    );
  }
}

class TrendingStats {
  final String trendingCategory;
  final String mostPopularPostTitle;

  TrendingStats({
    required this.trendingCategory,
    required this.mostPopularPostTitle,
  });

  factory TrendingStats.fromMap(Map<String, dynamic> map) {
    return TrendingStats(
      trendingCategory: map['trending_category'] ?? 'General',
      mostPopularPostTitle: map['most_popular_post_title'] ?? 'No posts yet',
    );
  }
}

// --- UTILITY FUNCTIONS ---
String getIconForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'farming': return '🚜';
    case 'livestock': return '🐄';
    case 'ranching': return '🤠';
    case 'crops': return '🌾';
    case 'markets': return '📈';
    case 'weather': return '🌦️';
    case 'chemicals': return '🧪';
    case 'equipment': return '🔧';
    case 'politics': return '🏛️';
    case 'input prices': return '💰';
    case 'general': return '📝';
    case 'other': return '🔗';
    default: return '📝';
  }
}

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

// --- MAIN APP ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AnonymousIdService.getAnonymousId();

  // === STEP 1: Resolve Supabase credentials synchronously (no network calls) ===
  String? supabaseUrl;
  String? supabaseAnonKey;

  // Try JavaScript window.ENV first (Firebase hosting)
  if (kIsWeb) {
    supabaseUrl = getWebEnvironmentVariable('SUPABASE_URL');
    supabaseAnonKey = getWebEnvironmentVariable('SUPABASE_ANON_KEY');
  }

  // Try dart-define (production)
  if (supabaseUrl?.isEmpty != false || supabaseAnonKey?.isEmpty != false) {
    supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
    supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');
  }

  // FALLBACK: Hardcoded values for Web (Safe because Anon Key is public)
  if (kIsWeb && (supabaseUrl?.isEmpty != false || supabaseAnonKey?.isEmpty != false)) {
    logger.w('Using hardcoded fallback credentials for Web');
    supabaseUrl = "https://ibgsloyjxdopkvwqcqwh.supabase.co";
    supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImliZ3Nsb3lqeGRvcGt2d3FjcXdoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI2ODYzMzksImV4cCI6MjA2ODI2MjMzOX0.Ik1980vz4s_UxVuEfBm61-kcIzEH-Nt-hQtydZUeNTw";
  }

  // Try .env file only if still missing (development only, adds latency)
  if (supabaseUrl?.isEmpty != false || supabaseAnonKey?.isEmpty != false) {
    try {
      await dotenv.load(fileName: ".env");
      supabaseUrl = dotenv.env['SUPABASE_URL'];
      supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    } catch (e) {
      // .env file not found, which is okay for production builds
    }
  }

  if (supabaseUrl == null || supabaseUrl.isEmpty ||
      supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    throw Exception('Supabase credentials not found. Please check environment variables or .env file.');
  }

  // === STEP 2: Initialize Firebase, Supabase, and MobileAds in PARALLEL ===
  try {
    final futures = <Future<void>>[];

    // Firebase initialization
    futures.add(Firebase.initializeApp().then((_) {
      logger.i('Firebase initialized successfully');
    }).catchError((e) {
      logger.w('Firebase initialization failed (may already be initialized in web): $e');
    }));

    // Supabase initialization
    futures.add(Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    ).then((_) {
      logger.i('Supabase initialized successfully');
    }));

    // MobileAds initialization (non-web only)
    if (!kIsWeb) {
      futures.add(MobileAds.instance.initialize().then((_) {
        logger.i('Mobile Ads initialized successfully');
      }).catchError((e) {
        logger.w('Mobile Ads initialization failed: $e');
      }));
    }

    // Wait for all to complete in parallel
    await Future.wait(futures);
  } catch (e) {
    logger.e('Initialization error: $e');
    rethrow;
  }

  // === STEP 3: Set up Crashlytics AFTER Firebase is ready ===
  if (!kIsWeb) {
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

      FlutterError.onError = (errorDetails) {
        logger.e('Flutter error: ${errorDetails.exception}', error: errorDetails.exception, stackTrace: errorDetails.stack);
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        logger.e('Platform error: $error', error: error, stackTrace: stack);
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      logger.i('Firebase Crashlytics initialized successfully');
    } catch (e) {
      logger.w('Firebase Crashlytics initialization failed: $e');
    }
  }

  try {
    logger.d('Initialization complete, starting app');

    // Check for existing session (don't auto-sign in - let AuthWrapper handle login flow)
    final session = supabase.auth.currentSession;
    if (session != null) {
      logger.d('Found existing session for user: ${session.user.id}');
    } else {
      logger.d('No existing session - user will be directed to login screen');
    }

    // Set up custom error widget for render errors
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: const Color(0xFF111827),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: Colors.orange.withValues(alpha: 0.8),
                ),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try refreshing the page',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                  textAlign: TextAlign.center,
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      details.exception.toString(),
                      style: GoogleFonts.robotoMono(
                        fontSize: 11,
                        color: Colors.red[300],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    };

    runApp(const ProviderScope(child: AgnonymousApp()));
  } catch (e) {
    logger.e('Failed to initialize app', error: e);
    runApp(ErrorApp(message: e.toString()));
  }
}

class ErrorApp extends StatelessWidget {
  final String message;
  const ErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF111827),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Error Starting App',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- THEME ---
final theme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF84CC16),
  scaffoldBackgroundColor: const Color(0xFF111827),
  textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
  ),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF84CC16),
    secondary: Color(0xFFF59E0B),
    surface: Color(0xFF1F2937),
    error: Color(0xFFEF4444),
  ),
);

class AgnonymousApp extends StatelessWidget {
  const AgnonymousApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agnonymous',
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/leaderboard': (context) => const LeaderboardScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/verify-email': (context) => const VerifyEmailScreen(),
      },
      navigatorObservers: [
        AnalyticsService.instance.observer,
      ],
    );
  }
}

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
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: HomeScreen(),
    );
  }
}

// --- HOME SCREEN ---
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String searchQuery = '';
  String selectedCategory = '';
  bool isSearching = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final currentCategory = selectedCategory.isNotEmpty ? selectedCategory : 'all';
    final postsState = ref.read(paginatedPostsProvider);
    final categoryState = postsState.getCategoryState(currentCategory);

    // Trigger load more when near bottom, not loading, and has more posts
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !categoryState.isLoading &&
        categoryState.hasMore) {
      ref.read(paginatedPostsProvider.notifier).loadMoreForCategory(currentCategory);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () {
          final currentCategory = selectedCategory.isNotEmpty ? selectedCategory : 'all';
          return ref.read(paginatedPostsProvider.notifier).refreshCategory(currentCategory);
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: false,
              snap: true,
              backgroundColor: const Color.fromRGBO(17, 24, 39, 0.8),
              title: HeaderBar(
                onSearchChanged: (query) {
                  setState(() {
                    searchQuery = query;
                    isSearching = query.isNotEmpty;
                  });
                },
              ),
              automaticallyImplyLeading: false,
              toolbarHeight: 80,
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: TrendingSectionDelegate(),
            ),
            const SliverToBoxAdapter(
              child: FertilizerTicker(),
            ),
            SliverToBoxAdapter(
              child: CategoryChips(
                selectedCategory: selectedCategory,
                onCategoryChanged: (category) {
                  setState(() {
                    selectedCategory = category;
                    // Clear search when selecting category
                    if (category.isNotEmpty) {
                      searchQuery = '';
                      isSearching = false;
                    }
                  });
                },
              ),
            ),
            PostFeedSliver(
              searchQuery: searchQuery,
              selectedCategory: selectedCategory,
            ),
            // Add bottom padding for the floating buttons
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Post Comment Button
            Expanded(
              child: FloatingActionButton.extended(
                heroTag: 'post_comment_btn',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const CreatePostScreen()),
                  );
                },
                backgroundColor: const Color(0xFF1F2937),
                foregroundColor: Colors.white,
                elevation: 4,
                icon: const FaIcon(FontAwesomeIcons.commentDots, color: Color(0xFF84CC16), size: 18),
                label: Text(
                  'Post',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: const Color(0xFF84CC16).withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Markets Button (Middle)
            Expanded(
              child: FloatingActionButton.extended(
                heroTag: 'markets_btn',
                onPressed: () {
                   Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const MarketDashboardScreen()),
                  );
                },
                backgroundColor: const Color(0xFF1F2937),
                foregroundColor: Colors.white,
                elevation: 4,
                icon: const Icon(Icons.candlestick_chart_outlined, color: Color(0xFF60A5FA), size: 18),
                label: Text(
                  'Markets',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: const Color(0xFF60A5FA).withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Price Post Button
            Expanded(
              child: FloatingActionButton.extended(
                heroTag: 'post_price_btn',
                onPressed: () {
                  showFertilizerPriceModal(context);
                },
                backgroundColor: const Color(0xFF84CC16), // Primary Green
                foregroundColor: Colors.white,
                elevation: 8,
                icon: const FaIcon(FontAwesomeIcons.tag, size: 18),
                label: Text(
                  '\$\$',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ).animate(onPlay: (controller) => controller.repeat(reverse: true))
               .shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.3)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- POST FEED ---


class PostFeedSliver extends ConsumerStatefulWidget {
  final String searchQuery;
  final String selectedCategory;
  const PostFeedSliver({super.key, this.searchQuery = '', this.selectedCategory = ''});

  @override
  ConsumerState<PostFeedSliver> createState() => _PostFeedSliverState();
}

class _PostFeedSliverState extends ConsumerState<PostFeedSliver> {
  String? _lastCategory;

  @override
  void initState() {
    super.initState();
    // Initial load for 'all' category
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentCategory();
    });
  }

  @override
  void didUpdateWidget(PostFeedSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Load new category when it changes
    if (oldWidget.selectedCategory != widget.selectedCategory) {
      // Clear search query when category changes
      if (widget.searchQuery.isNotEmpty) {
        // This is a bit of a hack, but we need to call the onSearchChanged callback
        // to clear the search query in the parent widget.
        // Future.microtask is used to avoid calling setState during a build.
        Future.microtask(() => context.findAncestorStateOfType<_HomeScreenState>()?.setState(() {
          
        }));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCurrentCategory();
      });
    }
  }

  void _loadCurrentCategory() {
    final currentCategory = widget.selectedCategory.isNotEmpty ? widget.selectedCategory : 'all';
    if (_lastCategory != currentCategory) {
      _lastCategory = currentCategory;
      logger.d('Loading category: $currentCategory');
      ref.read(paginatedPostsProvider.notifier).ensureCategoryLoaded(currentCategory);
    }
  }

  @override
  Widget build(BuildContext context) {
    final postsState = ref.watch(paginatedPostsProvider);
    
    // Determine which category to display
    final currentCategory = widget.selectedCategory.isNotEmpty ? widget.selectedCategory : 'all';
    final categoryState = postsState.getCategoryState(currentCategory);

    logger.d('Building feed for category: $currentCategory, posts: ${categoryState.posts.length}');

    final horizontalPadding = MediaQuery.of(context).size.width > 800
        ? (MediaQuery.of(context).size.width - 800) / 2
        : 16.0;

    // Error state
    if (categoryState.error != null) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FaIcon(FontAwesomeIcons.triangleExclamation, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text('Error loading posts: ${categoryState.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.read(paginatedPostsProvider.notifier).refreshCategory(currentCategory),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    var filteredPosts = categoryState.posts;

    // Apply search filter (category is already handled by loading specific category)
    if (widget.searchQuery.isNotEmpty) {
      final query = widget.searchQuery.toLowerCase();
      filteredPosts = filteredPosts.where((post) =>
          post.title.toLowerCase().contains(query) ||
          post.content.toLowerCase().contains(query) ||
          post.category.toLowerCase().contains(query)).toList();
    }

    // Apply sort mode
    final sortMode = ref.watch(feedSortModeProvider);
    if (sortMode == FeedSortMode.topFunny) {
      // Sort by funny count descending, then by created_at for ties
      filteredPosts = List.from(filteredPosts)
        ..sort((a, b) {
          final funnyCompare = b.funnyCount.compareTo(a.funnyCount);
          if (funnyCompare != 0) return funnyCompare;
          return b.createdAt.compareTo(a.createdAt);
        });
    }

    // Empty state
    if (filteredPosts.isEmpty && !categoryState.isLoading) {
      String emptyMessage;
      IconData emptyIcon;
      
      if (widget.searchQuery.isNotEmpty) {
        if (currentCategory == 'all') {
          emptyMessage = 'No posts found for "${widget.searchQuery}"';
        } else {
          emptyMessage = 'No posts found in "${widget.selectedCategory}" for "${widget.searchQuery}"';
        }
        emptyIcon = FontAwesomeIcons.magnifyingGlass;
      } else if (currentCategory != 'all') {
        emptyMessage = 'No posts yet in "${widget.selectedCategory}"\nBe the first to post!';
        emptyIcon = FontAwesomeIcons.seedling;
      } else {
        emptyMessage = 'No posts yet\nBe the first to post!';
        emptyIcon = FontAwesomeIcons.seedling;
      }
      
      return SliverFillRemaining( // Use SliverFillRemaining to center content
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(emptyIcon, size: 64, color: Colors.grey.shade600),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: const TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Loading state for initial load - show skeleton placeholders instead of spinner
    if (filteredPosts.isEmpty && categoryState.isLoading) {
      return SliverPadding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 24.0,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _PostSkeletonCard(),
            ),
            childCount: 3, // Show 3 skeleton cards
          ),
        ),
      );
    }

    // Determine if we should show a footer (loading or end of posts)
    final bool showLoadingFooter = categoryState.isLoading && categoryState.currentPage > 0;
    final bool showEndOfPostsFooter = !categoryState.hasMore && filteredPosts.isNotEmpty && !categoryState.isLoading;
    final bool hasFooter = showLoadingFooter || showEndOfPostsFooter;

    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 24.0,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            // Footer item (loading or end of posts)
            if (index == filteredPosts.length && hasFooter) {
              if (showLoadingFooter) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (showEndOfPostsFooter) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        FaIcon(FontAwesomeIcons.checkCircle,
                          color: Colors.grey.shade600, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          "You're all caught up!",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: PostCard(key: ValueKey(filteredPosts[index].id), post: filteredPosts[index]),
            );
          },
          childCount: filteredPosts.length + (hasFooter ? 1 : 0),
        ),
      ),
    );
  }
}

// --- HEADER BAR ---
class HeaderBar extends ConsumerStatefulWidget {
  final Function(String) onSearchChanged;
  const HeaderBar({super.key, required this.onSearchChanged});

  @override
  ConsumerState<HeaderBar> createState() => _HeaderBarState();
}

class _HeaderBarState extends ConsumerState<HeaderBar> {
  bool isSearchExpanded = false;
  final searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    widget.onSearchChanged(query);
    // Debounce analytics logging to avoid excessive events
    _searchDebounce?.cancel();
    if (query.length >= 3) {
      _searchDebounce = Timer(const Duration(milliseconds: 800), () {
        AnalyticsService.instance.logSearch(searchTerm: query);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 400;
    final isMediumScreen = MediaQuery.of(context).size.width < 600;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!isSearchExpanded) ...[
            Row(
              children: [
                Image.asset(
                  'assets/images/app_icon_foreground.png',
                  height: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  'Agnonymous',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0xFF22C55E), blurRadius: 4),
                          ],
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true))
                       .fadeIn(duration: 1000.ms).fadeOut(delay: 1000.ms),
                      const SizedBox(width: 6),
                      Text(
                        '${ref.watch(presenceProvider)} Online',
                        style: GoogleFonts.robotoMono(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (isMediumScreen) 
              IconButton(
                icon: const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 18),
                onPressed: () {
                  setState(() {
                    isSearchExpanded = true;
                  });
                },
                color: Colors.grey.shade400,
              ),
            if (!isMediumScreen) ...[
              _buildSearchField(),
              const SizedBox(width: 12),
            ],
            const _AuthHeaderButton(),
          ] else ...[
            // Expanded search mode for mobile
            Expanded(
              child: TextField(
                controller: searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search posts...',
                  prefixIcon: const Icon(FontAwesomeIcons.magnifyingGlass, size: 16),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        isSearchExpanded = false;
                        searchController.clear();
                        widget.onSearchChanged('');
                      });
                    },
                  ),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Search posts...',
            prefixIcon: const Icon(FontAwesomeIcons.magnifyingGlass, size: 16),
            filled: true,
            fillColor: Colors.black.withOpacity(0.2),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: _onSearchChanged,
        ),
      ),
    );
  }
}

class _AuthHeaderButton extends StatelessWidget {
  const _AuthHeaderButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const FaIcon(FontAwesomeIcons.gear, size: 20),
      color: Colors.white70,
      tooltip: 'Settings',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      ),
    );
  }
}

// --- GLOBAL STATS HEADER ---
class GlobalStatsHeader extends ConsumerWidget {
  const GlobalStatsHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(globalStatsProvider);
    final isVerySmallScreen = MediaQuery.of(context).size.width < 350;

    return statsAsync.when(
      loading: () => const SizedBox(
        height: 36,
        width: 36,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (err, stack) => const FaIcon(
        FontAwesomeIcons.triangleExclamation,
        color: Colors.red,
        size: 20,
      ),
      data: (stats) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatItem(
            label: isVerySmallScreen ? 'P' : 'Posts',
            value: NumberFormat.compact().format(stats.totalPosts),
          ),
          const SizedBox(width: 12),
          _StatItem(
            label: isVerySmallScreen ? 'V' : 'Votes',
            value: NumberFormat.compact().format(stats.totalVotes),
          ),
          const SizedBox(width: 12),
          _StatItem(
            label: isVerySmallScreen ? 'C' : 'Comments',
            value: NumberFormat.compact().format(stats.totalComments),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// --- CATEGORY DROPDOWN ---
class CategoryChips extends StatelessWidget {
  final String selectedCategory;
  final Function(String) onCategoryChanged;

  const CategoryChips({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  static const List<String> categories = [
    'Farming',
    'Livestock',
    'Ranching',
    'Crops',
    'Markets',
    'Weather',
    'Chemicals',
    'Equipment',
    'Politics',
    'Input Prices',
    'General',
    'Other'
  ];

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selectedCategory.isNotEmpty
                      ? theme.colorScheme.primary.withOpacity(0.5)
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCategory,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1F2937),
                  icon: FaIcon(
                    FontAwesomeIcons.chevronDown,
                    size: 12,
                    color: Colors.grey.shade400,
                  ),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  items: [
                    // Explicit "All Categories" option
                    DropdownMenuItem<String>(
                      value: '',
                      child: Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.filter,
                            size: 14,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'All Categories',
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Row(
                          children: [
                            Text(
                              getIconForCategory(category),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 10),
                            Text(category),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    if (value != null && value.isNotEmpty) {
                      AnalyticsService.instance.logCategoryFilter(category: value);
                    }
                    onCategoryChanged(value ?? '');
                  },
                ),
              ),
            ),
          ),
          if (selectedCategory.isNotEmpty) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => onCategoryChanged(''),
              icon: const FaIcon(
                FontAwesomeIcons.xmark,
                size: 20,
                color: Colors.white,
              ),
              tooltip: 'Clear filter',
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.error.withOpacity(0.8),
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// --- TRENDING SECTION ---
class TrendingSectionDelegate extends SliverPersistentHeaderDelegate {
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isSmallScreen = MediaQuery.of(context).size.width < 400;
    
    return Consumer(
      builder: (context, ref, child) {
        final trendingAsync = ref.watch(trendingStatsProvider);
        final sortMode = ref.watch(feedSortModeProvider);

        return Container(
          height: 40.0,
          color: const Color.fromRGBO(31, 41, 55, 0.95),
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 8 : 16, 
            vertical: 6,
          ),
          child: Row(
            children: [
              // Sort mode toggle chips
              _SortModeChip(
                label: 'Recent',
                icon: FontAwesomeIcons.clock,
                isSelected: sortMode == FeedSortMode.recent,
                onTap: () => ref.read(feedSortModeProvider.notifier).set(FeedSortMode.recent),
              ),
              const SizedBox(width: 8),
              _SortModeChip(
                label: isSmallScreen ? '😂' : 'Top Funny',
                icon: FontAwesomeIcons.faceLaughSquint,
                isSelected: sortMode == FeedSortMode.topFunny,
                onTap: () => ref.read(feedSortModeProvider.notifier).set(FeedSortMode.topFunny),
                color: const Color(0xFFF97316), // Orange for funny
              ),
              const Spacer(),
              // Trending info (only on larger screens)
              if (!isSmallScreen)
                trendingAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (stats) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(FontAwesomeIcons.fire, color: theme.colorScheme.secondary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        stats.trendingCategory,
                        style: TextStyle(
                          color: theme.colorScheme.secondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  double get maxExtent => 40.0;
  @override
  double get minExtent => 40.0;
  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) => true;
}

/// Sort mode chip widget
class _SortModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _SortModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? const Color(0xFF84CC16);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? chipColor : Colors.grey.shade600,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!label.startsWith('😂'))
              FaIcon(
                icon,
                size: 12,
                color: isSelected ? chipColor : Colors.grey.shade400,
              ),
            if (!label.startsWith('😂'))
              const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? chipColor : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- POST CARD ---
class PostCard extends ConsumerStatefulWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _isCommentsExpanded = false;

  /// Check if current user owns this post
  bool get _isOwner {
    final userId = supabase.auth.currentUser?.id;
    return userId != null && widget.post.userId == userId;
  }

  /// Show add to post dialog (append-only - cannot erase original content)
  Future<void> _showAddToPostDialog(BuildContext context) async {
    final additionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _AddToPostDialog(
        originalContent: widget.post.content,
        additionController: additionController,
        onSave: (addition) async {
          try {
            final userId = supabase.auth.currentUser?.id;
            if (userId == null) throw 'Not authenticated';

            // Sanitize the addition
            final sanitizedAddition = sanitizeInput(addition);
            if (sanitizedAddition.isEmpty) {
              throw 'Please enter content to add';
            }

            // Append to original content with separator
            final newContent = '${widget.post.content}\n\n---\n**Edit:** $sanitizedAddition';

            // Call the edit_post RPC function
            await supabase.rpc('edit_post', params: {
              'post_id_in': widget.post.id,
              'user_id_in': userId,
              'new_title': widget.post.title, // Title cannot be changed
              'new_content': newContent,
            });

            // Refresh posts to show updated content
            final currentCategories = ref.read(paginatedPostsProvider).categoryStates.keys.toList();
            for (final category in currentCategories) {
              ref.read(paginatedPostsProvider.notifier).refreshCategory(category);
            }

            return true;
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error adding to post: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return false;
          }
        },
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Addition posted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }

    additionController.dispose();
  }

  /// Show delete confirmation and perform soft delete
  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 28),
            const SizedBox(width: 12),
            const Text('Delete Post?', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'This will remove the post from public view. You can undo this action.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deletePost(context);
    }
  }

  /// Perform soft delete of post
  Future<void> _deletePost(BuildContext context) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw 'Not authenticated';

      // Call the soft_delete_post RPC function
      await supabase.rpc('soft_delete_post', params: {
        'post_id_in': widget.post.id,
        'user_id_in': userId,
      });

      // Refresh posts to remove deleted post
      final currentCategories = ref.read(paginatedPostsProvider).categoryStates.keys.toList();
      for (final category in currentCategories) {
        ref.read(paginatedPostsProvider.notifier).refreshCategory(category);
      }

      if (mounted) {
        // Show undo snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Post deleted'),
            backgroundColor: Colors.grey.shade800,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: const Color(0xFF84CC16),
              onPressed: () => _restorePost(context),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Restore a soft-deleted post
  Future<void> _restorePost(BuildContext context) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw 'Not authenticated';

      await supabase.rpc('restore_post', params: {
        'post_id_in': widget.post.id,
        'user_id_in': userId,
      });

      // Refresh posts to show restored post
      final currentCategories = ref.read(paginatedPostsProvider).categoryStates.keys.toList();
      for (final category in currentCategories) {
        ref.read(paginatedPostsProvider.notifier).refreshCategory(category);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post restored!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _castVote(BuildContext context, WidgetRef ref, String voteType) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final userId = supabase.auth.currentUser?.id;
      final anonId = await AnonymousIdService.getAnonymousId();
      
      // Prevent self-voting (if owner is known and logged in)
      if (userId != null && widget.post.userId == userId) {
        throw 'You cannot vote on your own posts.';
      }

      // Check client-side rate limiting
      final rateLimiter = RateLimiter();
      final rateLimitError = rateLimiter.canVote(widget.post.id);
      if (rateLimitError != null) {
        throw rateLimitError;
      }

      // Try RPC first, fall back to direct upsert if it fails
      try {
        await supabase.rpc('cast_user_vote', params: {
          'post_id_in': widget.post.id,
          'user_id_in': userId, // Can be null for anonymous users
          'anonymous_user_id_in': anonId, // Required for anonymous voting
          'vote_type_in': voteType,
        });
      } catch (rpcError) {
        // RPC failed (likely doesn't exist), use direct upsert
        // logger.w('RPC cast_user_vote failed, using direct upsert: $rpcError');

        // Table uses anonymous_user_id as the main identifier for guests
        await supabase.from('truth_votes').upsert(
          {
            'post_id': widget.post.id,
            'anonymous_user_id': anonId, // Required for uniqueness constraint
            'user_id': userId, // Can be null
            'vote_type': voteType,
            'is_anonymous': true,
          },
          onConflict: 'post_id,anonymous_user_id', // Start with anon constraint
        );
      }

      // Record successful vote for rate limiting
      rateLimiter.recordVote(widget.post.id);

      // Refresh categories to pick up the vote count change
      final currentCategories = ref.read(paginatedPostsProvider).categoryStates.keys.toList();
      for (final category in currentCategories) {
        ref.read(paginatedPostsProvider.notifier).refreshCategory(category);
      }

      final voteEmoji = {
        'thumbs_up': '👍',
        'partial': '🤔',
        'thumbs_down': '👎',
        'funny': '😂',
      }[voteType] ?? '';

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('$voteEmoji Vote cast successfully!'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      String errorMessage = 'Error casting vote';
      final errorStr = e.toString();

      if (errorStr.contains('rate limit')) {
        errorMessage = 'Too many votes! Please wait a minute.';
      } else if (errorStr.contains('own posts')) {
        errorMessage = 'You cannot vote on your own posts.';
      } else if (errorStr.contains('Access Denied')) {
        errorMessage = 'Access Denied: ${errorStr.split('Access Denied:').last.trim()}';
      } else if (errorStr.contains('unique_user_post_vote') || errorStr.contains('duplicate key')) {
        // Vote already exists - this shouldn't happen with upsert but handle it
        errorMessage = 'Vote updated!';
      } else {
         // Clean up Postgres error messages
         errorMessage = errorStr.replaceAll('PostgrestException(message:', '').replaceAll('details:', '').trim();
         if (errorMessage.length > 100) errorMessage = 'Error casting vote. Please try again.';
      }

      final isError = !errorMessage.contains('updated');
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final voteStatsAsync = ref.watch(voteStatsProvider(widget.post.id));
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    return LuxuryPostCard(
      title: widget.post.title,
      content: widget.post.content,
      category: widget.post.category,
      categoryEmoji: getIconForCategory(widget.post.category),
      createdAt: widget.post.createdAt,
      authorUsername: widget.post.authorUsername,
      authorVerified: widget.post.authorVerified,
      isAnonymous: widget.post.isAnonymous,
      commentCount: widget.post.commentCount,
      imageUrl: widget.post.imageUrl,
      funnyCount: voteStatsAsync.value?.funnyVotes ?? 0,
      isCommentsExpanded: _isCommentsExpanded,
      onToggleComments: () => setState(() => _isCommentsExpanded = !_isCommentsExpanded),
      onFunnyVote: () => _castVote(context, ref, 'funny'),
      truthMeterWidget: voteStatsAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error loading votes: $err', style: const TextStyle(color: Colors.red)),
          ),
        ),
        data: (stats) {
          // Calculate truth score
          final positiveVotes = stats.thumbsUpVotes * 2 + stats.partialVotes;
          final negativeVotes = stats.thumbsDownVotes * 2;
          final totalWeighted = positiveVotes + negativeVotes;
          final truthScore = totalWeighted > 0
              ? (positiveVotes / totalWeighted * 100).clamp(0.0, 100.0)
              : 50.0;

          // Determine status based on score
          TruthMeterStatus status;
          if (stats.totalVotes == 0) {
            status = TruthMeterStatus.unrated;
          } else if (truthScore >= 70) {
            status = TruthMeterStatus.verifiedCommunity;
          } else if (truthScore >= 40) {
            status = TruthMeterStatus.questionable;
          } else {
            status = TruthMeterStatus.rumour;
          }

          return truth_widget.TruthMeter(
            status: status,
            score: truthScore,
            voteCount: stats.totalVotes,
            thumbsUp: stats.thumbsUpVotes,
            thumbsDown: stats.thumbsDownVotes,
            partial: stats.partialVotes,
            funny: stats.funnyVotes,
            compact: false,
            showVoteBreakdown: true, // Always show to allow voting
            onVote: (voteType) => _castVote(context, ref, voteType),
          );
        },
      ),
      commentsWidget: CommentSection(postId: widget.post.id),
      showSignInPrompt: false,
      // Edit/Delete support (edit = append only, delete = 5 second window)
      isOwner: _isOwner,
      wasEdited: widget.post.wasEdited,
      onEdit: _isOwner ? () => _showAddToPostDialog(context) : null,
      // Only allow deletion within 5 seconds of post creation
      onDelete: _isOwner && _canDeletePost() ? () => _showDeleteConfirmation(context) : null,
    );
  }

  /// Check if post can still be deleted (within 5 seconds of creation)
  bool _canDeletePost() {
    final timeSinceCreation = DateTime.now().difference(widget.post.createdAt);
    return timeSinceCreation.inSeconds <= 5;
  }
}

/// Dialog for adding to a post (append-only - original content cannot be erased)
class _AddToPostDialog extends StatefulWidget {
  final String originalContent;
  final TextEditingController additionController;
  final Future<bool> Function(String addition) onSave;

  const _AddToPostDialog({
    required this.originalContent,
    required this.additionController,
    required this.onSave,
  });

  @override
  State<_AddToPostDialog> createState() => _AddToPostDialogState();
}

class _AddToPostDialogState extends State<_AddToPostDialog> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84CC16).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_comment_rounded,
                    color: Color(0xFF84CC16),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Add to Post',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: Icon(Icons.close, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Info notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade300, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You can only add to your post. Original content cannot be changed or deleted.',
                      style: TextStyle(
                        color: Colors.orange.shade200,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Original content preview
            Text(
              'Original Post',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 100),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  widget.originalContent,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Addition field
            Text(
              'Add Content',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.additionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF84CC16)),
                ),
                hintText: 'Add clarification, correction, or update...',
                hintStyle: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF84CC16),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSaving
                      ? null
                      : () async {
                          if (widget.additionController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter content to add'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          setState(() => _isSaving = true);
                          final success = await widget.onSave(
                            widget.additionController.text,
                          );
                          if (mounted) {
                            if (success) {
                              Navigator.pop(context, true);
                            } else {
                              setState(() => _isSaving = false);
                            }
                          }
                        },
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Add to Post'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- COMMENT SECTION ---
// Note: Comments cannot be edited or deleted to preserve transparency and reputation integrity
class CommentSection extends ConsumerStatefulWidget {
  final String postId;
  const CommentSection({super.key, required this.postId});

  @override
  ConsumerState<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends ConsumerState<CommentSection> {
  final _commentController = TextEditingController();
  bool _isPostingComment = false;
  bool _commentAsAnonymous = true;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // Note: Comments cannot be edited or deleted to preserve transparency
  // and reputation integrity. Users must think carefully before commenting.

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    // Check client-side rate limiting for comments
    final commentRateLimiter = CommentRateLimiter();
    final rateLimitError = commentRateLimiter.canComment();
    if (rateLimitError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rateLimitError),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
      return;
    }

    setState(() => _isPostingComment = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      final anonId = await AnonymousIdService.getAnonymousId();

      // Sanitize comment content to prevent XSS attacks
      final sanitizedContent = sanitizeInput(content);
      if (sanitizedContent.isEmpty) {
        throw 'Invalid comment content';
      }

      // Get user profile for author info if not anonymous
      final authState = ref.read(authProvider);
      final userProfile = authState.profile;

      final commentData = <String, dynamic>{
        'post_id': widget.postId,
        'user_id': userId,
        'anonymous_user_id': anonId,
        'content': sanitizedContent,
        'is_anonymous': _commentAsAnonymous,
      };

      // Add author info if not posting anonymously
      if (!_commentAsAnonymous && userProfile != null) {
        commentData['author_username'] = userProfile.username;
        commentData['author_verified'] = userProfile.emailVerified;
      }

      // Insert comment
      await supabase.from('comments').insert(commentData);

      // Track comment analytics
      AnalyticsService.instance.logCommentPosted();

      // Record successful comment for rate limiting
      commentRateLimiter.recordComment();

      _commentController.clear();
      
      // Force refresh categories to pick up the updated comment count
      final currentCategories = ref.read(paginatedPostsProvider).categoryStates.keys.toList();
      for (final category in currentCategories) {
        ref.read(paginatedPostsProvider.notifier).refreshCategory(category);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment posted!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error posting comment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPostingComment = false);
      }
    }
  }

  Widget _buildCommentIdentityToggle() {
    final authState = ref.watch(authProvider);
    final userProfile = authState.profile;
    final isLoggedIn = userProfile != null;
    final username = userProfile?.username ?? 'Unknown';
    final isVerified = userProfile?.emailVerified ?? false;

    return Row(
      children: [
        Text(
          'Comment as: ',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
          ),
        ),
        // Anonymous chip
        GestureDetector(
          onTap: () => setState(() => _commentAsAnonymous = true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _commentAsAnonymous
                  ? theme.colorScheme.primary.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _commentAsAnonymous
                    ? theme.colorScheme.primary
                    : Colors.grey.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.masks,
                  size: 14,
                  color: _commentAsAnonymous
                      ? theme.colorScheme.primary
                      : Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  'Anonymous',
                  style: TextStyle(
                    color: _commentAsAnonymous
                        ? theme.colorScheme.primary
                        : Colors.grey.shade500,
                    fontSize: 12,
                    fontWeight: _commentAsAnonymous
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Username chip (only if logged in with profile)
        if (isLoggedIn)
          GestureDetector(
            onTap: () => setState(() => _commentAsAnonymous = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: !_commentAsAnonymous
                    ? theme.colorScheme.primary.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !_commentAsAnonymous
                      ? theme.colorScheme.primary
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isVerified ? Icons.verified : Icons.person,
                    size: 14,
                    color: !_commentAsAnonymous
                        ? (isVerified ? Colors.blue : theme.colorScheme.primary)
                        : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '@$username',
                    style: TextStyle(
                      color: !_commentAsAnonymous
                          ? theme.colorScheme.primary
                          : Colors.grey.shade500,
                      fontSize: 12,
                      fontWeight: !_commentAsAnonymous
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(widget.postId));
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          commentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Text('Error loading comments: $err'),
            data: (comments) {
              if (comments.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text(
                      'No comments yet. Be the first!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  return Card(
                    color: Colors.grey.shade800,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Author info row
                          Row(
                            children: [
                              Icon(
                                comment.isAnonymous
                                    ? Icons.masks
                                    : (comment.authorVerified
                                        ? Icons.verified
                                        : Icons.person),
                                size: 14,
                                color: comment.isAnonymous
                                    ? Colors.grey.shade500
                                    : (comment.authorVerified
                                        ? Colors.blue
                                        : Colors.orange),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                comment.authorDisplay,
                                style: TextStyle(
                                  color: comment.isAnonymous
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade300,
                                  fontSize: 12,
                                  fontWeight: comment.isAnonymous
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat.yMMMd().add_jm().format(comment.createdAt),
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                              ),
                              // Edited indicator (legacy - comments can no longer be edited)
                              if (comment.wasEdited) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '(edited)',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Comment content
                          Text(
                            comment.content,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
          // Sign-in prompt removed to allow anonymous comments
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Comment identity toggle
                _buildCommentIdentityToggle(),
                const SizedBox(height: 8),
                // Comment input row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          filled: true,
                          fillColor: const Color(0xFF212121),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _postComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isPostingComment
                        ? const SizedBox(
                            width: 40,
                            height: 40,
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const FaIcon(FontAwesomeIcons.paperPlane),
                            onPressed: _postComment,
                            color: theme.colorScheme.primary,
                          ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

void _showLoginDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('Sign In Required', style: TextStyle(color: Colors.white)),
      content: const Text(
        'You need to be signed in to perform this action.',
        style: TextStyle(color: Colors.grey),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          child: const Text('Sign In'),
        ),
      ],
    ),
  );
}

/// Skeleton placeholder card shown while posts are loading
class _PostSkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          Row(
            children: [
              _SkeletonBox(width: 40, height: 40, borderRadius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(width: 120, height: 14),
                    const SizedBox(height: 6),
                    _SkeletonBox(width: 80, height: 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Content skeleton
          _SkeletonBox(width: double.infinity, height: 14),
          const SizedBox(height: 8),
          _SkeletonBox(width: double.infinity, height: 14),
          const SizedBox(height: 8),
          _SkeletonBox(width: 200, height: 14),
          const SizedBox(height: 16),
          // Footer skeleton
          Row(
            children: [
              _SkeletonBox(width: 60, height: 24, borderRadius: 12),
              const SizedBox(width: 16),
              _SkeletonBox(width: 60, height: 24, borderRadius: 12),
              const Spacer(),
              _SkeletonBox(width: 40, height: 24, borderRadius: 12),
            ],
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat())
      .shimmer(duration: 1500.ms, color: Colors.white.withOpacity(0.05));
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

