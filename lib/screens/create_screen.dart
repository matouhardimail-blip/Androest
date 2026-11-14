// ... الاستيرادات ...
import 'package:flutter_background_service/flutter_background_service.dart';

// ... داخل كلاس _CreateScreenState ...

  void _startWorkflow() {
    // ... التحقق من المدخلات ...
    
    // تشغيل الخدمة
    FlutterBackgroundService().startService();
    FlutterBackgroundService().invoke("setAsForeground");

    setState(() {
      // ... إعداد غرفة العمليات ...
    });

    _runAgentStep(_currentAgentIndex);
  }

  Future<void> _runAgentStep(int index) async {
    // ... تنفيذ الوكيل ...

    try {
      await for (final chunk in _api.generateStream(
        // ...
      )) {
        // ... تحديث الواجهة ...
      }
      setState(() { _isGenerating = false; _currentAgentIndex++; });
      
      // لا نوقف الخدمة هنا لأن الوكيل التالي قد يبدأ قريباً
      
    } catch (e) {
      // ...
    }
  }

  void _finishWorkflow() {
    setState(() {
      _isGenerating = false;
      _chatLog.add({'role': 'system', 'text': '✅ انتهى الاجتماع وتم إنتاج المشروع.'});
    });
    
    // إيقاف الخدمة بعد انتهاء كل شيء
    FlutterBackgroundService().invoke("setAsBackground");

    // ... حفظ المهمة ...
  }