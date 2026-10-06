const fs = require('node:fs');
const path = require('node:path');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: 'demo-memochat-rules',
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
  });

  try {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();

      await setDoc(doc(db, 'chats/chat-1'), {
        participants: ['alice', 'bob'],
      });

      await setDoc(doc(db, 'chats/chat-1/messages/message-1'), {
        chatId: 'chat-1',
        senderId: 'alice',
        text: 'hello',
        type: 'text',
        isRead: false,
        isDelivered: false,
        status: 'sent',
      });

      await setDoc(doc(db, 'notifications/n-1'), {
        userId: 'alice',
        type: 'message',
        title: 'Hello',
        isRead: false,
      });
    });

    const alice = testEnv.authenticatedContext('alice').firestore();
    const bob = testEnv.authenticatedContext('bob').firestore();
    const mallory = testEnv.authenticatedContext('mallory').firestore();

    await assertSucceeds(
      getDoc(doc(alice, 'chats/chat-1/messages/message-1')),
    );
    await assertFails(
      getDoc(doc(mallory, 'chats/chat-1/messages/message-1')),
    );

    await assertSucceeds(
      updateDoc(doc(alice, 'chats/chat-1/messages/message-1'), {
        text: 'edited',
        isEdited: true,
      }),
    );

    await assertFails(
      updateDoc(doc(alice, 'chats/chat-1/messages/message-1'), {
        senderId: 'mallory',
      }),
    );

    await assertSucceeds(
      updateDoc(doc(bob, 'chats/chat-1/messages/message-1'), {
        isRead: true,
        readAt: 'server',
      }),
    );

    await assertFails(
      updateDoc(doc(bob, 'chats/chat-1/messages/message-1'), {
        text: 'tampered',
      }),
    );

    await assertSucceeds(
      updateDoc(doc(alice, 'notifications/n-1'), {
        isRead: true,
        readAt: 'server',
      }),
    );

    await assertFails(
      updateDoc(doc(alice, 'notifications/n-1'), {
        userId: 'mallory',
      }),
    );

    await assertFails(deleteDoc(doc(mallory, 'notifications/n-1')));

    await assertSucceeds(
      setDoc(doc(alice, 'users/alice/notificationHistory/h-1'), {
        type: 'message', title: 'Hello', body: 'Test', read: false,
      }),
    );
    await assertSucceeds(
      updateDoc(doc(alice, 'users/alice/notificationHistory/h-1'), {
        read: true, readAt: 'server',
      }),
    );
    await assertFails(
      getDoc(doc(bob, 'users/alice/notificationHistory/h-1')),
    );

    await assertSucceeds(
      setDoc(doc(alice, 'users/alice/devices/device-1'), {platform: 'android'}),
    );
    await assertFails(
      setDoc(doc(bob, 'users/alice/devices/device-2'), {platform: 'android'}),
    );

    await assertSucceeds(
      setDoc(doc(alice, 'users/alice/relationships/bob'), {blocked: true}),
    );
    await assertFails(
      setDoc(doc(alice, 'users/alice/relationships/alice'), {blocked: true}),
    );

    await assertSucceeds(
      setDoc(doc(alice, 'users/alice/miniApps/maps'), {state: {zoom: 5}}),
    );
    await assertFails(
      getDoc(doc(bob, 'users/alice/miniApps/maps')),
    );

    await assertSucceeds(
      setDoc(doc(alice, 'users/alice/syncQueue/job-1'), {state: 'pending'}),
    );
    await assertFails(
      setDoc(doc(bob, 'users/alice/syncQueue/job-2'), {state: 'pending'}),
    );

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'communities/community-1'), {
        ownerId: 'alice',
        name: 'Developers',
        description: 'Dev community',
        visibility: 'public',
        membersCount: 1,
      });
      await setDoc(doc(db, 'communities/community-1/members/alice'), {
        userId: 'alice',
        role: 'owner',
      });
      await setDoc(doc(db, 'communities/community-1/channels/general'), {
        communityId: 'community-1',
        ownerId: 'alice',
        name: 'General',
      });
    });

    await assertSucceeds(
      getDoc(doc(alice, 'communities/community-1')),
    );
    await assertSucceeds(
      setDoc(doc(bob, 'communities/community-1/members/bob'), {
        userId: 'bob',
        role: 'member',
      }),
    );
    await assertFails(
      setDoc(doc(mallory, 'communities/community-1/channels/bad'), {
        communityId: 'community-1',
        ownerId: 'mallory',
        name: 'Bad',
      }),
    );
    await assertSucceeds(
      setDoc(doc(bob, 'communities/community-1/channels/general/posts/post-1'), {
        authorId: 'bob',
        text: 'hello community',
      }),
    );
    await assertFails(
      getDoc(doc(mallory, 'communities/community-1/channels/general/posts/post-1')),
    );

    console.log('Firestore security rules: all tests passed.');
    await assertFails(
      setDoc(doc(alice, 'reports/report-1'), {
        reporterId: 'mallory',
        targetUserId: 'bob',
        reason: 'spam',
        createdAt: new Date(),
      }),
    );

    await assertSucceeds(
      setDoc(doc(alice, 'reports/report-2'), {
        reporterId: 'alice',
        targetUserId: 'bob',
        reason: 'spam',
        createdAt: new Date(),
      }),
    );

    await assertFails(
      getDoc(doc(bob, 'reports/report-2')),
    );
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
