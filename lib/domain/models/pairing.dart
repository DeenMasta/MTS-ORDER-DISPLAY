import 'dart:convert';
import 'dart:math';

class PairingChallenge {
  const PairingChallenge({
    required this.displayId,
    required this.name,
    required this.nonce,
    required this.code,
  });

  final String displayId;
  final String name;
  final String nonce;
  final String code;

  factory PairingChallenge.fresh({
    required String displayId,
    required String name,
  }) {
    final random = Random.secure();
    return PairingChallenge(
      displayId: displayId,
      name: name,
      nonce: base64UrlEncode(
        List<int>.generate(32, (_) => random.nextInt(256)),
      ).replaceAll('=', ''),
      code: random.nextInt(1000000).toString().padLeft(6, '0'),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': 'pair.challenge',
    'display_id': displayId,
    'name': name,
    'nonce': nonce,
    'code': code,
    'capabilities': {'app_version': '1.0.0', 'protocol': 'kitchen-order.v1'},
  };
}

class PairingConnectionState {
  const PairingConnectionState({required this.isPaired, this.code});

  final bool isPaired;
  final String? code;
}
