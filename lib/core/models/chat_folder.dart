class ChatFolder {
  const ChatFolder({required this.id, required this.name, this.chatIds = const []});
  final String id;
  final String name;
  final List<String> chatIds;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'chatIds': chatIds};
  factory ChatFolder.fromJson(Map<String, dynamic> json) => ChatFolder(id: json['id']?.toString() ?? '', name: json['name']?.toString() ?? 'مجلد', chatIds: List<String>.from((json['chatIds'] as List?)?.map((e) => e.toString()) ?? const []));
}