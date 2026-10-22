/// Продуктивность (ФТ-18): тепловая карта выполненных задач, серии дней
/// и достижения. Считается по датам выполнения задач, без обращения к серверу.
/// Файл не зависит от Flutter и проверяется модульными тестами.
library;

/// Достижение и прогресс к нему.
class Achievement {
  const Achievement(this.id, this.title, this.description, this.progress, this.target);
  final String id;
  final String title;
  final String description;
  final int progress;
  final int target;

  bool get unlocked => progress >= target;
  int get shown => progress > target ? target : progress;
}

class Productivity {
  Productivity(Iterable<DateTime> completions, {DateTime? now}) : _now = now ?? DateTime.now() {
    for (final c in completions) {
      final d = dayOf(c);
      _byDay[d] = (_byDay[d] ?? 0) + 1;
      _total++;
      if (c.hour < 9) _early++;
    }
  }

  final DateTime _now;
  final Map<DateTime, int> _byDay = {};
  int _total = 0;
  int _early = 0;

  static DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime get today => dayOf(_now);
  int get total => _total;

  /// Сколько задач выполнено в этот день.
  int countOn(DateTime day) => _byDay[dayOf(day)] ?? 0;

  /// Уровень цвета клетки тепловой карты: 0 — пусто, 4 — максимум.
  static int level(int count) => switch (count) { 0 => 0, 1 => 1, 2 => 2, 3 || 4 => 3, _ => 4 };

  /// Серия: сколько дней подряд выполнялась хотя бы одна задача.
  /// Если сегодня ещё ничего не выполнено, серия считается до вчерашнего дня —
  /// она не сгорает, пока день не закончился.
  int get currentStreak {
    var day = today;
    if (countOn(day) == 0) day = DateTime(day.year, day.month, day.day - 1);
    var n = 0;
    while (countOn(day) > 0) {
      n++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return n;
  }

  /// Самая длинная серия за всё время.
  int get bestStreak {
    final days = _byDay.keys.toList()..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final d in days) {
      final next = prev == null ? null : DateTime(prev.year, prev.month, prev.day + 1);
      run = (next != null && d == next) ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }

  bool get doneToday => countOn(today) > 0;

  List<Achievement> get achievements {
    final best = bestStreak;
    return [
      Achievement('first', 'Первый шаг', 'Выполните первую задачу', _total, 1),
      Achievement('ten', 'Десятка', 'Выполните 10 задач', _total, 10),
      Achievement('fifty', 'Полсотни', 'Выполните 50 задач', _total, 50),
      Achievement('streak3', 'В ритме', 'Выполняйте задачи 3 дня подряд', best, 3),
      Achievement('streak7', 'Неделя без пропусков', 'Выполняйте задачи 7 дней подряд', best, 7),
      Achievement('early', 'Ранняя пташка', 'Выполните 5 задач до 9:00', _early, 5),
    ];
  }
}

/// Русское склонение: plural(5, 'задача', 'задачи', 'задач') → «задач».
String plural(int n, String one, String few, String many) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
  return many;
}
