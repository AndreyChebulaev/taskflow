import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories.dart';
import '../state/offline_mode.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Экран 01: вход, регистрация, восстановление пароля (ФТ-1 – ФТ-3).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isRegister = false;
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthRepository>();
    try {
      if (_isRegister) {
        final loggedIn = await auth.signUp(_name.text, _email.text, _password.text);
        if (!loggedIn && mounted) {
          showInfo(context, 'Мы отправили письмо на ${_email.text.trim()}. Подтвердите email и войдите.');
          setState(() => _isRegister = false);
        }
      } else {
        await auth.signIn(_email.text, _password.text);
      }
      // При успешном входе AuthGate сам переключит экран
    } catch (e) {
      if (mounted) setState(() => _error = humanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!_isValidEmail(email)) {
      setState(() => _error = 'Введите email, на который отправить ссылку');
      return;
    }
    try {
      await context.read<AuthRepository>().resetPassword(email);
      if (mounted) showInfo(context, 'Ссылка для восстановления пароля отправлена на $email');
    } catch (e) {
      if (mounted) setState(() => _error = humanError(e));
    }
  }

  static bool _isValidEmail(String s) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  const _Logo(),
                  const SizedBox(height: 20),
                  const Text('TaskFlow', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Задачи под контролем', style: TextStyle(color: Color(0xFFA9C9C6), fontSize: 14)),
                  const SizedBox(height: 36),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(minHeight: (constraints.maxHeight - 220).clamp(0.0, double.infinity)),
                    decoration: BoxDecoration(
                      color: context.pal.card,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedSwitch(
                            labels: const ['Вход', 'Регистрация'],
                            selected: _isRegister ? 1 : 0,
                            onChanged: (i) => setState(() {
                              _isRegister = i == 1;
                              _error = null;
                            }),
                          ),
                          const SizedBox(height: 24),
                          if (_isRegister) ...[
                            const FieldLabel('Имя'),
                            TextFormField(
                              controller: _name,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(hintText: 'Как к вам обращаться'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите имя' : null,
                            ),
                            const SizedBox(height: 16),
                          ],
                          const FieldLabel('Email'),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(hintText: 'student@mail.ru'),
                            validator: (v) => _isValidEmail((v ?? '').trim()) ? null : 'Некорректный email',
                          ),
                          const SizedBox(height: 16),
                          const FieldLabel('Пароль'),
                          TextFormField(
                            controller: _password,
                            obscureText: _hidePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              hintText: 'Не короче 6 символов',
                              suffixIcon: IconButton(
                                tooltip: _hidePassword ? 'Показать пароль' : 'Скрыть пароль',
                                icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: context.pal.muted),
                                onPressed: () => setState(() => _hidePassword = !_hidePassword),
                              ),
                            ),
                            validator: (v) => (v ?? '').length < 6 ? 'Минимум 6 символов' : null,
                          ),
                          if (!_isRegister)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _busy ? null : _forgotPassword,
                                child: const Text('Забыли пароль?', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600)),
                              ),
                            )
                          else
                            const SizedBox(height: 16),
                          if (_error != null) ...[
                            Text(_error!, style: const TextStyle(color: Color(0xFFD64545), fontWeight: FontWeight.w500)),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                : Text(_isRegister ? 'Зарегистрироваться' : 'Войти'),
                          ),
                          const SizedBox(height: 12),
                          // Офлайн-режим: приложение работает без сети, данные — на устройстве
                          OutlinedButton.icon(
                            onPressed: _busy ? null : () => context.read<OfflineMode>().start(),
                            icon: const Icon(Icons.cloud_off_rounded, size: 20),
                            label: const Text('Работать без интернета'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.teal,
                              side: const BorderSide(color: AppColors.teal, width: 1.5),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Без входа в аккаунт: задачи хранятся только на этом телефоне',
                              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: context.pal.muted)),
                        ],
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

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 46),
    );
  }
}
