import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../models/auth_tokens_model.dart';
import '../../core/error/exceptions.dart';

/// Remote Data Source: Authentication API
/// Handles all authentication-related API calls
abstract class AuthRemoteDataSource {
  Future<void> sendOtp(String phoneNumber);
  Future<AuthRemoteResult> verifyOtp(String phoneNumber, String otp);
  Future<AuthRemoteResult> verifyOtpGeneric(String phoneNumber, String otp);
  Future<AuthRemoteResult> verifyOtpLoungeOwner(String phoneNumber, String otp);
  Future<AuthRemoteResult> verifyOtpLoungeStaff({
    required String phoneNumber,
    required String otp,
    required String loungeId,
    required String fullName,
    required String nicNumber,
    required String email,
  });
  Future<AuthRemoteResult> verifyOtpLoungeStaffRegistered(
      String phoneNumber, String otp);
  Future<AuthTokensModel> refreshToken(String refreshToken);
  Future<void> logout({required String? refreshToken, required bool logoutAll});
  Future<UserModel> getUserProfile({String? accessToken});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;
  final String baseUrl;

  AuthRemoteDataSourceImpl({
    required this.dio,
    required this.baseUrl,
  });

  @override
  Future<void> sendOtp(String phoneNumber) async {
    try {
      final response = await dio.post(
        '$baseUrl/api/v1/auth/send-otp',
        data: {
          'phone_number': phoneNumber,
          'app_type': 'lounge_owner',
        },
      );

      if (response.statusCode != 200) {
        throw ServerException(
          'Failed to send OTP',
          'SEND_OTP_FAILED',
          response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthRemoteResult> verifyOtp(String phoneNumber, String otp) async {
    try {
      // Use lounge-owner-specific endpoint for this app
      final response = await dio.post(
        '$baseUrl/api/v1/auth/verify-otp-lounge-owner',
        data: {
          'phone_number': phoneNumber,
          'otp': otp,
        },
      );

      if (response.statusCode != 200) {
        throw ServerException(
          'Failed to verify OTP',
          'VERIFY_OTP_FAILED',
          response.statusCode,
        );
      }

      final data = response.data as Map<String, dynamic>;

      // Extract tokens
      final tokens = AuthTokensModel.fromJson(data);

      // Extract user roles from response
      final roles = List<String>.from(data['roles'] ?? []);

      // Extract is_new_user flag
      final isNewUser = data['is_new_user'] as bool? ?? false;

      // Extract registration_step for lounge owners
      final registrationStep = data['registration_step'] as String?;

      // Decode JWT to get user ID and phone
      final decodedToken = _decodeJWT(tokens.accessToken);
      final userId = decodedToken['user_id'] as String? ??
          decodedToken['sub'] as String? ??
          '';
      final phoneFromToken = decodedToken['phone'] as String? ?? phoneNumber;
      final profileCompleted =
          decodedToken['profile_completed'] as bool? ?? false;

      // Create user model from JWT data and API response
      final user = UserModel(
        id: userId,
        phoneNumber: phoneFromToken,
        email: null, // Will be filled when profile is completed
        firstName: null,
        lastName: null,
        roles: roles,
        profileCompleted: profileCompleted,
        phoneVerified: true, // OTP verified means phone is verified
        status: 'active',
      );

      return AuthRemoteResult(
        user: user,
        tokens: tokens,
        roles: roles,
        isNewUser: isNewUser,
        registrationStep: registrationStep,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthRemoteResult> verifyOtpGeneric(
      String phoneNumber, String otp) async {
    try {
      // Use generic endpoint that doesn't assign any role
      final response = await dio.post(
        '$baseUrl/api/v1/auth/verify-otp-generic',
        data: {
          'phone_number': phoneNumber,
          'otp': otp,
        },
      );

      if (response.statusCode != 200) {
        throw ServerException(
          'Failed to verify OTP',
          'VERIFY_OTP_FAILED',
          response.statusCode,
        );
      }

      final data = response.data as Map<String, dynamic>;

      // Extract tokens
      final tokens = AuthTokensModel.fromJson(data);

      // Extract user roles from response (will be empty for new users)
      final roles = List<String>.from(data['roles'] ?? []);

      // Extract is_new_user flag
      final isNewUser = data['is_new_user'] as bool? ?? false;

      // Extract registration_step (will be null for generic endpoint)
      final registrationStep = data['registration_step'] as String?;

      // Decode JWT to get user ID and phone
      final decodedToken = _decodeJWT(tokens.accessToken);
      final userId = decodedToken['user_id'] as String? ??
          decodedToken['sub'] as String? ??
          '';
      final phoneFromToken = decodedToken['phone'] as String? ?? phoneNumber;
      final profileCompleted =
          decodedToken['profile_completed'] as bool? ?? false;

      // Create user model from JWT data and API response
      final user = UserModel(
        id: userId,
        phoneNumber: phoneFromToken,
        email: null,
        firstName: null,
        lastName: null,
        roles: roles,
        profileCompleted: profileCompleted,
        phoneVerified: true,
        status: 'active',
      );

      return AuthRemoteResult(
        user: user,
        tokens: tokens,
        roles: roles,
        isNewUser: isNewUser,
        registrationStep: registrationStep,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthRemoteResult> verifyOtpLoungeOwner(
      String phoneNumber, String otp) async {
    try {
      // Use lounge-owner-specific endpoint
      final response = await dio.post(
        '$baseUrl/api/v1/auth/verify-otp-lounge-owner',
        data: {
          'phone_number': phoneNumber,
          'otp': otp,
        },
      );

      if (response.statusCode != 200) {
        throw ServerException(
          'Failed to verify OTP',
          'VERIFY_OTP_FAILED',
          response.statusCode,
        );
      }

      final data = response.data as Map<String, dynamic>;

      // Extract tokens
      final tokens = AuthTokensModel.fromJson(data);

      // Extract user roles from response
      final roles = List<String>.from(data['roles'] ?? []);

      // Extract is_new_user flag
      final isNewUser = data['is_new_user'] as bool? ?? false;

      // Extract registration_step for lounge owners
      final registrationStep = data['registration_step'] as String?;

      // Decode JWT to get user ID and phone
      final decodedToken = _decodeJWT(tokens.accessToken);
      final userId = decodedToken['user_id'] as String? ??
          decodedToken['sub'] as String? ??
          '';
      final phoneFromToken = decodedToken['phone'] as String? ?? phoneNumber;
      final profileCompleted =
          decodedToken['profile_completed'] as bool? ?? false;

      // Create user model from JWT data and API response
      final user = UserModel(
        id: userId,
        phoneNumber: phoneFromToken,
        email: null,
        firstName: null,
        lastName: null,
        roles: roles,
        profileCompleted: profileCompleted,
        phoneVerified: true,
        status: 'active',
      );

      return AuthRemoteResult(
        user: user,
        tokens: tokens,
        roles: roles,
        isNewUser: isNewUser,
        registrationStep: registrationStep,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthRemoteResult> verifyOtpLoungeStaffRegistered(
      String phoneNumber, String otp) async {
    try {
      final response = await dio.post(
        '$baseUrl/api/v1/auth/verify-otp-lounge-staff-registered',
        data: {
          'phone_number': phoneNumber,
          'otp': otp,
        },
      );

      if (response.statusCode != 200) {
        throw ServerException(
          'Failed to verify OTP',
          'VERIFY_OTP_FAILED',
          response.statusCode,
        );
      }

      final data = response.data as Map<String, dynamic>;

      final tokens = AuthTokensModel.fromJson(data);
      final roles = List<String>.from(data['roles'] ?? []);
      final isNewUser = data['is_new_user'] as bool? ?? false;

      final decodedToken = _decodeJWT(tokens.accessToken);
      final userId = decodedToken['user_id'] as String? ??
          decodedToken['sub'] as String? ??
          '';
      final phoneFromToken = decodedToken['phone'] as String? ?? phoneNumber;
      final profileCompleted =
          decodedToken['profile_completed'] as bool? ?? false;

      final user = UserModel(
        id: userId,
        phoneNumber: phoneFromToken,
        email: null,
        firstName: null,
        lastName: null,
        roles: roles,
        profileCompleted: profileCompleted,
        phoneVerified: true,
        status: 'active',
      );

      return AuthRemoteResult(
        user: user,
        tokens: tokens,
        roles: roles,
        isNewUser: isNewUser,
        registrationStep: null,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<AuthRemoteResult> verifyOtpLoungeStaff({
    required String phoneNumber,
    required String otp,
    required String loungeId,
    required String fullName,
    required String nicNumber,
    required String email,
  }) async {
    try {
      // Use lounge-staff-specific endpoint
      final response = await dio.post(
        '$baseUrl/api/v1/auth/verify-otp-lounge-staff',
        data: {
          'phone_number': phoneNumber,
          'otp': otp,
          'lounge_id': loungeId,
          'full_name': fullName,
          'nic_number': nicNumber,
          'email': email,
        },
      );

      if (response.statusCode != 200) {
        throw ServerException(
          'Failed to verify OTP',
          'VERIFY_OTP_FAILED',
          response.statusCode,
        );
      }

      final data = response.data as Map<String, dynamic>;

      // Extract tokens
      final tokens = AuthTokensModel.fromJson(data);

      // Extract user roles from response
      final roles = List<String>.from(data['roles'] ?? []);

      // Extract is_new_user flag
      final isNewUser = data['is_new_user'] as bool? ?? false;

      // Staff profile is always complete after registration
      final profileCompleted = data['profile_complete'] as bool? ?? true;

      // Decode JWT to get user ID and phone
      final decodedToken = _decodeJWT(tokens.accessToken);
      final userId = decodedToken['user_id'] as String? ??
          decodedToken['sub'] as String? ??
          '';
      final phoneFromToken = decodedToken['phone'] as String? ?? phoneNumber;

      // Create user model from JWT data and API response
      final user = UserModel(
        id: userId,
        phoneNumber: phoneFromToken,
        email: email,
        firstName: fullName,
        lastName: null,
        roles: roles,
        profileCompleted: profileCompleted,
        phoneVerified: true,
        status: 'active',
      );

      return AuthRemoteResult(
        user: user,
        tokens: tokens,
        roles: roles,
        isNewUser: isNewUser,
        registrationStep: null, // Staff don't have registration steps
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Decode JWT token to extract payload
  /// JWT format: header.payload.signature
  Map<String, dynamic> _decodeJWT(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return {};
      }

      // Decode the payload (second part)
      final payload = parts[1];

      // Add padding if needed (JWT base64 doesn't use padding)
      var normalized = base64Url.normalize(payload);

      // Decode base64
      final decoded = utf8.decode(base64Url.decode(normalized));

      // Parse JSON
      return json.decode(decoded) as Map<String, dynamic>;
    } catch (e) {
      print('Error decoding JWT: $e');
      return {};
    }
  }

  @override
  Future<AuthTokensModel> refreshToken(String refreshToken) async {
    try {
      final response = await dio.post(
        '$baseUrl/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode != 200) {
        throw ServerException(
          'Failed to refresh token',
          'REFRESH_TOKEN_FAILED',
          response.statusCode,
        );
      }

      return AuthTokensModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> logout({
    required String? refreshToken,
    required bool logoutAll,
  }) async {
    try {
      final response = await dio.post(
        '$baseUrl/api/v1/auth/logout',
        data: {
          if (refreshToken != null) 'refresh_token': refreshToken,
          'logout_all': logoutAll,
        },
      );

      // Success or already logged out (token already revoked) - both are fine
      if (response.statusCode != 200 && response.statusCode != 500) {
        print('⚠️ Logout returned unexpected status: ${response.statusCode}');
      }
    } on DioException catch (e) {
      // Don't throw error on logout - clear local state anyway
      // Handle common cases: token already revoked (500), network errors, etc.
      print(
          '⚠️ Logout API error (ignoring): ${e.response?.statusCode} - ${e.message}');
    } catch (e) {
      print('⚠️ Logout unexpected error (ignoring): $e');
    }
  }

  @override
  Future<UserModel> getUserProfile({String? accessToken}) async {
    try {
      // If accessToken provided, use it directly (for initial login)
      // Otherwise, interceptor will add token from local storage
      final options = accessToken != null
          ? Options(headers: {'Authorization': 'Bearer $accessToken'})
          : null;

      final response = await dio.get(
        '$baseUrl/api/v1/user/profile',
        options: options,
      );

      if (response.statusCode != 200) {
        throw ServerException(
          'Failed to get user profile',
          'GET_PROFILE_FAILED',
          response.statusCode,
        );
      }

      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Handle Dio errors and convert to app exceptions
  AppException _handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const NetworkException('Connection timeout');
    }

    if (error.type == DioExceptionType.connectionError) {
      return const NetworkException('No internet connection');
    }

    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final data = error.response!.data;
      final rawData = data?.toString().toLowerCase() ?? '';

      final isLoungeNotApprovedError = (rawData.contains('lounge') &&
              rawData.contains('not') &&
              rawData.contains('approved')) ||
          rawData.contains('lounge_not_approved') ||
          rawData.contains('selected_lounge_not_approved');

      if (isLoungeNotApprovedError) {
        return ServerException(
          'The selected lounge is not yet approved. Please try another lounge.',
          'LOUNGE_NOT_APPROVED',
          statusCode,
        );
      }

      final isDuplicateEmailError = (rawData.contains('users_email_key') ||
          (rawData.contains('email') &&
              (rawData.contains('duplicate') ||
                  rawData.contains('already') ||
                  rawData.contains('exists') ||
                  rawData.contains('registered') ||
                  rawData.contains('23505'))));

      if (isDuplicateEmailError) {
        return ServerException(
          'This email is already registered.',
          'EMAIL_ALREADY_REGISTERED',
          statusCode,
        );
      }

      String message = 'An error occurred';
      String? code;

      if (data is Map<String, dynamic>) {
        message = data['message'] as String? ?? message;
        code = data['code'] as String? ?? data['error'] as String?;
      }

      if (statusCode == 401) {
        return AuthException(message, code);
      } else if (statusCode == 429) {
        return ServerException(message, code, statusCode);
      } else if (statusCode != null && statusCode >= 500) {
        return ServerException(message, code, statusCode);
      } else {
        return ServerException(message, code, statusCode);
      }
    }

    return NetworkException(error.message ?? 'Network error');
  }
}

/// Result from remote authentication
class AuthRemoteResult {
  final UserModel user;
  final AuthTokensModel tokens;
  final List<String> roles;
  final bool isNewUser;
  final String?
      registrationStep; // For lounge owners: phone_verified, personal_info, nic_uploaded, lounge_added, completed

  AuthRemoteResult({
    required this.user,
    required this.tokens,
    required this.roles,
    required this.isNewUser,
    this.registrationStep,
  });
}
