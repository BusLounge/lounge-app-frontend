import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Dependency Injection
import 'core/config/app_config.dart';
import 'core/di/injection_container.dart';
import 'core/realtime/realtime_event.dart';
import 'core/realtime/realtime_socket_service.dart';

// Providers
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/lounge_owner_provider.dart';
import 'presentation/providers/registration_provider.dart';
import 'presentation/providers/marketplace_provider.dart';
import 'presentation/providers/lounge_staff_provider.dart';
import 'presentation/providers/lounge_booking_provider.dart';
import 'presentation/providers/transport_location_provider.dart';
import 'presentation/providers/driver_provider.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/auth/initial_role_selection_screen.dart';
import 'screens/auth/phone_input_screen.dart';
import 'screens/auth/otp_verification_screen.dart';
import 'screens/auth/staff_otp_registration_screen.dart';
import 'screens/auth/staff_pending_approval_screen.dart';
import 'screens/auth/staff_registered_login_screen.dart';
import 'screens/lounge_owner/lounge_owner_registration_screen.dart';
import 'screens/dashboard/lounge_owner_home_screen.dart';
import 'screens/lounge/lounges_list_screen.dart';
import 'screens/lounge/add_lounge_screen.dart';
import 'screens/booking/bookings_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/marketplace/marketplace_products_screen.dart';

// Config
import 'config/theme_config.dart';

// Utils
import 'utils/sms_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Print app signature for SMS auto-read setup
  await SmsHelper.printAppSignature();

  // Initialize dependency injection
  final di = InjectionContainer();
  await di.init();

  runApp(MyApp(di: di));
}

class MyApp extends StatefulWidget {
  final InjectionContainer di;

  const MyApp({super.key, required this.di});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final RealtimeSocketService _realtimeSocketService;
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;

  @override
  void initState() {
    super.initState();

    _realtimeSocketService = RealtimeSocketService(
      baseUrl: AppConfig.webSocketUrl,
      accessTokenProvider: () async {
        final tokens = await widget.di.authLocalDataSource.getTokens();
        return tokens?.accessToken;
      },
    );

    _realtimeSubscription = _realtimeSocketService.events.listen((event) {
      unawaited(_handleRealtimeEvent(event));
    });

    widget.di.authProvider.addListener(_handleAuthStateChanged);
    unawaited(_syncRealtimeConnection());
  }

  @override
  void dispose() {
    widget.di.authProvider.removeListener(_handleAuthStateChanged);
    _realtimeSubscription?.cancel();
    unawaited(_realtimeSocketService.dispose());
    super.dispose();
  }

  void _handleAuthStateChanged() {
    unawaited(_syncRealtimeConnection());
  }

  Future<void> _syncRealtimeConnection() async {
    final authProvider = widget.di.authProvider;
    final user = authProvider.user;

    if (!authProvider.isAuthenticated || user == null) {
      await _realtimeSocketService.disconnect();
      return;
    }

    await _realtimeSocketService.connect(userId: user.id, roles: user.roles);
  }

