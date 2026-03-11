import 'package:equatable/equatable.dart';

/// Entity representing a lounge owner in the system
/// Owner manages business with lounges - separate business and manager info
class LoungeOwner extends Equatable {
  final String id;
  final String userId;

  // Business Information
  final String? businessName;
  final String? businessLicense;

  // Manager Information (person managing the business)
  final String? managerFullName;
  final String? managerNicNumber;
  final String? managerEmail;
  final String? district;
  // Note: Manager NIC images now stored in Supabase storage only (not in database)

  // Registration Progress (NIC verification removed)
  final String
      registrationStep; // phone_verified, business_info, lounge_added, completed
  final bool profileCompleted;

  // Admin Approval Status
  final String verificationStatus; // pending, approved, rejected
  final String? verificationNotes;
  final DateTime? verifiedAt;

  // Legacy OCR fields (deprecated but kept for backward compatibility)
  final int nicOcrAttempts;
  final DateTime? lastOcrAttemptAt;
  final DateTime? ocrBlockedUntil;

  final DateTime createdAt;
  final DateTime updatedAt;

  const LoungeOwner({
    required this.id,
    required this.userId,
    this.businessName,
    this.businessLicense,
    this.managerFullName,
    this.managerNicNumber,
    this.managerEmail,
    this.district,
    required this.registrationStep,
    required this.profileCompleted,
    required this.verificationStatus,
    this.verificationNotes,
    this.verifiedAt,
    this.nicOcrAttempts = 0,
    this.lastOcrAttemptAt,
    this.ocrBlockedUntil,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        businessName,
        businessLicense,
        managerFullName,
        managerNicNumber,
        managerEmail,
        district,
        registrationStep,
        profileCompleted,
        verificationStatus,
        verificationNotes,
        verifiedAt,
        nicOcrAttempts,
        lastOcrAttemptAt,
        ocrBlockedUntil,
        createdAt,
        updatedAt,
      ];

  /// Check if business and manager info is completed
  bool get hasBusinessInfo =>
      businessName != null &&
      managerFullName != null &&
      managerNicNumber != null;

  /// Check if registration is completed
  bool get isCompleted => registrationStep == 'completed' && profileCompleted;

  /// Check if OCR is currently blocked
  bool get isOCRBlocked {
    if (ocrBlockedUntil == null) return false;
    return DateTime.now().isBefore(ocrBlockedUntil!);
  }

  /// Get remaining OCR attempts
  int get remainingOCRAttempts {
    const maxAttempts = 4;
    return maxAttempts - nicOcrAttempts;
  }

  /// Check if OCR attempts are exhausted
  bool get hasExhaustedOCRAttempts => remainingOCRAttempts <= 0;

  /// Get the time remaining for OCR block in hours
  int? get ocrBlockRemainingHours {
    if (ocrBlockedUntil == null) return null;
    final difference = ocrBlockedUntil!.difference(DateTime.now());
    return difference.inHours;
  }

  LoungeOwner copyWith({
    String? id,
    String? userId,
    String? businessName,
    String? businessLicense,
    String? managerFullName,
    String? managerNicNumber,
    String? managerEmail,
    String? district,
    String? registrationStep,
    bool? profileCompleted,
    String? verificationStatus,
    String? verificationNotes,
    DateTime? verifiedAt,
    int? nicOcrAttempts,
    DateTime? lastOcrAttemptAt,
    DateTime? ocrBlockedUntil,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LoungeOwner(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      businessName: businessName ?? this.businessName,
      businessLicense: businessLicense ?? this.businessLicense,
      managerFullName: managerFullName ?? this.managerFullName,
      managerNicNumber: managerNicNumber ?? this.managerNicNumber,
      managerEmail: managerEmail ?? this.managerEmail,
      district: district ?? this.district,
      registrationStep: registrationStep ?? this.registrationStep,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationNotes: verificationNotes ?? this.verificationNotes,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      nicOcrAttempts: nicOcrAttempts ?? this.nicOcrAttempts,
      lastOcrAttemptAt: lastOcrAttemptAt ?? this.lastOcrAttemptAt,
      ocrBlockedUntil: ocrBlockedUntil ?? this.ocrBlockedUntil,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
