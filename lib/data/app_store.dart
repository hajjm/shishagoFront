import 'dart:async';
import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/app_models.dart';
import '../services/chichago_api.dart';
import '../services/session_controller.dart';

class ChichagoStore extends ChangeNotifier {
  ChichagoStore({required this.api, required this.session});

  final ChichagoApi api;
  final SessionController session;

  List<Product> products = [];
  List<AppOrder> orders = [];
  List<AppUser> users = [];
  List<AppNotification> notifications = [];
  Map<String, dynamic> dashboard = {};
  TrackingInfo? tracking;
  bool loading = false;
  String? error;
  final Map<String, int> _cart = {};
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<dynamic>? _trackingSubscription;
  StreamSubscription<dynamic>? _notificationSubscription;
  WebSocketChannel? _trackingChannel;
  WebSocketChannel? _notificationChannel;

  int get cartCount => _cart.values.fold(0, (sum, quantity) => sum + quantity);

  double get cartTotal => _cart.entries.fold(0, (sum, entry) {
    final product = products.firstWhere((item) => item.id == entry.key);
    return sum + product.price * entry.value;
  });

  int quantityFor(String productId) => _cart[productId] ?? 0;

  Future<void> initialize() async {
    await refresh();
    _listenForNotifications();
  }

  Future<void> refresh() => _run(() async {
    final role = session.user?.role;
    products = (await api.getItems(
      availableOnly: role != UserRole.owner,
    )).map(Product.fromJson).toList();
    orders = (await api.getOrders()).map(AppOrder.fromJson).toList();
    notifications = (await api.getNotifications())
        .map(AppNotification.fromJson)
        .toList();
    if (role == UserRole.owner) {
      users = (await api.getUsers()).map(AppUser.fromJson).toList();
      dashboard = await api.getDashboardSummary();
    }
  });

  Future<void> filterOrders({
    String? status,
    DateTime? from,
    DateTime? to,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) => _run(() async {
    orders = (await api.getOrders(
      status: status,
      dateFrom: from,
      dateTo: to,
      sortBy: sortBy,
      sortOrder: sortOrder,
    )).map(AppOrder.fromJson).toList();
  });

  void addToCart(Product product) {
    _cart.update(product.id, (value) => value + 1, ifAbsent: () => 1);
    notifyListeners();
  }

  void removeFromCart(Product product) {
    final quantity = _cart[product.id] ?? 0;
    if (quantity <= 1) {
      _cart.remove(product.id);
    } else {
      _cart[product.id] = quantity - 1;
    }
    notifyListeners();
  }

  Future<AppOrder> checkout({String notes = ''}) async {
    final user = session.user;
    if (user == null || user.latitude == null || user.longitude == null) {
      throw const ChichagoApiException(
        'Add a delivery location to your profile first',
        400,
      );
    }
    final response = await api.createOrder(
      items: _cart.entries
          .map((entry) => {'product_id': entry.key, 'quantity': entry.value})
          .toList(),
      address: user.address,
      latitude: user.latitude!,
      longitude: user.longitude!,
      notes: notes,
    );
    final order = AppOrder.fromJson(response);
    _cart.clear();
    orders.insert(0, order);
    notifyListeners();
    return order;
  }

  Future<void> reorder(AppOrder order) => _run(() async {
    final created = AppOrder.fromJson(await api.reorder(order.id));
    orders.insert(0, created);
  });

  Future<void> changeOrderStatus(AppOrder order, OrderStage stage) =>
      _run(() async {
        final updated = AppOrder.fromJson(
          await api.updateOrderStatus(order.id, stage.apiValue),
        );
        _replaceOrder(updated);
      });

  Future<void> assignDriver(AppOrder order, AppUser driver) => _run(() async {
    final updated = AppOrder.fromJson(
      await api.assignDriver(order.id, driver.id),
    );
    _replaceOrder(updated);
  });

  Future<void> saveProduct({
    Product? existing,
    required String name,
    required String description,
    required ProductCategory category,
    required double price,
    required bool available,
  }) => _run(() async {
    final payload = {
      'name': name,
      'description': description,
      'category': category.name,
      'price': price,
      'is_available': available,
    };
    if (existing == null) {
      products.add(Product.fromJson(await api.createItem(payload)));
    } else {
      final updated = Product.fromJson(
        await api.updateItem(existing.id, payload),
      );
      final index = products.indexWhere((item) => item.id == existing.id);
      products[index] = updated;
    }
  });

  Future<void> createDriver({required String name, required String phone}) =>
      _run(() async {
        users.insert(
          0,
          AppUser.fromJson(
            await api.createUser({
              'name': name,
              'phone': phone,
              'role': 'driver',
              'address': '',
            }),
          ),
        );
      });

  Future<void> setUserActive(AppUser user, bool active) => _run(() async {
    final updated = AppUser.fromJson(
      await api.updateUser(user.id, {'is_active': active}),
    );
    final index = users.indexWhere((value) => value.id == user.id);
    users[index] = updated;
  });

  Future<void> exportOrders({
    String? status,
    DateTime? from,
    DateTime? to,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) async {
    final bytes = await api.exportOrders(
      status: status,
      dateFrom: from,
      dateTo: to,
      sortBy: sortBy,
      sortOrder: sortOrder,
    );
    await FileSaver.instance.saveFile(
      name: 'chichago-orders',
      bytes: bytes,
      fileExtension: 'csv',
      mimeType: MimeType.csv,
    );
  }

  Future<void> watchTracking(AppOrder order) async {
    await _trackingSubscription?.cancel();
    await _trackingChannel?.sink.close();
    try {
      tracking = TrackingInfo.fromJson(await api.getTracking(order.id));
    } catch (_) {
      tracking = null;
    }
    _trackingChannel = api.orderUpdates(order.id);
    _trackingSubscription = _trackingChannel!.stream.listen((event) {
      final decoded = event is String ? event : event.toString();
      final data = Map<String, dynamic>.from(
        (decoded.isEmpty ? <String, dynamic>{} : _decode(decoded)),
      );
      if (data['type'] == 'location') {
        tracking = TrackingInfo.fromJson(
          Map<String, dynamic>.from(data['tracking'] as Map),
        );
      } else if (data['type'] == 'status' ||
          data['type'] == 'driver_assigned') {
        final updated = AppOrder.fromJson(
          Map<String, dynamic>.from(data['order'] as Map),
        );
        _replaceOrder(updated);
      }
      notifyListeners();
    }, onError: (_) {});
    notifyListeners();
  }

  Future<void> startLocationSharing(AppOrder order) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ChichagoApiException('Enable location services first', 400);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const ChichagoApiException('Location permission is required', 403);
    }
    await _locationSubscription?.cancel();
    _locationSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((position) async {
          try {
            await api.updateDriverLocation(
              orderId: order.id,
              latitude: position.latitude,
              longitude: position.longitude,
              heading: position.heading,
              speed: position.speed,
            );
          } catch (_) {
            // A later location update retries automatically.
          }
        });
    notifyListeners();
  }

