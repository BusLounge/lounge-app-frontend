import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../utils/logger.dart';

/// Custom cache manager for lounge application with optimized settings
class LoungeImageCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'LoungeLoungeCacheKey';

  static final LoungeImageCacheManager _instance = LoungeImageCacheManager._();

  factory LoungeImageCacheManager() {
    return _instance;
  }

  LoungeImageCacheManager._()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 30),
            maxNrOfCacheObjects: 500,
          ),
        );
}

/// Enhanced Image Caching Service with network awareness and batch caching
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._();

  factory ImageCacheService() => _instance;

  ImageCacheService._() {
    _initializeNetworkMonitoring();
  }

  final CacheManager _cacheManager = LoungeImageCacheManager();
  bool _isOnSlowNetwork = false;
  
  // Track caching operations to avoid duplicates
  final Map<String, Future<void>> _preCachingTasks = {};

  /// Initialize network monitoring
  void _initializeNetworkMonitoring() {
    Connectivity().onConnectivityChanged.listen((result) {
      // result is List<ConnectivityResult>
      _isOnSlowNetwork = result.contains(ConnectivityResult.mobile);
      AppLogger.info('Network changed: Mobile=$_isOnSlowNetwork');
    });
  }

  /// Get appropriate quality based on network
  String getQualityForNetwork() {
    return _isOnSlowNetwork ? 'sd' : 'hd';
  }

  /// Get cached or download image
  Future<String> getOrDownloadImage(
    String imageUrl, {
    String quality = 'sd',
  }) async {
    try {
      final optimizedUrl = _optimizeImageUrl(imageUrl, quality);
      final file = await _cacheManager.getSingleFile(optimizedUrl);
      AppLogger.info('Loaded cached image: $optimizedUrl');
      return file.path;
    } catch (e) {
      AppLogger.error('Failed to cache image: $e');
      return imageUrl;
    }
  }

  /// Clear image cache
  Future<void> clearCache() async {
    try {
      await _cacheManager.emptyCache();
      _preCachingTasks.clear();
      AppLogger.info('Image cache cleared');
    } catch (e) {
      AppLogger.error('Failed to clear cache: $e');
    }
  }

  /// Smart pre-cache images with batching and deduplication
  /// Batches requests to avoid overwhelming the network
  Future<void> preCacheImages(
    List<String> imageUrls, {
    String quality = 'sd',
    int batchSize = 3, // Download 3 images concurrently
  }) async {
    if (imageUrls.isEmpty) {
      return;
    }

    final taskKey = imageUrls.join(',');
    
    // Avoid duplicate caching operations
    if (_preCachingTasks.containsKey(taskKey)) {
      AppLogger.info('Pre-cache task already in progress for these images');
      return;
    }

    final task = _batchPreCacheImages(imageUrls, quality, batchSize);
    _preCachingTasks[taskKey] = task;
    
    try {
      await task;
      AppLogger.info('Pre-cached ${imageUrls.length} images at $quality quality');
    } catch (e) {
      AppLogger.error('Pre-cache failed: $e');
    } finally {
      _preCachingTasks.remove(taskKey);
    }
  }

  /// Batch pre-caching with concurrent downloads
  Future<void> _batchPreCacheImages(
    List<String> imageUrls,
    String quality,
    int batchSize,
  ) async {
    for (int i = 0; i < imageUrls.length; i += batchSize) {
      final batch = imageUrls.sublist(
        i,
        i + batchSize > imageUrls.length ? imageUrls.length : i + batchSize,
      );
      
      final futures = batch.map((url) async {
        try {
          final optimizedUrl = _optimizeImageUrl(url, quality);
          await _cacheManager.downloadFile(optimizedUrl);
        } catch (e) {
          AppLogger.error('Failed to pre-cache image $url: $e');
        }
      });

      // Wait for batch to complete before starting next batch
      await Future.wait(futures);
    }
  }

  /// Optimize image URL for different qualities
  String _optimizeImageUrl(String url, String quality) {
    if (!url.contains('cloudinary')) {
      return url;
    }

    // Skip if already has transformation params
    if (url.contains('/c_') || url.contains('/q_') || url.contains('/f_auto')) {
      return url;
    }

    final transformation = _getTransformation(quality);
    final uploadIdx = url.indexOf('/upload/');

    if (uploadIdx == -1) {
      return url;
    }

    final insertPos = uploadIdx + '/upload/'.length;
    return url.substring(0, insertPos) + transformation + url.substring(insertPos);
  }

  /// Get transformation string based on quality
  /// Includes: f_auto (auto format), fl_progressive (progressive encoding), w_limit (width limit)
  String _getTransformation(String quality) {
    switch (quality) {
      case 'sd':
        // Standard Definition: 480px max, 70% quality, auto format, progressive
        return 'c_limit,h_480,w_480,q_70,f_auto,fl_progressive/';
      case 'hd':
        // High Definition: 720px max, 80% quality, auto format with progressive
        return 'c_limit,h_720,w_720,q_80,f_auto,fl_progressive/';
      case 'full':
        // Full quality: auto format with progressive encoding only
        return 'f_auto,q_90,fl_progressive/';
      default:
        // Default to SD
        return 'c_limit,h_480,w_480,q_70,f_auto,fl_progressive/';
    }
  }

  /// Get cache info
  Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      // This is a placeholder - actual implementation depends on cache_manager version
      return {'cached_images': 0, 'size_bytes': 0};
    } catch (e) {
      AppLogger.error('Failed to get cache info: $e');
      return {};
    }
  }
}

