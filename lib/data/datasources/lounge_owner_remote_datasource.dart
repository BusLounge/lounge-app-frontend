import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/error/exceptions.dart';

/// Remote data source for lounge owner registration operations
/// Makes HTTP requests to backend API
class LoungeOwnerRemoteDataSource {
  final ApiClient apiClient;

  static const Duration _cacheTtl = Duration(minutes: 5);

  static Map<String, List<Map<String, dynamic>>>? _cachedOwnersByDistrict;
  static DateTime? _cachedOwnersByDistrictAt;
  static Future<Map<String, List<Map<String, dynamic>>>>?
      _ownersByDistrictInFlight;

  static final Map<String, List<Map<String, dynamic>>> _ownerLoungesCache = {};
  static final Map<String, DateTime> _ownerLoungesCacheAt = {};
  static final Map<String, Future<List<Map<String, dynamic>>>>
      _ownerLoungesInFlight = {};

  LoungeOwnerRemoteDataSource({required this.apiClient});

  bool _isFresh(DateTime? cachedAt) {
    if (cachedAt == null) return false;
    return DateTime.now().difference(cachedAt) < _cacheTtl;
  }

  /// Get all districts for dropdown/lookup use cases
  /// GET /api/v1/districts
  Future<List<Map<String, dynamic>>> getAllDistricts() async {
    try {
      final response = await apiClient.getPublic('/api/v1/districts');

      if (response.statusCode != 200) {
        throw ServerException('Failed to load districts');
      }

      final rawData = response.data;
      if (rawData is! Map<String, dynamic>) {
        throw ServerException('Invalid districts response format');
      }

      final districts = rawData['districts'];
      if (districts is! List) {
        return [];
      }

      return districts
          .whereType<Map<String, dynamic>>()
          .map((district) {
            return {
              'id': district['id']?.toString() ?? '',
              'district': district['district']?.toString() ?? '',
            };
          })
          .where((district) => (district['district'] as String).isNotEmpty)
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Get district by ID
  /// GET /api/v1/districts/{id}
  Future<Map<String, dynamic>> getDistrictById(String id) async {
    try {
      final response = await apiClient.getPublic('/api/v1/districts/$id');

      if (response.statusCode != 200) {
        throw ServerException('Failed to load district');
      }

      final rawData = response.data;
      if (rawData is! Map<String, dynamic>) {
        throw ServerException('Invalid district response format');
      }

      final district = rawData['district'];
      if (district is Map<String, dynamic>) {
        return {
          'id': district['id']?.toString() ?? '',
          'district': district['district']?.toString() ?? '',
        };
      }

      return {
        'id': '',
        'district': '',
      };
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Save business and manager information (Step 1)
  /// POST /api/v1/lounge-owner/register/business-info
  Future<void> saveBusinessInfo({
    required String ownerId,
    required String businessName,
    required String businessLicense,
    required String managerFullName,
    required String managerNicNumber,
    required String managerEmail,
    required String districtId,
  }) async {
    try {
      print('📤 Sending business info request...');
      print('   Business Name: $businessName');
      print('   Business License: $businessLicense');
      print('   Manager Name: $managerFullName');
      print('   Manager NIC: $managerNicNumber');
      print('   Manager Email: $managerEmail');
      print('   District ID: $districtId');

      final payload = <String, dynamic>{
        'business_name': businessName,
        'manager_full_name': managerFullName,
        'manager_nic_number': managerNicNumber,
        'district_id': districtId,
      };

      if (businessLicense.trim().isNotEmpty) {
        payload['business_license'] = businessLicense.trim();
      }

      if (managerEmail.trim().isNotEmpty) {
        payload['manager_email'] = managerEmail.trim();
      }

      payload['district'] = districtId;

      print('📤 Business info payload: $payload');

      final response = await apiClient.post(
        '/api/v1/lounge-owner/register/business-info',
        data: payload,
      );

      print('✅ Business info saved successfully');
      if (response.statusCode != 200) {
        throw ServerException('Failed to save business and manager info');
      }

      await _saveOwnerDistrictMapping(
        ownerId: ownerId,
        districtId: districtId,
        ownerName: managerFullName,
        businessName: businessName,
      );
    } on ServerException {
      rethrow;
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

  Future<void> _saveOwnerDistrictMapping({
    required String ownerId,
    required String districtId,
    required String ownerName,
    required String businessName,
  }) async {
    final ownerIds = await _resolveOwnerIdsForMapping(ownerId);
    ServerException? lastError;

    for (final candidateOwnerId in ownerIds) {
      try {
        final alreadyStored = await _isOwnerDistrictMappingStored(
          ownerId: candidateOwnerId,
          districtId: districtId,
        );

        if (alreadyStored) {
          return;
        }

        final response = await apiClient.post(
          '/api/v1/lounge-owner-districts',
          data: {
            'owner_id': candidateOwnerId,
            'district_id': districtId,
            'owner_name': ownerName,
            'business_name': businessName,
          },
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          return;
        }

        lastError = const ServerException(
          'Failed to create lounge owner district mapping',
        );
      } on DioException catch (e) {
        final alreadyStored = await _isOwnerDistrictMappingStored(
          ownerId: candidateOwnerId,
          districtId: districtId,
        );
        if (alreadyStored) {
          return;
        }

        String errorMessage =
            'Failed to create lounge owner district mapping';
        final data = e.response?.data;

        if (data is Map<String, dynamic>) {
          errorMessage =
              (data['error'] ?? data['message'] ?? errorMessage).toString();
        }

        lastError = ServerException(errorMessage);
      } catch (e) {
        lastError = ServerException(e.toString());
      }
    }

    if (lastError != null) {
      throw lastError;
    }

    throw const ServerException('Failed to create lounge owner district mapping');
  }

  Future<List<String>> _resolveOwnerIdsForMapping(String primaryOwnerId) async {
    final ids = <String>{primaryOwnerId};

    try {
      final response = await apiClient.get('/api/v1/lounge-owner/profile');
      final rawData = response.data;
      if (rawData is Map<String, dynamic>) {
        final profile = _extractProfilePayload(rawData);
        final profileOwnerId = profile['id']?.toString().trim();
        final profileUserId = profile['user_id']?.toString().trim();

        if (profileOwnerId != null && profileOwnerId.isNotEmpty) {
          ids.add(profileOwnerId);
        }
        if (profileUserId != null && profileUserId.isNotEmpty) {
          ids.add(profileUserId);
        }
      }
    } catch (_) {
      // Ignore profile resolution errors and continue with primary ownerId.
    }

    return ids.toList(growable: false);
  }

  Future<bool> _isOwnerDistrictMappingStored({
    required String ownerId,
    required String districtId,
  }) async {
    try {
      final response = await apiClient.post(
        '/api/v1/lounge-owner-districts/check-exists',
        data: {
          'owner_id': ownerId,
          'district_id': districtId,
        },
      );

      if (response.statusCode != 200) {
        return false;
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data['already_stored'] == true;
      }

      return false;
    } catch (_) {
      return false;
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
    if (_cachedOwnersByDistrict != null &&
        _isFresh(_cachedOwnersByDistrictAt)) {
      print('⚡ Using cached lounge owners by district');
      return _cachedOwnersByDistrict!;
    }

    if (_ownersByDistrictInFlight != null) {
      print('⏳ Awaiting in-flight district owners request');
      return _ownersByDistrictInFlight!;
    }

    final future = _fetchApprovedLoungeOwnersGroupedByDistrict();
    _ownersByDistrictInFlight = future;

    try {
      final data = await future;
      _cachedOwnersByDistrict = data;
      _cachedOwnersByDistrictAt = DateTime.now();
      return data;
    } finally {
      _ownersByDistrictInFlight = null;
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>>
      _fetchApprovedLoungeOwnersGroupedByDistrict() async {
    try {
      print('📍 Fetching approved lounge owners grouped by district...');
      final response = await apiClient.getPublic(
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
      final bool isNetworkIssue = e.response == null;
      final dynamic responseData = e.response?.data;
      String errorMessage;

      if (isNetworkIssue) {
        errorMessage =
            'Network timeout. Please check backend server and internet connection.';
      } else if (responseData is Map<String, dynamic>) {
        errorMessage = (responseData['message'] ??
                responseData['error'] ??
                e.message ??
                'Unknown error')
            .toString();
      } else {
        errorMessage = e.message ?? 'Unknown error';
      }

      throw ServerException('Get lounge owners failed: $errorMessage');
    } catch (e) {
      print('❌ Error: $e');
      throw ServerException(e.toString());
    }
  }

  /// Get approved lounge owners by district UUID
  /// GET /api/v1/lounge-owner/approved/by-district/{district_id}
  Future<List<Map<String, dynamic>>> getApprovedLoungeOwnersByDistrictId(
    String districtId,
  ) async {
    try {
      final response = await apiClient.getPublic(
        '/api/v1/lounge-owner/approved/by-district/$districtId',
      );

      if (response.statusCode != 200) {
        throw ServerException('Failed to get lounge owners for district');
      }

      final rawData = response.data;
      if (rawData is! Map<String, dynamic>) {
        return [];
      }

      final owners = rawData['lounge_owners'] ??
          (rawData['data'] is Map<String, dynamic>
              ? (rawData['data'] as Map<String, dynamic>)['lounge_owners']
              : null) ??
          rawData['owners'];
      if (owners is! List) {
        return [];
      }

      return owners.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (e) {
      final bool isNetworkIssue = e.response == null;
      final dynamic responseData = e.response?.data;
      String errorMessage;

      if (isNetworkIssue) {
        errorMessage =
            'Network timeout. Please check backend server and internet connection.';
      } else if (responseData is Map<String, dynamic>) {
        errorMessage = (responseData['message'] ??
                responseData['error'] ??
                e.message ??
                'Unknown error')
            .toString();
      } else {
        errorMessage = e.message ?? 'Unknown error';
      }

      throw ServerException('Get lounge owners failed: $errorMessage');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Get lounges owned by a specific lounge owner
  /// GET /api/v1/lounge-owner/:owner_id/lounges
  Future<List<Map<String, dynamic>>> getLoungesByOwnerId(String ownerId) async {
    final cachedLounges = _ownerLoungesCache[ownerId];
    final cachedAt = _ownerLoungesCacheAt[ownerId];
    if (cachedLounges != null && _isFresh(cachedAt)) {
      print('⚡ Using cached lounges for owner: $ownerId');
      return cachedLounges;
    }

    final inFlight = _ownerLoungesInFlight[ownerId];
    if (inFlight != null) {
      print('⏳ Awaiting in-flight lounges request for owner: $ownerId');
      return inFlight;
    }

    final future = _fetchLoungesByOwnerId(ownerId);
    _ownerLoungesInFlight[ownerId] = future;

    try {
      final lounges = await future;
      _ownerLoungesCache[ownerId] = lounges;
      _ownerLoungesCacheAt[ownerId] = DateTime.now();
      return lounges;
    } finally {
      _ownerLoungesInFlight.remove(ownerId);
    }
  }

  /// Get lounges by owner ID and district ID
  /// GET /api/v1/lounge-owner/{owner_id}/lounges/by-district/{district_id}
  Future<List<Map<String, dynamic>>> getLoungesByOwnerAndDistrictId({
    required String ownerId,
    required String districtId,
  }) async {
    try {
      final response = await apiClient.getPublic(
        '/api/v1/lounge-owner/$ownerId/lounges/by-district/$districtId',
      );

      if (response.statusCode != 200) {
        throw ServerException('Failed to get lounges for owner and district');
      }

      final rawData = response.data;
      if (rawData is List) {
        return rawData.whereType<Map<String, dynamic>>().toList();
      }

      if (rawData is! Map<String, dynamic>) {
        return [];
      }

      final lounges = rawData['lounges'] ??
          (rawData['data'] is Map<String, dynamic>
              ? (rawData['data'] as Map<String, dynamic>)['lounges']
              : null) ??
          rawData['results'];

      if (lounges is! List) {
        return [];
      }

      return lounges.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (e) {
      final bool isNetworkIssue = e.response == null;
      final dynamic responseData = e.response?.data;
      String errorMessage;

      if (isNetworkIssue) {
        errorMessage =
            'Network timeout. Please check backend server and internet connection.';
      } else if (responseData is Map<String, dynamic>) {
        errorMessage = (responseData['message'] ??
                responseData['error'] ??
                e.message ??
                'Unknown error')
            .toString();
      } else {
        errorMessage = e.message ?? 'Unknown error';
      }

      throw ServerException('Get lounges failed: $errorMessage');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<List<Map<String, dynamic>>> _fetchLoungesByOwnerId(
      String ownerId) async {
    try {
      print('📍 Fetching lounges for owner: $ownerId');
      final response = await apiClient.getPublic(
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
      final bool isNetworkIssue = e.response == null;
      final dynamic responseData = e.response?.data;
      String errorMessage;

      if (isNetworkIssue) {
        errorMessage =
            'Network timeout. Please check backend server and internet connection.';
      } else if (responseData is Map<String, dynamic>) {
        errorMessage = (responseData['message'] ??
                responseData['error'] ??
                e.message ??
                'Unknown error')
            .toString();
      } else {
        errorMessage = e.message ?? 'Unknown error';
      }

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
    String? districtId,
  }) async {
    try {
      print('📤 Sending lounge owner profile update request...');
      if (businessName != null) print('   Business Name: $businessName');
      if (businessLicense != null)
        print('   Business License: $businessLicense');
      if (managerFullName != null) print('   Manager Name: $managerFullName');
      if (managerNicNumber != null) print('   Manager NIC: $managerNicNumber');
      if (managerEmail != null) print('   Manager Email: $managerEmail');
      if (districtId != null) print('   District ID: $districtId');

      final data = <String, dynamic>{};
      if (businessName != null) data['business_name'] = businessName;
      if (businessLicense != null) {
        data['business_registration_number'] = businessLicense;
      }
      if (managerFullName != null) data['manager_full_name'] = managerFullName;
      if (managerNicNumber != null)
        data['manager_nic_number'] = managerNicNumber;
      if (managerEmail != null) data['manager_email'] = managerEmail;
      if (districtId != null) {
        data['district'] = districtId;
        data['district_id'] = districtId;
      }

      print('📤 Profile update payload: $data');

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
