import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme.dart';
import '../skill_manager.dart';

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  List<Skill> _skills = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _skills = await SkillManager.loadSkills();
    setState(() => _isLoading = false);
  }

  void _showSkillDialog({Skill? skillToEdit}) {
    String name = skillToEdit?.name ?? "";
    String desc = skillToEdit?.description ?? "";
    String prompt = skillToEdit?.systemPrompt ?? "";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            skillToEdit == null ? "إضافة مهارة جديدة" : "تعديل المهارة",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  style: const TextStyle(color: Colors.white),
                  controller: TextEditingController(text: name),
                  decoration: const InputDecoration(
                    labelText: "اسم المهارة",
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 10),
                TextField(
                  style: const TextStyle(color: Colors.white),
                  controller: TextEditingController(text: desc),
                  decoration: const InputDecoration(
                    labelText: "وصف قصير",
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                  onChanged: (v) => desc = v,
                ),
                const SizedBox(height: 10),
                TextField(
                  style: const TextStyle(color: Colors.white),
                  controller: TextEditingController(text: prompt),
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: "التعليمات (System Prompt)",
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                  onChanged: (v) => prompt = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                if (name.isNotEmpty && prompt.isNotEmpty) {
                  if (skillToEdit == null) {
                    _skills.add(Skill(id: const Uuid().v4(), name: name, description: desc, systemPrompt: prompt));
                  } else {
                    int index = _skills.indexWhere((s) => s.id == skillToEdit.id);
                    if (index != -1) {
                      _skills[index] = Skill(id: skillToEdit.id, name: name, description: desc, systemPrompt: prompt);
                    }
                  }
                  await SkillManager.saveSkills(_skills);
                  _load();
                  if (mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text("حفظ", style: TextStyle(color: Colors.white)),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("إدارة المهارات"),
        backgroundColor: AppColors.background,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSkillDialog(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _skills.isEmpty 
          ? const Center(child: Text("لا توجد مهارات. أضف مهارة جديدة.", style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _skills.length,
              itemBuilder: (context, index) {
                final skill = _skills[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.extension, color: AppColors.primary),
                    title: Text(skill.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(skill.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: AppColors.textSecondary, size: 20),
                          onPressed: () => _showSkillDialog(skillToEdit: skill),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: AppColors.danger, size: 20),
                          onPressed: () async {
                            _skills.removeAt(index);
                            await SkillManager.saveSkills(_skills);
                            _load();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}