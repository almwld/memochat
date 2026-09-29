const {onDocumentCreated,onDocumentUpdated}=require('firebase-functions/v2/firestore');
const admin=require('firebase-admin');
const db=admin.firestore();

async function archiveNotification(uid, payload) {
  if (!uid) return;
  await db.collection('notifications').add({
    userId: uid,
    type: String(payload.data?.type || 'system'),
    title: String(payload.data?.title || payload.data?.senderName || 'صحتك'),
    body: String(payload.data?.body || 'لديك إشعار جديد'),
    data: payload.data || {},
    chatId: payload.data?.chatId || null,
    callId: payload.data?.callId || null,
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

exports.archiveNotificationUnreadCounter=onDocumentCreated('notifications/{notificationId}', async event => {
  const s=event.data;if(!s)return;
  const uid=String(s.data()?.userId||'');if(!uid)return;
  await db.collection('users').doc(uid).set({unreadNotificationsCount:admin.firestore.FieldValue.increment(1)},{merge:true});
});

async function getFcmTokens(uid){
  const snap=await db.collection('users').doc(uid).collection('private').doc('tokens').get();
  const data=snap.data()||{};
  return Array.isArray(data.tokens)?data.tokens.map(v=>String(v||'').trim()).filter(Boolean):[];
}

async function sendToUser(uid,payload){
  if(!uid)return;
  const tokens=await getFcmTokens(uid);
  if(!tokens.length)return;
  try{
    const type=String(payload.data?.type||'');
    const isCall=type==='incoming_call';
    const message={
      tokens,
      data:Object.fromEntries(Object.entries(payload.data||{}).map(([k,v])=>[k,String(v??'')])),
      android:{
        priority:'high',
        ttl:isCall?60*1000:60*60*1000,
      },
      apns:{
        headers:isCall
          ? {'apns-priority':'10','apns-push-type':'alert'}
          : {'apns-priority':'5','apns-push-type':'background'},
        payload:{
          aps:{
            'content-available':1,
            ...(isCall?{sound:'call_ringtone.caf'}:{}),
          },
        },
      },
    };
    const response=await admin.messaging().sendEachForMulticast(message);
    const invalidTokens=response.responses.map((result,index)=>!result.success && ['messaging/registration-token-not-registered','messaging/invalid-registration-token'].includes(result.error?.code)?tokens[index]:'').filter(Boolean);
    if(invalidTokens.length){
      await db.collection('users').doc(uid).collection('private').doc('tokens').update({tokens:admin.firestore.FieldValue.arrayRemove(...invalidTokens),updatedAt:admin.firestore.FieldValue.serverTimestamp()});
    }
    if(response.failureCount){ console.warn(`FCM multicast failures for ${uid}: ${response.failureCount}`); }
  }catch(e){
    console.error(`FCM send failed for ${uid}:`,e.message);
    if(['messaging/registration-token-not-registered','messaging/invalid-registration-token'].includes(e.code)){
      const invalid = String(e.token || '').trim();
      if (invalid) await db.collection('users').doc(uid).collection('private').doc('tokens').update({tokens: admin.firestore.FieldValue.arrayRemove(invalid),updatedAt: admin.firestore.FieldValue.serverTimestamp()});
    }
  }
}

exports.notifyAdminNotification=onDocumentCreated('notifications/{notificationId}',async event=>{
  const s=event.data;if(!s)return;
  const n=s.data()||{};
  const sentByAdmin=String(n.sentByAdmin||'').trim();
  const uid=String(n.userId||'').trim();
  if(!sentByAdmin||!uid)return;
  const data={
    type:String(n.type||'admin_broadcast'),
    title:String(n.title||'صحتك'),
    body:String(n.body||'لديك إشعار جديد'),
    recipientId:uid,
    adminId:sentByAdmin,
    notificationId:event.params.notificationId,
  };
  await sendToUser(uid,{data});
});

exports.notifyNewChatMessage=onDocumentCreated('chats/{chatId}/messages/{messageId}',async event=>{
  const s=event.data;if(!s)return;
  const m=s.data()||{},chatId=event.params.chatId,senderId=String(m.senderId||'');
  // Call lifecycle entries are timeline records, not chat messages. The
  // incoming-call FCM is sent by notifyIncomingCall and must never produce a
  // second notification that opens the chat room.
  if (m.type === 'call' || m.metadata?.callId || m.callId) return;
  if(!senderId)return;
  const chatSnap=await db.collection('chats').doc(chatId).get();
  if(!chatSnap.exists)return;
  const chat=chatSnap.data()||{};
  const ids=Array.isArray(chat.participants)?chat.participants.map(String):[];
  const receivers=ids.filter(id=>id&&id!==senderId);
  if(!receivers.length)return;
  const mutedFor=chat.mutedFor&&typeof chat.mutedFor==='object'?chat.mutedFor:{};
  const notifyReceivers=receivers.filter(uid=>mutedFor[uid]!==true);
  if(!notifyReceivers.length)return;
  const type=String(m.type||'text'),text=String(m.text||'').trim();
  const body={image:'📷 أرسل صورة',video:'🎬 أرسل فيديو',audio:'🎵 أرسل رسالة صوتية',file:'📎 أرسل ملف',location:'📍 شارك موقعاً'}[type]||text||'أرسل رسالة جديدة';
  const senderName=String(m.senderName||'مستخدم');

  // Delivery is distinct from sending: a message is delivered only when at
  // least one receiver is actually online. Opening the chat also marks it
  // delivered/read from the Flutter client.
  const receiverSnapshots=await Promise.all(receivers.map(uid=>db.collection('users').doc(uid).get()));
  const delivered=receiverSnapshots.some(snap=>snap.data()?.isOnline===true);
  await s.ref.update({
    isDelivered:delivered,
    deliveredAt:delivered?admin.firestore.FieldValue.serverTimestamp():null,
  });

  await Promise.all(notifyReceivers.map(async uid=>{
    const data={
      type:'new_message',
      chatId,
      messageId:event.params.messageId,
      senderId,
      senderName,
      senderPhotoUrl:String(m.senderPhotoUrl || m.senderAvatar || ''),
      messageType:type,
      imageUrl:String(m.imageUrl || ''),
      videoUrl:String(m.videoUrl || ''),
      audioUrl:String(m.audioUrl || ''),
      fileUrl:String(m.fileUrl || ''),
      fileName:String(m.fileName || ''),
      fileMimeType:String(m.fileMimeType || m.fileType || ''),
      fileSize:String(m.fileSize || ''),
      body,
      recipientId:uid,
      title:senderName,
    };
    await archiveNotification(uid,{data});
    await sendToUser(uid,{data});
  }));
});

function statusChanged(before, after) {
  return String(before?.status || '') !== String(after?.status || '');
}

function notificationPayload(type, title, body, extra = {}) {
  return {
    data: {
      type,
      title,
      body,
      ...Object.fromEntries(Object.entries(extra).map(([k, v]) => [k, v == null ? '' : String(v)])),
    },
  };
}

exports.notifyOrderLifecycle = onDocumentUpdated('orders/{orderId}', async event => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  if (!statusChanged(before, after)) return;
  const uid = String(after.userId || '');
  const status = String(after.status || '');
  if (!uid) return;
  const map = {
    confirmed: ['order_confirmed', 'تم تأكيد طلبك', 'تم تأكيد طلبك وسيبدأ تجهيزه.'],
    preparing: ['order_preparing', 'جاري تجهيز طلبك', 'طلبك قيد التجهيز الآن.'],
    ready: ['order_ready', 'طلبك جاهز', 'طلبك جاهز للخطوة التالية.'],
    delivering: ['order_on_way', 'طلبك في الطريق', 'طلبك خرج للتوصيل وهو في الطريق إليك.'],
    delivered: ['order_delivered', 'تم تسليم طلبك', 'تم تسليم طلبك بنجاح.'],
    cancelled: ['order_cancelled', 'تم إلغاء الطلب', 'تم إلغاء طلبك.'],
  };
  const item = map[status];
  if (!item) return;
  const data = notificationPayload(item[0], item[1], item[2], {
    orderId: event.params.orderId,
    id: event.params.orderId,
    recipientId: uid,
  });
  await archiveNotification(uid, data);
  await sendToUser(uid, data);
});

exports.notifyAppointmentLifecycle = onDocumentUpdated('appointments/{appointmentId}', async event => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  if (!statusChanged(before, after)) return;
  const uid = String(after.patientId || '');
  const status = String(after.status || '');
  if (!uid) return;
  const map = {
    confirmed: ['appointment_confirmed', 'تم تأكيد موعدك', 'تم تأكيد حجز موعدك مع الطبيب.'],
    cancelled: ['appointment_cancelled', 'تم إلغاء الموعد', 'تم إلغاء موعدك.'],
    rescheduled: ['appointment_rescheduled', 'تم تعديل الموعد', 'تم تعديل موعدك، يرجى مراجعة تفاصيل الحجز.'],
  };
  const item = map[status];
  if (!item) return;
  const data = notificationPayload(item[0], item[1], item[2], {
    appointmentId: event.params.appointmentId,
    id: event.params.appointmentId,
    recipientId: uid,
  });
  await archiveNotification(uid, data);
  await sendToUser(uid, data);
});

exports.notifyAppointmentCreated = onDocumentCreated('appointments/{appointmentId}', async event => {
  const data = event.data?.data() || {};
  const uid = String(data.patientId || '');
  if (!uid) return;
  const payload = notificationPayload(
    'appointment',
    'تم استلام طلب الموعد',
    'تم استلام طلب حجز موعدك وسيتم تحديثك عند التأكيد.',
    {appointmentId: event.params.appointmentId, id: event.params.appointmentId, recipientId: uid},
  );
  await archiveNotification(uid, payload);
  await sendToUser(uid, payload);
});

exports.notifyLabBookingLifecycle = onDocumentUpdated('lab_bookings/{bookingId}', async event => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  if (!statusChanged(before, after)) return;
  const uid = String(after.patientId || '');
  const status = String(after.status || '');
  if (!uid) return;
  let item = null;
  if (status === 'completed') item = ['lab_result_ready', 'نتيجة الفحص جاهزة', 'نتيجة فحصك أصبحت جاهزة ويمكنك مراجعتها.'];
  else if (status === 'confirmed') item = ['lab_booking_confirmed', 'تم تأكيد طلب الفحص', 'تم تأكيد حجز الفحص في المختبر.'];
  else if (status === 'cancelled') item = ['lab_booking_cancelled', 'تم إلغاء طلب الفحص', 'تم إلغاء طلب الفحص.'];
  if (!item) return;
  const payload = notificationPayload(item[0], item[1], item[2], {
    bookingId: event.params.bookingId,
    labBookingId: event.params.bookingId,
    id: event.params.bookingId,
    recipientId: uid,
  });
  await archiveNotification(uid, payload);
  await sendToUser(uid, payload);
});

