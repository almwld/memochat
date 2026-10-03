// ============================================================
// MemoChat LiveKit / Firebase Admin token server
// ============================================================

const express = require('express');
const admin = require('firebase-admin');
const { AccessToken } = require('livekit-server-sdk');
const crypto = require('crypto');
require('dotenv').config();

const app = express();
app.use(express.json({ limit: '1mb' }));

const PORT = Number(process.env.PORT || 3000);
const LIVEKIT_URL = process.env.LIVEKIT_URL || '';

// Firebase Admin credentials are supplied through Railway environment variables.
if (!admin.apps.length) {
  const fs = require('fs');
  const path = require('path');
  let credential;
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    credential = admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON));
  } else if (fs.existsSync(path.join(__dirname, 'firebase-service-account.json'))) {
    credential = admin.credential.cert(require('./firebase-service-account.json'));
  } else {
    credential = admin.credential.applicationDefault();
  }
  admin.initializeApp({ credential });
}

const db = admin.firestore();
const NEXTCLOUD_URL = String(process.env.NEXTCLOUD_URL || '').replace(/\/$/, '');
const NEXTCLOUD_USERNAME = String(process.env.NEXTCLOUD_USERNAME || '');
const NEXTCLOUD_PASSWORD = String(process.env.NEXTCLOUD_PASSWORD || '');
const MAX_MEDIA_BYTES = 100 * 1024 * 1024;

function requireNextcloud() {
  if (!NEXTCLOUD_URL || !NEXTCLOUD_USERNAME || !NEXTCLOUD_PASSWORD) {
    const error = new Error('Nextcloud server configuration is incomplete');
    error.statusCode = 503;
    throw error;
  }
}

function sanitizePathPart(value) {
  return String(value || '')
    .trim()
    .replace(/\\/g, '')
    .replace(/\.\./g, '')
    .replace(/\//g, '_')
    .replace(/[^a-zA-Z0-9_\-.\u0600-\u06ff ]/g, '_')
    .replace(/\s+/g, '_')
    .slice(0, 180);
}

function nextcloudAuthHeader() {
  return 'Basic ' + Buffer.from(
    NEXTCLOUD_USERNAME + ':' + NEXTCLOUD_PASSWORD
  ).toString('base64');
}

function nextcloudDavUrl(remotePath) {
  const clean = String(remotePath || '')
    .replace(/^\/+/, '')
    .split('/')
    .filter(Boolean)
    .map(encodeURIComponent)
    .join('/');
  return NEXTCLOUD_URL + '/remote.php/dav/files/' +
    encodeURIComponent(NEXTCLOUD_USERNAME) + '/' + clean;
}

async function ensureNextcloudDirectories(directory) {
  requireNextcloud();
  let current = '';
  for (const part of String(directory || '').split('/').filter(Boolean)) {
    current = current ? current + '/' + part : part;
    const response = await fetch(nextcloudDavUrl(current), {
      method: 'MKCOL',
      headers: { Authorization: nextcloudAuthHeader() },
    });
    if (![201, 405].includes(response.status)) {
      throw new Error('Nextcloud MKCOL failed: HTTP ' + response.status);
    }
  }
}

async function createNextcloudShare(remotePath) {
  requireNextcloud();
  const response = await fetch(
    NEXTCLOUD_URL +
      '/ocs/v2.php/apps/files_sharing/api/v1/shares?format=json',
    {
      method: 'POST',
      headers: {
        Authorization: nextcloudAuthHeader(),
        'OCS-APIRequest': 'true',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        path: '/' + String(remotePath).replace(/^\/+/, ''),
        shareType: '3',
      }),
    }
  );
  if (!response.ok) return null;
  const body = await response.json().catch(() => null);
  const url = body?.ocs?.data?.url;
  return url ? String(url).replace(/\/$/, '') + '/download' : null;
}


async function verifyFirebaseUser(req) {
  const auth = String(req.headers.authorization || '');
  if (!auth.startsWith('Bearer ')) {
    const error = new Error('Authorization bearer token is required');
    error.statusCode = 401;
    throw error;
  }
  try {
    return await admin.auth().verifyIdToken(auth.substring(7));
  } catch (_) {
    const error = new Error('Invalid Firebase ID token');
    error.statusCode = 401;
    throw error;
  }
}

