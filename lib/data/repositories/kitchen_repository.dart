import 'dart:async';

import '../../domain/models/display_session.dart';
import '../../domain/models/kitchen_ticket.dart';
import '../services/pos_connection_service.dart';
import '../services/ticket_store.dart';

abstract interface class KitchenRepository {
  Stream<void> get changes;

  Future<List<KitchenTicket>> dismiss(String ticketId);

  Future<List<KitchenTicket>> start(DisplaySession session);
}

class StoredKitchenRepository implements KitchenRepository {
  StoredKitchenRepository({
    required PosConnectionService connection,
    required TicketStore store,
  }) : _connection = connection,
       _store = store;

  final PosConnectionService _connection;
  final TicketStore _store;
  final _changes = StreamController<void>.broadcast();
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<KitchenTicket>> start(DisplaySession session) async {
    await _connection.connect(Uri.parse(session.posEndpoint));
    _subscription ??= _connection.messages
        .where((message) => message['type'] == 'kitchen_order')
        .listen((message) => unawaited(_receive(message)));
    return _store.activeTickets();
  }

  @override
  Future<List<KitchenTicket>> dismiss(String ticketId) async {
    await _store.dismiss(ticketId);
    final tickets = await _store.activeTickets();
    _changes.add(null);
    return tickets;
  }

  Future<void> _receive(Map<String, dynamic> message) async {
    try {
      if (message['protocol'] != 'kitchen-order.v1') return;
      final ticket = KitchenTicket.fromJson(message);
      await _store.receive(ticket);
      _connection.send({
        'type': 'kitchen_order.received',
        'message_id': ticket.messageId,
        'received_at': DateTime.now().toUtc().toIso8601String(),
      });
      _changes.add(null);
    } on FormatException {
      // Ignore malformed LAN input. It is not safe to acknowledge it.
    }
  }
}
