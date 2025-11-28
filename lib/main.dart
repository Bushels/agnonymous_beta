import 'dart:async';
import 'package:agnonymous_beta/create_post_screen.dart';
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
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/leaderboard/leaderboard_screen.dart';
import 'screens/pricing/prices_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'providers/auth_provider.dart';
import 'models/user_profile.dart' show TruthMeterStatus;
import 'services/analytics_service.dart';
import 'widgets/glass_bottom_nav.dart';
// VoteButtons no longer used - voting is handled inline in LuxuryPostCard
import 'widgets/luxury_post_card.dart';
import 'widgets/truth_meter.dart' as truth_widget;

// Conditional imports for web-only functionality

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
  // Implementation for web environment variables if needed
  // For now, return null or handle as appropriate
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
    );
  }

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

  Comment({
    required this.id,
    required this.content,
    required this.createdAt,
    this.userId,
    this.isAnonymous = true,
    this.authorUsername,
    this.authorVerified = false,
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
    );
  }

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
          .select('*');

      // Apply category filter for specific categories, skip for "all"
      if (category != 'all') {
        query = query.eq('category', category);
      }

      final data = await query
          .order('created_at', ascending: false)
          .range(pageToLoad * _pageSize, (pageToLoad + 1) * _pageSize - 1);

      final newPosts = (data as List).map((map) => Post.fromMap(map)).toList();

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
    return listOfMaps.map((map) => Comment.fromMap(map)).toList();
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

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    logger.i('Firebase initialized successfully');
  } catch (e) {
    logger.w('Firebase initialization failed (may already be initialized in web): $e');
  }

  // Initialize Mobile Ads
  if (!kIsWeb) {
    try {
      await MobileAds.instance.initialize();
      logger.i('Mobile Ads initialized successfully');
    } catch (e) {
      logger.w('Mobile Ads initialization failed: $e');
    }
  }

  try {
    // Try to get from JavaScript window.ENV first (Firebase hosting)
    String? supabaseUrl;
    String? supabaseAnonKey;

    // Use conditional web helper for platform-safe environment variable access
    if (kIsWeb) {
      supabaseUrl = getWebEnvironmentVariable('SUPABASE_URL');
      supabaseAnonKey = getWebEnvironmentVariable('SUPABASE_ANON_KEY');
    }

    // If not found, try dart-define (production)
    if (supabaseUrl?.isEmpty != false || supabaseAnonKey?.isEmpty != false) {
      supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
      supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');
    }

    // If still not found, try to load from .env (development)
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

    logger.d('Initializing Supabase connection');

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    logger.i('Supabase initialized successfully');

    try {
      // Try to get existing session first
      final session = supabase.auth.currentSession;
      if (session == null) {
        logger.d('No existing session, signing in anonymously');
        final authResponse = await supabase.auth.signInAnonymously();
        logger.i('Anonymous auth successful');
      } else {
        logger.d('Using existing session');
      }
    } catch (authError) {
      logger.w('Anonymous auth error: $authError');
      // Continue anyway, posts might be publicly accessible
    }

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
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
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

  // Navigation items (Profile accessed via top header)
  static const _navItems = [
    BottomNavItem(icon: FontAwesomeIcons.house, label: 'Home'),
    BottomNavItem(icon: FontAwesomeIcons.dollarSign, label: 'Prices'),
    BottomNavItem(icon: FontAwesomeIcons.plus, label: 'Post', isSpecial: true),
    BottomNavItem(icon: FontAwesomeIcons.trophy, label: 'Rank'),
    BottomNavItem(icon: FontAwesomeIcons.bell, label: 'Alerts'),
  ];

  void _onNavTap(int index) {
    // Special button opens create post screen as modal
    if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const CreatePostScreen()),
      );
      return;
    }

    setState(() {
      _currentIndex = index > 2 ? index - 1 : index; // Adjust for special button
    });
  }

  int _getNavIndex() {
    // Convert internal index to nav index (accounting for special button)
    return _currentIndex >= 2 ? _currentIndex + 1 : _currentIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),         // 0: Home (nav index 0)
          PricesScreen(),       // 1: Prices (nav index 1)
          LeaderboardScreen(),  // 2: Rank (nav index 3)
          NotificationsScreen(), // 3: Alerts (nav index 4)
        ],
      ),
      bottomNavigationBar: GlassBottomNav(
        currentIndex: _getNavIndex(),
        onTap: _onNavTap,
        items: _navItems,
      ),
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

    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !categoryState.isLoading) {
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
            // Add bottom padding for the navigation bar
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
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

    // Loading state for initial load
    if (filteredPosts.isEmpty && categoryState.isLoading) {
      return const SliverFillRemaining( // Use SliverFillRemaining to center content
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading posts...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 24.0,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == filteredPosts.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: PostCard(key: ValueKey(filteredPosts[index].id), post: filteredPosts[index]),
            );
          },
          childCount: filteredPosts.length + (categoryState.isLoading && categoryState.currentPage > 0 ? 1 : 0),
        ),
      ),
    );
  }
}

