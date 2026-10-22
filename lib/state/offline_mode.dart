import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_repositories.dart';

/// Офлайн-режим: работа без интернета и без входа в аккаунт.
/// Данные хранятся только на этом устройстве; режим запоминается между запусками.
class OfflineMode extends ChangeNotifier {
  OfflineMode(this._prefs) : data = LocalData(_prefs);

  final SharedPreferences _prefs;
  final LocalData data;
  static const _key = 'offline_mode';

  bool get active => _prefs.getBool(_key) ?? false;

  Future<void> start() async {
    await data.seedIfEmpty();
    await data.seedHistoryIfNeeded(); // для данных, созданных до версии с ФТ-18
    await _prefs.setBool(_key, true);
    notifyListeners();
  }

  /// Задачи офлайн-режима остаются на устройстве до следующего входа в него.
  Future<void> stop() async {
    await _prefs.setBool(_key, false);
    notifyListeners();
  }
}
