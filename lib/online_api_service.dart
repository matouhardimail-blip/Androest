import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'web_search.dart'; // استدعاء أداة البحث

class OnlineApiService {
  final Dio _dio = Dio();
  final WebSearch _webSearch = WebSearch();

  // إضافة متغير useTools لتحديد ما إذا كنا سنسمح للموديل باستخدام الأدوات
  Stream<String> generateStream({
    required String provider,
    required String apiKey,
    required String baseUrl,
    required String modelName,
    required String systemPrompt,
    required String userPrompt,
    bool useTools = false,
  }) async* {
    try {
      // 1. تعريف الأداة التي سيستخدمها الموديل
      final List<Map<String, dynamic>> tools = [
        {
          "type": "function",
          "function": {
            "name": "web_search",
            "description": "ابحث في الإنترنت عن معلومات حديثة أو أخبار أو طقس.",
            "parameters": {
              "type": "object",
              "properties": {
                "query": {
                  "type": "string",
                  "description": "كلمة البحث بالإنجليزية (مثال: weather in Agadir)"
                }
              },
              "required": ["query"]
            }
          }
        }
      ];

      // دالة داخلية لإرسال الطلب (لإعادة استخدامها عند استخدام الأدوات)
      Future<Response> sendRequest(List<Map<String, dynamic>> messages, {bool isStream = true}) async {
        return await _dio.post(
          '$baseUrl/chat/completions',
          options: Options(
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            responseType: isStream ? ResponseType.stream : ResponseType.json,
          ),
          data: jsonEncode({
            'model': modelName,
            'messages': messages,
            if (useTools) 'tools': tools,
            if (useTools) 'tool_choice': 'auto',
            'stream': isStream,
          }),
        );
      }

      List<Map<String, dynamic>> messages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ];

      // الحلقة (Loop): قد يطلب الموديل البحث، فنبحث، ثم نعيد الإرسال
      bool keepRunning = true;
      while (keepRunning) {
        keepRunning = false; // نعود للـ false إلا إذا طلب الموديل أداة
        final response = await sendRequest(messages);

        // تجميع الستريم ومراقبة طلبات الأدوات
        final stream = response.data.stream as Stream<Uint8List>;
        final lineStream = stream.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter());
        
        String toolCallName = "";
        String toolCallArgs = "";
        bool isToolCall = false;
        String currentText = "";

        await for (final line in lineStream) {
          if (line.startsWith('data: ') && line != 'data: [DONE]') {
            final dataStr = line.substring(6).trim();
            if (dataStr.isEmpty) continue;
            
            try {
              final data = jsonDecode(dataStr);
              if (data['choices'] != null && data['choices'].isNotEmpty) {
                final delta = data['choices'][0]['delta'];
                
                // إذا كان الموديل يكتب نصاً عادياً
                if (delta['content'] != null) {
                  currentText += delta['content'];
                  yield delta['content'];
                }
                
                // إذا كان الموديل يطلب تنفيذ أداة (Function Call)
                if (delta['tool_calls'] != null) {
                  isToolCall = true;
                  final toolCall = delta['tool_calls'][0];
                  if (toolCall['function']['name'] != null) {
                    toolCallName += toolCall['function']['name'];
                  }
                  if (toolCall['function']['arguments'] != null) {
                    toolCallArgs += toolCall['function']['arguments'];
                  }
                }
              }
            } catch (e) {
              // تجاهل قطع JSON التالفة
            }
          }
        }

        // بعد انتهاء الستريم، إذا طلب الموديل أداة
        if (isToolCall && toolCallName == "web_search") {
          keepRunning = true;
          
          // استخراج كلمة البحث من طلب الموديل
          String searchQuery = "";
          try {
            final args = jsonDecode(toolCallArgs);
            searchQuery = args['query'] ?? "";
          } catch(e) {}

          if (searchQuery.isNotEmpty) {
            // 1. إبلاغ الواجهة أن الموديل يبحث
            yield "\n\n> 🤖 *الموديل يقرر البحث في الإنترنت عن: $searchQuery...*\n\n";
            
            // 2. تنفيذ البحث الحقيقي
            String searchResults = await _webSearch.search(searchQuery);
            
            // 3. إضافة رد الموديل (الذي طلب الأداة) إلى تاريخ المحادثة
            messages.add({
              'role': 'assistant',
              'content': currentText,
              'tool_calls': [
                {
                  'id': 'call_123',
                  'type': 'function',
                  'function': {'name': toolCallName, 'arguments': toolCallArgs}
                }
              ]
            });
            
            // 4. إضافة نتيجة البحث كرسالة من "الأداة" للموديل
            messages.add({
              'role': 'tool',
              'tool_call_id': 'call_123',
              'name': 'web_search',
              'content': searchResults,
            });
            
            // نترك الحلقة (While Loop) تكمل وتعيد الإرسال للموديل مع نتيجة البحث
          }
        }
      }
    } catch (e) {
      yield "\n\n❌ خطأ في الاتصال: $e";
    }
  }

  // دالة اختبار الاتصال (كما هي)
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