import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../../chat/presentation/chat_navigation.dart';

class CallsHistoryScreen extends StatelessWidget {
  const CallsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المكالمات')),
      body: _body(),
    );
  }

  Widget _body() {
    if (Firebase.apps.isEmpty) {
      return const Center(child: Text('سجل المكالمات غير متاح حاليًا'));
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('يرجى تسجيل الدخول لعرض المكالمات'));
    }
    final caller = FirebaseFirestore.instance.collection('calls').where('callerId', isEqualTo: uid).limit(50).snapshots();
    final receiver = FirebaseFirestore.instance.collection('calls').where('receiverId', isEqualTo: uid).limit(50).snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: caller,
      builder: (context, outgoing) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: receiver,
        builder: (context, incoming) {
          if (outgoing.hasError || incoming.hasError) return const Center(child: Text('تعذر تحميل سجل المكالمات'));
          if (!outgoing.hasData || !incoming.hasData) return const Center(child: CircularProgressIndicator());
          final docs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
          for (final doc in outgoing.data!.docs) docs[doc.id] = doc;
          for (final doc in incoming.data!.docs) docs[doc.id] = doc;
          final calls = docs.values.toList()..sort((a, b) {
            final at = a.data()['createdAt'];
            final bt = b.data()['createdAt'];
            final ad = at is Timestamp ? at.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
            final bd = bt is Timestamp ? bt.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
            return bd.compareTo(ad);
          });
          if (calls.isEmpty) return const Center(child: Text('لا توجد مكالمات بعد'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: calls.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final data = calls[index].data();
              final isOutgoing = data['callerId'] == uid;
              final name = isOutgoing ? data['receiverName']?.toString() ?? 'مستخدم' : data['callerName']?.toString() ?? 'مستخدم';
              final video = data['isVideo'] == true;
              final status = data['status']?.toString() ?? '';
              final otherId = isOutgoing ? data['receiverId']?.toString() ?? '' : data['callerId']?.toString() ?? '';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(video ? Icons.videocam_rounded : (isOutgoing ? Icons.call_made_rounded : Icons.call_received_rounded))),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(video ? 'مكالمة فيديو • $status' : 'مكالمة صوتية • $status'),
                  trailing: IconButton(
                    tooltip: video ? 'اتصال فيديو' : 'اتصال صوتي',
                    onPressed: otherId.isEmpty || (data['chatId']?.toString().trim().isEmpty ?? true)
                        ? null
                        : () => ChatNavigation.openCall(
                            context,
                            chatId: data['chatId'].toString(),
                            userName: name,
                            userId: otherId,
                            isVideo: video,
                          ),
                    icon: Icon(video ? Icons.videocam_rounded : Icons.call_rounded),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
