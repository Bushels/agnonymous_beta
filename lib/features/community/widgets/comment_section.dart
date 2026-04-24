import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/models/post.dart';
import '../../../core/utils/globals.dart';
import '../../../app/theme.dart';
import '../../../services/anonymous_id_service.dart';
import '../../../services/analytics_service.dart';
import '../../../services/rate_limiter.dart';
import '../board_theme.dart';
import '../providers/community_providers.dart';
import '../providers/watch_provider.dart';

class CommentSection extends ConsumerStatefulWidget {
  final Post post;

  const CommentSection({super.key, required this.post});

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
      final sanitizedContent = sanitizeInput(content);
      if (sanitizedContent.isEmpty) {
        throw 'Invalid comment content';
      }

      await supabase.from('comments').insert({
        'post_id': widget.post.id,
        'anonymous_user_id': await AnonymousIdService.getAnonymousId(),
        'content': sanitizedContent,
        'is_anonymous': true,
      });

      await ref.read(watchedThreadsProvider.notifier).watchDetails(
            postId: widget.post.id,
            title: widget.post.title,
            category: widget.post.category,
            lastSeenCommentCount: widget.post.commentCount + 1,
          );

      AnalyticsService.instance.logCommentPosted();
      commentRateLimiter.recordComment();
      _commentController.clear();

      final currentCategories =
          ref.read(paginatedPostsProvider).categoryStates.keys.toList();
      for (final category in currentCategories) {
        ref.read(paginatedPostsProvider.notifier).refreshCategory(category);
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
    final commentsAsync = ref.watch(commentsProvider(widget.post.id));

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          commentsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (err, stack) => Text(
              'Error loading comments: $err',
              style: const TextStyle(color: BoardColors.monette),
            ),
            data: (comments) {
              if (comments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text(
                      'No comments yet. Be the first.',
                      style: BoardText.meta,
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
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: BoardColors.paper,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: BoardColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.masks,
                              size: 14,
                              color: BoardColors.muted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Anonymous',
                              style: TextStyle(
                                color: BoardColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat.yMMMd()
                                  .add_jm()
                                  .format(comment.createdAt),
                              style: TextStyle(
                                color: BoardColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          comment.content,
                          style: BoardText.body,
                        ),
                      ],
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
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: 'Add anonymous comment...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: BoardColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: BoardColors.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide:
                          const BorderSide(color: BoardColors.green, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
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
                      tooltip: 'Post comment',
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
