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
import 'auth_dialog.dart';

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
  bool _isCurrentUserAuthor = false;
  bool _isLoading = false;
  Map<String, dynamic>? _privateDetails;
  bool _loadingDetails = false;

  @override
  void initState() {
    super.initState();
    _checkOwnership();
  }

  @override
  void didUpdateWidget(ScamReportCard oldWidget) {
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
      if (mounted) {
        setState(() => _isCurrentUserAuthor = true);
        _loadPrivateDetails();
      }
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
      if (mounted) setState(() => _isCurrentUserAuthor = false);
    }
    _loadPrivateDetails();
  }

  void _loadPrivateDetails() async {
    final auth = ref.read(authProvider);
    final isEmailVerified = auth.user != null &&
        !auth.user!.isAnonymous &&
        auth.profile?.emailVerified == true;
    final isAdmin = ref.read(isAdminProvider).value ?? false;

    if (isEmailVerified || _isOwner || isAdmin) {
      if (mounted) setState(() => _loadingDetails = true);
      try {
        final doc = await firestore
            .collection('posts')
            .doc(widget.post.id)
            .collection('private')
            .doc('details')
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _privateDetails = doc.data();
            _loadingDetails = false;
          });
        } else {
          if (mounted) setState(() => _loadingDetails = false);
        }
      } catch (e) {
        logger.w('Failed to load private scam details: $e');
        if (mounted) setState(() => _loadingDetails = false);
      }
    }
  }

  bool get _isOwner => _isCurrentUserAuthor;

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

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title:
            const Text('Delete Post?', style: TextStyle(color: Colors.white)),
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
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deletePost();
    }
  }

  Future<void> _deletePost() async {
    try {
      final userId = firebaseAuth.currentUser?.uid;
      if (userId == null) throw 'Not authenticated';

      await firestore.collection('posts').doc(widget.post.id).update({
        'is_deleted': true,
        'deleted_at': FieldValue.serverTimestamp(),
        'deleted_by': userId,
      });

      final currentCategories =
          ref.read(paginatedPostsProvider).categoryStates.keys.toList();
      for (final category in currentCategories) {
        ref.read(paginatedPostsProvider.notifier).refreshCategory(category);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post deleted'),
          backgroundColor: Color(0xFF25271F),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting post: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _castVote(
      BuildContext context, WidgetRef ref, String voteType) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final anonId = await AnonymousIdService.getAnonymousId();

      final rateLimiter = RateLimiter();
      final rateLimitError = rateLimiter.canVote(widget.post.id);
      if (rateLimitError != null) {
        throw rateLimitError;
      }

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

      rateLimiter.recordVote(widget.post.id);

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
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isEmailVerified = auth.user != null &&
        !auth.user!.isAnonymous &&
        auth.profile?.emailVerified == true;
    final isAdmin = ref.watch(isAdminProvider).value ?? false;
    final showDetails = isEmailVerified || _isOwner || isAdmin;

    final List<String> proofImages = widget.post.isScam
        ? (showDetails && _privateDetails != null
            ? List<String>.from(_privateDetails!['image_urls'] ?? [])
            : const <String>[])
        : widget.post.imageUrls;

    if (_privateDetails == null && !_loadingDetails && showDetails) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPrivateDetails();
      });
    }

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
        border:
            Border.all(color: alertColor.withValues(alpha: 0.35), width: 1.5),
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
              color: widget.post.pendingReview
                  ? Colors.orange.withValues(alpha: 0.12)
                  : alertColor.withValues(alpha: 0.12),
              child: Row(
                children: [
                  FaIcon(
                    widget.post.pendingReview
                        ? FontAwesomeIcons.hourglassHalf
                        : FontAwesomeIcons.triangleExclamation,
                    color: widget.post.pendingReview
                        ? Colors.orange
                        : const Color(0xFFEF4444),
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.post.pendingReview
                        ? 'PENDING MODERATION C.U.N.T. REPORT'
                        : (widget.post.authorVerified
                            ? 'VERIFIED USER C.U.N.T. REPORT'
                            : 'REGISTERED USER C.U.N.T. REPORT'),
                    style: BoardText.meta.copyWith(
                      color: widget.post.pendingReview
                          ? Colors.orange
                          : const Color(0xFFEF4444),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  if (widget.post.pendingReview) ...[
                    const SizedBox(width: 8),
                    _buildAdminApprovalButtons(),
                  ],
                  const Spacer(),
                  if (widget.post.lossAmount != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.post.pendingReview
                            ? Colors.orange.withValues(alpha: 0.2)
                            : const Color(0xFFEF4444).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        currencyFormat.format(widget.post.lossAmount),
                        style: BoardText.meta.copyWith(
                          color: widget.post.pendingReview
                              ? const Color(0xFFFCD34D)
                              : const Color(0xFFFCA5A5),
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
                  Text(widget.post.title,
                      style: BoardText.title.copyWith(fontSize: 21)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Reported by: ${widget.post.authorUsername ?? "Verified Farmer"}',
                        style:
                            BoardText.meta.copyWith(color: BoardColors.muted),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•  ${DateFormat.yMMMd().format(widget.post.createdAt)}',
                        style:
                            BoardText.meta.copyWith(color: BoardColors.muted),
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
                    child: showDetails
                        ? (_privateDetails != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const FaIcon(
                                          FontAwesomeIcons.solidAddressCard,
                                          color: BoardColors.amber,
                                          size: 16),
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
                                  const Divider(
                                      color: BoardColors.line, height: 16),
                                  _buildContactRow(
                                    context,
                                    icon: FontAwesomeIcons.solidUser,
                                    label: 'Name',
                                    value: _privateDetails?['scammer_name'] ??
                                        'Unknown',
                                  ),
                                  if (_privateDetails?['scammer_company'] !=
                                          null &&
                                      _privateDetails!['scammer_company']!
                                          .toString()
                                          .isNotEmpty)
                                    _buildContactRow(
                                      context,
                                      icon: FontAwesomeIcons.building,
                                      label: 'Company',
                                      value:
                                          _privateDetails!['scammer_company']!
                                              .toString(),
                                    ),
                                  if (_privateDetails?['scammer_phone'] !=
                                          null &&
                                      _privateDetails!['scammer_phone']!
                                          .toString()
                                          .isNotEmpty)
                                    _buildContactRow(
                                      context,
                                      icon: FontAwesomeIcons.phone,
                                      label: 'Phone',
                                      value: _privateDetails!['scammer_phone']!
                                          .toString(),
                                      copyable: true,
                                    ),
                                  if (_privateDetails?['scammer_email'] !=
                                          null &&
                                      _privateDetails!['scammer_email']!
                                          .toString()
                                          .isNotEmpty)
                                    _buildContactRow(
                                      context,
                                      icon: FontAwesomeIcons.envelope,
                                      label: 'Email',
                                      value: _privateDetails!['scammer_email']!
                                          .toString(),
                                      copyable: true,
                                    ),
                                  _buildContactRow(
                                    context,
                                    icon: FontAwesomeIcons.locationDot,
                                    label: 'Location',
                                    value:
                                        widget.post.scamLocation ?? 'Unknown',
                                  ),
                                ],
                              )
                            : const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: BoardColors.amber),
                                  ),
                                ),
                              ))
                        : Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_rounded,
                                    color: Colors.orange, size: 36),
                                const SizedBox(height: 12),
                                Text(
                                  'Accused PII Hidden',
                                  style: BoardText.title.copyWith(
                                      fontSize: 16, color: Colors.white),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'To prevent abuse and protect privacy, debtor details are only visible to signed-in users with a verified email.',
                                  textAlign: TextAlign.center,
                                  style: BoardText.body.copyWith(
                                      color: BoardColors.muted, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 14),

                  // Loss details
                  Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.boxOpen,
                          color: BoardColors.muted, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        'Loss Item: ',
                        style: BoardText.body.copyWith(
                            color: BoardColors.muted,
                            fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Text(
                          widget.post.lossItem ?? 'Not specified',
                          style:
                              BoardText.body.copyWith(color: BoardColors.ink),
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

                  if (proofImages.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: proofImages.length,
                        itemBuilder: (context, index) {
                          final imageUrl = proofImages[index];
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
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    width: 120,
                                    height: 90,
                                    color: BoardColors.line,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                        Icons.broken_image_rounded,
                                        color: BoardColors.muted),
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
                      final directionalVotes =
                          stats.thumbsUpVotes + stats.thumbsDownVotes;
                      final truthScore = directionalVotes > 0
                          ? (stats.thumbsUpVotes / directionalVotes * 100)
                              .clamp(0.0, 100.0)
                          : 50.0;
                      final boardSignal = stats.thumbsUpVotes +
                          stats.partialVotes +
                          stats.thumbsDownVotes;

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
                child: FaIcon(FontAwesomeIcons.copy,
                    size: 12, color: BoardColors.amber),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionsRow(bool isWatched) {
    return Row(
      children: [
        const FaIcon(FontAwesomeIcons.comment,
            size: 14, color: BoardColors.muted),
        const SizedBox(width: 6),
        Text(
          '${widget.post.commentCount} Comments',
          style: BoardText.meta.copyWith(color: BoardColors.muted),
        ),
        const Spacer(),
        // Hide button
        TextButton.icon(
          onPressed: () {
            ref.read(hiddenPostsProvider.notifier).hidePost(widget.post.id);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Report hidden locally')),
            );
          },
          icon: const Icon(Icons.visibility_off_outlined,
              size: 14, color: BoardColors.muted),
          label: const Text('Hide',
              style: TextStyle(color: BoardColors.muted, fontSize: 11)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 6),
        // Report button (if not owner)
        if (!_isOwner) ...[
          TextButton.icon(
            onPressed: _reportPost,
            icon:
                const Icon(Icons.flag_outlined, size: 14, color: Colors.orange),
            label: const Text('Report',
                style: TextStyle(color: Colors.orange, fontSize: 11)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 6),
        ],
        IconButton(
          icon: FaIcon(
            isWatched ? FontAwesomeIcons.solidEye : FontAwesomeIcons.eye,
            size: 14,
            color: isWatched ? BoardColors.amber : BoardColors.muted,
          ),
          onPressed: _toggleWatch,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        if (_isOwner && _canDeletePost()) ...[
          const SizedBox(width: 6),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.trashCan,
                size: 14, color: Color(0xFFEF4444)),
            onPressed: _showDeleteConfirmation,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ],
    );
  }

  Future<void> _reportPost() async {
    final uid = firebaseAuth.currentUser?.uid;
    if (uid == null) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => AuthDialog(ref: ref),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please sign in or register to submit a report.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: const Text('Report C.U.N.T. Entry?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Flag this entry for moderator review. Reported entries are hidden from your feed immediately and investigated.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Report',
                style: TextStyle(
                    color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    if (_isLoading) return;

    try {
      setState(() => _isLoading = true);
      // Save report document
      await firestore
          .collection('reports')
          .doc('${uid}_${widget.post.id}')
          .set({
        'reporter_id': uid,
        'post_id': widget.post.id,
        'created_at': FieldValue.serverTimestamp(),
      });

      // Hide it locally immediately
      await ref.read(hiddenPostsProvider.notifier).hidePost(widget.post.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Report submitted. Entry has been hidden.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildAdminApprovalButtons() {
    final isAdmin = ref.watch(isAdminProvider).value ?? false;
    if (!isAdmin) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: _approvePost,
          icon: const Icon(Icons.check_circle_outline_rounded,
              color: BoardColors.green, size: 14),
          label: const Text('Approve',
              style: TextStyle(
                  color: BoardColors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: _showDeleteConfirmation,
          icon: const Icon(Icons.delete_outline_rounded,
              color: Color(0xFFEF4444), size: 14),
          label: const Text('Delete',
              style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Future<void> _approvePost() async {
    if (_isLoading) return;
    try {
      setState(() => _isLoading = true);
      await firestore.collection('posts').doc(widget.post.id).update({
        'pending_review': false,
        'approved_at': FieldValue.serverTimestamp(),
      });

      final currentCategories =
          ref.read(paginatedPostsProvider).categoryStates.keys.toList();
      for (final category in currentCategories) {
        ref.read(paginatedPostsProvider.notifier).refreshCategory(category);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Report approved and published to registry.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to approve report: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
