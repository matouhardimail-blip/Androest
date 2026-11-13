import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/agent_model.dart';
import 'package:flutter/material.dart';

class AgentManager {
  static const String _key = 'user_agents_registry';

  static Future<List<AgentModel>> loadAgents() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_key);
    
    if (data == null || data.isEmpty) {
      return _defaultAgents(); 
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

  // دالة تصدير الوكلاء كملف JSON ومشاركته
  static Future<void> exportAgents(List<AgentModel> agents) async {
    try {
      final data = jsonEncode(agents.map((e) => e.toJson()).toList());
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ai_hub_agents_backup.json');
      await file.writeAsString(data);
      
      await Share.shareXFiles([XFile(file.path)], text: 'نسخة احتياطية من وكلاء AI HUB');
    } catch (e) {
      print("Error exporting agents: $e");
    }
  }

  // دالة استيراد الوكلاء من نص JSON
  static Future<List<AgentModel>> importAgents(String jsonString) async {
    try {
      List decoded = jsonDecode(jsonString);
      return decoded.map((e) => AgentModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
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