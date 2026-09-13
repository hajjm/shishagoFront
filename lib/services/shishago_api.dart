import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class ShishaGoApi {
  ShishaGoApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? 'http://127.0.0.1:8001';

  final http.Client _client;
  final String baseUrl;
  String? accessToken;

  Future<Map<String, dynamic>> requestVerificationCode({
    required String phone,
    required String flow,
  }) => _mapRequest(
    'POST',
    '/auth/request-code',
    body: {'phone': phone, 'flow': flow},
  );

  Future<Map<String, dynamic>> verifyCode({
    required String phone,
    required String code,
    required String flow,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final result = await _mapRequest(
      'POST',
      '/auth/verify',
      body: {
        'phone': phone,
        'code': code,
        'flow': flow,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    accessToken = result['access_token'] as String;
    return result;
  }

  Future<Map<String, dynamic>> getMe() =>
      _mapRequest('GET', '/users/me', authenticated: true);

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> changes) =>
      _mapRequest('PATCH', '/users/me', body: changes, authenticated: true);

  Future<List<Map<String, dynamic>>> getItems({
    String? category,
    bool availableOnly = true,
  }) => _listRequest(
    'GET',
    '/items?available_only=$availableOnly${category == null ? '' : '&category=$category'}',
  );

  Future<Map<String, dynamic>> createItem(Map<String, dynamic> payload) =>
      _mapRequest('POST', '/items', body: payload, authenticated: true);

  Future<Map<String, dynamic>> updateItem(
    String productId,
    Map<String, dynamic> payload,
  ) => _mapRequest(
    'PATCH',
    '/items/$productId',
    body: payload,
    authenticated: true,
  );

  Future<void> deleteItem(String productId) async {
    final response = await _send(
      'DELETE',
      '/items/$productId',
      authenticated: true,
    );
    _ensureSuccess(response);
  }

  Future<List<Map<String, dynamic>>> getMarketCategories({
    bool activeOnly = true,
  }) => _listRequest('GET', '/market-categories?active_only=$activeOnly');

  Future<Map<String, dynamic>> createMarketCategory(String name) => _mapRequest(
    'POST',
    '/market-categories',
    body: {'name': name},
    authenticated: true,
  );

  Future<List<Map<String, dynamic>>> getOrders({
    String? status,
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) {
    final query = <String, String>{
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'status': ?status,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (dateFrom != null) 'date_from': _date(dateFrom),
      if (dateTo != null) 'date_to': _date(dateTo),
    };
    return _listRequest(
      'GET',
      '/orders?${Uri(queryParameters: query).query}',
      authenticated: true,
    );
  }

  Future<Map<String, dynamic>> getOrder(String orderId) =>
      _mapRequest('GET', '/orders/$orderId', authenticated: true);

  Future<Map<String, dynamic>> createOrder({
    required List<Map<String, dynamic>> items,
    required String address,
    required double latitude,
    required double longitude,
    String? deliveryLocationId,
    String notes = '',
  }) => _mapRequest(
    'POST',
    '/orders',
    authenticated: true,
    body: {
      'items': items,
      'delivery_address': address,
      'delivery_latitude': latitude,
      'delivery_longitude': longitude,
      'delivery_location_id': deliveryLocationId,
      'notes': notes,
    },
  );

  Future<List<Map<String, dynamic>>> getSavedLocations() =>
      _listRequest('GET', '/locations', authenticated: true);

  Future<Map<String, dynamic>> createSavedLocation({
    required String label,
    required String address,
    required double latitude,
    required double longitude,
    bool isDefault = false,
  }) => _mapRequest(
    'POST',
    '/locations',
    authenticated: true,
    body: {
      'label': label,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault,
    },
  );

  Future<Map<String, dynamic>> updateSavedLocation(
    String locationId,
    Map<String, dynamic> changes,
  ) => _mapRequest(
    'PATCH',
    '/locations/$locationId',
    authenticated: true,
    body: changes,
  );

  Future<void> deleteSavedLocation(String locationId) async {
    final response = await _send(
      'DELETE',
      '/locations/$locationId',
      authenticated: true,
    );
    _ensureSuccess(response);
  }

  Future<Map<String, dynamic>> reorder(String orderId) =>
      _mapRequest('POST', '/orders/$orderId/reorder', authenticated: true);

  Future<Map<String, dynamic>> updateOrderStatus(
    String orderId,
    String status,
  ) => _mapRequest(
    'PATCH',
    '/orders/$orderId/status',
    authenticated: true,
    body: {'status': status},
  );

  Future<Map<String, dynamic>> assignDriver(String orderId, String driverId) =>
      _mapRequest(
        'PATCH',
        '/orders/$orderId/driver',
        authenticated: true,
        body: {'driver_id': driverId},
      );

  Future<Map<String, dynamic>> getTracking(String orderId) =>
      _mapRequest('GET', '/orders/$orderId/tracking', authenticated: true);

  Future<Map<String, dynamic>> updateDriverLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
  }) => _mapRequest(
    'PUT',
    '/drivers/location',
    authenticated: true,
    body: {
      'order_id': orderId,
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
    },
  );

  Future<List<Map<String, dynamic>>> getUsers({
    String? role,
    bool? active,
  }) => _listRequest(
    'GET',
    '/users?${Uri(queryParameters: {'role': ?role, if (active != null) 'active': '$active'}).query}',
    authenticated: true,
  );

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> payload) =>
      _mapRequest('POST', '/users', body: payload, authenticated: true);

  Future<Map<String, dynamic>> updateUser(
    String userId,
    Map<String, dynamic> changes,
  ) => _mapRequest(
    'PATCH',
    '/users/$userId',
    body: changes,
    authenticated: true,
  );

  Future<Map<String, dynamic>> getDashboardSummary() =>
      _mapRequest('GET', '/dashboard/summary', authenticated: true);

  Future<List<Map<String, dynamic>>> getNotifications() =>
      _listRequest('GET', '/notifications', authenticated: true);

  Future<void> markNotificationRead(String notificationId) async {
    await _mapRequest(
      'PATCH',
      '/notifications/$notificationId/read',
      authenticated: true,
    );
  }

  Future<void> registerDevice(String token, String platform) async {
    await _mapRequest(
      'POST',
      '/devices',
      authenticated: true,
      body: {'token': token, 'platform': platform},
    );
  }

  Future<Uint8List> exportOrders({
    String? status,
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) async {
    final query = Uri(
      queryParameters: {
        'status': ?status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (dateFrom != null) 'date_from': _date(dateFrom),
        if (dateTo != null) 'date_to': _date(dateTo),
        'sort_by': sortBy,
        'sort_order': sortOrder,
      },
    ).query;
    final response = await _send(
      'GET',
      '/orders/export.xlsx${query.isEmpty ? '' : '?$query'}',
      authenticated: true,
    );
    _ensureSuccess(response);
    return response.bodyBytes;
  }

  WebSocketChannel orderUpdates(String orderId) =>
      WebSocketChannel.connect(_webSocketUri('/ws/orders/$orderId'));

  WebSocketChannel notificationUpdates() =>
      WebSocketChannel.connect(_webSocketUri('/ws/notifications'));

  Uri _webSocketUri(String path) {
    final token = accessToken;
    if (token == null) {
      throw const ShishaGoApiException('Not authenticated', 401);
    }
    final httpUri = Uri.parse('$baseUrl$path');
    return httpUri.replace(
      scheme: httpUri.scheme == 'https' ? 'wss' : 'ws',
      queryParameters: {'token': token},
    );
  }

  Future<Map<String, dynamic>> _mapRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    final response = await _send(
      method,
      path,
      body: body,
      authenticated: authenticated,
    );
    _ensureSuccess(response);
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> _listRequest(
    String method,
    String path, {
    bool authenticated = false,
  }) async {
    final response = await _send(method, path, authenticated: authenticated);
    _ensureSuccess(response);
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated) {
      final token = accessToken;
      if (token == null) {
        throw const ShishaGoApiException('Not authenticated', 401);
      }
      headers['Authorization'] = 'Bearer $token';
    }
    final uri = Uri.parse('$baseUrl$path');
    final encodedBody = body == null ? null : jsonEncode(body);
    return switch (method) {
      'POST' => _client.post(uri, headers: headers, body: encodedBody),
      'PATCH' => _client.patch(uri, headers: headers, body: encodedBody),
      'PUT' => _client.put(uri, headers: headers, body: encodedBody),
      'DELETE' => _client.delete(uri, headers: headers),
      _ => _client.get(uri, headers: headers),
    };
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String message = 'Request failed';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        message = decoded['detail']?.toString() ?? message;
      }
    } catch (_) {
      // The server returned a non-JSON error.
    }
    throw ShishaGoApiException(message, response.statusCode);
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  void close() => _client.close();
}

class ShishaGoApiException implements Exception {
  const ShishaGoApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
