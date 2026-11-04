import 'package:flutter_test/flutter_test.dart';
import 'package:mysztech_order_display/domain/models/kds_settings.dart';

void main() {
  test('persists separately selected new and urgent alert tones', () {
    const settings = KdsSettings(
      newOrderAlert: true,
      urgentOrderAlert: true,
      newOrderTone: KdsAlertTone.alert,
      urgentOrderTone: KdsAlertTone.chime,
    );

    final restored = KdsSettings.fromJson(settings.toJson());

    expect(restored.newOrderTone, KdsAlertTone.alert);
    expect(restored.urgentOrderTone, KdsAlertTone.chime);
  });

  test('persists order type visibility and defaults new types to shown', () {
    const settings = KdsSettings(orderTypeVisibility: {'id:grab': false});

    final restored = KdsSettings.fromJson(settings.toJson());

    expect(restored.isOrderTypeVisible(id: 'grab', name: 'Grab'), isFalse);
    expect(restored.isOrderTypeVisible(id: 'dine-in', name: 'Dine In'), isTrue);
  });
}
