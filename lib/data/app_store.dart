import 'dart:async';
import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/app_models.dart';
import '../services/shishago_api.dart';
import '../services/session_controller.dart';

const driverLocationUpdateInterval = Duration(seconds: 10);
const trackingPollingInterval = Duration(seconds: 10);
const notificationPollingInterval = Duration(seconds: 20);
const websocketHeartbeatInterval = Duration(seconds: 20);
const websocketConnectionTimeout = Duration(seconds: 8);
const websocketReconnectBaseDelay = Duration(seconds: 1);
const websocketReconnectMaxDelay = Duration(seconds: 30);

class _CartEntry {
  _CartEntry({
    required this.product,
    required this.selections,
    required this.unitPrice,
  }) : quantity = 1;

  final Product product;
  final Map<String, List<String>> selections;
  final double unitPrice;
  int quantity;
}

class CheckoutLine {
  const CheckoutLine({
    required this.product,
    required this.quantity,
    required this.unitPrice,
    required this.selections,
  });

  final Product product;
  final int quantity;
  final double unitPrice;
  final Map<String, List<String>> selections;

  double get total => unitPrice * quantity;

  String get customizationSummary {
    final names = <String>[];
    for (final option in product.customizationOptions) {
      final selected = selections[option.id] ?? const <String>[];
      names.addAll(
        option.choices
            .where((choice) => selected.contains(choice.id))
            .map((choice) => '${option.name}: ${choice.name}'),
      );
    }
    return names.join(' · ');
  }
}

class ShishaGoStore extends ChangeNotifier {
  ShishaGoStore({
    required this.api,
    required this.session,
    this.trackingPollInterval = trackingPollingInterval,
    this.notificationPollInterval = notificationPollingInterval,
    this.heartbeatInterval = websocketHeartbeatInterval,
    this.connectionTimeout = websocketConnectionTimeout,
    this.reconnectBaseDelay = websocketReconnectBaseDelay,
    this.reconnectMaxDelay = websocketReconnectMaxDelay,
  });

  final ShishaGoApi api;
  final SessionController session;
  final Duration trackingPollInterval;
  final Duration notificationPollInterval;
  final Duration heartbeatInterval;
  final Duration connectionTimeout;
  final Duration reconnectBaseDelay;
  final Duration reconnectMaxDelay;

  List<Product> products = [];
  List<MarketCategory> marketCategories = [];
  List<AppOrder> orders = [];
  List<AppUser> users = [];
  List<SavedLocation> savedLocations = [];
  List<AppNotification> notifications = [];
  Map<String, dynamic> dashboard = {};
  TrackingInfo? tracking;
  bool loading = false;
  String? error;
  final Map<String, _CartEntry> _cart = {};
  Timer? _locationTimer;
  String? _sharingOrderId;
  bool _locationUpdateInProgress = false;
  StreamSubscription<dynamic>? _trackingSubscription;
  StreamSubscription<dynamic>? _notificationSubscription;
  WebSocketChannel? _trackingChannel;
  WebSocketChannel? _notificationChannel;
  Timer? _trackingPollTimer;
  Timer? _notificationPollTimer;
  Timer? _trackingReconnectTimer;
  Timer? _notificationReconnectTimer;
  Timer? _trackingHeartbeatTimer;
  Timer? _notificationHeartbeatTimer;
  Timer? _trackingPongTimer;
  Timer? _notificationPongTimer;
  String? _trackedOrderId;
  bool _trackingPollInProgress = false;
  bool _notificationPollInProgress = false;
  bool _trackingRealtimeConnected = false;
  bool _notificationRealtimeConnected = false;
  int _trackingReconnectAttempts = 0;
  int _notificationReconnectAttempts = 0;
  bool _disposed = false;

  bool get trackingRealtimeConnected => _trackingRealtimeConnected;
  bool get notificationRealtimeConnected => _notificationRealtimeConnected;

  int get cartCount =>
      _cart.values.fold(0, (sum, entry) => sum + entry.quantity);

  double get cartTotal => _cart.values.fold(
    0,
    (sum, entry) => sum + entry.unitPrice * entry.quantity,
  );

