import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user_plan.dart';
import '../models/user_profile.dart';
import 'lan_gateway_server.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.server});

  final LanGatewayServer server;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _lmStudioUrlController;
  late final TextEditingController _modelController;

  StreamSubscription<void>? _serverUpdatesSubscription;
  bool _isSwitchingServer = false;
  List<UserProfile> _profiles = const <UserProfile>[];

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.server.bindHost);
    _portController = TextEditingController(
      text: widget.server.bindPort.toString(),
    );
    _lmStudioUrlController = TextEditingController(
      text: widget.server.lmStudioBaseUrl,
    );
    _modelController = TextEditingController(text: widget.server.defaultModel);
    _profiles = widget.server.profiles;
    _serverUpdatesSubscription = widget.server.updates.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profiles = widget.server.profiles;
      });
    });
  }

  @override
  void dispose() {
    _serverUpdatesSubscription?.cancel();
    _hostController.dispose();
    _portController.dispose();
    _lmStudioUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _toggleServer() async {
    if (_isSwitchingServer) {
      return;
    }
    setState(() {
      _isSwitchingServer = true;
    });
    try {
      if (widget.server.isRunning) {
        await widget.server.stop();
      } else {
        final port = int.tryParse(_portController.text.trim());
        if (port == null || port <= 0 || port > 65535) {
          _showSnack('Порт должен быть числом от 1 до 65535.');
          return;
        }
        await widget.server.start(
          host: _hostController.text.trim().isEmpty
              ? '0.0.0.0'
              : _hostController.text.trim(),
          port: port,
          lmStudioBaseUrl: _lmStudioUrlController.text.trim(),
          defaultModel: _modelController.text.trim(),
        );
      }
      _profiles = widget.server.profiles;
    } on Object catch (error) {
      _showSnack('Ошибка запуска LAN-шлюза: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingServer = false;
        });
      }
    }
  }

  Future<void> _setPlan(UserProfile profile, UserPlan plan) async {
    await widget.server.setProfilePlan(profile.id, plan);
    setState(() {
      _profiles = widget.server.profiles;
    });
  }

  Future<void> _setBan(UserProfile profile, bool banned) async {
    await widget.server.setProfileBan(profile.id, banned);
    setState(() {
      _profiles = widget.server.profiles;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusText = widget.server.isRunning
        ? 'Шлюз работает: ${widget.server.bindHost}:${widget.server.bindPort}'
        : 'Шлюз остановлен';
    final queueText = widget.server.isRunning
        ? 'Очередь: ${widget.server.queueLength} | В работе: ${widget.server.activeProfileId ?? '-'}'
        : 'Очередь недоступна';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Goodog's AI Admin"),
        actions: [
          FilledButton.icon(
            onPressed: _isSwitchingServer ? null : _toggleServer,
            icon: Icon(
              widget.server.isRunning ? Icons.stop_rounded : Icons.play_arrow,
            ),
            label: Text(widget.server.isRunning ? 'Остановить' : 'Запустить'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LAN-шлюз и очередь',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(statusText),
                  const SizedBox(height: 4),
                  Text(queueText),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _hostController,
                          decoration: const InputDecoration(
                            labelText: 'Host',
                            hintText: '0.0.0.0',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            hintText: '8088',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 320,
                        child: TextField(
                          controller: _lmStudioUrlController,
                          decoration: const InputDecoration(
                            labelText: 'LM Studio URL',
                            hintText: 'http://172.19.0.1:1234',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 320,
                        child: TextField(
                          controller: _modelController,
                          decoration: const InputDecoration(
                            labelText: 'Модель',
                            hintText: 'qwen2.5-7b-instruct-uncensored',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Профили пользователей',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_profiles.isEmpty)
                    const Text(
                      'Пока нет профилей. Они появятся после подключения клиентов.',
                    ),
                  ..._profiles.map((profile) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.displayName,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ID: ${profile.id}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 130,
                              child: DropdownButtonFormField<UserPlan>(
                                initialValue: profile.plan,
                                decoration: const InputDecoration(
                                  labelText: 'Тариф',
                                  isDense: true,
                                ),
                                items: UserPlan.values
                                    .map(
                                      (plan) => DropdownMenuItem<UserPlan>(
                                        value: plan,
                                        child: Text(plan.title),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  unawaited(_setPlan(profile, value));
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 160,
                              child: SwitchListTile.adaptive(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Бан'),
                                value: profile.isBanned,
                                onChanged: (value) {
                                  unawaited(_setBan(profile, value));
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
