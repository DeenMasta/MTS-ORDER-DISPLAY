import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/display_settings_repository.dart';
import '../../../../data/repositories/kitchen_repository.dart';
import '../../../../data/services/kitchen_alert_player.dart';
import '../../../../domain/models/display_session.dart';
import '../../../../domain/models/kds_settings.dart';
import '../../../../domain/models/kitchen_ticket.dart';
import '../../../../domain/models/pairing.dart';

class KitchenBoardViewModel extends ChangeNotifier {
  KitchenBoardViewModel({
    required KitchenRepository repository,
    required DisplaySettingsRepository settingsRepository,
    KitchenAlertPlayer? alertPlayer,
  }) : _repository = repository,
       _settingsRepository = settingsRepository,
       _alertPlayer = alertPlayer ?? const SilentKitchenAlertPlayer();

  final KitchenRepository _repository;
  final DisplaySettingsRepository _settingsRepository;
  final KitchenAlertPlayer _alertPlayer;
  StreamSubscription<void>? _changes;
  StreamSubscription<PairingConnectionState>? _pairingStates;
  List<KitchenTicket> _tickets = const [];
  String? _error;
  String? _pairingCode;
  bool _isPaired = false;
  bool _loading = false;
  KitchenOrderFilter _filter = KitchenOrderFilter.all;
  int _page = 0;
  int _receiptsPerPage = 4;
  Timer? _clock;
  List<KdsOrderType> _orderTypes = const [];
  Map<String, String> _orderTypeIcons = const {};
  KdsSettings _settings = const KdsSettings();
  final Set<String> _crossedItemKeys = <String>{};
  final Map<String, DateTime> _completionDeadlines = <String, DateTime>{};
  final Map<String, DateTime> _cancellationDeadlines = <String, DateTime>{};
  final Set<String> _locallyCompletedTicketIds = <String>{};
  final Map<String, KitchenTicket> _finishedHistoryTickets =
      <String, KitchenTicket>{};
  DateTime? _historyDay;
  final Set<String> _urgentTicketIds = <String>{};

  List<KitchenTicket> get tickets => _tickets;
  String? get error => _error;
  bool get isPaired => _isPaired;
  String? get pairingCode => _pairingCode;
  bool get loading => _loading;
  KitchenOrderFilter get filter => _filter;
  int get page => _page;
  int get receiptsPerPage => _receiptsPerPage;
  KdsSettings get settings => _settings;

  /// The menu history contains locally Finished receipts and receipts cancelled
  /// or voided by the POS.
  List<List<KitchenTicket>> get todayHistoryGroups {
    if (!_isSameCalendarDay(_historyDay, DateTime.now())) return const [];
    final groups = groupKitchenTicketsByOrder(_finishedHistoryTickets.values);
    groups.sort((a, b) => b.first.createdAt.compareTo(a.first.createdAt));
    return groups;
  }

  List<KitchenOrderFilter> get availableFilters {
    final filters = <KitchenOrderFilter>[KitchenOrderFilter.all];
    for (final type in _orderTypes) {
      if (!_settings.isOrderTypeVisible(id: type.id, name: type.name)) {
        continue;
      }
      final filter = KitchenOrderFilter.fromOrderType(type);
      if (!filters.any(filter.representsSameOrderType)) filters.add(filter);
    }
    for (final ticket in _tickets) {
      if (!_isOrderTypeVisible(ticket)) continue;
      final filter = KitchenOrderFilter.fromTicket(ticket);
      if (!filters.any(filter.representsSameOrderType)) filters.add(filter);
    }
    return filters;
  }

  List<List<KitchenTicket>> get ticketGroups {
    final visible = _tickets.where(
      (ticket) =>
          _isOrderTypeVisible(ticket) &&
          _filter.matches(ticket) &&
          !_isFinishedLocally(ticket),
    );
    final groups = groupKitchenTicketsByOrder(visible).toList(growable: false);
    groups.sort((a, b) {
      final result = a.first.createdAt.compareTo(b.first.createdAt);
      return _settings.newestFirst ? -result : result;
    });
    return groups;
  }

