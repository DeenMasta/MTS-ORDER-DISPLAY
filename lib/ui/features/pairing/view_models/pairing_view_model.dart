import 'dart:convert';
import 'dart:math';

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
       _sessionRepository = sessionRepository;

  final PairingRepository _pairingRepository;
  final DeviceIdentityRepository _deviceIdentityRepository;
  final DisplaySessionRepository _sessionRepository;

  String? _code;
  String? _errorMessage;
  int _attempt = 0;
  PairingStatus _status = PairingStatus.idle;

  String? get code => _code;
  String? get errorMessage => _errorMessage;
  PairingStatus get status => _status;

  Future<bool> start({
    required String posAddress,
    required String posPort,
    required String displayName,
  }) async {
    final attempt = ++_attempt;
    var pairingStarted = false;
    try {
      final endpoint = _endpoint(posAddress, posPort);
      final name = displayName.trim();
      if (name.isEmpty || name.length > 120) {
        throw const FormatException('Enter a display name up to 120 characters.');
      }
      _code = _newCode();
      _errorMessage = null;
      _status = PairingStatus.connecting;
      notifyListeners();

      final challenge = PairingChallenge(
        displayId: await _deviceIdentityRepository.getOrCreate(),
        name: name,
        nonce: _newNonce(),
        code: _code!,
      );
      if (!_isCurrent(attempt)) return false;
      _status = PairingStatus.waiting;
      notifyListeners();
      pairingStarted = true;
      final session = await _pairingRepository.pair(
        posEndpoint: endpoint,
        challenge: challenge,
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

  Uri _endpoint(String address, String port) {
    final host = address.trim();
    if (host.isEmpty || host.contains(RegExp(r'\s'))) {
      throw const FormatException('Enter a valid POS LAN address.');
    }
    final parsedPort = int.tryParse(port.trim());
    if (parsedPort == null || parsedPort < 1 || parsedPort > 65535) {
      throw const FormatException('POS port must be between 1 and 65535.');
    }
    return Uri(scheme: 'ws', host: host, port: parsedPort, path: '/kds');
  }

  String _newCode() =>
      Random.secure().nextInt(1000000).toString().padLeft(6, '0');

  String _newNonce() {
    final random = Random.secure();
    return base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
  }
}
