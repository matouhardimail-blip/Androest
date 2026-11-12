import 'dart:io';
import 'package:path/path.dart' as p;

class McpTools {
  // المجلد الأساسي لحفظ المشاريع (في مجلد Download لسهولة الوصول)
  static final String baseDir = '/storage/emulated/0/Download/AgentPhoneProjects';

  static Future<String> writeFile(String filePath, String content) async {
    try {
      Directory dir = Directory(baseDir);
      if (!await dir.exists()) await dir.create(recursive: true);

      // تنظيف المسار من أي رموز غير مسموحة
      String cleanPath = filePath.replaceAll('`', '').trim();
      
      File file = File(p.join(baseDir, cleanPath));
      await file.parent.create(recursive: true);
      
      // معالجة الأسطر الجديدة (إذا أرسلها الموديل كنص \n)
      String cleanContent = content.replaceAll('\\n', '\n').replaceAll('\\"', '"');
      
      await file.writeAsString(cleanContent);
      return "✅ تم حفظ الملف بنجاح في: ${file.path}";
    } catch (e) {
      return "❌ فشل حفظ الملف: $e";
    }
  }

  static Future<String> readFile(String filePath) async {
    try {
      String cleanPath = filePath.replaceAll('`', '').trim();
      File file = File(p.join(baseDir, cleanPath));
      if (await file.exists()) {
        return await file.readAsString();
      }
      return "❌ الملف غير موجود.";
    } catch (e) {
      return "❌ فشل قراءة الملف: $e";
    }
  }
}