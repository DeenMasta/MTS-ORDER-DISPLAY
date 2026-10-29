import 'package:flutter/material.dart';

import '../../pairing/view_models/pairing_view_model.dart';
import '../../pairing/views/pairing_screen.dart';
import '../../kitchen/view_models/kitchen_board_view_model.dart';
import '../../kitchen/views/kitchen_board_screen.dart';
import '../view_models/session_view_model.dart';

class SessionGate extends StatelessWidget {
  const SessionGate({
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
    return ListenableBuilder(
      listenable: sessionViewModel,
      builder: (context, child) => switch (sessionViewModel.status) {
        SessionStatus.loading => const _StatusScreen(
          title: 'Starting kitchen display',
          child: CircularProgressIndicator(),
        ),
        SessionStatus.unpaired => PairingScreen(
          viewModel: pairingViewModel,
          onPaired: sessionViewModel.initialize,
        ),
        SessionStatus.paired => KitchenBoardScreen(
          viewModel: kitchenBoardViewModel,
          session: sessionViewModel.session!,
        ),
        SessionStatus.error => _StatusScreen(
          title: 'Unable to start kitchen display',
          child: FilledButton(
            onPressed: sessionViewModel.initialize,
            child: const Text('Try again'),
          ),
        ),
      },
    );
  }
}

class _StatusScreen extends StatelessWidget {
  const _StatusScreen({required this.title, required this.child});

  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
