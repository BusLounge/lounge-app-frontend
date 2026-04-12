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
import 'staff_registration_otp_screen.dart';

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
  final _fullNameController = TextEditingController();
  final _nicController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Logger _logger = Logger();

  String _completePhoneNumber = '';
  bool _isPhoneValid = false;
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

  // Districts and owners for selected owner district
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _ownersForSelectedDistrict = [];

  // Selected values
  String? _selectedDistrict;
  String? _selectedLoungeDistrict;
  String? _selectedOwnerId;
  String? _selectedLoungeId;

  // Lounges for selected owner
  List<Map<String, dynamic>> _loungesForSelectedOwner = [];

  // Loading states
  bool _isLoadingDistricts = true;
  bool _isLoadingOwners = false;
  bool _isLoadingLounges = false;
  bool _isSubmitting = false;
  String? _ownersError;
  bool _showNetworkDelayMessage = false;
  static const String _otpNetworkDelayMessage =
      'Network Delay Detected. OTP may still arrive. Please wait or retry.';
  late LoungeOwnerRemoteDataSource _loungeOwnerDataSource;

  bool _isTimeoutLikeOtpFailure(String? message) {
    final normalized = (message ?? '').toLowerCase();
    return normalized.contains('timeout') ||
        normalized.contains('timed out') ||
        normalized.contains('time out') ||
        normalized.contains('deadline exceeded');
  }

  @override
  void initState() {
    super.initState();
    // Initialize the datasource
    final di = InjectionContainer();
    _loungeOwnerDataSource = di.loungeOwnerRemoteDataSource;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().setSelectedRole('lounge_staff');
    });
    _loadDistricts();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _nicController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadDistricts() async {
    try {
      _logger.i('📍 Fetching districts...');

      final districts = await _loungeOwnerDataSource.getAllDistricts();

      if (mounted) {
        setState(() {
          _districts = districts;
          _isLoadingDistricts = false;
        });
      }

      _logger.i('✅ Loaded ${districts.length} districts');
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

  Future<void> _onDistrictChanged(String? districtId) async {
    if (districtId == null || districtId.isEmpty) return;

    setState(() {
      _selectedDistrict = districtId;
      _selectedLoungeDistrict = null;
      _selectedOwnerId = null;
      _selectedLoungeId = null;
      _loungesForSelectedOwner = [];
      _ownersForSelectedDistrict = [];
      _ownersError = null;
      _isLoadingOwners = true;
      _isLoadingLounges = false;
    });

    try {
      _logger.i('📍 Fetching approved owners for district: $districtId');
      final owners = await _loungeOwnerDataSource
          .getApprovedLoungeOwnersByDistrictId(districtId);

      if (mounted) {
        setState(() {
          _ownersForSelectedDistrict = owners;
          _isLoadingOwners = false;
        });
      }
      _logger.i('✅ Loaded ${owners.length} owners for district');
    } catch (e) {
      _logger.e('❌ Error loading owners for district: $e');
      if (mounted) {
        setState(() {
          _ownersForSelectedDistrict = [];
          _isLoadingOwners = false;
          _ownersError = 'Failed to load lounge owners';
        });
      }
    }
  }

  Future<void> _onOwnerChanged(String? ownerId) async {
    if (ownerId == null) return;

    if (_selectedDistrict == null || _selectedDistrict!.isEmpty) {
      return;
    }

    setState(() {
      _selectedOwnerId = ownerId;
      _selectedLoungeId = null;
      _loungesForSelectedOwner = [];
      _isLoadingLounges = false;
    });

    if (_selectedLoungeDistrict != null &&
        _selectedLoungeDistrict!.isNotEmpty) {
      await _loadLoungesForSelectedOwnerAndDistrict();
    }
  }

  Future<void> _onLoungeDistrictChanged(String? districtId) async {
    if (districtId == null || districtId.isEmpty) return;

    setState(() {
      _selectedLoungeDistrict = districtId;
      _selectedLoungeId = null;
      _loungesForSelectedOwner = [];
      _isLoadingLounges = true;
    });

    await _loadLoungesForSelectedOwnerAndDistrict();
  }

  Future<void> _loadLoungesForSelectedOwnerAndDistrict() async {
    final ownerId = _selectedOwnerId;
    final districtId = _selectedLoungeDistrict;

    if (ownerId == null || ownerId.isEmpty) {
      return;
    }

    if (districtId == null || districtId.isEmpty) {
      return;
    }

    try {
      _logger.i(
        '📍 Fetching lounges for owner: $ownerId in lounge district: $districtId',
      );

      final lounges =
          await _loungeOwnerDataSource.getLoungesByOwnerAndDistrictId(
        ownerId: ownerId,
        districtId: districtId,
      );

      if (mounted) {
        setState(() {
          _loungesForSelectedOwner = lounges;
          _isLoadingLounges = false;
        });
      }

      _logger.i('✅ Loaded ${_loungesForSelectedOwner.length} lounges');
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

  Future<void> _sendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_selectedLoungeId == null) {
      ErrorDialog.show(
        context: context,
        message: 'Please select a lounge',
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

    setState(() {
      _isSendingOtp = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.sendOtp(_completePhoneNumber);

    if (!mounted) return;

    setState(() {
      _isSendingOtp = false;
    });

    if (success) {
      setState(() {
        _showNetworkDelayMessage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent to your phone. Please check your messages.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StaffRegistrationOtpScreen(
            phoneNumber: _completePhoneNumber,
            loungeId: _selectedLoungeId!,
            fullName: _fullNameController.text.trim(),
            nicNumber: _nicController.text.trim().toUpperCase(),
            email: _emailController.text.trim(),
          ),
        ),
      );
    } else {
      final errorMessage = authProvider.error ?? 'Failed to send OTP';
      if (_isTimeoutLikeOtpFailure(errorMessage)) {
        setState(() {
          _showNetworkDelayMessage = true;
        });
        return;
      }

      setState(() {
        _showNetworkDelayMessage = false;
      });
      ErrorDialog.show(
        context: context,
        message: errorMessage,
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
                  if (_showNetworkDelayMessage) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFF6E5), Color(0xFFFFE8BF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF3B24B)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.network_check_rounded,
                            color: Color(0xFF7A4A00),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              _otpNetworkDelayMessage,
                              style: TextStyle(
                                color: Color(0xFF5D3900),
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _showNetworkDelayMessage = false;
                              });
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF7A4A00),
                            ),
                            tooltip: 'Dismiss',
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  // Lounge Owner District Selection
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
                              'Select Lounge Owner\'s District',
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
                                labelText: 'District',
                                hintText: 'Select lounge owner\'s district',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items: _districts.map((district) {
                                final id = district['id'] as String? ?? '';
                                final name =
                                    district['district'] as String? ?? '';
                                return DropdownMenuItem<String>(
                                  value: id,
                                  child: Text(name),
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
                      : _isLoadingOwners
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _ownersError != null
                              ? Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.error.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: AppColors.error,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _ownersError!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.error,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _ownersForSelectedDistrict.isEmpty
                                  ? Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color:
                                            AppColors.warning.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.warning
                                              .withOpacity(0.3),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Select Lounge Owner',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 8),
                                        DropdownButtonFormField<String>(
                                          value: _selectedOwnerId,
                                          decoration: InputDecoration(
                                            prefixIcon:
                                                const Icon(Icons.person),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          items: _ownersForSelectedDistrict
                                              .map((owner) {
                                            final id =
                                                owner['id'] as String? ?? '';
                                            final name = owner['business_name']
                                                    as String? ??
                                                owner['manager_name']
                                                    as String? ??
                                                owner['owner_name']
                                                    as String? ??
                                                owner['name'] as String? ??
                                                'Unknown';
                                            return DropdownMenuItem<String>(
                                              value: id,
                                              child: Text(name),
                                            );
                                          }).toList(),
                                          onChanged: _onOwnerChanged,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Please select a lounge owner';
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                    ),
                  const SizedBox(height: 16),

                  // Lounge District Selection
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
                      : _isLoadingDistricts
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
                                  'Select Lounge District',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _selectedLoungeDistrict,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.map_outlined),
                                    labelText: 'District',
                                    hintText: 'Select lounge district',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  items: _districts.map((district) {
                                    final id = district['id'] as String? ?? '';
                                    final name =
                                        district['district'] as String? ?? '';
                                    return DropdownMenuItem<String>(
                                      value: id,
                                      child: Text(name),
                                    );
                                  }).toList(),
                                  onChanged: _onLoungeDistrictChanged,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a lounge district';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                  const SizedBox(height: 16),

                  // Lounge Selection
                  _selectedOwnerId == null || _selectedLoungeDistrict == null
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
                                  _selectedOwnerId == null
                                      ? 'Select a lounge owner first'
                                      : 'Select a lounge district first',
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
                                      'No lounges available for this owner in the selected district',
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
