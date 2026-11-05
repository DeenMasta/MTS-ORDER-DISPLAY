import 'package:flutter_test/flutter_test.dart';
import 'package:mysztech_order_display/domain/models/kds_settings.dart';

void main() {
  test('uses a different default template for urgent alerts', () {
    const settings = KdsSettings();

    expect(settings.newOrderTone, KdsAlertTone.chime);
    expect(settings.urgentOrderTone, KdsAlertTone.alert);
    expect(settings.newOrderTone, isNot(settings.urgentOrderTone));
  });

  test('keeps calm and urgent sound template choices separate', () {
    expect(KdsAlertTone.templatesFor(urgent: false), [
      KdsAlertTone.chime,
      KdsAlertTone.bell,
      KdsAlertTone.pulse,
      KdsAlertTone.call,
    ]);
    expect(KdsAlertTone.templatesFor(urgent: true), [
      KdsAlertTone.alert,
      KdsAlertTone.priority,
      KdsAlertTone.urgentPulse,
      KdsAlertTone.urgentCall,
    ]);
  });

  test('persists separate sound templates for new and urgent alerts', () {
    const settings = KdsSettings(
      newOrderAlert: true,
      urgentOrderAlert: true,
      newOrderTone: KdsAlertTone.bell,
      urgentOrderTone: KdsAlertTone.priority,
    );

    final restored = KdsSettings.fromJson(settings.toJson());

    expect(restored.newOrderTone, KdsAlertTone.bell);
    expect(restored.urgentOrderTone, KdsAlertTone.priority);
  });

  test('persists order type visibility and defaults new types to shown', () {
    const settings = KdsSettings(orderTypeVisibility: {'id:grab': false});

    final restored = KdsSettings.fromJson(settings.toJson());

    expect(restored.isOrderTypeVisible(id: 'grab', name: 'Grab'), isFalse);
    expect(restored.isOrderTypeVisible(id: 'dine-in', name: 'Dine In'), isTrue);
  });
}
