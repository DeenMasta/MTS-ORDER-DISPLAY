import 'package:flutter/material.dart';

import '../../../../domain/models/kitchen_ticket.dart';
import '../view_models/kitchen_board_view_model.dart';

class KitchenHistoryScreen extends StatefulWidget {
  const KitchenHistoryScreen({super.key, required this.viewModel});

  final KitchenBoardViewModel viewModel;

  @override
  State<KitchenHistoryScreen> createState() => _KitchenHistoryScreenState();
}

class _KitchenHistoryScreenState extends State<KitchenHistoryScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.loadTodayHistory();
  }

  Future<void> _restoreToDashboard(List<KitchenTicket> tickets) async {
    await widget.viewModel.undoLocalCompletion(tickets);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F5F0),
    body: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/kds_background.png',
            fit: BoxFit.cover,
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 420;
                    return Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          color: const Color(0xFF17212B),
                        ),
                        SizedBox(width: compact ? 2 : 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order history',
                                style: TextStyle(
                                  color: const Color(0xFF17212B),
                                  fontSize: compact ? 18 : 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Today only — resets at midnight',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF52616B),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Image.asset(
                          'assets/images/mysztech_logo.png',
                          height: compact ? 20 : 28,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListenableBuilder(
                    listenable: widget.viewModel,
                    builder: (context, _) {
                      final groups = widget.viewModel.todayHistoryGroups;
                      if (groups.isEmpty) return const _EmptyHistory();
                      return RefreshIndicator(
                        color: const Color(0xFFA44C2E),
                        onRefresh: widget.viewModel.loadTodayHistory,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: groups.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final tickets = groups[index];
                            return _HistoryReceipt(
                              tickets: tickets,
                              finished: widget.viewModel.isCompletedLocally(
                                tickets,
                              ),
                              onTap: () => _restoreToDashboard(tickets),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.receipt_long_outlined, color: Color(0xFF52616B), size: 42),
        SizedBox(height: 12),
        Text(
          'No orders in today’s history.',
          style: TextStyle(color: Color(0xFF17212B), fontSize: 16),
        ),
        SizedBox(height: 6),
        Text(
          'Stored receipts are kept on this device.',
          style: TextStyle(color: Color(0xFF52616B), fontSize: 12),
        ),
      ],
    ),
  );
}

class _HistoryReceipt extends StatelessWidget {
  const _HistoryReceipt({
    required this.tickets,
    required this.finished,
    required this.onTap,
  });

  final List<KitchenTicket> tickets;
  final bool finished;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ticket = tickets.first;
    final items = tickets.expand((ticket) => ticket.items).toList();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD5DAD8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '#${ticket.orderNumber}',
                  style: const TextStyle(
                    color: const Color(0xFF17212B),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                if (finished) ...[
                  const SizedBox(width: 8),
                  const _FinishedBadge(),
                ],
                const Spacer(),
                Text(
                  _timeLabel(ticket.createdAt.toLocal()),
                  style: const TextStyle(
                    color: Color(0xFFA44C2E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.restore_rounded, color: Color(0xFF52616B)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                ticket.orderTypeName?.toUpperCase() ?? 'ORDER',
                if (ticket.tableName case final table? when table.isNotEmpty)
                  'Table $table',
              ].join('  •  '),
              style: const TextStyle(
                color: Color(0xFF52616B),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: Color(0xFFD5DAD8), height: 1),
            ),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${item.displayQuantity}x  ${item.name}',
                  style: const TextStyle(
                    color: Color(0xFF17212B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _FinishedBadge extends StatelessWidget {
  const _FinishedBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFF0D6E52),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Text(
      'FINISHED',
      style: TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: .5,
      ),
    ),
  );
}

class KitchenHistoryDetailScreen extends StatelessWidget {
  const KitchenHistoryDetailScreen({
    super.key,
    required this.tickets,
    required this.finished,
  });

  final List<KitchenTicket> tickets;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final ticket = tickets.first;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/kds_background.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 380;
                      return Row(
                        children: [
                          IconButton(
                            tooltip: 'Back to order history',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                            color: const Color(0xFF17212B),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Order #${ticket.orderNumber}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: const Color(0xFF17212B),
                                fontSize: compact ? 17 : 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Image.asset(
                            'assets/images/mysztech_logo.png',
                            height: compact ? 20 : 28,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          color: const Color(0xFFF9FAFB),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                                color: Colors.black,
                                child: Row(
                                  children: [
                                    Text(
                                      '#${ticket.orderNumber}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (finished)
                                      const _HistoryDetailStatus(
                                        label: 'FINISHED',
                                        color: Color(0xFF0D8A62),
                                      )
                                    else
                                      const _HistoryDetailStatus(
                                        label: 'IN HISTORY',
                                        color: Color(0xFFA44C2E),
                                      ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ticket.orderTypeName?.toUpperCase() ??
                                          'ORDER',
                                      style: const TextStyle(
                                        color: Color(0xFF111827),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    _HistoryDetailLine(
                                      label: 'Date & time',
                                      value: _historyDateTime(
                                        ticket.enteredAt ?? ticket.createdAt,
                                      ),
                                    ),
                                    if (ticket.tableName case final table?
                                        when table.isNotEmpty)
                                      _HistoryDetailLine(
                                        label: 'Table',
                                        value: table,
                                      ),
                                    if (ticket.displayOrderer
                                        case final orderer?)
                                      _HistoryDetailLine(
                                        label: 'Ordered by',
                                        value: orderer,
                                      ),
                                    if (ticket.orderFor case final orderFor?)
                                      _HistoryDetailLine(
                                        label: 'Order for',
                                        value: orderFor,
                                      ),
                                    if (ticket.displayRemarks
                                        case final remarks?)
                                      _HistoryDetailLine(
                                        label: 'Remarks',
                                        value: remarks,
                                      ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Divider(
                                        color: Color(0xFFCBD5E1),
                                        height: 1,
                                      ),
                                    ),
                                    const Text(
                                      'ITEMS',
                                      style: TextStyle(
                                        color: Color(0xFF475569),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    for (final orderTicket in tickets)
                                      for (final item in orderTicket.items)
                                        _HistoryItem(item: item),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryDetailStatus extends StatelessWidget {
  const _HistoryDetailStatus({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: .7,
      ),
    ),
  );
}

class _HistoryDetailLine extends StatelessWidget {
  const _HistoryDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.item});

  final KitchenTicketItem item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${item.displayQuantity}x  ${item.name}',
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (item.variant case final variant? when variant.isNotEmpty)
          _HistoryItemDetail(value: variant),
        for (final modifier in item.modifiers)
          _HistoryItemDetail(value: '- $modifier'),
        if (item.comments case final comments? when comments.isNotEmpty)
          _HistoryItemDetail(value: 'Notes: $comments'),
      ],
    ),
  );
}

class _HistoryItemDetail extends StatelessWidget {
  const _HistoryItemDetail({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 24, top: 3),
    child: Text(value, style: const TextStyle(color: Color(0xFF475569))),
  );
}

String _historyDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}  $hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
}
