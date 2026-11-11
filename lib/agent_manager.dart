import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/agent_model.dart';
import 'package:flutter/material.dart';

class AgentManager {
  static const String _key = 'user_agents_registry';

  static Future<List<AgentModel>> loadAgents() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_key);
    
    if (data == null || data.isEmpty) {
      return _defaultAgents(); // وكلاء افتراضيون في حال كان التطبيق جديداً
    }
    
    try {
      List decoded = jsonDecode(data);
      return decoded.map((e) => AgentModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveAgents(List<AgentModel> agents) async {
    final prefs = await SharedPreferences.getInstance();
    String data = jsonEncode(agents.map((e) => e.toJson()).toList());
    await prefs.setString(_key, data);
  }

  static List<AgentModel> _defaultAgents() {
    return [
      AgentModel(
        id: "default_gpt",
        name: "ChatGPT",
        description: "مساعد عام ذكي",
        providerId: "default", 
        modelName: "GPT-4o",
        systemPrompt: "أنت مساعد ذكي. أجب بوضوح.",
        icon: Icons.chat,
        color: Colors.green,
      )
    ];
  }
}