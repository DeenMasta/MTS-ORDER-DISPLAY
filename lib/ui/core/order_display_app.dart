import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_splash.dart';
import 'app_version_view_model.dart';
import '../features/kitchen/view_models/kitchen_board_view_model.dart';
import '../features/pairing/view_models/pairing_view_model.dart';
import '../features/session/view_models/session_view_model.dart';
import '../features/session/views/session_gate.dart';

class OrderDisplayApp extends StatelessWidget {
  const OrderDisplayApp({
    super.key,
    required this.sessionViewModel,
    required this.pairingViewModel,
    required this.kitchenBoardViewModel,
    required this.appVersionViewModel,
  });

  final PairingViewModel pairingViewModel;
  final KitchenBoardViewModel kitchenBoardViewModel;
  final SessionViewModel sessionViewModel;
  final AppVersionViewModel appVersionViewModel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mysztech ODS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary)
            .copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              secondary: AppColors.primaryMuted,
              surface: AppColors.surface,
              onSurface: AppColors.text,
              outline: AppColors.outline,
            ),
        useMaterial3: true,
        filledButtonTheme: const FilledButtonThemeData(
          style: AppButtonStyles.filled,
        ),
        outlinedButtonTheme: const OutlinedButtonThemeData(
          style: AppButtonStyles.outlined,
        ),
        textButtonTheme: const TextButtonThemeData(style: AppButtonStyles.text),
      ),
      home: ListenableBuilder(
        listenable: appVersionViewModel,
        builder: (context, _) => AppSplash(
          child: SessionGate(
            sessionViewModel: sessionViewModel,
            pairingViewModel: pairingViewModel,
            kitchenBoardViewModel: kitchenBoardViewModel,
            appName: AppVersionViewModel.appName,
            appVersion: appVersionViewModel.displayVersion,
          ),
        ),
      ),
    );
  }
}
