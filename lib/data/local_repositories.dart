import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';
import '../models/task.dart';
import 'repositories.dart';

/// Офлайн-режим: задачи и категории хранятся на устройстве (SharedPreferences)
/// в том же формате, что и строки таблиц Supabase, поэтому модели и TaskStore
/// работают с ними без изменений.
class LocalData {
  LocalData(this._prefs);
  final SharedPreferences _prefs;

  static const _tasksKey = 'offline_tasks';
  static const _categoriesKey = 'offline_categories';

  List<Map<String, dynamic>> _read(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _write(String key, List<Map<String, dynamic>> rows) => _prefs.setString(key, jsonEncode(rows));

  List<Map<String, dynamic>> get tasks => _read(_tasksKey);
  List<Map<String, dynamic>> get categories => _read(_categoriesKey);
  Future<void> saveTasks(List<Map<String, dynamic>> rows) => _write(_tasksKey, rows);
  Future<void> saveCategories(List<Map<String, dynamic>> rows) => _write(_categoriesKey, rows);

  bool get isEmpty => !_prefs.containsKey(_categoriesKey);

  /// Случайный id в формате uuid (из него вычисляется id уведомления).
  static String newId() {
    final r = Random.secure();
    String hex(int n) => List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}';
  }

  static String now() => DateTime.now().toUtc().toIso8601String();

  /// Стартовые данные, чтобы сразу было что показать: как у нового аккаунта
  /// три категории, плюс несколько задач со сроками относительно сегодняшнего дня.
  Future<void> seedIfEmpty() async {
    if (!isEmpty) return;
    final study = newId(), work = newId(), home = newId();
    await saveCategories([
      {'id': study, 'name': 'Учёба', 'color': '#2EC4B6', 'created_at': now()},
      {'id': work, 'name': 'Работа', 'color': '#FF7A59', 'created_at': now()},
      {'id': home, 'name': 'Дом', 'color': '#F5B700', 'created_at': now()},
    ]);
    final today = DateTime.now();
    DateTime at(int days, int hour, [int minute = 0]) => DateTime(today.year, today.month, today.day + days, hour, minute);
    Map<String, dynamic> task(String title, String? cat, DateTime? due, int priority,
            {String repeat = 'none', bool done = false, int? reminder, String? description}) =>
        {
          'id': newId(),
          'title': title,
          'description': description,
          'category_id': cat,
          'due_at': due?.toUtc().toIso8601String(),
          'priority': priority,
          'repeat': repeat,
          'is_done': done,
          'completed_at': done ? due?.toUtc().toIso8601String() : null,
          'created_at': now(),
          'reminders': reminder == null ? [] : [{'offset_minutes': reminder}],
        };
    await saveTasks([
      task('Сдать лабораторную работу', study, at(0, 23), 1, reminder: 60, description: 'Лабораторная №4 по мобильной разработке'),
      task('Сделать зарядку', null, at(1, 8), 3, repeat: 'daily'),
      task('Прочитать главу 3', study, at(2, 20), 3),
      task('Оплатить интернет', home, at(3, 12), 2, repeat: 'monthly'),
      task('Подготовить отчёт', work, at(5, 18), 2, repeat: 'weekly'),
      task('Курсовая работа', study, at(12, 18), 1),
      task('Купить продукты', home, at(-1, 19), 2, done: true),
    ]);
    await _prefs.setBool(_historyKey, false);
    await seedHistoryIfNeeded();
  }

  static const _historyKey = 'offline_history_seeded';

  /// История выполненных задач за последние недели — чтобы на тепловой карте,
  /// в серии дней и достижениях (ФТ-18) сразу было что показать.
  Future<void> seedHistoryIfNeeded() async {
    if (_prefs.getBool(_historyKey) ?? false) return;
    final cats = categories;
    String? cat(String name) {
      for (final c in cats) {
        if (c['name'] == name) return c['id'] as String;
      }
      return null;
    }

    const List<(String, String?)> titles = [
      ('Пробежка', null), ('Повторить конспект', 'Учёба'), ('Разобрать почту', 'Работа'),
      ('Лабораторная работа', 'Учёба'), ('Сходить в магазин', 'Дом'), ('Тренировка', null),
      ('Прочитать статью', 'Учёба'), ('Созвон с командой', 'Работа'), ('Уборка', 'Дом'),
    ];
    // [дней назад, час выполнения]; 1–4 дня назад подряд — текущая серия
    const history = [
      [1, 19], [1, 8], [2, 20], [3, 7], [3, 18], [4, 21], [6, 19], [7, 8], [7, 17], [8, 19], [9, 20],
      [10, 18], [12, 19], [13, 8], [14, 20], [14, 21], [15, 19], [17, 18], [20, 19], [21, 20],
      [22, 19], [24, 18], [27, 20], [28, 19], [31, 19], [35, 18], [38, 20], [42, 19],
    ];
    final today = DateTime.now();
    final rows = tasks;
    for (var i = 0; i < history.length; i++) {
      final t = titles[i % titles.length];
      final at = DateTime(today.year, today.month, today.day - history[i][0], history[i][1], 15).toUtc().toIso8601String();
      rows.add({
        'id': newId(),
        'title': t.$1,
        'description': null,
        'category_id': t.$2 == null ? null : cat(t.$2!),
        'due_at': at,
        'priority': 2,
        'repeat': 'none',
        'is_done': true,
        'completed_at': at,
        'created_at': at,
        'reminders': [],
      });
    }
    await saveTasks(rows);
    await _prefs.setBool(_historyKey, true);
  }
}

