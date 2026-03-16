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

  late double _temperature;
  late bool _webSearchEnabled;
  late double _webSearchMaxResults;
  late String _languageCode;
  late AppThemeMode _themeMode;
  late AppColorPalette _palette;

  bool _isSaving = false;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSettings;
    _baseUrlController = TextEditingController(text: initial.baseUrl);
    _modelController = TextEditingController(text: initial.model);
    _systemPromptController = TextEditingController(text: initial.systemPrompt);
    _temperature = initial.temperature;
    _webSearchEnabled = initial.webSearchEnabled;
    _webSearchMaxResults = initial.webSearchMaxResults.toDouble();
    _languageCode = initial.languageCode;
    _themeMode = initial.themeMode;
    _palette = initial.palette;
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelController.dispose();
    _systemPromptController.dispose();
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
                      children: [
                        TextFormField(
                          controller: _baseUrlController,
                          decoration: InputDecoration(
                            labelText: i18n.t('baseUrlLabel'),
                            hintText: 'http://172.19.0.1:1234',
                          ),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSection(
                    order: 2,
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
