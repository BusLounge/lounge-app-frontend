import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Data sources
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/datasources/auth_local_datasource.dart';
import '../../data/datasources/staff_remote_datasource.dart';
import '../../data/datasources/lounge_owner_remote_datasource.dart';
import '../../data/datasources/lounge_remote_datasource.dart';
import '../../data/datasources/marketplace_remote_datasource.dart';
import '../../data/datasources/supabase_storage_service.dart';
import '../../data/datasources/lounge_staff_remote_datasource.dart';
import '../../data/datasources/lounge_booking_remote_datasource.dart';
import '../../data/datasources/transport_location_remote_datasource.dart';
import '../../data/datasources/driver_remote_datasource.dart';

// Repositories
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/staff_repository_impl.dart';
import '../../data/repositories/lounge_owner_repository_impl.dart';
import '../../data/repositories/lounge_repository_impl.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/staff_repository.dart';
import '../../domain/repositories/lounge_owner_repository.dart';
import '../../domain/repositories/lounge_repository.dart';

// Use cases - Auth
import '../../domain/usecases/send_otp.dart';
import '../../domain/usecases/verify_otp.dart';
import '../../domain/usecases/logout.dart';
import '../../domain/usecases/register_staff.dart';
import '../../domain/usecases/get_staff_profile.dart';

// Use cases - Lounge Owner
import '../../domain/usecases/save_business_info.dart';
import '../../domain/usecases/upload_nic_images.dart';
import '../../domain/usecases/get_registration_progress.dart';
import '../../domain/usecases/check_ocr_block.dart';
import '../../domain/usecases/get_profile.dart';

// Use cases - Lounge
import '../../domain/usecases/add_lounge.dart';
import '../../domain/usecases/get_my_lounges.dart';
import '../../domain/usecases/get_all_lounges.dart';

// Providers
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/staff_provider.dart';
import '../../presentation/providers/lounge_owner_provider.dart';
import '../../presentation/providers/registration_provider.dart';
import '../../presentation/providers/marketplace_provider.dart';
import '../../presentation/providers/role_selection_provider.dart';
import '../../presentation/providers/lounge_staff_provider.dart';
import '../../presentation/providers/lounge_booking_provider.dart';
import '../../presentation/providers/transport_location_provider.dart';
import '../../presentation/providers/driver_provider.dart';

// Config
import '../../config/api_config.dart';
import '../config/app_config.dart';

// Utils
import '../utils/device_info_helper.dart';
import '../network/api_client.dart';

/// Dependency Injection Container
/// Singleton pattern for managing app dependencies
class InjectionContainer {
  static final InjectionContainer _instance = InjectionContainer._internal();
  factory InjectionContainer() => _instance;
  InjectionContainer._internal();

  // Dependencies
  late Dio _dio;
  late FlutterSecureStorage _secureStorage;
  late SharedPreferences _sharedPreferences;
  late DeviceInfoHelper _deviceInfoHelper;
  late ApiClient _apiClient;
  late SupabaseClient _supabaseClient;

  // Data sources
  late AuthRemoteDataSource _authRemoteDataSource;
  late AuthLocalDataSource _authLocalDataSource;
  late StaffRemoteDataSource _staffRemoteDataSource;
  late LoungeOwnerRemoteDataSource _loungeOwnerRemoteDataSource;
  late LoungeRemoteDataSource _loungeRemoteDataSource;
  late MarketplaceRemoteDataSource _marketplaceRemoteDataSource;
  late SupabaseStorageService _supabaseStorageService;
  late LoungeStaffRemoteDataSource _loungeStaffRemoteDataSource;
  late LoungeBookingRemoteDataSource _loungeBookingRemoteDataSource;
  late TransportLocationRemoteDataSource _transportLocationRemoteDataSource;
  late DriverRemoteDataSource _driverRemoteDataSource;

  // Repositories
  late AuthRepository _authRepository;
  late StaffRepository _staffRepository;
  late LoungeOwnerRepository _loungeOwnerRepository;
  late LoungeRepository _loungeRepository;
  late MarketplaceRepository _marketplaceRepository;

  // Use cases - Auth
  late SendOtpUseCase _sendOtpUseCase;
  late VerifyOtpUseCase _verifyOtpUseCase;
  late LogoutUseCase _logoutUseCase;
  late RegisterStaffUseCase _registerStaffUseCase;
  late GetStaffProfileUseCase _getStaffProfileUseCase;

  // Use cases - Lounge Owner
  late SaveBusinessInfo _saveBusinessInfoUseCase;
  late UploadNICImages _uploadNICImagesUseCase;
  late GetRegistrationProgress _getRegistrationProgressUseCase;
  late CheckOCRBlock _checkOCRBlockUseCase;
  late GetProfile _getProfileUseCase;

