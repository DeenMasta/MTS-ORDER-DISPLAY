enum KdsAlertTone {
  chime,
  alert;

  static KdsAlertTone fromStorage(Object? value, KdsAlertTone fallback) =>
      switch (value) {
        'chime' => chime,
        'alert' => alert,
        _ => fallback,
      };
}

extension KdsAlertToneLabel on KdsAlertTone {
  String get label => switch (this) {
    KdsAlertTone.chime => 'Gentle chime',
    KdsAlertTone.alert => 'Attention alert',
  };
}

class KdsSettings {
  const KdsSettings({
    this.warningMinutes = 5,
    this.urgentMinutes = 10,
    this.largeText = false,
    this.compactCards = false,
    this.newestFirst = false,
    this.newOrderAlert = false,
    this.urgentOrderAlert = false,
    this.newOrderTone = KdsAlertTone.chime,
    this.urgentOrderTone = KdsAlertTone.alert,
    this.orderTypeVisibility = const {},
  });

  final int warningMinutes;
  final int urgentMinutes;
  final bool largeText;
  final bool compactCards;
  final bool newestFirst;
  final bool newOrderAlert;
  final bool urgentOrderAlert;
  final KdsAlertTone newOrderTone;
  final KdsAlertTone urgentOrderTone;
  final Map<String, bool> orderTypeVisibility;

  /// Order types are visible by default so newly received POS types appear
  /// without requiring any local configuration.
  bool isOrderTypeVisible({String? id, String? name}) {
    final normalizedId = id?.trim();
    final normalizedName = name?.trim().toLowerCase();
    return (normalizedId == null || normalizedId.isEmpty
            ? null
            : orderTypeVisibility['id:$normalizedId'] ??
                  orderTypeVisibility[normalizedId]) ??
        (normalizedName == null || normalizedName.isEmpty
            ? null
            : orderTypeVisibility['name:$normalizedName']) ??
        true;
  }

  KdsSettings withOrderTypeVisibility({
    required String? id,
    required String? name,
    required bool visible,
  }) {
    final key = _orderTypeKey(id: id, name: name);
    if (key == null) return this;
    return copyWith(
      orderTypeVisibility: {...orderTypeVisibility, key: visible},
    );
  }

  KdsSettings copyWith({
    int? warningMinutes,
    int? urgentMinutes,
    bool? largeText,
    bool? compactCards,
    bool? newestFirst,
    bool? newOrderAlert,
    bool? urgentOrderAlert,
    KdsAlertTone? newOrderTone,
    KdsAlertTone? urgentOrderTone,
    Map<String, bool>? orderTypeVisibility,
  }) => KdsSettings(
    warningMinutes: warningMinutes ?? this.warningMinutes,
    urgentMinutes: urgentMinutes ?? this.urgentMinutes,
    largeText: largeText ?? this.largeText,
    compactCards: compactCards ?? this.compactCards,
    newestFirst: newestFirst ?? this.newestFirst,
    newOrderAlert: newOrderAlert ?? this.newOrderAlert,
    urgentOrderAlert: urgentOrderAlert ?? this.urgentOrderAlert,
    newOrderTone: newOrderTone ?? this.newOrderTone,
    urgentOrderTone: urgentOrderTone ?? this.urgentOrderTone,
    orderTypeVisibility: orderTypeVisibility ?? this.orderTypeVisibility,
  );

  Map<String, Object> toJson() => {
    'warning_minutes': warningMinutes,
    'urgent_minutes': urgentMinutes,
    'large_text': largeText,
    'compact_cards': compactCards,
    'newest_first': newestFirst,
    'new_order_alert': newOrderAlert,
    'urgent_order_alert': urgentOrderAlert,
    'new_order_tone': newOrderTone.name,
    'urgent_order_tone': urgentOrderTone.name,
    'order_type_visibility': orderTypeVisibility,
  };

  factory KdsSettings.fromJson(Map<String, dynamic> json) => KdsSettings(
    warningMinutes: json['warning_minutes'] as int? ?? 5,
    urgentMinutes: json['urgent_minutes'] as int? ?? 10,
    largeText: json['large_text'] as bool? ?? false,
    compactCards: json['compact_cards'] as bool? ?? false,
    newestFirst: json['newest_first'] as bool? ?? false,
    newOrderAlert: json['new_order_alert'] as bool? ?? false,
    urgentOrderAlert: json['urgent_order_alert'] as bool? ?? false,
    newOrderTone: KdsAlertTone.fromStorage(
      json['new_order_tone'],
      KdsAlertTone.chime,
    ),
    urgentOrderTone: KdsAlertTone.fromStorage(
      json['urgent_order_tone'],
      KdsAlertTone.alert,
    ),
    orderTypeVisibility: _visibilityFromJson(json['order_type_visibility']),
  );

  static String? _orderTypeKey({String? id, String? name}) {
    final normalizedId = id?.trim();
    if (normalizedId != null && normalizedId.isNotEmpty) {
      return 'id:$normalizedId';
    }
    final normalizedName = name?.trim().toLowerCase();
    if (normalizedName == null || normalizedName.isEmpty) return null;
    return 'name:$normalizedName';
  }

  static Map<String, bool> _visibilityFromJson(Object? value) {
    if (value is! Map) return const {};
    return Map.unmodifiable({
      for (final entry in value.entries)
        if (entry.key is String && entry.value is bool)
          entry.key as String: entry.value as bool,
    });
  }
}
