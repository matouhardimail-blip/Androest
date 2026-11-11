import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:async';
import 'dart:io';
import 'package:markdown/markdown.dart' as md;
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:uuid/uuid.dart';

import 'model_manager.dart';
import 'code_bubble.dart';
import 'online_api_service.dart';
import 'chat_session.dart';
import 'cloud_provider.dart';
import 'web_search.dart';
import 'trading_agent.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi-Agent System',
      theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
      home: const SplashScreen(),
    );
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(BuildContext context, md.Element element, TextStyle? preferredStyle, TextStyle? blockStyle) {
    return CodeBubble(code: element.textContent);
  }
}

// ==========================================
// 1. شاشة البداية
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ModelManager _modelManager = ModelManager();
  String _status = "جاري التحقق من الموديل...";
  
  @override
  void initState() {
    super.initState();
    _checkState();
  }

  Future<void> _checkState() async {
    File? modelFile = await _modelManager.getModelFile();
    String path = modelFile?.path ?? "";
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ChatScreen(modelPath: path)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(_status)));
  }
}

// ==========================================
// 2. شاشة إدارة المزودين (Providers)
// ==========================================
class ProviderManagerScreen extends StatefulWidget {
  @override
  State<ProviderManagerScreen> createState() => _ProviderManagerScreenState();
}

