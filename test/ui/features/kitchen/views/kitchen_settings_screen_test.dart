import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysztech_order_display/data/repositories/display_settings_repository.dart';
import 'package:mysztech_order_display/data/repositories/kitchen_repository.dart';
import 'package:mysztech_order_display/domain/models/display_session.dart';
import 'package:mysztech_order_display/domain/models/kds_settings.dart';
import 'package:mysztech_order_display/domain/models/kitchen_ticket.dart';
import 'package:mysztech_order_display/domain/models/pairing.dart';
import 'package:mysztech_order_display/ui/features/kitchen/view_models/kitchen_board_view_model.dart';
import 'package:mysztech_order_display/ui/features/kitchen/views/kitchen_settings_screen.dart';

void main() {
  testWidgets('saves a changed alert switch automatically', (tester) async {
    final settingsRepository = _RecordingSettingsRepository();
    final viewModel = KitchenBoardViewModel(
      repository: _EmptyKitchenRepository(),
      settingsRepository: settingsRepository,
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: KitchenSettingsScreen(
          viewModel: viewModel,
          session: _session,
          onChangeConnection: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Changes save automatically to this display.'), findsOne);
    expect(find.text('Save changes'), findsNothing);

    final newOrderAlert = find.widgetWithText(
      SwitchListTile,
      'New-order alert',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: newOrderAlert, matching: find.byType(Switch)),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(settingsRepository.savedSettings, hasLength(1));
    expect(settingsRepository.savedSettings.single.newOrderAlert, isTrue);
  });

  testWidgets('saves valid timer thresholds after typing stops', (
    tester,
  ) async {
    final settingsRepository = _RecordingSettingsRepository();
    final viewModel = KitchenBoardViewModel(
      repository: _EmptyKitchenRepository(),
      settingsRepository: settingsRepository,
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: KitchenSettingsScreen(
          viewModel: viewModel,
          session: _session,
          onChangeConnection: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(3));
    await tester.enterText(find.byType(TextField).first, '07:00');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(settingsRepository.savedSettings, hasLength(1));
    expect(settingsRepository.savedSettings.single.warningMinutes, 7);
    expect(settingsRepository.savedSettings.single.warningSeconds, isZero);
    expect(settingsRepository.savedSettings.single.urgentMinutes, 10);
  });

  testWidgets('saves the Finished receipt delay automatically', (tester) async {
    final settingsRepository = _RecordingSettingsRepository();
    final viewModel = KitchenBoardViewModel(
      repository: _EmptyKitchenRepository(),
      settingsRepository: settingsRepository,
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: KitchenSettingsScreen(
          viewModel: viewModel,
          session: _session,
          onChangeConnection: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(2), '25');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(settingsRepository.savedSettings, hasLength(1));
    expect(settingsRepository.savedSettings.single.finishedReceiptSeconds, 25);
  });

  testWidgets('saves a combined timer and formats seconds with two digits', (
    tester,
  ) async {
    final settingsRepository = _RecordingSettingsRepository();
    final viewModel = KitchenBoardViewModel(
      repository: _EmptyKitchenRepository(),
      settingsRepository: settingsRepository,
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: KitchenSettingsScreen(
          viewModel: viewModel,
          session: _session,
          onChangeConnection: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '5:3');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(settingsRepository.savedSettings, hasLength(1));
    expect(settingsRepository.savedSettings.single.warningMinutes, 5);
    expect(settingsRepository.savedSettings.single.warningSeconds, 3);
    expect(settingsRepository.savedSettings.single.urgentMinutes, 10);
    expect(settingsRepository.savedSettings.single.urgentSeconds, isZero);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '05:03',
    );
  });

  testWidgets('limits timer entry to a two-digit MM:SS value', (tester) async {
    final viewModel = KitchenBoardViewModel(
      repository: _EmptyKitchenRepository(),
      settingsRepository: _RecordingSettingsRepository(),
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: KitchenSettingsScreen(
          viewModel: viewModel,
          session: _session,
          onChangeConnection: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final timerField = find.byType(TextField).first;
    await tester.enterText(timerField, '123:456');

    expect(tester.widget<TextField>(timerField).controller!.text, '05:00');
  });

  testWidgets('inserts the separator after two minute digits', (tester) async {
    final viewModel = KitchenBoardViewModel(
      repository: _EmptyKitchenRepository(),
      settingsRepository: _RecordingSettingsRepository(),
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: KitchenSettingsScreen(
          viewModel: viewModel,
          session: _session,
          onChangeConnection: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final timerField = find.byType(TextField).first;
    await tester.tap(timerField);
    await tester.pump();
    expect(
      tester.widget<TextField>(timerField).controller!.selection,
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
    await tester.enterText(timerField, '1000');

    expect(tester.widget<TextField>(timerField).controller!.text, '10:00');
  });
}

const _session = DisplaySession(
  displayId: 'display',
  posIp: '192.168.1.10',
  displayName: 'Kitchen Display',
);

class _RecordingSettingsRepository implements DisplaySettingsRepository {
  final List<KdsSettings> savedSettings = <KdsSettings>[];

  @override
  Future<KdsSettings> load() async => const KdsSettings();

  @override
  Future<void> save(KdsSettings settings) async => savedSettings.add(settings);
}

class _EmptyKitchenRepository implements KitchenRepository {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  PairingConnectionState get pairingState =>
      const PairingConnectionState(isPaired: true);

  @override
  Stream<PairingConnectionState> get pairingStates =>
      const Stream<PairingConnectionState>.empty();

  @override
  Future<void> deleteOrderType(String id) async {}

  @override
  Future<List<KitchenTicket>> dismiss(String ticketId) async => const [];

  @override
  Future<List<KitchenTicket>> historyForDay(DateTime day) async => const [];

  @override
  Future<void> archiveCancelled(List<String> ticketIds) async {}

  @override
  Future<void> markFinished(List<String> ticketIds) async {}

  @override
  Future<List<KdsOrderType>> orderTypes() async => const [];

  @override
  Future<void> restoreFinished(
    List<String> ticketIds, {
    required bool markRetrieved,
  }) async {}

  @override
  Future<List<KitchenTicket>> start(DisplaySession session) async => const [];

  @override
  Future<void> updateOrderTypeIcon(String id, String icon) async {}
}
