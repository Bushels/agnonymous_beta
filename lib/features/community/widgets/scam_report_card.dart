import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/globals.dart';
import '../../../core/models/post.dart';
import '../../../models/user_profile.dart' show TruthMeterStatus;
import '../../../services/anonymous_id_service.dart';
import '../../../services/rate_limiter.dart';
import '../board_theme.dart';
import '../providers/community_providers.dart';
import '../providers/watch_provider.dart';
import '../providers/auth_provider.dart';
import 'board_truth_meter.dart';
import 'comment_section.dart';

class ScamReportCard extends ConsumerStatefulWidget {
  final Post post;

  const ScamReportCard({
    super.key,
    required this.post,
  });

  @override
  ConsumerState<ScamReportCard> createState() => _ScamReportCardState();
}

class _ScamReportCardState extends ConsumerState<ScamReportCard> {
  bool _isCommentsExpanded = false;

  bool get _isOwner {
    final userId = firebaseAuth.currentUser?.uid;
    return userId != null && widget.post.userId == userId;
  }

  bool _canDeletePost() {
    final timeSinceCreation = DateTime.now().difference(widget.post.createdAt);
    return timeSinceCreation.inSeconds <= 5;
  }

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

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: const Text('Delete Post?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deletePost(context);
    }
  }

  Future<void> _deletePost(BuildContext context) async {
    try {
      final userId = firebaseAuth.currentUser?.uid;
      if (userId == null) throw 'Not authenticated';

      await firestore.collection('posts').doc(widget.post.id).update({
        'is_deleted': true,
        'deleted_at': FieldValue.serverTimestamp(),
        'deleted_by': userId,
      });

      await firestore.collection('stats').doc('global').update({
        'total_posts': FieldValue.increment(-1),
      });

      final currentCategories =
          ref.read(paginatedPostsProvider).categoryStates.keys.toList();
      for (final category in currentCategories) {
        ref.read(paginatedPostsProvider.notifier).refreshCategory(category);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted'),
            backgroundColor: Color(0xFF25271F),
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

  Future<void> _castVote(
      BuildContext context, WidgetRef ref, String voteType) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final anonId = await AnonymousIdService.getAnonymousId();
      final profile = ref.read(authProvider).profile;
      final weight = profile != null ? profile.voteWeight.round() : 1;

      final rateLimiter = RateLimiter();
      final rateLimitError = rateLimiter.canVote(widget.post.id);
      if (rateLimitError != null) {
        throw rateLimitError;
      }

      if (widget.post.userId == anonId) {
        throw 'You cannot vote on your own post';
      }

      final voteRef = firestore.collection('votes').doc('${anonId}_${widget.post.id}');
      final postRef = firestore.collection('posts').doc(widget.post.id);
      final statsRef = firestore.collection('stats').doc('global');

      bool isNewVote = false;

      await firestore.runTransaction((transaction) async {
        final voteSnapshot = await transaction.get(voteRef);
        final postSnapshot = await transaction.get(postRef);

        if (!postSnapshot.exists) {
          throw 'Post not found';
        }

        final postData = postSnapshot.data() as Map<String, dynamic>;
        final postAuthorId = postData['user_id'] ?? postData['anonymous_user_id'];
        if (postAuthorId == anonId) {
          throw 'You cannot vote on your own post';
        }

        String? oldVoteType;
        if (voteSnapshot.exists) {
          final oldVoteData = voteSnapshot.data() as Map<String, dynamic>;
          oldVoteType = oldVoteData['vote_type'] as String?;
        }

        transaction.set(voteRef, {
          'post_id': widget.post.id,
          'anonymous_user_id': anonId,
          'vote_type': voteType,
          'created_at': FieldValue.serverTimestamp(),
        });

        final postUpdates = <String, dynamic>{};
        if (oldVoteType != null) {
          if (oldVoteType != voteType) {
            postUpdates['${oldVoteType}_count'] = FieldValue.increment(-weight);
            postUpdates['${voteType}_count'] = FieldValue.increment(weight);
          }
        } else {
          isNewVote = true;
          postUpdates['${voteType}_count'] = FieldValue.increment(weight);
          postUpdates['vote_count'] = FieldValue.increment(1);

          transaction.set(
            statsRef,
            {
              'total_votes': FieldValue.increment(1),
            },
            SetOptions(merge: true),
          );
        }

        if (postUpdates.isNotEmpty) {
          transaction.update(postRef, postUpdates);
        }
      });

      rateLimiter.recordVote(widget.post.id);

      if (isNewVote && profile != null) {
        await ref.read(authProvider.notifier).addReputationPoints(1, 'vote');
      }

      await HapticFeedback.lightImpact();

      final currentCategories =
          ref.read(paginatedPostsProvider).categoryStates.keys.toList();
      for (final category in currentCategories) {
        ref.read(paginatedPostsProvider.notifier).refreshCategory(category);
      }

      final voteEmoji = {
        'thumbs_up': '\u{1F44D}',
        'partial': '\u{1F914}',
        'thumbs_down': '\u{1F44E}',
      }[voteType] ?? '';

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('$voteEmoji Vote cast successfully!'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      await HapticFeedback.heavyImpact();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: BoardColors.paper,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: BoardColors.line),
        ),
      ),
    );
  }

  void _showImageDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency(decimalDigits: 0);
    const alertColor = Color(0xFFEF4444);
    final voteStatsAsync = ref.watch(voteStatsProvider(widget.post.id));
    final watchedState = ref.watch(watchedThreadsProvider);
    final isWatched = watchedState.isWatching(widget.post.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: BoardColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: alertColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: alertColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _toggleComments,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alert Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: alertColor.withValues(alpha: 0.12),
              child: Row(
                children: [
                  const FaIcon(FontAwesomeIcons.triangleExclamation, color: Color(0xFFEF4444), size: 14),
                  const SizedBox(width: 8),
                  Text(
                    'VERIFIED USER C.U.N.T. REPORT',
                    style: BoardText.meta.copyWith(
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  if (widget.post.lossAmount != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        currencyFormat.format(widget.post.lossAmount),
                        style: BoardText.meta.copyWith(
                          color: const Color(0xFFFCA5A5),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Meta
                  Text(widget.post.title, style: BoardText.title.copyWith(fontSize: 21)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Reported by: ${widget.post.authorUsername ?? "Verified Farmer"}',
                        style: BoardText.meta.copyWith(color: BoardColors.muted),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•  ${DateFormat.yMMMd().format(widget.post.createdAt)}',
                        style: BoardText.meta.copyWith(color: BoardColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Scammer Contact Details Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BoardColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const FaIcon(FontAwesomeIcons.solidAddressCard, color: BoardColors.amber, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'ACCUSED DETAILS',
                              style: BoardText.meta.copyWith(
                                color: BoardColors.amber,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: BoardColors.line, height: 16),
                        _buildContactRow(
                          context,
                          icon: FontAwesomeIcons.user,
                          label: 'Name',
                          value: widget.post.scammerName ?? 'Unknown',
                        ),
                        if (widget.post.scammerCompany != null && widget.post.scammerCompany!.isNotEmpty)
                          _buildContactRow(
                            context,
                            icon: FontAwesomeIcons.building,
                            label: 'Company',
                            value: widget.post.scammerCompany!,
                          ),
                        if (widget.post.scammerPhone != null && widget.post.scammerPhone!.isNotEmpty)
                          _buildContactRow(
                            context,
                            icon: FontAwesomeIcons.phone,
                            label: 'Phone',
                            value: widget.post.scammerPhone!,
                            copyable: true,
                          ),
                        if (widget.post.scammerEmail != null && widget.post.scammerEmail!.isNotEmpty)
                          _buildContactRow(
                            context,
                            icon: FontAwesomeIcons.envelope,
                            label: 'Email',
                            value: widget.post.scammerEmail!,
                            copyable: true,
                          ),
                        _buildContactRow(
                          context,
                          icon: FontAwesomeIcons.locationDot,
                          label: 'Location',
                          value: widget.post.scamLocation ?? 'Unknown',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Loss details
                  Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.boxOpen, color: BoardColors.muted, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        'Loss Item: ',
                        style: BoardText.body.copyWith(color: BoardColors.muted, fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Text(
                          widget.post.lossItem ?? 'Not specified',
                          style: BoardText.body.copyWith(color: BoardColors.ink),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Description Content
                  Text(
                    widget.post.content,
                    style: BoardText.body.copyWith(height: 1.45),
                  ),

                  // Proof Images Gallery
                  if (widget.post.imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.post.imageUrls.length,
                        itemBuilder: (context, index) {
                          final imageUrl = widget.post.imageUrls[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () => _showImageDialog(context, imageUrl),
                              borderRadius: BorderRadius.circular(8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imageUrl,
                                  width: 120,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 120,
                                    height: 90,
                                    color: BoardColors.line,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.broken_image_rounded, color: BoardColors.muted),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // Action Row & Truth Meter
                  const SizedBox(height: 16),
                  _buildActionsRow(isWatched),
                  
                  const SizedBox(height: 12),
                  voteStatsAsync.when(
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
                      } else if (truthScore >= 80) {
                        status = TruthMeterStatus.likelyTrue;
                      } else if (truthScore >= 50) {
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
                ],
              ),
            ),

            if (_isCommentsExpanded)
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF1D1F18),
                  border: Border(top: BorderSide(color: BoardColors.line)),
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: CommentSection(post: widget.post),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool copyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: FaIcon(icon, size: 12, color: BoardColors.muted),
            ),
          ),
          Text(
            '$label: ',
            style: BoardText.meta.copyWith(color: BoardColors.muted),
          ),
          Expanded(
            child: Text(
              value,
              style: BoardText.meta.copyWith(color: BoardColors.ink),
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: () => _copyToClipboard(context, value, label),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                child: FaIcon(FontAwesomeIcons.copy, size: 12, color: BoardColors.amber),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionsRow(bool isWatched) {
    return Row(
      children: [
        const FaIcon(FontAwesomeIcons.comment, size: 14, color: BoardColors.muted),
        const SizedBox(width: 6),
        Text(
          '${widget.post.commentCount} Comments',
          style: BoardText.meta.copyWith(color: BoardColors.muted),
        ),
        const Spacer(),
        IconButton(
          icon: FaIcon(
            isWatched ? FontAwesomeIcons.solidEye : FontAwesomeIcons.eye,
            size: 14,
            color: isWatched ? BoardColors.amber : BoardColors.muted,
          ),
          onPressed: _toggleWatch,
        ),
        if (_isOwner && _canDeletePost())
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.trashCan, size: 14, color: Color(0xFFEF4444)),
            onPressed: () => _showDeleteConfirmation(context),
          ),
      ],
    );
  }
}
