import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class ModelDownloader {
  // ضع رابط الموديل المباشر هنا (مثال من HuggingFace)
  static const String modelUrl = 'https://huggingface.co/ضع_المسار_هنا.gguf'; 
  static const String fileName = 'agentic_arabic_2.6b.gguf';

  Future<File?> getModelFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<File> downloadModel(Function(double progress) onProgress) async {
    final dir = await getApplicationDocumentsDirectory();
    final finalPath = '${dir.path}/$fileName';
    final tempPath = '$finalPath.tmp';

    final dio = Dio();
    
    try {
      await dio.download(
        modelUrl,
        tempPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );
      
      final tempFile = File(tempPath);
      final finalFile = await tempFile.rename(finalPath);
      return finalFile;
    } catch (e) {
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      throw Exception("فشل التحميل: $e");
    }
  }
}
