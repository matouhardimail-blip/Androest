import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateService {
  // رابط الـ API لجلب جميع الإصدارات
  static const String apiUrl = 'https://api.github.com/repos/matouhardimail-blip/Androest/releases';

  // ترجع: "success", "no_update", أو "error"
  Future<String> checkAndUpdate(Function(double) onProgress) async {
    try {
      // 1. جلب جميع الإصدارات من GitHub
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) return "error";

      List<dynamic> releases = jsonDecode(response.body);
      if (releases.isEmpty) return "no_update";

      // 2. أخذ أحدث إصدار (أول عنصر في القائمة)
      var latestRelease = releases.first;
      String latestTag = latestRelease['tag_name']; 
      
      // 3. البحث عن رابط تحميل الـ APK داخل الإصدار
      String? downloadUrl;
      List<dynamic> assets = latestRelease['assets'];
      for (var asset in assets) {
        if (asset['name'] == 'app-release.apk') {
          downloadUrl = asset['browser_download_url'];
          break;
        }
      }

      if (downloadUrl == null) return "error";

      // 4. مقارنة الإصدار الحالي مع الأحدث
      final prefs = await SharedPreferences.getInstance();
      String? installedTag = prefs.getString('installed_build_tag');

      if (installedTag == latestTag) {
        return "no_update";
      }

      // 5. طلب صلاحية التثبيت
      if (!await Permission.requestInstallPackages.isGranted) {
        await Permission.requestInstallPackages.request();
      }

      // 6. تحميل الملف
      final dir = await getApplicationDocumentsDirectory();
      final apkPath = '${dir.path}/update.apk';
      final file = File(apkPath);

      if (await file.exists()) {
        await file.delete();
      }

      final dio = Dio();
      await dio.download(
        downloadUrl,
        apkPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      // 7. حفظ رقم الإصدار الجديد
      await prefs.setString('installed_build_tag', latestTag);

      // 8. فتح الملف للتثبيت
      final result = await OpenFilex.open(apkPath);
      return result.type == ResultType.done ? "success" : "error";
    } catch (e) {
      print("خطأ في التحديث: $e");
      return "error";
    }
  }
}