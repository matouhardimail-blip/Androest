import 'package:flutter/material.dart';
import 'dart:io'; // <--- تم إضافة هذا الاستيراد
import '../theme.dart';
import 'provider_manager_screen.dart';
import 'skills_screen.dart';
import '../update_service.dart';
import '../notification_service.dart';
import '../model_manager.dart';

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

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
  }

  Future<void> _checkModelStatus() async {
    File? file = await _modelManager.getModelFile();
    setState(() => _isModelReady = file != null);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("أنت تستخدم أحدث نسخة من التطبيق."), backgroundColor: AppColors.success),
        );
      } else if (status == "error") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("فشل التحديث أو تم إلغاؤه."), backgroundColor: AppColors.danger),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم تحميل الموديل المحلي بنجاح!"), backgroundColor: AppColors.success),
      );
    } catch (e) {
      setState(() => _isDownloadingModel = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("فشل التحميل: $e"), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(20)),
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
                          const Text("User Name", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const Text("user@example.com", style: TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                            child: const Text("Premium Plan", style: TextStyle(color: AppColors.primary, fontSize: 12)),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // قسم الموديل المحلي
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(15)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.offline_bolt, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text("الموديل المحلي (العمل بدون إنترنت)", style: TextStyle(color: Colors.white, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_isDownloadingModel) ...[
                      LinearProgressIndicator(value: _modelProgress, color: AppColors.primary),
                      const SizedBox(height: 5),
                      Text("${(_modelProgress * 100).toStringAsFixed(1)}%", style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ] else if (_isModelReady) ...[
                      const Text("الموديل جاهز للاستخدام.", style: TextStyle(color: AppColors.success, fontSize: 14)),
                      const SizedBox(height: 10),
                      const Text("للاستخدام: اذهب إلى إدارة المزودين، أضف مزوداً جديداً واختر النوع (Local) بدون مفتاح API.", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ] else ...[
                      const Text("قم بتحميل الموديل (1.67 جيجا) لاستخدامه بدون إنترنت.", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _downloadLocalModel,
                          icon: const Icon(Icons.download),
                          label: const Text("تحميل الموديل المحلي"),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        ),
                      )
                    ]
                  ],
                ),
              ),

              GestureDetector(
                onTap: _isUpdating ? null : _handleUpdate,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(15)),
                  child: Row(
                    children: [
                      const Icon(Icons.update, color: AppColors.success),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("تحديث التطبيق لأحدث نسخة", style: TextStyle(color: Colors.white, fontSize: 16)),
                            if (_isUpdating) ...[
                              const SizedBox(height: 8),
                              LinearProgressIndicator(value: _updateProgress > 0 ? _updateProgress : null, color: AppColors.primary),
                              const SizedBox(height: 4),
                              Text("${(_updateProgress * 100).toStringAsFixed(1)}%", style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ]
                          ],
                        ),
                      ),
                      if (!_isUpdating) const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),

              _buildSettingItem(
                context,
                Icons.extension, 
                "إدارة المهارات (Skills)",
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SkillsScreen()))
              ),
              _buildSettingItem(
                context,
                Icons.key, 
                "API Keys & Connections",
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProviderManagerScreen()))
              ),
              _buildSettingItem(
                context, 
                Icons.info, 
                "About AI HUB",
                onTap: () => showAboutDialog(context: context, applicationName: "AI HUB", applicationVersion: "1.0.0")
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem(BuildContext context, IconData icon, String title, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(15)),
        child: ListTile(
          leading: Icon(icon, color: AppColors.textSecondary),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}