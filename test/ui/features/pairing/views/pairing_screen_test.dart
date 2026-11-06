import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysztech_order_display/data/repositories/device_identity_repository.dart';
import 'package:mysztech_order_display/data/repositories/display_session_repository.dart';
import 'package:mysztech_order_display/data/repositories/pairing_repository.dart';
import 'package:mysztech_order_display/domain/models/display_session.dart';
import 'package:mysztech_order_display/domain/models/pairing.dart';
import 'package:mysztech_order_display/ui/core/app_colors.dart';
import 'package:mysztech_order_display/ui/features/pairing/view_models/pairing_view_model.dart';
import 'package:mysztech_order_display/ui/features/pairing/views/pairing_screen.dart';

void main() {
  testWidgets('uses the brand pink for primary pairing actions', (
    tester,
  ) async {
    final viewModel = PairingViewModel(
      pairingRepository: TrackingPairingRepository(),
      deviceIdentityRepository: FixedDeviceIdentityRepository(),
      sessionRepository: MemoryDisplaySessionRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PairingScreen(viewModel: viewModel, onPaired: () async {}),
      ),
    );

    final pairDisplay = find.text('Pair display');
    final buttonTheme = Theme.of(tester.element(pairDisplay)).filledButtonTheme;

    expect(
      buttonTheme.style?.backgroundColor?.resolve(const <WidgetState>{}),
      AppColors.primary,
    );
  });

  testWidgets(
    'does not close the POS connection when the setup screen unmounts',
    (tester) async {
      final pairingRepository = TrackingPairingRepository();
      final viewModel = PairingViewModel(
        pairingRepository: pairingRepository,
        deviceIdentityRepository: FixedDeviceIdentityRepository(),
        sessionRepository: MemoryDisplaySessionRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PairingScreen(viewModel: viewModel, onPaired: () async {}),
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());

      expect(pairingRepository.cancelCalls, 0);
    },
  );

  testWidgets('shows the POS approval step while pairing is pending', (
    tester,
  ) async {
    final pairingRepository = PendingPairingRepository();
    final viewModel = PairingViewModel(
      pairingRepository: pairingRepository,
      deviceIdentityRepository: FixedDeviceIdentityRepository(),
      sessionRepository: MemoryDisplaySessionRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PairingScreen(viewModel: viewModel, onPaired: () async {}),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '192.168.1.10');
    await tester.ensureVisible(find.text('Pair display'));
    await tester.tap(find.text('Pair display'));
    await tester.pump();

    expect(find.text('Confirm pairing'), findsOneWidget);
    expect(find.text('Cancel pairing'), findsOneWidget);

    pairingRepository.complete();
    await tester.pump();
  });
}

class TrackingPairingRepository implements PairingRepository {
  final _states = StreamController<PairingConnectionState>.broadcast();
  var cancelCalls = 0;

  @override
  bool get isPaired => false;

  @override
  PairingConnectionState get state =>
      const PairingConnectionState(isPaired: false);

  @override
  Stream<PairingConnectionState> get states => _states.stream;

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }

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

class PendingPairingRepository extends TrackingPairingRepository {
  final _result = Completer<DisplaySession>();

  @override
  Future<DisplaySession> pair({
    required String posIp,
    required String displayName,
    required String installationId,
  }) => _result.future;

  void complete() => _result.complete(
    const DisplaySession(
      displayId: 'display-1',
      posIp: '192.168.1.10',
      displayName: 'Order Display',
    ),
  );
}

class FixedDeviceIdentityRepository implements DeviceIdentityRepository {
  @override
  Future<String> getOrCreate() async => 'installation-uuid';
}

class MemoryDisplaySessionRepository implements DisplaySessionRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<DisplaySession?> load() async => null;

  @override
  Future<void> save(DisplaySession session) async {}
}
