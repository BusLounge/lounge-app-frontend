import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/lounge_staff_model.dart';
import '../../core/error/exceptions.dart';
import '../../core/network/api_client.dart';
import '../../config/api_config.dart';

/// Remote Data Source: Lounge Staff API
/// Handles all lounge staff-related API calls according to backend documentation
abstract class LoungeStaffRemoteDataSource {
  /// Add staff directly to lounge (Lounge Owner only) - requires approval
  /// POST /api/v1/lounges/:id/staff/direct-add
  Future<LoungeStaffModel> addStaffDirectly({
    required String loungeId,
    required String fullName,
    required String nicNumber,
    required String phone,
    required String email,
    required DateTime hiredDate,
  });

  /// Get all staff for a specific lounge (Lounge Owner only)
  /// GET /api/v1/lounges/:lounge_id/staff
  Future<List<LoungeStaffModel>> getStaffByLounge({
    required String loungeId,
    String? approvalStatus, // approved, pending, declined
    String? employmentStatus, // active, suspended, terminated
  });

  /// Get staff filtered by approval status
  /// GET /api/v1/lounges/:lounge_id/staff?approval_status=<status>
  Future<List<LoungeStaffModel>> getStaffByApprovalStatus({
    required String loungeId,
    required String approvalStatus,
  });

  /// Approve or decline staff application (Lounge Owner only)
  /// PUT /api/v1/lounges/:lounge_id/staff/:staff_id/approval
  Future<Map<String, dynamic>> updateStaffApproval({
    required String loungeId,
    required String staffId,
    required String approvalStatus,
  });

  /// Remove staff member from a lounge (Lounge Owner only)
  /// DELETE /api/v1/lounges/:lounge_id/staff/:staff_id
  Future<void> removeStaff({
    required String loungeId,
    required String staffId,
  });

  /// Get my staff profile (Staff member view)
  /// GET /api/v1/lounge-staff/profile
  Future<LoungeStaffModel> getMyStaffProfile();

  /// Update my staff profile
  /// PUT /api/v1/lounge-staff/profile/update
  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? phone,
    String? nicNumber,
    String? email,
    String? notes,
  });
}

class LoungeStaffRemoteDataSourceImpl implements LoungeStaffRemoteDataSource {
  final ApiClient apiClient;
  late final Dio _loungeDio; // Separate Dio instance for local lounge APIs
  final _secureStorage = const FlutterSecureStorage();

