import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../domain/models/display_session.dart';
import '../../../../domain/models/kds_settings.dart';
import '../../../../domain/models/kitchen_ticket.dart';
import '../../../core/order_type_icon_library.dart';
import '../view_models/kitchen_board_view_model.dart';
import 'kitchen_history_screen.dart';
import 'kitchen_settings_screen.dart';
import 'slanted_timer_clipper.dart';

const _appChromeSurface = Color(0xFF080F13);
const _appChromeElevated = Color(0xFF101B20);
const _appChromeBorder = Color(0xFF315356);
const _appChromeAccent = Color(0xFF58D0BF);
const _appChromeMuted = Color(0xFFA6BEBA);

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
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    widget.viewModel.start(widget.session);
  }

  Future<void> _openSettings() async {
    _scaffoldKey.currentState?.closeEndDrawer();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => KitchenSettingsScreen(
          viewModel: widget.viewModel,
          session: widget.session,
          onChangeConnection: widget.onChangeConnection,
        ),
      ),
    );
  }

  Future<void> _openHistory() async {
    _scaffoldKey.currentState?.closeEndDrawer();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => KitchenHistoryScreen(viewModel: widget.viewModel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: _scaffoldKey,
    backgroundColor: const Color(0xFF030B15),
    endDrawer: _KitchenSideMenu(
      onHistory: _openHistory,
      onSettings: _openSettings,
    ),
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
              onOpenMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
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
    required this.onOpenMenu,
  });
  final KitchenBoardViewModel viewModel;
  final DisplaySession session;
  final Future<void> Function() onChangeConnection;
  final VoidCallback onOpenMenu;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final receiptsPerPage = compact ? 1 : 4;
        if (viewModel.receiptsPerPage != receiptsPerPage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              viewModel.setReceiptsPerPage(receiptsPerPage);
            }
          });
        }
        final pagingIsUpdating = viewModel.receiptsPerPage != receiptsPerPage;
        return Padding(
          padding: EdgeInsets.all(compact ? 10 : 16),
          child: Column(
            children: [
              _Header(
                compact: compact,
                orderCount: viewModel.ticketGroups.length,
                onOpenMenu: onOpenMenu,
              ),
              if (!viewModel.isPaired) ...[
                SizedBox(height: compact ? 8 : 12),
                _ConnectionStatus(code: viewModel.pairingCode),
              ],
              SizedBox(height: compact ? 8 : 10),
              Align(
                alignment: Alignment.centerLeft,
                child: _FilterBar(viewModel: viewModel),
              ),
              SizedBox(height: compact ? 8 : 10),
              Expanded(
                child: pagingIsUpdating
                    ? const Center(child: CircularProgressIndicator())
                    : viewModel.visibleTicketGroups.isEmpty
                    ? const Center(
                        child: Text(
                          'No active kitchen tickets.',
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                      )
                    : _TicketPager(
                        key: ValueKey(
                          '${viewModel.filter.id}:${viewModel.pageCount}:$receiptsPerPage',
                        ),
                        viewModel: viewModel,
                        groups: viewModel.ticketGroups,
                        iconNameFor: viewModel.orderTypeIconNameFor,
                        settings: viewModel.settings,
                        isCrossed: viewModel.isItemCrossed,
                        onToggle: viewModel.toggleItemCrossed,
                        completionSecondsRemaining:
                            viewModel.completionSecondsRemaining,
                        onComplete: viewModel.completeLocally,
                        onUndoComplete: viewModel.undoLocalCompletion,
                      ),
              ),
              SizedBox(height: compact ? 2 : 6),
              _Pager(viewModel: viewModel),
            ],
          ),
        );
      },
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
        Flexible(
          child: Text(
            code == null
                ? 'Reconnecting to POS…'
                : 'Confirm this code in POS: $code',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.compact,
    required this.orderCount,
    required this.onOpenMenu,
  });

  final bool compact;
  final int orderCount;
  final VoidCallback onOpenMenu;

  @override
  Widget build(BuildContext context) => Container(
    height: compact ? 52 : 58,
    padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
    decoration: BoxDecoration(
      color: const Color(0xDD02070D),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _appChromeBorder),
    ),
    child: Row(
      children: [
        Text(
          'Orders: ${orderCount.toString().padLeft(2, '0')}',
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Image.asset(
          'assets/images/mysztech_logo.png',
          height: compact ? 27 : 37,
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Display menu',
          onPressed: onOpenMenu,
          icon: Icon(
            Icons.menu_rounded,
            color: Colors.white,
            size: compact ? 24 : 28,
          ),
        ),
      ],
    ),
  );
}

class _KitchenSideMenu extends StatelessWidget {
  const _KitchenSideMenu({required this.onHistory, required this.onSettings});

