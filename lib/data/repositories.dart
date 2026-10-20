import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';
import '../models/task.dart';

SupabaseClient get _db => Supabase.instance.client;

/// Авторизация (ФТ-1 – ФТ-3). Пароли хранит Supabase Auth.
class AuthRepository {
  User? get currentUser => _db.auth.currentUser;
  Stream<AuthState> get changes => _db.auth.onAuthStateChange;

  Future<void> signIn(String email, String password) async {
    await _db.auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// Возвращает true, если сразу создана сессия (подтверждение email выключено).
  Future<bool> signUp(String name, String email, String password) async {
    final res = await _db.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'name': name.trim()}, // триггер handle_new_user создаст профиль с этим именем
    );
    return res.session != null;
  }

  Future<void> resetPassword(String email) => _db.auth.resetPasswordForEmail(email.trim());

  Future<void> signOut() => _db.auth.signOut();

  /// Смена пароля из настроек (ФТ-16).
  Future<void> updatePassword(String password) async {
    await _db.auth.updateUser(UserAttributes(password: password));
  }
}

/// Профиль пользователя (ФТ-15).
class ProfileRepository {
  Future<String?> fetchName() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _db.from('profiles').select('name').eq('id', uid).maybeSingle();
    return row?['name'] as String?;
  }
}

/// Задачи (ФТ-4 – ФТ-9) и напоминания к ним (ФТ-13).
/// user_id база подставляет сама (default auth.uid()).
class TaskRepository {
  /// Задача вместе с её напоминанием (связь reminders.task_id → tasks.id).
  static const _select = '*, reminders(offset_minutes)';

  Future<List<Task>> fetchAll() async {
    final rows = await _db.from('tasks').select(_select).order('due_at', ascending: true, nullsFirst: false);
    return rows.map(Task.fromMap).toList();
  }

  Future<Task> create(TaskDraft d) async {
    final row = await _db.from('tasks').insert(d.toMap()).select().single();
    final task = Task.fromMap(row);
    await _saveReminder(task.id, d);
    return d.effectiveReminder == null ? task : task.copyWith(reminderOffset: d.effectiveReminder);
  }

  Future<Task> update(String id, TaskDraft d) async {
    final row = await _db.from('tasks').update(d.toMap()).eq('id', id).select().single();
    final task = Task.fromMap(row);
    await _saveReminder(id, d);
    return d.effectiveReminder == null ? task : task.copyWith(reminderOffset: d.effectiveReminder);
  }

  /// У задачи одно напоминание: удаляем старое и записываем новое.
  Future<void> _saveReminder(String taskId, TaskDraft d) async {
    await _db.from('reminders').delete().eq('task_id', taskId);
    final offset = d.effectiveReminder;
    if (offset == null) return;
    await _db.from('reminders').insert({
      'task_id': taskId,
      'offset_minutes': offset,
      'remind_at': d.dueAt!.subtract(Duration(minutes: offset)).toUtc().toIso8601String(),
    });
  }

  Future<void> setDone(String id, bool done) async {
    await _db.from('tasks').update({'is_done': done}).eq('id', id);
  }

  /// Напоминания удалятся каскадно (on delete cascade).
  Future<void> delete(String id) async {
    await _db.from('tasks').delete().eq('id', id);
  }
}

/// Категории (ФТ-10, ФТ-11).
class CategoryRepository {
  Future<List<TaskCategory>> fetchAll() async {
    final rows = await _db.from('categories').select().order('created_at');
    return rows.map(TaskCategory.fromMap).toList();
  }

  Future<TaskCategory> create(String name, String colorHex) async {
    final row = await _db.from('categories').insert({'name': name.trim(), 'color': colorHex}).select().single();
    return TaskCategory.fromMap(row);
  }

  Future<TaskCategory> update(String id, String name, String colorHex) async {
    final row = await _db
        .from('categories')
        .update({'name': name.trim(), 'color': colorHex})
        .eq('id', id)
        .select()
        .single();
    return TaskCategory.fromMap(row);
  }

  /// Задачи категории не удаляются: в базе category_id станет NULL (on delete set null).
  Future<void> delete(String id) async {
    await _db.from('categories').delete().eq('id', id);
  }
}

/// Понятные сообщения об ошибках на русском.
String humanError(Object e) {
  // Сетевые ошибки проверяем первыми: Supabase Auth заворачивает их в AuthException
  final raw = e.toString();
  if (raw.contains('SocketException') || raw.contains('Failed host lookup') || raw.contains('ClientException') || raw.contains('Network is unreachable')) {
    return 'Нет подключения к интернету. Проверьте сеть и попробуйте снова';
  }
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login credentials')) return 'Неверный email или пароль';
    if (m.contains('signups') && m.contains('disabled')) return 'Регистрация отключена в настройках Supabase (Authentication → Sign In / Providers)';
    if (m.contains('already registered') || m.contains('already been registered')) return 'Пользователь с таким email уже зарегистрирован';
    if (m.contains('email not confirmed')) return 'Email не подтверждён. Проверьте почту';
    if (m.contains('password should be at least')) return 'Пароль должен быть не короче 6 символов';
    if (m.contains('should be different')) return 'Новый пароль совпадает со старым';
    if (m.contains('rate limit') || m.contains('security purposes')) return 'Слишком много попыток. Подождите минуту';
    if (m.contains('invalid') && m.contains('email')) return 'Некорректный email';
    return e.message;
  }
  if (e is DuplicateNameException) return 'Такое название уже есть';
  if (e is PostgrestException) {
    if (e.code == '23505') return 'Такое название уже есть';
    if (e.code == '23514') return 'Недопустимое значение поля';
    return 'Ошибка базы данных: ${e.message}';
  }
  final s = e.toString();
  if (s.contains('SocketException') || s.contains('ClientException') || s.contains('Failed host lookup')) {
    return 'Нет подключения к интернету';
  }
  return 'Что-то пошло не так: $s';
}

/// Повтор названия категории в офлайн-режиме (аналог ошибки 23505 в базе).
class DuplicateNameException implements Exception {
  const DuplicateNameException();
}
