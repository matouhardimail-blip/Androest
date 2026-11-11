import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'dart:async';
import 'skill_manager.dart';
import 'cloud_provider.dart';

class Agent {
  final String name;
  final String systemPrompt;
  final String description;

  Agent({required this.name, required this.systemPrompt, required this.description});
}

class AgentFactory {
  static Agent createAgent(AgentCapability cap) {
    switch (cap) {
      case AgentCapability.textGeneration:
        return Agent(name: "الوكيل العام", description: "محادثة نصية", systemPrompt: "أنت مساعد ذكي. أجب بوضوح.");
      case AgentCapability.imageGeneration:
        return Agent(name: "وكيل الصور", description: "توليد الصور", systemPrompt: "أنت خبير في صياغة أوامر توليد الصور (Prompts) بالإنجليزية.");
      case AgentCapability.speechToText:
        return Agent(name: "وكيل التفريغ", description: "تحويل الصوت لنص", systemPrompt: "أنت أداة تحويل الصوت إلى نص.");
      case AgentCapability.textToSpeech:
        return Agent(name: "وكيل النطق", description: "تحويل النص لصوت", systemPrompt: "أنت أداة تحويل النص إلى صوت.");
      case AgentCapability.embeddings:
        return Agent(name: "وكيل التضمين", description: "تحليل النصوص", systemPrompt: "أنت أداة تحليل وتضمين النصوص.");
      case AgentCapability.vision:
        return Agent(name: "وكيل الرؤية", description: "تحليل الصور", systemPrompt: "أنت خبير في وصف وتحليل الصور باللغة العربية.");
      case AgentCapability.videoGeneration:
        return Agent(name: "وكيل الفيديو", description: "توليد مقاطع فيديو", systemPrompt: "أنت خبير في كتابة أوامر توليد الفيديو.");
      case AgentCapability.audioGeneration:
        return Agent(name: "وكيل الصوتيات", description: "توليد الموسيقى", systemPrompt: "أنت خبير في توليد الموسيقى والأصوات.");
      case AgentCapability.translation:
        return Agent(name: "وكيل الترجمة", description: "ترجمة النصوص", systemPrompt: "أنت مترجم محترف. ترجم النص بدقة.");
      case AgentCapability.summarization:
        return Agent(name: "وكيل التلخيص", description: "تلخيص النصوص", systemPrompt: "أنت خبير في تلخيص النصوص الطويلة واستخراج النقاط الرئيسية.");
      case AgentCapability.codeGeneration:
        return Agent(name: "مهندس البرمجيات", description: "كتابة الأكواد وإدارة الملفات", systemPrompt: """
أنت مهندس برمجيات خبير. مهمتك كتابة الكود الكامل لإنشاء المشاريع وتعديل الملفات.
إذا طلب منك المستخدم إنشاء أو تعديل ملف، استخدم أداة الكتابة بالصيغة التالية:
[TOOL: write_file("lib/main.dart", "الكود هنا")]
إذا احتجت لقراءة ملف، استخدم:
[TOOL: read_file("lib/main.dart")]
""");
      case AgentCapability.search:
        return Agent(name: "وكيل البحث", description: "البحث في الإنترنت", systemPrompt: "أنت أداة بحث. اكتب [SEARCH: كلمة] فقط.");
      case AgentCapability.moderation:
        return Agent(name: "وكيل الأمان", description: "فحص المحتوى", systemPrompt: "أنت وكيل أمان. قم بمراجعة المحتوى وتحديد ما إذا كان آمناً أو مسيئاً.");
    }
  }

  static Agent createAgentFromSkill(Skill skill) {
    return Agent(name: skill.name, description: skill.description, systemPrompt: skill.systemPrompt);
  }
}