import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shishago/data/app_store.dart';
import 'package:shishago/features/client/client_shell.dart';
import 'package:shishago/features/driver/driver_dashboard.dart';
import 'package:shishago/features/owner/owner_dashboard.dart';
import 'package:shishago/models/app_models.dart';
import 'package:shishago/services/session_controller.dart';
import 'package:shishago/services/shishago_api.dart';

const client = AppUser(
  id: 'client-mobile',
  name: 'Mobile Client',
  phone: '+96170000101',
  role: UserRole.client,
  address: 'Beirut',
  latitude: 33.89,
  longitude: 35.50,
  isActive: true,
  phoneVerified: true,
);

const owner = AppUser(
  id: 'owner-mobile',
  name: 'Mobile Owner',
  phone: '+96170000102',
  role: UserRole.owner,
  address: 'Beirut',
  isActive: true,
  phoneVerified: true,
);

const driver = AppUser(
  id: 'driver-mobile',
  name: 'Mobile Driver',
  phone: '+96170000103',
  role: UserRole.driver,
  address: 'Beirut',
  isActive: true,
  phoneVerified: true,
);

void configurePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
}

void main() {
  tearDown(() {});

  testWidgets('phone catalog quantity controls do not overflow after adding', (
    tester,
  ) async {
    configurePhone(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ShishaGoApi(baseUrl: 'http://127.0.0.1:8001');
    final session = SessionController(api)..user = client;
    final store = ShishaGoStore(api: api, session: session)
      ..products = const [
        Product(
          id: 'phone-shisha',
          name: 'Mint Shisha',
          description: 'A fresh mint setup delivered to your door',
          category: ProductCategory.chicha,
          price: 5,
        ),
      ];
    addTearDown(store.dispose);
    addTearDown(api.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ShopPage(store: store, user: client),
      ),
    );

    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      1,
    );
    await tester.tap(find.byTooltip('Add to order'));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.byTooltip('Add another'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final role in UserRole.values) {
    testWidgets('$role dashboard renders at iPhone/Android phone width', (
      tester,
    ) async {
      configurePhone(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = ShishaGoApi(baseUrl: 'http://127.0.0.1:8001');
      final session = SessionController(api)
        ..user = switch (role) {
          UserRole.client => client,
          UserRole.owner => owner,
          UserRole.driver => driver,
        };
      final store = ShishaGoStore(api: api, session: session);
      addTearDown(store.dispose);
      addTearDown(api.close);

      final page = switch (role) {
        UserRole.client => ClientShell(store: store, session: session),
        UserRole.owner => OwnerDashboard(store: store, session: session),
        UserRole.driver => DriverDashboard(store: store, session: session),
      };
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Shisha Go logo'), findsOneWidget);
    });
  }
}
