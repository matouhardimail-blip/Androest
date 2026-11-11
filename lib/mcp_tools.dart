import 'dart:io';
import 'package:path/path.dart' as p;

class McpTools {
  static final String baseDir = '/storage/emulated/0/Download/AgentPhoneProjects';

  static Future<String> writeFile(String filePath, String content) async {
    try {
      Directory dir = Directory(baseDir);
      if (!await dir.exists()) await dir.create(recursive: true);
      File file = File(p.join(baseDir, filePath));
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
      return "تم حفظ الملف بنجاح في: ${file.path}";
    } catch (e) {
      return "فشل حفظ الملف: $e";
    }
  }

  static Future<String> readFile(String filePath) async {
    try {
      File file = File(p.join(baseDir, filePath));
      if (await file.exists()) return await file.readAsString();
      return "الملف غير موجود.";
    } catch (e) {
      return "فشل قراءة الملف: $e";
    }
  }

  static Future<String?> handleToolCall(String response) async {
    RegExp regExp = RegExp(r'\[TOOL:\s*(\w+)\((.*?)\)\]', dotAll: true);
    var match = regExp.firstMatch(response);

    if (match != null) {
      String toolName = match.group(1)!.trim();
      String argsStr = match.group(2)!.trim();
      List<String> args = _parseArgs(argsStr);

      if (toolName == "write_file" && args.length >= 2) {
        return await writeFile(args[0], args[1]);
      } else if (toolName == "read_file" && args.length >= 1) {
        return await readFile(args[0]);
      }
      return "أداة غير معروفة أو وسائط ناقصة.";
    }
    return null;
  }

  static List<String> _parseArgs(String argsStr) {
    List<String> args = [];
    RegExp regExp = RegExp(r'"([^"]*)"');
    var matches = regExp.allMatches(argsStr);
    for (var m in matches) {
      String arg = m.group(1)!.replaceAll(r'\n', '\n').replaceAll(r'\"', '"');
      args.add(arg);
    }
    return args;
  }
}