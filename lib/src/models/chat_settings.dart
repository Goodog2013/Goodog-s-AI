import 'package:flutter/material.dart';

import 'app_language.dart';

enum AppThemeMode { system, light, dark }

enum AppColorPalette { ocean, sunset, forest }

class ChatSettings {
  const ChatSettings({
    required this.baseUrl,
    required this.model,
    required this.systemPrompt,
    required this.temperature,
    required this.webSearchEnabled,
    required this.webSearchMaxResults,
    required this.languageCode,
    required this.themeMode,
    required this.palette,
  });

  final String baseUrl;
  final String model;
  final String systemPrompt;
  final double temperature;
  final bool webSearchEnabled;
  final int webSearchMaxResults;
  final String languageCode;
  final AppThemeMode themeMode;
  final AppColorPalette palette;

  static const String defaultBaseUrl = 'http://172.19.0.1:1234';
  static const String defaultModel = 'qwen2.5-7b-instruct-uncensored';
  static const String defaultSystemPrompt =
      'Ты полезный и дружелюбный помощник.';
  static const double defaultTemperature = 0.7;
  static const bool defaultWebSearchEnabled = false;
  static const int defaultWebSearchMaxResults = 4;
  static const String defaultLanguageCode = 'ru';
  static const AppThemeMode defaultThemeMode = AppThemeMode.system;
  static const AppColorPalette defaultPalette = AppColorPalette.ocean;

  factory ChatSettings.defaults() {
    return const ChatSettings(
      baseUrl: defaultBaseUrl,
      model: defaultModel,
      systemPrompt: defaultSystemPrompt,
      temperature: defaultTemperature,
      webSearchEnabled: defaultWebSearchEnabled,
      webSearchMaxResults: defaultWebSearchMaxResults,
      languageCode: defaultLanguageCode,
      themeMode: defaultThemeMode,
      palette: defaultPalette,
    );
  }

  factory ChatSettings.fromJson(Map<String, dynamic> json) {
    return ChatSettings(
      baseUrl: json['baseUrl'] as String? ?? defaultBaseUrl,
      model: json['model'] as String? ?? defaultModel,
      systemPrompt: json['systemPrompt'] as String? ?? defaultSystemPrompt,
      temperature: _parseTemperature(json['temperature']),
      webSearchEnabled: _parseWebSearchEnabled(json['webSearchEnabled']),
      webSearchMaxResults: _parseWebSearchMaxResults(
        json['webSearchMaxResults'],
      ),
      languageCode: _parseLanguageCode(json['languageCode']),
      themeMode: _parseThemeMode(json['themeMode'] as String?),
      palette: _parsePalette(json['palette'] as String?),
    );
  }

  ChatSettings copyWith({
    String? baseUrl,
    String? model,
    String? systemPrompt,
    double? temperature,
    bool? webSearchEnabled,
    int? webSearchMaxResults,
    String? languageCode,
    AppThemeMode? themeMode,
    AppColorPalette? palette,
  }) {
    return ChatSettings(
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      webSearchEnabled: webSearchEnabled ?? this.webSearchEnabled,
      webSearchMaxResults: webSearchMaxResults ?? this.webSearchMaxResults,
      languageCode: languageCode ?? this.languageCode,
      themeMode: themeMode ?? this.themeMode,
      palette: palette ?? this.palette,
    );
  }

  String get normalizedBaseUrl {
    final trimmed = baseUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  ThemeMode get flutterThemeMode {
    switch (themeMode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'baseUrl': baseUrl,
      'model': model,
      'systemPrompt': systemPrompt,
      'temperature': temperature,
      'webSearchEnabled': webSearchEnabled,
      'webSearchMaxResults': webSearchMaxResults,
      'languageCode': languageCode,
      'themeMode': _themeModeToJson(themeMode),
      'palette': _paletteToJson(palette),
    };
  }

  static double _parseTemperature(Object? value) {
    if (value is num) {
      final parsed = value.toDouble();
      if (parsed.isFinite) {
        return (parsed.clamp(0.0, 2.0) as num).toDouble();
      }
    }
    return defaultTemperature;
  }

  static bool _parseWebSearchEnabled(Object? value) {
    if (value is bool) {
      return value;
    }
    return defaultWebSearchEnabled;
  }

  static int _parseWebSearchMaxResults(Object? value) {
    if (value is int) {
      return value.clamp(1, 8);
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed.clamp(1, 8);
      }
    }
    return defaultWebSearchMaxResults;
  }

  static String _parseLanguageCode(Object? value) {
    if (value is String) {
      return AppLanguage.normalizeCode(value);
    }
    return defaultLanguageCode;
  }

  static AppThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      case 'system':
      default:
        return AppThemeMode.system;
    }
  }

  static String _themeModeToJson(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'system';
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.dark:
        return 'dark';
    }
  }

  static AppColorPalette _parsePalette(String? value) {
    switch (value) {
      case 'sunset':
        return AppColorPalette.sunset;
      case 'forest':
        return AppColorPalette.forest;
      case 'ocean':
      default:
        return AppColorPalette.ocean;
    }
  }

  static String _paletteToJson(AppColorPalette palette) {
    switch (palette) {
      case AppColorPalette.ocean:
        return 'ocean';
      case AppColorPalette.sunset:
        return 'sunset';
      case AppColorPalette.forest:
        return 'forest';
    }
  }
}
