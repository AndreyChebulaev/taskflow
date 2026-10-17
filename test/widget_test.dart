import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/models/task.dart';
import 'package:todo_app/state/settings_store.dart';

/// Модульные тесты логики задач (запуск: flutter test).
void main() {
  group('Повторяющиеся задачи (ФТ-9)', () {
    final base = DateTime(2026, 10, 14, 18, 0);

    test('ежедневно — следующий день', () {
      expect(Repeat.daily.next(base), DateTime(2026, 10, 15, 18, 0));
    });

    test('еженедельно — через 7 дней', () {
      expect(Repeat.weekly.next(base), DateTime(2026, 10, 21, 18, 0));
    });

    test('ежемесячно — то же число следующего месяца', () {
      expect(Repeat.monthly.next(base), DateTime(2026, 11, 14, 18, 0));
    });

    test('ежемесячно с 31-го — последний день короткого месяца', () {
      expect(Repeat.monthly.next(DateTime(2026, 10, 31, 9)), DateTime(2026, 11, 30, 9));
      expect(Repeat.monthly.next(DateTime(2027, 1, 31, 9)), DateTime(2027, 2, 28, 9));
    });

    test('декабрь → январь следующего года', () {
      expect(Repeat.monthly.next(DateTime(2026, 12, 5, 10)), DateTime(2027, 1, 5, 10));
    });
  });

  group('Приоритеты (ФТ-7)', () {
    test('значения из базы', () {
      expect(TaskPriority.fromValue(1), TaskPriority.high);
      expect(TaskPriority.fromValue(2), TaskPriority.medium);
      expect(TaskPriority.fromValue(3), TaskPriority.low);
    });

    test('неизвестное значение — средний', () {
      expect(TaskPriority.fromValue(9), TaskPriority.medium);
    });
  });

  group('Модель задачи', () {
    test('разбор строки из Supabase', () {
      final t = Task.fromMap({
        'id': 'a1',
        'title': 'Сдать лабораторную',
        'description': null,
        'category_id': null,
        'due_at': '2026-10-14T13:00:00+00:00',
        'priority': 1,
        'repeat': 'weekly',
        'is_done': false,
        'created_at': '2026-10-14T10:00:00+00:00',
      });
      expect(t.priority, TaskPriority.high);
      expect(t.repeat, Repeat.weekly);
      expect(t.dueAt!.isUtc, isFalse);
      expect(t.dueAt!.toUtc(), DateTime.utc(2026, 10, 14, 13));
    });

    test('черновик без описания отправляет null', () {
      final m = TaskDraft(title: '  Купить продукты  ', description: '   ').toMap();
      expect(m['title'], 'Купить продукты');
      expect(m['description'], isNull);
      expect(m['repeat'], 'none');
    });
  });

  group('Напоминания (ФТ-13)', () {
    Task make({int? offset, bool done = false, DateTime? due}) => Task(
          id: '3f2a9c10-0000-4000-8000-000000000001',
          title: 'Сдать лабораторную',
          dueAt: due ?? DateTime(2026, 10, 20, 18, 0),
          reminderOffset: offset,
          isDone: done,
          createdAt: DateTime(2026, 10, 16),
        );

    test('время напоминания = дедлайн минус смещение', () {
      expect(make(offset: 60).remindAt, DateTime(2026, 10, 20, 17, 0));
      expect(make(offset: 1440).remindAt, DateTime(2026, 10, 19, 18, 0));
      expect(make(offset: 0).remindAt, DateTime(2026, 10, 20, 18, 0));
      expect(make().remindAt, isNull);
    });

    test('напоминание читается из вложенного списка Supabase', () {
      final t = Task.fromMap({
        'id': 'b2',
        'title': 'x',
        'due_at': '2026-10-20T13:00:00+00:00',
        'priority': 2,
        'repeat': 'none',
        'is_done': false,
        'created_at': '2026-10-16T10:00:00+00:00',
        'reminders': [
          {'offset_minutes': 15}
        ],
      });
      expect(t.reminderOffset, 15);
    });

    test('без дедлайна напоминание не сохраняется', () {
      final d = TaskDraft(title: 'x', reminderOffset: 60);
      expect(d.effectiveReminder, isNull);
      d.dueAt = DateTime(2026, 10, 20);
      expect(d.effectiveReminder, 60);
    });

    test('id уведомления стабилен и помещается в int32', () {
      final a = make(offset: 15).notificationId;
      expect(a, make(offset: 60).notificationId);
      expect(a, lessThan(1 << 31));
    });

    test('copyWith сохраняет напоминание и меняет статус', () {
      final t = make(offset: 15).copyWith(isDone: true);
      expect(t.isDone, isTrue);
      expect(t.reminderOffset, 15);
      expect(t.copyWith(clearReminder: true).reminderOffset, isNull);
    });
  });

  group('Настройки (ФТ-16)', () {
    test('значения по умолчанию и сохранение', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final s = SettingsStore(prefs);
      expect(s.themeMode, ThemeMode.system);
      expect(s.notificationsEnabled, isTrue);
      expect(s.defaultReminder, 15);

      await s.setThemeMode(ThemeMode.dark);
      await s.setDefaultReminder(null);
      final again = SettingsStore(prefs);
      expect(again.themeMode, ThemeMode.dark);
      expect(again.defaultReminder, isNull);
    });
  });
}
