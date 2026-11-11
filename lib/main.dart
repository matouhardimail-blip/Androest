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
import 'agent_system.dart';
import 'mcp_tools.dart';
import 'skill_manager.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi-Agent Platform',
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
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// ==========================================
// 2. شاشة إدارة المهارات (Skills)
// ==========================================
class SkillManagerScreen extends StatefulWidget {
  @override
  State<SkillManagerScreen> createState() => _SkillManagerScreenState();
}

class _SkillManagerScreenState extends State<SkillManagerScreen> {
  List<Skill> _skills = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await SkillManager.loadSkills();
    setState(() => _skills = s);
  }

  void _addSkill() {
    showDialog(
      context: context,
      builder: (context) {
        String name = "", desc = "", prompt = "";
        return AlertDialog(
          title: const Text("إضافة مهارة جديدة (Skill)"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(decoration: const InputDecoration(labelText: "اسم المهارة"), onChanged: (v) => name = v),
                TextField(decoration: const InputDecoration(labelText: "وصف قصير"), onChanged: (v) => desc = v),
                TextField(decoration: const InputDecoration(labelText: "System Prompt"), maxLines: 5, onChanged: (v) => prompt = v),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: () async {
                if (name.isNotEmpty && prompt.isNotEmpty) {
                  _skills.add(Skill(id: const Uuid().v4(), name: name, description: desc, systemPrompt: prompt));
                  await SkillManager.saveSkills(_skills);
                  _load();
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text("حفظ"),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("مهارات الوكلاء (Skills)")),
      floatingActionButton: FloatingActionButton(onPressed: _addSkill, child: const Icon(Icons.add)),
      body: ListView.builder(
        itemCount: _skills.length,
        itemBuilder: (context, index) {
          final s = _skills[index];
          return ListTile(
            title: Text(s.name),
            subtitle: Text(s.description),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                _skills.removeAt(index);
                await SkillManager.saveSkills(_skills);
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
// 3. شاشة إدارة المزودين (Providers)
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
        List<AgentCapability> selectedCaps = [AgentCapability.textGeneration];

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("إضافة وكيل / مزود خدمة"),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    TextField(decoration: const InputDecoration(labelText: "اسم الوكيل"), onChanged: (v) => name = v),
                    DropdownButtonFormField<String>(
                      value: type,
                      items: const [
                        DropdownMenuItem(value: "openai", child: Text("OpenAI (أو متوافق)")),
                        DropdownMenuItem(value: "anthropic", child: Text("Anthropic (Claude)")),
                      ],
                      onChanged: (v) {
                        setStateDialog(() {
                          type = v!;
                          baseUrl = type == "anthropic" ? "https://api.anthropic.com" : "https://api.openai.com/v1";
                          model = type == "anthropic" ? "claude-3-5-sonnet-20240620" : "gpt-4o";
                        });
                      },
                      decoration: const InputDecoration(labelText: "المزود"),
                    ),
                    TextField(decoration: const InputDecoration(labelText: "API Key"), onChanged: (v) => key = v),
                    TextField(decoration: const InputDecoration(labelText: "Base URL"), controller: TextEditingController(text: baseUrl), onChanged: (v) => baseUrl = v),
                    TextField(decoration: const InputDecoration(labelText: "Model Name"), controller: TextEditingController(text: model), onChanged: (v) => model = v),
                    const SizedBox(height: 15),
                    const Text("القدرات (Capabilities):", style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8,
                      children: AgentCapability.values.map((cap) {
                        return FilterChip(
                          label: Text(cap.name),
                          selected: selectedCaps.contains(cap),
                          onSelected: (selected) {
                            setStateDialog(() {
                              if (selected) selectedCaps.add(cap);
                              else selectedCaps.remove(cap);
                            });
                          },
                        );
                      }).toList(),
                    ),
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
                        capabilities: selectedCaps,
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
      appBar: AppBar(title: const Text("إدارة الوكلاء السحابيين")),
      floatingActionButton: FloatingActionButton(onPressed: _addProvider, child: const Icon(Icons.add)),
      body: ListView.builder(
        itemCount: _providers.length,
        itemBuilder: (context, index) {
          final p = _providers[index];
          return ListTile(
            title: Text(p.name),
            subtitle: Text("${p.providerType} - ${p.modelName}\nالقدرات: ${p.capabilities.map((e) => e.name).join(', ')}"),
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
// 4. شاشة الدردشة والتنفيذ
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
  
  final OnlineApiService _api = OnlineApiService();
  List<CloudProviderConfig> _cloudProviders = [];
  List<Skill> _skills = [];
  Skill? _selectedSkill;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    _cloudProviders = await CloudConfigManager.loadProviders();
    _skills = await SkillManager.loadSkills();
    _sessions = await ChatHistoryManager.loadSessions();

    setState(() {
      if (_sessions.isEmpty) {
        _sessions.add(ChatSession(id: const Uuid().v4(), title: "محادثة جديدة", messages: [], lastUpdated: DateTime.now()));
      }
      _currentSession = _sessions.last;
      if (_skills.isNotEmpty) _selectedSkill = _skills.first;
    });
  }

  void _saveCurrentSession() {
    if (_currentSession != null) {
      _currentSession!.lastUpdated = DateTime.now();
      ChatHistoryManager.saveSessions(_sessions);
    }
  }

  void _routeAndExecute(String userText) async {
    if (_cloudProviders.isEmpty) {
      setState(() {
        _currentSession!.messages.add(AgentMessage(role: 'ai', text: "الرجاء إضافة مزود خدمة من الإعدادات."));
        _isLoading = false;
      });
      return;
    }

    AgentCapability requiredCap = AgentCapability.textGeneration;
    String lower = userText.toLowerCase();
    
    // منطق توجيه بسيط
    if (lower.contains("ارسم") || lower.contains("صورة")) requiredCap = AgentCapability.imageGeneration;
    if (lower.contains("أنشئ مشروع") || lower.contains("اكتب كود") || lower.contains("عدل ملف")) requiredCap = AgentCapability.codeGeneration;
    if (lower.contains("ترجم")) requiredCap = AgentCapability.translation;
    if (lower.contains("لخص")) requiredCap = AgentCapability.summarization;
    if (lower.contains("ابحث")) requiredCap = AgentCapability.search;

    CloudProviderConfig? targetProvider = _cloudProviders.firstWhere(
      (p) => p.capabilities.contains(requiredCap),
      orElse: () => _cloudProviders.firstWhere((p) => p.capabilities.contains(AgentCapability.textGeneration), orElse: () => _cloudProviders.first),
    );

    Agent agent = _selectedSkill != null ? AgentFactory.createAgentFromSkill(_selectedSkill!) : AgentFactory.createAgent(requiredCap);

    setState(() {
      _currentSession!.messages.add(AgentMessage(role: 'ai', text: "المنسق: سأستخدم (${agent.name}) عبر (${targetProvider.name})..."));
    });
    int msgIndex = _currentSession!.messages.length;
    setState(() => _currentSession!.messages.add(AgentMessage(role: 'ai', text: "جاري التنفيذ...")));

    // --- توليد نصي (مخصص للمشاريع والترجمة وغيره) ---
    String currentResponse = "";
    bool toolExecuted = false;

    await for (final token in _api.generateStream(
      provider: targetProvider.providerType,
      apiKey: targetProvider.apiKey,
      baseUrl: targetProvider.baseUrl,
      modelName: targetProvider.modelName,
      systemPrompt: agent.systemPrompt,
      userPrompt: userText,
    )) {
      currentResponse += token;
      setState(() => _currentSession!.messages[msgIndex] = AgentMessage(role: 'ai', text: currentResponse));

      // نظام MCP
      if (requiredCap == AgentCapability.codeGeneration && !toolExecuted && currentResponse.contains("[TOOL:")) {
        toolExecuted = true;
        String? result = await McpTools.handleToolCall(currentResponse);
        if (result != null) {
          setState(() => _currentSession!.messages.add(AgentMessage(role: 'ai', text: "⚙️ تم تنفيذ الأداة: $result")));
        }
      }
    }

    setState(() => _isLoading = false);
    _saveCurrentSession();
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty || _currentSession == null) return;
    String userText = _controller.text;
    
    setState(() {
      _currentSession!.messages.add(AgentMessage(role: 'user', text: userText));
      _controller.clear();
      _isLoading = true;
      if (_currentSession!.title == "محادثة جديدة") {
        _currentSession!.title = userText.substring(0, userText.length > 20 ? 20 : userText.length);
      }
    });

    _routeAndExecute(userText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> sessionTiles = [];
    for (var s in _sessions) {
      sessionTiles.add(
        ListTile(
          title: Text(s.title),
          selected: s.id == _currentSession?.id,
          onTap: () { setState(() => _currentSession = s); Navigator.pop(context); },
        )
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentSession?.title ?? 'المنصة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.extension, color: Colors.amber),
            tooltip: "إدارة المهارات",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SkillManagerScreen())).then((_) => _initApp())
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
            ...sessionTiles,
          ],
        ),
      ),
      body: Column(
        children: [
          if (_skills.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: DropdownButtonFormField<Skill>(
                value: _selectedSkill,
                decoration: const InputDecoration(labelText: "المهارة النشطة (Skill)", border: OutlineInputBorder()),
                items: _skills.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                onChanged: (v) => setState(() => _selectedSkill = v),
              ),
            ),
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
                    decoration: const InputDecoration(hintText: "اكتب طلبك...", border: OutlineInputBorder()),
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
        child: isUser 
          ? Text(text) 
          : MarkdownBody(
              data: text, 
              selectable: true, 
              builders: {'pre': CodeElementBuilder()},
            ),
      ),
    );
  }
}