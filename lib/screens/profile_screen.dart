import 'package:flutter/material.dart';
import '../theme.dart';
import 'provider_manager_screen.dart';
import '../update_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUpdating = false;
  double _progress = 0.0;

  void _handleUpdate() async {
    setState(() {
      _isUpdating = true;
      _progress = 0.0;
    });

    UpdateService updateService = UpdateService();
    String status = await updateService.checkAndUpdate((progress) {
      setState(() {
        _progress = progress;
      });
    });

    if (mounted) {
      setState(() {
        _isUpdating = false;
      });

      if (status == "no_update") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("أنت تستخدم أحدث نسخة من التطبيق."),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (status == "error") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("فشل التحديث أو تم إلغاؤه."),
            backgroundColor: AppColors.danger,
          ),
        );
      }
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
                decoration: BoxDecoration(
                  color: AppColors.cardBackground, 
                  borderRadius: BorderRadius.circular(20)
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
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2), 
                              borderRadius: BorderRadius.circular(10)
                            ),
                            child: const Text("Premium Plan", style: TextStyle(color: AppColors.primary, fontSize: 12)),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              GestureDetector(
                onTap: _isUpdating ? null : _handleUpdate,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground, 
                    borderRadius: BorderRadius.circular(15)
                  ),
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
                              LinearProgressIndicator(
                                value: _progress > 0 ? _progress : null, 
                                color: AppColors.primary,
                                backgroundColor: AppColors.textSecondary.withOpacity(0.2),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${(_progress * 100).toStringAsFixed(1)}%", 
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)
                              ),
                            ]
                          ],
                        ),
                      ),
                      if (!_isUpdating)
                        const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),

              _buildSettingItem(
                context,
                Icons.key, 
                "API Keys & Connections",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProviderManagerScreen()),
                  );
                }
              ),
              _buildSettingItem(
                context, 
                Icons.settings, 
                "App Preferences",
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("قريباً...")));
                }
              ),
              _buildSettingItem(
                context, 
                Icons.language, 
                "Language (Arabic / English)",
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("قريباً...")));
                }
              ),
              _buildSettingItem(
                context, 
                Icons.info, 
                "About AI HUB",
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: "AI HUB",
                    applicationVersion: "1.0.0",
                    applicationLegalese: "All AI Agents in One Place",
                  );
                }
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
        decoration: BoxDecoration(
          color: AppColors.cardBackground, 
          borderRadius: BorderRadius.circular(15)
        ),
        child: ListTile(
          leading: Icon(icon, color: AppColors.textSecondary),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}