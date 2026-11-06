import 'package:flutter/services.dart';

/// Reads the version bundled with the application from its pubspec.
abstract interface class AppVersionService {
  Future<String> get displayVersion;
}

class BundledPubspecAppVersionService implements AppVersionService {
  BundledPubspecAppVersionService({AssetBundle? assets})
    : _assets = assets ?? rootBundle;

  final AssetBundle _assets;

  @override
  Future<String> get displayVersion async {
    final pubspec = await _assets.loadString('pubspec.yaml', cache: false);
    return versionFromPubspec(pubspec);
  }
}

String versionFromPubspec(String pubspec) {
  final match = RegExp(
    r'^\s*version\s*:\s*([^\s#]+)',
    multiLine: true,
  ).firstMatch(pubspec);
  if (match == null) throw const FormatException('pubspec version is missing.');
  return 'v${match.group(1)!}';
}
