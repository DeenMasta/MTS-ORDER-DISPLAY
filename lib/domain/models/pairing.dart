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

  Map<String, dynamic> toJson() => {
    'type': 'pair.challenge',
    'display_id': displayId,
    'name': name,
    'nonce': nonce,
    'code': code,
    'capabilities': {'app_version': '1.0.0', 'protocol': 'kitchen-order.v1'},
  };
}
