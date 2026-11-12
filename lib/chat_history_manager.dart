import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/chat_session.dart';

class ChatHistoryManager {
  static const String _key = 'chat_history_sessions';

  // جلب جميع المحادثات
  static Future<List<ChatSession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_key);
    if (data == null || data.isEmpty) return [];
    
    try {
      List decoded = jsonDecode(data);
      List<ChatSession> sessions = decoded.map((e) => ChatSession.fromJson(e)).toList();
      // ترتيب المحادثات من الأحدث للأقدم
      sessions.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
      return sessions;
    } catch (e) {
      return [];
    }
  }

  // حفظ أو تحديث محادثة
  static Future<void> saveSession(ChatSession session) async {
    List<ChatSession> sessions = await loadSessions();
    int index = sessions.indexWhere((s) => s.id == session.id);
    
    if (index != -1) {
      sessions[index] = session;
    } else {
      sessions.add(session);
    }

    final prefs = await SharedPreferences.getInstance();
    String data = jsonEncode(sessions.map((e) => e.toJson()).toList());
    await prefs.setString(_key, data);
  }

  // حذف محادثة
  static Future<void> deleteSession(String sessionId) async {
    List<ChatSession> sessions = await loadSessions();
    sessions.removeWhere((s) => s.id == sessionId);
    final prefs = await SharedPreferences.getInstance();
    String data = jsonEncode(sessions.map((e) => e.toJson()).toList());
    await prefs.setString(_key, data);
  }
}