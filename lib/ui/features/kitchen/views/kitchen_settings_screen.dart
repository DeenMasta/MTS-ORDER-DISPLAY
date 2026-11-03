import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/display_session.dart';
import '../../../../domain/models/kds_settings.dart';
import '../../../../domain/models/kitchen_ticket.dart';
import '../../../core/order_type_icon_library.dart';
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
  List<KdsOrderType> _orderTypes = const [];
  bool _loadingOrderTypes = true;

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
    _loadOrderTypes();
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

  void _setOrderTypeVisibility(KdsOrderType type, bool visible) => _update(
    _draft.withOrderTypeVisibility(
      id: type.id,
      name: type.name,
      visible: visible,
    ),
  );

  Future<void> _loadOrderTypes() async {
    final orderTypes = await widget.viewModel.orderTypes();
    if (!mounted) return;
    setState(() {
      _orderTypes = orderTypes;
      _loadingOrderTypes = false;
    });
  }

  Future<void> _selectOrderTypeIcon(KdsOrderType type) async {
    final icon = await _showOrderTypeIconPicker(type);
    if (icon == null || icon == type.icon) return;

    await widget.viewModel.updateOrderTypeIcon(type.id, icon);
    if (!mounted) return;
    setState(() {
      _orderTypes = _orderTypes
          .map(
            (orderType) => orderType.id == type.id
                ? KdsOrderType(
                    id: orderType.id,
                    name: orderType.name,
                    icon: icon,
                  )
                : orderType,
          )
          .toList(growable: false);
    });
  }

  Future<String?> _showOrderTypeIconPicker(KdsOrderType type) =>
      showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(0xFF081827),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose an icon for ${type.name}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'This icon is used on the receipt and dashboard.',
                    style: TextStyle(color: Color(0xFFA8C6D6)),
                  ),
                  const SizedBox(height: 20),
                  for (final category in const [
                    'Food & beverage',
                    'Retail',
                    'Service',
                  ]) ...[
                    Text(
                      category,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF43C9F5),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in orderTypeIconLibrary.where(
                          (option) => option.category == category,
                        ))
                          _OrderTypeIconChoice(
                            option: option,
                            selected: option.name == type.icon,
                            onTap: () => Navigator.pop(context, option.name),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

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
        seedColor: const Color(0xFF58D0BF),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF060B10),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B1219),
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF0D171E),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF28434A)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF090F15),
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
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Choose which order types appear on this display. Changes apply after Save changes.',
                ),
              ),
              SwitchListTile(
                title: const Text('Show order type icons'),
                value: _draft.showTypeIcons,
                onChanged: (value) =>
                    _update(_draft.copyWith(showTypeIcons: value)),
              ),
              if (_loadingOrderTypes)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_orderTypes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No order types have been received from the POS.',
                  ),
                )
              else
                for (final type in _orderTypes)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF123A52),
                      foregroundColor: const Color(0xFF49CCF4),
                      child: Icon(orderTypeIconFor(type.icon)),
                    ),
                    title: Text(type.name),
                    subtitle: Text(
                      '${_draft.isOrderTypeVisible(id: type.id, name: type.name) ? 'Shown on dashboard' : 'Hidden from dashboard'} • Icon: ${orderTypeIconOptionFor(type.icon).label}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: _draft.isOrderTypeVisible(
                            id: type.id,
                            name: type.name,
                          ),
                          onChanged: (visible) =>
                              _setOrderTypeVisibility(type, visible),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                    onTap: () => _selectOrderTypeIcon(type),
                  ),
            ],
          ),
          _Section(
            title: 'Order timer',
            children: [
              LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth < 360
                    ? Column(
                        children: [
                          _minutesField(_warningController, 'Yellow starts at'),
                          const SizedBox(height: 12),
                          _minutesField(_urgentController, 'Red starts at'),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _minutesField(
                              _warningController,
                              'Yellow starts at',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _minutesField(
                              _urgentController,
                              'Red starts at',
                            ),
                          ),
                        ],
                      ),
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
                  'Play once when a new order first reaches this display.',
                ),
                value: _draft.newOrderAlert,
                onChanged: (value) =>
                    _update(_draft.copyWith(newOrderAlert: value)),
              ),
              ListTile(
                enabled: _draft.newOrderAlert,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('New-order tone'),
                subtitle: const Text('Choose the sound for incoming orders.'),
                trailing: DropdownButton<KdsAlertTone>(
                  value: _draft.newOrderTone,
                  items: [
                    for (final tone in KdsAlertTone.values)
                      DropdownMenuItem(value: tone, child: Text(tone.label)),
                  ],
                  onChanged: !_draft.newOrderAlert
                      ? null
                      : (tone) {
                          if (tone != null) {
                            _update(_draft.copyWith(newOrderTone: tone));
                          }
                        },
                ),
              ),
              SwitchListTile(
                title: const Text('Urgent-order alert'),
                subtitle: const Text(
                  'Play once when an active order reaches the red timer.',
                ),
                value: _draft.urgentOrderAlert,
                onChanged: (value) =>
                    _update(_draft.copyWith(urgentOrderAlert: value)),
              ),
              ListTile(
                enabled: _draft.urgentOrderAlert,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.crisis_alert_outlined),
                title: const Text('Urgent-order tone'),
                subtitle: const Text('Choose the sound for red-timer orders.'),
                trailing: DropdownButton<KdsAlertTone>(
                  value: _draft.urgentOrderTone,
                  items: [
                    for (final tone in KdsAlertTone.values)
                      DropdownMenuItem(value: tone, child: Text(tone.label)),
                  ],
                  onChanged: !_draft.urgentOrderAlert
                      ? null
                      : (tone) {
                          if (tone != null) {
                            _update(_draft.copyWith(urgentOrderTone: tone));
                          }
                        },
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text('Alert loudness follows the device sound level.'),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          widget.viewModel.testAlertTone(_draft.newOrderTone),
                      icon: const Icon(Icons.volume_up_outlined),
                      label: const Text('Test new-order tone'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => widget.viewModel.testAlertTone(
                        _draft.urgentOrderTone,
                      ),
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text('Test urgent tone'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _Section(
            title: 'Dashboard layout',
            children: [
              SwitchListTile(
                title: const Text('Large receipt text'),
                subtitle: const Text(
                  'Make order items easier to read at a distance.',
                ),
                value: _draft.largeText,
                onChanged: (value) =>
                    _update(_draft.copyWith(largeText: value)),
              ),
              SwitchListTile(
                title: const Text('Compact receipt cards'),
                subtitle: const Text(
                  'Fit more order information in each card.',
                ),
                value: _draft.compactCards,
                onChanged: (value) =>
                    _update(_draft.copyWith(compactCards: value)),
              ),
              SwitchListTile(
                title: const Text('Newest orders first'),
                subtitle: const Text(
                  'Off keeps the oldest orders at the front.',
                ),
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

class _OrderTypeIconChoice extends StatelessWidget {
  const _OrderTypeIconChoice({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final OrderTypeIconOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: option.label,
    child: Material(
      color: selected ? const Color(0xFF0D526D) : const Color(0xFF10283A),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 104,
          height: 86,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  option.icon,
                  color: selected
                      ? const Color(0xFF69DCF9)
                      : const Color(0xFFD6E9F0),
                ),
                const SizedBox(height: 7),
                Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF69DCF9)
                        : const Color(0xFFD6E9F0),
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
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
