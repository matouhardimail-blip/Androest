import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

class WebSearch {
  // دالة البحث الرئيسية التي تجمع النتائج من عدة محركات
  Future<String> search(String query) async {
    try {
      // تشغيل البحث في جميع المحركات بالتوازي لتوفير الوقت
      final results = await Future.wait([
        _searchDuckDuckGo(query),
        _searchBing(query),
        _searchYahoo(query),
        _searchEcosia(query),
        _searchBrave(query),
      ]);

      String combinedResults = "";
      int sourceCount = 0;

      // دمج النتائج التي تم العثور عليها
      if (results[0].isNotEmpty) { combinedResults += "مصدر (DuckDuckGo):\n${results[0]}\n"; sourceCount++; }
      if (results[1].isNotEmpty) { combinedResults += "مصدر (Bing):\n${results[1]}\n"; sourceCount++; }
      if (results[2].isNotEmpty) { combinedResults += "مصدر (Yahoo):\n${results[2]}\n"; sourceCount++; }
      if (results[3].isNotEmpty) { combinedResults += "مصدر (Ecosia):\n${results[3]}\n"; sourceCount++; }
      if (results[4].isNotEmpty) { combinedResults += "مصدر (Brave):\n${results[4]}\n"; sourceCount++; }

      if (combinedResults.isEmpty) {
        return "لم يتم العثور على نتائج في أي من محركات البحث. جرب صياغة أخرى.";
      }

      return "تم العثور على معلومات من $sourceCount مصادر مختلفة:\n\n$combinedResults";
    } catch (e) {
      return "حدث خطأ أثناء البحث: $e";
    }
  }

  // ---------------------------------------------------------
  // 1. محرك DuckDuckGo
  // ---------------------------------------------------------
  Future<String> _searchDuckDuckGo(String query) async {
    try {
      final url = Uri.parse('https://html.duckduckgo.com/html/?q=${Uri.encodeComponent(query)}');
      final response = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'});
      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        var results = document.querySelectorAll('.result__body');
        String formatted = "";
        int count = 0;
        for (var result in results) {
          if (count >= 2) break;
          var title = result.querySelector('.result__a')?.text.trim() ?? "";
          var snippet = result.querySelector('.result__snippet')?.text.trim() ?? "";
          if (title.isNotEmpty && snippet.isNotEmpty) {
            formatted += "- $title\n  $snippet\n";
            count++;
          }
        }
        return formatted;
      }
    } catch (_) {}
    return "";
  }

  // ---------------------------------------------------------
  // 2. محرك Bing
  // ---------------------------------------------------------
  Future<String> _searchBing(String query) async {
    try {
      final url = Uri.parse('https://www.bing.com/search?q=${Uri.encodeComponent(query)}&setlang=ar');
      final response = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'});
      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        var results = document.querySelectorAll('li.b_algo');
        String formatted = "";
        int count = 0;
        for (var result in results) {
          if (count >= 2) break;
          var title = result.querySelector('h2 a')?.text.trim() ?? "";
          var snippet = result.querySelector('.b_caption p')?.text.trim() ?? "";
          if (title.isNotEmpty && snippet.isNotEmpty) {
            formatted += "- $title\n  $snippet\n";
            count++;
          }
        }
        return formatted;
      }
    } catch (_) {}
    return "";
  }

  // ---------------------------------------------------------
  // 3. محرك Yahoo
  // ---------------------------------------------------------
  Future<String> _searchYahoo(String query) async {
    try {
      final url = Uri.parse('https://search.yahoo.com/search?p=${Uri.encodeComponent(query)}');
      final response = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'});
      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        var results = document.querySelectorAll('.algo');
        String formatted = "";
        int count = 0;
        for (var result in results) {
          if (count >= 2) break;
          var title = result.querySelector('h3.title a')?.text.trim() ?? "";
          var snippet = result.querySelector('.compText p')?.text.trim() ?? "";
          if (title.isNotEmpty && snippet.isNotEmpty) {
            formatted += "- $title\n  $snippet\n";
            count++;
          }
        }
        return formatted;
      }
    } catch (_) {}
    return "";
  }

  // ---------------------------------------------------------
  // 4. محرك Ecosia
  // ---------------------------------------------------------
  Future<String> _searchEcosia(String query) async {
    try {
      final url = Uri.parse('https://www.ecosia.org/search?q=${Uri.encodeComponent(query)}');
      final response = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'});
      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        var results = document.querySelectorAll('article.result');
        String formatted = "";
        int count = 0;
        for (var result in results) {
          if (count >= 2) break;
          var title = result.querySelector('.result__title a')?.text.trim() ?? "";
          var snippet = result.querySelector('.result__snippet')?.text.trim() ?? "";
          if (title.isNotEmpty && snippet.isNotEmpty) {
            formatted += "- $title\n  $snippet\n";
            count++;
          }
        }
        return formatted;
      }
    } catch (_) {}
    return "";
  }

  // ---------------------------------------------------------
  // 5. محرك Brave (من خلال نسخة الويب)
  // ---------------------------------------------------------
  Future<String> _searchBrave(String query) async {
    try {
      final url = Uri.parse('https://search.brave.com/search?q=${Uri.encodeComponent(query)}');
      final response = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'});
      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        var results = document.querySelectorAll('.snippet');
        String formatted = "";
        int count = 0;
        for (var result in results) {
          if (count >= 2) break;
          var title = result.querySelector('.title')?.text.trim() ?? "";
          var snippet = result.querySelector('.snippet-description')?.text.trim() ?? "";
          if (title.isNotEmpty && snippet.isNotEmpty) {
            formatted += "- $title\n  $snippet\n";
            count++;
          }
        }
        return formatted;
      }
    } catch (_) {}
    return "";
  }
}