app.get('/health', (_req, res) => res.json({ success: true, service: 'memochat-livekit-token-server' }));
app.post(
  '/media/upload',
  express.raw({ type: 'application/octet-stream', limit: MAX_MEDIA_BYTES }),
  async (req, res) => {
    try {
      const decodedToken = await verifyFirebaseUser(req);
      if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
        return res.status(400).json({ success: false, message: 'Media body is required' });
      }
      const fileName = sanitizePathPart(req.query.fileName || 'media.bin');
      const logicalPath = String(req.query.path || 'uploads')
        .split('/')
        .map(sanitizePathPart)
        .filter(Boolean)
        .slice(0, 8)
        .join('/');
      const chatId = String(req.query.chatId || '').trim();

      if (chatId) {
        const chatSnapshot = await db.collection('chats').doc(chatId).get();
        const participants = chatSnapshot.exists && Array.isArray(chatSnapshot.data()?.participants)
          ? chatSnapshot.data().participants.map(String)
          : [];
        if (!participants.includes(decodedToken.uid)) {
          return res.status(403).json({ success: false, message: 'ليس لديك صلاحية رفع الوسائط لهذه المحادثة' });
        }
      }

      requireNextcloud();
      const ownerPath = 'Sehatak/users/' + sanitizePathPart(decodedToken.uid);
      const directory = ownerPath + '/' + logicalPath;
      await ensureNextcloudDirectories(directory);

      const remotePath = directory + '/' +
        crypto.randomUUID() + '_' + fileName;
      const uploadResponse = await fetch(nextcloudDavUrl(remotePath), {
        method: 'PUT',
        headers: {
          Authorization: nextcloudAuthHeader(),
          'Content-Type': String(req.query.mimeType || 'application/octet-stream'),
          'Content-Length': String(req.body.length),
        },
        body: req.body,
      });
      if (![201, 204].includes(uploadResponse.status)) {
        return res.status(502).json({
          success: false,
          message: 'فشل رفع الوسائط إلى Nextcloud',
          providerStatus: uploadResponse.status,
        });
      }

      const publicUrl = req.query.createShare === 'false'
        ? null
        : await createNextcloudShare(remotePath);

      return res.status(201).json({
        success: true,
        file: {
          provider: 'nextcloud',
          remotePath,
          fileName,
          mimeType: String(req.query.mimeType || 'application/octet-stream'),
          size: req.body.length,
          url: publicUrl,
          shareReady: Boolean(publicUrl),
        },
      });
    } catch (error) {
      const status = Number(error.statusCode) || 500;
      console.error('Media upload error:', error.message || error);
      return res.status(status).json({
        success: false,
        message: status >= 500 ? 'فشل رفع الوسائط' : error.message,
      });
    }
  }
);

app.post('/media/share', async (req, res) => {
  try {
    const decodedToken = await verifyFirebaseUser(req);
    const remotePath = String(req.body?.remotePath || '').replace(/^\/+/, '');
    const prefix = 'Sehatak/users/' + sanitizePathPart(decodedToken.uid) + '/';
    if (!remotePath.startsWith(prefix)) {
      return res.status(403).json({ success: false, message: 'ليس لديك صلاحية مشاركة هذا الملف' });
    }
    const url = await createNextcloudShare(remotePath);
    if (!url) return res.status(502).json({ success: false, message: 'تعذر إنشاء رابط المشاركة' });
    return res.json({ success: true, url });
  } catch (error) {
    const status = Number(error.statusCode) || 500;
    return res.status(status).json({ success: false, message: error.message || 'Share failed' });
  }
});



