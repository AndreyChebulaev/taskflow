/// Умный ввод задачи одной строкой (ФТ-17).
///
/// Пример: «Сдать лабу завтра в 18:00 !важно #учёба каждую неделю напомни за час»
/// → название «Сдать лабу», дедлайн — завтра 18:00, приоритет — высокий,
/// категория — «Учёба», повтор — неделя, напоминание — за 1 час.
///
/// Файл не зависит от Flutter: разбор проверяется обычными модульными тестами.
library;

/// Вид распознанного фрагмента — по нему поле ввода раскрашивает текст.
enum QuickKind { date, time, priority, category, repeat, reminder }

/// Распознанный фрагмент строки: позиция в тексте и что он означает.
class QuickToken {
  const QuickToken(this.start, this.end, this.kind);
  final int start;
  final int end;
  final QuickKind kind;

  @override
  String toString() => '$kind[$start,$end)';
}

/// Результат разбора.
class QuickParse {
  QuickParse({
    required this.title,
    required this.tokens,
    this.dueAt,
    this.priority,
    this.categoryId,
    this.newCategoryName,
    this.repeat,
    this.reminderOffset,
  });

  final String title;
  final List<QuickToken> tokens;
  final DateTime? dueAt;

  /// 1 — высокий, 2 — средний, 3 — низкий (как в таблице tasks).
  final int? priority;

  /// Найденная категория пользователя.
  final String? categoryId;

  /// #название, которого нет среди категорий — её можно создать.
  final String? newCategoryName;

  /// daily / weekly / monthly.
  final String? repeat;

  /// Минут до дедлайна (0, 15, 60, 1440).
  final int? reminderOffset;

  bool get isEmpty => title.isEmpty;
}

class QuickParser {
  /// Время по умолчанию, если указан только день (как в календаре).
  static const defaultHour = 18;

  // Граница слова для кириллицы: \b в Dart работает только с латиницей.
  static const _b = r'(?<![\p{L}\p{N}])';
  static const _e = r'(?![\p{L}\p{N}])';

  static RegExp _re(String body) => RegExp(_b + body + _e, caseSensitive: false, unicode: true);

  static const _weekdays = {
    'понедельник': 1, 'вторник': 2, 'среда': 3, 'среду': 3, 'четверг': 4,
    'пятница': 5, 'пятницу': 5, 'суббота': 6, 'субботу': 6, 'воскресенье': 7,
  };
  static const _weekdayPattern = 'понедельник|вторник|среду|среда|четверг|пятницу|пятница|субботу|суббота|воскресенье';

  static const _months = {
    'янв': 1, 'фев': 2, 'мар': 3, 'апр': 4, 'мая': 5, 'май': 5, 'июн': 6,
    'июл': 7, 'авг': 8, 'сен': 9, 'окт': 10, 'ноя': 11, 'дек': 12,
  };
  static const _monthPattern =
      'января|янв|февраля|фев|марта|мар|апреля|апр|мая|июня|июн|июля|июл|августа|авг|сентября|сент|сен|октября|окт|ноября|нояб|ноя|декабря|дек';

  static final _repeatWeekday = _re('кажд(?:ый|ую|ое)\\s+($_weekdayPattern)');
  static final _repeat = _re('(?:кажд(?:ый|ую|ое)\\s+(день|неделю|месяц)|(ежедневно|еженедельно|ежемесячно))');
  static final _reminder = _re('напомн(?:и|ить)(?:\\s+за\\s+(?:(15)\\s*мин(?:ут[уы]?)?|(?:1\\s*)?(час)|(?:1\\s*)?(день|сутки)))?');
  static final _priority = RegExp(r'(?<!\S)!+(важно|срочно|высокий|средний|низкий|[123])?' + _e, caseSensitive: false, unicode: true);
  static final _urgent = _re('(срочно)');
  static final _category = RegExp(r'(?<!\S)#([\p{L}\p{N}_-]+)', unicode: true);
  static final _inDuration = _re('через\\s+(?:(\\d{1,3})\\s*)?(минут[уы]?|мин|час(?:а|ов)?|полчаса|д(?:ень|ня|ней)|недел(?:ю|и|ь)|месяц(?:а|ев)?)');
  static final _dayWord = _re('(сегодня|завтра|послезавтра)');
  static final _weekday = _re('(?:(?:в|во|к|до)\\s+)?($_weekdayPattern)');
  static final _numericDate = _re('(?:(?:к|до)\\s+)?(\\d{1,2})\\.(\\d{1,2})(?:\\.(\\d{2}|\\d{4}))?');
  static final _textDate = _re('(?:(?:к|до)\\s+)?(\\d{1,2})\\s+($_monthPattern)\\.?');
  static final _timeWithPrep = _re('(?:в|к|до)\\s+(\\d{1,2})(?::(\\d{2}))?(?:\\s*час(?:а|ов)?)?(?:\\s+(утра|дня|вечера|ночи))?');
  static final _timeBare = _re('(\\d{1,2}):(\\d{2})');
  static final _dayPart = _re('(утром|днём|днем|вечером)');

