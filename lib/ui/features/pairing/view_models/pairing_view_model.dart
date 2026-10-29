import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/device_identity_repository.dart';
import '../../../../data/repositories/display_session_repository.dart';
import '../../../../data/repositories/pairing_repository.dart';
import '../../../../domain/models/pairing.dart';

enum PairingStatus { idle, connecting, waiting, error }

class PairingViewModel extends ChangeNotifier {
  PairingViewModel({
    required PairingRepository pairingRepository,
    required DeviceIdentityRepository deviceIdentityRepository,
    required DisplaySessionRepository sessionRepository,
  }) : _pairingRepository = pairingRepository,
       _deviceIdentityRepository = deviceIdentityRepository,
       _sessionRepository = sessionRepository {
    _states = _pairingRepository.states.listen(_onPairingState);
  }

  final PairingRepository _pairingRepository;
  final DeviceIdentityRepository _deviceIdentityRepository;
  final DisplaySessionRepository _sessionRepository;

  String? _code;
  String? _errorMessage;
  int _attempt = 0;
  PairingStatus _status = PairingStatus.idle;
  late final StreamSubscription<PairingConnectionState> _states;

  String? get code => _code;
  String? get errorMessage => _errorMessage;
  PairingStatus get status => _status;

  Future<bool> start({
    required String posAddress,
    required String displayName,
  }) async {
    final attempt = ++_attempt;
    var pairingStarted = false;
    try {
      final posIp = _posIp(posAddress);
      final name = displayName.trim();
      if (name.isEmpty || name.length > 120) {
        throw const FormatException('Enter a display name up to 120 characters.');
      }
      _code = null;
      _errorMessage = null;
      _status = PairingStatus.connecting;
      notifyListeners();

      final installationId = await _deviceIdentityRepository.getOrCreate();
      if (!_isCurrent(attempt)) return false;
      _status = PairingStatus.waiting;
      notifyListeners();
      pairingStarted = true;
      final session = await _pairingRepository.pair(
        posIp: posIp,
        displayName: name,
        installationId: installationId,
      );
      if (!_isCurrent(attempt)) return false;
      await _sessionRepository.save(session);
      if (!_isCurrent(attempt)) {
        await _sessionRepository.clear();
        return false;
      }
      _clearTemporaryState();
      notifyListeners();
      return true;
    } on FormatException catch (error) {
      if (!_isCurrent(attempt)) return false;
      if (pairingStarted) await _pairingRepository.cancel();
      if (!_isCurrent(attempt)) return false;
      _fail(error.message);
    } catch (_) {
      if (!_isCurrent(attempt)) return false;
      if (pairingStarted) await _pairingRepository.cancel();
      if (!_isCurrent(attempt)) return false;
      _fail('Unable to complete pairing. Check the POS address and try again.');
    }
    return false;
  }

  Future<void> cancel() async {
    _attempt++;
    await _pairingRepository.cancel();
    _clearTemporaryState();
    notifyListeners();
  }

  bool _isCurrent(int attempt) => _attempt == attempt;

  void _clearTemporaryState() {
    _code = null;
    _errorMessage = null;
    _status = PairingStatus.idle;
  }

  void _fail(String message) {
    _code = null;
    _errorMessage = message;
    _status = PairingStatus.error;
    notifyListeners();
  }

  String _posIp(String address) {
    final host = address.trim();
    if (host.isEmpty || host.contains(RegExp(r'\s'))) {
      throw const FormatException('Enter a valid POS LAN address.');
    }
    return host;
  }

  void _onPairingState(PairingConnectionState state) {
    if (state.code == null) return;
    _code = state.code;
    _status = PairingStatus.waiting;
    notifyListeners();
  }

  @override
  void dispose() {
    _states.cancel();
    super.dispose();
  }
}
