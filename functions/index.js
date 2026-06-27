const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

// Helper to determine reputation level and vote weight based on points
function fromPoints(points) {
  let level = 0;
  let voteWeight = 1.0;
  if (points >= 5000) { level = 9; voteWeight = 3.0; }
  else if (points >= 2500) { level = 8; voteWeight = 2.5; }
  else if (points >= 1500) { level = 7; voteWeight = 2.0; }
  else if (points >= 1000) { level = 6; voteWeight = 1.7; }
  else if (points >= 750) { level = 5; voteWeight = 1.5; }
  else if (points >= 500) { level = 4; voteWeight = 1.3; }
  else if (points >= 300) { level = 3; voteWeight = 1.2; }
  else if (points >= 150) { level = 2; voteWeight = 1.1; }
  else if (points >= 50) { level = 1; voteWeight = 1.0; }
  return { level, voteWeight };
}

// Trigger: When a post is created
exports.onPostCreated = functions.firestore
  .document('posts/{postId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();

    // Only count and reward if not pending review
    if (data.pending_review !== true) {
      // Update global stats
      const statsRef = db.collection('stats').doc('global');
      await db.runTransaction(async (transaction) => {
        const statsDoc = await transaction.get(statsRef);
        const currentCount = statsDoc.exists ? (statsDoc.data().total_posts || 0) : 0;
        transaction.set(statsRef, { total_posts: currentCount + 1 }, { merge: true });
      });

      // If registered (not anonymous), update user profile reputation and post count
      if (data.is_anonymous === false && data.user_id) {
        const userRef = db.collection('user_profiles').doc(data.user_id);
        await db.runTransaction(async (transaction) => {
          const userDoc = await transaction.get(userRef);
          if (!userDoc.exists) return;

          const userData = userDoc.data();
          const oldPoints = userData.reputation_points || 0;
          const newPoints = oldPoints + 5; // +5 points for creating a post
          const postCount = (userData.post_count || 0) + 1;
          const levelInfo = fromPoints(newPoints);

          transaction.update(userRef, {
            reputation_points: newPoints,
            reputation_level: levelInfo.level,
            vote_weight: levelInfo.voteWeight,
            post_count: postCount,
            updated_at: admin.firestore.FieldValue.serverTimestamp()
          });
        });
      }
    }
  });

