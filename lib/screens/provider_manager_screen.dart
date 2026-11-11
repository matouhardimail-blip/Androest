import 'package:flutter/material.dart';
import '../theme.dart';
import '../cloud_provider.dart';
import 'package:uuid/uuid.dart';

class ProviderManagerScreen extends StatefulWidget {
  const ProviderManagerScreen({super.key});

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
              backgroundColor: AppColors.cardBackground,
              title: const Text("إضافة وكيل / مزود خدمة", style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "اسم الوكيل", labelStyle: TextStyle(color: AppColors.textSecondary)), 
                      onChanged: (v) => name = v
                    ),
                    DropdownButtonFormField<String>(
                      value: type,
                      dropdownColor: AppColors.cardBackground,
                      items: const [
                        DropdownMenuItem(value: "openai", child: Text("OpenAI (أو متوافق)", style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: "anthropic", child: Text("Anthropic (Claude)", style: TextStyle(color: Colors.white))),
                      ],
                      onChanged: (v) {
                        setStateDialog(() {
                          type = v!;
                          baseUrl = type == "anthropic" ? "https://api.anthropic.com" : "https://api.openai.com/v1";
                          model = type == "anthropic" ? "claude-3-5-sonnet-20240620" : "gpt-4o";
                        });
                      },
                      decoration: const InputDecoration(labelText: "المزود", labelStyle: TextStyle(color: AppColors.textSecondary)),
                    ),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "API Key", labelStyle: TextStyle(color: AppColors.textSecondary)), 
                      onChanged: (v) => key = v
                    ),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Base URL", labelStyle: TextStyle(color: AppColors.textSecondary)), 
                      controller: TextEditingController(text: baseUrl), 
                      onChanged: (v) => baseUrl = v
                    ),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Model Name", labelStyle: TextStyle(color: AppColors.textSecondary)), 
                      controller: TextEditingController(text: model), 
                      onChanged: (v) => model = v
                    ),
                    const SizedBox(height: 15),
                    const Text("القدرات (Capabilities):", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    Wrap(
                      spacing: 8,
                      children: AgentCapability.values.map((cap) {
                        return FilterChip(
                          label: Text(cap.name, style: TextStyle(color: selectedCaps.contains(cap) ? Colors.white : Colors.grey)),
                          selected: selectedCaps.contains(cap),
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.background,
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
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء", style: TextStyle(color: Colors.grey))),
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text("إضافة", style: TextStyle(color: Colors.white)),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("إدارة مزودي الخدمة")),
      floatingActionButton: FloatingActionButton(onPressed: _addProvider, backgroundColor: AppColors.primary, child: const Icon(Icons.add)),
      body: ListView.builder(
        itemCount: _providers.length,
        itemBuilder: (context, index) {
          final p = _providers[index];
          return ListTile(
            title: Text(p.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text("${p.providerType} - ${p.modelName}\nالقدرات: ${p.capabilities.map((e) => e.name).join(', ')}", style: const TextStyle(color: AppColors.textSecondary)),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: AppColors.danger),
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