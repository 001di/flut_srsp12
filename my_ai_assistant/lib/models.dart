class Message {
  final String text;
  final bool isUser;
  final DateTime time;

  Message({required this.text, required this.isUser, DateTime? time})
      : time = time ?? DateTime.now();

  Map<String, dynamic> toJson() =>
      {'text': text, 'isUser': isUser, 'time': time.toIso8601String()};

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        text: j['text'],
        isUser: j['isUser'],
        time: DateTime.parse(j['time']),
      );
}

class Conversation {
  final String id;
  String title;
  String role;
  final DateTime createdAt;
  final List<Message> messages;

  Conversation({
    required this.id,
    this.title = 'Новый чат',
    this.role = 'consultant',
    DateTime? createdAt,
    List<Message>? messages,
  })  : createdAt = createdAt ?? DateTime.now(),
        messages = messages ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'role': role,
        'createdAt': createdAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'],
        title: j['title'],
        role: j['role'] ?? 'consultant',
        createdAt: DateTime.parse(j['createdAt']),
        messages: (j['messages'] as List)
            .map((m) => Message.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}
