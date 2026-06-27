import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/globals.dart';
import '../../../core/models/models.dart';
import '../../../models/user_profile.dart' show TruthMeterStatus;
import '../../../services/anonymous_id_service.dart';
import '../../../services/rate_limiter.dart';
import '../providers/community_providers.dart';
import '../providers/watch_provider.dart';
import 'board_post_card.dart';
import 'board_truth_meter.dart';
import 'comment_section.dart';
import '../../../models/user_profile.dart';

// --- POST CARD ---
class PostCard extends ConsumerStatefulWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _isCommentsExpanded = false;
  bool _isCurrentUserAuthor = false;

  @override
  void initState() {
    super.initState();
    _checkOwnership();
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.userId != widget.post.userId) {
      _checkOwnership();
    }
  }

  void _checkOwnership() async {
    final userId = firebaseAuth.currentUser?.uid;
    if (userId == null) return;

    if (widget.post.userId == userId) {
      if (mounted) setState(() => _isCurrentUserAuthor = true);
      return;
    }

    // Check posts_private for anonymous posts
    try {
      final privateDoc =
          await firestore.collection('posts_private').doc(widget.post.id).get();
      if (privateDoc.exists && mounted) {
        setState(() => _isCurrentUserAuthor = true);
      } else {
        if (mounted) setState(() => _isCurrentUserAuthor = false);
      }
    } catch (_) {
      // Permission denied or doesn't exist -> not owner
      if (mounted) setState(() => _isCurrentUserAuthor = false);
    }
  }

  /// Check if current user owns this post
  bool get _isOwner => _isCurrentUserAuthor;

  void _toggleComments() {
    final willExpand = !_isCommentsExpanded;
    setState(() => _isCommentsExpanded = willExpand);
    if (willExpand) {
      ref.read(watchedThreadsProvider.notifier).markSeen(widget.post);
    }
  }

  Future<void> _toggleWatch() async {
    final watches = ref.read(watchedThreadsProvider);
    final wasWatching = watches.isWatching(widget.post.id);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    await ref.read(watchedThreadsProvider.notifier).toggle(widget.post);

    if (!mounted) return;
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          wasWatching
              ? 'Thread removed from your watch list'
              : 'Watching this thread on this device',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
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
            final userId = firebaseAuth.currentUser?.uid;
            if (userId == null) throw 'Not authenticated';

            // Sanitize the addition
            final sanitizedAddition = sanitizeInput(addition);
            if (sanitizedAddition.isEmpty) {
              throw 'Please enter content to add';
            }

            // Append to original content with separator
            final newContent =
                '${widget.post.content}\n\n---\n**Edit:** $sanitizedAddition';

            // Update post in Firestore
            await firestore.collection('posts').doc(widget.post.id).update({
              'content': newContent,
              'edited_at': FieldValue.serverTimestamp(),
              'edit_count': FieldValue.increment(1),
            });

            // Refresh posts to show updated content
            final currentCategories =
                ref.read(paginatedPostsProvider).categoryStates.keys.toList();
            for (final category in currentCategories) {
              ref
                  .read(paginatedPostsProvider.notifier)
                  .refreshCategory(category);
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

    if (result == true && context.mounted) {
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
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.red.shade400, size: 28),
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
            child:
                Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
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

    if (confirmed == true && context.mounted) {
      await _deletePost(context);
    }
  }

  /// Perform soft delete of post
  Future<void> _deletePost(BuildContext context) async {
    try {
      final userId = firebaseAuth.currentUser?.uid;
      if (userId == null) throw 'Not authenticated';

      // Soft delete in Firestore
      await firestore.collection('posts').doc(widget.post.id).update({
        'is_deleted': true,
        'deleted_at': FieldValue.serverTimestamp(),
        'deleted_by': userId,
      });

      // Refresh posts to remove deleted post
      final currentCategories =
          ref.read(paginatedPostsProvider).categoryStates.keys.toList();
      for (final category in currentCategories) {
        ref.read(paginatedPostsProvider.notifier).refreshCategory(category);
      }

      if (context.mounted) {
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
      if (context.mounted) {
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
      final userId = firebaseAuth.currentUser?.uid;
      if (userId == null) throw 'Not authenticated';

      // Restore in Firestore
      await firestore.collection('posts').doc(widget.post.id).update({
        'is_deleted': false,
        'deleted_at': null,
        'deleted_by': null,
      });

      // Refresh posts to show restored post
      final currentCategories =
          ref.read(paginatedPostsProvider).categoryStates.keys.toList();
      for (final category in currentCategories) {
        ref.read(paginatedPostsProvider.notifier).refreshCategory(category);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post restored!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _castVote(
      BuildContext context, WidgetRef ref, String voteType) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final anonId = await AnonymousIdService.getAnonymousId();

      // Check client-side rate limiting
      final rateLimiter = RateLimiter();
      final rateLimitError = rateLimiter.canVote(widget.post.id);
      if (rateLimitError != null) {
        throw rateLimitError;
      }

      // Check self-voting
      if (_isCurrentUserAuthor) {
        throw 'You cannot vote on your own post';
      }

      final voteRef =
          firestore.collection('votes').doc('${anonId}_${widget.post.id}');

      // Write vote document to Firestore directly
      await voteRef.set({
        'post_id': widget.post.id,
        'anonymous_user_id': anonId,
        'vote_type': voteType,
        'created_at': FieldValue.serverTimestamp(),
      });

      // Record successful vote for rate limiting
      rateLimiter.recordVote(widget.post.id);

      // Trigger light haptic on success
      await HapticFeedback.lightImpact();

      // Refresh categories to pick up the vote count change
      final currentCategories =
          ref.read(paginatedPostsProvider).categoryStates.keys.toList();
      for (final category in currentCategories) {
        ref.read(paginatedPostsProvider.notifier).refreshCategory(category);
      }

      final voteEmoji = {
            'thumbs_up': '\u{1F44D}',
            'partial': '\u{1F914}',
            'thumbs_down': '\u{1F44E}',
          }[voteType] ??
          '';

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('$voteEmoji Vote cast successfully!'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Trigger heavy haptic on error
      await HapticFeedback.heavyImpact();
      String errorMessage = 'Error casting vote';
      final errorStr = e.toString();

      if (errorStr.contains('rate limit')) {
        errorMessage = 'Too many votes! Please wait a minute.';
      } else if (errorStr.contains('own posts')) {
        errorMessage = 'You cannot vote on your own posts.';
      } else if (errorStr.contains('Access Denied')) {
        errorMessage =
            'Access Denied: ${errorStr.split('Access Denied:').last.trim()}';
      } else if (errorStr.contains('unique_user_post_vote') ||
          errorStr.contains('duplicate key')) {
        // Vote already exists - this shouldn't happen with upsert but handle it
        errorMessage = 'Vote updated!';
      } else {
        // Clean up Postgres error messages
        errorMessage = errorStr
            .replaceAll('PostgrestException(message:', '')
            .replaceAll('details:', '')
            .trim();
        if (errorMessage.length > 100) {
          errorMessage = 'Error casting vote. Please try again.';
        }
      }

      final isError = !errorMessage.contains('updated');
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor:
              isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final voteStatsAsync = ref.watch(voteStatsProvider(widget.post.id));
    final watchedState = ref.watch(watchedThreadsProvider);
    final isWatched = watchedState.isWatching(widget.post.id);
    final newCommentCount = watchedState.unreadFor(widget.post);

    return BoardPostCard(
      title: widget.post.title,
      content: widget.post.content,
      category: widget.post.category,
      categoryEmoji: getIconForCategory(widget.post.category),
      monetteArea: widget.post.monetteArea,
      createdAt: widget.post.createdAt,
      authorUsername: widget.post.authorUsername,
      authorVerified: widget.post.authorVerified,
      isAnonymous: widget.post.isAnonymous,
      commentCount: widget.post.commentCount,
      imageUrl: widget.post.imageUrl,
      imageUrls: widget.post.imageUrls,
      isCommentsExpanded: _isCommentsExpanded,
      isWatched: isWatched,
      newCommentCount: newCommentCount,
      onToggleComments: _toggleComments,
      onToggleWatch: _toggleWatch,
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
            child: Text('Error loading votes: $err',
                style: const TextStyle(color: Colors.red)),
          ),
        ),
        data: (stats) {
          final directionalVotes = stats.thumbsUpVotes + stats.thumbsDownVotes;
          final truthScore = directionalVotes > 0
              ? (stats.thumbsUpVotes / directionalVotes * 100).clamp(0.0, 100.0)
              : 50.0;
          final boardSignal =
              stats.thumbsUpVotes + stats.partialVotes + stats.thumbsDownVotes;

          TruthMeterStatus status;
          if (boardSignal == 0) {
            status = TruthMeterStatus.unrated;
          } else if (directionalVotes == 0) {
            status = TruthMeterStatus.questionable;
          } else if (truthScore >= 70) {
            status = TruthMeterStatus.verifiedCommunity;
          } else if (truthScore >= 55) {
            status = TruthMeterStatus.likelyTrue;
          } else if (truthScore >= 40) {
            status = TruthMeterStatus.partiallyTrue;
          } else if (truthScore >= 30) {
            status = TruthMeterStatus.questionable;
          } else {
            status = TruthMeterStatus.rumour;
          }

          return BoardTruthMeter(
            status: status,
            score: truthScore,
            thumbsUp: stats.thumbsUpVotes,
            thumbsDown: stats.thumbsDownVotes,
            neutral: stats.partialVotes,
            onVote: (voteType) => _castVote(context, ref, voteType),
          );
        },
      ),
      commentsWidget: CommentSection(post: widget.post),
      showSignInPrompt: false,
      // Edit/Delete support (edit = append only, delete = 5 second window)
      isOwner: _isOwner,
      wasEdited: widget.post.wasEdited,
      onEdit: _isOwner ? () => _showAddToPostDialog(context) : null,
      // Only allow deletion within 5 seconds of post creation
      onDelete: _isOwner && _canDeletePost()
          ? () => _showDeleteConfirmation(context)
          : null,
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
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
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
                    color: const Color(0xFF84CC16).withValues(alpha: 0.1),
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
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.orange.shade300, size: 20),
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
                color: Colors.black.withValues(alpha: 0.2),
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
                fillColor: Colors.black.withValues(alpha: 0.3),
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
                  onPressed:
                      _isSaving ? null : () => Navigator.pop(context, false),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
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
                          if (context.mounted) {
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
