import 'dart:async';
import 'dart:js' as js;
import 'dart:math' as math;
import 'package:agnonymous_beta/create_post_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- SUPABASE CLIENT ---
final supabase = Supabase.instance.client;

// --- DATA MODELS ---
class Post {
  final String id;
  final String title;
  final String content;
  final String category;
  final DateTime createdAt;
  final int commentCount;
  final int voteCount;

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.createdAt,
    required this.commentCount,
    required this.voteCount,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Untitled',
      content: map['content'] ?? '',
      category: map['category'] ?? 'General',
      createdAt: DateTime.parse(map['created_at']),
      commentCount: map['comment_count'] ?? 0,
      voteCount: map['vote_count'] ?? 0,
    );
  }
}

class Comment {
  final String id;
  final String content;
  final DateTime createdAt;

  Comment({required this.id, required this.content, required this.createdAt});

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'],
      content: map['content'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class VoteStats {
  final int trueVotes;
  final int partialVotes;
  final int falseVotes;
  final int totalVotes;

  VoteStats({
    required this.trueVotes,
    required this.partialVotes,
    required this.falseVotes,
  }) : totalVotes = trueVotes + partialVotes + falseVotes;

  factory VoteStats.fromMap(Map<String, dynamic> map) {
    return VoteStats(
      trueVotes: (map['true_votes'] ?? 0).toInt(),
      partialVotes: (map['partial_votes'] ?? 0).toInt(),
      falseVotes: (map['false_votes'] ?? 0).toInt(),
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
class PaginatedPostsNotifier extends StateNotifier<PaginatedPostsState> {
  PaginatedPostsNotifier(this.ref) : super(const PaginatedPostsState()) {
    _initRealTime();
    // Load initial posts for "all" category
    loadPostsForCategory('all', isInitial: true);
  }

  final Ref ref;
  final int _pageSize = 50;  // 50 posts per category for better coverage
  RealtimeChannel? _postsChannel;
  RealtimeChannel? _commentsChannel;

  Future<void> loadPostsForCategory(String category, {bool isInitial = false, bool isRefresh = false}) async {
    final categoryState = state.getCategoryState(category);
    
    if (categoryState.isLoading || (!categoryState.hasMore && !isRefresh)) return;

    final pageToLoad = isRefresh || isInitial ? 0 : categoryState.currentPage;

    // Update this category's loading state
    final updatedCategoryStates = Map<String, CategoryPostsState>.from(state.categoryStates);
    updatedCategoryStates[category] = categoryState.copyWith(isLoading: true, error: null);
    state = state.copyWith(categoryStates: updatedCategoryStates);

    try {
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

      // Debug logging
      print('=== CATEGORY PAGINATION DEBUG ===');
      print('Category: $category, Page $pageToLoad: Loaded ${newPosts.length} posts');
      print('Current state: ${categoryState.posts.length} posts, hasMore: ${categoryState.hasMore}');

      // Deduplicate by ID to handle real-time inserts without duplicates
      final Set<String> existingIds = categoryState.posts.map((p) => p.id).toSet();
      final filteredNewPosts = newPosts.where((p) => !existingIds.contains(p.id)).toList();

      final updatedPosts = isInitial
          ? filteredNewPosts  // Initial load: use new posts directly
          : isRefresh 
              ? [...filteredNewPosts, ...categoryState.posts]  // Prepend new for refreshes
              : [...categoryState.posts, ...filteredNewPosts];  // Append for load more

      final newCategoryState = categoryState.copyWith(
        posts: updatedPosts,
        isLoading: false,
        hasMore: newPosts.length == _pageSize,
        currentPage: pageToLoad + 1,
      );

      final finalCategoryStates = Map<String, CategoryPostsState>.from(state.categoryStates);
      finalCategoryStates[category] = newCategoryState;
      state = state.copyWith(categoryStates: finalCategoryStates);

      print('Updated state: ${newCategoryState.posts.length} posts, hasMore: ${newCategoryState.hasMore}');
      print('=== END CATEGORY PAGINATION DEBUG ===');
    } catch (e) {
      print('Error loading posts for category $category: $e');
      final errorCategoryStates = Map<String, CategoryPostsState>.from(state.categoryStates);
      errorCategoryStates[category] = categoryState.copyWith(isLoading: false, error: e.toString());
      state = state.copyWith(categoryStates: errorCategoryStates);
    }
  }

  void loadMoreForCategory(String category) => loadPostsForCategory(category);
  Future<void> refreshCategory(String category) => loadPostsForCategory(category, isRefresh: true);
  
  // Method to ensure category is loaded
  void ensureCategoryLoaded(String category) {
    if (!state.categoryStates.containsKey(category)) {
      loadPostsForCategory(category, isInitial: true);
    }
  }

  void _initRealTime() {
    _postsChannel = supabase
        .channel('posts_all_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            print('Posts table changed: ${payload.eventType}');
            // Refresh all loaded categories
            for (final category in state.categoryStates.keys) {
              refreshCategory(category);
            }
          },
        )
        .subscribe();

    _commentsChannel = supabase
        .channel('comments_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'comments',
          callback: (payload) {
            print('Comment change detected: ${payload.eventType}');
            // Refresh all loaded categories to update comment counts
            for (final category in state.categoryStates.keys) {
              refreshCategory(category);
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _postsChannel?.unsubscribe();
    _commentsChannel?.unsubscribe();
    super.dispose();
  }
}

// --- RIVERPOD PROVIDERS ---
// Provider Declaration
final paginatedPostsProvider = StateNotifierProvider<PaginatedPostsNotifier, PaginatedPostsState>((ref) {
  return PaginatedPostsNotifier(ref);
});

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
      controller.add(VoteStats(trueVotes: 0, partialVotes: 0, falseVotes: 0));
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
      print('=== DEBUG: Global Stats ===');
      print('Posts: ${stats.totalPosts}, Votes: ${stats.totalVotes}, Comments: ${stats.totalComments}');
      print('=== End Global Stats ===');
      controller.add(stats);
    } catch (e) {
      print('Error fetching global stats: $e');
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
    
    print('Trending stats raw response: $response');
    
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
    print('Error fetching trending stats: $e');
    return TrendingStats(
      trendingCategory: 'General',
      mostPopularPostTitle: 'No posts yet',
    );
  }
});

// --- MAIN APP ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Try to get from JavaScript window.ENV first (Firebase hosting)
    String? supabaseUrl;
    String? supabaseAnonKey;
    
    try {
      final env = js.context['ENV'] as js.JsObject?;
      if (env != null) {
        supabaseUrl = env['SUPABASE_URL'] as String?;
        supabaseAnonKey = env['SUPABASE_ANON_KEY'] as String?;
      }
    } catch (e) {
      // JS interop failed, try other methods
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

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    
    await supabase.auth.signInAnonymously();
    
    runApp(const ProviderScope(child: AgnonymousApp()));
  } catch (e) {
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
      home: const HomeScreen(),
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
    final currentCategory = selectedCategory.isNotEmpty ? selectedCategory.toLowerCase() : 'all';
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
          final currentCategory = selectedCategory.isNotEmpty ? selectedCategory.toLowerCase() : 'all';
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );
        },
        backgroundColor: theme.colorScheme.primary,
        child: const FaIcon(FontAwesomeIcons.plus, color: Colors.white),
      ),
    );
  }
}

