import 'package:flutter/material.dart';
import 'dart:io'; 
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
              // بطاقة المستخدم
              Container(
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
                          const Text("User Name", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const Text("user@example.com", style: TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                            child: const Text("Premium Plan", style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // قسم الموديل المحلي بتصميم أفضل
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
                      const Text("جاري التحميل...", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(value: _modelProgress, color: AppColors.primary, minHeight: 8),
                      ),
                      const SizedBox(height: 5),
                      Text("${(_modelProgress * 100).toStringAsFixed(1)}%", style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ] else if (_isModelReady) ...[
                      const Text("الموديل جاهز للاستخدام أوفلاين.", style: TextStyle(color: AppColors.success, fontSize: 14)),
                      const SizedBox(height: 10),
                      const Text("للاستخدام: أضف مزود خدمة جديد واختر النوع (Local).", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ] else ...[
                      const Text("قم بتحميل الموديل (1.67 جيجا) لاستخدامه بدون إنترنت.", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton.icon(
                          onPressed: _downloadLocalModel,
                          icon: const Icon(Icons.download, size: 20),
                          label: const Text("تحميل الموديل", style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      )
                    ]
                  ],
                ),
              ),

              // زر التحديث
              GestureDetector(
                onTap: _isUpdating ? null : _handleUpdate,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground, 
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.accentBlue.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.update, color: AppColors.accentBlue, size: 20),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("تحديث التطبيق", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            if (_isUpdating) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(value: _updateProgress > 0 ? _updateProgress : null, color: AppColors.primary, minHeight: 6),
                              ),
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
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground, 
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.textPrimary, size: 20),
          ),
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}