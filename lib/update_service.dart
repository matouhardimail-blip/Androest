import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';

class UpdateService {
  static const String latestApkUrl = 'https://github.com/matouhardimail-blip/Androest/releases/latest/download/app-release.apk';

  Future<bool> checkAndUpdate(Function(double) onProgress) async {
    try {
      if (!await Permission.requestInstallPackages.isGranted) {
        await Permission.requestInstallPackages.request();
      }

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

      final result = await OpenFilex.open(apkPath);
      return result.type == ResultType.done;
    } catch (e) {
      return false;
    }
  }
}