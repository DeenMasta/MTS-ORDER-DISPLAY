import 'package:flutter/material.dart';

import '../../../../domain/models/display_session.dart';
import '../../../../domain/models/kds_settings.dart';
import '../../../../domain/models/kitchen_ticket.dart';
import '../view_models/kitchen_board_view_model.dart';
import 'kitchen_settings_screen.dart';

class KitchenBoardScreen extends StatefulWidget {
  const KitchenBoardScreen({
    super.key,
    required this.viewModel,
    required this.session,
    required this.onChangeConnection,
  });
  final KitchenBoardViewModel viewModel;
  final DisplaySession session;
  final Future<void> Function() onChangeConnection;

  @override
  State<KitchenBoardScreen> createState() => _KitchenBoardScreenState();
}

class _KitchenBoardScreenState extends State<KitchenBoardScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.start(widget.session);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF030B15),
    body: Stack(
      children: [
        const Positioned.fill(child: _BrandPatternBackground()),
        SafeArea(
          child: ListenableBuilder(
            listenable: widget.viewModel,
            builder: (context, _) => _KitchenBoardBody(
              viewModel: widget.viewModel,
              session: widget.session,
              onChangeConnection: widget.onChangeConnection,
            ),
          ),
        ),
      ],
    ),
  );
}

