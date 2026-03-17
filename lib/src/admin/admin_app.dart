import 'package:flutter/material.dart';

import 'admin_screen.dart';
import 'lan_gateway_server.dart';

class GoodogsAdminApp extends StatefulWidget {
  const GoodogsAdminApp({super.key, required this.server});

  final LanGatewayServer server;

  @override
  State<GoodogsAdminApp> createState() => _GoodogsAdminAppState();
}

class _GoodogsAdminAppState extends State<GoodogsAdminApp> {
  @override
  void dispose() {
    widget.server.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Goodog's AI Admin",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E7F67)),
        useMaterial3: true,
      ),
      home: AdminScreen(server: widget.server),
    );
  }
}