app.post('/token', async (req, res) => {
  try {
    const decodedToken = await verifyFirebaseUser(req);
    const roomName = String(req.body?.roomName || '').trim();
    const participantName = String(req.body?.participantName || decodedToken.name || 'مستخدم').trim();
    if (!roomName) return res.status(400).json({ success: false, message: 'roomName is required' });

    // A LiveKit room is issued only for a real, active Firestore call.
    // The room contract is call_<callId>; never trust an arbitrary room name
    // supplied by the client.
    const callIdMatch = /^call_([A-Za-z0-9_-]+)$/.exec(roomName);
    if (!callIdMatch) {
      return res.status(400).json({
        success: false,
        message: 'roomName غير صالح: يجب أن يكون call_<callId>',
      });
    }
    const callId = callIdMatch[1];
    const callSnapshot = await db.collection('calls').doc(callId).get();
    if (!callSnapshot.exists) {
      return res.status(404).json({
        success: false,
        message: 'المكالمة غير موجودة',
      });
    }

    const call = callSnapshot.data() || {};
    const callerId = String(call.callerId || '');
    const receiverId = String(call.receiverId || '');
    const callRoomName = String(
      call.liveKitRoomName || call.roomName || '',
    ).trim();
    const callStatus = String(call.status || '').trim();

    if (callerId !== decodedToken.uid && receiverId !== decodedToken.uid) {
      return res.status(403).json({
        success: false,
        message: 'ليس لديك صلاحية الانضمام إلى هذه المكالمة',
      });
    }

    if (callRoomName !== roomName) {
      return res.status(403).json({
        success: false,
        message: 'غرفة LiveKit لا تطابق المكالمة',
      });
    }

    if (!['calling', 'ringing', 'accepted', 'connected'].includes(callStatus)) {
      return res.status(409).json({
        success: false,
        message: 'المكالمة لم تعد نشطة',
        status: callStatus,
      });
    }

    const apiKey = process.env.LIVEKIT_API_KEY;
    const apiSecret = process.env.LIVEKIT_API_SECRET;
    if (!apiKey || !apiSecret || !LIVEKIT_URL) return res.status(500).json({ success: false, message: 'LiveKit server configuration is incomplete' });
    const token = new AccessToken(apiKey, apiSecret, {
      identity: decodedToken.uid,
      name: participantName.slice(0, 120),
      ttl: '1h',
    });
    token.addGrant({ roomJoin: true, room: roomName, canPublish: true, canSubscribe: true, canPublishData: true });
    const jwt = await token.toJwt();
    return res.json({ success: true, data: { token: jwt, url: LIVEKIT_URL, roomName, participantIdentity: decodedToken.uid, participantName: participantName.slice(0, 120) } });
  } catch (error) {
    const status = Number(error.statusCode) || 500;
    if (status >= 500) console.error('Token error:', error.message || error);
    return res.status(status).json({ success: false, message: error.message || 'Unable to create LiveKit token' });
  }
});