  int get pageCount => ticketGroups.isEmpty
      ? 1
      : (ticketGroups.length + _receiptsPerPage - 1) ~/ _receiptsPerPage;

  List<List<KitchenTicket>> get visibleTicketGroups {
    final start = _page * _receiptsPerPage;
    return ticketGroups
        .skip(start)
        .take(_receiptsPerPage)
        .toList(growable: false);
  }

  String orderTypeIconNameFor(KitchenTicket ticket) =>
      _orderTypeIcons[ticket.orderTypeId] ??
      (ticket.orderTypeName?.toLowerCase().contains('take') ?? false
          ? 'takeout_dining'
          : 'restaurant');

  /// Crossed items are an in-memory visual checklist only. They are never
  /// sent to the POS. Crossing every item finishes the receipt locally.
  bool isItemCrossed(KitchenTicket ticket, int itemIndex) =>
      _crossedItemKeys.contains(_itemKey(ticket, itemIndex));

  void toggleItemCrossed(KitchenTicket ticket, int itemIndex) {
    if (ticket.isCancelled) return;
    final key = _itemKey(ticket, itemIndex);
    if (!_crossedItemKeys.add(key)) _crossedItemKeys.remove(key);
    final receipt = _receiptFor(ticket);
    if (_areAllItemsCrossed(receipt)) unawaited(completeLocally(receipt));
    notifyListeners();
  }

  /// Marks a receipt as finished only on this display and saves that local
  /// state so completed receipts do not return after a restart.
  Future<void> completeLocally(List<KitchenTicket> tickets) async {
    if (tickets.isEmpty ||
        isCompletedLocally(tickets) ||
        isCancelled(tickets)) {
      return;
    }
    final now = DateTime.now();
    final deadline = now.add(
      Duration(seconds: _settings.finishedReceiptSeconds),
    );
    _historyDay = DateTime(now.year, now.month, now.day);
    for (final ticket in tickets) {
      _completionDeadlines[ticket.id] = deadline;
      _locallyCompletedTicketIds.add(ticket.id);
      _finishedHistoryTickets[ticket.id] = ticket.copyWith(finishedAt: now);
    }
    notifyListeners();
    await _repository.markFinished(tickets.map((ticket) => ticket.id).toList());
  }

  /// Cancels the Finished countdown from the live dashboard.
  ///
  /// This returns the receipt to its regular active state; it was not
  /// retrieved from history and must not show the retrieved indicator.
  Future<void> undoLocalCompletion(List<KitchenTicket> tickets) =>
      _restoreFinished(tickets, markRetrieved: false);

  /// Retrieves a Finished receipt from Order History back to the dashboard.
  ///
  /// This changes only this display's local status; it never contacts POS.
  Future<void> retrieveFromHistory(List<KitchenTicket> tickets) {
    if (isCancelled(tickets)) return Future<void>.value();
    return _restoreFinished(tickets, markRetrieved: true);
  }

  Future<void> _restoreFinished(
    List<KitchenTicket> tickets, {
    required bool markRetrieved,
  }) async {
    final retrievedIds = tickets.map((ticket) => ticket.id).toSet();
    for (final ticket in tickets) {
      _completionDeadlines.remove(ticket.id);
      _locallyCompletedTicketIds.remove(ticket.id);
      _finishedHistoryTickets.remove(ticket.id);
    }
    final activeTicketIds = _tickets.map((ticket) => ticket.id).toSet();
    _tickets = [
      for (final ticket in _tickets)
        retrievedIds.contains(ticket.id)
            ? ticket.copyWith(isRetrieved: markRetrieved || ticket.isRetrieved)
            : ticket,
      for (final ticket in tickets)
        if (activeTicketIds.add(ticket.id))
          ticket.copyWith(isRetrieved: markRetrieved || ticket.isRetrieved),
    ];
    _filter = KitchenOrderFilter.all;
    final restoredPage = ticketGroups.indexWhere(
      (receipt) => receipt.any(
        (ticket) => tickets.any((restored) => restored.id == ticket.id),
      ),
    );
    if (restoredPage >= 0) _page = restoredPage ~/ _receiptsPerPage;
    notifyListeners();
    await _repository.restoreFinished(
      tickets.map((ticket) => ticket.id).toList(),
      markRetrieved: markRetrieved,
    );
  }

