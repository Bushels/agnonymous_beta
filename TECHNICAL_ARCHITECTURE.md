# Agnonymous - Technical Architecture

## Technology Stack

### Frontend
| Technology | Version | Purpose |
|------------|---------|---------|
| Flutter | 3.41.7 | Cross-platform UI framework |
| Dart | 3.11.5 | Programming language |
| flutter_riverpod | 3.0.3 | State management (Notifier pattern) |
| google_fonts | 6.2.0 | Typography |
| font_awesome_flutter | 10.7.0 | Icons |
| firebase_core | 3.10.0 | Firebase Initialization |
| firebase_auth | 5.4.0 | User Authentication |
| cloud_firestore | 5.6.0 | Document Database |
| firebase_storage | 12.3.0 | Cloud Storage for Images |
| logger | 2.5.0 | Logging utility |
| html_unescape | 2.0.0 | XSS prevention |

### Backend (Firebase)
| Technology | Purpose |
|------------|---------|
| Firebase Auth | Authentication & device-based anonymous session IDs |
| Cloud Firestore | NoSQL document database (JSON collections & documents) |
| Firebase Storage | Image uploads and content type/size enforcement |
| Cloud Functions | Node.js triggers for secure server-side aggregations, counters, and reputation logic |
| Firestore Rules | Declarative data access control, schema validation, and field-level immutability |

### Infrastructure
| Service | Purpose |
|---------|---------|
| Firebase Hosting | Web deployment |
| GitHub | Source control |

---

## Architecture Patterns

### State Management: Riverpod 3.x Notifier Pattern

The application uses the `Notifier` pattern (NOT the deprecated `StateNotifier`):

```dart
// CORRECT pattern for this project
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    ref.onDispose(() {
      // Clean up subscriptions
    });
    return AuthState();
  }

  void updateState() {
    state = state.copyWith(...);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
```

### Real-time Subscriptions with Firestore Listeners

```dart
// Inside a Riverpod Provider or Notifier
@override
List<Post> build() {
  final subscription = firestore
      .collection('posts')
      .where('category', isEqualTo: category)
      .where('is_deleted', isEqualTo: false)
      .where('pending_review', isEqualTo: false)
      .snapshots()
      .listen((snapshot) {
        // Update state with newly changed documents
      });

  ref.onDispose(() => subscription.cancel());
}
```

---

## Database Collections & Schema Design

Cloud Firestore collections organize all database information. To prevent de-anonymization and manipulation of derived values, the database is split into public collections, private ownership collections, and private subcollections.

### Public Collections

#### `/user_profiles/{uid}`
Public profile details for registered users (no email address).
- `id` (String): Firebase Auth user ID.
- `username` (String): Unique display name.
- `created_at` (Timestamp): Creation date.
- `updated_at` (Timestamp): Modification date.
- `reputation_points` (Integer): Total reputation score.
- `reputation_level` (Integer): User tier (0 to 9).
- `vote_weight` (Double): Influence multiplier for voting.
- `post_count` (Integer): Total public posts created.
- `comment_count` (Integer): Total comments written.
- `vote_count` (Integer): Total votes cast.

#### `/posts/{postId}`
Standard public posts and account-gated C.U.N.T. scam reports. Approved C.U.N.T. documents are readable only by verified-email users or administrators. If a standard post is created anonymously:
- `user_id` and `anonymous_user_id` are omitted/null to protect identity.
- Ownership is verified via `/posts_private/{postId}` document checks.

Document Fields:
- `id` (String): Document ID.
- `title` (String): Post title.
- `content` (String): Post contents.
- `category` (String): Post category (e.g. 'Monette', 'C.U.N.T.').
- `created_at` (Timestamp): Server timestamp.
- `updated_at` (Timestamp): Server timestamp.
- `is_anonymous` (Boolean): True if posted anonymously.
- `author_username` (String): Author's username or placeholder name.
- `author_verified` (Boolean): True if author has verified their email.
- `is_deleted` (Boolean): True if soft-deleted.
- `pending_review` (Boolean): True for unmoderated C.U.N.T. reports.
- `comment_count` (Integer): Incremented via Cloud Functions triggers.
- `vote_count` (Integer): Incremented via Cloud Functions triggers.
- `thumbs_up_count`, `thumbs_down_count`, `partial_count`, `funny_count` (Integer): Vote aggregates.
- `search_keywords` (Array of Strings): Tokens generated for server-side search.

**Standard post image fields:**
- `image_urls` (Array of Strings): Uploaded image URLs.
- `image_url` (String?): Primary image URL.

**Account-gated C.U.N.T. scam report fields:**
- `has_images` (Boolean): True when the required private evidence image set exists.
- `scam_location` (String): Transaction location.
- `loss_item` (String): Material item lost.
- `loss_amount` (Double): Dollar amount of damage.

Accused-party PII and C.U.N.T. evidence URLs are not public post fields. They live under `/posts/{postId}/private/details`.

#### `/comments/{commentId}`
Comments attached to standard posts are public. Comments attached to C.U.N.T. reports inherit the registry's verified-account or administrator read gate.
- `id` (String): Document ID.
- `post_id` (String): Reference to parent post.
- `content` (String): Comment text.
- `created_at` (Timestamp): Server timestamp.
- `is_anonymous` (Boolean): True if posted anonymously.
- `author_username` (String): Author display name.
- `author_verified` (Boolean): True if author is verified.

