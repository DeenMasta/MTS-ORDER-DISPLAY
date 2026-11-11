import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../domain/models/display_session.dart';
import '../../../../domain/models/kds_settings.dart';
import '../../../../domain/models/kitchen_ticket.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_constants.dart';
import '../../../core/order_type_icon_library.dart';
import '../view_models/kitchen_board_view_model.dart';
import 'kitchen_history_screen.dart';
import 'kitchen_settings_screen.dart';
import 'slanted_timer_clipper.dart';

const _boardBackground = AppColors.canvas;
const _boardForeground = AppColors.text;
const _boardMuted = AppColors.mutedText;

class KitchenBoardScreen extends StatefulWidget {
  const KitchenBoardScreen({
    super.key,
    required this.viewModel,
    required this.session,
    required this.onChangeConnection,
    required this.appName,
    required this.appVersion,
  });
  final KitchenBoardViewModel viewModel;
  final DisplaySession session;
  final Future<void> Function() onChangeConnection;
  final String appName;
  final String? appVersion;

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
    backgroundColor: _boardBackground,
    endDrawer: _KitchenSideMenu(
      onHistory: _openHistory,
      onSettings: _openSettings,
      appName: widget.appName,
      appVersion: widget.appVersion,
    ),
    body: Stack(
      children: [
        const Positioned.fill(child: _BrandPatternBackground()),
        SafeArea(
          child: ListenableBuilder(
            listenable: widget.viewModel,
            builder: (context, _) => Stack(
              children: [
                _KitchenBoardBody(
                  viewModel: widget.viewModel,
                  session: widget.session,
                  onChangeConnection: widget.onChangeConnection,
                  onOpenMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
                ),
                if (!widget.viewModel.isPaired) ...[
                  const Positioned.fill(
                    child: ModalBarrier(
                      dismissible: false,
                      color: Color(0x660D0610),
                    ),
                  ),
                  Center(
                    child: _ReconnectDialog(
                      pairingCode: widget.viewModel.pairingCode,
                    ),
                  ),
                ],
              ],
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
  Widget build(BuildContext context) =>
      Image.asset(AppAssets.brandPatternBackground, fit: BoxFit.cover);
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
                          'No active order tickets.',
                          style: TextStyle(color: _boardMuted, fontSize: 18),
                        ),
                      )
                    : _TicketPager(
                        key: ValueKey(
                          '${viewModel.filter.id}:${viewModel.pageCount}:$receiptsPerPage',
                        ),
                        viewModel: viewModel,
                        groups: viewModel.ticketGroups,
                        clockTicks: viewModel.clockTicks,
                        iconNameFor: viewModel.orderTypeIconNameFor,
                        settings: viewModel.settings,
                        isRetrieved: viewModel.isRetrieved,
                        isCancelled: viewModel.isCancelled,
                        isCrossed: viewModel.isItemCrossed,
                        onToggle: viewModel.toggleItemCrossed,
                        completionSecondsRemaining:
                            viewModel.completionSecondsRemaining,
                        cancellationSecondsRemaining:
                            viewModel.cancellationSecondsRemaining,
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

class _ReconnectDialog extends StatelessWidget {
  const _ReconnectDialog({this.pairingCode});

  final String? pairingCode;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 390),
    child: Card(
      color: AppColors.surfaceRaised,
      elevation: 12,
      shadowColor: const Color(0x660D0610),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Reconnecting to POS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pairingCode == null
                  ? 'Trying to restore the secure POS connection.'
                  : 'Confirm this code in the POS to continue:',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            if (pairingCode case final code?) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.outline),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1FC00050),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        Text(
          'Orders: ${orderCount.toString().padLeft(2, '0')}',
          style: TextStyle(
            color: _boardForeground,
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Image.asset(AppAssets.mysztechLogo, height: compact ? 27 : 37),
        const Spacer(),
        IconButton(
          tooltip: 'Display menu',
          onPressed: onOpenMenu,
          icon: Icon(
            Icons.menu_rounded,
            color: _boardForeground,
            size: compact ? 24 : 28,
          ),
        ),
      ],
    ),
  );
}

class _KitchenSideMenu extends StatelessWidget {
  const _KitchenSideMenu({
    required this.onHistory,
    required this.onSettings,
    required this.appName,
    required this.appVersion,
  });

  final VoidCallback onHistory;
  final VoidCallback onSettings;
  final String appName;
  final String? appVersion;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = math.min(
      math.max(160.0, screenWidth - 16),
      math.min(360.0, math.max(280.0, screenWidth * .78)),
    );
    return Drawer(
      width: width,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 22, 16, 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.outline)),
              ),
              child: Row(
                children: [
                  Image.asset(AppAssets.mysztechLogo, height: 32),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close menu',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: _boardForeground,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 22, 22, 10),
              child: Text(
                'DISPLAY MENU',
                style: TextStyle(
                  color: _boardMuted,
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
              child: Divider(color: AppColors.outline, height: 1),
            ),
            _SideMenuItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              detail: 'Display and connection',
              onTap: onSettings,
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _boardMuted, fontSize: 12),
                    ),
                  ),
                  if (appVersion case final version?) ...[
                    const SizedBox(width: 12),
                    Text(
                      version,
                      style: const TextStyle(color: _boardMuted, fontSize: 12),
                    ),
                  ],
                ],
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
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: AppColors.primary),
    ),
    title: Text(
      label,
      style: const TextStyle(
        color: _boardForeground,
        fontWeight: FontWeight.w700,
      ),
    ),
    subtitle: Text(detail, style: const TextStyle(color: _boardMuted)),
    trailing: const Icon(Icons.chevron_right_rounded, color: _boardMuted),
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
                showCheckmark: false,
                onSelected: (_) => viewModel.selectFilter(filter),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: viewModel.filter == filter
                      ? Colors.white
                      : AppColors.primaryDark,
                ),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 6,
                ),
                shape: const StadiumBorder(
                  side: BorderSide(color: AppColors.outline),
                ),
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
    required this.clockTicks,
    required this.iconNameFor,
    required this.settings,
    required this.isRetrieved,
    required this.isCancelled,
    required this.isCrossed,
    required this.onToggle,
    required this.completionSecondsRemaining,
    required this.cancellationSecondsRemaining,
    required this.onComplete,
    required this.onUndoComplete,
  });

  final KitchenBoardViewModel viewModel;
  final List<List<KitchenTicket>> groups;
  final ValueListenable<int> clockTicks;
  final String Function(KitchenTicket) iconNameFor;
  final KdsSettings settings;
  final bool Function(List<KitchenTicket>) isRetrieved;
  final bool Function(List<KitchenTicket>) isCancelled;
  final bool Function(KitchenTicket ticket, int itemIndex) isCrossed;
  final void Function(KitchenTicket ticket, int itemIndex) onToggle;
  final int Function(List<KitchenTicket>) completionSecondsRemaining;
  final int Function(List<KitchenTicket>) cancellationSecondsRemaining;
  final Future<void> Function(List<KitchenTicket>) onComplete;
  final Future<void> Function(List<KitchenTicket>) onUndoComplete;

  @override
  State<_TicketPager> createState() => _TicketPagerState();
}

