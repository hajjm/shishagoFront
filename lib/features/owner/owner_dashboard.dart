import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../data/app_store.dart';
import '../../models/app_models.dart';
import '../../services/session_controller.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/notifications_button.dart';
import '../../widgets/order_widgets.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key, required this.store, required this.session});
  final ShishaGoStore store;
  final SessionController session;

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  int selectedIndex = 0;
  bool menuExpanded = true;

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
                : const BrandLogo(size: 40),
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
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.paper,
                    border: Border(right: BorderSide(color: AppColors.sand)),
                  ),
                  child: NavigationRail(
                    extended: menuExpanded,
                    minWidth: 80,
                    minExtendedWidth: 224,
                    backgroundColor: AppColors.paper,
                    indicatorColor: AppColors.ember.withValues(alpha: 0.15),
                    selectedIconTheme: const IconThemeData(
                      color: AppColors.emberDark,
                    ),
                    selectedLabelTextStyle: const TextStyle(
                      color: AppColors.emberDark,
                      fontWeight: FontWeight.w800,
                    ),
                    unselectedLabelTextStyle: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) =>
                        setState(() => selectedIndex = index),
                    leading: Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: Column(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: menuExpanded
                                ? const BrandMark(
                                    key: ValueKey('expanded-brand'),
                                    compact: true,
                                  )
                                : const BrandLogo(
                                    key: ValueKey('compact-brand'),
                                    size: 44,
                                  ),
                          ),
                          const SizedBox(height: 14),
                          IconButton.filledTonal(
                            tooltip: menuExpanded
                                ? 'Collapse menu'
                                : 'Expand menu',
                            onPressed: () =>
                                setState(() => menuExpanded = !menuExpanded),
                            icon: Icon(
                              menuExpanded
                                  ? Icons.keyboard_double_arrow_left_rounded
                                  : Icons.keyboard_double_arrow_right_rounded,
                            ),
                          ),
                        ],
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
  final ShishaGoStore store;

  @override
  State<OwnerOrdersPage> createState() => _OwnerOrdersPageState();
}

class _OwnerOrdersPageState extends State<OwnerOrdersPage> {
  String filter = 'All';
  DateTime? fromDate;
  DateTime? toDate;
  bool newestFirst = true;
  final searchController = TextEditingController();
  Timer? searchDebounce;

  String? get statusFilter => switch (filter) {
    'All' => null,
    'Preparing' => 'preparing',
    'On the way' => 'on_the_way',
    'Delivered' => 'completed',
    'Finished using' => 'finished_using',
    _ => filter.toLowerCase(),
  };

  Future<void> applyFilters() => widget.store.filterOrders(
    status: statusFilter,
    search: searchController.text,
    from: fromDate,
    to: toDate,
    sortOrder: newestFirst ? 'desc' : 'asc',
  );

  Future<void> setFilter(String value) async {
    setState(() => filter = value);
    await applyFilters();
  }

  void searchOrders(String _) {
    searchDebounce?.cancel();
    searchDebounce = Timer(const Duration(milliseconds: 350), applyFilters);
  }

