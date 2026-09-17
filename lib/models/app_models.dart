import 'dart:math' as math;

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

extension ProductCategoryLabel on ProductCategory {
  String get label => switch (this) {
    ProductCategory.chicha => 'Shisha',
    ProductCategory.market => 'Market',
  };
}

class MarketCategory {
  const MarketCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.isActive,
  });

  factory MarketCategory.fromJson(Map<String, dynamic> json) => MarketCategory(
    id: json['id'] as String,
    name: json['name'] as String,
    slug: json['slug'] as String,
    isActive: json['is_active'] as bool? ?? true,
  );

  final String id;
  final String name;
  final String slug;
  final bool isActive;
}

class DeliveryZone {
  const DeliveryZone({
    required this.id,
    required this.name,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusKm,
    required this.isActive,
  });

  factory DeliveryZone.fromJson(Map<String, dynamic> json) => DeliveryZone(
    id: json['id'] as String,
    name: json['name'] as String,
    centerLatitude: (json['center_latitude'] as num).toDouble(),
    centerLongitude: (json['center_longitude'] as num).toDouble(),
    radiusKm: (json['radius_km'] as num).toDouble(),
    isActive: json['is_active'] as bool? ?? true,
  );

  final String id;
  final String name;
  final double centerLatitude;
  final double centerLongitude;
  final double radiusKm;
  final bool isActive;

  bool contains(double latitude, double longitude) {
    const earthRadiusKm = 6371.0088;
    final latitudeDelta = _radians(centerLatitude - latitude);
    final longitudeDelta = _radians(centerLongitude - longitude);
    final haversine =
        math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(_radians(latitude)) *
            math.cos(_radians(centerLatitude)) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    final distance =
        earthRadiusKm * 2 * math.asin(math.min(1, math.sqrt(haversine)));
    return distance <= radiusKm;
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}

class DeliveryAvailability {
  const DeliveryAvailability({
    required this.available,
    this.zone,
    this.distanceKm,
    this.deliveryFee,
  });

  factory DeliveryAvailability.fromJson(Map<String, dynamic> json) =>
      DeliveryAvailability(
        available: json['available'] as bool,
        zone: json['zone'] == null
            ? null
            : DeliveryZone.fromJson(json['zone'] as Map<String, dynamic>),
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
        deliveryFee: (json['delivery_fee'] as num?)?.toDouble(),
      );

  final bool available;
  final DeliveryZone? zone;
  final double? distanceKm;
  final double? deliveryFee;
}

class DeliveryFeeTier {
  const DeliveryFeeTier({required this.maxDistanceKm, required this.fee});

  factory DeliveryFeeTier.fromJson(Map<String, dynamic> json) =>
      DeliveryFeeTier(
        maxDistanceKm: (json['max_distance_km'] as num).toDouble(),
        fee: (json['fee'] as num).toDouble(),
      );

  final double maxDistanceKm;
  final double fee;

  Map<String, dynamic> toJson() => {
    'max_distance_km': maxDistanceKm,
    'fee': fee,
  };
}

class DeliveryPricing {
  const DeliveryPricing({
    required this.storeLatitude,
    required this.storeLongitude,
    required this.tiers,
  });

  factory DeliveryPricing.fromJson(Map<String, dynamic> json) =>
      DeliveryPricing(
        storeLatitude: (json['store_latitude'] as num).toDouble(),
        storeLongitude: (json['store_longitude'] as num).toDouble(),
        tiers: (json['tiers'] as List<dynamic>)
            .map(
              (tier) => DeliveryFeeTier.fromJson(tier as Map<String, dynamic>),
            )
            .toList(),
      );

  final double storeLatitude;
  final double storeLongitude;
  final List<DeliveryFeeTier> tiers;
}

class ProductCustomizationChoice {
  const ProductCustomizationChoice({
    required this.id,
    required this.name,
    required this.priceAdjustment,
    required this.isAvailable,
  });

  factory ProductCustomizationChoice.fromJson(Map<String, dynamic> json) =>
      ProductCustomizationChoice(
        id: json['id'] as String,
        name: json['name'] as String,
        priceAdjustment: (json['price_adjustment'] as num).toDouble(),
        isAvailable: json['is_available'] as bool? ?? true,
      );

  final String id;
  final String name;
  final double priceAdjustment;
  final bool isAvailable;
}

class ProductCustomizationOption {
  const ProductCustomizationOption({
    required this.id,
    required this.name,
    required this.minSelections,
    required this.maxSelections,
    required this.choices,
  });

  factory ProductCustomizationOption.fromJson(Map<String, dynamic> json) =>
      ProductCustomizationOption(
        id: json['id'] as String,
        name: json['name'] as String,
        minSelections: json['min_selections'] as int,
        maxSelections: json['max_selections'] as int,
        choices: (json['choices'] as List<dynamic>)
            .map(
              (value) => ProductCustomizationChoice.fromJson(
                value as Map<String, dynamic>,
              ),
            )
            .toList(),
      );

