import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:llama_flutter_android/llama_flutter_android.dart' as llama;

import '../config/app_config.dart';
import '../models/chat_message.dart';
import 'model_downloader.dart';

/// مراحل تجهيز النموذج (تُعرض في شاشة التحميل).
enum BootPhase { checking, downloading, loading, ready, failed }

typedef BootStatus = void Function(BootPhase phase, double progress, String text);

/// الطبقة الوحيدة التي تتعامل مع llama.cpp.
/// تُخفي التنزيل، فحص الذاكرة، التحميل، إدارة السياق، والإيقاف خلف واجهة بسيطة.
class LlmService {
  LlmService() : _downloader = ModelDownloader();

  final ModelDownloader _downloader;

  llama.LlamaController? _controller;
  StreamSubscription<double>? _loadSub;
  ModelSpec _spec = ModelSpec.active;
  String? _modelPath;
  bool _loaded = false;

  bool get isReady => _loaded;
  ModelSpec get spec => _spec;
  String? get modelPath => _modelPath;

  /// يُستدعى مرة واحدة عند إقلاع التطبيق.
  Future<void> prepare({
    required BootStatus onStatus,
    CancelToken? cancelToken,
  }) async {
    _spec = ModelSpec.active;
    _controller ??= llama.LlamaController();

    // محاولة سابقة قد تكون فشلت بعد تحميل النموذج أصلاً في الطبقة الأصلية؛
    // عندها ترفض loadModel() بـ "Model already loaded" ⇒ نعيد إنشاء المتحكم.
    if (!_loaded) {
      try {
        if (await _controller!.isModelLoaded()) {
          await _controller!.dispose();
          _controller = llama.LlamaController();
        }
      } catch (_) {
        // تجاهل: المتحكم الجديد سيتعامل مع الحالة
      }
    }

    // 1) فحص الذاكرة الحرة قبل أي تنزيل (A52 بنسخة 6GB حسّاس للضغط).
    onStatus(BootPhase.checking, 0, 'جارٍ فحص ذاكرة الجهاز…');
    final gpu = await _controller!.detectGpu();
    final needBytes =
        (_spec.expectedBytes * 1.35).round() + 128 * 1024 * 1024; // أوزان + KV + buffers
    if (gpu.freeRamBytes > 0 && gpu.freeRamBytes < needBytes) {
      throw StateError(
        'الذاكرة المتاحة غير كافية (${_mb(gpu.freeRamBytes)} MB). '
        'أغلق التطبيقات أو استخدم النموذج الأخف SmolLM2-360M.',
      );
    }

    // 2) التنزيل — يحدث في أول تشغيل فقط.
    onStatus(BootPhase.downloading, 0, 'التحقق من وجود النموذج على الجهاز…');
    final path = await _downloader.ensureModel(
      _spec,
      (int received, int total, String status) {
        onStatus(BootPhase.downloading,
            total == 0 ? 0 : received / total, status);
      },
      cancelToken: cancelToken,
    );
    _modelPath = path;

    // 3) التحميل في الذاكرة (شريط تقدّم من المكتبة نفسها).
    onStatus(BootPhase.loading, 0, 'جارٍ تحميل النموذج في الذاكرة…');
    await _loadSub?.cancel();
    _loadSub = _controller!.loadProgress.listen(
      (double v) => onStatus(BootPhase.loading, v, 'جارٍ تحميل أوزان النموذج…'),
      onError: (Object e) {},
    );

    await _controller!.loadModel(
      modelPath: path,
      threads: DeviceProfile.threads,
      contextSize: DeviceProfile.contextSize,
      gpuLayers: DeviceProfile.gpuLayers,
    );

    _loaded = true;
    onStatus(BootPhase.ready, 1, 'النموذج جاهز — يعمل دون إنترنت');
  }

  /// تفريغ النموذج عند الانتقال للخلفية لتحرير ~500 MB من RAM.
  /// الاستدعاء التالي لـ [ensureReady] يعيد التحميل من الملف المحلي (بلا إنترنت).
  Future<void> release() async {
    await _loadSub?.cancel();
    _loadSub = null;
    try {
      await _controller?.stop();
      await _controller?.dispose();
    } catch (_) {
      // تجاهل أخطاء التفريغ عند إغلاق التطبيق
    }
    _controller = null;
    _loaded = false;
  }

  /// إعادة التحميل الكسولة بعد العودة من الخلفية.
  Future<void> ensureReady(void Function(String text) onStatus) async {
    if (_loaded && _modelPath != null) return;
    if (_modelPath == null || !await File(_modelPath!).exists()) {
      throw StateError('ملف النموذج غير موجود، أعد تشغيل التطبيق.');
    }
    onStatus('جارٍ إعادة تحميل النموذج في الذاكرة…');
    _controller ??= llama.LlamaController();
    await _controller!.loadModel(
      modelPath: _modelPath!,
      threads: DeviceProfile.threads,
      contextSize: DeviceProfile.contextSize,
      gpuLayers: DeviceProfile.gpuLayers,
    );
    _loaded = true;
  }

  /// نسبة استخدام الـ KV cache للعرض في الواجهة (0..100).
  Future<double> contextUsage() async {
    if (!_loaded || _controller == null) return 0;
    try {
      return (await _controller!.getContextInfo()).usagePercentage;
    } catch (_) {
      return 0;
    }
  }

  /// بثّ الرد توكن-بتوكن باستخدام قالب ChatML الخاص بالنموذج.
  Stream<String> streamReply(List<ChatMessage> history) async* {
    if (!_loaded || _controller == null) {
      throw StateError('النموذج غير محمّل؛ استدعِ ensureReady() أولاً.');
    }

    // الطبقة الأصلية تحتفظ بـ KV cache بين الاستدعاءات (g_n_past لا يُصفّر).
    // لذلك نفرّغه قبل كل رسالة ونرسل التاريخ كاملاً ⇒ لا تكرار ولا تجاوز للنافذة.
    await _controller!.clearContext();

    final stream = _controller!.generateChat(
      messages: _toApiMessages(history),
      template: _spec.template,
      maxTokens: DeviceProfile.maxTokens,
      temperature: DeviceProfile.temperature,
      topP: DeviceProfile.topP,
      topK: DeviceProfile.topK,
      repeatPenalty: DeviceProfile.repeatPenalty,
    );

    await for (final String token in stream) {
      // درع إضافي لو تسرب وسم قالب مثل <|im_end|> ضمن البث.
      if (token.contains('<|')) continue;
      yield token;
    }
  }

  Future<void> stopGeneration() async {
    await _controller?.stop();
  }

  List<llama.ChatMessage> _toApiMessages(List<ChatMessage> history) {
    final out = <llama.ChatMessage>[
      llama.ChatMessage(role: 'system', content: DeviceProfile.systemPrompt),
    ];
    final valid = history
        .where((ChatMessage m) => m.text.trim().isNotEmpty)
        .toList(growable: false);
    final keep = DeviceProfile.historyTurns * 2;
    final start = valid.length > keep ? valid.length - keep : 0;
    for (final ChatMessage m in valid.sublist(start)) {
      out.add(llama.ChatMessage(
        role: m.isUser ? 'user' : 'assistant',
        content: m.text.trim(),
      ));
    }
    return out;
  }

  static String _mb(int bytes) => (bytes / 1024 / 1024).toStringAsFixed(0);
}
