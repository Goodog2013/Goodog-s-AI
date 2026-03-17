import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../models/auth_account.dart';
import '../../models/auth_session.dart';
import '../../models/chat_message.dart';
import '../../models/user_profile.dart';

class LanGatewayClient {
  LanGatewayClient({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  final http.Client Function() _clientFactory;
  http.Client? _activeClient;
  bool _cancelRequested = false;

  Future<AuthSession?> fetchAuthSession({
    required String gatewayBaseUrl,
  }) async {
    final response = await _get(
      Uri.parse('${_normalize(gatewayBaseUrl)}/api/auth/session'),
    );
    final authenticated = response['authenticated'] as bool? ?? false;
    if (!authenticated) {
      return null;
    }
    return _parseAuthSession(response);
  }

  Future<AuthSession> register({
    required String gatewayBaseUrl,
    required String login,
    required String password,
    required String email,
    required String name,
  }) async {
    final response = await _post(
      Uri.parse('${_normalize(gatewayBaseUrl)}/api/auth/register'),
      body: {
        'login': login,
        'password': password,
        'email': email,
        'name': name,
      },
    );
    return _parseAuthSession(response);
  }

  Future<AuthSession> login({
    required String gatewayBaseUrl,
    required String login,
    required String password,
  }) async {
    final response = await _post(
      Uri.parse('${_normalize(gatewayBaseUrl)}/api/auth/login'),
      body: {'login': login, 'password': password},
    );
    return _parseAuthSession(response);
  }

  Future<void> logout({required String gatewayBaseUrl}) async {
    await _post(
      Uri.parse('${_normalize(gatewayBaseUrl)}/api/auth/logout'),
      body: const <String, dynamic>{},
    );
  }

  Future<GatewayChatResult> requestChat({
    required String gatewayBaseUrl,
    required String model,
    required double temperature,
    required List<ChatMessage> messages,
  }) async {
    final response = await _post(
      Uri.parse('${_normalize(gatewayBaseUrl)}/api/chat'),
      body: {
        'model': model,
        'temperature': temperature,
        'messages': messages.map((m) => m.toApiJson()).toList(),
      },
    );

    final reply = response['reply'];
    if (reply is! String || reply.trim().isEmpty) {
      throw const LanGatewayException('Шлюз вернул пустой ответ.');
    }

    final profile = _parseProfile(response['profile']);
    final account = _parseAccount(response['account']);

    return GatewayChatResult(
      reply: reply.trim(),
      profile: profile,
      account: account,
    );
  }

  AuthSession _parseAuthSession(Map<String, dynamic> response) {
    final account = _parseAccount(response['account']);
    if (account == null) {
      throw const LanGatewayException(
        'Шлюз вернул некорректные данные аккаунта.',
      );
    }
    final profile = _parseProfile(response['profile']);
    if (profile == null) {
      throw const LanGatewayException(
        'Шлюз вернул некорректные данные профиля.',
      );
    }
    return AuthSession(account: account, profile: profile);
  }

  AuthAccount? _parseAccount(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    return AuthAccount.fromJson(raw);
  }

  UserProfile? _parseProfile(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    return UserProfile.fromJson(raw);
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final client = _clientFactory();
    _activeClient = client;
    _cancelRequested = false;

    try {
      final response = await client.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LanGatewayException(_extractError(response));
      }
      return _decodeResponse(response.body);
    } on SocketException {
      if (_cancelRequested) {
        throw const LanGatewayException(
          cancelledByUserMessage,
          isCancelled: true,
        );
      }
      throw const LanGatewayException(
        'Не удалось подключиться к LAN-шлюзу. Проверьте IP и порт в настройках.',
      );
    } on http.ClientException {
      if (_cancelRequested) {
        throw const LanGatewayException(
          cancelledByUserMessage,
          isCancelled: true,
        );
      }
      throw const LanGatewayException(
        'Ошибка HTTP-клиента при работе с LAN-шлюзом.',
      );
    } on FormatException {
      throw const LanGatewayException('Шлюз вернул некорректный JSON.');
    } finally {
      if (identical(_activeClient, client)) {
        _activeClient = null;
      }
      _cancelRequested = false;
      client.close();
    }
  }

  Future<Map<String, dynamic>> _post(
    Uri uri, {
    required Map<String, dynamic> body,
  }) async {
    final client = _clientFactory();
    _activeClient = client;
    _cancelRequested = false;

    try {
      final response = await client.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LanGatewayException(_extractError(response));
      }
      return _decodeResponse(response.body);
    } on SocketException {
      if (_cancelRequested) {
        throw const LanGatewayException(
          cancelledByUserMessage,
          isCancelled: true,
        );
      }
      throw const LanGatewayException(
        'Не удалось подключиться к LAN-шлюзу. Проверьте IP и порт в настройках.',
      );
    } on http.ClientException {
      if (_cancelRequested) {
        throw const LanGatewayException(
          cancelledByUserMessage,
          isCancelled: true,
        );
      }
      throw const LanGatewayException(
        'Ошибка HTTP-клиента при работе с LAN-шлюзом.',
      );
    } on FormatException {
      throw const LanGatewayException('Шлюз вернул некорректный JSON.');
    } finally {
      if (identical(_activeClient, client)) {
        _activeClient = null;
      }
      _cancelRequested = false;
      client.close();
    }
  }

  Map<String, dynamic> _decodeResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object');
    }
    return decoded;
  }

  String _extractError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['error'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } on FormatException {
      // No-op, fallback below.
    }
    return 'LAN-шлюз вернул HTTP ${response.statusCode}.';
  }

  String _normalize(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  void cancelActiveRequest() {
    _cancelRequested = true;
    _activeClient?.close();
    _activeClient = null;
  }

  void dispose() {
    cancelActiveRequest();
  }
}

class GatewayChatResult {
  const GatewayChatResult({
    required this.reply,
    required this.profile,
    required this.account,
  });

  final String reply;
  final UserProfile? profile;
  final AuthAccount? account;
}

class LanGatewayException implements Exception {
  const LanGatewayException(this.message, {this.isCancelled = false});

  final String message;
  final bool isCancelled;

  @override
  String toString() => message;
}

const String cancelledByUserMessage = 'Генерация остановлена.';