  /// Indicates that the receipt was marked Finished on this display.
  /// The order remains available in local order history.
  bool isCompletedLocally(List<KitchenTicket> tickets) =>
      tickets.any((ticket) => _locallyCompletedTicketIds.contains(ticket.id));

  /// Whether this receipt was restored from local order history.
  bool isRetrieved(List<KitchenTicket> tickets) =>
      tickets.any((ticket) => ticket.isRetrieved);

  /// Whether the POS cancelled or voided this receipt.
  bool isCancelled(List<KitchenTicket> tickets) =>
      tickets.any((ticket) => ticket.isCancelled);

  /// Time from the order's first received timestamp until it was finished.
  Duration? completionDurationFor(List<KitchenTicket> tickets) {
    if (tickets.isEmpty) return null;
    DateTime? finishedAt;
    var startedAt = tickets.first.createdAt;
    for (final ticket in tickets) {
      if (ticket.createdAt.isBefore(startedAt)) startedAt = ticket.createdAt;
      final ticketFinishedAt = ticket.finishedAt;
      if (ticketFinishedAt != null &&
          (finishedAt == null || ticketFinishedAt.isAfter(finishedAt))) {
        finishedAt = ticketFinishedAt;
      }
    }
    if (finishedAt == null || finishedAt.isBefore(startedAt)) return null;
    return finishedAt.difference(startedAt);
  }

  int completionSecondsRemaining(List<KitchenTicket> tickets) {
    final deadline = tickets
        .map((ticket) => _completionDeadlines[ticket.id])
        .whereType<DateTime>()
        .fold<DateTime?>(null, (earliest, value) {
          if (earliest == null || value.isBefore(earliest)) return value;
          return earliest;
        });
    if (deadline == null) return 0;
    final milliseconds = deadline.difference(DateTime.now()).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  /// Seconds the POS cancellation notice remains visible on the dashboard.
  int cancellationSecondsRemaining(List<KitchenTicket> tickets) {
    final deadline = tickets
        .map((ticket) => _cancellationDeadlines[ticket.id])
        .whereType<DateTime>()
        .fold<DateTime?>(null, (earliest, value) {
          if (earliest == null || value.isBefore(earliest)) return value;
          return earliest;
        });
    if (deadline == null) return 0;
    final milliseconds = deadline.difference(DateTime.now()).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  Future<void> testNewOrderSound({KdsAlertTone? tone}) =>
      _alertPlayer.play(tone ?? _settings.newOrderTone);

  Future<void> testUrgentOrderSound({KdsAlertTone? tone}) =>
      _alertPlayer.play(tone ?? _settings.urgentOrderTone);

  Future<void> start(DisplaySession session) async {
    _changes ??= _repository.changes.listen(
      (_) => unawaited(_reload(session, notifyForNewOrders: true)),
    );
    _isPaired = _repository.pairingState.isPaired;
    _pairingCode = _repository.pairingState.code;
    _pairingStates ??= _repository.pairingStates.listen((state) {
      _isPaired = state.isPaired;
      _pairingCode = state.code;
      notifyListeners();
    });
    _clock ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _removeExpiredCompletions();
      _removeExpiredCancellations();
      _clearHistoryForNewDay();
      _checkUrgentOrderAlerts();
      notifyListeners();
    });
    _settings = await _settingsRepository.load();
    await _reload(session);
    await loadTodayHistory();
    _checkUrgentOrderAlerts(playSound: false);
    _ensureSelectedFilterIsVisible();
    notifyListeners();
  }

