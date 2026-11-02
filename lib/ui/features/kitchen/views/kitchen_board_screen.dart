import 'package:flutter/material.dart';

import '../../../../domain/models/display_session.dart';
import '../../../../domain/models/kds_settings.dart';
import '../../../../domain/models/kitchen_ticket.dart';
import '../view_models/kitchen_board_view_model.dart';
import 'kitchen_settings_screen.dart';
import 'slanted_timer_clipper.dart';

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
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset('assets/images/kds_background.png', fit: BoxFit.cover),
      const ColoredBox(color: Color(0x9900060D)),
    ],
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
    if (viewModel.error case final error? when viewModel.tickets.isEmpty) {
      return _StatusMessage(
        message: error,
        detail:
            'Check that POS at ${session.posIp}:8080 is online and on the same Wi-Fi.',
        actionLabel: 'Retry connection',
        onAction: () => viewModel.start(session),
        secondaryActionLabel: 'Change POS connection',
        onSecondaryAction: onChangeConnection,
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: _FilterBar(viewModel: viewModel),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: viewModel.visibleTicketGroups.isEmpty
                ? const Center(
                    child: Text(
                      'No active kitchen tickets.',
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                  )
                : _TicketPager(
                    viewModel: viewModel,
                    groups: viewModel.ticketGroups,
                    iconNameFor: viewModel.orderTypeIconNameFor,
                    settings: viewModel.settings,
                    isCrossed: viewModel.isItemCrossed,
                    onToggle: viewModel.toggleItemCrossed,
                    completionSecondsRemaining:
                        viewModel.completionSecondsRemaining,
                    onComplete: viewModel.completeLocally,
                  ),
          ),
          const SizedBox(height: 6),
          _Pager(viewModel: viewModel),
        ],
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
    height: 58,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: const Color(0xDD02070D),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.blueGrey.shade300),
    ),
    child: Row(
      children: [
        Text(
          'Orders: ${orderCount.toString().padLeft(2, '0')}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Image.asset('assets/images/mysztech_logo.png', height: 37),
        const Spacer(),
        PopupMenuTheme(
          data: PopupMenuThemeData(
            color: const Color(0xFF0D263A),
            surfaceTintColor: Colors.transparent,
            textStyle: const TextStyle(color: Colors.white),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF1B9ED8)),
            ),
          ),
          child: PopupMenuButton<_HeaderAction>(
            tooltip: 'Display menu',
            icon: const Icon(Icons.menu, color: Colors.white, size: 26),
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
                  leading: Icon(
                    Icons.receipt_long_outlined,
                    color: Color(0xFF38BDF8),
                  ),
                  title: Text(
                    'Live orders',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              PopupMenuItem(
                value: _HeaderAction.history,
                child: ListTile(
                  leading: Icon(Icons.history, color: Color(0xFF38BDF8)),
                  title: Text(
                    'Order history',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              PopupMenuItem(
                value: _HeaderAction.settings,
                child: ListTile(
                  leading: Icon(
                    Icons.settings_outlined,
                    color: Color(0xFF38BDF8),
                  ),
                  title: Text(
                    'Settings',
                    style: TextStyle(color: Colors.white),
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

enum _HeaderAction { liveOrders, history, settings }

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.viewModel});
  final KitchenBoardViewModel viewModel;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: viewModel.availableFilters
          .map(
            (filter) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter.label.toUpperCase()),
                selected: viewModel.filter == filter,
                onSelected: (_) => viewModel.selectFilter(filter),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: viewModel.filter == filter
                      ? Colors.white
                      : Colors.black,
                ),
                selectedColor: Colors.black,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 6,
                ),
                shape: const StadiumBorder(),
              ),
            ),
          )
          .toList(growable: false),
    ),
  );
}

class _TicketPager extends StatefulWidget {
  const _TicketPager({
    required this.viewModel,
    required this.groups,
    required this.iconNameFor,
    required this.settings,
    required this.isCrossed,
    required this.onToggle,
    required this.completionSecondsRemaining,
    required this.onComplete,
  });

  final KitchenBoardViewModel viewModel;
  final List<List<KitchenTicket>> groups;
  final String Function(KitchenTicket) iconNameFor;
  final KdsSettings settings;
  final bool Function(KitchenTicket ticket, int itemIndex) isCrossed;
  final void Function(KitchenTicket ticket, int itemIndex) onToggle;
  final int Function(List<KitchenTicket>) completionSecondsRemaining;
  final ValueChanged<List<KitchenTicket>> onComplete;

  @override
  State<_TicketPager> createState() => _TicketPagerState();
}

