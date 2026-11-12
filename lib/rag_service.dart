class RagService {
  // 1. دالة تقسيم النص الطويل إلى أجزاء (Chunks)
  List<String> splitIntoChunks(String text, {int chunkSize = 1500, int overlap = 200}) {
    List<String> chunks = [];
    int start = 0;
    
    while (start < text.length) {
      int end = start + chunkSize;
      if (end > text.length) {
        end = text.length;
      }
      
      // محاولة القطع عند مسافة أو نقطة لتجنب قطع الكلمات
      if (end < text.length) {
        int lastSpace = text.lastIndexOf(' ', end);
        if (lastSpace > start + (chunkSize ~/ 2)) {
          end = lastSpace;
        }
      }
      
      chunks.add(text.substring(start, end).trim());
      
      // الانتقال للجزء التالي مع ترك تداخل (Overlap) بسيط للحفاظ على السياق
      start = end - overlap;
      if (start < 0) start = 0;
      if (start >= text.length) break;
    }
    
    return chunks;
  }

  // 2. دالة البحث عن الأجزاء الأكثر صلة بسؤال المستخدم
  List<String> getRelevantChunks(String query, List<String> chunks, {int maxChunks = 3}) {
    // تنظيف السؤال وتقسيمه لكلمات
    List<String> queryWords = query.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), '') // إزالة الرموز والحفاظ على العربية
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2) // تجاهل الكلمات القصيرة جداً (مثل: من، في)
        .toList();

    if (queryWords.isEmpty) return chunks.take(maxChunks).toList();

    Map<int, int> chunkScores = {};

    // حساب النقاط لكل جزء بناءً على عدد الكلمات المتطابقة
    for (int i = 0; i < chunks.length; i++) {
      int score = 0;
      String chunkLower = chunks[i].toLowerCase();
      
      for (String word in queryWords) {
        if (chunkLower.contains(word)) {
          score++;
        }
      }
      chunkScores[i] = score;
    }

    // ترتيب الأجزاء حسب النقاط من الأعلى للأقل
    var sortedEntries = chunkScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<String> result = [];
    for (var entry in sortedEntries) {
      if (entry.value > 0 && result.length < maxChunks) {
        result.add(chunks[entry.key]);
      }
    }

    // إذا لم نجد أي تطابق، نرجع أول 3 أجزاء كاحتياط
    if (result.isEmpty) {
      return chunks.take(maxChunks).toList();
    }

    return result;
  }
}