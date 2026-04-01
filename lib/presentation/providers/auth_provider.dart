import 'package:flutter/foundation.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/send_otp.dart';
import '../../domain/usecases/verify_otp.dart';
import '../../domain/usecases/logout.dart';
import '../../domain/repositories/auth_repository.dart';

/// Presentation Layer: Auth ViewModel
///
/// Responsibilities:
/// - Manage UI state only
/// - Delegate business logic to use cases
/// - Convert domain failures to UI-friendly messages
class AuthProvider extends ChangeNotifier {
  final SendOtpUseCase sendOtpUseCase;
  final VerifyOtpUseCase verifyOtpUseCase;
  final LogoutUseCase logoutUseCase;
  final AuthRepository authRepository;

  AuthProvider({
    required this.sendOtpUseCase,
    required this.verifyOtpUseCase,
    required this.logoutUseCase,
    required this.authRepository,
  });

  // UI State
  bool _isLoading = false;
  String? _error;
  User? _user;
  String? _phoneNumber;
  bool _isAuthenticated = false;
  String _selectedRole =
      'lounge_owner'; // Store selected role for OTP verification

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  User? get user => _user;
  String? get phoneNumber => _phoneNumber;
  bool get isAuthenticated => _isAuthenticated;

  /// Check authentication status on app start
  Future<void> checkAuthStatus() async {
    _setLoading(true);
    _clearError();

    try {
      _isAuthenticated = await authRepository.isAuthenticated();

      if (_isAuthenticated) {
        _user = await authRepository.getCurrentUser();
      } else {
        _user = null;
      }
    } catch (e) {
      _error = 'Failed to check authentication status';
      _isAuthenticated = false;
      _user = null;
    } finally {
      _setLoading(false);
    }
  }

  /// Send OTP to phone number
  Future<bool> sendOtp(String phoneNumber) async {
    _setLoading(true);
    _clearError();
    _phoneNumber = phoneNumber;

    final result = await sendOtpUseCase(phoneNumber);

    return result.fold(
      (failure) {
        _error = _mapFailureToMessage(failure);
        _setLoading(false);
        return false;
      },
      (_) {
        _setLoading(false);
        return true;
      },
    );
  }

  /// Verify OTP for Lounge Owner registration/login
  Future<Map<String, dynamic>> verifyOtpLoungeOwner(
      String phoneNumber, String otp) async {
    _setLoading(true);
    _clearError();

    final result = await authRepository.verifyOtpLoungeOwner(
        phoneNumber: phoneNumber, otp: otp);

    return result.fold(
      (failure) {
        _error = _mapFailureToMessage(failure);
        _setLoading(false);
        return {
          'success': false,
          'nextRoute': '/otp-verification',
          'message': _error,
        };
      },
      (verifyResult) {
        // Update UI state
        _isAuthenticated = true;
        _phoneNumber = null;

        // Get user from repository (already saved by repository)
        authRepository.getCurrentUser().then((user) {
          _user = user;
          notifyListeners();
        });

        _setLoading(false);

        // Determine next route based on registrationStep
        String nextRoute = '/lounge-owner-registration';
        if (verifyResult.registrationStep == 'completed') {
          nextRoute = '/lounge-owner-home';
        }

        return {
          'success': true,
          'userId': verifyResult.user.id,
          'roles': verifyResult.roles,
          'nextRoute': nextRoute,
          'registrationStep': verifyResult.registrationStep,
          'isNewUser': verifyResult.isNewUser,
          'profileCompleted': verifyResult.user.profileCompleted,
        };
      },
    );
  }

  /// Verify OTP for Lounge Staff registration/login
  Future<Map<String, dynamic>> verifyOtpLoungeStaff({
    required String phoneNumber,
    required String otp,
    required String loungeId,
    required String fullName,
    required String nicNumber,
    required String email,
  }) async {
    _setLoading(true);
    _clearError();

    final result = await authRepository.verifyOtpLoungeStaff(
      phoneNumber: phoneNumber,
      otp: otp,
      loungeId: loungeId,
      fullName: fullName,
      nicNumber: nicNumber,
      email: email,
    );

    return result.fold(
      (failure) {
        _error = _mapFailureToMessage(failure);
        _setLoading(false);
        return {'success': false, 'nextRoute': '/otp-verification'};
      },
      (verifyResult) {
        // Update UI state
        _isAuthenticated = true;
        _phoneNumber = null;

        // Get user from repository (already saved by repository)
        authRepository.getCurrentUser().then((user) {
          _user = user;
          notifyListeners();
        });

        _setLoading(false);

        return {
          'success': true,
          'userId': verifyResult.user.id,
          'roles': verifyResult.roles,
          'nextRoute': '/staff-dashboard',
          'registrationStep': verifyResult.registrationStep,
          'isNewUser': verifyResult.isNewUser,
          'profileCompleted': verifyResult.user.profileCompleted,
        };
      },
    );
  }

