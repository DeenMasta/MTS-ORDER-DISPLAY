import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/display_session.dart';
import '../../../../domain/models/kds_settings.dart';
import '../../../../domain/models/kitchen_ticket.dart';
import '../view_models/kitchen_board_view_model.dart';

class KitchenSettingsScreen extends StatefulWidget {
  const KitchenSettingsScreen({
    super.key,
    required this.viewModel,
    required this.session,
    required this.onChangeConnection,
  });

  final KitchenBoardViewModel viewModel;
  final DisplaySession session;
  final Future<void> Function() onChangeConnection;

  @override
  State<KitchenSettingsScreen> createState() => _KitchenSettingsScreenState();
}

class _KitchenSettingsScreenState extends State<KitchenSettingsScreen> {
  late KdsSettings _draft;
  late final TextEditingController _warningController;
  late final TextEditingController _urgentController;
  late final Future<List<KdsOrderType>> _orderTypes;

  @override
  void initState() {
    super.initState();
    _draft = widget.viewModel.settings;
    _warningController = TextEditingController(
      text: _draft.warningMinutes.toString(),
    );
    _urgentController = TextEditingController(
      text: _draft.urgentMinutes.toString(),
    );
    _orderTypes = widget.viewModel.orderTypes();
  }

  @override
  void dispose() {
    _warningController.dispose();
    _urgentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final warning = int.tryParse(_warningController.text.trim());
    final urgent = int.tryParse(_urgentController.text.trim());
    if (warning == null || urgent == null) {
      _message('Enter whole minutes for both timer thresholds.');
      return;
    }
    try {
      await widget.viewModel.saveSettings(
        _draft.copyWith(warningMinutes: warning, urgentMinutes: urgent),
      );
      if (mounted) {
        _message('Settings saved.');
        Navigator.pop(context);
      }
    } on FormatException catch (error) {
      _message(error.message);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  void _update(KdsSettings value) => setState(() => _draft = value);

  Future<void> _changeConnection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change POS connection?'),
        content: const Text(
          'This removes the saved POS address and returns to pairing. Existing locally stored orders are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Change connection'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.onChangeConnection();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00A8E8),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF06131F),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF081B2B),
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF10263A),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF081B2B),
      ),
    ),
    child: Scaffold(
      appBar: AppBar(title: const Text('Display settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Section(
            title: 'Order types',
            children: [
              SwitchListTile(
                title: const Text('Show Dine In'),
                subtitle: const Text(
                  'Show Dine In filters and orders on this device.',
                ),
                value: _draft.showDineIn,
                onChanged: (value) =>
                    _update(_draft.copyWith(showDineIn: value)),
              ),
              SwitchListTile(
                title: const Text('Show Takeaway'),
                subtitle: const Text(
                  'Show Takeaway filters and orders on this device.',
                ),
                value: _draft.showTakeaway,
                onChanged: (value) =>
                    _update(_draft.copyWith(showTakeaway: value)),
              ),
              SwitchListTile(
                title: const Text('Show order type icons'),
                value: _draft.showTypeIcons,
                onChanged: (value) =>
                    _update(_draft.copyWith(showTypeIcons: value)),
              ),
              FutureBuilder<List<KdsOrderType>>(
                future: _orderTypes,
                builder: (context, snapshot) => Column(
                  children: [
                    for (final type in snapshot.data ?? const <KdsOrderType>[])
                      ListTile(
                        title: Text('${type.name} icon'),
                        trailing: DropdownButton<String>(
                          value: type.icon,
                          items: const [
                            DropdownMenuItem(
                              value: 'restaurant',
                              child: Icon(Icons.restaurant),
                            ),
                            DropdownMenuItem(
                              value: 'table_restaurant',
                              child: Icon(Icons.table_restaurant),
                            ),
                            DropdownMenuItem(
                              value: 'takeout_dining',
                              child: Icon(Icons.takeout_dining),
                            ),
                            DropdownMenuItem(
                              value: 'delivery_dining',
                              child: Icon(Icons.delivery_dining),
                            ),
                          ],
                          onChanged: (icon) {
                            if (icon != null) {
                              widget.viewModel.updateOrderTypeIcon(
                                type.id,
                                icon,
                              );
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          _Section(
            title: 'Order timer',
            children: [
              Row(
                children: [
                  Expanded(
                    child: _minutesField(
                      _warningController,
                      'Yellow starts at',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _minutesField(_urgentController, 'Red starts at'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Yellow must be greater than 0 and lower than red.'),
              const SizedBox(height: 16),
              const _TimerPreview(),
            ],
          ),
          _Section(
            title: 'Sound & notifications',
            children: [
              SwitchListTile(
                title: const Text('New-order alert'),
                subtitle: const Text(
                  'Stored preference; system sound support depends on the device.',
                ),
                value: _draft.newOrderAlert,
                onChanged: (value) =>
                    _update(_draft.copyWith(newOrderAlert: value)),
              ),
              SwitchListTile(
                title: const Text('Urgent-order alert'),
                value: _draft.urgentOrderAlert,
                onChanged: (value) =>
                    _update(_draft.copyWith(urgentOrderAlert: value)),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => SystemSound.play(SystemSoundType.click),
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('Test system sound'),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _changeConnection,
                  icon: const Icon(Icons.edit_location_alt_outlined),
                  label: const Text('Change POS connection'),
                ),
              ),
            ],
          ),
          _Section(
            title: 'Display',
            children: [
              SwitchListTile(
                title: const Text('Large receipt text'),
                value: _draft.largeText,
                onChanged: (value) =>
                    _update(_draft.copyWith(largeText: value)),
              ),
              SwitchListTile(
                title: const Text('Compact cards'),
                value: _draft.compactCards,
                onChanged: (value) =>
                    _update(_draft.copyWith(compactCards: value)),
              ),
              SwitchListTile(
                title: const Text('Newest orders first'),
                value: _draft.newestFirst,
                onChanged: (value) =>
                    _update(_draft.copyWith(newestFirst: value)),
              ),
            ],
          ),
          _Section(
            title: 'Connection',
            children: [
              ListTile(
                leading: Icon(
                  widget.viewModel.isPaired
                      ? Icons.cloud_done
                      : Icons.cloud_off,
                ),
                title: Text(
                  widget.viewModel.isPaired
                      ? 'Connected to POS'
                      : 'Reconnecting to POS',
                ),
                subtitle: Text('POS: ${widget.session.posIp}'),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await widget.viewModel.start(widget.session);
                    if (mounted) _message('Reconnect requested.');
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reconnect'),
                ),
              ),
            ],
          ),
          _Section(
            title: 'About this display',
            children: [
              ListTile(
                title: const Text('Display name'),
                subtitle: Text(widget.session.displayName),
              ),
              ListTile(
                title: const Text('Display ID'),
                subtitle: Text(widget.session.displayId),
              ),
              const ListTile(
                title: Text('App version'),
                subtitle: Text('1.0.0'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save changes'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );

  Widget _minutesField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
          suffixText: 'minutes',
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

class _TimerPreview extends StatelessWidget {
  const _TimerPreview();
  @override
  Widget build(BuildContext context) => const Row(
    children: [
      _Preview(color: Color(0xFF02D53C), label: '00:03:00'),
      SizedBox(width: 8),
      _Preview(color: Color(0xFFFFEF00), label: '00:05:00'),
      SizedBox(width: 8),
      _Preview(color: Color(0xFFFF1C2C), label: '00:10:00'),
    ],
  );
}

class _Preview extends StatelessWidget {
  const _Preview({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: color,
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );
}
