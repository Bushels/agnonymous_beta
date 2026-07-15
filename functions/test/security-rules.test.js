const fs = require('node:fs');
const path = require('node:path');
const { after, before, beforeEach, describe, test } = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  setDoc,
  Timestamp,
  where,
  writeBatch,
} = require('firebase/firestore');
const {
  getBytes,
  ref: storageRef,
  uploadBytes,
} = require('firebase/storage');

const projectId = 'agnonymous-rules-test';
const root = path.resolve(__dirname, '..', '..');
let testEnv;

const anonymousClaims = {
  email_verified: false,
  firebase: { sign_in_provider: 'anonymous' },
};

const unverifiedClaims = {
  email: 'unverified@example.com',
  email_verified: false,
  firebase: { sign_in_provider: 'password' },
};

const verifiedClaims = {
  email: 'verified@example.com',
  email_verified: true,
  firebase: { sign_in_provider: 'password' },
};

function postData(category, overrides = {}) {
  return {
    id: overrides.id ?? 'post-id',
    title: overrides.title ?? 'Test title',
    content: overrides.content ?? 'Test content',
    category,
    created_at: overrides.created_at ?? Timestamp.fromMillis(1000),
    updated_at: overrides.updated_at ?? Timestamp.fromMillis(1000),
    is_anonymous: overrides.is_anonymous ?? true,
    author_username: overrides.author_username ?? 'Anonymous Farmer',
    author_verified: overrides.author_verified ?? false,
    is_deleted: overrides.is_deleted ?? false,
    pending_review: overrides.pending_review ?? false,
    comment_count: overrides.comment_count ?? 0,
    vote_count: overrides.vote_count ?? 0,
    thumbs_up_count: overrides.thumbs_up_count ?? 0,
    thumbs_down_count: overrides.thumbs_down_count ?? 0,
    partial_count: overrides.partial_count ?? 0,
    funny_count: overrides.funny_count ?? 0,
    search_keywords: overrides.search_keywords ?? ['test'],
    ...overrides,
  };
}

async function seedFirestore(seed) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await seed(context.firestore());
  });
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(path.join(root, 'firestore.rules'), 'utf8'),
    },
    storage: {
      rules: fs.readFileSync(path.join(root, 'storage.rules'), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
});

after(async () => {
  await testEnv.cleanup();
});