  /// Verify OTP for Registered Lounge Staff (login flow)
  Future<Map<String, dynamic>> verifyOtpLoungeStaffRegistered({
    required String phoneNumber,
    required String otp,
  }) async {
    _setLoading(true);
    _clearError();

    final result = await authRepository.verifyOtpLoungeStaffRegistered(
      phoneNumber: phoneNumber,
      otp: otp,
    );

    return result.fold(
      (failure) {
        _error = _mapFailureToMessage(failure);
        _setLoading(false);
        return {'success': false};
      },
      (verifyResult) {
        _isAuthenticated = true;
        _phoneNumber = null;

        authRepository.getCurrentUser().then((user) {
          _user = user;
          notifyListeners();
        });

        _setLoading(false);

        return {
          'success': true,
          'userId': verifyResult.user.id,
          'roles': verifyResult.roles,
          'isNewUser': verifyResult.isNewUser,
          'profileCompleted': verifyResult.user.profileCompleted,
        };
      },
    );
  }

  /// Set the selected role (lounge_owner or lounge_staff)
  void setSelectedRole(String role) {
    _selectedRole = role;
    notifyListeners();
  }

  /// Verify OTP and authenticate
  /// Returns Map with navigation info
  /// Uses the selected role to determine which endpoint to call
  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String otp) async {
    _setLoading(true);
    _clearError();

    // If lounge_owner was selected, use the lounge owner endpoint
    if (_selectedRole == 'lounge_owner') {
      final result = await authRepository.verifyOtpLoungeOwner(
        phoneNumber: phoneNumber,
        otp: otp,
      );

      return result.fold(
        (failure) {
          _error = _mapFailureToMessage(failure);
          _setLoading(false);
          return {'success': false, 'nextRoute': '/otp-verification'};
        },
        (verifyResult) {
          // Update UI state
          _isAuthenticated = true;
          _phoneNumber = null;

          // Get user from repository (already saved by repository)
          authRepository.getCurrentUser().then((user) {
            _user = user;
            notifyListeners();
          });

          _setLoading(false);

          // Determine next route based on registrationStep
          String nextRoute = '/lounge-owner-registration';
          if (verifyResult.registrationStep == 'completed') {
            nextRoute = '/lounge-owner-home';
          }

          return {
            'success': true,
            'userId': verifyResult.user.id,
            'roles': verifyResult.roles,
            'nextRoute': nextRoute,
            'registrationStep': verifyResult.registrationStep,
            'isNewUser': verifyResult.isNewUser,
            'profileCompleted': verifyResult.user.profileCompleted,
          };
        },
      );
    }

    // If lounge_staff was selected, use the generic verify OTP endpoint
    // which returns empty roles for new users
    final result = await authRepository.verifyOtpGeneric(
      phoneNumber: phoneNumber,
      otp: otp,
    );

    return result.fold(
      (failure) {
        _error = _mapFailureToMessage(failure);
        _setLoading(false);
        return {'success': false, 'nextRoute': '/otp-verification'};
      },
      (verifyResult) {
        // For staff, don't fully authenticate yet
        // Store tokens but don't set _isAuthenticated = true until staff details are collected
        _phoneNumber = phoneNumber;

        // Save tokens for later use
        authRepository.getCurrentUser().then((user) {
          _user = user;
          notifyListeners();
        });

        _setLoading(false);

        // Navigate to staff registration to collect full details
        return {
          'success': true,
          'nextRoute': '/staff-registration',
          'phoneNumber': phoneNumber,
          'userId': verifyResult.user.id,
          'roles': verifyResult.roles,
          'isNewUser': verifyResult.isNewUser,
          'profileCompleted': verifyResult.user.profileCompleted,
        };
      },
    );
  }

  /// Logout user
  Future<bool> logout({bool logoutAll = false}) async {
    _setLoading(true);
    _clearError();

    final result = await logoutUseCase(logoutAll: logoutAll);

    return result.fold(
      (failure) {
        _error = _mapFailureToMessage(failure);
        // Still clear local state
        _isAuthenticated = false;
        _user = null;
        _phoneNumber = null;
        _setLoading(false);
        return true; // Return true since local logout succeeded
      },
      (_) {
        _isAuthenticated = false;
        _user = null;
        _phoneNumber = null;
        _setLoading(false);
        return true;
      },
    );
  }

  /// Update user data (when profile changes)
  void updateUser(User user) {
    _user = user;
    notifyListeners();
  }

  /// Update user profile and save to storage
  Future<bool> updateUserProfile(User user) async {
    _setLoading(true);
    _clearError();

    final result = await authRepository.updateUserProfile(user);

    return result.fold(
      (failure) {
        _error = _mapFailureToMessage(failure);
        _setLoading(false);
        return false;
      },
      (updatedUser) {
        _user = updatedUser;
        _setLoading(false);
        return true;
      },
    );
  }

  /// Clear error message
  void clearError() {
    _clearError();
  }

  // Private helpers
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  /// Map domain failures to user-friendly messages
  String _mapFailureToMessage(dynamic failure) {
    final rawMessage = failure.toString().replaceFirst('Failure: ', '').trim();
    final lower = rawMessage.toLowerCase();

    if ((lower.contains('failed to create user account') ||
            lower.contains('user_creation_failed')) &&
        !lower.contains('email')) {
      return 'This email is already registered. Please retype a different email address.';
    }

    if (lower.contains('email') &&
        (lower.contains('already') ||
            lower.contains('exists') ||
            lower.contains('registered') ||
            lower.contains('duplicate'))) {
      return 'This email is already registered.';
    }

    return rawMessage;
  }
}
