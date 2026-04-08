import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../domain/entities/lounge.dart';
import '../../domain/entities/lounge_route.dart';
import '../../domain/repositories/lounge_repository.dart';
import '../../domain/usecases/add_lounge.dart';
import '../../domain/usecases/get_my_lounges.dart';

/// Provider for registration flow
/// Manages step tracking, form data, and photos (NIC verification removed)
class RegistrationProvider with ChangeNotifier {
  final AddLounge addLoungeUseCase;
  final GetMyLounges getMyLoungesUseCase;
  final LoungeRepository loungeRepository;

  RegistrationProvider({
    required this.addLoungeUseCase,
    required this.getMyLoungesUseCase,
    required this.loungeRepository,
  });

  // State
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // Step 1: Business & Manager Info
  String? _businessName;
  String? _businessLicense;
  String? _businessAddress;
  String? _managerFullName;
  String? _managerNicNumber;
  String? _managerEmail;

  // Step 2: Lounge Photos (NIC verification step removed)
  final List<File> _loungePhotos = [];

  // Step 3: Lounge Data
  String? _loungeName;
  String? _description;
  String? _address;
  String? _state;
  String? _postalCode;
  String? _district;
  double? _latitude;
  double? _longitude;
  String? _contactPhone;
  int? _capacity;
  String? _price1Hour;
  String? _price2Hours;
  String? _price3Hours;
  String? _priceUntilBus;
  List<String> _amenities = [];
  List<LoungeRoute> _routes = []; // Array of routes that lounge serves

  // My Lounges
  List<Lounge> _myLounges = [];
  String? _activeLoungeId;

  // Getters
  int get currentStep => _currentStep;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Step 1 Getters
  String? get businessName => _businessName;
  String? get businessLicense => _businessLicense;
  String? get businessAddress => _businessAddress;
  String? get managerFullName => _managerFullName;
  String? get managerNicNumber => _managerNicNumber;
  String? get managerEmail => _managerEmail;

  // Step 2 Getters (Lounge Photos)
  List<File> get loungePhotos => _loungePhotos;
  int get photoCount => _loungePhotos.length;
  bool get canAddMorePhotos => _loungePhotos.length < 5;
  bool get hasMinimumPhotos => _loungePhotos.isNotEmpty;

  // Step 3 Getters
  String? get loungeName => _loungeName;
  String? get description => _description;
  String? get address => _address;
  String? get state => _state;
  String? get postalCode => _postalCode;
  String? get district => _district;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get contactPhone => _contactPhone;
  int? get capacity => _capacity;
  String? get price1Hour => _price1Hour;
  String? get price2Hours => _price2Hours;
  String? get price3Hours => _price3Hours;
  String? get priceUntilBus => _priceUntilBus;
  List<String> get amenities => _amenities;
  List<LoungeRoute> get routes => _routes;

  List<Lounge> get myLounges => _myLounges;
  String? get activeLoungeId => _activeLoungeId;

  List<Lounge> get verifiedLounges =>
      _myLounges.where((lounge) => lounge.isVerified).toList();

  String? get preferredVerifiedLoungeId {
    final lounges = verifiedLounges;
    if (lounges.isEmpty) {
      return null;
    }

    final hasActiveLounge =
        _activeLoungeId != null && lounges.any((l) => l.id == _activeLoungeId);

    if (hasActiveLounge) {
      return _activeLoungeId;
    }

    return lounges.first.id;
  }

  void setActiveLoungeId(String? loungeId) {
    if (loungeId == _activeLoungeId) {
      return;
    }

    if (loungeId == null) {
      _activeLoungeId = null;
      notifyListeners();
      return;
    }

    final exists = _myLounges.any((lounge) => lounge.id == loungeId);
    if (!exists) {
      return;
    }

    _activeLoungeId = loungeId;
    notifyListeners();
  }

  // Pending lounge submission (stored locally until account is approved)
  bool _hasPendingLounge = false;
  List<String> _pendingLoungePhotoUrls = [];

  bool get hasPendingLounge => _hasPendingLounge;
  List<String> get pendingLoungePhotoUrls => _pendingLoungePhotoUrls;

  /// Check if we have complete lounge data ready for submission
  bool get hasCompleteLoungeDraft {
    return _loungeName != null &&
        _address != null &&
        _contactPhone != null &&
        _capacity != null &&
        _latitude != null &&
        _longitude != null &&
        _routes.isNotEmpty;
  }

  /// Set current step (0-2: Business Info, Lounge Details, Review)
  void setStep(int step) {
    if (step >= 0 && step <= 2) {
      _currentStep = step;
      notifyListeners();
    }
  }

