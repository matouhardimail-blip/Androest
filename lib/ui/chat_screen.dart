import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/chat_message.dart';
import '../services/llm_service.dart';
import 'widgets/composer.dart';
import 'widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.llm});

  final LlmService llm;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final List<ChatMessage> _messages = <ChatMessage>[];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  StreamSubscription<String>? _sub;
  bool _generating = false;
  String _status = '';
  double _contextUsage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messages.add(ChatMessage(
      role: ChatRole.assistant,
      text: 'أهلاً! أنا مساعد يعمل بالكامل داخل هاتفك، دون أي اتصال بالإنترنت. كيف أساعدك؟',
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // عند الانتقال للخلفية: أوقف الاستدلال فوراً وحرّر ~500 MB من RAM.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _haltGeneration();
      widget.llm.release();
      if (mounted) {
        setState(() => _status = 'تم تفريغ النموذج من الذاكرة، سيعود عند أول رسالة');
      }
    }
  }

  void _haltGeneration({bool notify = true}) {
    _sub?.cancel();
    _sub = null;
    if (_generating) {
      _generating = false;
      if (_messages.isNotEmpty) _messages.last.finalize();
      if (notify && mounted) setState(() {});
    }
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _generating) return;
    _input.clear();

    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, text: text));
      _messages.add(ChatMessage(
          role: ChatRole.assistant, isStreaming: true));
      _generating = true;
      _status = 'جارٍ التجهيز…';
    });
    _scrollToBottom();

    try {
      await widget.llm.ensureReady((String s) {
        if (mounted) setState(() => _status = s);
      });
      if (mounted) setState(() => _status = 'جارٍ كتابة الرد…');

      _sub = widget.llm.streamReply(_messages).listen(
        (String token) {
          if (!mounted) return;
          setState(() => _messages.last.text += token);
          _scrollToBottom();
        },
        onError: (Object e) => _finish('خطأ أثناء التوليد: $e'),
        onDone: () => _finish(''),
        cancelOnError: true,
      );
    } catch (e) {
      _finish('تعذّر بدء التوليد: $e');
    }
  }

  void _finish(String error) {
    if (!_generating) return;
    _sub?.cancel();
    _sub = null;
    if (!mounted) return;
    setState(() {
      _generating = false;
      final ChatMessage reply = _messages.last;
      reply.finalize();
      if (reply.text.isEmpty) {
        reply.text = error.isNotEmpty ? error : 'لم يُنتج النموذج رداً، جرّب مجدداً.';
      } else if (error.isNotEmpty) {
        reply.text = '${reply.text}\n\n$error';
      }
      _status = error;
    });
    _scrollToBottom();
    _refreshUsage();
  }

  Future<void> _stop() async {
    _sub?.cancel();
    _sub = null;
    await widget.llm.stopGeneration();
    _finish('');
  }

  Future<void> _refreshUsage() async {
    final v = await widget.llm.contextUsage();
    if (mounted) setState(() => _contextUsage = v);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _clearChat() {
    if (_generating) return;
    setState(() {
      _messages
        ..clear()
        ..add(ChatMessage(
          role: ChatRole.assistant,
          text: 'تم بدء محادثة جديدة.',
        ));
      _contextUsage = 0;
      _status = '';
    });
  }

  @override
  void dispose() {
    _haltGeneration(notify: false);
    WidgetsBinding.instance.removeObserver(this);
    widget.llm.release();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = ModelSpec.active;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('AgentPhone', style: TextStyle(fontSize: 17)),
            Text(
              '${spec.label}  ·  دون إنترنت',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'محادثة جديدة',
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // شريط حالة يوضّح ضبط الأداء (مفيد للتشخيص على الجهاز الحقيقي)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            color: Colors.teal.shade50,
            child: Text(
              'CPU فقط · ${DeviceProfile.threads} threads · ctx ${DeviceProfile.contextSize} '
              '· max ${DeviceProfile.maxTokens} tok · استخدام السياق ${_contextUsage.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 11, color: Colors.teal.shade900),
              textAlign: TextAlign.center,
            ),
          ),
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              child: Text(_status,
                  style: const TextStyle(fontSize: 12, color: Colors.orange)),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              itemCount: _messages.length,
              itemBuilder: (BuildContext context, int i) =>
                  MessageBubble(message: _messages[i]),
            ),
          ),
          Composer(
            controller: _input,
            isGenerating: _generating,
            onSend: _send,
            onStop: _stop,
          ),
        ],
      ),
    );
  }
}