class _TicketPagerState extends State<_TicketPager> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.viewModel.page);
  }

  @override
  void didUpdateWidget(covariant _TicketPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.hasClients &&
        _controller.page?.round() != widget.viewModel.page) {
      _controller.animateToPage(
        widget.viewModel.page,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView.builder(
    controller: _controller,
    clipBehavior: Clip.hardEdge,
    pageSnapping: true,
    itemCount: widget.viewModel.pageCount,
    onPageChanged: widget.viewModel.showPage,
    itemBuilder: (context, page) => _TicketGrid(
      groups: widget.groups.skip(page * 4).take(4).toList(growable: false),
      iconNameFor: widget.iconNameFor,
      settings: widget.settings,
      isCrossed: widget.isCrossed,
      onToggle: widget.onToggle,
      completionSecondsRemaining: widget.completionSecondsRemaining,
      onComplete: widget.onComplete,
    ),
  );
}

class _TicketGrid extends StatelessWidget {
  const _TicketGrid({
    required this.groups,
    required this.iconNameFor,
    required this.settings,
    required this.isCrossed,
    required this.onToggle,
    required this.completionSecondsRemaining,
    required this.onComplete,
  });
  final List<List<KitchenTicket>> groups;
  final String Function(KitchenTicket) iconNameFor;
  final KdsSettings settings;
  final bool Function(KitchenTicket ticket, int itemIndex) isCrossed;
  final void Function(KitchenTicket ticket, int itemIndex) onToggle;
  final int Function(List<KitchenTicket>) completionSecondsRemaining;
  final ValueChanged<List<KitchenTicket>> onComplete;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900
          ? 4
          : constraints.maxWidth >= 560
          ? 2
          : 1;
      return GridView.builder(
        itemCount: groups.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 1
              ? .62
              : settings.compactCards
              ? .76
              : .62,
        ),
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) => _TicketCard(
          tickets: groups[index],
          iconName: iconNameFor(groups[index].first),
          settings: settings,
          isCrossed: isCrossed,
          onToggle: onToggle,
          secondsRemaining: completionSecondsRemaining(groups[index]),
          onComplete: () => onComplete(groups[index]),
        ),
      );
    },
  );
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.tickets,
    required this.iconName,
    required this.settings,
    required this.isCrossed,
    required this.onToggle,
    required this.secondsRemaining,
    required this.onComplete,
  });
  final List<KitchenTicket> tickets;
  final String iconName;
  final KdsSettings settings;
  final bool Function(KitchenTicket ticket, int itemIndex) isCrossed;
  final void Function(KitchenTicket ticket, int itemIndex) onToggle;
  final int secondsRemaining;
  final VoidCallback onComplete;
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
          SizedBox(
            height: 52,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                ClipPath(
                  clipper: const SlantedTimerClipper(),
                  child: ColoredBox(color: accent),
                ),
                if (secondsRemaining > 0)
                  const ColoredBox(color: Color(0xFF007C58)),
                Semantics(
                  button: secondsRemaining == 0,
                  label: secondsRemaining > 0
                      ? 'Finished. Removing in $secondsRemaining seconds.'
                      : 'Tap receipt header to mark this order finished.',
                  child: InkWell(
                    onTap: secondsRemaining == 0 ? onComplete : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: secondsRemaining > 0
                          ? Center(
                              child: Text(
                                'FINISHED  00:${secondsRemaining.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            )
                          : Row(
                              children: [
                                Text(
                                  '#${ticket.orderNumber}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatDuration(elapsed),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (settings.showTypeIcons) ...[
                        Icon(_orderTypeIcon(iconName), size: 18),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          ticket.orderTypeName?.toUpperCase() ?? 'ORDER',
                          style: TextStyle(
                            fontSize: settings.largeText ? 19 : 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (ticket.tableName case final table?)
                        Text(
                          'Table $table',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 22, thickness: 1),
                  if (ticket.displayOrderer case final orderer?)
                    Text('Ordered by: $orderer', style: _detailStyle),
                  if (ticket.orderFor case final orderFor?)
                    Text('Order for: $orderFor', style: _detailStyle),
                  if (ticket.displayRemarks case final remarks?)
                    Text('Remarks: $remarks', style: _detailStyle),
                  const Divider(height: 18, thickness: 1),
                  _Items(
                    tickets: tickets,
                    largeText: settings.largeText,
                    isCrossed: isCrossed,
                    onToggle: onToggle,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: Center(
              child: Text(
                _formatDate(ticket.enteredAt ?? ticket.createdAt),
                style: const TextStyle(color: Color(0xFF52525B), fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _detailStyle = TextStyle(color: Color(0xFF45454D), fontSize: 12);

class _Items extends StatelessWidget {
  const _Items({
    required this.tickets,
    required this.largeText,
    required this.isCrossed,
    required this.onToggle,
  });
  final List<KitchenTicket> tickets;
  final bool largeText;
  final bool Function(KitchenTicket ticket, int itemIndex) isCrossed;
  final void Function(KitchenTicket ticket, int itemIndex) onToggle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final ticket in tickets)
        for (
          var itemIndex = 0;
          itemIndex < ticket.items.length;
          itemIndex++
        ) ...[
          Builder(
            builder: (context) {
              final item = ticket.items[itemIndex];
              final crossed = isCrossed(ticket, itemIndex);
              return Semantics(
                button: true,
                label: crossed
                    ? '${item.name}, completed. Tap to restore.'
                    : '${item.name}. Tap to cross out.',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => onToggle(ticket, itemIndex),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      '${item.displayQuantity}x  ${item.name}',
                      style: TextStyle(
                        fontSize: largeText ? 20 : 15,
                        fontWeight: FontWeight.w800,
                        color: crossed ? Colors.black45 : null,
                        decoration: crossed ? TextDecoration.lineThrough : null,
                        decorationThickness: crossed ? 2.5 : null,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (ticket.items[itemIndex].variant case final variant?
              when variant.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 45, top: 3),
              child: Text(variant, style: _detailStyle),
            ),
          for (final modifier in ticket.items[itemIndex].modifiers)
            Padding(
              padding: const EdgeInsets.only(left: 45, top: 3),
              child: Text('- $modifier', style: _detailStyle),
            ),
          if (ticket.items[itemIndex].comments case final comments?
              when comments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 45, top: 3),
              child: Text(comments, style: _detailStyle),
            ),
          const SizedBox(height: 5),
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
    this.detail,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });
  final String message;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 20),
        ),
        if (detail case final detail?) ...[
          const SizedBox(height: 8),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
        if (onAction != null) ...[
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
        if (onSecondaryAction != null)
          TextButton(
            onPressed: onSecondaryAction,
            child: Text(secondaryActionLabel!),
          ),
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