  /// Разобрать строку. [categories] — id → название категорий пользователя.
  static QuickParse parse(String text, {DateTime? now, Map<String, String> categories = const {}}) {
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    final tokens = <QuickToken>[];

    bool free(int s, int e) => tokens.every((t) => e <= t.start || s >= t.end);
    // Находит первое совпадение, не пересекающееся с уже распознанными.
    RegExpMatch? take(RegExp re, QuickKind kind, [bool Function(RegExpMatch m)? accept]) {
      for (final m in re.allMatches(text)) {
        if (!free(m.start, m.end)) continue;
        if (accept != null && !accept(m)) continue;
        tokens.add(QuickToken(m.start, m.end, kind));
        return m;
      }
      return null;
    }

    String? repeat;
    int? priority;
    int? reminder;
    String? categoryId;
    String? newCategory;
    DateTime? day; // дата без времени
    int? hour;
    int? minute;
    DateTime? exact; // «через 2 часа» — точный момент

    // Повтор
    final rw = take(_repeatWeekday, QuickKind.repeat);
    if (rw != null) {
      repeat = 'weekly';
      day = _nextWeekday(today, _weekdays[rw.group(1)!.toLowerCase()]!);
    } else {
      final r = take(_repeat, QuickKind.repeat);
      if (r != null) {
        final w = (r.group(1) ?? r.group(2))!.toLowerCase();
        repeat = (w == 'день' || w == 'ежедневно') ? 'daily' : (w == 'неделю' || w == 'еженедельно') ? 'weekly' : 'monthly';
      }
    }

    // Напоминание
    final rm = take(_reminder, QuickKind.reminder);
    if (rm != null) {
      reminder = rm.group(1) != null ? 15 : rm.group(2) != null ? 60 : rm.group(3) != null ? 1440 : 0;
    }

    // Приоритет
    final p = take(_priority, QuickKind.priority);
    if (p != null) {
      final w = (p.group(1) ?? '').toLowerCase();
      priority = switch (w) { 'средний' || '2' => 2, 'низкий' || '3' => 3, _ => 1 };
    } else if (take(_urgent, QuickKind.priority) != null) {
      priority = 1;
    }

    // Категория
    final c = take(_category, QuickKind.category);
    if (c != null) {
      final name = c.group(1)!;
      categoryId = _findCategory(name, categories);
      if (categoryId == null) newCategory = name[0].toUpperCase() + name.substring(1);
    }

    // Дата и время
    final d = take(_inDuration, QuickKind.date);
    if (d != null) {
      final n = int.tryParse(d.group(1) ?? '') ?? 1;
      final unit = d.group(2)!.toLowerCase();
      if (unit == 'полчаса') {
        exact = clock.add(const Duration(minutes: 30));
      } else if (unit.startsWith('мин')) {
        exact = clock.add(Duration(minutes: n));
      } else if (unit.startsWith('час')) {
        exact = clock.add(Duration(hours: n));
      } else if (unit.startsWith('нед')) {
        day = today.add(Duration(days: 7 * n));
      } else if (unit.startsWith('месяц')) {
        day = DateTime(today.year, today.month + n, today.day);
      } else {
        day = today.add(Duration(days: n));
      }
    }
    if (exact == null && day == null) {
      final w = take(_dayWord, QuickKind.date);
      if (w != null) {
        final shift = switch (w.group(1)!.toLowerCase()) { 'завтра' => 1, 'послезавтра' => 2, _ => 0 };
        day = today.add(Duration(days: shift));
      }
    }
    if (exact == null && day == null) {
      final m = take(_numericDate, QuickKind.date, (m) => _validDate(m.group(1)!, m.group(2)!));
      if (m != null) day = _dateFrom(today, int.parse(m.group(1)!), int.parse(m.group(2)!), m.group(3));
    }
    if (exact == null && day == null) {
      final m = take(_textDate, QuickKind.date, (m) => int.parse(m.group(1)!).between(1, 31));
      if (m != null) day = _dateFrom(today, int.parse(m.group(1)!), _monthOf(m.group(2)!), null);
    }
    if (exact == null && day == null) {
      final m = take(_weekday, QuickKind.date);
      if (m != null) day = _nextWeekday(today, _weekdays[m.group(1)!.toLowerCase()]!);
    }
    if (exact == null) {
      final t = take(_timeWithPrep, QuickKind.time, (m) => _validTime(m.group(1)!, m.group(2), m.group(3)));
      if (t != null) {
        hour = _hour24(int.parse(t.group(1)!), t.group(3));
        minute = int.parse(t.group(2) ?? '0');
      } else {
        final b = take(_timeBare, QuickKind.time, (m) => _validTime(m.group(1)!, m.group(2), null));
        if (b != null) {
          hour = int.parse(b.group(1)!);
          minute = int.parse(b.group(2)!);
        } else {
          final part = take(_dayPart, QuickKind.time);
          if (part != null) {
            hour = switch (part.group(1)!.toLowerCase()) { 'утром' => 9, 'вечером' => 19, _ => 13 };
            minute = 0;
          }
        }
      }
    }

    DateTime? due = exact;
    if (due == null && (day != null || hour != null)) {
      final h = hour ?? defaultHour, min = minute ?? 0;
      if (day != null) {
        due = DateTime(day.year, day.month, day.day, h, min);
      } else {
        // Только время: сегодня, а если уже прошло — завтра
        due = DateTime(today.year, today.month, today.day, h, min);
        if (!due.isAfter(clock)) due = due.add(const Duration(days: 1));
      }
    }
    // Повторяющейся задаче нужен срок: ближайший по правилу повтора
    if (due == null && repeat != null) {
      due = DateTime(today.year, today.month, today.day, defaultHour);
      if (!due.isAfter(clock)) due = due.add(const Duration(days: 1));
    }

    tokens.sort((a, b) => a.start.compareTo(b.start));
    return QuickParse(
      title: _title(text, tokens),
      tokens: tokens,
      dueAt: due,
      priority: priority,
      categoryId: categoryId,
      newCategoryName: newCategory,
      repeat: repeat,
      reminderOffset: due == null ? null : reminder,
    );
  }

