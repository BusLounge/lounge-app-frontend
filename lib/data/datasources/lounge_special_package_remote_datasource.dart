import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../models/lounge_special_package_model.dart';

/// Remote data source for lounge special packages
abstract class LoungeSpecialPackageRemoteDataSource {
  Future<List<LoungeSpecialPackageModel>> getSpecialPackages(String loungeId);
  Future<LoungeSpecialPackageModel> createSpecialPackage(
    String loungeId,
    Map<String, dynamic> data,
  );
  Future<LoungeSpecialPackageModel> updateSpecialPackage(
    String loungeId,
    String packageId,
    Map<String, dynamic> data,
  );
  Future<void> deleteSpecialPackage(String loungeId, String packageId);
}

/// Implementation of LoungeSpecialPackageRemoteDataSource
class LoungeSpecialPackageRemoteDataSourceImpl
    implements LoungeSpecialPackageRemoteDataSource {
  final ApiClient _apiClient;

  LoungeSpecialPackageRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<List<LoungeSpecialPackageModel>> getSpecialPackages(
      String loungeId) async {
    try {
      AppLogger.info('Fetching special packages for lounge: $loungeId');
      final response = await _apiClient.get(
        '/api/v1/marketplace/special-packages/lounge/$loungeId',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data =
            response.data['special_packages'] ?? response.data['data'] ?? [];
        final packages = data
            .map((json) =>
                LoungeSpecialPackageModel.fromJson(json as Map<String, dynamic>))
            .toList();
        AppLogger.info('Fetched ${packages.length} special packages');
        return packages;
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Failed to fetch special packages',
      );
    } catch (e) {
      AppLogger.error('Error fetching special packages for lounge $loungeId', e);
      rethrow;
    }
  }

  @override
  Future<LoungeSpecialPackageModel> createSpecialPackage(
    String loungeId,
    Map<String, dynamic> data,
  ) async {
    try {
      AppLogger.info('Creating special package for lounge: $loungeId');
      final response = await _apiClient.post(
        '/api/v1/marketplace/special-packages/lounge/$loungeId',
        data: data,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final pkgData =
            response.data['special_package'] ?? response.data['data'] ?? response.data;
        final pkg = LoungeSpecialPackageModel.fromJson(
            pkgData as Map<String, dynamic>);
        AppLogger.info('Created special package: ${pkg.packageName}');
        return pkg;
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Failed to create special package',
      );
    } catch (e) {
      AppLogger.error('Error creating special package', e);
      rethrow;
    }
  }

  @override
  Future<LoungeSpecialPackageModel> updateSpecialPackage(
    String loungeId,
    String packageId,
    Map<String, dynamic> data,
  ) async {
    try {
      AppLogger.info('Updating special package: $packageId');
      final response = await _apiClient.put(
        '/api/v1/marketplace/special-packages/$packageId',
        data: data,
      );

      if (response.statusCode == 200) {
        final pkgData =
            response.data['special_package'] ?? response.data['data'] ?? response.data;
        final pkg = LoungeSpecialPackageModel.fromJson(
            pkgData as Map<String, dynamic>);
        AppLogger.info('Updated special package: ${pkg.packageName}');
        return pkg;
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Failed to update special package',
      );
    } catch (e) {
      AppLogger.error('Error updating special package $packageId', e);
      rethrow;
    }
  }

  @override
  Future<void> deleteSpecialPackage(String loungeId, String packageId) async {
    try {
      AppLogger.info('Deleting special package: $packageId');
      final response = await _apiClient.delete(
        '/api/v1/marketplace/special-packages/$packageId',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        AppLogger.info('Deleted special package: $packageId');
        return;
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'Failed to delete special package',
      );
    } catch (e) {
      AppLogger.error('Error deleting special package $packageId', e);
      rethrow;
    }
  }
}
