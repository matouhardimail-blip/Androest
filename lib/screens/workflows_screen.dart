import 'package:flutter/material.dart';
import '../theme.dart';
import '../workflow_manager.dart';
import '../models/workflow_model.dart';
import 'package:intl/intl.dart';

class WorkflowsScreen extends StatefulWidget {
  const WorkflowsScreen({super.key});

  @override
  State<WorkflowsScreen> createState() => _WorkflowsScreenState();
}

class _WorkflowsScreenState extends State<WorkflowsScreen> {
  List<WorkflowModel> _workflows = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _workflows = await WorkflowManager.loadWorkflows();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          backgroundColor: AppColors.cardBackground,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _workflows.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        const Icon(Icons.history, size: 60, color: AppColors.textSecondary),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            "لا توجد مهام سابقة.\nاذهب إلى شاشة (Create) لبدء مهمة جديدة.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _workflows.length,
                      itemBuilder: (context, index) {
                        final wf = _workflows[index];
                        return _buildWorkflowCard(wf);
                      },
                    ),
        ),
      ),
    );
  }

  Widget _buildWorkflowCard(WorkflowModel wf) {
    Color statusColor;
    String statusText;
    
    if (wf.status == 'completed') {
      statusColor = AppColors.success;
      statusText = 'Completed';
    } else if (wf.status == 'running') {
      statusColor = AppColors.primary;
      statusText = 'Running';
    } else {
      statusColor = AppColors.danger;
      statusText = 'Failed';
    }

    String formattedTime = DateFormat('MMM d, h:mm a').format(wf.timestamp);

    return GestureDetector(
      onTap: () {
        // عرض تفاصيل المهمة عند الضغط
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.cardBackground,
            title: Text(wf.taskTitle, style: const TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Text(wf.finalResult, style: const TextStyle(color: AppColors.textSecondary)),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("إغلاق", style: TextStyle(color: AppColors.primary)))
            ],
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    wf.taskTitle, 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(formattedTime, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}