  /// Go to next step
  void nextStep() {
    if (_currentStep < 2) {
      _currentStep++;
      notifyListeners();
    }
  }

  /// Go to previous step
  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  /// Save Step 1 data (Business & Manager Info)
  void saveBusinessInfoData({
    required String businessName,
    required String businessLicense,
    String? businessAddress,
    required String managerFullName,
    required String managerNicNumber,
    required String managerEmail,
  }) {
    _businessName = businessName;
    _businessLicense = businessLicense;
    _businessAddress = businessAddress;
    _managerFullName = managerFullName;
    _managerNicNumber = managerNicNumber;
    _managerEmail = managerEmail;
    notifyListeners();
  }

  // NIC image methods removed - NIC verification now done by admin manually

  /// Add lounge photo
  void addLoungePhoto(File photo) {
    if (_loungePhotos.length < 5) {
      _loungePhotos.add(photo);
      notifyListeners();
    }
  }

  /// Remove lounge photo
  void removeLoungePhoto(int index) {
    if (index >= 0 && index < _loungePhotos.length) {
      _loungePhotos.removeAt(index);
      notifyListeners();
    }
  }

  /// Clear all lounge photos
  void clearLoungePhotos() {
    _loungePhotos.clear();
    notifyListeners();
  }

  /// Save Step 3 data
  void saveLoungeData({
    required String loungeName,
    String? description,
    required String address,
    String? state,
    String? postalCode,
    String? district,
    required double latitude,
    required double longitude,
    required String contactPhone,
    required int capacity,
    required String price1Hour,
    required String price2Hours,
    required String price3Hours,
    required String priceUntilBus,
    required List<String> amenities,
    required List<LoungeRoute> routes,
  }) {
    _loungeName = loungeName;
    _description = description;
    _address = address;
    _state = state;
    _postalCode = postalCode;
    _district = district;
    _latitude = latitude;
    _longitude = longitude;
    _contactPhone = contactPhone;
    _capacity = capacity;
    _price1Hour = price1Hour;
    _price2Hours = price2Hours;
    _price3Hours = price3Hours;
    _priceUntilBus = priceUntilBus;
    _amenities = amenities;
    _routes = routes;
    notifyListeners();
  }

  /// Add a route to the lounge
  void addRoute(LoungeRoute route) {
    _routes.add(route);
    notifyListeners();
  }

  /// Remove a route from the lounge
  void removeRoute(int index) {
    if (index >= 0 && index < _routes.length) {
      _routes.removeAt(index);
      notifyListeners();
    }
  }

  /// Clear all routes
  void clearRoutes() {
    _routes.clear();
    notifyListeners();
  }

