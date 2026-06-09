import '../../domain/entities/lounge_booking.dart';

/// Data Model: Lounge Booking
/// Handles JSON serialization/deserialization for API communication
class LoungeBookingModel extends LoungeBooking {
  const LoungeBookingModel({
    required super.id,
    required super.loungeId,
    required super.passengerId,
    required super.bookingReference,
    required super.checkInTime,
    super.checkOutTime,
    super.scheduledDeparture,
    required super.durationHours,
    required super.guestCount,
    required super.status,
    required super.amountPaid,
    super.paymentMethod,
    super.specialRequests,
    required super.createdAt,
    required super.updatedAt,
    super.loungeName,
    super.loungeAddress,
    super.passengerName,
    super.passengerPhone,
    super.masterBookingId,
    super.hasTransport = false,
    super.vehicleType,
    super.pickupLocationName,
  });

  /// Create model from JSON (from API response)
  factory LoungeBookingModel.fromJson(Map<String, dynamic> json) {
    final checkInTime = _dateTimeFromJson(json['check_in_time']) ??
        _dateTimeFromJson(json['scheduled_arrival']);
    final checkOutTime = _dateTimeFromJson(json['check_out_time']);
    final scheduledDeparture = _dateTimeFromJson(json['scheduled_departure']) ??
        _dateTimeFromJson(json['scheduled_departure_time']);
    final createdAt = _dateTimeFromJson(json['created_at']);
    final updatedAt = _dateTimeFromJson(json['updated_at']) ?? createdAt;

    final passengerInfo = _mapFromJson(json['passenger']) ??
        _mapFromJson(json['user']) ??
        _mapFromJson(json['customer']);
    final passengerName = _stringFromJson(json['passenger_name']) ??
        _stringFromJson(json['primary_guest_name']) ??
        _stringFromJson(json['customer_name']) ??
        _stringFromJson(passengerInfo?['full_name']) ??
        _stringFromJson(passengerInfo?['name']) ??
        _combineName(
          _stringFromJson(passengerInfo?['first_name']),
          _stringFromJson(passengerInfo?['last_name']),
        );
    final passengerPhone = _stringFromJson(json['passenger_phone']) ??
        _stringFromJson(json['primary_guest_phone']) ??
        _stringFromJson(json['customer_phone']) ??
        _stringFromJson(passengerInfo?['phone']) ??
        _stringFromJson(passengerInfo?['phone_number']);

    return LoungeBookingModel(
      id: _stringFromJson(json['id']) ?? '',
      loungeId: _stringFromJson(json['lounge_id']) ?? '',
      passengerId: _stringFromJson(json['passenger_id']) ?? '',
      bookingReference: _stringFromJson(json['booking_reference']) ?? '',
      checkInTime: checkInTime ?? DateTime.now(),
      checkOutTime: checkOutTime,
      scheduledDeparture: scheduledDeparture,
      durationHours: _intFromJson(json['duration_hours']) ?? 1,
      guestCount: _intFromJson(json['guest_count']) ??
          _intFromJson(json['number_of_guests']) ??
          1,
      status: _stringFromJson(json['status']) ?? 'pending',
      amountPaid: _stringFromJson(json['amount_paid']) ??
          _stringFromJson(json['total_amount']) ??
          '0.00',
      paymentMethod: _stringFromJson(json['payment_method']),
      specialRequests: _stringFromJson(json['special_requests']),
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
      loungeName: _stringFromJson(json['lounge_name']),
      loungeAddress: _stringFromJson(json['lounge_address']),
      passengerName: passengerName,
      passengerPhone: passengerPhone,
      masterBookingId: _stringFromJson(json['master_booking_id']),
      hasTransport: json['has_transport'] == true || json['has_transport'] == 1,
      vehicleType: _stringFromJson(json['vehicle_type']),
      pickupLocationName: _stringFromJson(json['pickup_location_name']),
    );
  }

  static String? _stringFromJson(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    if (value is Map<String, dynamic>) {
      final valid = value['Valid'];
      if (valid is bool && valid == false) return null;
      if (value.containsKey('String')) return value['String']?.toString();
      if (value.containsKey('Int64')) return value['Int64']?.toString();
      if (value.containsKey('Float64')) return value['Float64']?.toString();
    }
    return null;
  }

  static Map<String, dynamic>? _mapFromJson(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  static String? _combineName(String? firstName, String? lastName) {
    final parts = [firstName, lastName]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  static int? _intFromJson(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    if (value is Map<String, dynamic>) {
      final valid = value['Valid'];
      if (valid is bool && valid == false) return null;
      if (value.containsKey('Int64')) {
        final raw = value['Int64'];
        if (raw is int) return raw;
        if (raw is num) return raw.toInt();
        if (raw is String) return int.tryParse(raw);
      }
    }
    return null;
  }

  static DateTime? _dateTimeFromJson(dynamic value) {
    final raw = _stringFromJson(value);
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Convert model to JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lounge_id': loungeId,
      'passenger_id': passengerId,
      'booking_reference': bookingReference,
      'check_in_time': checkInTime.toIso8601String(),
      if (checkOutTime != null)
        'check_out_time': checkOutTime!.toIso8601String(),
      if (scheduledDeparture != null)
        'scheduled_departure': scheduledDeparture!.toIso8601String(),
      'duration_hours': durationHours,
      'guest_count': guestCount,
      'status': status,
      'amount_paid': amountPaid,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (specialRequests != null) 'special_requests': specialRequests,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (loungeName != null) 'lounge_name': loungeName,
      if (loungeAddress != null) 'lounge_address': loungeAddress,
      if (passengerName != null) 'passenger_name': passengerName,
      if (passengerPhone != null) 'passenger_phone': passengerPhone,
      if (masterBookingId != null) 'master_booking_id': masterBookingId,
      'has_transport': hasTransport,
      if (vehicleType != null) 'vehicle_type': vehicleType,
      if (pickupLocationName != null) 'pickup_location_name': pickupLocationName,
    };
  }

  /// Convert from domain entity
  factory LoungeBookingModel.fromEntity(LoungeBooking entity) {
    return LoungeBookingModel(
      id: entity.id,
      loungeId: entity.loungeId,
      passengerId: entity.passengerId,
      bookingReference: entity.bookingReference,
      checkInTime: entity.checkInTime,
      checkOutTime: entity.checkOutTime,
      scheduledDeparture: entity.scheduledDeparture,
      durationHours: entity.durationHours,
      guestCount: entity.guestCount,
      status: entity.status,
      amountPaid: entity.amountPaid,
      paymentMethod: entity.paymentMethod,
      specialRequests: entity.specialRequests,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      loungeName: entity.loungeName,
      loungeAddress: entity.loungeAddress,
      passengerName: entity.passengerName,
      passengerPhone: entity.passengerPhone,
      masterBookingId: entity.masterBookingId,
      hasTransport: entity.hasTransport,
      vehicleType: entity.vehicleType,
      pickupLocationName: entity.pickupLocationName,
    );
  }
}
