import 'dart:async';
import 'package:agnonymous_beta/create_post_screen.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg_provider/flutter_svg_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
// Corrected import path for intl package
import 'package:intl/intl.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';

// --- SUPABASE CLIENT ---
final supabase = Supabase.instance.client;

// --- DATA MODELS ---
class Post {
  final String id;
  final String title;
  final String content;
  final String category;
  final DateTime createdAt;
  final int commentCount;

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.createdAt,
    required this.commentCount,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Untitled',
      content: map['content'] ?? '',
      category: map['category'] ?? 'General',
      createdAt: DateTime.parse(map['created_at']),
      commentCount: map['comment_count'] ?? 0,
    );
  }
}

class Comment {
  final String id;
  final String content;
  final DateTime createdAt;

  Comment({required this.id, required this.content, required this.createdAt});

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'],
      content: map['content'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class VoteStats {
  final int trueVotes;
  final int partialVotes;
  final int falseVotes;
  final int totalVotes;

  VoteStats({
    required this.trueVotes,
    required this.partialVotes,
    required this.falseVotes,
  }) : totalVotes = trueVotes + partialVotes + falseVotes;

  factory VoteStats.fromMap(Map<String, dynamic> map) {
    return VoteStats(
      trueVotes: (map['true_votes'] ?? 0).toInt(),
      partialVotes: (map['partial_votes'] ?? 0).toInt(),
      falseVotes: (map['false_votes'] ?? 0).toInt(),
    );
  }
}


// --- DATA PROVIDERS (RIVERPOD) ---
final postsProvider = StreamProvider<List<Post>>((ref) {
  final stream = supabase
      .from('posts')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);

  return stream.map((listOfMaps) {
    return listOfMaps.map((map) => Post.fromMap(map)).toList();
  });
});

final commentsProvider = StreamProvider.family<List<Comment>, String>((ref, postId) {
  final stream = supabase
      .from('comments')
      .stream(primaryKey: ['id'])
      .eq('post_id', postId)
      .order('created_at', ascending: true);

  return stream.map((listOfMaps) {
    return listOfMaps.map((map) => Comment.fromMap(map)).toList();
  });
});

// ** COMPLETELY REWRITTEN VOTE STATS PROVIDER WITH CORRECT SYNTAX **
final voteStatsProvider = StreamProvider.family<VoteStats, String>((ref, postId) {
  final controller = StreamController<VoteStats>();

  Future<void> fetchStats() async {
    try {
      final data = await supabase.rpc('get_post_vote_stats', params: {'post_id_in': postId});
      if (data != null && data.isNotEmpty) {
        controller.add(VoteStats.fromMap(data[0]));
      } else {
        controller.add(VoteStats(trueVotes: 0, partialVotes: 0, falseVotes: 0));
      }
    } catch (e) {
      controller.addError(e);
    }
  }

  // Fetch initial stats
  fetchStats();

  // Create a Realtime channel for all changes on the truth_votes table
  final channel = supabase
      .channel('public:truth_votes:$postId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'truth_votes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'post_id',
          value: postId,
        ),
        callback: (payload) {
          // When a change is detected for our post, re-fetch the stats
          fetchStats();
        },
      )
      .subscribe();

  // Clean up the channel when the provider is disposed
  ref.onDispose(() {
    channel.unsubscribe();
  });

  return controller.stream;
});


// --- MAIN APP SETUP ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    runApp(const ErrorApp(
        message:
            'Supabase URL or Anon Key is missing.\n\nPlease make sure your .env file is set up correctly.'));
    return;
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    await supabase.auth.signInAnonymously();

  } catch (e) {
    runApp(ErrorApp(message: 'Failed to initialize Supabase or Sign In:\n$e'));
    return;
  }
  
  runApp(const ProviderScope(child: AgnonymousApp()));
}

class ErrorApp extends StatelessWidget {
  final String message;
  const ErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF111827),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'FATAL ERROR:\n\n$message',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}

