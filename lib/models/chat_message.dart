enum ChatRole { user, assistant }

/// رسالة واحدة في شاشة المحادثة.
/// [text] و [isStreaming] قابلان للتعديل لأن الرد يُبنى توكن-بتوكن.
class ChatMessage {
  ChatMessage({
    required this.role,
    this.text = '',
    this.isStreaming = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final ChatRole role;
  final DateTime createdAt;
  String text;
  bool isStreaming;

  bool get isUser => role == ChatRole.user;

  /// إزالة أي وسوم قالب تسربت من النموذج بعد انتهاء التوليد.
  void finalize() {
    text = text.replaceAll(RegExp(r'<\|[^>]*\|>'), '').trim();
    isStreaming = false;
  }
}
