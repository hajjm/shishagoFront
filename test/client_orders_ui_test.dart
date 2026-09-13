import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shishago/data/app_store.dart';
import 'package:shishago/features/client/client_shell.dart';
import 'package:shishago/models/app_models.dart';
import 'package:shishago/services/session_controller.dart';
import 'package:shishago/services/shishago_api.dart';

AppOrder order(String id, OrderStage stage, {bool hasShisha = false}) =>
    AppOrder(
      id: id,
      reference: 'ORDER-$id',
      clientId: 'client-1',
      clientName: 'Client One',
      clientPhone: '+96170000001',
      driverId: stage == OrderStage.pending ? null : 'driver-1',
      driverName: stage == OrderStage.pending ? null : 'Driver One',
      driverPhone: stage == OrderStage.pending ? null : '+96170000002',
      lines: hasShisha
          ? const [
              OrderLine(
                productId: 'shisha-1',
                productName: 'Mint Shisha',
                category: ProductCategory.chicha,
                quantity: 1,
                unitPrice: 20,
              ),
            ]
          : const [],
      total: 24,
      stage: stage,
      createdAt: DateTime(2026, 9, 10),
      address: 'Beirut',
      latitude: 33.89,
      longitude: 35.50,
    );

void main() {
  testWidgets('client navigation has no standalone Track tab', (tester) async {
    final api = ShishaGoApi(baseUrl: 'http://127.0.0.1:8001');
    final session = SessionController(api)
      ..user = const AppUser(
        id: 'client-1',
        name: 'Client One',
        phone: '+96170000001',
        role: UserRole.client,
        address: 'Beirut',
        latitude: 33.89,
        longitude: 35.50,
        isActive: true,
        phoneVerified: true,
      );
    final store = ShishaGoStore(api: api, session: session);
    addTearDown(store.dispose);
    addTearDown(api.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ClientShell(store: store, session: session),
      ),
    );

    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Track'), findsNothing);
  });

  testWidgets('orders expose pending cancellation and specific tracking', (
    tester,
  ) async {
    final api = ShishaGoApi(baseUrl: 'http://127.0.0.1:8001');
    final store = ShishaGoStore(api: api, session: SessionController(api));
    addTearDown(store.dispose);
    addTearDown(api.close);
    final pending = order('PENDING', OrderStage.pending);
    final accepted = order('ACCEPTED', OrderStage.accepted);
    store.orders = [pending, accepted];
    AppOrder? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrdersPage(store: store, onTrack: (order) => selected = order),
        ),
      ),
    );

    expect(find.text('Cancel order'), findsOneWidget);
    expect(find.text('Track order'), findsOneWidget);

    await tester.tap(find.text('ORDER-ACCEPTED'));
    await tester.pump();
    expect(selected?.id, 'ACCEPTED');

    await tester.tap(find.text('Cancel order'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this order?'), findsOneWidget);
    await tester.tap(find.text('Keep order'));
    await tester.pumpAndSettle();
  });

  testWidgets('delivered shisha can be marked finished using', (tester) async {
    final api = ShishaGoApi(baseUrl: 'http://127.0.0.1:8001');
    final store = ShishaGoStore(api: api, session: SessionController(api));
    addTearDown(store.dispose);
    addTearDown(api.close);
    store.orders = [order('DELIVERED', OrderStage.completed, hasShisha: true)];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrdersPage(store: store, onTrack: (_) {}),
        ),
      ),
    );

    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('I finished using the shisha'), findsOneWidget);
  });
}
