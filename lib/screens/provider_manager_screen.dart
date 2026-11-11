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

  // قائمة المزودين الافتراضيين
  final List<Map<String, String>> _defaultProviders = [
    {
      'name': 'Groq',
      'type': 'openai',
      'url': 'https://api.groq.com/openai/v1',
      'model': 'llama-3.3-70b-versatile',
      'desc': 'سريع جداً ومجاني (موصى به)'
    },
    {
      'name': 'OpenRouter',
      'type': 'openai',
      'url': 'https://openrouter.ai/api/v1',
      'model': 'google/gemini-2.0-flash-exp:free',
      'desc': 'العديد من الموديلات المجانية'
    },
    {
      'name': 'Google AI Studio',
      'type': 'openai',
      'url': 'https://generativelanguage.googleapis.com/v1beta/openai/',
      'model': 'gemini-1.5-flash',
      'desc': 'من جوجل، يدعم العربية بقوة'
    },
    {
      'name': 'Keyless AI',
      'type': 'openai',
      'url': 'https://keylessai.thryx.workers.dev/v1',
      'model': 'gpt-4o-mini',
      'desc': 'بدون مفتاح API نهائياً'
    }
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final providers = await CloudConfigManager.loadProviders();
    setState(() => _providers = providers);
  }

  // الخطوة 1: اختيار نوع المزود
  void _showProviderOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("اختر مزود الخدمة", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(color: Colors.white12),
              ..._defaultProviders.map((p) => ListTile(
                leading: const Icon(Icons.bolt, color: AppColors.primary),
                title: Text(p['name']!, style: const TextStyle(color: Colors.white)),
                subtitle: Text(p['desc']!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context); // إغلاق النافذة السفلية
                  _showAddProviderDialog(
                    presetName: p['name'],
                    presetType: p['type'],
                    presetUrl: p['url'],
                    presetModel: p['model'],
                  );
                },
              )).toList(),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.settings, color: AppColors.textSecondary),
                title: const Text("مزود مخصص (Custom)", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showAddProviderDialog(); // نافذة فارغة
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // الخطوة 2: إدخال المفتاح (والبيانات إذا كان مخصصاً)
  void _showAddProviderDialog({
    String? presetName,
    String? presetType,
    String? presetUrl,
    String? presetModel,
  }) {
    bool isCustom = presetName == null;
    
    String name = presetName ?? "";
    String type = presetType ?? "openai";
    String key = presetName == "Keyless AI" ? "sk-no-key-required" : ""; // إذا كان Keyless نضع مفتاحاً وهمياً
    String baseUrl = presetUrl ?? "https://api.openai.com/v1";
    String model = presetModel ?? "gpt-4o";
    List<AgentCapability> selectedCaps = [AgentCapability.textGeneration];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                isCustom ? "إضافة مزود مخصص" : "ربط مزود: $name",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (isCustom) ...[
                      TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "اسم المزود",
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        ),
                        onChanged: (v) => name = v,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: type,
                        dropdownColor: AppColors.cardBackground,
                        items: const [
                          DropdownMenuItem(value: "openai", child: Text("OpenAI / متوافق", style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: "anthropic", child: Text("Anthropic (Claude)", style: TextStyle(color: Colors.white))),
                        ],
                        onChanged: (v) => setStateDialog(() => type = v!),
                        decoration: const InputDecoration(
                          labelText: "نوع المزود",
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Base URL",
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        ),
                        controller: TextEditingController(text: baseUrl),
                        onChanged: (v) => baseUrl = v,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Model Name",
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        ),
                        controller: TextEditingController(text: model),
                        onChanged: (v) => model = v,
                      ),
                      const SizedBox(height: 10),
                    ],

                    // حقل الـ API Key يظهر للجميع (عدا Keyless يمكن إخفاؤه أو تعطيله)
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      obscureText: true,
                      enabled: name != "Keyless AI",
                      controller: TextEditingController(text: key),
                      decoration: InputDecoration(
                        labelText: name == "Keyless AI" ? "لا يتطلب مفتاح" : "API Key",
                        labelStyle: const TextStyle(color: AppColors.textSecondary),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                      ),
                      onChanged: (v) => key = v,
                    ),
                    
                    if (isCustom) ...[
                      const SizedBox(height: 20),
                      const Text("القدرات (Capabilities):", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      Wrap(
                        spacing: 8,
                        children: AgentCapability.values.map((cap) {
                          return FilterChip(
                            label: Text(cap.name, style: TextStyle(color: selectedCaps.contains(cap) ? Colors.white : Colors.grey, fontSize: 12)),
                            selected: selectedCaps.contains(cap),
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.background,
                            checkmarkColor: Colors.white,
                            onSelected: (selected) {
                              setStateDialog(() {
                                if (selected) selectedCaps.add(cap);
                                else selectedCaps.remove(cap);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: () async {
                    if (name.isNotEmpty && (key.isNotEmpty || name == "Keyless AI")) {
                      _providers.add(CloudProviderConfig(
                        id: const Uuid().v4(),
                        name: name,
                        providerType: type,
                        apiKey: key,
                        baseUrl: baseUrl,
                        modelName: model,
                        capabilities: isCustom ? selectedCaps : [AgentCapability.textGeneration],
                      ));
                      await CloudConfigManager.saveProviders(_providers);
                      _load();
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("إدارة مزودي الخدمة"),
        backgroundColor: AppColors.background,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showProviderOptions, // نستدعي دالة اختيار النوع أولاً
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _providers.isEmpty 
        ? const Center(child: Text("لم تقم بإضافة أي مزود خدمة بعد.", style: TextStyle(color: Colors.grey)))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _providers.length,
            itemBuilder: (context, index) {
              final p = _providers[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  title: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text("${p.providerType} - ${p.modelName}\nالقدرات: ${p.capabilities.map((e) => e.name).join(', ')}", style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: AppColors.danger),
                    onPressed: () async {
                      _providers.removeAt(index);
                      await CloudConfigManager.saveProviders(_providers);
                      _load();
                    },
                  ),
                ),
              );
            },
          ),
    );
  }
}