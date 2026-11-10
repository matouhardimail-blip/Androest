import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:io';
import 'package:markdown/markdown.dart' as md; // مطلوب لتعريف Element

// استيراد الملفات التي أنشأناها
import 'model_downloader.dart';
import 'trading_agent.dart';
import 'code_bubble.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Agents',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const SplashScreen(),
    );
  }
}

// ==========================================
// حل مشكلة MarkdownElementBuilder المجردة
// ==========================================
class CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
      BuildContext context, md.Element element, TextStyle? preferredStyle) {
    String code = element.textContent;
    return CodeBubble(code: code);
  }
}

// ==========================================
// 1. شاشة البداية (التحميل والتحقق)
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.0;
  bool _isDownloading = false;
  String _status = "جاري التحقق من الموديل...";

  @override
  void initState() {
    super.initState();
    _checkAndDownload();
  }

  Future<void> _checkAndDownload() async {
    final downloader = ModelDownloader();
    File? modelFile = await downloader.getModelFile();

    if (modelFile != null) {
      _goToChat(modelFile.path);
      return;
    }

    setState(() {
      _status = "جاري تحميل الموديل (1.7 جيجا)... يرجى استخدام Wi-Fi.";
      _isDownloading = true;
    });

    try {
      File downloadedFile = await downloader.downloadModel((progress) {
        setState(() => _progress = progress);
      });
      _goToChat(downloadedFile.path);
    } catch (e) {
      setState(() {
        _status = "فشل التحميل. تأكد من الإنترنت وأعد المحاولة.";
        _isDownloading = false;
      });
    }
  }

  void _goToChat(String modelPath) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ChatScreen(modelPath: modelPath)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.smart_toy, size: 80, color: Colors.teal),
            const SizedBox(height: 20),
            Text(_status, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (_isDownloading) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 10),
              Text("${(_progress * 100).toStringAsFixed(1)}%"),
            ],
            if (!_isDownloading && _status.contains("فشل"))
              ElevatedButton(
                onPressed: _checkAndDownload,
                child: const Text("إعادة المحاولة"),
              )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. شاشة الدردشة الرئيسية
// ==========================================
class ChatScreen extends StatefulWidget {
  final String modelPath;
  const ChatScreen({super.key, required this.modelPath});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  void _initModel() async {
    // TODO: قم بتحميل الموديل هنا باستخدام مسار widget.modelPath
    setState(() {
      _messages.add({"role": "ai", "text": "الموديل جاهز. كيف يمكنني مساعدتك؟"});
    });
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;
    
    String userText = _controller.text;
    setState(() {
      _messages.add({"role": "user", "text": userText});
      _controller.clear();
      _isLoading = true;
    });

    // رد تجريبي
    String aiResponse = "هذا رد تجريبي. الكود جاهز: \n```dart\nvoid main() {\n  print('Hello');\n}\n```"; 

    setState(() {
      _messages.add({"role": "ai", "text": aiResponse});
      _isLoading = false;
    });
  }

  void _runTradingAgent() async {
    setState(() {
      _messages.add({"role": "user", "text": "قم بتحليل الذهب الآن."});
      _isLoading = true;
    });

    TradingAgent agent = TradingAgent();
    String data = await agent.fetchGoldPrices();
    String prompt = agent.generateTAPrompt(data);

    // رد تجريبي
    String aiResponse = "تحليل البيانات:\n$data\n\nالقرار:\n[SIGNAL: BUY]"; 

    setState(() {
      _messages.add({"role": "ai", "text": aiResponse});
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('وكلاء الذكاء الاصطناعي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart, color: Colors.amber),
            tooltip: "تحليل الذهب",
            onPressed: _isLoading ? null : _runTradingAgent,
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                bool isUser = msg['role'] == 'user';
                return _buildMessageBubble(msg['text'], isUser);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "اكتب رسالتك...",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.teal),
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.teal.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: isUser
            ? Text(text, style: const TextStyle(fontSize: 16))
            : MarkdownBody(
                data: text,
                selectable: true,
                builders: {
                  'pre': CodeElementBuilder(), // هنا استخدمنا الكلاس الجديد
                },
              ),
      ),
    );
  }
}
