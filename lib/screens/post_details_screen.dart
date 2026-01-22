import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../widgets/luxury_post_card.dart';
import '../widgets/truth_meter.dart';

class PostDetailsScreen extends ConsumerStatefulWidget {
  final String postId;
  final Post? initialPost;

  const PostDetailsScreen({
    super.key,
    required this.postId,
    this.initialPost,
  });

  @override
  ConsumerState<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends ConsumerState<PostDetailsScreen> {
  late Future<Post?> _postFuture;

  @override
  void initState() {
    super.initState();
    _postFuture = _loadPost();
  }

  Future<Post?> _loadPost() async {
    if (widget.initialPost != null) return widget.initialPost;

    try {
      final response = await supabase
          .from('posts')
          .select()
          .eq('id', widget.postId)
          .single();
      return Post.fromMap(response);
    } catch (e) {
      logger.e('Error loading post: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Post Details',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<Post?>(
        future: _postFuture,
        initialData: widget.initialPost,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data == null) {
            return Center(
              child: Text(
                'Post not found',
                style: GoogleFonts.inter(color: Colors.grey),
              ),
            );
          }

          final post = snapshot.data!;
          final commentsAsync = ref.watch(commentsProvider(post.id));

          return SingleChildScrollView(
            child: Column(
              children: [
                LuxuryPostCard(
                  title: post.title,
                  content: post.content,
                  category: post.category,
                  categoryEmoji: getIconForCategory(post.category),
                  createdAt: post.createdAt,
                  authorUsername: post.authorUsername,
                  authorVerified: post.authorVerified,
                  isAnonymous: post.isAnonymous,
                  truthMeterWidget: TruthMeter(
                    status: post.truthMeterStatus,
                    score: post.truthMeterScore,
                    voteCount: post.voteCount,
                    thumbsUp: post.thumbsUpCount,
                    thumbsDown: post.thumbsDownCount,
                    partial: post.partialCount,
                    funny: post.funnyCount,
                  ),
                  commentCount: post.commentCount,
                  funnyCount: post.funnyCount,
                  isCommentsExpanded: true,
                  commentsWidget: commentsAsync.when(
                    data: (comments) => _buildCommentsList(comments),
                    loading: () => const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (err, stack) => Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Error loading comments',
                        style: TextStyle(color: Colors.red[400]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommentsList(List<Comment> comments) {
    if (comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No comments yet',
            style: GoogleFonts.inter(color: Colors.grey[500]),
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    comment.authorDisplay,
                    style: GoogleFonts.inter(
                      color: Colors.grey[300],
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (comment.authorBadge != null) ...[
                    const SizedBox(width: 4),
                    Text(comment.authorBadge!),
                  ],
                  const Spacer(),
                  Text(
                    _formatTimeAgo(comment.createdAt),
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                comment.content,
                style: GoogleFonts.inter(
                  color: Colors.grey[400],
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat.MMMd().format(dateTime);
    }
  }
}
