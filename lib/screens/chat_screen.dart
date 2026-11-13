import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../theme.dart';
import '../models/agent_model.dart';
import '../models/chat_session.dart'; 
import '../chat_history_manager.dart'; 
import '../cloud_provider.dart';
import '../online_api_service.dart';
import '../local_llama_service.dart';
import '../model_manager.dart';
import '../notification_service.dart';
import '../skill_manager.dart';
import '../rag_service.dart';
import '../pdf_service.dart';

class ChatScreen extends StatefulWidget {
  final AgentModel agent;
  final ChatSession? existingSession;

  const ChatScreen({super.key, required this.agent, this.existingSession});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final OnlineApiService _api = OnlineApiService();
  final LocalLlamaService _localLlama = LocalLlamaService();
  final RagService _rag = RagService();
  final ModelManager _modelManager = ModelManager();
  final ImagePicker _picker = ImagePicker();
  
  late ChatSession _currentSession;
  bool _isLoading = false;
  bool _isSummarizing = false;
  CloudProviderConfig? _providerConfig;
  
  String? _attachedFileContent;
  List<String> _attachedFileChunks = [];
  File? _attachedImage; 
  
  StreamSubscription? _streamSubscription;

  bool _isDeepAnalysisEnabled = false;
  bool _isWebSearchEnabled = false;
  
  List<Skill> _allSkills = [];

  @override
  void initState() {
    super.initState();
    _initSession();
    _loadData();
  }

  void _initSession() {
    if (widget.existingSession != null) {
      _currentSession = widget.existingSession!;
    } else {
      _currentSession = ChatSession(
        id: const Uuid().v4(),
        title: "محادثة جديدة",
        agentId: widget.agent.id,
        agentName: widget.agent.name,
        messages: [],
        lastUpdated: DateTime.now(),
      );
    }
  }

  Future<void> _loadData() async {
    final providers = await CloudConfigManager.loadProviders();
    _allSkills = await SkillManager.loadSkills();
    
    try {
      final provider = providers.firstWhere((p) => p.id == widget.agent.providerId);
      setState(() { _providerConfig = provider; });

      if (provider.providerType == 'local') {
        File? modelFile = await _modelManager.getModelFile();
        if (modelFile != null) await _localLlama.loadModel(modelFile.path);
        else setState(() { _currentSession.messages.add(ChatMessageData(role: 'ai', text: '⚠️ الموديل المحلي غير محمل.')); });
      }
    } catch (e) {
      setState(() { _currentSession.messages.add(ChatMessageData(role: 'ai', text: 'خطأ: مزود الخدمة غير موجود.')); });
    }
  }

  void _saveHistory() {
    _currentSession.lastUpdated = DateTime.now();
    ChatHistoryManager.saveSession(_currentSession);
  }

  void _regenerateResponse() {
    if (_currentSession.messages.isEmpty || _isLoading) return;
    if (_currentSession.messages.last.role == 'ai') _currentSession.messages.removeLast();
    String lastUserPrompt = "";
    for (int i = _currentSession.messages.length - 1; i >= 0; i--) {
      if (_currentSession.messages[i].role == 'user') { lastUserPrompt = _currentSession.messages[i].text; break; }
    }
    if (lastUserPrompt.isNotEmpty) {
      setState(() { _currentSession.messages.add(ChatMessageData(role: 'ai', text: '...')); _isLoading = true; });
      _executeAIGeneration(lastUserPrompt);
    }
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty && _attachedFileContent == null && _attachedImage == null) return;
    if (_providerConfig == null) return;

    String userText = _controller.text.trim();
    String finalPrompt = userText;

    if (_attachedFileContent != null) {
      if (_attachedFileChunks.isNotEmpty) {
        List<String> relevantChunks = _rag.getRelevantChunks(userText, _attachedFileChunks);
        finalPrompt = "إليك الأجزاء ذات الصلة:\n\n${relevantChunks.join('\n\n')}\n\nسؤال المستخدم:\n$userText";
      } else {
        finalPrompt = "محتوى الملف:\n$_attachedFileContent\n\nطلب المستخدم:\n$userText";
      }
    }

    String? imageBase64;
    if (_attachedImage != null) imageBase64 = base64Encode(await _attachedImage!.readAsBytes());

    setState(() {
      if (_currentSession.messages.isEmpty && userText.isNotEmpty) _currentSession.title = userText.length > 25 ? userText.substring(0, 25) + "..." : userText;
      _currentSession.messages.add(ChatMessageData(role: 'user', text: userText.isEmpty ? "تم إرفاق صورة/ملف" : userText));
      _currentSession.messages.add(ChatMessageData(role: 'ai', text: '')); 
      _isLoading = true;
      _controller.clear(); _attachedFileContent = null; _attachedFileChunks = []; _attachedImage = null; 
    });
    
