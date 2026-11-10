import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:async';
import 'dart:io';
import 'package:markdown/markdown.dart' as md;
import 'package:llama_flutter_android/llama_flutter_android.dart';

import 'model_downloader.dart';
import 'trading_agent.dart';
import 'code_bubble.dart';
import 'web_search.dart'; // استيراد أداة البحث

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

class CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
      BuildContext context, md.Element element, TextStyle? preferredStyle, TextStyle? blockStyle) {
    return CodeBubble(code: element.textContent);
  }
}

// ==========================================
// 1. شاشة البداية
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
      _status = "جاري تحميل الموديل (1.67 جيجا)... يرجى استخدام Wi-Fi.";
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
              ElevatedButton(onPressed: _checkAndDownload, child: const Text("إعادة المحاولة"))
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. شاشة الدردشة (المحرك الحقيقي + البحث)
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
  bool _isModelReady = false;

  final LlamaController _llama = LlamaController();
  StreamSubscription? _generationSub;

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    try {
      // تم إزالة nThreads لأنها غير مدعومة في هذا الإصدار
      await _llama.loadModel(
        modelPath: widget.modelPath,
        contextSize: 2048,
      );
      setState(() {
        _isModelReady = true;
        _messages.add({"role": "ai", "text": "الموديل جاهز. يمكنني البحث في الإنترنت إذا طلبت مني ذلك."});
      });
    } catch (e) {
      setState(() {
        _messages.add({"role": "ai", "text": "فشل تحميل الموديل: $e"});
      });
    }
  }

  // دالة التوليد المعدلة لدعم البحث
  void _generateResponse(String prompt, {bool isSearchResult = false}) {
    String currentResponse = "";
    setState(() {
      _isLoading = true;
      _messages.add({"role": "ai", "text": ""});
    });

    _generationSub = _llama.generate(
      prompt: prompt,
      maxTokens: 512,
      temperature: 0.7,
    ).listen(
      (token) async {
        currentResponse += token;
        setState(() {
          _messages.last["text"] = currentResponse;
        });

        // فحص هل الموديل قرر البحث؟ (نفحص فقط إذا لم تكن النتيجة بحث سابق)
        if (!isSearchResult && currentResponse.contains("[SEARCH:")) {
          await _generationSub?.cancel();
          
          RegExp regExp = RegExp(r'\[SEARCH:\s*(.*?)\]');
          var match = regExp.firstMatch(currentResponse);
          String query = match?.group(1)?.trim() ?? "";

          if (query.isNotEmpty) {
            setState(() {
              _messages.last["text"] = "🔍 جاري البحث في الإنترنت عن: $query...";
            });

            WebSearch searcher = WebSearch();
            String searchResults = await searcher.search(query);

            // حذف رسالة "جاري البحث"
            setState(() {
              _messages.removeLast();
            });

            // إعادة إرسال النتائج للموديل ليجيب
            String newPrompt = """
لقد بحثت في الإنترنت عن "$query" وحصلت على النتائج التالية:
$searchResults

الآن، أجب على المستخدم بناءً على هذه النتائج بوضوح. لا تطلب بحثاً آخر.
""";
            _generateResponse(newPrompt, isSearchResult: true);
          }
        }
      },
      onDone: () {
        setState(() => _isLoading = false);
      },
      onError: (error) {
        setState(() {
          _isLoading = false;
          _messages.last["text"] = "خطأ: $error";
        });
      },
    );
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty || !_isModelReady) return;
    String userText = _controller.text;
    
    // إضافة تعليمات النظام لتعليم الموديل كيفية البحث
    String systemPrompt = """
أنت مساعد ذكي. إذا لم تكن تعرف الإجابة أو احتجت لمعلومات حديثة، يمكنك البحث في الإنترنت.
لكي تبحث، اكتب هذه الصيغة فقط: [SEARCH: كلمة_البحث]
سؤال المستخدم: $userText
""";

    setState(() {
      _messages.add({"role": "user", "text": userText});
      _controller.clear();
    });
    
    _generateResponse(systemPrompt);
  }

  void _runTradingAgent() async {
    if (!_isModelReady) return;
    setState(() {
      _messages.add({"role": "user", "text": "قم بتحليل الذهب الآن."});
    });

    TradingAgent agent = TradingAgent();
    String data = await agent.fetchGoldPrices();
    String prompt = agent.generateTAPrompt(data);
    
    _generateResponse(prompt);
  }

  @override
  void dispose() {
    _generationSub?.cancel();
    _llama.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isModelReady ? 'وكيل ذكي متصل' : 'جاري تحميل الموديل...'),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart, color: Colors.amber),
            onPressed: (_isLoading || !_isModelReady) ? null : _runTradingAgent,
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
                return _buildMessageBubble(msg['text'], msg['role'] == 'user');
              },
            ),
          ),
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: _isModelReady && !_isLoading,
                    decoration: const InputDecoration(hintText: "اسأل عن أي شيء...", border: OutlineInputBorder()),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.teal),
                  onPressed: (_isLoading || !_isModelReady) ? null : _sendMessage,
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
                data: text.isEmpty ? "..." : text,
                selectable: true,
                builders: {'pre': CodeElementBuilder()},
              ),
      ),
    );
  }
}