describe('verified-account C.U.N.T. registry boundary', () => {
  test('anonymous visitors retain access to standard approved posts', async () => {
    await seedFirestore((db) =>
      setDoc(doc(db, 'posts', 'standard-post'), postData('General', { id: 'standard-post' })),
    );

    const db = testEnv.authenticatedContext('anon-user', anonymousClaims).firestore();
    await assertSucceeds(getDoc(doc(db, 'posts', 'standard-post')));
  });

  test('anonymous and unverified accounts cannot read an approved registry entry', async () => {
    await seedFirestore((db) =>
      setDoc(doc(db, 'posts', 'registry-post'), postData('C.U.N.T.', {
        id: 'registry-post',
        is_anonymous: false,
        author_username: 'Reporter',
        author_verified: true,
        user_id: 'reporter-uid',
        scam_location: 'Saskatchewan',
        loss_item: 'Canola',
        loss_amount: 1000,
        has_images: true,
      })),
    );

    const anonDb = testEnv.authenticatedContext('anon-user', anonymousClaims).firestore();
    const unverifiedDb = testEnv.authenticatedContext('plain-user', unverifiedClaims).firestore();
    await assertFails(getDoc(doc(anonDb, 'posts', 'registry-post')));
    await assertFails(getDoc(doc(unverifiedDb, 'posts', 'registry-post')));
  });

  test('a verified account can read an approved registry entry', async () => {
    await seedFirestore((db) =>
      setDoc(doc(db, 'posts', 'registry-post'), postData('C.U.N.T.', {
        id: 'registry-post',
        is_anonymous: false,
        author_username: 'Reporter',
        author_verified: true,
        user_id: 'reporter-uid',
        scam_location: 'Saskatchewan',
        loss_item: 'Canola',
        loss_amount: 1000,
        has_images: true,
      })),
    );

    const db = testEnv.authenticatedContext('verified-user', verifiedClaims).firestore();
    await assertSucceeds(getDoc(doc(db, 'posts', 'registry-post')));
  });

  test('anonymous All Rooms query succeeds only when it excludes registry categories', async () => {
    await seedFirestore(async (db) => {
      await setDoc(doc(db, 'posts', 'standard-post'), postData('General', { id: 'standard-post' }));
      await setDoc(doc(db, 'posts', 'registry-post'), postData('C.U.N.T.', {
        id: 'registry-post',
        is_anonymous: false,
        author_username: 'Reporter',
        author_verified: true,
        user_id: 'reporter-uid',
        scam_location: 'Saskatchewan',
        loss_item: 'Canola',
        loss_amount: 1000,
        has_images: true,
      }));
    });

    const db = testEnv.authenticatedContext('anon-user', anonymousClaims).firestore();
    const safeQuery = query(
      collection(db, 'posts'),
      where('is_deleted', '==', false),
      where('pending_review', '==', false),
      where('category', 'in', [
        'Ag Business',
        'Chemicals',
        'Crops',
        'Equipment',
        'Farming',
        'General',
        'Grain',
        'Input Prices',
        'Land',
        'Livestock',
        'Markets',
        'Monette',
        'Other',
        'Politics',
        'Ranching',
        'Weather',
      ]),
      orderBy('created_at', 'desc'),
    );
    const unsafeRegistryQuery = query(
      collection(db, 'posts'),
      where('is_deleted', '==', false),
      where('pending_review', '==', false),
      where('category', '==', 'C.U.N.T.'),
      orderBy('created_at', 'desc'),
    );

    const safeSnapshot = await assertSucceeds(getDocs(safeQuery));
    await assertFails(getDocs(unsafeRegistryQuery));
    if (safeSnapshot.size !== 1 || safeSnapshot.docs[0].id !== 'standard-post') {
      throw new Error('Safe All Rooms query returned unexpected posts');
    }
  });

  test('unverified accounts cannot read or create registry comments and votes', async () => {
    await seedFirestore(async (db) => {
      await setDoc(doc(db, 'posts', 'registry-post'), postData('C.U.N.T.', {
        id: 'registry-post',
        is_anonymous: false,
        author_username: 'Reporter',
        author_verified: true,
        user_id: 'reporter-uid',
        scam_location: 'Saskatchewan',
        loss_item: 'Canola',
        loss_amount: 1000,
        has_images: true,
      }));
      await setDoc(doc(db, 'comments', 'registry-comment'), {
        id: 'registry-comment',
        post_id: 'registry-post',
        content: 'Registry comment',
        is_anonymous: true,
        author_username: 'Anonymous Farmer',
        author_verified: false,
        is_deleted: false,
        created_at: Timestamp.fromMillis(2000),
      });
    });

    const db = testEnv.authenticatedContext('plain-user', unverifiedClaims).firestore();
    await assertFails(getDoc(doc(db, 'comments', 'registry-comment')));
    await assertFails(setDoc(doc(db, 'comments', 'new-comment'), {
      id: 'new-comment',
      post_id: 'registry-post',
      content: 'Not allowed',
      is_anonymous: true,
      author_username: 'Anonymous Farmer',
      author_verified: false,
      is_deleted: false,
      created_at: Timestamp.fromMillis(3000),
    }));
    await assertFails(setDoc(doc(db, 'votes', 'plain-user_registry-post'), {
      post_id: 'registry-post',
      anonymous_user_id: 'plain-user',
      vote_type: 'thumbs_up',
      created_at: Timestamp.fromMillis(3000),
    }));
  });

  test('standard comments and votes remain available to anonymous sessions', async () => {
    await seedFirestore(async (db) => {
      await setDoc(doc(db, 'posts', 'standard-post'), postData('General', {
        id: 'standard-post',
      }));
      await setDoc(doc(db, 'posts_private', 'standard-post'), {
        user_id: 'post-owner',
        created_at: Timestamp.fromMillis(1000),
      });
      await setDoc(doc(db, 'comments', 'standard-comment'), {
        id: 'standard-comment',
        post_id: 'standard-post',
        content: 'Standard comment',
        is_anonymous: true,
        author_username: 'Anonymous Farmer',
        author_verified: false,
        is_deleted: false,
        created_at: Timestamp.fromMillis(2000),
      });
    });

    const db = testEnv.authenticatedContext('anon-user', anonymousClaims).firestore();
    const commentsQuery = query(
      collection(db, 'comments'),
      where('post_id', '==', 'standard-post'),
      where('is_deleted', '==', false),
      orderBy('created_at', 'asc'),
    );
    const comments = await assertSucceeds(getDocs(commentsQuery));
    if (comments.size !== 1) throw new Error('Anonymous standard comments query failed');

    await assertSucceeds(setDoc(doc(db, 'votes', 'anon-user_standard-post'), {
      post_id: 'standard-post',
      anonymous_user_id: 'anon-user',
      vote_type: 'thumbs_up',
      created_at: Timestamp.fromMillis(3000),
    }));
  });

  test('verified account can submit an evidence-backed pending report atomically', async () => {
    await seedFirestore(async (db) => {
      await setDoc(doc(db, 'user_profiles', 'verified-user'), {
        id: 'verified-user',
        username: 'VerifiedReporter',
      });
      await setDoc(doc(db, 'usernames', 'verifiedreporter'), { uid: 'verified-user' });
    });

    const db = testEnv.authenticatedContext('verified-user', verifiedClaims).firestore();
    const batch = writeBatch(db);
    batch.set(doc(db, 'posts', 'new-report'), postData('C.U.N.T.', {
      id: 'new-report',
      is_anonymous: false,
      author_username: 'VerifiedReporter',
      author_verified: true,
      user_id: 'verified-user',
      pending_review: true,
      scam_location: 'Saskatchewan',
      loss_item: 'Canola',
      loss_amount: 2500,
      has_images: true,
    }));
    batch.set(doc(db, 'posts', 'new-report', 'private', 'details'), {
      scammer_name: 'Accused Party',
      scammer_company: 'Example Co',
      scammer_phone: '',
      scammer_email: '',
      scam_location: 'Saskatchewan',
      loss_item: 'Canola',
      loss_amount: 2500,
      image_urls: ['https://example.invalid/evidence.jpg'],
      image_url: 'https://example.invalid/evidence.jpg',
    });
    batch.set(doc(db, 'posts_private', 'new-report'), {
      user_id: 'verified-user',
      created_at: Timestamp.fromMillis(3000),
    });

    await assertSucceeds(batch.commit());
  });

  test('unverified account cannot submit a registry report', async () => {
    await seedFirestore(async (db) => {
      await setDoc(doc(db, 'user_profiles', 'plain-user'), {
        id: 'plain-user',
        username: 'PlainReporter',
      });
      await setDoc(doc(db, 'usernames', 'plainreporter'), { uid: 'plain-user' });
    });

    const db = testEnv.authenticatedContext('plain-user', unverifiedClaims).firestore();
    const batch = writeBatch(db);
    batch.set(doc(db, 'posts', 'blocked-report'), postData('C.U.N.T.', {
      id: 'blocked-report',
      is_anonymous: false,
      author_username: 'PlainReporter',
      author_verified: false,
      user_id: 'plain-user',
      pending_review: true,
      scam_location: 'Saskatchewan',
      loss_item: 'Canola',
      loss_amount: 2500,
      has_images: true,
    }));
    batch.set(doc(db, 'posts', 'blocked-report', 'private', 'details'), {
      scammer_name: 'Accused Party',
      image_urls: ['https://example.invalid/evidence.jpg'],
    });
    batch.set(doc(db, 'posts_private', 'blocked-report'), {
      user_id: 'plain-user',
      created_at: Timestamp.fromMillis(3000),
    });

    await assertFails(batch.commit());
  });

  test('admin can list pending reports, approve one, and append an audit action', async () => {
    await seedFirestore(async (db) => {
      await setDoc(doc(db, 'admin_roles', 'admin-user'), { role: 'admin' });
      await setDoc(doc(db, 'posts', 'pending-report'), postData('C.U.N.T.', {
        id: 'pending-report',
        is_anonymous: false,
        author_username: 'Reporter',
        author_verified: true,
        user_id: 'reporter-uid',
        pending_review: true,
        scam_location: 'Saskatchewan',
        loss_item: 'Canola',
        loss_amount: 1000,
        has_images: true,
      }));
    });

    const db = testEnv.authenticatedContext('admin-user', unverifiedClaims).firestore();
    const pendingQuery = query(
      collection(db, 'posts'),
      where('category', '==', 'C.U.N.T.'),
      where('is_deleted', '==', false),
      where('pending_review', '==', true),
      orderBy('created_at', 'desc'),
    );
    const pending = await assertSucceeds(getDocs(pendingQuery));
    if (pending.size !== 1) throw new Error('Admin did not receive pending report');

    const batch = writeBatch(db);
    batch.update(doc(db, 'posts', 'pending-report'), {
      pending_review: false,
      approved_at: Timestamp.fromMillis(4000),
      approved_by: 'admin-user',
    });
    batch.set(doc(db, 'moderation_actions', 'approve-pending-report'), {
      post_id: 'pending-report',
      action: 'approved',
      moderator_id: 'admin-user',
      reason: '',
      created_at: Timestamp.fromMillis(4000),
    });
    await assertSucceeds(batch.commit());
  });

  test('admin can read only their own role document', async () => {
    await seedFirestore(async (db) => {
      await setDoc(doc(db, 'admin_roles', 'admin-user'), { role: 'admin' });
      await setDoc(doc(db, 'admin_roles', 'other-admin'), { role: 'admin' });
    });

    const db = testEnv.authenticatedContext('admin-user', unverifiedClaims).firestore();
    await assertSucceeds(getDoc(doc(db, 'admin_roles', 'admin-user')));
    await assertFails(getDoc(doc(db, 'admin_roles', 'other-admin')));
  });

  test('an unverified account cannot create a registry watch', async () => {
    const db = testEnv.authenticatedContext('plain-user', unverifiedClaims).firestore();
    await assertFails(setDoc(doc(db, 'watches', 'plain-user_registry-post'), {
      post_id: 'registry-post',
      title: 'Registry post',
      category: 'C.U.N.T.',
      last_seen_comment_count: 0,
      notifications_enabled: true,
      watched_at: Timestamp.fromMillis(3000),
      updated_at: Timestamp.fromMillis(3000),
      user_id: 'plain-user',
    }));
  });
});

