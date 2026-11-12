import 'package:llama_flutter_android/llama_flutter_android.dart';

class LocalLlamaService {
  final LlamaController _llama = LlamaController();
  bool _isModelLoaded = false;

  bool get isModelLoaded => _isModelLoaded;

  Future<void> loadModel(String modelPath) async {
    if (_isModelLoaded) return;
    await _llama.loadModel(
      modelPath: modelPath,
      contextSize: 2048, // يمكن زيادتها حسب قدرة الهاتف
    );
    _isModelLoaded = true;
  }

  Stream<String> generateStream({
    required String systemPrompt,
    required String userPrompt,
  }) async* {
    if (!_isModelLoaded) {
      yield "❌ خطأ: الموديل المحلي غير محمل. يرجى تحميله من الإعدادات.";
      return;
    }

    String fullPrompt = "$systemPrompt\n\nطلب المستخدم: $userPrompt\nالرد:";

    try {
      final stream = _llama.generate(
        prompt: fullPrompt,
        maxTokens: 512,
        temperature: 0.3,
      );

      await for (final chunk in stream) {
        yield chunk;
      }
    } catch (e) {
      yield "\n\n❌ خطأ في الموديل المحلي: $e";
    }
  }

  void clearContext() {
    _llama.clearContext();
  }

  void dispose() {
    _llama.dispose();
    _isModelLoaded = false;
  }
}