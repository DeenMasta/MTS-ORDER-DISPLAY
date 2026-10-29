import 'dart:convert';

import '../../domain/models/display_session.dart';
import '../services/secure_session_storage.dart';

abstract interface class DisplaySessionRepository {
  Future<void> clear();

  Future<DisplaySession?> load();

  Future<void> save(DisplaySession session);
}

class StoredDisplaySessionRepository implements DisplaySessionRepository {
  StoredDisplaySessionRepository({required SessionStorage storage})
    : _storage = storage;

  final SessionStorage _storage;

  @override
  Future<void> clear() => _storage.clear();

  @override
  Future<DisplaySession?> load() async {
    final encodedSession = await _storage.read();
    if (encodedSession == null) {
      return null;
    }

    try {
      final decodedSession = jsonDecode(encodedSession);
      if (decodedSession is! Map<String, dynamic>) {
        throw const FormatException('Invalid stored display session.');
      }
      return DisplaySession.fromJson(decodedSession);
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> save(DisplaySession session) =>
      _storage.write(jsonEncode(session.toJson()));
}
