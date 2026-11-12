import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:file_selector/file_selector.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'dart:io';
import '../theme.dart';
import '../models/agent_model.dart';
import '../models/chat_session.dart'; // استدعاء نموذج المحادثة
import '../chat_history_manager.dart'; // استدعاء مدير الحفظ
import '../cloud_provider.dart';
import '../online_api_service.dart';
import '../notification_service.dart';
import '../skill_manager.dart';

class ChatScreen extends StatefulWidget {
  final AgentModel agent;
  final ChatSession? existingSession; // إذا كانت المحادثة موجودة مسبقاً

  const ChatScreen({super.key, required this.agent, this.existingSession});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final OnlineApiService _api = OnlineApiService();
  
  late ChatSession _currentSession;
  bool _isLoading = false;
  CloudProviderConfig? _providerConfig;
  String? _attachedFileContent;
  StreamSubscription? _streamSubscription;

  bool _isDeepAnalysisEnabled = false;
  bool _isWebSearchEnabled = false;
  
  List<Skill> _skills = [];
  Skill? _selectedSkill;

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
      // إنشاء محادثة جديدة
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
    _skills = await SkillManager.loadSkills();
    try {
      setState(() {
        _providerConfig = providers.firstWhere((p) => p.id == widget.agent.providerId);
      });
    } catch (e) {
      setState(() {
        _currentSession.messages.add(ChatMessageData(role: 'ai', text: 'خطأ: مزود الخدمة غير موجود.'));
      });
    }
  }

  void _saveHistory() {
    _currentSession.lastUpdated = DateTime.now();
    ChatHistoryManager.saveSession(_currentSession);
  }

  Future<void> _pickFile() async {
    try {
      const typeGroup = XTypeGroup(label: 'Documents', extensions: ['txt', 'json', 'md', 'csv', 'pdf']);
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      
      if (file != null) {
        String content = await File(file.path).readAsString(); 
        setState(() {
          _attachedFileContent = content;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("تم إرفاق الملف: ${file.name}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("فشل قراءة الملف.")),
      );
    }
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty && _attachedFileContent == null) return;
    if (_providerConfig == null) return;

    String userText = _controller.text.trim();
    String finalPrompt = userText;

    if (_attachedFileContent != null) {
      finalPrompt = "محتوى الملف المرفق:\n$_attachedFileContent\n\nطلب المستخدم:\n$userText";
    }

    setState(() {
      // إذا كانت هذه أول رسالة، نستخدمها كعنوان للمحادثة
      if (_currentSession.messages.isEmpty && userText.isNotEmpty) {
        _currentSession.title = userText.length > 25 ? userText.substring(0, 25) + "..." : userText;
      }
      
      _currentSession.messages.add(ChatMessageData(role: 'user', text: userText.isEmpty ? "تم إرفاق ملف" : userText));
      _currentSession.messages.add(ChatMessageData(role: 'ai', text: '')); 
      _isLoading = true;
      _controller.clear();
      _attachedFileContent = null;
    });
    
    _saveHistory();
    _scrollToBottom();

    String currentResponse = "";
    int aiMessageIndex = _currentSession.messages.length - 1;

    String finalSystemPrompt = widget.agent.systemPrompt;
    if (_selectedSkill != null) {
      finalSystemPrompt += "\n\n[مهارة إضافية - ${_selectedSkill!.name}]:\n${_selectedSkill!.systemPrompt}";
    }
    
    if (_isDeepAnalysisEnabled) {
      finalSystemPrompt += "\n\nقم بتحليل السؤال بعمق، وفكر خطوة بخطوة قبل إعطاء الإجابة النهائية.";
    }

    _streamSubscription = _api.generateStream(
      provider: _providerConfig!.providerType,
      apiKey: _providerConfig!.apiKey,
      baseUrl: _providerConfig!.baseUrl,
      modelName: _providerConfig!.modelName,
      systemPrompt: finalSystemPrompt,
      userPrompt: finalPrompt,
      useTools: _isWebSearchEnabled,
    ).listen(
      (chunk) {
        currentResponse += chunk;
        setState(() {
          _currentSession.messages[aiMessageIndex].text = currentResponse;
        });
        _scrollToBottom();
      },
      onDone: () {
        setState(() => _isLoading = false);
        _saveHistory(); // حفظ المحادثة بعد اكتمال الرد
        NotificationService.showNotification(
          "اكتمل الرد من ${widget.agent.name}",
          "يمكنك الآن قراءة الإجابة.",
        );
      },
      onError: (e) {
        setState(() {
          _currentSession.messages[aiMessageIndex].text = "❌ خطأ: $e";
          _isLoading = false;
        });
        _saveHistory();
      },
      cancelOnError: true,
    );
  }

  void _stopGeneration() {
    _streamSubscription?.cancel();
    setState(() => _isLoading = false);
    setState(() {
      _currentSession.messages.last.text += "\n\n[تم إيقاف التوليد]";
    });
    _saveHistory();
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
                    subtitle: const Text("جعل الموديل يفكر خطوة بخطوة", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    value: _isDeepAnalysisEnabled,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setStateBottomSheet(() => _isDeepAnalysisEnabled = val);
                      setState(() => _isDeepAnalysisEnabled = val);
                    },
                  ),
                  SwitchListTile(
                    title: const Text("تفعيل الأدوات (Tools / MCP)", style: TextStyle(color: Colors.white)),
                    subtitle: const Text("السماح للموديل بالبحث وحفظ الملفات", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
            Text(_currentSession.title, style: const TextStyle(fontSize: 18)),
            Text(widget.agent.modelName, style: const TextStyle(fontSize: 12, color: AppColors.success)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _currentSession.messages.isEmpty 
              ? _buildEmptyState() 
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _currentSession.messages.length,
                  itemBuilder: (context, index) {
                    final msg = _currentSession.messages[index];
                    bool isUser = msg.role == 'user';
                    return _buildMessageBubble(msg.text, isUser);
                  },
                ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome, size: 60, color: AppColors.primary),
          const SizedBox(height: 20),
          const Text("كيف يمكنني مساعدتك اليوم؟", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
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
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file, color: AppColors.textSecondary),
                onPressed: _pickFile,
              ),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: AppColors.cardBackground,
                    builder: (context) => ListView(
                      shrinkWrap: true,
                      children: [
                        const ListTile(title: Text("اختر مهارة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        ListTile(
                          title: const Text("بدون مهارة", style: TextStyle(color: Colors.grey)),
                          onTap: () { setState(() => _selectedSkill = null); Navigator.pop(context); },
                        ),
                        ..._skills.map((skill) => ListTile(
                          leading: const Icon(Icons.extension, color: AppColors.primary),
                          title: Text(skill.name, style: const TextStyle(color: Colors.white)),
                          onTap: () { setState(() => _selectedSkill = skill); Navigator.pop(context); },
                        )).toList(),
                      ],
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: _selectedSkill != null ? AppColors.primary : Colors.white12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.extension, size: 14, color: _selectedSkill != null ? AppColors.primary : AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(_selectedSkill?.name ?? "مهارة", style: TextStyle(color: _selectedSkill != null ? Colors.white : AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.tune, color: AppColors.textSecondary),
                onPressed: _showSettingsDialog,
              ),
              const Spacer(),
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(_isLoading ? Icons.stop : Icons.arrow_upward, color: Colors.white, size: 20),
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