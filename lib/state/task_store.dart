import 'package:flutter/foundation.dart';

import '../data/local_repositories.dart';
import '../data/repositories.dart';
import '../models/category.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import 'productivity.dart';
import 'settings_store.dart';

enum TaskSort { byDue, byPriority }

/// Состояние задач и категорий (слой «Состояние» из ТЗ).
/// Экраны читают данные отсюда и вызывают методы, а сам store
/// обращается к Supabase через репозитории.
class TaskStore extends ChangeNotifier {
  TaskStore({TaskRepository? tasks, CategoryRepository? categories, this.notifications, this.settings})
      : _taskRepo = tasks ?? TaskRepository(),
        _catRepo = categories ?? CategoryRepository();

  TaskRepository _taskRepo;
  CategoryRepository _catRepo;
  bool _offline = false;

  bool get isOffline => _offline;

  /// Источник данных: Supabase или устройство (офлайн-режим).
  /// Вызывается при смене режима до загрузки; списки сбрасываются без перерисовки.
  void useSource({LocalData? local}) {
    final offline = local != null;
    if (offline == _offline) return;
    _offline = offline;
    _taskRepo = local != null ? LocalTaskRepository(local) : TaskRepository();
    _catRepo = local != null ? LocalCategoryRepository(local) : CategoryRepository();
    notifications?.cancelAll();
    _tasks = [];
    _categories = [];
    error = null;
    categoryFilter = null;
    showDone = false;
  }
  final NotificationService? notifications;
  final SettingsStore? settings;

  bool get _remindersOn => settings?.notificationsEnabled ?? false;

  /// Запланировать или снять напоминание по задаче (ФТ-14).
  /// При [report] ошибка пробрасывается как [ReminderException], чтобы показать её пользователю.
  Future<void> _syncReminder(Task t, {bool report = false}) async {
    final n = notifications;
    if (n == null) return;
    try {
      if (_remindersOn) {
        await n.schedule(t);
      } else {
        await n.cancel(t);
      }
    } catch (e) {
      debugPrint('Не удалось запланировать напоминание: $e');
      if (report) throw ReminderException('Задача сохранена, но напоминание не запланировано: $e');
    }
  }

  /// Пересоздать все напоминания (после загрузки и при смене настроек).
  Future<void> resyncReminders() async {
    try {
      await notifications?.resync(_tasks, enabled: _remindersOn);
    } catch (e) {
      debugPrint('Не удалось обновить напоминания: $e');
    }
  }

  List<Task> _tasks = [];
  List<TaskCategory> _categories = [];
  bool loading = false;
  String? error;

  // Фильтры и сортировка экрана «Задачи» (ФТ-8, ФТ-11)
  bool showDone = false;
  String? categoryFilter; // null — все категории
  TaskSort sort = TaskSort.byDue;

  List<Task> get allTasks => List.unmodifiable(_tasks);
  List<TaskCategory> get categories => List.unmodifiable(_categories);

