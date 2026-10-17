import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories.dart';
import '../models/category.dart';
import '../state/task_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';

/// Экран 03: категории (ФТ-10, ФТ-11).
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static String _tasksWord(int n) {
    final m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return '$n задача';
    if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return '$n задачи';
    return '$n задач';
  }

  void _openTasks(BuildContext context, String? categoryId) {
    final store = context.read<TaskStore>();
    store.setCategoryFilter(categoryId);
    store.setShowDone(false);
    HomeShell.selectTab(context, 0);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final noCategory = store.countInCategory(null);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 16),
              child: Text('Категории', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            ),
            for (final c in store.categories) ...[
              Dismissible(
                key: ValueKey(c.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(color: AppColors.coral, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Удалить категорию «${c.name}»?',
                    message: 'Задачи из неё не удалятся, а перейдут в «Без категории».',
                  );
                  if (!ok) return false;
                  try {
                    await store.deleteCategory(c.id);
                    return true;
                  } catch (e) {
                    if (context.mounted) showError(context, humanError(e));
                    return false;
                  }
                },
                child: ListTileCard(
                  leading: _ColorBox(color: c.color),
                  title: c.name,
                  subtitle: _tasksWord(store.countInCategory(c.id)),
                  onTap: () => _openTasks(context, c.id),
                  trailing: IconButton(
                    tooltip: 'Изменить',
                    icon: Icon(Icons.edit_outlined, size: 20, color: context.pal.muted),
                    onPressed: () => showCategoryDialog(context, category: c),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ListTileCard(
              leading: _ColorBox(color: context.pal.checkbox),
              title: 'Без категории',
              subtitle: _tasksWord(noCategory),
            ),
            const SizedBox(height: 16),
            Material(
              color: context.pal.tealLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.teal, width: 1.5)),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => showCategoryDialog(context),
                child: SizedBox(
                  height: 52,
                  child: Center(
                    child: Text('+  Новая категория', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.pal.onTealLight)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Свайп влево — удалить категорию', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: context.pal.muted)),
          ],
        ),
      ),
    );
  }
}

class _ColorBox extends StatelessWidget {
  const _ColorBox({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 32, height: 32, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)));
}

/// Диалог создания / редактирования категории: название и цвет.
Future<void> showCategoryDialog(BuildContext context, {TaskCategory? category}) {
  return showDialog(context: context, builder: (_) => _CategoryDialog(category: category));
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.category});
  final TaskCategory? category;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.category?.name ?? '');
  late Color _color = widget.category?.color ?? AppColors.teal;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Введите название');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final store = context.read<TaskStore>();
    try {
      if (widget.category == null) {
        await store.addCategory(name, colorToHex(_color));
      } else {
        await store.updateCategory(widget.category!.id, name, colorToHex(_color));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = humanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'Новая категория' : 'Изменить категорию'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 50,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: 'Название', errorText: _error, counterText: ''),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          Text('Цвет', style: TextStyle(fontSize: 12, color: context.pal.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in AppColors.categoryPalette)
                Semantics(
                  selected: c.toARGB32() == _color.toARGB32(),
                  button: true,
                  child: GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.toARGB32() == _color.toARGB32() ? context.pal.ink : Colors.transparent, width: 2.5),
                      ),
                      child: c.toARGB32() == _color.toARGB32() ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        TextButton(
          onPressed: _busy ? null : _save,
          child: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
