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
      where: 'status IN (?, ?, ?)',
      whereArgs: ['active', 'retrieved', 'cancelling'],
      orderBy: 'updated_at ASC',
    );
    return rows.map(_ticketFromRow).toList(growable: false);
  }

  /// Returns Finished and Cancelled receipts for the supplied local calendar
  /// day.
  ///
  /// Old receipts remain in SQLite; the day range only controls what is shown
  /// in the KDS history view.
  Future<List<KitchenTicket>> historyTicketsForDay(DateTime day) async {
    final localStart = DateTime(day.year, day.month, day.day);
    final localEnd = localStart.add(const Duration(days: 1));
    final rows = await (await _db).database.query(
      'tickets',
      where: 'status IN (?, ?) AND updated_at >= ? AND updated_at < ?',
      whereArgs: [
        'dismissed',
        'cancelled',
        localStart.toUtc().toIso8601String(),
        localEnd.toUtc().toIso8601String(),
      ],
      orderBy: 'updated_at DESC',
    );
    return rows
        .map((row) => _ticketFromRow(row, includeFinishedAt: true))
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
      for (final orderType in ticket.orderTypes) {
        await transaction.insert(
          'order_types',
          orderType.toJson(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      if (ticket.orderTypeId != null && ticket.orderTypeName != null) {
        await transaction.insert('order_types', {
          'id': ticket.orderTypeId,
          'name': ticket.orderTypeName,
          'icon': 'restaurant',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      final existing = await transaction.query(
        'tickets',
        where: 'id = ?',
        whereArgs: [ticket.id],
      );
      if (existing.isNotEmpty &&
          ticket.revision <= (existing.single['revision'] as int)) {
        return;
      }
      final isCancellation =
          ticket.action == 'cancel' || ticket.action == 'void';
      await transaction.insert('tickets', {
        'id': ticket.id,
        'revision': ticket.revision,
        'status': isCancellation ? 'cancelling' : 'active',
        'payload_json': jsonEncode(ticket.toJson()),
        'updated_at': (isCancellation ? DateTime.now() : ticket.createdAt)
            .toUtc()
            .toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<KdsOrderType>> orderTypes() async =>
      (await (await _db).database.query('order_types', orderBy: 'name ASC'))
          .map((row) => KdsOrderType.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);

  Future<void> updateOrderTypeIcon(String id, String icon) async {
    await (await _db).database.update(
      'order_types',
      {'icon': icon},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Removes only this display's local order-type configuration. It never
  /// sends a mutation to the POS or changes its source order data.
  Future<void> deleteOrderType(String id) async {
    await (await _db).database.delete(
      'order_types',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> dismiss(String ticketId) async {
    await markFinished([ticketId]);
  }

  /// Updates only this display's local ticket status; it never contacts POS.
  Future<void> markFinished(Iterable<String> ticketIds) =>
      _setTicketStatus(ticketIds, status: 'dismissed');

  /// Moves cancelled receipts from their brief dashboard notice into history.
  Future<void> archiveCancelled(Iterable<String> ticketIds) =>
      _setTicketStatus(ticketIds, status: 'cancelled');

  /// Restores a receipt to live orders.
  ///
  /// The retrieved status is reserved for the explicit Order History action.
  /// Undoing the Finished countdown returns the receipt to its normal active
  /// state so it cannot show a misleading retrieved indicator.
  Future<void> restoreFinished(
    Iterable<String> ticketIds, {
    required bool markRetrieved,
  }) => _setTicketStatus(
    ticketIds,
    status: markRetrieved ? 'retrieved' : 'active',
  );

  KitchenTicket _ticketFromRow(
    Map<String, Object?> row, {
    bool includeFinishedAt = false,
  }) {
    final payload = Map<String, dynamic>.from(
      jsonDecode(row['payload_json']! as String) as Map,
    );
    final status = row['status'];
    if (status == 'retrieved') payload['is_retrieved'] = true;
    if (status == 'cancelling' || status == 'cancelled') {
      payload['is_cancelled'] = true;
      payload['cancelled_at'] = row['updated_at'];
    }
    if (includeFinishedAt && status == 'dismissed') {
      payload['finished_at'] = row['updated_at'];
    }
    return KitchenTicket.fromJson(payload);
  }

  Future<void> _setTicketStatus(
    Iterable<String> ticketIds, {
    required String status,
  }) async {
    final ids = ticketIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return;
    final database = (await _db).database;
    final updatedAt = DateTime.now().toUtc().toIso8601String();
    await database.transaction((transaction) async {
      for (final id in ids) {
        await transaction.update(
          'tickets',
          {'status': status, 'updated_at': updatedAt},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });
  }

  Future<AppDatabase> get _db => _database ??= _openDatabase();
}
