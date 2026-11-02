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

  List<KitchenTicket> get tickets => _tickets;
  String? get error => _error;
  bool get isPaired => _isPaired;
  String? get pairingCode => _pairingCode;
  bool get loading => _loading;
  KitchenOrderFilter get filter => _filter;
  int get page => _page;
  KdsSettings get settings => _settings;

  Iterable<KitchenOrderFilter> get availableFilters =>
      KitchenOrderFilter.values.where(
        (filter) =>
            filter == KitchenOrderFilter.all || _isFilterVisible(filter),
      );

  List<List<KitchenTicket>> get ticketGroups {
    final visible = _tickets.where(
      (ticket) => _isOrderVisible(ticket) && _filter.matches(ticket),
    );
    final groups = groupKitchenTicketsByOrder(visible).toList(growable: false);
    groups.sort((a, b) {
      final result = a.first.createdAt.compareTo(b.first.createdAt);
      return _settings.newestFirst ? -result : result;
    });
    return groups;
  }

  int get pageCount =>
      ticketGroups.isEmpty ? 1 : (ticketGroups.length + 2) ~/ 3;

  List<List<KitchenTicket>> get visibleTicketGroups {
    final start = _page * 3;
    return ticketGroups.skip(start).take(3).toList(growable: false);
  }

  String orderTypeIconNameFor(KitchenTicket ticket) =>
      _orderTypeIcons[ticket.orderTypeId] ??
      (ticket.orderTypeName?.toLowerCase().contains('take') ?? false
          ? 'takeout_dining'
          : 'restaurant');

  Future<void> start(DisplaySession session) async {
    _changes ??= _repository.changes.listen((_) => unawaited(_reload(session)));
    _isPaired = _repository.pairingState.isPaired;
    _pairingCode = _repository.pairingState.code;
    _pairingStates ??= _repository.pairingStates.listen((state) {
      _isPaired = state.isPaired;
      _pairingCode = state.code;
      notifyListeners();
    });
    _clock ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => notifyListeners(),
    );
    await _reload(session);
    await _loadOrderTypeIcons();
    _settings = await _settingsRepository.load();
    _ensureSelectedFilterIsVisible();
    notifyListeners();
  }

  void selectFilter(KitchenOrderFilter filter) {
    if (!_isFilterVisible(filter)) return;
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
      if (_page >= pageCount) _page = pageCount - 1;
    } catch (_) {
      _error = 'Unable to connect to the POS.';
    }
    _loading = false;
    notifyListeners();
  }

  bool _isFilterVisible(KitchenOrderFilter filter) => switch (filter) {
    KitchenOrderFilter.all => true,
    KitchenOrderFilter.takeaway => _settings.showTakeaway,
    KitchenOrderFilter.dineIn => _settings.showDineIn,
  };

  bool _isOrderVisible(KitchenTicket ticket) {
    final type = ticket.orderTypeName?.toLowerCase() ?? '';
    if (type.contains('take')) return _settings.showTakeaway;
    if (type.contains('dine')) return _settings.showDineIn;
    return true;
  }

  void _ensureSelectedFilterIsVisible() {
    if (!_isFilterVisible(_filter)) _filter = KitchenOrderFilter.all;
  }

  @override
  void dispose() {
    _clock?.cancel();
    _changes?.cancel();
    _pairingStates?.cancel();
    super.dispose();
  }
}

enum KitchenOrderFilter {
  all('All'),
  takeaway('Takeaway'),
  dineIn('Dine in');

  const KitchenOrderFilter(this.label);
  final String label;

  bool matches(KitchenTicket ticket) => switch (this) {
    KitchenOrderFilter.all => true,
    KitchenOrderFilter.takeaway =>
      ticket.orderTypeName?.toLowerCase().contains('take') ?? false,
    KitchenOrderFilter.dineIn =>
      ticket.orderTypeName?.toLowerCase().contains('dine') ?? false,
  };
}
