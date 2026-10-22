import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/data/local_repositories.dart';
import 'package:todo_app/data/repositories.dart';
import 'package:todo_app/models/task.dart';
import 'package:todo_app/services/quick_parser.dart';
import 'package:todo_app/state/productivity.dart';
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

  group('Офлайн-режим', () {
    Future<LocalData> fresh() async {
      SharedPreferences.setMockInitialValues({});
      return LocalData(await SharedPreferences.getInstance());
    }

    test('стартовые данные: 3 категории и задачи', () async {
      final data = await fresh();
      await data.seedIfEmpty();
      expect(data.categories.length, 3);
      final tasks = await LocalTaskRepository(data).fetchAll();
      // 7 стартовых задач + история выполненных для тепловой карты
      expect(tasks.where((t) => !t.isDone).length, 6);
      expect(tasks.where((t) => t.isDone).length, greaterThan(20));
      expect(tasks.where((t) => t.isDone).every((t) => t.completedAt != null), isTrue);
      await data.seedIfEmpty(); // повторно не добавляет
      expect(data.categories.length, 3);
      expect((await LocalTaskRepository(data).fetchAll()).length, tasks.length);
    });

    test('создание, изменение, выполнение и удаление задачи', () async {
      final repo = LocalTaskRepository(await fresh());
      final due = DateTime(2026, 11, 1, 18);
      final t = await repo.create(TaskDraft(title: 'Тест', dueAt: due, priority: TaskPriority.high, reminderOffset: 60));
      expect(t.title, 'Тест');
      expect(t.dueAt, due);
      expect(t.reminderOffset, 60);
      final u = await repo.update(t.id, TaskDraft.fromTask(t)..title = 'Тест 2');
      expect(u.title, 'Тест 2');
      await repo.setDone(t.id, true);
      final done = (await repo.fetchAll()).single;
      expect(done.isDone, isTrue);
      expect(done.completedAt, isNotNull);
      await repo.setDone(t.id, false);
      expect((await repo.fetchAll()).single.completedAt, isNull);
      await repo.delete(t.id);
      expect(await repo.fetchAll(), isEmpty);
    });

    test('удаление категории оставляет задачи без категории', () async {
      final data = await fresh();
      final cats = LocalCategoryRepository(data);
      final c = await cats.create('Спорт', '#2EC4B6');
      await LocalTaskRepository(data).create(TaskDraft(title: 'Бег', categoryId: c.id));
      await cats.delete(c.id);
      expect(await cats.fetchAll(), isEmpty);
      expect((await LocalTaskRepository(data).fetchAll()).single.categoryId, isNull);
    });

    test('повтор названия категории запрещён', () async {
      final cats = LocalCategoryRepository(await fresh());
      await cats.create('Спорт', '#2EC4B6');
      await expectLater(cats.create('спорт', '#FF7A59'), throwsA(isA<DuplicateNameException>()));
      expect(humanError(const DuplicateNameException()), 'Такое название уже есть');
    });
  });

  group('Умный ввод (ФТ-17)', () {
    final now = DateTime(2026, 10, 22, 16, 0); // четверг
    const cats = {'c1': 'Учёба', 'c2': 'Работа', 'c3': 'Дом'};
    QuickParse parse(String s) => QuickParser.parse(s, now: now, categories: cats);

    test('полная строка: дата, время, приоритет, категория, повтор, напоминание', () {
      final r = parse('Сдать лабу завтра в 18:00 !важно #учёба каждую неделю напомни за час');
      expect(r.title, 'Сдать лабу');
      expect(r.dueAt, DateTime(2026, 10, 23, 18, 0));
      expect(r.priority, 1);
      expect(r.categoryId, 'c1');
      expect(r.repeat, 'weekly');
      expect(r.reminderOffset, 60);
      expect(r.tokens.length, 6);
    });

    test('обычный текст остаётся названием', () {
      final r = parse('Купить молоко');
      expect(r.title, 'Купить молоко');
      expect(r.dueAt, isNull);
      expect(r.tokens, isEmpty);
    });

    test('только время: сегодня, а если прошло — завтра', () {
      expect(parse('Позвонить маме в 19').dueAt, DateTime(2026, 10, 22, 19));
      expect(parse('Позвонить маме в 10').dueAt, DateTime(2026, 10, 23, 10));
      expect(parse('Встреча 15:30').dueAt, DateTime(2026, 10, 23, 15, 30));
    });

    test('день недели, «вечера», категория по началу слова', () {
      final r = parse('Встреча в пятницу в 7 вечера #раб !');
      expect(r.title, 'Встреча');
      expect(r.dueAt, DateTime(2026, 10, 23, 19));
      expect(r.categoryId, 'c2');
      expect(r.priority, 1);
    });

    test('даты: 25.10, 1 декабря, 01.01 — следующий год', () {
      expect(parse('Отчёт к 25.10 !2').dueAt, DateTime(2026, 10, 25, 18));
      expect(parse('Отчёт к 25.10 !2').priority, 2);
      expect(parse('Курсовая до 1 декабря').dueAt, DateTime(2026, 12, 1, 18));
      expect(parse('Новый год 01.01').dueAt, DateTime(2027, 1, 1, 18));
    });

    test('относительные сроки: через 3 дня, через 2 часа', () {
      expect(parse('Доклад через 3 дня').dueAt, DateTime(2026, 10, 25, 18));
      expect(parse('Таблетка через 2 часа').dueAt, DateTime(2026, 10, 22, 18));
    });

    test('каждый понедельник утром и новая категория', () {
      final r = parse('Пробежка каждый понедельник утром #спорт');
      expect(r.repeat, 'weekly');
      expect(r.dueAt, DateTime(2026, 10, 26, 9));
      expect(r.categoryId, isNull);
      expect(r.newCategoryName, 'Спорт');
    });

    test('«срочно» и низкий приоритет', () {
      expect(parse('Срочно купить билеты послезавтра').priority, 1);
      expect(parse('Срочно купить билеты послезавтра').title, 'Купить билеты');
      expect(parse('Глава 2 и 3 сегодня вечером !низкий').priority, 3);
    });
  });

  group('Продуктивность (ФТ-18)', () {
    final now = DateTime(2026, 10, 22, 16);
    DateTime ago(int days, [int hour = 19]) => DateTime(2026, 10, 22 - days, hour);

    test('серия до вчерашнего дня не сгорает, рекорд считается отдельно', () {
      final p = Productivity([ago(1), ago(2), ago(2, 8), ago(3), ago(4), ago(10), ago(11), ago(12), ago(13), ago(14), ago(15), ago(16)], now: now);
      expect(p.currentStreak, 4);
      expect(p.bestStreak, 7);
      expect(p.countOn(ago(2)), 2);
      expect(p.total, 12);
    });

    test('серия прерывается после пропущенного дня', () {
      expect(Productivity([ago(2)], now: now).currentStreak, 0);
      expect(Productivity([ago(0), ago(1)], now: now).currentStreak, 2);
      // переход через месяц
      expect(Productivity([DateTime(2026, 10, 31, 20), DateTime(2026, 11, 1, 10)], now: DateTime(2026, 11, 1, 12)).currentStreak, 2);
    });

    test('уровни тепловой карты и достижения', () {
      expect([0, 1, 2, 3, 4, 9].map(Productivity.level).toList(), [0, 1, 2, 3, 3, 4]);
      final a = {for (final x in Productivity([ago(1, 8), ago(2, 7), ago(3)], now: now).achievements) x.id: x};
      expect(a['first']!.unlocked, isTrue);
      expect(a['ten']!.unlocked, isFalse);
      expect(a['streak3']!.unlocked, isTrue);
      expect(a['early']!.progress, 2);
    });

    test('склонение', () {
      expect([1, 2, 5, 11, 21, 22].map((n) => plural(n, 'день', 'дня', 'дней')).toList(), ['день', 'дня', 'дней', 'дней', 'день', 'дня']);
    });

    test('выполненная задача получает время выполнения', () {
      final t = Task(id: '0f3a9c1e-0000-4000-a000-000000000000', title: 'Т', createdAt: DateTime(2026, 10, 1));
      final done = t.copyWith(isDone: true);
      expect(done.completedAt, isNotNull);
      expect(done.doneAt, done.completedAt);
      expect(done.copyWith(isDone: false).completedAt, isNull);
      expect(t.doneAt, isNull);
    });
  });
}
