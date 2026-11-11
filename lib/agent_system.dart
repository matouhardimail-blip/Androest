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
أنت أداة استخراج كلمات بحث. مهمتك تحويل سؤال المستخدم إلى كلمات بحث بالإنجليزية.
يجب أن يكون المخرج الوحيد هو: [SEARCH: كلمة_البحث]
لا تكتب أي شيء آخر. لا تشرح. لا تجب. فقط المخرج المطلوب.
""",
    );
  }
}

class Orchestrator {
  final LlamaController llama;
  Orchestrator(this.llama);

  Future<Agent> routeTask(String userPrompt) async {
    String routingPrompt = """
أنت منسق وكلاء. المستخدم يطلب: "$userPrompt"
اختر الوكيل الأنسب من القائمة التالية:
- إذا كان الطلب عن الذهب: اكتب [AGENT: GOLD]
- إذا كان الطلب عن عملة رقمية أو ميم كوين (مثل DOGE, PEPE): اكتب [AGENT: MEME]
- إذا كان الطلب عن أي شيء آخر (أخبار، معلومات، طقس): اكتب [AGENT: SEARCH]

المخرج المطلوب فقط (بدون أي كلام آخر): [AGENT: اسم_الوكيل]
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
