import 'package:flutter/services.dart';

import '../../domain/models/kds_settings.dart';

/// Platform boundary for the local sounds used by the order display.
abstract interface class KitchenAlertPlayer {
  Future<void> play(KdsAlertTone tone);

  Future<void> dispose();
}

/// Uses the Android audio engine for distinct KDS alerts. Unlike a third-party
/// audio package, this channel is compiled directly into the Android app.
///
/// On platforms without the Android channel, it uses Flutter's system sound as
/// a quiet fallback and deliberately never interrupts the order workflow.
class BuiltInKitchenAlertPlayer implements KitchenAlertPlayer {
  BuiltInKitchenAlertPlayer({MethodChannel? channel})
    : _channel = channel ?? _kitchenAlertsChannel;

  static const _kitchenAlertsChannel = MethodChannel(
    'com.mysztechnology.mysztech_order_display/kitchen_alerts',
  );

  final MethodChannel _channel;

  @override
  Future<void> play(KdsAlertTone tone) async {
    try {
      await _channel.invokeMethod<void>('playTemplateSound', tone.name);
    } on MissingPluginException {
      await _playSystemFallback(tone);
    } on PlatformException {
      await _playSystemFallback(tone);
    }
  }

  Future<void> _playSystemFallback(KdsAlertTone tone) async {
    try {
      await SystemSound.play(switch (tone) {
        KdsAlertTone.chime ||
        KdsAlertTone.bell ||
        KdsAlertTone.pulse ||
        KdsAlertTone.call => SystemSoundType.click,
        KdsAlertTone.alert ||
        KdsAlertTone.priority ||
        KdsAlertTone.urgentPulse ||
        KdsAlertTone.urgentCall => SystemSoundType.alert,
      });
    } on MissingPluginException {
      // Alerts are optional on a platform without a system sound channel.
    } on PlatformException {
      // Alerts must never block a kitchen order from rendering.
    }
  }

  @override
  Future<void> dispose() async {}
}

class SilentKitchenAlertPlayer implements KitchenAlertPlayer {
  const SilentKitchenAlertPlayer();

  @override
  Future<void> play(KdsAlertTone tone) async {}

  @override
  Future<void> dispose() async {}
}
