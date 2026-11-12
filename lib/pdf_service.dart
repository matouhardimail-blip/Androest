import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfService {
  // دالة لاستخراج النص من ملف PDF
  static Future<String> extractText(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      
      String text = '';
      // المرور على كل صفحة واستخراج النص منها
      for (int i = 0; i < document.pages.count; i++) {
        text += PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i) + '\n';
      }
      
      document.dispose();
      
      if (text.trim().isEmpty) {
        return "لم يتم العثور على نص في هذا الملف. قد يكون ملفاً مصوراً (Scanned PDF).";
      }
      
      return text;
    } catch (e) {
      return "خطأ في قراءة ملف PDF: $e";
    }
  }
}