  List<CheckoutLine> get cartLines => _cart.values
      .map(
        (entry) => CheckoutLine(
          product: entry.product,
          quantity: entry.quantity,
          unitPrice: entry.unitPrice,
          selections: entry.selections,
        ),
      )
      .toList(growable: false);

  int quantityFor(String productId) => _cart.values
      .where((entry) => entry.product.id == productId)
      .fold(0, (sum, entry) => sum + entry.quantity);

  Future<void> initialize() async {
    await refresh();
    unawaited(_connectNotificationSocket());
  }

  Future<void> refresh() => _run(() async {
    final role = session.user?.role;
    products = (await api.getItems(
      availableOnly: role != UserRole.owner,
    )).map(Product.fromJson).toList();
    marketCategories = (await api.getMarketCategories(
      activeOnly: role != UserRole.owner,
    )).map(MarketCategory.fromJson).toList();
    orders = (await api.getOrders()).map(AppOrder.fromJson).toList();
    notifications = (await api.getNotifications())
        .map(AppNotification.fromJson)
        .toList();
    if (role == UserRole.client) {
      savedLocations = (await api.getSavedLocations())
          .map(SavedLocation.fromJson)
          .toList();
    }
    if (role == UserRole.owner) {
      users = (await api.getUsers()).map(AppUser.fromJson).toList();
      dashboard = await api.getDashboardSummary();
    }
  });

