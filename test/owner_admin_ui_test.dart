import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shishago/data/app_store.dart';
import 'package:shishago/features/driver/driver_dashboard.dart';
import 'package:shishago/features/owner/owner_dashboard.dart';
import 'package:shishago/models/app_models.dart';
import 'package:shishago/services/session_controller.dart';
import 'package:shishago/services/shishago_api.dart';

ShishaGoStore createStore() {
  final api = ShishaGoApi(baseUrl: 'http://127.0.0.1:8001');
  return ShishaGoStore(api: api, session: SessionController(api));
}

const owner = AppUser(
  id: 'owner-1',
  name: 'Owner',
  phone: '+96170000000',
  role: UserRole.owner,
  address: 'Beirut',
  isActive: true,
  phoneVerified: true,
);

AppOrder assignedOrder({
  required String id,
  required String reference,
  required String clientName,
  required String clientPhone,
  required OrderStage stage,
  int? rating,
  String? ratingComment,
}) => AppOrder(
  id: id,
  reference: reference,
  clientId: 'client-$id',
  clientName: clientName,
  clientPhone: clientPhone,
  driverId: 'driver-1',
  driverName: 'Driver One',
  lines: const [],
  total: 20,
  stage: stage,
  createdAt: DateTime(2026, 9, 10),
  address: 'Beirut',
  latitude: 33.89,
  longitude: 35.50,
  rating: rating,
  ratingComment: ratingComment,
);