/// Widget for displaying cached images with adaptive quality loading
class OptimizedCachedImage extends StatefulWidget {
  final String imageUrl;
  final String? quality;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, String, Object)? errorWidget;
  final Widget Function(BuildContext, String)? loadingWidget;
  final bool adaptiveQuality; // Automatically adjust quality based on network

  const OptimizedCachedImage({
    Key? key,
    required this.imageUrl,
    this.quality,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorWidget,
    this.loadingWidget,
    this.adaptiveQuality = true,
  }) : super(key: key);

  @override
  State<OptimizedCachedImage> createState() => _OptimizedCachedImageState();
}

class _OptimizedCachedImageState extends State<OptimizedCachedImage> {
  late String _effectiveQuality;
  final ImageCacheService _cacheService = ImageCacheService();

  @override
  void initState() {
    super.initState();
    _updateQuality();
  }

  void _updateQuality() {
    if (widget.adaptiveQuality) {
      _effectiveQuality = _cacheService.getQualityForNetwork();
    } else {
      _effectiveQuality = widget.quality ?? 'sd';
    }
  }

  @override
  Widget build(BuildContext context) {
    _updateQuality();

    return CachedNetworkImage(
      imageUrl: _optimizeUrl(widget.imageUrl, _effectiveQuality),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: (context, url) =>
          widget.loadingWidget?.call(context, url) ??
          Container(
            color: Colors.grey[300],
            child: const Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      errorWidget: (context, url, error) =>
          widget.errorWidget?.call(context, url, error) ??
          Container(
            color: Colors.grey[300],
            child: const Icon(Icons.image_not_supported),
          ),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
    );
  }

  String _optimizeUrl(String url, String quality) {
    if (!url.contains('cloudinary')) {
      return url;
    }
    if (url.contains('/c_') || url.contains('/q_') || url.contains('/f_auto')) {
      return url;
    }

    final transformation = _getTransformation(quality);
    final uploadIdx = url.indexOf('/upload/');
    if (uploadIdx == -1) {
      return url;
    }

    final insertPos = uploadIdx + '/upload/'.length;
    return url.substring(0, insertPos) + transformation + url.substring(insertPos);
  }

  String _getTransformation(String quality) {
    switch (quality) {
      case 'sd':
        return 'c_limit,h_480,w_480,q_70,f_auto,fl_progressive/';
      case 'hd':
        return 'c_limit,h_720,w_720,q_80,f_auto,fl_progressive/';
      case 'full':
        return 'f_auto,q_90,fl_progressive/';
      default:
        return 'c_limit,h_480,w_480,q_70,f_auto,fl_progressive/';
    }
  }
}
