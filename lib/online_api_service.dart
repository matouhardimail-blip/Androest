import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'web_search.dart';

class OnlineApiService {
  final Dio _dio = Dio();
  final WebSearch _webSearch = WebSearch();

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
      final List<Map<String, dynamic>> tools = [
        {
          "type": "function",
          "function": {
            "name": "web_search",
            "description": "أداة بحث حقيقية في الإنترنت. استخدمها دائماً للأخبار والطقس والمعلومات الحديثة.",
            "parameters": {
              "type": "object",
              "properties": {
                "query": {
                  "type": "string",
                  "description": "كلمة البحث بالإنجليزية"
                }
              },
              "required": ["query"]
            }
          }
        }
      ];

      // حقن تعليمات صارمة إذا كان البحث مفعلاً
      String finalSystemPrompt = systemPrompt;
      if (useTools) {
        finalSystemPrompt += """

\n\n[تعليمات هامة جداً]:
أنت وكيل ذكي متصل بالإنترنت. يحظر عليك تماماً كتابة "لا يمكنني البحث" أو "بحثي مقيد".
إذا سألك المستخدم عن أخبار، طقس، أو أي معلومات حديثة، يجب عليك فوراً استخدام أداة (web_search) دون تردد.
لا تجب من معرفتك الداخلية، بل ابحث أولاً.
""";
      }

      List<Map<String, dynamic>> messages = [
        {'role': 'system', 'content': finalSystemPrompt},
        {'role': 'user', 'content': userPrompt},
      ];

      bool keepRunning = true;
      int toolCallCount = 0;

      while (keepRunning) {
        keepRunning = false;
        
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
            'messages': messages,
            if (useTools) 'tools': tools,
            if (useTools) 'tool_choice': 'auto', // يترك للموديل القرار، لكن التعليمات أعلاه تجبره
            'stream': true,
          }),
        );

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
                
                if (delta['content'] != null) {
                  currentText += delta['content'];
                  yield delta['content'];
                }
                
                if (delta['tool_calls'] != null) {
                  isToolCall = true;
                  final toolCall = delta['tool_calls'][0];
                  if (toolCall['function']['name'] != null) toolCallName += toolCall['function']['name'];
                  if (toolCall['function']['arguments'] != null) toolCallArgs += toolCall['function']['arguments'];
                }
              }
            } catch (e) {}
          }
        }

        // إذا طلب أداة بحث
        if (isToolCall && toolCallName == "web_search" && toolCallCount < 1) {
          keepRunning = true;
          toolCallCount++;
          
          String searchQuery = "";
          try {
            final args = jsonDecode(toolCallArgs);
            searchQuery = args['query'] ?? "";
          } catch(e) {}

          if (searchQuery.isNotEmpty) {
            yield "\n\n> 🔍 *جاري البحث في الإنترنت عن: $searchQuery...*\n\n";
            
            await Future.delayed(const Duration(seconds: 1));
            
            String searchResults = await _webSearch.search(searchQuery);
            
            messages.add({
              'role': 'assistant',
              'content': currentText.isEmpty ? null : currentText,
              'tool_calls': [
                {
                  'id': 'call_123',
                  'type': 'function',
                  'function': {'name': toolCallName, 'arguments': toolCallArgs}
                }
              ]
            });
            
            messages.add({
              'role': 'tool',
              'tool_call_id': 'call_123',
              'name': 'web_search',
              'content': searchResults.isEmpty ? "لم يتم العثور على نتائج." : searchResults,
            });

            // نطلب منه الإجابة الآن
            messages.add({
              'role': 'system',
              'content': "لقد نفذت البحث بنجاح. الآن أجب على المستخدم بناءً على النتائج. لا تعتذر."
            });
          }
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        yield "\n\n⚠️ **الرجاء الانتظار بضع ثوانٍ (تجاوزت الحد الأقصى للطلبات).**";
      } else {
        yield "\n\n❌ خطأ في الاتصال: ${e.message}";
      }
    } catch (e) {
      yield "\n\n❌ خطأ غير متوقع: $e";
    }
  }

  // ... (بقية دالة testConnection كما هي)
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