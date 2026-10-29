import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._(this.database);

  final Database database;

  static Future<AppDatabase> open() async {
    final database = await openDatabase(
      'kitchen_display.db',
      version: 2,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE tickets (
            id TEXT PRIMARY KEY,
            revision INTEGER NOT NULL,
            status TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE sync_state (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE pending_actions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ticket_id TEXT NOT NULL,
            action TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await _createProcessedMessages(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createProcessedMessages(database);
      },
    );
    return AppDatabase._(database);
  }

  static Future<void> _createProcessedMessages(DatabaseExecutor database) =>
      database.execute('''
        CREATE TABLE processed_messages (
          message_id TEXT PRIMARY KEY,
          received_at TEXT NOT NULL
        )
      ''');
}
