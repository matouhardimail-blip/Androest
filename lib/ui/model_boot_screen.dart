import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/llm_service.dart';
import 'chat_screen.dart';

/// شاشة التحميل الأولى: مؤشر واضح أثناء التنزيل + أثناء تحميل الأوزان في RAM.
/// تظهر مرة واحدة فقط؛ بعدها يبقى النموذج على الجهاز ويعمل offline بالكامل.
class ModelBootScreen extends StatefulWidget {
  const ModelBootScreen({super.key});

  @override
  State<ModelBootScreen> createState() => _ModelBootScreenState();
}

class _ModelBootScreenState extends State<ModelBootScreen> {
  final LlmService _llm = LlmService();
  CancelToken _cancelToken = CancelToken();

  BootPhase _phase = BootPhase.checking;
  double _progress = 0;
  String _status = 'جارٍ التهيئة…';
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    _cancelToken = CancelToken();
    setState(() {
      _error = null;
      _phase = BootPhase.checking;
      _progress = 0;
    });

    try {
      await _llm.prepare(
        cancelToken: _cancelToken,
        onStatus: (BootPhase phase, double progress, String text) {
          if (!mounted) return;
          setState(() {
            _phase = phase;
            _progress = progress.clamp(0.0, 1.0);
            _status = text;
          });
        },
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => ChatScreen(llm: _llm)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = BootPhase.failed;
        _error = e.toString();
      });
    }
  }

  String get _phaseTitle {
    switch (_phase) {
      case BootPhase.checking:
        return 'فحص الجهاز';
      case BootPhase.downloading:
        return 'تنزيل النموذج (مرة واحدة)';
      case BootPhase.loading:
        return 'تحميل النموذج في الذاكرة';
      case BootPhase.failed:
        return 'تعذّر التجهيز';
      case BootPhase.ready:
        return 'جاهز';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (_progress * 100).toStringAsFixed(0);
    final spec = ModelSpec.active;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.smartphone,
                          size: 34, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Text('AgentPhone',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('ذكاء اصطناعي محلي بالكامل · Galaxy A52',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey.shade700)),
                    const SizedBox(height: 24),

                    // بطاقة النموذج
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.memory, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(spec.label,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                Text('GGUF · ${spec.sizeMB.toStringAsFixed(0)} MB',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(_phaseTitle,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),

                    if (_phase != BootPhase.failed) ...<Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          minHeight: 10,
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Text(_status,
                                style: theme.textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text('$percent%',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],

                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _boot,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة (استئناف)'),
                      ),
                    ],

                    if (_phase == BootPhase.downloading)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton.icon(
                          onPressed: () {
                            _cancelToken.cancel('ألغى المستخدم التنزيل');
                          },
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('إلغاء التنزيل'),
                        ),
                      ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const <Widget>[
                        Icon(Icons.wifi_off, size: 16, color: Colors.green),
                        SizedBox(width: 6),
                        Text('بعد التنزيل الأول يعمل التطبيق دون إنترنت',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
