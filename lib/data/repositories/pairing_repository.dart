import 'dart:async';

import '../../domain/models/display_session.dart';
import '../../domain/models/pairing.dart';
import '../services/pos_connection_service.dart';

abstract interface class PairingRepository {
  bool get isPaired;
  PairingConnectionState get state;
  Stream<PairingConnectionState> get states;

  Future<void> cancel();
  Future<DisplaySession> pair({
    required String posIp,
    required String displayName,
    required String installationId,
  });
  Future<void> resume({
    required DisplaySession session,
    required String installationId,
  });
}

class LanPairingRepository implements PairingRepository {
  LanPairingRepository({required PosConnection connection}) : _connection = connection;

  final PosConnection _connection;
  final _states = StreamController<PairingConnectionState>.broadcast();
  StreamSubscription<void>? _connections;
  StreamSubscription<void>? _disconnections;
  StreamSubscription<Map<String, dynamic>>? _messages;
  Completer<DisplaySession>? _pairing;
  String? _displayName;
  String? _installationId;
  String? _posIp;
  PairingConnectionState _state = const PairingConnectionState(isPaired: false);

  @override
  bool get isPaired => _state.isPaired;

  @override
  PairingConnectionState get state => _state;

  @override
  Stream<PairingConnectionState> get states => _states.stream;

  @override
  Future<DisplaySession> pair({
    required String posIp,
    required String displayName,
    required String installationId,
  }) async {
    _configure(
      posIp: posIp,
      displayName: displayName,
      installationId: installationId,
    );
    final pending = _pairing = Completer<DisplaySession>();
    _listen();
    await _connection.connect(_endpoint);
    return pending.future.timeout(const Duration(minutes: 10));
  }

  @override
  Future<void> resume({
    required DisplaySession session,
    required String installationId,
  }) async {
    _configure(
      posIp: session.posIp,
      displayName: session.displayName,
      installationId: installationId,
    );
    _listen();
    if (isPaired) return;
    await _connection.connect(_endpoint);
  }

  @override
  Future<void> cancel() async {
    _pairing = null;
    _setState(const PairingConnectionState(isPaired: false));
    await _connection.close();
  }

  void _listen() {
    _connections ??= _connection.connections.listen((_) => _sendChallenge());
    _disconnections ??= _connection.disconnections.listen(
      (_) => _setState(const PairingConnectionState(isPaired: false)),
    );
    _messages ??= _connection.messages.listen(_receive);
  }

  void _configure({
    required String posIp,
    required String displayName,
    required String installationId,
  }) {
    _posIp = posIp;
    _displayName = displayName;
    _installationId = installationId;
  }

  Uri get _endpoint => Uri(scheme: 'ws', host: _posIp!, port: 8080, path: '/kds');

  void _sendChallenge() {
    final displayName = _displayName;
    final installationId = _installationId;
    if (displayName == null || installationId == null) return;
    final challenge = PairingChallenge.fresh(
      displayId: installationId,
      name: displayName,
    );
    _setState(PairingConnectionState(isPaired: false, code: challenge.code));
    try {
      _connection.send(challenge.toJson());
    } on Object {
      // The socket closed between the connection event and challenge send.
    }
  }

  void _receive(Map<String, dynamic> message) {
    if (message['type'] != 'pair.confirmed' ||
        message['protocol'] != 'kitchen-order.v1') {
      return;
    }
    final displayId = message['display_id'];
    if (displayId is! String || displayId.trim().isEmpty) return;

    _setState(const PairingConnectionState(isPaired: true));
    final pending = _pairing;
    if (pending == null || pending.isCompleted) return;
    pending.complete(
      DisplaySession(
        displayId: displayId,
        posIp: _posIp!,
        displayName: _displayName!,
      ),
    );
  }

  void _setState(PairingConnectionState state) {
    _state = state;
    _states.add(state);
  }
}
