import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

abstract interface class PosConnection {
  Stream<void> get connections;
  Stream<void> get disconnections;
  Stream<Map<String, dynamic>> get messages;

  Future<void> close();
  Future<void> connect(Uri endpoint);
  void send(Map<String, dynamic> message);
}

class PosConnectionService implements PosConnection {
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _connections = StreamController<void>.broadcast();
  final _disconnections = StreamController<void>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Uri? _endpoint;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  @override
  Stream<void> get connections => _connections.stream;

  @override
  Stream<void> get disconnections => _disconnections.stream;

  @override
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  @override
  Future<void> connect(Uri endpoint) async {
    if (_channel != null && _endpoint == endpoint) return;
    _reconnectTimer?.cancel();
    _reconnectAttempt = 0;
    await _closeChannel();
    await _open(endpoint);
  }

  Future<void> _open(Uri endpoint) async {
    final channel = WebSocketChannel.connect(endpoint);
    await channel.ready;
    _channel = channel;
    _endpoint = endpoint;
    _subscription = channel.stream.listen(
      (message) {
        if (message is! String) return;
        try {
          final decoded = jsonDecode(message);
          if (decoded is Map<String, dynamic>) _messages.add(decoded);
        } on FormatException {
          // Ignore malformed messages from the LAN peer.
        }
      },
      onError: _messages.addError,
      onDone: () {
        if (identical(_channel, channel)) {
          _channel = null;
          _endpoint = null;
          _disconnections.add(null);
          _scheduleReconnect(endpoint);
        }
      },
    );
    _connections.add(null);
  }

  void _scheduleReconnect(Uri endpoint) {
    _reconnectTimer?.cancel();
    final exponent = _reconnectAttempt > 5 ? 5 : _reconnectAttempt;
    final seconds = 1 << exponent;
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: seconds), () async {
      try {
        await _open(endpoint);
      } catch (_) {
        _scheduleReconnect(endpoint);
      }
    });
  }

  @override
  void send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) throw StateError('POS connection is not open.');
    channel.sink.add(jsonEncode(message));
  }

  @override
  Future<void> close() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    await _closeChannel();
  }

  Future<void> _closeChannel() async {
    await _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    _channel = null;
    _endpoint = null;
    await channel?.sink.close();
  }
}
