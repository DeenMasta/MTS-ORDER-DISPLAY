import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/kitchen_repository.dart';
import '../../../../domain/models/display_session.dart';
import '../../../../domain/models/kitchen_ticket.dart';

class KitchenBoardViewModel extends ChangeNotifier {
  KitchenBoardViewModel({required KitchenRepository repository})
    : _repository = repository;

  final KitchenRepository _repository;
  StreamSubscription<void>? _changes;
  List<KitchenTicket> _tickets = const [];
  String? _error;
  bool _loading = false;

  List<KitchenTicket> get tickets => _tickets;
  String? get error => _error;
  bool get loading => _loading;

  Future<void> start(DisplaySession session) async {
    _changes ??= _repository.changes.listen((_) => unawaited(_reload(session)));
    await _reload(session);
  }

  Future<void> dismiss(String ticketId) async {
    _tickets = await _repository.dismiss(ticketId);
    notifyListeners();
  }

  Future<void> _reload(DisplaySession session) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _tickets = await _repository.start(session);
    } catch (_) {
      _error = 'Unable to connect to the POS.';
    }
    _loading = false;
    notifyListeners();
  }
}