describe('registry evidence storage boundary', () => {
  test('evidence is private to owner, verified accounts, and admins', async () => {
    const ownerStorage = testEnv
      .authenticatedContext('evidence-owner', unverifiedClaims)
      .storage();
    const evidencePath = 'post-images/scams/evidence-owner/proof.jpg';
    await assertSucceeds(uploadBytes(
      storageRef(ownerStorage, evidencePath),
      Buffer.from([0xff, 0xd8, 0xff, 0xd9]),
      { contentType: 'image/jpeg' },
    ));

    const anonymousStorage = testEnv
      .authenticatedContext('anon-user', anonymousClaims)
      .storage();
    const verifiedStorage = testEnv
      .authenticatedContext('verified-user', verifiedClaims)
      .storage();
    await assertFails(getBytes(storageRef(anonymousStorage, evidencePath)));
    await assertSucceeds(getBytes(storageRef(verifiedStorage, evidencePath)));
  });

  test('ordinary anonymous post images remain publicly readable', async () => {
    const ownerStorage = testEnv
      .authenticatedContext('image-owner', anonymousClaims)
      .storage();
    const imagePath = 'post-images/anonymous/image-owner/photo.jpg';
    await assertSucceeds(uploadBytes(
      storageRef(ownerStorage, imagePath),
      Buffer.from([0xff, 0xd8, 0xff, 0xd9]),
      { contentType: 'image/jpeg' },
    ));

    const publicStorage = testEnv.unauthenticatedContext().storage();
    await assertSucceeds(getBytes(storageRef(publicStorage, imagePath)));
  });
});
