import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../models/chat_message.dart';
import '../../models/chat_settings.dart';

class LmStudioApiClient {
  LmStudioApiClient({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  final http.Client Function() _clientFactory;
  http.Client? _activeClient;
  bool _cancelRequested = false;

  static const String cancelledByUserMessage = 'Генерация остановлена.';

  Future<String> createChatCompletion({
    required ChatSettings settings,
    required List<ChatMessage> messages,
  }) async {
    final uri = Uri.parse('${settings.normalizedBaseUrl}/v1/chat/completions');
    final payload = <String, dynamic>{
      'model': settings.model,
      'messages': messages.map((message) => message.toApiJson()).toList(),
      'temperature': settings.temperature,
    };
    final requestClient = _clientFactory();
    _activeClient = requestClient;
    _cancelRequested = false;

    try {
      final response = await requestClient.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ChatApiException(
          _extractErrorMessage(response.body, response.statusCode),
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ChatApiException(
          'Сервер вернул неожиданный формат ответа.',
        );
      }

      final reply = _extractAssistantReply(decoded);
      if (reply == null || reply.trim().isEmpty) {
        throw const ChatApiException('Модель вернула пустой ответ.');
      }

      return reply.trim();
    } on ChatApiException {
      rethrow;
    } on SocketException {
      if (_cancelRequested) {
        throw const ChatApiException(cancelledByUserMessage, isCancelled: true);
      }
      throw const ChatApiException(
        'Не удалось подключиться к LM Studio. Проверьте URL и сеть.',
      );
    } on http.ClientException {
      if (_cancelRequested) {
        throw const ChatApiException(cancelledByUserMessage, isCancelled: true);
      }
      throw const ChatApiException(
        'Ошибка HTTP-клиента при обращении к LM Studio.',
      );
    } on FormatException {
      throw const ChatApiException('Сервер вернул некорректный JSON.');
    } on Exception {
      if (_cancelRequested) {
        throw const ChatApiException(cancelledByUserMessage, isCancelled: true);
      }
      rethrow;
    } finally {
      if (identical(_activeClient, requestClient)) {
        _activeClient = null;
      }
      _cancelRequested = false;
      requestClient.close();
    }
  }

  String _extractErrorMessage(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String && message.trim().isNotEmpty) {
            return 'Ошибка LM Studio: ${message.trim()}';
          }
        }
      }
    } on FormatException {
      return 'LM Studio вернул HTTP $statusCode.';
    }

    return 'LM Studio вернул HTTP $statusCode.';
  }

  String? _extractAssistantReply(Map<String, dynamic> json) {
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) {
      return null;
    }

    final firstChoice = choices.first;
    if (firstChoice is! Map<String, dynamic>) {
      return null;
    }

    final message = firstChoice['message'];
    if (message is! Map<String, dynamic>) {
      return null;
    }

    final content = message['content'];
    if (content is String) {
      return content;
    }

    if (content is List) {
      final buffer = StringBuffer();
      for (final item in content) {
        if (item is String) {
          buffer.write(item);
          continue;
        }
        if (item is Map<String, dynamic>) {
          final text = item['text'];
          if (text is String) {
            buffer.write(text);
          }
        }
      }
      final normalized = buffer.toString();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return null;
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

class ChatApiException implements Exception {
  const ChatApiException(this.message, {this.isCancelled = false});

  final String message;
  final bool isCancelled;

  @override
  String toString() => message;
}