class _ProviderManagerScreenState extends State<ProviderManagerScreen> {
  List<CloudProviderConfig> _providers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final providers = await CloudConfigManager.loadProviders();
    setState(() => _providers = providers);
  }

  void _addProvider() {
    showDialog(
      context: context,
      builder: (context) {
        String name = "";
        String type = "openai";
        String key = "";
        String baseUrl = "https://api.openai.com/v1";
        String model = "gpt-4o";
        
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("إضافة مزود خدمة"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(decoration: const InputDecoration(labelText: "اسم الوكيل (مثال: GPT-4)"), onChanged: (v) => name = v),
                    DropdownButtonFormField<String>(
                      value: type,
                      items: const [
                        DropdownMenuItem(value: "openai", child: Text("OpenAI (أو متوافق)")),
                        DropdownMenuItem(value: "anthropic", child: Text("Anthropic (Claude)")),
                      ],
                      onChanged: (v) {
                        setStateDialog(() {
                          type = v!;
                          if (type == "anthropic") {
                            baseUrl = "https://api.anthropic.com";
                          } else {
                            baseUrl = "https://api.openai.com/v1";
                          }
                        });
                      },
                      decoration: const InputDecoration(labelText: "نوع المزود"),
                    ),
                    TextField(decoration: const InputDecoration(labelText: "API Key"), onChanged: (v) => key = v),
                    TextField(decoration: const InputDecoration(labelText: "Base URL"), controller: TextEditingController(text: baseUrl), onChanged: (v) => baseUrl = v),
                    TextField(decoration: const InputDecoration(labelText: "Model Name"), controller: TextEditingController(text: model), onChanged: (v) => model = v),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
                ElevatedButton(
                  onPressed: () async {
                    if (name.isNotEmpty && key.isNotEmpty) {
                      _providers.add(CloudProviderConfig(
                        id: const Uuid().v4(),
                        name: name,
                        providerType: type,
                        apiKey: key,
                        baseUrl: baseUrl,
                        modelName: model,
                      ));
                      await CloudConfigManager.saveProviders(_providers);
                      _load();
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text("إضافة"),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إدارة مزودي الخدمة")),
      floatingActionButton: FloatingActionButton(onPressed: _addProvider, child: const Icon(Icons.add)),
      body: ListView.builder(
        itemCount: _providers.length,
        itemBuilder: (context, index) {
          final p = _providers[index];
          return ListTile(
            title: Text(p.name),
            subtitle: Text("${p.providerType} - ${p.modelName}"),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                _providers.removeAt(index);
                await CloudConfigManager.saveProviders(_providers);
                _load();
              },
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// 3. شاشة الدردشة
// ==========================================
class ChatScreen extends StatefulWidget {
  final String modelPath;
  const ChatScreen({super.key, required this.modelPath});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  List<ChatSession> _sessions = [];
  ChatSession? _currentSession;
  
  bool _isLoading = false;
  bool _isLocalReady = false;
  
  final LlamaController _llama = LlamaController();
  final OnlineApiService _api = OnlineApiService();
  
  List<CloudProviderConfig> _cloudProviders = [];

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    if (widget.modelPath.isNotEmpty) {
      try {
        await _llama.loadModel(modelPath: widget.modelPath, contextSize: 2048);
        _isLocalReady = true;
      } catch (e) {}
    }
    
    _cloudProviders = await CloudConfigManager.loadProviders();
    _sessions = await ChatHistoryManager.loadSessions();

    setState(() {
      if (_sessions.isEmpty) {
        _sessions.add(ChatSession(id: const Uuid().v4(), title: "محادثة جديدة", messages: [], lastUpdated: DateTime.now()));
      }
      _currentSession = _sessions.last;
    });
  }

  void _saveCurrentSession() {
    if (_currentSession != null) {
      _currentSession!.lastUpdated = DateTime.now();
      ChatHistoryManager.saveSessions(_sessions);
    }
  }

  // دالة التنسيق بين أي وكيلين يختارهما المستخدم
  void _showCoordinationDialog() {
    if (_cloudProviders.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تحتاج إلى إضافة وكيلين على الأقل من الإعدادات.")));
      return;
    }

    CloudProviderConfig agent1 = _cloudProviders[0];
    CloudProviderConfig agent2 = _cloudProviders[1];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("تنسيق تبادلي"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("اختر الوكيل الأول (الباحث):"),
                  DropdownButton<CloudProviderConfig>(
                    isExpanded: true,
                    value: agent1,
                    items: _cloudProviders.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                    onChanged: (v) => setStateDialog(() => agent1 = v!),
                  ),
                  const SizedBox(height: 15),
                  const Text("اختر الوكيل الثاني (المراجع):"),
                  DropdownButton<CloudProviderConfig>(
                    isExpanded: true,
                    value: agent2,
                    items: _cloudProviders.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                    onChanged: (v) => setStateDialog(() => agent2 = v!),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _runCrossCoordination(agent1, agent2);
                  },
                  child: const Text("تشغيل"),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _runCrossCoordination(CloudProviderConfig agent1, CloudProviderConfig agent2) async {
    String userPrompt = _controller.text.trim();
    if (userPrompt.isEmpty) return;
    _controller.clear();

    setState(() {
      _currentSession!.messages.add(ChatMessage(role: 'user', text: userPrompt));
      _isLoading = true;
    });

    // المرحلة 1
    setState(() => _currentSession!.messages.add(ChatMessage(role: 'ai', text: "المرحلة 1 (${agent1.name}): جاري البحث والتحليل...")));
    int msg1Index = _currentSession!.messages.length - 1;
    String result1 = "";

    await for (final token in _api.generateStream(
      provider: agent1.providerType,
      apiKey: agent1.apiKey,
      baseUrl: agent1.baseUrl,
      modelName: agent1.modelName,
      systemPrompt: "أنت باحث خبير. قم بجمع المعلومات الدقيقة والشاملة حول طلب المستخدم باللغة العربية.",
      userPrompt: userPrompt,
    )) {
      result1 += token;
      setState(() => _currentSession!.messages[msg1Index] = ChatMessage(role: 'ai', text: "المرحلة 1 (${agent1.name}):\n" + result1));
    }

    // المرحلة 2
    setState(() => _currentSession!.messages.add(ChatMessage(role: 'ai', text: "المرحلة 2 (${agent2.name}): جاري المراجعة والتدقيق...")));
    int msg2Index = _currentSession!.messages.length - 1;
    String result2 = "";

    String prompt2 = "إليك البحث الذي أعدّه وكيل آخر:\n\n$result1\n\nالمستخدم سأل: $userPrompt\nالآن راجع هذا البحث، صحح أخطاءه، وأضف عليه رؤى جديدة باللغة العربية.";

    await for (final token in _api.generateStream(
      provider: agent2.providerType,
      apiKey: agent2.apiKey,
      baseUrl: agent2.baseUrl,
      modelName: agent2.modelName,
      systemPrompt: "أنت ناقد ومحلل خبير.",
      userPrompt: prompt2,
    )) {
      result2 += token;
      setState(() => _currentSession!.messages[msg2Index] = ChatMessage(role: 'ai', text: "المرحلة 2 (${agent2.name}):\n" + result2));
    }

    setState(() => _isLoading = false);
    _saveCurrentSession();
  }

  // تشغيل الموديل المحلي حصرياً عبر هذا الزر
  void _runLocalAgent() async {
    if (!_isLocalReady) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الموديل المحلي غير محمل.")));
      return;
    }
    if (_controller.text.isEmpty) return;
    
    String userText = _controller.text;
    _controller.clear();

    setState(() {
      _currentSession!.messages.add(ChatMessage(role: 'user', text: userText));
      _isLoading = true;
      _currentSession!.messages.add(ChatMessage(role: 'ai', text: "الوكيل المحلي: "));
    });

    String currentResponse = "";
    int messageIndex = _currentSession!.messages.length - 1;

    _llama.generate(prompt: userText, maxTokens: 256, temperature: 0.1).listen(
      (token) {
        currentResponse += token;
        setState(() => _currentSession!.messages[messageIndex] = ChatMessage(role: 'ai', text: "الوكيل المحلي:\n" + currentResponse));
      },
      onDone: () {
        setState(() => _isLoading = false);
        _llama.clearContext(); 
        _saveCurrentSession();
      },
    );
  }

  // زر الإرسال العادي (يستخدم السحابة إن وجدت)
  void _sendMessage() async {
    if (_controller.text.isEmpty || _currentSession == null) return;
    String userText = _controller.text;
    
    setState(() {
      _currentSession!.messages.add(ChatMessage(role: 'user', text: userText));
      _controller.clear();
      _isLoading = true;
      if (_currentSession!.title == "محادثة جديدة") {
        _currentSession!.title = userText.substring(0, userText.length > 20 ? 20 : userText.length);
      }
    });

    if (_cloudProviders.isNotEmpty) {
      CloudProviderConfig defaultAgent = _cloudProviders.first;
      setState(() => _currentSession!.messages.add(ChatMessage(role: 'ai', text: "الوكيل (${defaultAgent.name}): ")));
      int messageIndex = _currentSession!.messages.length - 1;
      String currentResponse = "";

      await for (final token in _api.generateStream(
        provider: defaultAgent.providerType,
        apiKey: defaultAgent.apiKey,
        baseUrl: defaultAgent.baseUrl,
        modelName: defaultAgent.modelName,
        systemPrompt: "أنت مساعد ذكي. أجب باللغة العربية.",
        userPrompt: userText,
      )) {
        currentResponse += token;
        setState(() => _currentSession!.messages[messageIndex] = ChatMessage(role: 'ai', text: "الوكيل (${defaultAgent.name}):\n" + currentResponse));
      }
      setState(() => _isLoading = false);
      _saveCurrentSession();
    } else if (_isLocalReady) {
      _runLocalAgentFallback(userText);
    } else {
      setState(() {
        _currentSession!.messages.add(ChatMessage(role: 'ai', text: "الرجاء إضافة مزود سحابي أو تحميل الموديل المحلي."));
        _isLoading = false;
      });
    }
  }

  void _runLocalAgentFallback(String userText) async {
    setState(() => _currentSession!.messages.add(ChatMessage(role: 'ai', text: "الوكيل المحلي: ")));
    String currentResponse = "";
    int messageIndex = _currentSession!.messages.length - 1;

    _llama.generate(prompt: userText, maxTokens: 256, temperature: 0.1).listen(
      (token) {
        currentResponse += token;
        setState(() => _currentSession!.messages[messageIndex] = ChatMessage(role: 'ai', text: "الوكيل المحلي:\n" + currentResponse));
      },
      onDone: () {
        setState(() => _isLoading = false);
        _llama.clearContext(); 
        _saveCurrentSession();
      },
    );
  }

  @override
  void dispose() {
    _llama.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentSession?.title ?? 'المحادثات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_android, color: Colors.blueAccent), 
            tooltip: "الموديل المحلي (طلب صريح)", 
            onPressed: _isLoading ? null : _runLocalAgent
          ),
          IconButton(
            icon: const Icon(Icons.sync_alt, color: Colors.amber), 
            tooltip: "تنسيق بين وكيلين (تختارهم)", 
            onPressed: _isLoading ? null : _showCoordinationDialog
          ),
          IconButton(
            icon: const Icon(Icons.settings), 
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderManagerScreen())).then((_) => _initApp())
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(child: Text("المحادثات", style: TextStyle(fontSize: 24))),
            ListTile(
              leading: const Icon(Icons.add), 
              title: const Text("محادثة جديدة"), 
              onTap: () { 
                setState(() { 
                  _sessions.add(ChatSession(id: const Uuid().v4(), title: "محادثة جديدة", messages: [], lastUpdated: DateTime.now())); 
                  _currentSession = _sessions.last; 
                }); 
                _saveCurrentSession();
                Navigator.pop(context); 
              }
            ),
            const Divider(),
            ..._sessions.map((s) => ListTile(
              title: Text(s.title),
              selected: s.id == _currentSession?.id,
              onTap: () { setState(() => _currentSession = s); Navigator.pop(context); },
            )).toList(),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _currentSession?.messages.length ?? 0,
              itemBuilder: (context, index) {
                final msg = _currentSession!.messages[index];
                return _buildMessageBubble(msg.text, msg.role == 'user');
              },
            ),
          ),
          if (_isLoading) const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator()),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(hintText: "اكتب رسالتك هنا...", border: OutlineInputBorder()),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: Colors.teal), onPressed: _isLoading ? null : _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.teal.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: isUser ? Text(text) : MarkdownBody(data: text, selectable: true, builders: {'pre': CodeElementBuilder()}),
      ),
    );
  }
}