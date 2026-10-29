import 'package:flutter/foundation.dart';

import '../../../../data/repositories/display_session_repository.dart';
import '../../../../domain/models/display_session.dart';

enum SessionStatus { loading, unpaired, paired, error }

class SessionViewModel extends ChangeNotifier {
  SessionViewModel({required DisplaySessionRepository sessionRepository})
    : _sessionRepository = sessionRepository;

  final DisplaySessionRepository _sessionRepository;
  SessionStatus _status = SessionStatus.loading;
  DisplaySession? _session;

  DisplaySession? get session => _session;
  SessionStatus get status => _status;

  Future<void> initialize() async {
    _status = SessionStatus.loading;
    notifyListeners();
    try {
      _session = await _sessionRepository.load();
      _status = _session == null ? SessionStatus.unpaired : SessionStatus.paired;
    } catch (_) {
      _session = null;
      _status = SessionStatus.error;
    }
    notifyListeners();
  }
}
