import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/app_language.dart';
import '../../models/chat_settings.dart';
import '../localization/app_i18n.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.initialSettings,
    required this.onSave,
    required this.onClearHistory,
  });

  final ChatSettings initialSettings;
  final Future<void> Function(ChatSettings settings) onSave;
  final Future<void> Function() onClearHistory;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelController;
  late final TextEditingController _systemPromptController;
  late final TextEditingController _profileNameController;
  late final TextEditingController _profileIdController;
  late final TextEditingController _lanGatewayUrlController;

  late double _temperature;
  late bool _webSearchEnabled;
  late double _webSearchMaxResults;
  late String _languageCode;
  late AppThemeMode _themeMode;
  late AppColorPalette _palette;
  late bool _lanGatewayEnabled;

  bool _isSaving = false;
  bool _isClearing = false;
  bool _isCheckingLmStudio = false;
  bool _isCheckingLanGateway = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSettings;
    _baseUrlController = TextEditingController(text: initial.baseUrl);
    _modelController = TextEditingController(text: initial.model);
    _systemPromptController = TextEditingController(text: initial.systemPrompt);
    _profileNameController = TextEditingController(text: initial.profileName);
    _profileIdController = TextEditingController(text: initial.profileId);
    _lanGatewayUrlController = TextEditingController(
      text: initial.lanGatewayUrl,
    );
    _temperature = initial.temperature;
    _webSearchEnabled = initial.webSearchEnabled;
    _webSearchMaxResults = initial.webSearchMaxResults.toDouble();
    _languageCode = initial.languageCode;
    _themeMode = initial.themeMode;
    _palette = initial.palette;
    _lanGatewayEnabled = initial.lanGatewayEnabled;
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelController.dispose();
    _systemPromptController.dispose();
    _profileNameController.dispose();
    _profileIdController.dispose();
    _lanGatewayUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final settings = ChatSettings(
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
      systemPrompt: _systemPromptController.text.trim(),
      temperature: _temperature,
      webSearchEnabled: _webSearchEnabled,
      webSearchMaxResults: _webSearchMaxResults.round(),
      languageCode: _languageCode,
      themeMode: _themeMode,
      palette: _palette,
      profileId: _profileIdController.text.trim(),
      profileName: _profileNameController.text.trim(),
      lanGatewayEnabled: _lanGatewayEnabled,
      lanGatewayUrl: _lanGatewayUrlController.text.trim(),
    );

    try {
      await widget.onSave(settings);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_i18n.t('saveError'))));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _clearHistory() async {
    if (_isClearing) {
      return;
    }

    final approved =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(_i18n.t('clearHistoryTitle')),
              content: Text(_i18n.t('clearHistoryBody')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(_i18n.t('cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(_i18n.t('clear')),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!approved) {
      return;
    }

    setState(() {
      _isClearing = true;
    });

    try {
      await widget.onClearHistory();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_i18n.t('historyCleared'))));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_i18n.t('historyClearError'))));
    } finally {
      if (mounted) {
        setState(() {
          _isClearing = false;
        });
      }
    }
  }

  String? _validateBaseUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _i18n.t('baseUrlRequired');
    }
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return _i18n.t('baseUrlInvalid');
    }
    return null;
  }

  String? _validateModel(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return _i18n.t('modelRequired');
    }
    return null;
  }

  String? _validateLanGatewayUrl(String? value) {
    if (!_lanGatewayEnabled) {
      return null;
    }
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _i18n.t('lanGatewayRequired');
    }
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return _i18n.t('lanGatewayInvalid');
    }
    return null;
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const Set<String> _loopbackHosts = <String>{
    'localhost',
    '127.0.0.1',
    '0.0.0.0',
    '::1',
  };

  static const Set<String> _bridgeHosts = <String>{
    '172.17.0.1',
    '172.18.0.1',
    '172.19.0.1',
    '172.20.0.1',
    '172.21.0.1',
  };

  String _pickText({required String ru, required String en}) {
    return _languageCode == 'en' ? en : ru;
  }

  String? _androidNetworkWarningForUrl(String rawUrl) {
    if (!_isAndroid) {
      return null;
    }

    final normalized = _normalizeBaseUrl(rawUrl);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasAuthority) {
      return null;
    }
    final host = uri.host.toLowerCase();

    if (_loopbackHosts.contains(host)) {
      return _pickText(
        ru: 'Р”Р»СЏ С‚РµР»РµС„РѕРЅР° localhost/127.0.0.1 СѓРєР°Р·С‹РІР°РµС‚ РЅР° СЃР°Рј С‚РµР»РµС„РѕРЅ. РЈРєР°Р¶РёС‚Рµ LAN IP РІР°С€РµРіРѕ РџРљ (РѕР±С‹С‡РЅРѕ 192.168.x.x).',
        en: 'On a real phone localhost/127.0.0.1 points to the phone itself. Use your PC LAN IP (usually 192.168.x.x).',
      );
    }

    if (host == '10.0.2.2') {
      return _pickText(
        ru: '10.0.2.2 СЂР°Р±РѕС‚Р°РµС‚ С‚РѕР»СЊРєРѕ РІ Android-СЌРјСѓР»СЏС‚РѕСЂРµ. Р”Р»СЏ СЂРµР°Р»СЊРЅРѕРіРѕ С‚РµР»РµС„РѕРЅР° РЅСѓР¶РµРЅ LAN IP РІР°С€РµРіРѕ РџРљ.',
        en: '10.0.2.2 works only in the Android emulator. A real phone needs your PC LAN IP.',
      );
    }

    if (_bridgeHosts.contains(host)) {
      return _pickText(
        ru: 'РђРґСЂРµСЃ $host С‡Р°СЃС‚Рѕ СЏРІР»СЏРµС‚СЃСЏ РІРЅСѓС‚СЂРµРЅРЅРёРј Docker/WSL-Р°РґР°РїС‚РµСЂРѕРј Рё РЅРµРґРѕСЃС‚СѓРїРµРЅ РёР· Wi-Fi. РСЃРїРѕР»СЊР·СѓР№С‚Рµ IP РџРљ РёР· ipconfig.',
        en: 'Address $host is often a Docker/WSL bridge and may be unreachable from Wi-Fi. Use your PC LAN IP from ipconfig.',
      );
    }

    return null;
  }

  String _normalizeBaseUrl(String rawUrl) {
    final text = rawUrl.trim();
    if (text.endsWith('/')) {
      return text.substring(0, text.length - 1);
    }
    return text;
  }

  void _applyBaseUrlPreset(String value) {
    _baseUrlController.text = value;
  }

  void _applyGatewayUrlPreset(String value) {
    _lanGatewayUrlController.text = value;
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _checkLmStudioConnection() async {
    if (_isCheckingLmStudio) {
      return;
    }
    setState(() {
      _isCheckingLmStudio = true;
    });
    try {
      final baseUrl = _normalizeBaseUrl(_baseUrlController.text);
      final uri = Uri.tryParse('$baseUrl/v1/models');
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        _showSnack(_i18n.t('baseUrlInvalid'));
        return;
      }

      final statusCode = await _probeStatusCode(uri);
      if (statusCode >= 200 && statusCode < 400) {
        _showSnack(_i18n.t('connectionOk', {'target': 'LM Studio'}));
      } else {
        _showSnack(
          _i18n.t('connectionFailedStatus', {
            'target': 'LM Studio',
            'status': statusCode.toString(),
          }),
        );
      }
    } on TimeoutException {
      _showSnack(_i18n.t('connectionTimeout', {'target': 'LM Studio'}));
    } on SocketException {
      final hint = _androidNetworkWarningForUrl(_baseUrlController.text);
      if (hint == null) {
        _showSnack(_i18n.t('connectionNoNetwork', {'target': 'LM Studio'}));
      } else {
        _showSnack(
          '${_i18n.t('connectionNoNetwork', {'target': 'LM Studio'})} $hint',
        );
      }
    } catch (_) {
      _showSnack(_i18n.t('connectionFailed', {'target': 'LM Studio'}));
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingLmStudio = false;
        });
      }
    }
  }

  Future<void> _checkLanGatewayConnection() async {
    if (_isCheckingLanGateway) {
      return;
    }
    setState(() {
      _isCheckingLanGateway = true;
    });
    try {
      final baseUrl = _normalizeBaseUrl(_lanGatewayUrlController.text);
      final uri = Uri.tryParse('$baseUrl/api/health');
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        _showSnack(_i18n.t('lanGatewayInvalid'));
        return;
      }

      final statusCode = await _probeStatusCode(uri);
      if (statusCode >= 200 && statusCode < 400) {
        _showSnack(_i18n.t('connectionOk', {'target': 'LAN gateway'}));
      } else {
        _showSnack(
          _i18n.t('connectionFailedStatus', {
            'target': 'LAN gateway',
            'status': statusCode.toString(),
          }),
        );
      }
    } on TimeoutException {
      _showSnack(_i18n.t('connectionTimeout', {'target': 'LAN gateway'}));
    } on SocketException {
      final hint = _androidNetworkWarningForUrl(_lanGatewayUrlController.text);
      if (hint == null) {
        _showSnack(_i18n.t('connectionNoNetwork', {'target': 'LAN gateway'}));
      } else {
        _showSnack(
          '${_i18n.t('connectionNoNetwork', {'target': 'LAN gateway'})} $hint',
        );
      }
    } catch (_) {
      _showSnack(_i18n.t('connectionFailed', {'target': 'LAN gateway'}));
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingLanGateway = false;
        });
      }
    }
  }

  Future<int> _probeStatusCode(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 6));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 6),
      );
      await response.drain();
      return response.statusCode;
    } finally {
      client.close(force: true);
    }
  }

  Widget _buildAndroidNetworkHints(AppI18n i18n) {
    final colors = Theme.of(context).colorScheme;
    final warning = _androidNetworkWarningForUrl(_baseUrlController.text);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.secondary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wifi_find_rounded, color: colors.onSecondaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  i18n.t('androidNetworkTitle'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            i18n.t('androidNetworkSubtitle'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSecondaryContainer),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: Text(i18n.t('presetEmulator')),
                onPressed: () => _applyBaseUrlPreset('http://10.0.2.2:1234'),
              ),
              ActionChip(
                label: Text(i18n.t('presetLanExample')),
                onPressed: () =>
                    _applyBaseUrlPreset('http://192.168.1.10:1234'),
              ),
              ActionChip(
                label: Text(i18n.t('presetGatewayLan')),
                onPressed: () =>
                    _applyGatewayUrlPreset('http://192.168.1.10:8088'),
              ),
            ],
          ),
          if (warning != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.errorContainer.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: colors.onErrorContainer,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  AppI18n get _i18n => AppI18n(_languageCode);

  Widget _buildSection({
    required int order,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + order * 80),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  child,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeModeSelector(AppI18n i18n) {
    return SegmentedButton<AppThemeMode>(
      segments: AppThemeMode.values
          .map(
            (mode) => ButtonSegment<AppThemeMode>(
              value: mode,
              label: Text(i18n.modeLabel(mode)),
              icon: Icon(_modeIcon(mode)),
            ),
          )
          .toList(growable: false),
      selected: <AppThemeMode>{_themeMode},
      onSelectionChanged: (selection) {
        setState(() {
          _themeMode = selection.first;
        });
      },
      showSelectedIcon: false,
    );
  }

  Widget _buildPaletteSelector(AppI18n i18n) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AppColorPalette.values
          .map((palette) {
            final selected = _palette == palette;
            return ChoiceChip(
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _palette = palette;
                });
              },
              avatar: CircleAvatar(
                radius: 8,
                backgroundColor: _paletteColor(palette),
              ),
              label: Text(i18n.paletteLabel(palette)),
              selectedColor: colors.primary.withValues(alpha: 0.22),
              side: BorderSide(
                color: selected
                    ? colors.primary.withValues(alpha: 0.45)
                    : colors.outlineVariant.withValues(alpha: 0.4),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildLanguageSelector(AppI18n i18n) {
    return DropdownButtonFormField<String>(
      initialValue: _languageCode,
      decoration: InputDecoration(labelText: i18n.t('language')),
      items: AppLanguage.supported
          .map(
            (language) => DropdownMenuItem<String>(
              value: language.code,
              child: Text(i18n.languageItemLabel(language)),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        if (value == null) {
          return;
        }
        setState(() {
          _languageCode = value;
        });
      },
    );
  }

  IconData _modeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return Icons.settings_suggest_rounded;
      case AppThemeMode.light:
        return Icons.light_mode_rounded;
      case AppThemeMode.dark:
        return Icons.dark_mode_rounded;
    }
  }

  Color _paletteColor(AppColorPalette palette) {
    switch (palette) {
      case AppColorPalette.ocean:
        return const Color(0xFF1E6DF8);
      case AppColorPalette.sunset:
        return const Color(0xFFE56B5B);
      case AppColorPalette.forest:
        return const Color(0xFF2B9F78);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = _i18n;
    final colors = Theme.of(context).colorScheme;
    final paletteName = i18n.paletteLabel(_palette);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        title: Text(i18n.t('settings')),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _save,
            icon: const Icon(Icons.check_rounded),
            tooltip: i18n.t('save'),
          ),
        ],
      ),
      body: ColoredBox(
        color: colors.surface,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    order: 0,
                    title: i18n.t('appearance'),
                    subtitle: i18n.t('appearanceSubtitle', {
                      'palette': paletteName,
                    }),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildThemeModeSelector(i18n),
                        const SizedBox(height: 14),
                        _buildPaletteSelector(i18n),
                        const SizedBox(height: 14),
                        _buildLanguageSelector(i18n),
                        const SizedBox(height: 8),
                        Text(
                          i18n.t('languageSubtitle'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    order: 1,
                    title: i18n.t('connection'),
                    subtitle: i18n.t('connectionSubtitle'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _baseUrlController,
                          decoration: InputDecoration(
                            labelText: i18n.t('baseUrlLabel'),
                            hintText: 'http://172.19.0.1:1234',
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: _validateBaseUrl,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _modelController,
                          decoration: InputDecoration(
                            labelText: i18n.t('modelLabel'),
                          ),
                          validator: _validateModel,
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isCheckingLmStudio
                                ? null
                                : _checkLmStudioConnection,
                            icon: _isCheckingLmStudio
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.wifi_tethering_rounded),
                            label: Text(
                              _isCheckingLmStudio
                                  ? i18n.t('checking')
                                  : i18n.t('checkLmStudio'),
                            ),
                          ),
                        ),
                        if (_isAndroid) _buildAndroidNetworkHints(i18n),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    order: 2,
                    title: 'РџСЂРѕС„РёР»СЊ Рё РґРѕСЃС‚СѓРї',
                    subtitle:
                        'РџСЂРѕС„РёР»СЊ РёСЃРїРѕР»СЊР·СѓРµС‚СЃСЏ РґР»СЏ РїСЂР°РІ (Free/Plus/Max), Р±Р°РЅР° Рё РѕС‡РµСЂРµРґРё Р·Р°РїСЂРѕСЃРѕРІ РїРѕ Р»РѕРєР°Р»СЊРЅРѕР№ СЃРµС‚Рё.',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _profileNameController,
                          decoration: const InputDecoration(
                            labelText: 'РРјСЏ РїСЂРѕС„РёР»СЏ',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _profileIdController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'ID РїСЂРѕС„РёР»СЏ',
                            helperText:
                                'Р“РµРЅРµСЂРёСЂСѓРµС‚СЃСЏ Р°РІС‚РѕРјР°С‚РёС‡РµСЃРєРё. РџРѕ РЅРµРјСѓ Р°РґРјРёРЅ РјРµРЅСЏРµС‚ РїСЂР°РІР°.',
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'LAN-С€Р»СЋР· (РѕС‡РµСЂРµРґСЊ + РїСЂР°РІР°)',
                          ),
                          subtitle: const Text(
                            'Р’РєР»СЋС‡РёС‚Рµ, С‡С‚РѕР±С‹ Р·Р°РїСЂРѕСЃС‹ С€Р»Рё С‡РµСЂРµР· Р»РѕРєР°Р»СЊРЅС‹Р№ СЃРµСЂРІРµСЂ-РѕС‡РµСЂРµРґСЊ СЃ РїСЂРёРѕСЂРёС‚РµС‚Р°РјРё.',
                          ),
                          value: _lanGatewayEnabled,
                          onChanged: (value) {
                            setState(() {
                              _lanGatewayEnabled = value;
                            });
                          },
                        ),
                        if (_lanGatewayEnabled) ...[
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _lanGatewayUrlController,
                            decoration: const InputDecoration(
                              labelText: 'URL LAN-С€Р»СЋР·Р°',
                              hintText: 'http://192.168.1.10:8088',
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: _validateLanGatewayUrl,
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isCheckingLanGateway
                                  ? null
                                  : _checkLanGatewayConnection,
                              icon: _isCheckingLanGateway
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.route_rounded),
                              label: Text(
                                _isCheckingLanGateway
                                    ? i18n.t('checking')
                                    : i18n.t('checkLanGateway'),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    order: 3,
                    title: i18n.t('generation'),
                    subtitle: i18n.t('generationSubtitle'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _systemPromptController,
                          minLines: 3,
                          maxLines: 6,
                          decoration: InputDecoration(
                            labelText: i18n.t('systemPromptLabel'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          i18n.t('systemPromptHelp'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          i18n.t('temperature', {
                            'value': _temperature.toStringAsFixed(2),
                          }),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Slider(
                          value: _temperature,
                          min: 0,
                          max: 2,
                          divisions: 20,
                          label: _temperature.toStringAsFixed(2),
                          onChanged: (value) {
                            setState(() {
                              _temperature = value;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(i18n.t('webSearchTitle')),
                          subtitle: Text(i18n.t('webSearchSubtitle')),
                          value: _webSearchEnabled,
                          onChanged: (value) {
                            setState(() {
                              _webSearchEnabled = value;
                            });
                          },
                        ),
                        if (_webSearchEnabled) ...[
                          const SizedBox(height: 8),
                          Text(
                            i18n.t('sourcesCount', {
                              'count': _webSearchMaxResults.round().toString(),
                            }),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Slider(
                            value: _webSearchMaxResults,
                            min: 1,
                            max: 8,
                            divisions: 7,
                            label: _webSearchMaxResults.round().toString(),
                            onChanged: (value) {
                              setState(() {
                                _webSearchMaxResults = value;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(
                        _isSaving ? i18n.t('saving') : i18n.t('saveSettings'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isClearing ? null : _clearHistory,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(
                        _isClearing
                            ? i18n.t('clearing')
                            : i18n.t('clearHistory'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
