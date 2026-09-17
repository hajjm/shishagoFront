import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../data/app_store.dart';
import '../../models/app_models.dart';
import '../../services/session_controller.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/notifications_button.dart';
import '../../widgets/order_widgets.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({
    super.key,
    required this.store,
    required this.session,
  });

  final ShishaGoStore store;
  final SessionController session;

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  String? selectedOrderId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ensureAutomaticLocationSharing());
    });
  }

  List<AppOrder> get activeOrders => widget.store.orders.where((order) {
    if (order.stage == OrderStage.completed) return order.hasShisha;
    return {
      OrderStage.accepted,
      OrderStage.preparing,
      OrderStage.onTheWay,
      OrderStage.finishedUsing,
    }.contains(order.stage);
  }).toList();

  AppOrder? selectedOrder(List<AppOrder> orders) {
    if (orders.isEmpty) return null;
    for (final order in orders) {
      if (order.id == selectedOrderId) return order;
    }
    return orders.first;
  }

  Future<void> refresh() async {
    try {
      await widget.store.refresh();
      await ensureAutomaticLocationSharing();
    } catch (error) {
      showError(error);
    }
  }

  Future<void> ensureAutomaticLocationSharing() async {
    if (widget.store.isSharingLocation) return;
    try {
      for (final order in activeOrders) {
        if (order.stage == OrderStage.onTheWay) {
          await widget.store.startLocationSharing(order);
          return;
        }
      }
    } catch (error) {
      showError(error);
    }
  }

  Future<void> retryLocation(AppOrder order) async {
    try {
      await widget.store.startLocationSharing(order);
      if (mounted) setState(() {});
    } catch (error) {
      showError(error);
    }
  }

  Future<void> advance(AppOrder order) async {
    final next = switch (order.stage) {
      OrderStage.accepted => OrderStage.preparing,
      OrderStage.preparing => OrderStage.onTheWay,
      OrderStage.onTheWay => OrderStage.completed,
      OrderStage.finishedUsing => OrderStage.collected,
      _ => null,
    };
    if (next == null) return;
    try {
      await widget.store.changeOrderStatus(order, next);
      if (next == OrderStage.onTheWay) {
        await widget.store.startLocationSharing(order);
      }
      if (next == OrderStage.completed &&
          widget.store.sharingOrderId == order.id) {
        await widget.store.stopLocationSharing();
        await ensureAutomaticLocationSharing();
      }
      if (mounted) setState(() {});
    } catch (error) {
      showError(error);
    }
  }

  Future<void> callClient(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      showError('Calling is not supported on this device');
    }
  }

  Future<void> whatsappClient(AppOrder order) async {
    final phone = order.clientPhone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.https('wa.me', '/$phone', {
      'text':
          'Hello ${order.clientName}, this is your Shisha Go driver for order ${order.reference}.',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      showError('WhatsApp could not be opened on this device');
    }
  }

  Future<void> openClientLocation(AppOrder order) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${order.latitude},${order.longitude}',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      showError('Google Maps could not be opened on this device');
    }
  }

  void showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final assignments = activeOrders;
        final order = selectedOrder(assignments);
        final collected = widget.store.orders
            .where((value) => value.stage == OrderStage.collected)
            .length;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: MediaQuery.sizeOf(context).width < 440
                ? const BrandLogo(size: 40)
                : const BrandMark(compact: true),
            actions: [
              NotificationsButton(store: widget.store),
              IconButton(
                tooltip: 'Refresh',
                onPressed: widget.store.loading ? null : refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: widget.session.logout,
                icon: const Icon(Icons.logout_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: refresh,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Hey ${widget.session.user?.name ?? 'driver'}',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order == null
                          ? 'No active delivery assigned'
                          : '${assignments.length} active ${assignments.length == 1 ? 'delivery' : 'deliveries'} assigned',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 22),
                    if (order == null)
                      const _EmptyAssignment()
                    else ...[
                      _AssignmentPicker(
                        orders: assignments,
                        selectedOrderId: order.id,
                        onSelected: (orderId) =>
                            setState(() => selectedOrderId = orderId),
                      ),
                      const SizedBox(height: 18),
                      _DeliveryCard(
                        order: order,
                        sharing:
                            widget.store.isSharingLocation &&
                            order.stage == OrderStage.onTheWay,
                        onRetryLocation: () => retryLocation(order),
                        onCall: () => callClient(order.clientPhone),
                        onWhatsApp: () => whatsappClient(order),
                        onOpenLocation: () => openClientLocation(order),
                      ),
                      const SizedBox(height: 18),
                      _ProgressCard(
                        order: order,
                        busy: widget.store.loading,
                        onAdvance: () => advance(order),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _DriverMetric(
                            value: '$collected',
                            label: 'Collected orders',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DriverMetric(
                            value: '${widget.store.orders.length}',
                            label: 'Assigned orders',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AssignmentPicker extends StatelessWidget {
  const _AssignmentPicker({
    required this.orders,
    required this.selectedOrderId,
    required this.onSelected,
  });

  final List<AppOrder> orders;
  final String selectedOrderId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            'Assigned deliveries',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.ember.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${orders.length} active',
              style: const TextStyle(
                color: AppColors.emberDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 126,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final order = orders[index];
            final selected = order.id == selectedOrderId;
            return SizedBox(
              width: 236,
              child: Material(
                color: selected
                    ? AppColors.ember.withValues(alpha: 0.10)
                    : AppColors.paper,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: selected ? AppColors.ember : AppColors.sand,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onSelected(order.id),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.reference,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: OrderStatusPill(stage: order.stage),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          order.clientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.order,
    required this.sharing,
    required this.onRetryLocation,
    required this.onCall,
    required this.onWhatsApp,
    required this.onOpenLocation,
  });

  final AppOrder order;
  final bool sharing;
  final VoidCallback onRetryLocation;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onOpenLocation;

  String get locationTitle => switch (order.stage) {
    OrderStage.onTheWay when sharing => 'Live location sharing is on',
    OrderStage.onTheWay => 'Location sharing needs attention',
    OrderStage.completed => 'Shisha delivered',
    OrderStage.finishedUsing => 'Shisha ready for collection',
    _ => 'Driver is at the Shisha Go store',
  };

  String get locationSubtitle => switch (order.stage) {
    OrderStage.onTheWay =>
      'The client receives a fresh position every 10 seconds.',
    OrderStage.completed =>
      'Waiting for the client or the automatic four-hour timer.',
    OrderStage.finishedUsing =>
      'Collect the shisha from the client and return it to the store.',
    _ => 'Location sharing starts automatically after Preparing.',
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              order.reference,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            OrderStatusPill(stage: order.stage),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          order.clientName,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 5),
        Material(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DELIVERY DETAILS',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 7),
                Text(order.items, style: const TextStyle(color: Colors.white)),
                if (order.notes.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    'Note: ${order.notes}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
                if (order.bringChange) ...[
                  const SizedBox(height: 7),
                  const Row(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        color: AppColors.sand,
                        size: 19,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'CLIENT REQUESTED CHANGE',
                        style: TextStyle(
                          color: AppColors.sand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Order total: \$${order.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _RoutePoint(
          icon: order.stage == OrderStage.finishedUsing
              ? Icons.location_on_rounded
              : Icons.storefront_rounded,
          label: order.stage == OrderStage.finishedUsing
              ? 'COLLECT FROM'
              : 'PICK UP',
          value: order.stage == OrderStage.finishedUsing
              ? order.address
              : 'Shisha Go store',
          color: AppColors.ember,
          onTap: order.stage == OrderStage.finishedUsing
              ? onOpenLocation
              : null,
        ),
        Container(
          margin: const EdgeInsets.only(left: 17),
          height: 28,
          width: 2,
          color: Colors.white24,
        ),
        _RoutePoint(
          icon: order.stage == OrderStage.finishedUsing
              ? Icons.storefront_rounded
              : Icons.location_on_rounded,
          label: order.stage == OrderStage.finishedUsing
              ? 'RETURN TO'
              : 'DROP OFF',
          value: order.stage == OrderStage.finishedUsing
              ? 'Shisha Go store'
              : order.address,
          color: AppColors.sage,
          onTap: order.stage == OrderStage.finishedUsing
              ? null
              : onOpenLocation,
        ),
        const SizedBox(height: 18),
        Material(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            leading: Icon(
              order.stage == OrderStage.onTheWay
                  ? Icons.gps_fixed_rounded
                  : order.stage == OrderStage.finishedUsing
                  ? Icons.inventory_2_rounded
                  : Icons.storefront_rounded,
              color: sharing ? AppColors.sage : Colors.white70,
            ),
            title: Text(
              locationTitle,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              locationSubtitle,
              style: const TextStyle(color: Colors.white60),
            ),
            trailing: order.stage == OrderStage.onTheWay && !sharing
                ? TextButton(
                    onPressed: onRetryLocation,
                    child: const Text('Retry'),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: onCall,
                icon: const Icon(Icons.phone_rounded),
                label: const Text('Call'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: onWhatsApp,
                icon: const Icon(Icons.chat_rounded),
                label: const Text('WhatsApp'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            order.clientPhone,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.order,
    required this.busy,
    required this.onAdvance,
  });

  final AppOrder order;
  final bool busy;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery progress',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          for (final step in const [
            OrderStage.accepted,
            OrderStage.preparing,
            OrderStage.onTheWay,
            OrderStage.completed,
            OrderStage.finishedUsing,
            OrderStage.collected,
          ])
            _ProgressRow(
              label: step.label,
              complete: order.stage.index >= step.index,
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy || order.stage == OrderStage.completed
                  ? null
                  : onAdvance,
              child: Text(
                order.stage == OrderStage.onTheWay
                    ? 'Mark as delivered'
                    : order.stage == OrderStage.completed
                    ? 'Waiting for client to finish'
                    : order.stage == OrderStage.finishedUsing
                    ? 'Mark as collected'
                    : 'Move to the next stage',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyAssignment extends StatelessWidget {
  const _EmptyAssignment();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      child: Column(
        children: [
          const Icon(Icons.delivery_dining_rounded, size: 58),
          const SizedBox(height: 14),
          Text(
            'You are all caught up',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Pull down to check for a newly assigned order.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _RoutePoint extends StatelessWidget {
  const _RoutePoint({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, size: 19, color: Colors.white),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (onTap != null)
                  const Text(
                    'Open in Google Maps',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.open_in_new_rounded, color: Colors.white70),
          ],
        ],
      ),
    ),
  );
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.label, required this.complete});

  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(
          complete
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: complete ? AppColors.sage : AppColors.sand,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontWeight: complete ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class _DriverMetric extends StatelessWidget {
  const _DriverMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}
