import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/repositories.dart';
import '../state/task_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/task_card.dart';
import 'task_sheet.dart';

/// Экран 04: календарь на месяц (ФТ-12).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month; // первое число отображаемого месяца
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
  }

  void _shiftMonth(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _month = DateTime(now.year, now.month);
      _selected = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final dayTasks = store.tasksOn(_selected);
    final title = DateFormat('LLLL y', 'ru').format(_month);
    final selectedTitle = DateFormat('EEEE, d MMMM', 'ru').format(_selected);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-calendar',
        tooltip: 'Задача на выбранный день',
        onPressed: () => showTaskSheet(context, initialDate: _selected),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text('Календарь', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                  ),
                ),
                TextButton(onPressed: _goToday, child: const Text('Сегодня', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600))),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              decoration: BoxDecoration(color: context.pal.card, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(tooltip: 'Предыдущий месяц', onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
                      Expanded(
                        child: Text(
                          title[0].toUpperCase() + title.substring(1),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(tooltip: 'Следующий месяц', onPressed: () => _shiftMonth(1), icon: const Icon(Icons.chevron_right_rounded)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _MonthGrid(
                    month: _month,
                    selected: _selected,
                    dotColor: (d) => store.topPriorityOn(d)?.color,
                    onSelect: (d) => setState(() {
                      _selected = d;
                      if (d.month != _month.month) _month = DateTime(d.year, d.month);
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedTitle[0].toUpperCase() + selectedTitle.substring(1),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text('задач: ${dayTasks.length}', style: TextStyle(fontSize: 13, color: context.pal.muted)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (dayTasks.isEmpty)
              const EmptyState(icon: Icons.event_available_rounded, title: 'На этот день задач нет')
            else
              for (final t in dayTasks) ...[
                TaskCard(
                  task: t,
                  category: store.categoryById(t.categoryId),
                  onTap: () => showTaskSheet(context, task: t),
                  onToggle: () async {
                    try {
                      await store.toggleDone(t);
                    } catch (e) {
                      if (context.mounted) showError(context, humanError(e));
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

/// Сетка месяца: неделя начинается с понедельника.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.selected, required this.dotColor, required this.onSelect});
  final DateTime month;
  final DateTime selected;
  final Color? Function(DateTime day) dotColor;
  final ValueChanged<DateTime> onSelect;

  static const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstWeekday = DateTime(month.year, month.month, 1).weekday; // 1 = пн
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = firstWeekday - 1;
    final cells = ((leading + daysInMonth) / 7).ceil() * 7;

    return Column(
      children: [
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(child: Center(child: Text(w, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.pal.muted)))),
          ],
        ),
        const SizedBox(height: 6),
        for (var row = 0; row < cells ~/ 7; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: Builder(builder: (context) {
                    final day = DateTime(month.year, month.month, row * 7 + col - leading + 1);
                    final inMonth = day.month == month.month;
                    final isSelected = day == selected;
                    final isToday = day == today;
                    final dot = dotColor(day);
                    return InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => onSelect(day),
                      child: SizedBox(
                        height: 44,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? context.pal.strong : null,
                                shape: BoxShape.circle,
                                border: isToday && !isSelected ? Border.all(color: AppColors.teal, width: 1.5) : null,
                              ),
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? Colors.white : (inMonth ? context.pal.ink : context.pal.checkbox),
                                ),
                              ),
                            ),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(color: isSelected ? null : dot, shape: BoxShape.circle),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
            ],
          ),
      ],
    );
  }
}
