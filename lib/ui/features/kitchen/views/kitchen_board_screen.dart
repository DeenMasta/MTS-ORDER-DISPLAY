import 'package:flutter/material.dart';

import '../../../../domain/models/display_session.dart';
import '../../../../domain/models/kitchen_ticket.dart';
import '../view_models/kitchen_board_view_model.dart';

class KitchenBoardScreen extends StatefulWidget {
  const KitchenBoardScreen({super.key, required this.viewModel, required this.session});

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
    appBar: AppBar(title: const Text('Kitchen display')),
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
        if (widget.viewModel.tickets.isEmpty) {
          return const Center(child: Text('No active kitchen tickets.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: widget.viewModel.tickets.length,
          itemBuilder: (context, index) => _TicketCard(
            ticket: widget.viewModel.tickets[index],
            onDismiss: () => widget.viewModel.dismiss(widget.viewModel.tickets[index].id),
          ),
        );
      },
    ),
  );
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onDismiss});

  final KitchenTicket ticket;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Card(
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
          if (ticket.tableName case final tableName?) Text(tableName),
          if (ticket.orderName case final orderName?) Text(orderName),
          const Divider(),
          ...ticket.items.map(
            (item) => Text(
              '${item.quantity} × ${item.name}${item.comments == null || item.comments!.isEmpty ? '' : '\n${item.comments}'}',
            ),
          ),
          if (ticket.remarks case final remarks?)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(remarks),
            ),
        ],
      ),
    ),
  );
}
