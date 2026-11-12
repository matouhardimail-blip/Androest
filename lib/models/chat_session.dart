import 'dart:convert';

class ChatMessageData {
  final String role;
  String text; // <--- تم إزالة final من هنا ليصبح قابلاً للتعديل
  
  ChatMessageData({required this.role, required this.text});

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
  factory ChatMessageData.fromJson(Map<String, dynamic> json) => ChatMessageData(role: json['role'], text: json['text']);
}

class ChatSession {
  final String id;
  String title;
  final String agentId;
  final String agentName;
  List<ChatMessageData> messages;
  DateTime lastUpdated;

  ChatSession({
    required this.id,
    required this.title,
    required this.agentId,
    required this.agentName,
    required this.messages,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'agentId': agentId,
    'agentName': agentName,
    'messages': messages.map((m) => m.toJson()).toList(),
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'],
    title: json['title'],
    agentId: json['agentId'],
    agentName: json['agentName'],
    messages: (json['messages'] as List).map((m) => ChatMessageData.fromJson(m)).toList(),
    lastUpdated: DateTime.parse(json['lastUpdated']),
  );
}