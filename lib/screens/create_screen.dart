import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme.dart';
import '../models/agent_model.dart';
import '../agent_manager.dart';
import '../cloud_provider.dart';
import '../online_api_service.dart';
import '../mcp_tools.dart'; 
import 'workspace_screen.dart'; 

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final TextEditingController _taskController = TextEditingController();
  final OnlineApiService _api = OnlineApiService();
  
  List<AgentModel> _availableAgents = [];
  List<AgentModel> _selectedAgents = [];
  List<CloudProviderConfig> _providers = [];
  
  bool _isLoadingAgents = true;
  bool _isRunning = false;
  
  List<Map<String, String>> _executionLog = [];
  String _finalResult = "";
  List<String> _savedFiles = []; 

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _availableAgents = await AgentManager.loadAgents();
    _providers = await CloudConfigManager.loadProviders();
    setState(() => _isLoadingAgents = false);
  }

  void _toggleAgentSelection(AgentModel agent) {
    setState(() {
      if (_selectedAgents.contains(agent)) {
        _selectedAgents.remove(agent);
      } else {
        _selectedAgents.add(agent);
      }
    });
  }

  Future<void> _runWorkflow() async {
    if (_taskController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى كتابة المهمة أولاً.")));
      return;
    }
    if (_selectedAgents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى اختيار وكيل واحد على الأقل.")));
      return;
    }
    if (_providers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا توجد مزودات خدمة. أضف مزوداً من الإعدادات.")));
      return;
    }

    setState(() {
      _isRunning = true;
      _executionLog.clear();
      _finalResult = "";
      _savedFiles.clear();
    });

    String originalTask = _taskController.text.trim();
    String currentContext = originalTask;

    for (int i = 0; i < _selectedAgents.length; i++) {
      AgentModel agent = _selectedAgents[i];
      
      CloudProviderConfig? provider;
      try {
        provider = _providers.firstWhere((p) => p.id == agent.providerId);
      } catch (e) {
        setState(() {
          _executionLog.add({'agent': agent.name, 'status': 'error', 'text': 'مزود الخدمة غير موجود.'});
        });
        break;
      }

      setState(() {
        _executionLog.add({'agent': agent.name, 'status': 'running', 'text': 'جاري التفكير...'});
      });

      int logIndex = _executionLog.length - 1;
      String agentOutput = "";

      String prompt = "";
      if (i == 0) {
        prompt = "أنت أول وكيل في فريق. المهمة الأساسية هي: '$originalTask'.\nقدم مساهمتك بناءً على دورك.";
      } else {
        if (i == _selectedAgents.length - 1) {
          prompt = "المهمة الأساسية: '$originalTask'.\nهذا ما أنتجه الوكيل السابق:\n\n$currentContext\n\nأنت الوكيل الأخير. مهمتك هي إخراج الأكواد النهائية للمشروع.\nيجب أن تكتب كل ملف بالصيغة التالية بالضبط حتى يتم حفظه:\n```[اللغة] [مسار/الملف]\n[الكود هنا]\n```\nمثال:\n```dart lib/main.dart\nvoid main() {}\n```";
        } else {
          prompt = "المهمة الأساسية: '$originalTask'.\nهذا ما أنتجه الوكيل السابق:\n\n$currentContext\n\nبناءً على ما سبق، قدم مساهمتك كـ (${agent.name}) لاستكمال المهمة.";
        }
      }

      bool success = await _executeAgentStream(agent, provider, prompt, (streamText) {
        setState(() {
          _executionLog[logIndex]['text'] = streamText;
        });
      });

      if (success) {
        currentContext = _executionLog[logIndex]['text']!;
        setState(() {
          _executionLog[logIndex]['status'] = 'done';
        });
      } else {
        setState(() {
          _executionLog[logIndex]['status'] = 'error';
        });
        break;
      }
    }

    setState(() {
      _isRunning = false;
      if (_executionLog.isNotEmpty && _executionLog.last['status'] == 'done') {
        _finalResult = currentContext;
        _extractAndSaveFiles(_finalResult);
      }
    });
  }

  Future<void> _extractAndSaveFiles(String markdownText) async {
    RegExp regExp = RegExp(r'```(\w+)?\s+([^\n\r]+)\r?\n([\s\S]*?)```');
    Iterable<RegExpMatch> matches = regExp.allMatches(markdownText);

    for (var match in matches) {
      String? filePath = match.group(2)?.trim();
      String? content = match.group(3);

      if (filePath != null && content != null && filePath.contains('.')) {
        filePath = filePath.replaceAll('`', '').trim();
        String result = await McpTools.writeFile(filePath, content);
        
        if (result.contains("تم حفظ الملف")) {
          setState(() {
            _savedFiles.add(filePath!);
          });
        }
      }
    }
  }

  Future<bool> _executeAgentStream(
    AgentModel agent, 
    CloudProviderConfig provider, 
    String prompt, 
    Function(String) onUpdate
  ) async {
    bool success = false;
    String currentOutput = "";

    try {
      final stream = _api.generateStream(
        provider: provider.providerType,
        apiKey: provider.apiKey,
        baseUrl: provider.baseUrl,
        modelName: provider.modelName,
        systemPrompt: agent.systemPrompt,
        userPrompt: prompt,
        chatHistory: [], // <--- تم إضافة هذا السطر لحل المشكلة
      );

      await for (final chunk in stream) {
        currentOutput += chunk;
        onUpdate(currentOutput);
      }
      success = true;
    } catch (e) {
      onUpdate(currentOutput + "\n\n❌ خطأ: $e");
      success = false;
    }

    return success;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Multi-Agent Workspace", style: Theme.of(context).textTheme.headlineMedium),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: TextField(
                        controller: _taskController,
                        maxLines: 3,
                        enabled: !_isRunning,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "اكتب المهمة المعقدة هنا... (مثلاً: أنشئ تطبيق آلة حاسبة بواجهة جميلة)",
                          hintStyle: TextStyle(color: AppColors.textSecondary),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text("اختر فريق العمل (بالتسلسل):", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    if (_isLoadingAgents)
                      const Center(child: CircularProgressIndicator())
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableAgents.map((agent) {
                          bool isSelected = _selectedAgents.contains(agent);
                          return FilterChip(
                            label: Text(agent.name, style: TextStyle(color: isSelected ? Colors.white : Colors.grey)),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.cardBackground,
                            checkmarkColor: Colors.white,
                            onSelected: _isRunning ? null : (_) => _toggleAgentSelection(agent),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isRunning ? null : _runWorkflow,
                        icon: _isRunning 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.play_arrow),
                        label: Text(_isRunning ? "جاري التنفيذ..." : "تشغيل سير العمل"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_executionLog.isNotEmpty) ...[
                      Text("سجل التنفيذ:", style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      ..._executionLog.map((log) => _buildLogCard(log)).toList(),
                    ],

                    if (_savedFiles.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: AppColors.success),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle, color: AppColors.success),
                                SizedBox(width: 8),
                                Text("تم إنشاء المشروع بنجاح!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ..._savedFiles.map((f) => Text("- $f", style: const TextStyle(color: Colors.white70, fontSize: 14))).toList(),
                            const SizedBox(height: 15),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkspaceScreen()));
                                },
                                icon: const Icon(Icons.folder_open),
                                label: const Text("فتح مساحة العمل (Workspace)"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(Map<String, String> log) {
    bool isRunning = log['status'] == 'running';
    bool isDone = log['status'] == 'done';
    bool isError = log['status'] == 'error';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRunning ? AppColors.primary : (isDone ? AppColors.success : (isError ? AppColors.danger : Colors.transparent)),
          width: isRunning || isDone || isError ? 1 : 0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRunning ? Icons.sync : (isDone ? Icons.check_circle : (isError ? Icons.error : Icons.circle)),
                color: isRunning ? AppColors.primary : (isDone ? AppColors.success : (isError ? AppColors.danger : Colors.grey)),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(log['agent']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (isRunning) const Text("يعمل الآن...", style: TextStyle(color: AppColors.primary, fontSize: 12)),
            ],
          ),
          if (log['text']!.isNotEmpty && !isDone) ...[
            const SizedBox(height: 10),
            MarkdownBody(
              data: log['text']!,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                code: const TextStyle(backgroundColor: Colors.black45, color: Colors.greenAccent),
              ),
            ),
          ]
        ],
      ),
    );
  }
}