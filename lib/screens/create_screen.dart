import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:uuid/uuid.dart';
import '../theme.dart';
import '../models/agent_model.dart';
import '../models/workflow_model.dart';
import '../agent_manager.dart';
import '../cloud_provider.dart';
import '../online_api_service.dart';
import '../mcp_tools.dart'; 
import '../workflow_manager.dart';
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
    bool hasError = false;

    for (int i = 0; i < _selectedAgents.length; i++) {
      AgentModel agent = _selectedAgents[i];
      
      CloudProviderConfig? provider;
      try {
        provider = _providers.firstWhere((p) => p.id == agent.providerId);
      } catch (e) {
        setState(() {
          _executionLog.add({'agent': agent.name, 'status': 'error', 'text': 'مزود الخدمة غير موجود.'});
        });
        hasError = true;
        break;
      }

      setState(() {
        _executionLog.add({'agent': agent.name, 'status': 'running', 'text': 'جاري التفكير...'});
      });

      int logIndex = _executionLog.length - 1;

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
        hasError = true;
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

    // حفظ المهمة في السجل
    WorkflowModel wf = WorkflowModel(
      id: const Uuid().v4(),
      taskTitle: originalTask,
      status: hasError ? 'failed' : 'completed',
      timestamp: DateTime.now(),
      finalResult: _finalResult.isEmpty ? "فشلت المهمة أو لم يتم إنتاج نتيجة." : _finalResult,
      savedFiles: _savedFiles,
    );
    await WorkflowManager.saveWorkflow(wf);
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
        chatHistory: [], 
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
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Text("Multi-Agent Workspace", style: Theme.of(context).textTheme.headlineMedium),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // بطاقة إدخال المهمة
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: TextField(
                        controller: _taskController,
                        maxLines: 4,
                        enabled: !_isRunning,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: const InputDecoration(
                          hintText: "اكتب المهمة المعقدة هنا...\n(مثلاً: أنشئ تطبيق آلة حاسبة بواجهة جميلة)",
                          hintStyle: TextStyle(color: AppColors.textSecondary),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    Row(
                      children: [
                        const Icon(Icons.group, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text("اختر فريق العمل (بالتسلسل):", style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    if (_isLoadingAgents)
                      const Center(child: CircularProgressIndicator())
                    else if (_availableAgents.isEmpty)
                      const Text("لا يوجد وكلاء. أضف وكلاء من الشاشة السابقة.", style: TextStyle(color: AppColors.danger))
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _availableAgents.map((agent) {
                          bool isSelected = _selectedAgents.contains(agent);
                          return FilterChip(
                            label: Text(agent.name, style: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.cardBackground,
                            checkmarkColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? Colors.transparent : Colors.white12)),
                            onSelected: _isRunning ? null : (_) => _toggleAgentSelection(agent),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 30),

                    // زر التشغيل
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: _isRunning ? null : _runWorkflow,
                        icon: _isRunning 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.rocket_launch),
                        label: Text(_isRunning ? "جاري التنفيذ..." : "بدء سير العمل", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    if (_executionLog.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.terminal, color: AppColors.accentBlue, size: 20),
                          const SizedBox(width: 8),
                          Text("سجل التنفيذ:", style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._executionLog.map((log) => _buildLogCard(log)).toList(),
                    ],

                    if (_savedFiles.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.success.withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle, color: AppColors.success),
                                SizedBox(width: 10),
                                Text("تم إنشاء المشروع بنجاح!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _savedFiles.map((f) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text("📄 $f", style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                )).toList(),
                              ),
                            ),
                            const SizedBox(height: 20),
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
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRunning ? AppColors.primary : (isDone ? AppColors.success : (isError ? AppColors.danger : Colors.transparent)),
          width: 1.5,
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
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(log['agent']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              if (isRunning) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            ],
          ),
          if (log['text']!.isNotEmpty && !isDone) ...[
            const SizedBox(height: 12),
            MarkdownBody(
              data: log['text']!,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                code: const TextStyle(backgroundColor: Colors.black45, color: Colors.greenAccent),
              ),
            ),
          ]
        ],
      ),
    );
  }
}