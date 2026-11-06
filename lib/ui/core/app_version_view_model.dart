import 'package:flutter/foundation.dart';

import '../../data/services/app_version_service.dart';

/// Exposes local package metadata for presentation without coupling views to a
/// platform plugin.
class AppVersionViewModel extends ChangeNotifier {
  AppVersionViewModel({required AppVersionService appVersionService})
    : _appVersionService = appVersionService;

  static const appName = 'Mysztech ODS';

  final AppVersionService _appVersionService;
  String? _displayVersion;

  String? get displayVersion => _displayVersion;

  Future<void> load() async {
    try {
      final displayVersion = await _appVersionService.displayVersion;
      if (_displayVersion == displayVersion) return;
      _displayVersion = displayVersion;
      notifyListeners();
    } on Object {
      // A missing platform implementation should not block the order display.
    }
  }
}
