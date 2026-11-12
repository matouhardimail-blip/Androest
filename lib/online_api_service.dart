import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

class OnlineApiService {
  final Dio _dio = Dio();

  Stream<String> generateStream({
    required String provider,
    required String apiKey,
    required String baseUrl,
    required String modelName,
    required String systemPrompt,
    required String userPrompt,
  }) async* {
    try {
      if (provider.toLowerCase() == "anthropic") {
        final response = await _dio.post(
          '$baseUrl/v1/messages',
          options: Options(
            headers: {
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            responseType: ResponseType.stream,
          ),
          data: jsonEncode({
            'model': modelName,
            'max_tokens': 2048,
            'system': systemPrompt,
            'messages': [
              {'role': 'user', 'content': userPrompt},
            ],
            'stream': true,
          }),
        );

        final stream = response.data.stream as Stream<List<int>>;
        // استخدام LineSplitter لتجميع القطع المقطوعة
        final lineStream = stream.transform(utf8.decoder).transform(const LineSplitter());
        
        await for (final line in lineStream) {
          if (line.startsWith('data: ') && line != 'data: [DONE]') {
            final dataStr = line.substring(6).trim();
            if (dataStr.isEmpty) continue;
            try {
              final data = jsonDecode(dataStr);
              if (data['type'] == 'content_block_delta' && data['delta'] != null && data['delta']['text'] != null) {
                yield data['delta']['text'];
              }
            } catch (e) {
              // تجاهل قطع JSON التالفة من الخادم
            }
          }
        }
      } else {
        final response = await _dio.post(
          '$baseUrl/chat/completions',
          options: Options(
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            responseType: ResponseType.stream,
          ),
          data: jsonEncode({
            'model': modelName,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
            'stream': true,
          }),
        );

        final stream = response.data.stream as Stream<List<int>>;
        // استخدام LineSplitter لتجميع القطع المقطوعة
        final lineStream = stream.transform(utf8.decoder).transform(const LineSplitter());
        
        await for (final line in lineStream) {
          if (line.startsWith('data: ') && line != 'data: [DONE]') {
            final dataStr = line.substring(6).trim();
            if (dataStr.isEmpty) continue;
            try {
              final data = jsonDecode(dataStr);
              if (data['choices'] != null && 
                  data['choices'].isNotEmpty && 
                  data['choices'][0]['delta'] != null && 
                  data['choices'][0]['delta']['content'] != null) {
                yield data['choices'][0]['delta']['content'];
              }
            } catch (e) {
              // تجاهل قطع JSON التالفة من الخادم
            }
          }
        }
      }
    } catch (e) {
      if (e is DioException) {
        String errorMessage = "خطأ غير معروف";
        if (e.response != null && e.response!.data != null) {
          if (e.response!.data is ResponseBody) {
            final responseBody = e.response!.data as ResponseBody;
            final bytes = await responseBody.stream.fold<List<int>>(<int>[], (previous, element) => previous..addAll(element));
            errorMessage = utf8.decode(bytes);
          } else if (e.response!.data is String) {
            errorMessage = e.response!.data;
          } else {
            errorMessage = e.response!.data.toString();
          }
        }
        yield "\n\n❌ خطأ من الخادم (${e.response?.statusCode}):\n$errorMessage";
      } else {
        yield "\n\n❌ خطأ في الاتصال: $e";
      }
    }
  }

  Future<String?> testConnection({
    required String provider,
    required String apiKey,
    required String baseUrl,
    required String modelName,
  }) async {
    try {
      if (provider.toLowerCase() == "anthropic") {
        final response = await _dio.post(
          '$baseUrl/v1/messages',
          options: Options(
            headers: {
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
          ),
          data: jsonEncode({
            'model': modelName,
            'max_tokens': 5,
            'messages': [{'role': 'user', 'content': 'Hi'}],
          }),
        );
        if (response.statusCode == 200) return null;
      } else {
        final response = await _dio.post(
          '$baseUrl/chat/completions',
          options: Options(
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
          ),
          data: jsonEncode({
            'model': modelName,
            'messages': [{'role': 'user', 'content': 'Hi'}],
            'max_tokens': 5,
          }),
        );
        if (response.statusCode == 200) return null;
      }
    } on DioException catch (e) {
      String msg = "خطأ غير معروف";
      if (e.response != null && e.response!.data != null) {
         if (e.response!.data is Map) {
            msg = e.response!.data['error']?['message'] ?? e.response!.data['message'] ?? e.response!.data.toString();
         } else {
            msg = e.response!.data.toString();
         }
      } else {
         msg = e.message ?? e.toString();
      }
      return "(${e.response?.statusCode ?? 'Err'}) $msg";
    } catch (e) {
      return e.toString();
    }
    return "فشل الاتصال غير متوقع";
  }
}