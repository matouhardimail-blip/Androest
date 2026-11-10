import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

/// (receivedBytes, totalBytes, statusText)
typedef DownloadProgress = void Function(int received, int total, String status);

/// ينزّل ملف GGUF مرة واحدة فقط إلى مساحة التطبيق الخاصة، مع:
///  - شريط تقدّم حقيقي بالبايت
///  - استئناف بعد انقطاع الشبكة عبر ترويسة Range (ملف .part)
///  - تحقق من الحجم النهائي قبل تسمية الملف بصيغته النهائية
///
/// بعد اكتمال التنزيل لا يُستخدم الإنترنت إطلاقاً.
class ModelDownloader {
  ModelDownloader({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(minutes: 5),
              followRedirects: true,
            ));

  final Dio _dio;

  Future<Directory> get modelsDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'models'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> fileFor(ModelSpec spec) async =>
      File(p.join((await modelsDir).path, spec.file));

  /// true فقط إذا كان الملف موجوداً وكاملاً.
  Future<bool> isReady(ModelSpec spec) async {
    final f = await fileFor(spec);
    return await f.exists() && await f.length() == spec.expectedBytes;
  }

  /// يُعيد المسار النهائي للنموذج، منزّلاً إياه عند الحاجة.
  Future<String> ensureModel(
    ModelSpec spec,
    DownloadProgress onProgress, {
    CancelToken? cancelToken,
  }) async {
    final target = await fileFor(spec);

    // 1) التشغيل دون إنترنت: الملف موجود وكامل ⇒ لا يوجد أي طلب شبكة.
    if (await target.exists() && await target.length() == spec.expectedBytes) {
      onProgress(spec.expectedBytes, spec.expectedBytes,
          'النموذج محفوظ على الجهاز — يعمل دون إنترنت');
      return target.path;
    }

    final part = File('${target.path}.part');
    int start = 0;
    if (await part.exists()) {
      start = await part.length();
      if (start > spec.expectedBytes) {
        await part.delete();
        start = 0;
      }
    }

    onProgress(start, spec.expectedBytes, 'جارٍ الاتصال بـ Hugging Face…');

    final response = await _dio.get<ResponseBody>(
      spec.url,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        headers: start > 0
            ? <String, dynamic>{HttpHeaders.rangeHeader: 'bytes=$start-'}
            : null,
        validateStatus: (int? code) => code == 200 || code == 206,
      ),
    );

    final body = response.data;
    if (body == null) throw const HttpException('استجابة فارغة من الخادم');
    if (response.statusCode != 200 && response.statusCode != 206) {
      throw HttpException('فشل التنزيل: HTTP ${response.statusCode}');
    }

    // الخادم تجاهل Range وأعاد الملف من البداية ⇒ نبدأ من الصفر.
    final bool resumed = response.statusCode == 206 && start > 0;
    if (!resumed && start > 0) {
      await part.delete();
      start = 0;
    }

    final sink = part.openWrite(mode: resumed ? FileMode.append : FileMode.write);
    int received = 0;
    int lastPercent = -1;

    void notify(String status) {
      final done = start + received;
      final percent = (done * 100) ~/ spec.expectedBytes;
      if (percent != lastPercent || done >= spec.expectedBytes) {
        lastPercent = percent;
        final mb = (done / 1048576).toStringAsFixed(0);
        final totalMb = (spec.expectedBytes / 1048576).toStringAsFixed(0);
        onProgress(done, spec.expectedBytes, '$status  ·  $mb / $totalMb MB');
      }
    }

    try {
      await for (final List<int> chunk in body.stream) {
        sink.add(chunk);
        received += chunk.length;
        // لا تُنهك واجهة المستخدم: تحديث عند كل 1% كحد أقصى.
        notify('جارٍ تنزيل النموذج');
      }
      await sink.flush();
    } finally {
      // عند الإلغاء/الخطأ نُبقي ملف .part ليُستأنف لاحقاً.
      await sink.close();
    }

    final size = await part.length();
    if (size != spec.expectedBytes) {
      throw HttpException(
        'الملف غير مكتمل ($size / ${spec.expectedBytes} بايت). أعد المحاولة ليُستأنف التنزيل.',
      );
    }

    if (await target.exists()) await target.delete();
    await part.rename(target.path);
    onProgress(spec.expectedBytes, spec.expectedBytes, 'اكتمل التنزيل');
    return target.path;
  }

  Future<void> deleteModel(ModelSpec spec) async {
    final target = await fileFor(spec);
    final part = File('${target.path}.part');
    if (await target.exists()) await target.delete();
    if (await part.exists()) await part.delete();
  }
}
