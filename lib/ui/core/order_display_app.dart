import 'package:flutter/material.dart';

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
  });

  final PairingViewModel pairingViewModel;
  final KitchenBoardViewModel kitchenBoardViewModel;
  final SessionViewModel sessionViewModel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mysztech Order Display',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8A2A19)),
        useMaterial3: true,
      ),
      home: SessionGate(
        sessionViewModel: sessionViewModel,
        pairingViewModel: pairingViewModel,
        kitchenBoardViewModel: kitchenBoardViewModel,
      ),
    );
  }
}
