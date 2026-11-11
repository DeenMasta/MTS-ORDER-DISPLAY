import 'dart:async';

import '../../domain/models/display_session.dart';
import '../../domain/models/kitchen_ticket.dart';
import '../../domain/models/pairing.dart';
import '../services/pos_connection_service.dart';
import '../services/ticket_store.dart';
import 'device_identity_repository.dart';
import 'pairing_repository.dart';

abstract interface class KitchenRepository {
  Stream<void> get changes;
  PairingConnectionState get pairingState;
  Stream<PairingConnectionState> get pairingStates;

  Future<List<KitchenTicket>> dismiss(String ticketId);
  Future<void> markFinished(List<String> ticketIds);
  Future<void> archiveCancelled(List<String> ticketIds);

  /// Returns local Finished receipts to the dashboard.
  ///
  /// [markRetrieved] is true only when the user explicitly retrieves a
  /// receipt from Order History. Undoing Finished from the dashboard must not
  /// show the retrieved indicator.
  Future<void> restoreFinished(
    List<String> ticketIds, {
    required bool markRetrieved,
  });
  Future<List<KitchenTicket>> historyForDay(DateTime day);
  Future<List<KitchenTicket>> start(DisplaySession session);
  Future<List<KdsOrderType>> orderTypes();
  Future<void> updateOrderTypeIcon(String id, String icon);
  Future<void> deleteOrderType(String id);
}

class StoredKitchenRepository implements KitchenRepository {
  StoredKitchenRepository({
    required PosConnection connection,
    required PairingRepository pairingRepository,
    required DeviceIdentityRepository deviceIdentityRepository,
    required TicketStore store,
  }) : _connection = connection,
       _pairingRepository = pairingRepository,
       _deviceIdentityRepository = deviceIdentityRepository,
       _store = store;

  final PosConnection _connection;
  final PairingRepository _pairingRepository;
  final DeviceIdentityRepository _deviceIdentityRepository;
  final TicketStore _store;
  final _changes = StreamController<void>.broadcast();
  StreamSubscription<Map<String, dynamic>>? _orders;
  StreamSubscription<PairingConnectionState>? _pairingStates;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  PairingConnectionState get pairingState => _pairingRepository.state;

  @override
  Stream<PairingConnectionState> get pairingStates => _pairingRepository.states;

  @override
  Future<List<KitchenTicket>> start(DisplaySession session) async {
    _orders ??= _connection.messages
        .where((message) => message['type'] == 'kitchen_order')
        .listen((message) => unawaited(_receive(message)));
    _pairingStates ??= _pairingRepository.states.listen(
      (_) => _changes.add(null),
    );
    await _pairingRepository.resume(
      session: session,
      installationId: await _deviceIdentityRepository.getOrCreate(),
    );
    return _store.activeTickets();
  }

  @override
  Future<List<KitchenTicket>> dismiss(String ticketId) async {
    await _store.dismiss(ticketId);
    final tickets = await _store.activeTickets();
    _changes.add(null);
    return tickets;
  }

  @override
  Future<void> markFinished(List<String> ticketIds) =>
      _store.markFinished(ticketIds);

  @override
  Future<void> archiveCancelled(List<String> ticketIds) async {
    await _store.archiveCancelled(ticketIds);
    _changes.add(null);
  }

  @override
  Future<void> restoreFinished(
    List<String> ticketIds, {
    required bool markRetrieved,
  }) => _store.restoreFinished(ticketIds, markRetrieved: markRetrieved);

  @override
  Future<List<KitchenTicket>> historyForDay(DateTime day) =>
      _store.historyTicketsForDay(day);

  @override
  Future<List<KdsOrderType>> orderTypes() => _store.orderTypes();

  @override
  Future<void> updateOrderTypeIcon(String id, String icon) =>
      _store.updateOrderTypeIcon(id, icon);

  @override
  Future<void> deleteOrderType(String id) => _store.deleteOrderType(id);

  Future<void> _receive(Map<String, dynamic> message) async {
    if (!_pairingRepository.isPaired ||
        message['protocol'] != 'kitchen-order.v1') {
      return;
    }
    try {
      final ticket = KitchenTicket.fromJson(message);
      await _store.receive(ticket);
      _connection.send({
        'type': 'kitchen_order.received',
        'message_id': ticket.messageId,
        'received_at': DateTime.now().toUtc().toIso8601String(),
      });
      _changes.add(null);
    } on Object {
      // Failed or malformed orders are never acknowledged.
    }
  }
}
