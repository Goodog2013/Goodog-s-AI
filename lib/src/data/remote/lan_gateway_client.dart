import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../models/chat_message.dart';
import '../../models/user_profile.dart';

class LanGatewayClient {
  LanGatewayClient({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  final http.Client Function() _clientFactory;
  http.Client? _activeClient;
  bool _cancelRequested = false;

  Future<UserProfile> syncProfile({
    required String gatewayBaseUrl,
    required String profileId,
    required String profileName,
  }) async {
    final response = await _post(
      Uri.parse('${_normalize(gatewayBaseUrl)}/api/sync-profile'),
      body: {'profileId': profileId, 'profileName': profileName},
    );
    final profileJson = response['profile'];
    if (profileJson is! Map<String, dynamic>) {
      throw const LanGatewayException('Шлюз вернул некорректный профиль.');
    }
    return UserProfile.fromJson(profileJson);
  }

  Future<GatewayChatResult> requestChat({
    required String gatewayBaseUrl,
    required String profileId,
    required String profileName,
    required String model,
    required double temperature,
    required List<ChatMessage> messages,
  }) async {
    final response = await _post(
      Uri.parse('${_normalize(gatewayBaseUrl)}/api/chat'),
      body: {
        'profileId': profileId,
        'profileName': profileName,
        'model': model,
        'temperature': temperature,
        'messages': messages.map((m) => m.toApiJson()).toList(),
      },
    );

    final reply = response['reply'];
    if (reply is! String || reply.trim().isEmpty) {
      throw const LanGatewayException('Шлюз вернул пустой ответ.');
    }

    final profileJson = response['profile'];
    final profile = profileJson is Map<String, dynamic>
        ? UserProfile.fromJson(profileJson)
        : UserProfile.initial(id: profileId, name: profileName);

    return GatewayChatResult(reply: reply.trim(), profile: profile);
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

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const LanGatewayException(
          'Шлюз вернул неожиданный формат ответа.',
        );
      }
      return decoded;
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
  const GatewayChatResult({required this.reply, required this.profile});

  final String reply;
  final UserProfile profile;
}

class LanGatewayException implements Exception {
  const LanGatewayException(this.message, {this.isCancelled = false});

  final String message;
  final bool isCancelled;

  @override
  String toString() => message;
}

const String cancelledByUserMessage = 'Генерация остановлена.';
