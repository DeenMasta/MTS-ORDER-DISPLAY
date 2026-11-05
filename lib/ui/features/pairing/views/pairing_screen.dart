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
  final _displayNameController = TextEditingController(text: 'Order Display');
  final _posAddressController = TextEditingController();
  final _displayNameFocusNode = FocusNode();

  @override
  void dispose() {
    _displayNameController.dispose();
    _posAddressController.dispose();
    _displayNameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _startPairing() async {
    FocusScope.of(context).unfocus();
    final paired = await widget.viewModel.start(
      posAddress: _posAddressController.text,
      displayName: _displayNameController.text,
    );
    if (paired && mounted) await widget.onPaired();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFA44C2E),
      ),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFFFFFFF),
        border: OutlineInputBorder(),
      ),
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      body: Stack(
        children: [
          const Positioned.fill(child: _BrandPatternBackground()),
          SafeArea(
            child: ListenableBuilder(
              listenable: widget.viewModel,
              builder: (context, _) {
                final waiting =
                    widget.viewModel.status == PairingStatus.connecting ||
                    widget.viewModel.status == PairingStatus.waiting;
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: _PairingCard(
                        waiting: waiting,
                        code: widget.viewModel.code,
                        errorMessage: widget.viewModel.errorMessage,
                        posAddressController: _posAddressController,
                        displayNameController: _displayNameController,
                        displayNameFocusNode: _displayNameFocusNode,
                        onStartPairing: _startPairing,
                        onCancel: widget.viewModel.cancel,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _BrandPatternBackground extends StatelessWidget {
  const _BrandPatternBackground();

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [Image.asset('assets/images/kds_background.png', fit: BoxFit.cover)],
  );
}

class _PairingCard extends StatelessWidget {
  const _PairingCard({
    required this.waiting,
    required this.code,
    required this.errorMessage,
    required this.posAddressController,
    required this.displayNameController,
    required this.displayNameFocusNode,
    required this.onStartPairing,
    required this.onCancel,
  });

  final bool waiting;
  final String? code;
  final String? errorMessage;
  final TextEditingController posAddressController;
  final TextEditingController displayNameController;
  final FocusNode displayNameFocusNode;
  final Future<void> Function() onStartPairing;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color(0xF2FFFCF9),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFD5DAD8)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: Image.asset('assets/images/mysztech_logo.png', height: 42)),
        const SizedBox(height: 24),
        Text(
          waiting ? 'Confirm pairing' : 'Set up your order display',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          waiting
              ? 'Approve this display from the POS to finish setup.'
              : 'Connect this screen to your POS in two quick steps.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF52616B),
          ),
        ),
        const SizedBox(height: 28),
        if (waiting)
          _WaitingForApproval(code: code, onCancel: onCancel)
        else
          _SetupForm(
            errorMessage: errorMessage,
            posAddressController: posAddressController,
            displayNameController: displayNameController,
            displayNameFocusNode: displayNameFocusNode,
            onStartPairing: onStartPairing,
          ),
      ],
    ),
  );
}

class _SetupForm extends StatelessWidget {
  const _SetupForm({
    required this.errorMessage,
    required this.posAddressController,
    required this.displayNameController,
    required this.displayNameFocusNode,
    required this.onStartPairing,
  });

  final String? errorMessage;
  final TextEditingController posAddressController;
  final TextEditingController displayNameController;
  final FocusNode displayNameFocusNode;
  final Future<void> Function() onStartPairing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _StepHeading(number: '1', title: 'Find your POS'),
      const SizedBox(height: 12),
      TextField(
        controller: posAddressController,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => displayNameFocusNode.requestFocus(),
        decoration: const InputDecoration(
          labelText: 'POS LAN address',
          hintText: '192.168.1.10',
          prefixIcon: Icon(Icons.lan_outlined),
        ),
      ),
      const SizedBox(height: 8),
      const _Hint(
        icon: Icons.info_outline,
        text:
            'Enter the address shown in POS settings. It connects to ws://POS-IP:8080/kds.',
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Divider(color: Color(0xFFD5DAD8)),
      ),
      const _StepHeading(number: '2', title: 'Name this screen'),
      const SizedBox(height: 12),
      TextField(
        controller: displayNameController,
        focusNode: displayNameFocusNode,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onStartPairing(),
        decoration: const InputDecoration(
          labelText: 'Display name',
          hintText: 'Main Kitchen',
          prefixIcon: Icon(Icons.tv_outlined),
        ),
      ),
      if (errorMessage case final message?) ...[
        const SizedBox(height: 20),
        _ErrorMessage(message: message),
      ],
      const SizedBox(height: 28),
      FilledButton.icon(
        onPressed: onStartPairing,
        icon: const Icon(Icons.link),
        label: const Text('Pair display'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
        ),
      ),
      const SizedBox(height: 14),
      const _Hint(
        icon: Icons.wifi_outlined,
        text: 'Keep this display and the POS on the same local network.',
      ),
    ],
  );
}

class _WaitingForApproval extends StatelessWidget {
  const _WaitingForApproval({required this.code, required this.onCancel});

  final String? code;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD5DAD8)),
        ),
        child: Column(
          children: [
            if (code == null) ...[
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              const Text('Contacting POS…'),
            ] else ...[
              const Text(
                'PAIRING CODE',
                style: TextStyle(
                  color: Color(0xFF52616B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              SelectableText(
                code!,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
      const _Hint(
        icon: Icons.desktop_windows_outlined,
        text:
            'Look for this pairing request in your POS settings and approve it there.',
      ),
      const SizedBox(height: 24),
      OutlinedButton.icon(
        onPressed: onCancel,
        icon: const Icon(Icons.close),
        label: const Text('Cancel pairing'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    ],
  );
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.number, required this.title});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFA44C2E),
          shape: BoxShape.circle,
        ),
        child: Text(
          number,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: const Color(0xFF52616B)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF52616B),
          ),
        ),
      ),
    ],
  );
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE8E8),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Theme.of(context).colorScheme.error),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
  );
}