  void selectFilter(KitchenOrderFilter filter) {
    if (!availableFilters.contains(filter)) return;
    if (_filter == filter) return;
    _filter = filter;
    _page = 0;
    notifyListeners();
  }

  /// Updates presentation paging for the available screen width while keeping
  /// the receipt currently in view as close as possible to its old position.
  void setReceiptsPerPage(int value) {
    if (value <= 0 || value == _receiptsPerPage) return;
    final firstVisibleReceipt = _page * _receiptsPerPage;
    _receiptsPerPage = value;
    _page = (firstVisibleReceipt ~/ _receiptsPerPage)
        .clamp(0, pageCount - 1)
        .toInt();
    notifyListeners();
  }

  Future<void> saveSettings(KdsSettings settings) async {
    final hasInvalidSeconds =
        settings.warningSeconds < 0 ||
        settings.warningSeconds >= 60 ||
        settings.urgentSeconds < 0 ||
        settings.urgentSeconds >= 60;
    if (hasInvalidSeconds ||
        settings.warningThresholdSeconds <= 0 ||
        settings.warningThresholdSeconds >= settings.urgentThresholdSeconds ||
        settings.finishedReceiptSeconds < 1 ||
        settings.finishedReceiptSeconds > 300) {
      throw const FormatException(
        'Set valid order timers and a Finished receipt delay from 1 to 300 seconds.',
      );
    }
    await _settingsRepository.save(settings);
    _settings = settings;
    _checkUrgentOrderAlerts(playSound: false);
    _ensureSelectedFilterIsVisible();
    if (_page >= pageCount) _page = pageCount - 1;
    notifyListeners();
  }

  Future<void> loadTodayHistory() async {
    final now = DateTime.now();
    if (!_isSameCalendarDay(_historyDay, now)) {
      _finishedHistoryTickets.clear();
      _historyDay = DateTime(now.year, now.month, now.day);
    }
    try {
      final tickets = await _repository.historyForDay(now);
      for (final ticket in tickets) {
        _finishedHistoryTickets[ticket.id] = ticket;
        if (ticket.isCancelled) {
          _locallyCompletedTicketIds.remove(ticket.id);
        } else {
          _locallyCompletedTicketIds.add(ticket.id);
        }
      }
    } on Object {
      // A history read failure must not prevent live orders from rendering.
    }
    notifyListeners();
  }

  void showNextPage() {
    if (_page >= pageCount - 1) return;
    _page++;
    notifyListeners();
  }

  void showPreviousPage() {
    if (_page == 0) return;
    _page--;
    notifyListeners();
  }

  void showPage(int page) {
    final safePage = page.clamp(0, pageCount - 1);
    if (_page == safePage) return;
    _page = safePage;
    notifyListeners();
  }

  Future<void> dismiss(String ticketId) async {
    _tickets = await _repository.dismiss(ticketId);
    notifyListeners();
  }

  Future<List<KdsOrderType>> orderTypes() async =>
      List.unmodifiable(_orderTypes);

  Future<void> updateOrderTypeIcon(String id, String icon) async {
    await _repository.updateOrderTypeIcon(id, icon);
    _orderTypes = _orderTypes
        .map(
          (type) => type.id == id
              ? KdsOrderType(id: type.id, name: type.name, icon: icon)
              : type,
        )
        .toList(growable: false);
    _orderTypeIcons = {..._orderTypeIcons, id: icon};
    notifyListeners();
  }

