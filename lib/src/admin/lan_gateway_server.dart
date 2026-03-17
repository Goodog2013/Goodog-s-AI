import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../data/remote/lm_studio_api_client.dart';
import '../models/auth_account.dart';
import '../models/chat_message.dart';
import '../models/chat_settings.dart';
import '../models/user_plan.dart';
import '../models/user_profile.dart';
import 'auth_store.dart';
import 'profile_store.dart';

class LanGatewayServer {
  LanGatewayServer({
    required ProfileStore profileStore,
    required AuthStore authStore,
    LmStudioApiClient? lmStudioApiClient,
  }) : _profileStore = profileStore,
       _authStore = authStore,
       _lmStudioApiClient = lmStudioApiClient ?? LmStudioApiClient();

  final ProfileStore _profileStore;
  final AuthStore _authStore;
  final LmStudioApiClient _lmStudioApiClient;
  final StreamController<void> _updates = StreamController<void>.broadcast();
  final Random _random = Random.secure();

  final Map<String, UserProfile> _profiles = <String, UserProfile>{};
  final Map<String, AuthAccount> _accounts = <String, AuthAccount>{};
  final Map<String, String> _ipBindings = <String, String>{};
  final List<_QueueJob> _queue = <_QueueJob>[];

  HttpServer? _server;
  bool _isProcessing = false;
  String? _activeProfileId;

  String _bindHost = '0.0.0.0';
  int _bindPort = 8088;
  String _lmStudioBaseUrl = ChatSettings.defaultBaseUrl;
  String _defaultModel = ChatSettings.defaultModel;

  Stream<void> get updates => _updates.stream;
  bool get isRunning => _server != null;
  bool get isProcessing => _isProcessing;
  int get queueLength => _queue.length;
  String? get activeProfileId => _activeProfileId;
  String get bindHost => _bindHost;
  int get bindPort => _bindPort;
  String get lmStudioBaseUrl => _lmStudioBaseUrl;
  String get defaultModel => _defaultModel;

