/// إعدادات مضبوطة خصيصاً لهاتف Samsung Galaxy A52:
/// Snapdragon 720G (2x Kryo 465 Gold @2.3GHz + 6x Silver @1.8GHz)، ذاكرة 6/8 GB.
///
/// الهدف: أقل حرارة وأقل استهلاك RAM مع سرعة مقبولة (~8-14 توكن/ثانية).
class DeviceProfile {
  const DeviceProfile._();

  /// 4 خيوط فقط. تشغيل 8 خيوط على هذا المعالج يرفع الحرارة ويسبّب throttling
  /// بعد دقيقتين دون مكاسب حقيقية في سرعة التوليد (token generation متسلسل أصلاً).
  static const int threads = 4;

  /// نافذة قصيرة = KV cache صغير.
  /// Qwen2.5-0.5B: 24 طبقة × 14 رأس × 64 بُعد ≈ 84 KB لكل توكن (f16).
  /// 1024 توكن ≈ 86 MB بدل ~172 MB عند 2048.
  static const int contextSize = 1024;

  /// سقف صارم لطول الرد: يحدّد زمن الاستدلال والحرارة لكل رسالة.
  static const int maxTokens = 256;

  /// نحتفظ بآخر 3 أدوار فقط من المحادثة (turn = سؤال + جواب).
  static const int historyTurns = 3;

  /// CPU فقط. المكتبة تُبنى بـ GGML_VULKAN=OFF، و Adreno 618 يزيد الحرارة
  /// دون فائدة تُذكر لهذا الحجم من النموذج.
  static const int gpuLayers = 0;

  static const double temperature = 0.7;
  static const double topP = 0.9;
  static const int topK = 40;
  static const double repeatPenalty = 1.1;

  static const String systemPrompt =
      'You are a helpful, concise assistant running fully offline on a phone. '
      'Reply in the same language as the user. Keep answers short, 2 to 5 sentences.';
}

/// مواصفة نموذج GGUF قابل للتنزيل.
///
/// [expectedBytes] مأخوذ من Hugging Face API ويُستخدم للتحقق من سلامة الملف
/// وتجنّب تحميل ملف ناقص بعد انقطاع الشبكة.
class ModelSpec {
  const ModelSpec({
    required this.id,
    required this.repo,
    required this.file,
    required this.expectedBytes,
    required this.label,
    this.template = 'chatml',
  });

  final String id;
  final String repo;
  final String file;
  final int expectedBytes;
  final String label;

  /// اسم القالب داخل المكتبة: 'chatml' يعمل مع Qwen2.5 / Qwen3 / SmolLM2.
  final String template;

  String get url => 'https://huggingface.co/$repo/resolve/main/$file';
  double get sizeMB => expectedBytes / (1024 * 1024);

  // ---------------------------------------------------------------------------
  // غيّر السطر التالي فقط لتبديل النموذج (ثم احذف ملف .part القديم إن وُجد).
  // ---------------------------------------------------------------------------
  static const ModelSpec active = qwen25Q4KM;

  /// الافتراضي: Qwen2.5-0.5B-Instruct Q4_K_M — 468.6 MiB.
  static const qwen25Q4KM = ModelSpec(
    id: 'qwen2.5-0.5b-instruct-q4_k_m',
    repo: 'Qwen/Qwen2.5-0.5B-Instruct-GGUF',
    file: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
    expectedBytes: 491400032,
    label: 'Qwen2.5 0.5B Instruct · Q4_K_M',
  );

  /// أخفّ وأسرع قليلاً، جودة أقل قليلاً — 408.9 MiB.
  static const qwen25Q40 = ModelSpec(
    id: 'qwen2.5-0.5b-instruct-q4_0',
    repo: 'Qwen/Qwen2.5-0.5B-Instruct-GGUF',
    file: 'qwen2.5-0.5b-instruct-q4_0.gguf',
    expectedBytes: 428730208,
    label: 'Qwen2.5 0.5B Instruct · Q4_0',
  );

  /// أحدث وأصغر من Qwen2.5 — 378.3 MiB. ملاحظة: قد يُخرج وسوم <think>.
  static const qwen3Q4KM = ModelSpec(
    id: 'qwen3-0.6b-q4_k_m',
    repo: 'unsloth/Qwen3-0.6B-GGUF',
    file: 'Qwen3-0.6B-Q4_K_M.gguf',
    expectedBytes: 396705472,
    label: 'Qwen3 0.6B · Q4_K_M',
  );

  /// الأنسب لنسخة 6GB RAM ولتقليل الحرارة — 258.1 MiB فقط.
  static const smolLm2Q4KM = ModelSpec(
    id: 'smollm2-360m-instruct-q4_k_m',
    repo: 'bartowski/SmolLM2-360M-Instruct-GGUF',
    file: 'SmolLM2-360M-Instruct-Q4_K_M.gguf',
    expectedBytes: 270590880,
    label: 'SmolLM2 360M Instruct · Q4_K_M',
  );
}
