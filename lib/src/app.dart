import 'package:flutter/material.dart';

import 'presentation/controllers/chat_controller.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/chat_screen.dart';
import 'presentation/theme/app_theme.dart';

class GoodogsChatApp extends StatefulWidget {
  const GoodogsChatApp({super.key, required this.chatController});

  final ChatController chatController;

  @override
  State<GoodogsChatApp> createState() => _GoodogsChatAppState();
}

class _GoodogsChatAppState extends State<GoodogsChatApp> {
  @override
  void dispose() {
    widget.chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.chatController,
      builder: (context, _) {
        final settings = widget.chatController.settings;
        return MaterialApp(
          title: "Goodog's AI",
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(settings.palette),
          darkTheme: AppTheme.dark(settings.palette),
          themeMode: settings.flutterThemeMode,
          themeAnimationDuration: const Duration(milliseconds: 350),
          themeAnimationCurve: Curves.easeOutCubic,
          home: widget.chatController.requiresAuthentication
              ? AuthScreen(controller: widget.chatController)
              : ChatScreen(controller: widget.chatController),
        );
      },
    );
  }
}
