import 'package:flutter_test/flutter_test.dart';
import 'package:mysztech_order_display/domain/models/kds_settings.dart';

void main() {
  test('uses a per-order-type preference before legacy visibility flags', () {
    const settings = KdsSettings(
      showDineIn: false,
      orderTypeVisibility: {'dine-in': true, 'name:grab': false},
    );

    expect(settings.isOrderTypeVisible(id: 'dine-in', name: 'Dine In'), isTrue);
    expect(settings.isOrderTypeVisible(name: 'Grab'), isFalse);
    expect(settings.isOrderTypeVisible(name: 'Dine In'), isFalse);
  });

  test('persists per-order-type visibility in local display settings', () {
    final settings = const KdsSettings().withOrderTypeVisibility(
      id: 'foodpanda',
      name: 'Foodpanda',
      visible: false,
    );
    final restored = KdsSettings.fromJson(settings.toJson());

    expect(
      restored.isOrderTypeVisible(id: 'foodpanda', name: 'Foodpanda'),
      isFalse,
    );
    expect(restored.isOrderTypeVisible(name: 'Foodpanda'), isFalse);
  });

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
}