final theme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF84CC16),
  scaffoldBackgroundColor: const Color(0xFF111827),
  textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
  ),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF84CC16),
    secondary: Color(0xFFF59E0B),
    surface: Color(0xFF1F2937),
    error: Color(0xFFEF4444),
  ),
);

class AgnonymousApp extends StatelessWidget {
  const AgnonymousApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agnonymous',
      theme: theme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

// --- UI WIDGETS ---

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: Svg('assets/images/background_pattern.svg'),
            fit: BoxFit.cover,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              floating: true,
              pinned: false,
              snap: true,
              backgroundColor: Color.fromRGBO(17, 24, 39, 0.8),
              title: HeaderBar(),
              automaticallyImplyLeading: false,
              toolbarHeight: 80,
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: TrendingSectionDelegate(),
            ),
            const SliverToBoxAdapter(child: PostFeed()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );
        },
        backgroundColor: theme.colorScheme.primary,
        child: const FaIcon(FontAwesomeIcons.plus, color: Colors.white),
      ),
    );
  }
}

class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              FaIcon(FontAwesomeIcons.hatCowboy,
                  color: theme.colorScheme.primary, size: 30),
              const SizedBox(width: 12),
              Text('Agnonymous',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold, fontSize: 24)),
            ],
          ),
          if (MediaQuery.of(context).size.width > 600)
            Row(
              children: [
                _buildSearchField(),
                const SizedBox(width: 20),
                const GlobalStatsHeader(),
              ],
            )
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      width: 200,
      height: 40,
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search posts...',
          prefixIcon:
              const Icon(FontAwesomeIcons.magnifyingGlass, size: 16),
          filled: true,
          fillColor: Colors.black.withAlpha(51),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class GlobalStatsHeader extends StatelessWidget {
  const GlobalStatsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatItem(label: 'Posts', value: '1,234'),
        SizedBox(width: 24),
        _StatItem(label: 'Votes', value: '5,678'),
        SizedBox(width: 24),
        _StatItem(label: 'Comments', value: '987'),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class TrendingSectionDelegate extends SliverPersistentHeaderDelegate {
  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 40.0,
      color: const Color.fromRGBO(31, 41, 55, 0.8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FaIcon(FontAwesomeIcons.fire, color: theme.colorScheme.secondary, size: 16),
          const SizedBox(width: 8),
          const Text('Trending:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Text('Chemicals 🧪',
              style: TextStyle(color: theme.colorScheme.secondary)),
          const Spacer(),
          FaIcon(FontAwesomeIcons.arrowTrendUp, color: theme.colorScheme.primary, size: 16),
          const SizedBox(width: 8),
          const Flexible(
            child: Text(
              'Unreported pesticide use...',
              style: TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 40.0;
  @override
  double get minExtent => 40.0;
  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) => false;
}

class PostFeed extends ConsumerWidget {
  const PostFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsyncValue = ref.watch(postsProvider);

    return LayoutBuilder(builder: (context, constraints) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: constraints.maxWidth > 800 ? (constraints.maxWidth - 800) / 2 : 16.0,
          vertical: 24.0,
        ),
        child: postsAsyncValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (posts) {
            if (posts.isEmpty) {
              return const Center(
                child: Text(
                  'No posts yet. Be the first!',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final post = posts[index];
                return PostCard(post: post);
              },
            );
          },
        ),
      );
    });
  }
}

class PostCard extends StatefulWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isCommentsExpanded = false;

  String _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'farming': return '🚜';
      case 'livestock': return '🐄';
      case 'ranching': return '🤠';
      case 'crops': return '🌾';
      case 'markets': return '📈';
      case 'weather': return '🌦️';
      case 'chemicals': return '🧪';
      case 'equipment': return '🔧';
      case 'politics': return '🏛️';
      default: return '📝';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blueGrey.withAlpha(50), 
                  child: Text(_getIconForCategory(widget.post.category), style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.post.category,
                        style: TextStyle(
                            color: Colors.blueGrey[200],
                            fontWeight: FontWeight.bold)),
                    Text(
                      DateFormat.yMMMd().add_jm().format(widget.post.createdAt),
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(widget.post.title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Text(widget.post.content, style: TextStyle(color: Colors.grey[300])),
            const SizedBox(height: 16),
            TruthMeter(postId: widget.post.id),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                VoteButtons(postId: widget.post.id),
                TextButton.icon(
                  onPressed: () => setState(() => _isCommentsExpanded = !_isCommentsExpanded),
                  icon: FaIcon(
                      _isCommentsExpanded ? FontAwesomeIcons.chevronUp : FontAwesomeIcons.message, 
                      size: 16
                  ), 
                  label: Text('${widget.post.commentCount} Comments'),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey[400]),
                ),
              ],
            ),
            if (_isCommentsExpanded)
              CommentSection(postId: widget.post.id),
          ],
        ),
      ),
    );
  }
}

