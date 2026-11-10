import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/display_session.dart';
import '../../../../domain/models/kds_settings.dart';
import '../../../../domain/models/kitchen_ticket.dart';
import '../../../core/app_colors.dart';
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
  late final TextEditingController _warningTimerController;
  late final TextEditingController _urgentTimerController;
  late final TextEditingController _finishedDelayController;
  List<KdsOrderType> _orderTypes = const [];
  bool _loadingOrderTypes = true;
  Timer? _timerSaveDebounce;
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _draft = widget.viewModel.settings;
    _warningTimerController = TextEditingController(
      text: _formatTimerInput(_draft.warningThresholdSeconds),
    );
    _urgentTimerController = TextEditingController(
      text: _formatTimerInput(_draft.urgentThresholdSeconds),
    );
    _finishedDelayController = TextEditingController(
      text: _draft.finishedReceiptSeconds.toString(),
    );
    _loadOrderTypes();
  }

  @override
  void dispose() {
    _timerSaveDebounce?.cancel();
    _warningTimerController.dispose();
    _urgentTimerController.dispose();
    _finishedDelayController.dispose();
    super.dispose();
  }

  void _scheduleTimerSave() {
    _timerSaveDebounce?.cancel();
    _timerSaveDebounce = Timer(
      const Duration(milliseconds: 650),
      () => unawaited(_saveTimerThresholds()),
    );
  }

  Future<void> _saveTimerThresholds({
    bool showValidationMessage = false,
  }) async {
    final warningThresholdSeconds = _parseTimerInput(
      _warningTimerController.text,
    );
    final urgentThresholdSeconds = _parseTimerInput(
      _urgentTimerController.text,
    );
    final finishedReceiptSeconds = int.tryParse(
      _finishedDelayController.text.trim(),
    );
    if (warningThresholdSeconds == null ||
        urgentThresholdSeconds == null ||
        finishedReceiptSeconds == null ||
        warningThresholdSeconds <= 0 ||
        warningThresholdSeconds >= urgentThresholdSeconds ||
        finishedReceiptSeconds < 1 ||
        finishedReceiptSeconds > 300) {
      if (showValidationMessage) {
        _message(
          'Use valid timers. Finished receipt delay must be 1 to 300 seconds.',
        );
      }
      return;
    }
    _normaliseTimerInput(_warningTimerController, warningThresholdSeconds);
    _normaliseTimerInput(_urgentTimerController, urgentThresholdSeconds);
    await _update(
      _draft.copyWith(
        warningMinutes: warningThresholdSeconds ~/ 60,
        warningSeconds: warningThresholdSeconds % 60,
        urgentMinutes: urgentThresholdSeconds ~/ 60,
        urgentSeconds: urgentThresholdSeconds % 60,
        finishedReceiptSeconds: finishedReceiptSeconds,
      ),
    );
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _update(KdsSettings value) {
    setState(() => _draft = value);
    _saveQueue = _saveQueue.then((_) async {
      try {
        await widget.viewModel.saveSettings(value);
      } on FormatException catch (error) {
        _restoreUnsavedValue(value);
        if (mounted) _message(error.message);
      } on Object {
        _restoreUnsavedValue(value);
        if (mounted) _message('Unable to save settings on this display.');
      }
    });
    return _saveQueue;
  }

  void _restoreUnsavedValue(KdsSettings failedValue) {
    if (!mounted || !identical(_draft, failedValue)) return;
    final restored = widget.viewModel.settings;
    setState(() => _draft = restored);
    _warningTimerController.text = _formatTimerInput(
      restored.warningThresholdSeconds,
    );
    _urgentTimerController.text = _formatTimerInput(
      restored.urgentThresholdSeconds,
    );
    _finishedDelayController.text = restored.finishedReceiptSeconds.toString();
  }

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

  Future<void> _removeOrderType(KdsOrderType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${type.name}?'),
        content: const Text(
          'This hides the type and matching receipts on this display only. The POS and its order data are not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await widget.viewModel.removeOrderType(type);
    if (!mounted) return;
    setState(() {
      _orderTypes = _orderTypes
          .where((orderType) => orderType.id != type.id)
          .toList(growable: false);
      _draft = _draft.withOrderTypeVisibility(
        id: type.id,
        name: type.name,
        visible: false,
      );
    });
    _message('${type.name} removed from this display.');
  }

  Future<String?> _showOrderTypeIconPicker(KdsOrderType type) =>
      showModalBottomSheet<String>(
        context: context,
        backgroundColor: AppColors.surface,
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
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'This icon is used on the receipt and dashboard.',
                    style: TextStyle(color: AppColors.mutedText),
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
                        color: AppColors.mutedText,
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

  Future<void> _chooseAlertTemplate({required bool urgent}) async {
    final selected = await showModalBottomSheet<KdsAlertTone>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final activeTone = urgent
            ? _draft.urgentOrderTone
            : _draft.newOrderTone;
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.78,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose ${urgent ? 'urgent-order' : 'new-order'} sound',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 12),
                    children: [
                      for (final tone in KdsAlertTone.templatesFor(
                        urgent: urgent,
                      ))
                        ListTile(
                          leading: Icon(_alertToneIcon(tone)),
                          title: Text(tone.label),
                          subtitle: Text(tone.description),
                          trailing: tone == activeTone
                              ? const Icon(Icons.check_circle_rounded)
                              : null,
                          onTap: () => Navigator.pop(context, tone),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    await _update(
      urgent
          ? _draft.copyWith(urgentOrderTone: selected)
          : _draft.copyWith(newOrderTone: selected),
    );
  }

  Future<void> _testAlertSound({required bool urgent}) async {
    try {
      await (urgent
          ? widget.viewModel.testUrgentOrderSound(tone: _draft.urgentOrderTone)
          : widget.viewModel.testNewOrderSound(tone: _draft.newOrderTone));
    } on Object {
      _message('Unable to play the alert sound.');
    }
  }

  IconData _alertToneIcon(KdsAlertTone tone) => switch (tone) {
    KdsAlertTone.chime => Icons.music_note_rounded,
    KdsAlertTone.bell => Icons.notifications_outlined,
    KdsAlertTone.pulse => Icons.graphic_eq_rounded,
    KdsAlertTone.call => Icons.ring_volume_outlined,
    KdsAlertTone.alert => Icons.notification_important_outlined,
    KdsAlertTone.priority => Icons.campaign_outlined,
    KdsAlertTone.urgentPulse => Icons.notifications_active_outlined,
    KdsAlertTone.urgentCall => Icons.ring_volume_rounded,
  };

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.primaryMuted,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        outline: AppColors.outline,
      ),
      scaffoldBackgroundColor: AppColors.canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.text,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceRaised,
        labelStyle: TextStyle(color: AppColors.mutedText),
        suffixStyle: TextStyle(color: AppColors.mutedText),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.mutedText,
        textColor: AppColors.text,
        subtitleTextStyle: TextStyle(color: AppColors.mutedText),
      ),
      filledButtonTheme: const FilledButtonThemeData(
        style: AppButtonStyles.filled,
      ),
      outlinedButtonTheme: const OutlinedButtonThemeData(
        style: AppButtonStyles.outlined,
      ),
      textButtonTheme: const TextButtonThemeData(style: AppButtonStyles.text),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0xFFFFFFFF)
              : AppColors.disabled,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.outline,
        ),
      ),
    ),
    child: Scaffold(
      appBar: AppBar(title: const Text('Display settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Text(
              'Changes save automatically to this display.',
              style: TextStyle(color: AppColors.mutedText),
            ),
          ),
          _Section(
            title: 'Order types',
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Use the switch to show a type on the dashboard. Tap a type to change its icon.',
                ),
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
                      backgroundColor: AppColors.primarySoft,
                      foregroundColor: AppColors.text,
                      child: Icon(orderTypeIconFor(type.icon)),
                    ),
                    title: Text(
                      type.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${_draft.isOrderTypeVisible(id: type.id, name: type.name) ? 'Shown on dashboard' : 'Hidden from dashboard'} \u00b7 ${orderTypeIconOptionFor(type.icon).label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: _draft.isOrderTypeVisible(
                            id: type.id,
                            name: type.name,
                          ),
                          onChanged: (visible) => unawaited(
                            _update(
                              _draft.withOrderTypeVisibility(
                                id: type.id,
                                name: type.name,
                                visible: visible,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove ${type.name}',
                          onPressed: () => _removeOrderType(type),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
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
                builder: (context, constraints) => constraints.maxWidth < 520
                    ? Column(
                        children: [
                          _timerThresholdFields(
                            label: 'Yellow starts at',
                            controller: _warningTimerController,
                          ),
                          const SizedBox(height: 12),
                          _timerThresholdFields(
                            label: 'Red starts at',
                            controller: _urgentTimerController,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _timerThresholdFields(
                              label: 'Yellow starts at',
                              controller: _warningTimerController,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _timerThresholdFields(
                              label: 'Red starts at',
                              controller: _urgentTimerController,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _finishedDelayController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  onTap: () =>
                      _finishedDelayController.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: _finishedDelayController.text.length,
                      ),
                  onChanged: (_) => _scheduleTimerSave(),
                  onSubmitted: (_) => unawaited(
                    _saveTimerThresholds(showValidationMessage: true),
                  ),
                  onTapOutside: (_) => unawaited(
                    _saveTimerThresholds(showValidationMessage: true),
                  ),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Finished receipt delay (seconds)',
                    helperText: 'How long Finished stays visible (1–300).',
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Type four digits (for example, 1000 becomes 10:00). Yellow must be above 00:00 and before red.',
              ),
              const SizedBox(height: 16),
              _TimerPreview(
                warningSeconds: _draft.warningThresholdSeconds,
                urgentSeconds: _draft.urgentThresholdSeconds,
              ),
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
                    unawaited(_update(_draft.copyWith(newOrderAlert: value))),
              ),
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('New-order sound'),
                subtitle: Text(
                  'Template: ${_draft.newOrderTone.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _chooseAlertTemplate(urgent: false),
              ),
              SwitchListTile(
                title: const Text('Urgent-order alert'),
                subtitle: const Text(
                  'Play once when an active order reaches the red timer.',
                ),
                value: _draft.urgentOrderAlert,
                onChanged: (value) => unawaited(
                  _update(_draft.copyWith(urgentOrderAlert: value)),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.crisis_alert_outlined),
                title: const Text('Urgent-order sound'),
                subtitle: Text(
                  'Template: ${_draft.urgentOrderTone.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _chooseAlertTemplate(urgent: true),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  'Choose a KDS sound template for each event. Alert loudness follows the device sound level.',
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _testAlertSound(urgent: false),
                      icon: const Icon(Icons.volume_up_outlined),
                      label: const Text('Test new-order sound'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _testAlertSound(urgent: true),
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text('Test urgent sound'),
                    ),
                  ],
                ),
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
          const SizedBox(height: 24),
        ],
      ),
    ),
  );

  Widget _timerThresholdFields({
    required String label,
    required TextEditingController controller,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      _timerField(controller),
    ],
  );

  Widget _timerField(TextEditingController controller) => TextField(
    controller: controller,
    keyboardType: TextInputType.datetime,
    inputFormatters: const [_TimerInputFormatter()],
    onTap: () => controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    ),
    onChanged: (_) => _scheduleTimerSave(),
    onSubmitted: (_) =>
        unawaited(_saveTimerThresholds(showValidationMessage: true)),
    onTapOutside: (_) =>
        unawaited(_saveTimerThresholds(showValidationMessage: true)),
    decoration: InputDecoration(
      border: const OutlineInputBorder(),
      labelText: 'MM:SS',
      hintText: '05:00',
    ),
  );

  void _normaliseTimerInput(
    TextEditingController controller,
    int totalSeconds,
  ) {
    final formatted = _formatTimerInput(totalSeconds);
    if (controller.text == formatted) return;
    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

int? _parseTimerInput(String value) {
  final match = RegExp(r'^(\d+):(\d{1,2})$').firstMatch(value.trim());
  if (match == null) return null;
  final minutes = int.tryParse(match.group(1)!);
  final seconds = int.tryParse(match.group(2)!);
  if (minutes == null || seconds == null || minutes < 0 || seconds >= 60) {
    return null;
  }
  return minutes * 60 + seconds;
}

String _formatTimerInput(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

class _TimerInputFormatter extends TextInputFormatter {
  const _TimerInputFormatter();

  static final _digitsOnly = RegExp(r'^\d*$');
  static final _partialTimer = RegExp(r'^\d{0,2}:\d{0,2}$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    if (_digitsOnly.hasMatch(text)) {
      if (text.length > 4) return oldValue;
      if (text.length == 1) return newValue;
      final formatted = '${text.substring(0, 2)}:${text.substring(2)}';
      final seconds = text.length > 2 ? int.tryParse(text.substring(2)) : null;
      if (seconds != null && seconds >= 60) return oldValue;
      return newValue.copyWith(
        text: formatted,
        selection: TextSelection.collapsed(offset: newValue.selection.end + 1),
      );
    }

    if (!_partialTimer.hasMatch(text)) return oldValue;

    final segments = text.split(':');
    final seconds = segments.length == 2 ? int.tryParse(segments.last) : null;
    if (seconds != null && seconds >= 60) return oldValue;
    return newValue;
  }
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
      color: selected ? AppColors.primarySoft : AppColors.surfaceRaised,
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
                Icon(option.icon, color: AppColors.text),
                const SizedBox(height: 7),
                Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
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
  const _TimerPreview({
    required this.warningSeconds,
    required this.urgentSeconds,
  });

  final int warningSeconds;
  final int urgentSeconds;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const _Preview(
        color: Color(0xFF02D53C),
        foregroundColor: Color(0xFF05090C),
        label: '00:00:00',
      ),
      const SizedBox(width: 8),
      _Preview(
        color: Color(0xFFFFEF00),
        foregroundColor: Color(0xFF05090C),
        label: _formatTimer(warningSeconds),
      ),
      const SizedBox(width: 8),
      _Preview(
        color: Color(0xFFFF1C2C),
        foregroundColor: Color(0xFF05090C),
        label: _formatTimer(urgentSeconds),
      ),
    ],
  );
}

String _formatTimer(int totalSeconds) {
  final duration = Duration(seconds: totalSeconds);
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.color,
    required this.foregroundColor,
    required this.label,
  });
  final Color color;
  final Color foregroundColor;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0x33000000)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w900,
          letterSpacing: .4,
        ),
      ),
    ),
  );
}
