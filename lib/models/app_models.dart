import 'package:flutter/material.dart';

enum UserRole { client, owner, driver }

extension UserRoleValue on UserRole {
  String get apiValue => name;

  static UserRole parse(String value) => UserRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => UserRole.client,
  );
}

enum ProductCategory { chicha, market }

enum OrderStage { pending, accepted, preparing, onTheWay, completed, cancelled }

extension OrderStageLabel on OrderStage {
  String get label => switch (this) {
    OrderStage.pending => 'Pending',
    OrderStage.accepted => 'Accepted',
    OrderStage.preparing => 'Preparing',
    OrderStage.onTheWay => 'On the way',
    OrderStage.completed => 'Completed',
    OrderStage.cancelled => 'Cancelled',
  };

  String get apiValue => switch (this) {
    OrderStage.preparing => 'preparing',
    OrderStage.onTheWay => 'on_the_way',
    _ => name,
  };

  static OrderStage parse(String value) => switch (value) {
    'preparing' || 'picked_up' => OrderStage.preparing,
    'on_the_way' => OrderStage.onTheWay,
    'completed' => OrderStage.completed,
    'cancelled' => OrderStage.cancelled,
    'accepted' => OrderStage.accepted,
    _ => OrderStage.pending,
  };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.address,
    required this.isActive,
    required this.phoneVerified,
    this.latitude,
    this.longitude,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    role: UserRoleValue.parse(json['role'] as String),
    address: json['address'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    isActive: json['is_active'] as bool? ?? true,
    phoneVerified: json['phone_verified'] as bool? ?? false,
  );

  final String id;
  final String name;
  final String phone;
  final UserRole role;
  final String address;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  final bool phoneVerified;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    this.imageUrl,
    this.available = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    category: json['category'] == 'market'
        ? ProductCategory.market
        : ProductCategory.chicha,
    price: (json['price'] as num).toDouble(),
    imageUrl: json['image_url'] as String?,
    available: json['is_available'] as bool? ?? true,
  );

  final String id;
  final String name;
  final String description;
  final ProductCategory category;
  final double price;
  final String? imageUrl;
  final bool available;

  IconData get icon => category == ProductCategory.chicha
      ? Icons.local_fire_department_rounded
      : Icons.shopping_bag_rounded;
}

class OrderLine {
  const OrderLine({
    required this.productId,
    required this.productName,
    required this.category,
    required this.quantity,
    required this.unitPrice,
  });

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
    productId: json['product_id'] as String,
    productName: json['product_name'] as String,
    category: json['category'] == 'market'
        ? ProductCategory.market
        : ProductCategory.chicha,
    quantity: json['quantity'] as int,
    unitPrice: (json['unit_price'] as num).toDouble(),
  );

  final String productId;
  final String productName;
  final ProductCategory category;
  final int quantity;
  final double unitPrice;
}

class AppOrder {
  const AppOrder({
    required this.id,
    required this.reference,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.lines,
    required this.total,
    required this.stage,
    required this.createdAt,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.driverId,
    this.driverName,
    this.driverPhone,
  });

  factory AppOrder.fromJson(Map<String, dynamic> json) => AppOrder(
    id: json['id'] as String,
    reference: json['reference'] as String,
    clientId: json['client_id'] as String,
    clientName: json['client_name'] as String,
    clientPhone: json['client_phone'] as String,
    driverId: json['driver_id'] as String?,
    driverName: json['driver_name'] as String?,
    driverPhone: json['driver_phone'] as String?,
    lines: (json['items'] as List<dynamic>)
        .map((item) => OrderLine.fromJson(item as Map<String, dynamic>))
        .toList(),
    total: (json['total'] as num).toDouble(),
    stage: OrderStageLabel.parse(json['status'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
    address: json['delivery_address'] as String,
    latitude: (json['delivery_latitude'] as num).toDouble(),
    longitude: (json['delivery_longitude'] as num).toDouble(),
  );

  final String id;
  final String reference;
  final String clientId;
  final String clientName;
  final String clientPhone;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final List<OrderLine> lines;
  final double total;
  final OrderStage stage;
  final DateTime createdAt;
  final String address;
  final double latitude;
  final double longitude;

  String get items =>
      lines.map((line) => '${line.productName} × ${line.quantity}').join(', ');
}

class TrackingInfo {
  const TrackingInfo({
    required this.orderId,
    required this.stage,
    required this.driverName,
    required this.driverPhone,
    this.latitude,
    this.longitude,
    this.heading,
    this.speed,
    this.updatedAt,
  });

  factory TrackingInfo.fromJson(Map<String, dynamic> json) => TrackingInfo(
    orderId: json['order_id'] as String,
    stage: OrderStageLabel.parse(json['status'] as String),
    driverName: json['driver_name'] as String,
    driverPhone: json['driver_phone'] as String,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    heading: (json['heading'] as num?)?.toDouble(),
    speed: (json['speed'] as num?)?.toDouble(),
    updatedAt: json['updated_at'] == null
        ? null
        : DateTime.parse(json['updated_at'] as String),
  );

  final String orderId;
  final OrderStage stage;
  final String driverName;
  final String driverPhone;
  final double? latitude;
  final double? longitude;
  final double? heading;
  final double? speed;
  final DateTime? updatedAt;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        isRead: json['is_read'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
}