class _TicketPagerState extends State<_TicketPager> {
  late final PageController _controller;
  late int _displayedPage;

  @override
  void initState() {
    super.initState();
    _displayedPage = widget.viewModel.page;
    _controller = PageController(
      initialPage: _displayedPage,
      viewportFraction: 1,
      keepPage: false,
    );
  }

  @override
  void didUpdateWidget(covariant _TicketPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetPage = widget.viewModel.page;
    if (targetPage == _displayedPage) return;
    _displayedPage = targetPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      if ((_controller.page ?? targetPage).round() == targetPage) return;
      _controller.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
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
    physics: const PageScrollPhysics(),
    pageSnapping: true,
    itemCount: widget.viewModel.pageCount,
    onPageChanged: (page) {
      _displayedPage = page;
      widget.viewModel.showPage(page);
    },
    itemBuilder: (context, page) => Padding(
      // Retain full-width pages for smooth snapping, while giving adjacent
      // pages the same 12 px visual gap as receipt cards.
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: _TicketGrid(
        groups: widget.groups
            .skip(page * widget.viewModel.receiptsPerPage)
            .take(widget.viewModel.receiptsPerPage)
            .toList(growable: false),
        clockTicks: widget.clockTicks,
        iconNameFor: widget.iconNameFor,
        settings: widget.settings,
        isRetrieved: widget.isRetrieved,
        isCancelled: widget.isCancelled,
        isCrossed: widget.isCrossed,
        onToggle: widget.onToggle,
        completionSecondsRemaining: widget.completionSecondsRemaining,
        cancellationSecondsRemaining: widget.cancellationSecondsRemaining,
        onComplete: widget.onComplete,
        onUndoComplete: widget.onUndoComplete,
      ),
    ),
  );
}

