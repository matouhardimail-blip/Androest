import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

class WebSearch {
  Future<String> search(String query) async {
    try {
      final results = await Future.wait([
        _searchDuckDuckGo(query),
        _searchBing(query),
      ]);

      String combinedResults = "";
      if (results[0].isNotEmpty) combinedResults += "DuckDuckGo:\n${results[0]}\n";
      if (results[1].isNotEmpty) combinedResults += "Bing:\n${results[1]}\n";

      if (combinedResults.isEmpty) {
        // إذا فشل السحب البرمجي، نعطي الموديل معلومة أنه بحث لكن لم يجد نصاً
        return "تم إجراء البحث، ولكن المواقع لم تسمح بسحب النصوص. أجب بناءً على معرفتك أو أخبر المستخدم أنك بحثت ولم تجد نصاً واضحاً.";
      }

      return "نتائج البحث:\n$combinedResults";
    } catch (e) {
      return "حدث خطأ فني أثناء البحث. أجب بناءً على معرفتك.";
    }
  }

  Future<String> _searchDuckDuckGo(String query) async {
    try {
      final url = Uri.parse('https://html.duckduckgo.com/html/?q=${Uri.encodeComponent(query)}');
      final response = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'});
      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        var results = document.querySelectorAll('.result__body');
        String formatted = "";
        int count = 0;
        for (var result in results) {
          if (count >= 3) break;
          var title = result.querySelector('.result__a')?.text.trim() ?? "";
          var snippet = result.querySelector('.result__snippet')?.text.trim() ?? "";
          if (snippet.isNotEmpty) {
            formatted += "- $title: $snippet\n";
            count++;
          }
        }
        return formatted;
      }
    } catch (_) {}
    return "";
  }

  Future<String> _searchBing(String query) async {
    try {
      final url = Uri.parse('https://www.bing.com/search?q=${Uri.encodeComponent(query)}');
      final response = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'});
      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        var results = document.querySelectorAll('li.b_algo');
        String formatted = "";
        int count = 0;
        for (var result in results) {
          if (count >= 3) break;
          var title = result.querySelector('h2')?.text.trim() ?? "";
          var snippet = result.querySelector('.b_caption p')?.text.trim() ?? "";
          if (snippet.isNotEmpty) {
            formatted += "- $title: $snippet\n";
            count++;
          }
        }
        return formatted;
      }
    } catch (_) {}
    return "";
  }
}