import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateService {
  // رابط الـ API لجلب معلومات آخر إصدار
  static const String apiUrl = 'https://api.github.com/repos/matouhardimail-blip/Androest/releases/latest';
  static const String latestApkUrl = 'https://github.com/matouhardimail-blip/Androest/releases/latest/download/app-release.apk';

  // ترجع: "success", "no_update", أو "error"
  Future<String> checkAndUpdate(Function(double) onProgress) async {
    try {
      // 1. جلب معلومات آخر إصدار من GitHub
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode != 200) return "error";

      final data = jsonDecode(response.body);
      String latestTag = data['tag_name']; // مثال: "build-25"

      // 2. التحقق من الإصدار المثبت حالياً
      final prefs = await SharedPreferences.getInstance();
      String? installedTag = prefs.getString('installed_build_tag');

      if (installedTag == latestTag) {
        return "no_update"; // أنت تستخدم أحدث نسخة
      }

      // 3. طلب صلاحية التثبيت
      if (!await Permission.requestInstallPackages.isGranted) {
        await Permission.requestInstallPackages.request();
      }

      // 4. تحميل الملف
      final dir = await getApplicationDocumentsDirectory();
      final apkPath = '${dir.path}/update.apk';
      final file = File(apkPath);

      if (await file.exists()) {
        await file.delete();
      }

      final dio = Dio();
      await dio.download(
        latestApkUrl,
        apkPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      // 5. حفظ رقم الإصدار الجديد لكي لا يطلبه مرة أخرى
      await prefs.setString('installed_build_tag', latestTag);

      // 6. فتح الملف للتثبيت
      final result = await OpenFilex.open(apkPath);
      return result.type == ResultType.done ? "success" : "error";
    } catch (e) {
      print("خطأ في التحديث: $e");
      return "error";
    }
  }
}