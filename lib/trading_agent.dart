import 'dart:convert';
import 'package:http/http.dart' as http;

class TradingAgent {
  // دالة جلب الذهب
  Future<String> fetchGoldPrices() async {
    final url = Uri.parse('https://api.binance.com/api/v3/klines?symbol=PAXGUSDT&interval=1h&limit=5');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        String formattedData = "بيانات آخر 5 شموع للذهب:\n";
        for (var candle in data) {
          formattedData += "- O: ${candle[1]}, H: ${candle[2]}, L: ${candle[3]}, C: ${candle[4]}\n";
        }
        return formattedData;
      }
      return "فشل جلب البيانات.";
    } catch (e) {
      return "خطأ: $e";
    }
  }

  // دالة جديدة: جلب الميم كوينز (مثل DOGE)
  Future<String> fetchMemeCoinPrices(String coinSymbol) async {
    // تأكد أن الرمز مكتوب بحروف كبيرة (مثلاً DOGEUSDT)
    String symbol = coinSymbol.toUpperCase();
    if (!symbol.endsWith("USDT")) symbol += "USDT";
    
    final url = Uri.parse('https://api.binance.com/api/v3/ticker/24hr?symbol=$symbol');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return """
بيانات عملة $symbol خلال 24 ساعة:
- السعر الحالي: ${data['lastPrice']} USDT
- أعلى سعر: ${data['highPrice']}
- أدنى سعر: ${data['lowPrice']}
- حجم التداول: ${data['volume']}
- نسبة التغير: ${data['priceChangePercent']}%
""";
      }
      return "لم يتم العثور على بيانات للعملة $symbol.";
    } catch (e) {
      return "خطأ في جلب البيانات: $e";
    }
  }
}