exports.notifyLabBookingCreated = onDocumentCreated('lab_bookings/{bookingId}', async event => {
  const data = event.data?.data() || {};
  const uid = String(data.patientId || '');
  if (!uid) return;
  const payload = notificationPayload(
    'lab_request',
    'تم استلام طلب الفحص',
    'تم استلام طلب الفحص وسنقوم بتحديثك عند تأكيده.',
    {bookingId: event.params.bookingId, labBookingId: event.params.bookingId, id: event.params.bookingId, recipientId: uid},
  );
  await archiveNotification(uid, payload);
  await sendToUser(uid, payload);
});

exports.notifyPaymentLifecycle = onDocumentUpdated('transactions/{transactionId}', async event => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  if (!statusChanged(before, after)) return;
  const uid = String(after.userId || '');
  const status = String(after.status || '');
  if (!uid) return;
  let item = null;
  if (status === 'completed' && String(after.type || '') === 'payment') item = ['payment_success', 'تم إتمام الدفع', 'تم إتمام عملية الدفع بنجاح.'];
  else if (status === 'failed') item = ['payment_failed', 'فشلت عملية الدفع', 'تعذر إتمام عملية الدفع.'];
  else if (status === 'completed' && String(after.type || '') === 'refund') item = ['payment_refunded', 'تم استرداد المبلغ', 'تمت معالجة استرداد المبلغ.'];
  if (!item) return;
  const payload = notificationPayload(item[0], item[1], item[2], {
    transactionId: event.params.transactionId,
    paymentId: event.params.transactionId,
    orderId: after.orderId || '',
    id: event.params.transactionId,
    recipientId: uid,
  });
  await archiveNotification(uid, payload);
  await sendToUser(uid, payload);
});

