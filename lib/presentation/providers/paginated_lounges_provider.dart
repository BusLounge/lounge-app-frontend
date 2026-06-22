import 'package:flutter/foundation.dart';
import '../../config/api_config.dart';
import '../../core/utils/logger.dart';
import '../../core/services/image_cache_service.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../domain/entities/lounge.dart';
import 'dart:async';

/// Provider for paginated lounge listing with optimization
class PaginatedLoungesProvider extends ChangeNotifier {
  final MarketplaceRepository _repository;

  // Pagination state
  List<Lounge> _lounges = [];
  List<Lounge> get lounges => _lounges;

  int _currentOffset = 0;
  int _totalCount = 0;
  int _pageSize = ApiConfig.defaultPageSize;

  bool _isLoading = false;
  bool _hasMore = true;

  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  int get currentCount => _lounges.length;
  int get totalCount => _totalCount;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Image quality preference
  String _imageQuality = ApiConfig.defaultImageQuality;
  String get imageQuality => _imageQuality;

  // Filter params
  String? _filterState;
  String? _filterRoute;
  String? _filterStop;

  PaginatedLoungesProvider({required MarketplaceRepository repository})
      : _repository = repository;

  /// Load initial page of lounges
  Future<void> loadInitial({
    String? state,
    String? routeId,
    String? stopId,
    int pageSize = ApiConfig.defaultPageSize,
    String imageQuality = ApiConfig.defaultImageQuality,
  }) async {
    _lounges.clear();
    _currentOffset = 0;
    _pageSize = pageSize;
    _imageQuality = imageQuality;
    _filterState = state;
    _filterRoute = routeId;
    _filterStop = stopId;

    await loadNextPage();
  }

  /// Load next page of lounges
  Future<void> loadNextPage() async {
    if (_isLoading || !_hasMore) {
      AppLogger.warning('Cannot load next page: loading=$_isLoading, hasMore=$_hasMore');
      return;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Build appropriate URL based on filters
      late List<Lounge> pageLounge;
      late int total;

      if (_filterStop != null) {
        // Load lounges by stop
        AppLogger.info('Loading lounges by stop: $_filterStop, offset: $_currentOffset');
        // Need to implement paginated method in repository
        pageLounge = []; // Placeholder
        total = 0;
      } else if (_filterRoute != null) {
        // Load lounges by route
        AppLogger.info('Loading lounges by route: $_filterRoute, offset: $_currentOffset');
        pageLounge = [];
        total = 0;
      } else {
        // Load all active lounges
        AppLogger.info('Loading active lounges, offset: $_currentOffset');
        pageLounge = [];
        total = 0;
      }

      _lounges.addAll(pageLounge);
      _totalCount = total;
      _currentOffset += _pageSize;
      _hasMore = _currentOffset < total;

      // Pre-cache images for newly loaded lounges (in background)
      _preCacheLoungImages(pageLounge);

      AppLogger.info('Loaded ${pageLounge.length} lounges. Total: $total, HasMore: $_hasMore');
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error loading lounges page', e);
      _errorMessage = 'Failed to load lounges: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Pre-cache lounge images in background (non-blocking)
  Future<void> _preCacheLoungImages(List<Lounge> loungesToCache) async {
    try {
      final imageUrls = <String>{};
      for (final lounge in loungesToCache) {
        if (lounge.images != null) {
          imageUrls.addAll(lounge.images!);
        }
      }

      if (imageUrls.isNotEmpty) {
        // Call pre-cache without awaiting to avoid blocking UI
        ImageCacheService().preCacheImages(
          imageUrls.toList(),
          quality: _imageQuality,
          batchSize: 3,
        ).catchError((e) {
          AppLogger.warning('Background image pre-caching failed: $e');
        });
      }
    } catch (e) {
      AppLogger.warning('Failed to setup pre-caching: $e');
    }
  }

  /// Refresh the list from beginning
  Future<void> refresh() async {
    AppLogger.info('Refreshing lounge list');
    _lounges.clear();
    _currentOffset = 0;
    _hasMore = true;
    await loadNextPage();
  }

  /// Clear everything
  void clear() {
    _lounges.clear();
    _currentOffset = 0;
    _totalCount = 0;
    _hasMore = true;
    _errorMessage = null;
    notifyListeners();
  }

  /// Set image quality and pre-cache images at new quality
  void setImageQuality(String quality) {
    if (quality == _imageQuality) return;
    _imageQuality = quality;
    AppLogger.info('Image quality changed to: $quality');
    
    // Pre-cache all current images at new quality
    _preCacheLoungImages(_lounges).ignore();
    notifyListeners();
  }
}
