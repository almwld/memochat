import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../../../core/repositories/firebase_chat_repository.dart';
import '../../../core/crypto/signal_session_manager.dart';
import '../../../core/security/conversation_security_policy.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ConversationSecurityPolicy _security = ConversationSecurityPolicy();
  String? get currentUserId => _auth.currentUser?.uid;
  String _uid(){final id=currentUserId;if(id==null||id.isEmpty)throw Exception('يجب تسجيل الدخول');return id;}
  DocumentReference<Map<String,dynamic>> _chatRef(String id)=>_firestore.collection('chats').doc(id);
  Future<DocumentSnapshot<Map<String,dynamic>>> _authorizedChat(String chatId)async{final id=_uid();final snap=await _chatRef(chatId).get();if(!snap.exists)throw Exception('المحادثة غير موجودة');final participants=List<String>.from(snap.data()?['participants']??const []);if(!participants.contains(id))throw Exception('ليس لديك صلاحية لهذه المحادثة');return snap;}
  Future<Map<String,dynamic>> _decryptMessageData(String currentUid, Map<String,dynamic> data) async {
    final raw=data['e2eePayloads'];
    final senderId=data['senderId']?.toString().trim() ?? '';
    if(raw is Map && senderId.isNotEmpty){
      final encoded=raw[currentUid]?.toString();
      if(encoded!=null&&encoded.isNotEmpty){
        final clear=await SignalSessionManager.instance.decryptFrom(senderId,base64Decode(encoded),chatId:data['chatId']?.toString());
        final payload=jsonDecode(utf8.decode(clear));
        if(payload is Map)return <String,dynamic>{...data,...Map<String,dynamic>.from(payload),'senderId':senderId,'chatId':data['chatId']};
      }
    }
    return data;
  }
  Future<List<MessageModel>> _decryptMessageDocs(List<QueryDocumentSnapshot<Map<String,dynamic>>> docs) async {
    final uid=_uid();
    return Future.wait(docs.map((d) async {
      final data=d.data();
      try {
        return MessageModel.fromFirestore(d.id,await _decryptMessageData(uid,data));
      } catch (firstError) {
        // A cold-start receiver may not have installed its Signal identity and
        // pre-key store yet. Initialize once and retry the same ciphertext.
        if (data['type'] == 'encrypted') {
          try {
            await SignalSessionManager.instance.ensureReady();
            return MessageModel.fromFirestore(d.id,await _decryptMessageData(uid,data));
          } catch (_) {
            debugPrint('Signal decrypt failed for message '+d.id+': '+firstError.toString());
            return MessageModel.fromFirestore(d.id,{...data,'text':null,'type':'system'});
          }
        }
        return MessageModel.fromFirestore(d.id,data);
      }
    }));
  }

  Stream<List<ChatModel>> streamChats({int limit=50})=>_firestore.collection('chats').where('participants',arrayContains:_uid()).limit(limit).snapshots().map((s){final uid=currentUserId;final list=s.docs.map((d)=>ChatModel.fromFirestore(d.id,d.data())).where((c){final data=s.docs.firstWhere((d)=>d.id==c.id).data();final deletedFor=data['deletedFor'];return uid==null||deletedFor is! Map||deletedFor[uid]!=true;}).toList();list.sort((a,b)=>(b.updatedAt??Timestamp(0,0)).compareTo(a.updatedAt??Timestamp(0,0)));return list;});
  Future<List<ChatModel>> getMoreChats({required int limit,DocumentSnapshot? startAfter})async{Query<Map<String,dynamic>> q=_firestore.collection('chats').where('participants',arrayContains:_uid()).limit(limit);if(startAfter!=null)q=q.startAfterDocument(startAfter);final s=await q.get();final uid=currentUserId;return s.docs.where((d){final deletedFor=d.data()['deletedFor'];return uid==null||deletedFor is! Map||deletedFor[uid]!=true;}).map((d)=>ChatModel.fromFirestore(d.id,d.data())).toList();}
  Future<String> generateInviteLink(String chatId) async {
    final uid=_uid(); final chat=await _authorizedChat(chatId); final data=chat.data() ?? {};
    if (data['isGroup'] != true) throw Exception('روابط الدعوة متاحة للمجموعات فقط');
    final roles=Map<String,dynamic>.from(data['memberRoles'] as Map? ?? const {});
    if (roles[uid] != 'owner' && roles[uid] != 'admin') throw Exception('لا تملك صلاحية إنشاء رابط دعوة');
    var code=data['inviteCode']?.toString().trim() ?? '';
    if (code.isEmpty) {
      const chars='ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
      final random=Random.secure();
      code=List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
      await _chatRef(chatId).update({'inviteCode':code,'updatedAt':FieldValue.serverTimestamp()});
    }
    return 'memochat://group/invite?code=' + Uri.encodeComponent(code);
  }

  Future<String> joinByInviteLink(String link) async {
    final uri=Uri.tryParse(link); final code=uri?.queryParameters['code'] ?? '';
    if (code.isEmpty) throw Exception('رابط الدعوة غير صالح');
    final uid=_uid();
    final query=await _firestore.collection('chats').where('inviteCode',isEqualTo:code).limit(1).get();
    if (query.docs.isEmpty) throw Exception('رابط الدعوة منتهي أو غير موجود');
    final ref=query.docs.first.reference; final data=query.docs.first.data();
    if (data['isGroup'] != true) throw Exception('الرابط ليس لمجموعة');
    final participants=List<String>.from(data['participants'] as List? ?? const []);
    if (participants.contains(uid)) return ref.id;
    final user=_auth.currentUser;
    participants.add(uid);
    final details=Map<String,dynamic>.from(data['participantDetails'] as Map? ?? const {});
    details[uid]={'name':user?.displayName ?? 'مستخدم','photoUrl':user?.photoURL};
    final roles=Map<String,dynamic>.from(data['memberRoles'] as Map? ?? const {})..[uid]='member';
    final unread=Map<String,dynamic>.from(data['unreadCount'] as Map? ?? const {})..[uid]=0;
    await ref.update({'participants':participants,'participantDetails':details,'memberRoles':roles,'unreadCount':unread,'updatedAt':FieldValue.serverTimestamp()});
    return ref.id;
  }

  Future<void> addMemberToGroup(String chatId, String memberId, {String? memberName, String? memberPhoto}) async {
    final uid = _uid();
    final chat = await _authorizedChat(chatId);
    final data = chat.data() ?? <String, dynamic>{};
    if (data['isGroup'] != true) throw StateError('هذه ليست مجموعة');
    final roles = Map<String, dynamic>.from(data['memberRoles'] as Map? ?? const {});
    if (roles[uid] != 'owner' && roles[uid] != 'admin') throw StateError('لا تملك صلاحية إضافة أعضاء');
    final target = memberId.trim();
    if (target.isEmpty || target == uid) throw StateError('عضو غير صالح');
    final participants = List<String>.from(data['participants'] as List? ?? const []);
    if (participants.contains(target)) return;
    participants.add(target);
    final details = Map<String, dynamic>.from(data['participantDetails'] as Map? ?? const {});
    details[target] = {'name': memberName?.trim().isNotEmpty == true ? memberName!.trim() : 'مستخدم', 'photoUrl': memberPhoto ?? ''};
    roles[target] = 'member';
    final unread = Map<String, dynamic>.from(data['unreadCount'] as Map? ?? const {})..[target] = 0;
    await _chatRef(chatId).update({
      'participants': participants,
      'participantDetails': details,
      'memberRoles': roles,
      'unreadCount': unread,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    });
  }

  Future<void> promoteToAdmin(String chatId, String memberId) async {
    final uid=_uid(); final chat=await _authorizedChat(chatId); final data=chat.data() ?? {};
    final roles=Map<String,dynamic>.from(data['memberRoles'] as Map? ?? const {});
    if (roles[uid] != 'owner' && roles[uid] != 'admin') throw Exception('لا تملك صلاحية الإدارة');
    if (!roles.containsKey(memberId)) throw Exception('العضو غير موجود');
    roles[memberId]='admin'; await _chatRef(chatId).update({'memberRoles':roles,'updatedAt':FieldValue.serverTimestamp()});
  }

  Future<void> demoteFromAdmin(String chatId, String memberId) async {
    final uid=_uid(); final chat=await _authorizedChat(chatId); final data=chat.data() ?? {};
    final roles=Map<String,dynamic>.from(data['memberRoles'] as Map? ?? const {});
    if (roles[uid] != 'owner') throw Exception('المالك فقط يستطيع خفض صلاحية المدير');
    if (roles[memberId] == 'owner') throw Exception('لا يمكن خفض صلاحية المالك');
    if (roles.containsKey(memberId)) roles[memberId]='member';
    await _chatRef(chatId).update({'memberRoles':roles,'updatedAt':FieldValue.serverTimestamp()});
  }

  Future<void> removeMember(String chatId, String memberId) async {
    final uid=_uid(); final chat=await _authorizedChat(chatId); final data=chat.data() ?? {};
    final roles=Map<String,dynamic>.from(data['memberRoles'] as Map? ?? const {});
    if (roles[uid] != 'owner' && roles[uid] != 'admin') throw Exception('لا تملك صلاحية الإدارة');
    if (roles[memberId] == 'owner') throw Exception('لا يمكن إزالة مالك المجموعة');
    final participants=List<String>.from(data['participants'] as List? ?? const [])..remove(memberId);
    final details=Map<String,dynamic>.from(data['participantDetails'] as Map? ?? const {})..remove(memberId);
    final unread=Map<String,dynamic>.from(data['unreadCount'] as Map? ?? const {})..remove(memberId);
    roles.remove(memberId);
    await _chatRef(chatId).update({'participants':participants,'participantDetails':details,'unreadCount':unread,'memberRoles':roles,'updatedAt':FieldValue.serverTimestamp()});
  }

  Future<String> createGroupChat({required String name, required List<String> memberIds, required Map<String, Map<String, dynamic>> memberDetails}) async {
    final owner = _uid();
    final cleanName = name.trim();
    final members = <String>{owner, ...memberIds.where((id) => id.trim().isNotEmpty && id != owner)}.toList();
    if (cleanName.isEmpty) throw ArgumentError('اسم المجموعة فارغ');
    if (members.length < 2) throw ArgumentError('أضف عضوًا واحدًا على الأقل');
    final ref = _firestore.collection('chats').doc();
    final details = <String, dynamic>{};
    for (final id in members) {
      final supplied = memberDetails[id] ?? <String, dynamic>{};
      details[id] = {
        'name': supplied['name']?.toString() ?? 'مستخدم',
        'photoUrl': supplied['photoUrl']?.toString(),
      };
    }
    final roles = <String, dynamic>{owner: 'owner'};
    for (final id in members) { if (id != owner) roles[id] = 'member'; }
    final unread = <String, dynamic>{for (final id in members) id: 0};
    await ref.set({
      'participants': members.toList(),
      'participantDetails': details,
      'memberRoles': roles,
      'lastMessage': '',
      'lastMessageTime': null,
      'lastMessageSenderId': null,
      'unreadCount': unread,
      'isGroup': true,
      'groupName': cleanName,
      'groupPhoto': '',
      'isArchived': false,
      'isPinned': false,
      'isMuted': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Canonical direct-chat entry point.
  /// All profile/contact/community routes use the same repository contract so
  /// they resolve the same stable DM id and never create parallel rooms.
  Future<String> createChat({
    required String userId,
    required String userName,
    required String currentUserName,
    String? userImage,
    String? currentUserImage,
    String? idempotencyKey,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw Exception('معرّف المستخدم الآخر غير صالح');
    }
    // FirebaseChatRepository owns the canonical DM schema/id. Keep this
    // compatibility API for older callers, but do not duplicate creation logic.
    return FirebaseChatRepository().createConversation(
      otherUserId: normalizedUserId,
      otherUserName: userName,
      otherUserPhoto: userImage,
    );
  }

  Future<String> sendMessage({required String chatId,required String text,String? messageId,String? imageUrl,String? videoUrl,String? audioUrl,String? fileUrl,String? locationUrl,double? locationLat,double? locationLng,String? locationAddress,Map<String,dynamic>? metadata,String? replyToId,String? idempotencyKey,String? fileName,String? fileSize,String? fileMimeType,String? audioDuration}) async {
    final id=_uid(); final user=_auth.currentUser!; final chat=await _authorizedChat(chatId);
    await _security.ensureReady();
    await SignalSessionManager.instance.ensureReady();
    if(idempotencyKey?.isNotEmpty==true){final x=await _chatRef(chatId).collection('messages').where('idempotencyKey',isEqualTo:idempotencyKey).limit(1).get();if(x.docs.isNotEmpty)return x.docs.first.id;}
    final participants=List<String>.from(chat.data()?['participants']??const []);
    final receiverIds=participants.where((p)=>p!=id).toList();
    final type=metadata?['kind']=='contact'?'contact':metadata?['kind']=='game_invite'?'game_invite':imageUrl!=null?'image':videoUrl!=null?'video':audioUrl!=null?'audio':fileUrl!=null?'file':locationUrl!=null?'location':'text';
    Map<String,dynamic>? replyPreview;
    if(replyToId?.isNotEmpty==true){final rr=await _chatRef(chatId).collection('messages').doc(replyToId).get();if(rr.exists){final d=await _decryptMessageData(id,rr.data()??{});replyPreview={'id':rr.id,'senderId':d['senderId']?.toString()??'','senderName':d['senderName']?.toString()??'مستخدم','text':d['text']?.toString()??'مرفق','type':d['type']?.toString()??'text'};}}
    final ref=(messageId?.isNotEmpty==true)?_chatRef(chatId).collection('messages').doc(messageId):_chatRef(chatId).collection('messages').doc();
    if(messageId?.isNotEmpty==true){final existing=await ref.get();if(existing.exists)return ref.id;}
    final payload=<String,dynamic>{'senderName':user.displayName??'مستخدم','senderPhotoUrl':user.photoURL,'text':text,'type':type,'imageUrl':imageUrl,'videoUrl':videoUrl,'audioUrl':audioUrl,'fileUrl':fileUrl,'locationUrl':locationUrl,'locationLat':locationLat,'locationLng':locationLng,'locationAddress':locationAddress,'metadata':metadata,'fileName':fileName,'fileSize':fileSize,'fileMimeType':fileMimeType,'audioDuration':audioDuration,'replyToId':replyToId,'replyPreview':replyPreview};
    final encryptedRecipients=<String,dynamic>{};
    for(final recipient in <String>{...receiverIds,id}){final e=await SignalSessionManager.instance.encryptFor(recipient,utf8.encode(jsonEncode(payload)),chatId:chatId);encryptedRecipients[recipient]=base64Encode(e);}
    final delivered=false;
    final batch=_firestore.batch();
    batch.set(ref,{'chatId':chatId,'senderId':id,'type':'encrypted','e2eeVersion':1,'e2eePayloads':encryptedRecipients,'security':_security.messageSecurity(chatId),'timestamp':FieldValue.serverTimestamp(),'clientTimestamp':Timestamp.now(),'isRead':false,'isDelivered':delivered,'status':MessageStatus.sent.name,'deliveredAt':null,'readAt':null,'isDeleted':false,'isEdited':false,'isPinned':false,'replyToId':replyToId,'reactions':<String,dynamic>{},if(idempotencyKey?.isNotEmpty==true)'idempotencyKey':idempotencyKey});
    final preview=type=='text'?'رسالة مشفرة':type=='image'?'صورة مشفرة':type=='video'?'فيديو مشفر':type=='audio'?'رسالة صوتية مشفرة':type=='file'?'ملف مشفر':'مرفق مشفر';
    final update=<String,dynamic>{'lastMessage':preview,'lastMessageTime':FieldValue.serverTimestamp(),'lastMessageSenderId':_security.summarySenderId(chatId,id),'updatedAt':FieldValue.serverTimestamp()};
    for(final p in participants){if(p!=id)update['unreadCount.$p']=FieldValue.increment(1);}
    batch.update(_chatRef(chatId),update);
    await batch.commit();
    return ref.id;
  }

    Future<String> forwardMessage({required String sourceChatId,required String messageId,required String destinationChatId}) async {
    final sourceUserId=_uid();await _authorizedChat(sourceChatId);await _authorizedChat(destinationChatId);final source=await _chatRef(sourceChatId).collection('messages').doc(messageId).get();if(!source.exists)throw Exception('الرسالة غير موجودة');
    final data=source.data()??{};if(data['isDeleted']==true)throw Exception('لا يمكن إعادة توجيه رسالة محذوفة');final destination=await _authorizedChat(destinationChatId);final participants=List<String>.from(destination.data()?['participants']??const []);if(!participants.contains(sourceUserId))throw Exception('لا تملك صلاحية الإرسال');
    final metadata=<String,dynamic>{};final rawMetadata=data['metadata'];if(rawMetadata is Map)metadata.addAll(rawMetadata.map((k,v)=>MapEntry(k.toString(),v)));metadata['forwarded']=true;metadata['forwardedFromChatId']=sourceChatId;metadata['forwardedFromMessageId']=messageId;metadata['originalSenderId']=data['senderId']?.toString();metadata['originalSenderName']=data['senderName']?.toString();
    return sendMessage(chatId:destinationChatId,text:data['text']?.toString()??'',imageUrl:data['imageUrl']?.toString(),videoUrl:data['videoUrl']?.toString(),audioUrl:data['audioUrl']?.toString(),fileUrl:data['fileUrl']?.toString(),locationUrl:data['locationUrl']?.toString(),locationLat:(data['locationLat'] as num?)?.toDouble(),locationLng:(data['locationLng'] as num?)?.toDouble(),locationAddress:data['locationAddress']?.toString(),metadata:metadata,fileName:data['fileName']?.toString(),fileSize:data['fileSize']?.toString(),fileMimeType:data['fileMimeType']?.toString(),audioDuration:data['audioDuration']?.toString(),idempotencyKey:'forward_'+sourceChatId+'_'+messageId+'_'+DateTime.now().microsecondsSinceEpoch.toString());
  }

Future<String> sendSystemMessage({required String chatId,required String text,String? idempotencyKey,Map<String,dynamic>? metadata}) async {
  final id=_uid(); final user=_auth.currentUser!; final chat=await _authorizedChat(chatId);
  await _security.ensureReady();
  await SignalSessionManager.instance.ensureReady();
  if(idempotencyKey?.isNotEmpty==true){final x=await _chatRef(chatId).collection('messages').where('idempotencyKey',isEqualTo:idempotencyKey).limit(1).get();if(x.docs.isNotEmpty)return x.docs.first.id;}
  final participants=List<String>.from(chat.data()?['participants']??const []);
  final type=metadata?['callId']!=null?'call':'system';
  final ref=_chatRef(chatId).collection('messages').doc();
  final payload=<String,dynamic>{'senderName':user.displayName??'مستخدم','senderPhotoUrl':user.photoURL,'text':text,'type':type,'metadata':metadata??<String,dynamic>{}};
  final encryptedRecipients=<String,dynamic>{};
  for(final recipient in <String>{...participants}){final e=await SignalSessionManager.instance.encryptFor(recipient,utf8.encode(jsonEncode(payload)),chatId:chatId);encryptedRecipients[recipient]=base64Encode(e);}
  final batch=_firestore.batch();
  batch.set(ref,{'chatId':chatId,'senderId':id,'type':'encrypted','e2eeVersion':1,'e2eePayloads':encryptedRecipients,'security':_security.messageSecurity(chatId),'timestamp':FieldValue.serverTimestamp(),'clientTimestamp':Timestamp.now(),'isRead':false,'isDelivered':false,'status':MessageStatus.sent.name,'deliveredAt':null,'readAt':null,'isDeleted':false,'isEdited':false,'reactions':<String,dynamic>{},if(idempotencyKey?.isNotEmpty==true)'idempotencyKey':idempotencyKey});
  final update=<String,dynamic>{'lastMessage':type=='call'?'مكالمة مشفرة':'رسالة نظامية مشفرة','lastMessageTime':FieldValue.serverTimestamp(),'lastMessageSenderId':_security.summarySenderId(chatId,id),'updatedAt':FieldValue.serverTimestamp()};
  for(final p in participants){if(p!=id)update['unreadCount.$p']=FieldValue.increment(1);}
  batch.update(_chatRef(chatId),update);
  await batch.commit();
  return ref.id;
}
    Stream<MessagePaginationResult> streamMessages(String chatId,{int limit=30}) {
    final controller=StreamController<MessagePaginationResult>();
    StreamSubscription<QuerySnapshot<Map<String,dynamic>>>? subscription;
    Future<void> start() async {
      try {
        await _authorizedChat(chatId);
        subscription=_chatRef(chatId).collection('messages').orderBy('timestamp',descending:true).limit(limit).snapshots().listen((s) async {
          try {
            controller.add(MessagePaginationResult(messages:await _decryptMessageDocs(s.docs),lastDocument:s.docs.isNotEmpty?s.docs.last:null,hasMore:s.docs.length>=limit));
          } catch(e,st) { controller.addError(e,st); }
        },onError:controller.addError);
      } catch(e,st) { controller.addError(e,st); await controller.close(); }
    }
    controller.onCancel=() async { await subscription?.cancel(); };
    unawaited(start());
    return controller.stream;
  }
  Future<MessagePaginationResult> getMoreMessages({required String chatId,required int limit,DocumentSnapshot? startAfter})async{await _authorizedChat(chatId);Query<Map<String,dynamic>> q=_chatRef(chatId).collection('messages').orderBy('timestamp',descending:true).limit(limit);if(startAfter!=null)q=q.startAfterDocument(startAfter);final s=await q.get();return MessagePaginationResult(messages:await _decryptMessageDocs(s.docs),lastDocument:s.docs.isNotEmpty?s.docs.last:null,hasMore:s.docs.length>=limit);}
  Future<List<MessageModel>> searchMessages({required String chatId,required String query,int limit=200})async{await _authorizedChat(chatId);final needle=query.trim().toLowerCase();if(needle.isEmpty)return const [];final safeLimit=limit.clamp(20,500).toInt();final snapshot=await _chatRef(chatId).collection('messages').orderBy('timestamp',descending:true).limit(safeLimit).get();final messages=await _decryptMessageDocs(snapshot.docs);return messages.where((m){final values=[m.text??'',m.senderName,m.fileName??'',m.fileMimeType??''];return values.any((v)=>v.toLowerCase().contains(needle));}).toList();}
  Future<void> markAsUnread(String chatId) async { final id=_uid(); await _authorizedChat(chatId); await _chatRef(chatId).update({'unreadCount.$id':FieldValue.increment(1),'updatedAt':FieldValue.serverTimestamp()}); }
  Future<void> archiveChat(String chatId,bool archived)async{await _authorizedChat(chatId);await _chatRef(chatId).update({'isArchived':archived,'updatedAt':FieldValue.serverTimestamp()});}
  Future<void> pinChat(String chatId,bool pinned)async{final id=_uid();await _authorizedChat(chatId);await _chatRef(chatId).update({'pinnedFor.$id':pinned,'updatedAt':FieldValue.serverTimestamp()});}
  Future<void> muteChat(String chatId,bool muted)async{final id=_uid();await _authorizedChat(chatId);await _chatRef(chatId).update({'mutedFor.$id':muted,'updatedAt':FieldValue.serverTimestamp()});}
  Future<void> deleteChat(String chatId)async{await _authorizedChat(chatId);await _chatRef(chatId).update({'deletedFor.${_uid()}':true,'updatedAt':FieldValue.serverTimestamp()});}
  Future<void> deleteMessage(String chatId,String messageId)async{final id=_uid();final chat=await _authorizedChat(chatId);await _security.ensureReady();final ref=_chatRef(chatId).collection('messages').doc(messageId);final d=await ref.get();if(!d.exists||d.data()?['senderId']!=id)throw Exception('لا يمكن حذف الرسالة');final payload=await _decryptMessageData(id,d.data()??{});payload['text']='تم حذف هذه الرسالة';payload['type']='deleted';final participants=List<String>.from(chat.data()?['participants']??const []);final envelopes=<String,dynamic>{};for(final recipient in <String>{...participants}){final e=await SignalSessionManager.instance.encryptFor(recipient,utf8.encode(jsonEncode(payload)),chatId:chatId);envelopes[recipient]=base64Encode(e);}await ref.update({'e2eePayloads':envelopes,'type':'encrypted','isDeleted':true,'deletedAt':FieldValue.serverTimestamp(),'security':_security.messageSecurity(chatId)});}
  Future<void> starMessage(String chatId, String messageId, bool starred) async { final id=_uid(); await _authorizedChat(chatId); final ref=_chatRef(chatId).collection('messages').doc(messageId); final snap=await ref.get(); if(!snap.exists) throw Exception('الرسالة غير موجودة'); await ref.update({'isStarred':starred,'starredAt':starred?FieldValue.serverTimestamp():null,'starredBy':starred?id:null}); }
  Future<List<MessageModel>> getStarredMessages(String chatId,{int limit=100}) async { await _authorizedChat(chatId); final s=await _chatRef(chatId).collection('messages').where('isStarred',isEqualTo:true).limit(limit).get(); return s.docs.map((d)=>MessageModel.fromFirestore(d.id,d.data())).toList(); }
  Future<void> pinMessage(String chatId,String messageId,bool pinned)async{final id=_uid();await _authorizedChat(chatId);final ref=_chatRef(chatId).collection('messages').doc(messageId);final snap=await ref.get();if(!snap.exists)throw Exception('الرسالة غير موجودة');await ref.update({'isPinned':pinned,'pinnedAt':pinned?FieldValue.serverTimestamp():null,'pinnedBy':pinned?id:null});}
  Future<void> markDelivered(String chatId)async{final id=_uid();await _authorizedChat(chatId);final s=await _chatRef(chatId).collection('messages').orderBy('timestamp',descending:true).limit(100).get();final pending=s.docs.where((d)=>d.data()['senderId']?.toString()!=id&&d.data()['isDelivered']!=true).toList();if(pending.isEmpty)return;final b=_firestore.batch();for (final d in pending) {
      b.update(d.reference, {
        'isDelivered': true,
        'status': MessageStatus.delivered.name,
        'deliveredAt': FieldValue.serverTimestamp(),
      });
    }await b.commit();}
  Future<void> deleteMessageForMe(String chatId,String messageId)async{final id=_uid();await _authorizedChat(chatId);await _chatRef(chatId).collection('messages').doc(messageId).update({'deletedFor.$id':true});}
  Future<void> editMessage(String chatId,String messageId,String text)async{final id=_uid();final clean=text.trim();if(clean.isEmpty)throw Exception('نص الرسالة فارغ');final chat=await _authorizedChat(chatId);await _security.ensureReady();final ref=_chatRef(chatId).collection('messages').doc(messageId);final snap=await ref.get();if(!snap.exists||snap.data()?['senderId']?.toString()!=id)throw Exception('لا يمكن تعديل هذه الرسالة');if(snap.data()?['isDeleted']==true)throw Exception('لا يمكن تعديل رسالة محذوفة');final payload=await _decryptMessageData(id,snap.data()??{});payload['text']=clean;final participants=List<String>.from(chat.data()?['participants']??const []);final envelopes=<String,dynamic>{};for(final recipient in <String>{...participants}){final e=await SignalSessionManager.instance.encryptFor(recipient,utf8.encode(jsonEncode(payload)),chatId:chatId);envelopes[recipient]=base64Encode(e);}await ref.update({'e2eePayloads':envelopes,'type':'encrypted','isEdited':true,'editedAt':FieldValue.serverTimestamp(),'security':_security.messageSecurity(chatId)});}
  Future<List<MessageModel>> getPinnedMessages(String chatId,{int limit=50})async{await _authorizedChat(chatId);final s=await _chatRef(chatId).collection('messages').where('isPinned',isEqualTo:true).limit(limit).get();final items=s.docs.map((d)=>MessageModel.fromFirestore(d.id,d.data())).toList();items.sort((a,b)=>(b.timestamp??Timestamp(0,0)).compareTo(a.timestamp??Timestamp(0,0)));return items;}
  Future<void> addReaction(String chatId,String messageId,String reaction)async{final id=_uid();await _authorizedChat(chatId);final value=reaction.trim();if(value.isEmpty)return;final ref=_chatRef(chatId).collection('messages').doc(messageId);final snap=await ref.get();if(!snap.exists)throw Exception('الرسالة غير موجودة');final raw=snap.data()?['reactions'];final reactions=<String,dynamic>{};if(raw is Map)reactions.addAll(raw.map((k,v)=>MapEntry(k.toString(),v.toString())));if(reactions[id]?.toString()==value){reactions.remove(id);}else{reactions[id]=value;}await ref.update({'reactions':reactions});}
  Future<void> markAsRead(String chatId)async{final id=_uid();await _authorizedChat(chatId);final all=await _chatRef(chatId).collection('messages').orderBy('timestamp',descending:true).limit(100).get();final unread=all.docs.where((d){final data=d.data();return data['senderId']?.toString()!=id&&data['isRead']!=true;}).toList();if(unread.isEmpty)return;final b=_firestore.batch();for (final d in unread) {
      b.update(d.reference, {
        'isDelivered': true,
        'status': MessageStatus.read.name,
        'deliveredAt': d.data()['deliveredAt'] ?? FieldValue.serverTimestamp(),
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }b.update(_chatRef(chatId),{'unreadCount.$id':0,'typing.$id':false});await b.commit();}
}
class MessagePaginationResult{final List<MessageModel> messages;final DocumentSnapshot? lastDocument;final bool hasMore;const MessagePaginationResult({required this.messages,this.lastDocument,required this.hasMore});}