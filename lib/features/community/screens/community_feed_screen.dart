import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../create_post_screen.dart';
import '../../../screens/market/market_dashboard_screen.dart';
import '../../../widgets/ticker/fertilizer_ticker.dart';
import '../../../widgets/ticker/fertilizer_price_modal.dart';
import '../providers/community_providers.dart';
import '../widgets/post_feed_sliver.dart';
import '../widgets/header_bar.dart';
import '../widgets/category_chips.dart';
import '../widgets/trending_section.dart';

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
