import 'package:flutter_test/flutter_test.dart';
import 'package:mysztech_order_display/data/services/app_version_service.dart';
import 'package:mysztech_order_display/ui/core/app_version_view_model.dart';

void main() {
  test('exposes the product name and loaded pubspec version', () async {
    final viewModel = AppVersionViewModel(
      appVersionService: _FixedAppVersionService('v1.0.0+1'),
    );

    await viewModel.load();

    expect(AppVersionViewModel.appName, 'Mysztech ODS');
    expect(viewModel.displayVersion, 'v1.0.0+1');
  });
}

class _FixedAppVersionService implements AppVersionService {
  const _FixedAppVersionService(this._displayVersion);

  final String _displayVersion;

  @override
  Future<String> get displayVersion async => _displayVersion;
}
