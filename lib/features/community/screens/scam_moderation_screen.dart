import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/post.dart';
import '../../../core/utils/globals.dart';
import '../board_theme.dart';
import '../community_categories.dart';
import '../providers/auth_provider.dart';
import '../widgets/ambient_background.dart';
import '../widgets/scam_report_card.dart';

class ScamModerationScreen extends ConsumerWidget {
  const ScamModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      backgroundColor: BoardColors.prairie,
      appBar: AppBar(
        backgroundColor: BoardColors.paper,
        foregroundColor: BoardColors.ink,
        title: Text(
          'C.U.N.T. Moderation Queue',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
        ),
      ),
      body: AmbientBackground(
        child: isAdmin.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: BoardColors.green),
          ),
          error: (_, __) => const _AccessDenied(),
          data: (allowed) =>
              allowed ? const _PendingReportsList() : const _AccessDenied(),
        ),
      ),
    );
  }
}

class _PendingReportsList extends StatelessWidget {
  const _PendingReportsList();

  @override
  Widget build(BuildContext context) {
    final stream = firestore
        .collection('posts')
        .where('category', whereIn: registryCategoryNames)
        .where('is_deleted', isEqualTo: false)
        .where('pending_review', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load the moderation queue: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: BoardText.body.copyWith(color: Colors.red.shade300),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: BoardColors.green),
          );
        }

        final posts = snapshot.data!.docs.map(_postFromDocument).toList();
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded,
                    color: BoardColors.green, size: 52),
                const SizedBox(height: 14),
                Text('Queue clear', style: BoardText.title),
                const SizedBox(height: 6),
                Text(
                  'No C.U.N.T. reports are waiting for review.',
                  style: BoardText.body.copyWith(color: BoardColors.muted),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ScamReportCard(
                key: ValueKey(posts[index].id),
                post: posts[index],
              ),
            ),
          ),
        );
      },
    );
  }

  Post _postFromDocument(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, dynamic>.from(doc.data());
    data['id'] = doc.id;
    for (final field in [
      'created_at',
      'updated_at',
      'verified_at',
      'deleted_at',
      'edited_at',
    ]) {
      if (data[field] is Timestamp) {
        data[field] = (data[field] as Timestamp).toDate().toIso8601String();
      }
    }
    return Post.fromMap(data);
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, color: BoardColors.amber, size: 52),
            const SizedBox(height: 14),
            Text('Admin access required', style: BoardText.title),
            const SizedBox(height: 6),
            Text(
              'This queue is available only to registry moderators.',
              textAlign: TextAlign.center,
              style: BoardText.body.copyWith(color: BoardColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
