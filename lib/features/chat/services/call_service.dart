import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:memochat/features/chat/models/call_model.dart';
import 'package:memochat/features/chat/services/active_call_registry.dart';
import 'package:memochat/features/chat/services/chat_service.dart';
import 'package:memochat/features/chat/services/toast_service.dart';
import 'package:memochat/features/chat/services/call_sound_coordinator.dart';
import 'package:memochat/features/chat/services/notification_service.dart';
import 'package:memochat/features/chat/presentation/incoming_call_screen.dart';
import 'package:memochat/features/chat/presentation/call_screen.dart';
import 'package:memochat/features/chat/presentation/chat_navigation.dart';

String _formatDuration(int seconds) { final safe = seconds < 0 ? 0 : seconds; final minutes = safe ~/ 60; final secs = safe % 60; return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}'; }

class CallService {
  static const Map<CallStatus, Set<CallStatus>> allowedTransitions = {
    CallStatus.calling: {
      CallStatus.ringing,
      CallStatus.connected,
      CallStatus.rejected,
      CallStatus.cancelled,
      CallStatus.missed,
      CallStatus.busy,
    },
    CallStatus.ringing: {
      CallStatus.connected,
      CallStatus.rejected,
      CallStatus.cancelled,
      CallStatus.missed,
      CallStatus.busy,
    },
    CallStatus.connected: {
      CallStatus.ended,
    },
    CallStatus.ended: {},
    CallStatus.missed: {},
    CallStatus.rejected: {},
    CallStatus.busy: {},
    CallStatus.cancelled: {},
  };