// Trigger: When a post is updated (e.g. soft-deleted, admin-verified, or approved)
exports.onPostUpdated = functions.firestore
  .document('posts/{postId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const statsRef = db.collection('stats').doc('global');

    // Handle moderator approval (pending_review: true -> false)
    if (before.pending_review === true && after.pending_review === false) {
      // Increment global stats if post is not soft-deleted
      if (after.is_deleted !== true) {
        await db.runTransaction(async (transaction) => {
          const statsDoc = await transaction.get(statsRef);
          const currentCount = statsDoc.exists ? (statsDoc.data().total_posts || 0) : 0;
          transaction.set(statsRef, { total_posts: currentCount + 1 }, { merge: true });
        });
      }

      // Award reputation points if registered/public post
      if (after.is_anonymous === false && after.user_id) {
        const userRef = db.collection('user_profiles').doc(after.user_id);
        await db.runTransaction(async (transaction) => {
          const userDoc = await transaction.get(userRef);
          if (!userDoc.exists) return;

          const userData = userDoc.data();
          const oldPoints = userData.reputation_points || 0;
          const newPoints = oldPoints + 5; // +5 points for approved post
          const postCount = (userData.post_count || 0) + 1;
          const levelInfo = fromPoints(newPoints);

          transaction.update(userRef, {
            reputation_points: newPoints,
            reputation_level: levelInfo.level,
            vote_weight: levelInfo.voteWeight,
            post_count: postCount,
            updated_at: admin.firestore.FieldValue.serverTimestamp()
          });
        });
      }
    }

    // Handle post flagged/sent back to pending review (pending_review: false -> true)
    if (before.pending_review === false && after.pending_review === true) {
      if (after.is_deleted !== true) {
        await db.runTransaction(async (transaction) => {
          const statsDoc = await transaction.get(statsRef);
          const currentCount = statsDoc.exists ? (statsDoc.data().total_posts || 0) : 0;
          transaction.set(statsRef, { total_posts: Math.max(0, currentCount - 1) }, { merge: true });
        });
      }

      if (after.is_anonymous === false && after.user_id) {
        const userRef = db.collection('user_profiles').doc(after.user_id);
        await db.runTransaction(async (transaction) => {
          const userDoc = await transaction.get(userRef);
          if (!userDoc.exists) return;

          const userData = userDoc.data();
          const oldPoints = userData.reputation_points || 0;
          const newPoints = Math.max(0, oldPoints - 5);
          const postCount = Math.max(0, (userData.post_count || 0) - 1);
          const levelInfo = fromPoints(newPoints);

          transaction.update(userRef, {
            reputation_points: newPoints,
            reputation_level: levelInfo.level,
            vote_weight: levelInfo.voteWeight,
            post_count: postCount,
            updated_at: admin.firestore.FieldValue.serverTimestamp()
          });
        });
      }
    }

    // Handle soft deletes (only affect stats if post is not pending review)
    if (before.pending_review !== true && after.pending_review !== true) {
      if (before.is_deleted === false && after.is_deleted === true) {
        await db.runTransaction(async (transaction) => {
          const statsDoc = await transaction.get(statsRef);
          const currentCount = statsDoc.exists ? (statsDoc.data().total_posts || 0) : 0;
          transaction.set(statsRef, { total_posts: Math.max(0, currentCount - 1) }, { merge: true });
        });
      } else if (before.is_deleted === true && after.is_deleted === false) {
        await db.runTransaction(async (transaction) => {
          const statsDoc = await transaction.get(statsRef);
          const currentCount = statsDoc.exists ? (statsDoc.data().total_posts || 0) : 0;
          transaction.set(statsRef, { total_posts: currentCount + 1 }, { merge: true });
        });
      }
    }

    // Award +10 reputation points for admin verification
    if (before.admin_verified === false && after.admin_verified === true && after.user_id) {
      const userRef = db.collection('user_profiles').doc(after.user_id);
      await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) return;

        const userData = userDoc.data();
        const oldPoints = userData.reputation_points || 0;
        const newPoints = oldPoints + 10;
        const levelInfo = fromPoints(newPoints);

        transaction.update(userRef, {
          reputation_points: newPoints,
          reputation_level: levelInfo.level,
          vote_weight: levelInfo.voteWeight,
          updated_at: admin.firestore.FieldValue.serverTimestamp()
        });
      });
    }
  });

// Trigger: When a comment is created
exports.onCommentCreated = functions.firestore
  .document('comments/{commentId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    const postId = data.post_id;

    // Increment post's comment count
    const postRef = db.collection('posts').doc(postId);
    await db.runTransaction(async (transaction) => {
      const postDoc = await transaction.get(postRef);
      if (postDoc.exists) {
        const currentCount = postDoc.data().comment_count || 0;
        transaction.update(postRef, { comment_count: currentCount + 1 });
      }
    });

    // Update global stats
    const statsRef = db.collection('stats').doc('global');
    await db.runTransaction(async (transaction) => {
      const statsDoc = await transaction.get(statsRef);
      const currentCount = statsDoc.exists ? (statsDoc.data().total_comments || 0) : 0;
      transaction.set(statsRef, { total_comments: currentCount + 1 }, { merge: true });
    });

    // If registered (not anonymous), update user profile reputation (+2 for first comment on post)
    if (data.is_anonymous === false && data.anonymous_user_id) {
      const userRef = db.collection('user_profiles').doc(data.anonymous_user_id);

      // Determine if this is the first comment by this user on this post
      const previousComments = await db.collection('comments')
        .where('post_id', '==', postId)
        .where('anonymous_user_id', '==', data.anonymous_user_id)
        .limit(2)
        .get();

      const isFirstComment = previousComments.size <= 1;
      const pointsToAdd = isFirstComment ? 2 : 0;

      await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) return;

        const userData = userDoc.data();
        const oldPoints = userData.reputation_points || 0;
        const newPoints = oldPoints + pointsToAdd;
        const commentCount = (userData.comment_count || 0) + 1;
        const levelInfo = fromPoints(newPoints);

        transaction.update(userRef, {
          reputation_points: newPoints,
          reputation_level: levelInfo.level,
          vote_weight: levelInfo.voteWeight,
          comment_count: commentCount,
          updated_at: admin.firestore.FieldValue.serverTimestamp()
        });
      });
    }
  });

