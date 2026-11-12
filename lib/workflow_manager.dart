import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/workflow_model.dart';

class WorkflowManager {
  static const String _key = 'workflow_history';

  static Future<List<WorkflowModel>> loadWorkflows() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_key);
    if (data == null || data.isEmpty) return [];
    
    try {
      List decoded = jsonDecode(data);
      List<WorkflowModel> workflows = decoded.map((e) => WorkflowModel.fromJson(e)).toList();
      workflows.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // الأحدث أولاً
      return workflows;
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveWorkflow(WorkflowModel workflow) async {
    List<WorkflowModel> workflows = await loadWorkflows();
    workflows.insert(0, workflow); // إضافة الجديد في البداية
    
    // الاحتفاظ بآخر 20 مهمة فقط
    if (workflows.length > 20) {
      workflows = workflows.sublist(0, 20);
    }

    final prefs = await SharedPreferences.getInstance();
    String data = jsonEncode(workflows.map((e) => e.toJson()).toList());
    await prefs.setString(_key, data);
  }
}