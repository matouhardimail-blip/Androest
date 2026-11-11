import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:async';
import 'dart:io';
import 'package:markdown/markdown.dart' as md;
import 'package:llama_flutter_android/llama_flutter_android.dart';

import 'model_downloader.dart';
import 'code_bubble.dart';
import 'web_search.dart';
import 'trading_agent.dart';
import 'agent_system.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi-Agent System',
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
            const Icon(Icons.hub, size: 80, color: Colors.teal),
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
  late Orchestrator _orchestrator;

  @override
  void initState() {
    super.initState();
    _orchestrator = Orchestrator(_llama);
    _initModel();
  }

  Future<void> _initModel() async {
    try {
      await _llama.loadModel(
        modelPath: widget.modelPath,
        contextSize: 2048,
      );
      setState(() {
        _isModelReady = true;
        _messages.add({"role": "ai", "text": "نظام الوكلاء جاهز. اكتب طلبك (مثلاً: ابحث عن الطقس، حلل الذهب، حلل عملة DOGE)."});
      });
    } catch (e) {
      setState(() {
        _messages.add({"role": "ai", "text": "فشل تحميل الموديل: $e"});
      });
    }
  }

  void _executeAgentTask(Agent agent, String prompt, {bool isSearchResult = false}) async {
    String currentResponse = "";
    setState(() {
      _isLoading = true;
      _messages.add({"role": "ai", "text": "الوكيل (${agent.name}): "});
    });

    String fullPrompt = "${agent.systemPrompt}\n\nطلب المستخدم: $prompt\nالرد:";

    _generationSub = _llama.generate(
      prompt: fullPrompt,
      maxTokens: 256,
      temperature: 0.1,
    ).listen(
      (token) async {
        currentResponse += token;
        
        if (!isSearchResult && agent.name == "وكيل البحث") {
           setState(() {
             _messages.last["text"] = "الوكيل (${agent.name}):\n🔍 جاري تحليل الطلب للبحث...";
           });
        } else {
           setState(() {
             _messages.last["text"] = "الوكيل (${agent.name}):\n" + currentResponse;
           });
        }

        if (!isSearchResult && currentResponse.contains("[SEARCH:")) {
          await _generationSub?.cancel();
          
          RegExp regExp = RegExp(r'\[SEARCH:\s*(.*?)\]');
          var match = regExp.firstMatch(currentResponse);
          String query = match?.group(1)?.trim() ?? "";
          query = query.replaceAll(RegExp(r'[^\w\s]'), '');

          if (query.isNotEmpty) {
            setState(() {
              _messages.last["text"] = "الوكيل (${agent.name}):\n🔍 جاري البحث في الإنترنت عن: $query...";
            });

            WebSearch searcher = WebSearch();
            String searchResults = await searcher.search(query);

            setState(() => _messages.removeLast());

            String searchPrompt = """
لقد بحثت في الإنترنت عن "$query" وحصلت على المعلومات التالية:
$searchResults

المستخدم سأل: $prompt
الآن أجب على المستخدم باللغة العربية بناءً على هذه المعلومات. لا تطلب بحثاً آخر. كن دقيقاً.
""";
            _executeAgentTask(agent, searchPrompt, isSearchResult: true);
          } else {
             setState(() {
               _messages.last["text"] = "الوكيل (${agent.name}):\nلم أتمكن من فهم كلمة البحث، جرب صياغة أخرى.";
               _isLoading = false;
             });
          }
        }
      },
      onDone: () {
        setState(() => _isLoading = false);
        _llama.clearContext(); 
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
    
    setState(() {
      _messages.add({"role": "user", "text": userText});
      _controller.clear();
      _isLoading = true;
    });

    Agent assignedAgent = await _orchestrator.routeTask(userText);
    
    if (assignedAgent.name == "وكيل الذهب") {
      setState(() => _messages.add({"role": "ai", "text": "المنسق: سأستخدم وكيل الذهب لجلب الأسعار..."}));
      TradingAgent tradingAgent = TradingAgent();
      String data = await tradingAgent.fetchGoldPrices();
      _executeAgentTask(assignedAgent, "بيانات السوق:\n$data\nحلل الاتجاه.");
      
    } else if (assignedAgent.name == "وكيل الميم كوينز") {
      setState(() => _messages.add({"role": "ai", "text": "المنسق: سأستخدم وكيل الميم كوينز..."}));
      String symbol = "DOGE"; 
      if (userText.toUpperCase().contains("PEPE")) symbol = "PEPE";
      if (userText.toUpperCase().contains("SHIB")) symbol = "SHIB";
      
      TradingAgent tradingAgent = TradingAgent();
      String data = await tradingAgent.fetchMemeCoinPrices(symbol);
      _executeAgentTask(assignedAgent, "بيانات العملة:\n$data\nحلل هذا الاتجاه وأعطني قراراً.");
      
    } else {
      _executeAgentTask(assignedAgent, userText);
    }
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
        title: Text(_isModelReady ? 'نظام الوكلاء المتعدد' : 'جاري التحميل...'),
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
                    decoration: const InputDecoration(hintText: "أعطِ أمراً للمنسق...", border: OutlineInputBorder()),
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
