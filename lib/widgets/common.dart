import 'package:flutter/material.dart';

import '../theme.dart';

void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: const Color(0xFFB83A3A)));
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String message, String action = 'Удалить'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action, style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Подпись над полем ввода.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.pal.muted)),
      );
}

/// Переключатель-«таблетка» (Вход/Регистрация, тема оформления).
class SegmentedSwitch extends StatelessWidget {
  const SegmentedSwitch({super.key, required this.labels, required this.selected, required this.onChanged, this.background});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: background ?? context.pal.bg, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? context.pal.strong : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: i == selected ? Colors.white : context.pal.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Чип-фильтр в стиле макета.
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, required this.selected, required this.onTap, this.color, this.dot});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color; // цвет выбранного чипа, по умолчанию — из темы
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final active = color ?? context.pal.strong;
    return Material(
      color: selected ? active : context.pal.card,
      shape: StadiumBorder(side: BorderSide(color: selected ? active : context.pal.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 6),
              ],
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : context.pal.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Пустое состояние списка.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: context.pal.tealLight, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.teal, size: 36),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: context.pal.muted)),
          ],
        ],
      ),
    );
  }
}

/// Белая карточка-строка (категории, пункты профиля и настроек).
class ListTileCard extends StatelessWidget {
  const ListTileCard({super.key, required this.leading, required this.title, this.subtitle, this.trailing, this.onTap});
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.pal.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: TextStyle(fontSize: 12, color: context.pal.muted)),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