  /// Removes an unused type from this KDS and hides matching local receipts.
  /// The POS API and its orders are not changed.
  Future<void> removeOrderType(KdsOrderType type) async {
    final updatedSettings = _settings.withOrderTypeVisibility(
      id: type.id,
      name: type.name,
      visible: false,
    );
    await _settingsRepository.save(updatedSettings);
    await _repository.deleteOrderType(type.id);
    _settings = updatedSettings;
    _orderTypes = _orderTypes
        .where((orderType) => orderType.id != type.id)
        .toList(growable: false);
    _orderTypeIcons = Map.unmodifiable({
      for (final entry in _orderTypeIcons.entries)
        if (entry.key != type.id) entry.key: entry.value,
    });
    _ensureSelectedFilterIsVisible();
    if (_page >= pageCount) _page = pageCount - 1;
    notifyListeners();
  }

  Future<void> _loadOrderTypes() async {
    final types = await _repository.orderTypes();
    _orderTypes = List.unmodifiable(types);
    _orderTypeIcons = {for (final type in types) type.id: type.icon};
  }

  Future<void> _reload(
    DisplaySession session, {
    bool notifyForNewOrders = false,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final previousIds = _tickets.map((ticket) => ticket.id).toSet();
      final updatedTickets = await _repository.start(session);
      _tickets = updatedTickets;
      _prepareCancelledTicketsForDisplay();
      await _loadOrderTypes();
      _discardCrossedItemsForReplacedTickets();
      final hasNewOrders = updatedTickets.any(
        (ticket) => !previousIds.contains(ticket.id),
      );
      final playedNewOrderSound =
          notifyForNewOrders && hasNewOrders && _settings.newOrderAlert;
      if (playedNewOrderSound) {
        unawaited(_playAlert(KdsAlertTone.chime));
      }
      _checkUrgentOrderAlerts(
        playSound: notifyForNewOrders && !playedNewOrderSound,
      );
      if (_page >= pageCount) _page = pageCount - 1;
    } catch (_) {
      _error = 'Unable to connect to the POS.';
    }
    _loading = false;
    notifyListeners();
  }

  void _ensureSelectedFilterIsVisible() {
    if (!availableFilters.contains(_filter)) _filter = KitchenOrderFilter.all;
  }

  bool _isOrderTypeVisible(KitchenTicket ticket) {
    final ticketTypeId = ticket.orderTypeId;
    final ticketTypeName = ticket.orderTypeName;
    if (ticketTypeId != null && ticketTypeId.isNotEmpty) {
      return _settings.isOrderTypeVisible(
        id: ticketTypeId,
        name: ticketTypeName,
      );
    }
    final configuredType = _orderTypes.where(
      (type) => type.name.toLowerCase() == ticketTypeName?.toLowerCase(),
    );
    if (configuredType.isNotEmpty) {
      final type = configuredType.first;
      return _settings.isOrderTypeVisible(id: type.id, name: type.name);
    }
    return _settings.isOrderTypeVisible(id: null, name: ticketTypeName);
  }

  String _itemKey(KitchenTicket ticket, int itemIndex) =>
      '${ticket.id}:${ticket.revision}:$itemIndex';

  void _discardCrossedItemsForReplacedTickets() {
    final activeKeys = <String>{
      for (final ticket in _tickets)
        for (var index = 0; index < ticket.items.length; index++)
          _itemKey(ticket, index),
    };
    _crossedItemKeys.removeWhere((key) => !activeKeys.contains(key));
    final activeTicketIds = _tickets.map((ticket) => ticket.id).toSet();
    _completionDeadlines.removeWhere(
      (ticketId, _) => !activeTicketIds.contains(ticketId),
    );
    _cancellationDeadlines.removeWhere(
      (ticketId, _) => !activeTicketIds.contains(ticketId),
    );
    for (final ticket in _tickets) {
      final finishedTicket = _finishedHistoryTickets[ticket.id];
      if (finishedTicket != null && ticket.revision > finishedTicket.revision) {
        _completionDeadlines.remove(ticket.id);
        _locallyCompletedTicketIds.remove(ticket.id);
        _finishedHistoryTickets.remove(ticket.id);
      }
    }
  }

