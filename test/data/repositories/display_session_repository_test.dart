import 'package:flutter_test/flutter_test.dart';
import 'package:mysztech_order_display/data/repositories/display_session_repository.dart';
import 'package:mysztech_order_display/data/services/secure_session_storage.dart';

void main() {
  test('clears a malformed stored display session', () async {
    final storage = FakeSessionStorage('{not-json');
    final repository = StoredDisplaySessionRepository(storage: storage);

    final session = await repository.load();

    expect(session, isNull);
    expect(storage.wasCleared, isTrue);
  });
}

class FakeSessionStorage implements SessionStorage {
  FakeSessionStorage(this.value);

  String? value;
  bool wasCleared = false;

  @override
  Future<void> clear() async {
    wasCleared = true;
    value = null;
  }

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}