  /// Submit lounge (Step 3)
  /// Note: Photo URLs should be uploaded to Supabase first
  Future<bool> submitLounge({required List<String> photoUrls}) async {
    print('📍 Provider - submitLounge called with ${photoUrls.length} photos');

    if (_loungeName == null || _address == null) {
      _errorMessage = 'Lounge name and address are required';
      notifyListeners();
      print('❌ Provider - Missing lounge name or address');
      return false;
    }

    if (_contactPhone == null) {
      _errorMessage = 'Contact phone is required';
      notifyListeners();
      print('❌ Provider - Missing contact phone');
      return false;
    }

    if (_capacity == null || _capacity! <= 0) {
      _errorMessage = 'Valid capacity is required';
      notifyListeners();
      print('❌ Provider - Invalid capacity');
      return false;
    }

    if (_latitude == null || _longitude == null) {
      _errorMessage = 'Location is required';
      notifyListeners();
      print('❌ Provider - Missing location');
      return false;
    }

    if (_routes.isEmpty) {
      _errorMessage = 'At least one route is required';
      notifyListeners();
      print('❌ Provider - No routes added');
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    print('📍 Provider - Calling addLoungeUseCase...');
    final result = await addLoungeUseCase(
      loungeName: _loungeName!,
      address: _address!,
      state: _state,
      postalCode: _postalCode,
      district: _district,
      latitude: _latitude!,
      longitude: _longitude!,
      contactPhone: _contactPhone!,
      capacity: _capacity!,
      price1Hour: _price1Hour ?? '0.00',
      price2Hours: _price2Hours ?? '0.00',
      price3Hours: _price3Hours ?? '0.00',
      priceUntilBus: _priceUntilBus ?? '0.00',
      amenities: _amenities,
      images: photoUrls,
      description: _description,
      routes: _routes,
    );

    return result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        notifyListeners();
        print('❌ Provider - Failure: ${failure.message}');
        return false;
      },
      (loungeId) {
        _isLoading = false;
        notifyListeners();
        print('✅ Provider - Success! Lounge ID: $loungeId');
        return true;
      },
    );
  }

  /// Mark that we have a pending lounge waiting for account approval
  void savePendingLounge(List<String> photoUrls) {
    _hasPendingLounge = true;
    _pendingLoungePhotoUrls = photoUrls;
    print('📍 Provider - Saved pending lounge with ${photoUrls.length} photos');
    notifyListeners();
  }

  /// Clear pending lounge data after successful submission
  void clearPendingLounge() {
    _hasPendingLounge = false;
    _pendingLoungePhotoUrls.clear();
    print('📍 Provider - Cleared pending lounge data');
    notifyListeners();
  }

  /// Submit pending lounge (used after account approval)
  Future<bool> submitPendingLounge() async {
    if (!_hasPendingLounge) {
      print('❌ Provider - No pending lounge to submit');
      return false;
    }

    print('📍 Provider - Submitting pending lounge...');
    final success = await submitLounge(photoUrls: _pendingLoungePhotoUrls);

    if (success) {
      clearPendingLounge();
      // Also clear the form data since it's been submitted
      _loungeName = null;
      _description = null;
      _address = null;
      _state = null;
      _postalCode = null;
      _latitude = null;
      _longitude = null;
      _contactPhone = null;
      _capacity = null;
      _price1Hour = null;
      _price2Hours = null;
      _price3Hours = null;
      _priceUntilBus = null;
      _amenities.clear();
      _routes.clear();
      _loungePhotos.clear();
      notifyListeners();
    }

    return success;
  }

  /// Load my lounges
  Future<void> loadMyLounges() async {
    print('📍 Provider - loadMyLounges called');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await getMyLoungesUseCase();

    result.fold(
      (failure) {
        print('❌ Provider - loadMyLounges failed: ${failure.message}');
        _isLoading = false;
        _errorMessage = failure.message;
        notifyListeners();
      },
      (lounges) {
        print('✅ Provider - loadMyLounges success: ${lounges.length} lounges');
        for (var lounge in lounges) {
          print('   - ${lounge.loungeName} (${lounge.status})');
        }
        _isLoading = false;
        _myLounges = lounges;
        final verified = verifiedLounges;
        if (verified.isEmpty) {
          _activeLoungeId = null;
        } else if (_activeLoungeId == null ||
            !verified.any((lounge) => lounge.id == _activeLoungeId)) {
          _activeLoungeId = verified.first.id;
        }
        notifyListeners();
      },
    );
  }

  Future<Lounge?> getLoungeDetails(String id) async {
    final result = await loungeRepository.getLoungeById(id);

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return null;
      },
      (lounge) {
        print('📍 getLoungeDetails parsed lounge: ${lounge.loungeName}');
        print('   state: ${lounge.state}');
        print('   postalCode: ${lounge.postalCode}');
        print('   district: ${lounge.district}');
        final index = _myLounges.indexWhere((item) => item.id == lounge.id);
        if (index != -1) {
          _myLounges[index] = lounge;
          notifyListeners();
        }
        return lounge;
      },
    );
  }

  Future<bool> updateLoungeDetails(Lounge lounge) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await loungeRepository.updateLounge(lounge);

    return result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (_) async {
        final refreshedLounge = await getLoungeDetails(lounge.id);
        if (refreshedLounge == null) {
          final index = _myLounges.indexWhere((item) => item.id == lounge.id);
          if (index != -1) {
            _myLounges[index] = lounge;
          }
        }
        _isLoading = false;
        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> deleteLoungeById(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await loungeRepository.deleteLounge(id);

    return result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (_) {
        _myLounges.removeWhere((item) => item.id == id);
        _isLoading = false;
        notifyListeners();
        return true;
      },
    );
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Reset all data
  void reset() {
    _currentStep = 0;
    _isLoading = false;
    _errorMessage = null;
    _businessName = null;
    _businessLicense = null;
    _managerFullName = null;
    _managerNicNumber = null;
    _managerEmail = null;
    _loungePhotos.clear();
    _loungeName = null;
    _description = null;
    _address = null;
    _state = null;
    _postalCode = null;
    _latitude = null;
    _longitude = null;
    _contactPhone = null;
    _capacity = null;
    _price1Hour = null;
    _price2Hours = null;
    _price3Hours = null;
    _priceUntilBus = null;
    _amenities.clear();
    _myLounges.clear();
    // Don't clear pending lounge data on reset - it should persist
    notifyListeners();
  }
}
