# Database Security & Data Integrity Documentation

## 🔒 Security Layers Implemented

This document outlines the defense-in-depth security model implemented in Agnonymous Beta, securing the anonymous posting board, protecting user privacy, preventing de-anonymization, and protecting derived metrics from manipulation.

---

## 🛡️ Defense-in-Depth Security Model

```
+--------------------------------------------------------+
|           Layer 1: Application Sanitization            |
|       (Input sanitization, HTML escaping, XSS block)   |
+--------------------------------------------------------+
                           |
                           v
+--------------------------------------------------------+
|           Layer 2: Cloud Firestore Rules               |
|      (Access control, field immutability, schemas)     |
+--------------------------------------------------------+
                           |
                           v
+--------------------------------------------------------+
|           Layer 3: Cloud Storage Rules                 |
|       (Path prefixes, size limits, JPEG content check) |
+--------------------------------------------------------+
                           |
                           v
+--------------------------------------------------------+
|           Layer 4: Cloud Functions Triggers            |
|     (Aggregations, derived counts, reputation logic)    |
+--------------------------------------------------------+
                           |
                           v
+--------------------------------------------------------+
|           Layer 5: PII Lock & Moderation Flow          |
|    (Email verification requirements, pending banners)  |
+--------------------------------------------------------+
```

---

### **Layer 1: Application-Level Protection**

**Files:** `lib/core/utils/helpers.dart`, `lib/create_post_screen.dart`, `lib/features/community/screens/create_scam_report_screen.dart`

1. **Input Sanitization (XSS Prevention)**
   - Function: `sanitizeInput()`
   - Removes HTML tags and decodes entities.
   - Applied to all user-submitted text fields (post/report titles, content, scam fields).

2. **Size and Format Validation**
   - Title: 1-100 characters.
   - Content: 10-2000 characters.
   - Category: Checked against a list of approved options (e.g. 'Monette', 'C.U.N.T.').

3. **Anonymous Identity Splitting**
   - If a post or comment is published anonymously, the client omits user identifiers (`user_id` / `anonymous_user_id`) from the public document.
   - A corresponding private record is written to `/posts_private/{postId}` or `/comments_private/{commentId}` containing the owner's UID. This allows owners to edit/delete without exposing their UID in the public feed.

---

### **Layer 2: Cloud Firestore Security Rules**

**File:** `firestore.rules`

Firestore Security Rules enforce strict access controls and field immutability directly in the database layer.

1. **Public/Private Split for Profiles**
   - `/user_profiles/{uid}` is readable by anyone, but writes are restricted to the owner (`request.auth.uid == uid`). Writing `email` or `email_verified` fields to this public document is rejected.
   - Private subcollection `/user_profiles/{uid}/private/info` stores sensitive email details. Read/Write permissions are granted only if the authenticated user's UID matches the path identifier (`request.auth.uid == uid`).

2. **Derived Metrics Immutability**
   - Users are prohibited from directly modifying counts, stats, and reputation points.
   - Security rules block any write that attempts to alter: `comment_count`, `vote_count`, `thumbs_up_count`, `thumbs_down_count`, `partial_count`, `funny_count`, and global `stats` counters.

3. **Post and Comment Creation Rules**
   - For anonymous creations: rules verify that no `user_id` or `anonymous_user_id` fields are present in the public record.
   - For registered creations: rules verify that `user_id == request.auth.uid`.
   - Update permissions check that the requester owns the post via the corresponding `/posts_private/{postId}` document:
     `get(/databases/$(database)/documents/posts_private/$(postId)).data.user_id == request.auth.uid`

4. **Vote Visibility**
   - Reads on `/votes/{voteId}` are restricted. A user can only read their own vote documents (ID matches `^authUid_.*`).