// --- HEADER BAR ---
class HeaderBar extends StatefulWidget {
  final Function(String) onSearchChanged;
  const HeaderBar({super.key, required this.onSearchChanged});

  @override
  State<HeaderBar> createState() => _HeaderBarState();
}

class _HeaderBarState extends State<HeaderBar> {
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

class _AuthHeaderButton extends ConsumerWidget {
  const _AuthHeaderButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final userProfile = ref.watch(currentUserProfileProvider);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    if (isAuthenticated) {
      return InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blueGrey.shade800,
            child: Text(
              userProfile?.username.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      ),
      icon: const FaIcon(FontAwesomeIcons.rightToBracket, size: 14),
      label: isSmallScreen ? const Text('Sign In') : const Text('Sign In / Join'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.1),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
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
                  value: selectedCategory.isEmpty ? null : selectedCategory,
                  hint: Row(
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
                  items: categories.map((category) {
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
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
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
              icon: FaIcon(
                FontAwesomeIcons.xmark,
                size: 16,
                color: Colors.grey.shade400,
              ),
              tooltip: 'Clear filter',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
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

        return Container(
          height: 40.0,
          color: const Color.fromRGBO(31, 41, 55, 0.8),
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 8 : 16, 
            vertical: 8,
          ),
          child: trendingAsync.when(
            loading: () => const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (err, stack) => const Center(
              child: FaIcon(FontAwesomeIcons.triangleExclamation, color: Colors.red, size: 16),
            ),
            data: (stats) => isSmallScreen
                ? Row(
                    children: [
                      FaIcon(FontAwesomeIcons.fire, color: theme.colorScheme.secondary, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${getIconForCategory(stats.trendingCategory)} ${stats.trendingCategory}',
                          style: TextStyle(
                            color: theme.colorScheme.secondary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FaIcon(FontAwesomeIcons.trophy, color: theme.colorScheme.primary, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          stats.mostPopularPostTitle,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      FaIcon(FontAwesomeIcons.fire, color: theme.colorScheme.secondary, size: 16),
                      const SizedBox(width: 8),
                      const Text('Trending:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Text(
                        '${stats.trendingCategory} ${getIconForCategory(stats.trendingCategory)}',
                        style: TextStyle(color: theme.colorScheme.secondary),
                      ),
                      const Spacer(),
                      FaIcon(FontAwesomeIcons.arrowTrendUp, color: theme.colorScheme.primary, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          stats.mostPopularPostTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
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

// --- POST CARD ---
class PostCard extends ConsumerStatefulWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _isCommentsExpanded = false;

  Future<void> _castVote(BuildContext context, WidgetRef ref, String voteType) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw 'User not authenticated';
      }

      // Prevent self-voting
      if (widget.post.userId == userId) {
        throw 'You cannot vote on your own posts.';
      }

      // Try RPC first, fall back to direct upsert if it fails
      try {
        await supabase.rpc('cast_user_vote', params: {
          'post_id_in': widget.post.id,
          'user_id_in': userId,
          'vote_type_in': voteType,
        });
      } catch (rpcError) {
        // RPC failed (likely doesn't exist), use direct upsert
        logger.w('RPC cast_user_vote failed, using direct upsert: $rpcError');

        // Table uses anonymous_user_id as the main identifier
        await supabase.from('truth_votes').upsert(
          {
            'post_id': widget.post.id,
            'anonymous_user_id': userId,
            'user_id': userId,
            'vote_type': voteType,
            'is_anonymous': true,
          },
          onConflict: 'anonymous_user_id,post_id',
        );
      }

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
      funnyCount: voteStatsAsync.value?.funnyVotes ?? 0,
      isCommentsExpanded: _isCommentsExpanded,
      onToggleComments: isAuthenticated ? () => setState(() => _isCommentsExpanded = !_isCommentsExpanded) : null,
      onFunnyVote: isAuthenticated ? () => _castVote(context, ref, 'funny') : null,
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
            showVoteBreakdown: isAuthenticated,
            onVote: isAuthenticated ? (voteType) => _castVote(context, ref, voteType) : null,
          );
        },
      ),
      commentsWidget: isAuthenticated ? CommentSection(postId: widget.post.id) : null,
      showSignInPrompt: !isAuthenticated,
    );
  }
}



// --- COMMENT SECTION ---
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

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isPostingComment = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw 'Not authenticated';

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
        'anonymous_user_id': userId,
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
          if (!ref.watch(isAuthenticatedProvider))
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                icon: const FaIcon(FontAwesomeIcons.rightToBracket, size: 16),
                label: const Text('Sign in to join the conversation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                  foregroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          else
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
