import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'web_search.dart';
import 'mcp_tools.dart';

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
    required List<Map<String, String>> chatHistory,
    bool useTools = false,
    String? imageBase64, // <--- إضافة متغير للصورة
  }) async* {
    try {
      final List<Map<String, dynamic>> tools = [
        {
          "type": "function",
          "function": {
            "name": "web_search",
            "description": "ابحث في الإنترنت عن معلومات حديثة أو أخبار.",
            "parameters": {
              "type": "object",
              "properties": {
                "query": {"type": "string", "description": "كلمة البحث"}
              },
              "required": ["query"]
            }
          }
        },
        {
          "type": "function",
          "function": {
            "name": "write_file",
            "description": "إنشاء أو تعديل ملف برمجي على جهاز المستخدم.",
            "parameters": {
              "type": "object",
              "properties": {
                "file_path": {"type": "string", "description": "مسار الملف"},
                "content": {"type": "string", "description": "الكود أو النص الكامل"}
              },
              "required": ["file_path", "content"]
            }
          }
        },
        {
          "type": "function",
          "function": {
            "name": "generate_image",
            "description": "ارسم أو أنشئ صورة بناءً على وصف.",
            "parameters": {
              "type": "object",
              "properties": {
                "prompt": {"type": "string", "description": "وصف الصورة بالإنجليزية"}
              },
              "required": ["prompt"]
            }
          }
        }
      ];

      String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      String finalSystemPrompt = systemPrompt;
      if (useTools) {
        finalSystemPrompt += """

\n\n[تعليمات هامة جداً]:
التاريخ اليوم هو: $currentDate.
أنت وكيل ذكي ولديك أدوات (بحث، كتابة ملفات، توليد صور).
""";
      }

      List<Map<String, dynamic>> messages = [
        {'role': 'system', 'content': finalSystemPrompt},
      ];

      int maxHistoryLength = 10; 
      int startIndex = chatHistory.length > maxHistoryLength ? chatHistory.length - maxHistoryLength : 0;
      
      for (int i = startIndex; i < chatHistory.length; i++) {
        messages.add({
          'role': chatHistory[i]['role'], 
          'content': chatHistory[i]['text']
        });
      }

      // إضافة الرسالة الحالية (مع الصورة إذا وجدت)
      if (imageBase64 != null) {
        messages.add({
          'role': 'user',
          'content': [
            {'type': 'text', 'text': userPrompt},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,$imageBase64'
              }
            }
          ]
        });
      } else {
        messages.add({'role': 'user', 'content': userPrompt});
      }

      bool keepRunning = true;
      int toolCallCount = 0;

      while (keepRunning && toolCallCount < 3) {
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
            if (useTools) 'tool_choice': 'auto',
            'temperature': 0.1,
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

        if (isToolCall) {
          keepRunning = true;
          toolCallCount++;
          
          String toolResult = "";
          yield "\n\n> ⚙️ *جاري تنفيذ الأداة: $toolCallName...*\n\n";
          
          await Future.delayed(const Duration(milliseconds: 500));

          try {
            final args = jsonDecode(toolCallArgs);
            
            if (toolCallName == "web_search") {
              String query = args['query'] ?? "";
              yield "\n\n> 🔍 *جاري البحث في الإنترنت عن: $query...*\n\n";
              toolResult = await _webSearch.search(query);
            } 
            else if (toolCallName == "write_file") {
              String path = args['file_path'] ?? "";
              String content = args['content'] ?? "";
              yield "\n\n> 💾 *جاري حفظ الملف: $path...*\n\n";
              toolResult = await McpTools.writeFile(path, content);
            }
            else if (toolCallName == "generate_image") {
              String prompt = args['prompt'] ?? "";
              yield "\n\n> 🎨 *جاري رسم الصورة: $prompt...*\n\n";
              String encodedPrompt = Uri.encodeComponent(prompt);
              String imageUrl = 'https://image.pollinations.ai/prompt/$encodedPrompt?width=1024&height=1024&nologo=true';
              toolResult = "تم توليد الصورة بنجاح. رابط الصورة هو: $imageUrl\n\nاعرض الصورة للمستخدم باستخدام صيغة Markdown: ![صورة]($imageUrl)";
            }
          } catch (e) {
            toolResult = "خطأ في تنفيذ الأداة: $e";
          }
          
          messages.add({
            'role': 'assistant',
            'content': currentText.isEmpty ? null : currentText,
            'tool_calls': [
              {
                'id': 'call_$toolCallCount',
                'type': 'function',
                'function': {'name': toolCallName, 'arguments': toolCallArgs}
              }
            ]
          });
          
          messages.add({
            'role': 'tool',
            'tool_call_id': 'call_$toolCallCount',
            'name': toolCallName,
            'content': toolResult,
          });

          messages.add({
            'role': 'system',
            'content': "تم تنفيذ الأداة بنجاح. أكمل الإجابة."
          });
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        yield "\n\n⚠️ **الرجاء الانتظار بضع ثوانٍ.**";
      } else {
        yield "\n\n❌ خطأ في الاتصال: ${e.message}";
      }
    } catch (e) {
      yield "\n\n❌ خطأ غير متوقع: $e";
    }
  }

  Future<String> summarizeChat({
    required String provider,
    required String apiKey,
    required String baseUrl,
    required String modelName,
    required List<Map<String, String>> chatHistory,
  }) async {
    try {
      String historyText = chatHistory.map((m) => "${m['role'] == 'user' ? 'المستخدم' : 'المساعد'}: ${m['text']}").join('\n');
      
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
          'messages': [
            {'role': 'system', 'content': 'أنت خبير في تلخيص المحادثات. لخص المحادثة التالية في نقاط مختصرة جداً.'},
            {'role': 'user', 'content': historyText},
          ],
        }),
      );
      return response.data['choices'][0]['message']['content'];
    } catch (e) {
      return "فشل التلخيص: $e";
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