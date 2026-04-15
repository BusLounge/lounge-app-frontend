import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../repositories/lounge_owner_repository.dart';

class SaveBusinessInfo {
  final LoungeOwnerRepository repository;

  SaveBusinessInfo(this.repository);

  Future<Either<Failure, void>> call({
    required String ownerId,
    required String businessName,
    required String businessLicense,
    required String managerFullName,
    required String managerNicNumber,
    required String managerEmail,
    required String districtId,
  }) async {
    if (ownerId.trim().isEmpty) {
      return Left(ValidationFailure('Owner ID is required'));
    }

    // Validate business name
    if (businessName.trim().isEmpty) {
      return Left(ValidationFailure('Business name is required'));
    }

    // Validate manager full name
    if (managerFullName.trim().isEmpty) {
      return Left(ValidationFailure('Manager full name is required'));
    }

    // Validate manager NIC
    if (managerNicNumber.trim().isEmpty) {
      return Left(ValidationFailure('Manager NIC number is required'));
    }

    // Validate NIC format (Sri Lankan NIC: 9 digits + V or 12 digits)
    final nicPattern = RegExp(r'^(\d{9}[VvXx]|\d{12})$');
    if (!nicPattern.hasMatch(managerNicNumber.trim())) {
      return Left(ValidationFailure('Invalid manager NIC format'));
    }

    // Validate manager email (optional but must be valid if provided)
    if (managerEmail.trim().isNotEmpty) {
      final emailPattern = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailPattern.hasMatch(managerEmail.trim())) {
        return Left(ValidationFailure('Invalid manager email format'));
      }
    }

    // Validate district
    if (districtId.trim().isEmpty) {
      return Left(ValidationFailure('District is required'));
    }

    return await repository.saveBusinessInfo(
      ownerId: ownerId.trim(),
      businessName: businessName.trim(),
      businessLicense: businessLicense.trim(),
      managerFullName: managerFullName.trim(),
      managerNicNumber: managerNicNumber.trim().toUpperCase(),
      districtId: districtId.trim(),
      managerEmail: managerEmail.trim(),
    );
  }
}
