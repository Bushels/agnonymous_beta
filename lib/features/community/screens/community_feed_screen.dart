import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../create_post_screen.dart';
import '../board_theme.dart';
import '../community_categories.dart';
import '../providers/community_providers.dart';
import '../widgets/post_feed_sliver.dart';
import '../widgets/category_chips.dart';
import '../widgets/trending_section.dart';

// --- HOME SCREEN ---
class HomeScreen extends ConsumerStatefulWidget {
  final String initialCategory;

  const HomeScreen({
    super.key,
    this.initialCategory = '',
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String searchQuery = '';
  late String selectedCategory;
  bool isSearching = false;
  bool isRefreshing = false;
  DateTime? lastRefreshedAt;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.initialCategory;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final currentCategory =
        selectedCategory.isNotEmpty ? selectedCategory : 'all';
    final postsState = ref.read(paginatedPostsProvider);
    final categoryState = postsState.getCategoryState(currentCategory);

    // Trigger load more when near bottom, not loading, and has more posts
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !categoryState.isLoading &&
        categoryState.hasMore) {
      ref
          .read(paginatedPostsProvider.notifier)
          .loadMoreForCategory(currentCategory);
    }
  }

  Future<void> _refreshCurrentCategory() async {
    final currentCategory =
        selectedCategory.isNotEmpty ? selectedCategory : 'all';
    setState(() => isRefreshing = true);
    await ref
        .read(paginatedPostsProvider.notifier)
        .refreshCategory(currentCategory);
    if (!mounted) return;
    setState(() {
      isRefreshing = false;
      lastRefreshedAt = DateTime.now();
    });
  }

  void _openCreatePost() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(
          initialCategory: selectedCategory.isNotEmpty
              ? selectedCategory
              : defaultBoardCategory,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BoardColors.prairie,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFE9B8),
              BoardColors.prairie,
              Color(0xFFEAF5D4),
            ],
          ),
        ),
        child: RefreshIndicator(
          color: BoardColors.monette,
          onRefresh: _refreshCurrentCategory,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: _RoomHero(
                  selectedCategory: selectedCategory,
                  isRefreshing: isRefreshing,
                  lastRefreshedAt: lastRefreshedAt,
                  onRefresh: _refreshCurrentCategory,
                  onSearchChanged: (query) {
                    setState(() {
                      searchQuery = query;
                      isSearching = query.isNotEmpty;
                    });
                  },
                ),
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
              const SliverToBoxAdapter(
                child: SizedBox(height: 118),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'post_comment_btn',
        onPressed: _openCreatePost,
        backgroundColor: BoardColors.monette,
        foregroundColor: Colors.white,
        elevation: 10,
        tooltip: 'Post anonymously',
        child: const FaIcon(FontAwesomeIcons.penToSquare, size: 20),
      ),
    );
  }
}

class _RoomHero extends StatefulWidget {
  final String selectedCategory;
  final bool isRefreshing;
  final DateTime? lastRefreshedAt;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onSearchChanged;

  const _RoomHero({
    required this.selectedCategory,
    required this.isRefreshing,
    required this.lastRefreshedAt,
    required this.onRefresh,
    required this.onSearchChanged,
  });

  @override
  State<_RoomHero> createState() => _RoomHeroState();
}

class _RoomHeroState extends State<_RoomHero> {
  bool searchOpen = false;
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.selectedCategory.isEmpty
        ? 'All Rooms'
        : '${widget.selectedCategory} Room';

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Container(
              decoration: BoxDecoration(
                color: BoardColors.paper.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: BoardColors.line),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3C2F16).withValues(alpha: 0.12),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 42,
                        width: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF2D2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: BoardColors.line),
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          'assets/images/agnonymous_mark.svg',
                          width: 30,
                          height: 30,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Agnonymous',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: BoardColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const _LiveDot(),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _statusText(),
                                    overflow: TextOverflow.ellipsis,
                                    style: BoardText.meta,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => setState(() => searchOpen = true),
                        icon: const FaIcon(
                          FontAwesomeIcons.magnifyingGlass,
                          size: 16,
                        ),
                        tooltip: 'Search posts',
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed:
                            widget.isRefreshing ? null : widget.onRefresh,
                        icon: widget.isRefreshing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const FaIcon(
                                FontAwesomeIcons.arrowsRotate,
                                size: 16,
                              ),
                        tooltip: 'Refresh board',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(room, style: BoardText.roomTitle),
                  const SizedBox(height: 8),
                  Text(
                    'Anonymous agriculture discussion. No sign up. No pricing board. Just the thread.',
                    style: BoardText.body.copyWith(color: BoardColors.muted),
                  ),
                  if (searchOpen) ...[
                    const SizedBox(height: 16),
                    _searchField(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: controller,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search the board...',
        prefixIcon: const Icon(FontAwesomeIcons.magnifyingGlass, size: 16),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            controller.clear();
            widget.onSearchChanged('');
            setState(() => searchOpen = false);
          },
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: BoardColors.line),
        ),
      ),
      onChanged: widget.onSearchChanged,
    );
  }

  String _statusText() {
    if (widget.isRefreshing) return 'refreshing now';
    final refreshedAt = widget.lastRefreshedAt;
    if (refreshedAt == null) return 'live board';
    final difference = DateTime.now().difference(refreshedAt);
    if (difference.inMinutes < 1) return 'updated just now';
    return 'updated ${difference.inMinutes}m ago';
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: BoardColors.green,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: BoardColors.green.withValues(alpha: 0.45),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}