  final String id;
  final String name;
  final int minSelections;
  final int maxSelections;
  final List<ProductCustomizationChoice> choices;
}

enum OrderStage {
  pending,
  accepted,
  preparing,
  onTheWay,
  completed,
  finishedUsing,
  collected,
  cancelled,
}

extension OrderStageLabel on OrderStage {
  String get label => switch (this) {
    OrderStage.pending => 'Pending',
    OrderStage.accepted => 'Accepted',
    OrderStage.preparing => 'Preparing',
    OrderStage.onTheWay => 'On the way',
    OrderStage.completed => 'Delivered',
    OrderStage.finishedUsing => 'Finished using',
    OrderStage.collected => 'Collected',
    OrderStage.cancelled => 'Cancelled',
  };

  String get apiValue => switch (this) {
    OrderStage.preparing => 'preparing',
    OrderStage.onTheWay => 'on_the_way',
    OrderStage.finishedUsing => 'finished_using',
    _ => name,
  };

  static OrderStage parse(String value) => switch (value) {
    'preparing' || 'picked_up' => OrderStage.preparing,
    'on_the_way' => OrderStage.onTheWay,
    'completed' => OrderStage.completed,
    'finished_using' => OrderStage.finishedUsing,
    'collected' => OrderStage.collected,
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

class SavedLocation {
  const SavedLocation({
    required this.id,
    required this.label,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.isDefault,
  });

  factory SavedLocation.fromJson(Map<String, dynamic> json) => SavedLocation(
    id: json['id'] as String,
    label: json['label'] as String,
    address: json['address'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    isDefault: json['is_default'] as bool? ?? false,
  );

  final String id;
  final String label;
  final String address;
  final double latitude;
  final double longitude;
  final bool isDefault;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    this.marketCategoryId,
    this.marketCategoryName,
    this.imageUrl,
    this.available = true,
    this.customizationOptions = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    category: json['category'] == 'market'
        ? ProductCategory.market
        : ProductCategory.chicha,
    price: (json['price'] as num).toDouble(),
    marketCategoryId: json['market_category_id'] as String?,
    marketCategoryName: json['market_category_name'] as String?,
    imageUrl: json['image_url'] as String?,
    available: json['is_available'] as bool? ?? true,
    customizationOptions:
        (json['customization_options'] as List<dynamic>? ?? const [])
            .map(
              (value) => ProductCustomizationOption.fromJson(
                value as Map<String, dynamic>,
              ),
            )
            .toList(),
  );

  final String id;
  final String name;
  final String description;
  final ProductCategory category;
  final double price;
  final String? marketCategoryId;
  final String? marketCategoryName;
  final String? imageUrl;
  final bool available;
  final List<ProductCustomizationOption> customizationOptions;

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
    this.customizations = const [],
  });

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
    productId: json['product_id'] as String,
    productName: json['product_name'] as String,
    category: json['category'] == 'market'
        ? ProductCategory.market
        : ProductCategory.chicha,
    quantity: json['quantity'] as int,
    unitPrice: (json['unit_price'] as num).toDouble(),
    customizations: (json['customizations'] as List<dynamic>? ?? const [])
        .map(
          (value) =>
              OrderLineCustomization.fromJson(value as Map<String, dynamic>),
        )
        .toList(),
  );

  final String productId;
  final String productName;
  final ProductCategory category;
  final int quantity;
  final double unitPrice;
  final List<OrderLineCustomization> customizations;
}

class OrderLineCustomization {
  const OrderLineCustomization({
    required this.optionId,
    required this.optionName,
    required this.choiceId,
    required this.choiceName,
    required this.priceAdjustment,
  });

  factory OrderLineCustomization.fromJson(Map<String, dynamic> json) =>
      OrderLineCustomization(
        optionId: json['option_id'] as String,
        optionName: json['option_name'] as String,
        choiceId: json['choice_id'] as String,
        choiceName: json['choice_name'] as String,
        priceAdjustment: (json['price_adjustment'] as num).toDouble(),
      );

  final String optionId;
  final String optionName;
  final String choiceId;
  final String choiceName;
  final double priceAdjustment;
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
    this.deliveryLocationId,
    this.notes = '',
    this.rating,
    this.ratingComment,
    this.deliveryFee = 0,
    this.bringChange = false,
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
    deliveryLocationId: json['delivery_location_id'] as String?,
    notes: json['notes'] as String? ?? '',
    rating: json['rating'] as int?,
    ratingComment: json['rating_comment'] as String?,
    deliveryFee: (json['delivery_fee'] as num? ?? 0).toDouble(),
    bringChange: json['bring_change'] as bool? ?? false,
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
  final String? deliveryLocationId;
  final String notes;
  final int? rating;
  final String? ratingComment;
  final double deliveryFee;
  final bool bringChange;
  final List<OrderLine> lines;
  final double total;
  final OrderStage stage;
  final DateTime createdAt;
  final String address;
  final double latitude;
  final double longitude;

  bool get hasShisha =>
      lines.any((line) => line.category == ProductCategory.chicha);

  String get items => lines
      .map((line) {
        final choices = line.customizations
            .map((value) => value.choiceName)
            .join(', ');
        return '${line.productName}${choices.isEmpty ? '' : ' ($choices)'} × ${line.quantity}';
      })
      .join(', ');
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
    this.kind = 'order_update',
    this.data = const {},
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        isRead: json['is_read'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
        kind: json['kind'] as String? ?? 'order_update',
        data: Map<String, dynamic>.from(
          json['data'] as Map? ?? const <String, dynamic>{},
        ),
      );

  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String kind;
  final Map<String, dynamic> data;
}