void main() {
  testWidgets('owner metrics use a collapsed summary on phones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = createStore()
      ..dashboard = {
        'order_count': 3,
        'revenue': 42.5,
        'active_delivery_count': 2,
      };
    addTearDown(store.dispose);
    addTearDown(store.api.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnerOrdersPage(store: store)),
      ),
    );

    expect(find.text("Today's summary"), findsOneWidget);
    expect(find.text('Orders today'), findsNothing);
    await tester.tap(find.text("Today's summary"));
    await tester.pumpAndSettle();
    expect(find.text('Orders today'), findsOneWidget);
    expect(find.text('\$42.50'), findsOneWidget);
    expect(find.text('Active deliveries'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner orders includes order ID search', (tester) async {
    final store = createStore();
    addTearDown(store.dispose);
    addTearDown(store.api.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnerOrdersPage(store: store)),
      ),
    );

    expect(
      find.widgetWithText(TextField, 'Search by order ID'),
      findsOneWidget,
    );
  });

  testWidgets('owner sees the client rating beside its order', (tester) async {
    final store = createStore();
    addTearDown(store.dispose);
    addTearDown(store.api.close);
    store.orders = [
      assignedOrder(
        id: 'rated-1',
        reference: 'SH-RATED',
        clientName: 'Happy Client',
        clientPhone: '+96170000003',
        stage: OrderStage.finishedUsing,
        rating: 4,
        ratingComment: 'Very good delivery',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnerOrdersPage(store: store)),
      ),
    );

    expect(find.text('4/5'), findsOneWidget);
    expect(find.text('Very good delivery'), findsOneWidget);
  });

  testWidgets('catalog price accepts digits and two decimal places only', (
    tester,
  ) async {
    final store = createStore();
    addTearDown(store.dispose);
    addTearDown(store.api.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnerCatalogPage(store: store)),
      ),
    );
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();

    final priceField = find.widgetWithText(TextField, 'Price');
    final controller = tester.widget<TextField>(priceField).controller!;

    await tester.enterText(priceField, '12');
    expect(controller.text, '12');
    await tester.enterText(priceField, '12a');
    expect(controller.text, '12');
    await tester.enterText(priceField, '12.34');
    expect(controller.text, '12.34');
    await tester.enterText(priceField, '12.345');
    expect(controller.text, '12.34');

    await tester.tap(find.text('Add option'));
    await tester.pumpAndSettle();
    expect(find.text('Option name'), findsOneWidget);
    expect(find.text('Add choice'), findsOneWidget);
    expect(find.text('Allow multiple choices'), findsOneWidget);
  });

  testWidgets('catalog availability is on the row and edit offers delete', (
    tester,
  ) async {
    final store = createStore();
    addTearDown(store.dispose);
    addTearDown(store.api.close);
    store.products = const [
      Product(
        id: 'shisha-1',
        name: 'Fresh Mint',
        description: 'Mint flavor',
        category: ProductCategory.chicha,
        price: 18,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnerCatalogPage(store: store)),
      ),
    );

    expect(find.byType(Switch), findsOneWidget);
    await tester.tap(find.byTooltip('Edit item'));
    await tester.pumpAndSettle();
    expect(find.text('Edit item'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Available'), findsNothing);
  });

  testWidgets('catalog separates Shisha and categorized Market items', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = createStore();
    addTearDown(store.dispose);
    addTearDown(store.api.close);
    store.marketCategories = const [
      MarketCategory(
        id: 'cat-charcoal',
        name: 'Charcoal',
        slug: 'charcoal',
        isActive: true,
      ),
      MarketCategory(
        id: 'cat-accessories',
        name: 'Accessories',
        slug: 'accessories',
        isActive: true,
      ),
    ];
    store.products = const [
      Product(
        id: 'shisha-1',
        name: 'Fresh Mint',
        description: '',
        category: ProductCategory.chicha,
        price: 18,
      ),
      Product(
        id: 'market-1',
        name: 'Natural Charcoal',
        description: '',
        category: ProductCategory.market,
        marketCategoryId: 'cat-charcoal',
        marketCategoryName: 'Charcoal',
        price: 6.5,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnerCatalogPage(store: store)),
      ),
    );
    expect(find.text('Fresh Mint'), findsOneWidget);
    expect(find.text('Natural Charcoal'), findsNothing);

    await tester.tap(find.text('Market'));
    await tester.pumpAndSettle();
    expect(find.text('Fresh Mint'), findsNothing);
    expect(find.text('Natural Charcoal'), findsOneWidget);
    expect(find.text('Charcoal'), findsWidgets);
    expect(find.text('Accessories'), findsOneWidget);
    expect(find.text('Add category'), findsOneWidget);

    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    expect(find.text('Market category'), findsOneWidget);
  });

  testWidgets('people page separates clients and drivers', (tester) async {
    final store = createStore();
    addTearDown(store.dispose);
    addTearDown(store.api.close);
    store.users = const [
      AppUser(
        id: 'client-1',
        name: 'Client One',
        phone: '+96170000001',
        role: UserRole.client,
        address: 'Beirut',
        isActive: true,
        phoneVerified: true,
      ),
      AppUser(
        id: 'driver-1',
        name: 'Driver One',
        phone: '+96170000002',
        role: UserRole.driver,
        address: '',
        isActive: true,
        phoneVerified: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OwnerPeoplePage(store: store)),
      ),
    );

    expect(find.text('Client One'), findsOneWidget);
    expect(find.text('Driver One'), findsNothing);
    expect(find.text('Add driver'), findsNothing);

    await tester.tap(find.text('Drivers'));
    await tester.pumpAndSettle();

    expect(find.text('Client One'), findsNothing);
    expect(find.text('Driver One'), findsOneWidget);
    expect(find.text('Add driver'), findsOneWidget);
    expect(find.byTooltip('Delete driver'), findsOneWidget);
  });

  testWidgets(
    'add driver dialog owns controllers for its full route lifetime',
    (tester) async {
      final store = createStore();
      addTearDown(store.dispose);
      addTearDown(store.api.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OwnerPeoplePage(store: store)),
        ),
      );
      await tester.tap(find.text('Drivers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add driver'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Full name'),
        'Driver Two',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Add driver'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('owner side menu expands and collapses', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = createStore();
    store.session.user = owner;
    addTearDown(store.dispose);
    addTearDown(store.api.close);

    await tester.pumpWidget(
      MaterialApp(
        home: OwnerDashboard(store: store, session: store.session),
      ),
    );

    expect(find.byTooltip('Collapse menu'), findsOneWidget);
    await tester.tap(find.byTooltip('Collapse menu'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Expand menu'), findsOneWidget);
  });

  testWidgets('driver can select and manage multiple active deliveries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = createStore();
    store.session.user = const AppUser(
      id: 'driver-1',
      name: 'Driver One',
      phone: '+96171111111',
      role: UserRole.driver,
      address: '',
      isActive: true,
      phoneVerified: true,
    );
    store.orders = [
      assignedOrder(
        id: '3',
        reference: 'SH-003',
        clientName: 'Collection Client',
        clientPhone: '+96170000003',
        stage: OrderStage.finishedUsing,
      ),
      assignedOrder(
        id: '1',
        reference: 'SH-001',
        clientName: 'First Client',
        clientPhone: '+96170000001',
        stage: OrderStage.accepted,
      ),
      assignedOrder(
        id: '2',
        reference: 'SH-002',
        clientName: 'Second Client',
        clientPhone: '+96170000002',
        stage: OrderStage.preparing,
      ),
    ];
    addTearDown(store.dispose);
    addTearDown(store.api.close);

    await tester.pumpWidget(
      MaterialApp(
        home: DriverDashboard(store: store, session: store.session),
      ),
    );

    expect(find.text('3 active deliveries assigned'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('Shisha ready for collection'), findsOneWidget);
    expect(find.text('+96170000003'), findsOneWidget);
    expect(find.text('DELIVERY DETAILS'), findsOneWidget);
    expect(find.text('Open in Google Maps'), findsOneWidget);
    expect(find.text('Mark as collected'), findsOneWidget);
    expect(driverLocationUpdateInterval, const Duration(seconds: 10));
  });
}
