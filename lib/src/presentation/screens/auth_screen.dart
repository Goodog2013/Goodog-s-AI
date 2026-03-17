import 'package:flutter/material.dart';

import '../controllers/chat_controller.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.controller});

  final ChatController controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  late final TextEditingController _loginController;
  late final TextEditingController _passwordController;

  late final TextEditingController _registerLoginController;
  late final TextEditingController _registerPasswordController;
  late final TextEditingController _registerEmailController;
  late final TextEditingController _registerNameController;

  bool _isSubmitting = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _loginController = TextEditingController();
    _passwordController = TextEditingController();
    _registerLoginController = TextEditingController();
    _registerPasswordController = TextEditingController();
    _registerEmailController = TextEditingController();
    _registerNameController = TextEditingController();
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _registerLoginController.dispose();
    _registerPasswordController.dispose();
    _registerEmailController.dispose();
    _registerNameController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (_isSubmitting) {
      return;
    }
    if (!(_loginFormKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });
    final error = await widget.controller.login(
      login: _loginController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isSubmitting = false;
      _inlineError = error ?? widget.controller.authError;
    });
  }

  Future<void> _submitRegister() async {
    if (_isSubmitting) {
      return;
    }
    if (!(_registerFormKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });
    final error = await widget.controller.register(
      login: _registerLoginController.text.trim(),
      password: _registerPasswordController.text,
      email: _registerEmailController.text.trim(),
      name: _registerNameController.text.trim(),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isSubmitting = false;
      _inlineError = error ?? widget.controller.authError;
    });
  }

  String? _requiredValidator(String? value, {String? label}) {
    if ((value ?? '').trim().isEmpty) {
      return label == null
          ? 'Обязательное поле.'
          : '$label: обязательное поле.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Goodog's AI",
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Вход обязателен (привязка сессии к вашему IP).',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const TabBar(
                          tabs: [
                            Tab(text: 'Вход'),
                            Tab(text: 'Регистрация'),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if ((_inlineError ?? widget.controller.authError) !=
                            null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _inlineError ?? widget.controller.authError ?? '',
                              style: TextStyle(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        SizedBox(
                          height: 320,
                          child: TabBarView(
                            children: [
                              Form(
                                key: _loginFormKey,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _loginController,
                                      decoration: const InputDecoration(
                                        labelText: 'Логин или email',
                                      ),
                                      validator: (v) =>
                                          _requiredValidator(v, label: 'Логин'),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Пароль',
                                      ),
                                      validator: (v) => _requiredValidator(
                                        v,
                                        label: 'Пароль',
                                      ),
                                    ),
                                    const Spacer(),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: _isSubmitting
                                            ? null
                                            : _submitLogin,
                                        icon: const Icon(Icons.login_rounded),
                                        label: Text(
                                          _isSubmitting ? 'Входим...' : 'Войти',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Form(
                                key: _registerFormKey,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _registerNameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Имя',
                                      ),
                                      validator: (v) =>
                                          _requiredValidator(v, label: 'Имя'),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _registerLoginController,
                                      decoration: const InputDecoration(
                                        labelText: 'Логин',
                                      ),
                                      validator: (v) =>
                                          _requiredValidator(v, label: 'Логин'),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _registerEmailController,
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                      ),
                                      validator: (v) =>
                                          _requiredValidator(v, label: 'Email'),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _registerPasswordController,
                                      obscureText: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Пароль',
                                      ),
                                      validator: (v) => _requiredValidator(
                                        v,
                                        label: 'Пароль',
                                      ),
                                    ),
                                    const Spacer(),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: _isSubmitting
                                            ? null
                                            : _submitRegister,
                                        icon: const Icon(
                                          Icons.person_add_rounded,
                                        ),
                                        label: Text(
                                          _isSubmitting
                                              ? 'Регистрируем...'
                                              : 'Зарегистрироваться',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
