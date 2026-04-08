import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'lounge_route.dart';

/// Entity representing a lounge location
class Lounge extends Equatable {
  final String id;
  final String loungeOwnerId;
  final String loungeName;
  final String? description;
  final String address;
  final String? state;
  final String? district;
  final String? country;
  final String? postalCode;
  final String? latitude; // Required for map
  final String? longitude; // Required for map
  final String? contactPhone;
  final int? capacity; // Maximum number of people

  // Routes that this lounge serves
  final List<LoungeRoute>? routes;

  // Pricing (in LKR)
  final String? price1Hour;
  final String? price2Hours;
  final String? price3Hours;
  final String? priceUntilBus;

  // Amenities as array of strings
  final List<String>?
      amenities; // ["wifi", "ac", "cafeteria", "charging_ports", "entertainment", "parking", "restrooms", "waiting_area"]

  // Images as array of URLs
  final List<String>? images;

  final String status; // pending, active, inactive, suspended
  final bool isOperational;
  final String? averageRating;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Lounge({
    required this.id,
    required this.loungeOwnerId,
    required this.loungeName,
    this.description,
    required this.address,
    this.state,
    this.district,
    this.country,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.contactPhone,
    this.capacity,
    this.routes,
    this.price1Hour,
    this.price2Hours,
    this.price3Hours,
    this.priceUntilBus,
    this.amenities,
    this.images,
    required this.status,
    required this.isOperational,
    this.averageRating,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        loungeOwnerId,
        loungeName,
        description,
        address,
        state,
        district,
        country,
        postalCode,
        latitude,
        longitude,
        contactPhone,
        capacity,
        routes,
        price1Hour,
        price2Hours,
        price3Hours,
        priceUntilBus,
        amenities,
        images,
        status,
        isOperational,
        averageRating,
        createdAt,
        updatedAt,
      ];

  /// Check if lounge is active
  bool get isActive => status == 'active';

  /// Check if lounge is pending approval
  bool get isPending => status == 'pending';

  /// Check if lounge is verified/approved
  bool get isVerified =>
      status == 'approved' || status == 'active' || status == 'verified';

  /// Get the primary photo (first photo in the list)
  String? get primaryPhoto => images?.isNotEmpty == true ? images!.first : null;

  Lounge copyWith({
    String? id,
    String? loungeOwnerId,
    String? loungeName,
    String? description,
    String? address,
    String? state,
    String? district,
    String? country,
    String? postalCode,
    String? latitude,
    String? longitude,
    String? contactPhone,
    int? capacity,
    List<LoungeRoute>? routes,
    String? price1Hour,
    String? price2Hours,
    String? price3Hours,
    String? priceUntilBus,
    List<String>? amenities,
    List<String>? images,
    String? status,
    bool? isOperational,
    String? averageRating,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Lounge(
      id: id ?? this.id,
      loungeOwnerId: loungeOwnerId ?? this.loungeOwnerId,
      loungeName: loungeName ?? this.loungeName,
      description: description ?? this.description,
      address: address ?? this.address,
      state: state ?? this.state,
      district: district ?? this.district,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      contactPhone: contactPhone ?? this.contactPhone,
      capacity: capacity ?? this.capacity,
      routes: routes ?? this.routes,
      price1Hour: price1Hour ?? this.price1Hour,
      price2Hours: price2Hours ?? this.price2Hours,
      price3Hours: price3Hours ?? this.price3Hours,
      priceUntilBus: priceUntilBus ?? this.priceUntilBus,
      amenities: amenities ?? this.amenities,
      images: images ?? this.images,
      status: status ?? this.status,
      isOperational: isOperational ?? this.isOperational,
      averageRating: averageRating ?? this.averageRating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Standard amenity codes
class LoungeAmenities {
  static const String wifi = 'wifi';
  static const String ac = 'ac';
  static const String cafeteria = 'cafeteria';
  static const String chargingPorts = 'charging_ports';
  static const String entertainment = 'entertainment';
  static const String parking = 'parking';
  static const String restrooms = 'restrooms';
  static const String waitingArea = 'waiting_area';

  // List of all amenity codes
  static const List<String> allCodes = [
    wifi,
    ac,
    cafeteria,
    chargingPorts,
    entertainment,
    parking,
    restrooms,
    waitingArea,
  ];

  static const Map<String, String> labels = {
    wifi: 'Wi-Fi',
    ac: 'A/C',
    cafeteria: 'Cafeteria',
    chargingPorts: 'Charging Ports',
    entertainment: 'Entertainment',
    parking: 'Parking',
    restrooms: 'Rest Rooms',
    waitingArea: 'Waiting Area',
  };

  static const Map<String, IconData> icons = {
    wifi: Icons.wifi,
    ac: Icons.ac_unit,
    cafeteria: Icons.restaurant,
    chargingPorts: Icons.power,
    entertainment: Icons.tv,
    parking: Icons.local_parking,
    restrooms: Icons.wc,
    waitingArea: Icons.chair,
  };
}
