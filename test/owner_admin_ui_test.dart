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
);

void main() {
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
  });

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

    expect(find.text('2 active deliveries assigned'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('Driver is at the Shisha Go store'), findsOneWidget);
    await tester.tap(find.text('SH-002').first);
    await tester.pumpAndSettle();
    expect(find.text('+96170000002'), findsOneWidget);
    expect(find.text('Preparing'), findsWidgets);
    expect(driverLocationUpdateInterval, const Duration(seconds: 10));
  });
}
