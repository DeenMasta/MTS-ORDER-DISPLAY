import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysztech_order_display/data/repositories/device_identity_repository.dart';
import 'package:mysztech_order_display/data/repositories/display_settings_repository.dart';
import 'package:mysztech_order_display/data/repositories/display_session_repository.dart';
import 'package:mysztech_order_display/data/repositories/kitchen_repository.dart';
import 'package:mysztech_order_display/data/repositories/pairing_repository.dart';
import 'package:mysztech_order_display/data/services/app_version_service.dart';
import 'package:mysztech_order_display/domain/models/display_session.dart';
import 'package:mysztech_order_display/domain/models/kds_settings.dart';
import 'package:mysztech_order_display/domain/models/kitchen_ticket.dart';
import 'package:mysztech_order_display/domain/models/pairing.dart';
import 'package:mysztech_order_display/ui/core/app_splash.dart';
import 'package:mysztech_order_display/ui/core/app_version_view_model.dart';
import 'package:mysztech_order_display/ui/core/order_display_app.dart';
import 'package:mysztech_order_display/ui/features/kitchen/view_models/kitchen_board_view_model.dart';
import 'package:mysztech_order_display/ui/features/pairing/view_models/pairing_view_model.dart';
import 'package:mysztech_order_display/ui/features/session/view_models/session_view_model.dart';

void main() {
  testWidgets('fits the splash screen on narrow displays', (tester) async {
    await tester.binding.setSurfaceSize(const Size(180, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: AppSplash(
          minimumDuration: Duration(days: 1),
          child: SizedBox.shrink(),
        ),
      ),
    );

    expect(find.text('MYSZTECH'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/kds_order_display_icon_rose.png',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

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
          settingsRepository: EmptySettingsRepository(),
        ),
        appVersionViewModel: AppVersionViewModel(
          appVersionService: FixedAppVersionService(),
        ),
      ),
    );
    await viewModel.initialize();
    await tester.pump(AppSplash.defaultMinimumDuration);
    await tester.pumpAndSettle();

    expect(find.text('Set up your order display'), findsOneWidget);
  });
}

class EmptySettingsRepository implements DisplaySettingsRepository {
  @override
  Future<KdsSettings> load() async => const KdsSettings();

  @override
  Future<void> save(KdsSettings settings) async {}
}

class EmptyKitchenRepository implements KitchenRepository {
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  PairingConnectionState get pairingState =>
      const PairingConnectionState(isPaired: false);

  @override
  Stream<PairingConnectionState> get pairingStates => Stream.empty();

  @override
  Future<List<KitchenTicket>> dismiss(String ticketId) async => [];

  @override
  Future<void> markFinished(List<String> ticketIds) async {}

  @override
  Future<void> restoreFinished(
    List<String> ticketIds, {
    required bool markRetrieved,
  }) async {}

  @override
  Future<List<KitchenTicket>> historyForDay(DateTime day) async => [];

  @override
  Future<List<KdsOrderType>> orderTypes() async => [];

  @override
  Future<List<KitchenTicket>> start(DisplaySession session) async => [];

  @override
  Future<void> updateOrderTypeIcon(String id, String icon) async {}

  @override
  Future<void> deleteOrderType(String id) async {}
}

class EmptyPairingRepository implements PairingRepository {
  @override
  bool get isPaired => false;

  @override
  PairingConnectionState get state =>
      const PairingConnectionState(isPaired: false);

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

class FixedAppVersionService implements AppVersionService {
  @override
  Future<String> get displayVersion async => 'v1.0.0+1';
}

class EmptyDisplaySessionRepository implements DisplaySessionRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<DisplaySession?> load() async => null;

  @override
  Future<void> save(DisplaySession session) async {}
}