#### `/votes/{voteId}`
Cast votes on posts. Document ID format is `{voterUid}_{postId}` to prevent double-voting.
- `id` (String): Unique identifier.
- `post_id` (String): Target post ID.
- `vote_type` (String): One of `thumbs_up`, `partial`, `thumbs_down`.
- `vote_weight` (Double): Voter's influence factor.
- `created_at` (Timestamp): Creation timestamp.

### Private Collections & Subcollections

#### `/user_profiles/{uid}/private/info`
Private profile information containing sensitive user fields.
- `email` (String): Owner's email address.
- `email_verified` (Boolean): Auth-linked verification status.

#### `/posts_private/{postId}`
Private ownership mapper.
- `user_id` (String): Creator's authenticated UID.

#### `/posts/{postId}/private/details`
Private C.U.N.T. report details. Read access is limited to admins, the report owner, or verified-email users viewing approved, non-deleted reports.
- `scammer_name` (String): Accused party's name.
- `scammer_company` (String): Accused party's company name.
- `scammer_phone` (String): Accused phone number.
- `scammer_email` (String): Accused email address.
- `image_urls` (Array of Strings): Evidence image URLs.
- `image_url` (String?): Primary evidence image URL.

#### `/comments_private/{commentId}`
Private ownership mapper.
- `user_id` (String): Creator's authenticated UID.

#### `/reports/{reportId}`
Flagged posts/scam reports submitted for review. Document ID format is `{reporterUid}_{postId}`.
- `post_id` (String): Reported post ID.
- `reporter_id` (String): Reporter's Firebase Auth UID.
- `created_at` (Timestamp): Report creation timestamp.

#### `/admin_roles/{uid}`
Defines users with administrative power.
- `role` (String): E.g., 'moderator' or 'admin'.
- The signed-in user may read only their own role document so the client can expose moderation tools. Client writes are denied; roles are granted with trusted backend credentials.

#### `/moderation_actions/{actionId}`
Immutable audit record for C.U.N.T. moderation decisions. Administrators can append and read these records. Client updates and deletes are denied.
- `post_id` (String): Moderated report ID.
- `action` (String): `approved` or `rejected`.
- `moderator_id` (String): Administrator UID.
- `reason` (String): Required for rejection and empty for approval.
- `created_at` (Timestamp): Server timestamp.

---

## Server-Side Security & Derived Counts

To protect database integrity, clients are restricted from directly modifying counts, stats, and user reputation points. Cloud Functions process changes to base collections and update denormalized totals using Admin privileges.

### Cloud Functions Triggers

#### 1. `onPostCreated`
Triggers when a new post is added to `/posts/{postId}`.
- Increments `/stats/global` `total_posts`.
- If not anonymous, awards `+5` reputation points to the creator's profile.

#### 2. `onPostUpdated`
Triggers when a post is edited or deleted.
- Adjusts `/stats/global` `total_posts` if soft-deleted (`is_deleted` changed to true).
- If `admin_verified` is toggled from false to true, awards `+10` reputation points.

#### 3. `onCommentCreated`
Triggers when a new comment is added.
- Increments `comment_count` on the parent `/posts/{postId}` document.
- Increments `/stats/global` `total_comments`.
- Awards `+2` reputation points for the first comment on a post.

#### 4. `onVoteCreated`
Triggers when a new vote document is written.
- Inspects the voter's profile for `vote_weight` (defaults to 1.0).
- Increments the corresponding vote counts on `/posts/{postId}` (`thumbs_up_count`, etc.) multiplied by `vote_weight`.
- Awards `+1` reputation points to the voter.

#### 5. `onVoteUpdated`
Triggers on vote type change.
- Updates post vote counters (reverts old vote type counts and applies new vote type counts).

#### 6. `onVoteDeleted`
Triggers on vote deletion.
- Decrements the corresponding vote counts on `/posts/{postId}`.

#### 7. `onReportCreated`
Triggers when a report document is created.
- Increments the `report_count` field on `/posts/{postId}`.
- If `report_count >= 3`, automatically sets `pending_review = true` on the post to hide it until moderated.

---

## Security Considerations

1. **Anonymity Guarantee**: Anonymous device IDs are generated on the client side and never joined to registered user profiles or email records. Firestore rules reject public posts carrying any `user_id` when `is_anonymous` is true.
2. **Access Control**: Everyone can read approved standard posts. Approved C.U.N.T. reports and their comments require a verified-email account or administrator role. Users can update only their own posts, verified through `posts_private/{postId}`.
3. **Derived Values Protection**: All aggregate counts (`comment_count`, `vote_count`, etc.) are read-only to clients in Firestore security rules.
4. **Scam Report Moderation**: Scam reports start as `pending_review = true` and are visible only to the owner and administrators until reviewed. Approval or rejection is written atomically with an immutable moderation action. Approved reports, contact details, comments, votes, watches, and evidence remain unavailable to anonymous and unverified users.

---

*Document Version: 2.1 (Verified-Account Registry)*
*Last Updated: July 2026*
