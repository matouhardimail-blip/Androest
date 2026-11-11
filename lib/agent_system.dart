import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'dart:async';

class Agent {
  final String name;
  final String systemPrompt;
  final String description;

  Agent({required this.name, required this.systemPrompt, required this.description});
}

class AgentFactory {
  static Agent createGoldAgent() {
    return Agent(
      name: "وكيل الذهب",
      description: "متخصص في تحليل أسعار الذهب",
      systemPrompt: "أنت وكيل تحليل فني. حلل البيانات وأخرج [SIGNAL: BUY] أو [SIGNAL: SELL] أو [SIGNAL: HOLD].",
    );
  }

  static Agent createMemeAgent() {
    return Agent(
      name: "وكيل الميم كوينز",
      description: "متخصص في العملات الرقمية والميم كوينز",
      systemPrompt: "أنت وكيل تحليل عملات رقمية. حلل البيانات وأخرج قراراً بالتداول.",
    );
  }

  static Agent createSearchAgent() {
    return Agent(
      name: "وكيل البحث",
      description: "يبحث في الإنترنت عن الأخبار والمعلومات",
      systemPrompt: """
أنت مساعد ذكي. إذا احتجت لمعلومات حديثة أو لم تكن تعرف الإجابة، يمكنك البحث في الإنترنت.
لكي تبحث، اكتب هذه الصيغة فقط: [SEARCH: الكلمة_بالإنجليزية]
مثال: [SEARCH: weather in Riyadh]
لا تطلب من المستخدم البحث. ابحث أنت بنفسك.
""",
    );
  }
}

class Orchestrator {
  final LlamaController llama;
  Orchestrator(this.llama);

  Future<Agent> routeTask(String userPrompt) async {
    String lowerPrompt = userPrompt.toLowerCase();
    
    if (lowerPrompt.contains("ذهب") || lowerPrompt.contains("gold") || lowerPrompt.contains("تداول")) {
      return AgentFactory.createGoldAgent();
    } 
    if (lowerPrompt.contains("doge") || lowerPrompt.contains("pepe") || lowerPrompt.contains("shib") || lowerPrompt.contains("ميم")) {
      return AgentFactory.createMemeAgent();
    }

    String routingPrompt = """
أنت منسق وكلاء. المستخدم يطلب: "$userPrompt"
اختر الوكيل الأنسب:
- إذا كان الطلب عن الذهب: [AGENT: GOLD]
- إذا كان الطلب عن عملة رقمية: [AGENT: MEME]
- إذا كان الطلب عن أي شيء آخر: [AGENT: SEARCH]
المخرج المطلوب فقط: [AGENT: اسم_الوكيل]
""";

    String decision = "";
    Completer<String> completer = Completer();

    final sub = llama.generate(prompt: routingPrompt, maxTokens: 20, temperature: 0.1).listen(
      (token) => decision += token,
      onDone: () => completer.complete(decision),
      onError: (e) => completer.completeError(e),
    );

    try {
      String result = await completer.future;
      sub.cancel();
      if (result.contains("[AGENT: GOLD]")) return AgentFactory.createGoldAgent();
      if (result.contains("[AGENT: MEME]")) return AgentFactory.createMemeAgent();
      return AgentFactory.createSearchAgent();
    } catch (e) {
      return AgentFactory.createSearchAgent();
    }
  }
}