  // Use cases - Lounge
  late AddLounge _addLoungeUseCase;
  late GetMyLounges _getMyLoungesUseCase;
  late GetAllLounges _getAllLoungesUseCase;

  // Providers
  late AuthProvider _authProvider;
  late StaffProvider _staffProvider;
  late LoungeOwnerProvider _loungeOwnerProvider;
  late RegistrationProvider _registrationProvider;
  late MarketplaceProvider _marketplaceProvider;
  late RoleSelectionProvider _roleSelectionProvider;
  late LoungeStaffProvider _loungeStaffProvider;
  late LoungeBookingProvider _loungeBookingProvider;
  late TransportLocationProvider _transportLocationProvider;
  late DriverProvider _driverProvider;

  /// Initialize all dependencies
  Future<void> init() async {
    // ========== Core ==========
    // IMPORTANT: Initialize storage BEFORE Dio (interceptor needs it)
    _secureStorage = const FlutterSecureStorage();
    _sharedPreferences = await SharedPreferences.getInstance();

    // Initialize device info helper
    _deviceInfoHelper = DeviceInfoHelper();
    await _deviceInfoHelper.initialize();

    // Initialize Supabase
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    _supabaseClient = Supabase.instance.client;

    // Create local datasource first (needed by Dio interceptor and ApiClient)
    _authLocalDataSource = AuthLocalDataSourceImpl(
      secureStorage: _secureStorage,
    );

    // Now create Dio (can access _authLocalDataSource in interceptor)
    _dio = _createDio();

    // ========== Data Sources ==========
    _authRemoteDataSource = AuthRemoteDataSourceImpl(
      dio: _dio,
      baseUrl: ApiConfig.baseUrl,
    );

    _staffRemoteDataSource = StaffRemoteDataSourceImpl(
      dio: _dio,
      baseUrl: ApiConfig.baseUrl,
    );

    // Create ApiClient
    _apiClient = ApiClient(_authLocalDataSource);

    _loungeOwnerRemoteDataSource = LoungeOwnerRemoteDataSource(
      apiClient: _apiClient,
    );

    _loungeRemoteDataSource = LoungeRemoteDataSource(apiClient: _apiClient);

    _marketplaceRemoteDataSource = MarketplaceRemoteDataSourceImpl(
      apiClient: _apiClient,
    );

    _supabaseStorageService = SupabaseStorageService(
      supabaseClient: _supabaseClient,
    );

    _loungeStaffRemoteDataSource = LoungeStaffRemoteDataSourceImpl(
      apiClient: _apiClient,
    );

    _loungeBookingRemoteDataSource = LoungeBookingRemoteDataSourceImpl(
      apiClient: _apiClient,
    );

    _transportLocationRemoteDataSource =
        TransportLocationRemoteDataSourceImpl();

    _driverRemoteDataSource = DriverRemoteDataSourceImpl();

    // ========== Repositories ==========
    _authRepository = AuthRepositoryImpl(
      remoteDataSource: _authRemoteDataSource,
      localDataSource: _authLocalDataSource,
      apiClient: _apiClient,
    );

    _staffRepository = StaffRepositoryImpl(
      remoteDataSource: _staffRemoteDataSource,
    );

    _loungeOwnerRepository = LoungeOwnerRepositoryImpl(
      remoteDataSource: _loungeOwnerRemoteDataSource,
    );

    _loungeRepository = LoungeRepositoryImpl(
      remoteDataSource: _loungeRemoteDataSource,
    );

    _marketplaceRepository = MarketplaceRepositoryImpl(
      remoteDataSource: _marketplaceRemoteDataSource,
    );

    // ========== Use Cases - Auth ==========
    _sendOtpUseCase = SendOtpUseCase(_authRepository);
    _verifyOtpUseCase = VerifyOtpUseCase(_authRepository);
    _logoutUseCase = LogoutUseCase(_authRepository);
    _registerStaffUseCase = RegisterStaffUseCase(_staffRepository);
    _getStaffProfileUseCase = GetStaffProfileUseCase(_staffRepository);

    // ========== Use Cases - Lounge Owner ==========
    _saveBusinessInfoUseCase = SaveBusinessInfo(_loungeOwnerRepository);
    _uploadNICImagesUseCase = UploadNICImages(_loungeOwnerRepository);
    _getRegistrationProgressUseCase = GetRegistrationProgress(
      _loungeOwnerRepository,
    );
    _checkOCRBlockUseCase = CheckOCRBlock(_loungeOwnerRepository);
    _getProfileUseCase = GetProfile(_loungeOwnerRepository);

    // ========== Use Cases - Lounge ==========
    _addLoungeUseCase = AddLounge(_loungeRepository);
    _getMyLoungesUseCase = GetMyLounges(_loungeRepository);
    _getAllLoungesUseCase = GetAllLounges(_loungeRepository);

    // ========== Providers (ViewModels) ==========
    _authProvider = AuthProvider(
      sendOtpUseCase: _sendOtpUseCase,
      verifyOtpUseCase: _verifyOtpUseCase,
      logoutUseCase: _logoutUseCase,
      authRepository: _authRepository,
    );

    _staffProvider = StaffProvider(
      registerStaffUseCase: _registerStaffUseCase,
      getStaffProfileUseCase: _getStaffProfileUseCase,
    );

    _loungeOwnerProvider = LoungeOwnerProvider(
      saveBusinessInfoUseCase: _saveBusinessInfoUseCase,
      uploadNICImagesUseCase: _uploadNICImagesUseCase,
      getRegistrationProgressUseCase: _getRegistrationProgressUseCase,
      checkOCRBlockUseCase: _checkOCRBlockUseCase,
      getProfileUseCase: _getProfileUseCase,
      loungeOwnerRepository: _loungeOwnerRepository,
    );

    _registrationProvider = RegistrationProvider(
      addLoungeUseCase: _addLoungeUseCase,
      getMyLoungesUseCase: _getMyLoungesUseCase,
      loungeRepository: _loungeRepository,
    );

    _marketplaceProvider = MarketplaceProvider(
      repository: _marketplaceRepository,
    );

    _roleSelectionProvider = RoleSelectionProvider(
      getAllLoungesUseCase: _getAllLoungesUseCase,
    );

    _loungeStaffProvider = LoungeStaffProvider(
      remoteDataSource: _loungeStaffRemoteDataSource,
    );

    _loungeBookingProvider = LoungeBookingProvider(
      remoteDataSource: _loungeBookingRemoteDataSource,
    );

    _transportLocationProvider = TransportLocationProvider(
      remoteDataSource: _transportLocationRemoteDataSource,
    );

    _driverProvider = DriverProvider(
      remoteDataSource: _driverRemoteDataSource,
    );
  }

