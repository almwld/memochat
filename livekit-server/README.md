# MemoChat LiveKit & FCM Server

خادم Node.js الخاص بـ MemoChat لإصدار توكنات LiveKit وإرسال إشعارات المكالمات والرسائل عبر Firebase Cloud Messaging (FCM).

## الاستضافة والنشر

- منصة الاستضافة المعتمدة: **Suga**، وليست Railway.
- خدمة Suga: `memochat-livekit-server`.
- رابط الخدمة: `https://c3mhwp72itmc-production-ar6e2elm.us-central1.suga.run`.
- فرع النشر التلقائي: `main`.
- كود الخادم موجود في هذا المجلد `livekit-server/`. لا يصبح تعديل موجود على فرع Pull Request فعالًا في الخدمة المنشورة حتى يُدمج في `main) ثم تنجح عملية النشر على Suga.

## متغيرات البيئة

تُدار القيم السرية من إعدادات خدمة Suga، ولا تُحفظ داخل المستودع:

- `PORT` — المنفذ الذي توفره منصة الاستضافة.
- `FIREBASE_PROJECT_ID` — يجب أن يكون `memo-f97b5`.
- `FIREBASE_SERVICE_ACCOUNT_JSON` أو `FIREBASE_SERVICE_ACCOUNT_JSON_B64` — بيانات اعتماد Firebase Admin لمشروع MemoChat.
- `LIVEKIT_URL` و`LIVEKIT_API_KEY` و`LIVEKIT_API_SECRET` — إعدادات LiveKit.
- `NEXTCLOUD_URL` و`NEXTCLOUD_USERNAME` و`NEXTCLOUD_PASSWORD` — إعدادات نقل الوسائط عبر Nextcloud.

## الإشعارات

يستمع الخادم إلى رسائل Firestore الجديدة ويرسل إشعارات بيانات FCM إلى رموز الأجهزة المسجلة في `users/{uid}/private/tokens`. يتولى التطبيق على Android عرض الإشعار في شريط الحالة والتعامل مع الضغط عليه. كما يوفّر الخادم مسار إشعارات المكالمات الواردة، مع إبقاء Firestore مصدر الحالة الأساسي.

تُعرض الرسائل المشفرة بإشعار عام دون كشف محتواها. ولا يعتمد هذا المسار على Cloud Functions أو Railway.

## فحص الخدمة

- `GET /health` — التحقق من أن الخدمة تعمل.
- `GET /debug/config` — تشخيص وجود إعدادات الخدمة دون إرجاع الأسرار.
- `POST /token` — إصدار توكن LiveKit بعد التحقق من Firebase ID token.
- `POST /call-notification` — طلب إرسال تنبيه مكالمة واردة بعد التحقق من هوية المتصل وصحة المكالمة.

## تشغيل محلي

```bash
cd livekit-server
npm install
npm start
```

استخدم متغيرات بيئة محلية آمنة؛ لا تضع مفاتيح LiveKit أو بيانات اعتماد Firebase في Git.
