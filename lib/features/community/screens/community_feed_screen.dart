import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../create_post_screen.dart';
import 'create_scam_report_screen.dart';
import '../board_theme.dart';
import '../community_categories.dart';
import '../providers/community_providers.dart';
import '../widgets/post_feed_sliver.dart';
import '../widgets/category_chips.dart';
import '../widgets/trending_section.dart';
import '../widgets/ambient_background.dart';
import '../../../services/anonymous_id_service.dart';
import '../providers/watch_provider.dart';
import '../../../core/utils/globals.dart';
import '../providers/auth_provider.dart';
import '../../../models/user_profile.dart';
import '../widgets/auth_dialog.dart';

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
    if (selectedCategory == 'C.U.N.T.' || selectedCategory == 'Scams') {
      final auth = ref.read(authProvider);
      if (auth.user == null || auth.user!.isAnonymous) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => AuthDialog(ref: ref),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must sign in or register to publish a C.U.N.T. report.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const CreateScamReportScreen(),
        ),
      );
      return;
    }

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
      body: AmbientBackground(
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
              if (AnonymousIdService.authInitError != null)
                SliverToBoxAdapter(
                  child: _AuthErrorBanner(error: AnonymousIdService.authInitError!),
                ),
              SliverPersistentHeader(
                pinned: false,
                delegate: TrendingSectionDelegate(),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: CategoryChipsDelegate(
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
                child: SizedBox(height: 96),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'post_comment_btn',
        onPressed: _openCreatePost,
        backgroundColor: BoardColors.green,
        foregroundColor: const Color(0xFF0F160F),
        elevation: 12,
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
    final isScamCategory = widget.selectedCategory == 'C.U.N.T.' || widget.selectedCategory == 'Scams';
    final room = widget.selectedCategory.isEmpty
        ? 'All Rooms'
        : (isScamCategory ? 'C.U.N.T. Registry' : '${widget.selectedCategory} Room');

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.26),
                    blurRadius: 22,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: BoardColors.field,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: BoardColors.line),
                          ),
                          alignment: Alignment.center,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                              semanticLabel:
                                  'Agnonymous anonymous farmer field mark',
                            ),
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
                          style: IconButton.styleFrom(
                            backgroundColor: BoardColors.clay,
                            foregroundColor: BoardColors.amber,
                          ),
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
                          style: IconButton.styleFrom(
                            backgroundColor: BoardColors.clay,
                            foregroundColor: BoardColors.amber,
                          ),
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
                        const SizedBox(width: 8),
                        const _IdentityMenuButton(),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(room, style: BoardText.roomTitle),
                    const SizedBox(height: 8),
                    Text(
                      isScamCategory
                          ? 'Chronic Unpaid Network Therapy registry. Farmer-reported transaction non-payment and crop trade fraud. Verified account required to post.'
                          : 'Anonymous field reports, questions, and photos from the prairie.',
                      style: BoardText.body.copyWith(
                        color: BoardColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isScamCategory) const _CuntSortSelector(),
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
        fillColor: const Color(0xFF303229),
        hintStyle: const TextStyle(color: BoardColors.muted),
        labelStyle: const TextStyle(color: BoardColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: BoardColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: BoardColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: BoardColors.green),
        ),
      ),
      style: BoardText.body,
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

class _IdentityMenuButton extends ConsumerWidget {
  const _IdentityMenuButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final isSignedIn = ref.watch(isSignedInProvider);
    final profile = auth.profile;

    final Widget menuButtonIcon;
    final Color buttonColor;
    final Color buttonBg;

    if (isSignedIn && profile != null) {
      menuButtonIcon = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(profile.levelInfo.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          const FaIcon(FontAwesomeIcons.circleCheck, size: 10, color: BoardColors.sky),
        ],
      );
      buttonColor = BoardColors.sky;
      buttonBg = BoardColors.sky.withValues(alpha: 0.16);
    } else {
      menuButtonIcon = const FaIcon(FontAwesomeIcons.circleUser, size: 16);
      buttonColor = BoardColors.muted;
      buttonBg = BoardColors.clay;
    }

    return PopupMenuButton<String>(
      tooltip: 'Identity options',
      offset: const Offset(0, 48),
      color: const Color(0xFF25271F), // BoardColors.paper
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BoardColors.line),
      ),
      onSelected: (value) async {
        if (value == 'reset') {
          await _showResetDialog(context, ref);
        } else if (value == 'signin') {
          _showAuthDialog(context, ref);
        } else if (value == 'profile' && profile != null) {
          _showProfileDialog(context, ref, profile);
        } else if (value == 'signout') {
          await ref.read(authProvider.notifier).signOut();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Returned to anonymous mode.'),
                backgroundColor: BoardColors.green,
              ),
            );
          }
        }
      },
      itemBuilder: (context) => isSignedIn
          ? [
              PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.user,
                      size: 14,
                      color: BoardColors.sky,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'My Profile',
                      style: TextStyle(color: BoardColors.ink),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'signout',
                child: Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.arrowRightFromBracket,
                      size: 14,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Sign Out',
                      style: TextStyle(color: BoardColors.ink),
                    ),
                  ],
                ),
              ),
            ]
          : [
              PopupMenuItem<String>(
                value: 'signin',
                child: Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.userPlus,
                      size: 14,
                      color: BoardColors.green,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Sign In / Register',
                      style: TextStyle(color: BoardColors.ink),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'reset',
                child: Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.arrowRotateLeft,
                      size: 14,
                      color: BoardColors.amber,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Reset anonymous identity',
                      style: TextStyle(color: BoardColors.ink),
                    ),
                  ],
                ),
              ),
            ],
      child: IgnorePointer(
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: buttonBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: buttonColor.withValues(alpha: 0.28)),
          ),
          alignment: Alignment.center,
          child: menuButtonIcon,
        ),
      ),
    );
  }

  void _showAuthDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AuthDialog(ref: ref),
    );
  }

  void _showProfileDialog(BuildContext context, WidgetRef ref, UserProfile profile) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _ProfileDialog(profile: profile),
    );
  }

  Future<void> _showResetDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange.shade400,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Reset Identity?',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const Text(
          'A new anonymous device id will be generated. Your watched threads '
          'and any device-only history will be cleared. Posts, comments, and '
          'votes already published remain on the board.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Reset',
              style: TextStyle(
                color: Color(0xFF84CC16),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await AnonymousIdService.resetAnonymousId();
      await ref.read(watchedThreadsProvider.notifier).clearAll();
    } catch (e) {
      logger.w('Anonymous id reset failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reset failed. Try again in a moment.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anonymous identity reset.'),
          backgroundColor: Color(0xFF84CC16),
        ),
      );
    }
  }
}



