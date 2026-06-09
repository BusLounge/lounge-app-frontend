/// Domain Entity: Lounge Booking
/// Represents a passenger booking at a lounge
class LoungeBooking {
  final String id;
  final String loungeId;
  final String passengerId;
  final String bookingReference;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final DateTime? scheduledDeparture;
  final int durationHours;
  final int guestCount;
  final String status; // pending, active, completed, cancelled
  final String amountPaid;
  final String? paymentMethod;
  final String? specialRequests;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Optional lounge information (when included in response)
  final String? loungeName;
  final String? loungeAddress;

  // Optional passenger information (when included in response)
  final String? passengerName;
  final String? passengerPhone;

  // Transport fields
  final String? masterBookingId;
  final bool hasTransport;
  final String? vehicleType;
  final String? pickupLocationName;

  const LoungeBooking({
    required this.id,
    required this.loungeId,
    required this.passengerId,
    required this.bookingReference,
    required this.checkInTime,
    this.checkOutTime,
    this.scheduledDeparture,
    required this.durationHours,
    required this.guestCount,
    required this.status,
    required this.amountPaid,
    this.paymentMethod,
    this.specialRequests,
    required this.createdAt,
    required this.updatedAt,
    this.loungeName,
    this.loungeAddress,
    this.passengerName,
    this.passengerPhone,
    this.masterBookingId,
    this.hasTransport = false,
    this.vehicleType,
    this.pickupLocationName,
  });

  // Helper getters
  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  bool get isCheckedIn => checkOutTime == null && !isPending && !isCancelled;
  bool get isCheckedOut => checkOutTime != null;
}
