class KdsSettings {
  const KdsSettings({
    this.showDineIn = true,
    this.showTakeaway = true,
    this.showTypeIcons = true,
    this.warningMinutes = 5,
    this.urgentMinutes = 10,
    this.largeText = false,
    this.compactCards = false,
    this.newestFirst = false,
    this.newOrderAlert = false,
    this.urgentOrderAlert = false,
  });

  final bool showDineIn;
  final bool showTakeaway;
  final bool showTypeIcons;
  final int warningMinutes;
  final int urgentMinutes;
  final bool largeText;
  final bool compactCards;
  final bool newestFirst;
  final bool newOrderAlert;
  final bool urgentOrderAlert;

  KdsSettings copyWith({
    bool? showDineIn,
    bool? showTakeaway,
    bool? showTypeIcons,
    int? warningMinutes,
    int? urgentMinutes,
    bool? largeText,
    bool? compactCards,
    bool? newestFirst,
    bool? newOrderAlert,
    bool? urgentOrderAlert,
  }) => KdsSettings(
    showDineIn: showDineIn ?? this.showDineIn,
    showTakeaway: showTakeaway ?? this.showTakeaway,
    showTypeIcons: showTypeIcons ?? this.showTypeIcons,
    warningMinutes: warningMinutes ?? this.warningMinutes,
    urgentMinutes: urgentMinutes ?? this.urgentMinutes,
    largeText: largeText ?? this.largeText,
    compactCards: compactCards ?? this.compactCards,
    newestFirst: newestFirst ?? this.newestFirst,
    newOrderAlert: newOrderAlert ?? this.newOrderAlert,
    urgentOrderAlert: urgentOrderAlert ?? this.urgentOrderAlert,
  );

  Map<String, Object> toJson() => {
    'show_dine_in': showDineIn,
    'show_takeaway': showTakeaway,
    'show_type_icons': showTypeIcons,
    'warning_minutes': warningMinutes,
    'urgent_minutes': urgentMinutes,
    'large_text': largeText,
    'compact_cards': compactCards,
    'newest_first': newestFirst,
    'new_order_alert': newOrderAlert,
    'urgent_order_alert': urgentOrderAlert,
  };

  factory KdsSettings.fromJson(Map<String, dynamic> json) => KdsSettings(
    showDineIn: json['show_dine_in'] as bool? ?? true,
    showTakeaway: json['show_takeaway'] as bool? ?? true,
    showTypeIcons: json['show_type_icons'] as bool? ?? true,
    warningMinutes: json['warning_minutes'] as int? ?? 5,
    urgentMinutes: json['urgent_minutes'] as int? ?? 10,
    largeText: json['large_text'] as bool? ?? false,
    compactCards: json['compact_cards'] as bool? ?? false,
    newestFirst: json['newest_first'] as bool? ?? false,
    newOrderAlert: json['new_order_alert'] as bool? ?? false,
    urgentOrderAlert: json['urgent_order_alert'] as bool? ?? false,
  );
}
