import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'web_search.dart';
import 'trading_agent.dart';

// 1. تعريف الوكيل
class Agent {
  final String name;
  final String systemPrompt;
  final String description;

  Agent({required this.name, required this.systemPrompt, required this.description});
}

// 2. مصنع الوكلاء (ينشئ الوكلاء آلياً)
class AgentFactory {
  static Agent createGoldAgent() {
    return Agent(
      name: "وكيل الذهب",
      description: "متخصص في تحليل أسعار الذهب",
      systemPrompt: """
أنت وكيل تحليل فني خبير في الذهب. سأعطيك بيانات الأسعار.
قم بتحليل الاتجاه وأخرج القرار فقط بصيغة:
[SIGNAL: BUY] إذا كان صاعداً.
[SIGNAL: SELL] إذا كان هابطاً.
[SIGNAL: HOLD] إذا كان غير واضح.
""",
    );
  }

  static Agent createSearchAgent() {
    return Agent(
      name: "وكيل البحث",
      description: "يبحث في الإنترنت عن الأخبار والمعلومات",
      systemPrompt: """
أنت وكيل باحث. مهمتك الإجابة على أسئلة المستخدم.
إذا احتجت معلومات حديثة، اكتب [SEARCH: كلمة_البحث] فقط.
لا تجب من رأسك إذا لم تكن متأكداً.
""",
    );
  }

  static Agent createGeneralAgent() {
    return Agent(
      name: "الوكيل العام",
      description: "مساعد عام للأسئلة البسيطة",
      systemPrompt: "أنت مساعد ذكي. أجب على أسئلة المستخدم بوضوح وباللغة العربية.",
    );
  }
}

// 3. المنسق (Orchestrator) - يضمن التناوب
class Orchestrator {
  final LlamaController llama;
  
  Orchestrator(this.llama);

  // دالة اتخاذ القرار (توجيه المهمة)
  Agent routeTask(String userPrompt) {
    String lowerPrompt = userPrompt.toLowerCase();
    
    // توجيه بناءً على الكلمات المفتاحية لتوفير وقت المعالج
    if (lowerPrompt.contains("ذهب") || lowerPrompt.contains("gold") || lowerPrompt.contains("تداول")) {
      return AgentFactory.createGoldAgent();
    } 
    if (lowerPrompt.contains("ابحث") || lowerPrompt.contains("أخبار") || lowerPrompt.contains("من هو") || lowerPrompt.contains("ما هو")) {
      return AgentFactory.createSearchAgent();
    }
    
    // إذا لم يتم العثور على كلمات مفتاحية، نستخدم الوكيل العام
    return AgentFactory.createGeneralAgent();
  }
}
