import '../../domain/models/display_session.dart';
import '../../domain/models/pairing.dart';
import '../services/pos_connection_service.dart';

abstract interface class PairingRepository {
  Future<DisplaySession> pair({
    required Uri posEndpoint,
    required PairingChallenge challenge,
  });

  Future<void> cancel();
}

class LanPairingRepository implements PairingRepository {
  LanPairingRepository({required PosConnectionService connection})
    : _connection = connection;

  final PosConnectionService _connection;

  @override
  Future<DisplaySession> pair({
    required Uri posEndpoint,
    required PairingChallenge challenge,
  }) async {
    await _connection.connect(posEndpoint);
    final confirmation = _connection.messages.firstWhere(
      (message) => message['type'] == 'pair.confirmed',
    );
    _connection.send(challenge.toJson());
    final response = await confirmation.timeout(const Duration(minutes: 10));
    final displayId = response['display_id'];
    if (response['protocol'] != 'kitchen-order.v1' ||
        displayId is! String ||
        displayId.trim().isEmpty) {
      throw const FormatException('The POS returned an unsupported pairing response.');
    }
    return DisplaySession(
      displayId: displayId,
      posEndpoint: posEndpoint.toString(),
    );
  }

  @override
  Future<void> cancel() => _connection.close();
}
