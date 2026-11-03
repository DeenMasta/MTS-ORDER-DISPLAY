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
    this.showDineIn = true,
    this.showTakeaway = true,
    this.orderTypeVisibility = const {},
    this.showTypeIcons = true,
    this.warningMinutes = 5,
    this.urgentMinutes = 10,
    this.largeText = false,
    this.compactCards = false,
    this.newestFirst = false,
    this.newOrderAlert = false,
    this.urgentOrderAlert = false,
    this.newOrderTone = KdsAlertTone.chime,
    this.urgentOrderTone = KdsAlertTone.alert,
  });

  final bool showDineIn;
  final bool showTakeaway;

  /// Per-type dashboard visibility, keyed by POS ID and, for older tickets,
  /// a normalized order-type name.
  final Map<String, bool> orderTypeVisibility;
  final bool showTypeIcons;
  final int warningMinutes;
  final int urgentMinutes;
  final bool largeText;
  final bool compactCards;
  final bool newestFirst;
  final bool newOrderAlert;
  final bool urgentOrderAlert;
  final KdsAlertTone newOrderTone;
  final KdsAlertTone urgentOrderTone;

  KdsSettings copyWith({
    bool? showDineIn,
    bool? showTakeaway,
    Map<String, bool>? orderTypeVisibility,
    bool? showTypeIcons,
    int? warningMinutes,
    int? urgentMinutes,
    bool? largeText,
    bool? compactCards,
    bool? newestFirst,
    bool? newOrderAlert,
    bool? urgentOrderAlert,
    KdsAlertTone? newOrderTone,
    KdsAlertTone? urgentOrderTone,
  }) => KdsSettings(
    showDineIn: showDineIn ?? this.showDineIn,
    showTakeaway: showTakeaway ?? this.showTakeaway,
    orderTypeVisibility: orderTypeVisibility ?? this.orderTypeVisibility,
    showTypeIcons: showTypeIcons ?? this.showTypeIcons,
    warningMinutes: warningMinutes ?? this.warningMinutes,
    urgentMinutes: urgentMinutes ?? this.urgentMinutes,
    largeText: largeText ?? this.largeText,
    compactCards: compactCards ?? this.compactCards,
    newestFirst: newestFirst ?? this.newestFirst,
    newOrderAlert: newOrderAlert ?? this.newOrderAlert,
    urgentOrderAlert: urgentOrderAlert ?? this.urgentOrderAlert,
    newOrderTone: newOrderTone ?? this.newOrderTone,
    urgentOrderTone: urgentOrderTone ?? this.urgentOrderTone,
  );

  /// Returns whether this order type should appear on this display.
  ///
  /// Earlier versions saved only Dine In/Takeaway flags. They remain the
  /// fallback until a specific type has been configured.
  bool isOrderTypeVisible({String? id, String? name}) {
    final typeId = id?.trim();
    if (typeId?.isNotEmpty == true) {
      final byId = orderTypeVisibility[typeId];
      if (byId != null) return byId;
    }
    final nameKey = _nameKey(name);
    if (nameKey != null) {
      final byName = orderTypeVisibility[nameKey];
      if (byName != null) return byName;
    }
    final normalizedName = name?.trim().toLowerCase() ?? '';
    if (normalizedName.contains('take')) return showTakeaway;
    if (normalizedName.contains('dine')) return showDineIn;
    return true;
  }

  /// Creates settings with a visibility preference for one POS order type.
  KdsSettings withOrderTypeVisibility({
    required String id,
    required String name,
    required bool visible,
  }) {
    final values = Map<String, bool>.from(orderTypeVisibility);
    values[id] = visible;
    final nameKey = _nameKey(name);
    if (nameKey != null) values[nameKey] = visible;
    return copyWith(orderTypeVisibility: values);
  }

  Map<String, Object> toJson() => {
    'show_dine_in': showDineIn,
    'show_takeaway': showTakeaway,
    'order_type_visibility': orderTypeVisibility,
    'show_type_icons': showTypeIcons,
    'warning_minutes': warningMinutes,
    'urgent_minutes': urgentMinutes,
    'large_text': largeText,
    'compact_cards': compactCards,
    'newest_first': newestFirst,
    'new_order_alert': newOrderAlert,
    'urgent_order_alert': urgentOrderAlert,
    'new_order_tone': newOrderTone.name,
    'urgent_order_tone': urgentOrderTone.name,
  };

  factory KdsSettings.fromJson(Map<String, dynamic> json) => KdsSettings(
    showDineIn: json['show_dine_in'] as bool? ?? true,
    showTakeaway: json['show_takeaway'] as bool? ?? true,
    orderTypeVisibility: _visibilityFromJson(json['order_type_visibility']),
    showTypeIcons: json['show_type_icons'] as bool? ?? true,
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
  );

  static Map<String, bool> _visibilityFromJson(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.key is String && entry.value is bool)
          entry.key as String: entry.value as bool,
    };
  }

  static String? _nameKey(String? name) {
    final normalized = name?.trim().toLowerCase() ?? '';
    return normalized.isEmpty ? null : 'name:$normalized';
  }
}
