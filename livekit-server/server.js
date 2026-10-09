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
const LIVEKIT_URL = String(process.env.LIVEKIT_URL || 'wss://memo-2jv45qyl.livekit.cloud').trim();

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
      const ownerPath = 'MemoChat/users/' + sanitizePathPart(decodedToken.uid);
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
    const prefix = 'MemoChat/users/' + sanitizePathPart(decodedToken.uid) + '/';
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


// Voice-room token endpoint. Voice rooms are persisted under voiceRooms/{roomId}
// and are intentionally isolated from one-to-one calls/{callId}.
app.post('/voice-token', async (req, res) => {
  try {
    const decodedToken = await verifyFirebaseUser(req);
    const roomId = String(req.body?.roomId || '').trim();
    const roomName = String(req.body?.roomName || '').trim();
    const participantName = String(req.body?.participantName || decodedToken.name || 'مستخدم').trim();

    if (!roomId || !roomName) {
      return res.status(400).json({ success: false, message: 'roomId و roomName مطلوبان' });
    }
    if (!/^memo_voice_[A-Za-z0-9_-]+$/.test(roomName)) {
      return res.status(400).json({ success: false, message: 'اسم غرفة الصوت غير صالح' });
    }

    const roomSnapshot = await db.collection('voiceRooms').doc(roomId).get();
    if (!roomSnapshot.exists) {
      return res.status(404).json({ success: false, message: 'غرفة الصوت غير موجودة' });
    }
    const room = roomSnapshot.data() || {};
    if (room.active !== true) {
      return res.status(409).json({ success: false, message: 'غرفة الصوت مغلقة' });
    }
    if (String(room.roomName || '') !== roomName) {
      return res.status(403).json({ success: false, message: 'اسم LiveKit لا يطابق غرفة الصوت' });
    }

    const memberSnapshot = await db.collection('voiceRooms').doc(roomId)
      .collection('members').doc(decodedToken.uid).get();
    if (!memberSnapshot.exists) {
      return res.status(403).json({ success: false, message: 'انضم إلى الغرفة أولاً' });
    }
    const member = memberSnapshot.data() || {};
    const role = String(member.role || 'listener').trim().toLowerCase();
    const canPublish = role === 'host' || role === 'speaker' || role === 'moderator';
    const canPublishData = canPublish;

    const apiKey = process.env.LIVEKIT_API_KEY;
    const apiSecret = process.env.LIVEKIT_API_SECRET;
    if (!apiKey || !apiSecret || !LIVEKIT_URL) {
      return res.status(500).json({ success: false, message: 'إعدادات LiveKit غير مكتملة' });
    }

    const token = new AccessToken(apiKey, apiSecret, {
      identity: decodedToken.uid,
      name: participantName.slice(0, 120),
      ttl: '2h',
    });
    token.addGrant({
      roomJoin: true,
      room: roomName,
      canPublish,
      canSubscribe: true,
      canPublishData,
    });

    return res.json({
      success: true,
      data: {
        token: await token.toJwt(),
        url: LIVEKIT_URL,
        roomName,
        participantIdentity: decodedToken.uid,
        participantName: participantName.slice(0, 120),
      },
    });
  } catch (error) {
    const status = Number(error.statusCode) || 500;
    console.error('Voice token error:', error.message || error);
    return res.status(status).json({
      success: false,
      message: error.message || 'تعذر إنشاء توكن غرفة الصوت',
    });
  }
});