  Future<void> _handleRealtimeEvent(RealtimeEvent event) async {
    final registrationProvider = widget.di.registrationProvider;

    final isApprovalEvent = event.containsAny([
      'approval',
      'verification_status',
      'profile_approval',
      'owner.approved',
      'staff.approved',
    ]);

    final isStaffEvent = event.containsAny([
      'staff',
      'employee',
      'lounge_staff',
    ]);

    final isLocationEvent = event.containsAny([
      'location',
      'transport_location',
      'destination',
    ]);

    final isLoungeEvent = event.containsAny([
      'lounge',
      'profile',
      'registration',
    ]);

    if (isApprovalEvent || isLoungeEvent) {
      unawaited(
        widget.di.loungeOwnerProvider.getLoungeOwnerProfile(showLoading: false),
      );
      unawaited(widget.di.registrationProvider.loadMyLounges(showLoading: false));
    }

    if (isStaffEvent) {
      final loungeId = event.firstStringByKeys([
            'lounge_id',
            'loungeId',
            'owner_lounge_id',
          ]) ??
          registrationProvider.activeLoungeId ??
          registrationProvider.preferredVerifiedLoungeId;

      if (loungeId != null) {
        unawaited(
          widget.di.loungeStaffProvider
              .refreshForLounge(loungeId, showLoading: false),
        );
      } else {
        unawaited(widget.di.loungeStaffProvider.refreshLastQuery());
      }

      unawaited(widget.di.loungeStaffProvider.getMyStaffProfile(showLoading: false));
    }

    if (isLocationEvent) {
      final loungeId = event.firstStringByKeys([
            'lounge_id',
            'loungeId',
            'owner_lounge_id',
          ]) ??
          registrationProvider.activeLoungeId ??
          registrationProvider.preferredVerifiedLoungeId;

      if (loungeId != null) {
        unawaited(widget.di.transportLocationProvider.loadTransportLocations(
          loungeId,
          showLoading: false,
        ));
      } else {
        unawaited(widget.di.transportLocationProvider.refreshLastLounge());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Provide the refactored providers with proper DI
        ChangeNotifierProvider<AuthProvider>.value(value: widget.di.authProvider),
        ChangeNotifierProvider<LoungeOwnerProvider>.value(
          value: widget.di.loungeOwnerProvider,
        ),
        ChangeNotifierProvider<RegistrationProvider>.value(
          value: widget.di.registrationProvider,
        ),
        ChangeNotifierProvider<MarketplaceProvider>.value(
          value: widget.di.marketplaceProvider,
        ),
        ChangeNotifierProvider.value(value: widget.di.roleSelectionProvider),
        ChangeNotifierProvider<LoungeStaffProvider>.value(
          value: widget.di.loungeStaffProvider,
        ),
        ChangeNotifierProvider<LoungeBookingProvider>.value(
          value: widget.di.loungeBookingProvider,
        ),
        ChangeNotifierProvider<TransportLocationProvider>.value(
          value: widget.di.transportLocationProvider,
        ),
        ChangeNotifierProvider<DriverProvider>.value(
          value: widget.di.driverProvider,
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return MaterialApp(
            title: 'Lounge Owner App',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            home: const SplashScreen(),
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/':
                  return MaterialPageRoute(
                    builder: (_) => const SplashScreen(),
                  );
                case '/role-selection':
                  return MaterialPageRoute(
                    builder: (_) => const InitialRoleSelectionScreen(),
                  );
                case '/phone-input':
                  return MaterialPageRoute(
                    builder: (_) => const PhoneInputScreen(),
                  );
                case '/otp-verification':
                  final args = settings.arguments as Map<String, dynamic>?;
                  return MaterialPageRoute(
                    builder: (_) => OtpVerificationScreen(
                      phoneNumber: args?['phoneNumber'] as String? ?? '',
                    ),
                  );
                case '/staff-otp-registration':
                  return MaterialPageRoute(
                    builder: (_) => const StaffOtpRegistrationScreen(),
                  );
                case '/staff-pending-approval':
                  return MaterialPageRoute(
                    builder: (_) => const StaffPendingApprovalScreen(),
                  );
                case '/staff-registered-login':
                  return MaterialPageRoute(
                    builder: (_) => const StaffRegisteredLoginScreen(),
                  );
                case '/lounge-owner-registration':
                  final args = settings.arguments as Map<String, dynamic>?;
                  return MaterialPageRoute(
                    builder: (_) => LoungeOwnerRegistrationScreen(
                      userId: args?['userId'] as String? ?? '',
                    ),
                  );
                case '/home':
                  return MaterialPageRoute(
                    builder: (_) => const LoungeOwnerHomeScreen(),
                  );
                case '/lounges':
                  return MaterialPageRoute(
                    builder: (_) => const LoungesListScreen(),
                  );
                case '/add-lounge':
                  return MaterialPageRoute(
                    builder: (_) => const AddLoungeScreen(),
                  );
                case '/bookings':
                  return MaterialPageRoute(
                    builder: (_) => const BookingsScreen(),
                  );
                case '/profile':
                  return MaterialPageRoute(
                    builder: (_) => const ProfileScreen(),
                  );
                case '/edit-profile':
                  return MaterialPageRoute(
                    builder: (_) => const EditProfileScreen(),
                  );
                case '/marketplace':
                  final args = settings.arguments as Map<String, dynamic>?;
                  return MaterialPageRoute(
                    builder: (_) => MarketplaceProductsScreen(
                      loungeId: args?['loungeId'] as String? ?? '',
                      loungeName:
                          args?['loungeName'] as String? ?? 'Marketplace',
                    ),
                  );
                default:
                  return MaterialPageRoute(
                    builder: (_) => const SplashScreen(),
                  );
              }
            },
          );
        },
      ),
    );
  }
}
