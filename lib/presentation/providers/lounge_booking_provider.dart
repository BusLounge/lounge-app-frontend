import 'package:flutter/foundation.dart';
import '../../domain/entities/lounge_booking.dart';
import '../../data/datasources/lounge_booking_remote_datasource.dart';
import '../../data/models/lounge_booking_model.dart';
import '../../core/error/exceptions.dart';

/// Provider: Lounge Booking Management
/// Manages UI state for lounge booking operations
class LoungeBookingProvider extends ChangeNotifier {
  final LoungeBookingRemoteDataSource remoteDataSource;

  LoungeBookingProvider({required this.remoteDataSource});

  // UI State
  bool _isLoading = false;
  String? _error;
  List<LoungeBooking> _bookings = [];
  LoungeBooking? _selectedBooking;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<LoungeBooking> get bookings => _bookings;
  LoungeBooking? get selectedBooking => _selectedBooking;

  // Filter getters
  List<LoungeBooking> get activeBookings =>
      _bookings.where((b) => b.isActive).toList();
  List<LoungeBooking> get pendingBookings =>
      _bookings.where((b) => b.isPending).toList();
  List<LoungeBooking> get completedBookings =>
      _bookings.where((b) => b.isCompleted).toList();
  List<LoungeBooking> get todayBookings {
    final now = DateTime.now();
    return _bookings.where((booking) {
      final checkInDate = booking.checkInTime;
      return checkInDate.year == now.year &&
          checkInDate.month == now.month &&
          checkInDate.day == now.day;
    }).toList();
  }

  /// Get owner bookings
  Future<bool> getOwnerBookings({
    String? loungeId,
    String? status,
    String? date,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bookingModels = await remoteDataSource.getOwnerBookings(
        loungeId: loungeId,
        status: status,
        date: date,
      );

      _bookings = bookingModels;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get today's bookings (Staff/Owner view)
  Future<bool> getTodayBookings({
    String? loungeId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bookingModels = await remoteDataSource.getTodayBookings(
        loungeId: loungeId,
      );
      _bookings = bookingModels;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get my bookings (Passenger view)
  Future<bool> getMyBookings({
    String? status,
    int? page,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bookingModels = await remoteDataSource.getMyBookings(
        status: status,
        page: page,
      );

      _bookings = bookingModels;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get upcoming bookings
  Future<bool> getUpcomingBookings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bookingModels = await remoteDataSource.getUpcomingBookings();
      _bookings = bookingModels;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get booking by ID
  Future<bool> getBookingById(String bookingId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final booking = await remoteDataSource.getBookingById(bookingId);
      _selectedBooking = booking;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get booking by reference
  Future<bool> getBookingByReference(String reference) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final booking = await remoteDataSource.getBookingByReference(reference);
      _selectedBooking = booking;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get booking by QR code data
  Future<bool> getBookingByQrCodeData(String qrCodeData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final booking = await remoteDataSource.getBookingByQrCodeData(qrCodeData);
      _selectedBooking = booking;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Toggle check-in/check-out for booking
  Future<String?> toggleBookingCheckInOut({
    required String bookingId,
    double? latitude,
    double? longitude,
    String? locationName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await remoteDataSource.toggleBookingCheckInOut(
        bookingId: bookingId,
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
      );

      final bookingJson = result['booking'];
      if (bookingJson is Map<String, dynamic>) {
        _selectedBooking = LoungeBookingModel.fromJson(bookingJson);
      }

      _isLoading = false;
      notifyListeners();
      return result['message']?.toString();
    } on AppException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Get bookings for staff member (Staff view)
  /// Returns bookings for the lounge assigned to the authenticated staff
  Future<Map<String, dynamic>?> getStaffBookings({
    int? limit,
    int? offset,
    String? status,
    String? date,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await remoteDataSource.getStaffBookings(
        limit: limit,
        offset: offset,
        status: status,
        date: date,
      );

      _bookings = result['bookings'] as List<LoungeBooking>;
      _isLoading = false;
      notifyListeners();

      return {
        'lounge_id': result['lounge_id'],
        'limit': result['limit'],
        'offset': result['offset'],
        'total_bookings': _bookings.length,
      };
    } on AppException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Fetch food orders attached to a booking
  /// Keeps booking list state intact; used by details/order views.
  Future<Map<String, dynamic>?> getBookingOrders({
    required String bookingId,
    String? date,
  }) async {
    _error = null;
    notifyListeners();

    try {
      // Prefer richer payload that includes booking + orders in one response.
      final withOrders = await remoteDataSource.getBookingWithOrders(
        bookingId: bookingId,
        date: date,
      );
      return withOrders;
    } on AppException catch (e) {
      // Fallback for older backend versions that may not expose /with-orders.
      try {
        final ordersOnly = await remoteDataSource.getBookingOrders(
          bookingId: bookingId,
          date: date,
        );
        return ordersOnly;
      } catch (_) {
        _error = e.message;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = 'An unexpected error occurred';
      notifyListeners();
      return null;
    }
  }

  /// Complete a booking and reflect status in current list state.
  Future<String?> completeBooking({required String bookingId}) async {
    _error = null;
    notifyListeners();

    try {
      final result =
          await remoteDataSource.completeBooking(bookingId: bookingId);
      _bookings = _bookings.map((booking) {
        if (booking.id == bookingId) {
          return LoungeBookingModel.fromEntity(booking)
              .copyWithStatus('completed');
        }
        return booking;
      }).toList();
      notifyListeners();
      return result['message']?.toString() ?? 'Booking completed successfully';
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'An unexpected error occurred';
      notifyListeners();
      return null;
    }
  }

  /// Update in-lounge order status for a booking order.
  Future<String?> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    _error = null;
    notifyListeners();

    try {
      final result = await remoteDataSource.updateOrderStatus(
        orderId: orderId,
        status: status,
      );
      notifyListeners();
      return result['message']?.toString() ?? 'Order status updated';
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'An unexpected error occurred';
      notifyListeners();
      return null;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset provider state
  void reset() {
    _isLoading = false;
    _error = null;
    _bookings = [];
    _selectedBooking = null;
    notifyListeners();
  }
}

extension on LoungeBookingModel {
  LoungeBookingModel copyWithStatus(String status) {
    return LoungeBookingModel(
      id: id,
      loungeId: loungeId,
      passengerId: passengerId,
      bookingReference: bookingReference,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      durationHours: durationHours,
      guestCount: guestCount,
      status: status,
      amountPaid: amountPaid,
      paymentMethod: paymentMethod,
      specialRequests: specialRequests,
      createdAt: createdAt,
      updatedAt: updatedAt,
      loungeName: loungeName,
      loungeAddress: loungeAddress,
      passengerName: passengerName,
      passengerPhone: passengerPhone,
    );
  }
}
