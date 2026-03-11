import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/error/exceptions.dart';

/// Remote data source for lounge owner registration operations
/// Makes HTTP requests to backend API
class LoungeOwnerRemoteDataSource {
  final ApiClient apiClient;

  LoungeOwnerRemoteDataSource({required this.apiClient});

  /// Save business and manager information (Step 1)
  /// POST /api/v1/lounge-owner/register/business-info
  Future<void> saveBusinessInfo({
    required String businessName,
    required String businessLicense,
    required String managerFullName,
    required String managerNicNumber,
    required String managerEmail,
    required String district,
  }) async {
    try {
      print('📤 Sending business info request...');
      print('   Business Name: $businessName');
      print('   Business License: $businessLicense');
      print('   Manager Name: $managerFullName');
      print('   Manager NIC: $managerNicNumber');
      print('   Manager Email: $managerEmail');
      print('   District: $district');

      final response = await apiClient.post(
        '/api/v1/lounge-owner/register/business-info',
        data: {
          'business_name': businessName,
          'business_license': businessLicense,
          'manager_full_name': managerFullName,
          'manager_nic_number': managerNicNumber,
          'manager_email': managerEmail,
          'district': district,
        },
      );

      print('✅ Business info saved successfully');
      if (response.statusCode != 200) {
        throw ServerException('Failed to save business and manager info');
      }
    } on DioException catch (e) {
      print('❌ DioException in saveBusinessInfo:');
      print('   Status Code: ${e.response?.statusCode}');
      print('   Response Data: ${e.response?.data}');
      print('   Error Message: ${e.message}');

      // Extract meaningful error from backend response
      String errorMessage = 'Failed to save business info';
      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          errorMessage = data['error'] ?? data['message'] ?? errorMessage;
          if (data['details'] != null) {
            errorMessage += ': ${data['details']}';
          }
        }
      }
      throw ServerException(errorMessage);
    } catch (e) {
      print('❌ Unexpected error in saveBusinessInfo: $e');
      throw ServerException(e.toString());
    }
  }

  /// Upload Manager NIC images with OCR validation (Step 2)
  /// POST /api/v1/lounge-owner/register/upload-manager-nic
  Future<Map<String, dynamic>> uploadManagerNIC({
    required String managerNicNumber,
    required String managerNicFrontUrl,
    required String managerNicBackUrl,
    required String ocrExtractedText,
    required bool ocrMatched,
  }) async {
    try {
      final response = await apiClient.post(
        '/api/v1/lounge-owner/register/upload-manager-nic',
        data: {
          'manager_nic_number': managerNicNumber,
          'manager_nic_front_url': managerNicFrontUrl,
          'manager_nic_back_url': managerNicBackUrl,
          'ocr_extracted': ocrExtractedText,
          'ocr_matched': ocrMatched,
        },
      );

      if (response.statusCode != 200) {
        throw ServerException('Failed to upload Manager NIC images');
      }

      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Get registration progress
  /// GET /api/v1/lounge-owner/registration/progress
  Future<Map<String, dynamic>> getRegistrationProgress() async {
    try {
      final response =
          await apiClient.get('/api/v1/lounge-owner/registration/progress');

      if (response.statusCode != 200) {
        throw ServerException('Failed to get registration progress');
      }

      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Get lounge owner profile
  /// GET /api/v1/lounge-owner/profile
  /// Note: If this endpoint doesn't exist on your backend, return empty/mock data
  /// The profile_completed flag from JWT is more reliable
  Future<Map<String, dynamic>> getProfile() async {
    try {
      // Try to get profile from backend
      final response = await apiClient.get('/api/v1/lounge-owner/profile');

      if (response.statusCode != 200) {
        print(
            '⚠️ Profile endpoint returned ${response.statusCode}, returning empty profile');
        return {
          'id': '',
          'profile_completed': false,
          'verification_status': 'pending',
        };
      }

      final rawData = response.data;
      if (rawData is! Map<String, dynamic>) {
        print('⚠️ Profile response is not a map: ${rawData.runtimeType}');
        return {
          'id': '',
          'profile_completed': false,
          'verification_status': 'pending',
        };
      }

      final data = _extractProfilePayload(rawData);

      // 🔍 DEBUG: Log FULL JSON response
      print('🔍 API RESPONSE /lounge-owner/profile FULL JSON:');
      data.forEach((key, value) {
        print('   $key: $value (${value.runtimeType})');
      });

      return data;
    } catch (e) {
      print('⚠️ Failed to get profile: $e, returning empty profile');
      // Return empty profile so app doesn't crash
      // The JWT already tells us if profile is complete
      return {
        'id': '',
        'profile_completed': false,
        'verification_status': 'pending',
      };
    }
  }

  Map<String, dynamic> _extractProfilePayload(Map<String, dynamic> payload) {
    final candidates = [
      payload['data'],
      payload['profile'],
      payload['lounge_owner'],
      payload['loungeOwner'],
      payload['result'],
    ];

    for (final candidate in candidates) {
      if (candidate is Map<String, dynamic>) {
        return candidate;
      }
    }

    return payload;
  }

  /// Check if OCR is blocked
  /// Returns ocr_blocked_until timestamp if blocked, null if not blocked
  Future<String?> checkOCRBlock() async {
    try {
      final progress = await getRegistrationProgress();
      return progress['ocr_blocked_until'] as String?;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Get approved lounge owners grouped by district
  /// GET /api/v1/lounge-owner/approved/grouped-by-district
  /// Response: {"district_name": [{"id": "...", "owner_name": "...", ...}]}
  Future<Map<String, List<Map<String, dynamic>>>>
      getApprovedLoungeOwnersGroupedByDistrict() async {
    try {
      print('📍 Fetching approved lounge owners grouped by district...');
      final response = await apiClient.get(
        '/api/v1/lounge-owner/approved/grouped-by-district',
      );

      print('📍 Response Status: ${response.statusCode}');
      print('📍 Response Data Type: ${response.data.runtimeType}');
      print('📍 Response Data: ${response.data}');

      if (response.statusCode != 200) {
        throw ServerException(
          'Failed to get lounge owners - Status: ${response.statusCode}',
        );
      }

      var responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('lounge_owners_by_district')) {
          responseData = responseData['lounge_owners_by_district'];
        } else if (responseData.containsKey('data')) {
          responseData = responseData['data'];
        } else if (responseData.containsKey('districts')) {
          responseData = responseData['districts'];
        }
      }
      final result = <String, List<Map<String, dynamic>>>{};

      if (responseData is Map<String, dynamic>) {
        responseData.forEach((district, owners) {
          if (owners is List) {
            result[district] =
                owners.map((e) => e as Map<String, dynamic>).toList();
          }
        });
      }

      print('📍 Parsed ${result.length} districts');
      return result;
    } on DioException catch (e) {
      print('❌ DioException: ${e.type}');
      print('❌ Response Status: ${e.response?.statusCode}');
      print('❌ Response Data: ${e.response?.data}');
      final errorMessage =
          e.response?.data?['message'] ?? e.message ?? 'Unknown error';
      throw ServerException('Get lounge owners failed: $errorMessage');
    } catch (e) {
      print('❌ Error: $e');
      throw ServerException(e.toString());
    }
  }

  /// Get lounges owned by a specific lounge owner
  /// GET /api/v1/lounge-owner/:owner_id/lounges
  Future<List<Map<String, dynamic>>> getLoungesByOwnerId(String ownerId) async {
    try {
      print('📍 Fetching lounges for owner: $ownerId');
      final response = await apiClient.get(
        '/api/v1/lounge-owner/$ownerId/lounges',
      );

      print('📍 Response Status: ${response.statusCode}');
      print('📍 Response Data: ${response.data}');

      if (response.statusCode != 200) {
        throw ServerException(
          'Failed to get lounges - Status: ${response.statusCode}',
        );
      }

      final responseData = response.data;
      List<dynamic> loungesList;

      if (responseData is List) {
        loungesList = responseData;
      } else if (responseData is Map && responseData.containsKey('lounges')) {
        loungesList = responseData['lounges'] as List? ?? [];
      } else if (responseData is Map && responseData.containsKey('data')) {
        loungesList = responseData['data'] as List? ?? [];
      } else {
        print('⚠️ Unexpected response format: ${responseData.runtimeType}');
        loungesList = [];
      }

      print('📍 Parsed ${loungesList.length} lounges');
      return loungesList.map((e) => e as Map<String, dynamic>).toList();
    } on DioException catch (e) {
      print('❌ DioException: ${e.type}');
      print('❌ Response Status: ${e.response?.statusCode}');
      print('❌ Response Data: ${e.response?.data}');
      final errorMessage =
          e.response?.data?['message'] ?? e.message ?? 'Unknown error';
      throw ServerException('Get lounges failed: $errorMessage');
    } catch (e) {
      print('❌ Error: $e');
      throw ServerException(e.toString());
    }
  }

  /// Update lounge owner profile
  /// PUT /api/v1/lounge-owner/profile/update
  Future<Map<String, dynamic>> updateProfile({
    String? businessName,
    String? businessLicense,
    String? managerFullName,
    String? managerNicNumber,
    String? managerEmail,
    String? district,
  }) async {
    try {
      print('📤 Sending lounge owner profile update request...');
      if (businessName != null) print('   Business Name: $businessName');
      if (businessLicense != null)
        print('   Business License: $businessLicense');
      if (managerFullName != null) print('   Manager Name: $managerFullName');
      if (managerNicNumber != null) print('   Manager NIC: $managerNicNumber');
      if (managerEmail != null) print('   Manager Email: $managerEmail');
      if (district != null) print('   District: $district');

      final data = <String, dynamic>{};
      if (businessName != null) data['business_name'] = businessName;
      if (businessLicense != null) data['business_license'] = businessLicense;
      if (managerFullName != null) data['manager_full_name'] = managerFullName;
      if (managerNicNumber != null)
        data['manager_nic_number'] = managerNicNumber;
      if (managerEmail != null) data['manager_email'] = managerEmail;
      if (district != null) data['district'] = district;

      final response = await apiClient.put(
        '/api/v1/lounge-owner/profile/update',
        data: data,
      );

      if (response.statusCode != 200) {
        throw ServerException('Failed to update lounge owner profile');
      }

      print('✅ Lounge owner profile updated successfully');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      print('❌ DioException in updateProfile:');
      print('   Status Code: ${e.response?.statusCode}');
      print('   Response Data: ${e.response?.data}');
      final errorMessage =
          e.response?.data?['message'] ?? e.message ?? 'Unknown error';
      throw ServerException('Update profile failed: $errorMessage');
    } catch (e) {
      print('❌ Error: $e');
      throw ServerException(e.toString());
    }
  }
}
