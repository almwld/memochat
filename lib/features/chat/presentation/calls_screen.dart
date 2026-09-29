import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:memochat/core/constants/app_colors.dart';
import 'package:memochat/features/chat/models/call_model.dart';
import 'package:memochat/features/chat/services/call_service.dart';
import 'package:memochat/features/chat/presentation/chat_room_screen.dart' show ChatRoomScreen;

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
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      return _empty('سجّل الدخول لعرض سجل المكالمات', isDark);
    }

    return StreamBuilder<List<CallModel>>(
      stream: CallService().streamCallHistory(limit: 50),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (snapshot.hasError) {
          debugPrint('call history error: ${snapshot.error}');
          if (_lastCalls.isNotEmpty) {
            return _buildCallsList(context, _lastCalls, currentUid, isDark);
          }
          return _empty('تعذر تحميل سجل المكالمات حالياً\nتحقق من الاتصال وحاول مرة أخرى', isDark);
        }

        if (snapshot.hasData) {
          _lastCalls = snapshot.data!;
        }
        final calls = snapshot.data ?? _lastCalls;
        if (calls.isEmpty) {
          return _empty('لا توجد مكالمات بعد\nستظهر مكالماتك هنا تلقائياً', isDark);
        }

        return _buildCallsList(context, calls, currentUid, isDark);
      },
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
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatRoomScreen(
              chatId: call.chatId,
              otherUserId: otherId,
              otherUserName: otherName,
              otherUserImage: otherPhoto,
            )));
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
