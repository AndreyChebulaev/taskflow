import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories.dart';
import '../models/task.dart';
import '../screens/task_sheet.dart';
import '../services/quick_parser.dart';
import '../state/settings_store.dart';
import '../state/task_store.dart';
import '../theme.dart';
import 'task_card.dart';

/// Цвет подсветки распознанного фрагмента.
Color quickKindColor(QuickKind kind) => switch (kind) {
      QuickKind.date || QuickKind.time => AppColors.teal,
      QuickKind.priority => AppColors.coral,
      QuickKind.category => const Color(0xFF7C6FE0),
      QuickKind.repeat => const Color(0xFF4A90D9),
      QuickKind.reminder => const Color(0xFFD99A00),
    };

/// Поле, которое прямо при вводе раскрашивает распознанные дату, приоритет,
/// категорию, повтор и напоминание.
class QuickInputController extends TextEditingController {
  Map<String, String> categories = const {};

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final parse = QuickParser.parse(text, categories: categories);
    if (parse.tokens.isEmpty) return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    final children = <TextSpan>[];
    var pos = 0;
    for (final t in parse.tokens) {
      if (t.start > pos) children.add(TextSpan(text: text.substring(pos, t.start)));
      final color = quickKindColor(t.kind);
      children.add(TextSpan(
        text: text.substring(t.start, t.end),
        style: TextStyle(color: color, fontWeight: FontWeight.w700, backgroundColor: color.withValues(alpha: 0.12)),
      ));
      pos = t.end;
    }
    if (pos < text.length) children.add(TextSpan(text: text.substring(pos)));
    return TextSpan(style: style, children: children);
  }
}

/// Строка умного ввода на экране «Задачи» (ФТ-17).
class QuickAddBar extends StatefulWidget {
  const QuickAddBar({super.key});

  @override
  State<QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends State<QuickAddBar> {
  final _controller = QuickInputController();
  final _focus = FocusNode();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  QuickParse _parse(TaskStore store) {
    _controller.categories = {for (final c in store.categories) c.id: c.name};
    return QuickParser.parse(_controller.text, categories: _controller.categories);
  }

  /// Черновик задачи из разобранной строки; новая #категория создаётся.
  Future<TaskDraft> _draft(TaskStore store, QuickParse p) async {
    final defaultReminder = context.read<SettingsStore>().defaultReminder;
    String? categoryId = p.categoryId;
    if (p.newCategoryName != null) {
      final color = AppColors.categoryPalette[store.categories.length % AppColors.categoryPalette.length];
      categoryId = await store.ensureCategory(p.newCategoryName!, colorToHex(color));
    }
    return TaskDraft(
      title: p.title,
      dueAt: p.dueAt,
      priority: p.priority == null ? TaskPriority.medium : TaskPriority.fromValue(p.priority!),
      repeat: Repeat.fromValue(p.repeat),
      categoryId: categoryId,
      reminderOffset: p.tokens.any((t) => t.kind == QuickKind.reminder) ? p.reminderOffset : defaultReminder,
    );
  }

  Future<void> _submit() async {
    final store = context.read<TaskStore>();
    final p = _parse(store);
    if (p.isEmpty || _busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final draft = await _draft(store, p);
      await store.addTask(draft);
      _controller.clear();
      messenger.showSnackBar(SnackBar(
        content: Text('Добавлено: «${draft.title}»${draft.dueAt == null ? '' : ' · ${formatDue(draft.dueAt!)}'}'),
      ));
    } on ReminderException catch (e) {
      _controller.clear();
      messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: const Color(0xFFB83A3A)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(humanError(e)), backgroundColor: const Color(0xFFB83A3A)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Открыть разобранную задачу в полной форме, чтобы что-то поправить.
  Future<void> _openForm() async {
    final store = context.read<TaskStore>();
    final p = _parse(store);
    if (p.isEmpty) return;
    final draft = await _draft(store, p);
    if (!mounted) return;
    _controller.clear();
    _focus.unfocus();
    await showTaskSheet(context, draft: draft);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final p = _parse(store);
    final hasText = _controller.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focus,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submit(),
            maxLength: 300,
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Быстрая задача: «отчёт завтра в 18 !важно #работа»',
              hintStyle: TextStyle(fontSize: 13.5, color: context.pal.muted),
              prefixIcon: const Icon(Icons.bolt_rounded, color: AppColors.teal),
              suffixIcon: hasText
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(tooltip: 'Открыть в форме', onPressed: _busy ? null : _openForm, icon: Icon(Icons.tune_rounded, color: context.pal.muted)),
                      IconButton(
                        tooltip: 'Добавить',
                        onPressed: _busy || p.isEmpty ? null : _submit,
                        icon: const Icon(Icons.send_rounded, color: AppColors.teal),
                      ),
                    ])
                  : IconButton(tooltip: 'Как писать', onPressed: () => showQuickHelp(context), icon: Icon(Icons.help_outline_rounded, color: context.pal.muted)),
            ),
          ),
          if (hasText) ...[
            const SizedBox(height: 8),
            _Preview(parse: p, store: store),
          ],
        ],
      ),
    );
  }
}

