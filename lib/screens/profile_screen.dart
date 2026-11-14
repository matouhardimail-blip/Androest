import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'dart:io';
import '../theme.dart';
import 'provider_manager_screen.dart';
import 'skills_screen.dart';
import '../update_service.dart';
import '../notification_service.dart';
import '../model_manager.dart';
import '../settings_manager.dart'; 
import '../cloud_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUpdating = false;
  double _updateProgress = 0.0;

  final ModelManager _modelManager = ModelManager();
  bool _isDownloadingModel = false;
  double _modelProgress = 0.0;
  bool _isModelReady = false;

  String _userName = "";
  bool _isDarkMode = true;
  String? _defaultProviderId;
  List<CloudProviderConfig> _providers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    File? file = await _modelManager.getModelFile();
    String name = await SettingsManager.getUserName();
    bool isDark = await SettingsManager.isDarkMode();
    String? providerId = await SettingsManager.getDefaultProviderId();
    List<CloudProviderConfig> providers = await CloudConfigManager.loadProviders();

    setState(() {
      _isModelReady = file != null;
      _userName = name;
      _isDarkMode = isDark;
      _defaultProviderId = providerId;
      _providers = providers;
    });
  }

  void _handleUpdate() async {
    setState(() {
      _isUpdating = true;
      _updateProgress = 0.0;
    });

    UpdateService updateService = UpdateService();
    String status = await updateService.checkAndUpdate((progress) {
      setState(() => _updateProgress = progress);
    });

    if (mounted) {
      setState(() => _isUpdating = false);
      if (status == "no_update") {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("أنت تستخدم أحدث نسخة من التطبيق."), backgroundColor: AppColors.success));
      } else if (status == "error") {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل التحديث. تأكد من الإنترنت أو من وجود إصدار جديد."), backgroundColor: AppColors.danger));
      } else if (status == "success") {
         NotificationService.showNotification("تحديث AI HUB", "تم تحميل النسخة الجديدة بنجاح، جاري التثبيت...");
      }
    }
  }

  void _downloadLocalModel() async {
    setState(() {
      _isDownloadingModel = true;
      _modelProgress = 0.0;
    });

    try {
      await _modelManager.downloadModel((progress) {
        setState(() => _modelProgress = progress);
      });
      setState(() {
        _isDownloadingModel = false;
        _isModelReady = true;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم التحميل بنجاح!"), backgroundColor: AppColors.success));
    } catch (e) {
      setState(() => _isDownloadingModel = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("فشل التحميل: $e"), backgroundColor: AppColors.danger));
    }
  }

  void _editNameDialog() {
    String tempName = _userName;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text("تعديل الاسم", style: TextStyle(color: Colors.white)),
        content: TextField(
          style: const TextStyle(color: Colors.white),
          controller: TextEditingController(text: tempName),
          decoration: const InputDecoration(
            labelText: "اسمك",
            labelStyle: TextStyle(color: AppColors.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
          onChanged: (v) => tempName = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              if (tempName.isNotEmpty) {
                await SettingsManager.setUserName(tempName);
                setState(() => _userName = tempName);
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text("حفظ", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _factoryResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text("مسح جميع البيانات", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
        content: const Text("هل أنت متأكد؟ سيتم حذف جميع الوكلاء، المحادثات، المشاريع، والإعدادات نهائياً. لا يمكن التراجع عن هذا الإجراء.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              await SettingsManager.factoryReset();
              if (mounted) {
                Navigator.pop(context);
                SystemNavigator.pop(); 
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text("نعم، احذف كل شيء", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GestureDetector(
                onTap: _editNameDialog,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground, 
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.person, size: 40, color: Colors.white),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                const Icon(Icons.edit, size: 14, color: AppColors.textSecondary),
                              ],
                            ),
                            const Text("اضغط لتعديل الاسم", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),

              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground, 
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    if (_providers.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: _defaultProviderId ?? _providers.first.id,
                        dropdownColor: AppColors.cardBackground,
                        iconEnabledColor: AppColors.primary,
                        items: _providers.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(color: Colors.white)))).toList(),
                        onChanged: (val) async {
                          if (val != null) {
                            await SettingsManager.setDefaultProviderId(val);
                            setState(() => _defaultProviderId = val);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: "المزود الافتراضي للتوليد التلقائي",
                          labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.transparent)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.transparent)),
                        ),
                      ),
                    
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("الوضع الداكن (Dark Mode)", style: TextStyle(color: Colors.white, fontSize: 15)),
                      value: _isDarkMode,
                      activeColor: AppColors.primary,
                      onChanged: (val) async {
                        await SettingsManager.setThemeMode(val);
                        setState(() => _isDarkMode = val);
                        themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light; 
                      },
                    ),
                  ],
                ),
              ),

              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground, 
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.offline_bolt, color: AppColors.success, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text("الموديل المحلي (بدون إنترنت)", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isDownloadingModel) ...[
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: _modelProgress, color: AppColors.primary, minHeight: 8)),
                      const SizedBox(height: 5),
                      Text("${(_modelProgress * 100).toStringAsFixed(1)}%", style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                    ] else if (_isModelReady) ...[
                      const Text("الموديل جاهز للاستخدام أوفلاين.", style: TextStyle(color: AppColors.success, fontSize: 14)),
                    ] else ...[
                      const Text("قم بتحميل الموديل للعمل بدون إنترنت.", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity, height: 45,
                        child: ElevatedButton.icon(
                          onPressed: _downloadLocalModel,
                          icon: const Icon(Icons.download, size: 20),
                          label: const Text("تحميل الموديل"),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      )
                    ]
                  ],
                ),
              ),

              _buildSettingItem(context, Icons.update, "تحديث التطبيق", onTap: _isUpdating ? null : _handleUpdate),
              _buildSettingItem(context, Icons.extension, "إدارة المهارات (Skills)", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SkillsScreen()))),
              _buildSettingItem(context, Icons.key, "API Keys & Connections", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProviderManagerScreen()))),

              const SizedBox(height: 30),
              
              TextButton.icon(
                onPressed: _factoryResetDialog,
                icon: const Icon(Icons.delete_forever, color: AppColors.danger),
                label: const Text("مسح جميع البيانات (Factory Reset)", style: TextStyle(color: AppColors.danger)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem(BuildContext context, IconData icon, String title, {required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle), child: Icon(icon, color: AppColors.textPrimary, size: 20)),
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}