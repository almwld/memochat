import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:memochat/core/constants/app_colors.dart';
import 'package:memochat/features/chat/models/call_model.dart';
import 'package:memochat/features/chat/services/call_service.dart';
import 'package:memochat/features/chat/models/status_model.dart';
import 'package:memochat/features/chat/services/status_service.dart';
import 'add_status_screen.dart';
import 'story_viewer_screen.dart';
import 'package:memochat/features/chat/presentation/chat_room_screen.dart' show ChatRoomScreen;
import 'package:memochat/features/chat/presentation/chat_navigation.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  List<CallModel> _lastCalls = const [];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (Firebase.apps.isEmpty) return _empty('سجّل الدخول لعرض سجل المكالمات', isDark);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      return _empty('سجّل الدخول لعرض سجل المكالمات', isDark);
    }

    return StreamBuilder<List<UserStatusModel>>(
      stream: StatusService().streamActiveStatuses(),
      builder: (context, statusSnapshot) {
        final statuses = statusSnapshot.data ?? const <UserStatusModel>[];
        final mine = currentUid == null
            ? null
            : statuses.where((s) => s.userId == currentUid).firstOrNull;
        final others = statuses.where((s) => s.userId != currentUid).toList()
          ..sort((a, b) {
            if (a.isViewed != b.isViewed) return a.isViewed ? 1 : -1;
            return b.createdAt.compareTo(a.createdAt);
          });
        return Column(
          children: [
            _buildStatusHeader(context, statuses, mine, isDark),
            Expanded(
              child: StreamBuilder<List<CallModel>>(
                stream: CallService().streamCallHistory(limit: 50),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  if (snapshot.hasError) {
                    debugPrint('call history error: \${snapshot.error}');
                    if (_lastCalls.isNotEmpty) return _buildCallsList(context, _lastCalls, currentUid, isDark);
                    return _empty('تعذر تحميل سجل المكالمات حالياً\nتحقق من الاتصال وحاول مرة أخرى', isDark);
                  }
                  if (snapshot.hasData) _lastCalls = snapshot.data!;
                  final calls = snapshot.data ?? _lastCalls;
                  if (calls.isEmpty) return _empty('لا توجد مكالمات بعد\nستظهر مكالماتك هنا تلقائياً', isDark);
                  return _buildCallsList(context, calls, currentUid, isDark);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusHeader(BuildContext context, List<UserStatusModel> statuses, UserStatusModel? mine, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              const Expanded(child: Text('الحالات اليومية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            ],
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            scrollDirection: Axis.horizontal,
            itemCount: others.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _StatusAddTile(
                  hasStatus: mine != null,
                  status: mine,
                  onTap: () {
                    if (mine != null) {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryViewerScreen(status: mine)));
                    } else {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddStatusScreen()));
                    }
                  },
                );
              }
              final status = others[index - 1];
              return _StatusTile(
                status: status,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryViewerScreen(status: status))),
              );
            },
          ),
        ),
        Divider(height: 1, color: isDark ? const Color(0xFF273449) : const Color(0xFFE5E7EB)),
      ],
    );
  }

  Widget _buildCallsList(BuildContext context, List<CallModel> calls, String uid, bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      itemCount: calls.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) => _callTile(context, calls[index], uid, isDark),
    );
  }

  Widget _callTile(BuildContext context, CallModel call, String uid, bool isDark) {
    final outgoing = call.callerId == uid;
    final name = outgoing ? call.receiverName : call.callerName;
    final photo = outgoing ? call.receiverPhotoUrl : call.callerPhotoUrl;
    final missed = call.status == CallStatus.missed;
    final rejected = call.status == CallStatus.rejected;
    final color = missed || rejected ? AppColors.error : AppColors.primary;
    final statusText = _statusText(call.status, outgoing);
    final typeText = call.isVideoCallType ? 'فيديو' : 'صوت';

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF162039) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: CircleAvatar(
          radius: 27,
          backgroundColor: AppColors.primary.withOpacity(.12),
          backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
          child: photo == null || photo.isEmpty
              ? const Icon(Icons.person, color: AppColors.primary)
              : null,
        ),
        title: Text(name.isEmpty ? 'مستخدم' : name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Row(
          children: [
            Icon(
              outgoing ? Icons.call_made : Icons.call_received,
              size: 15,
              color: color,
            ),
            const SizedBox(width: 5),
            Flexible(child: Text('$statusText • $typeText', overflow: TextOverflow.ellipsis)),
          ],
        ),
        trailing: TextButton(
          onPressed: () async {
            if (call.chatId.isEmpty) return;
            final otherId = outgoing ? call.receiverId : call.callerId;
            final otherName = outgoing ? call.receiverName : call.callerName;
            final otherPhoto = outgoing ? call.receiverPhotoUrl : call.callerPhotoUrl;
            await ChatNavigation.openRoom(context,chatId:call.chatId,otherUserId:otherId,otherUserName:otherName,otherUserImage:otherPhoto);
          },
          child: const Text('المحادثة'),
        ),
      ),
    );
  }

  String _statusText(CallStatus status, bool outgoing) {
    switch (status) {
      case CallStatus.calling:
      case CallStatus.ringing:
        return outgoing ? 'جارٍ الاتصال' : 'واردة';
      case CallStatus.connected:
        return 'متصلة';
      case CallStatus.ended:
        return 'منتهية';
      case CallStatus.missed:
        return 'فائتة';
      case CallStatus.rejected:
        return 'مرفوضة';
      case CallStatus.busy:
        return 'مشغول';
      case CallStatus.cancelled:
        return 'ملغاة';
    }
  }

  Widget _empty(String message, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            height: 1.6,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ),
    );
  }
}


class _StatusAddTile extends StatelessWidget {
  const _StatusAddTile({required this.hasStatus, required this.status, required this.onTap});
  final bool hasStatus;
  final UserStatusModel? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = status?.userImage?.trim() ?? '';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: scheme.primary, width: 2)),
                  child: CircleAvatar(radius: 29, backgroundImage: image.isEmpty ? null : NetworkImage(image), child: image.isEmpty ? const Icon(Icons.person_outline_rounded) : null),
                ),
                PositionedDirectional(
                  end: 0,
                  bottom: 0,
                  child: Container(
                    width: 23,
                    height: 23,
                    decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2)),
                    child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(hasStatus ? 'حالتي' : 'إضافة حالة', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.status, required this.onTap});
  final UserStatusModel status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = status.userImage?.trim() ?? '';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: status.isViewed ? Theme.of(context).dividerColor : Theme.of(context).colorScheme.primary, width: 2)),
              child: CircleAvatar(radius: 29, backgroundImage: image.isEmpty ? null : NetworkImage(image), child: image.isEmpty ? Text(status.userName.characters.first) : null),
            ),
            const SizedBox(height: 6),
            Text(status.userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
