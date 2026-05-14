import 'package:dartz/dartz.dart';
import '../../domain/entities/lounge_owner.dart';
import '../../domain/entities/registration_progress.dart';
import '../../domain/repositories/lounge_owner_repository.dart';
import '../../core/error/failures.dart';
import '../../core/error/exceptions.dart';
import '../datasources/lounge_owner_remote_datasource.dart';
import '../models/lounge_owner_model.dart';
import '../models/registration_progress_model.dart';

/// Implementation of LoungeOwnerRepository
/// Converts data source calls to Either<Failure, T> pattern
/// Handles exception to failure conversion
class LoungeOwnerRepositoryImpl implements LoungeOwnerRepository {
  final LoungeOwnerRemoteDataSource remoteDataSource;

  LoungeOwnerRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, void>> saveBusinessInfo({
    required String ownerId,
    required String businessName,
    required String businessLicense,
    required String managerFullName,
    required String managerNicNumber,
    required String managerEmail,
    required String districtId,
  }) async {
    try {
      await remoteDataSource.saveBusinessInfo(
        ownerId: ownerId,
        businessName: businessName,
        businessLicense: businessLicense,
        managerFullName: managerFullName,
        managerNicNumber: managerNicNumber,
        managerEmail: managerEmail,
        districtId: districtId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> uploadManagerNIC({
    required String managerNicNumber,
    required String managerNicFrontUrl,
    required String managerNicBackUrl,
    required String ocrExtracted,
    required bool ocrMatched,
  }) async {
    try {
      final response = await remoteDataSource.uploadManagerNIC(
          managerNicNumber: managerNicNumber,
          managerNicFrontUrl: managerNicFrontUrl,
          managerNicBackUrl: managerNicBackUrl,
          ocrExtractedText: ocrExtracted,
          ocrMatched: ocrMatched);

      // Backend returns { "ocr_matched": true/false, "message": "..." }
      final ocrMatchedResult = response['ocr_matched'] as bool? ?? false;
      return Right(ocrMatchedResult);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, DateTime?>> checkOCRBlock() async {
    try {
      final blockedUntil = await remoteDataSource.checkOCRBlock();
      if (blockedUntil == null) {
        return const Right(null);
      }
      final dateTime = DateTime.parse(blockedUntil);
      return Right(dateTime);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, RegistrationProgress>>
      getRegistrationProgress() async {
    try {
      final json = await remoteDataSource.getRegistrationProgress();
      final progress = RegistrationProgressModel.fromJson(json);
      return Right(progress);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, LoungeOwner>> getProfile() async {
    try {
      final json = await remoteDataSource.getProfile();
      print('🔍 REPOSITORY - Got JSON, creating model...');
      final profile = LoungeOwnerModel.fromJson(json);
      print(
          '🔍 REPOSITORY - Model created successfully: ${profile.registrationStep}, ${profile.profileCompleted}');
      return Right(profile);
    } on ServerException catch (e) {
      print('❌ REPOSITORY - ServerException: ${e.message}');
      return Left(ServerFailure(e.message));
    } catch (e) {
      print('❌ REPOSITORY - Unexpected error: $e');
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> completeRegistration() async {
    try {
      // Backend automatically marks registration as complete after adding first lounge
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, LoungeOwner>> updateProfile({
    String? businessName,
    String? businessLicense,
    String? managerFullName,
    String? managerNicNumber,
    String? managerEmail,
    String? districtId,
  }) async {
    try {
      final json = await remoteDataSource.updateProfile(
        businessName: businessName,
        businessLicense: businessLicense,
        managerFullName: managerFullName,
        managerNicNumber: managerNicNumber,
        managerEmail: managerEmail,
        districtId: districtId,
      );
      final profile = LoungeOwnerModel.fromJson(json);
      return Right(profile);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> createBankDetails({
    required String bankName,
    required String branchName,
    required String branchCode,
    required String acType,
    required String acHolderName,
    required String acNumber,
    required String? swiftCode,
  }) async {
    try {
      final result = await remoteDataSource.createBankDetails(
        bankName: bankName,
        branchName: branchName,
        branchCode: branchCode,
        acType: acType,
        acHolderName: acHolderName,
        acNumber: acNumber,
        swiftCode: swiftCode,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> createBankLink({
    required String bankDetailsId,
    String? loungeId,
  }) async {
    try {
      final result = await remoteDataSource.createBankLink(
        bankDetailsId: bankDetailsId,
        loungeId: loungeId,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getBankLinks() async {
    try {
      final result = await remoteDataSource.getBankLinks();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
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
    try {
      await remoteDataSource.updateBankDetails(
        id: id,
        bankName: bankName,
        branchName: branchName,
        branchCode: branchCode,
        acType: acType,
        acHolderName: acHolderName,
        acNumber: acNumber,
        swiftCode: swiftCode,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }
}
