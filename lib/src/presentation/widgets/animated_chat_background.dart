import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AnimatedChatBackground extends StatefulWidget {
  const AnimatedChatBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AnimatedChatBackground> createState() => _AnimatedChatBackgroundState();
}

class _AnimatedChatBackgroundState extends State<AnimatedChatBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatTheme = Theme.of(context).extension<ChatThemeExtension>();
    final gradient =
        chatTheme?.backgroundGradient ??
        const [Color(0xFFF1F4FB), Color(0xFFEAF2FF), Color(0xFFF4EEFF)];
    final overlay =
        chatTheme?.overlayGradient ??
        const [Color(0x44FFFFFF), Color(0x14FFFFFF)];
    final colors = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              return Stack(
                children: [
                  _GlowBlob(
                    alignment: Alignment(
                      -0.95 + math.sin(t * math.pi * 2) * 0.08,
                      -0.9 + math.cos(t * math.pi * 2) * 0.05,
                    ),
                    color: colors.primary.withValues(alpha: 0.2),
                    size: 230,
                  ),
                  _GlowBlob(
                    alignment: Alignment(
                      0.9 + math.sin((t + 0.35) * math.pi * 2) * 0.1,
                      -0.3 + math.cos((t + 0.35) * math.pi * 2) * 0.08,
                    ),
                    color: colors.tertiary.withValues(alpha: 0.2),
                    size: 260,
                  ),
                  _GlowBlob(
                    alignment: Alignment(
                      0.65 + math.sin((t + 0.7) * math.pi * 2) * 0.06,
                      0.95 + math.cos((t + 0.7) * math.pi * 2) * 0.04,
                    ),
                    color: colors.secondary.withValues(alpha: 0.16),
                    size: 320,
                  ),
                ],
              );
            },
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: overlay,
                ),
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.alignment,
    required this.color,
    required this.size,
  });

  final Alignment alignment;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 80,
                spreadRadius: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
