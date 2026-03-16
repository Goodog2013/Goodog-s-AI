import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.index});

  final ChatMessage message;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final colors = Theme.of(context).colorScheme;
    final chatTheme = Theme.of(context).extension<ChatThemeExtension>();
    final baseBubbleColor = isUser
        ? (chatTheme?.userBubbleColor ?? colors.primaryContainer)
        : (chatTheme?.assistantBubbleColor ?? colors.surfaceContainerHighest);

    return TweenAnimationBuilder<double>(
      key: ValueKey<String>(message.id),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + (index % 4) * 30),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  baseBubbleColor,
                  Color.lerp(baseBubbleColor, colors.surface, 0.24)!,
                ],
              ),
              border: Border.all(
                color: isUser
                    ? colors.primary.withValues(alpha: 0.3)
                    : colors.outlineVariant.withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: SelectableText(
                message.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
