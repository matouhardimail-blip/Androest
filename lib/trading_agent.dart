import 'dart:convert';
import 'package:http/http.dart' as http;

class TradingAgent {
  Future<String> fetchGoldPrices() async {
    final url = Uri.parse('https://api.binance.com/api/v3/klines?symbol=PAXGUSDT&interval=1h&limit=5');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        String formattedData = "بيانات آخر 5 شموع (الافتتاح، الأعلى، الأدنى، الإغلاق):\n";
        for (var candle in data) {
          formattedData += "- O: ${candle[1]}, H: ${candle[2]}, L: ${candle[3]}, C: ${candle[4]}\n";
        }
        return formattedData;
      } else {
        return "فشل جلب البيانات: ${response.statusCode}";
      }
    } catch (e) {
      return "خطأ في الاتصال: $e";
    }
  }

  String generateTAPrompt(String marketData) {
    return """
أنت وكيل تحليل فني خبير في الذهب. لديك البيانات التالية:
$marketData

قم بتحليل الاتجاه. لا تشرح طويلاً. أخرج القرار فقط بصيغة:
[SIGNAL: BUY] إذا كان الاتجاه صاعداً.
[SIGNAL: SELL] إذا كان هابطاً.
[SIGNAL: HOLD] إذا كان غير واضح.
""";
  }
}
