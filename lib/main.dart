import 'package:flutter/widgets.dart';

import 'app_dependencies.dart';
import 'ui/core/order_display_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = AppDependencies();
  runApp(
    OrderDisplayApp(
      sessionViewModel: dependencies.sessionViewModel,
      pairingViewModel: dependencies.pairingViewModel,
      kitchenBoardViewModel: dependencies.kitchenBoardViewModel,
    ),
  );
  dependencies.sessionViewModel.initialize();
}