// Helper to validate vote documents and check for self-voting
async function checkVoteValidity(voteId, data, isDeleteOrUpdate = false) {
  if (!data) return { valid: false, reason: 'no_data' };
  const postId = data.post_id;
  const voterUid = data.anonymous_user_id;
  const voteType = data.vote_type;

  if (voteId !== `${voterUid}_${postId}`) {
    return { valid: false, reason: 'invalid_id' };
  }

  if (!['thumbs_up', 'partial', 'thumbs_down'].includes(voteType)) {
    return { valid: false, reason: 'invalid_type' };
  }

  const postRef = db.collection('posts').doc(postId);
  const postDoc = await postRef.get();
  if (!postDoc.exists) {
    return { valid: false, reason: 'post_not_found' };
  }
  const postData = postDoc.data();

  // For update/delete, we allow voting operations on soft-deleted or pending posts
  // to clean up counters or reputation if they were originally valid.
  if (!isDeleteOrUpdate) {
    if (postData.is_deleted === true) {
      return { valid: false, reason: 'post_deleted' };
    }
    if (postData.pending_review === true) {
      return { valid: false, reason: 'post_pending' };
    }
  }

  // Self voting checks: public user_id
  if (postData.user_id && voterUid === postData.user_id) {
    return { valid: false, reason: 'self_vote' };
  }

  // Self voting checks: private anonymous owner
  const postPrivateDoc = await db.collection('posts_private').doc(postId).get();
  if (postPrivateDoc.exists) {
    const privateOwnerUid = postPrivateDoc.data().user_id;
    if (voterUid === privateOwnerUid) {
      return { valid: false, reason: 'self_vote' };
    }
  }

  return { valid: true };
}

// Trigger: When a vote is created
exports.onVoteCreated = functions.firestore
  .document('votes/{voteId}')
  .onCreate(async (snapshot, context) => {
    const voteId = context.params.voteId;
    const data = snapshot.data();

    const validity = await checkVoteValidity(voteId, data, false);
    if (!validity.valid) {
      console.warn(`Rejecting and deleting invalid vote ${voteId}: ${validity.reason}`);
      await snapshot.ref.update({ invalid_vote: true });
      await snapshot.ref.delete();
      return;
    }

    const postId = data.post_id;
    const voterUid = data.anonymous_user_id;
    const voteType = data.vote_type;

    // Get voter's vote weight
    let weight = 1.0;
    let isRegistered = false;
    if (voterUid) {
      const userDoc = await db.collection('user_profiles').doc(voterUid).get();
      if (userDoc.exists) {
        weight = userDoc.data().vote_weight || 1.0;
        isRegistered = true;
      }
    }

    // Update post counts
    const postRef = db.collection('posts').doc(postId);
    await db.runTransaction(async (transaction) => {
      const postDoc = await transaction.get(postRef);
      if (!postDoc.exists) return;

      const postData = postDoc.data();
      const currentVoteCount = postData.vote_count || 0;
      const currentTypeCount = postData[`${voteType}_count`] || 0;

      const updates = {
        vote_count: currentVoteCount + 1,
        [`${voteType}_count`]: currentTypeCount + weight
      };

      transaction.update(postRef, updates);
    });

    // Update global stats
    const statsRef = db.collection('stats').doc('global');
    await db.runTransaction(async (transaction) => {
      const statsDoc = await transaction.get(statsRef);
      const currentCount = statsDoc.exists ? (statsDoc.data().total_votes || 0) : 0;
      transaction.set(statsRef, { total_votes: currentCount + 1 }, { merge: true });
    });

    // Award +1 reputation point for voting if registered (only for first vote on this post)
    if (isRegistered && voterUid) {
      const userRef = db.collection('user_profiles').doc(voterUid);
      await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) return;

        const userData = userDoc.data();
        const oldPoints = userData.reputation_points || 0;
        const newPoints = oldPoints + 1;
        const voteCount = (userData.vote_count || 0) + 1;
        const levelInfo = fromPoints(newPoints);

        transaction.update(userRef, {
          reputation_points: newPoints,
          reputation_level: levelInfo.level,
          vote_weight: levelInfo.voteWeight,
          vote_count: voteCount,
          updated_at: admin.firestore.FieldValue.serverTimestamp()
        });
      });
    }
  });

