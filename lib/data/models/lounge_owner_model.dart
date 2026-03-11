import '../../domain/entities/lounge_owner.dart';

/// Model for LoungeOwner that extends the entity and handles backend JSON
/// Backend has business and manager fields for the new multi-entity structure
/// Note: total_lounges and total_staff are dynamically calculated by backend
class LoungeOwnerModel extends LoungeOwner {
  final int? totalLounges; // Dynamic count from backend
  final int? totalStaff; // Dynamic count from backend

  const LoungeOwnerModel({
    required super.id,
    required super.userId,
    super.businessName,
    super.businessLicense,
    super.managerFullName,
    super.managerNicNumber,
    super.managerEmail,
    super.district,
    required super.registrationStep,
    required super.profileCompleted,
    required super.verificationStatus,
    super.verificationNotes,
    super.verifiedAt,
    super.nicOcrAttempts,
    super.lastOcrAttemptAt,
    super.ocrBlockedUntil,
    required super.createdAt,
    required super.updatedAt,
    this.totalLounges,
    this.totalStaff,
  });

  factory LoungeOwnerModel.fromJson(Map<String, dynamic> json) {
    final managerMap = _asMap(json['manager']);
    final businessMap = _asMap(json['business']);

    // 🔍 DEBUG: Log raw JSON values
    print('🔍 LoungeOwnerModel.fromJson - Raw JSON:');
    print('   registration_step: ${json['registration_step']}');
    print('   profile_completed: ${json['profile_completed']}');

    final model = LoungeOwnerModel(
      id: _parseOptionalText(
            json['id'] ?? json['owner_id'] ?? json['lounge_owner_id'],
          ) ??
          '',
      userId: _parseOptionalText(
            json['user_id'] ?? json['userId'] ?? json['owner_user_id'],
          ) ??
          '',
      businessName: _parseOptionalText(
        json['business_name'] ?? businessMap?['name'],
      ),
      businessLicense: _parseOptionalText(
        json['business_license'] ?? businessMap?['license'],
      ),
      managerFullName: _parseOptionalText(
        json['manager_full_name'] ??
            managerMap?['full_name'] ??
            managerMap?['name'],
      ),
      managerNicNumber: _parseOptionalText(
        json['manager_nic_number'] ??
            managerMap?['nic_number'] ??
            managerMap?['nic'],
      ),
      managerEmail: _parseOptionalText(
        json['manager_email'] ??
            json['managerEmail'] ??
            managerMap?['email'] ??
            json['email'] ??
            _findDeepValue(
              json,
              const {'manageremail', 'email'},
            ),
      ),
      district: _parseDistrict(
        json['district'] ??
            businessMap?['district'] ??
            managerMap?['district'] ??
            _findDeepValue(
              json,
              const {'district', 'businessdistrict', 'ownerdistrict'},
            ),
      ),
      registrationStep:
          json['registration_step'] as String? ?? 'phone_verified',
      profileCompleted: json['profile_completed'] as bool? ?? false,
      verificationStatus: json['verification_status'] as String? ?? 'pending',
      verificationNotes: json['verification_notes'] as String?,
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'] as String)
          : null,
      nicOcrAttempts: json['nic_ocr_attempts'] as int? ?? 0,
      lastOcrAttemptAt: json['last_ocr_attempt_at'] != null
          ? DateTime.parse(json['last_ocr_attempt_at'] as String)
          : null,
      ocrBlockedUntil: json['ocr_blocked_until'] != null
          ? DateTime.parse(json['ocr_blocked_until'] as String)
          : null,
      createdAt: DateTime.parse(
        _parseOptionalText(json['created_at']) ??
            DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        _parseOptionalText(json['updated_at']) ??
            DateTime.now().toIso8601String(),
      ),
      totalLounges: json['total_lounges'] as int? ?? 0,
      totalStaff: json['total_staff'] as int? ?? 0,
    );

    // 🔍 DEBUG: Log parsed model values
    print('🔍 LoungeOwnerModel.fromJson - Parsed model:');
    print('   registrationStep: ${model.registrationStep}');
    print('   profileCompleted: ${model.profileCompleted}');

    return model;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'business_name': businessName,
      'business_license': businessLicense,
      'manager_full_name': managerFullName,
      'manager_nic_number': managerNicNumber,
      'manager_email': managerEmail,
      'district': district,
      'registration_step': registrationStep,
      'profile_completed': profileCompleted,
      'verification_status': verificationStatus,
      'verification_notes': verificationNotes,
      'verified_at': verifiedAt?.toIso8601String(),
      'nic_ocr_attempts': nicOcrAttempts,
      'last_ocr_attempt_at': lastOcrAttemptAt?.toIso8601String(),
      'ocr_blocked_until': ocrBlockedUntil?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'total_lounges': totalLounges,
      'total_staff': totalStaff,
    };
  }

  @override
  LoungeOwnerModel copyWith({
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
    int? totalLounges,
    int? totalStaff,
  }) {
    return LoungeOwnerModel(
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
      totalLounges: totalLounges ?? this.totalLounges,
      totalStaff: totalStaff ?? this.totalStaff,
    );
  }

  static String? _parseDistrict(dynamic districtValue) {
    if (districtValue == null) return null;

    if (districtValue is String) {
      final trimmed = districtValue.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (districtValue is Map<String, dynamic>) {
      final raw = districtValue['String'] ??
          districtValue['string'] ??
          districtValue['district'] ??
          districtValue['name'] ??
          districtValue['value'];

      // Prefer actual string content if present, even if `Valid` is false.
      if (raw is String) {
        final trimmed = raw.trim();
        return trimmed.isEmpty ? null : trimmed;
      }

      if (raw != null) {
        final value = raw.toString().trim();
        return value.isEmpty ? null : value;
      }

      final valid = districtValue['Valid'] ?? districtValue['valid'];
      if (valid is bool && !valid) {
        return null;
      }

      return null;
    }

    final fallback = districtValue.toString().trim();
    return fallback.isEmpty ? null : fallback;
  }

  static String? _parseOptionalText(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (value is Map<String, dynamic>) {
      final raw =
          value['String'] ?? value['string'] ?? value['value'] ?? value['text'];
      if (raw != null) {
        final parsed = raw.toString().trim();
        return parsed.isEmpty ? null : parsed;
      }

      final valid = value['Valid'] ?? value['valid'];
      if (valid is bool && !valid) return null;
      return null;
    }

    final fallback = value.toString().trim();
    return fallback.isEmpty ? null : fallback;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  static dynamic _findDeepValue(
    dynamic source,
    Set<String> targetKeys,
  ) {
    if (source is Map<String, dynamic>) {
      for (final entry in source.entries) {
        final key = entry.key.toLowerCase().replaceAll('_', '');
        if (targetKeys.contains(key)) {
          return entry.value;
        }
      }

      for (final entry in source.entries) {
        final result = _findDeepValue(entry.value, targetKeys);
        if (result != null) return result;
      }
    }

    if (source is List) {
      for (final item in source) {
        final result = _findDeepValue(item, targetKeys);
        if (result != null) return result;
      }
    }

    return null;
  }
}
