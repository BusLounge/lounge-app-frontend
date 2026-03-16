import 'package:flutter/foundation.dart';
import '../../domain/entities/driver.dart';
import '../../data/datasources/driver_remote_datasource.dart';
import '../../data/models/lounge_booking_driver_assignment_model.dart';
import '../../core/error/exceptions.dart';

/// Provider: Driver Management
/// Manages UI state for driver operations
class DriverProvider extends ChangeNotifier {
  final DriverRemoteDataSource remoteDataSource;

  DriverProvider({required this.remoteDataSource});

  // UI State
  bool _isLoading = false;
  String? _error;
  List<Driver> _driverList = [];
  Driver? _selectedDriver;
  LoungeBookingDriverAssignmentModel? _lastAssignment;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Driver> get driverList => _driverList;
  Driver? get selectedDriver => _selectedDriver;
  LoungeBookingDriverAssignmentModel? get lastAssignment => _lastAssignment;

  /// Add driver to lounge
  Future<bool> addDriver({
    required String loungeId,
    required String fullName,
    required String nicNumber,
    required String contactNumber,
    required String vehicleNumber,
    required String vehicleType,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final driver = await remoteDataSource.addDriver(
        loungeId: loungeId,
        fullName: fullName,
        nicNumber: nicNumber,
        contactNumber: contactNumber,
        vehicleNumber: vehicleNumber,
        vehicleType: vehicleType,
      );

      // Don't add to local list - will be fetched when driver list loads
      _selectedDriver = driver;

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

  /// Get all drivers for a lounge
  Future<bool> getDriversByLounge({
    required String loungeId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final drivers = await remoteDataSource.getDriversByLounge(
        loungeId: loungeId,
      );

      _driverList = drivers;
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

  /// Remove a driver from lounge (Owner only)
  Future<bool> removeDriver({
    required String loungeId,
    required String driverId,
    bool showLoading = true,
  }) async {
    if (showLoading) {
      _isLoading = true;
    }
    _error = null;
    notifyListeners();

    try {
      await remoteDataSource.removeDriver(
        loungeId: loungeId,
        driverId: driverId,
      );
      _driverList.removeWhere((driver) => driver.id == driverId);
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _error = e.message;
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
      return false;
    }
  }

  /// Assign driver to booking
  Future<bool> assignDriverToBooking({
    required String bookingId,
    required String driverId,
    required String loungeId,
    required String guestName,
    required String guestContact,
    required String driverContact,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final assignment = await remoteDataSource.assignDriverToBooking(
        bookingId: bookingId,
        driverId: driverId,
        loungeId: loungeId,
        guestName: guestName,
        guestContact: guestContact,
        driverContact: driverContact,
      );

      _lastAssignment = assignment;
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

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset provider state
  void reset() {
    _isLoading = false;
    _error = null;
    _driverList = [];
    _selectedDriver = null;
    notifyListeners();
  }
}
