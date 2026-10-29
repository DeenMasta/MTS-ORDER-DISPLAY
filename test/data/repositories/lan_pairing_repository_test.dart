import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mysztech_order_display/data/repositories/pairing_repository.dart';
import 'package:mysztech_order_display/data/services/pos_connection_service.dart';

void main() {
  test('pairs on port 8080 and stores the Laravel display ID separately', () async {
    final connection = FakePosConnection();
    final repository = LanPairingRepository(connection: connection);

    final pairing = repository.pair(
      posIp: '192.168.1.10',
      displayName: 'Main Kitchen',
      installationId: 'installation-uuid',
    );
    await _settle();

    expect(connection.endpoint.toString(), 'ws://192.168.1.10:8080/kds');
    expect(connection.sent.single['display_id'], 'installation-uuid');
    final firstChallenge = connection.sent.single;
    connection.receive({
      'type': 'pair.confirmed',
      'display_id': 'laravel-display-id',
      'protocol': 'kitchen-order.v1',
    });

    final session = await pairing;
    expect(session.displayId, 'laravel-display-id');
    expect(session.posIp, '192.168.1.10');
    expect(firstChallenge['display_id'], isNot(session.displayId));
  });

  test('a new socket resets pairing and sends a fresh challenge', () async {
    final connection = FakePosConnection();
    final repository = LanPairingRepository(connection: connection);

    final pairing = repository.pair(
      posIp: '192.168.1.10',
      displayName: 'Main Kitchen',
      installationId: 'installation-uuid',
    );
    await _settle();
    final firstChallenge = connection.sent.single;
    connection.receive({
      'type': 'pair.confirmed',
      'display_id': 'laravel-display-id',
      'protocol': 'kitchen-order.v1',
    });
    await pairing;

    connection.closeSocket();
    await _settle();
    expect(repository.isPaired, isFalse);

    connection.openNewSocket();
    await _settle();

    final secondChallenge = connection.sent.last;
    expect(repository.isPaired, isFalse);
    expect(secondChallenge['nonce'], isNot(firstChallenge['nonce']));
    expect(secondChallenge['code'], isNot(firstChallenge['code']));
    expect((secondChallenge['code']! as String).length, inInclusiveRange(4, 32));
  });
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

class FakePosConnection implements PosConnection {
  final _connections = StreamController<void>.broadcast();
  final _disconnections = StreamController<void>.broadcast();
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final sent = <Map<String, dynamic>>[];
  Uri? endpoint;

  @override
  Stream<void> get connections => _connections.stream;

  @override
  Stream<void> get disconnections => _disconnections.stream;

  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  @override
  Future<void> close() async {}

  @override
  Future<void> connect(Uri endpoint) async {
    this.endpoint = endpoint;
    _connections.add(null);
  }

  void openNewSocket() => _connections.add(null);

  void closeSocket() => _disconnections.add(null);

  void receive(Map<String, dynamic> message) => _messages.add(message);

  @override
  void send(Map<String, dynamic> message) => sent.add(message);
}
