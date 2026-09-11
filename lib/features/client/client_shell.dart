import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../data/app_store.dart';
import '../../models/app_models.dart';
import '../../services/device_location_service.dart';
import '../../services/session_controller.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/notifications_button.dart';
import '../../widgets/order_widgets.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({super.key, required this.store, required this.session});

  final ShishaGoStore store;
  final SessionController session;

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int selectedIndex = 0;
  String? trackingOrderId;

  void trackOrder(AppOrder order) {
    setState(() {
      trackingOrderId = order.id;
      selectedIndex = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeOrders = widget.store.orders
        .where(
          (order) => !{
            OrderStage.pending,
            OrderStage.completed,
            OrderStage.cancelled,
          }.contains(order.stage),
        )
        .toList();
    AppOrder? trackingOrder;
    for (final order in activeOrders) {
      if (order.id == trackingOrderId) {
        trackingOrder = order;
        break;
      }
    }
    if (trackingOrder == null && activeOrders.isNotEmpty) {
      trackingOrder = activeOrders.first;
    }
    final pages = [
      ShopPage(store: widget.store, user: widget.session.user!),
      OrdersPage(store: widget.store, onTrack: trackOrder),
      trackingOrder == null
          ? const _NoActiveDelivery()
          : TrackingPage(
              key: ValueKey(trackingOrder.id),
              store: widget.store,
              order: trackingOrder,
            ),
      ProfilePage(session: widget.session),
    ];
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const BrandMark(compact: true),
        actions: [
          NotificationsButton(store: widget.store),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => setState(() => selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Shop',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on_rounded),
            label: 'Track',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class ShopPage extends StatefulWidget {
  const ShopPage({super.key, required this.store, required this.user});

  final ShishaGoStore store;
  final AppUser user;

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  ProductCategory category = ProductCategory.chicha;
  String? marketCategoryId;

  Future<void> checkout() async {
    try {
      final order = await widget.store.checkout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${order.reference} was placed successfully')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final products = widget.store.products
            .where(
              (product) =>
                  product.category == category &&
                  (category != ProductCategory.market ||
                      marketCategoryId == null ||
                      product.marketCategoryId == marketCategoryId),
            )
            .toList();
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1050
                ? 4
                : constraints.maxWidth >= 680
                ? 3
                : 2;
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Good evening, ${widget.user.name.split(' ').first}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineLarge,
                                  ),
                                ),
                                CircleAvatar(
                                  backgroundColor: AppColors.sand,
                                  child: Text(
                                    widget.user.name
                                        .substring(0, 1)
                                        .toUpperCase(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 17,
                                  color: AppColors.ember,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    widget.user.address,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: AppColors.ink,
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: const Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'THE NIGHT STARTS HERE',
                                          style: TextStyle(
                                            color: AppColors.sand,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.4,
                                          ),
                                        ),
                                        SizedBox(height: 7),
                                        Text(
                                          'A complete setup,\nready at your door.',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            height: 1.15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 62,
                                    color: AppColors.ember,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SegmentedButton<ProductCategory>(
                              segments: const [
                                ButtonSegment(
                                  value: ProductCategory.chicha,
                                  icon: Icon(
                                    Icons.local_fire_department_outlined,
                                  ),
                                  label: Text('Shisha'),
                                ),
                                ButtonSegment(
                                  value: ProductCategory.market,
                                  icon: Icon(Icons.shopping_bag_outlined),
                                  label: Text('Market'),
                                ),
                              ],
                              selected: {category},
                              onSelectionChanged: (selection) => setState(() {
                                category = selection.first;
                                marketCategoryId = null;
                              }),
                            ),
                            if (category == ProductCategory.market &&
                                widget.store.marketCategories.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    ChoiceChip(
                                      label: const Text('All'),
                                      selected: marketCategoryId == null,
                                      onSelected: (_) => setState(
                                        () => marketCategoryId = null,
                                      ),
                                    ),
                                    ...widget.store.marketCategories
                                        .where((value) => value.isActive)
                                        .map(
                                          (value) => Padding(
                                            padding: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            child: ChoiceChip(
                                              label: Text(value.name),
                                              selected:
                                                  marketCategoryId == value.id,
                                              onSelected: (_) => setState(
                                                () =>
                                                    marketCategoryId = value.id,
                                              ),
                                            ),
                                          ),
                                        ),
                                  ],
                                ),
                              ),
                            ],
                            if (widget.store.cartCount > 0) ...[
                              const SizedBox(height: 14),
                              Card(
                                color: AppColors.ember,
                                child: ListTile(
                                  textColor: Colors.white,
                                  iconColor: Colors.white,
                                  leading: const Icon(
                                    Icons.shopping_cart_rounded,
                                  ),
                                  title: Text(
                                    '${widget.store.cartCount} items · \$${widget.store.cartTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  trailing: FilledButton.tonal(
                                    onPressed: widget.store.loading
                                        ? null
                                        : checkout,
                                    child: const Text('Place order'),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: 274,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => ProductCard(
                        product: products[index],
                        store: widget.store,
                      ),
                      childCount: products.length,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.store});
  final Product product;
  final ShishaGoStore store;

  @override
  Widget build(BuildContext context) {
    final quantity = store.quantityFor(product.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 96,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.sand.withValues(alpha: 0.7),
                    AppColors.cream,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Icon(product.icon, size: 45, color: AppColors.ember),
            ),
            const SizedBox(height: 12),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Text(
                product.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
            Row(
              children: [
                Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                if (quantity == 0)
                  IconButton.filled(
                    onPressed: () => store.addToCart(product),
                    icon: const Icon(Icons.add_rounded),
                  )
                else
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => store.removeFromCart(product),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      Text(
                        '$quantity',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        onPressed: () => store.addToCart(product),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key, required this.store, required this.onTrack});
  final ShishaGoStore store;
  final ValueChanged<AppOrder> onTrack;

  bool isTrackable(AppOrder order) => {
    OrderStage.accepted,
    OrderStage.preparing,
    OrderStage.onTheWay,
  }.contains(order.stage);

  Future<void> cancelOrder(BuildContext context, AppOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          '${order.reference} can only be cancelled while it is pending.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await store.changeOrderStatus(order, OrderStage.cancelled);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => RefreshIndicator(
      onRefresh: store.refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Your orders', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 6),
          const Text(
            'Track active deliveries or order your favorites again.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 22),
          if (store.orders.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Your first order will appear here.'),
              ),
            ),
          ...store.orders.map(
            (order) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: isTrackable(order) ? () => onTrack(order) : null,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.reference,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          OrderStatusPill(stage: order.stage),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(order.items),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '\$${order.total.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              order.address,
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (order.stage == OrderStage.pending) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                          ),
                          onPressed: store.loading
                              ? null
                              : () => cancelOrder(context, order),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancel order'),
                        ),
                      ] else if (isTrackable(order)) ...[
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: () => onTrack(order),
                          icon: const Icon(Icons.location_on_rounded),
                          label: const Text('Track order'),
                        ),
                      ] else if (order.stage == OrderStage.completed) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              await store.reorder(order);
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.toString())),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Order again'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key, required this.store, required this.order});
  final ShishaGoStore store;
  final AppOrder order;

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  @override
  void initState() {
    super.initState();
    widget.store.watchTracking(widget.order);
  }

  Future<void> callDriver(String phone) async {
    final opened = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calling is not supported on this device'),
        ),
      );
    }
  }

  Future<void> whatsappDriver(AppOrder order, String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.https('wa.me', '/$digits', {
      'text':
          'Hello, I am contacting you about Shisha Go order ${order.reference}.',
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp could not be opened')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final tracking = widget.store.tracking;
      final order = widget.store.orders.firstWhere(
        (value) => value.id == widget.order.id,
        orElse: () => widget.order,
      );
      final hasDriver = order.driverId != null;
      final atStore =
          hasDriver &&
          {OrderStage.accepted, OrderStage.preparing}.contains(order.stage);
      final driverPhone = tracking?.driverPhone ?? order.driverPhone;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            atStore ? 'Order tracking' : 'Live delivery',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 6),
          Text(
            '${order.reference} · ${order.stage.label}',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: const Color(0xFFE7E2D8),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Stack(
              children: [
                ...List.generate(
                  5,
                  (index) => Positioned(
                    left: 25.0 + index * 70,
                    top: 0,
                    bottom: 0,
                    child: Transform.rotate(
                      angle: 0.35,
                      child: Container(width: 2, color: Colors.white70),
                    ),
                  ),
                ),
                const Positioned(
                  left: 52,
                  bottom: 44,
                  child: _MapPin(
                    icon: Icons.home_rounded,
                    color: AppColors.ink,
                  ),
                ),
                if (hasDriver)
                  Positioned(
                    left: atStore ? 82 : null,
                    bottom: atStore ? 48 : null,
                    right: atStore ? null : 78,
                    top: atStore ? null : 72,
                    child: const _MapPin(
                      icon: Icons.delivery_dining_rounded,
                      color: AppColors.ember,
                    ),
                  ),
                Positioned(
                  left: 18,
                  top: 18,
                  child: Chip(
                    avatar: const Icon(Icons.gps_fixed_rounded, size: 17),
                    label: Text(
                      tracking?.latitude == null
                          ? !hasDriver
                                ? 'Waiting for driver assignment'
                                : atStore
                                ? 'Driver is at the Shisha Go store'
                                : 'Waiting for driver GPS'
                          : '${tracking!.latitude!.toStringAsFixed(5)}, ${tracking.longitude!.toStringAsFixed(5)}',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                backgroundColor: AppColors.sand,
                child: Icon(Icons.person_rounded),
              ),
              title: Text(
                tracking?.driverName ?? order.driverName ?? 'Assigning driver',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(driverPhone ?? ''),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Call driver',
                    onPressed: driverPhone == null
                        ? null
                        : () => callDriver(driverPhone),
                    icon: const Icon(Icons.phone_rounded),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: 'WhatsApp driver',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: driverPhone == null
                        ? null
                        : () => whatsappDriver(order, driverPhone),
                    icon: const Icon(Icons.chat_rounded),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (final stage in [
            OrderStage.accepted,
            OrderStage.preparing,
            OrderStage.onTheWay,
            OrderStage.completed,
          ])
            _DeliveryStep(
              label: stage.label,
              complete: order.stage.index >= stage.index,
              active: order.stage == stage,
            ),
        ],
      );
    },
  );
}

class _NoActiveDelivery extends StatelessWidget {
  const _NoActiveDelivery();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_off_outlined,
            size: 58,
            color: AppColors.muted,
          ),
          const SizedBox(height: 14),
          Text(
            'No active delivery',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Text(
            'Live tracking appears after your order is accepted and a driver is assigned.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
    ),
    child: Icon(icon, color: Colors.white),
  );
}

class _DeliveryStep extends StatelessWidget {
  const _DeliveryStep({
    required this.label,
    required this.complete,
    this.active = false,
  });
  final String label;
  final bool complete;
  final bool active;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(
          complete
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: active
              ? AppColors.ember
              : complete
              ? AppColors.sage
              : AppColors.sand,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.session});
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final user = session.user!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Your profile', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 22),
        CircleAvatar(
          radius: 42,
          backgroundColor: AppColors.sand,
          child: Text(
            user.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            user.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        Center(
          child: Text(
            user.phone,
            style: const TextStyle(color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 26),
        _ProfileTile(
          icon: Icons.location_on_outlined,
          title: 'Delivery address',
          subtitle: user.latitude == null
              ? '${user.address}\nGPS location not set'
              : '${user.address}\nGPS location saved',
        ),
        _ProfileTile(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'WhatsApp verified',
          subtitle: user.phoneVerified
              ? 'Your number is verified'
              : 'Verification needed',
        ),
        const SizedBox(height: 18),
        FilledButton.tonalIcon(
          onPressed: () => showEditProfile(context, session),
          icon: const Icon(Icons.edit_location_alt_outlined),
          label: const Text('Edit profile and location'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: session.logout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      leading: Icon(icon, color: AppColors.ember),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
    ),
  );
}

Future<void> showEditProfile(
  BuildContext context,
  SessionController session,
) async {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: session.user!.name);
  final addressController = TextEditingController(text: session.user!.address);
  var latitude = session.user!.latitude;
  var longitude = session.user!.longitude;
  var location = latitude == null || longitude == null
      ? null
      : CapturedLocation(latitude: latitude, longitude: longitude);
  var locating = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Delivery profile'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'Enter your full name'
                      : null,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: addressController,
                  validator: (value) => (value?.trim().length ?? 0) < 3
                      ? 'Enter your delivery address'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Delivery address',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: locating
                        ? null
                        : () async {
                            setDialogState(() => locating = true);
                            try {
                              location = await const DeviceLocationService()
                                  .captureCurrent();
                              latitude = location!.latitude;
                              longitude = location!.longitude;
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.toString())),
                                );
                              }
                            } finally {
                              setDialogState(() => locating = false);
                            }
                          },
                    icon: locating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            latitude == null
                                ? Icons.my_location_rounded
                                : Icons.check_circle_rounded,
                          ),
                    label: Text(
                      latitude == null
                          ? 'Use current GPS location'
                          : 'Update GPS location',
                    ),
                  ),
                ),
                if (location != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'GPS: ${location!.label}',
                    style: const TextStyle(
                      color: AppColors.sage,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              if (latitude == null || longitude == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Select your GPS location')),
                );
                return;
              }
              try {
                await session.updateProfile(
                  name: nameController.text.trim(),
                  address: addressController.text.trim(),
                  latitude: latitude!,
                  longitude: longitude!,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  nameController.dispose();
  addressController.dispose();
}
