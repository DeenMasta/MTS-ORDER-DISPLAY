import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysztech_order_display/data/services/kitchen_alert_player.dart';
import 'package:mysztech_order_display/domain/models/kds_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sends each selected sound template to Android', () async {
    const channel = MethodChannel(
      'com.mysztechnology.mysztech_order_display/kitchen_alerts',
    );
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final player = BuiltInKitchenAlertPlayer(channel: channel);
    for (final tone in KdsAlertTone.values) {
      await player.play(tone);
    }

    expect(calls.map((call) => call.method), everyElement('playTemplateSound'));
    expect(
      calls.map((call) => call.arguments),
      KdsAlertTone.values.map((tone) => tone.name).toList(),
    );
  });
}
