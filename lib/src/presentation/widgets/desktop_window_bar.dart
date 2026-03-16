import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/app_theme.dart';

class DesktopWindowBar extends StatefulWidget {
  const DesktopWindowBar({
    super.key,
    required this.title,
    required this.onOpenSettings,
    required this.settingsTooltip,
    required this.minimizeTooltip,
    required this.maximizeTooltip,
    required this.restoreTooltip,
    required this.closeTooltip,
  });

  final String title;
  final VoidCallback onOpenSettings;
  final String settingsTooltip;
  final String minimizeTooltip;
  final String maximizeTooltip;
  final String restoreTooltip;
  final String closeTooltip;

  static bool get isSupported => !kIsWeb && Platform.isWindows;

  @override
  State<DesktopWindowBar> createState() => _DesktopWindowBarState();
}

class _DesktopWindowBarState extends State<DesktopWindowBar>
    with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    if (DesktopWindowBar.isSupported) {
      windowManager.addListener(this);
      _syncWindowState();
    }
  }

  @override
  void dispose() {
    if (DesktopWindowBar.isSupported) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowMaximize() => _syncWindowState();

  @override
  void onWindowUnmaximize() => _syncWindowState();

  Future<void> _syncWindowState() async {
    if (!DesktopWindowBar.isSupported || !mounted) {
      return;
    }
    final isMaximized = await windowManager.isMaximized();
    if (!mounted) {
      return;
    }
    setState(() {
      _isMaximized = isMaximized;
    });
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    _syncWindowState();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final chatTheme = Theme.of(context).extension<ChatThemeExtension>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_isMaximized ? 6 : 18),
          bottom: const Radius.circular(14),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color:
                  chatTheme?.panelColor ??
                  colors.surface.withValues(alpha: 0.88),
              border: Border.all(
                color:
                    chatTheme?.panelBorderColor ??
                    colors.outlineVariant.withValues(alpha: 0.35),
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(_isMaximized ? 6 : 18),
                bottom: const Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DragToMoveArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset(
                              'assets/app_icon.png',
                              width: 18,
                              height: 18,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.smart_toy_rounded,
                                  size: 18,
                                  color: colors.primary,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _WindowActionButton(
                  tooltip: widget.settingsTooltip,
                  icon: Icons.tune_rounded,
                  onTap: widget.onOpenSettings,
                ),
                _WindowActionButton(
                  tooltip: widget.minimizeTooltip,
                  icon: Icons.remove_rounded,
                  onTap: () => windowManager.minimize(),
                ),
                _WindowActionButton(
                  tooltip: _isMaximized
                      ? widget.restoreTooltip
                      : widget.maximizeTooltip,
                  icon: _isMaximized
                      ? Icons.filter_none_rounded
                      : Icons.crop_square_rounded,
                  onTap: _toggleMaximize,
                ),
                _WindowActionButton(
                  tooltip: widget.closeTooltip,
                  icon: Icons.close_rounded,
                  danger: true,
                  onTap: () => windowManager.close(),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowActionButton extends StatefulWidget {
  const _WindowActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_WindowActionButton> createState() => _WindowActionButtonState();
}

class _WindowActionButtonState extends State<_WindowActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = widget.danger
        ? (_hovered ? const Color(0xFFD63C45) : Colors.transparent)
        : (_hovered
              ? colors.primary.withValues(alpha: 0.16)
              : Colors.transparent);
    final iconColor = widget.danger && _hovered
        ? Colors.white
        : colors.onSurface;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            width: 36,
            height: 34,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }
}
