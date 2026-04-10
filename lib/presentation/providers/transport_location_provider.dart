import 'package:flutter/material.dart';
import '../../data/datasources/transport_location_remote_datasource.dart';
import '../../data/models/transport_location_model.dart';
import '../../core/error/exceptions.dart';

class TransportLocationProvider extends ChangeNotifier {
  final TransportLocationRemoteDataSource remoteDataSource;

  List<TransportLocationModel> _locations = [];
  bool _isLoading = false;
  String? _error;
  String? _lastLoungeId;

  TransportLocationProvider({required this.remoteDataSource});

  List<TransportLocationModel> get locations => _locations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get all transport locations for a lounge
  Future<void> loadTransportLocations(
    String loungeId, {
    bool showLoading = true,
  }) async {
    _lastLoungeId = loungeId;

    if (showLoading) {
      _isLoading = true;
    }
    _error = null;
    if (showLoading) {
      notifyListeners();
    }

    try {
      final locations = await remoteDataSource.getTransportLocations(loungeId);
      _locations = locations;
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();

      await _refreshLocationPrices(loungeId);
    } on AppException catch (e) {
      _error = e.message;
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
    } catch (e) {
      _error = 'An unexpected error occurred';
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> refreshLastLounge({bool showLoading = false}) async {
    if (_lastLoungeId == null) {
      return;
    }

    await loadTransportLocations(_lastLoungeId!, showLoading: showLoading);
  }

  /// Add a new transport location
  Future<TransportLocationModel?> addTransportLocation({
    required String loungeId,
    required String locationName,
    required double latitude,
    required double longitude,
    required int estDuration,
    required double distance,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newLocation = await remoteDataSource.addTransportLocation(
        loungeId: loungeId,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        estDuration: estDuration,
        distance: distance,
      );

      _locations.add(newLocation);
      _isLoading = false;
      notifyListeners();
      return newLocation;
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

  /// Update a transport location
  Future<bool> updateTransportLocation({
    required String loungeId,
    required String locationId,
    String? locationName,
    double? latitude,
    double? longitude,
    int? estDuration,
    double? distance,
    bool? isActive,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedLocation = await remoteDataSource.updateTransportLocation(
        loungeId: loungeId,
        locationId: locationId,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        estDuration: estDuration,
        distance: distance,
        isActive: isActive,
      );

      final index = _locations.indexWhere((loc) => loc.id == locationId);
      if (index != -1) {
        _locations[index] = updatedLocation;
      }

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

  /// Delete a transport location
  Future<bool> deleteTransportLocation({
    required String loungeId,
    required String locationId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await remoteDataSource.deleteTransportLocation(
        loungeId: loungeId,
        locationId: locationId,
      );

      _locations.removeWhere((loc) => loc.id == locationId);

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

  /// Get prices for a location
  Future<Map<String, double>?> getLocationPrices({
    required String loungeId,
    required String locationId,
  }) async {
    try {
      return await remoteDataSource.getLocationPrices(
        loungeId: loungeId,
        locationId: locationId,
      );
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

  /// Set prices for a location
  Future<bool> setLocationPrices({
    required String loungeId,
    required String locationId,
    required Map<String, double> prices,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await remoteDataSource.setLocationPrices(
        loungeId: loungeId,
        locationId: locationId,
        prices: prices,
      );

      // Update local cache
      final index = _locations.indexWhere((loc) => loc.id == locationId);
      if (index != -1) {
        _locations[index] = TransportLocationModel(
          id: _locations[index].id,
          loungeId: _locations[index].loungeId,
          locationName: _locations[index].locationName,
          latitude: _locations[index].latitude,
          longitude: _locations[index].longitude,
          estDuration: _locations[index].estDuration,
          distance: _locations[index].distance,
          isActive: _locations[index].isActive,
          createdAt: _locations[index].createdAt,
          updatedAt: DateTime.now(),
          prices: prices,
        );
      }

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

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _refreshLocationPrices(String loungeId) async {
    if (_locations.isEmpty) return;

    final updatedLocations = await Future.wait(
      _locations.map((location) async {
        final prices = await _safeGetLocationPrices(
          loungeId: loungeId,
          locationId: location.id,
        );

        if (prices == null || prices.isEmpty) {
          return location;
        }

        return TransportLocationModel(
          id: location.id,
          loungeId: location.loungeId,
          locationName: location.locationName,
          latitude: location.latitude,
          longitude: location.longitude,
          estDuration: location.estDuration,
          distance: location.distance,
          isActive: location.isActive,
          createdAt: location.createdAt,
          updatedAt: location.updatedAt,
          prices: _normalizePrices(prices),
        );
      }),
    );

    _locations = updatedLocations;
    notifyListeners();
  }

  Map<String, double> _normalizePrices(Map<String, double> prices) {
    final normalized = <String, double>{};

    prices.forEach((key, value) {
      if (value <= 0) {
        return;
      }
      final normalizedKey = key.toLowerCase();
      if (normalizedKey.contains('three_wheeler')) {
        normalized['Three Wheeler'] = value;
      } else if (normalizedKey.contains('car')) {
        normalized['Car'] = value;
      } else if (normalizedKey.contains('van')) {
        normalized['Van'] = value;
      } else {
        normalized[key] = value;
      }
    });

    return normalized;
  }

  Future<Map<String, double>?> _safeGetLocationPrices({
    required String loungeId,
    required String locationId,
  }) async {
    try {
      return await remoteDataSource.getLocationPrices(
        loungeId: loungeId,
        locationId: locationId,
      );
    } catch (_) {
      return null;
    }
  }
}