// ============================================================
// Incoming call FCM bridge
// ============================================================
// Firestore remains the source of truth. This endpoint only wakes the
// receiver with a high-priority data-only FCM message.
app.post('/call-notification', async (req, res) => {
  const requestId = `call-notify-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  try {
    const decodedToken = await verifyFirebaseUser(req);
    const callId = String(req.body?.callId || '').trim();
    if (!/^[A-Za-z0-9_-]{1,180}$/.test(callId)) {
      return res.status(400).json({ success: false, message: 'A valid callId is required', requestId });
    }

    const callSnapshot = await db.collection('calls').doc(callId).get();
    if (!callSnapshot.exists) return res.status(404).json({ success: false, message: 'Call not found', requestId });

    const call = callSnapshot.data() || {};
    const callerId = String(call.callerId || '');
    const receiverId = String(call.receiverId || '').trim();
    const status = String(call.status || '').trim();
    const chatId = String(call.chatId || '').trim();

    if (callerId !== decodedToken.uid) {
      return res.status(403).json({ success: false, message: 'Caller is not authorized for this call', requestId });
    }
    if (!['calling', 'ringing'].includes(status)) {
      return res.status(409).json({ success: false, message: 'Call is no longer ringing', status, requestId });
    }
    if (!receiverId || receiverId === decodedToken.uid || !chatId) {
      return res.status(400).json({ success: false, message: 'Invalid call participants', requestId });
    }

    const tokenSnapshot = await db.collection('users').doc(receiverId)
      .collection('private').doc('tokens').get();
    const tokenData = tokenSnapshot.exists ? (tokenSnapshot.data() || {}) : {};
    const fcmTokens = Array.isArray(tokenData.tokens)
      ? [...new Set(tokenData.tokens.map(v => String(v || '').trim()).filter(Boolean))]
      : [];

    if (!fcmTokens.length) {
      // A 2xx response is interpreted by CallService as a successful wake-up.
      // Fail explicitly when no device can receive the external call alert.
      return res.status(503).json({
        success: false,
        sent: false,
        code: 'FCM_TOKEN_MISSING',
        message: 'The receiver has no registered push token',
        receiverId,
        requestId,
      });
    }

    const message = {
      tokens: fcmTokens,
      data: {
        type: 'incoming_call',
        notificationId: callId,
        callId,
        chatId,
        senderId: callerId,
        senderName: String(call.callerName || 'مستخدم'),
        senderPhotoUrl: String(call.callerPhotoUrl || ''),
        recipientId: receiverId,
        callerId,
        receiverId,
        userId: receiverId,
        callerName: String(call.callerName || 'مستخدم'),
        callerPhotoUrl: String(call.callerPhotoUrl || ''),
        title: String(call.callerName || 'مستخدم'),
        body: (call.isVideoCall === true || call.isVideo === true || call.callType === 'video')
          ? 'مكالمة فيديو واردة'
          : 'مكالمة صوتية واردة',
        route: 'call:' + callId,
        timestamp: String(Date.now()),
        isVideo: (call.isVideoCall === true || call.isVideo === true || call.callType === 'video') ? 'true' : 'false',
        callType: String(call.callType || ((call.isVideoCall || call.isVideo) ? 'video' : 'audio')),
      },
      android: { priority: 'high', ttl: 60 * 1000 },
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    const invalidTokens = [];
    response.responses.forEach((result, index) => {
      if (!result.success && [
        'messaging/registration-token-not-registered',
        'messaging/invalid-registration-token',
      ].includes(result.error?.code)) {
        invalidTokens.push(fcmTokens[index]);
      }
    });
    if (invalidTokens.length) {
      await db.collection('users').doc(receiverId).collection('private').doc('tokens')
        .update({ tokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens) });
    }

    if (response.successCount === 0) {
      const firstError = response.responses.find(result => !result.success)?.error;
      return res.status(502).json({
        success: false, sent: false,
        reason: firstError?.code || 'fcm_send_failed',
        requestId,
      });
    }

    return res.json({
      success: true,
      sent: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
      callId,
      receiverId,
      requestId,
    });
  } catch (error) {
    const status = Number(error.statusCode) || 500;
    console.error('Call notification error:', error.message || error);
    return res.status(status).json({
      success: false,
      message: error.message || 'Unable to send incoming call notification',
      requestId,
    });
  }
});

app.use((error, _req, res, _next) => {
  if (error instanceof SyntaxError) return res.status(400).json({ success: false, message: 'Invalid JSON body' });
  console.error('Request error:', error);
  return res.status(500).json({ success: false, message: 'Internal server error' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`MemoChat LiveKit token server running on port ${PORT}`);
  console.log(`LIVEKIT_URL: ${LIVEKIT_URL}`);
});