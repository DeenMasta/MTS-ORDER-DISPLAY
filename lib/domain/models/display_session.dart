class DisplaySession {
  const DisplaySession({required this.displayId, required this.posEndpoint});

  final String displayId;
  final String posEndpoint;

  factory DisplaySession.fromJson(Map<String, dynamic> json) {
    String value(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Missing display session field: $key');
      }
      return value;
    }

    final endpoint = Uri.tryParse(value('pos_endpoint'));
    if (endpoint == null || !endpoint.hasAuthority || !{'ws', 'wss'}.contains(endpoint.scheme)) {
      throw const FormatException('Invalid POS connection address.');
    }
    return DisplaySession(displayId: value('display_id'), posEndpoint: endpoint.toString());
  }

  Map<String, dynamic> toJson() => {
    'display_id': displayId,
    'pos_endpoint': posEndpoint,
  };
}
