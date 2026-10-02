# Sehatak LiveKit Token Server

خادم Node.js صغير مستقل لإصدار LiveKit JWT لتطبيق «صحتك».

- Firebase Auth هو مصدر الهوية والتحقق من المستخدم.
- Firebase/Firestore يبقى الـBackend الرئيسي للتطبيق.
- الخادم لا يخزن بيانات المستخدمين.
- `LIVEKIT_API_KEY` و`LIVEKIT_API_SECRET` أسرار ولا توضع في Git.
- مناسب للنشر على Railway من مجلد المستودع نفسه.

## تشغيل Railway

اضبط متغيرات الخدمة في Railway:

- `PORT` — Railway يضبطه تلقائياً، ويمكن تركه بدون قيمة.
- `FIREBASE_PROJECT_ID` — معرف مشروع Firebase.
- `FIREBASE_SERVICE_ACCOUNT_JSON` — JSON لحساب خدمة Firebase كمتغير سري في Railway. لا ترفع ملف الحساب إلى Git.
- `LIVEKIT_API_KEY` — مفتاح LiveKit السري.
- `LIVEKIT_API_SECRET` — سر LiveKit السري.
- `LIVEKIT_URL` — رابط WebSocket الخاص بـ LiveKit، ويمكن ترك القيمة الافتراضية المستخدمة في الكود.

الخدمة تستمع على `0.0.0.0` وتستخدم `PORT` الذي توفره منصة الاستضافة.

## التشغيل المحلي

```bash
cd livekit-token-server
npm install
export FIREBASE_PROJECT_ID='your-project-id'
export FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
export LIVEKIT_API_KEY='...'
export LIVEKIT_API_SECRET='...'
npm start
```

## API

`GET /health` للتحقق من أن الخادم يعمل، ويعرض فقط حالة إعداد Firebase وLiveKit بدون كشف الأسرار.

`POST /token` يتطلب:

`Authorization: Bearer <Firebase ID token>`

وجسم JSON:

```json
{"roomName":"call_<callId>","participantName":"اسم المستخدم"}
```

الخادم يتحقق من Firebase ID token ثم يصدر توكن LiveKit بهوية Firebase UID.

## Railway / GitHub

المستودع يحتوي على `index.js` في الجذر لأن بعض إعدادات Railway/Node تشغّل افتراضياً `node index.js`. هذا الملف يفوض التنفيذ إلى `livekit-token-server/server.js`.

GitHub يحفظ الكود، بينما Railway يشغّل الخادم بشكل دائم. لا توجد مفاتيح LiveKit أو Firebase سرية داخل المستودع.
