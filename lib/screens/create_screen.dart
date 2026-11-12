import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/agent_model.dart';
import '../agent_manager.dart';
import '../cloud_provider.dart';
import '../online_api_service.dart';

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
  
  // لتخزين سجل التنفيذ (الخطوات)
  List<Map<String, String>> _executionLog = [];
  String _finalResult = "";

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
    });

    String originalTask = _taskController.text.trim();
    String currentContext = originalTask;

    // التشغيل المتسلسل (Sequential Execution)
    for (int i = 0; i < _selectedAgents.length; i++) {
      AgentModel agent = _selectedAgents[i];
      
      // البحث عن مزود الخدمة المرتبط بالوكيل
      CloudProviderConfig? provider;
      try {
        provider = _providers.firstWhere((p) => p.id == agent.providerId);
      } catch (e) {
        setState(() {
          _executionLog.add({'agent': agent.name, 'status': 'error', 'text': 'مزود الخدمة غير موجود.'});
        });
        break; // نوقف العملية
      }

      setState(() {
        _executionLog.add({'agent': agent.name, 'status': 'running', 'text': 'جاري التفكير...'});
      });

      int logIndex = _executionLog.length - 1;
      String agentOutput = "";

      // تجهيز البرومبت بناءً على دور الوكيل في السلسلة
      String prompt = "";
      if (i == 0) {
        prompt = "أنت أول وكيل في فريق. المهمة الأساسية هي: '$originalTask'.\nقدم مساهمتك بناءً على دورك.";
      } else {
        prompt = "المهمة الأساسية: '$originalTask'.\nهذا ما أنتجه الوكيل السابق:\n\n$currentContext\n\nبناءً على ما سبق، قدم مساهمتك كـ (${agent.name}) لاستكمال المهمة.";
      }

      // تشغيل الستريم وانتظار انتهائه
      bool success = await _executeAgentStream(agent, provider, prompt, (streamText) {
        // تحديث الواجهة أثناء الكتابة
        setState(() {
          _executionLog[logIndex]['text'] = streamText;
        });
      });

      if (success) {
        currentContext = agentOutput; // نمرر النتيجة للوكيل التالي
        setState(() {
          _executionLog[logIndex]['status'] = 'done';
        });
      } else {
        setState(() {
          _executionLog[logIndex]['status'] = 'error';
        });
        break; // نتوقف إذا فشل وكيل
      }
    }

    setState(() {
      _isRunning = false;
      if (_executionLog.isNotEmpty && _executionLog.last['status'] == 'done') {
        _finalResult = currentContext; // النتيجة النهائية هي مخرجات آخر وكيل
      }
    });
  }

  // دالة مساعدة لتنفيذ وكيل واحد وانتظار انتهائه
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
                    // 1. إدخال المهمة
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
                          hintText: "اكتب المهمة المعقدة هنا... (مثلاً: ابحث عن أفضل 3 هواتف في 2024، ثم قارن بينها)",
                          hintStyle: TextStyle(color: AppColors.textSecondary),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. اختيار الوكلاء
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

                    // 3. زر التشغيل
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

                    // 4. سجل التنفيذ
                    if (_executionLog.isNotEmpty) ...[
                      Text("سجل التنفيذ:", style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      ..._executionLog.map((log) => _buildLogCard(log)).toList(),
                    ],

                    // 5. النتيجة النهائية
                    if (_finalResult.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text("النتيجة النهائية:", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.success)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: AppColors.success.withOpacity(0.3)),
                        ),
                        child: SelectableText(
                          _finalResult,
                          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
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
          if (log['text']!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              log['text']!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              maxLines: isDone ? 3 : 10, // إظهار جزء من النص
              overflow: TextOverflow.ellipsis,
            ),
          ]
        ],
      ),
    );
  }
}