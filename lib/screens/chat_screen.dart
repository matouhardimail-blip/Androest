// ... الاستيرادات ...
import 'package:flutter_background_service/flutter_background_service.dart';

// ... داخل كلاس _ChatScreenState ...

  void _executeAIGeneration(String finalPrompt, {String? imageBase64}) {
    // تشغيل خدمة الخلفية
    FlutterBackgroundService().startService();
    FlutterBackgroundService().invoke("setAsForeground");

    List<Map<String, String>> chatHistory = _currentSession.messages.map((m) => {'role': m.role, 'text': m.text}).toList();
    String currentResponse = "";
    int aiMessageIndex = _currentSession.messages.length - 1;

    String finalSystemPrompt = widget.agent.systemPrompt;
    // ... باقي الكود ...

    if (_providerConfig!.providerType == 'local') {
      _streamSubscription = _localLlama.generateStream(systemPrompt: finalSystemPrompt, userPrompt: finalPrompt).listen(
        (chunk) { currentResponse += chunk; setState(() { _currentSession.messages[aiMessageIndex].text = currentResponse; }); _scrollToBottom(); },
        onDone: () { 
           setState(() => _isLoading = false); 
           _saveHistory(); 
           FlutterBackgroundService().invoke("setAsBackground"); // إعادة للخلفية
        },
        onError: (e) { 
           setState(() { _currentSession.messages[aiMessageIndex].text = "❌ خطأ: $e"; _isLoading = false; }); 
           FlutterBackgroundService().invoke("setAsBackground");
        },
      );
    } else {
      _streamSubscription = _api.generateStream(
        provider: _providerConfig!.providerType, apiKey: _providerConfig!.apiKey, baseUrl: _providerConfig!.baseUrl, modelName: _providerConfig!.modelName,
        systemPrompt: finalSystemPrompt, userPrompt: finalPrompt, chatHistory: chatHistory, useTools: _isWebSearchEnabled, imageBase64: imageBase64,
      ).listen(
        (chunk) { currentResponse += chunk; setState(() { _currentSession.messages[aiMessageIndex].text = currentResponse; }); _scrollToBottom(); },
        onDone: () { 
           setState(() => _isLoading = false); 
           _saveHistory(); 
           FlutterBackgroundService().invoke("setAsBackground"); // إعادة للخلفية
        },
        onError: (e) { 
           setState(() { _currentSession.messages[aiMessageIndex].text = "❌ خطأ: $e"; _isLoading = false; }); 
           _saveHistory(); 
           FlutterBackgroundService().invoke("setAsBackground");
        },
        cancelOnError: true,
      );
    }
  }