  static bool isTransitionAllowed(CallStatus from, CallStatus to) =>
      allowedTransitions[from]?.contains(to) ?? false;

  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _chat = ChatService();
  bool _inCall = false;
  String? _current;
  bool get isInCall => _inCall;
  String? get currentCallId => _current;
  String? get currentUserId => _auth.currentUser?.uid;
  String _uid() { final u = currentUserId; if (u == null || u.isEmpty) throw Exception('يجب تسجيل الدخول'); return u; }
  Future<T> _retry<T>(Future<T> Function() op) async { Object? last; for (var i = 0; i < 3; i++) { try { return await op(); } on FirebaseException catch (e) { last = e; if (!['unavailable','deadline-exceeded','aborted'].contains(e.code) || i == 2) rethrow; await Future<void>.delayed(Duration(milliseconds: 350 * pow(2, i).toInt())); } } throw last ?? Exception('فشل الوصول إلى Firestore'); }
  Stream<List<CallModel>> streamCallHistory({int limit = 50}) => _firestore.collection('calls').where('participants', arrayContains: _uid()).limit(limit).snapshots().map((s) { final items=s.docs.map((d)=>CallModel.fromFirestore(d.id,d.data())).toList(); items.sort((a,b)=>(b.startedAt??Timestamp(0,0)).compareTo(a.startedAt??Timestamp(0,0))); return items; });
  Stream<CallModel?> streamCall(String id) => _firestore.collection('calls').doc(id).snapshots().map((d) => d.exists ? CallModel.fromFirestore(d.id, d.data()!) : null);
  Future<void> _timeline({required String chatId, required String callId, required String text, required String status, required CallType type, int? durationSeconds}) async { if (chatId.isEmpty) return; try { await _chat.sendSystemMessage(chatId: chatId, text: text, idempotencyKey: 'call_${callId}_$status', metadata: {'callId': callId, 'callType': type.name, 'isVideo': type == CallType.video, 'status': status, if (durationSeconds != null) 'duration': _formatDuration(durationSeconds)}); } catch (e) { debugPrint('call timeline: $e'); } }
  String _lockId(String a, String b) { final ids = [a,b]..sort(); return '${ids[0]}_${ids[1]}'; }
  Future<CallModel?> initiateCall({required String receiverId, required String receiverName, String? receiverPhotoUrl, required CallType type, required String chatId, String? idempotencyKey}) async {
    final uid = _uid();
    final user = _auth.currentUser!;
    if (receiverId.isEmpty || receiverId == uid) throw Exception('معرّف المستقبل غير صالح');
    final normalizedChatId = chatId.trim();
    if (normalizedChatId.isEmpty) throw Exception('معرّف المحادثة غير صالح');

    // Calls are allowed only from the real direct chat shared by both users.
    // This keeps the LiveKit room contract tied to an authorized Firestore
    // conversation and rejects stale/fabricated contact routes.
    final chatSnapshot = await _retry(
      () => _firestore.collection('chats').doc(normalizedChatId).get(),
    );
    if (!chatSnapshot.exists) throw Exception('المحادثة غير موجودة');
    final chatData = chatSnapshot.data() ?? <String, dynamic>{};
    final chatParticipants = (chatData['participants'] as List?)
            ?.map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toSet() ??
        <String>{};
    if (chatData['isGroup'] == true ||
        chatParticipants.length != 2 ||
        !chatParticipants.contains(uid) ||
        !chatParticipants.contains(receiverId)) {
      throw Exception('المكالمة غير مرتبطة بمحادثة مباشرة صالحة');
    }
    final registry = ActiveCallRegistry.instance;
    if (registry.hasActiveCall) {
      final activeId = registry.activeCallId;
      bool isStale = activeId == null || activeId.trim().isEmpty;
      if (!isStale) {
        try {
          final activeSnap = await _retry(
            () => _firestore.collection('calls').doc(activeId).get(),
          );
          if (!activeSnap.exists) {
            isStale = true;
          } else {
            final data = activeSnap.data() ?? <String, dynamic>{};
            final status = data['status']?.toString();
            const terminalStatuses = <String>{
              'ended',
              'cancelled',
              'rejected',
              'missed',
              'busy',
            };
            if (status == null || terminalStatuses.contains(status)) {
              isStale = true;
            } else {
              final rawStartedAt = data['startedAt'];
              final startedAt =
                  rawStartedAt is Timestamp ? rawStartedAt.toDate() : null;
              if (startedAt != null &&
                  DateTime.now().difference(startedAt).inMinutes > 5 &&
                  status != 'connected') {
                isStale = true;
              }
            }
          }
        } catch (e) {
          debugPrint('CALL REGISTRY CHECK FAILED active=$activeId error=$e');
        }
      }
      if (isStale) {
        debugPrint('CALL REGISTRY: clearing stale active call $activeId');
        registry.reset();
      } else {
        throw StateError('لديك مكالمة نشطة بالفعل');
      }
    }
    var id = (idempotencyKey ?? _firestore.collection('calls').doc().id).trim();
    // Idempotency keys are logical call ids, not LiveKit room names. Normalize
    // legacy keys so we never create call_call_<id> room names.
    while (id.startsWith('call_')) {
      id = id.substring('call_'.length);
    }
    if (id.isEmpty) id = _firestore.collection('calls').doc().id;
    final ref = _firestore.collection('calls').doc(id);
    final lockRef = _firestore.collection('callLocks').doc(_lockId(uid, receiverId));
    final room = 'call_$id';
    await _retry(() => _firestore.runTransaction((tx) async {
      final existingCall = await tx.get(ref); if (existingCall.exists) return;
      tx.set(lockRef, {'participants':[uid,receiverId],'activeCallId':id,'status':CallStatus.calling.name,'updatedAt':FieldValue.serverTimestamp()});
      tx.set(ref, {'id':id,'chatId':normalizedChatId,'callerId':uid,'callerName':user.displayName ?? 'مستخدم','callerPhotoUrl':user.photoURL,'receiverId':receiverId,'receiverName':receiverName,'receiverPhotoUrl':receiverPhotoUrl,'callType':type.name,'status':CallStatus.calling.name,'startedAt':FieldValue.serverTimestamp(),'isAnswered':false,'participants':[uid,receiverId],'liveKitRoomName':room,'roomName':room,'isVideoCall':type == CallType.video});
    }));
    _inCall = true; _current = id;
    final saved = await _retry(() => ref.get());
    if (!saved.exists) throw Exception('تعذر حفظ المكالمة');
    final call = CallModel.fromFirestore(id,saved.data()!);
    // The Firestore calls/{callId} trigger is the single incoming-call FCM producer.
    unawaited(_timeline(chatId:normalizedChatId,callId:id,text:type == CallType.video ? 'بدء مكالمة فيديو' : 'بدء مكالمة صوتية',status:CallStatus.calling.name,type:type));
    return call;
  }

