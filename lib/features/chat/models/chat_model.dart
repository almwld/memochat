import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ChatModel extends Equatable {
  final String id;
  final List<String> participants;
  final Map<String, dynamic> participantDetails;
  final String? lastMessage;
  final Timestamp? lastMessageTime;
  final String? lastMessageSenderId;
  final Map<String, int> unreadCount;
  final bool isGroup;
  final String? groupName;
  final String? groupPhoto;
  final bool isArchived;
  final bool isPinned;
  final bool isMuted;
  final bool isOnline;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Map<String, dynamic>? metadata;

  const ChatModel({
    required this.id,
    required this.participants,
    this.participantDetails = const {},
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    this.unreadCount = const {},
    this.isGroup = false,
    this.groupName,
    this.groupPhoto,
    this.isArchived = false,
    this.isPinned = false,
    this.isMuted = false,
    this.isOnline = false,
    this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  factory ChatModel.fromFirestore(String id, Map<String, dynamic> data) {
    Timestamp? timestampOf(dynamic value) {
      if (value is Timestamp) return value;
      if (value is DateTime) return Timestamp.fromDate(value);
      if (value is num) {
        final raw = value.toInt();
        return Timestamp.fromMillisecondsSinceEpoch(
          raw > 100000000000 ? raw : raw * 1000,
        );
      }
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return Timestamp.fromDate(parsed);
      }
      return null;
    }

    List<String> stringsOf(dynamic value) {
      if (value is! Iterable) return <String>[];
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    Map<String, dynamic> mapOf(dynamic value) {
      if (value is! Map) return <String, dynamic>{};
      return value.map((key, value) => MapEntry(key.toString(), value));
    }

    Map<String, int> unreadOf(dynamic value) {
      final raw = mapOf(value);
      return raw.map((key, value) {
        final parsed = value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
        return MapEntry(key, (parsed ?? 0).clamp(0, 2147483647));
      });
    }

    bool boolOf(dynamic value) =>
        value is bool ? value : value?.toString().toLowerCase() == 'true';

    final details = mapOf(data['participantDetails']);
    final rawMetadata = mapOf(data['metadata']);

    return ChatModel(
      id: id,
      participants: stringsOf(data['participants']),
      participantDetails: details,
      lastMessage: data['lastMessage']?.toString(),
      lastMessageTime: timestampOf(data['lastMessageTime']),
      lastMessageSenderId: data['lastMessageSenderId']?.toString(),
      unreadCount: unreadOf(data['unreadCount']),
      isGroup: boolOf(data['isGroup']),
      groupName: data['groupName']?.toString(),
      groupPhoto: data['groupPhoto']?.toString(),
      isArchived: boolOf(data['isArchived']),
      isPinned: boolOf(data['isPinned']),
      isMuted: boolOf(data['isMuted']),
      isOnline: boolOf(data['isOnline']),
      createdAt: timestampOf(data['createdAt']),
      updatedAt: timestampOf(data['updatedAt']),
      metadata: rawMetadata.isEmpty ? null : rawMetadata,
    );
  }

  String _otherParticipantId(String userId) {
    final p = participants.firstWhere(
      (p) => p.trim().isNotEmpty && p != userId,
      orElse: () => '',
    );
    if (p.isNotEmpty) return p;
    for (final key in participantDetails.keys) {
      final otherId = key.toString().trim();
      if (otherId.isNotEmpty && otherId != userId) return otherId;
    }
    return '';
  }

  String getDisplayName(String userId) {
    if (isGroup) {
      final name = groupName?.trim();
      return name?.isNotEmpty == true ? name! : 'مجموعة';
    }
    final d = participantDetails[_otherParticipantId(userId)];
    if (d is Map) {
      final name = d['name']?.toString().trim();
      if (name?.isNotEmpty == true) return name!;
    }
    return 'مستخدم';
  }

  String getDisplayPhoto(String userId) {
    if (isGroup) return groupPhoto?.toString() ?? '';
    final d = participantDetails[_otherParticipantId(userId)];
    return d is Map ? d['photoUrl']?.toString() ?? '' : '';
  }

  String getOtherParticipant(String userId) => _otherParticipantId(userId);

  int getTotalUnreadCount() =>
      unreadCount.values.fold(0, (sum, count) => sum + count);

  @override
  List<Object?> get props => [
        id,
        participants,
        participantDetails,
        lastMessage,
        lastMessageTime,
        lastMessageSenderId,
        unreadCount,
        isGroup,
        groupName,
        groupPhoto,
        isArchived,
        isPinned,
        isMuted,
        isOnline,
        createdAt,
        updatedAt,
        metadata,
      ];
}
