import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import '../theme.dart';
import '../models/agent_model.dart';
import '../cloud_provider.dart';
import '../online_api_service.dart';

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
  
  List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  CloudProviderConfig? _providerConfig;
  String? _attachedFileContent;

  @override
  void initState() {
    super.initState();
    _loadProviderConfig();
  }

  Future<void> _loadProviderConfig() async {
    final providers = await CloudConfigManager.loadProviders();
    if (providers.isNotEmpty) {
      setState(() {
        _providerConfig = providers.first; // نستخدم أول مزود تم إضافته
      });
    } else {
      setState(() {
        _messages.add({'role': 'ai', 'text': 'يرجى إضافة مزود خدمة (API Key) من صفحة الإعدادات أولاً لتتمكن من الدردشة.'});
      });
    }
  }

  // دالة رفع الملفات (مثل ملفات المهارات أو النصوص)
  Future<void> _pickFile() async {
    try {
      const typeGroup = XTypeGroup(label: 'Documents', extensions: ['txt', 'json', 'md', 'csv']);
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
    
    // إذا كان هناك ملف مرفق، نمرره مع النص
    String finalPrompt = userText;
    if (_attachedFileContent != null) {
      finalPrompt = "محتوى الملف المرفق:\n$_attachedFileContent\n\nطلب المستخدم:\n$userText";
    }

    setState(() {
      _messages.add({'role': 'user', 'text': userText.isEmpty ? "تم إرفاق ملف" : userText});
      _messages.add({'role': 'ai', 'text': ''}); // فقاعة فارغة للرد
      _isLoading = true;
      _controller.clear();
      _attachedFileContent = null;
    });
    
    _scrollToBottom();

    String currentResponse = "";
    int aiMessageIndex = _messages.length - 1;

    try {
      await for (final chunk in _api.generateStream(
        provider: _providerConfig!.providerType,
        apiKey: _providerConfig!.apiKey,
        baseUrl: _providerConfig!.baseUrl,
        modelName: _providerConfig!.modelName,
        systemPrompt: "أنت ${widget.agent.name}. ${widget.agent.description}. أجب باللغة العربية.",
        userPrompt: finalPrompt,
      )) {
        currentResponse += chunk;
        setState(() {
          _messages[aiMessageIndex]['text'] = currentResponse;
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _messages[aiMessageIndex]['text'] = "خطأ: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.agent.name, style: const TextStyle(fontSize: 18)),
            Text(widget.agent.model, style: const TextStyle(fontSize: 12, color: AppColors.success)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
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

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
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
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.upload_file, color: AppColors.textSecondary),
            onPressed: _pickFile,
            tooltip: "رفع ملف",
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "اكتب رسالتك...",
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.primary,
            child: _isLoading 
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _sendMessage,
                ),
          ),
        ],
      ),
    );
  }
}