/// Что приложение поняло из строки — набор цветных меток.
class _Preview extends StatelessWidget {
  const _Preview({required this.parse, required this.store});
  final QuickParse parse;
  final TaskStore store;

  @override
  Widget build(BuildContext context) {
    final p = parse;
    final chips = <Widget>[
      if (p.dueAt != null) _chip(context, Icons.event_rounded, formatDue(p.dueAt!), quickKindColor(QuickKind.date)),
      if (p.priority != null) _chip(context, Icons.flag_rounded, TaskPriority.fromValue(p.priority!).label, TaskPriority.fromValue(p.priority!).color),
      if (p.categoryId != null)
        _chip(context, Icons.label_rounded, store.categoryById(p.categoryId)?.name ?? '', store.categoryById(p.categoryId)?.color ?? quickKindColor(QuickKind.category)),
      if (p.newCategoryName != null) _chip(context, Icons.new_label_rounded, 'новая: ${p.newCategoryName}', quickKindColor(QuickKind.category)),
      if (p.repeat != null) _chip(context, Icons.repeat_rounded, Repeat.fromValue(p.repeat).label, quickKindColor(QuickKind.repeat)),
      if (p.reminderOffset != null) _chip(context, Icons.notifications_active_rounded, Reminder.label(p.reminderOffset), quickKindColor(QuickKind.reminder)),
    ];
    if (chips.isEmpty) {
      return Text('Можно добавить: завтра в 18, в пятницу, !важно, #учёба, каждую неделю, напомни за час',
          style: TextStyle(fontSize: 12, color: context.pal.muted));
    }
    return Wrap(spacing: 6, runSpacing: 6, children: [
      if (p.title.isNotEmpty) _chip(context, Icons.edit_rounded, p.title, context.pal.ink, outlined: true),
      ...chips,
    ]);
  }

  Widget _chip(BuildContext context, IconData icon, String label, Color color, {bool outlined = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color.withValues(alpha: 0.14),
          border: outlined ? Border.all(color: context.pal.line) : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: outlined ? context.pal.ink : color)),
          ),
        ]),
      );
}

/// Подсказка с правилами умного ввода.
void showQuickHelp(BuildContext context) {
  const rows = [
    (QuickKind.date, 'Дата', 'сегодня, завтра, послезавтра, в пятницу, 25.10, 1 декабря, через 3 дня, через неделю'),
    (QuickKind.time, 'Время', 'в 18, в 18:30, в 7 вечера, утром, вечером, через 2 часа'),
    (QuickKind.priority, 'Приоритет', '!важно или ! — высокий, !средний, !низкий, срочно'),
    (QuickKind.category, 'Категория', '#учёба, #раб (по началу названия), #спорт — создаст новую'),
    (QuickKind.repeat, 'Повтор', 'каждый день, каждую неделю, каждый месяц, каждый понедельник'),
    (QuickKind.reminder, 'Напоминание', 'напомни, напомни за 15 минут, за час, за день'),
  ];
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          const Text('Умный ввод', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Напишите задачу одной строкой — приложение само найдёт срок, приоритет, категорию, повтор и напоминание.',
              style: TextStyle(fontSize: 13, color: ctx.pal.muted)),
          const SizedBox(height: 12),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 5, right: 10), decoration: BoxDecoration(color: quickKindColor(r.$1), shape: BoxShape.circle)),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${r.$2}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: r.$3),
                  ]), style: const TextStyle(fontSize: 14, height: 1.35)),
                ),
              ]),
            ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: ctx.pal.tealLight, borderRadius: BorderRadius.circular(12)),
            child: Text('Пример: «Сдать лабу завтра в 18:00 !важно #учёба каждую неделю напомни за час»',
                style: TextStyle(fontSize: 13, color: ctx.pal.onTealLight, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ),
  );
}
