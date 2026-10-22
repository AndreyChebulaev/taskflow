import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/repositories.dart';
import '../models/task.dart';
import '../state/offline_mode.dart';
import '../state/task_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/quick_add.dart';
import '../widgets/task_card.dart';
import 'task_sheet.dart';

/// Экран 02: список задач (ФТ-4 – ФТ-9).
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final tasks = store.visibleTasks;
    final today = DateFormat('EEEE, d MMMM', 'ru').format(DateTime.now());
    final todayCap = today[0].toUpperCase() + today.substring(1);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-tasks',
        tooltip: 'Новая задача',
        onPressed: () => showTaskSheet(context),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.teal,
          onRefresh: store.load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Задачи', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700))),
                      _SortButton(store: store),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
                  child: Text('$todayCap · активных: ${store.activeCount}${store.isOffline ? ' · офлайн' : ''}', style: TextStyle(fontSize: 13, color: context.pal.muted)),
                ),
              ),
              // Умный ввод одной строкой (ФТ-17)
              const SliverToBoxAdapter(child: QuickAddBar()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(spacing: 8, children: [
                    AppChip(label: 'Активные', selected: !store.showDone, onTap: () => store.setShowDone(false)),
                    AppChip(label: 'Выполненные', selected: store.showDone, onTap: () => store.setShowDone(true)),
                  ]),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    children: [
                      AppChip(label: 'Все', selected: store.categoryFilter == null, onTap: () => store.setCategoryFilter(null)),
                      for (final c in store.categories) ...[
                        const SizedBox(width: 8),
                        AppChip(
                          label: c.name,
                          dot: c.color,
                          selected: store.categoryFilter == c.id,
                          onTap: () => store.setCategoryFilter(c.id),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (store.loading && store.allTasks.isEmpty)
                const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator(color: AppColors.teal)))
              else if (store.error != null && store.allTasks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      EmptyState(icon: Icons.cloud_off_rounded, title: 'Не удалось загрузить задачи', subtitle: store.error),
                      TextButton(onPressed: store.load, child: const Text('Повторить')),
                      if (!store.isOffline)
                        TextButton.icon(
                          onPressed: () => context.read<OfflineMode>().start(),
                          icon: const Icon(Icons.cloud_off_rounded, size: 18),
                          label: const Text('Работать без интернета'),
                        ),
                    ],
                  ),
                )
              else if (tasks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: store.showDone
                        ? const EmptyState(icon: Icons.task_alt_rounded, title: 'Выполненных задач пока нет')
                        : const EmptyState(
                            icon: Icons.checklist_rounded,
                            title: 'Активных задач нет',
                            subtitle: 'Нажмите «+», чтобы добавить первую задачу',
                          ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  sliver: SliverList.separated(
                    itemCount: tasks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _DismissibleTask(task: tasks[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Карточка со свайпом влево для удаления (ФТ-5, с подтверждением).
class _DismissibleTask extends StatelessWidget {
  const _DismissibleTask({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final store = context.read<TaskStore>();
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: AppColors.coral, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) => confirmDialog(context, title: 'Удалить задачу?', message: '«${task.title}» будет удалена без возможности восстановления.'),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await store.deleteTask(task.id);
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(humanError(e)), backgroundColor: const Color(0xFFB83A3A)));
        }
      },
      child: TaskCard(
        task: task,
        category: store.categoryById(task.categoryId),
        onTap: () => showTaskSheet(context, task: task),
        onToggle: () async {
          // Карточка исчезнет из списка сразу после отметки, поэтому
          // берём ScaffoldMessenger заранее, пока context ещё в дереве.
          final messenger = ScaffoldMessenger.of(context);
          try {
            final next = await store.toggleDone(task);
            if (next != null && next.dueAt != null) {
              messenger.showSnackBar(SnackBar(content: Text('Следующая задача создана на ${formatDue(next.dueAt!)}')));
            }
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text(humanError(e)), backgroundColor: const Color(0xFFB83A3A)));
          }
        },
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.store});
  final TaskStore store;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TaskSort>(
      tooltip: 'Сортировка',
      initialValue: store.sort,
      onSelected: store.setSort,
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: context.pal.card, shape: BoxShape.circle),
        child: Icon(Icons.sort_rounded, size: 20, color: context.pal.ink),
      ),
      itemBuilder: (_) => const [
        PopupMenuItem(value: TaskSort.byDue, child: Text('По дедлайну')),
        PopupMenuItem(value: TaskSort.byPriority, child: Text('По приоритету')),
      ],
    );
  }
}
