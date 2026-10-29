import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/kitchen_ticket.dart';
import 'app_database.dart';

class TicketStore {
  TicketStore({required Future<AppDatabase> Function() openDatabase})
    : _openDatabase = openDatabase;

  final Future<AppDatabase> Function() _openDatabase;
  Future<AppDatabase>? _database;

  Future<List<KitchenTicket>> activeTickets() async {
    final rows = await (await _db).database.query(
      'tickets',
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'updated_at ASC',
    );
    return rows
        .map(
          (row) => KitchenTicket.fromJson(
            jsonDecode(row['payload_json']! as String) as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
  }

  Future<void> receive(KitchenTicket ticket) async {
    final database = (await _db).database;
    await database.transaction((transaction) async {
      final processed = await transaction.query(
        'processed_messages',
        where: 'message_id = ?',
        whereArgs: [ticket.messageId],
      );
      if (processed.isNotEmpty) return;

      await transaction.insert('processed_messages', {
        'message_id': ticket.messageId,
        'received_at': DateTime.now().toUtc().toIso8601String(),
      });
      final existing = await transaction.query(
        'tickets',
        where: 'id = ?',
        whereArgs: [ticket.id],
      );
      if (existing.isNotEmpty && ticket.revision <= (existing.single['revision'] as int)) {
        return;
      }
      await transaction.insert('tickets', {
        'id': ticket.id,
        'revision': ticket.revision,
        'status': ticket.action == 'cancel' ? 'cancelled' : 'active',
        'payload_json': jsonEncode(ticket.toJson()),
        'updated_at': ticket.createdAt.toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> dismiss(String ticketId) async {
    await (await _db).database.update(
      'tickets',
      {'status': 'dismissed'},
      where: 'id = ?',
      whereArgs: [ticketId],
    );
  }

  Future<AppDatabase> get _db => _database ??= _openDatabase();
}
