import 'package:flutter_test/flutter_test.dart';
import 'package:mysztech_order_display/data/services/app_version_service.dart';

void main() {
  test('reads the full version and build number from pubspec text', () {
    expect(versionFromPubspec('name: kds\nversion: 1.0.0+1\n'), 'v1.0.0+1');
  });

  test('ignores comments after the pubspec version', () {
    expect(versionFromPubspec('version: 2.4.1+7 # production\n'), 'v2.4.1+7');
  });
}