  Future<_Ctx?> _state({required String id, required List<CallStatus> allowed, required Map<String,dynamic> data, required bool active, bool ignore = false}) async {
    _Ctx? c;
    await _retry(() async { await _firestore.runTransaction((tx) async { final ref=_firestore.collection('calls').doc(id); final d=await tx.get(ref); if(!d.exists)return; final raw=d.data() ?? <String,dynamic>{}; final currentStatus=CallStatus.values.firstWhere((x)=>x.name==raw['status'],orElse:()=>CallStatus.calling);
      final nextStatusName=data['status']?.toString();
      final nextStatus=CallStatus.values.firstWhere((x)=>x.name==nextStatusName,orElse:()=>currentStatus);
      if(!allowed.contains(currentStatus) || !isTransitionAllowed(currentStatus,nextStatus)){
        if(ignore)return;
        throw StateError('انتقال حالة المكالمة غير مسموح: ${currentStatus.name} -> ${nextStatus.name}');
      } final t=CallType.values.firstWhere((x)=>x.name==raw['callType'],orElse:()=>CallType.audio); c=_Ctx(raw['chatId']?.toString() ?? '',t); tx.update(ref,data); final callerId=raw['callerId']?.toString() ?? ''; final receiverId=raw['receiverId']?.toString() ?? ''; if(callerId.isNotEmpty&&receiverId.isNotEmpty){final lockRef=_firestore.collection('callLocks').doc(_lockId(callerId,receiverId)); tx.set(lockRef,{'participants':[callerId,receiverId],'activeCallId':active?id:null,'status':data['status']?.toString() ?? (active?currentStatus.name:CallStatus.ended.name),'updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));} }); return null; });
    _inCall=active; _current=active?id:null; if(!active) unawaited(CallSoundCoordinator.instance.stopForCall(id)); return c;
  }

  /// Marks the call as answered without claiming the media session is connected.
  Future<void> acceptCall(String id) async {
    unawaited(_stopCallForegroundService());
    final registry = ActiveCallRegistry.instance;
    final activeId = registry.activeCallId;
    if (registry.hasActiveCall && activeId != id) {
      await markBusy(id);
      throw StateError('لا يمكن قبول المكالمة أثناء وجود مكالمة نشطة');
    }

    await _retry(() async {
      await _firestore.runTransaction((tx) async {
        final ref = _firestore.collection('calls').doc(id);
        final d = await tx.get(ref);
        if (!d.exists) throw StateError('المكالمة غير موجودة');
        final raw = d.data() ?? <String, dynamic>{};
        final status = raw['status']?.toString() ?? '';
        if (status != CallStatus.calling.name && status != CallStatus.ringing.name) {
          throw StateError('حالة المكالمة غير قابلة للقبول: $status');
        }

        final callerId = raw['callerId']?.toString() ?? '';
        final receiverId = raw['receiverId']?.toString() ?? '';
        if (receiverId != _uid()) {
          throw StateError('لا يمكن قبول مكالمة ليست موجهة لهذا المستخدم');
        }

        tx.update(ref, {
          'isAnswered': true,
        });

        if (callerId.isNotEmpty && receiverId.isNotEmpty) {
          tx.set(
            _firestore.collection('callLocks').doc(_lockId(callerId, receiverId)),
            {
              'participants': [callerId, receiverId],
              'activeCallId': id,
              'status': status,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      });
    });

    _inCall = true;
    _current = id;
    registry.register(id);
    await CallSoundCoordinator.instance.stopForCall(id);
  }

  /// Moves the call to connected only after a LiveKit room is actually joined.
  Future<void> markConnected(String id) async {
    final normalized = id.trim();
    if (normalized.isEmpty) throw StateError('معرّف المكالمة فارغ');

    await _retry(() async {
      await _firestore.runTransaction((tx) async {
        final ref = _firestore.collection('calls').doc(normalized);
        final d = await tx.get(ref);
        if (!d.exists) throw StateError('المكالمة غير موجودة');
        final raw = d.data() ?? <String, dynamic>{};
        final status = raw['status']?.toString() ?? '';
        final answered = raw['isAnswered'] == true;
        final callerId = raw['callerId']?.toString() ?? '';
        final receiverId = raw['receiverId']?.toString() ?? '';

        if (status == CallStatus.connected.name) return;
        if (status != CallStatus.calling.name && status != CallStatus.ringing.name) {
          throw StateError('المكالمة لم تعد قابلة للاتصال: $status');
        }
        if (!answered && receiverId == _uid()) {
          throw StateError('لا يمكن تسجيل الاتصال قبل قبول المكالمة');
        }

        tx.update(ref, {
          'status': CallStatus.connected.name,
          'isAnswered': true,
          'connectedAt': FieldValue.serverTimestamp(),
        });

        if (callerId.isNotEmpty && receiverId.isNotEmpty) {
          tx.set(
            _firestore.collection('callLocks').doc(_lockId(callerId, receiverId)),
            {
              'participants': [callerId, receiverId],
              'activeCallId': normalized,
              'status': CallStatus.connected.name,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      });
    });

    _inCall = true;
    _current = normalized;
  }

  Future<void> rejectCall(String id) async { final c=await _state(id:id,allowed:const[CallStatus.calling,CallStatus.ringing],data:{'status':CallStatus.rejected.name,'endedAt':FieldValue.serverTimestamp()},active:false); await CallSoundCoordinator.instance.stopForCall(id); unawaited(NotificationService().cancelIncomingCallNotification(id)); if (c != null) unawaited(_timeline(chatId:c.chatId,callId:id,text:'تم رفض المكالمة',status:CallStatus.rejected.name,type:c.type)); }
  Future<void> markBusy(String id) async { final c=await _state(id:id,allowed:const[CallStatus.calling,CallStatus.ringing],data:{'status':CallStatus.busy.name,'endedAt':FieldValue.serverTimestamp(),'busyReason':'receiver_in_call','metadata.busyReason':'receiver_in_call'},active:false,ignore:true); await CallSoundCoordinator.instance.stopForCall(id); unawaited(NotificationService().cancelIncomingCallNotification(id)); if (c != null) unawaited(_timeline(chatId:c.chatId,callId:id,text:'المستخدم مشغول بمكالمة أخرى',status:CallStatus.busy.name,type:c.type)); }
  Future<void> cancelCall(String id) async { unawaited(_stopCallForegroundService()); final c=await _state(id:id,allowed:const[CallStatus.calling,CallStatus.ringing],data:{'status':CallStatus.cancelled.name,'endedAt':FieldValue.serverTimestamp()},active:false); await CallSoundCoordinator.instance.stopForCall(id); unawaited(NotificationService().cancelIncomingCallNotification(id)); if (c != null) unawaited(_timeline(chatId:c.chatId,callId:id,text:'تم إلغاء المكالمة',status:CallStatus.cancelled.name,type:c.type)); }
  Future<void> endCall(String id,{int? durationSeconds}) async { unawaited(_stopCallForegroundService()); final c=await _state(id:id,allowed:const[CallStatus.calling,CallStatus.ringing,CallStatus.connected],data:{'status':CallStatus.ended.name,'endedAt':FieldValue.serverTimestamp(),'durationSeconds':durationSeconds},active:false); await CallSoundCoordinator.instance.stopForCall(id); unawaited(NotificationService().cancelIncomingCallNotification(id)); if (c != null) unawaited(_timeline(chatId:c.chatId,callId:id,text:durationSeconds != null && durationSeconds > 0 ? 'انتهت المكالمة • ${durationSeconds}s' : 'انتهت المكالمة',status:CallStatus.ended.name,type:c.type,durationSeconds:durationSeconds)); }
  Future<void> missCall(String id) async { unawaited(_stopCallForegroundService()); final c=await _state(id:id,allowed:const[CallStatus.calling,CallStatus.ringing],data:{'status':CallStatus.missed.name,'endedAt':FieldValue.serverTimestamp()},active:false,ignore:true); await CallSoundCoordinator.instance.stopForCall(id); unawaited(NotificationService().cancelIncomingCallNotification(id)); if (c != null) unawaited(_timeline(chatId:c.chatId,callId:id,text:'مكالمة فائتة',status:CallStatus.missed.name,type:c.type)); }
  Future<String?> resolveChatId(String id) async { final snapshot=await _retry(()=>_firestore.collection('calls').doc(id).get()); if(!snapshot.exists)return null; final data=snapshot.data(); if(data==null)return null; return data['chatId']?.toString(); }

  Future<void> handleIncomingCallById(BuildContext context,String id) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return;

    // FCM taps and the Firestore listener share one incoming-call UI owner.
    await CallSoundCoordinator.instance.presentIncomingCallById(normalizedId);
  }

  /// Answers a notification action without opening a second permission flow.
  /// CallScreen remains the single owner of media permission and LiveKit startup.
  Future<void> answerIncomingCallById(BuildContext context, String id) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty || !context.mounted) return;

    final snap = await _retry(
      () => _firestore.collection('calls').doc(normalizedId).get(),
    );
    if (!snap.exists || !context.mounted) return;

    final data = snap.data() ?? <String, dynamic>{};
    final receiverId = data['receiverId']?.toString() ?? '';
    if (receiverId.isNotEmpty && receiverId != currentUserId) return;

    final status = data['status']?.toString() ?? '';
    if (status != CallStatus.calling.name && status != CallStatus.ringing.name) {
      return;
    }

    final chatId = data['chatId']?.toString() ?? '';
    final callerId = data['callerId']?.toString() ?? '';
    if (chatId.isEmpty || callerId.isEmpty) return;

    final registry = ActiveCallRegistry.instance;
    if (registry.hasActiveCall && !registry.isActive(normalizedId)) {
      await markBusy(normalizedId);
      return;
    }

    try {
      await HapticFeedback.mediumImpact();
      await acceptCall(normalizedId);
    } catch (e) {
      debugPrint('CALL NOTIFICATION ANSWER ERROR: $e');
      if (context.mounted) {
        ToastService.showError('تعذر قبول المكالمة. حاول مرة أخرى.');
      }
      return;
    }

    if (!context.mounted) return;

    final isVideo =
        data['isVideoCall'] == true || data['callType']?.toString() == 'video';

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CallScreen(
          callId: normalizedId,
          chatId: chatId,
          userName: data['callerName']?.toString() ?? 'مستخدم',
          userId: callerId,
          userImage: data['callerPhotoUrl']?.toString(),
          isVideo: isVideo,
          isOutgoing: false,
        ),
      ),
    );
  }

  Future<void> openChatForCall(BuildContext context, String id) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty || !context.mounted) return;
    final snap = await _retry(() => _firestore.collection('calls').doc(normalizedId).get());
    if (!snap.exists || !context.mounted) return;
    final data = snap.data() ?? <String, dynamic>{};
    final callerId = data['callerId']?.toString() ?? '';
    final callerName = data['callerName']?.toString() ?? 'مستخدم';
    final callerImage = data['callerPhotoUrl']?.toString();
    if (callerId.isEmpty) return;
    await _notificationCancelAndStop(normalizedId);
    if (!context.mounted) return;
    await ChatNavigation.openChat(context, userName: callerName, userId: callerId, userImage: callerImage);
  }

  Future<void> _notificationCancelAndStop(String id) async {
    await CallSoundCoordinator.instance.stopForCall(id);
  }

  Future<void> handleIncomingCall(BuildContext context,RemoteMessage message) async {
    final id = (message.data['callId'] ?? message.data['id'])?.toString().trim();
    if (id == null || id.isEmpty) return;

    // Keep legacy FCM routing on the same single incoming-call UI owner.
    await CallSoundCoordinator.instance.presentIncomingCallById(id);
  }

  void dispose(){_inCall=false;_current=null;}
}
class _Ctx { final String chatId; final CallType type; const _Ctx(this.chatId,this.type); }