class _BrandPatternBackground extends StatelessWidget {
  const _BrandPatternBackground();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const tileWidth = 230.0;
      const tileHeight = 155.0;
      final columns = (constraints.maxWidth / tileWidth).ceil() + 1;
      final rows = (constraints.maxHeight / tileHeight).ceil() + 1;
      return IgnorePointer(
        child: ClipRect(
          child: Stack(
            children: [
              for (var row = 0; row < rows; row++)
                for (var column = 0; column < columns; column++)
                  Positioned(
                    left: column * tileWidth - 45 + (row.isOdd ? 45 : 0),
                    top: row * tileHeight - 30,
                    child: Transform.rotate(
                      angle: -.20,
                      child: Opacity(
                        opacity: .075,
                        child: Image.asset(
                          'assets/images/mysztech_logo.png',
                          width: 185,
                        ),
                      ),
                    ),
                  ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xAA030B15), Color(0xDD030B15)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _KitchenBoardBody extends StatelessWidget {
  const _KitchenBoardBody({
    required this.viewModel,
    required this.session,
    required this.onChangeConnection,
  });
  final KitchenBoardViewModel viewModel;
  final DisplaySession session;
  final Future<void> Function() onChangeConnection;

  @override
  Widget build(BuildContext context) {
    if (viewModel.loading && viewModel.tickets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.error case final error?) {
      return _StatusMessage(
        message: error,
        actionLabel: 'Retry connection',
        onAction: () => viewModel.start(session),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            _Header(
              orderCount: viewModel.ticketGroups.length,
              onSettings: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => KitchenSettingsScreen(
                    viewModel: viewModel,
                    session: session,
                    onChangeConnection: onChangeConnection,
                  ),
                ),
              ),
              onHistory: () => _showHistoryUnavailable(context),
            ),
            if (!viewModel.isPaired) ...[
              const SizedBox(height: 12),
              _ConnectionStatus(code: viewModel.pairingCode),
            ],
            const SizedBox(height: 28),
            _FilterBar(viewModel: viewModel),
            const SizedBox(height: 28),
            Expanded(
              child: viewModel.visibleTicketGroups.isEmpty
                  ? const Center(
                      child: Text(
                        'No active kitchen tickets.',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    )
                  : _TicketGrid(
                      groups: viewModel.visibleTicketGroups,
                      iconNameFor: viewModel.orderTypeIconNameFor,
                      settings: viewModel.settings,
                      onDismiss: (tickets) async {
                        for (final ticket in tickets) {
                          await viewModel.dismiss(ticket.id);
                        }
                      },
                    ),
            ),
            const SizedBox(height: 12),
            _Pager(viewModel: viewModel),
          ],
        ),
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.code});

  final String? code;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF152536),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF4A90C2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Text(
          code == null
              ? 'Reconnecting to POS…'
              : 'Confirm this code in POS: $code',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.orderCount,
    required this.onSettings,
    required this.onHistory,
  });
  final int orderCount;
  final VoidCallback onSettings;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) => Container(
    height: 92,
    padding: const EdgeInsets.symmetric(horizontal: 34),
    decoration: BoxDecoration(
      color: const Color(0xDD02070D),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.blueGrey.shade300, width: 2),
    ),
    child: Row(
      children: [
        Text(
          'Orders: ${orderCount.toString().padLeft(2, '0')}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Image.asset('assets/images/mysztech_logo.png', height: 58),
        const Spacer(),
        PopupMenuButton<_HeaderAction>(
          tooltip: 'Display menu',
          icon: const Icon(Icons.menu, color: Colors.white, size: 38),
          onSelected: (value) {
            switch (value) {
              case _HeaderAction.liveOrders:
                break;
              case _HeaderAction.history:
                onHistory();
              case _HeaderAction.settings:
                onSettings();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _HeaderAction.liveOrders,
              child: ListTile(
                leading: Icon(Icons.receipt_long_outlined),
                title: Text('Live orders'),
              ),
            ),
            PopupMenuItem(
              value: _HeaderAction.history,
              child: ListTile(
                leading: Icon(Icons.history),
                title: Text('Order history'),
              ),
            ),
            PopupMenuItem(
              value: _HeaderAction.settings,
              child: ListTile(
                leading: Icon(Icons.settings_outlined),
                title: Text('Settings'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

enum _HeaderAction { liveOrders, history, settings }

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.viewModel});
  final KitchenBoardViewModel viewModel;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 24,
    runSpacing: 12,
    children: viewModel.availableFilters
        .map(
          (filter) => ChoiceChip(
            label: Text(filter.label.toUpperCase()),
            selected: viewModel.filter == filter,
            onSelected: (_) => viewModel.selectFilter(filter),
            labelStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: viewModel.filter == filter ? Colors.white : Colors.black,
            ),
            selectedColor: Colors.black,
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
            shape: const StadiumBorder(),
          ),
        )
        .toList(growable: false),
  );
}

class _TicketGrid extends StatelessWidget {
  const _TicketGrid({
    required this.groups,
    required this.onDismiss,
    required this.iconNameFor,
    required this.settings,
  });
  final List<List<KitchenTicket>> groups;
  final ValueChanged<List<KitchenTicket>> onDismiss;
  final String Function(KitchenTicket) iconNameFor;
  final KdsSettings settings;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1050
          ? 3
          : constraints.maxWidth >= 650
          ? 2
          : 1;
      return GridView.builder(
        itemCount: groups.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 28,
          mainAxisSpacing: 28,
          childAspectRatio: columns == 1
              ? 1.15
              : settings.compactCards
              ? .83
              : .70,
        ),
        itemBuilder: (context, index) => _TicketCard(
          tickets: groups[index],
          onDismiss: () => onDismiss(groups[index]),
          iconName: iconNameFor(groups[index].first),
          settings: settings,
        ),
      );
    },
  );
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.tickets,
    required this.onDismiss,
    required this.iconName,
    required this.settings,
  });
  final List<KitchenTicket> tickets;
  final VoidCallback onDismiss;
  final String iconName;
  final KdsSettings settings;
  @override
  Widget build(BuildContext context) {
    final ticket = tickets.first;
    final elapsed = DateTime.now().difference(ticket.createdAt.toLocal());
    final accent = elapsed.inMinutes >= settings.urgentMinutes
        ? const Color(0xFFFF1C2C)
        : elapsed.inMinutes >= settings.warningMinutes
        ? const Color(0xFFFFEF00)
        : const Color(0xFF02D53C);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFFFAFAFA),
      child: Column(
        children: [
          Container(
            height: 76,
            padding: const EdgeInsets.only(left: 30, right: 10),
            color: Colors.black,
            child: Row(
              children: [
                Text(
                  '#${ticket.orderNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Container(
                  height: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  color: accent,
                  alignment: Alignment.center,
                  child: Text(
                    _formatDuration(elapsed),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 29,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 25, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (settings.showTypeIcons) ...[
                        Icon(_orderTypeIcon(iconName), size: 26),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          ticket.orderTypeName?.toUpperCase() ?? 'ORDER',
                          style: TextStyle(
                            fontSize: settings.largeText ? 25 : 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (ticket.tableName case final table?)
                        Text(
                          'Table $table',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 34, thickness: 1.5),
                  if (ticket.displayOrderer case final orderer?)
                    Text('Ordered by: $orderer', style: _detailStyle),
                  if (ticket.orderFor case final orderFor?)
                    Text('Order for: $orderFor', style: _detailStyle),
                  if (ticket.displayRemarks case final remarks?)
                    Text('Remarks: $remarks', style: _detailStyle),
                  const Divider(height: 28, thickness: 1.5),
                  Expanded(
                    child: _Items(
                      tickets: tickets,
                      largeText: settings.largeText,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatDate(ticket.enteredAt ?? ticket.createdAt),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF52525B),
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onDismiss,
                        tooltip: 'Dismiss locally',
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _detailStyle = TextStyle(color: Color(0xFF45454D), fontSize: 17);

class _Items extends StatelessWidget {
  const _Items({required this.tickets, required this.largeText});
  final List<KitchenTicket> tickets;
  final bool largeText;
  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.zero,
    children: [
      for (final item in tickets.expand((ticket) => ticket.items)) ...[
        Text(
          '${item.displayQuantity}x  ${item.name}',
          style: TextStyle(
            fontSize: largeText ? 26 : 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (item.variant case final variant? when variant.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 45, top: 3),
            child: Text(variant, style: _detailStyle),
          ),
        for (final modifier in item.modifiers)
          Padding(
            padding: const EdgeInsets.only(left: 45, top: 3),
            child: Text('- $modifier', style: _detailStyle),
          ),
        if (item.comments case final comments? when comments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 45, top: 3),
            child: Text(comments, style: _detailStyle),
          ),
        const SizedBox(height: 9),
      ],
    ],
  );
}

class _Pager extends StatelessWidget {
  const _Pager({required this.viewModel});
  final KitchenBoardViewModel viewModel;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        onPressed: viewModel.page == 0 ? null : viewModel.showPreviousPage,
        icon: const Icon(Icons.chevron_left, color: Colors.white),
      ),
      ...List.generate(
        viewModel.pageCount,
        (index) => Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == viewModel.page ? Colors.white : Colors.transparent,
            border: Border.all(color: Colors.white),
          ),
        ),
      ),
      IconButton(
        onPressed: viewModel.page >= viewModel.pageCount - 1
            ? null
            : viewModel.showNextPage,
        icon: const Icon(Icons.chevron_right, color: Colors.white),
      ),
    ],
  );
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 20),
        ),
        if (onAction != null) ...[
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}

Future<void> _showHistoryUnavailable(
  BuildContext context,
) => showModalBottomSheet<void>(
  context: context,
  builder: (context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order history',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        Text(
          'History requires a POS history contract. The current LAN protocol '
          'sends live orders only, so no historical data is fabricated here.',
        ),
      ],
    ),
  ),
);

IconData _orderTypeIcon(String name) => switch (name) {
  'table_restaurant' => Icons.table_restaurant,
  'takeout_dining' => Icons.takeout_dining,
  'delivery_dining' => Icons.delivery_dining,
  _ => Icons.restaurant,
};
String _formatDuration(Duration value) {
  final seconds = value.isNegative ? 0 : value.inSeconds;
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(seconds ~/ 3600)}:${two((seconds % 3600) ~/ 60)}:${two(seconds % 60)}';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}  $hour:${local.minute.toString().padLeft(2, '0')} ${local.hour >= 12 ? 'PM' : 'AM'}';
}