  final VoidCallback onHistory;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final width = math.min(
      360.0,
      math.max(280.0, MediaQuery.sizeOf(context).width * .78),
    );
    return Drawer(
      width: width,
      backgroundColor: _appChromeSurface,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 22, 16, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_appChromeElevated, _appChromeSurface],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(bottom: BorderSide(color: _appChromeBorder)),
              ),
              child: Row(
                children: [
                  Image.asset('assets/images/mysztech_logo.png', height: 32),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close menu',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 22, 22, 10),
              child: Text(
                'DISPLAY MENU',
                style: TextStyle(
                  color: _appChromeMuted,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            _SideMenuItem(
              icon: Icons.history_rounded,
              label: 'Order history',
              detail: 'Today’s stored receipts',
              onTap: onHistory,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Divider(color: _appChromeBorder, height: 1),
            ),
            _SideMenuItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              detail: 'Display and connection',
              onTap: onSettings,
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(22),
              child: Text(
                'Kitchen Display System',
                style: TextStyle(color: _appChromeMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideMenuItem extends StatelessWidget {
  const _SideMenuItem({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _appChromeElevated,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: _appChromeAccent),
    ),
    title: Text(
      label,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
    ),
    subtitle: Text(detail, style: const TextStyle(color: _appChromeMuted)),
    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF87AAA4)),
    onTap: onTap,
  );
}

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
    super.key,
    required this.viewModel,
    required this.groups,
    required this.iconNameFor,
    required this.settings,
    required this.isCrossed,
    required this.onToggle,
    required this.completionSecondsRemaining,
    required this.onComplete,
    required this.onUndoComplete,
  });

  final KitchenBoardViewModel viewModel;
  final List<List<KitchenTicket>> groups;
  final String Function(KitchenTicket) iconNameFor;
  final KdsSettings settings;
  final bool Function(KitchenTicket ticket, int itemIndex) isCrossed;
  final void Function(KitchenTicket ticket, int itemIndex) onToggle;
  final int Function(List<KitchenTicket>) completionSecondsRemaining;
  final Future<void> Function(List<KitchenTicket>) onComplete;
  final Future<void> Function(List<KitchenTicket>) onUndoComplete;

  @override
  State<_TicketPager> createState() => _TicketPagerState();
}

class _TicketPagerState extends State<_TicketPager> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: widget.viewModel.page,
      viewportFraction: 1,
      keepPage: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snapToPageBoundary() {
    if (!_controller.hasClients) return;
    final currentPage = _controller.page;
    if (currentPage == null) return;

    final targetPage = currentPage.round().clamp(
      0,
      widget.viewModel.pageCount - 1,
    );
    if ((currentPage - targetPage).abs() < .001) return;

    _controller.jumpToPage(targetPage);
    widget.viewModel.showPage(targetPage);
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification &&
              notification.metrics.axis == Axis.horizontal) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _snapToPageBoundary();
            });
          }
          return false;
        },
        child: ClipRect(
          child: PageView.builder(
            controller: _controller,
            clipBehavior: Clip.hardEdge,
            physics: const PageScrollPhysics(),
            pageSnapping: true,
            itemCount: widget.viewModel.pageCount,
            onPageChanged: widget.viewModel.showPage,
            itemBuilder: (context, page) => Padding(
              // Retain full-width pages for smooth snapping, while giving
              // adjacent pages the same 12 px visual gap as receipt cards.
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _TicketGrid(
                groups: widget.groups
                    .skip(page * 4)
                    .take(4)
                    .toList(growable: false),
                iconNameFor: widget.iconNameFor,
                settings: widget.settings,
                isCrossed: widget.isCrossed,
                onToggle: widget.onToggle,
                completionSecondsRemaining: widget.completionSecondsRemaining,
                onComplete: widget.onComplete,
                onUndoComplete: widget.onUndoComplete,
              ),
            ),
          ),
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
    required this.onUndoComplete,
  });
  final List<List<KitchenTicket>> groups;
  final String Function(KitchenTicket) iconNameFor;
  final KdsSettings settings;
  final bool Function(KitchenTicket ticket, int itemIndex) isCrossed;
  final void Function(KitchenTicket ticket, int itemIndex) onToggle;
  final int Function(List<KitchenTicket>) completionSecondsRemaining;
  final Future<void> Function(List<KitchenTicket>) onComplete;
  final Future<void> Function(List<KitchenTicket>) onUndoComplete;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900
          ? 4
          : constraints.maxWidth >= 560
          ? 2
          : 1;
      final rows = math.max(1, (groups.length / columns).ceil());
      final cardWidth = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
      final cardHeight = math.max(
        1,
        (constraints.maxHeight - ((rows - 1) * 12)) / rows,
      );
      final preferredCardHeight =
          cardWidth / (settings.compactCards ? .76 : .62);
      final fittedCardHeight = math.min(cardHeight, preferredCardHeight);
      return GridView.builder(
        itemCount: groups.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: cardWidth / fittedCardHeight,
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
          onUndoComplete: () => onUndoComplete(groups[index]),
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
    required this.onUndoComplete,
  });
  final List<KitchenTicket> tickets;
  final String iconName;
  final KdsSettings settings;
  final bool Function(KitchenTicket ticket, int itemIndex) isCrossed;
  final void Function(KitchenTicket ticket, int itemIndex) onToggle;
  final int secondsRemaining;
  final Future<void> Function() onComplete;
  final Future<void> Function() onUndoComplete;
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
                    onTap: secondsRemaining == 0
                        ? () {
                            onComplete();
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: secondsRemaining > 0
                          ? Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'FINISHED',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                Text(
                                  '00:${secondsRemaining.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Semantics(
                                  button: true,
                                  label: 'Undo finished receipt',
                                  child: Tooltip(
                                    message: 'Undo finished receipt',
                                    child: IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        onUndoComplete();
                                      },
                                      icon: const Icon(
                                        Icons.undo_rounded,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
              child: Text('Notes: $comments', style: _detailStyle),
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

IconData _orderTypeIcon(String name) => orderTypeIconFor(name);
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
