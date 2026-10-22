import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/repositories.dart';
import '../models/task.dart';
import '../state/settings_store.dart';
import '../state/task_store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Экран 07: нижняя панель создания и редактирования задачи
/// (ФТ-4, ФТ-5, ФТ-7, ФТ-9). Если [initialDate] задана — дедлайн
/// по умолчанию ставится на этот день (используется из календаря).
Future<void> showTaskSheet(BuildContext context, {Task? task, DateTime? initialDate, TaskDraft? draft}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.pal.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => TaskSheet(task: task, initialDate: initialDate, draft: draft),
  );
}

class TaskSheet extends StatefulWidget {
  const TaskSheet({super.key, this.task, this.initialDate, this.draft});
  final Task? task;
  final DateTime? initialDate;

  /// Заполненный черновик новой задачи (из умного ввода, ФТ-17).
  final TaskDraft? draft;

  @override
  State<TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<TaskSheet> {
  final _form = GlobalKey<FormState>();
  late final TaskDraft _draft;
  late final TextEditingController _title;
  late final TextEditingController _description;
  bool _busy = false;

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _draft = TaskDraft.fromTask(widget.task!);
    } else if (widget.draft != null) {
      _draft = widget.draft!;
    } else {
      final d = widget.initialDate;
      _draft = TaskDraft(
        dueAt: d == null ? null : DateTime(d.year, d.month, d.day, 18),
        categoryId: context.read<TaskStore>().categoryFilter,
        reminderOffset: context.read<SettingsStore>().defaultReminder,
      );
    }
    _title = TextEditingController(text: _draft.title);
    _description = TextEditingController(text: _draft.description ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final base = _draft.dueAt ?? DateTime(now.year, now.month, now.day, 18);
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: 'Дедлайн',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base), helpText: 'Время');
    final t = time ?? TimeOfDay.fromDateTime(base);
    setState(() => _draft.dueAt = DateTime(date.year, date.month, date.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_draft.repeat != Repeat.none && _draft.dueAt == null) {
      showError(context, 'Для повторяющейся задачи укажите дедлайн');
      return;
    }
    _draft
      ..title = _title.text
      ..description = _description.text;
    setState(() => _busy = true);
    final store = context.read<TaskStore>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final offset = _draft.effectiveReminder;
    final remindAt = offset == null ? null : _draft.dueAt!.subtract(Duration(minutes: offset));
    try {
      if (_isEdit) {
        await store.updateTask(widget.task!.id, _draft);
      } else {
        await store.addTask(_draft);
      }
      navigator.pop();
      // Подсказка, если напоминание уже в прошлом по часам устройства
      if (remindAt != null && !remindAt.isAfter(DateTime.now())) {
        messenger.showSnackBar(SnackBar(
          content: Text('Время напоминания уже прошло по часам устройства '
              '(${DateFormat('d MMM, HH:mm', 'ru').format(DateTime.now())}) — уведомление не придёт'),
        ));
      }
    } on ReminderException catch (e) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: const Color(0xFFB83A3A), duration: const Duration(seconds: 8)));
    } catch (e) {
      if (mounted) showError(context, humanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, title: 'Удалить задачу?', message: '«${widget.task!.title}» будет удалена без возможности восстановления.');
    if (!ok || !mounted) return;
    final store = context.read<TaskStore>();
    final navigator = Navigator.of(context);
    try {
      await store.deleteTask(widget.task!.id);
      navigator.pop();
    } catch (e) {
      if (mounted) showError(context, humanError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final notificationsOff = !context.watch<SettingsStore>().notificationsEnabled;
    final categoryExists = store.categoryById(_draft.categoryId) != null;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_isEdit ? 'Редактирование' : 'Новая задача', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                ),
                if (_isEdit)
                  IconButton(
                    tooltip: 'Удалить задачу',
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.coral),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const FieldLabel('Название *'),
            TextFormField(
              controller: _title,
              autofocus: !_isEdit,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Что нужно сделать?', counterText: ''),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null,
            ),
            const SizedBox(height: 14),
            const FieldLabel('Описание'),
            TextFormField(
              controller: _description,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Необязательно', counterText: ''),
            ),
            const SizedBox(height: 14),
            const FieldLabel('Дедлайн'),
            _PickerField(
              text: _draft.dueAt == null ? 'Без срока' : DateFormat('d MMMM y, HH:mm', 'ru').format(_draft.dueAt!),
              icon: Icons.calendar_today_outlined,
              onTap: _pickDue,
              onClear: _draft.dueAt == null ? null : () => setState(() => _draft.dueAt = null),
            ),
            const SizedBox(height: 14),
            const FieldLabel('Категория'),
            DropdownButtonFormField<String?>(
              initialValue: categoryExists ? _draft.categoryId : null,
              isExpanded: true,
              decoration: const InputDecoration(),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Без категории')),
                for (final c in store.categories)
                  DropdownMenuItem<String?>(
                    value: c.id,
                    child: Row(children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: c.color, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(width: 10),
                      Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
              ],
              onChanged: (v) => setState(() => _draft.categoryId = v),
            ),
            const SizedBox(height: 14),
            const FieldLabel('Приоритет'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in TaskPriority.values)
                AppChip(label: p.label, color: p.color, selected: _draft.priority == p, onTap: () => setState(() => _draft.priority = p)),
            ]),
            const SizedBox(height: 14),
            const FieldLabel('Повтор'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in Repeat.values)
                AppChip(label: r.label, selected: _draft.repeat == r, onTap: () => setState(() => _draft.repeat = r)),
            ]),
            const SizedBox(height: 14),
            const FieldLabel('Напоминание'),
            DropdownButtonFormField<int?>(
              key: ValueKey(_draft.dueAt == null),
              initialValue: _draft.dueAt == null ? null : _draft.reminderOffset,
              isExpanded: true,
              decoration: InputDecoration(
                helperText: _draft.dueAt == null
                    ? 'Сначала укажите дедлайн'
                    : (notificationsOff ? 'Уведомления выключены в настройках' : null),
              ),
              items: [
                for (final e in Reminder.options.entries)
                  DropdownMenuItem<int?>(value: e.key, child: Text(e.value)),
              ],
              onChanged: _draft.dueAt == null ? null : (v) => setState(() => _draft.reminderOffset = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({required this.text, required this.icon, required this.onTap, this.onClear});
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.pal.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: context.pal.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(child: Text(text, style: TextStyle(fontSize: 15, color: onClear == null ? context.pal.muted : context.pal.ink))),
                if (onClear != null)
                  IconButton(tooltip: 'Убрать срок', onPressed: onClear, icon: Icon(Icons.close_rounded, size: 20, color: context.pal.muted))
                else
                  Padding(padding: const EdgeInsets.only(right: 12), child: Icon(icon, size: 20, color: context.pal.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