  Future<void> stopLocationSharing() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    notifyListeners();
  }

  bool get isSharingLocation => _locationSubscription != null;

  void _listenForNotifications() {
    _notificationChannel = api.notificationUpdates();
    _notificationSubscription = _notificationChannel!.stream.listen((event) {
      try {
        final decoded = Map<String, dynamic>.from(
          _decode(event is String ? event : event.toString()) as Map,
        );
        final payload = decoded['notification'];
        if (payload is Map) {
          final notification = AppNotification.fromJson(
            Map<String, dynamic>.from(payload),
          );
          notifications.removeWhere((value) => value.id == notification.id);
          notifications.insert(0, notification);
          notifyListeners();
          Timer(const Duration(milliseconds: 300), () {
            refresh().catchError((_) {});
          });
        }
      } catch (_) {
        // A manual refresh retrieves any event with an invalid payload.
      }
    }, onError: (_) {});
  }

  Future<void> loadNotifications() async {
    notifications = (await api.getNotifications())
        .map(AppNotification.fromJson)
        .toList();
    notifyListeners();
  }

  Future<void> markNotificationRead(AppNotification notification) async {
    await api.markNotificationRead(notification.id);
    await loadNotifications();
  }

  void _replaceOrder(AppOrder updated) {
    final index = orders.indexWhere((order) => order.id == updated.id);
    if (index == -1) {
      orders.insert(0, updated);
    } else {
      orders[index] = updated;
    }
  }

  dynamic _decode(String value) {
    // Kept here to isolate websocket payload handling from the UI.
    return const JsonDecoder().convert(value);
  }

  Future<void> _run(Future<void> Function() operation) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await operation();
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _trackingSubscription?.cancel();
    _notificationSubscription?.cancel();
    _trackingChannel?.sink.close();
    _notificationChannel?.sink.close();
    super.dispose();
  }
}
