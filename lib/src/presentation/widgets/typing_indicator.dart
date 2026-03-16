import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final chatTheme = Theme.of(context).extension<ChatThemeExtension>();
    final bubble =
        chatTheme?.assistantBubbleColor ?? colors.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Align(
          alignment: Alignment.centerLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bubble,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Dot(
                    scale: _scaleAt(0.0, _controller.value),
                    color: colors.primary,
                  ),
                  const SizedBox(width: 6),
                  _Dot(
                    scale: _scaleAt(0.2, _controller.value),
                    color: colors.primary,
                  ),
                  const SizedBox(width: 6),
                  _Dot(
                    scale: _scaleAt(0.4, _controller.value),
                    color: colors.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Модель печатает',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double _scaleAt(double shift, double value) {
    final adjusted = (value + shift) % 1.0;
    return 0.72 + (math.sin(adjusted * math.pi * 2) * 0.5 + 0.5) * 0.5;
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.scale, required this.color});

  final double scale;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
