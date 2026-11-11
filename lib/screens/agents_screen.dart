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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    setState(() => _isLoading = true);
    _agents = await AgentManager.loadAgents();
    setState(() => _isLoading = false);
  }

  // دالة موحدة للإضافة والتعديل
  Future<void> _showAgentDialog({AgentModel? agentToEdit}) async {
    // 1. جلب المزودين بشكل مباشر عند فتح النافذة لضمان ظهور أي إضافات جديدة
    List<CloudProviderConfig> providers = await CloudConfigManager.loadProviders();

    if (providers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("الرجاء إضافة مزود خدمة (API) أولاً من الإعدادات.")),
        );
      }
      return;
    }

    if (!mounted) return;

    String name = agentToEdit?.name ?? "";
    String desc = agentToEdit?.description ?? "";
    String sysPrompt = agentToEdit?.systemPrompt ?? "أنت مساعد ذكي.";
    
    String selectedProviderId = agentToEdit?.providerId ?? providers.first.id;
    if (agentToEdit != null && !providers.any((p) => p.id == agentToEdit.providerId)) {
      selectedProviderId = providers.first.id; 
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground, // ستايل داكن
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                agentToEdit == null ? "إنشاء وكيل جديد" : "تعديل الوكيل",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                      ),
                      onChanged: (v) => name = v,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      controller: TextEditingController(text: desc),
                      decoration: const InputDecoration(
                        labelText: "وصف قصير",
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                      ),
                      onChanged: (v) => desc = v,
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: selectedProviderId,
                      dropdownColor: AppColors.cardBackground,
                      iconEnabledColor: AppColors.primary,
                      items: providers.map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text("${p.name} (${p.modelName})", style: const TextStyle(color: Colors.white)),
                      )).toList(),
                      onChanged: (v) => setStateDialog(() => selectedProviderId = v!),
                      decoration: const InputDecoration(
                        labelText: "مزود الخدمة المرتبط",
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      controller: TextEditingController(text: sysPrompt),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "شخصية الوكيل (System Prompt)",
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
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
                      CloudProviderConfig selectedProvider = providers.firstWhere((p) => p.id == selectedProviderId);
                      
                      if (agentToEdit == null) {
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
                      _loadAgents();
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
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
                    onPressed: () => _showAgentDialog(), 
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
                            _loadAgents();
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