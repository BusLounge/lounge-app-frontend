class AppConfig {
  // API Configuration - Choreo backend by default.
  // Override with --dart-define=LOCAL_BACKEND_URL=...
  static const String _defaultBackendUrl =
      'https://6ed89a53-55ef-45f1-a497-e383bfedea00-dev.e1-us-east-azure.choreoapis.dev/default/backendloungeowner/v1.0';

  static const String baseUrl = String.fromEnvironment(
    'LOCAL_BACKEND_URL',
    defaultValue: _defaultBackendUrl,
  );
  static const String apiVersion = 'v1';
  static const String apiBaseUrl =
      baseUrl; // Already includes /api/v1 structure

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