// Production incoming-call notification endpoint.
// Flutter creates the canonical calls/{callId} document, then calls this endpoint.
// Railway verifies the caller and sends FCM directly, so Firebase Cloud Functions/Blaze are not required.
// Incoming calls remain DATA-ONLY so Flutter can own the full-screen call notification
// and answer/reject actions. Text messages intentionally use notification + data below
// so Android can place them in the system tray while the app is backgrounded.
app.post('/call-notification', async (req, res) => {
  const requestId = `call-notify-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  console.log(`📞 [${requestId}] incoming /call-notification request`);
  try {
    const decodedToken = await verifyFirebaseUser(req);
    const body = req.body && typeof req.body === 'object' ? req.body : {};
    const callId = String(body.callId || '').trim();
    console.log(`📞 [${requestId}] authenticated uid=${decodedToken.uid} callId=${callId || '(missing)'}`);
    if (!callId) return res.status(400).json({ success: false, message: 'callId is required', requestId });

    const callSnapshot = await db.collection('calls').doc(callId).get();
    if (!callSnapshot.exists) {
      console.error(`❌ [${requestId}] call not found id=${callId}`);
      return res.status(404).json({ success: false, message: 'Call not found', requestId });
    }

    const call = callSnapshot.data() || {};
    const callerId = String(call.callerId || '');
    const receiverId = String(call.receiverId || '').trim();
    const status = String(call.status || '');
    const chatId = String(call.chatId || '').trim();
    console.log(`📋 [${requestId}] call status=${status} caller=${callerId} receiver=${receiverId} chatId=${chatId || '(missing)'}`);

    if (callerId !== String(decodedToken.uid)) {
      console.error(`❌ [${requestId}] caller authorization mismatch token=${decodedToken.uid} call.callerId=${callerId}`);
      return res.status(403).json({ success: false, message: 'Caller is not authorized for this call', requestId });
    }
    if (!['calling', 'ringing'].includes(status)) {
      console.warn(`⚠️ [${requestId}] call no longer ringing status=${status}`);
      return res.status(409).json({ success: false, message: 'Call is no longer ringing', status, requestId });
    }
    if (!receiverId || receiverId === decodedToken.uid) {
      console.error(`❌ [${requestId}] invalid receiverId=${receiverId}`);
      return res.status(400).json({ success: false, message: 'Invalid receiverId', requestId });
    }
    if (!chatId) {
      console.error(`❌ [${requestId}] call has no chatId callId=${callId}`);
      return res.status(400).json({ success: false, reason: 'missing_chat_id', message: 'Call chatId is required for incoming-call UI', requestId });
    }

    const receiverSnapshot = await db.collection('users').doc(receiverId).get();
    if (!receiverSnapshot.exists) {
      console.error(`❌ [${requestId}] receiver user not found uid=${receiverId}`);
      return res.status(404).json({ success: false, message: 'Receiver not found', requestId });
    }
    const receiver = receiverSnapshot.data() || {};
    // Canonical Flutter path: users/{uid}/private/tokens.tokens
    // Keep root fields as a legacy compatibility fallback.
    const tokenSnapshot = await db.collection('users').doc(receiverId)
      .collection('private').doc('tokens').get();
    const tokenData = tokenSnapshot.exists ? (tokenSnapshot.data() || {}) : {};
    const fcmTokens = [
      ...(Array.isArray(tokenData.tokens) ? tokenData.tokens : []),
      ...(Array.isArray(receiver.fcmTokens) ? receiver.fcmTokens : []),
      receiver.fcmToken,
    ]
      .map((value) => String(value || '').trim())
      .filter(Boolean)
      .filter((value, index, all) => all.indexOf(value) === index);

    if (!fcmTokens.length) {
      console.error(`❌ [${requestId}] receiver has no FCM token(s) uid=${receiverId}`);
      return res.status(200).json({ success: true, sent: false, reason: 'fcm_token_missing', requestId });
    }

    const isVideo = call.isVideoCall === true || String(call.callType || '') === 'video';
    const callerName = String(call.callerName || decodedToken.name || 'مستخدم');
    const callerPhotoUrl = String(call.callerPhotoUrl || '');
    // Incoming calls intentionally use a HIGH-prIORITY data-only payload.
    // This lets FirebaseMessaging.onBackgroundMessage run and hand the call
    // to NotificationService, which owns the IMPORTANCE_MAX + full-screen
    // notification and call action buttons. A notification payload would let
    // Android render a normal status-bar notification, but would bypass this
    // Flutter full-screen call path while the app is backgrounded/terminated.
    const message = {
      tokens: fcmTokens,
      data: {
        type: 'incoming_call',
        callId,
        chatId,
        callerId,
        receiverId,
        userId: receiverId,
        callerName,
        callerPhotoUrl,
        isVideo: isVideo ? 'true' : 'false',
        callType: isVideo ? 'video' : 'audio',
      },
      android: {
        priority: 'high',
        ttl: 60 * 1000,
      },
    };
    console.log(`📤 [${requestId}] sending HIGH-priority DATA-ONLY FCM receiver=${receiverId} tokens=${fcmTokens.length} type=incoming_call isVideo=${isVideo} chatId=${chatId}`);
    try {
      const response = await admin.messaging().sendEachForMulticast(message);
      const invalidTokens = [];
      response.responses.forEach((result, index) => {
        if (!result.success && ['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(result.error?.code)) {
          invalidTokens.push(fcmTokens[index]);
        }
      });
      if (invalidTokens.length) {
        await db.collection('users').doc(receiverId).set({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
          ...(fcmTokens.every((token) => invalidTokens.includes(token))
            ? { fcmToken: null }
            : {}),
          lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      if (response.failureCount === response.successCount + response.failureCount && response.successCount === 0) {
        const firstError = response.responses.find((result) => !result.success)?.error;
        console.error(`❌ [${requestId}] all FCM tokens failed code=${firstError?.code || 'unknown'} message=${firstError?.message || 'unknown'}`);
        return res.status(502).json({ success: false, sent: false, reason: firstError?.code || 'fcm_send_failed', requestId });
      }
      console.log(`✅ [${requestId}] FCM accepted success=${response.successCount} failure=${response.failureCount}`);
      return res.json({ success: true, sent: response.successCount > 0, successCount: response.successCount, failureCount: response.failureCount, callId, receiverId, requestId, mode: 'data_only_multicast' });
    } catch (error) {
      console.error(`❌ [${requestId}] Incoming call FCM error code=${error.code || 'unknown'} message=${error.message || error}`);
      return res.status(502).json({ success: false, sent: false, reason: error.code || 'fcm_send_failed', requestId });
    }
  } catch (error) {
    const status = Number(error.statusCode) || 500;
    console.error(`❌ [${requestId}] Call notification error status=${status} message=${error.message || error}`);
    return res.status(status).json({ success: false, message: error.message || 'Unable to send incoming call notification', requestId });
  }
});

// ============================================================
// Firestore -> FCM: New chat message listener
// ============================================================
function buildMessagePayload(opts) {
  var preview = String(opts.messageText || '').slice(0, 120);
  return {
    token: opts.fcmToken,
    // Notification + data is intentional for chat messages: Android can render
    // the message in the system tray while the data payload preserves chat routing.
    notification: {
      title: String(opts.senderName || 'رسالة جديدة'),
      body: preview || 'لديك رسالة جديدة في الدردشة',
    },
    data: {
      type: 'new_message',
      chatId: String(opts.chatId || ''),
      messageId: String(opts.messageId || ''),
      senderId: String(opts.senderId || ''),
      senderName: String(opts.senderName || 'user'),
      senderPhotoUrl: String(opts.senderPhotoUrl || ''),
      messageType: String(opts.messageType || 'text'),
      imageUrl: String(opts.imageUrl || ''),
      videoUrl: String(opts.videoUrl || ''),
      audioUrl: String(opts.audioUrl || ''),
      fileUrl: String(opts.fileUrl || ''),
      fileName: String(opts.fileName || ''),
      fileMimeType: String(opts.fileMimeType || ''),
      fileSize: String(opts.fileSize || ''),
      body: preview,
      title: String(opts.senderName || 'رسالة جديدة'),
      chatType: String(opts.chatType || 'direct'),
      timestamp: String(Date.now())
    },
    android: {
      priority: 'high',
      ttl: 3600000,
      notification: {
        channelId: 'sehatak_messages_v2',
        sound: 'notification',
        priority: 'high',
      },
    },
    apns: {
      headers: { 'apns-priority': '5', 'apns-push-type': 'background' },
      payload: { aps: { 'content-available': 1 } }
    }
  };
}

async function handleNewMessage(change) {
  try {
    var msg = change.doc.data() || {};
    // Call timeline entries are not chat messages. The dedicated
    // /call-notification endpoint already sends the incoming-call FCM, so
    // never emit a second notification that opens the chat room.
    if (msg.type === 'call' || (msg.metadata && msg.metadata.callId) || msg.callId) return;
    var messageId = change.doc.id;
    var parent = change.doc.ref.parent;
    var chatId = parent && parent.parent ? parent.parent.id : null;
    if (!chatId) { console.warn('[msg] no chatId id=' + messageId); return; }

    var senderId = String(msg.senderId || '');
    if (!senderId) { console.warn('[msg] no senderId id=' + messageId); return; }

    var senderName = String(msg.senderName || msg.senderDisplayName || '');
    var senderPhotoUrl = String(msg.senderPhotoUrl || msg.senderAvatar || '');
    var messageType = String(msg.type || 'text');
    var imageUrl = String(msg.imageUrl || '');
    var videoUrl = String(msg.videoUrl || '');
    var audioUrl = String(msg.audioUrl || '');
    var fileUrl = String(msg.fileUrl || '');
    var fileName = String(msg.fileName || '');
    var fileMimeType = String(msg.fileMimeType || msg.fileType || '');
    var fileSize = String(msg.fileSize || '');
    var messageText = '';
    if (typeof msg.text === 'string') messageText = msg.text;
    else if (typeof msg.message === 'string') messageText = msg.message;
    else if (typeof msg.content === 'string') messageText = msg.content;

    var chatSnap = await db.collection('chats').doc(chatId).get();
    if (!chatSnap.exists) { console.warn('[msg] chat missing id=' + chatId); return; }
    var chat = chatSnap.data() || {};

    var participants = Array.isArray(chat.participants)
      ? chat.participants.map(String).filter(Boolean) : [];
    if (participants.length === 0) { console.warn('[msg] no participants'); return; }

    var receivers = participants.filter(function(id) { return id !== senderId; });
    if (receivers.length === 0) { console.log('[msg] self-chat'); return; }

    var userRefs = receivers.map(function(uid) { return db.collection('users').doc(uid); });
    var userSnaps = await db.getAll.apply(db, userRefs);

    var chatType = String(chat.type || 'direct');
    var senderLabel = senderName || 'user';
    var sentCount = 0;
    var i;

    for (i = 0; i < userSnaps.length; i++) {
      var userSnap = userSnaps[i];
      if (!userSnap.exists) continue;
      var receiverId = userSnap.id;
      var mutedFor = chat.mutedFor && typeof chat.mutedFor === 'object' ? chat.mutedFor : {};
      if (chat.isMuted === true || chat.muted === true || mutedFor[receiverId] === true) {
        console.log('[msg] muted chatId=' + chatId + ' receiver=' + receiverId);
        continue;
      }
      var user = userSnap.data() || {};
      // Canonical Flutter path: users/{uid}/private/tokens.tokens
      // Keep root fields as a legacy compatibility fallback.
      var tokenSnap = await db.collection('users').doc(receiverId)
        .collection('private').doc('tokens').get();
      var tokenData = tokenSnap.exists ? (tokenSnap.data() || {}) : {};
      var fcmTokens = (Array.isArray(tokenData.tokens) ? tokenData.tokens : [])
        .concat(Array.isArray(user.fcmTokens) ? user.fcmTokens : [])
        .concat([user.fcmToken])
        .map(function(value) { return String(value || '').trim(); })
        .filter(Boolean)
        .filter(function(value, index, all) { return all.indexOf(value) === index; });
      if (!fcmTokens.length) {
        console.warn('[msg] no FCM token for receiver=' + receiverId +
          ' (checked users/{uid}/private/tokens and legacy root fields)');
        continue;
      }

      for (var ti = 0; ti < fcmTokens.length; ti++) {
        var fcmToken = fcmTokens[ti];
        var payload = buildMessagePayload({
          fcmToken: fcmToken,
          senderId: senderId,
          senderName: senderLabel,
          senderPhotoUrl: senderPhotoUrl,
          chatId: chatId,
          messageId: messageId,
          messageText: messageText,
          chatType: chatType,
          messageType: messageType,
          imageUrl: imageUrl,
          videoUrl: videoUrl,
          audioUrl: audioUrl,
          fileUrl: fileUrl,
          fileName: fileName,
          fileMimeType: fileMimeType,
          fileSize: fileSize
        });

        try {
          var fcmId = await admin.messaging().send(payload);
          sentCount++;
          console.log('[msg] sent id=' + messageId + ' to=' + userSnap.id + ' tokenIndex=' + ti + ' fcm=' + fcmId);
        } catch (err) {
          console.error('[msg] FCM failed to=' + userSnap.id + ' tokenIndex=' + ti + ' code=' + (err.code || '?'));
          if (err.code === 'messaging/registration-token-not-registered' ||
              err.code === 'messaging/invalid-registration-token') {
            await db.collection('users').doc(userSnap.id).set(
              { fcmTokens: admin.firestore.FieldValue.arrayRemove(fcmToken) }, { merge: true }
            );
          }
        }
      }
    }
    console.log('[msg] done id=' + messageId + ' sent=' + sentCount + '/' + receivers.length);
  } catch (err) {
    console.error('[msg] handler error: ' + (err.message || err));
  }
}

function startMessageListener() {
  try {
    var startTime = new Date();
    console.log('[msg] listener starting since ' + startTime.toISOString());
    db.collectionGroup('messages')
      .where('timestamp', '>=', startTime)
      .orderBy('timestamp', 'asc')
      .onSnapshot(
        function(snap) {
          snap.docChanges().forEach(function(change) {
            if (change.type !== 'added') return;
            handleNewMessage(change).catch(function(err) {
              console.error('[msg] unhandled: ' + (err.message || err));
            });
          });
        },
        function(err) { console.error('[msg] snapshot error: ' + (err.message || err)); }
      );
    console.log('[msg] listener active.');
  } catch (err) {
    console.error('[msg] listener failed: ' + (err.message || err));
  }
}
// ============================================================

app.use((error, _req, res, _next) => {
  if (error instanceof SyntaxError) return res.status(400).json({ success: false, message: 'Invalid JSON body' });
  console.error('Request error:', error);
  return res.status(500).json({ success: false, message: 'Internal server error' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`MemoChat LiveKit token server running on port ${PORT}`);
  console.log(`LIVEKIT_URL: ${LIVEKIT_URL}`);
  startMessageListener();
});