  List<UserProfile> get profiles {
    final list = _profiles.values.toList(growable: false);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<AuthAccount> get accounts {
    final list = _accounts.values.toList(growable: false);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  AuthAccount? accountByProfileId(String profileId) {
    return _accounts[profileId];
  }

  Future<void> start({
    String host = '0.0.0.0',
    int port = 8088,
    String lmStudioBaseUrl = ChatSettings.defaultBaseUrl,
    String defaultModel = ChatSettings.defaultModel,
  }) async {
    if (_server != null) {
      return;
    }

    _bindHost = host.trim().isEmpty ? '0.0.0.0' : host.trim();
    _bindPort = port;
    _lmStudioBaseUrl = _normalizeUrl(lmStudioBaseUrl);
    _defaultModel = defaultModel.trim().isEmpty
        ? ChatSettings.defaultModel
        : defaultModel.trim();

    final loadedProfiles = await _profileStore.loadProfiles();
    _profiles
      ..clear()
      ..addAll(loadedProfiles);

    final authSnapshot = await _authStore.loadSnapshot();
    _accounts
      ..clear()
      ..addAll(authSnapshot.accounts);

    _ipBindings
      ..clear()
      ..addEntries(
        authSnapshot.ipBindings.entries.where(
          (entry) => _accounts.containsKey(entry.value),
        ),
      );

    _server = await HttpServer.bind(_bindHost, _bindPort);
    unawaited(_listenLoop(_server!));
    _emitUpdate();
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
    _queue.clear();
    _activeProfileId = null;
    _isProcessing = false;
    _emitUpdate();
  }

  Future<void> dispose() async {
    await stop();
    _updates.close();
    _lmStudioApiClient.dispose();
  }

  Future<void> setProfilePlan(String profileId, UserPlan plan) async {
    final existing = _profiles[profileId];
    if (existing == null) {
      return;
    }
    _profiles[profileId] = existing.copyWith(
      plan: plan,
      updatedAt: DateTime.now(),
    );
    await _persistProfiles();
    _emitUpdate();
  }

  Future<void> setProfileBan(String profileId, bool banned) async {
    final existing = _profiles[profileId];
    if (existing == null) {
      return;
    }
    _profiles[profileId] = existing.copyWith(
      isBanned: banned,
      updatedAt: DateTime.now(),
    );
    await _persistProfiles();
    _emitUpdate();
  }

  Future<void> _listenLoop(HttpServer server) async {
    await for (final request in server) {
      unawaited(_handleRequest(request));
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final method = request.method.toUpperCase();
      final segments = request.uri.pathSegments;

      if (method == 'GET' &&
          segments.length == 2 &&
          segments[0] == 'api' &&
          segments[1] == 'status') {
        await _writeJson(request.response, <String, dynamic>{
          'running': isRunning,
          'processing': isProcessing,
          'queueLength': queueLength,
          'activeProfileId': activeProfileId,
          'host': bindHost,
          'port': bindPort,
          'lmStudioBaseUrl': _lmStudioBaseUrl,
          'defaultModel': _defaultModel,
          'accountCount': _accounts.length,
          'boundIpCount': _ipBindings.length,
        });
        return;
      }

      if (method == 'GET' &&
          segments.length == 2 &&
          segments[0] == 'api' &&
          segments[1] == 'profiles') {
        await _writeJson(request.response, <String, dynamic>{
          'profiles': profiles.map((item) => item.toJson()).toList(),
        });
        return;
      }

      if (method == 'GET' &&
          segments.length == 2 &&
          segments[0] == 'api' &&
          segments[1] == 'accounts') {
        await _writeJson(request.response, <String, dynamic>{
          'accounts': accounts.map((item) => item.toPublicJson()).toList(),
        });
        return;
      }

      if (method == 'GET' &&
          segments.length == 3 &&
          segments[0] == 'api' &&
          segments[1] == 'auth' &&
          segments[2] == 'session') {
        await _handleAuthSession(request);
        return;
      }

      if (method == 'POST' &&
          segments.length == 3 &&
          segments[0] == 'api' &&
          segments[1] == 'auth' &&
          segments[2] == 'register') {
        await _handleAuthRegister(request);
        return;
      }

      if (method == 'POST' &&
          segments.length == 3 &&
          segments[0] == 'api' &&
          segments[1] == 'auth' &&
          segments[2] == 'login') {
        await _handleAuthLogin(request);
        return;
      }

      if (method == 'POST' &&
          segments.length == 3 &&
          segments[0] == 'api' &&
          segments[1] == 'auth' &&
          segments[2] == 'logout') {
        await _handleAuthLogout(request);
        return;
      }

      if (method == 'POST' &&
          segments.length == 2 &&
          segments[0] == 'api' &&
          segments[1] == 'chat') {
        await _handleChat(request);
        return;
      }

      if (method == 'POST' &&
          segments.length == 4 &&
          segments[0] == 'api' &&
          segments[1] == 'profiles') {
        final profileId = segments[2];
        final action = segments[3];
        final profile = _profiles[profileId];
        if (profile == null) {
          await _writeError(request.response, 'Профиль не найден.', 404);
          return;
        }

        final body = await _readJsonBody(request);
        if (action == 'plan') {
          final plan = UserPlanX.parse(body['plan'] as String?);
          await setProfilePlan(profileId, plan);
          await _writeJson(request.response, <String, dynamic>{
            'profile': _profiles[profileId]!.toJson(),
          });
          return;
        }
        if (action == 'ban') {
          final banned = body['banned'] as bool? ?? false;
          await setProfileBan(profileId, banned);
          await _writeJson(request.response, <String, dynamic>{
            'profile': _profiles[profileId]!.toJson(),
          });
          return;
        }
      }

      await _writeError(request.response, 'Not found.', 404);
    } on GatewayServerException catch (error) {
      await _writeError(request.response, error.message, 400);
    } on ChatApiException catch (error) {
      await _writeError(request.response, error.message, 502);
    } on FormatException {
      await _writeError(request.response, 'Некорректный JSON.', 400);
    } catch (_) {
      await _writeError(request.response, 'Внутренняя ошибка LAN-шлюза.', 500);
    }
  }

  Future<void> _handleAuthSession(HttpRequest request) async {
    final ip = _requestIp(request);
    final account = _currentAccountForIp(ip);
    if (account == null) {
      await _writeJson(request.response, <String, dynamic>{
        'authenticated': false,
      });
      return;
    }
    final profile = await _ensureProfileForAccount(account, persist: true);
    await _writeJson(request.response, <String, dynamic>{
      'authenticated': true,
      'account': account.toPublicJson(),
      'profile': profile.toJson(),
    });
  }

  Future<void> _handleAuthRegister(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final login = (body['login'] as String? ?? '').trim();
    final password = (body['password'] as String? ?? '').trim();
    final email = (body['email'] as String? ?? '').trim();
    final name = (body['name'] as String? ?? '').trim();

    _validateRegistration(
      login: login,
      password: password,
      email: email,
      name: name,
    );

    final loginLower = login.toLowerCase();
    final emailLower = email.toLowerCase();
    for (final existing in _accounts.values) {
      if (existing.login.toLowerCase() == loginLower) {
        throw const GatewayServerException('Логин уже занят.');
      }
      if (existing.email.toLowerCase() == emailLower) {
        throw const GatewayServerException('Email уже зарегистрирован.');
      }
    }

    final accountId = _generateAccountId();
    final salt = _generateSalt();
    final passwordHash = _hashPassword(password, salt);
    final now = DateTime.now();
    final account = AuthAccount(
      id: accountId,
      login: login,
      email: email,
      displayName: name,
      passwordHash: passwordHash,
      passwordSalt: salt,
      createdAt: now,
      updatedAt: now,
    );

    _accounts[account.id] = account;
    final profile = await _ensureProfileForAccount(account, persist: true);

    final ip = _requestIp(request);
    _ipBindings[ip] = account.id;
    await _persistAuth();
    _emitUpdate();

    await _writeJson(request.response, <String, dynamic>{
      'authenticated': true,
      'account': account.toPublicJson(),
      'profile': profile.toJson(),
    });
  }

  Future<void> _handleAuthLogin(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final login = (body['login'] as String? ?? '').trim();
    final password = (body['password'] as String? ?? '').trim();
    if (login.isEmpty || password.isEmpty) {
      throw const GatewayServerException('Введите логин и пароль.');
    }

    AuthAccount? account;
    final loginLower = login.toLowerCase();
    for (final item in _accounts.values) {
      if (item.login.toLowerCase() == loginLower ||
          item.email.toLowerCase() == loginLower) {
        account = item;
        break;
      }
    }
    if (account == null) {
      throw const GatewayServerException('Пользователь не найден.');
    }

    final expectedHash = _hashPassword(password, account.passwordSalt);
    if (expectedHash != account.passwordHash) {
      throw const GatewayServerException('Неверный пароль.');
    }

    final ip = _requestIp(request);
    _ipBindings[ip] = account.id;
    await _persistAuth();

    final profile = await _ensureProfileForAccount(account, persist: true);
    _emitUpdate();
    await _writeJson(request.response, <String, dynamic>{
      'authenticated': true,
      'account': account.toPublicJson(),
      'profile': profile.toJson(),
    });
  }

  Future<void> _handleAuthLogout(HttpRequest request) async {
    final ip = _requestIp(request);
    _ipBindings.remove(ip);
    await _persistAuth();
    _emitUpdate();
    await _writeJson(request.response, <String, dynamic>{'ok': true});
  }

  Future<void> _handleChat(HttpRequest request) async {
    final ip = _requestIp(request);
    final account = _currentAccountForIp(ip);
    if (account == null) {
      await _writeError(request.response, 'Нужно войти в аккаунт.', 401);
      return;
    }

    var profile = await _ensureProfileForAccount(account, persist: true);
    if (profile.isBanned) {
      await _writeError(request.response, 'Профиль заблокирован.', 403);
      return;
    }

    final body = await _readJsonBody(request);
    final messages = _parseMessages(body['messages']);
    if (messages.isEmpty) {
      await _writeError(
        request.response,
        'messages не может быть пустым.',
        400,
      );
      return;
    }

    final model = (body['model'] as String?)?.trim();
    final temperature = _parseTemperature(body['temperature']);
    final filteredMessages = _trimContext(
      messages,
      maxContextMessages: profile.limits.maxContextMessages,
    );

    final completer = Completer<String>();
    _queue.add(
      _QueueJob(
        profile: profile,
        messages: filteredMessages,
        model: model?.isEmpty == true ? null : model,
        temperature: temperature,
        completer: completer,
        enqueuedAt: DateTime.now(),
      ),
    );
    _sortQueue();
    _emitUpdate();
    unawaited(_processQueue());

    final reply = await completer.future;
    profile = _profiles[account.id] ?? profile;
    await _writeJson(request.response, <String, dynamic>{
      'reply': reply,
      'profile': profile.toJson(),
      'account': account.toPublicJson(),
    });
  }

  Future<UserProfile> _ensureProfileForAccount(
    AuthAccount account, {
    required bool persist,
  }) async {
    final existing = _profiles[account.id];
    final now = DateTime.now();
    final profile = existing == null
        ? UserProfile.initial(id: account.id, name: account.displayName)
        : existing.copyWith(displayName: account.displayName, updatedAt: now);
    _profiles[account.id] = profile;
    if (persist) {
      await _persistProfiles();
    }
    return profile;
  }

  AuthAccount? _currentAccountForIp(String ip) {
    final accountId = _ipBindings[ip];
    if (accountId == null) {
      return null;
    }
    final account = _accounts[accountId];
    if (account == null) {
      _ipBindings.remove(ip);
      unawaited(_persistAuth());
      return null;
    }
    return account;
  }

  Future<void> _processQueue() async {
    if (_isProcessing) {
      return;
    }
    _isProcessing = true;
    _emitUpdate();

    while (_queue.isNotEmpty) {
      _sortQueue();
      final job = _queue.removeAt(0);
      _activeProfileId = job.profile.id;
      _emitUpdate();
      try {
        final settings = ChatSettings.defaults().copyWith(
          baseUrl: _lmStudioBaseUrl,
          model: job.model ?? _defaultModel,
          temperature: job.temperature,
          profileId: job.profile.id,
          profileName: job.profile.displayName,
        );
        final reply = await _lmStudioApiClient.createChatCompletion(
          settings: settings,
          messages: job.messages,
        );
        if (job.profile.limits.responseDelaySeconds > 0) {
          await Future<void>.delayed(
            Duration(seconds: job.profile.limits.responseDelaySeconds),
          );
        }
        if (!job.completer.isCompleted) {
          job.completer.complete(reply);
        }
      } on ChatApiException catch (error) {
        if (!job.completer.isCompleted) {
          job.completer.completeError(error);
        }
      } catch (_) {
        if (!job.completer.isCompleted) {
          job.completer.completeError(
            const ChatApiException('Ошибка запроса к LM Studio.'),
          );
        }
      } finally {
        _activeProfileId = null;
        _emitUpdate();
      }
    }

    _isProcessing = false;
    _emitUpdate();
  }

  void _sortQueue() {
    _queue.sort((a, b) {
      final byPriority = b.profile.limits.queuePriority.compareTo(
        a.profile.limits.queuePriority,
      );
      if (byPriority != 0) {
        return byPriority;
      }
      return a.enqueuedAt.compareTo(b.enqueuedAt);
    });
  }

  List<ChatMessage> _trimContext(
    List<ChatMessage> messages, {
    required int maxContextMessages,
  }) {
    final system = <ChatMessage>[];
    final nonSystem = <ChatMessage>[];
    for (final message in messages) {
      if (message.role == ChatRole.system) {
        system.add(message);
      } else {
        nonSystem.add(message);
      }
    }

    if (nonSystem.length <= maxContextMessages) {
      return <ChatMessage>[...system, ...nonSystem];
    }
    final tail = nonSystem.sublist(
      nonSystem.length - maxContextMessages,
      nonSystem.length,
    );
    return <ChatMessage>[...system, ...tail];
  }

  List<ChatMessage> _parseMessages(Object? rawMessages) {
    if (rawMessages is! List) {
      return const <ChatMessage>[];
    }
    final parsed = <ChatMessage>[];
    for (final item in rawMessages.whereType<Map>()) {
      final messageMap = item.cast<String, dynamic>();
      final roleRaw = (messageMap['role'] as String? ?? '').trim();
      final content = (messageMap['content'] as String? ?? '').trim();
      if (content.isEmpty) {
        continue;
      }
      switch (roleRaw) {
        case 'assistant':
          parsed.add(ChatMessage.assistant(content));
        case 'system':
          parsed.add(ChatMessage.system(content));
        case 'user':
        default:
          parsed.add(ChatMessage.user(content));
      }
    }
    return parsed;
  }

  double _parseTemperature(Object? value) {
    if (value is num) {
      return value.toDouble().clamp(0.0, 2.0);
    }
    return ChatSettings.defaultTemperature;
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    if (raw.trim().isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    throw const FormatException('Body is not a JSON object');
  }

  Future<void> _writeJson(
    HttpResponse response,
    Map<String, dynamic> body, {
    int statusCode = 200,
  }) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }

  Future<void> _writeError(
    HttpResponse response,
    String message,
    int statusCode,
  ) async {
    await _writeJson(response, <String, dynamic>{
      'error': message,
    }, statusCode: statusCode);
  }

  Future<void> _persistProfiles() {
    return _profileStore.saveProfiles(_profiles.values);
  }

  Future<void> _persistAuth() {
    return _authStore.saveSnapshot(
      AuthSnapshot(accounts: _accounts, ipBindings: _ipBindings),
    );
  }

  void _validateRegistration({
    required String login,
    required String password,
    required String email,
    required String name,
  }) {
    if (login.length < 3 || login.length > 32) {
      throw const GatewayServerException(
        'Логин должен содержать от 3 до 32 символов.',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(login)) {
      throw const GatewayServerException(
        'Логин может содержать только латиницу, цифры и ._-',
      );
    }
    if (password.length < 6) {
      throw const GatewayServerException(
        'Пароль должен быть не короче 6 символов.',
      );
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw const GatewayServerException('Введите корректный email.');
    }
    if (name.length < 2 || name.length > 64) {
      throw const GatewayServerException(
        'Имя должно содержать от 2 до 64 символов.',
      );
    }
  }

  String _requestIp(HttpRequest request) {
    final forwarded = request.headers.value('x-forwarded-for');
    if (forwarded != null && forwarded.trim().isNotEmpty) {
      final first = forwarded.split(',').first.trim();
      if (first.isNotEmpty) {
        return first;
      }
    }
    return request.connectionInfo?.remoteAddress.address ?? 'unknown';
  }

  String _generateAccountId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final suffix = _random.nextInt(9000) + 1000;
    return 'acc_$ts$suffix';
  }

  String _generateSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPassword(String password, String salt) {
    return sha256.convert(utf8.encode('$salt::$password')).toString();
  }

  String _normalizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  void _emitUpdate() {
    if (!_updates.isClosed) {
      _updates.add(null);
    }
  }
}

class GatewayServerException implements Exception {
  const GatewayServerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _QueueJob {
  const _QueueJob({
    required this.profile,
    required this.messages,
    required this.model,
    required this.temperature,
    required this.completer,
    required this.enqueuedAt,
  });

  final UserProfile profile;
  final List<ChatMessage> messages;
  final String? model;
  final double temperature;
  final Completer<String> completer;
  final DateTime enqueuedAt;
}
