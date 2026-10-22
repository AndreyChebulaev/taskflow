import 'package:flutter/material.dart';

import '../theme.dart';

/// Приоритет задачи (в базе: 1 — высокий, 2 — средний, 3 — низкий).
enum TaskPriority {
  high(1, 'Высокий', AppColors.coral),
  medium(2, 'Средний', AppColors.yellow),
  low(3, 'Низкий', AppColors.teal);

  const TaskPriority(this.value, this.label, this.color);
  final int value;
  final String label;
  final Color color;

  static TaskPriority fromValue(int v) => TaskPriority.values.firstWhere((p) => p.value == v, orElse: () => TaskPriority.medium);
}

/// Повтор задачи (ФТ-9).
enum Repeat {
  none('none', 'Нет'),
  daily('daily', 'День'),
  weekly('weekly', 'Неделя'),
  monthly('monthly', 'Месяц');

  const Repeat(this.value, this.label);
  final String value;
  final String label;

  static Repeat fromValue(String? v) => Repeat.values.firstWhere((r) => r.value == v, orElse: () => Repeat.none);

  /// Следующая дата для повторяющейся задачи.
  DateTime next(DateTime d) {
    switch (this) {
      case Repeat.daily:
        return d.add(const Duration(days: 1));
      case Repeat.weekly:
        return d.add(const Duration(days: 7));
      case Repeat.monthly:
        // Если в следующем месяце нет такого числа (31 → 30), берём последний день месяца.
        final lastDay = DateTime(d.year, d.month + 2, 0).day;
        return DateTime(d.year, d.month + 1, d.day > lastDay ? lastDay : d.day, d.hour, d.minute);
      case Repeat.none:
        return d;
    }
  }
}

/// Варианты напоминания (ФТ-13): минут до дедлайна.
class Reminder {
  static const options = <int?, String>{
    null: 'Без напоминания',
    0: 'В момент дедлайна',
    15: 'За 15 минут',
    60: 'За 1 час',
    1440: 'За 1 день',
  };

  static String label(int? offset) => options[offset] ?? 'За $offset мин';
}

class Task {
  final String id;
  final String title;
  final String? description;
  final String? categoryId;
  final DateTime? dueAt;
  final TaskPriority priority;
  final Repeat repeat;
  final bool isDone;
  final DateTime createdAt;
  final int? reminderOffset; // минут до дедлайна; null — без напоминания
  final DateTime? completedAt; // когда отмечена выполненной (ФТ-18)

  const Task({
    required this.id,
    required this.title,
    this.description,
    this.categoryId,
    this.dueAt,
    this.priority = TaskPriority.medium,
    this.repeat = Repeat.none,
    this.isDone = false,
    required this.createdAt,
    this.reminderOffset,
    this.completedAt,
  });

  factory Task.fromMap(Map<String, dynamic> m) => Task(
        id: m['id'] as String,
        title: m['title'] as String,
        description: m['description'] as String?,
        categoryId: m['category_id'] as String?,
        dueAt: m['due_at'] == null ? null : DateTime.parse(m['due_at'] as String).toLocal(),
        priority: TaskPriority.fromValue((m['priority'] as num?)?.toInt() ?? 2),
        repeat: Repeat.fromValue(m['repeat'] as String?),
        isDone: m['is_done'] as bool? ?? false,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        reminderOffset: _reminderFrom(m['reminders']),
        completedAt: m['completed_at'] == null ? null : DateTime.parse(m['completed_at'] as String).toLocal(),
      );

  /// Напоминание приходит вложенным списком: select('*, reminders(offset_minutes)').
  static int? _reminderFrom(Object? raw) {
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map) return (first['offset_minutes'] as num?)?.toInt();
    }
    return null;
  }

  /// При смене isDone время выполнения ставится или сбрасывается автоматически.
  Task copyWith({bool? isDone, bool clearCategory = false, int? reminderOffset, bool clearReminder = false, DateTime? completedAt}) => Task(
        id: id,
        title: title,
        description: description,
        categoryId: clearCategory ? null : categoryId,
        dueAt: dueAt,
        priority: priority,
        repeat: repeat,
        isDone: isDone ?? this.isDone,
        createdAt: createdAt,
        reminderOffset: clearReminder ? null : (reminderOffset ?? this.reminderOffset),
        completedAt: isDone == null
            ? (completedAt ?? this.completedAt)
            : (isDone ? (completedAt ?? this.completedAt ?? DateTime.now()) : null),
      );

  /// Дата выполнения для статистики. У задач, выполненных до появления
  /// поля completed_at, берём срок или дату создания.
  DateTime? get doneAt => isDone ? (completedAt ?? dueAt ?? createdAt) : null;

  /// Момент напоминания или null, если его нет.
  DateTime? get remindAt =>
      (dueAt == null || reminderOffset == null) ? null : dueAt!.subtract(Duration(minutes: reminderOffset!));

  /// Стабильный числовой id уведомления из uuid задачи (Android требует int).
  int get notificationId => int.parse(id.replaceAll('-', '').padRight(7, '0').substring(0, 7), radix: 16);

  bool get isOverdue => !isDone && dueAt != null && dueAt!.isBefore(DateTime.now());
}

/// Данные формы задачи (для создания и редактирования).
class TaskDraft {
  String title;
  String? description;
  String? categoryId;
  DateTime? dueAt;
  TaskPriority priority;
  Repeat repeat;
  int? reminderOffset;

  TaskDraft({
    this.title = '',
    this.description,
    this.categoryId,
    this.dueAt,
    this.priority = TaskPriority.medium,
    this.repeat = Repeat.none,
    this.reminderOffset,
  });

  factory TaskDraft.fromTask(Task t) => TaskDraft(
        title: t.title,
        description: t.description,
        categoryId: t.categoryId,
        dueAt: t.dueAt,
        priority: t.priority,
        repeat: t.repeat,
        reminderOffset: t.reminderOffset,
      );

  /// Напоминание без дедлайна не имеет смысла.
  int? get effectiveReminder => dueAt == null ? null : reminderOffset;

  /// Поля таблицы tasks (напоминание хранится отдельно, в таблице reminders).
  Map<String, dynamic> toMap() => {
        'title': title.trim(),
        'description': (description == null || description!.trim().isEmpty) ? null : description!.trim(),
        'category_id': categoryId,
        'due_at': dueAt?.toUtc().toIso8601String(),
        'priority': priority.value,
        'repeat': repeat.value,
      };
}
