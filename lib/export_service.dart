import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class ExportService {
  // دالة لضغط المجلد بالكامل وإنشاء ملف ZIP
  static Future<File?> zipProjectFolder(String sourceDirPath, String zipFileName) async {
    try {
      Directory sourceDir = Directory(sourceDirPath);
      if (!await sourceDir.exists()) return null;

      // إنشاء أرشيف جديد
      var archive = Archive();

      // المرور على جميع الملفات داخل المجلد وإضافتها للأرشيف
      await for (var entity in sourceDir.list(recursive: true)) {
        if (entity is File) {
          // استخراج المسار النسبي للملف (لكي يكون الهيكل داخل الـ ZIP صحيحاً)
          String filePath = entity.path;
          String relativePath = p.relative(filePath, from: sourceDirPath);
          
          List<int> bytes = await entity.readAsBytes();
          
          ArchiveFile file = ArchiveFile(relativePath, bytes.length, bytes);
          archive.addFile(file);
        }
      }

      if (archive.isEmpty) return null;

      // تحويل الأرشيف إلى بيانات ZIP
      List<int>? zipData = ZipEncoder().encode(archive);
      if (zipData == null) return null;

      // حفظ الملف النهائي في مجلد التنزيلات (Download)
      Directory downloadDir = Directory('/storage/emulated/0/Download');
      if (!await downloadDir.exists()) {
        downloadDir = await getApplicationDocumentsDirectory();
      }
      
      String zipPath = p.join(downloadDir.path, zipFileName);
      File zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipData);

      return zipFile;
    } catch (e) {
      print("خطأ في تصدير المشروع: $e");
      return null;
    }
  }

  // دالة لمشاركة ملف الـ ZIP
  static Future<void> shareZipFile(File zipFile) async {
    await Share.shareXFiles([XFile(zipFile.path)], text: 'مشروع من AI HUB');
  }
}