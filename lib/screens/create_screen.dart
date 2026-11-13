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
import '../skill_manager.dart'; // لربط المهارات
import 'workspace_screen.dart'; 

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _interventionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final OnlineApiService _api = OnlineApiService();
  
  List<AgentModel> _availableAgents = [];
  List<AgentModel> _selectedAgents = [];
  List<CloudProviderConfig> _providers = [];
  List<Skill> _allSkills = [];
  
  bool _isLoadingData = true;
  bool _isGenerating = false;
  bool _isAutoSelecting = false;
  bool _workflowStarted = false;
  
  // متغيرات غرفة العمليات
  int _currentAgentIndex = 0;
  String _originalTask = "";
  List<Map<String, String>> _chatLog = []; // سجل المحادثة بين الوكلاء والمستخدم
  List<String> _savedFiles = []; 
  String _currentStreamingText = "";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _availableAgents = await AgentManager.loadAgents();
    _providers = await CloudConfigManager.loadProviders();
    _allSkills = await SkillManager.loadSkills();
    setState(() => _isLoadingData = false);
  }

  void _toggleAgentSelection(AgentModel agent) {
    if (_workflowStarted) return;
    setState(() {
      if (_selectedAgents.contains(agent)) {
        _selectedAgents.remove(agent);
      } else {
        _selectedAgents.add(agent);
      }
    });
  }

  // دالة التنسيق التلقائي
  Future<void> _autoOrchestrate() async {
    if (_taskController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى كتابة المهمة أولاً.")));
      return;
    }
    if (_providers.isEmpty) return;

    setState(() => _isAutoSelecting = true);

    List<Map<String, String>> agentsData = _availableAgents.map((a) => {
      'id': a.id, 'name': a.name, 'description': a.description,
    }).toList();

    CloudProviderConfig provider = _providers.first;

    List<String>? selectedIds = await _api.autoSelectAgents(
      provider: provider.providerType,
      apiKey: provider.apiKey,
      baseUrl: provider.baseUrl,
      modelName: provider.modelName,
      userTask: _taskController.text.trim(),
      availableAgents: agentsData,
    );

    setState(() {
      _isAutoSelecting = false;
      if (selectedIds != null && selectedIds.isNotEmpty) {
        _selectedAgents.clear();
        for (String id in selectedIds) {
          var agent = _availableAgents.firstWhere((a) => a.id == id, orElse: () => _availableAgents.first);
          if (!_selectedAgents.contains(agent)) _selectedAgents.add(agent);
        }
      }
    });
  }

  // بدء سير العمل
  void _startWorkflow() {
    if (_taskController.text.trim().isEmpty || _selectedAgents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("اكتب المهمة واختر الفريق أولاً.")));
      return;
    }

    setState(() {
      _workflowStarted = true;
      _originalTask = _taskController.text.trim();
      _chatLog.clear();
      _savedFiles.clear();
      _currentAgentIndex = 0;
      _chatLog.add({'role': 'user', 'text': "المهمة الأساسية: $_originalTask"});
    });

    _runAgentStep(_currentAgentIndex);
  }

  // تشغيل وكيل معين
  Future<void> _runAgentStep(int index) async {
    if (index >= _selectedAgents.length) {
      // انتهى الفريق
      _finishWorkflow();
      return;
    }

    AgentModel agent = _selectedAgents[index];
    CloudProviderConfig? provider;
    
    try {
      provider = _providers.firstWhere((p) => p.id == agent.providerId);
    } catch (e) {
      setState(() => _isGenerating = false);
      _chatLog.add({'role': 'system', 'text': 'خطأ: مزود الخدمة للوكيل ${agent.name} غير موجود.'});
      return;
    }

    setState(() {
      _isGenerating = true;
      _currentStreamingText = "";
    });

    // 1. بناء سياق المحادثة
    String conversationContext = _chatLog.map((m) => "${m['role'] == 'user' ? 'المستخدم/المنسق' : m['role']}: ${m['text']}").join('\n\n');

    // 2. تجهيز المهارات
    List<String> agentSkills = _allSkills
        .where((s) => agent.skillIds.contains(s.id))
        .map((s) => s.systemPrompt)
        .toList();
    
    String skillsPrompt = agentSkills.isNotEmpty ? "\n\n[مهاراتك الخاصة]:\n${agentSkills.join('\n\n')}" : "";

    // 3. بناء البرومبت للوكيل
    String prompt = """
أنت (${agent.name})، ووصفك: ${agent.description}.
أنت في اجتماع فريق متعدد الوكلاء. المهمة الأساسية هي: "$_originalTask".

إليك ما دار في غرفة العمليات حتى الآن:
$conversationContext

مهمتك الآن: قدم مساهمتك المتخصصة بناءً على دورك وما دار في النقاش.
- إذا احتجت معلومات، استخدم أداة البحث.
- إذا كنت مطوراً، اكتب الأكواد بصيغة \`\`\`[اللغة] [المسار]\n[الكود]\n\`\`\` ليتم حفظها.
- لا تعتذر، أنجز عملك وقدم النتيجة.
""";

    // 4. تشغيل الوكيل
    String currentResponse = "";
    bool isFirstToken = true;
    
    // إضافة فقاعة للوكيل في الواجهة
    setState(() {
      _chatLog.add({'role': agent.name, 'text': '...'});
    });

    int logIndex = _chatLog.length - 1;

    try {
      await for (final chunk in _api.generateStream(
        provider: provider.providerType,
        apiKey: provider.apiKey,
        baseUrl: provider.baseUrl,
        modelName: provider.modelName,
        systemPrompt: agent.systemPrompt + skillsPrompt,
        userPrompt: prompt,
        chatHistory: [], // السياق مبني يدوياً في البرومبت
        useTools: true, // تفعيل الأدوات للجميع
      )) {
        currentResponse += chunk;
        setState(() {
          _chatLog[logIndex]['text'] = currentResponse;
        });
        _scrollToBottom();
        
        // استخراج الملفات إن وجدت في هذا الرد
        _extractFilesFromText(currentResponse);
      }
      
      setState(() {
        _isGenerating = false;
        _currentAgentIndex++; // الانتقال للوكيل التالي
        _currentStreamingText = "";
      });

    } catch (e) {
      setState(() {
        _isGenerating = false;
        _chatLog[logIndex]['text'] = "❌ خطأ: $e";
      });
    }
  }

  // تدخل المستخدم وتمرير الكلمة للوكيل التالي
  void _submitIntervention() {
    if (_interventionController.text.trim().isEmpty) return;

    setState(() {
      _chatLog.add({'role': 'user', 'text': _interventionController.text.trim()});
      _interventionController.clear();
    });
    _scrollToBottom();

    // تشغيل الوكيل التالي فوراً
    _runAgentStep(_currentAgentIndex);
  }

  void _finishWorkflow() {
    setState(() {
      _isGenerating = false;
      _chatLog.add({'role': 'system', 'text': '✅ انتهى الاجتماع وتم إنتاج المشروع بنجاح.'});
    });

    // حفظ المهمة في السجل
    String finalResult = _chatLog.lastWhere((m) => m['role'] != 'user' && m['role'] != 'system', orElse: () => {'text': 'لا يوجد'})['text']!;
    
    WorkflowModel wf = WorkflowModel(
      id: const Uuid().v4(),
      taskTitle: _originalTask,
      status: 'completed',
      timestamp: DateTime.now(),
      finalResult: finalResult,
      savedFiles: _savedFiles,
      conversationLog: _chatLog,
    );
    WorkflowManager.saveWorkflow(wf);
  }

  Future<void> _extractFilesFromText(String text) async {
    RegExp regExp = RegExp(r'```(\w+)?\s+([^\n\r]+)\r?\n([\s\S]*?)```');
    Iterable<RegExpMatch> matches = regExp.allMatches(text);
    for (var match in matches) {
      String? filePath = match.group(2)?.trim();
      String? content = match.group(3);
      if (filePath != null && content != null && filePath.contains('.')) {
        filePath = filePath.replaceAll('`', '').trim();
        if (!_savedFiles.contains(filePath)) {
          String result = await McpTools.writeFile(filePath, content);
          if (result.contains("تم حفظ الملف")) {
            setState(() => _savedFiles.add(filePath!));
          }
        }
      }
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // شريط علوي
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (_workflowStarted) IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => setState(() => _workflowStarted = false)),
                      Text(_workflowStarted ? "غرفة عمليات الفريق" : "Multi-Agent Workspace", style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.folder_special, color: AppColors.primary),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkspaceScreen())),
                  )
                ],
              ),
            ),

            // إذا لم يبدأ العمل: عرض إعداد الفريق
            if (!_workflowStarted) _buildSetupView(),
            
            // إذا بدأ العمل: عرض غرفة العمليات
            if (_workflowStarted) Expanded(child: _buildWarRoomView()),

            // شريط الإدخال السفلي
            if (_workflowStarted) _buildInterventionInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupView() {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _taskController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "اكتب المهمة المعقدة...",
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(20),
                ),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isAutoSelecting ? null : _autoOrchestrate,
                icon: _isAutoSelecting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome, color: AppColors.amber),
                label: const Text("تنسيق تلقائي (Auto-Orchestrate)", style: TextStyle(color: AppColors.amber)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.amber)),
              ),
            ),
            const SizedBox(height: 25),
            Text("الفريق (بالتسلسل):", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _availableAgents.map((agent) {
                bool isSelected = _selectedAgents.contains(agent);
                return FilterChip(
                  label: Text(agent.name, style: TextStyle(color: isSelected ? Colors.white : Colors.grey)),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.cardBackground,
                  onSelected: (_) => _toggleAgentSelection(agent),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton.icon(
                onPressed: _startWorkflow,
                icon: const Icon(Icons.forum),
                label: const Text("بدء الاجتماع", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarRoomView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _chatLog.length,
      itemBuilder: (context, index) {
        final msg = _chatLog[index];
        bool isUser = msg['role'] == 'user' || msg['role'] == 'system';
        String senderName = isUser ? 'أنت (المنسق)' : msg['role']!;

        if (msg['role'] == 'system') {
          return Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: Text(msg['text']!, style: const TextStyle(color: AppColors.success)),
            ),
          );
        }

        return Align(
          alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
            decoration: BoxDecoration(
              color: isUser ? AppColors.primary : AppColors.cardBackground,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 0 : 16), bottomRight: Radius.circular(isUser ? 16 : 0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isUser) ...[
                  Text(senderName, style: const TextStyle(color: AppColors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                ],
                MarkdownBody(
                  data: msg['text']!,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(color: Colors.white, fontSize: 15),
                    code: const TextStyle(backgroundColor: Colors.black45, color: Colors.greenAccent),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInterventionInput() {
    // إذا كان الوكيل يعمل الآن، لا يمكن للمستخدم الكتابة
    bool canIntervene = !_isGenerating && _currentAgentIndex < _selectedAgents.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isGenerating)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
              child: Text("الوكيل (${_selectedAgents[_currentAgentIndex].name}) يعمل الآن...", style: const TextStyle(color: AppColors.primary, fontSize: 12)),
            )
          else if (canIntervene)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
              child: Text("دور الوكيل التالي (${_selectedAgents[_currentAgentIndex].name}). اكتب توجيهاتك أو اضغط إرسال للمتابعة.", style: const TextStyle(color: AppColors.amber, fontSize: 12)),
            ),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _interventionController,
                  enabled: canIntervene,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "اكتب توجيهك للفريق هنا...",
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _submitIntervention(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: canIntervene ? AppColors.primary : Colors.grey,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: canIntervene ? _submitIntervention : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}