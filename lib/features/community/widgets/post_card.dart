import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/globals.dart';
import '../../../core/models/models.dart';
import '../../../models/user_profile.dart' show TruthMeterStatus;
import '../../../providers/auth_provider.dart';
import '../../../services/anonymous_id_service.dart';
import '../../../services/rate_limiter.dart';
import '../../../widgets/luxury_post_card.dart';
import '../../../widgets/truth_meter.dart' as truth_widget;
import '../providers/community_providers.dart';
import 'comment_section.dart';

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
        'thumbs_up': '\u{1F44D}',
        'partial': '\u{1F914}',
        'thumbs_down': '\u{1F44E}',
        'funny': '\u{1F602}',
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
