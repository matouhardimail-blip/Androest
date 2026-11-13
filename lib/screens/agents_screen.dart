import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme.dart';
import '../models/agent_model.dart';
import '../agent_manager.dart';
import '../cloud_provider.dart';
import '../online_api_service.dart';
import '../skill_manager.dart';
import 'chat_screen.dart';

class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  List<AgentModel> _agents = [];
  List<CloudProviderConfig> _providers = [];
  List<Skill> _availableSkills = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    setState(() => _isLoading = true);
    _agents = await AgentManager.loadAgents();
    _providers = await CloudConfigManager.loadProviders();
    _availableSkills = await SkillManager.loadSkills();
    setState(() => _isLoading = false);
  }

  Future<void> _showAgentDialog({AgentModel? agentToEdit}) async {
    List<CloudProviderConfig> providers = await CloudConfigManager.loadProviders();

    if (providers.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الرجاء إضافة مزود خدمة أولاً.")));
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
              backgroundColor: AppColors.cardBackground, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(agentToEdit == null ? "إنشاء وكيل جديد" : "تعديل الوكيل", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      controller: TextEditingController(text: name),
                      decoration: const InputDecoration(labelText: "اسم الوكيل", labelStyle: TextStyle(color: AppColors.textSecondary), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                      onChanged: (v) => name = v,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      controller: TextEditingController(text: desc),
                      decoration: const InputDecoration(labelText: "وصف قصير", labelStyle: TextStyle(color: AppColors.textSecondary), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                      onChanged: (v) => desc = v,
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: selectedProviderId,
                      dropdownColor: AppColors.cardBackground,
                      items: providers.map((p) => DropdownMenuItem(value: p.id, child: Text("${p.name}", style: const TextStyle(color: Colors.white)))).toList(),
                      onChanged: (v) => setStateDialog(() => selectedProviderId = v!),
                      decoration: const InputDecoration(labelText: "مزود الخدمة", labelStyle: TextStyle(color: AppColors.textSecondary), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      controller: TextEditingController(text: sysPrompt),
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: "شخصية الوكيل", labelStyle: TextStyle(color: AppColors.textSecondary), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))),
                      onChanged: (v) => sysPrompt = v,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: () async {
                    if (name.isNotEmpty) {
                      CloudProviderConfig selectedProvider = providers.firstWhere((p) => p.id == selectedProviderId);
                      
                      if (agentToEdit == null) {
                        _agents.add(AgentModel(
                          id: const Uuid().v4(), name: name, description: desc, providerId: selectedProviderId, modelName: selectedProvider.modelName, systemPrompt: sysPrompt, icon: Icons.smart_toy, color: AppColors.primary,
                        ));
                      } else {
                        int index = _agents.indexWhere((a) => a.id == agentToEdit.id);
                        if (index != -1) {
                          _agents[index] = AgentModel(
                            id: agentToEdit.id, name: name, description: desc, providerId: selectedProviderId, modelName: selectedProvider.modelName, systemPrompt: sysPrompt, icon: agentToEdit.icon, color: agentToEdit.color, isConnected: agentToEdit.isConnected, skillIds: agentToEdit.skillIds,
                          );
                        }
                      }
                      await AgentManager.saveAgents(_agents);
                      _loadAgents();
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

  void _showAutoGenerateDialog() {
    if (_providers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("أضف مزود خدمة أولاً.")));
      return;
    }

    String prompt = "";
    int agentCount = 3;
    List<String> selectedSkillIds = [];
    bool isGenerating = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.amber), // تم التعديل هنا
                  SizedBox(width: 10),
                  Text("توليد فريق وكلاء", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const Text("صف الفريق الذي تريده، وحدد عدد الوكلاء والمهارات المشتركة.", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 15),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: "مثال: فريق من 4 وكلاء لتغطية أخبار كرة القدم...",
                        hintStyle: TextStyle(color: AppColors.textSecondary),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                      ),
                      onChanged: (v) => prompt = v,
                    ),
                    const SizedBox(height: 15),
                    
                    Row(
                      children: [
                        const Text("عدد الوكلاء: ", style: TextStyle(color: Colors.white)),
                        Expanded(
                          child: Slider(
                            value: agentCount.toDouble(),
                            min: 1, max: 6, divisions: 5,
                            label: agentCount.toString(),
                            activeColor: AppColors.primary,
                            onChanged: (val) => setStateDialog(() => agentCount = val.toInt()),
                          ),
                        ),
                        Text(agentCount.toString(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),

                    if (_availableSkills.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text("المهارات المشتركة (اختياري):", style: TextStyle(color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _availableSkills.map((skill) {
                          bool isSelected = selectedSkillIds.contains(skill.id);
                          return FilterChip(
                            label: Text(skill.name, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 12)),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.background,
                            checkmarkColor: Colors.white,
                            onSelected: (selected) {
                              setStateDialog(() {
                                if (selected) selectedSkillIds.add(skill.id);
                                else selectedSkillIds.remove(skill.id);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    if (isGenerating) ...[
                      const SizedBox(height: 20),
                      const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      const SizedBox(height: 10),
                      const Center(child: Text("جاري بناء الفريق... قد يستغرق هذا 30 ثانية", style: TextStyle(color: AppColors.primary, fontSize: 12))),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: isGenerating ? null : () => Navigator.pop(context), child: const Text("إلغاء", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: isGenerating || prompt.isEmpty ? null : () async {
                    setStateDialog(() => isGenerating = true);
                    CloudProviderConfig provider = _providers.first;
                    OnlineApiService api = OnlineApiService();
                    
                    try {
                      List<Map<String, String>>? agentsData = await api.generateAgentTeam(
                        provider: provider.providerType,
                        apiKey: provider.apiKey,
                        baseUrl: provider.baseUrl,
                        modelName: provider.modelName,
                        userPrompt: prompt,
                        numberOfAgents: agentCount,
                      );

                      if (agentsData != null && agentsData.isNotEmpty) {
                        for (var data in agentsData) {
                          _agents.add(AgentModel(
                            id: const Uuid().v4(),
                            name: data['name']!,
                            description: data['description']!,
                            providerId: provider.id,
                            modelName: provider.modelName,
                            systemPrompt: data['systemPrompt']!,
                            icon: Icons.group_work,
                            color: Colors.blueAccent,
                            skillIds: selectedSkillIds,
                          ));
                        }
                        await AgentManager.saveAgents(_agents);
                        _loadAgents();
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("تم توليد فريق من ${agentsData.length} وكلاء!"), backgroundColor: AppColors.success),
                          );
                        }
                      } else {
                        setStateDialog(() => isGenerating = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("فشل التوليد: الموديل لم يُرجع بيانات صالحة. جرب موديلاً آخر مثل GPT-4o."), backgroundColor: AppColors.danger, duration: Duration(seconds: 5)),
                          );
                        }
                      }
                    } catch (e) {
                      setStateDialog(() => isGenerating = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("حدث خطأ: $e"), backgroundColor: AppColors.danger, duration: const Duration(seconds: 5)),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text("توليد الفريق", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.auto_awesome, color: Colors.amber, size: 28), 
                        onPressed: _showAutoGenerateDialog,
                        tooltip: "توليد فريق وكلاء",
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 30),
                        onPressed: () => _showAgentDialog(), 
                      )
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _agents.isEmpty 
                  ? const Center(child: Text("لا يوجد وكلاء.", style: TextStyle(color: Colors.grey)))
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
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: agent.color.withOpacity(0.2), shape: BoxShape.circle),
                                  child: Icon(agent.icon, color: agent.color, size: 30),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(agent.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                      Text(agent.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text(agent.modelName, style: const TextStyle(color: AppColors.accentBlue, fontSize: 12)),
                                      if (agent.skillIds.isNotEmpty) ...[
                                         const SizedBox(height: 4),
                                         Text("مهارات: ${agent.skillIds.length}", style: const TextStyle(color: Colors.amber, fontSize: 11)),
                                      ]
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: AppColors.textSecondary, size: 22),
                                  onPressed: () => _showAgentDialog(agentToEdit: agent),
                                ),
                                const SizedBox(width: 5),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(agent: agent)));
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                  child: const Text("Open", style: TextStyle(fontWeight: FontWeight.bold)),
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