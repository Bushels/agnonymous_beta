import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = File('firestore.rules').readAsStringSync();
  });

  group('Firestore security rules', () {
    test('shape-lock scam post owner updates to public fields only', () {
      final helper = _functionBody(rules, 'hasScamPostUpdateShape');

      expect(helper, contains("request.resource.data.keys().hasOnly"));
      expect(helper, contains("'has_images'"));
      expect(helper, contains("'scam_location'"));
      expect(helper, contains("'loss_item'"));
      expect(helper, contains("'loss_amount'"));
      expect(helper, isNot(contains("'image_url'")));
      expect(helper, isNot(contains("'image_urls'")));
      expect(helper, isNot(contains("'scammer_name'")));
      expect(helper, isNot(contains("'scammer_company'")));
      expect(helper, isNot(contains("'scammer_phone'")));
      expect(helper, isNot(contains("'scammer_email'")));
    });

    test('post owner update rule requires the scam public-shape helper', () {
      expect(
        rules,
        matches(RegExp(
          r'isScamCategory\(resource\.data\.category\)\s+&& hasScamPostUpdateShape\(\)',
        )),
      );
    });

    test('post owner updates cannot rewrite public identity fields', () {
      final denylist = _affectedKeysDenylist(rules);

      expect(denylist, contains("'id'"));
      expect(denylist, contains("'is_anonymous'"));
      expect(denylist, contains("'author_username'"));
      expect(denylist, contains("'author_verified'"));
      expect(denylist, contains("'user_id'"));
      expect(denylist, contains("'anonymous_user_id'"));
    });

    test('username registry only accepts uid field', () {
      final usernameBlock = _matchBlock(rules, 'usernames/{usernameKey}');

      expect(usernameBlock,
          contains("request.resource.data.keys().hasOnly(['uid'])"));
      expect(usernameBlock,
          contains('request.resource.data.uid == request.auth.uid'));
      expect(usernameBlock, contains('allow update, delete: if false'));
    });

    test('vote writes require active non-owned posts', () {
      final voteBlock = _matchBlock(rules, 'votes/{voteId}');

      expect(
        voteBlock,
        contains('&& isActivePost(request.resource.data.post_id)'),
      );
      expect(
        voteBlock,
        contains(
            '&& !isPostOwner(request.resource.data.post_id, request.auth.uid)'),
      );
      expect(
        voteBlock,
        contains("request.resource.data.keys().hasOnly(['post_id', "
            "'anonymous_user_id', 'vote_type', 'created_at'])"),
      );
    });

    test('report writes require active non-owned posts and locked shape', () {
      final reportBlock = _matchBlock(rules, 'reports/{reportId}');

      expect(reportBlock,
          contains('&& isActivePost(request.resource.data.post_id)'));
      expect(
        reportBlock,
        contains(
            '&& !isPostOwner(request.resource.data.post_id, request.auth.uid)'),
      );
      expect(
        reportBlock,
        contains("request.resource.data.keys().hasOnly(['reporter_id', "
            "'post_id', 'created_at'])"),
      );
    });

    test('registry reads require a verified account or admin role', () {
      final accessHelper = _functionBody(rules, 'hasRegistryAccess');
      final postsBlock = _matchBlock(rules, 'posts/{postId}');

      expect(accessHelper, contains('hasVerifiedAccount() || isAdmin()'));
      expect(
        postsBlock,
        contains(
            '!isScamCategory(resource.data.category) || hasRegistryAccess()'),
      );
    });

    test('registry comments, watches, and interactions share the same gate',
        () {
      final activePostHelper = _functionBodyWithArguments(
        rules,
        'isActivePost',
        'postId',
      );
      final watchesBlock = _matchBlock(rules, 'watches/{watchId}');

      expect(activePostHelper, contains('|| hasRegistryAccess()'));
      expect(watchesBlock, contains('|| hasRegistryAccess()'));
    });

    test('anonymous post ownership checks tolerate omitted public user ids',
        () {
      final ownerHelper = _functionBodyWithArguments(
        rules,
        'isPostOwner',
        'postId, uid',
      );

      expect(
        ownerHelper,
        contains("data.keys().hasAny(['user_id'])"),
      );
    });

    test('admin roles are self-readable but cannot be client-written', () {
      final adminBlock = _matchBlock(rules, 'admin_roles/{userId}');

      expect(adminBlock, contains('userId == request.auth.uid'));
      expect(adminBlock, contains('allow write: if false'));
    });

    test('moderation decisions are admin-only and immutable', () {
      final moderationBlock =
          _matchBlock(rules, 'moderation_actions/{actionId}');

      expect(moderationBlock, contains('allow read: if isAdmin()'));
      expect(moderationBlock, contains('allow create: if isAdmin()'));
      expect(moderationBlock, contains("action in ['approved', 'rejected']"));
      expect(moderationBlock, contains('allow update, delete: if false'));
    });
  });
}

String _functionBody(String source, String name) {
  final pattern = RegExp(
    'function $name\\(\\) \\{([\\s\\S]*?)\\n    \\}',
    multiLine: true,
  );
  final match = pattern.firstMatch(source);
  expect(match, isNotNull, reason: 'Missing Firestore rules helper $name');
  return match!.group(1)!;
}

String _functionBodyWithArguments(
  String source,
  String name,
  String arguments,
) {
  final pattern = RegExp(
    'function $name\\($arguments\\) \\{([\\s\\S]*?)\\n    \\}',
    multiLine: true,
  );
  final match = pattern.firstMatch(source);
  expect(match, isNotNull, reason: 'Missing Firestore rules helper $name');
  return match!.group(1)!;
}

String _matchBlock(String source, String path) {
  final pattern = RegExp(
    'match /${RegExp.escape(path)} \\{([\\s\\S]*?)\\n    \\}',
    multiLine: true,
  );
  final match = pattern.firstMatch(source);
  expect(match, isNotNull, reason: 'Missing Firestore match block /$path');
  return match!.group(1)!;
}

String _affectedKeysDenylist(String source) {
  final pattern = RegExp(
    r"request\.resource\.data\.diff\(resource\.data\)\.affectedKeys\(\)\.hasAny\(\[([\s\S]*?)\]\)",
    multiLine: true,
  );
  final matches = pattern.allMatches(source).toList();
  expect(matches, isNotEmpty, reason: 'Missing affectedKeys denylist');
  for (final match in matches) {
    final denylist = match.group(1)!;
    if (denylist.contains("'thumbs_up_count'")) {
      return denylist;
    }
  }
  fail('Missing post update affectedKeys denylist');
}
