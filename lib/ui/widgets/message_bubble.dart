import 'package:flutter/material.dart';

import '../../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool user = message.isUser;
    final Color bg = user
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final Color fg =
        user ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            user ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!user)
            CircleAvatar(
              radius: 15,
              backgroundColor: Colors.teal.shade100,
              child: const Icon(Icons.smartphone, size: 16, color: Colors.teal),
            ),
          if (!user) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(user ? 16 : 4),
                  bottomRight: Radius.circular(user ? 4 : 16),
                ),
              ),
              child: message.isStreaming && message.text.isEmpty
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: fg),
                        ),
                        const SizedBox(width: 8),
                        Text('يفكّر…',
                            style: TextStyle(color: fg, fontSize: 13)),
                      ],
                    )
                  : Text.rich(
                      TextSpan(
                        style: TextStyle(color: fg, fontSize: 15, height: 1.5),
                        children: <TextSpan>[
                          TextSpan(text: message.text),
                          if (message.isStreaming)
                            TextSpan(
                              text: ' ▍',
                              style: TextStyle(color: fg.withAlpha(180)),
                            ),
                        ],
                      ),
                      textDirection: TextDirection.rtl,
                    ),
            ),
          ),
          if (user) const SizedBox(width: 8),
          if (user)
            CircleAvatar(
              radius: 15,
              backgroundColor: Colors.grey.shade300,
              child: const Icon(Icons.person, size: 16, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}
