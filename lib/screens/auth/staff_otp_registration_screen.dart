import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import '../../config/constants.dart';
import '../../config/theme_config.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/error_dialog.dart';
import '../../widgets/loading_overlay.dart';
import '../../data/datasources/lounge_owner_remote_datasource.dart';
import '../../core/di/injection_container.dart';

class NoLeadingZeroFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final newText = newValue.text;

    if (oldText.isEmpty && newText.startsWith('0')) {
      return oldValue;
    }

    return newValue;
  }
}

/// Extended registration form for Lounge Staff
/// Collects: Full Name, NIC Number, Email, Lounge Selection, Phone, and OTP
/// After submission, verifies OTP with all details and navigates to pending approval
class StaffOtpRegistrationScreen extends StatefulWidget {
  const StaffOtpRegistrationScreen({
    super.key,
  });

  @override
  State<StaffOtpRegistrationScreen> createState() =>
      _StaffOtpRegistrationScreenState();
}

class _StaffOtpRegistrationScreenState
    extends State<StaffOtpRegistrationScreen> {
  final _otpController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _nicController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Logger _logger = Logger();

  String _completePhoneNumber = '';
  bool _isPhoneValid = false;
  bool _otpSent = false;
  bool _isSendingOtp = false;

  bool _isValidNic(String value) {
    final normalized = value.trim().toUpperCase();
    final nicPattern = RegExp(r'^(\d{12}|\d{9}[A-Z])$');
    return nicPattern.hasMatch(normalized);
  }

  bool _isValidEmail(String value) {
    final normalized = value.trim();
    final emailPattern = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,}$');
    return emailPattern.hasMatch(normalized);
  }

  String? _normalizeToLocalPhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10 && digits.startsWith('0')) {
      return digits;
    }
    if (digits.length == 11 && digits.startsWith('94')) {
      return '0${digits.substring(2)}';
    }
    return null;
  }

  String _mapUserErrorMessage(String? message) {
    final raw = (message ?? '').trim();
    if (raw.isEmpty) {
      return 'Registration failed. Please try again.';
    }

    final lower = raw.toLowerCase();
    if ((lower.contains('lounge') &&
            lower.contains('not') &&
            lower.contains('approved')) ||
        lower.contains('lounge_not_approved') ||
        lower.contains('selected_lounge_not_approved')) {
      return 'The selected lounge is not yet approved. Please try another lounge.';
    }

    if ((lower.contains('failed to create user account') ||
            lower.contains('user_creation_failed')) &&
        !lower.contains('email')) {
      return 'This email is already registered. Please retype a different email address.';
    }

    if ((lower.contains('email') || lower.contains('users_email_key')) &&
        (lower.contains('already') ||
            lower.contains('duplicate') ||
            lower.contains('exists') ||
            lower.contains('registered') ||
            lower.contains('23505'))) {
      return 'This email is already registered.';
    }

    return raw;
  }

  // District → Lounge Owners mapping
  Map<String, List<Map<String, dynamic>>> _districtOwnersMap = {};

  // Selected values
  String? _selectedDistrict;
  String? _selectedOwnerId;
  String? _selectedLoungeId;

  // Lounges for selected owner
  List<Map<String, dynamic>> _loungesForSelectedOwner = [];

  // Loading states
  bool _isLoadingDistricts = true;
  bool _isLoadingLounges = false;
  bool _isSubmitting = false;
  late LoungeOwnerRemoteDataSource _loungeOwnerDataSource;

  @override
  void initState() {
    super.initState();
    // Initialize the datasource
    final di = InjectionContainer();
    _loungeOwnerDataSource = di.loungeOwnerRemoteDataSource;
    Provider.of<AuthProvider>(context, listen: false)
        .setSelectedRole('lounge_staff');
    _loadDistricts();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _fullNameController.dispose();
    _nicController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadDistricts() async {
    try {
      _logger.i('📍 Fetching districts with lounge owners...');

      final districtOwnersMap = await _loungeOwnerDataSource
          .getApprovedLoungeOwnersGroupedByDistrict();

      if (mounted) {
        setState(() {
          _districtOwnersMap = districtOwnersMap;
          _isLoadingDistricts = false;
        });
      }

      _logger.i('✅ Loaded owners for ${districtOwnersMap.length} districts');
    } catch (e) {
      _logger.e('❌ Error loading districts: $e');
      if (mounted) {
        setState(() {
          _isLoadingDistricts = false;
        });
        ErrorDialog.show(
          context: context,
          message: 'Failed to load districts. Please check your connection.',
        );
      }
    }
  }

  Future<void> _onDistrictChanged(String? district) async {
    if (district == null) return;

    setState(() {
      _selectedDistrict = district;
      _selectedOwnerId = null;
      _selectedLoungeId = null;
      _loungesForSelectedOwner = [];
    });
  }

  Future<void> _onOwnerChanged(String? ownerId) async {
    if (ownerId == null) return;

    setState(() {
      _selectedOwnerId = ownerId;
      _selectedLoungeId = null;
      _isLoadingLounges = true;
    });

    try {
      _logger.i('📍 Fetching lounges for owner: $ownerId');

      final lounges = await _loungeOwnerDataSource.getLoungesByOwnerId(ownerId);

      if (mounted) {
        setState(() {
          _loungesForSelectedOwner = lounges;
          _isLoadingLounges = false;
        });
      }

      _logger.i('✅ Loaded ${lounges.length} lounges');
    } catch (e) {
      _logger.e('❌ Error loading lounges: $e');
      if (mounted) {
        setState(() {
          _isLoadingLounges = false;
        });
        ErrorDialog.show(
          context: context,
          message: 'Failed to load lounges. Please try again.',
        );
      }
    }
  }

  Future<void> _submitRegistration() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (!_otpSent) {
        ErrorDialog.show(
          context: context,
          message: 'Please request and enter the OTP first',
        );
        return;
      }

      if (_completePhoneNumber.isEmpty || !_isPhoneValid) {
        ErrorDialog.show(
          context: context,
          message: 'Phone number must be exactly 10 digits',
        );
        return;
      }

      if (_selectedLoungeId == null) {
        ErrorDialog.show(
          context: context,
          message: 'Please select a lounge',
        );
        return;
      }

      setState(() {
        _isSubmitting = true;
      });

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        _logger.i('📱 Submitting staff registration with OTP...');
        _logger.i('   Phone: $_completePhoneNumber');
        _logger.i('   Full Name: ${_fullNameController.text}');
        _logger.i('   Email: ${_emailController.text}');
        _logger.i('   Lounge ID: $_selectedLoungeId');

        final result = await authProvider.verifyOtpLoungeStaff(
          phoneNumber: _completePhoneNumber,
          otp: _otpController.text,
          loungeId: _selectedLoungeId!,
          fullName: _fullNameController.text.trim(),
          nicNumber: _nicController.text.trim().toUpperCase(),
          email: _emailController.text.trim(),
        );

        if (!mounted) return;

        if (result['success'] == true) {
          _logger.i('✅ Staff registration successful');

          // Navigate to pending approval screen
          Navigator.pushReplacementNamed(
            context,
            '/staff-pending-approval',
            arguments: {
              'loungeId': _selectedLoungeId,
            },
          );
        } else {
          _logger.e('❌ Registration failed: ${result['message']}');
          ErrorDialog.show(
            context: context,
            message: _mapUserErrorMessage(
              (result['message'] as String?) ?? authProvider.error,
            ),
          );
        }
      } catch (e) {
        _logger.e('❌ Error during registration: $e');
        if (mounted) {
          ErrorDialog.show(
            context: context,
            message: 'An error occurred. Please try again.',
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  Future<void> _sendOtp() async {
    if (_completePhoneNumber.isEmpty || !_isPhoneValid) {
      ErrorDialog.show(
        context: context,
        message: 'Phone number must be exactly 10 digits',
      );
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.sendOtp(_completePhoneNumber);

    if (!mounted) return;

    setState(() {
      _isSendingOtp = false;
      _otpSent = success;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent to your phone. Please check your messages.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      ErrorDialog.show(
        context: context,
        message: authProvider.error ?? 'Failed to send OTP',
        onRetry: _sendOtp,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            Navigator.of(context).pushReplacementNamed(
              AppConstants.roleSelectionRoute,
            );
          },
        ),
        title: const Text('Complete Registration'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _isSubmitting,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const SizedBox(height: 8),
                  Text(
                    'Enter Your Details',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Complete your registration to work at ${_selectedLoungeId != null ? _loungesForSelectedOwner.firstWhere((l) => l['id'] == _selectedLoungeId, orElse: () => {})['name'] ?? _loungesForSelectedOwner.firstWhere((l) => l['id'] == _selectedLoungeId, orElse: () => {})['lounge_name'] ?? 'selected lounge' : 'a lounge'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // Full Name Field
                  TextFormField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter your full name',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Full name is required';
                      }
                      if (value!.length < 2) {
                        return 'Please enter a valid name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // NIC Number Field
                  TextFormField(
                    controller: _nicController,
                    decoration: InputDecoration(
                      labelText: 'NIC Number',
                      hintText: 'Enter your NIC number',
                      prefixIcon: const Icon(Icons.credit_card),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'NIC number is required';
                      }
                      if (!_isValidNic(value!)) {
                        return 'ID number format is incorrect. Use 12 digits or 9 digits + 1 letter.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'Enter your email',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Email is required';
                      }
                      if (!_isValidEmail(value!)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // District Selection
                  _isLoadingDistricts
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select District',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedDistrict,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.map),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items: _districtOwnersMap.keys.map((district) {
                                return DropdownMenuItem<String>(
                                  value: district,
                                  child: Text(district),
                                );
                              }).toList(),
                              onChanged: _onDistrictChanged,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a district';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                  const SizedBox(height: 16),

                  // Lounge Owner Selection
                  _selectedDistrict == null
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.info.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info, color: AppColors.info),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Select a district first',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.info),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ((_districtOwnersMap[_selectedDistrict] ?? []).isEmpty)
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.warning.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'No lounge owners in selected district',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.warning,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select Lounge Owner',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _selectedOwnerId,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.person),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  items:
                                      (_districtOwnersMap[_selectedDistrict] ??
                                              [])
                                          .map((owner) {
                                    final id = owner['id'] as String? ?? '';
                                    final name =
                                        owner['business_name'] as String? ??
                                            owner['manager_name'] as String? ??
                                            owner['owner_name'] as String? ??
                                            owner['name'] as String? ??
                                            'Unknown';
                                    return DropdownMenuItem<String>(
                                      value: id,
                                      child: Text(name),
                                    );
                                  }).toList(),
                                  onChanged: _onOwnerChanged,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a lounge owner';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                  const SizedBox(height: 16),

                  // Lounge Selection
                  _selectedOwnerId == null
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.info.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info, color: AppColors.info),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Select a lounge owner first',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.info),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _isLoadingLounges
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _loungesForSelectedOwner.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Center(
                                    child: Text(
                                      'No lounges available for this owner',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Select Lounge',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: _selectedLoungeId,
                                      decoration: InputDecoration(
                                        prefixIcon:
                                            const Icon(Icons.location_on),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      items: _loungesForSelectedOwner
                                          .map((lounge) {
                                        final id =
                                            lounge['id'] as String? ?? '';
                                        final name = lounge['name']
                                                as String? ??
                                            lounge['lounge_name'] as String? ??
                                            'Unknown Lounge';
                                        final city = lounge['city'] as String?;
                                        final displayName =
                                            '$name${city != null ? ' - $city' : ''}';

                                        return DropdownMenuItem<String>(
                                          value: id,
                                          child: Text(displayName),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedLoungeId = value;
                                        });
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select a lounge';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                  const SizedBox(height: 24),

                  // Phone Number
                  IntlPhoneField(
                    controller: _phoneController,
                    inputFormatters: [
                      NoLeadingZeroFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '77 123 4567',
                      border: OutlineInputBorder(),
                    ),
                    initialCountryCode: AppConstants.countryISOCode,
                    disableLengthCheck: false,
                    onChanged: (phone) {
                      final normalized = _normalizeToLocalPhone(
                        phone.completeNumber,
                      );
                      setState(() {
                        _completePhoneNumber = normalized ?? '';
                        _isPhoneValid = normalized != null;
                      });
                    },
                    validator: (phone) {
                      if (phone == null || phone.number.isEmpty) {
                        return 'Phone number is required';
                      }
                      final normalized = _normalizeToLocalPhone(
                        phone.completeNumber,
                      );
                      if (normalized == null) {
                        return 'Phone number must be exactly 10 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Send OTP Button
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      onPressed: _isSendingOtp ? null : _sendOtp,
                      text: _isSendingOtp ? 'Sending OTP...' : 'Send OTP',
                      isLoading: _isSendingOtp,
                      height: 48,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // OTP Field
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: AppConstants.otpLength,
                    enabled: _otpSent,
                    decoration: InputDecoration(
                      labelText: 'OTP Code',
                      hintText: 'Enter 6-digit OTP',
                      prefixIcon: const Icon(Icons.security),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (!_otpSent) {
                        return 'Please request OTP first';
                      }
                      if (value?.isEmpty ?? true) {
                        return 'OTP is required';
                      }
                      if (value!.length != AppConstants.otpLength) {
                        return 'OTP must be ${AppConstants.otpLength} digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your registration will be reviewed by the lounge owner. You will be notified once approved.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.primary,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      onPressed: _isSubmitting ? null : _submitRegistration,
                      text: _isSubmitting
                          ? 'Registering...'
                          : 'Complete Registration',
                      isLoading: _isSubmitting,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
