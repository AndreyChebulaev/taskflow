import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/task.dart';
import '../theme.dart';

/// «Сегодня, 18:00», «Завтра», «17 окт.»
String formatDue(DateTime d, {bool withTime = true}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  final hasTime = d.hour != 0 || d.minute != 0;
  final time = withTime && hasTime ? ', ${DateFormat.Hm('ru').format(d)}' : '';
  if (diff == 0) return 'сегодня$time';
  if (diff == 1) return 'завтра$time';
  if (diff == -1) return 'вчера$time';
  final pattern = d.year == now.year ? 'd MMMM' : 'd MMMM y';
  return '${DateFormat(pattern, 'ru').format(d)}$time';
}

/// Карточка задачи (компонент «Task card» из макета).
class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, this.category, required this.onToggle, required this.onTap});
  final Task task;
  final TaskCategory? category;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      category?.name ?? 'Без категории',
      if (task.dueAt != null) formatDue(task.dueAt!),
    ].join(' · ');

    return Material(
      color: context.pal.card,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: task.priority.color,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
                ),
              ),
              Semantics(
                checked: task.isDone,
                label: task.isDone ? 'Снять отметку' : 'Отметить выполненной',
                child: InkWell(
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                    child: Center(child: _CheckBox(done: task.isDone)),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: task.isDone ? context.pal.muted : context.pal.ink,
                          decoration: task.isDone ? TextDecoration.lineThrough : null,
                          decorationColor: context.pal.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: task.isOverdue ? AppColors.coral : context.pal.muted),
                      ),
                    ],
                  ),
                ),
              ),
              if (task.repeat != Repeat.none)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Tooltip(
                    message: 'Повтор: ${task.repeat.label.toLowerCase()}',
                    child: Icon(Icons.repeat_rounded, size: 18, color: context.pal.muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: done ? AppColors.teal : context.pal.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: done ? AppColors.teal : context.pal.checkbox, width: 1.6),
      ),
      child: done ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
    );
  }
}