// Trigger: When a vote is updated (e.g. changed vote type)
exports.onVoteUpdated = functions.firestore
  .document('votes/{voteId}')
  .onUpdate(async (change, context) => {
    const voteId = context.params.voteId;
    const before = change.before.data();
    const after = change.after.data();
    const postId = after.post_id;
    const voterUid = after.anonymous_user_id;
    const oldType = before.vote_type;
    const newType = after.vote_type;

    if (oldType === newType) return;

    // Check validity of the updated vote doc
    const validityAfter = await checkVoteValidity(voteId, after, true);
    if (!validityAfter.valid) {
      console.warn(`Rejecting and deleting invalid vote update ${voteId}: ${validityAfter.reason}`);
      await change.after.ref.update({ invalid_vote: true });
      await change.after.ref.delete();
      return;
    }

    // Check if the original vote was also valid
    const validityBefore = await checkVoteValidity(voteId, before, true);
    if (!validityBefore.valid || before.invalid_vote === true) {
      // If the original vote was invalid, it was not counted.
      // So treat this update as a fresh vote create.
      let weight = 1.0;
      if (voterUid) {
        const userDoc = await db.collection('user_profiles').doc(voterUid).get();
        if (userDoc.exists) {
          weight = userDoc.data().vote_weight || 1.0;
        }
      }
      const postRef = db.collection('posts').doc(postId);
      await db.runTransaction(async (transaction) => {
        const postDoc = await transaction.get(postRef);
        if (!postDoc.exists) return;
        const postData = postDoc.data();
        const currentVoteCount = postData.vote_count || 0;
        const currentTypeCount = postData[`${newType}_count`] || 0;
        transaction.update(postRef, {
          vote_count: currentVoteCount + 1,
          [`${newType}_count`]: currentTypeCount + weight
        });
      });

      // Update global stats since this is a new vote
      const statsRef = db.collection('stats').doc('global');
      await db.runTransaction(async (transaction) => {
        const statsDoc = await transaction.get(statsRef);
        const currentCount = statsDoc.exists ? (statsDoc.data().total_votes || 0) : 0;
        transaction.set(statsRef, { total_votes: currentCount + 1 }, { merge: true });
      });
      return;
    }

    // Get voter's weight
    let weight = 1.0;
    if (voterUid) {
      const userDoc = await db.collection('user_profiles').doc(voterUid).get();
      if (userDoc.exists) {
        weight = userDoc.data().vote_weight || 1.0;
      }
    }

    // Update post counts
    const postRef = db.collection('posts').doc(postId);
    await db.runTransaction(async (transaction) => {
      const postDoc = await transaction.get(postRef);
      if (!postDoc.exists) return;

      const postData = postDoc.data();
      const currentOldCount = postData[`${oldType}_count`] || 0;
      const currentNewCount = postData[`${newType}_count`] || 0;

      transaction.update(postRef, {
        [`${oldType}_count`]: Math.max(0, currentOldCount - weight),
        [`${newType}_count`]: currentNewCount + weight
      });
    });
  });

