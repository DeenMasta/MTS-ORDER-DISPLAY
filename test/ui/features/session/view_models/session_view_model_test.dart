import 'package:flutter_test/flutter_test.dart';
import 'package:mysztech_order_display/data/repositories/display_session_repository.dart';
import 'package:mysztech_order_display/domain/models/display_session.dart';
import 'package:mysztech_order_display/ui/features/session/view_models/session_view_model.dart';

void main() {
  test('uses a stored POS LAN session', () async {
    final viewModel = SessionViewModel(
      sessionRepository: FakeDisplaySessionRepository(
        session: const DisplaySession(
          displayId: 'display-1',
          posIp: '192.168.1.10',
          displayName: 'Main Kitchen',
        ),
      ),
    );

    await viewModel.initialize();

    expect(viewModel.status, SessionStatus.paired);
    expect(viewModel.session?.displayId, 'display-1');
  });

  test('clears the saved session when changing POS connection', () async {
    final repository = FakeDisplaySessionRepository(
      session: const DisplaySession(
        displayId: 'display-1',
        posIp: '192.168.1.10',
        displayName: 'Main Kitchen',
      ),
    );
    final viewModel = SessionViewModel(sessionRepository: repository);

    await viewModel.initialize();
    await viewModel.changeConnection();

    expect(repository.wasCleared, isTrue);
    expect(viewModel.session, isNull);
    expect(viewModel.status, SessionStatus.unpaired);
  });
}

class FakeDisplaySessionRepository implements DisplaySessionRepository {
  FakeDisplaySessionRepository({this.session});

  DisplaySession? session;
  bool wasCleared = false;

  @override
  Future<void> clear() async {
    wasCleared = true;
    session = null;
  }

  @override
  Future<DisplaySession?> load() async => session;

  @override
  Future<void> save(DisplaySession session) async {}
}
