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
    const message={
      tokens,
      data:Object.fromEntries(Object.entries(payload.data||{}).map(([k,v])=>[k,String(v??'')])),
      // Data-only FCM is required so the app can apply the user's notification
      // preferences and render the correct message/call/system notification,
      // including actions, rather than Android auto-rendering a generic alert.
      android:{
        priority:'high',
        ttl:60*60*1000,
      },
      apns:{
        headers:{'apns-priority':'5','apns-push-type':'background'},
        payload:{aps:{'content-available':1}},
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
      if (invalid) await db.collection('users').doc(uid).collection('private').doc('tokens').update({tokens: admin.firestore.FieldValue.arrayRemove(invalid),updatedAt:admin.firestore.FieldValue.serverTimestamp()});
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
  const encryptedMessage=Boolean(m.e2eePayloads && typeof m.e2eePayloads==='object');
  const metadataProtected=Boolean(m.security && m.security.metadataProtection===true);
  const type=encryptedMessage?'encrypted':String(m.type||'text'),text=encryptedMessage?'':String(m.text||'').trim();
  const body=encryptedMessage?'لديك رسالة جديدة في الدردشة':({image:'📷 أرسل صورة',video:'🎬 أرسل فيديو',audio:'🎵 أرسل رسالة صوتية',file:'📎 أرسل ملف',location:'📍 شارك موقعاً'}[type]||text||'أرسل رسالة جديدة');
  const senderName=(encryptedMessage || metadataProtected)?'جهة اتصال':String(m.senderName||'مستخدم');
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
      ...(metadataProtected ? {} : {senderId}),
      senderName,
      senderPhotoUrl:metadataProtected?'':String(m.senderPhotoUrl || m.senderAvatar || ''),
      messageType:type,
      imageUrl:encryptedMessage?'':String(m.imageUrl || ''),
      videoUrl:encryptedMessage?'':String(m.videoUrl || ''),
      audioUrl:encryptedMessage?'':String(m.audioUrl || ''),
      fileUrl:encryptedMessage?'':String(m.fileUrl || ''),
      fileName:encryptedMessage?'':String(m.fileName || ''),
      fileMimeType:encryptedMessage?'':String(m.fileMimeType || m.fileType || ''),
      fileSize:encryptedMessage?'':String(m.fileSize || ''),
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

exports.notifyGroupMemberAdded=onDocumentUpdated('chats/{chatId}',async event=>{
  const before=event.data?.before?.data()||{};
  const after=event.data?.after?.data()||{};
  if(after.isGroup!==true)return;
  const oldIds=new Set(Array.isArray(before.participants)?before.participants.map(String):[]);
  const newIds=Array.isArray(after.participants)?after.participants.map(String):[];
  const added=newIds.filter(id=>id&&!oldIds.has(id));
  if(!added.length)return;
  const senderId=String(event.data.after.data()?.lastMessageSenderId||after.updatedBy||'');
  const details=after.participantDetails&&typeof after.participantDetails==='object'?after.participantDetails:{};
  await Promise.all(added.map(async uid=>{
    const data={
      type:'group_invite',
      title:String(after.groupName||'دعوة إلى مجموعة'),
      body:'تمت إضافتك إلى مجموعة في MemoChat',
      chatId:event.params.chatId,
      senderId:senderId||event.params.chatId,
      recipientId:uid,
      route:'chat:'+event.params.chatId,
    };
    await archiveNotification(uid,{data});
    await sendToUser(uid,{data});
  }));
});

exports.notifyCommunityInvite=onDocumentCreated('communityInvites/{inviteId}',async event=>{
  const snap=event.data;if(!snap)return;
  const d=snap.data()||{};
  const uid=String(d.recipientId||''),sender=String(d.senderId||'');
  if(!uid||!sender)return;
  const data={
    type:'community_invite',
    title:String(d.communityName||'دعوة إلى مجتمع'),
    body:'تمت دعوتك إلى مجتمع في MemoChat',
    communityId:String(d.communityId||''),
    senderId:sender,
    recipientId:uid,
    route:'community:'+String(d.communityId||''),
    inviteId:event.params.inviteId,
  };
  await archiveNotification(uid,{data});
  await sendToUser(uid,{data});
});

exports.notifyVoiceRoomInvite=onDocumentCreated('voiceRoomInvites/{inviteId}',async event=>{
  const snap=event.data;if(!snap)return;
  const d=snap.data()||{};
  const uid=String(d.recipientId||''),sender=String(d.senderId||'');
  if(!uid||!sender)return;
  const data={
    type:'voice_room_invite',
    title:String(d.roomName||'دعوة إلى غرفة صوتية'),
    body:'تمت دعوتك إلى غرفة صوتية',
    roomId:String(d.roomId||''),
    roomName:String(d.roomLiveName||''),
    senderId:sender,
    recipientId:uid,
    route:'voice_room:'+String(d.roomId||''),
    inviteId:event.params.inviteId,
  };
  await archiveNotification(uid,{data});
  await sendToUser(uid,{data});
});

exports.notifyFriendRequest=onDocumentCreated('friendRequests/{requestId}',async event=>{
  const snap=event.data;if(!snap)return;
  const d=snap.data()||{};
  const uid=String(d.recipientId||''),sender=String(d.senderId||'');
  if(!uid||!sender)return;
  const data={
    type:'friend_request',
    title:'طلب صداقة جديد',
    body:String(d.senderName||'مستخدم')+' أرسل لك طلب صداقة',
    senderId:sender,
    recipientId:uid,
    requestId:event.params.requestId,
    route:'contacts:friend_request',
  };
  await archiveNotification(uid,{data});
  await sendToUser(uid,{data});
});