import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import '../state/task_store.dart';
import 'calendar_screen.dart';
import 'categories_screen.dart';
import 'profile_screen.dart';
import 'task_sheet.dart';
import 'tasks_screen.dart';

/// Главный экран с нижним меню (компонент «Bottom navigation»).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Переключить вкладку из дочернего экрана (например, «Категории» → «Задачи»).
  static void selectTab(BuildContext context, int index) =>
      context.findAncestorStateOfType<_HomeShellState>()?.select(index);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final NotificationService _notifications;
  late final TaskStore _store;

  void select(int i) => setState(() => _index = i);

  @override
  void initState() {
    super.initState();
    _notifications = context.read<NotificationService>();
    _store = context.read<TaskStore>();
    _notifications.openTaskRequest.addListener(_openFromNotification);
    _store.addListener(_openFromNotification); // задача могла ещё не загрузиться
    // Загружаем данные пользователя после первого кадра
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _store.load();
      _openFromNotification();
    });
  }

  @override
  void dispose() {
    _notifications.openTaskRequest.removeListener(_openFromNotification);
    _store.removeListener(_openFromNotification);
    super.dispose();
  }

  /// ФТ-14: нажатие на уведомление открывает задачу.
  void _openFromNotification() {
    final id = _notifications.openTaskRequest.value;
    if (id == null || !mounted) return;
    final matches = _store.allTasks.where((t) => t.id == id);
    if (matches.isEmpty) {
      if (!_store.loading && _store.allTasks.isNotEmpty) _notifications.openTaskRequest.value = null; // задачу удалили
      return;
    }
    _notifications.openTaskRequest.value = null;
    select(0);
    showTaskSheet(context, task: matches.first);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [TasksScreen(), CategoriesScreen(), CalendarScreen(), ProfileScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: select,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.check_box_outlined), selectedIcon: Icon(Icons.check_box), label: 'Задачи'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'Категории'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Календарь'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Профиль'),
        ],
      ),
    );
  }
}
