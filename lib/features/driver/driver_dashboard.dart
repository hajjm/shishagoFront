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
  String? sharingOrderId;

  AppOrder? get activeOrder {
    for (final order in widget.store.orders) {
      if (order.stage != OrderStage.completed &&
          order.stage != OrderStage.cancelled) {
        return order;
      }
    }
    return null;
  }

  Future<void> refresh() async {
    try {
      await widget.store.refresh();
    } catch (error) {
      showError(error);
    }
  }

  Future<void> toggleLocation(bool enabled, AppOrder order) async {
    try {
      if (enabled) {
        await widget.store.startLocationSharing(order);
        sharingOrderId = order.id;
      } else {
        await widget.store.stopLocationSharing();
        sharingOrderId = null;
      }
      if (mounted) setState(() {});
    } catch (error) {
      showError(error);
    }
  }

  Future<void> advance(AppOrder order) async {
    final next = switch (order.stage) {
      OrderStage.accepted => OrderStage.pickedUp,
      OrderStage.pickedUp => OrderStage.onTheWay,
      OrderStage.onTheWay => OrderStage.completed,
      _ => null,
    };
    if (next == null) return;
    try {
      await widget.store.changeOrderStatus(order, next);
      if (next == OrderStage.completed) {
        await widget.store.stopLocationSharing();
        sharingOrderId = null;
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
        final order = activeOrder;
        final completed = widget.store.orders
            .where((value) => value.stage == OrderStage.completed)
            .length;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const BrandMark(compact: true),
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
                          : 'Your active delivery is ready',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 22),
                    if (order == null)
                      const _EmptyAssignment()
                    else ...[
                      _DeliveryCard(
                        order: order,
                        sharing:
                            widget.store.isSharingLocation &&
                            sharingOrderId == order.id,
                        onSharingChanged: (value) =>
                            toggleLocation(value, order),
                        onCall: () => callClient(order.clientPhone),
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
                            value: '$completed',
                            label: 'Completed deliveries',
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

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.order,
    required this.sharing,
    required this.onSharingChanged,
    required this.onCall,
  });

  final AppOrder order;
  final bool sharing;
  final ValueChanged<bool> onSharingChanged;
  final VoidCallback onCall;

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
        Text(order.items, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 20),
        const _RoutePoint(
          icon: Icons.storefront_rounded,
          label: 'PICK UP',
          value: 'Shisha Go store',
          color: AppColors.ember,
        ),
        Container(
          margin: const EdgeInsets.only(left: 17),
          height: 28,
          width: 2,
          color: Colors.white24,
        ),
        _RoutePoint(
          icon: Icons.location_on_rounded,
          label: 'DROP OFF',
          value: order.address,
          color: AppColors.sage,
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SwitchListTile(
            value: sharing,
            onChanged: onSharingChanged,
            activeThumbColor: AppColors.sage,
            title: Text(
              sharing ? 'Live location is shared' : 'Share live location',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: const Text(
              'The client receives your position during this delivery.',
              style: TextStyle(color: Colors.white60),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: onCall,
            icon: const Icon(Icons.phone_rounded),
            label: Text('Call ${order.clientPhone}'),
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
            OrderStage.pickedUp,
            OrderStage.onTheWay,
            OrderStage.completed,
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
                    ? 'Delivery completed'
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
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
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
          ],
        ),
      ),
    ],
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
