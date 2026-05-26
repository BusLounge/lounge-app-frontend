import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme_config.dart';
import '../../core/di/injection_container.dart';
import '../../data/datasources/lounge_owner_remote_datasource.dart';
import '../../domain/entities/lounge_owner.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/lounge_owner_provider.dart';
import '../../widgets/owner_bottom_nav_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late LoungeOwnerRemoteDataSource _loungeOwnerRemoteDataSource;
  final Map<String, String> _districtNamesById = {};
  List<Map<String, dynamic>> _bankLinks = [];
  bool _bankLoading = false;
  String? _bankError;

  static const List<String> _sriLankanBanks = [
    'Amana Bank',
    'Bank of Ceylon',
    'Bank of China',
    'Cargills Bank',
    'Citibank, N.A.',
    'Commercial Bank of Ceylon',
    'Deutsche Bank',
    'DFCC Bank',
    'Habib Bank',
    'Hatton National Bank',
    'HDFC Bank of Sri Lanka',
    'Hong Kong and Shanghai Banking Corporation (HSBC)',
    'Indian Bank',
    'Indian Overseas Bank',
    'MCB Bank',
    'National Development Bank',
    'National Savings Bank',
    'Nations Trust Bank',
    'Pan Asia Bank',
    'People\'s Bank',
    'Public Bank Berhad',
    'Regional Development Bank',
    'Sampath Bank',
    'Sanasa Development Bank',
    'Seylan Bank',
    'Sri Lanka Savings Bank',
    'Standard Chartered Bank',
    'State Bank of India',
    'State Mortgage and Investment Bank',
    'Union Bank of Colombo',
  ];

  static const List<String> _accountTypes = [
    'Savings Account',
    'Current Account',
    'Business Account',
    'Joint Account',
  ];

  @override
  void initState() {
    super.initState();
    _loungeOwnerRemoteDataSource =
        InjectionContainer().loungeOwnerRemoteDataSource;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<LoungeOwnerProvider>(
        context,
        listen: false,
      ).getLoungeOwnerProfile();
      _loadDistricts();
      _loadBankLinks();
    });
  }

  Future<void> _loadDistricts() async {
    try {
      final districts = await _loungeOwnerRemoteDataSource.getAllDistricts();
      if (!mounted) return;

      setState(() {
        _districtNamesById
          ..clear()
          ..addEntries(
            districts.map((district) {
              final id = district['id']?.toString() ?? '';
              final name = district['district']?.toString() ?? '';
              return MapEntry(id, name);
            }).where((entry) =>
                entry.key.isNotEmpty && entry.value.trim().isNotEmpty),
          );
      });
    } catch (_) {
      // Keep profile usable even when district lookup fails.
    }
  }

  Future<void> _loadBankLinks() async {
    if (!mounted) return;
    setState(() {
      _bankLoading = true;
      _bankError = null;
    });

    final provider = Provider.of<LoungeOwnerProvider>(context, listen: false);
    final result = await provider.getBankLinks();

    result.fold(
      (failure) {
        if (!mounted) return;
        setState(() {
          _bankError = failure.message;
          _bankLinks = [];
          _bankLoading = false;
        });
      },
      (links) {
        if (!mounted) return;
        setState(() {
          _bankLinks = links;
          _bankLoading = false;
        });
      },
    );
  }

  bool _looksLikeUuid(String value) {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(value.trim());
  }

  String _resolveDistrictDisplay(LoungeOwner? loungeOwner) {
    final rawDistrict = loungeOwner?.district?.trim();
    if (rawDistrict == null || rawDistrict.isEmpty) {
      return 'Not provided';
    }

    final mappedName = _districtNamesById[rawDistrict];
    if (mappedName != null && mappedName.trim().isNotEmpty) {
      return mappedName;
    }

    if (_looksLikeUuid(rawDistrict)) {
      return 'Unknown district';
    }

    return rawDistrict;
  }

  bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;

  String _maskSensitive(String? value) {
    if (value == null) return 'Not provided';
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Not provided';
    if (trimmed.length <= 4) {
      return '****';
    }
    final lastFour = trimmed.substring(trimmed.length - 4);
    return '****$lastFour';
  }

  Map<String, dynamic>? _extractBankDetails() {
    if (_bankLinks.isEmpty) return null;
    final entry = _bankLinks.first;
    final details = entry['bank_details'];
    if (details is Map<String, dynamic>) {
      return details;
    }
    return null;
  }

  Future<void> _showEditBankDetailsDialog(Map<String, dynamic> details) async {
    final bankNameController =
        TextEditingController(text: details['bank_name']?.toString() ?? '');
    final branchNameController =
        TextEditingController(text: details['branch_name']?.toString() ?? '');
    final branchCodeController =
        TextEditingController(text: details['branch_code']?.toString() ?? '');
    final acTypeController =
        TextEditingController(text: details['ac_type']?.toString() ?? '');
    final holderController = TextEditingController(
        text: details['ac_holder_name']?.toString() ?? '');
    final numberController =
        TextEditingController(text: details['ac_number']?.toString() ?? '');
    final swiftController =
        TextEditingController(text: details['swift_code']?.toString() ?? '');

    final formKey = GlobalKey<FormState>();
    final provider = Provider.of<LoungeOwnerProvider>(context, listen: false);
    String? selectedBankName = bankNameController.text.trim().isEmpty
        ? null
        : bankNameController.text.trim();
    String? selectedAccountType = acTypeController.text.trim().isEmpty
        ? null
        : acTypeController.text.trim();

    final bankOptions = <String>[
      if (selectedBankName != null &&
          !_sriLankanBanks.contains(selectedBankName))
        selectedBankName,
      ..._sriLankanBanks,
    ];
    final accountTypeOptions = <String>[
      if (selectedAccountType != null &&
          !_accountTypes.contains(selectedAccountType))
        selectedAccountType,
      ..._accountTypes,
    ];

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Bank Details'),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedBankName,
                        decoration:
                            const InputDecoration(labelText: 'Bank Name'),
                        isExpanded: true,
                        items: bankOptions
                            .map(
                              (bank) => DropdownMenuItem<String>(
                                value: bank,
                                child:
                                    Text(bank, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedBankName = value;
                            bankNameController.text = value ?? '';
                          });
                        },
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Bank name is required'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: branchNameController,
                        decoration:
                            const InputDecoration(labelText: 'Branch Name'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Branch name is required'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: branchCodeController,
                        decoration:
                            const InputDecoration(labelText: 'Branch Code'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Branch code is required'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedAccountType,
                        decoration:
                            const InputDecoration(labelText: 'Account Type'),
                        isExpanded: true,
                        items: accountTypeOptions
                            .map(
                              (type) => DropdownMenuItem<String>(
                                value: type,
                                child:
                                    Text(type, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedAccountType = value;
                            acTypeController.text = value ?? '';
                          });
                        },
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Account type is required'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: holderController,
                        decoration:
                            const InputDecoration(labelText: 'Account Holder'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Account holder is required'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: numberController,
                        decoration:
                            const InputDecoration(labelText: 'Account Number'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Account number is required'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: swiftController,
                        decoration: const InputDecoration(
                            labelText: 'SWIFT Code (Optional)'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    final bankId = details['id']?.toString();
    if (bankId == null || bankId.isEmpty) {
      return;
    }

    final result = await provider.updateBankDetails(
      id: bankId,
      bankName: bankNameController.text.trim(),
      branchName: branchNameController.text.trim(),
      branchCode: branchCodeController.text.trim(),
      acType: acTypeController.text.trim(),
      acHolderName: holderController.text.trim(),
      acNumber: numberController.text.trim(),
      swiftCode: swiftController.text.trim().isEmpty
          ? null
          : swiftController.text.trim(),
    );

    result.fold(
      (failure) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: AppColors.error,
          ),
        );
      },
      (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bank details updated successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadBankLinks();
      },
    );
  }

  Future<void> _showAddBankDetailsDialog() async {
    final bankNameController = TextEditingController();
    final branchNameController = TextEditingController();
    final branchCodeController = TextEditingController();
    final acTypeController = TextEditingController();
    final holderController = TextEditingController();
    final numberController = TextEditingController();
    final swiftController = TextEditingController();

    final formKey = GlobalKey<FormState>();
    final provider = Provider.of<LoungeOwnerProvider>(context, listen: false);
    String? selectedBankName;
    String? selectedAccountType;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Bank Details'),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedBankName,
                        decoration:
                            const InputDecoration(labelText: 'Bank Name'),
                        isExpanded: true,
                        items: _sriLankanBanks
                            .map(
                              (bank) => DropdownMenuItem<String>(
                                value: bank,
                                child:
                                    Text(bank, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedBankName = value;
                            bankNameController.text = value ?? '';
                          });
                        },
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Bank name is required'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: branchNameController,
                        decoration:
                            const InputDecoration(labelText: 'Branch Name'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Branch name is required'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: branchCodeController,
                        decoration:
                            const InputDecoration(labelText: 'Branch Code'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Branch code is required'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedAccountType,
                        decoration:
                            const InputDecoration(labelText: 'Account Type'),
                        isExpanded: true,
                        items: _accountTypes
                            .map(
                              (type) => DropdownMenuItem<String>(
                                value: type,
                                child:
                                    Text(type, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedAccountType = value;
                            acTypeController.text = value ?? '';
                          });
                        },
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Account type is required'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: holderController,
                        decoration:
                            const InputDecoration(labelText: 'Account Holder'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Account holder is required'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: numberController,
                        decoration:
                            const InputDecoration(labelText: 'Account Number'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Account number is required'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: swiftController,
                        decoration: const InputDecoration(
                            labelText: 'SWIFT Code (Optional)'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    final createResult = await provider.createBankDetails(
      bankName: bankNameController.text.trim(),
      branchName: branchNameController.text.trim(),
      branchCode: branchCodeController.text.trim(),
      acType: acTypeController.text.trim(),
      acHolderName: holderController.text.trim(),
      acNumber: numberController.text.trim(),
      swiftCode: swiftController.text.trim().isEmpty
          ? null
          : swiftController.text.trim(),
    );

    Map<String, dynamic>? created;
    final createError = createResult.fold(
      (failure) => failure.message,
      (data) {
        created = data;
        return null;
      },
    );

    if (createError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(createError),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final bankId = created?['id']?.toString();
    if (bankId == null || bankId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bank details saved but id missing.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final linkResult =
        await provider.createBankLink(bankDetailsId: bankId, loungeId: null);

    final linkError = linkResult.fold(
      (failure) => failure.message,
      (_) => null,
    );

    if (linkError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(linkError),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Bank details added successfully.'),
        backgroundColor: AppColors.success,
      ),
    );
    _loadBankLinks();
  }

  Future<void> _logout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final loungeOwnerProvider = Provider.of<LoungeOwnerProvider>(
      context,
      listen: false,
    );

    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textLight,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await authProvider.logout();
      loungeOwnerProvider.clearData();

      if (!context.mounted) return;

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/phone-input', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LoungeOwnerProvider, AuthProvider>(
      builder: (context, loungeOwnerProvider, authProvider, child) {
        final loungeOwner = loungeOwnerProvider.loungeOwner;
        final user = authProvider.user;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            title: const Text(
              'Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: AppColors.textPrimary),
                onPressed: () => _logout(context),
                tooltip: 'Logout',
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 60,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          loungeOwner?.managerFullName ??
                              user?.firstName ??
                              'Lounge Owner',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Lounge Owner',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (loungeOwner?.verificationStatus != null) ...[
                          const SizedBox(height: 12),
                          _buildStatusBadge(loungeOwner!.verificationStatus),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Contact Information
                  _buildSectionCard(
                    title: 'Contact Information',
                    icon: Icons.contact_phone,
                    children: [
                      if (user?.phoneNumber != null)
                        _buildInfoRow(
                          'Phone Number',
                          user!.phoneNumber,
                          Icons.phone,
                        ),
                      if (_hasValue(loungeOwner?.managerFullName))
                        _buildInfoRow(
                          'Manager Full Name',
                          loungeOwner!.managerFullName!,
                          Icons.person,
                        ),
                      if (_hasValue(loungeOwner?.managerNicNumber))
                        _buildInfoRow(
                          'Manager NIC Number',
                          loungeOwner!.managerNicNumber!,
                          Icons.badge,
                        ),
                      _buildInfoRow(
                        'Manager Email',
                        _hasValue(loungeOwner?.managerEmail)
                            ? loungeOwner!.managerEmail!
                            : 'Not provided',
                        Icons.email,
                      ),
                      _buildInfoRow(
                        'District',
                        _resolveDistrictDisplay(loungeOwner),
                        Icons.location_on,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildSectionCard(
                    title: 'Bank Details',
                    icon: Icons.account_balance,
                    children: [
                      if (_bankLoading)
                        const Text('Loading bank details...')
                      else if (_bankError != null)
                        Text(
                          _bankError!,
                          style: const TextStyle(color: AppColors.error),
                        )
                      else if (_extractBankDetails() == null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('No bank details on file.'),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _showAddBankDetailsDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Bank Details'),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _buildInfoRow(
                          'Bank Name',
                          _extractBankDetails()!['bank_name']?.toString() ??
                              'Not provided',
                          Icons.account_balance,
                        ),
                        _buildInfoRow(
                          'Branch Name',
                          _extractBankDetails()!['branch_name']?.toString() ??
                              'Not provided',
                          Icons.location_city,
                        ),
                        _buildInfoRow(
                          'Branch Code',
                          _extractBankDetails()!['branch_code']?.toString() ??
                              'Not provided',
                          Icons.account_tree,
                        ),
                        _buildInfoRow(
                          'Account Type',
                          _extractBankDetails()!['ac_type']?.toString() ??
                              'Not provided',
                          Icons.category,
                        ),
                        _buildInfoRow(
                          'Account Holder',
                          _extractBankDetails()!['ac_holder_name']
                                  ?.toString() ??
                              'Not provided',
                          Icons.person,
                        ),
                        _buildInfoRow(
                          'Account Number',
                          _maskSensitive(
                            _extractBankDetails()!['ac_number']?.toString(),
                          ),
                          Icons.numbers,
                        ),
                        _buildInfoRow(
                          'SWIFT Code',
                          _maskSensitive(
                            _extractBankDetails()!['swift_code']?.toString(),
                          ),
                          Icons.qr_code,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              final details = _extractBankDetails();
                              if (details != null) {
                                _showEditBankDetailsDialog(details);
                              }
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit'),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  _buildActionButton(
                    label: 'Edit Profile',
                    icon: Icons.edit,
                    onTap: () {
                      Navigator.pushNamed(context, '/edit-profile');
                    },
                  ),

                  const SizedBox(height: 24),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _logout(context),
                      icon: const Icon(Icons.logout, size: 20),
                      label: const Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          bottomNavigationBar: OwnerBottomNavBar(
            currentIndex: 3,
            verificationStatus: loungeOwner?.verificationStatus,
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case 'pending':
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFF57C00);
        label = 'Pending Approval';
        icon = Icons.hourglass_empty;
        break;
      case 'rejected':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        label = 'Rejected';
        icon = Icons.cancel;
        break;
      case 'approved':
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        label = 'Verified';
        icon = Icons.verified;
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        label = status;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