  Future<void> clearSearch() async {
    searchDebounce?.cancel();
    searchController.clear();
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
      final savedPath = await widget.store.exportOrders(
        status: statusFilter,
        search: searchController.text,
        from: fromDate,
        to: toDate,
        sortOrder: newestFirst ? 'desc' : 'asc',
      );
      if (mounted) {
        final saved = savedPath != null && savedPath.trim().isNotEmpty;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved
                  ? 'Order export saved to the selected folder'
                  : 'Order export cancelled',
            ),
          ),
        );
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
  void dispose() {
    searchDebounce?.cancel();
    searchController.dispose();
    super.dispose();
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
                  label: const Text('Export Excel'),
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: TextField(
                controller: searchController,
                onChanged: searchOrders,
                onSubmitted: (_) => applyFilters(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search by order ID',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: searchController,
                    builder: (context, value, _) => value.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: clearSearch,
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    [
                          'All',
                          'Pending',
                          'Accepted',
                          'Preparing',
                          'On the way',
                          'Delivered',
                          'Finished using',
                          'Collected',
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
  final ShishaGoStore store;

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
              else if (order.stage == OrderStage.finishedUsing)
                FilledButton.icon(
                  onPressed: () =>
                      store.changeOrderStatus(order, OrderStage.collected),
                  icon: const Icon(Icons.inventory_2_rounded),
                  label: const Text('Mark collected'),
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

class OwnerCatalogPage extends StatefulWidget {
  const OwnerCatalogPage({super.key, required this.store});
  final ShishaGoStore store;

  @override
  State<OwnerCatalogPage> createState() => _OwnerCatalogPageState();
}

class _OwnerCatalogPageState extends State<OwnerCatalogPage> {
  ProductCategory selectedSection = ProductCategory.chicha;
  String? selectedMarketCategoryId;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final products = widget.store.products.where((product) {
        if (product.category != selectedSection) return false;
        return selectedSection != ProductCategory.market ||
            selectedMarketCategoryId == null ||
            product.marketCategoryId == selectedMarketCategoryId;
      }).toList();
      return ListView(
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
                      'Manage Shisha and Market items.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (selectedSection == ProductCategory.market)
                    OutlinedButton.icon(
                      onPressed: () =>
                          showMarketCategoryEditor(context, widget.store),
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('Add category'),
                    ),
                  FilledButton.icon(
                    onPressed: () => showProductEditor(
                      context,
                      widget.store,
                      initialCategory: selectedSection,
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add item'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<ProductCategory>(
              segments: const [
                ButtonSegment(
                  value: ProductCategory.chicha,
                  icon: Icon(Icons.local_fire_department_outlined),
                  label: Text('Shisha'),
                ),
                ButtonSegment(
                  value: ProductCategory.market,
                  icon: Icon(Icons.shopping_bag_outlined),
                  label: Text('Market'),
                ),
              ],
              selected: {selectedSection},
              onSelectionChanged: (selection) => setState(() {
                selectedSection = selection.first;
                selectedMarketCategoryId = null;
              }),
            ),
          ),
          if (selectedSection == ProductCategory.market) ...[
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: selectedMarketCategoryId == null,
                    onSelected: (_) =>
                        setState(() => selectedMarketCategoryId = null),
                  ),
                  ...widget.store.marketCategories
                      .where((category) => category.isActive)
                      .map(
                        (category) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            label: Text(category.name),
                            selected: selectedMarketCategoryId == category.id,
                            onSelected: (_) => setState(
                              () => selectedMarketCategoryId = category.id,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  selectedSection == ProductCategory.market
                      ? 'No market items in this category yet.'
                      : 'No Shisha items yet.',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            ),
          ...products.map(
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
                  '${product.category == ProductCategory.market ? product.marketCategoryName ?? 'Market' : 'Shisha'} · ${product.available ? 'Available' : 'Hidden'}${product.customizationOptions.isEmpty ? '' : ' · ${product.customizationOptions.length} customization option${product.customizationOptions.length == 1 ? '' : 's'}'}',
                ),
                trailing: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 10),
                    Tooltip(
                      message: product.available
                          ? 'Available to clients'
                          : 'Hidden from clients',
                      child: Switch.adaptive(
                        value: product.available,
                        onChanged: widget.store.loading
                            ? null
                            : (value) async {
                                try {
                                  await widget.store.setProductAvailability(
                                    product,
                                    value,
                                  );
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error.toString())),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit item',
                      onPressed: () => showProductEditor(
                        context,
                        widget.store,
                        product: product,
                      ),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> showMarketCategoryEditor(
  BuildContext context,
  ShishaGoStore store,
) async {
  final name = TextEditingController();
  String? nameError;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Add market category'),
        content: TextField(
          controller: name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Category name',
            hintText: 'For example, Charcoal',
            errorText: nameError,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: store.loading
                ? null
                : () async {
                    if (name.text.trim().length < 2) {
                      setState(() => nameError = 'Enter a category name');
                      return;
                    }
                    try {
                      await store.createMarketCategory(name.text);
                      if (context.mounted) Navigator.pop(context);
                    } catch (_) {
                      if (context.mounted) {
                        setState(() => nameError = store.error);
                      }
                    }
                  },
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
}

class _CustomizationChoiceDraft {
  _CustomizationChoiceDraft({this.name = '', this.priceAdjustment = 0});

  String name;
  double priceAdjustment;
}

class _CustomizationOptionDraft {
  _CustomizationOptionDraft({
    this.name = '',
    this.required = false,
    this.allowMultiple = false,
    List<_CustomizationChoiceDraft>? choices,
  }) : choices = choices ?? [_CustomizationChoiceDraft()];

  String name;
  bool required;
  bool allowMultiple;
  final List<_CustomizationChoiceDraft> choices;
}

Future<void> showProductEditor(
  BuildContext context,
  ShishaGoStore store, {
  Product? product,
  ProductCategory? initialCategory,
}) async {
  final name = TextEditingController(text: product?.name);
  final description = TextEditingController(text: product?.description);
  final price = TextEditingController(text: product?.price.toString());
  final customizationOptions =
      product?.customizationOptions
          .map(
            (option) => _CustomizationOptionDraft(
              name: option.name,
              required: option.minSelections > 0,
              allowMultiple: option.maxSelections > 1,
              choices: option.choices
                  .map(
                    (choice) => _CustomizationChoiceDraft(
                      name: choice.name,
                      priceAdjustment: choice.priceAdjustment,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList() ??
      [];
  var category = product?.category ?? initialCategory ?? ProductCategory.chicha;
  String? marketCategoryId = product?.marketCategoryId;
  if (category == ProductCategory.market && marketCategoryId == null) {
    final activeCategories = store.marketCategories.where(
      (value) => value.isActive,
    );
    if (activeCategories.isNotEmpty) {
      marketCategoryId = activeCategories.first.id;
    }
  }
  String? priceError;
  String? categoryError;
  String? customizationError;
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [_priceInputFormatter],
                onChanged: (_) {
                  if (priceError != null) setState(() => priceError = null);
                },
                decoration: InputDecoration(
                  labelText: 'Price',
                  errorText: priceError,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField(
                initialValue: category,
                items: ProductCategory.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  category = value!;
                  categoryError = null;
                  if (category == ProductCategory.market &&
                      marketCategoryId == null) {
                    final activeCategories = store.marketCategories.where(
                      (entry) => entry.isActive,
                    );
                    if (activeCategories.isNotEmpty) {
                      marketCategoryId = activeCategories.first.id;
                    }
                  }
                }),
              ),
              if (category == ProductCategory.market) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: marketCategoryId,
                  decoration: InputDecoration(
                    labelText: 'Market category',
                    errorText: categoryError,
                  ),
                  items: store.marketCategories
                      .where((value) => value.isActive)
                      .map(
                        (value) => DropdownMenuItem(
                          value: value.id,
                          child: Text(value.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    marketCategoryId = value;
                    categoryError = null;
                  }),
                ),
                if (store.marketCategories.every((value) => !value.isActive))
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Add a market category before creating this item.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
              ],
              const Divider(height: 28),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Customization options',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(
                      () =>
                          customizationOptions.add(_CustomizationOptionDraft()),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add option'),
                  ),
                ],
              ),
              if (customizationOptions.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No customization. Clients add this item directly.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              for (
                var optionIndex = 0;
                optionIndex < customizationOptions.length;
                optionIndex++
              )
                Card(
                  margin: const EdgeInsets.only(top: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue:
                                    customizationOptions[optionIndex].name,
                                onChanged: (value) =>
                                    customizationOptions[optionIndex].name =
                                        value,
                                decoration: const InputDecoration(
                                  labelText: 'Option name',
                                  hintText: 'For example, Bowl size',
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove option',
                              onPressed: () => setState(
                                () =>
                                    customizationOptions.removeAt(optionIndex),
                              ),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: customizationOptions[optionIndex].required,
                          onChanged: (value) => setState(
                            () => customizationOptions[optionIndex].required =
                                value,
                          ),
                          title: const Text('Required'),
                          dense: true,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value:
                              customizationOptions[optionIndex].allowMultiple,
                          onChanged: (value) => setState(
                            () =>
                                customizationOptions[optionIndex]
                                        .allowMultiple =
                                    value,
                          ),
                          title: const Text('Allow multiple choices'),
                          dense: true,
                        ),
                        for (
                          var choiceIndex = 0;
                          choiceIndex <
                              customizationOptions[optionIndex].choices.length;
                          choiceIndex++
                        )
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue:
                                        customizationOptions[optionIndex]
                                            .choices[choiceIndex]
                                            .name,
                                    onChanged: (value) =>
                                        customizationOptions[optionIndex]
                                                .choices[choiceIndex]
                                                .name =
                                            value,
                                    decoration: const InputDecoration(
                                      labelText: 'Choice',
                                      hintText: 'For example, Large',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 112,
                                  child: TextFormField(
                                    initialValue:
                                        customizationOptions[optionIndex]
                                            .choices[choiceIndex]
                                            .priceAdjustment
                                            .toStringAsFixed(2),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    inputFormatters: [_priceInputFormatter],
                                    onChanged: (value) =>
                                        customizationOptions[optionIndex]
                                                .choices[choiceIndex]
                                                .priceAdjustment =
                                            double.tryParse(value) ?? 0,
                                    decoration: const InputDecoration(
                                      labelText: 'Extra price',
                                      prefixText: '\$',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove choice',
                                  onPressed: () => setState(
                                    () => customizationOptions[optionIndex]
                                        .choices
                                        .removeAt(choiceIndex),
                                  ),
                                  icon: const Icon(
                                    Icons.remove_circle_outline_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(
                              () => customizationOptions[optionIndex].choices
                                  .add(_CustomizationChoiceDraft()),
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add choice'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (customizationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    customizationError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (product != null)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (confirmationContext) => AlertDialog(
                    title: const Text('Delete this item?'),
                    content: Text(
                      '${product.name} will be removed from the catalog. Existing order history will be preserved.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(confirmationContext, false),
                        child: const Text('Keep item'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(
                            confirmationContext,
                          ).colorScheme.error,
                        ),
                        onPressed: () =>
                            Navigator.pop(confirmationContext, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                try {
                  await store.deleteProduct(product);
                  if (context.mounted) Navigator.pop(context);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                }
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final parsedPrice = double.tryParse(price.text);
              if (parsedPrice == null || parsedPrice <= 0) {
                setState(() => priceError = 'Enter a valid price');
                return;
              }
              if (category == ProductCategory.market &&
                  marketCategoryId == null) {
                setState(() => categoryError = 'Choose a market category');
                return;
              }
              if (customizationOptions.any(
                (option) =>
                    option.name.trim().isEmpty ||
                    option.choices.isEmpty ||
                    option.choices.any((choice) => choice.name.trim().isEmpty),
              )) {
                setState(() {
                  customizationError =
                      'Every option needs a name and at least one named choice';
                });
                return;
              }
              await store.saveProduct(
                existing: product,
                name: name.text,
                description: description.text,
                category: category,
                marketCategoryId: marketCategoryId,
                price: parsedPrice,
                available: product?.available ?? true,
                customizationOptions: customizationOptions
                    .map(
                      (option) => {
                        'name': option.name.trim(),
                        'min_selections': option.required ? 1 : 0,
                        'max_selections': option.allowMultiple
                            ? option.choices.length
                            : 1,
                        'choices': option.choices
                            .map(
                              (choice) => {
                                'name': choice.name.trim(),
                                'price_adjustment': choice.priceAdjustment,
                                'is_available': true,
                              },
                            )
                            .toList(),
                      },
                    )
                    .toList(),
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

final _priceInputFormatter = TextInputFormatter.withFunction((
  oldValue,
  newValue,
) {
  final validPrice = RegExp(r'^\d*(?:\.\d{0,2})?$');
  return validPrice.hasMatch(newValue.text) ? newValue : oldValue;
});

class OwnerPeoplePage extends StatefulWidget {
  const OwnerPeoplePage({super.key, required this.store});
  final ShishaGoStore store;

  @override
  State<OwnerPeoplePage> createState() => _OwnerPeoplePageState();
}

class _OwnerPeoplePageState extends State<OwnerPeoplePage> {
  UserRole selectedRole = UserRole.client;

  Future<void> deleteDriver(AppUser driver) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete driver?'),
        content: Text(
          'Delete ${driver.name} permanently? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.store.deleteDriver(driver);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${driver.name} was deleted.')));
    } catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete driver: $exception')),
      );
    }
  }

  Future<void> addDriver() async {
    final driver = await showDialog<({String name, String phone})>(
      context: context,
      builder: (_) => const _AddDriverDialog(),
    );

    if (driver == null || !mounted) return;

    try {
      await widget.store.createDriver(name: driver.name, phone: driver.phone);
    } catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create driver: $exception')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final users = widget.store.users
          .where((user) => user.role == selectedRole)
          .toList();
      final roleLabel = selectedRole == UserRole.client ? 'clients' : 'drivers';
      return ListView(
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
                    Text(
                      'Manage $roleLabel.',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (selectedRole == UserRole.driver)
                FilledButton.icon(
                  onPressed: addDriver,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Add driver'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<UserRole>(
              segments: const [
                ButtonSegment(
                  value: UserRole.client,
                  icon: Icon(Icons.people_outline_rounded),
                  label: Text('Clients'),
                ),
                ButtonSegment(
                  value: UserRole.driver,
                  icon: Icon(Icons.delivery_dining_outlined),
                  label: Text('Drivers'),
                ),
              ],
              selected: {selectedRole},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => selectedRole = selection.first),
            ),
          ),
          const SizedBox(height: 22),
          if (users.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 56),
              child: Center(
                child: Text(
                  'No $roleLabel yet.',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            ...users.map(
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: user.isActive,
                        onChanged: (value) =>
                            widget.store.setUserActive(user, value),
                      ),
                      if (user.role == UserRole.driver)
                        IconButton(
                          tooltip: 'Delete driver',
                          onPressed: () => deleteDriver(user),
                          color: Colors.red,
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _AddDriverDialog extends StatefulWidget {
  const _AddDriverDialog();

  @override
  State<_AddDriverDialog> createState() => _AddDriverDialogState();
}

class _AddDriverDialogState extends State<_AddDriverDialog> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController(text: '+961 ');

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void submit() {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) return;
    Navigator.pop(context, (name: name, phone: phone));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add driver'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: nameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Full name'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
          decoration: const InputDecoration(labelText: 'WhatsApp phone'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: submit, child: const Text('Create')),
    ],
  );
}