class CommentSection extends ConsumerStatefulWidget {
  final String postId;
  const CommentSection({super.key, required this.postId});

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

    setState(() => _isPostingComment = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw 'Not authenticated';

      await supabase.from('comments').insert({
        'post_id': widget.postId,
        'anonymous_user_id': userId,
        'content': content,
      });
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting comment: $e'), backgroundColor: Colors.red),
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
                  child: Center(child: Text('No comments yet.')),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  return Card(
                    color: Colors.grey[800],
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(comment.content),
                      subtitle: Text(DateFormat.yMMMd().format(comment.createdAt)),
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
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    filled: true,
                    fillColor: Colors.grey[850],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _isPostingComment
                  ? const CircularProgressIndicator()
                  : IconButton(
                      icon: const FaIcon(FontAwesomeIcons.paperPlane),
                      onPressed: _postComment,
                      color: theme.colorScheme.primary,
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

class TruthMeter extends ConsumerWidget {
  final String postId;
  const TruthMeter({super.key, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voteStatsAsync = ref.watch(voteStatsProvider(postId));

    return voteStatsAsync.when(
      loading: () => const SizedBox(
        height: 28, 
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, stack) => Text('Could not load votes', style: TextStyle(color: Colors.red[400])),
      data: (stats) {
        if (stats.totalVotes == 0) {
          return const Center(
            child: Text(
              'No votes yet. Be the first to cast one!',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Community Truth Meter',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Row(
                children: [
                  _MeterSegment(
                      value: stats.trueVotes / stats.totalVotes,
                      color: theme.colorScheme.primary),
                  _MeterSegment(
                      value: stats.partialVotes / stats.totalVotes,
                      color: theme.colorScheme.secondary),
                  _MeterSegment(
                      value: stats.falseVotes / stats.totalVotes,
                      color: theme.colorScheme.error),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('True (${(stats.trueVotes / stats.totalVotes * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                Text('Partial (${(stats.partialVotes / stats.totalVotes * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                Text('False (${(stats.falseVotes / stats.totalVotes * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              ],
            )
          ],
        );
      },
    );
  }
}

class _MeterSegment extends StatelessWidget {
  final double value;
  final Color color;
  const _MeterSegment({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: (value * 100).toInt(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        height: 10,
        color: color,
      ),
    );
  }
}

class VoteButtons extends ConsumerWidget {
  final String postId;
  const VoteButtons({super.key, required this.postId});

  void _castVote(String voteType, WidgetRef ref, BuildContext context) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw 'User not authenticated.';
      }

      await supabase.rpc('cast_user_vote', params: {
        'post_id_in': postId,
        'user_id_in': userId,
        'vote_type_in': voteType,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vote "$voteType" cast successfully!'),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error casting vote: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () => _castVote('true', ref, context),
          icon: const FaIcon(FontAwesomeIcons.check, size: 14),
          label: const Text('True'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary.withAlpha(204), 
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => _castVote('partial', ref, context),
          icon: const FaIcon(FontAwesomeIcons.triangleExclamation, size: 14),
          label: const Text('Partial'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.secondary.withAlpha(204), 
             foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => _castVote('false', ref, context),
          icon: const FaIcon(FontAwesomeIcons.xmark, size: 14), 
          label: const Text('False'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.error.withAlpha(204), 
             foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
