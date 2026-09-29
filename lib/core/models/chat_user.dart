class ChatUser {
  const ChatUser({
    required this.id,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.isOnline = false,
  });

  final String id;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final bool isOnline;
}
