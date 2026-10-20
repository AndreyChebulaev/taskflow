import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/repositories.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'services/notification_service.dart';
import 'state/offline_mode.dart';
import 'state/settings_store.dart';
import 'state/task_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'ru';
  await initializeDateFormatting('ru');
  await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseKey);

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsStore(prefs);
  final offline = OfflineMode(prefs);
  final notifications = NotificationService();
  await notifications.init();

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => AuthRepository()),
        Provider(create: (_) => ProfileRepository()),
        Provider.value(value: notifications),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: offline),
        ChangeNotifierProvider(create: (_) => TaskStore(notifications: notifications, settings: settings)),
      ],
      child: const TaskFlowApp(),
    ),
  );
}

class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsStore, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode, // ФТ-16: системная / светлая / тёмная
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}

/// Показывает экран входа или главный экран в зависимости от сессии (ФТ-2:
/// сессия сохраняется между запусками — это делает supabase_flutter).
/// В офлайн-режиме вход не нужен: данные берутся с устройства.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final offline = context.watch<OfflineMode>();
    final store = context.read<TaskStore>();
    if (offline.active) {
      store.useSource(local: offline.data);
      return const HomeShell(key: ValueKey('offline'));
    }
    final auth = context.read<AuthRepository>();
    return StreamBuilder<AuthState>(
      stream: auth.changes,
      builder: (context, _) {
        final user = auth.currentUser;
        if (user == null) return const AuthScreen();
        store.useSource();
        // key по id пользователя: при смене аккаунта главный экран создаётся заново
        return HomeShell(key: ValueKey(user.id));
      },
    );
  }
}
