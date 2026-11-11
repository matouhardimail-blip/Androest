import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme.dart';
import '../models/agent_model.dart';
import '../agent_manager.dart';
import '../cloud_provider.dart';
import 'chat_screen.dart';

class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  List<AgentModel> _agents = [];
  List<CloudProviderConfig> _providers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _agents = await AgentManager.loadAgents();
    _providers = await CloudConfigManager.loadProviders();
    setState(() => _isLoading = false);
  }

  // دالة موحدة للإضافة والتعديل
  void _showAgentDialog({AgentModel? agentToEdit}) {
    if (_providers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("الرجاء إضافة مزود خدمة (API) أولاً من الإعدادات.")),
      );
      return;
    }

    // إذا كان هناك وكيل يتم تعديله، نستخدم بياناته. وإلا نبدأ ببيانات فارغة
    String name = agentToEdit?.name ?? "";
    String desc = agentToEdit?.description ?? "";
    String sysPrompt = agentToEdit?.systemPrompt ?? "أنت مساعد ذكي.";
    
    // التحقق مما إذا كان مزود الخدمة المرتبط بالوكيل لا يزال موجوداً
    String selectedProviderId = agentToEdit?.providerId ?? _providers.first.id;
    if (agentToEdit != null && !_providers.any((p) => p.id == agentToEdit.providerId)) {
      selectedProviderId = _providers.first.id; // إذا تم حذف المزود، نختار الأول افتراضياً
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              title: Text(
                agentToEdit == null ? "إنشاء وكيل جديد" : "تعديل الوكيل",
                style: const TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      controller: TextEditingController(text: name),
                      decoration: const InputDecoration(
                        labelText: "اسم الوكيل",
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                      onChanged: (v) => name = v,
                    ),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      controller: TextEditingController(text: desc),
                      decoration: const InputDecoration(
                        labelText: "وصف قصير",
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                      onChanged: (v) => desc = v,
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: selectedProviderId,
                      dropdownColor: AppColors.cardBackground,
                      items: _providers.map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text("${p.name} (${p.modelName})", style: const TextStyle(color: Colors.white)),
                      )).toList(),
                      onChanged: (v) => setStateDialog(() => selectedProviderId = v!),
                      decoration: const InputDecoration(
                        labelText: "مزود الخدمة المرتبط",
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      controller: TextEditingController(text: sysPrompt),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "شخصية الوكيل (System Prompt)",
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                      onChanged: (v) => sysPrompt = v,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text("إلغاء", style: TextStyle(color: Colors.grey))
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (name.isNotEmpty) {
                      CloudProviderConfig selectedProvider = _providers.firstWhere((p) => p.id == selectedProviderId);
                      
                      if (agentToEdit == null) {
                        // إنشاء وكيل جديد
                        AgentModel newAgent = AgentModel(
                          id: const Uuid().v4(),
                          name: name,
                          description: desc,
                          providerId: selectedProviderId,
                          modelName: selectedProvider.modelName,
                          systemPrompt: sysPrompt,
                          icon: Icons.smart_toy,
                          color: AppColors.primary,
                        );
                        _agents.add(newAgent);
                      } else {
                        // تعديل وكيل موجود
                        int index = _agents.indexWhere((a) => a.id == agentToEdit.id);
                        if (index != -1) {
                          _agents[index] = AgentModel(
                            id: agentToEdit.id,
                            name: name,
                            description: desc,
                            providerId: selectedProviderId,
                            modelName: selectedProvider.modelName,
                            systemPrompt: sysPrompt,
                            icon: agentToEdit.icon,
                            color: agentToEdit.color,
                            isConnected: agentToEdit.isConnected,
                          );
                        }
                      }
                      
                      await AgentManager.saveAgents(_agents);
                      _loadData();
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text("حفظ", style: TextStyle(color: Colors.white)),
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.arrow_back, color: Colors.white),
                      const SizedBox(width: 15),
                      Text("My Agents", style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 30),
                    onPressed: () => _showAgentDialog(), // فتح نافذة الإضافة
                  )
                ],
              ),
            ),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _agents.isEmpty 
                  ? const Center(child: Text("لا يوجد وكلاء. أضف وكيلاً جديداً.", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _agents.length,
                      itemBuilder: (context, index) {
                        final agent = _agents[index];
                        return Dismissible(
                          key: Key(agent.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: AppColors.danger,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) async {
                            _agents.removeAt(index);
                            await AgentManager.saveAgents(_agents);
                            _loadData();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: agent.color.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(agent.icon, color: agent.color, size: 30),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(agent.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                      Text(agent.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 8),
                                      Text(agent.modelName, style: const TextStyle(color: AppColors.success, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                // زر التعديل الجديد
                                IconButton(
                                  icon: const Icon(Icons.edit, color: AppColors.textSecondary, size: 22),
                                  onPressed: () => _showAgentDialog(agentToEdit: agent),
                                  tooltip: "تعديل الوكيل",
                                ),
                                const SizedBox(width: 5),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => ChatScreen(agent: agent)),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary.withOpacity(0.2),
                                    foregroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text("Open"),
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}