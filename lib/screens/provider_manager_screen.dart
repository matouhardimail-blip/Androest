import 'package:flutter/material.dart';
import '../theme.dart';
import '../cloud_provider.dart';
import '../online_api_service.dart';
import 'package:uuid/uuid.dart';

class ProviderManagerScreen extends StatefulWidget {
  const ProviderManagerScreen({super.key});

  @override
  State<ProviderManagerScreen> createState() => _ProviderManagerScreenState();
}

class _ProviderManagerScreenState extends State<ProviderManagerScreen> {
  List<CloudProviderConfig> _providers = [];
  final OnlineApiService _api = OnlineApiService();

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
      'name': 'الموديل المحلي (Local)',
      'type': 'local',
      'url': 'local',
      'model': 'agentic_arabic_2.6b.gguf',
      'desc': 'يعمل بدون إنترنت (يجب تحميله أولاً)'
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
                leading: Icon(
                  p['type'] == 'local' ? Icons.offline_bolt : Icons.bolt, 
                  color: p['type'] == 'local' ? AppColors.success : AppColors.primary
                ),
                title: Text(p['name']!, style: const TextStyle(color: Colors.white)),
                subtitle: Text(p['desc']!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
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
                  _showAddProviderDialog(); 
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showAddProviderDialog({
    String? presetName,
    String? presetType,
    String? presetUrl,
    String? presetModel,
  }) {
    bool isCustom = presetName == null;
    bool isLocal = presetType == 'local';
    
    String name = presetName ?? "";
    String type = presetType ?? "openai";
    String key = isLocal ? "local" : "";
    String baseUrl = presetUrl ?? "https://api.openai.com/v1";
    String model = presetModel ?? "gpt-4o";
    List<AgentCapability> selectedCaps = [AgentCapability.textGeneration];

    bool isTesting = false;
    bool testPassed = isLocal; // إذا كان محلياً، نعتبره جاهزاً

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            
            Future<void> testConnection() async {
              if (!isLocal && key.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إدخال مفتاح API أولاً")));
                return;
              }
              if (isLocal) {
                setStateDialog(() => testPassed = true);
                return;
              }

              setStateDialog(() => isTesting = true);
              
              String? error = await _api.testConnection(
                provider: type,
                apiKey: key,
                baseUrl: baseUrl,
                modelName: model,
              );

              setStateDialog(() {
                isTesting = false;
                if (error == null) {
                  testPassed = true;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("✅ تم الاتصال بنجاح!"), backgroundColor: AppColors.success),
                  );
                } else {
                  testPassed = false;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("❌ فشل الاتصال: $error"), backgroundColor: AppColors.danger, duration: const Duration(seconds: 5)),
                  );
                }
              });
            }

            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                isCustom ? "إضافة مزود مخصص" : "ربط مزود: $presetName",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "اسم المزود",
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      controller: TextEditingController(text: name),
                      onChanged: (v) { name = v; setStateDialog(() => testPassed = isLocal); },
                    ),
                    const SizedBox(height: 10),
                    if (isCustom) ...[
                      DropdownButtonFormField<String>(
                        value: type,
                        dropdownColor: AppColors.cardBackground,
                        items: const [
                          DropdownMenuItem(value: "openai", child: Text("OpenAI / متوافق", style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: "anthropic", child: Text("Anthropic (Claude)", style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: "local", child: Text("Local (بدون إنترنت)", style: TextStyle(color: Colors.white))),
                        ],
                        onChanged: (v) { setStateDialog(() { type = v!; isLocal = type == 'local'; testPassed = isLocal; }); },
                        decoration: const InputDecoration(
                          labelText: "نوع المزود",
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    
                    if (!isLocal) ...[
                      TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Base URL",
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        ),
                        controller: TextEditingController(text: baseUrl),
                        onChanged: (v) { baseUrl = v; setStateDialog(() => testPassed = false); },
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
                        onChanged: (v) { model = v; setStateDialog(() => testPassed = false); },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        style: const TextStyle(color: Colors.white),
                        obscureText: true,
                        controller: TextEditingController(text: key),
                        decoration: InputDecoration(
                          labelText: "API Key",
                          labelStyle: const TextStyle(color: AppColors.textSecondary),
                          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                          suffixIcon: testPassed 
                            ? const Icon(Icons.check_circle, color: AppColors.success) 
                            : null,
                        ),
                        onChanged: (v) { key = v; setStateDialog(() => testPassed = false); },
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isTesting ? null : testConnection,
                          icon: isTesting 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                            : const Icon(Icons.network_check, color: AppColors.primary),
                          label: Text(
                            isTesting ? "جاري الفحص..." : "فحص الاتصال (Test)",
                            style: const TextStyle(color: AppColors.primary),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ] else ...[
                      const Text("الموديل المحلي يعمل بدون إنترنت. لا يتطلب رابطاً أو مفتاحاً.", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: testPassed ? () async {
                    _providers.add(CloudProviderConfig(
                      id: const Uuid().v4(),
                      name: name,
                      providerType: isLocal ? "local" : type,
                      apiKey: key,
                      baseUrl: baseUrl,
                      modelName: isLocal ? "Local Model" : model,
                      capabilities: [AgentCapability.textGeneration],
                    ));
                    await CloudConfigManager.saveProviders(_providers);
                    _load();
                    if (mounted) Navigator.pop(context);
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: testPassed ? AppColors.success : Colors.grey.withOpacity(0.3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text("إضافة وحفظ", style: TextStyle(color: testPassed ? Colors.white : Colors.grey)),
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
        onPressed: _showProviderOptions,
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
                  leading: Icon(
                    p.providerType == 'local' ? Icons.offline_bolt : Icons.cloud, 
                    color: p.providerType == 'local' ? AppColors.success : AppColors.primary
                  ),
                  title: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text("${p.providerType} - ${p.modelName}", style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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