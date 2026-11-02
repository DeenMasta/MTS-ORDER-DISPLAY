import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/display_settings_repository.dart';
import '../../../../data/repositories/kitchen_repository.dart';
import '../../../../domain/models/display_session.dart';
import '../../../../domain/models/kds_settings.dart';
import '../../../../domain/models/kitchen_ticket.dart';
import '../../../../domain/models/pairing.dart';

class KitchenBoardViewModel extends ChangeNotifier {
  KitchenBoardViewModel({
    required KitchenRepository repository,
    required DisplaySettingsRepository settingsRepository,
  }) : _repository = repository,
       _settingsRepository = settingsRepository;

  final KitchenRepository _repository;
  final DisplaySettingsRepository _settingsRepository;
  StreamSubscription<void>? _changes;
  StreamSubscription<PairingConnectionState>? _pairingStates;
  List<KitchenTicket> _tickets = const [];
  String? _error;
  String? _pairingCode;
  bool _isPaired = false;
  bool _loading = false;
  KitchenOrderFilter _filter = KitchenOrderFilter.all;
  int _page = 0;
  Timer? _clock;
  Map<String, String> _orderTypeIcons = const {};
  KdsSettings _settings = const KdsSettings();
  final Set<String> _crossedItemKeys = <String>{};
  final Map<String, DateTime> _completionDeadlines = <String, DateTime>{};
  final Set<String> _locallyCompletedTicketIds = <String>{};

  List<KitchenTicket> get tickets => _tickets;
  String? get error => _error;
  bool get isPaired => _isPaired;
  String? get pairingCode => _pairingCode;
  bool get loading => _loading;
  KitchenOrderFilter get filter => _filter;
  int get page => _page;
  KdsSettings get settings => _settings;

  List<KitchenOrderFilter> get availableFilters {
    final filters = <KitchenOrderFilter>[KitchenOrderFilter.all];
    for (final ticket in _tickets.where(_isOrderVisible)) {
      final filter = KitchenOrderFilter.fromTicket(ticket);
      if (!filters.contains(filter)) filters.add(filter);
    }
    return filters;
  }

  List<List<KitchenTicket>> get ticketGroups {
    final visible = _tickets.where(
      (ticket) =>
          _isOrderVisible(ticket) &&
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

  int get pageCount =>
      ticketGroups.isEmpty ? 1 : (ticketGroups.length + 3) ~/ 4;

  List<List<KitchenTicket>> get visibleTicketGroups {
    final start = _page * 4;
    return ticketGroups.skip(start).take(4).toList(growable: false);
  }

  String orderTypeIconNameFor(KitchenTicket ticket) =>
      _orderTypeIcons[ticket.orderTypeId] ??
      (ticket.orderTypeName?.toLowerCase().contains('take') ?? false
          ? 'takeout_dining'
          : 'restaurant');

  /// Crossed items are an in-memory visual checklist only. They are never
  /// stored locally or sent to the POS.
  bool isItemCrossed(KitchenTicket ticket, int itemIndex) =>
      _crossedItemKeys.contains(_itemKey(ticket, itemIndex));

  void toggleItemCrossed(KitchenTicket ticket, int itemIndex) {
    final key = _itemKey(ticket, itemIndex);
    if (!_crossedItemKeys.add(key)) _crossedItemKeys.remove(key);
    notifyListeners();
  }

  /// Marks a receipt as finished only on this display. It is never persisted
  /// or sent to the POS.
  void completeLocally(List<KitchenTicket> tickets) {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    for (final ticket in tickets) {
      _completionDeadlines[ticket.id] = deadline;
      _locallyCompletedTicketIds.add(ticket.id);
    }
    notifyListeners();
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

  Future<void> start(DisplaySession session) async {
    _changes ??= _repository.changes.listen((_) => unawaited(_reload(session)));
    _isPaired = _repository.pairingState.isPaired;
    _pairingCode = _repository.pairingState.code;
    _pairingStates ??= _repository.pairingStates.listen((state) {
      _isPaired = state.isPaired;
      _pairingCode = state.code;
      notifyListeners();
    });
    _clock ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _removeExpiredCompletions();
      notifyListeners();
    });
    await _reload(session);
    await _loadOrderTypeIcons();
    _settings = await _settingsRepository.load();
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

  Future<void> saveSettings(KdsSettings settings) async {
    if (settings.warningMinutes <= 0 ||
        settings.warningMinutes >= settings.urgentMinutes) {
      throw const FormatException(
        'Yellow threshold must be greater than 0 and lower than red threshold.',
      );
    }
    if (!settings.showDineIn && !settings.showTakeaway) {
      throw const FormatException('Keep at least one order type visible.');
    }
    await _settingsRepository.save(settings);
    _settings = settings;
    _ensureSelectedFilterIsVisible();
    if (_page >= pageCount) _page = pageCount - 1;
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

  Future<List<KdsOrderType>> orderTypes() => _repository.orderTypes();

  Future<void> updateOrderTypeIcon(String id, String icon) async {
    await _repository.updateOrderTypeIcon(id, icon);
    _orderTypeIcons = {..._orderTypeIcons, id: icon};
    notifyListeners();
  }

  Future<void> _loadOrderTypeIcons() async {
    final types = await _repository.orderTypes();
    _orderTypeIcons = {for (final type in types) type.id: type.icon};
    notifyListeners();
  }

  Future<void> _reload(DisplaySession session) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _tickets = await _repository.start(session);
      _discardCrossedItemsForReplacedTickets();
      if (_page >= pageCount) _page = pageCount - 1;
    } catch (_) {
      _error = 'Unable to connect to the POS.';
    }
    _loading = false;
    notifyListeners();
  }

  bool _isOrderVisible(KitchenTicket ticket) {
    final type = ticket.orderTypeName?.toLowerCase() ?? '';
    if (type.contains('take')) return _settings.showTakeaway;
    if (type.contains('dine')) return _settings.showDineIn;
    return true;
  }

  void _ensureSelectedFilterIsVisible() {
    if (!availableFilters.contains(_filter)) _filter = KitchenOrderFilter.all;
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
    _locallyCompletedTicketIds.removeWhere(
      (ticketId) => !activeTicketIds.contains(ticketId),
    );
  }

  bool _isFinishedLocally(KitchenTicket ticket) {
    if (!_locallyCompletedTicketIds.contains(ticket.id)) return false;
    final deadline = _completionDeadlines[ticket.id];
    return deadline == null || !deadline.isAfter(DateTime.now());
  }

  void _removeExpiredCompletions() => _completionDeadlines.removeWhere(
    (_, deadline) => !deadline.isAfter(DateTime.now()),
  );

  @override
  void dispose() {
    _clock?.cancel();
    _changes?.cancel();
    _pairingStates?.cancel();
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

  bool matches(KitchenTicket ticket) {
    if (this == all) return true;
    final ticketFilter = KitchenOrderFilter.fromTicket(ticket);
    return id == ticketFilter.id;
  }

  @override
  bool operator ==(Object other) =>
      other is KitchenOrderFilter && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
