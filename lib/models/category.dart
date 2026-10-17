import 'package:flutter/material.dart';

import '../theme.dart';

class TaskCategory {
  final String id;
  final String name;
  final String colorHex;

  const TaskCategory({required this.id, required this.name, required this.colorHex});

  Color get color => colorFromHex(colorHex);

  factory TaskCategory.fromMap(Map<String, dynamic> m) => TaskCategory(
        id: m['id'] as String,
        name: m['name'] as String,
        colorHex: m['color'] as String? ?? '#2EC4B6',
      );
}