// --- POST FEED ---


class PostFeedSliver extends ConsumerWidget {
  final String searchQuery;
  final String selectedCategory;
  const PostFeedSliver({super.key, this.searchQuery = '', this.selectedCategory = ''});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsState = ref.watch(paginatedPostsProvider);
    
    // Determine which category to load
    final currentCategory = selectedCategory.isNotEmpty ? selectedCategory.toLowerCase() : 'all';
    
    // Ensure the category is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paginatedPostsProvider.notifier).ensureCategoryLoaded(currentCategory);
    });
    
    final categoryState = postsState.getCategoryState(currentCategory);

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
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filteredPosts = filteredPosts.where((post) =>
          post.title.toLowerCase().contains(query) ||
          post.content.toLowerCase().contains(query) ||
          post.category.toLowerCase().contains(query)).toList();
    }

    // Empty state
    if (filteredPosts.isEmpty && !categoryState.isLoading) {
      String emptyMessage;
      IconData emptyIcon;
      
      if (searchQuery.isNotEmpty) {
        if (currentCategory == 'all') {
          emptyMessage = 'No posts found for "$searchQuery"';
        } else {
          emptyMessage = 'No posts found in "$selectedCategory" for "$searchQuery"';
        }
        emptyIcon = FontAwesomeIcons.magnifyingGlass;
      } else if (currentCategory != 'all') {
        emptyMessage = 'No posts yet in "$selectedCategory"\nBe the first to post!';
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
              child: PostCard(post: filteredPosts[index]),
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

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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
            Text(
              'Agnonymous',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
              ),
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
            const GlobalStatsHeader(),
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
                onChanged: widget.onSearchChanged,
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
          onChanged: widget.onSearchChanged,
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

// --- CATEGORY CHIPS ---
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
    'General',
    'Other'
  ];

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 16,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Filter by Category:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 12),
              if (selectedCategory.isNotEmpty)
                TextButton(
                  onPressed: () => onCategoryChanged(''),
                  child: const Text(
                    'Show All',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((category) {
              final isSelected = selectedCategory == category;
              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(getIconForCategory(category)),
                    const SizedBox(width: 6),
                    Text(category),
                  ],
                ),
                selected: isSelected,
                onSelected: (selected) {
                  onCategoryChanged(selected ? category : '');
                },
                selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                checkmarkColor: theme.colorScheme.primary,
                backgroundColor: Colors.grey.withOpacity(0.1),
                side: BorderSide(
                  color: isSelected 
                      ? theme.colorScheme.primary 
                      : Colors.grey.withOpacity(0.3),
                ),
              );
            }).toList(),
          ),
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
class PostCard extends StatefulWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isCommentsExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blueGrey.withOpacity(0.2),
                  child: Text(
                    getIconForCategory(widget.post.category),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.category,
                        style: TextStyle(
                          color: Colors.blueGrey.shade200,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat.yMMMd().add_jm().format(widget.post.createdAt),
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.post.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.post.content,
              style: TextStyle(color: Colors.grey.shade300),
            ),
            const SizedBox(height: 16),
            TruthMeter(postId: widget.post.id),
            const SizedBox(height: 16),
            _buildActionRow(),
            if (_isCommentsExpanded)
              CommentSection(postId: widget.post.id),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    final isSmallScreen = MediaQuery.of(context).size.width < 450;
    
    return isSmallScreen
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VoteButtons(postId: widget.post.id),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => _isCommentsExpanded = !_isCommentsExpanded),
                icon: FaIcon(
                  _isCommentsExpanded ? FontAwesomeIcons.chevronUp : FontAwesomeIcons.message,
                  size: 16,
                ),
                label: Text('${widget.post.commentCount} Comments'),
                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade400),
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 3,
                child: VoteButtons(postId: widget.post.id),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _isCommentsExpanded = !_isCommentsExpanded),
                icon: FaIcon(
                  _isCommentsExpanded ? FontAwesomeIcons.chevronUp : FontAwesomeIcons.message,
                  size: 16,
                ),
                label: Text('${widget.post.commentCount} Comments'),
                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade400),
              ),
            ],
          );
  }
}

