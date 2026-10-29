import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mysztech_order_display/data/repositories/device_identity_repository.dart';
import 'package:mysztech_order_display/data/repositories/display_session_repository.dart';
import 'package:mysztech_order_display/data/repositories/pairing_repository.dart';
import 'package:mysztech_order_display/domain/models/display_session.dart';
import 'package:mysztech_order_display/domain/models/pairing.dart';
import 'package:mysztech_order_display/ui/features/pairing/view_models/pairing_view_model.dart';

void main() {
  test('stores a session only after POS confirms pairing', () async {
    final sessions = FakeDisplaySessionRepository();
    final viewModel = PairingViewModel(
      pairingRepository: FakePairingRepository(session: session()),
      deviceIdentityRepository: FixedDeviceIdentityRepository(),
      sessionRepository: sessions,
    );

    final paired = await viewModel.start(
      posAddress: '192.168.1.10',
      posPort: '8080',
      displayName: 'Main Kitchen',
    );

    expect(paired, isTrue);
    expect(sessions.saved?.posEndpoint, 'ws://192.168.1.10:8080/kds');
    expect(viewModel.status, PairingStatus.idle);
  });

  test('does not store a session when pairing fails', () async {
    final sessions = FakeDisplaySessionRepository();
    final viewModel = PairingViewModel(
      pairingRepository: FakePairingRepository(error: Exception()),
      deviceIdentityRepository: FixedDeviceIdentityRepository(),
      sessionRepository: sessions,
    );

    final paired = await viewModel.start(
      posAddress: '192.168.1.10',
      posPort: '8080',
      displayName: 'Main Kitchen',
    );

    expect(paired, isFalse);
    expect(sessions.saved, isNull);
    expect(viewModel.errorMessage, isNotNull);
  });

  test('cancelling a pairing ignores a later connection failure', () async {
    final repository = PendingPairingRepository();
    final viewModel = PairingViewModel(
      pairingRepository: repository,
      deviceIdentityRepository: FixedDeviceIdentityRepository(),
      sessionRepository: FakeDisplaySessionRepository(),
    );

    final pairing = viewModel.start(
      posAddress: '192.168.1.10',
      posPort: '8080',
      displayName: 'Main Kitchen',
    );
    await repository.started.future;
    await viewModel.cancel();
    repository.result.completeError(Exception());

    expect(await pairing, isFalse);
    expect(repository.wasCancelled, isTrue);
    expect(viewModel.status, PairingStatus.idle);
    expect(viewModel.errorMessage, isNull);
  });
}

class FakePairingRepository implements PairingRepository {
  FakePairingRepository({this.session, this.error});

  final DisplaySession? session;
  final Object? error;

  @override
  Future<void> cancel() async {}

  @override
  Future<DisplaySession> pair({
    required Uri posEndpoint,
    required PairingChallenge challenge,
  }) async {
    if (error != null) throw error!;
    return session!;
  }
}

class FixedDeviceIdentityRepository implements DeviceIdentityRepository {
  @override
  Future<String> getOrCreate() async => 'installation-1';
}

class PendingPairingRepository implements PairingRepository {
  final started = Completer<void>();
  final result = Completer<DisplaySession>();
  bool wasCancelled = false;

  @override
  Future<void> cancel() async {
    wasCancelled = true;
  }

  @override
  Future<DisplaySession> pair({
    required Uri posEndpoint,
    required PairingChallenge challenge,
  }) {
    started.complete();
    return result.future;
  }
}

class FakeDisplaySessionRepository implements DisplaySessionRepository {
  DisplaySession? saved;

  @override
  Future<void> clear() async {
    saved = null;
  }

  @override
  Future<DisplaySession?> load() async => saved;

  @override
  Future<void> save(DisplaySession session) async {
    saved = session;
  }
}

DisplaySession session() => const DisplaySession(
  displayId: 'display-1',
  posEndpoint: 'ws://192.168.1.10:8080/kds',
);
