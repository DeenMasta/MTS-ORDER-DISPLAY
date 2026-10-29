import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mysztech_order_display/data/repositories/device_identity_repository.dart';
import 'package:mysztech_order_display/data/repositories/kitchen_repository.dart';
import 'package:mysztech_order_display/data/repositories/pairing_repository.dart';
import 'package:mysztech_order_display/data/services/app_database.dart';
import 'package:mysztech_order_display/data/services/pos_connection_service.dart';
import 'package:mysztech_order_display/data/services/ticket_store.dart';
import 'package:mysztech_order_display/domain/models/display_session.dart';
import 'package:mysztech_order_display/domain/models/kitchen_ticket.dart';
import 'package:mysztech_order_display/domain/models/pairing.dart';

void main() {
  test('does not accept an order before the current socket is paired', () async {
    final pairing = FakePairingRepository(isPaired: false);
    final connection = FakePosConnection();
    final repository = _repository(connection, pairing, FakeTicketStore());
    await repository.start(session);

    connection.receive(order());
    await _settle();

    expect(connection.sent, isEmpty);
  });

  test('acknowledges duplicate messages after each durable write attempt', () async {
    final pairing = FakePairingRepository(isPaired: true);
    final connection = FakePosConnection();
    final store = FakeTicketStore();
    final repository = _repository(connection, pairing, store);
    await repository.start(session);

    connection.receive(order());
    connection.receive(order());
    await _settle();

    expect(store.active, hasLength(1));
    expect(connection.receipts, hasLength(2));
    expect(connection.receipts.every((receipt) => receipt['message_id'] == 'message-1'), isTrue);
  });

  test('keeps a newer revision when an older message arrives later', () async {
    final pairing = FakePairingRepository(isPaired: true);
    final connection = FakePosConnection();
    final store = FakeTicketStore();
    final repository = _repository(connection, pairing, store);
    await repository.start(session);

    connection.receive(order(messageId: 'message-2', revision: 2));
    connection.receive(order(messageId: 'message-1', revision: 1));
    await _settle();

    expect(store.active.single.revision, 2);
    expect(connection.receipts, hasLength(2));
  });

  test('removes a card when a cancellation is stored', () async {
    final pairing = FakePairingRepository(isPaired: true);
    final connection = FakePosConnection();
    final store = FakeTicketStore();
    final repository = _repository(connection, pairing, store);
    await repository.start(session);

    connection.receive(order());
    connection.receive(order(messageId: 'cancel-1', revision: 2, action: 'cancel'));
    await _settle();

    expect(store.active, isEmpty);
    expect(connection.receipts, hasLength(2));
  });

  test('acknowledges only after a successful local write', () async {
    final events = <String>[];
    final pairing = FakePairingRepository(isPaired: true);
    final connection = FakePosConnection(events: events);
    final store = FakeTicketStore(events: events);
    final repository = _repository(connection, pairing, store);
    await repository.start(session);

    connection.receive(order());
    await _settle();
    expect(events, ['write', 'ack']);

    store.failWrites = true;
    connection.receive(order(messageId: 'message-2', revision: 2));
    await _settle();
    expect(connection.receipts, hasLength(1));
  });
}

final session = const DisplaySession(
  displayId: 'laravel-display-id',
  posIp: '192.168.1.10',
  displayName: 'Main Kitchen',
);

StoredKitchenRepository _repository(
  FakePosConnection connection,
  FakePairingRepository pairing,
  FakeTicketStore store,
) => StoredKitchenRepository(
  connection: connection,
  pairingRepository: pairing,
  deviceIdentityRepository: FixedDeviceIdentityRepository(),
  store: store,
);

Map<String, dynamic> order({
  String messageId = 'message-1',
  int revision = 1,
  String action = 'upsert',
}) => {
  'type': 'kitchen_order',
  'protocol': 'kitchen-order.v1',
  'message_id': messageId,
  'sale_id': 'sale-1',
  'department_id': 'department-1',
  'revision': revision,
  'action': action,
  'order_number': 104,
  'created_at': '2026-10-29T10:30:00+08:00',
  'items': [
    {'name': 'Chicken Rice', 'quantity': 2},
  ],
};

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class FixedDeviceIdentityRepository implements DeviceIdentityRepository {
  @override
  Future<String> getOrCreate() async => 'installation-uuid';
}

class FakePairingRepository implements PairingRepository {
  FakePairingRepository({required this.isPaired});

  @override
  bool isPaired;
  final _states = StreamController<PairingConnectionState>.broadcast();

  @override
  PairingConnectionState get state => PairingConnectionState(isPaired: isPaired);

  @override
  Stream<PairingConnectionState> get states => _states.stream;

  @override
  Future<void> cancel() async {}

  @override
  Future<DisplaySession> pair({
    required String posIp,
    required String displayName,
    required String installationId,
  }) => throw UnimplementedError();

  @override
  Future<void> resume({
    required DisplaySession session,
    required String installationId,
  }) async {}
}

class FakePosConnection implements PosConnection {
  FakePosConnection({this.events});

  final List<String>? events;
  final _connections = StreamController<void>.broadcast();
  final _disconnections = StreamController<void>.broadcast();
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final sent = <Map<String, dynamic>>[];

  List<Map<String, dynamic>> get receipts =>
      sent.where((message) => message['type'] == 'kitchen_order.received').toList();

  @override
  Stream<void> get connections => _connections.stream;

  @override
  Stream<void> get disconnections => _disconnections.stream;

  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  @override
  Future<void> close() async {}

  @override
  Future<void> connect(Uri endpoint) async {}

  void receive(Map<String, dynamic> message) => _messages.add(message);

  @override
  void send(Map<String, dynamic> message) {
    events?.add('ack');
    sent.add(message);
  }
}

class FakeTicketStore extends TicketStore {
  FakeTicketStore({this.events})
    : super(openDatabase: () async => throw UnimplementedError());

  final List<String>? events;
  final _processed = <String>{};
  final _cards = <String, KitchenTicket>{};
  bool failWrites = false;

  List<KitchenTicket> get active => _cards.values.toList();

  @override
  Future<List<KitchenTicket>> activeTickets() async => active;

  @override
  Future<void> dismiss(String ticketId) async {
    _cards.remove(ticketId);
  }

  @override
  Future<void> receive(KitchenTicket ticket) async {
    events?.add('write');
    if (failWrites) throw const FormatException('Unable to save order.');
    if (!_processed.add(ticket.messageId)) return;
    final existing = _cards[ticket.id];
    if (existing != null && ticket.revision <= existing.revision) return;
    if (ticket.action == 'cancel') {
      _cards.remove(ticket.id);
      return;
    }
    _cards[ticket.id] = ticket;
  }
}