  // ---------- вспомогательные ----------

  static String _norm(String s) => s.toLowerCase().replaceAll('ё', 'е');

  /// Точное совпадение названия, иначе — по началу слова (#уч → «Учёба»).
  static String? _findCategory(String name, Map<String, String> categories) {
    final n = _norm(name);
    for (final e in categories.entries) {
      if (_norm(e.value) == n) return e.key;
    }
    for (final e in categories.entries) {
      if (n.length >= 2 && _norm(e.value).startsWith(n)) return e.key;
    }
    return null;
  }

  static DateTime _nextWeekday(DateTime today, int weekday) {
    final diff = (weekday - today.weekday) % 7;
    return today.add(Duration(days: diff));
  }

  static int _monthOf(String word) {
    final w = word.toLowerCase();
    for (final e in _months.entries) {
      if (w.startsWith(e.key)) return e.value;
    }
    return 1;
  }

  static bool _validDate(String d, String m) {
    final day = int.parse(d), month = int.parse(m);
    return day >= 1 && day <= 31 && month >= 1 && month <= 12;
  }

  /// Дата без года — ближайшая в будущем (25.01 в октябре → следующий год).
  static DateTime _dateFrom(DateTime today, int day, int month, String? year) {
    if (year != null) {
      final y = int.parse(year);
      return DateTime(y < 100 ? 2000 + y : y, month, day);
    }
    final d = DateTime(today.year, month, day);
    return d.isBefore(today) ? DateTime(today.year + 1, month, day) : d;
  }

  static bool _validTime(String h, String? m, String? part) {
    final hour = int.parse(h), minute = int.parse(m ?? '0');
    if (minute > 59) return false;
    if (part != null) return hour >= 1 && hour <= 12;
    return hour <= 23;
  }

  static int _hour24(int h, String? part) => switch (part?.toLowerCase()) {
        'вечера' || 'дня' when h < 12 => h + 12,
        'ночи' when h == 12 => 0,
        'утра' when h == 12 => 0,
        _ => h,
      };

  /// Название — текст без распознанных фрагментов.
  static String _title(String text, List<QuickToken> tokens) {
    final buf = StringBuffer();
    var pos = 0;
    for (final t in tokens) {
      buf.write(text.substring(pos, t.start));
      buf.write(' ');
      pos = t.end;
    }
    buf.write(text.substring(pos));
    var title = buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    title = title.replaceAllMapped(RegExp(r'\s+([,.;:!?])'), (m) => m.group(1)!).replaceAll(RegExp(r'^[,.;:\-–—\s]+|[,;:\-–—\s]+$'), '').trim();
    if (title.isEmpty) return '';
    return title[0].toUpperCase() + title.substring(1);
  }
}

extension on int {
  bool between(int a, int b) => this >= a && this <= b;
}
