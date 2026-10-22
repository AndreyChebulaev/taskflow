import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories.dart';
import '../state/offline_mode.dart';
import '../state/task_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/productivity_view.dart';
import 'settings_screen.dart';

/// Экран 05: профиль и статистика (ФТ-15). Отсюда открываются настройки (ФТ-16).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Future<String?> _name;

  @override
  void initState() {
    super.initState();
    _name = context.read<OfflineMode>().active
        ? Future.value('Офлайн-режим')
        : context.read<ProfileRepository>().fetchName().catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final email = store.isOffline ? 'данные хранятся на устройстве' : (context.read<AuthRepository>().currentUser?.email ?? '');
    final week = store.weekStats;
    final weekShare = week.total == 0 ? 0.0 : week.done / week.total;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: AppColors.dark,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 16, 20, 24),
            child: FutureBuilder<String?>(
              future: _name,
              builder: (context, snap) {
                final name = (snap.data == null || snap.data!.isEmpty) ? email.split('@').first : snap.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Профиль', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 16),
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: AppColors.teal,
                            child: Text(
                              name.isEmpty ? '?' : name[0].toUpperCase(),
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(email, style: const TextStyle(fontSize: 13, color: Color(0xFFA9C9C6))),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _StatCard(value: store.allTasks.length, label: 'Всего задач', color: context.pal.ink)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatCard(value: store.doneCount, label: 'Выполнено', color: AppColors.teal)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: context.pal.card, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('Выполнено за неделю', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                          Text('${(weekShare * 100).round()}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.teal)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: weekShare, minHeight: 12, color: AppColors.teal, backgroundColor: context.pal.bg),
                      ),
                      const SizedBox(height: 8),
                      Text('${week.done} из ${week.total} задач со сроком на этой неделе', style: TextStyle(fontSize: 12, color: context.pal.muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Серия дней, тепловая карта и достижения (ФТ-18)
                ProductivityView(stats: store.productivity),
                const SizedBox(height: 12),
                ListTileCard(
                  leading: _RoundIcon(Icons.settings_outlined),
                  title: 'Настройки',
                  subtitle: 'Тема, уведомления, выход',
                  trailing: Icon(Icons.chevron_right_rounded, color: context.pal.muted),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
                const SizedBox(height: 12),
                ListTileCard(
                  leading: _RoundIcon(Icons.info_outline_rounded),
                  title: 'О приложении',
                  subtitle: 'Версия 1.0',
                  trailing: Icon(Icons.chevron_right_rounded, color: context.pal.muted),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'TaskFlow',
                    applicationVersion: '1.0',
                    applicationLegalese: 'Учебный проект по дисциплине «Разработка мобильных приложений», ТИУ, 2026',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, required this.color});
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(color: context.pal.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 13, color: context.pal.muted)),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: context.pal.tealLight, shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: context.pal.onTealLight),
      );
}
