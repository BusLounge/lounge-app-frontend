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
}
