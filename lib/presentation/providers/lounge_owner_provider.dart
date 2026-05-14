import 'package:flutter/foundation.dart';
import '../../domain/entities/lounge_owner.dart';
import '../../domain/entities/registration_progress.dart';
import '../../domain/repositories/lounge_owner_repository.dart';
import '../../domain/usecases/save_business_info.dart';
import '../../domain/usecases/upload_nic_images.dart';
import '../../domain/usecases/get_registration_progress.dart';
import '../../domain/usecases/check_ocr_block.dart';
import '../../domain/usecases/get_profile.dart';
import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';

/// Provider for lounge owner operations
/// Manages state for business info, manager NIC upload, and profile
class LoungeOwnerProvider with ChangeNotifier {
  final SaveBusinessInfo saveBusinessInfoUseCase;
  final UploadNICImages uploadNICImagesUseCase;
  final GetRegistrationProgress getRegistrationProgressUseCase;
  final CheckOCRBlock checkOCRBlockUseCase;
  final GetProfile getProfileUseCase;
  final LoungeOwnerRepository loungeOwnerRepository;

  LoungeOwnerProvider({
    required this.saveBusinessInfoUseCase,
    required this.uploadNICImagesUseCase,
    required this.getRegistrationProgressUseCase,
    required this.checkOCRBlockUseCase,
    required this.getProfileUseCase,
    required this.loungeOwnerRepository,
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
    required String ownerId,
    required String businessName,
    required String businessLicense,
    required String managerFullName,
    required String managerNicNumber,
    required String managerEmail,
    required String districtId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await saveBusinessInfoUseCase(
      ownerId: ownerId,
      businessName: businessName,
      businessLicense: businessLicense,
      managerFullName: managerFullName,
      managerNicNumber: managerNicNumber,
      managerEmail: managerEmail,
      districtId: districtId,
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
  Future<bool> getLoungeOwnerProfile({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    print('🔍 PROVIDER - Calling getProfileUseCase...');
    final result = await getProfileUseCase();

    return result.fold(
      (failure) {
        print('❌ PROVIDER - Got failure: ${failure.message}');
        if (showLoading) {
          _isLoading = false;
        }
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (profile) {
        print(
            '🔍 PROVIDER - Got success! Profile type: ${profile.runtimeType}');
        if (showLoading) {
          _isLoading = false;
        }
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
    String? districtId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await loungeOwnerRepository.updateProfile(
      businessName: businessName,
      businessLicense: businessLicense,
      managerFullName: managerFullName,
      managerNicNumber: managerNicNumber,
      managerEmail: managerEmail,
      districtId: districtId,
    );

    return result.fold(
      (failure) {
        _isLoading = false;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (profile) {
        _isLoading = false;
        _profile = profile;
        notifyListeners();
        return true;
      },
    );
  }

  /// Clear all data
  void clearData() {
    reset();
  }

  /// Create bank details for lounge owner
  Future<Either<Failure, Map<String, dynamic>>> createBankDetails({
    required String bankName,
    required String branchName,
    required String branchCode,
    required String acType,
    required String acHolderName,
    required String acNumber,
    required String? swiftCode,
  }) async {
    return await loungeOwnerRepository.createBankDetails(
      bankName: bankName,
      branchName: branchName,
      branchCode: branchCode,
      acType: acType,
      acHolderName: acHolderName,
      acNumber: acNumber,
      swiftCode: swiftCode,
    );
  }

  /// Create bank link for lounge owner
  Future<Either<Failure, Map<String, dynamic>>> createBankLink({
    required String bankDetailsId,
    String? loungeId,
  }) async {
    return await loungeOwnerRepository.createBankLink(
      bankDetailsId: bankDetailsId,
      loungeId: loungeId,
    );
  }

  /// List bank links for current lounge owner
  Future<Either<Failure, List<Map<String, dynamic>>>> getBankLinks() async {
    return await loungeOwnerRepository.getBankLinks();
  }

  /// Update bank details
  Future<Either<Failure, void>> updateBankDetails({
    required String id,
    required String bankName,
    required String branchName,
    required String branchCode,
    required String acType,
    required String acHolderName,
    required String acNumber,
    required String? swiftCode,
  }) async {
    return await loungeOwnerRepository.updateBankDetails(
      id: id,
      bankName: bankName,
      branchName: branchName,
      branchCode: branchCode,
      acType: acType,
      acHolderName: acHolderName,
      acNumber: acNumber,
      swiftCode: swiftCode,
    );
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
