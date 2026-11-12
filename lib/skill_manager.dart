import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Skill {
  final String id;
  final String name;
  final String systemPrompt;
  final String description;

  Skill({required this.id, required this.name, required this.systemPrompt, required this.description});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'systemPrompt': systemPrompt,
    'description': description,
  };

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
    id: json['id'],
    name: json['name'],
    systemPrompt: json['systemPrompt'],
    description: json['description'],
  );
}

class SkillManager {
  static const String _key = 'agent_skills_v2';

  static Future<List<Skill>> loadSkills() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_key);
    
    if (data == null || data.isEmpty) {
      return _defaultSkills();
    }
    
    try {
      List decoded = jsonDecode(data);
      return decoded.map((e) => Skill.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveSkills(List<Skill> skills) async {
    final prefs = await SharedPreferences.getInstance();
    String data = jsonEncode(skills.map((e) => e.toJson()).toList());
    await prefs.setString(_key, data);
  }

  static List<Skill> _defaultSkills() {
    return [
      Skill(
        id: "default_coder",
        name: "مطور برمجيات",
        description: "متخصص في كتابة ومراجعة الأكواد",
        systemPrompt: "أنت مهندس برمجيات خبير. أجب بالأكواد البرمجية الدقيقة واشرحها باختصار.",
      ),
      Skill(
        id: "default_translator",
        name: "مترجم محترف",
        description: "ترجمة دقيقة بين اللغات",
        systemPrompt: "أنت مترجم محترف. ترجم النص المطلوب بدقة شديدة مع الحفاظ على السياق.",
      )
    ];
  }
}