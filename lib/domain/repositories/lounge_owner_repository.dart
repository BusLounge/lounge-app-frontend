import 'package:dartz/dartz.dart';
import '../entities/lounge_owner.dart';
import '../entities/registration_progress.dart';
import '../../core/error/failures.dart';

abstract class LoungeOwnerRepository {
  /// Save business and manager information (Step 1)
  Future<Either<Failure, void>> saveBusinessInfo({
    required String ownerId,
    required String businessName,
    required String businessLicense,
    required String managerFullName,
    required String managerNicNumber,
    required String managerEmail,
    required String districtId,
  });

  /// Upload Manager NIC images (Step 2)
  Future<Either<Failure, bool>> uploadManagerNIC({
    required String managerNicNumber,
    required String managerNicFrontUrl,
    required String managerNicBackUrl,
    required String ocrExtracted,
    required bool ocrMatched,
  });

  /// Check if OCR is blocked
  Future<Either<Failure, DateTime?>> checkOCRBlock();

  /// Get registration progress
  Future<Either<Failure, RegistrationProgress>> getRegistrationProgress();

  /// Get lounge owner profile
  Future<Either<Failure, LoungeOwner>> getProfile();

  /// Complete registration
  Future<Either<Failure, void>> completeRegistration();

  /// Update lounge owner profile
  Future<Either<Failure, LoungeOwner>> updateProfile({
    String? businessName,
    String? businessLicense,
    String? managerFullName,
    String? managerNicNumber,
    String? managerEmail,
    String? districtId,
  });

  /// Create bank details for lounge owner
  Future<Either<Failure, Map<String, dynamic>>> createBankDetails({
    required String bankName,
    required String branchName,
    required String branchCode,
    required String acType,
    required String acHolderName,
    required String acNumber,
    required String? swiftCode,
  });

  /// Create bank link for lounge owner
  Future<Either<Failure, Map<String, dynamic>>> createBankLink({
    required String bankDetailsId,
    String? loungeId,
  });

  /// List bank links for current lounge owner
  Future<Either<Failure, List<Map<String, dynamic>>>> getBankLinks();

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
  });
}
