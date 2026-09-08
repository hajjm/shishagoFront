import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/app_store.dart';
import '../../models/app_models.dart';
import '../../services/session_controller.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/notifications_button.dart';
import '../../widgets/order_widgets.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key, required this.store, required this.session});
  final ChichagoStore store;
  final SessionController session;

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      OwnerOrdersPage(store: widget.store),
      OwnerCatalogPage(store: widget.store),
      OwnerPeoplePage(store: widget.store),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: wide
                ? Text(
                    ['Orders', 'Catalog', 'People'][selectedIndex],
                    style: Theme.of(context).textTheme.headlineMedium,
                  )
                : const BrandMark(compact: true),
            actions: [
              NotificationsButton(store: widget.store),
              IconButton(
                onPressed: widget.store.refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                onPressed: widget.session.logout,
                icon: const Icon(Icons.logout_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Row(
            children: [
              if (wide)
                NavigationRail(
                  minWidth: 88,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => selectedIndex = index),
                  leading: const Padding(
                    padding: EdgeInsets.only(bottom: 28),
                    child: Icon(
                      Icons.local_fire_department_rounded,
                      color: AppColors.ember,
                      size: 38,
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long_rounded),
                      label: Text('Orders'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2_rounded),
                      label: Text('Catalog'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people_outline_rounded),
                      selectedIcon: Icon(Icons.people_rounded),
                      label: Text('People'),
                    ),
                  ],
                ),
              Expanded(
                child: IndexedStack(index: selectedIndex, children: pages),
              ),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => selectedIndex = index),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      label: 'Orders',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      label: 'Catalog',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.people_outline_rounded),
                      label: 'People',
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class OwnerOrdersPage extends StatefulWidget {
  const OwnerOrdersPage({super.key, required this.store});
  final ChichagoStore store;

  @override
  State<OwnerOrdersPage> createState() => _OwnerOrdersPageState();
}

class _OwnerOrdersPageState extends State<OwnerOrdersPage> {
  String filter = 'All';
  DateTime? fromDate;
  DateTime? toDate;
  bool newestFirst = true;

  String? get statusFilter =>
      filter == 'All' ? null : filter.toLowerCase().replaceAll(' ', '_');

  Future<void> applyFilters() => widget.store.filterOrders(
    status: statusFilter,
    from: fromDate,
    to: toDate,
    sortOrder: newestFirst ? 'desc' : 'asc',
  );

  Future<void> setFilter(String value) async {
    setState(() => filter = value);
    await applyFilters();
  }

  Future<void> pickDate(bool isFrom) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (isFrom ? fromDate : toDate) ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (selected == null) return;
    setState(() {
      if (isFrom) {
        fromDate = selected;
      } else {
        toDate = selected;
      }
    });
    await applyFilters();
  }

  Future<void> clearDates() async {
    setState(() {
      fromDate = null;
      toDate = null;
    });
    await applyFilters();
  }

  Future<void> setSort(bool newest) async {
    setState(() => newestFirst = newest);
    await applyFilters();
  }

  Future<void> export() async {
    try {
      await widget.store.exportOrders(
        status: statusFilter,
        from: fromDate,
        to: toDate,
        sortOrder: newestFirst ? 'desc' : 'asc',
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Order export saved')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final summary = widget.store.dashboard;
      return RefreshIndicator(
        onRefresh: widget.store.refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today at a glance',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(DateTime.now()),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  onPressed: export,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  label: 'Orders today',
                  value: '${summary['order_count'] ?? 0}',
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.ember,
                ),
                _MetricCard(
                  label: 'Revenue',
                  value:
                      '\$${(summary['revenue'] as num? ?? 0).toStringAsFixed(2)}',
                  icon: Icons.payments_outlined,
                  color: AppColors.sage,
                ),
                _MetricCard(
                  label: 'Active deliveries',
                  value: '${summary['active_delivery_count'] ?? 0}',
                  icon: Icons.delivery_dining_rounded,
                  color: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              'All orders',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    [
                          'All',
                          'Pending',
                          'Accepted',
                          'Picked up',
                          'On the way',
                          'Completed',
                          'Cancelled',
                        ]
                        .map(
                          (label) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(label),
                              selected: filter == label,
                              onSelected: (_) => setFilter(label),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => pickDate(true),
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text(
                    fromDate == null
                        ? 'From date'
                        : 'From ${MaterialLocalizations.of(context).formatMediumDate(fromDate!)}',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => pickDate(false),
                  icon: const Icon(Icons.event_rounded),
                  label: Text(
                    toDate == null
                        ? 'To date'
                        : 'To ${MaterialLocalizations.of(context).formatMediumDate(toDate!)}',
                  ),
                ),
                if (fromDate != null || toDate != null)
                  TextButton.icon(
                    onPressed: clearDates,
                    icon: const Icon(Icons.clear_rounded),
                    label: const Text('Clear dates'),
                  ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.arrow_downward_rounded),
                      label: Text('Newest'),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.arrow_upward_rounded),
                      label: Text('Oldest'),
                    ),
                  ],
                  selected: {newestFirst},
                  onSelectionChanged: (values) => setSort(values.first),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (widget.store.orders.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No orders match this filter.'),
                ),
              ),
            ...widget.store.orders.map(
              (order) => _OwnerOrderCard(order: order, store: widget.store),
            ),
          ],
        ),
      );
    },
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 245,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 14),
            Text(value, style: Theme.of(context).textTheme.headlineLarge),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ),
  );
}

