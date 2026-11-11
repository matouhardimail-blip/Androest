import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:async';
import 'dart:io';
import '../theme.dart';
import '../models/agent_model.dart';
import '../cloud_provider.dart';
import '../online_api_service.dart';
import '../notification_service.dart';
import '../web_search.dart'; // استدعاء أداة البحث

class ChatScreen extends StatefulWidget {
  final AgentModel agent;
  const ChatScreen({super.key, required this.agent});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final OnlineApiService _api = OnlineApiService();
  final WebSearch _webSearch = WebSearch();
  
  List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  CloudProviderConfig? _providerConfig;
  String? _attachedFileContent;
  StreamSubscription? _streamSubscription;

  // متغيرات الإعدادات الجديدة
  bool _isDeepAnalysisEnabled = false;
  bool _isWebSearchEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadProviderConfig();
  }

  Future<void> _loadProviderConfig() async {
    final providers = await CloudConfigManager.loadProviders();
    try {
      setState(() {
        _providerConfig = providers.firstWhere((p) => p.id == widget.agent.providerId);
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'ai', 'text': 'خطأ: مزود الخدمة المرتبط بهذا الوكيل غير موجود. قد يكون تم حذفه من الإعدادات.'});
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      const typeGroup = XTypeGroup(label: 'Documents', extensions: ['txt', 'json', 'md', 'csv', 'pdf']);
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      
      if (file != null) {
        String content = await File(file.path).readAsString(); // ملاحظة: لقراءة PDF نحتاج مكتبة إضافية، هنا يقرأ النصوص فقط
        setState(() {
          _attachedFileContent = content;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("تم إرفاق الملف: ${file.name}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("فشل قراءة الملف. تأكد من أنه ملف نصي.")),
      );
    }
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty && _attachedFileContent == null) return;
    if (_providerConfig == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لم يتم تكوين API Key.")));
      return;
    }

    String userText = _controller.text.trim();
    String finalPrompt = userText;

    // 1. التعامل مع الملف المرفق
    if (_attachedFileContent != null) {
      finalPrompt = "محتوى الملف المرفق:\n$_attachedFileContent\n\nطلب المستخدم:\n$userText";
    }

    setState(() {
      _messages.add({'role': 'user', 'text': userText.isEmpty ? "تم إرفاق ملف" : userText});
      _messages.add({'role': 'ai', 'text': ''}); 
      _isLoading = true;
      _controller.clear();
      _attachedFileContent = null;
    });
    
    _scrollToBottom();

    String currentResponse = "";
    int aiMessageIndex = _messages.length - 1;

    // 2. تنفيذ البحث في الويب إذا كان مفعلاً
    if (_isWebSearchEnabled) {
      setState(() {
        _messages[aiMessageIndex]['text'] = "🔍 جاري البحث في الإنترنت...\n";
      });
      String searchResults = await _webSearch.search(userText);
      finalPrompt = "نتائج البحث في الإنترنت:\n$searchResults\n\nسؤال المستخدم:\n$userText\n\nأجب بناءً على هذه النتائج.";
    }

    // 3. إضافة تعليمات التحليل العميق
    String finalSystemPrompt = widget.agent.systemPrompt;
    if (_isDeepAnalysisEnabled) {
      finalSystemPrompt += "\n\nقم بتحليل السؤال بعمق، وفكر خطوة بخطوة قبل إعطاء الإجابة النهائية.";
    }

    if (_isWebSearchEnabled) {
      setState(() {
        _messages[aiMessageIndex]['text'] = ""; // تفريغ رسالة البحث لبدء كتابة الرد
      });
    }

    _streamSubscription = _api.generateStream(
      provider: _providerConfig!.providerType,
      apiKey: _providerConfig!.apiKey,
      baseUrl: _providerConfig!.baseUrl,
      modelName: _providerConfig!.modelName,
      systemPrompt: finalSystemPrompt,
      userPrompt: finalPrompt,
    ).listen(
      (chunk) {
        currentResponse += chunk;
        setState(() {
          _messages[aiMessageIndex]['text'] = currentResponse;
        });
        _scrollToBottom();
      },
      onDone: () {
        setState(() => _isLoading = false);
        NotificationService.showNotification(
          "اكتمل الرد من ${widget.agent.name}",
          "يمكنك الآن قراءة الإجابة.",
        );
      },
      onError: (e) {
        setState(() {
          _messages[aiMessageIndex]['text'] = "❌ خطأ: $e";
          _isLoading = false;
        });
      },
      cancelOnError: true,
    );
  }

  void _stopGeneration() {
    _streamSubscription?.cancel();
    setState(() => _isLoading = false);
    setState(() {
      _messages.last['text'] = _messages.last['text']! + "\n\n[تم إيقاف التوليد بواسطة المستخدم]";
    });
  }

  void _clearChat() {
    setState(() => _messages.clear());
  }

  Future<void> _archiveChat() async {
    _clearChat();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم أرشفة المحادثة (محلياً).")),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // نافذة الإعدادات المنبثقة (Deep Analysis & Web Search)
  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateBottomSheet) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("خيارات متقدمة", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  SwitchListTile(
                    title: const Text("تحليل عميق (Deep Analysis)", style: TextStyle(color: Colors.white)),
                    subtitle: const Text("جعل الموديل يفكر خطوة بخطوة قبل الرد", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    value: _isDeepAnalysisEnabled,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setStateBottomSheet(() => _isDeepAnalysisEnabled = val);
                      setState(() => _isDeepAnalysisEnabled = val);
                    },
                  ),
                  SwitchListTile(
                    title: const Text("البحث في الويب (Web Search)", style: TextStyle(color: Colors.white)),
                    subtitle: const Text("جلب معلومات حديثة من الإنترنت", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    value: _isWebSearchEnabled,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setStateBottomSheet(() => _isWebSearchEnabled = val);
                      setState(() => _isWebSearchEnabled = val);
                    },
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.agent.name, style: const TextStyle(fontSize: 18)),
            Text(widget.agent.modelName, style: const TextStyle(fontSize: 12, color: AppColors.success)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'clear') _clearChat();
              if (value == 'archive') _archiveChat();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                    SizedBox(width: 8),
                    Text('مسح المحادثة', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text('أرشفة المحادثة', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty 
              ? _buildEmptyState() // شاشة الاقتراحات إذا كانت المحادثة فارغة
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    bool isUser = msg['role'] == 'user';
                    return _buildMessageBubble(msg['text']!, isUser);
                  },
                ),
          ),
          if (_attachedFileContent != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.cardBackground,
              child: Row(
                children: [
                  const Icon(Icons.attach_file, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(child: Text("ملف مرفق جاهز للإرسال", style: TextStyle(color: Colors.white70))),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.danger, size: 20),
                    onPressed: () => setState(() => _attachedFileContent = null),
                  )
                ],
              ),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  // شاشة البداية (الاقتراحات)
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, size: 60, color: AppColors.primary),
            const SizedBox(height: 20),
            const Text(
              "كيف يمكنني مساعدتك اليوم؟",
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip(Icons.image, "وصف صورة", "قم بوصف هذه الصورة"),
                _buildSuggestionChip(Icons.picture_as_pdf, "تلخيص PDF", "قم بتلخيص هذا المستند"),
                _buildSuggestionChip(Icons.code, "شرح كود", "قم بشرح هذا الكود البرمجي"),
                _buildSuggestionChip(Icons.lightbulb, "أفكار إبداعية", "أعطني أفكاراً إبداعية لمشروع"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(IconData icon, String title, String prompt) {
    return InkWell(
      onTap: () {
        setState(() {
          _controller.text = prompt;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 0 : 16),
            bottomRight: Radius.circular(isUser ? 16 : 0),
          ),
        ),
        child: isUser 
          ? Text(text, style: const TextStyle(color: Colors.white, fontSize: 16))
          : MarkdownBody(
              data: text.isEmpty ? "..." : text,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: Colors.white, fontSize: 16),
                code: const TextStyle(backgroundColor: Colors.black45, color: Colors.greenAccent),
              ),
            ),
      ),
    );
  }

  // حقل الإدخال الجديد (مطابق للصورة)
  Widget _buildInputArea() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // الجزء العلوي: حقل النص
          TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            maxLines: null,
            decoration: const InputDecoration(
              hintText: "اسألني عن أي شيء...",
              hintStyle: TextStyle(color: AppColors.textSecondary),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
          
          // الجزء السفلي: الأزرار والأدوات
          Row(
            children: [
              // زر رفع الملف
              IconButton(
                icon: const Icon(Icons.attach_file, color: AppColors.textSecondary),
                onPressed: _pickFile,
                tooltip: "رفع ملف",
              ),
              
              // اسم الوكيل (بدلاً من قائمة اختيار الموديل في الصورة)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(widget.agent.icon, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(widget.agent.name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // زر الإعدادات المتقدمة
              IconButton(
                icon: const Icon(Icons.tune, color: AppColors.textSecondary),
                onPressed: _showSettingsDialog,
                tooltip: "إعدادات متقدمة",
              ),

              const Spacer(),

              // زر المايك (تحويل الصوت لنص - قيد التطوير)
              IconButton(
                icon: const Icon(Icons.mic, color: AppColors.textSecondary),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ميزة الإدخال الصوتي قيد التطوير...")));
                },
              ),

              // زر الإرسال / الإيقاف
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    _isLoading ? Icons.stop : Icons.arrow_upward, 
                    color: Colors.white, 
                    size: 20
                  ),
                  onPressed: _isLoading ? _stopGeneration : _sendMessage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}