5. **C.U.N.T. Registry Access Boundary**
   - Approved registry posts and their comments are readable only by verified-email users or administrators.
   - Anonymous and unverified All Rooms queries use a positive allowlist of standard categories so registry documents cannot enter the public feed.
   - Registry votes, reports, and watches inherit the same access gate through the parent-post check.
   - `/admin_roles/{uid}` is self-readable for role discovery but cannot be written by clients.
   - `/moderation_actions/{actionId}` is an admin-only, append-only audit trail.

---

### **Layer 3: Cloud Storage Security Rules**

**File:** `storage.rules`

Ensures images are stored safely under restricted paths, preventing attackers from writing arbitrary files or overwriting other users' uploads.

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /post-images/{type}/{userId}/{imageId} {
      allow read: if type == 'anonymous'
                  || (
                    request.auth != null
                    && (
                      request.auth.uid == userId
                      || request.auth.token.email_verified == true
                      || firestore.exists(/databases/(default)/documents/admin_roles/$(request.auth.uid))
                    )
                  );
      allow create: if request.auth != null
                    && request.auth.uid == userId
                    && (type == 'anonymous' || type == 'scams')
                    && request.resource.contentType.matches('image/jpeg')
                    && request.resource.size < 5 * 1024 * 1024;
      allow update, delete: if false;
    }
  }
}
```

**Enforcements:**
- **Ownership**: The write is rejected unless the authenticated user's UID matches the `{userId}` path parameter.
- **Scam Evidence Read Gate**: Scam images are readable only by the uploader, admins, or verified-email users. Anonymous post images remain public.
- **Type**: Restricts paths to `anonymous` and `scams` folders.
- **Format**: Only `image/jpeg` files are allowed.
- **Size**: Uploads are restricted to files under 5 megabytes.

---

### **Layer 4: Cloud Functions Triggers**

**File:** `functions/index.js`

To prevent client forging of scores, derived counts, and reputation points, all counting and point assignment actions are processed in the backend.

- **Post Creations**: Increments global stats. Non-anonymous posts grant `+5` points to the author profile.
- **Comment Creations**: Increments post `comment_count` and global stats. Grants `+2` points for the first comment on a post.
- **Vote Creations/Updates/Deletions**: Pulls the voter's `vote_weight` securely and increments/decrements post vote aggregates (`thumbs_up_count`, etc.) by that weight. Awards `+1` reputation point to active voters.
- **Report Flagging**: Increments post `report_count`. If a post receives 3 or more reports, the function automatically flags it as `pending_review = true` to hide it from standard feeds.

---

### **Layer 5: PII Lock & Moderation Flow**

**Files:** `lib/features/community/screens/create_scam_report_screen.dart`, `lib/features/community/widgets/scam_report_card.dart`

To protect individual privacy and prevent false claims:
1. **Whole-Registry Account Gate**: Approved C.U.N.T. reports and all related interaction data require a verified-email account or administrator role. Anonymous and unverified users cannot read or interact with the registry.
2. **Moderation Status**: All C.U.N.T. scam reports are created with `pending_review: true` and are visible only to the report owner and administrators. Admins must approve the report before it appears to verified registry users.
3. **Private Details Lock**: Accused-party contact details and evidence URLs live under `/posts/{postId}/private/details`, not on the main post document. Those details are readable only by administrators, the report owner, or verified-email users after the report is approved and not deleted.
4. **Evidence Requirement**: At least one image of supporting evidence is required to submit a scam report.
5. **Audited Decisions**: Approval and rejection update the report and append an immutable `/moderation_actions` record in one atomic batch. Rejections require a reason.

---

### **Layer 6: Web Security Headers**

**File:** `firebase.json`

HTTP response headers block various browser-based vulnerabilities:

- **Content-Security-Policy (CSP)**: Controls where scripts, images, and styles can load from.
- **X-Frame-Options**: Set to `SAMEORIGIN` to prevent clickjacking attacks.
- **X-Content-Type-Options**: Set to `nosniff` to prevent MIME-type sniffing.
- **Referrer-Policy**: Restricts the amount of referrer details sent on outbound clicks.

---

*Document Version: 2.1 (Verified-Account Registry)*
*Last Updated: July 2026*
