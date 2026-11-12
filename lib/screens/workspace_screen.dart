import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../theme.dart';
import '../mcp_tools.dart';
import '../export_service.dart'; // استدعاء خدمة التصدير

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  List<FileSystemEntity> _files = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String _baseDir = McpTools.baseDir;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      Directory dir = Directory(_baseDir);
      if (await dir.exists()) {
        var entities = dir.listSync(recursive: true);
        _files = entities.where((e) => e is File).toList();
      } else {
        _files = [];
      }
    } catch (e) {
      _files = [];
    }
    setState(() => _isLoading = false);
  }

  void _openFile(File file) async {
    String content = await file.readAsString();
    String fileName = p.basename(file.path);
    String relativePath = file.path.replaceAll('$_baseDir/', '');

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FileEditorScreen(
          file: file,
          fileName: fileName,
          relativePath: relativePath,
          initialContent: content,
        ),
      ),
    ).then((_) => _loadFiles());
  }

  // دالة تصدير المشروع كملف ZIP
  Future<void> _exportProject() async {
    setState(() => _isExporting = true);
    
    String zipName = 'AI_HUB_Project_${DateTime.now().millisecondsSinceEpoch}.zip';
    File? zipFile = await ExportService.zipProjectFolder(_baseDir, zipName);

    setState(() => _isExporting = false);

    if (zipFile != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("تم تصدير المشروع بنجاح إلى: ${zipFile.path}"),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: "مشاركة",
              textColor: Colors.white,
              onPressed: () => ExportService.shareZipFile(zipFile),
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("لا توجد ملفات لتصديرها، أو حدث خطأ."), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("مساحة العمل (المشاريع)"),
        backgroundColor: AppColors.background,
        actions: [
          if (_files.isNotEmpty)
            IconButton(
              icon: _isExporting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.file_download, color: AppColors.success),
              tooltip: "تصدير المشروع كملف ZIP",
              onPressed: _isExporting ? null : _exportProject,
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadFiles,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 60, color: AppColors.textSecondary),
                      SizedBox(height: 16),
                      Text(
                        "لا توجد ملفات حتى الآن.\nاطلب من الوكيل إنشاء مشروع وسيظهر هنا.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index] as File;
                    String relativePath = file.path.replaceAll('$_baseDir/', '');
                    String fileName = p.basename(file.path);
                    String folderPath = p.dirname(relativePath);
                    if (folderPath == '.') folderPath = 'الرئيسي';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.insert_drive_file, color: AppColors.primary),
                        title: Text(fileName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(folderPath, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                        onTap: () => _openFile(file),
                      ),
                    );
                  },
                ),
    );
  }
}

// شاشة عرض وتعديل الملف
class FileEditorScreen extends StatefulWidget {
  final File file;
  final String fileName;
  final String relativePath;
  final String initialContent;

  const FileEditorScreen({
    super.key,
    required this.file,
    required this.fileName,
    required this.relativePath,
    required this.initialContent,
  });

  @override
  State<FileEditorScreen> createState() => _FileEditorScreenState();
}

class _FileEditorScreenState extends State<FileEditorScreen> {
  late TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  Future<void> _saveFile() async {
    setState(() => _isSaving = true);
    try {
      await widget.file.writeAsString(_controller.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم حفظ التعديلات بنجاح"), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("فشل الحفظ: $e"), backgroundColor: AppColors.danger),
        );
      }
    }
    setState(() => _isSaving = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.fileName, style: const TextStyle(fontSize: 16)),
            Text(widget.relativePath, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, color: AppColors.primary),
            onPressed: _isSaving ? null : _saveFile,
            tooltip: "حفظ التعديلات",
          )
        ],
      ),
      body: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'monospace',
            fontSize: 14,
            height: 1.5,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: "// الملف فارغ",
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }
} 