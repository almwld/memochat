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
        url: 'wss://platformmemochat-z73p6n5m.livekit.cloud',
        roomName,
        participantIdentity,
        participantName,
      },
    };
  },
);
