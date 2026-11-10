import 'package:flutter/material.dart';

/// حقل الإدخال + زر الإرسال / الإيقاف.
class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool isGenerating;
  final Future<void> Function(String) onSend;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                enabled: !isGenerating,
                textDirection: TextDirection.rtl,
                textInputAction: TextInputAction.send,
                onSubmitted: isGenerating ? null : (String v) => onSend(v),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالتك…',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (isGenerating)
              IconButton.filled(
                tooltip: 'إيقاف التوليد',
                onPressed: () => onStop(),
                icon: const Icon(Icons.stop),
              )
            else
              IconButton.filled(
                tooltip: 'إرسال',
                onPressed: () => onSend(controller.text),
                icon: const Icon(Icons.send),
              ),
          ],
        ),
      ),
    );
  }
}
