import 'dart:convert';
import 'package:http/http.dart' as http;

class WebSearch {
  Future<String> search(String query) async {
    try {
      final url = Uri.parse('https://api.duckduckgo.com/?q=$query&format=json&no_html=1');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String results = "";

        if (data['AbstractText'] != null && data['AbstractText'].isNotEmpty) {
          results += "ملخص: ${data['AbstractText']}\n";
        }

        if (data['RelatedTopics'] != null) {
          for (var topic in data['RelatedTopics']) {
            if (topic['Text'] != null) {
              results += "- ${topic['Text']}\n";
            }
          }
        }

        return results.isEmpty ? "لم يتم العثور على نتائج." : results;
      }
      return "فشل الاتصال بمحرك البحث.";
    } catch (e) {
      return "خطأ في البحث: $e";
    }
  }
}