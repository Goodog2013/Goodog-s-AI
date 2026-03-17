import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'src/admin/admin_app.dart';
import 'src/admin/auth_store.dart';
import 'src/admin/lan_gateway_server.dart';
import 'src/admin/profile_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      title: "Goodog's AI Admin",
      center: true,
      size: Size(1180, 820),
      minimumSize: Size(960, 620),
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final supportDir = await getApplicationSupportDirectory();
  final profilesFile = File(
    '${supportDir.path}${Platform.pathSeparator}goodogs_profiles.json',
  );
  final authFile = File(
    '${supportDir.path}${Platform.pathSeparator}goodogs_auth.json',
  );
  final profileStore = ProfileStore(file: profilesFile);
  final authStore = AuthStore(file: authFile);
  final server = LanGatewayServer(
    profileStore: profileStore,
    authStore: authStore,
  );

  runApp(GoodogsAdminApp(server: server));
}