  /// Create and configure Dio instance
  Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors
    dio.interceptors.add(_createAuthInterceptor());
    dio.interceptors.add(_createLoggingInterceptor());

    return dio;
  }

  /// Create authentication interceptor
  InterceptorsWrapper _createAuthInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Get token from local storage
        final tokens = await _authLocalDataSource.getTokens();
        if (tokens != null && !tokens.isExpired) {
          options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
        }

        // Add device information headers
        final deviceHeaders = _deviceInfoHelper.getDeviceHeaders();
        options.headers.addAll(deviceHeaders);

        return handler.next(options);
      },
      onError: (error, handler) async {
        // Handle 401 - Token expired
        if (error.response?.statusCode == 401) {
          try {
            // Try to refresh token
            final result = await _authRepository.refreshToken();

            await result.fold(
              (failure) async {
                // Refresh failed - clear tokens
                await _authLocalDataSource.clearAll();
                return handler.reject(error);
              },
              (newTokens) async {
                // Retry the request with new token
                final options = error.requestOptions;
                options.headers['Authorization'] =
                    'Bearer ${newTokens.accessToken}';

                final response = await _dio.fetch(options);
                return handler.resolve(response);
              },
            );
          } catch (e) {
            return handler.reject(error);
          }
        } else {
          return handler.next(error);
        }
      },
    );
  }

  /// Create logging interceptor
  LogInterceptor _createLoggingInterceptor() {
    return LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
      logPrint: (obj) => print('[DIO] $obj'),
    );
  }

  // ========== Getters ==========
  AuthProvider get authProvider => _authProvider;
  StaffProvider get staffProvider => _staffProvider;
  LoungeOwnerProvider get loungeOwnerProvider => _loungeOwnerProvider;
  RegistrationProvider get registrationProvider => _registrationProvider;
  MarketplaceProvider get marketplaceProvider => _marketplaceProvider;
  RoleSelectionProvider get roleSelectionProvider => _roleSelectionProvider;
  LoungeStaffProvider get loungeStaffProvider => _loungeStaffProvider;
  LoungeBookingProvider get loungeBookingProvider => _loungeBookingProvider;
  TransportLocationProvider get transportLocationProvider =>
      _transportLocationProvider;
  DriverProvider get driverProvider => _driverProvider;

  AuthRepository get authRepository => _authRepository;
  StaffRepository get staffRepository => _staffRepository;
  LoungeOwnerRepository get loungeOwnerRepository => _loungeOwnerRepository;
  LoungeRepository get loungeRepository => _loungeRepository;
  AuthLocalDataSource get authLocalDataSource => _authLocalDataSource;

  ApiClient get apiClient => _apiClient;
  SupabaseStorageService get supabaseStorageService => _supabaseStorageService;
  LoungeOwnerRemoteDataSource get loungeOwnerRemoteDataSource =>
      _loungeOwnerRemoteDataSource;
}
