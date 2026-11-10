import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class ModelDownloader {
  // ضع هنا الرابط المباشر لملف الموديل بصيغة GGUF من HuggingFace
  // مثال: https://huggingface.co/username/repo/resolve/main/model.gguf
  static const String modelUrl = 'https://huggingface.co/ضع_المسار_هنا.gguf'; 
  static const String fileName = 'agentic_arabic_2.6b.gguf';

  // 1. دالة التحقق: هل الموديل موجود ومكتمل؟
  Future<File?> getModelFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    
    // إذا كان الملف موجوداً، فهذا يعني أن التحميل اكتمل سابقاً
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  // 2. دالة التحميل
  Future<File> downloadModel(Function(double progress) onProgress) async {
    final dir = await getApplicationDocumentsDirectory();
    final finalPath = '${dir.path}/$fileName';
    final tempPath = '$finalPath.tmp'; // مسار مؤقت أثناء التحميل

    final dio = Dio();
    
    try {
      await dio.download(
        modelUrl,
        tempPath, // نحمل إلى الملف المؤقت
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );
      
      // بعد اكتمال التحميل بنجاح، نغير اسم الملف المؤقت إلى الاسم النهائي
      final tempFile = File(tempPath);
      final finalFile = await tempFile.rename(finalPath);
      
      return finalFile;
    } catch (e) {
      // إذا فشل التحميل، نحذف الملف المؤقت حتى لا يتراكم
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      throw Exception("فشل التحميل: $e");
    }
  }
}