// --- TRUTH METER ---
class TruthMeter extends ConsumerWidget {
  final String postId;
  const TruthMeter({super.key, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voteStatsAsync = ref.watch(voteStatsProvider(postId));
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 600 ? 600.0 : screenWidth - 32;

    return voteStatsAsync.when(
      loading: () => const SizedBox(
        height: 28,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, stack) => Text(
        'Could not load votes',
        style: TextStyle(color: Colors.red.shade400),
      ),
      data: (stats) {
        if (stats.totalVotes == 0) {
          return const Center(
            child: Text(
              'No votes yet. Be the first to cast one!',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          );
        }
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Community Truth Meter',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  children: [
                    if (stats.trueVotes > 0)
                      _MeterSegment(
                        value: stats.trueVotes / stats.totalVotes,
                        color: theme.colorScheme.primary,
                      ),
                    if (stats.partialVotes > 0)
                      _MeterSegment(
                        value: stats.partialVotes / stats.totalVotes,
                        color: theme.colorScheme.secondary,
                      ),
                    if (stats.falseVotes > 0)
                      _MeterSegment(
                        value: stats.falseVotes / stats.totalVotes,
                        color: theme.colorScheme.error,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _buildLabel('True', stats.trueVotes, stats.totalVotes, theme.colorScheme.primary),
                  _buildLabel('Partial', stats.partialVotes, stats.totalVotes, theme.colorScheme.secondary),
                  _buildLabel('False', stats.falseVotes, stats.totalVotes, theme.colorScheme.error),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabel(String label, int votes, int total, Color color) {
    final percentage = (votes / total * 100).toStringAsFixed(0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ($percentage%)',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        ),
      ],
    );
  }
}

class _MeterSegment extends StatelessWidget {
  final double value;
  final Color color;
  const _MeterSegment({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: (value * 100).toInt(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        height: 10,
        color: color,
      ),
    );
  }
}

// --- VOTE BUTTONS ---
class VoteButtons extends ConsumerStatefulWidget {
  final String postId;
  const VoteButtons({super.key, required this.postId});

  @override
  ConsumerState<VoteButtons> createState() => _VoteButtonsState();
}

class _VoteButtonsState extends ConsumerState<VoteButtons> {
  bool _isVoting = false;
  String? _pendingVote;

  Future<void> _castVote(String voteType) async {
    if (_isVoting) return;
    
    setState(() {
      _isVoting = true;
      _pendingVote = voteType;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw 'User not authenticated';
      }

      await supabase.rpc('cast_user_vote', params: {
        'post_id_in': widget.postId,
        'user_id_in': userId,
        'vote_type_in': voteType,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vote "$voteType" cast successfully!'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error casting vote';
        if (e.toString().contains('rate limit')) {
          errorMessage = 'Too many votes! Please wait a minute.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVoting = false;
          _pendingVote = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 400;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildVoteButton(
          voteType: 'true',
          icon: FontAwesomeIcons.check,
          label: 'True',
          color: theme.colorScheme.primary,
          isCompact: isCompact,
        ),
        const SizedBox(width: 4),
        _buildVoteButton(
          voteType: 'partial',
          icon: FontAwesomeIcons.triangleExclamation,
          label: 'Partial',
          color: theme.colorScheme.secondary,
          isCompact: isCompact,
        ),
        const SizedBox(width: 4),
        _buildVoteButton(
          voteType: 'false',
          icon: FontAwesomeIcons.xmark,
          label: 'False',
          color: theme.colorScheme.error,
          isCompact: isCompact,
        ),
      ],
    );
  }

  Widget _buildVoteButton({
    required String voteType,
    required IconData icon,
    required String label,
    required Color color,
    required bool isCompact,
  }) {
    final isLoading = _isVoting && _pendingVote == voteType;
    
    return ElevatedButton(
      onPressed: _isVoting ? null : () => _castVote(voteType),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.8),
        foregroundColor: Colors.white,
        minimumSize: isCompact ? const Size(60, 32) : null,
        padding: isCompact 
            ? const EdgeInsets.symmetric(horizontal: 8)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: isLoading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : isCompact
              ? FaIcon(icon, size: 14)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(icon, size: 14),
                    const SizedBox(width: 6),
                    Text(label),
                  ],
                ),
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

      await supabase.from('comments').insert({
        'post_id': widget.postId,
        'anonymous_user_id': userId,
        'content': content,
      });
      
      _commentController.clear();
      
      // Force refresh of posts to update comment count (invalidate + refresh for emulator reliability)
      ref.invalidate(postsProvider);
      ref.refresh(postsProvider);
      
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
                    child: ListTile(
                      title: Text(comment.content),
                      subtitle: Text(
                        DateFormat.yMMMd().add_jm().format(comment.createdAt),
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
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
    );
  }
}