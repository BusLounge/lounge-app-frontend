import 'package:flutter/foundation.dart';

class AppConfig {
  // API Configuration - local backend by default.
  // Override with --dart-define=LOCAL_BACKEND_URL=...
  static String get _defaultBackendUrl {
    if (kIsWeb) {
      return 'http://localhost:8080';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8080';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
        return 'http://localhost:8080';
    }
  }

  static const String _localBackendUrlOverride =
      String.fromEnvironment('LOCAL_BACKEND_URL', defaultValue: '');
  static const String _webSocketUrlOverride =
      String.fromEnvironment('WEBSOCKET_URL', defaultValue: '');
  static const String _webSocketEnabledOverride =
      String.fromEnvironment('WEBSOCKET_ENABLED', defaultValue: 'false');
  static const String _webSocketPath =
      String.fromEnvironment('WEBSOCKET_PATH', defaultValue: '/ws');

  static bool get webSocketEnabled {
    final value = _webSocketEnabledOverride.toLowerCase().trim();
    return value == '1' || value == 'true' || value == 'yes';
  }

  static String get baseUrl => _localBackendUrlOverride.isNotEmpty
      ? _localBackendUrlOverride
      : _defaultBackendUrl;

  static String get webSocketUrl {
    if (_webSocketUrlOverride.isNotEmpty) {
      return _webSocketUrlOverride;
    }

    final base = Uri.parse(baseUrl);
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
    final wsPath =
        _webSocketPath.startsWith('/') ? _webSocketPath : '/$_webSocketPath';

    return base.replace(scheme: wsScheme, path: wsPath).toString();
  }

  static const String apiVersion = 'v1';
  static String get apiBaseUrl => baseUrl; // Already includes /api/v1 structure

  // Endpoints (relative to baseUrl)
  static const String authEndpoint = '/auth';
  static const String loungeOwnerEndpoint = '/lounge-owner';
  static const String loungeEndpoint = '/lounge-owner/lounges';
  static const String registrationEndpoint = '/lounge-owner/register';

  // Supabase Configuration (for file storage)
  static const String supabaseUrl = 'https://pttatcukzpceljcrwehk.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB0dGF0Y3VrenBjZWxqY3J3ZWhrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAzMTU5NzMsImV4cCI6MjA3NTg5MTk3M30.zKQrCEochcFM1M3NtEoDRhi8xJIwhobuEmkAiN09bjg';

  // Supabase Storage Buckets
  static const String nicUploadsBucket =
      'nic_uploads'; // Private bucket for NIC images (max 2MB)
  static const String loungePhotosBucket =
      'lounge_photos'; // Public bucket for lounge images (max 5MB)

  // App Configuration
  static const int ocrMaxAttempts = 4;
  static const Duration ocrBlockDuration = Duration(hours: 24);
  static const int maxLoungePhotos = 5;
  static const int minLoungePhotos = 1;

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
