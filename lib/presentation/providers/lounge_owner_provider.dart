import 'package:flutter/foundation.dart';
import '../../domain/entities/lounge_owner.dart';
import '../../domain/entities/registration_progress.dart';
import '../../domain/usecases/save_business_info.dart';
import '../../domain/usecases/upload_nic_images.dart';
import '../../domain/usecases/get_registration_progress.dart';
import '../../domain/usecases/check_ocr_block.dart';
import '../../domain/usecases/get_profile.dart';

/// Provider for lounge owner operations
/// Manages state for business info, manager NIC upload, and profile
class LoungeOwnerProvider with ChangeNotifier {
  final SaveBusinessInfo saveBusinessInfoUseCase;
  final UploadNICImages uploadNICImagesUseCase;
  final GetRegistrationProgress getRegistrationProgressUseCase;
  final CheckOCRBlock checkOCRBlockUseCase;
  final GetProfile getProfileUseCase;

  LoungeOwnerProvider({
    required this.saveBusinessInfoUseCase,
    required this.uploadNICImagesUseCase,
    required this.getRegistrationProgressUseCase,
    required this.checkOCRBlockUseCase,
    required this.getProfileUseCase,
  });

  // State
  bool _isLoading = false;
  String? _errorMessage;
  LoungeOwner? _profile;
  RegistrationProgress? _progress;
  DateTime? _ocrBlockedUntil;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get error => _errorMessage; // Alias for compatibility
  LoungeOwner? get profile => _profile;
  LoungeOwner? get loungeOwner => _profile; // Alias for compatibility
  RegistrationProgress? get progress => _progress;
  DateTime? get ocrBlockedUntil => _ocrBlockedUntil;
  bool get isOCRBlocked =>
      _ocrBlockedUntil != null && _ocrBlockedUntil!.isAfter(DateTime.now());

  /// Save business and manager information (Step 1)
  Future<bool> saveBusinessInfo({
    required String businessName,
    required String businessLicense,
    required String managerFullName,
    required String managerNicNumber,
    required String managerEmail,
    required String district,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await saveBusinessInfoUseCase(
      businessName: businessName,
      businessLicense: businessLicense,
      managerFullName: managerFullName,
      managerNicNumber: managerNicNumber,
      managerEmail: managerEmail,
      district: district,
    );

    return result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (_) {
        _isLoading = false;
        notifyListeners();
        return true;
      },
    );
  }

  /// Upload NIC images with OCR validation (Step 2)
  /// Returns true if OCR passed, false if failed
  Future<bool> uploadNICImages({
    required String frontImagePath,
    required String backImagePath,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await uploadNICImagesUseCase(
      frontImagePath: frontImagePath,
      backImagePath: backImagePath,
    );

    return result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (ocrPassed) {
        _isLoading = false;
        notifyListeners();
        return ocrPassed;
      },
    );
  }

  /// Check if user is blocked from OCR attempts
  Future<void> checkOCRBlock() async {
    final result = await checkOCRBlockUseCase();

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
      },
      (blockedUntil) {
        _ocrBlockedUntil = blockedUntil;
        notifyListeners();
      },
    );
  }

  /// Get current registration progress
  Future<void> loadRegistrationProgress() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await getRegistrationProgressUseCase();

    result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        notifyListeners();
      },
      (progress) {
        _isLoading = false;
        _progress = progress;
        notifyListeners();
      },
    );
  }

  /// Get lounge owner profile
  Future<bool> getLoungeOwnerProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    print('🔍 PROVIDER - Calling getProfileUseCase...');
    final result = await getProfileUseCase();

    return result.fold(
      (failure) {
        print('❌ PROVIDER - Got failure: ${failure.message}');
        _isLoading = false;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (profile) {
        print(
            '🔍 PROVIDER - Got success! Profile type: ${profile.runtimeType}');
        _isLoading = false;
        _profile = profile;

        // 🔍 DEBUG: Log what gets stored in provider
        print('🔍 PROVIDER - Storing profile:');
        print('   profile.registrationStep: ${profile.registrationStep}');
        print('   profile.profileCompleted: ${profile.profileCompleted}');
        print('   _profile is now: ${_profile?.registrationStep}');

        notifyListeners();
        return true;
      },
    );
  }

  /// Get lounge owner profile (alias)
  Future<void> loadProfile() async {
    await getLoungeOwnerProfile();
  }

  /// Update lounge owner profile information
  Future<bool> updateProfile({
    String? businessName,
    String? businessLicense,
    String? managerFullName,
    String? managerNicNumber,
    String? managerEmail,
    String? district,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // We need to use the repository directly since there's no use case for this
      // For now, we'll just reload the profile after attempting the update
      // The actual update call should be done through a use case (future enhancement)

      // This is a placeholder - actual implementation would need a use case
      // similar to SaveBusinessInfo
      if (_profile != null) {
        _profile = _profile!.copyWith(
          businessName: businessName ?? _profile!.businessName,
          businessLicense: businessLicense ?? _profile!.businessLicense,
          managerFullName: managerFullName ?? _profile!.managerFullName,
          managerNicNumber: managerNicNumber ?? _profile!.managerNicNumber,
          managerEmail: managerEmail ?? _profile!.managerEmail,
          district: district ?? _profile!.district,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to update profile: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Clear all data
  void clearData() {
    reset();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Reset state
  void reset() {
    _isLoading = false;
    _errorMessage = null;
    _profile = null;
    _progress = null;
    _ocrBlockedUntil = null;
    notifyListeners();
  }
}
