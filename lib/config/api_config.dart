class ApiConfig {
  // ============================================
  // BACKEND CONFIGURATION
  // ============================================
    // Default to the Choreo backend and allow overrides with
    // --dart-define=BACKEND_BASE_URL=...
  static String get _defaultBackendUrl {
    // Choreo backend
    return 'https://6ed89a53-55ef-45f1-a497-e383bfedea00-dev.e1-us-east-azure.choreoapis.dev/default/backendloungeowner/v1.0';
  }

  static const String _baseUrlOverride =
      String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) {
      return _baseUrlOverride;
    }
    return _defaultBackendUrl;
  }

  // API Endpoints
  static const String sendOtpEndpoint = '/api/v1/auth/send-otp';
  static const String verifyOtpEndpoint =
      '/api/v1/auth/verify-otp'; // For passenger app only
  static const String verifyOtpStaffEndpoint =
      '/api/v1/auth/verify-otp-staff'; // For staff app - NEW
  static const String refreshTokenEndpoint = '/api/v1/auth/refresh';
  static const String profileEndpoint = '/api/v1/user/profile';
  static const String updateProfileEndpoint = '/api/v1/user/profile';
  static const String logoutEndpoint = '/api/v1/auth/logout';
  static const String staffEndpoint = '/api/v1/staff';
  static const String searchTripsEndpoint = '/api/v1/search';
  static const String bookableTripsEndpoint = '/api/v1/bookable-trips';

  // Lounge owner and staff profile endpoints
  static const String loungeOwnerProfileUpdateEndpoint =
      '/api/v1/lounge-owner/profile/update';
  static const String loungeStaffProfileUpdateEndpoint =
      '/api/v1/lounge-staff/profile/update';

  // Helper methods to get the correct base URL.
  static String getAuthBaseUrl() => baseUrl;
  static String getLoungeBaseUrl() => baseUrl;

  // Full URLs - Auth APIs use the selected backend.
  static String get sendOtpUrl => '${getAuthBaseUrl()}$sendOtpEndpoint';
  static String get verifyOtpUrl => '${getAuthBaseUrl()}$verifyOtpEndpoint';
  static String get verifyOtpStaffUrl =>
      '${getAuthBaseUrl()}$verifyOtpStaffEndpoint';
  static String get refreshTokenUrl =>
      '${getAuthBaseUrl()}$refreshTokenEndpoint';
  static String get profileUrl => '${getAuthBaseUrl()}$profileEndpoint';
  static String get updateProfileUrl =>
      '${getAuthBaseUrl()}$updateProfileEndpoint';
  static String get logoutUrl => '${getAuthBaseUrl()}$logoutEndpoint';
  static String get staffUrl => '${getAuthBaseUrl()}$staffEndpoint';

  // Lounge owner and staff profile update URLs
  static String get loungeOwnerProfileUpdateUrl =>
      '${getLoungeBaseUrl()}$loungeOwnerProfileUpdateEndpoint';
  static String get loungeStaffProfileUpdateUrl =>
      '${getLoungeBaseUrl()}$loungeStaffProfileUpdateEndpoint';

  // Lounge-specific APIs use the same backend base URL.
  static String loungeUrl(String loungeId, String path) =>
      '${getLoungeBaseUrl()}/api/v1/lounges/$loungeId$path';
  static String loungeStaffUrl(String loungeId) =>
      '${getLoungeBaseUrl()}/api/v1/lounges/$loungeId/staff';
  static String loungeBookingsUrl(String loungeId) =>
      '${getLoungeBaseUrl()}/api/v1/lounges/$loungeId/bookings';

  // Pagination and image quality optimization defaults
  static const int defaultPageSize = 20;
  static const String defaultImageQuality = 'sd';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 90);
  static const Duration sendTimeout = Duration(seconds: 30);
}
