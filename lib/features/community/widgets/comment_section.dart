import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/globals.dart';
import '../../../app/theme.dart';
import '../../../services/anonymous_id_service.dart';
import '../../../services/analytics_service.dart';
import '../../../services/rate_limiter.dart';
import '../../../providers/auth_provider.dart';
import '../providers/community_providers.dart';

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
