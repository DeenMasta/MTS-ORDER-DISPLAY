import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mysztech_order_display/data/repositories/device_identity_repository.dart';
import 'package:mysztech_order_display/data/repositories/display_session_repository.dart';
import 'package:mysztech_order_display/data/repositories/kitchen_repository.dart';
import 'package:mysztech_order_display/data/repositories/pairing_repository.dart';
import 'package:mysztech_order_display/domain/models/display_session.dart';
import 'package:mysztech_order_display/domain/models/kitchen_ticket.dart';
import 'package:mysztech_order_display/domain/models/pairing.dart';
import 'package:mysztech_order_display/ui/core/order_display_app.dart';
import 'package:mysztech_order_display/ui/features/kitchen/view_models/kitchen_board_view_model.dart';
import 'package:mysztech_order_display/ui/features/pairing/view_models/pairing_view_model.dart';
import 'package:mysztech_order_display/ui/features/session/view_models/session_view_model.dart';

void main() {
  testWidgets('shows setup when no display session exists', (tester) async {
    final viewModel = SessionViewModel(
      sessionRepository: EmptyDisplaySessionRepository(),
    );

    await tester.pumpWidget(
      OrderDisplayApp(
        sessionViewModel: viewModel,
        pairingViewModel: PairingViewModel(
          pairingRepository: EmptyPairingRepository(),
          deviceIdentityRepository: FixedDeviceIdentityRepository(),
          sessionRepository: EmptyDisplaySessionRepository(),
        ),
        kitchenBoardViewModel: KitchenBoardViewModel(
          repository: EmptyKitchenRepository(),
        ),
      ),
    );
    await viewModel.initialize();
    await tester.pump();

    expect(find.text('Pair kitchen display'), findsOneWidget);
  });
}

class EmptyKitchenRepository implements KitchenRepository {
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  PairingConnectionState get pairingState => const PairingConnectionState(isPaired: false);

  @override
  Stream<PairingConnectionState> get pairingStates => Stream.empty();

  @override
  Future<List<KitchenTicket>> dismiss(String ticketId) async => [];

  @override
  Future<List<KdsOrderType>> orderTypes() async => [];

  @override
  Future<List<KitchenTicket>> start(DisplaySession session) async => [];

  @override
  Future<void> updateOrderTypeIcon(String id, String icon) async {}
}

class EmptyPairingRepository implements PairingRepository {
  @override
  bool get isPaired => false;

  @override
  PairingConnectionState get state => const PairingConnectionState(isPaired: false);

  @override
  Stream<PairingConnectionState> get states => Stream.empty();

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

class FixedDeviceIdentityRepository implements DeviceIdentityRepository {
  @override
  Future<String> getOrCreate() async => 'installation-1';
}

class EmptyDisplaySessionRepository implements DisplaySessionRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<DisplaySession?> load() async => null;

  @override
  Future<void> save(DisplaySession session) async {}
}
