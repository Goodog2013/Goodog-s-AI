import 'dart:convert';
import 'dart:io';

import '../models/user_profile.dart';

class ProfileStore {
  ProfileStore({required File file}) : _file = file;

  final File _file;

  Future<Map<String, UserProfile>> loadProfiles() async {
    if (!await _file.exists()) {
      return <String, UserProfile>{};
    }
    try {
      final content = await _file.readAsString();
      if (content.trim().isEmpty) {
        return <String, UserProfile>{};
      }
      final decoded = jsonDecode(content);
      if (decoded is! List) {
        return <String, UserProfile>{};
      }
      final map = <String, UserProfile>{};
      for (final item in decoded.whereType<Map>()) {
        final profile = UserProfile.fromJson(item.cast<String, dynamic>());
        map[profile.id] = profile;
      }
      return map;
    } on FormatException {
      return <String, UserProfile>{};
    }
  }

  Future<void> saveProfiles(Iterable<UserProfile> profiles) async {
    final parent = _file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final encoded = jsonEncode(
      profiles.map((profile) => profile.toJson()).toList(growable: false),
    );
    await _file.writeAsString(encoded);
  }
}