  Future<void> filterOrders({
    String? status,
    String? search,
    DateTime? from,
    DateTime? to,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) => _run(() async {
    orders = (await api.getOrders(
      status: status,
      search: search,
      dateFrom: from,
      dateTo: to,
      sortBy: sortBy,
      sortOrder: sortOrder,
    )).map(AppOrder.fromJson).toList();
  });

  void addToCart(
    Product product, {
    Map<String, Set<String>> selections = const {},
  }) {
    final normalizedSelections = {
      for (final entry in selections.entries)
        entry.key: (entry.value.toList()..sort()),
    };
    final signatureParts = normalizedSelections.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    final key =
        '${product.id}|${signatureParts.map((entry) => '${entry.key}:${entry.value.join(',')}').join('|')}';
    final priceAdjustment = product.customizationOptions.fold<double>(0, (
      sum,
      option,
    ) {
      final selected = normalizedSelections[option.id] ?? const <String>[];
      return sum +
          option.choices
              .where((choice) => selected.contains(choice.id))
              .fold<double>(
                0,
                (value, choice) => value + choice.priceAdjustment,
              );
    });
    final existing = _cart[key];
    if (existing == null) {
      _cart[key] = _CartEntry(
        product: product,
        selections: normalizedSelections,
        unitPrice: product.price + priceAdjustment,
      );
    } else {
      existing.quantity += 1;
    }
    notifyListeners();
  }

  void removeFromCart(Product product) {
    final matchingKey = _cart.keys.lastWhere(
      (key) => _cart[key]!.product.id == product.id,
      orElse: () => '',
    );
    if (matchingKey.isEmpty) return;
    final entry = _cart[matchingKey]!;
    if (entry.quantity <= 1) {
      _cart.remove(matchingKey);
    } else {
      entry.quantity -= 1;
    }
    notifyListeners();
  }

  Future<AppOrder> checkout({
    required SavedLocation location,
    String notes = '',
  }) async {
    if (_cart.isEmpty) {
      throw const ShishaGoApiException('Your cart is empty', 400);
    }
    final response = await api.createOrder(
      items: _cart.values
          .map(
            (entry) => {
              'product_id': entry.product.id,
              'quantity': entry.quantity,
              'selections': entry.selections.entries
                  .map(
                    (selection) => {
                      'option_id': selection.key,
                      'choice_ids': selection.value,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
      address: location.address,
      latitude: location.latitude,
      longitude: location.longitude,
      deliveryLocationId: location.id,
      notes: notes,
    );
    final order = AppOrder.fromJson(response);
    _cart.clear();
    orders.insert(0, order);
    notifyListeners();
    return order;
  }

  Future<SavedLocation> addSavedLocation({
    required String label,
    required String address,
    required double latitude,
    required double longitude,
    bool isDefault = false,
  }) async {
    final location = SavedLocation.fromJson(
      await api.createSavedLocation(
        label: label,
        address: address,
        latitude: latitude,
        longitude: longitude,
        isDefault: isDefault,
      ),
    );
    await refreshSavedLocations();
    return location;
  }

  Future<void> setDefaultLocation(SavedLocation location) async {
    await api.updateSavedLocation(location.id, {'is_default': true});
    await refreshSavedLocations();
  }

  Future<void> deleteSavedLocation(SavedLocation location) async {
    await api.deleteSavedLocation(location.id);
    await refreshSavedLocations();
  }

  Future<void> refreshSavedLocations() async {
    savedLocations = (await api.getSavedLocations())
        .map(SavedLocation.fromJson)
        .toList();
    notifyListeners();
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
    String? marketCategoryId,
    required double price,
    required bool available,
    List<Map<String, dynamic>> customizationOptions = const [],
  }) => _run(() async {
    final payload = {
      'name': name,
      'description': description,
      'category': category.name,
      'market_category_id': category == ProductCategory.market
          ? marketCategoryId
          : null,
      'price': price,
      'is_available': available,
      'customization_options': customizationOptions,
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

  Future<void> setProductAvailability(Product product, bool available) =>
      _run(() async {
        final updated = Product.fromJson(
          await api.updateItem(product.id, {'is_available': available}),
        );
        final index = products.indexWhere((item) => item.id == product.id);
        if (index != -1) products[index] = updated;
      });

  Future<void> deleteProduct(Product product) => _run(() async {
    await api.deleteItem(product.id);
    products.removeWhere((item) => item.id == product.id);
  });

  Future<MarketCategory> createMarketCategory(String name) async {
    late MarketCategory category;
    await _run(() async {
      category = MarketCategory.fromJson(
        await api.createMarketCategory(name.trim()),
      );
      marketCategories.add(category);
      marketCategories.sort((left, right) => left.name.compareTo(right.name));
    });
    return category;
  }

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

  Future<void> deleteDriver(AppUser driver) => _run(() async {
    await api.deleteUser(driver.id);
    users.removeWhere((user) => user.id == driver.id);
  });

  Future<String?> exportOrders({
    String? status,
    String? search,
    DateTime? from,
    DateTime? to,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) async {
    final bytes = await api.exportOrders(
      status: status,
      search: search,
      dateFrom: from,
      dateTo: to,
      sortBy: sortBy,
      sortOrder: sortOrder,
    );
    if (bytes.isEmpty) {
      throw StateError('The backend returned an empty export file.');
    }
    return FileSaver.instance.saveAs(
      name: 'shishago-orders',
      bytes: bytes,
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  Future<void> watchTracking(AppOrder order) async {
    await stopWatchingTracking();
    _trackedOrderId = order.id;
    await _pollTracking(order.id, clearOnFailure: true);
    if (_disposed || _trackedOrderId != order.id) return;
    unawaited(_connectTrackingSocket(order.id));
  }

  Future<void> stopWatchingTracking() async {
    _trackedOrderId = null;
    _trackingRealtimeConnected = false;
    _trackingReconnectAttempts = 0;
    _trackingPollTimer?.cancel();
    _trackingPollTimer = null;
    _trackingReconnectTimer?.cancel();
    _trackingReconnectTimer = null;
    _trackingHeartbeatTimer?.cancel();
    _trackingHeartbeatTimer = null;
    _trackingPongTimer?.cancel();
    _trackingPongTimer = null;
    final subscription = _trackingSubscription;
    final channel = _trackingChannel;
    _trackingSubscription = null;
    _trackingChannel = null;
    await subscription?.cancel();
    await channel?.sink.close();
  }

  Future<void> _connectTrackingSocket(String orderId) async {
    if (_disposed || _trackedOrderId != orderId) return;
    _trackingReconnectTimer?.cancel();
    _trackingReconnectTimer = null;

    final previousSubscription = _trackingSubscription;
    final previousChannel = _trackingChannel;
    _trackingSubscription = null;
    _trackingChannel = null;
    await previousSubscription?.cancel();
    await previousChannel?.sink.close();

    WebSocketChannel? channel;
    try {
      final createdChannel = api.orderUpdates(orderId);
      channel = createdChannel;
      _trackingChannel = createdChannel;
      _trackingSubscription = createdChannel.stream.listen(
        (event) => _handleTrackingEvent(orderId, createdChannel, event),
        onError: (_) => _handleTrackingDisconnect(orderId, createdChannel),
        onDone: () => _handleTrackingDisconnect(orderId, createdChannel),
        cancelOnError: false,
      );
      await createdChannel.ready.timeout(connectionTimeout);
    } catch (_) {
      if (channel != null && identical(_trackingChannel, channel)) {
        _handleTrackingDisconnect(orderId, channel);
      } else if (_trackingChannel == null) {
        _startTrackingPolling(orderId);
        _scheduleTrackingReconnect(orderId);
      }
      return;
    }
    final connectedChannel = channel;

    if (_disposed ||
        _trackedOrderId != orderId ||
        !identical(_trackingChannel, connectedChannel)) {
      await connectedChannel.sink.close();
      return;
    }
    _trackingRealtimeConnected = true;
    _trackingReconnectAttempts = 0;
    _trackingPollTimer?.cancel();
    _trackingPollTimer = null;
    _trackingHeartbeatTimer?.cancel();
    _trackingHeartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      try {
        connectedChannel.sink.add('ping');
        _trackingPongTimer?.cancel();
        _trackingPongTimer = Timer(connectionTimeout, () {
          _handleTrackingDisconnect(orderId, connectedChannel);
          unawaited(connectedChannel.sink.close());
        });
      } catch (_) {
        _handleTrackingDisconnect(orderId, connectedChannel);
      }
    });
    _notifyIfActive();
  }

  void _handleTrackingEvent(
    String orderId,
    WebSocketChannel channel,
    dynamic event,
  ) {
    if (_disposed ||
        _trackedOrderId != orderId ||
        !identical(_trackingChannel, channel)) {
      return;
    }
    try {
      final decoded = event is String ? event : event.toString();
      final data = Map<String, dynamic>.from(
        (decoded.isEmpty ? <String, dynamic>{} : _decode(decoded)),
      );
      if (data['type'] == 'pong') {
        _trackingPongTimer?.cancel();
        _trackingPongTimer = null;
        return;
      }
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
        if (_isTerminal(updated.stage)) {
          unawaited(stopWatchingTracking());
        }
      }
      _notifyIfActive();
    } catch (_) {
      unawaited(_pollTracking(orderId));
    }
  }

  void _handleTrackingDisconnect(String orderId, WebSocketChannel channel) {
    if (_disposed ||
        _trackedOrderId != orderId ||
        !identical(_trackingChannel, channel)) {
      return;
    }
    _trackingRealtimeConnected = false;
    _trackingHeartbeatTimer?.cancel();
    _trackingHeartbeatTimer = null;
    _trackingPongTimer?.cancel();
    _trackingPongTimer = null;
    _startTrackingPolling(orderId);
    _scheduleTrackingReconnect(orderId);
    _notifyIfActive();
  }

  void _startTrackingPolling(String orderId) {
    if (_disposed || _trackedOrderId != orderId) return;
    unawaited(_pollTracking(orderId));
    if (_trackingPollTimer?.isActive ?? false) return;
    _trackingPollTimer = Timer.periodic(trackingPollInterval, (_) {
      unawaited(_pollTracking(orderId));
    });
  }

  Future<void> _pollTracking(
    String orderId, {
    bool clearOnFailure = false,
  }) async {
    if (_disposed || _trackedOrderId != orderId || _trackingPollInProgress) {
      return;
    }
    _trackingPollInProgress = true;
    var changed = false;
    try {
      final updated = AppOrder.fromJson(await api.getOrder(orderId));
      if (_disposed || _trackedOrderId != orderId) return;
      _replaceOrder(updated);
      changed = true;
      if (updated.driverId == null) {
        tracking = null;
      } else {
        try {
          tracking = TrackingInfo.fromJson(await api.getTracking(orderId));
        } catch (_) {
          if (clearOnFailure) tracking = null;
        }
      }
      if (_isTerminal(updated.stage)) {
        unawaited(stopWatchingTracking());
      }
    } catch (_) {
      if (clearOnFailure) {
        tracking = null;
        changed = true;
      }
    } finally {
      _trackingPollInProgress = false;
      if (changed) _notifyIfActive();
    }
  }

  void _scheduleTrackingReconnect(String orderId) {
    if (_disposed ||
        _trackedOrderId != orderId ||
        (_trackingReconnectTimer?.isActive ?? false)) {
      return;
    }
    final delay = _reconnectDelay(_trackingReconnectAttempts++);
    _trackingReconnectTimer = Timer(delay, () {
      _trackingReconnectTimer = null;
      unawaited(_connectTrackingSocket(orderId));
    });
  }

  Future<void> startLocationSharing(AppOrder order) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ShishaGoApiException('Enable location services first', 400);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const ShishaGoApiException('Location permission is required', 403);
    }
    _locationTimer?.cancel();
    _sharingOrderId = order.id;
    try {
      await _sendDriverLocation(order);
    } catch (_) {
      _sharingOrderId = null;
      rethrow;
    }
    _locationTimer = Timer.periodic(driverLocationUpdateInterval, (_) {
      unawaited(_sendDriverLocation(order, ignoreErrors: true));
    });
    notifyListeners();
  }

  Future<void> stopLocationSharing() async {
    _locationTimer?.cancel();
    _locationTimer = null;
    _sharingOrderId = null;
    notifyListeners();
  }

  Future<void> _sendDriverLocation(
    AppOrder order, {
    bool ignoreErrors = false,
  }) async {
    if (_locationUpdateInProgress || _sharingOrderId != order.id) return;
    _locationUpdateInProgress = true;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      await api.updateDriverLocation(
        orderId: order.id,
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading,
        speed: position.speed,
      );
    } catch (_) {
      if (!ignoreErrors) rethrow;
    } finally {
      _locationUpdateInProgress = false;
    }
  }

  bool get isSharingLocation => _locationTimer != null;
  String? get sharingOrderId => _sharingOrderId;

  Future<void> _connectNotificationSocket() async {
    if (_disposed) return;
    _notificationReconnectTimer?.cancel();
    _notificationReconnectTimer = null;

    final previousSubscription = _notificationSubscription;
    final previousChannel = _notificationChannel;
    _notificationSubscription = null;
    _notificationChannel = null;
    await previousSubscription?.cancel();
    await previousChannel?.sink.close();

    WebSocketChannel? channel;
    try {
      final createdChannel = api.notificationUpdates();
      channel = createdChannel;
      _notificationChannel = createdChannel;
      _notificationSubscription = createdChannel.stream.listen(
        (event) => _handleNotificationEvent(createdChannel, event),
        onError: (_) => _handleNotificationDisconnect(createdChannel),
        onDone: () => _handleNotificationDisconnect(createdChannel),
        cancelOnError: false,
      );
      await createdChannel.ready.timeout(connectionTimeout);
    } catch (_) {
      if (channel != null && identical(_notificationChannel, channel)) {
        _handleNotificationDisconnect(channel);
      } else if (_notificationChannel == null) {
        _startNotificationPolling();
        _scheduleNotificationReconnect();
      }
      return;
    }
    final connectedChannel = channel;
    if (_disposed || !identical(_notificationChannel, connectedChannel)) {
      await connectedChannel.sink.close();
      return;
    }
    _notificationRealtimeConnected = true;
    _notificationReconnectAttempts = 0;
    _notificationPollTimer?.cancel();
    _notificationPollTimer = null;
    _notificationHeartbeatTimer?.cancel();
    _notificationHeartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      try {
        connectedChannel.sink.add('ping');
        _notificationPongTimer?.cancel();
        _notificationPongTimer = Timer(connectionTimeout, () {
          _handleNotificationDisconnect(connectedChannel);
          unawaited(connectedChannel.sink.close());
        });
      } catch (_) {
        _handleNotificationDisconnect(connectedChannel);
      }
    });
    _notifyIfActive();
  }

  void _handleNotificationEvent(WebSocketChannel channel, dynamic event) {
    if (_disposed || !identical(_notificationChannel, channel)) return;
    try {
      final decoded = Map<String, dynamic>.from(
        _decode(event is String ? event : event.toString()) as Map,
      );
      if (decoded['type'] == 'pong') {
        _notificationPongTimer?.cancel();
        _notificationPongTimer = null;
        return;
      }
      final payload = decoded['notification'];
      if (payload is Map) {
        final notification = AppNotification.fromJson(
          Map<String, dynamic>.from(payload),
        );
        if (notification.kind == 'account_disabled') {
          unawaited(session.logout());
          return;
        }
        notifications.removeWhere((value) => value.id == notification.id);
        notifications.insert(0, notification);
        _notifyIfActive();
        Timer(const Duration(milliseconds: 300), () {
          if (!_disposed) refresh().catchError((_) {});
        });
      }
    } catch (_) {
      unawaited(_pollNotifications());
    }
  }

  void _handleNotificationDisconnect(WebSocketChannel channel) {
    if (_disposed || !identical(_notificationChannel, channel)) return;
    _notificationRealtimeConnected = false;
    _notificationHeartbeatTimer?.cancel();
    _notificationHeartbeatTimer = null;
    _notificationPongTimer?.cancel();
    _notificationPongTimer = null;
    _startNotificationPolling();
    _scheduleNotificationReconnect();
    _notifyIfActive();
  }

  void _startNotificationPolling() {
    if (_disposed) return;
    unawaited(_pollNotifications());
    if (_notificationPollTimer?.isActive ?? false) return;
    _notificationPollTimer = Timer.periodic(notificationPollInterval, (_) {
      unawaited(_pollNotifications());
    });
  }

  Future<void> _pollNotifications() async {
    if (_disposed || _notificationPollInProgress) return;
    _notificationPollInProgress = true;
    try {
      notifications = (await api.getNotifications())
          .map(AppNotification.fromJson)
          .toList();
      _notifyIfActive();
    } catch (error) {
      if (error is ShishaGoApiException && error.statusCode == 401) {
        unawaited(session.logout());
        return;
      }
      // The next timer tick or a recovered WebSocket retries synchronization.
    } finally {
      _notificationPollInProgress = false;
    }
  }

  void _scheduleNotificationReconnect() {
    if (_disposed || (_notificationReconnectTimer?.isActive ?? false)) return;
    final delay = _reconnectDelay(_notificationReconnectAttempts++);
    _notificationReconnectTimer = Timer(delay, () {
      _notificationReconnectTimer = null;
      unawaited(_connectNotificationSocket());
    });
  }

  Duration _reconnectDelay(int attempt) {
    final cappedAttempt = attempt.clamp(0, 10).toInt();
    final multiplier = 1 << cappedAttempt;
    final milliseconds = reconnectBaseDelay.inMilliseconds * multiplier;
    return Duration(
      milliseconds: milliseconds
          .clamp(
            reconnectBaseDelay.inMilliseconds,
            reconnectMaxDelay.inMilliseconds,
          )
          .toInt(),
    );
  }

  bool _isTerminal(OrderStage stage) =>
      stage == OrderStage.completed ||
      stage == OrderStage.finishedUsing ||
      stage == OrderStage.collected ||
      stage == OrderStage.cancelled;

  void _notifyIfActive() {
    if (!_disposed) notifyListeners();
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
      if (exception is ShishaGoApiException && exception.statusCode == 401) {
        await session.logout();
      }
      error = exception.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _locationTimer?.cancel();
    _trackingPollTimer?.cancel();
    _notificationPollTimer?.cancel();
    _trackingReconnectTimer?.cancel();
    _notificationReconnectTimer?.cancel();
    _trackingHeartbeatTimer?.cancel();
    _notificationHeartbeatTimer?.cancel();
    _trackingPongTimer?.cancel();
    _notificationPongTimer?.cancel();
    _trackingSubscription?.cancel();
    _notificationSubscription?.cancel();
    _trackingChannel?.sink.close();
    _notificationChannel?.sink.close();
    super.dispose();
  }
}