/// Задачи без сервера (тот же интерфейс, что у TaskRepository).
class LocalTaskRepository implements TaskRepository {
  LocalTaskRepository(this._data);
  final LocalData _data;

  static Map<String, dynamic> _row(String id, TaskDraft d, {required bool isDone, required String createdAt, String? completedAt}) => {
        ...d.toMap(),
        'id': id,
        'is_done': isDone,
        'completed_at': completedAt,
        'created_at': createdAt,
        'reminders': d.effectiveReminder == null ? [] : [{'offset_minutes': d.effectiveReminder}],
      };

  @override
  Future<List<Task>> fetchAll() async => _data.tasks.map(Task.fromMap).toList();

  @override
  Future<Task> create(TaskDraft d) async {
    final row = _row(LocalData.newId(), d, isDone: false, createdAt: LocalData.now());
    await _data.saveTasks([..._data.tasks, row]);
    return Task.fromMap(row);
  }

  @override
  Future<Task> update(String id, TaskDraft d) async {
    final rows = _data.tasks;
    final i = rows.indexWhere((r) => r['id'] == id);
    if (i < 0) throw StateError('Задача не найдена');
    rows[i] = _row(id, d,
        isDone: rows[i]['is_done'] as bool? ?? false,
        createdAt: rows[i]['created_at'] as String,
        completedAt: rows[i]['completed_at'] as String?);
    await _data.saveTasks(rows);
    return Task.fromMap(rows[i]);
  }

  @override
  Future<void> setDone(String id, bool done) async {
    final rows = _data.tasks;
    for (final r in rows) {
      if (r['id'] == id) {
        r['is_done'] = done;
        r['completed_at'] = done ? LocalData.now() : null;
      }
    }
    await _data.saveTasks(rows);
  }

  @override
  Future<void> delete(String id) async {
    await _data.saveTasks(_data.tasks.where((r) => r['id'] != id).toList());
  }
}

/// Категории без сервера (тот же интерфейс, что у CategoryRepository).
class LocalCategoryRepository implements CategoryRepository {
  LocalCategoryRepository(this._data);
  final LocalData _data;

  void _checkUnique(String name, {String? exceptId}) {
    final n = name.trim().toLowerCase();
    if (_data.categories.any((c) => c['id'] != exceptId && (c['name'] as String).toLowerCase() == n)) {
      throw const DuplicateNameException();
    }
  }

  @override
  Future<List<TaskCategory>> fetchAll() async => _data.categories.map(TaskCategory.fromMap).toList();

  @override
  Future<TaskCategory> create(String name, String colorHex) async {
    _checkUnique(name);
    final row = {'id': LocalData.newId(), 'name': name.trim(), 'color': colorHex, 'created_at': LocalData.now()};
    await _data.saveCategories([..._data.categories, row]);
    return TaskCategory.fromMap(row);
  }

  @override
  Future<TaskCategory> update(String id, String name, String colorHex) async {
    _checkUnique(name, exceptId: id);
    final rows = _data.categories;
    final i = rows.indexWhere((r) => r['id'] == id);
    if (i < 0) throw StateError('Категория не найдена');
    rows[i] = {...rows[i], 'name': name.trim(), 'color': colorHex};
    await _data.saveCategories(rows);
    return TaskCategory.fromMap(rows[i]);
  }

  /// Как on delete set null в базе: задачи остаются без категории.
  @override
  Future<void> delete(String id) async {
    await _data.saveCategories(_data.categories.where((r) => r['id'] != id).toList());
    final tasks = _data.tasks;
    for (final t in tasks) {
      if (t['category_id'] == id) t['category_id'] = null;
    }
    await _data.saveTasks(tasks);
  }
}