exports.notifyInvoiceLifecycle = onDocumentCreated('invoices/{invoiceId}', async event => {
  const data = event.data?.data() || {};
  const uid = String(data.userId || data.patientId || data.customerId || '');
  if (!uid) return;
  const payload = notificationPayload(
    'invoice_created',
    'فاتورة جديدة',
    'تم إنشاء فاتورة جديدة في حسابك.',
    {invoiceId: event.params.invoiceId, id: event.params.invoiceId, recipientId: uid},
  );
  await archiveNotification(uid, payload);
  await sendToUser(uid, payload);
});

exports.notifyInvoiceStatus = onDocumentUpdated('invoices/{invoiceId}', async event => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  if (!statusChanged(before, after)) return;
  const uid = String(after.userId || after.patientId || after.customerId || '');
  const status = String(after.status || '');
  if (!uid) return;
  const map = {
    paid: ['invoice_paid', 'تم سداد الفاتورة', 'تم سداد الفاتورة بنجاح.'],
    due: ['invoice_due', 'فاتورة مستحقة', 'لديك فاتورة مستحقة تحتاج إلى السداد.'],
    cancelled: ['invoice_cancelled', 'تم إلغاء الفاتورة', 'تم إلغاء الفاتورة.'],
  };
  const item = map[status];
  if (!item) return;
  const payload = notificationPayload(item[0], item[1], item[2], {invoiceId: event.params.invoiceId, id: event.params.invoiceId, recipientId: uid});
  await archiveNotification(uid, payload);
  await sendToUser(uid, payload);
});


exports.notifyOrderCreated = onDocumentCreated('orders/{orderId}', async event => {
  const data = event.data?.data() || {};
  const uid = String(data.userId || '');
  if (!uid) return;
  const status = String(data.status || 'pending');
  if (status !== 'pending') return;
  const payload = notificationPayload(
    'order_confirmed',
    'تم استلام طلبك',
    'تم استلام طلبك بنجاح وسيتم تحديثك بحالته.',
    {orderId: event.params.orderId, id: event.params.orderId, recipientId: uid},
  );
  await archiveNotification(uid, payload);
  await sendToUser(uid, payload);
});

exports.notifyPaymentCreated = onDocumentCreated('transactions/{transactionId}', async event => {
  const data = event.data?.data() || {};
  const uid = String(data.userId || '');
  if (!uid || String(data.type || '') !== 'payment' || String(data.status || '') !== 'completed') return;
  const payload = notificationPayload(
    'payment_success',
    'تم إتمام الدفع',
    'تم إتمام عملية الدفع بنجاح.',
    {transactionId: event.params.transactionId, paymentId: event.params.transactionId, orderId: data.orderId || '', id: event.params.transactionId, recipientId: uid},
  );
  await archiveNotification(uid, payload);
  await sendToUser(uid, payload);
});
