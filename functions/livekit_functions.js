const admin = require('firebase-admin');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const {AccessToken} = require('livekit-server-sdk');

const LIVEKIT_API_KEY = defineSecret('LIVEKIT_API_KEY');
const LIVEKIT_API_SECRET = defineSecret('LIVEKIT_API_SECRET');

function requireAuth(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'يجب تسجيل الدخول أولاً');
  }
  return request.auth.uid;
}

function requiredText(value, field, max = 200) {
  const result = String(value || '').trim();
  if (!result || result.length > max) {
    throw new HttpsError('invalid-argument', `الحقل ${field} غير صالح`);
  }
  return result;
}

exports.createLiveKitToken = onCall(
  {
    region: 'us-central1',
    secrets: [LIVEKIT_API_KEY, LIVEKIT_API_SECRET],
    enforceAppCheck: false,
  },
  async (request) => {
    const uid = requireAuth(request);
    const roomName = requiredText(request.data?.roomName, 'roomName', 200);
    const participantName = requiredText(request.data?.participantName || uid, 'participantName', 120);
    const participantIdentity = requiredText(
      request.data?.participantIdentity || uid,
      'participantIdentity',
      128,
    );

    if (participantIdentity !== uid) {
      throw new HttpsError('permission-denied', 'هوية المشارك لا تطابق حساب Firebase');
    }

    // LiveKit tokens are only issued for a real active call. The room name
    // contract is call_<callId>, and the authenticated user must be one of
    // the two participants stored by CallService.
    const match = /^call_([A-Za-z0-9_-]+)$/.exec(roomName);
    if (!match) {
      throw new HttpsError('invalid-argument', 'roomName غير صالح');
    }
    const callId = match[1];
    const callSnap = await admin.firestore().collection('calls').doc(callId).get();
    if (!callSnap.exists) {
      throw new HttpsError('not-found', 'المكالمة غير موجودة');
    }
    const call = callSnap.data() || {};
    const callerId = String(call.callerId || '');
    const receiverId = String(call.receiverId || '');
    const storedRoom = String(call.liveKitRoomName || call.roomName || '');
    const status = String(call.status || '');
    if (participantIdentity !== callerId && participantIdentity !== receiverId) {
      throw new HttpsError('permission-denied', 'ليس لديك صلاحية الانضمام إلى هذه المكالمة');
    }
    if (storedRoom !== roomName) {
      throw new HttpsError('permission-denied', 'غرفة LiveKit لا تطابق المكالمة');
    }
    if (!['calling', 'ringing', 'connected'].includes(status)) {
      throw new HttpsError('failed-precondition', 'المكالمة لم تعد نشطة');
    }

    const apiKey = LIVEKIT_API_KEY.value();
    const apiSecret = LIVEKIT_API_SECRET.value();
    if (!apiKey || !apiSecret) {
      throw new HttpsError('failed-precondition', 'إعدادات LiveKit غير مكتملة على الخادم');
    }

    const token = new AccessToken(apiKey, apiSecret, {
      identity: participantIdentity,
      name: participantName,
      ttl: '1h',
    });
    token.addGrant({
      roomJoin: true,
      room: roomName,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    });

    const jwt = await token.toJwt();
    return {
      success: true,
      data: {
        token: jwt,
        url: 'wss://memo-2jv45qyl.livekit.cloud',
        roomName,
        participantIdentity,
        participantName,
      },
    };
  },
);


// Voice-room token endpoint. Voice rooms use a separate namespace from
// one-to-one calls and therefore must not be forced through calls/{callId}.
exports.createVoiceRoomToken = onCall(
  {
    region: 'us-central1',
    secrets: [LIVEKIT_API_KEY, LIVEKIT_API_SECRET],
    enforceAppCheck: false,
  },
  async (request) => {
    const uid = requireAuth(request);
    const roomId = requiredText(request.data?.roomId, 'roomId', 128);
    const roomName = requiredText(request.data?.roomName, 'roomName', 200);
    const participantName = requiredText(
      request.data?.participantName || uid,
      'participantName',
      120,
    );

    if (!/^memo_voice_[A-Za-z0-9_-]+$/.test(roomName)) {
      throw new HttpsError('invalid-argument', 'اسم غرفة الصوت غير صالح');
    }

    const roomSnap = await admin.firestore().collection('voiceRooms').doc(roomId).get();
    if (!roomSnap.exists) {
      throw new HttpsError('not-found', 'غرفة الصوت غير موجودة');
    }
    const room = roomSnap.data() || {};
    if (room.active !== true) {
      throw new HttpsError('failed-precondition', 'غرفة الصوت غير نشطة');
    }
    if (String(room.roomName || '') !== roomName) {
      throw new HttpsError('permission-denied', 'غرفة LiveKit لا تطابق غرفة الصوت');
    }

    const memberSnap = await admin.firestore()
      .collection('voiceRooms').doc(roomId)
      .collection('members').doc(uid).get();
    if (!memberSnap.exists) {
      throw new HttpsError('permission-denied', 'يجب الانضمام إلى غرفة الصوت أولاً');
    }

    const apiKey = LIVEKIT_API_KEY.value();
    const apiSecret = LIVEKIT_API_SECRET.value();
    if (!apiKey || !apiSecret) {
      throw new HttpsError('failed-precondition', 'إعدادات LiveKit غير مكتملة على الخادم');
    }

    const token = new AccessToken(apiKey, apiSecret, {
      identity: uid,
      name: participantName,
      ttl: '2h',
    });
    token.addGrant({
      roomJoin: true,
      room: roomName,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    });

    return {
      success: true,
      data: {
        token: await token.toJwt(),
        url: 'wss://memo-2jv45qyl.livekit.cloud',
        roomName,
        participantIdentity: uid,
        participantName,
      },
    };
  },
);
