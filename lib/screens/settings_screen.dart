import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/repositories.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../state/settings_store.dart';
import '../state/task_store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Экран 06: настройки (ФТ-16) — тема, уведомления, пароль, выход.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _themes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];

  Future<void> _toggleNotifications(BuildContext context, bool value) async {
    final settings = context.read<SettingsStore>();
    final store = context.read<TaskStore>();
    if (value) await context.read<NotificationService>().ensurePermission();
    await settings.setNotificationsEnabled(value);
    await store.resyncReminders();
  }

  Future<void> _pickDefaultReminder(BuildContext context) async {
    final settings = context.read<SettingsStore>();
    final picked = await showModalBottomSheet<_Choice>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Напоминать по умолчанию', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
            for (final e in Reminder.options.entries)
              ListTile(
                title: Text(e.value),
                trailing: settings.defaultReminder == e.key ? const Icon(Icons.check_rounded, color: AppColors.teal) : null,
                onTap: () => Navigator.pop(ctx, _Choice(e.key)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) await settings.setDefaultReminder(picked.value);
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await confirmDialog(context, title: 'Выйти из аккаунта?', message: 'Задачи сохранятся и будут доступны после входа.', action: 'Выйти');
    if (!ok || !context.mounted) return;
    final store = context.read<TaskStore>();
    final auth = context.read<AuthRepository>();
    final navigator = Navigator.of(context);
    try {
      await auth.signOut();
      store.clear();
      navigator.popUntil((r) => r.isFirst);
    } catch (e) {
      if (context.mounted) showError(context, humanError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final email = context.read<AuthRepository>().currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _SectionTitle('ТЕМА ОФОРМЛЕНИЯ'),
          SegmentedSwitch(
            labels: const ['Системная', 'Светлая', 'Тёмная'],
            selected: _themes.indexOf(settings.themeMode),
            background: context.pal.card,
            onChanged: (i) => settings.setThemeMode(_themes[i]),
          ),
          const _SectionTitle('УВЕДОМЛЕНИЯ'),
          _Group(children: [
            SwitchListTile(
              title: const Text('Напоминания о задачах', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text('Push-уведомление перед дедлайном', style: TextStyle(color: context.pal.muted, fontSize: 12)),
              value: settings.notificationsEnabled,
              onChanged: (v) => _toggleNotifications(context, v),
            ),
            Divider(height: 1, indent: 16, endIndent: 16, color: context.pal.line),
            ListTile(
              enabled: settings.notificationsEnabled,
              title: const Text('Напоминать по умолчанию', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(Reminder.label(settings.defaultReminder), style: TextStyle(color: context.pal.muted, fontSize: 12)),
              trailing: Icon(Icons.chevron_right_rounded, color: context.pal.muted),
              onTap: () => _pickDefaultReminder(context),
            ),
          ]),
          const _SectionTitle('ПРОВЕРКА УВЕДОМЛЕНИЙ'),
          const _NotificationCheck(),
          const _SectionTitle('АККАУНТ'),
          _Group(children: [
            ListTile(
              title: const Text('Email', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(email, style: TextStyle(color: context.pal.muted, fontSize: 12)),
            ),
            Divider(height: 1, indent: 16, endIndent: 16, color: context.pal.line),
            ListTile(
              title: const Text('Изменить пароль', style: TextStyle(fontWeight: FontWeight.w500)),
              trailing: Icon(Icons.chevron_right_rounded, color: context.pal.muted),
              onTap: () => showDialog(context: context, builder: (_) => const _ChangePasswordDialog()),
            ),
          ]),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () => _signOut(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.coral,
              side: const BorderSide(color: AppColors.coral, width: 1.5),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            child: const Text('Выйти из аккаунта'),
          ),
          const SizedBox(height: 16),
          Text('TaskFlow · версия 1.0', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: context.pal.muted)),
        ],
      ),
    );
  }
}

/// Обёртка, чтобы отличать «Без напоминания» (null) от закрытия списка.
class _Choice {
  const _Choice(this.value);
  final int? value;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: context.pal.muted)),
      );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
        color: context.pal.card,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
}

/// Смена пароля: новый пароль и подтверждение.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_password.text.length < 6) {
      setState(() => _error = 'Минимум 6 символов');
      return;
    }
    if (_password.text != _repeat.text) {
      setState(() => _error = 'Пароли не совпадают');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      await context.read<AuthRepository>().updatePassword(_password.text);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Пароль изменён')));
    } catch (e) {
      if (mounted) setState(() => _error = humanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Изменить пароль'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _password, obscureText: true, autofocus: true, decoration: const InputDecoration(hintText: 'Новый пароль')),
          const SizedBox(height: 12),
          TextField(
            controller: _repeat,
            obscureText: true,
            decoration: InputDecoration(hintText: 'Повторите пароль', errorText: _error),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        TextButton(onPressed: _busy ? null : _save, child: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.w700))),
      ],
    );
  }
}

/// Диагностика: разрешение, время устройства, число запланированных
/// напоминаний и тестовое уведомление. Пригодится и на защите проекта.
class _NotificationCheck extends StatefulWidget {
  const _NotificationCheck();

  @override
  State<_NotificationCheck> createState() => _NotificationCheckState();
}

class _NotificationCheckState extends State<_NotificationCheck> {
  bool? _allowed;
  int? _pending;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final n = context.read<NotificationService>();
    try {
      final allowed = await n.areEnabled();
      final pending = await n.pendingCount();
      if (mounted) setState(() {
        _allowed = allowed;
        _pending = pending;
      });
    } catch (_) {}
  }

  Future<void> _test() async {
    final n = context.read<NotificationService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await n.showTest();
      messenger.showSnackBar(const SnackBar(content: Text('Тестовое уведомление отправлено — проверьте шторку')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Ошибка уведомления: $e'), backgroundColor: const Color(0xFFB83A3A)));
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateFormat('d MMMM y, HH:mm', 'ru').format(DateTime.now());
    final allowedText = switch (_allowed) {
      true => 'разрешены',
      false => 'ЗАПРЕЩЕНЫ — включите в настройках Android',
      null => 'проверяется…',
    };
    final info = 'Уведомления: $allowedText\n'
        'Запланировано напоминаний: ${_pending ?? '…'}\n'
        'Время на устройстве: $now';
    return _Group(children: [
      ListTile(
        title: const Text('Состояние', style: TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(info, style: TextStyle(color: _allowed == false ? AppColors.coral : context.pal.muted, fontSize: 12, height: 1.5)),
        trailing: IconButton(tooltip: 'Обновить', icon: Icon(Icons.refresh_rounded, color: context.pal.muted), onPressed: _refresh),
      ),
      Divider(height: 1, indent: 16, endIndent: 16, color: context.pal.line),
      ListTile(
        leading: const Icon(Icons.notifications_active_outlined, color: AppColors.teal),
        title: const Text('Отправить тестовое уведомление', style: TextStyle(fontWeight: FontWeight.w500)),
        onTap: _test,
      ),
    ]);
  }
}
