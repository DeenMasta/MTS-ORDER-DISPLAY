import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysztech_order_display/data/services/kitchen_alert_player.dart';
import 'package:mysztech_order_display/domain/models/kds_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sends distinct built-in alert requests to Android', () async {
    const channel = MethodChannel(
      'com.mysztechnology.mysztech_order_display/kitchen_alerts',
    );
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final player = BuiltInKitchenAlertPlayer(channel: channel);
    await player.play(KdsAlertTone.chime);
    await player.play(KdsAlertTone.alert);

    expect(methods, ['playNewOrder', 'playUrgentOrder']);
  });
}