// Trigger: When a vote is deleted
exports.onVoteDeleted = functions.firestore
  .document('votes/{voteId}')
  .onDelete(async (snapshot, context) => {
    const voteId = context.params.voteId;
    const data = snapshot.data();

    // Check if this vote was flagged as invalid
    if (data && data.invalid_vote === true) {
      console.log(`onVoteDeleted: ignoring rejected invalid vote ${voteId}`);
      return;
    }

    // Check validity of the deleted vote doc
    const validity = await checkVoteValidity(voteId, data, true);
    if (!validity.valid) {
      console.log(`onVoteDeleted: ignoring invalid vote ${voteId} (${validity.reason})`);
      return;
    }

    const postId = data.post_id;
    const voterUid = data.anonymous_user_id;
    const voteType = data.vote_type;

    // Get voter's weight
    let weight = 1.0;
    let isRegistered = false;
    if (voterUid) {
      const userDoc = await db.collection('user_profiles').doc(voterUid).get();
      if (userDoc.exists) {
        weight = userDoc.data().vote_weight || 1.0;
        isRegistered = true;
      }
    }

    // Update post counts
    const postRef = db.collection('posts').doc(postId);
    await db.runTransaction(async (transaction) => {
      const postDoc = await transaction.get(postRef);
      if (!postDoc.exists) return;

      const postData = postDoc.data();
      const currentVoteCount = postData.vote_count || 0;
      const currentTypeCount = postData[`${voteType}_count`] || 0;

      transaction.update(postRef, {
        vote_count: Math.max(0, currentVoteCount - 1),
        [`${voteType}_count`]: Math.max(0, currentTypeCount - weight)
      });
    });

    // Update global stats
    const statsRef = db.collection('stats').doc('global');
    await db.runTransaction(async (transaction) => {
      const statsDoc = await transaction.get(statsRef);
      const currentCount = statsDoc.exists ? (statsDoc.data().total_votes || 0) : 0;
      transaction.set(statsRef, { total_votes: Math.max(0, currentCount - 1) }, { merge: true });
    });

    // Deduct 1 reputation point if registered
    if (isRegistered && voterUid) {
      const userRef = db.collection('user_profiles').doc(voterUid);
      await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) return;

        const userData = userDoc.data();
        const oldPoints = userData.reputation_points || 0;
        const newPoints = Math.max(0, oldPoints - 1);
        const voteCount = Math.max(0, (userData.vote_count || 0) - 1);
        const levelInfo = fromPoints(newPoints);

        transaction.update(userRef, {
          reputation_points: newPoints,
          reputation_level: levelInfo.level,
          vote_weight: levelInfo.voteWeight,
          vote_count: voteCount,
          updated_at: admin.firestore.FieldValue.serverTimestamp()
        });
      });
    }
  });

// Trigger: When a report is created
exports.onReportCreated = functions.firestore
  .document('reports/{reportId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    const postId = data.post_id;
    const reportId = context.params.reportId;
    const reporterId = data.reporter_id;

    // Defense-in-depth: Verify report ID matches standard format
    if (reportId !== `${reporterId}_${postId}`) {
      console.warn(`Report ID format mismatch. Expected: ${reporterId}_${postId}, got: ${reportId}. Deleting document.`);
      await snapshot.ref.delete();
      return;
    }

    const postRef = db.collection('posts').doc(postId);
    const privatePostRef = db.collection('posts_private').doc(postId);
    await db.runTransaction(async (transaction) => {
      const postDoc = await transaction.get(postRef);
      if (!postDoc.exists) {
        transaction.delete(snapshot.ref);
        return;
      }

      const postData = postDoc.data();
      const privatePostDoc = await transaction.get(privatePostRef);
      const privateOwnerId = privatePostDoc.exists ? privatePostDoc.data().user_id : null;
      const isSelfReport = reporterId === postData.user_id || reporterId === privateOwnerId;

      if (postData.is_deleted === true || postData.pending_review === true || isSelfReport) {
        transaction.delete(snapshot.ref);
        return;
      }

      const currentReports = postData.report_count || 0;
      const updates = { report_count: currentReports + 1 };

      // Auto-flag for review if reported 3 or more times
      if (currentReports + 1 >= 3) {
        updates.pending_review = true;
      }

      transaction.update(postRef, updates);
    });
  });
