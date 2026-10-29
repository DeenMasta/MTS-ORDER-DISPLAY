import 'package:flutter/material.dart';

import '../../../../domain/models/display_session.dart';
import '../../../../domain/models/kitchen_ticket.dart';
import '../view_models/kitchen_board_view_model.dart';

class KitchenBoardScreen extends StatefulWidget {
  const KitchenBoardScreen({
    super.key,
    required this.viewModel,
    required this.session,
  });

  final KitchenBoardViewModel viewModel;
  final DisplaySession session;

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
    appBar: AppBar(
      title: const Text('Kitchen display'),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Order type icons',
          onPressed: () => _showOrderTypeIcons(context, widget.viewModel),
        ),
      ],
    ),
    body: ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, child) {
        if (widget.viewModel.loading && widget.viewModel.tickets.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (widget.viewModel.error case final error?) {
          return Center(
            child: FilledButton(
              onPressed: () => widget.viewModel.start(widget.session),
              child: Text(error),
            ),
          );
        }
        if (!widget.viewModel.isPaired) {
          final code = widget.viewModel.pairingCode;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    code == null
                        ? 'Connecting to POS…'
                        : 'Confirm this code in POS',
                  ),
                  if (code != null)
                    Text(
                      code,
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                ],
              ),
            ),
          );
        }
        if (widget.viewModel.tickets.isEmpty) {
          return const Center(child: Text('No active kitchen tickets.'));
        }
        final ticketGroups = groupKitchenTicketsByOrder(
          widget.viewModel.tickets,
        );
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: ticketGroups.length,
          itemBuilder: (context, index) => _TicketCard(
            tickets: ticketGroups[index],
            onDismiss: () async {
              for (final ticket in ticketGroups[index]) {
                await widget.viewModel.dismiss(ticket.id);
              }
            },
          ),
        );
      },
    ),
  );
}

Future<void> _showOrderTypeIcons(
  BuildContext context,
  KitchenBoardViewModel viewModel,
) => showModalBottomSheet<void>(
  context: context,
  builder: (context) => FutureBuilder<List<KdsOrderType>>(
    future: viewModel.orderTypes(),
    builder: (context, snapshot) => ListView(
      children: [
        const ListTile(title: Text('Order type icons')),
        for (final type in snapshot.data ?? const <KdsOrderType>[])
          ListTile(
            title: Text(type.name),
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
              onChanged: (icon) async {
                if (icon == null) return;
                await viewModel.updateOrderTypeIcon(type.id, icon);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ),
      ],
    ),
  ),
);

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.tickets, required this.onDismiss});

  final List<KitchenTicket> tickets;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final ticket = tickets.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${ticket.orderNumber}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close),
                  tooltip: 'Dismiss locally',
                ),
              ],
            ),
            if (ticket.orderTypeName case final orderType?) Text(orderType),
            if (ticket.tableName case final tableName?)
              Text('Table $tableName'),
            if (ticket.staffName case final staffName?)
              Text('Ordered by: $staffName'),
            if (ticket.orderFor case final orderFor?)
              Text('Order for: $orderFor'),
            const Divider(),
            ...tickets
                .expand((ticket) => ticket.items)
                .map(
                  (item) => Text(
                    '${item.displayQuantity} × ${item.name}${item.comments == null || item.comments!.isEmpty ? '' : '\n${item.comments}'}',
                  ),
                ),
            ...tickets
                .expand((ticket) => ticket.items)
                .where(
                  (item) => item.variant != null || item.modifiers.isNotEmpty,
                )
                .map(
                  (item) => Text(
                    '${item.variant == null || item.variant!.isEmpty ? '' : item.variant!}'
                    '${item.variant == null || item.variant!.isEmpty || item.modifiers.isEmpty ? '' : ' - '}'
                    '${item.modifiers.join(', ')}',
                  ),
                ),
            if (ticket.displayRemarks case final remarks?)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(remarks),
              ),
            if (ticket.enteredAt case final enteredAt?)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(enteredAt.toLocal().toString()),
              ),
          ],
        ),
      ),
    );
  }
}
