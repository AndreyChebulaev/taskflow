import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';

/// Локальные push-уведомления о задачах (ФТ-13, ФТ-14).
///
/// Уведомления планирует сама система Android, поэтому они приходят,
/// даже если приложение закрыто. Нажатие на уведомление открывает задачу.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// id задачи, которую нужно открыть после нажатия на уведомление.
  final ValueNotifier<String?> openTaskRequest = ValueNotifier(null);

  bool _ready = false;
  bool _permissionAsked = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'task_reminders',
      'Напоминания о задачах',
      channelDescription: 'Уведомления о приближающихся дедлайнах',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> init() async {
    // База часовых поясов нужна для TZDateTime. Время уведомления передаём
    // как точный момент (TZDateTime.from), поэтому оно верно в любом поясе.
    tzdata.initializeTimeZones();

    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (response) {
        final id = response.payload;
        if (id != null && id.isNotEmpty) openTaskRequest.value = id;
      },
    );

    // Приложение было закрыто и запущено нажатием на уведомление
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if ((launch?.didNotificationLaunchApp ?? false) && payload != null) openTaskRequest.value = payload;
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Запрос разрешения на уведомления (Android 13+). Спрашиваем один раз за запуск.
  Future<void> ensurePermission({bool force = false}) async {
    if (_permissionAsked && !force) return;
    _permissionAsked = true;
    await _android?.requestNotificationsPermission();
  }

  /// Запланировать напоминание по задаче (старое с тем же id заменяется).
  Future<void> schedule(Task task) async {
    if (!_ready) return;
    await cancel(task);
    final at = task.remindAt;
    if (task.isDone || at == null || !at.isAfter(DateTime.now())) return;

    await ensurePermission();
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    await _plugin.zonedSchedule(
      id: task.notificationId,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _details,
      androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      title: task.title,
      body: _body(task),
      payload: task.id,
    );
  }

  /// Мгновенное тестовое уведомление (проверка разрешений и канала).
  Future<void> showTest() async {
    await ensurePermission(force: true);
    await _plugin.show(
      id: 999999,
      title: 'TaskFlow',
      body: 'Уведомления работают ✅',
      notificationDetails: _details,
    );
  }

  /// Разрешены ли уведомления приложению (null — не удалось определить).
  Future<bool?> areEnabled() async => _android?.areNotificationsEnabled();

  /// Сколько напоминаний сейчас запланировано в системе.
  Future<int> pendingCount() async => (await _plugin.pendingNotificationRequests()).length;

  Future<void> cancel(Task task) async {
    if (!_ready) return;
    await _plugin.cancel(id: task.notificationId);
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  /// Пересоздать все напоминания (после входа, загрузки или смены настроек).
  Future<void> resync(Iterable<Task> tasks, {required bool enabled}) async {
    await cancelAll();
    if (!enabled) return;
    for (final t in tasks) {
      if (t.remindAt != null) await schedule(t);
    }
  }

  static String _body(Task t) {
    final time = DateFormat.Hm('ru').format(t.dueAt!);
    switch (t.reminderOffset) {
      case 0:
        return 'Дедлайн сейчас — $time';
      case 15:
        return 'Дедлайн через 15 минут — $time';
      case 60:
        return 'Дедлайн через 1 час — $time';
      case 1440:
        return 'Дедлайн завтра в $time';
      default:
        return 'Дедлайн в $time';
    }
  }
}
