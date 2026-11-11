import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AgentMessage {
  final String role;
  final String text;
  AgentMessage({required this.role, required this.text});

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
  factory AgentMessage.fromJson(Map<String, dynamic> json) => AgentMessage(role: json['role'], text: json['text']);
}

class ChatSession {
  final String id;
  String title;
  List<AgentMessage> messages;
  DateTime lastUpdated;

  ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'],
    title: json['title'],
    messages: (json['messages'] as List).map((m) => AgentMessage.fromJson(m)).toList(),
    lastUpdated: DateTime.parse(json['lastUpdated']),
  );
}

class ChatHistoryManager {
  static const String _key = 'chat_sessions_history';

  static Future<List<ChatSession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_key);
    if (data == null || data.isEmpty) return [];
    
    try {
      List decoded = jsonDecode(data);
      return decoded.map((e) => ChatSession.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveSessions(List<ChatSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsToSave = sessions.length > 30 ? sessions.sublist(sessions.length - 30) : sessions;
    String data = jsonEncode(sessionsToSave.map((e) => e.toJson()).toList());
    await prefs.setString(_key, data);
  }
}