class _OwnerOrderCard extends StatelessWidget {
  const _OwnerOrderCard({required this.order, required this.store});
  final AppOrder order;
  final ChichagoStore store;

  Future<void> assign(BuildContext context) async {
    final drivers = store.users
        .where((user) => user.role == UserRole.driver && user.isActive)
        .toList();
    final selected = await showDialog<AppUser>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Assign a driver'),
        children: drivers.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Create an active driver first.'),
                ),
              ]
            : drivers
                  .map(
                    (driver) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, driver),
                      child: ListTile(
                        leading: const Icon(Icons.delivery_dining_rounded),
                        title: Text(driver.name),
                        subtitle: Text(driver.phone),
                      ),
                    ),
                  )
                  .toList(),
      ),
    );
    if (selected != null) await store.assignDriver(order, selected);
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      order.reference,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 10),
                    OrderStatusPill(stage: order.stage),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  order.clientName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${order.items}\n${order.address}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${order.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              if (order.stage == OrderStage.pending)
                FilledButton.tonal(
                  onPressed: () =>
                      store.changeOrderStatus(order, OrderStage.accepted),
                  child: const Text('Accept order'),
                )
              else if (order.stage == OrderStage.accepted &&
                  order.driverId == null)
                OutlinedButton.icon(
                  onPressed: () => assign(context),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Assign driver'),
                )
              else if (order.driverName != null)
                Text(
                  order.driverName!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class OwnerCatalogPage extends StatelessWidget {
  const OwnerCatalogPage({super.key, required this.store});
  final ChichagoStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Catalog',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const Text(
                    'Manage Chicha and Market items.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => showProductEditor(context, store),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add item'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        ...store.products.map(
          (product) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 9,
              ),
              leading: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(product.icon, color: AppColors.ember),
              ),
              title: Text(
                product.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${product.category.name} · ${product.available ? 'Available' : 'Hidden'}',
              ),
              trailing: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '\$${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  IconButton(
                    onPressed: () =>
                        showProductEditor(context, store, product: product),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> showProductEditor(
  BuildContext context,
  ChichagoStore store, {
  Product? product,
}) async {
  final name = TextEditingController(text: product?.name);
  final description = TextEditingController(text: product?.description);
  final price = TextEditingController(text: product?.price.toString());
  var category = product?.category ?? ProductCategory.chicha;
  var available = product?.available ?? true;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(product == null ? 'Add item' : 'Edit item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField(
                initialValue: category,
                items: ProductCategory.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => category = value!),
              ),
              SwitchListTile(
                value: available,
                onChanged: (value) => setState(() => available = value),
                title: const Text('Available'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final parsedPrice = double.tryParse(price.text);
              if (parsedPrice == null) return;
              await store.saveProduct(
                existing: product,
                name: name.text,
                description: description.text,
                category: category,
                price: parsedPrice,
                available: available,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  description.dispose();
  price.dispose();
}

class OwnerPeoplePage extends StatelessWidget {
  const OwnerPeoplePage({super.key, required this.store});
  final ChichagoStore store;

  Future<void> addDriver(BuildContext context) async {
    final name = TextEditingController();
    final phone = TextEditingController(text: '+961 ');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add driver'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'WhatsApp phone'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await store.createDriver(name: name.text, phone: phone.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    name.dispose();
    phone.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'People',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const Text(
                    'Manage clients and drivers.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => addDriver(context),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add driver'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        ...store.users
            .where((user) => user.role != UserRole.owner)
            .map(
              (user) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.sand,
                    child: Text(user.name.substring(0, 1).toUpperCase()),
                  ),
                  title: Text(
                    user.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('${user.role.name} · ${user.phone}'),
                  trailing: Switch(
                    value: user.isActive,
                    onChanged: (value) => store.setUserActive(user, value),
                  ),
                ),
              ),
            ),
      ],
    ),
  );
}
