import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/post.dart';
import '../../../core/utils/globals.dart';
import '../../../services/anonymous_id_service.dart';

class WatchedThread {
  final String postId;
  final String title;
  final String category;
  final int lastSeenCommentCount;
  final bool notificationsEnabled;
  final DateTime watchedAt;
  final DateTime updatedAt;

  const WatchedThread({
    required this.postId,
    required this.title,
    required this.category,
    required this.lastSeenCommentCount,
    this.notificationsEnabled = false,
    required this.watchedAt,
    required this.updatedAt,
  });

  factory WatchedThread.fromPost(
    Post post, {
    int? lastSeenCommentCount,
    bool notificationsEnabled = false,
  }) {
    final now = DateTime.now();
    return WatchedThread(
      postId: post.id,
      title: post.title,
      category: post.category,
      lastSeenCommentCount: lastSeenCommentCount ?? post.commentCount,
      notificationsEnabled: notificationsEnabled,
      watchedAt: now,
      updatedAt: now,
    );
  }

  factory WatchedThread.fromJson(Map<String, dynamic> json) {
    return WatchedThread(
      postId: json['post_id'] as String,
      title: (json['title'] as String?) ?? 'Untitled thread',
      category: (json['category'] as String?) ?? 'General',
      lastSeenCommentCount:
          (json['last_seen_comment_count'] as num?)?.toInt() ?? 0,
      notificationsEnabled: json['notifications_enabled'] as bool? ?? false,
      watchedAt: _parseDate(json['watched_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'post_id': postId,
        'title': title,
        'category': category,
        'last_seen_comment_count': lastSeenCommentCount,
        'notifications_enabled': notificationsEnabled,
        'watched_at': watchedAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  int unreadFor(Post post) {
    final unread = post.commentCount - lastSeenCommentCount;
    return unread > 0 ? unread : 0;
  }

  WatchedThread copyWith({
    String? title,
    String? category,
    int? lastSeenCommentCount,
    bool? notificationsEnabled,
    DateTime? watchedAt,
    DateTime? updatedAt,
  }) {
    return WatchedThread(
      postId: postId,
      title: title ?? this.title,
      category: category ?? this.category,
      lastSeenCommentCount: lastSeenCommentCount ?? this.lastSeenCommentCount,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      watchedAt: watchedAt ?? this.watchedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class WatchedThreadsState {
  final Map<String, WatchedThread> threads;
  final bool isLoaded;

  const WatchedThreadsState({
    this.threads = const {},
    this.isLoaded = false,
  });

  bool isWatching(String postId) => threads.containsKey(postId);

  int unreadFor(Post post) => threads[post.id]?.unreadFor(post) ?? 0;

  WatchedThreadsState copyWith({
    Map<String, WatchedThread>? threads,
    bool? isLoaded,
  }) {
    return WatchedThreadsState(
      threads: threads ?? this.threads,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class WatchedThreadsNotifier extends Notifier<WatchedThreadsState> {
  static const String _storageKey = 'anonymous_watched_threads_v1';

  @override
  WatchedThreadsState build() {
    Future.microtask(_load);
    return const WatchedThreadsState();
  }

  Future<void> toggle(Post post) async {
    if (state.isWatching(post.id)) {
      await unwatch(post.id);
    } else {
      await watch(post);
    }
  }

  Future<void> watch(
    Post post, {
    int? lastSeenCommentCount,
    bool notificationsEnabled = false,
  }) async {
    final existing = state.threads[post.id];
    final watchedThread = existing == null
        ? WatchedThread.fromPost(
            post,
            lastSeenCommentCount: lastSeenCommentCount,
            notificationsEnabled: notificationsEnabled,
          )
        : existing.copyWith(
            title: post.title,
            category: post.category,
            lastSeenCommentCount:
                lastSeenCommentCount ?? existing.lastSeenCommentCount,
            notificationsEnabled:
                notificationsEnabled || existing.notificationsEnabled,
            updatedAt: DateTime.now(),
          );

    await _saveThread(watchedThread);
  }

  Future<void> watchDetails({
    required String postId,
    required String title,
    required String category,
    required int lastSeenCommentCount,
    bool notificationsEnabled = false,
  }) async {
    final now = DateTime.now();
    final existing = state.threads[postId];
    final watchedThread = WatchedThread(
      postId: postId,
      title: title,
      category: category,
      lastSeenCommentCount: lastSeenCommentCount,
      notificationsEnabled:
          notificationsEnabled || (existing?.notificationsEnabled ?? false),
      watchedAt: existing?.watchedAt ?? now,
      updatedAt: now,
    );

    await _saveThread(watchedThread);
  }

  Future<void> markSeen(Post post) async {
    final existing = state.threads[post.id];
    if (existing == null) return;

    await _saveThread(
      existing.copyWith(
        title: post.title,
        category: post.category,
        lastSeenCommentCount: post.commentCount,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> unwatch(String postId) async {
    final updated = Map<String, WatchedThread>.from(state.threads)
      ..remove(postId);
    state = state.copyWith(threads: updated, isLoaded: true);
    await _persist();
    await _syncUnwatch(postId);
  }

  /// Wipe every watched thread from local storage and in-memory state.
  /// Used by the Reset Anonymous Identity flow — after an id rotation the
  /// old watches belong to an abandoned identity and must not carry over.
  Future<void> clearAll() async {
    state = const WatchedThreadsState(threads: {}, isLoaded: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> _saveThread(WatchedThread watchedThread) async {
    final updated = Map<String, WatchedThread>.from(state.threads);
    updated[watchedThread.postId] = watchedThread;
    state = state.copyWith(threads: updated, isLoaded: true);
    await _persist();
    await _syncWatch(watchedThread);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    final localThreads = <String, WatchedThread>{};

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final item in decoded) {
          final thread =
              WatchedThread.fromJson(Map<String, dynamic>.from(item as Map));
          localThreads[thread.postId] = thread;
        }
      } catch (error) {
        logger.w('Could not read watched threads: $error');
      }
    }

    state = state.copyWith(threads: localThreads, isLoaded: true);
    await _loadRemoteWatches();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
        state.threads.values.map((thread) => thread.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> _loadRemoteWatches() async {
    try {
      final anonymousId = await AnonymousIdService.getAnonymousId();
      final response = await supabase.rpc(
        'get_anonymous_post_watches',
        params: {'anonymous_user_id_in': anonymousId},
      );
      if (response is! List) return;

      final merged = Map<String, WatchedThread>.from(state.threads);
      for (final item in response) {
        final thread =
            WatchedThread.fromJson(Map<String, dynamic>.from(item as Map));
        final existing = merged[thread.postId];
        if (existing == null || thread.updatedAt.isAfter(existing.updatedAt)) {
          merged[thread.postId] = thread;
        }
      }

      state = state.copyWith(threads: merged, isLoaded: true);
      await _persist();
    } catch (error) {
      logger.d('Remote watched threads unavailable: $error');
    }
  }

  Future<void> _syncWatch(WatchedThread watchedThread) async {
    try {
      final anonymousId = await AnonymousIdService.getAnonymousId();
      await supabase.rpc(
        'upsert_anonymous_post_watch',
        params: {
          'anonymous_user_id_in': anonymousId,
          'post_id_in': watchedThread.postId,
          'last_seen_comment_count_in': watchedThread.lastSeenCommentCount,
          'notifications_enabled_in': watchedThread.notificationsEnabled,
        },
      );
    } catch (error) {
      logger.d('Remote watch sync skipped: $error');
    }
  }

  Future<void> _syncUnwatch(String postId) async {
    try {
      final anonymousId = await AnonymousIdService.getAnonymousId();
      await supabase.rpc(
        'delete_anonymous_post_watch',
        params: {
          'anonymous_user_id_in': anonymousId,
          'post_id_in': postId,
        },
      );
    } catch (error) {
      logger.d('Remote unwatch sync skipped: $error');
    }
  }
}

final watchedThreadsProvider =
    NotifierProvider<WatchedThreadsNotifier, WatchedThreadsState>(
  WatchedThreadsNotifier.new,
);
