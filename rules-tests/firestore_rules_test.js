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

      await setDoc(doc(db, 'calls/call-1'), {
        id: 'call-1',
        chatId: 'chat-1',
        callerId: 'alice',
        receiverId: 'bob',
        participants: ['alice', 'bob'],
        callType: 'audio',
        status: 'calling',
        liveKitRoomName: 'call_call-1',
        roomName: 'call_call-1',
      });

      await setDoc(doc(db, 'callLocks/alice_bob'), {
        participants: ['alice', 'bob'],
        activeCallId: 'call-1',
        status: 'calling',
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
      updateDoc(doc(bob, 'calls/call-1'), {
        status: 'connected',
        isAnswered: true,
      }),
    );

    await assertFails(
      updateDoc(doc(bob, 'calls/call-1'), {
        receiverId: 'mallory',
      }),
    );

    await assertSucceeds(
      updateDoc(doc(alice, 'callLocks/alice_bob'), {
        activeCallId: null,
        status: 'ended',
      }),
    );

    await assertFails(
      updateDoc(doc(alice, 'callLocks/alice_bob'), {
        participants: ['alice', 'mallory'],
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

    console.log('Firestore security rules: all tests passed.');
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
