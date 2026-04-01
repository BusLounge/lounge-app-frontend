import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme_config.dart';
import '../../domain/entities/user.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/lounge_staff_provider.dart';
import '../../presentation/providers/registration_provider.dart';
import '../../presentation/providers/role_selection_provider.dart';
import 'staff_registration_status_screen.dart';
import '../dashboard/lounge_owner_home_screen.dart';

class StaffRegistrationPage extends StatefulWidget {
  final bool isAddedByAdmin;
  final String? userId; // New user self-registration
  final String? phoneNumber; // New user phone
  final String? otp; // New user OTP
  final String? selectedDistrict;
  final String? selectedLoungeOwner;
  final String? selectedLounge;

  const StaffRegistrationPage({
    super.key,
    this.isAddedByAdmin = false,
    this.userId,
    this.phoneNumber,
    this.otp,
    this.selectedDistrict,
    this.selectedLoungeOwner,
    this.selectedLounge,
  });

  @override
  State<StaffRegistrationPage> createState() => _StaffRegistrationPageState();
}

class _StaffRegistrationPageState extends State<StaffRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _nicCtrl = TextEditingController();
  final _hiredDateCtrl = TextEditingController();
  DateTime? _hiredDate;
  String? _selectedLoungeId;

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

  bool _isValidPhoneNumber(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digitsOnly.length == 10;
  }

  String _toUserFriendlyError(String? rawError) {
    final message = (rawError ?? '').trim();
    if (message.isEmpty) {
      return 'Failed to complete registration';
    }

    final lower = message.toLowerCase();
    if (lower.contains('email') &&
        (lower.contains('already') ||
            lower.contains('exists') ||
            lower.contains('registered') ||
            lower.contains('duplicate'))) {
      return 'This email is already registered.';
    }

    return message;
  }

  @override
  void initState() {
    super.initState();
    if (widget.isAddedByAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadLounges();
      });
    }
  }

  Future<void> _loadLounges() async {
    final registrationProvider = context.read<RegistrationProvider>();
    if (registrationProvider.myLounges.isEmpty) {
      await registrationProvider.loadMyLounges();
    }
    final lounges = registrationProvider.verifiedLounges;
    if (mounted && lounges.isNotEmpty) {
      setState(() {
        _selectedLoungeId = lounges.first.id;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _nicCtrl.dispose();
    _hiredDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _showSuccessDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (widget.isAddedByAdmin) {
        // Admin/Lounge Owner adding staff - use the new API
        await _addStaffViaAPI();
      } else if (widget.userId != null &&
          widget.phoneNumber != null &&
          widget.otp != null) {
        // New user self-registration flow from role selection
        await _completeNewUserStaffRegistrationWithOTP();
      } else {
        // Existing staff self-registration flow - update profile
        await _completeStaffProfile();
      }
    }
  }

  Future<void> _completeNewUserStaffRegistrationWithOTP() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (widget.selectedLounge == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a lounge'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Get the lounge ID by searching for the lounge with matching name
    // Using the RoleSelectionProvider which has fetched all lounges
    final roleSelectionProvider =
        Provider.of<RoleSelectionProvider>(context, listen: false);

    String? loungeId;
    try {
      final matchingLounge = roleSelectionProvider.lounges.firstWhere(
        (lounge) => lounge.loungeName == widget.selectedLounge,
      );
      loungeId = matchingLounge.id;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Selected lounge not found. Please try again in role selection.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    //Call verifyOtpLoungeStaff endpoint with all required data
    final navigatorContext = context;
    final result = await authProvider.verifyOtpLoungeStaff(
      phoneNumber: widget.phoneNumber!,
      otp: widget.otp!,
      loungeId: loungeId,
      fullName: _nameCtrl.text.trim(),
      nicNumber: _nicCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
    );

    if (!mounted) return;
    Navigator.pop(navigatorContext); // Close loading dialog

    if (result['success'] == true) {
      ScaffoldMessenger.of(navigatorContext).showSnackBar(
        const SnackBar(
          content: Text('Registration completed successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );

      // Navigate to registration status screen
      Navigator.pushReplacement(
        navigatorContext,
        MaterialPageRoute(
          builder: (context) => StaffRegistrationStatusScreen(
            name: _nameCtrl.text.trim(),
            phone: widget.phoneNumber!,
            nic: _nicCtrl.text.trim(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(navigatorContext).showSnackBar(
        SnackBar(
          content: Text(_toUserFriendlyError(authProvider.error)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _addStaffViaAPI() async {
    final staffProvider = context.read<LoungeStaffProvider>();

    if (_selectedLoungeId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a lounge'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    // Call API to add staff
    final success = await staffProvider.addStaffDirectly(
      loungeId: _selectedLoungeId!,
      fullName: _nameCtrl.text.trim(),
      nicNumber: _nicCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      hiredDate: _hiredDate ?? DateTime.now(),
    );

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (success) {
      await _showSuccessDialog(
        title: 'Staff Member Added!',
        message: 'The staff member has been added successfully.',
      );

      // Navigate back to home
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const LoungeOwnerHomeScreen(),
        ),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(staffProvider.error ?? 'Failed to add staff member'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _completeStaffProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Update user data with registration information
    if (authProvider.user != null) {
      final updatedUser = User(
        id: authProvider.user!.id,
        phoneNumber: authProvider.user!.phoneNumber,
        email: authProvider.user!.email,
        firstName: _nameCtrl.text.trim(),
        lastName: '',
        nic: _nicCtrl.text.trim(),
        roles: authProvider.user!.roles,
        profileCompleted: true,
        phoneVerified: authProvider.user!.phoneVerified,
        status: authProvider.user!.status,
        createdAt: authProvider.user!.createdAt,
        updatedAt: DateTime.now(),
      );

      await authProvider.updateUserProfile(updatedUser);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Registration completed successfully!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    );

    // Staff self-registration flow - go to registration status screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => StaffRegistrationStatusScreen(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          nic: _nicCtrl.text.trim(),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Staff Member',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please provide staff details for verification',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Lounge Selection (for admin/owner only)
                if (widget.isAddedByAdmin) ...[
                  const Text(
                    'Lounge Selection',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Consumer<RegistrationProvider>(
                    builder: (context, registrationProvider, child) {
                      final lounges = registrationProvider.verifiedLounges;

                      if (lounges.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Text(
                            'No approved lounges found. Only approved lounges can have staff.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        );
                      }

                      return DropdownButtonFormField<String>(
                        value: _selectedLoungeId,
                        decoration: InputDecoration(
                          hintText: 'Select Lounge',
                          hintStyle: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.apartment,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.error),
                          ),
                        ),
                        items: lounges.map((lounge) {
                          return DropdownMenuItem<String>(
                            value: lounge.id,
                            child: Text(
                              lounge.loungeName,
                              style: const TextStyle(fontSize: 14),
                            ),
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
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // Form Fields Section
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _nameCtrl,
                  decoration: _fieldDecoration(
                    'Full Name',
                    Icons.person_outline,
                  ),
                  textCapitalization: TextCapitalization.words,
                  keyboardType: TextInputType.name,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter full name';
                    }
                    final trimmedValue = v.trim();
                    if (trimmedValue.length < 3) {
                      return 'Name must be at least 3 characters';
                    }
                    if (trimmedValue.length > 50) {
                      return 'Name must not exceed 50 characters';
                    }
                    final nameRegex = RegExp(r"^[a-zA-Z\s\-'\.]+$");
                    if (!nameRegex.hasMatch(trimmedValue)) {
                      return 'Name can only contain letters, spaces, hyphens, and apostrophes';
                    }
                    if (!RegExp(r'[a-zA-Z]').hasMatch(trimmedValue)) {
                      return 'Name must contain at least one letter';
                    }
                    if (trimmedValue.contains(RegExp(r'\s{2,}'))) {
                      return 'Name cannot contain consecutive spaces';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: _fieldDecoration(
                    'Phone Number',
                    Icons.phone_outlined,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter phone number';
                    }
                    final trimmedValue = v.trim();
                    if (!_isValidPhoneNumber(trimmedValue)) {
                      return 'Phone number must be exactly 10 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _fieldDecoration(
                    'Email Address',
                    Icons.email_outlined,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter email address';
                    }
                    if (!_isValidEmail(v)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _nicCtrl,
                  decoration: _fieldDecoration(
                    'NIC Number',
                    Icons.badge_outlined,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 12,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter NIC number';
                    }
                    if (!_isValidNic(v)) {
                      return 'ID number format is incorrect. Use 12 digits or 9 digits + 1 letter.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Hired Date Field
                TextFormField(
                  controller: _hiredDateCtrl,
                  readOnly: true,
                  decoration: _fieldDecoration(
                    'Hired Date',
                    Icons.calendar_today_outlined,
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _hiredDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setState(() {
                        _hiredDate = date;
                        _hiredDateCtrl.text =
                            '${date.day}/${date.month}/${date.year}';
                      });
                    }
                  },
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please select hired date'
                      : null,
                ),
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textLight,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      shadowColor: AppColors.primary.withOpacity(0.3),
                    ),
                    child: const Text(
                      'Complete Registration',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
