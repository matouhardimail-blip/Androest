import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ModelManager {
  static const String defaultUrl = 'https://huggingface.co/DarkStrox/Agentic-Arabic-2.6-GGUF/resolve/main/LFM2.5-2.6B.Q4_K_M.gguf';
  static const String fileName = 'agentic_arabic_2.6b.gguf';

  Future<String> getModelDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<File?> getModelFile() async {
    String dirPath = await getModelDirectory();
    final file = File(p.join(dirPath, fileName));
    if (await file.exists()) return file;
    return null;
  }

  Future<File> downloadModel(Function(double) onProgress) async {
    String dirPath = await getModelDirectory();
    String finalPath = p.join(dirPath, fileName);
    String tempPath = '$finalPath.tmp';

    final dio = Dio();
    try {
      await dio.download(
        defaultUrl,
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