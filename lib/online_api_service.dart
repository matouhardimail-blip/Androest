import 'dart:convert';
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
        await for (final chunk in stream) {
          final lines = utf8.decode(chunk).split('\n');
          for (final line in lines) {
            if (line.startsWith('data: ') && line != 'data: [DONE]') {
              final data = jsonDecode(line.substring(6));
              if (data['type'] == 'content_block_delta' && data['delta']['text'] != null) {
                yield data['delta']['text'];
              }
            }
          }
        }
      } else {
        // OpenAI / Groq / OpenRouter
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
        await for (final chunk in stream) {
          final lines = utf8.decode(chunk).split('\n');
          for (final line in lines) {
            if (line.startsWith('data: ') && line != 'data: [DONE]') {
              final data = jsonDecode(line.substring(6));
              if (data['choices'] != null && data['choices'][0]['delta']['content'] != null) {
                yield data['choices'][0]['delta']['content'];
              }
            }
          }
        }
      }
    } catch (e) {
      // التقاط خطأ Dio وإظهار السبب الحقيقي
      if (e is DioException) {
        String errorMessage = "خطأ غير معروف";
        if (e.response != null && e.response!.data != null) {
          // قراءة رسالة الخطأ من الخادم (مثل Groq أو OpenAI)
          if (e.response!.data is String) {
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
}