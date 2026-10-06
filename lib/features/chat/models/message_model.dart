import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum MessageType { text, image, audio, video, file, location, contact, system, reaction, reply, deleted, call, gameInvite }
enum MessageStatus { sending, sent, delivered, read, failed }

class MessageModel extends Equatable {
  final String id, chatId, senderId, senderName;
  final String? senderPhotoUrl, text;
  final String? ciphertext, encryptedKey, nonce;
  final bool isEncrypted;
  final Map<String, dynamic>? replyPreview;
  final MessageType type;
  final Timestamp? timestamp, clientTimestamp, readAt, deliveredAt, editedAt, pinnedAt;
  final bool isRead, isDelivered, isEdited, isDeleted, isPinned, isStarred;
  final MessageStatus status;
  final String? replyToId, idempotencyKey;
  final MessageModel? replyTo;
  final Map<String, String>? reactions;
  final Map<String, bool>? deletedFor;
  final Map<String, dynamic>? attachments, metadata;
  final String? imageUrl, audioUrl, fileUrl, videoUrl, locationUrl, locationAddress;
  final String? audioDuration, fileSize, fileName, fileMimeType, thumbnailUrl;
  final double? locationLat, locationLng;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    this.text,
    this.ciphertext,
    this.encryptedKey,
    this.nonce,
    this.isEncrypted = false,
    this.replyPreview,
    this.type = MessageType.text,
    this.timestamp,
    this.clientTimestamp,
    this.isRead = false,
    this.isDelivered = false,
    this.isEdited = false,
    this.isDeleted = false,
    this.replyToId,
    this.idempotencyKey,
    this.replyTo,
    this.reactions = const {},
    this.deletedFor,
    this.attachments,
    this.metadata,
    this.imageUrl,
    this.audioUrl,
    this.fileUrl,
    this.videoUrl,
    this.locationUrl,
    this.locationAddress,
    this.locationLat,
    this.locationLng,
    this.audioDuration,
    this.fileSize,
    this.fileName,
    this.fileMimeType,
    this.thumbnailUrl,
    this.readAt,
    this.deliveredAt,
    this.editedAt,
    this.pinnedAt,
    this.isPinned = false,
    this.isStarred = false,
    this.status = MessageStatus.sent,
  });

  factory MessageModel.fromFirestore(String id, Map<String, dynamic> data) {
    Timestamp? timestampOf(dynamic value) {
      if (value is Timestamp) return value;
      if (value is DateTime) return Timestamp.fromDate(value);
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return Timestamp.fromDate(parsed);
      }
      if (value is num) return Timestamp.fromMillisecondsSinceEpoch(value.toInt());
      return null;
    }

    Map<String, dynamic>? mapOf(dynamic value) {
      if (value is! Map) return null;
      return value.map((key, value) => MapEntry(key.toString(), value));
    }

    double? doubleOf(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    final serverTimestamp = timestampOf(data['timestamp']);
    final clientTimestamp = timestampOf(data['clientTimestamp']);
    final effectiveTimestamp = serverTimestamp ?? clientTimestamp ?? Timestamp.now();
    final rawStatus = data['status']?.toString();
    final status = MessageStatus.values.firstWhere(
      (value) => value.name == rawStatus,
      orElse: () => data['isRead'] == true
          ? MessageStatus.read
          : data['isDelivered'] == true
              ? MessageStatus.delivered
              : MessageStatus.sent,
    );
    final rawReactions = mapOf(data['reactions']);
    final rawDeletedFor = mapOf(data['deletedFor']);

    return MessageModel(
      id: id,
      chatId: data['chatId']?.toString() ?? '',
      senderId: data['senderId']?.toString() ?? '',
      senderName: data['senderName']?.toString() ?? 'مستخدم',
      senderPhotoUrl: data['senderPhotoUrl']?.toString(),
      ciphertext: data['ciphertext']?.toString(),
      encryptedKey: data['encryptedKey']?.toString(),
      nonce: data['nonce']?.toString(),
      isEncrypted: data['type']?.toString() == 'encrypted' || data['e2eeVersion'] != null,
      text: data['text']?.toString(),
      replyPreview: mapOf(data['replyPreview']),
      type: MessageType.values.firstWhere(
        (value) => value.name == data['type']?.toString(),
        orElse: () => data['type']?.toString() == 'game_invite'
            ? MessageType.gameInvite
            : MessageType.text,
      ),
      timestamp: effectiveTimestamp,
      clientTimestamp: clientTimestamp,
      isRead: data['isRead'] == true || status == MessageStatus.read,
      isDelivered: data['isDelivered'] == true ||
          status == MessageStatus.delivered ||
          status == MessageStatus.read,
      isEdited: data['isEdited'] == true,
      isDeleted: data['isDeleted'] == true,
      status: status,
      replyToId: data['replyToId']?.toString(),
      idempotencyKey: data['idempotencyKey']?.toString(),
      reactions: rawReactions == null
          ? <String, String>{}
          : rawReactions.map((key, value) => MapEntry(key, value.toString())),
      deletedFor: rawDeletedFor == null
          ? <String, bool>{}
          : rawDeletedFor.map((key, value) => MapEntry(key, value == true)),
      attachments: mapOf(data['attachments']),
      metadata: mapOf(data['metadata']),
      imageUrl: data['imageUrl']?.toString(),
      audioUrl: data['audioUrl']?.toString(),
      fileUrl: data['fileUrl']?.toString(),
      videoUrl: data['videoUrl']?.toString(),
      locationUrl: data['locationUrl']?.toString(),
      locationAddress: data['locationAddress']?.toString(),
      locationLat: doubleOf(data['locationLat']),
      locationLng: doubleOf(data['locationLng']),
      audioDuration: data['audioDuration']?.toString(),
      fileSize: data['fileSize']?.toString(),
      fileName: data['fileName']?.toString(),
      fileMimeType: data['fileMimeType']?.toString(),
      thumbnailUrl: data['thumbnailUrl']?.toString(),
      readAt: timestampOf(data['readAt']),
      deliveredAt: timestampOf(data['deliveredAt']),
      editedAt: timestampOf(data['editedAt']),
      pinnedAt: timestampOf(data['pinnedAt']),
      isPinned: data['isPinned'] == true,
      isStarred: data['isStarred'] == true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'chatId': chatId,
        'senderId': senderId,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'ciphertext': ciphertext,
        'encryptedKey': encryptedKey,
        'nonce': nonce,
        'text': text,
        'type': type.name,
        'timestamp': timestamp ?? FieldValue.serverTimestamp(),
        'clientTimestamp': clientTimestamp,
        'isRead': isRead || status == MessageStatus.read,
        'isDelivered': isDelivered || status == MessageStatus.delivered || status == MessageStatus.read,
        'isEdited': isEdited,
        'isDeleted': isDeleted,
        'replyToId': replyToId,
        'replyPreview': replyPreview,
        'idempotencyKey': idempotencyKey,
        'reactions': reactions,
        'deletedFor': deletedFor,
        'attachments': attachments,
        'metadata': metadata,
        'imageUrl': imageUrl,
        'audioUrl': audioUrl,
        'fileUrl': fileUrl,
        'videoUrl': videoUrl,
        'locationUrl': locationUrl,
        'locationAddress': locationAddress,
        'locationLat': locationLat,
        'locationLng': locationLng,
        'audioDuration': audioDuration,
        'fileSize': fileSize,
        'fileName': fileName,
        'fileMimeType': fileMimeType,
        'thumbnailUrl': thumbnailUrl,
        'status': status.name,
        'readAt': readAt,
        'deliveredAt': deliveredAt,
        'editedAt': editedAt,
        'pinnedAt': pinnedAt,
        'isPinned': isPinned,
        'isStarred': isStarred,
      };

  bool get isImage => type == MessageType.image;
  bool get isAudio => type == MessageType.audio;
  bool get isVideo => type == MessageType.video;
  bool get isFile => type == MessageType.file;
  bool get isLocation => type == MessageType.location;
  bool get isText => type == MessageType.text;
  bool get isReply => type == MessageType.reply;
  bool get isCall => type == MessageType.call;
  bool get hasReactions => reactions?.isNotEmpty ?? false;
  bool get hasAttachments => attachments?.isNotEmpty ?? false;

  @override
  List<Object?> get props => [
        id, chatId, senderId, senderName, senderPhotoUrl, text, ciphertext,
        encryptedKey, nonce, isEncrypted, type,
        timestamp, clientTimestamp, isRead, isDelivered, isEdited, isDeleted,
        replyToId, idempotencyKey, reactions, deletedFor, attachments, metadata,
        imageUrl, audioUrl, fileUrl, videoUrl, locationUrl, locationAddress,
        locationLat, locationLng, audioDuration, fileSize, fileName, fileMimeType,
        thumbnailUrl, readAt, deliveredAt, editedAt, pinnedAt, isPinned, isStarred, status,
      ];
}
