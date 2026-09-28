class ChatUser {
  const ChatUser({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.isOnline = false,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool isOnline;
}
