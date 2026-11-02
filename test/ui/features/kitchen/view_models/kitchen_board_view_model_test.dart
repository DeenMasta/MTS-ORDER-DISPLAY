import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mysztech_order_display/data/repositories/kitchen_repository.dart';
import 'package:mysztech_order_display/data/repositories/display_settings_repository.dart';
import 'package:mysztech_order_display/domain/models/display_session.dart';
import 'package:mysztech_order_display/domain/models/kds_settings.dart';
import 'package:mysztech_order_display/domain/models/kitchen_ticket.dart';
import 'package:mysztech_order_display/domain/models/pairing.dart';
import 'package:mysztech_order_display/ui/features/kitchen/view_models/kitchen_board_view_model.dart';

void main() {
  test('filters orders and resets paging when filter changes', () async {
    final repository = _FakeKitchenRepository([
      _ticket('1', 'Dine In'),
      _ticket('2', 'Takeaway'),
      _ticket('3', 'Dine In'),
      _ticket('4', 'Dine In'),
    ]);
    final viewModel = KitchenBoardViewModel(
      repository: repository,
      settingsRepository: _FakeSettingsRepository(),
    );
    addTearDown(viewModel.dispose);

    await viewModel.start(_session);
    viewModel.showNextPage();

    expect(viewModel.page, 1);
    expect(viewModel.visibleTicketGroups, hasLength(1));

    viewModel.selectFilter(KitchenOrderFilter.takeaway);

    expect(viewModel.page, 0);
    expect(viewModel.ticketGroups, hasLength(1));
    expect(viewModel.ticketGroups.single.first.orderNumber, '2');
  });

  test('applies saved type visibility without deleting tickets', () async {
    final repository = _FakeKitchenRepository([
      _ticket('1', 'Dine In'),
      _ticket('2', 'Takeaway'),
    ]);
    final viewModel = KitchenBoardViewModel(
      repository: repository,
      settingsRepository: _FakeSettingsRepository(),
    );
    addTearDown(viewModel.dispose);

    await viewModel.start(_session);
    await viewModel.saveSettings(
      const KdsSettings(showDineIn: false, showTakeaway: true),
    );

    expect(viewModel.tickets, hasLength(2));
    expect(viewModel.ticketGroups, hasLength(1));
    expect(viewModel.ticketGroups.single.first.orderNumber, '2');
  });

  test('rejects invalid timer thresholds', () async {
    final viewModel = KitchenBoardViewModel(
      repository: _FakeKitchenRepository([]),
      settingsRepository: _FakeSettingsRepository(),
    );
    addTearDown(viewModel.dispose);

    await expectLater(
      viewModel.saveSettings(
        const KdsSettings(warningMinutes: 10, urgentMinutes: 5),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

class _FakeSettingsRepository implements DisplaySettingsRepository {
  KdsSettings value = const KdsSettings();
  @override
  Future<KdsSettings> load() async => value;
  @override
  Future<void> save(KdsSettings settings) async => value = settings;
}

const _session = DisplaySession(
  displayId: 'display',
  posIp: '192.168.1.10',
  displayName: 'Kitchen',
);

KitchenTicket _ticket(String orderNumber, String type) => KitchenTicket(
  messageId: 'message-$orderNumber',
  saleId: 'sale-$orderNumber',
  departmentId: 'kitchen',
  revision: 1,
  action: 'upsert',
  orderNumber: orderNumber,
  createdAt: DateTime(2026),
  items: const [],
  orderTypeName: type,
);

class _FakeKitchenRepository implements KitchenRepository {
  _FakeKitchenRepository(this._tickets);
  final List<KitchenTicket> _tickets;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  PairingConnectionState get pairingState =>
      const PairingConnectionState(isPaired: true);

  @override
  Stream<PairingConnectionState> get pairingStates => const Stream.empty();

  @override
  Future<List<KitchenTicket>> dismiss(String ticketId) async =>
      _tickets.where((ticket) => ticket.id != ticketId).toList(growable: false);

  @override
  Future<List<KdsOrderType>> orderTypes() async => const [];

  @override
  Future<List<KitchenTicket>> start(DisplaySession session) async => _tickets;

  @override
  Future<void> updateOrderTypeIcon(String id, String icon) async {}
}
