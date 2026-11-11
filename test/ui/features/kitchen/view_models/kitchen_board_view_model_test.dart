import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mysztech_order_display/data/repositories/kitchen_repository.dart';
import 'package:mysztech_order_display/data/repositories/display_settings_repository.dart';
import 'package:mysztech_order_display/data/services/kitchen_alert_player.dart';
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
      _ticket('5', 'Dine In'),
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

  test('updates the number of receipts per page for compact layouts', () async {
    final viewModel = KitchenBoardViewModel(
      repository: _FakeKitchenRepository([
        _ticket('1', 'Dine In'),
        _ticket('2', 'Dine In'),
        _ticket('3', 'Dine In'),
        _ticket('4', 'Dine In'),
        _ticket('5', 'Dine In'),
      ]),
      settingsRepository: _FakeSettingsRepository(),
    );
    addTearDown(viewModel.dispose);

    await viewModel.start(_session);
    expect(viewModel.pageCount, 2);
    viewModel.setReceiptsPerPage(1);

    expect(viewModel.pageCount, 5);
    expect(viewModel.visibleTicketGroups, hasLength(1));
    expect(viewModel.visibleTicketGroups.single.first.orderNumber, '1');
    viewModel.showPage(4);
    expect(viewModel.visibleTicketGroups.single.first.orderNumber, '5');
  });

  test('shows every active order type as a dashboard filter', () async {
    final viewModel = KitchenBoardViewModel(
      repository: _FakeKitchenRepository([
        _ticket('1', 'Dine In'),
        _ticket('2', 'Delivery'),
      ]),
      settingsRepository: _FakeSettingsRepository(),
    );
    addTearDown(viewModel.dispose);

    await viewModel.start(_session);
    final delivery = viewModel.availableFilters.firstWhere(
      (filter) => filter.label == 'Delivery',
    );
    viewModel.selectFilter(delivery);

    expect(viewModel.ticketGroups, hasLength(1));
    expect(viewModel.ticketGroups.single.first.orderNumber, '2');
  });

  test(
    'hides a selected order type from dashboard filters and receipts',
    () async {
      final settingsRepository = _FakeSettingsRepository()
        ..value = KdsSettings.fromJson({
          'order_type_visibility': {'id:grab': false},
        });
      final viewModel = KitchenBoardViewModel(
        repository: _FakeKitchenRepository([
          _ticket('1', 'Dine In'),
          _ticket('2', 'Grab', orderTypeId: 'grab'),
        ]),
        settingsRepository: settingsRepository,
      );
      addTearDown(viewModel.dispose);

      await viewModel.start(_session);

      expect(viewModel.ticketGroups, hasLength(1));
      expect(viewModel.ticketGroups.single.first.orderNumber, '1');
      expect(
        viewModel.availableFilters.map((filter) => filter.label),
        containsAll(<String>['All', 'Dine in']),
      );
      expect(
        viewModel.availableFilters.map((filter) => filter.label),
        isNot(contains('Grab')),
      );
    },
  );

  test(
    'removes an unused type locally without changing the POS tickets',
    () async {
      final settingsRepository = _FakeSettingsRepository();
      const grab = KdsOrderType(
        id: 'grab',
        name: 'Grab',
        icon: 'delivery_dining',
      );
      final viewModel = KitchenBoardViewModel(
        repository: _FakeKitchenRepository(
          [_ticket('1', 'Grab', orderTypeId: 'grab')],
          configuredOrderTypes: const [grab],
        ),
        settingsRepository: settingsRepository,
      );
      addTearDown(viewModel.dispose);

      await viewModel.start(_session);
      await viewModel.removeOrderType(grab);

      expect(await viewModel.orderTypes(), isEmpty);
      expect(viewModel.ticketGroups, isEmpty);
      expect(
        settingsRepository.value.isOrderTypeVisible(id: 'grab', name: 'Grab'),
        isFalse,
      );
    },
  );

  test(
    'shows configured order types as dashboard filters without orders',
    () async {
      final viewModel = KitchenBoardViewModel(
        repository: _FakeKitchenRepository(
          const [],
          configuredOrderTypes: const [
            KdsOrderType(id: 'grab', name: 'Grab', icon: 'delivery_dining'),
            KdsOrderType(id: 'retail', name: 'Retail', icon: 'store'),
          ],
        ),
        settingsRepository: _FakeSettingsRepository(),
      );
      addTearDown(viewModel.dispose);

      await viewModel.start(_session);

      expect(
        viewModel.availableFilters.map((filter) => filter.label),
        containsAll(<String>['All', 'Grab', 'Retail']),
      );
    },
  );

  test(
    'matches a configured filter when an incoming ticket has no type ID',
    () async {
      final viewModel = KitchenBoardViewModel(
        repository: _FakeKitchenRepository(
          [_ticket('1', 'Grab')],
          configuredOrderTypes: const [
            KdsOrderType(id: 'grab', name: 'Grab', icon: 'delivery_dining'),
          ],
        ),
        settingsRepository: _FakeSettingsRepository(),
      );
      addTearDown(viewModel.dispose);

      await viewModel.start(_session);
      viewModel.selectFilter(
        viewModel.availableFilters.firstWhere(
          (filter) => filter.label == 'Grab',
        ),
      );

      expect(viewModel.ticketGroups, hasLength(1));
      expect(viewModel.ticketGroups.single.first.orderNumber, '1');
    },
  );

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

  test('accepts timer thresholds that include seconds', () async {
    final settingsRepository = _FakeSettingsRepository();
    final viewModel = KitchenBoardViewModel(
      repository: _FakeKitchenRepository([]),
      settingsRepository: settingsRepository,
    );
    addTearDown(viewModel.dispose);

    await viewModel.saveSettings(
      const KdsSettings(
        warningMinutes: 0,
        warningSeconds: 30,
        urgentMinutes: 1,
        urgentSeconds: 15,
      ),
    );

    expect(settingsRepository.value.warningThresholdSeconds, 30);
    expect(settingsRepository.value.urgentThresholdSeconds, 75);
  });

  test('uses the configured Finished receipt delay', () async {
    final settingsRepository = _FakeSettingsRepository()
      ..value = const KdsSettings(finishedReceiptSeconds: 25);
    final ticket = _ticket('1', 'Dine In');
    final viewModel = KitchenBoardViewModel(
      repository: _FakeKitchenRepository([ticket]),
      settingsRepository: settingsRepository,
    );
    addTearDown(viewModel.dispose);

    await viewModel.start(_session);
    await viewModel.completeLocally([ticket]);

    expect(
      viewModel.completionSecondsRemaining([ticket]),
      inInclusiveRange(24, 25),
    );
  });

  test('calculates the completion duration recorded for a receipt', () {
    final startedAt = DateTime(2026, 11, 9, 10);
    final ticket = _ticket('1', 'Dine In').copyWith(
      finishedAt: startedAt.add(const Duration(minutes: 7, seconds: 12)),
    );
    final viewModel = KitchenBoardViewModel(
      repository: _FakeKitchenRepository(const []),
      settingsRepository: _FakeSettingsRepository(),
    );
    addTearDown(viewModel.dispose);

    expect(
      viewModel.completionDurationFor([
        KitchenTicket(
          messageId: ticket.messageId,
          saleId: ticket.saleId,
          departmentId: ticket.departmentId,
          revision: ticket.revision,
          action: ticket.action,
          orderNumber: ticket.orderNumber,
          createdAt: startedAt,
          items: ticket.items,
          finishedAt: ticket.finishedAt,
        ),
      ]),
      const Duration(minutes: 7, seconds: 12),
    );
  });

  test(
    'plays the selected new-order template once for a received order',
    () async {
      final repository = _FakeKitchenRepository([_ticket('1', 'Dine In')]);
      final alertPlayer = _RecordingKitchenAlertPlayer();
      final settingsRepository = _FakeSettingsRepository()
        ..value = const KdsSettings(
          newOrderAlert: true,
          newOrderTone: KdsAlertTone.alert,
        );
      final viewModel = KitchenBoardViewModel(
        repository: repository,
        settingsRepository: settingsRepository,
        alertPlayer: alertPlayer,
      );
      addTearDown(viewModel.dispose);

      await viewModel.start(_session);
      expect(alertPlayer.tones, isEmpty);

      repository.addTicket(_ticket('2', 'Takeaway'));
      repository.notifyChanged();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(alertPlayer.tones, [KdsAlertTone.alert]);

      repository.notifyChanged();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(alertPlayer.tones, [KdsAlertTone.alert]);
    },
  );

  test(
    'provides distinct built-in sounds for the two Settings test buttons',
    () async {
      final alertPlayer = _RecordingKitchenAlertPlayer();
      final viewModel = KitchenBoardViewModel(
        repository: _FakeKitchenRepository([]),
        settingsRepository: _FakeSettingsRepository(),
        alertPlayer: alertPlayer,
      );
      addTearDown(viewModel.dispose);

      await viewModel.testNewOrderSound();
      await viewModel.testUrgentOrderSound();

      expect(alertPlayer.tones, [KdsAlertTone.chime, KdsAlertTone.alert]);
    },
  );

  test('previews the selected template when testing an alert', () async {
    final alertPlayer = _RecordingKitchenAlertPlayer();
    final viewModel = KitchenBoardViewModel(
      repository: _FakeKitchenRepository([]),
      settingsRepository: _FakeSettingsRepository(),
      alertPlayer: alertPlayer,
    );
    addTearDown(viewModel.dispose);

    await viewModel.testNewOrderSound(tone: KdsAlertTone.bell);

    expect(alertPlayer.tones, [KdsAlertTone.bell]);
  });

  test('finishes a receipt when its last item is crossed', () async {
    final ticket = KitchenTicket(
      messageId: 'message-1',
      saleId: 'sale-1',
      departmentId: 'kitchen',
      revision: 1,
      action: 'upsert',
      orderNumber: '1',
      createdAt: DateTime(2026),
      items: const [KitchenTicketItem(name: 'Nasi goreng', quantity: 1)],
    );
    final repository = _FakeKitchenRepository([ticket]);
    final viewModel = KitchenBoardViewModel(
      repository: repository,
      settingsRepository: _FakeSettingsRepository(),
    );
    addTearDown(viewModel.dispose);

    viewModel.toggleItemCrossed(ticket, 0);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.isItemCrossed(ticket, 0), isTrue);
    expect(viewModel.isCompletedLocally([ticket]), isTrue);
    expect(
      viewModel.completionSecondsRemaining([ticket]),
      inInclusiveRange(1, 10),
    );
    expect(repository.finishCalls, 1);
    expect(repository.dismissCalls, isZero);
  });

  test(
    'returns a dashboard Finished receipt without marking it retrieved',
    () async {
      final ticket = _ticket('1', 'Dine In');
      final repository = _FakeKitchenRepository([ticket]);
      final viewModel = KitchenBoardViewModel(
        repository: repository,
        settingsRepository: _FakeSettingsRepository(),
      );
      addTearDown(viewModel.dispose);

      await viewModel.start(_session);
      await viewModel.completeLocally([ticket]);

      expect(
        viewModel.completionSecondsRemaining([ticket]),
        inInclusiveRange(1, 10),
      );
      expect(viewModel.isCompletedLocally([ticket]), isTrue);
      expect(viewModel.ticketGroups, hasLength(1));
      expect(viewModel.todayHistoryGroups, hasLength(1));
      expect(viewModel.todayHistoryGroups.single.first.orderNumber, '1');
      expect(repository.finishCalls, 1);

      await viewModel.undoLocalCompletion([ticket]);

      expect(viewModel.completionSecondsRemaining([ticket]), isZero);
      expect(viewModel.isCompletedLocally([ticket]), isFalse);
      expect(viewModel.todayHistoryGroups, isEmpty);
      expect(viewModel.ticketGroups, hasLength(1));
      expect(viewModel.ticketGroups.single.first.orderNumber, '1');
      expect(viewModel.isRetrieved(viewModel.ticketGroups.single), isFalse);
      expect(repository.restoreCalls, 1);
      expect(repository.restoreIndicators, [false]);
    },
  );

  test(
    'does not return a finished receipt after the display restarts',
    () async {
      final ticket = _ticket('1', 'Dine In');
      final repository = _FakeKitchenRepository([ticket]);
      final firstDisplay = KitchenBoardViewModel(
        repository: repository,
        settingsRepository: _FakeSettingsRepository(),
      );

      await firstDisplay.start(_session);
      await firstDisplay.completeLocally([ticket]);
      firstDisplay.dispose();

      final restartedDisplay = KitchenBoardViewModel(
        repository: repository,
        settingsRepository: _FakeSettingsRepository(),
      );
      addTearDown(restartedDisplay.dispose);
      await restartedDisplay.start(_session);

      expect(restartedDisplay.ticketGroups, isEmpty);
      expect(restartedDisplay.todayHistoryGroups, hasLength(1));
      expect(restartedDisplay.todayHistoryGroups.single.first.orderNumber, '1');
    },
  );

  test('restores a stored history receipt to the live dashboard', () async {
    final ticket = _ticket('1', 'Dine In');
    final repository = _FakeKitchenRepository([ticket]);
    final firstDisplay = KitchenBoardViewModel(
      repository: repository,
      settingsRepository: _FakeSettingsRepository(),
    );
    await firstDisplay.start(_session);
    await firstDisplay.completeLocally([ticket]);
    firstDisplay.dispose();

    final restartedDisplay = KitchenBoardViewModel(
      repository: repository,
      settingsRepository: _FakeSettingsRepository(),
    );
    addTearDown(restartedDisplay.dispose);
    await restartedDisplay.start(_session);

    final historyReceipt = restartedDisplay.todayHistoryGroups.single;
    await restartedDisplay.retrieveFromHistory(historyReceipt);

    expect(restartedDisplay.todayHistoryGroups, isEmpty);
    expect(restartedDisplay.ticketGroups, hasLength(1));
    expect(restartedDisplay.ticketGroups.single.first.orderNumber, '1');
    expect(
      restartedDisplay.isRetrieved(restartedDisplay.ticketGroups.single),
      isTrue,
    );
    expect(repository.restoreCalls, 1);
    expect(repository.restoreIndicators, [true]);
  });

  test('loads persisted finished receipts into today history', () async {
    final today = _ticket('101', 'Dine In');
    final repository = _FakeKitchenRepository(
      const [],
      finishedHistory: [today],
    );
    final viewModel = KitchenBoardViewModel(
      repository: repository,
      settingsRepository: _FakeSettingsRepository(),
    );
    addTearDown(viewModel.dispose);

    await viewModel.loadTodayHistory();

    expect(repository.historyCalls, 1);
    expect(viewModel.todayHistoryGroups, hasLength(1));
  });

  test('archives a POS-cancelled receipt as Cancelled history', () async {
    final cancelled = _ticket('201', 'Dine In').copyWith(
      cancelledAt: DateTime.now().subtract(const Duration(seconds: 2)),
      isCancelled: true,
    );
    final repository = _FakeKitchenRepository([cancelled]);
    final viewModel = KitchenBoardViewModel(
      repository: repository,
      settingsRepository: _FakeSettingsRepository()
        ..value = const KdsSettings(finishedReceiptSeconds: 1),
    );
    addTearDown(viewModel.dispose);

    await viewModel.start(_session);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.ticketGroups, isEmpty);
    expect(viewModel.todayHistoryGroups, hasLength(1));
    expect(viewModel.isCancelled(viewModel.todayHistoryGroups.single), isTrue);
    expect(
      viewModel.isCompletedLocally(viewModel.todayHistoryGroups.single),
      isFalse,
    );
    expect(repository.archiveCancelledCalls, 1);

    await viewModel.retrieveFromHistory(viewModel.todayHistoryGroups.single);
    expect(viewModel.ticketGroups, isEmpty);
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

KitchenTicket _ticket(String orderNumber, String type, {String? orderTypeId}) =>
    KitchenTicket(
      messageId: 'message-$orderNumber',
      saleId: 'sale-$orderNumber',
      departmentId: 'kitchen',
      revision: 1,
      action: 'upsert',
      orderNumber: orderNumber,
      createdAt: DateTime(2026),
      items: const [],
      orderTypeId: orderTypeId,
      orderTypeName: type,
    );

class _FakeKitchenRepository implements KitchenRepository {
  _FakeKitchenRepository(
    this._tickets, {
    this.finishedHistory = const [],
    List<KdsOrderType> configuredOrderTypes = const [],
  }) : _configuredOrderTypes = List<KdsOrderType>.from(configuredOrderTypes);
  final List<KitchenTicket> _tickets;
  final List<KitchenTicket> finishedHistory;
  final List<KdsOrderType> _configuredOrderTypes;
  final Set<String> _finishedTicketIds = <String>{};
  final List<KitchenTicket> _cancelledHistory = <KitchenTicket>[];
  final _changes = StreamController<void>.broadcast();
  int dismissCalls = 0;
  int finishCalls = 0;
  int archiveCancelledCalls = 0;
  int restoreCalls = 0;
  final List<bool> restoreIndicators = <bool>[];
  int historyCalls = 0;

  void addTicket(KitchenTicket ticket) => _tickets.add(ticket);

  void notifyChanged() => _changes.add(null);

  @override
  Stream<void> get changes => _changes.stream;

  @override
  PairingConnectionState get pairingState =>
      const PairingConnectionState(isPaired: true);

  @override
  Stream<PairingConnectionState> get pairingStates => const Stream.empty();

  @override
  Future<List<KitchenTicket>> dismiss(String ticketId) async {
    dismissCalls++;
    return _tickets
        .where((ticket) => ticket.id != ticketId)
        .toList(growable: false);
  }

  @override
  Future<List<KitchenTicket>> historyForDay(DateTime day) async {
    historyCalls++;
    return <KitchenTicket>{
      ...finishedHistory,
      ..._cancelledHistory,
      ..._tickets.where((ticket) => _finishedTicketIds.contains(ticket.id)),
    }.toList(growable: false);
  }

  @override
  Future<void> archiveCancelled(List<String> ticketIds) async {
    archiveCancelledCalls++;
    final ids = ticketIds.toSet();
    _cancelledHistory.addAll(
      _tickets.where((ticket) => ids.contains(ticket.id)),
    );
    _tickets.removeWhere((ticket) => ids.contains(ticket.id));
  }

  @override
  Future<void> markFinished(List<String> ticketIds) async {
    finishCalls++;
    _finishedTicketIds.addAll(ticketIds);
  }

  @override
  Future<void> restoreFinished(
    List<String> ticketIds, {
    required bool markRetrieved,
  }) async {
    restoreCalls++;
    restoreIndicators.add(markRetrieved);
    _finishedTicketIds.removeAll(ticketIds);
  }

  @override
  Future<List<KdsOrderType>> orderTypes() async => _configuredOrderTypes;

  @override
  Future<List<KitchenTicket>> start(DisplaySession session) async => _tickets
      .where((ticket) => !_finishedTicketIds.contains(ticket.id))
      .toList(growable: false);

  @override
  Future<void> updateOrderTypeIcon(String id, String icon) async {}

  @override
  Future<void> deleteOrderType(String id) async {
    _configuredOrderTypes.removeWhere((type) => type.id == id);
  }
}

class _RecordingKitchenAlertPlayer implements KitchenAlertPlayer {
  final List<KdsAlertTone> tones = <KdsAlertTone>[];

  @override
  Future<void> play(KdsAlertTone tone) async => tones.add(tone);

  @override
  Future<void> dispose() async {}
}