  TaskCategory? categoryById(String? id) {
    if (id == null) return null;
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  int countInCategory(String? categoryId) => _tasks.where((t) => t.categoryId == categoryId).length;

  int get activeCount => _tasks.where((t) => !t.isDone).length;
  int get doneCount => _tasks.where((t) => t.isDone).length;

  List<Task> get visibleTasks {
    final list = _tasks.where((t) {
      if (t.isDone != showDone) return false;
      if (categoryFilter != null && t.categoryId != categoryFilter) return false;
      return true;
    }).toList();
    list.sort(_compare);
    return list;
  }

  int _compare(Task a, Task b) {
    if (sort == TaskSort.byPriority && a.priority != b.priority) {
      return a.priority.value.compareTo(b.priority.value);
    }
    // Задачи без срока — в конце
    if (a.dueAt == null && b.dueAt == null) return a.createdAt.compareTo(b.createdAt);
    if (a.dueAt == null) return 1;
    if (b.dueAt == null) return -1;
    final byDate = a.dueAt!.compareTo(b.dueAt!);
    if (byDate != 0) return byDate;
    return a.priority.value.compareTo(b.priority.value);
  }

  /// Задачи на конкретный день (для календаря, ФТ-12).
  List<Task> tasksOn(DateTime day) {
    final list = _tasks.where((t) => t.dueAt != null && _sameDay(t.dueAt!, day)).toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    return list;
  }

  /// Самый важный незавершённый приоритет на день — для цветной точки в календаре.
  TaskPriority? topPriorityOn(DateTime day) {
    TaskPriority? best;
    for (final t in _tasks) {
      if (t.isDone || t.dueAt == null || !_sameDay(t.dueAt!, day)) continue;
      if (best == null || t.priority.value < best.value) best = t.priority;
    }
    return best;
  }

  /// Статистика за текущую неделю (пн–вс) по задачам со сроком.
  ({int done, int total}) get weekStats {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 7));
    final week = _tasks.where((t) => t.dueAt != null && !t.dueAt!.isBefore(start) && t.dueAt!.isBefore(end));
    return (done: week.where((t) => t.isDone).length, total: week.length);
  }

  /// Серии, тепловая карта и достижения (ФТ-18).
  Productivity get productivity => Productivity(_tasks.map((t) => t.doneAt).whereType<DateTime>());

  /// Создать категорию, если её ещё нет (для умного ввода #новая), и вернуть её id.
  Future<String> ensureCategory(String name, String colorHex) async {
    final lower = name.trim().toLowerCase();
    for (final c in _categories) {
      if (c.name.toLowerCase() == lower) return c.id;
    }
    await addCategory(name, colorHex);
    return _categories.last.id;
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  // ---------- загрузка ----------

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([_taskRepo.fetchAll(), _catRepo.fetchAll()]);
      _tasks = results[0] as List<Task>;
      _categories = results[1] as List<TaskCategory>;
      if (categoryFilter != null && categoryById(categoryFilter) == null) categoryFilter = null;
      resyncReminders();
    } catch (e) {
      error = humanError(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void clear() {
    notifications?.cancelAll();
    _tasks = [];
    _categories = [];
    error = null;
    categoryFilter = null;
    showDone = false;
    notifyListeners();
  }

  // ---------- фильтры ----------

  void setShowDone(bool v) {
    showDone = v;
    notifyListeners();
  }

  void setCategoryFilter(String? id) {
    categoryFilter = id;
    notifyListeners();
  }

  void setSort(TaskSort s) {
    sort = s;
    notifyListeners();
  }

  // ---------- задачи ----------

  Future<void> addTask(TaskDraft d) async {
    final t = await _taskRepo.create(d);
    _tasks = [..._tasks, t];
    notifyListeners();
    await _syncReminder(t, report: true);
  }

  Future<void> updateTask(String id, TaskDraft d) async {
    final t = await _taskRepo.update(id, d);
    _tasks = [for (final x in _tasks) x.id == id ? t : x];
    notifyListeners();
    await _syncReminder(t, report: true);
  }

  /// Отметка выполнения (ФТ-6). Для повторяющейся задачи после выполнения
  /// создаётся следующая с новым дедлайном (ФТ-9).
  /// Возвращает следующую задачу, если она была создана.
  Future<Task?> toggleDone(Task task) async {
    final newValue = !task.isDone;
    // Оптимистичное обновление: интерфейс реагирует сразу
    _replace(task.id, (t) => t.copyWith(isDone: newValue));
    notifyListeners();
    try {
      await _taskRepo.setDone(task.id, newValue);
    } catch (e) {
      _replace(task.id, (t) => t.copyWith(isDone: task.isDone));
      notifyListeners();
      rethrow;
    }
    // Выполненная задача — напоминание снимается; снова активная — ставится
    await _syncReminder(task.copyWith(isDone: newValue));
    if (newValue && task.repeat != Repeat.none && task.dueAt != null) {
      final nextDue = task.repeat.next(task.dueAt!);
      // Не создаём дубль, если отметку сняли и поставили снова
      final exists = _tasks.any((t) => t.id != task.id && t.title == task.title && t.repeat == task.repeat && t.dueAt == nextDue);
      if (exists) return null;
      final draft = TaskDraft.fromTask(task)..dueAt = nextDue;
      final next = await _taskRepo.create(draft);
      _tasks = [..._tasks, next];
      notifyListeners();
      await _syncReminder(next);
      return next;
    }
    return null;
  }

  /// Удаление (ФТ-5). Сначала убираем из списка (нужно для анимации свайпа),
  /// при ошибке сети возвращаем задачу обратно.
  Future<void> deleteTask(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index < 0) return;
    final removed = _tasks[index];
    _tasks = [..._tasks]..removeAt(index);
    notifyListeners();
    try {
      await _taskRepo.delete(id);
      await notifications?.cancel(removed);
    } catch (e) {
      _tasks = [..._tasks]..insert(index.clamp(0, _tasks.length), removed);
      notifyListeners();
      rethrow;
    }
  }

  void _replace(String id, Task Function(Task) f) {
    _tasks = [for (final x in _tasks) x.id == id ? f(x) : x];
  }


  // ---------- категории ----------

  Future<void> addCategory(String name, String colorHex) async {
    final c = await _catRepo.create(name, colorHex);
    _categories = [..._categories, c];
    notifyListeners();
  }

  Future<void> updateCategory(String id, String name, String colorHex) async {
    final c = await _catRepo.update(id, name, colorHex);
    _categories = [for (final x in _categories) x.id == id ? c : x];
    notifyListeners();
  }

  /// ФТ-11: задачи удалённой категории остаются «без категории».
  Future<void> deleteCategory(String id) async {
    await _catRepo.delete(id);
    _categories = _categories.where((c) => c.id != id).toList();
    if (categoryFilter == id) categoryFilter = null;
    // Повторяем в памяти то, что база сделала через on delete set null
    _tasks = [for (final t in _tasks) t.categoryId == id ? t.copyWith(clearCategory: true) : t];
    notifyListeners();
  }
}

/// Задача сохранена, но системное напоминание поставить не удалось.
class ReminderException implements Exception {
  ReminderException(this.message);
  final String message;
  @override
  String toString() => message;
}
