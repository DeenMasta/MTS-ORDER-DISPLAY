import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class PosConnectionService {
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Uri? _endpoint;
  Timer? _reconnectTimer;

  Stream<Map<String, dynamic>> get messages => _messages.stream;

  Future<void> connect(Uri endpoint) async {
    if (_channel != null && _endpoint == endpoint) return;
    _reconnectTimer?.cancel();
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
          _reconnect(endpoint);
        }
      },
    );
  }

  void _reconnect(Uri endpoint) {
    // shortcut: fixed retry delay; add backoff only if outlet networks need it.
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      try {
        await _open(endpoint);
      } catch (_) {
        _reconnect(endpoint);
      }
    });
  }

  void send(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null) throw StateError('POS connection is not open.');
    channel.sink.add(jsonEncode(message));
  }

  Future<void> close() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
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
