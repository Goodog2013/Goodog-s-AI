import 'dart:convert';
import 'dart:io';

import '../models/auth_account.dart';

class AuthStore {
  AuthStore({required File file}) : _file = file;

  final File _file;

  Future<AuthSnapshot> loadSnapshot() async {
    if (!await _file.exists()) {
      return const AuthSnapshot.empty();
    }
    try {
      final content = await _file.readAsString();
      if (content.trim().isEmpty) {
        return const AuthSnapshot.empty();
      }
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        return const AuthSnapshot.empty();
      }
      return AuthSnapshot.fromJson(decoded);
    } on FormatException {
      return const AuthSnapshot.empty();
    }
  }

  Future<void> saveSnapshot(AuthSnapshot snapshot) async {
    final parent = _file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final encoded = jsonEncode(snapshot.toJson());
    await _file.writeAsString(encoded);
  }
}

class AuthSnapshot {
  const AuthSnapshot({required this.accounts, required this.ipBindings});

  const AuthSnapshot.empty()
    : accounts = const <String, AuthAccount>{},
      ipBindings = const <String, String>{};

  final Map<String, AuthAccount> accounts;
  final Map<String, String> ipBindings;

  factory AuthSnapshot.fromJson(Map<String, dynamic> json) {
    final accountsRaw = json['accounts'];
    final bindingsRaw = json['ipBindings'];

    final accountsMap = <String, AuthAccount>{};
    if (accountsRaw is List) {
      for (final item in accountsRaw.whereType<Map>()) {
        final account = AuthAccount.fromJson(item.cast<String, dynamic>());
        if (account.id.isNotEmpty) {
          accountsMap[account.id] = account;
        }
      }
    }

    final bindingMap = <String, String>{};
    if (bindingsRaw is Map) {
      for (final entry in bindingsRaw.entries) {
        final ip = entry.key.trim();
        final accountId = (entry.value ?? '').toString().trim();
        if (ip.isNotEmpty && accountId.isNotEmpty) {
          bindingMap[ip] = accountId;
        }
      }
    }

    return AuthSnapshot(accounts: accountsMap, ipBindings: bindingMap);
  }

  Map<String, dynamic> toJson() {
    return {
      'accounts': accounts.values.map((account) => account.toJson()).toList(),
      'ipBindings': ipBindings,
    };
  }
}