class _TicketGrid extends StatelessWidget {
  const _TicketGrid({
    required this.groups,
    required this.clockTicks,
    required this.iconNameFor,
    required this.settings,
    required this.isRetrieved,
    required this.isCancelled,
    required this.isCrossed,
    required this.onToggle,
    required this.completionSecondsRemaining,
    required this.cancellationSecondsRemaining,
    required this.onComplete,
    required this.onUndoComplete,
  });
  final List<List<KitchenTicket>> groups;
  final ValueListenable<int> clockTicks;
  final String Function(KitchenTicket) iconNameFor;
  final KdsSettings settings;
  final bool Function(List<KitchenTicket>) isRetrieved;
  final bool Function(List<KitchenTicket>) isCancelled;
  final bool Function(KitchenTicket ticket, int itemIndex) isCrossed;
  final void Function(KitchenTicket ticket, int itemIndex) onToggle;
  final int Function(List<KitchenTicket>) completionSecondsRemaining;
  final int Function(List<KitchenTicket>) cancellationSecondsRemaining;
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
          clockTicks: clockTicks,
          iconName: iconNameFor(groups[index].first),
          settings: settings,
          isRetrieved: isRetrieved(groups[index]),
          isCancelled: isCancelled(groups[index]),
          isCrossed: isCrossed,
          onToggle: onToggle,
          secondsRemaining: () => completionSecondsRemaining(groups[index]),
          cancellationSecondsRemaining: () =>
              cancellationSecondsRemaining(groups[index]),
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
    required this.clockTicks,
    required this.iconName,
    required this.settings,
    required this.isRetrieved,
    required this.isCancelled,
    required this.isCrossed,
    required this.onToggle,
    required this.secondsRemaining,
    required this.cancellationSecondsRemaining,
    required this.onComplete,
    required this.onUndoComplete,
  });
  final List<KitchenTicket> tickets;
  final ValueListenable<int> clockTicks;
  final String iconName;
  final KdsSettings settings;
  final bool isRetrieved;
  final bool isCancelled;
  final bool Function(KitchenTicket ticket, int itemIndex) isCrossed;
  final void Function(KitchenTicket ticket, int itemIndex) onToggle;
  final int Function() secondsRemaining;
  final int Function() cancellationSecondsRemaining;
  final Future<void> Function() onComplete;
  final Future<void> Function() onUndoComplete;
  @override
  Widget build(BuildContext context) {
    final ticket = tickets.first;
    final orderer = ticket.displayOrderer;
    final orderFor = ticket.orderFor;
    final remainingSeconds = secondsRemaining();
    final cancelledRemainingSeconds = cancellationSecondsRemaining();
    final elapsed = DateTime.now().difference(ticket.createdAt.toLocal());
    final accent = elapsed.inSeconds >= settings.urgentThresholdSeconds
        ? const Color(0xFFFF1C2C)
        : elapsed.inSeconds >= settings.warningThresholdSeconds
        ? const Color(0xFFFFEF00)
        : const Color(0xFF02D53C);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                if (isCancelled)
                  const ColoredBox(color: Color(0xFFB42339))
                else ...[
                  ClipPath(
                    clipper: const SlantedTimerClipper(),
                    child: ColoredBox(color: accent),
                  ),
                  if (remainingSeconds > 0)
                    const ColoredBox(color: Color(0xFF007C58)),
                ],
                Semantics(
                  button: !isCancelled && remainingSeconds == 0,
                  label: isCancelled
                      ? cancelledRemainingSeconds > 0
                            ? 'Cancelled. Moving to order history in '
                                  '$cancelledRemainingSeconds seconds.'
                            : 'Cancelled. Moving to order history.'
                      : remainingSeconds > 0
                      ? 'Finished. Removing in $remainingSeconds seconds.'
                      : 'Tap receipt header to mark this order finished.',
                  child: InkWell(
                    onTap: !isCancelled && remainingSeconds == 0
                        ? () {
                            onComplete();
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: isCancelled
                          ? Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'CANCELLED',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                if (cancelledRemainingSeconds > 0)
                                  ValueListenableBuilder<int>(
                                    valueListenable: clockTicks,
                                    builder: (context, _, _) => Text(
                                      '00:${cancellationSecondsRemaining().toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : remainingSeconds > 0
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
                                ValueListenableBuilder<int>(
                                  valueListenable: clockTicks,
                                  builder: (context, _, _) => Text(
                                    '00:${secondsRemaining().toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
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
                                ValueListenableBuilder<int>(
                                  valueListenable: clockTicks,
                                  builder: (context, _, _) {
                                    final currentElapsed = DateTime.now()
                                        .difference(ticket.createdAt.toLocal());
                                    return Text(
                                      _formatDuration(currentElapsed),
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                      ),
                                    );
                                  },
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
                      Icon(_orderTypeIcon(iconName), size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ticket.orderTypeName?.toUpperCase() ?? 'ORDER',
                          style: TextStyle(
                            fontSize: settings.largeText ? 19 : 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (ticket.tableName case final table?
                          when table.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            'Table $table',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 22, thickness: 1),
                  if (orderer != null || orderFor != null || isRetrieved)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (orderer != null)
                                Text(
                                  'Ordered by: $orderer',
                                  style: _detailStyle,
                                ),
                              if (orderFor != null)
                                Text(
                                  'Order for: $orderFor',
                                  style: _detailStyle,
                                ),
                            ],
                          ),
                        ),
                        if (isRetrieved) ...[
                          const SizedBox(width: 6),
                          Semantics(
                            label: 'Reopened from order history',
                            child: Tooltip(
                              message: 'Reopened from order history',
                              child: const DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(99),
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.restore_rounded,
                                        color: AppColors.primary,
                                        size: 18,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        'Reopen',
                                        style: TextStyle(
                                          color: AppColors.primaryDark,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  if (ticket.displayRemarks case final remarks?)
                    Text('Remarks: $remarks', style: _detailStyle),
                  const Divider(height: 18, thickness: 1),
                  _Items(
                    tickets: tickets,
                    largeText: settings.largeText,
                    isCrossed: isCrossed,
                    onToggle: onToggle,
                    enabled: !isCancelled && remainingSeconds == 0,
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
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _detailStyle = TextStyle(color: AppColors.mutedText, fontSize: 12);

class _Items extends StatelessWidget {
  const _Items({
    required this.tickets,
    required this.largeText,
    required this.isCrossed,
    required this.onToggle,
    required this.enabled,
  });
  final List<KitchenTicket> tickets;
  final bool largeText;
  final bool Function(KitchenTicket ticket, int itemIndex) isCrossed;
  final void Function(KitchenTicket ticket, int itemIndex) onToggle;
  final bool enabled;
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
                button: enabled,
                label: !enabled
                    ? '${item.name}, cancelled.'
                    : crossed
                    ? '${item.name}, completed. Tap to restore.'
                    : '${item.name}. Tap to cross out.',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: enabled ? () => onToggle(ticket, itemIndex) : null,
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
        icon: const Icon(Icons.chevron_left, color: _boardForeground),
      ),
      Expanded(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              viewModel.pageCount,
              (index) => Container(
                width: 20,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: index == viewModel.page
                      ? AppColors.primary
                      : AppColors.outline,
                ),
              ),
            ),
          ),
        ),
      ),
      IconButton(
        onPressed: viewModel.page >= viewModel.pageCount - 1
            ? null
            : viewModel.showNextPage,
        icon: const Icon(Icons.chevron_right, color: _boardForeground),
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
          style: const TextStyle(color: _boardForeground, fontSize: 20),
        ),
        if (detail case final detail?) ...[
          const SizedBox(height: 8),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _boardMuted),
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
