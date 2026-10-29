class DisplaySession {
  const DisplaySession({
    required this.displayId,
    required this.posIp,
    required this.displayName,
  });

  final String displayId;
  final String posIp;
  final String displayName;

  factory DisplaySession.fromJson(Map<String, dynamic> json) {
    String value(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Missing display session field: $key');
      }
      return value;
    }

    final posIp = json['pos_ip'] ?? _legacyPosIp(json['pos_endpoint']);
    if (posIp is! String || posIp.trim().isEmpty || posIp.contains(RegExp(r'\s'))) {
      throw const FormatException('Invalid POS LAN address.');
    }
    final storedDisplayName = json['display_name'];
    final displayName = storedDisplayName is String && storedDisplayName.trim().isNotEmpty
        ? storedDisplayName.trim()
        : 'Kitchen Display';
    return DisplaySession(
      displayId: value('display_id'),
      posIp: posIp.trim(),
      displayName: displayName,
    );
  }

  Map<String, dynamic> toJson() => {
    'display_id': displayId,
    'pos_ip': posIp,
    'display_name': displayName,
  };

  static String? _legacyPosIp(Object? endpoint) {
    if (endpoint is! String) return null;
    final parsed = Uri.tryParse(endpoint);
    return parsed?.host;
  }
}
