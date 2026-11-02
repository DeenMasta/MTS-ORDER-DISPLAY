import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/kds_settings.dart';
import 'app_database.dart';

class DisplaySettingsStore {
  DisplaySettingsStore({required Future<AppDatabase> Function() openDatabase})
    : _openDatabase = openDatabase;

  final Future<AppDatabase> Function() _openDatabase;
  Future<AppDatabase>? _database;

  Future<KdsSettings> load() async {
    final rows = await (await _db).database.query(
      'display_settings',
      where: 'key = ?',
      whereArgs: const ['settings'],
    );
    if (rows.isEmpty) return const KdsSettings();
    try {
      return KdsSettings.fromJson(
        jsonDecode(rows.single['value']! as String) as Map<String, dynamic>,
      );
    } on FormatException {
      return const KdsSettings();
    }
  }

  Future<void> save(KdsSettings settings) async {
    await (await _db).database.insert('display_settings', {
      'key': 'settings',
      'value': jsonEncode(settings.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<AppDatabase> get _db => _database ??= _openDatabase();
}
