const {onDocumentCreated,onDocumentUpdated}=require('firebase-functions/v2/firestore');
const admin=require('firebase-admin');
const db=admin.firestore();

async function archiveNotification(uid, payload) {
  if (!uid) return;
  await db.collection('notifications').add({
    userId: uid,
    type: String(payload.data?.type || 'system'),
    title: String(payload.data?.title || payload.data?.senderName || 'MemoChat'),
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
    title:String(n.title||'MemoChat'),
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



// Canonical incoming-call delivery: Firestore is the source of truth and
// this trigger is the single FCM producer for incoming calls.
exports.notifyIncomingCall=onDocumentCreated('calls/{callId}',async event=>{
  const snap=event.data;if(!snap)return;
  const call=snap.data()||{};
  const callId=event.params.callId;
  const status=String(call.status||'');
  if(!['calling','ringing'].includes(status))return;
  const callerId=String(call.callerId||'');
  const receiverId=String(call.receiverId||'');
  const chatId=String(call.chatId||'');
  if(!callerId||!receiverId||!chatId||callerId===receiverId)return;
  const data={
    type:'incoming_call',
    callId,
    chatId,
    callerId,
    receiverId,
    callerName:String(call.callerName||'مستخدم'),
    callerPhotoUrl:String(call.callerPhotoUrl||''),
    isVideo:(call.isVideoCall===true||call.isVideo===true||String(call.callType||'')==='video')?'true':'false',
    callType:String(call.callType||((call.isVideoCall===true||call.isVideo===true)?'video':'audio')),
    title:String(call.callerName||'مكالمة واردة'),
    body:String(call.isVideoCall===true||call.isVideo===true||String(call.callType||'')==='video'?'مكالمة فيديو واردة':'مكالمة صوتية واردة'),
  };
  await archiveNotification(receiverId,{data});
  await sendToUser(receiverId,{data});
});
