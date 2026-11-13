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
    String? imageBase64, 
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
              "properties": {"query": {"type": "string"}},
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
                "file_path": {"type": "string"},
                "content": {"type": "string"}
              },
              "required": ["file_path", "content"]
            }
          }
        }
      ];

      String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      String finalSystemPrompt = systemPrompt;
      if (useTools) {
        finalSystemPrompt += "\n\n[تعليمات هامة جداً]:\nالتاريخ اليوم هو: $currentDate.\nأنت وكيل ذكي ولديك أدوات (بحث، كتابة ملفات).";
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

      if (imageBase64 != null) {
        messages.add({
          'role': 'user',
          'content': [
            {'type': 'text', 'text': userPrompt.isEmpty ? "قم بوصف هذه الصورة" : userPrompt},
            {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'}}
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
          yield "\n\n> ⚙️ *جاري تنفيذ: $toolCallName...*\n\n";
          
          await Future.delayed(const Duration(milliseconds: 500));

          try {
            final args = jsonDecode(toolCallArgs);
            
            if (toolCallName == "web_search") {
              String query = args['query'] ?? "";
              yield "\n\n> 🔍 *جاري البحث عن: $query...*\n\n";
              toolResult = await _webSearch.search(query);
            } 
            else if (toolCallName == "write_file") {
              String path = args['file_path'] ?? "";
              String content = args['content'] ?? "";
              yield "\n\n> 💾 *جاري حفظ الملف: $path...*\n\n";
              toolResult = await McpTools.writeFile(path, content);
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

          messages.add({'role': 'system', 'content': "تم تنفيذ الأداة. أكمل الإجابة."});
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        yield "\n\n⚠️ **الرجاء الانتظار (تجاوزت الحد).**";
      } else {
        yield "\n\n❌ خطأ: ${e.response?.statusCode}\n${e.response?.data}";
      }
    } catch (e) {
      yield "\n\n❌ خطأ: $e";
    }
  }

  Future<List<String>?> autoSelectAgents({
    required String provider,
    required String apiKey,
    required String baseUrl,
    required String modelName,
    required String userTask,
    required List<Map<String, String>> availableAgents,
  }) async {
    try {
      String prompt = """
المستخدم يريد: "$userTask"
الوكلاء المتاحون:
${availableAgents.map((a) => "- ${a['id']} : ${a['name']} (${a['description']})").join('\n')}

اختر أفضل 2 أو 3 وكلاء ورتبهم. أخرج مصفوفة JSON للمعرفات فقط: ["id1", "id2"]
""";

      final response = await _dio.post(
        '$baseUrl/chat/completions',
        options: Options(headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'}),
        data: jsonEncode({'model': modelName, 'messages': [{'role': 'user', 'content': prompt}], 'temperature': 0.1}),
      );

      String content = response.data['choices'][0]['message']['content'].trim();
      int start = content.indexOf('[');
      int end = content.lastIndexOf(']');
      if (start != -1 && end != -1) {
        List<dynamic> ids = jsonDecode(content.substring(start, end + 1));
        return ids.map((e) => e.toString()).toList();
      }
      return null;
    } catch (e) { return null; }
  }

  // دالة التلخيص والاختبار
  Future<String> summarizeChat({required String provider, required String apiKey, required String baseUrl, required String modelName, required List<Map<String, String>> chatHistory}) async {
    try {
      String historyText = chatHistory.map((m) => "${m['role'] == 'user' ? 'المستخدم' : 'المساعد'}: ${m['text']}").join('\n');
      final response = await _dio.post('$baseUrl/chat/completions', options: Options(headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'}), data: jsonEncode({'model': modelName, 'messages': [{'role': 'system', 'content': 'لخص المحادثة.'}, {'role': 'user', 'content': historyText}]}));
      return response.data['choices'][0]['message']['content'];
    } catch (e) { return "فشل التلخيص: $e"; }
  }

  Future<String?> testConnection({required String provider, required String apiKey, required String baseUrl, required String modelName}) async {
    try {
      final response = await _dio.post('$baseUrl/chat/completions', options: Options(headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'}), data: jsonEncode({'model': modelName, 'messages': [{'role': 'user', 'content': 'Hi'}], 'max_tokens': 5}));
      if (response.statusCode == 200) return null;
    } on DioException catch (e) {
      return "(${e.response?.statusCode}) ${e.response?.data}";
    } catch (e) { return e.toString(); }
    return "فشل";
  }
}