enum KdsAlertTone {
  chime,
  bell,
  pulse,
  call,
  alert,
  priority,
  urgentPulse,
  urgentCall;

  /// Each urgent template shares its musical motif with the matching new-order
  /// template, then repeats it more quickly with a higher final note.
  static const newOrderTemplates = <KdsAlertTone>[chime, bell, pulse, call];
  static const urgentOrderTemplates = <KdsAlertTone>[
    alert,
    priority,
    urgentPulse,
    urgentCall,
  ];

  static List<KdsAlertTone> templatesFor({required bool urgent}) =>
      urgent ? urgentOrderTemplates : newOrderTemplates;

  static KdsAlertTone fromStorage(Object? value, KdsAlertTone fallback) =>
      switch (value) {
        'chime' => chime,
        'bell' => bell,
        'pulse' => pulse,
        'call' => call,
        'alert' => alert,
        'priority' => priority,
        'urgentPulse' => urgentPulse,
        'urgentCall' => urgentCall,
        _ => fallback,
      };
}

extension KdsAlertToneLabel on KdsAlertTone {
  String get label => switch (this) {
    KdsAlertTone.chime => 'Bright chime',
    KdsAlertTone.bell => 'Warm bell',
    KdsAlertTone.pulse => 'Quick pulse',
    KdsAlertTone.call => 'Kitchen call',
    KdsAlertTone.alert => 'Chime priority',
    KdsAlertTone.priority => 'Bell priority',
    KdsAlertTone.urgentPulse => 'Pulse priority',
    KdsAlertTone.urgentCall => 'Call priority',
  };

  String get description => switch (this) {
    KdsAlertTone.chime => 'A clear three-note arrival chime.',
    KdsAlertTone.bell => 'A warm counter-bell sequence.',
    KdsAlertTone.pulse => 'A short two-pulse service cue.',
    KdsAlertTone.call => 'A friendly two-note kitchen call.',
    KdsAlertTone.alert =>
      'The Bright chime motif, faster and repeated for urgent orders.',
    KdsAlertTone.priority =>
      'The Warm bell motif, faster and repeated for urgent orders.',
    KdsAlertTone.urgentPulse =>
      'The Quick pulse motif, faster and repeated for urgent orders.',
    KdsAlertTone.urgentCall =>
      'The Kitchen call motif, faster and repeated for urgent orders.',
  };
}

class KdsSettings {
  const KdsSettings({
    this.warningMinutes = 5,
    this.warningSeconds = 0,
    this.urgentMinutes = 10,
    this.urgentSeconds = 0,
    this.finishedReceiptSeconds = 10,
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
  final int warningSeconds;
  final int urgentMinutes;
  final int urgentSeconds;
  final int finishedReceiptSeconds;
  final bool largeText;
  final bool compactCards;
  final bool newestFirst;
  final bool newOrderAlert;
  final bool urgentOrderAlert;
  final KdsAlertTone newOrderTone;
  final KdsAlertTone urgentOrderTone;
  final Map<String, bool> orderTypeVisibility;

  /// Total elapsed seconds before the yellow timer state begins.
  int get warningThresholdSeconds => warningMinutes * 60 + warningSeconds;

  /// Total elapsed seconds before the red timer state begins.
  int get urgentThresholdSeconds => urgentMinutes * 60 + urgentSeconds;

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
    int? warningSeconds,
    int? urgentMinutes,
    int? urgentSeconds,
    int? finishedReceiptSeconds,
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
    warningSeconds: warningSeconds ?? this.warningSeconds,
    urgentMinutes: urgentMinutes ?? this.urgentMinutes,
    urgentSeconds: urgentSeconds ?? this.urgentSeconds,
    finishedReceiptSeconds:
        finishedReceiptSeconds ?? this.finishedReceiptSeconds,
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
    'warning_seconds': warningSeconds,
    'urgent_minutes': urgentMinutes,
    'urgent_seconds': urgentSeconds,
    'finished_receipt_seconds': finishedReceiptSeconds,
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
    warningSeconds: json['warning_seconds'] as int? ?? 0,
    urgentMinutes: json['urgent_minutes'] as int? ?? 10,
    urgentSeconds: json['urgent_seconds'] as int? ?? 0,
    finishedReceiptSeconds: json['finished_receipt_seconds'] as int? ?? 10,
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
