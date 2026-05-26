/// Data Model: Lounge Booking Driver Assignment
/// Handles JSON serialization/deserialization for driver assignment API communication
class LoungeBookingDriverAssignmentModel {
  final String? id;
  final String bookingId;
  final String driverId;
  final String? status; // pending, assigned, accepted, completed, cancelled
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LoungeBookingDriverAssignmentModel({
    this.id,
    required this.bookingId,
    required this.driverId,
    this.status,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  /// Create model from JSON (from API response)
  factory LoungeBookingDriverAssignmentModel.fromJson(
      Map<String, dynamic> json) {
    return LoungeBookingDriverAssignmentModel(
      id: json['id'] as String?,
      bookingId: json['booking_id'] as String? ??
          json['lounge_booking_id'] as String? ??
          '',
      driverId: json['driver_id'] as String? ?? '',
      status: json['status'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert model to JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'driver_id': driverId,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
    };
  }
}