  void _prepareCancelledTicketsForDisplay() {
    final now = DateTime.now();
    final cancelledTickets = _tickets
        .where((ticket) => ticket.isCancelled)
        .toList(growable: false);
    final cancelledIds = cancelledTickets.map((ticket) => ticket.id).toSet();
    _cancellationDeadlines.removeWhere(
      (ticketId, _) => !cancelledIds.contains(ticketId),
    );

    final expired = <KitchenTicket>[];
    for (final ticket in cancelledTickets) {
      _completionDeadlines.remove(ticket.id);
      _locallyCompletedTicketIds.remove(ticket.id);
      _finishedHistoryTickets.remove(ticket.id);
      final cancelledAt = ticket.cancelledAt ?? now;
      final deadline = cancelledAt.add(
        Duration(seconds: _settings.finishedReceiptSeconds),
      );
      if (deadline.isAfter(now)) {
        _cancellationDeadlines[ticket.id] = deadline;
      } else {
        expired.add(ticket);
      }
    }
    if (expired.isNotEmpty) unawaited(_archiveCancelled(expired));
  }

  bool _isFinishedLocally(KitchenTicket ticket) {
    if (!_locallyCompletedTicketIds.contains(ticket.id)) return false;
    final deadline = _completionDeadlines[ticket.id];
    return deadline == null || !deadline.isAfter(DateTime.now());
  }

  void _removeExpiredCompletions() => _completionDeadlines.removeWhere(
    (_, deadline) => !deadline.isAfter(DateTime.now()),
  );

  void _removeExpiredCancellations() {
    final now = DateTime.now();
    final expiredIds = _cancellationDeadlines.entries
        .where((entry) => !entry.value.isAfter(now))
        .map((entry) => entry.key)
        .toSet();
    if (expiredIds.isEmpty) return;
    _cancellationDeadlines.removeWhere(
      (ticketId, _) => expiredIds.contains(ticketId),
    );
    final expiredTickets = _tickets
        .where((ticket) => expiredIds.contains(ticket.id))
        .toList(growable: false);
    if (expiredTickets.isNotEmpty) {
      unawaited(_archiveCancelled(expiredTickets));
    }
  }

  Future<void> _archiveCancelled(List<KitchenTicket> tickets) async {
    final ids = tickets.map((ticket) => ticket.id).toSet();
    if (ids.isEmpty) return;
    final now = DateTime.now();
    _historyDay = DateTime(now.year, now.month, now.day);
    for (final ticket in tickets) {
      _cancellationDeadlines.remove(ticket.id);
      _completionDeadlines.remove(ticket.id);
      _locallyCompletedTicketIds.remove(ticket.id);
      _finishedHistoryTickets[ticket.id] = ticket.copyWith(
        cancelledAt: ticket.cancelledAt ?? now,
        isCancelled: true,
      );
    }
    _tickets = _tickets
        .where((ticket) => !ids.contains(ticket.id))
        .toList(growable: false);
    if (_page >= pageCount) _page = pageCount - 1;
    notifyListeners();
    try {
      await _repository.archiveCancelled(ids.toList(growable: false));
    } on Object {
      // Keep the cancellation visible and retry on the next countdown tick.
      final retryDeadline = DateTime.now().add(const Duration(seconds: 1));
      _tickets = [..._tickets, ...tickets];
      for (final ticket in tickets) {
        _cancellationDeadlines[ticket.id] = retryDeadline;
        _finishedHistoryTickets.remove(ticket.id);
      }
      notifyListeners();
    }
  }

