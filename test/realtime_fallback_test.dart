import 'package:flutter_test/flutter_test.dart';
import 'package:shishago/data/app_store.dart';
import 'package:shishago/models/app_models.dart';
import 'package:shishago/services/session_controller.dart';
import 'package:shishago/services/shishago_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _UnavailableSocketApi extends ShishaGoApi {
  _UnavailableSocketApi() : super(baseUrl: 'http://test.invalid');

  int orderFetches = 0;
  int trackingFetches = 0;
  int notificationFetches = 0;

  Map<String, dynamic> get orderJson => {
    'id': 'order-1',
    'reference': 'SHISHA-001',
    'client_id': 'client-1',
    'client_name': 'Test Client',
    'client_phone': '+96170000001',
    'driver_id': 'driver-1',
    'driver_name': 'Test Driver',
    'driver_phone': '+96170000002',
    'items': <Map<String, dynamic>>[],
    'total': 20,
    'status': 'on_the_way',
    'created_at': '2026-09-12T10:00:00Z',
    'delivery_address': 'Beirut',
    'delivery_latitude': 33.89,
    'delivery_longitude': 35.50,
  };

  @override
  Future<List<Map<String, dynamic>>> getItems({
    String? category,
    bool availableOnly = true,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> getMarketCategories({
    bool activeOnly = false,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> getSavedLocations() async => [
    {
      'id': 'location-1',
      'label': 'Home',
      'address': 'Beirut',
      'latitude': 33.89,
      'longitude': 35.50,
      'is_default': true,
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> getOrders({
    String? status,
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) async => [orderJson];

  @override
  Future<Map<String, dynamic>> getOrder(String orderId) async {
    orderFetches += 1;
    return orderJson;
  }

  @override
  Future<Map<String, dynamic>> getTracking(String orderId) async {
    trackingFetches += 1;
    return {
      'order_id': orderId,
      'status': 'on_the_way',
      'driver_name': 'Test Driver',
      'driver_phone': '+96170000002',
      'latitude': 33.891 + trackingFetches / 1000,
      'longitude': 35.501,
      'heading': 90,
      'speed': 7,
      'updated_at': '2026-09-12T10:00:10Z',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getNotifications() async {
    notificationFetches += 1;
    return [
      {
        'id': 'notification-1',
        'title': 'Order update',
        'body': 'Your order is on the way',
        'is_read': false,
        'created_at': '2026-09-12T10:00:00Z',
      },
    ];
  }

  @override
  WebSocketChannel orderUpdates(String orderId) =>
      throw StateError('WebSocket unavailable');

  @override
  WebSocketChannel notificationUpdates() =>
      throw StateError('WebSocket unavailable');
}

class _DisabledAccountApi extends ShishaGoApi {
  _DisabledAccountApi() : super(baseUrl: 'http://test.invalid');

  @override
  Future<List<Map<String, dynamic>>> getItems({
    String? category,
    bool availableOnly = true,
  }) => throw const ShishaGoApiException('Account is unavailable', 401);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a rejected disabled session is signed out automatically', () async {
    SharedPreferences.setMockInitialValues({});
    final api = _DisabledAccountApi()..accessToken = 'disabled-token';
    final session = SessionController(api)
      ..user = const AppUser(
        id: 'client-disabled',
        name: 'Disabled Client',
        phone: '+96170000009',
        role: UserRole.client,
        address: 'Beirut',
        isActive: true,
        phoneVerified: true,
      );
    final store = ShishaGoStore(api: api, session: session);
    addTearDown(store.dispose);
    addTearDown(api.close);

    await expectLater(store.initialize(), throwsA(isA<ShishaGoApiException>()));
    expect(session.user, isNull);
    expect(api.accessToken, isNull);
  });

  test(
    'polls tracking and notifications while WebSockets are unavailable',
    () async {
      final api = _UnavailableSocketApi();
      final session = SessionController(api)
        ..user = const AppUser(
          id: 'client-1',
          name: 'Test Client',
          phone: '+96170000001',
          role: UserRole.client,
          address: 'Beirut',
          latitude: 33.89,
          longitude: 35.50,
          isActive: true,
          phoneVerified: true,
        );
      final store = ShishaGoStore(
        api: api,
        session: session,
        trackingPollInterval: const Duration(milliseconds: 10),
        notificationPollInterval: const Duration(milliseconds: 10),
        reconnectBaseDelay: const Duration(hours: 1),
        reconnectMaxDelay: const Duration(hours: 1),
      );
      addTearDown(store.dispose);
      addTearDown(api.close);

      await store.initialize();
      await store.watchTracking(AppOrder.fromJson(api.orderJson));
      await Future<void>.delayed(const Duration(milliseconds: 45));

      expect(store.trackingRealtimeConnected, isFalse);
      expect(store.notificationRealtimeConnected, isFalse);
      expect(api.orderFetches, greaterThanOrEqualTo(2));
      expect(api.trackingFetches, greaterThanOrEqualTo(2));
      expect(api.notificationFetches, greaterThanOrEqualTo(2));
      expect(store.tracking?.driverName, 'Test Driver');
      expect(store.notifications.single.title, 'Order update');
    },
  );
}
