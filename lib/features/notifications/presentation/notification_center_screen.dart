import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/premium_ui.dart';

import '../../../features/chat/presentation/chat_navigation.dart';
import '../../../features/chat/services/call_service.dart';
import '../../../features/advanced/presentation/advanced_hub_screen.dart';
import '../../../features/advanced/data/advanced_features_service.dart';
import '../../../core/services/friend_request_service.dart';
import '../../../features/communities/presentation/communities_screen.dart';
import '../../../features/communities/data/community_service.dart';
import '../../../features/contacts/presentation/contacts_screen.dart';
import '../../../core/repositories/firebase_chat_repository.dart';

import '../../../core/notifications/notification_inbox.dart';
import '../../../core/services/notification_history_service.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/ui/memo_chat_ui_tokens.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final _inbox = NotificationInbox();
  final _history = NotificationHistoryService();

  Map<String, dynamic> _payload(Map<String, dynamic> data) {
    final nested = data['data'];
    return <String, dynamic>{
      if (nested is Map) ...Map<String, dynamic>.from(nested),
      ...data,
    };
  }

  String _notificationType(Map<String, dynamic> data) =>
      _payload(data)['type']?.toString() ?? data['type']?.toString() ?? '';

  Future<void> _respondToInvitation(Map<String, dynamic> raw, {required bool accept, required String historyId}) async {
    final data = _payload(raw);
    final type = _notificationType(data);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      if (type == 'friend_request') {
        final requestId = data['requestId']?.toString() ?? '';
        if (requestId.isEmpty) throw StateError('معرّف طلب الصداقة غير موجود');
        if (accept) {
          await FriendRequestService().accept(requestId);
        } else {
          await FriendRequestService().reject(requestId);
        }
      } else if (type == 'voice_room_invite') {
        final inviteId = data['inviteId']?.toString() ?? '';
        final ref = FirebaseFirestore.instance.collection('voiceRoomInvites').doc(inviteId);
        final invite = await ref.get();
        if (inviteId.isEmpty || !invite.exists || invite.data()?['recipientId']?.toString() != uid || invite.data()?['state'] != 'pending') {
          throw StateError('الدعوة غير متاحة أو سبق الرد عليها');
        }
        await ref.update({'state': accept ? 'accepted' : 'rejected', 'updatedAt': FieldValue.serverTimestamp()});
        if (accept) {
          final roomId = invite.data()?['roomId']?.toString() ?? '';
          if (roomId.isEmpty) throw StateError('معرّف الغرفة غير موجود');
          final service = AdvancedFeaturesService();
          await service.joinVoiceRoom(roomId);
          final room = await FirebaseFirestore.instance.collection('voiceRooms').doc(roomId).get();
          final roomData = room.data() ?? const <String, dynamic>{};
          final roomName = roomData['roomName']?.toString() ?? '';
          if (!room.exists || roomName.isEmpty) throw StateError('الغرفة لم تعد متاحة');
          if (mounted) {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => VoiceRoomScreen(roomId: roomId, roomName: roomName, title: roomData['name']?.toString() ?? 'غرفة صوتية')));
          }
        }
      } else if (type == 'community_invite') {
        final inviteId = data['inviteId']?.toString() ?? '';
        final ref = FirebaseFirestore.instance.collection('communityInvites').doc(inviteId);
        final invite = await ref.get();
        if (inviteId.isEmpty || !invite.exists || invite.data()?['recipientId']?.toString() != uid || invite.data()?['state'] != 'pending') {
          throw StateError('الدعوة غير متاحة أو سبق الرد عليها');
        }
        await ref.update({'state': accept ? 'accepted' : 'rejected', 'updatedAt': FieldValue.serverTimestamp()});
        if (accept) {
          final communityId = invite.data()?['communityId']?.toString() ?? '';
          if (communityId.isEmpty) throw StateError('معرّف المجتمع غير موجود');
          final service = CommunityService();
          await service.joinCommunity(communityId);
          final community = await FirebaseFirestore.instance.collection('communities').doc(communityId).get();
          if (!community.exists) throw StateError('المجتمع لم يعد متاحاً');
          if (mounted) {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommunityDetailScreen(communityId: communityId, name: community.data()?['name']?.toString() ?? 'مجتمع', service: service)));
          }
        }
      } else {
        return;
      }
      if (uid.isNotEmpty && historyId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).collection('notificationHistory').doc(historyId).update({'actionCompleted': true, 'read': true, 'readAt': FieldValue.serverTimestamp()});
        } catch (_) {}
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(accept ? 'تم قبول الدعوة.' : 'تم رفض الدعوة.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر ${accept ? 'قبول' : 'رفض'} الطلب: ${error.toString().replaceFirst('Bad state: ', '')}')));
    }
  }

  Widget? _invitationActions(Map<String, dynamic> data, String historyId) {
    if (data['actionCompleted'] == true) return null;
    final type = _notificationType(data);
    if (!const {'friend_request', 'voice_room_invite', 'community_invite'}.contains(type)) return null;
    return Wrap(mainAxisSize: MainAxisSize.min, spacing: 0, children: [
      IconButton(tooltip: 'قبول', visualDensity: VisualDensity.compact, icon: const Icon(Icons.check_circle_rounded), onPressed: () => _respondToInvitation(data, accept: true, historyId: historyId)),
      IconButton(tooltip: 'رفض', visualDensity: VisualDensity.compact, icon: const Icon(Icons.cancel_outlined), onPressed: () => _respondToInvitation(data, accept: false, historyId: historyId)),
    ]);
  }

  Future<void> _openNotification(Map<String, dynamic> rawData) async {
    final data = _payload(rawData);
    final route = data['route']?.toString() ?? '';
    final callId = data['callId']?.toString() ?? '';
    final chatId = data['chatId']?.toString() ?? '';
    final senderId = data['senderId']?.toString() ?? '';

    if (route.startsWith('contacts:')) {
      if (mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ContactsScreen(repository: FirebaseChatRepository()),
        ));
      }
      return;
    }

    if (route.startsWith('voice_room:')) {
      final roomId = route.substring('voice_room:'.length);
      if (roomId.isNotEmpty && mounted) {
        final snap = await FirebaseFirestore.instance.collection('voiceRooms').doc(roomId).get();
        final data = snap.data() ?? const <String, dynamic>{};
        final roomName = data['roomName']?.toString() ?? '';
        final title = data['name']?.toString() ?? 'غرفة صوتية';
        if (snap.exists && roomName.isNotEmpty && mounted) {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => VoiceRoomScreen(roomId: roomId, roomName: roomName, title: title)));
        }
      }
      return;
    }

    if (route.startsWith('community:')) {
      final communityId = route.substring('community:'.length);
      if (communityId.isNotEmpty && mounted) {
        final snap = await FirebaseFirestore.instance.collection('communities').doc(communityId).get();
        final name = snap.data()?['name']?.toString() ?? data['title']?.toString() ?? 'مجتمع';
        if (snap.exists && mounted) {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommunityDetailScreen(
            communityId: communityId,
            name: name,
            service: CommunityService(),
          )));
        }
      }
      return;
    }

    if (callId.isNotEmpty || route.startsWith('call:')) {
      final id = callId.isNotEmpty ? callId : route.substring('call:'.length);
      if (id.isNotEmpty && mounted) {
        await CallService().handleIncomingCallById(context, id);
      }
      return;
    }

    if (chatId.isEmpty || senderId.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid == senderId) return;

    final snap = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
    if (!snap.exists || !mounted) return;
    final chat = snap.data() ?? <String, dynamic>{};
    final participants = List<String>.from(
      (chat['participants'] as List?)?.map((e) => e.toString()) ?? const [],
    );
    if (!participants.contains(uid) || !participants.contains(senderId)) return;

    final details = Map<String, dynamic>.from(chat['participantDetails'] as Map? ?? const {});
    final names = Map<String, dynamic>.from(chat['participantNames'] as Map? ?? const {});
    final photos = Map<String, dynamic>.from(chat['participantPhotos'] as Map? ?? const {});
    final senderDetails = details[senderId] is Map
        ? Map<String, dynamic>.from(details[senderId] as Map)
        : const <String, dynamic>{};

    await ChatNavigation.openRoom(context,chatId:chatId,otherUserId:senderId,otherUserName:names[senderId]?.toString()??senderDetails['name']?.toString()??'مستخدم',otherUserImage:photos[senderId]?.toString()??senderDetails['photoUrl']?.toString());
  }

  Future<void> _markAllRead() async {
    await _history.markAllRead();
    await _inbox.markAllRead();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ScrollAwareScaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          IconButton(
            tooltip: 'تحديد الكل كمقروء',
            onPressed: _markAllRead,
            icon: const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _history.watch(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('تعذر تحميل الإشعارات'));
          }
          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return FutureBuilder<List<NotificationInboxItem>>(
              future: _inbox.read(),
              builder: (context, fallback) {
                final items = fallback.data ?? const <NotificationInboxItem>[];
                if (items.isEmpty) {
                  return const Center(child: Text('لا توجد إشعارات'));
                }
                return _buildInboxFallback(items);
              },
            );
          }
          final unread = docs.where((doc) => doc.data()['read'] != true).length;
          return Column(
            children: [
              if (unread > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '$unread غير مقروء',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final read = data['read'] == true;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: MemoChatUiTokens.radiusMd,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: read
                            ? scheme.surfaceContainerHighest
                            : MemoChatUiTokens.accent.withOpacity(.12),
                        child: AppIcon(
                          AppIcons.notifications,
                          color: read
                              ? scheme.onSurfaceVariant
                              : MemoChatUiTokens.accent,
                        ),
                      ),
                      title: Text(
                        data['title']?.toString() ?? 'إشعار',
                        style: TextStyle(
                          fontWeight:
                              read ? FontWeight.w500 : FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(data['body']?.toString() ?? ''),
                      trailing: _invitationActions(data, doc.id),
                      onTap: () async {
                        await _history.markRead(doc.id);
                        await _openNotification(data);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInboxFallback(List<NotificationInboxItem> items) =>
      ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            leading: const CircleAvatar(
              child: AppIcon(AppIcons.notifications),
            ),
            title: Text(item.title),
            subtitle: Text(item.body),
            onTap: () async {
              await _inbox.markRead(item.id);
              if (mounted) setState(() {});
            },
          );
        },
      );
}
