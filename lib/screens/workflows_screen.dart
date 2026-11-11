import 'package:flutter/material.dart';
import '../theme.dart';

class WorkflowsScreen extends StatelessWidget {
  const WorkflowsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text("Recent Activity", style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 20),
            _buildWorkflowCard(context, "Website Project", "Completed", AppColors.success, "2 min ago"),
            _buildWorkflowCard(context, "Trading Analysis XAUUSD", "Running", AppColors.primary, "10 min ago"),
            _buildWorkflowCard(context, "Email Automation", "Failed", AppColors.danger, "1 hour ago"),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowCard(BuildContext context, String title, String status, Color statusColor, String time) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("فتح تفاصيل: $title")),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(15)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: Text(status, style: TextStyle(color: statusColor, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(time, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}