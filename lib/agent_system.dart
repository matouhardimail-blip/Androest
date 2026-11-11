import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'web_search.dart';
import 'trading_agent.dart';

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
      // هذا البرومبت الصارم سيمنع الموديل من الكلام ويجبره على طلب البحث فقط
      systemPrompt: """
أنت أداة استخراج كلمات بحث. مهمتك الوحيدة هي تحويل سؤال المستخدم إلى كلمات بحث بالإنجليزية.
يجب أن يكون المخرج الوحيد هو: [SEARCH: كلمة_البحث]
لا تكتب أي شيء آخر. لا تشرح. لا تجب. فقط المخرج المطلوب.
مثال: المستخدم: ما هو سعر الذهب اليوم؟ -> المخرج: [SEARCH: gold price today]
مثال: المستخدم: من هو ميسي؟ -> المخرج: [SEARCH: Lionel Messi]
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

class Orchestrator {
  final LlamaController llama;
  
  Orchestrator(this.llama);

  Agent routeTask(String userPrompt) {
    String lowerPrompt = userPrompt.toLowerCase();
    
    if (lowerPrompt.contains("ذهب") || lowerPrompt.contains("gold") || lowerPrompt.contains("تداول")) {
      return AgentFactory.createGoldAgent();
    } 
    // توجيه أي سؤال آخر إلى وكيل البحث
    return AgentFactory.createSearchAgent();
  }
}
