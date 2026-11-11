import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

class ModelManager {
  static const String defaultUrl = 'https://huggingface.co/DarkStrox/Agentic-Arabic-2.6-GGUF/resolve/main/LFM2.5-2.6B.Q4_K_M.gguf';
  static const String fileName = 'agentic_arabic_2.6b.gguf';

  Future<String> getDefaultDirectory() async {
    final dir = await getExternalStorageDirectory();
    return dir!.path;
  }

  Future<String> getSavedDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('model_dir') ?? await getDefaultDirectory();
  }

  Future<String> getSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('model_url') ?? defaultUrl;
  }

  Future<void> saveSettings(String dir, String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('model_dir', dir);
    await prefs.setString('model_url', url);
  }

  Future<File?> getModelFile() async {
    String dirPath = await getSavedDirectory();
    final file = File(p.join(dirPath, fileName));
    if (await file.exists()) return file;
    return null;
  }

  Future<String?> pickDirectory() async {
    String? selectedDirectory = await getDirectoryPath();
    if (selectedDirectory != null) {
      String currentUrl = await getSavedUrl();
      await saveSettings(selectedDirectory, currentUrl);
      return selectedDirectory;
    }
    return null;
  }

  Future<File?> pickAndCopyModelFile() async {
    const typeGroup = XTypeGroup(label: 'GGUF Models', extensions: ['gguf']);
    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
    
    if (file != null) {
      File pickedFile = File(file.path);
      String dirPath = await getSavedDirectory();
      String newPath = p.join(dirPath, fileName);
      await pickedFile.copy(newPath);
      return File(newPath);
    }
    return null;
  }

  Future<File> downloadModel(String url, Function(double) onProgress) async {
    String dirPath = await getSavedDirectory();
    String finalPath = p.join(dirPath, fileName);
    String tempPath = '$finalPath.tmp';

    final dio = Dio();
    try {
      await dio.download(
        url,
        tempPath,
        onReceiveProgress: (received, total) {
          if (total != -1) onProgress(received / total);
        },
      );
      final tempFile = File(tempPath);
      return await tempFile.rename(finalPath);
    } catch (e) {
      final tempFile = File(tempPath);
      if (await tempFile.exists()) await tempFile.delete();
      throw Exception("فشل التحميل: $e");
    }
  }
}