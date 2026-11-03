import 'package:flutter/services.dart';

import '../../domain/models/kds_settings.dart';

/// Platform boundary for the local sounds used by the kitchen display.
abstract interface class KitchenAlertPlayer {
  Future<void> play(KdsAlertTone tone);
}

class SystemKitchenAlertPlayer implements KitchenAlertPlayer {
  const SystemKitchenAlertPlayer();

  @override
  Future<void> play(KdsAlertTone tone) async {
    try {
      await SystemSound.play(
        tone == KdsAlertTone.chime
            ? SystemSoundType.click
            : SystemSoundType.alert,
      );
    } on MissingPluginException {
      // Sound is optional and unavailable on some desktop/device targets.
    }
  }
}

class SilentKitchenAlertPlayer implements KitchenAlertPlayer {
  const SilentKitchenAlertPlayer();

  @override
  Future<void> play(KdsAlertTone tone) async {}
}