class _ProfileDialog extends StatelessWidget {
  final UserProfile profile;
  const _ProfileDialog({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            
            // Avatar Level Circle
            Container(
              height: 76,
              width: 76,
              decoration: BoxDecoration(
                color: BoardColors.sky.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: BoardColors.sky.withValues(alpha: 0.3), width: 3),
              ),
              alignment: Alignment.center,
              child: Text(
                profile.levelInfo.emoji,
                style: const TextStyle(fontSize: 36),
              ),
            ),
            const SizedBox(height: 14),

            // Username with Verified Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  profile.username,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const FaIcon(
                  FontAwesomeIcons.circleCheck,
                  size: 16,
                  color: BoardColors.sky,
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Level Title Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: BoardColors.clay,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: BoardColors.line),
              ),
              child: Text(
                'Level ${profile.reputationLevel}: ${profile.levelInfo.title}',
                style: GoogleFonts.inter(
                  color: BoardColors.sky,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Reputation & Progress
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Reputation Points',
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                    ),
                    Text(
                      '${profile.reputationPoints} Points',
                      style: GoogleFonts.outfit(
                        color: BoardColors.sky,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: profile.progressToNextLevel,
                    backgroundColor: const Color(0xFF374151),
                    valueColor: const AlwaysStoppedAnimation<Color>(BoardColors.sky),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${profile.pointsToNextLevel} points to Level ${profile.reputationLevel + 1} (${ReputationLevelInfo.fromLevel(profile.reputationLevel + 1).title})',
                  style: GoogleFonts.inter(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stats row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem('Posts', profile.postCount),
                  Container(height: 24, width: 1, color: Colors.white12),
                  _statItem('Comments', profile.commentCount),
                  Container(height: 24, width: 1, color: Colors.white12),
                  _statItem('Votes', profile.voteCount),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Perks Unlocked Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2633).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: BoardColors.sky.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unlocked Perks:',
                    style: GoogleFonts.inter(
                      color: BoardColors.sky,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: BoardColors.sky, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Active Vote Weight: ${profile.voteWeight.toStringAsFixed(1)}x',
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  ...profile.levelInfo.perks.map((perk) => Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt, color: BoardColors.sky, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                perk,
                                style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }
}

class CategoryChipsDelegate extends SliverPersistentHeaderDelegate {
  final String selectedCategory;
  final Function(String) onCategoryChanged;

  const CategoryChipsDelegate({
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return CategoryChips(
      selectedCategory: selectedCategory,
      onCategoryChanged: onCategoryChanged,
    );
  }

  @override
  double get maxExtent => 62.0;

  @override
  double get minExtent => 62.0;

  @override
  bool shouldRebuild(covariant CategoryChipsDelegate oldDelegate) {
    return oldDelegate.selectedCategory != selectedCategory;
  }
}

class _CuntSortSelector extends ConsumerWidget {
  const _CuntSortSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSort = ref.watch(cuntSortProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Row(
        children: [
          Text(
            'Sort by:  ',
            style: BoardText.meta.copyWith(color: BoardColors.muted),
          ),
          _SortChip(
            label: 'Latest',
            selected: activeSort == CuntSortMode.latest,
            onTap: () => ref.read(cuntSortProvider.notifier).set(CuntSortMode.latest),
          ),
          const SizedBox(width: 8),
          _SortChip(
            label: 'Highest Loss',
            selected: activeSort == CuntSortMode.highestLoss,
            onTap: () => ref.read(cuntSortProvider.notifier).set(CuntSortMode.highestLoss),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = BoardColors.amber;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? activeColor.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? activeColor : BoardColors.line,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: BoardText.meta.copyWith(
            color: selected ? activeColor : BoardColors.muted,
          ),
        ),
      ),
    );
  }
}

class _AuthErrorBanner extends StatelessWidget {
  final String error;

  const _AuthErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.3),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Authentication Initialization Failed',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'The app could not connect to Firebase Auth safely. Voting, comments, and post features will be blocked. \n\nError details: $error\n\nIf this is a custom domain, please ensure that this domain is added to the "Authorized domains" list in Firebase Console > Authentication > Settings.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
