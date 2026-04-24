import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/utils/globals.dart';
import '../board_theme.dart';
import '../providers/community_providers.dart';
import 'post_card.dart';
import '../../../core/widgets/skeleton_loader.dart';

class PostFeedSliver extends ConsumerStatefulWidget {
  final String searchQuery;
  final String selectedCategory;

  const PostFeedSliver({
    super.key,
    this.searchQuery = '',
    this.selectedCategory = '',
  });

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCurrentCategory();
      });
    }
  }

  void _loadCurrentCategory() {
    final currentCategory =
        widget.selectedCategory.isNotEmpty ? widget.selectedCategory : 'all';
    if (_lastCategory != currentCategory) {
      _lastCategory = currentCategory;
      logger.d('Loading category: $currentCategory');
      ref
          .read(paginatedPostsProvider.notifier)
          .ensureCategoryLoaded(currentCategory);
    }
  }

  @override
  Widget build(BuildContext context) {
    final postsState = ref.watch(paginatedPostsProvider);

    // Determine which category to display
    final currentCategory =
        widget.selectedCategory.isNotEmpty ? widget.selectedCategory : 'all';
    final categoryState = postsState.getCategoryState(currentCategory);

    logger.d(
        'Building feed for category: $currentCategory, posts: ${categoryState.posts.length}');

    final width = MediaQuery.of(context).size.width;
    final horizontalPadding = width > 900 ? (width - 820) / 2 : 16.0;

    // Error state
    if (categoryState.error != null) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FaIcon(
                  FontAwesomeIcons.triangleExclamation,
                  color: BoardColors.monette,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text('Error loading posts: ${categoryState.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref
                      .read(paginatedPostsProvider.notifier)
                      .refreshCategory(currentCategory),
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
      filteredPosts = filteredPosts
          .where((post) =>
              post.title.toLowerCase().contains(query) ||
              post.content.toLowerCase().contains(query) ||
              post.category.toLowerCase().contains(query))
          .toList();
    }

    // Apply sort mode
    final sortMode = ref.watch(feedSortModeProvider);
    if (sortMode == FeedSortMode.active) {
      // Sort by comment activity, then by created_at for ties.
      filteredPosts = List.from(filteredPosts)
        ..sort((a, b) {
          final commentCompare = b.commentCount.compareTo(a.commentCount);
          if (commentCompare != 0) return commentCompare;
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
          emptyMessage =
              'No posts found in "${widget.selectedCategory}" for "${widget.searchQuery}"';
        }
        emptyIcon = FontAwesomeIcons.magnifyingGlass;
      } else if (currentCategory != 'all') {
        emptyMessage = widget.selectedCategory == 'Monette'
            ? 'No Monette posts yet.\nStart the board.'
            : 'No posts yet in "${widget.selectedCategory}"\nBe the first to post!';
        emptyIcon = FontAwesomeIcons.seedling;
      } else {
        emptyMessage = 'No posts yet\nBe the first to post!';
        emptyIcon = FontAwesomeIcons.seedling;
      }

      return SliverFillRemaining(
        // Use SliverFillRemaining to center content
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(emptyIcon, size: 56, color: BoardColors.green),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: BoardText.title.copyWith(fontSize: 20),
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
          vertical: 14.0,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: PostSkeletonCard(),
            ),
            childCount: 3, // Show 3 skeleton cards
          ),
        ),
      );
    }

    // Determine if we should show a footer (loading or end of posts)
    final bool showLoadingFooter =
        categoryState.isLoading && categoryState.currentPage > 0;
    final bool showEndOfPostsFooter = !categoryState.hasMore &&
        filteredPosts.isNotEmpty &&
        !categoryState.isLoading;
    final bool hasFooter = showLoadingFooter || showEndOfPostsFooter;

    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 14.0,
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
                        FaIcon(FontAwesomeIcons.circleCheck,
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
              child: PostCard(
                key: ValueKey(filteredPosts[index].id),
                post: filteredPosts[index],
              ),
            );
          },
          childCount: filteredPosts.length + (hasFooter ? 1 : 0),
        ),
      ),
    );
  }
}
