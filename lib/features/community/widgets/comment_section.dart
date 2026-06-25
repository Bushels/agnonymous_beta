import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/models/post.dart';
import '../../../core/utils/globals.dart';
import '../../../services/anonymous_id_service.dart';
import '../../../services/analytics_service.dart';
import '../../../services/rate_limiter.dart';
import '../board_theme.dart';
import '../providers/community_providers.dart';
import '../providers/watch_provider.dart';
import 'posting_as_sheet.dart';
import '../providers/auth_provider.dart';
import 'auth_dialog.dart';

class CommentSection extends ConsumerStatefulWidget {
  final Post post;

  const CommentSection({super.key, required this.post});

  @override
  ConsumerState<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends ConsumerState<CommentSection> {
  final _commentController = TextEditingController();
  bool _isPostingComment = false;
  String _alias = AnonymousIdService.defaultDisplayName;
  bool _hasCustomAlias = false;
  bool _isAnonymousComment = true;

  @override
  void initState() {
    super.initState();
    _loadAlias();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadAlias() async {
    final profile = ref.read(authProvider).profile;
    if (profile != null) {
      if (!mounted) return;
      setState(() {
        _alias = profile.username;
        _hasCustomAlias = true;
        _isAnonymousComment = false;
      });
      return;
    }

    final saved = await AnonymousIdService.getSavedDisplayName();
    if (!mounted) return;
    setState(() {
      _alias = saved ?? AnonymousIdService.defaultDisplayName;
      _hasCustomAlias = saved != null;
      _isAnonymousComment = true;
    });
  }

  Future<void> _openAliasEditor() async {
    final profile = ref.read(authProvider).profile;
    final result = await showPostingAsSheet(
      context,
      currentAlias: _alias,
      hasCustomAlias: _hasCustomAlias,
      userProfile: profile,
      initialIsAnonymous: _isAnonymousComment,
    );
    if (result == null) return;

    if (result == 'show_auth') {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => AuthDialog(ref: ref),
      );
      return;
    }

    if (result.remember && result.isAnonymous) {
      await AnonymousIdService.setSavedDisplayName(result.alias);
    }

    if (!mounted) return;
    setState(() {
      _alias = result.alias;
      _hasCustomAlias = result.hasCustomAlias;
      _isAnonymousComment = result.isAnonymous;
    });
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

      final commentDoc = firestore.collection('comments').doc();
      final anonymousId = await AnonymousIdService.getAnonymousId();
      
      final auth = ref.read(authProvider);
      final isRegistered = auth.user != null && !auth.user!.isAnonymous;
      final commentAsRegistered = isRegistered && !_isAnonymousComment;

      await firestore.runTransaction((transaction) async {
        transaction.set(commentDoc, {
          'post_id': widget.post.id,
          'anonymous_user_id': anonymousId,
          'content': sanitizedContent,
          'is_anonymous': !commentAsRegistered,
          'author_username': commentAsRegistered ? auth.profile?.username : _alias,
          'author_verified': commentAsRegistered,
          'is_deleted': false,
          'created_at': FieldValue.serverTimestamp(),
        });

        // Increment comment count on the post
        final postRef = firestore.collection('posts').doc(widget.post.id);
        transaction.update(postRef, {
          'comment_count': FieldValue.increment(1),
        });

        // Increment global stats comment count
        final statsRef = firestore.collection('stats').doc('global');
        transaction.set(
          statsRef,
          {
            'total_comments': FieldValue.increment(1),
          },
          SetOptions(merge: true),
        );
      });

      await ref.read(watchedThreadsProvider.notifier).watchDetails(
            postId: widget.post.id,
            title: widget.post.title,
            category: widget.post.category,
            lastSeenCommentCount: widget.post.commentCount + 1,
          );

      if (commentAsRegistered) {
        await ref.read(authProvider.notifier).addReputationPoints(2, 'comment');
      }

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
                      color: const Color(0xFF25271F),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: BoardColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            FaIcon(
                              comment.isAnonymous
                                  ? FontAwesomeIcons.userSecret
                                  : FontAwesomeIcons.user,
                              size: 11,
                              color: BoardColors.muted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              comment.authorDisplay,
                              style: TextStyle(
                                color: comment.authorVerified
                                    ? BoardColors.sky
                                    : BoardColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (comment.authorVerified) ...[
                              const SizedBox(width: 4),
                              const FaIcon(
                                FontAwesomeIcons.circleCheck,
                                size: 11,
                                color: BoardColors.sky,
                              ),
                            ],
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
          Align(
            alignment: Alignment.centerLeft,
            child: _buildPostingAsChip(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: _hasCustomAlias
                        ? 'Comment as $_alias...'
                        : 'Add anonymous comment...',
                    filled: true,
                    fillColor: const Color(0xFF303229),
                    hintStyle: const TextStyle(color: BoardColors.muted),
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
                  style: BoardText.body,
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
                      color: BoardColors.green,
                      tooltip: 'Post comment',
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostingAsChip() {
    final auth = ref.watch(authProvider);
    final profile = auth.profile;
    final isRegistered = profile != null && !_isAnonymousComment;

    final Color accentColor = isRegistered ? BoardColors.sky : BoardColors.green;
    final bool isHighlighted = isRegistered || _hasCustomAlias;

    return InkWell(
      onTap: _openAliasEditor,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF303229),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isHighlighted
                ? accentColor.withValues(alpha: 0.45)
                : BoardColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              isRegistered
                  ? FontAwesomeIcons.user
                  : _hasCustomAlias
                      ? FontAwesomeIcons.user
                      : FontAwesomeIcons.userSecret,
              size: 12,
              color: isHighlighted ? accentColor : BoardColors.muted,
            ),
            const SizedBox(width: 6),
            Row(
              children: [
                Text(
                  isRegistered
                      ? 'Commenting as ${profile.username}'
                      : _hasCustomAlias
                          ? 'Commenting as $_alias'
                          : 'Commenting anonymously',
                  style: BoardText.meta.copyWith(
                    color: BoardColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (isRegistered) ...[
                  const SizedBox(width: 4),
                  const FaIcon(
                    FontAwesomeIcons.circleCheck,
                    size: 11,
                    color: BoardColors.sky,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    profile.levelInfo.emoji,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 6),
            const FaIcon(
              FontAwesomeIcons.pen,
              size: 10,
              color: BoardColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}