  /// Sounds once when an active receipt first crosses the urgent threshold.
  /// Existing urgent receipts are marked as seen on app start and settings save
  /// so reconnects and redraws never trigger a burst of alerts.
  void _checkUrgentOrderAlerts({bool playSound = true}) {
    final now = DateTime.now();
    final currentUrgentIds = _tickets
        .where(
          (ticket) =>
              !_isFinishedLocally(ticket) &&
              !ticket.isCancelled &&
              now.difference(ticket.createdAt.toLocal()).inSeconds >=
                  _settings.urgentThresholdSeconds,
        )
        .map((ticket) => ticket.id)
        .toSet();
    final newlyUrgent = currentUrgentIds.difference(_urgentTicketIds);
    _urgentTicketIds
      ..clear()
      ..addAll(currentUrgentIds);
    if (playSound && newlyUrgent.isNotEmpty && _settings.urgentOrderAlert) {
      unawaited(_playAlert(KdsAlertTone.alert));
    }
  }

  Future<void> _playAlert(KdsAlertTone eventTone) async {
    try {
      final template = eventTone == KdsAlertTone.chime
          ? _settings.newOrderTone
          : _settings.urgentOrderTone;
      await _alertPlayer.play(template);
    } on Object {
      // A local audio issue must never prevent POS orders from rendering.
    }
  }

  void _clearHistoryForNewDay() {
    if (_historyDay == null ||
        _isSameCalendarDay(_historyDay, DateTime.now())) {
      return;
    }
    _finishedHistoryTickets.clear();
    _locallyCompletedTicketIds.clear();
    _historyDay = null;
  }

  List<KitchenTicket> _receiptFor(KitchenTicket ticket) {
    for (final group in groupKitchenTicketsByOrder(_tickets)) {
      if (group.any((candidate) => candidate.id == ticket.id)) return group;
    }
    return [ticket];
  }

  bool _areAllItemsCrossed(List<KitchenTicket> tickets) {
    var hasItems = false;
    for (final ticket in tickets) {
      for (var index = 0; index < ticket.items.length; index++) {
        hasItems = true;
        if (!isItemCrossed(ticket, index)) return false;
      }
    }
    return hasItems;
  }

  bool _isSameCalendarDay(DateTime? first, DateTime second) =>
      first != null &&
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  @override
  void dispose() {
    _clock?.cancel();
    _changes?.cancel();
    _pairingStates?.cancel();
    unawaited(_alertPlayer.dispose());
    super.dispose();
  }
}

class KitchenOrderFilter {
  const KitchenOrderFilter._(this.id, this.label);

  static const all = KitchenOrderFilter._('all', 'All');
  static const takeaway = KitchenOrderFilter._('name:takeaway', 'Takeaway');
  static const dineIn = KitchenOrderFilter._('name:dine in', 'Dine in');

  final String id;
  final String label;

  factory KitchenOrderFilter.fromTicket(KitchenTicket ticket) {
    final name = ticket.orderTypeName?.trim();
    final normalizedName = name?.toLowerCase();
    if (normalizedName == 'takeaway') return takeaway;
    if (normalizedName == 'dine in') return dineIn;
    return KitchenOrderFilter._(
      ticket.orderTypeId == null || ticket.orderTypeId!.isEmpty
          ? 'name:${normalizedName ?? 'order'}'
          : 'id:${ticket.orderTypeId}',
      name?.isNotEmpty == true ? name! : 'Order',
    );
  }

  factory KitchenOrderFilter.fromOrderType(KdsOrderType type) =>
      KitchenOrderFilter._('id:${type.id}', type.name);

  bool matches(KitchenTicket ticket) {
    if (this == all) return true;
    final ticketFilter = KitchenOrderFilter.fromTicket(ticket);
    return representsSameOrderType(ticketFilter);
  }

  bool representsSameOrderType(KitchenOrderFilter other) {
    if (this == all || other == all) return this == other;
    return id == other.id || label.toLowerCase() == other.label.toLowerCase();
  }

  @override
  bool operator ==(Object other) =>
      other is KitchenOrderFilter && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