    _saveHistory();
    _scrollToBottom();
    _executeAIGeneration(finalPrompt, imageBase64: imageBase64);
  }

  void _executeAIGeneration(String finalPrompt, {String? imageBase64}) {
    List<Map<String, String>> chatHistory = _currentSession.messages.map((m) => {'role': m.role, 'text': m.text}).toList();
    String currentResponse = "";
    int aiMessageIndex = _currentSession.messages.length - 1;

    String finalSystemPrompt = widget.agent.systemPrompt;
    List<String> agentSkills = _allSkills.where((s) => widget.agent.skillIds.contains(s.id)).map((s) => s.systemPrompt).toList();
    if (agentSkills.isNotEmpty) finalSystemPrompt += "\n\n[المهارات]:\n" + agentSkills.join('\n\n');
    if (_isDeepAnalysisEnabled) finalSystemPrompt += "\n\nقم بتحليل السؤال بعمق.";

    if (_providerConfig!.providerType == 'local') {
      _streamSubscription = _localLlama.generateStream(systemPrompt: finalSystemPrompt, userPrompt: finalPrompt).listen(
        (chunk) { currentResponse += chunk; setState(() { _currentSession.messages[aiMessageIndex].text = currentResponse; }); _scrollToBottom(); },
        onDone: () { setState(() => _isLoading = false); _saveHistory(); },
        onError: (e) { setState(() { _currentSession.messages[aiMessageIndex].text = "❌ خطأ: $e"; _isLoading = false; }); },
      );
    } else {
      _streamSubscription = _api.generateStream(
        provider: _providerConfig!.providerType, apiKey: _providerConfig!.apiKey, baseUrl: _providerConfig!.baseUrl, modelName: _providerConfig!.modelName,
        systemPrompt: finalSystemPrompt, userPrompt: finalPrompt, chatHistory: chatHistory, useTools: _isWebSearchEnabled, imageBase64: imageBase64,
      ).listen(
        (chunk) { currentResponse += chunk; setState(() { _currentSession.messages[aiMessageIndex].text = currentResponse; }); _scrollToBottom(); },
        onDone: () { setState(() => _isLoading = false); _saveHistory(); },
        onError: (e) { setState(() { _currentSession.messages[aiMessageIndex].text = "❌ خطأ: $e"; _isLoading = false; }); _saveHistory(); },
        cancelOnError: true,
      );
    }
  }

  void _stopGeneration() {
    _streamSubscription?.cancel();
    setState(() => _isLoading = false);
    setState(() { _currentSession.messages.last.text += "\n\n[تم إيقاف التوليد]"; });
    _saveHistory();
  }

  void _summarizeChat() async {
    if (_currentSession.messages.length < 3) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("المحادثة قصيرة جداً."))); return; }
    if (_providerConfig?.providerType == 'local' || _providerConfig == null) return;

    setState(() => _isSummarizing = true);
    List<Map<String, String>> chatHistory = _currentSession.messages.map((m) => {'role': m.role, 'text': m.text}).toList();
    String summary = await _api.summarizeChat(provider: _providerConfig!.providerType, apiKey: _providerConfig!.apiKey, baseUrl: _providerConfig!.baseUrl, modelName: _providerConfig!.modelName, chatHistory: chatHistory);
    setState(() {
      _currentSession.messages.clear();
      _currentSession.messages.add(ChatMessageData(role: 'ai', text: "📌 **ملخص المحادثة:**\n\n$summary\n\n(تم مسح الرسائل القديمة)."));
      _isSummarizing = false;
    });
    _saveHistory();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context, backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateBottomSheet) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("خيارات متقدمة", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context))]),
                  const Divider(color: Colors.white24),
                  SwitchListTile(title: const Text("تحليل عميق", style: TextStyle(color: Colors.white)), value: _isDeepAnalysisEnabled, activeColor: AppColors.primary, onChanged: (val) { setStateBottomSheet(() => _isDeepAnalysisEnabled = val); setState(() => _isDeepAnalysisEnabled = val); }),
                  SwitchListTile(title: const Text("تفعيل الأدوات (Tools)", style: TextStyle(color: Colors.white)), value: _isWebSearchEnabled, activeColor: AppColors.primary, onChanged: (val) { setStateBottomSheet(() => _isWebSearchEnabled = val); setState(() => _isWebSearchEnabled = val); }),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _pickFile() async {
    try {
      const typeGroup = XTypeGroup(label: 'Documents', extensions: ['txt', 'json', 'md', 'csv', 'pdf']);
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file != null) {
        String content = file.path.toLowerCase().endsWith('.pdf') ? await PdfService.extractText(File(file.path)) : await File(file.path).readAsString();
        if (content.length > 3000) _attachedFileChunks = _rag.splitIntoChunks(content); else _attachedFileChunks = [];
        setState(() { _attachedFileContent = content; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم إرفاق: ${file.name}")));
      }
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("فشل: $e"))); }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) setState(() { _attachedImage = File(image.path); });
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("فشل: $e"))); }
  }

  @override
  void dispose() {
    _controller.dispose(); _scrollController.dispose(); _streamSubscription?.cancel();
    if (_providerConfig?.providerType == 'local') _localLlama.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(_currentSession.title, style: const TextStyle(fontSize: 18)),
            Text(_providerConfig?.providerType == 'local' ? "وضع الأوفلاين" : widget.agent.modelName, style: TextStyle(fontSize: 12, color: _providerConfig?.providerType == 'local' ? AppColors.success : AppColors.accentBlue)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _isLoading ? null : _regenerateResponse, tooltip: "إعادة توليد"),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onSelected: (value) { if (value == 'summarize') _summarizeChat(); if (value == 'clear') { setState(() => _currentSession.messages.clear()); _saveHistory(); } },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'summarize', child: Row(children: [Icon(Icons.compress_rounded, color: AppColors.primary, size: 20), SizedBox(width: 8), Text('تلخيص', style: TextStyle(color: Colors.white))])),
              const PopupMenuItem<String>(value: 'clear', child: Row(children: [Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20), SizedBox(width: 8), Text('مسح', style: TextStyle(color: Colors.white))])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSummarizing) const LinearProgressIndicator(color: AppColors.primary),
          Expanded(
            child: _currentSession.messages.isEmpty 
              ? _buildEmptyState() 
              : ListView.builder(
                  controller: _scrollController, padding: const EdgeInsets.all(16),
                  itemCount: _currentSession.messages.length,
                  itemBuilder: (context, index) {
                    final msg = _currentSession.messages[index];
                    return _buildMessageBubble(msg.text, msg.role == 'user');
                  },
                ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.auto_awesome_rounded, size: 60, color: AppColors.primary), SizedBox(height: 20), Text("كيف يمكنني مساعدتك اليوم؟", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))]));
  }

  // تحسين فقاعة الرسالة وإضافة الصور الرمزية
  Widget _buildMessageBubble(String text, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // صورة الوكيل (على اليسار)
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.cardBackground, shape: BoxShape.circle, border: Border.all(color: Colors.white12)),
              child: Icon(widget.agent.icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 8),
          ],
          
          // نص الرسالة
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.cardBackground,
                border: isUser ? null : Border.all(color: Colors.white.withOpacity(0.05)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
              ),
              child: isUser 
                ? Text(text, style: const TextStyle(color: Colors.white, fontSize: 16))
                : MarkdownBody(
                    data: text.isEmpty ? "..." : text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                      code: const TextStyle(backgroundColor: Colors.black45, color: Colors.greenAccent),
                    ),
                    imageBuilder: (uri, title, alt) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(uri.toString(), fit: BoxFit.cover)),
                    ),
                  ),
            ),
          ),

          // صورة المستخدم (على اليمين)
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.cardBackground, shape: BoxShape.circle, border: Border.all(color: Colors.white12)),
              child: const Icon(Icons.person_rounded, color: Colors.white70, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  // تحسين حقل الإدخال ليكون عائماً وأنيقاً
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_attachedImage != null)
            Container(
              padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_attachedImage!, width: 50, height: 50, fit: BoxFit.cover)),
                const SizedBox(width: 10),
                const Expanded(child: Text("صورة جاهزة", style: TextStyle(color: Colors.white70))),
                IconButton(icon: const Icon(Icons.close_rounded, color: AppColors.danger, size: 20), onPressed: () => setState(() => _attachedImage = null))
              ]),
            ),
          
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.textSecondary),
                  onPressed: _pickImage,
                  tooltip: "صورة",
                ),
                IconButton(
                  icon: const Icon(Icons.attach_file_rounded, color: AppColors.textSecondary),
                  onPressed: _pickFile,
                  tooltip: "ملف",
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: "اكتب رسالتك هنا...",
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.tune_rounded, color: AppColors.textSecondary),
                  onPressed: _showSettingsDialog,
                  tooltip: "إعدادات",
                ),
                Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: IconButton(
                      icon: Icon(_isLoading ? Icons.stop_rounded : Icons.arrow_upward_rounded, color: Colors.white, size: 22),
                      onPressed: _isLoading ? _stopGeneration : _sendMessage,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}