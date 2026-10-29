import 'package:flutter/material.dart';

import '../view_models/pairing_view_model.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({
    super.key,
    required this.viewModel,
    required this.onPaired,
  });

  final PairingViewModel viewModel;
  final Future<void> Function() onPaired;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _displayNameController = TextEditingController(text: 'Kitchen Display');
  final _posAddressController = TextEditingController();

  @override
  void dispose() {
    _displayNameController.dispose();
    _posAddressController.dispose();
    super.dispose();
  }

  Future<void> _startPairing() async {
    final paired = await widget.viewModel.start(
      posAddress: _posAddressController.text,
      displayName: _displayNameController.text,
    );
    if (paired && mounted) {
      await widget.onPaired();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pair kitchen display')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, child) {
            final waiting = widget.viewModel.status == PairingStatus.connecting ||
                widget.viewModel.status == PairingStatus.waiting;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('Enter the address shown in POS settings.'),
                const SizedBox(height: 16),
                _field(_posAddressController, 'POS LAN address', '192.168.1.10'),
                const Text('Connects to ws://POS-IP:8080/kds'),
                const Divider(height: 40),
                _field(_displayNameController, 'Display name', 'Main Kitchen'),
                if (widget.viewModel.code case final code?) ...[
                  const SizedBox(height: 24),
                  Text('Confirm this code in POS', style: Theme.of(context).textTheme.titleMedium),
                  Text(code, style: Theme.of(context).textTheme.displayMedium),
                ],
                if (widget.viewModel.errorMessage case final message?) ...[
                  const SizedBox(height: 16),
                  Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                if (waiting)
                  OutlinedButton(
                    onPressed: widget.viewModel.cancel,
                    child: const Text('Cancel pairing'),
                  )
                else
                  FilledButton(
                    onPressed: _startPairing,
                    child: const Text('Start pairing'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(border: const OutlineInputBorder(), hintText: hint, labelText: label),
    ),
  );
}
