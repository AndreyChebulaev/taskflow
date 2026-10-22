import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../state/productivity.dart';
import '../theme.dart';

/// Блок продуктивности в профиле (ФТ-18): серия дней, тепловая карта, достижения.
class ProductivityView extends StatelessWidget {
  const ProductivityView({super.key, required this.stats});
  final Productivity stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StreakCard(stats: stats),
        const SizedBox(height: 12),
        _Card(
          title: 'Активность',
          trailing: '${stats.total} ${plural(stats.total, 'задача', 'задачи', 'задач')}',
          child: Heatmap(stats: stats),
        ),
        const SizedBox(height: 12),
        _Card(
          title: 'Достижения',
          trailing: '${stats.achievements.where((a) => a.unlocked).length} из ${stats.achievements.length}',
          child: _Achievements(stats: stats),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.trailing});
  final String title;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.pal.card, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            if (trailing != null) Text(trailing!, style: TextStyle(fontSize: 12, color: context.pal.muted)),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

/// Серия дней подряд с выполненными задачами.
class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.stats});
  final Productivity stats;

  @override
  Widget build(BuildContext context) {
    final n = stats.currentStreak;
    final active = n > 0;
    final hint = !active
        ? 'Выполните задачу сегодня, чтобы начать серию'
        : stats.doneToday
            ? 'Сегодня задача уже выполнена — серия продолжается'
            : 'Выполните задачу сегодня, чтобы не прервать серию';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.pal.card, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: active ? AppColors.coral.withValues(alpha: 0.15) : context.pal.bg,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.local_fire_department_rounded, size: 30, color: active ? AppColors.coral : context.pal.checkbox),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$n ${plural(n, 'день', 'дня', 'дней')} подряд',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: active ? AppColors.coral : context.pal.ink)),
            const SizedBox(height: 2),
            Text(hint, style: TextStyle(fontSize: 12, color: context.pal.muted)),
          ]),
        ),
        Column(children: [
          Text('${stats.bestStreak}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.pal.ink)),
          Text('рекорд', style: TextStyle(fontSize: 11, color: context.pal.muted)),
        ]),
      ]),
    );
  }
}

/// Тепловая карта: колонка — неделя (пн–вс), цвет клетки — сколько задач выполнено.
class Heatmap extends StatelessWidget {
  const Heatmap({super.key, required this.stats});
  final Productivity stats;

  static const _gap = 3.0;
  static const _labelW = 22.0;

  Color _color(BuildContext context, int level) => level == 0
      ? context.pal.line.withValues(alpha: 0.6)
      : AppColors.teal.withValues(alpha: const [0.0, 0.3, 0.55, 0.8, 1.0][level]);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      const cell = 15.0;
      final weeks = ((box.maxWidth - _labelW) / (cell + _gap)).floor().clamp(8, 30);
      final today = stats.today;
      final firstMonday = DateTime(today.year, today.month, today.day - (today.weekday - 1) - 7 * (weeks - 1));
      final columns = <Widget>[];
      final months = <Widget>[];
      int? prevMonth;
      for (var w = 0; w < weeks; w++) {
        final weekStart = DateTime(firstMonday.year, firstMonday.month, firstMonday.day + 7 * w);
        // Подпись месяца над первой неделей этого месяца
        final label = w == 0 ? weekStart.day <= 21 : weekStart.month != prevMonth;
        prevMonth = weekStart.month;
        if (label && w < weeks - 1) {
          months.add(Positioned(
            left: _labelW + w * (cell + _gap),
            child: Text(DateFormat('LLL', 'ru').format(weekStart).replaceAll('.', ''),
                style: TextStyle(fontSize: 10, color: context.pal.muted)),
          ));
        }
        columns.add(Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: Column(children: [
            for (var d = 0; d < 7; d++)
              _cell(context, DateTime(weekStart.year, weekStart.month, weekStart.day + d), today, cell),
          ]),
        ));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: 14, child: Stack(clipBehavior: Clip.none, children: months)),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: _labelW,
            child: Column(children: [
              for (final l in const ['пн', '', 'ср', '', 'пт', '', 'вс'])
                SizedBox(height: cell + _gap, child: Text(l, style: TextStyle(fontSize: 9.5, color: context.pal.muted))),
            ]),
          ),
          ...columns,
        ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('меньше ', style: TextStyle(fontSize: 10, color: context.pal.muted)),
          for (var l = 0; l <= 4; l++)
            Container(
              width: 11,
              height: 11,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(color: _color(context, l), borderRadius: BorderRadius.circular(3)),
            ),
          Text(' больше', style: TextStyle(fontSize: 10, color: context.pal.muted)),
        ]),
      ]);
    });
  }

  Widget _cell(BuildContext context, DateTime day, DateTime today, double size) {
    final future = day.isAfter(today);
    final count = stats.countOn(day);
    final box = Container(
      width: size,
      height: size,
      margin: const EdgeInsets.only(bottom: _gap),
      decoration: BoxDecoration(
        color: future ? Colors.transparent : _color(context, Productivity.level(count)),
        borderRadius: BorderRadius.circular(3),
        border: day == today ? Border.all(color: AppColors.coral, width: 1.5) : null,
      ),
    );
    if (future) return box;
    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      message: '${DateFormat('d MMMM', 'ru').format(day)}: '
          '${count == 0 ? 'нет выполненных задач' : '$count ${plural(count, 'задача', 'задачи', 'задач')}'}',
      child: box,
    );
  }
}

class _Achievements extends StatelessWidget {
  const _Achievements({required this.stats});
  final Productivity stats;

  static const _icons = {
    'first': Icons.flag_rounded,
    'ten': Icons.military_tech_rounded,
    'fifty': Icons.emoji_events_rounded,
    'streak3': Icons.local_fire_department_rounded,
    'streak7': Icons.whatshot_rounded,
    'early': Icons.wb_twilight_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = (box.maxWidth - 16) / 3;
      return Wrap(spacing: 8, runSpacing: 8, children: [
        for (final a in stats.achievements)
          SizedBox(
            width: w,
            child: Tooltip(
              triggerMode: TooltipTriggerMode.tap,
              message: '${a.description}${a.unlocked ? ' — получено!' : ' (${a.shown} из ${a.target})'}',
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
                decoration: BoxDecoration(
                  color: a.unlocked ? context.pal.tealLight : context.pal.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  Icon(_icons[a.id], size: 28, color: a.unlocked ? AppColors.teal : context.pal.checkbox),
                  const SizedBox(height: 6),
                  Text(a.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: a.unlocked ? context.pal.ink : context.pal.muted)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: a.shown / a.target,
                      minHeight: 4,
                      color: AppColors.teal,
                      backgroundColor: context.pal.line,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${a.shown}/${a.target}', style: TextStyle(fontSize: 10, color: context.pal.muted)),
                ]),
              ),
            ),
          ),
      ]);
    });
  }
}