  LoungeStaffRemoteDataSourceImpl({required this.apiClient}) {
    // Create dedicated Dio instance for local lounge backend
    _loungeDio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.getLoungeBaseUrl(),
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add auth interceptor to include JWT token from secure storage
    _loungeDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.read(key: 'access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            print('🔐 Lounge API: Token added to request');
          } else {
            print('⚠️ Lounge API: No token found in storage');
          }
          return handler.next(options);
        },
      ),
    );
  }

  @override
  Future<LoungeStaffModel> addStaffDirectly({
    required String loungeId,
    required String fullName,
    required String nicNumber,
    required String phone,
    required String email,
    required DateTime hiredDate,
  }) async {
    try {
      final baseUrl = ApiConfig.getLoungeBaseUrl();
      final endpoint = '/api/v1/lounges/$loungeId/staff/direct-add';
      final fullUrl = '$baseUrl$endpoint';

      print('📤 [LOUNGE API] Adding staff to lounge: $loungeId');
      print('📤 [LOUNGE API] Full URL: $fullUrl');
      print('📤 [LOUNGE API] Base URL: $baseUrl');
      print('📤 [LOUNGE API] Endpoint: $endpoint');
      print(
        '📤 [LOUNGE API] Staff data: fullName=$fullName, nic=$nicNumber, phone=$phone, email=$email, hiredDate=$hiredDate',
      );

      // Check if we have auth token
      final token = await _secureStorage.read(key: 'access_token');
      if (token != null) {
        print('📤 [AUTH] Token available for request');
      } else {
        print('⚠️ [AUTH] WARNING: No auth token found!');
      }

      final response = await _loungeDio.post(
        endpoint,
        data: {
          'lounge_id': loungeId,
          'full_name': fullName,
          'nic_number': nicNumber,
          'phone': phone,
          'email': email,
          'hired_date': hiredDate.toIso8601String(),
        },
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response data: ${response.data}');
      print('📥 Response data type: ${response.data.runtimeType}');

      if (response.data == null) {
        throw const ServerException(
          'Empty response from server',
          'EMPTY_RESPONSE',
          null,
        );
      }

      // Handle different response formats
      try {
        final responseData = response.data;

        // If response is wrapped in a data/staff field
        if (responseData is Map<String, dynamic>) {
          final staffData =
              responseData['staff'] ?? responseData['data'] ?? responseData;
          return LoungeStaffModel.fromJson(staffData as Map<String, dynamic>);
        }

        return LoungeStaffModel.fromJson(responseData as Map<String, dynamic>);
      } catch (e) {
        print('❌ Error parsing response: $e');
        print('❌ Response structure: ${response.data}');
        throw const ServerException(
          'Failed to parse staff data from response',
          'PARSE_ERROR',
          null,
        );
      }
    } on DioException catch (e) {
      print('❌ DioException: ${e.message}');
      print('❌ Response: ${e.response?.data}');
      throw _handleDioError(e);
    } catch (e) {
      print('❌ Unexpected error: $e');
      rethrow;
    }
  }

  @override
  Future<List<LoungeStaffModel>> getStaffByLounge({
    required String loungeId,
    String? approvalStatus,
    String? employmentStatus,
  }) async {
    try {
      final queryParameters = <String, dynamic>{};
      if (approvalStatus != null) {
        queryParameters['approval_status'] = approvalStatus;
      }
      if (employmentStatus != null) {
        queryParameters['employment_status'] = employmentStatus;
      }

      final response = await _loungeDio.get(
        '/api/v1/lounges/$loungeId/staff',
        queryParameters: queryParameters,
      );

      if (response.data == null) {
        throw const ServerException(
          'Empty response from server',
          'EMPTY_RESPONSE',
          null,
        );
      }

      final staffList = _extractStaffList(response.data);
      return staffList.map((json) => LoungeStaffModel.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to parse staff data from response',
        'PARSE_ERROR',
      );
    }
  }

  @override
  Future<List<LoungeStaffModel>> getStaffByApprovalStatus({
    required String loungeId,
    required String approvalStatus,
  }) async {
    try {
      final response = await _loungeDio.get(
        '/api/v1/lounges/$loungeId/staff',
        queryParameters: {'approval_status': approvalStatus},
      );

      if (response.data == null) {
        throw const ServerException(
          'Empty response from server',
          'EMPTY_RESPONSE',
          null,
        );
      }

      final staffList = _extractStaffList(response.data);
      return staffList.map((json) => LoungeStaffModel.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(
        'Failed to parse staff data from response',
        'PARSE_ERROR',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> updateStaffApproval({
    required String loungeId,
    required String staffId,
    required String approvalStatus,
  }) async {
    try {
      final response = await _loungeDio.put(
        '/api/v1/lounges/$loungeId/staff/$staffId/approval',
        data: {
          'approval_status': approvalStatus,
          'approvement_status': approvalStatus,
        },
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }

      return {'message': 'Staff approval status updated successfully'};
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<void> removeStaff({
    required String loungeId,
    required String staffId,
  }) async {
    try {
      final response = await _loungeDio.delete(
        '/api/v1/lounges/$loungeId/staff/$staffId',
      );

      if (response.statusCode != 200) {
        throw ServerException(
          'Failed to remove staff member',
          'REMOVE_STAFF_FAILED',
          response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<LoungeStaffModel> getMyStaffProfile() async {
    try {
      final response = await _loungeDio.get('/api/v1/lounge-staff/profile');

      if (response.data == null) {
        throw const ServerException(
          'Empty response from server',
          'EMPTY_RESPONSE',
          null,
        );
      }

      return LoungeStaffModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Handle Dio errors and convert to app exceptions
  AppException _handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const NetworkException(
        'Connection timeout. Please check backend availability and network connectivity.',
      );
    }

    if (error.type == DioExceptionType.connectionError) {
      return const NetworkException(
        'Cannot connect to server. Please ensure the backend is running and accessible.',
      );
    }

    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final data = error.response!.data;

      String message = 'An error occurred';
      String? code;

      if (data is Map<String, dynamic>) {
        message = data['message'] as String? ?? message;
        code = data['code'] as String? ?? data['error'] as String?;
      }

      if (statusCode == 401) {
        return AuthException(message, code);
      } else if (statusCode == 403) {
        return AuthException(message, code ?? 'FORBIDDEN');
      } else if (statusCode == 409) {
        // Conflict - usually duplicate entry
        return ServerException(
          message.isNotEmpty
              ? message
              : 'This staff member already exists or there is a conflict with the data',
          code ?? 'CONFLICT',
          statusCode,
        );
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

  List<Map<String, dynamic>> _extractStaffList(dynamic responseData) {
    if (responseData is List) {
      return responseData.whereType<Map<String, dynamic>>().toList();
    }

    if (responseData is Map<String, dynamic>) {
      final dynamic unwrapped = responseData['staff'] ??
          responseData['data'] ??
          responseData['result'];

      if (unwrapped is List) {
        return unwrapped.whereType<Map<String, dynamic>>().toList();
      }

      if (unwrapped is Map<String, dynamic>) {
        final dynamic nestedList = unwrapped['staff'] ?? unwrapped['data'];
        if (nestedList is List) {
          return nestedList.whereType<Map<String, dynamic>>().toList();
        }
      }
    }

    throw const ServerException(
      'Failed to parse staff data from response',
      'PARSE_ERROR',
    );
  }

  @override
  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? phone,
    String? nicNumber,
    String? email,
    String? notes,
  }) async {
    try {
      print('📤 Sending lounge staff profile update request...');
      if (fullName != null) print('   Full Name: $fullName');
      if (phone != null) print('   Phone: $phone');
      if (nicNumber != null) print('   NIC Number: $nicNumber');
      if (email != null) print('   Email: $email');
      if (notes != null) print('   Notes: $notes');

      final data = <String, dynamic>{};
      if (fullName != null) data['full_name'] = fullName;
      if (phone != null) {
        data['phone'] = phone;
        data['phone_number'] = phone;
      }
      if (nicNumber != null) data['nic_number'] = nicNumber;
      if (email != null) data['email'] = email;
      if (notes != null) data['notes'] = notes;

      final response = await _loungeDio.put(
        '/api/v1/lounge-staff/profile/update',
        data: data,
      );

      if (response.statusCode != 200) {
        throw ServerException(
          'Failed to update lounge staff profile',
          'UPDATE_STAFF_PROFILE_FAILED',
          response.statusCode,
        );
      }

      print('✅ Lounge staff profile updated successfully');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      print('❌ DioException in updateProfile:');
      print('   Status Code: ${e.response?.statusCode}');
      print('   Response Data: ${e.response?.data}');
      throw _handleDioError(e);
    } catch (e) {
      print('❌ Error: $e');
      throw ServerException(e.toString(), 'UNKNOWN_ERROR');
    }
  }
}
