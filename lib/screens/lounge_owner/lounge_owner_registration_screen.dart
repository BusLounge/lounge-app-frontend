import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io';
import 'package:lounge_owner_app/config/theme_config.dart';
import '../../presentation/providers/lounge_owner_provider.dart';
import '../../presentation/providers/registration_provider.dart';
import '../../presentation/widgets/location_picker_widget.dart';
import '../../domain/entities/lounge.dart';
import '../../domain/entities/lounge_route.dart';
import '../../core/di/injection_container.dart';
import '../../data/datasources/lounge_owner_remote_datasource.dart';
import '../../data/datasources/route_remote_datasource.dart';
import '../../data/models/route_model.dart';

class LoungeOwnerRegistrationScreen extends StatefulWidget {
  final String userId;
  final String? phoneNumber; // New user phone
  final String? otp; // New user OTP

  const LoungeOwnerRegistrationScreen({
    super.key,
    required this.userId,
    this.phoneNumber,
    this.otp,
  });

  @override
  State<LoungeOwnerRegistrationScreen> createState() =>
      _LoungeOwnerRegistrationScreenState();
}

class _LoungeOwnerRegistrationScreenState
    extends State<LoungeOwnerRegistrationScreen> {
  final List<String> _steps = [
    'Business & Manager',
    'Review & Submit',
  ];

  static const List<String> _sriLankanProvinces = [
    'Western',
    'Central',
    'Southern',
    'Northern',
    'Eastern',
    'North Western',
    'North Central',
    'Uva',
    'Sabaragamuwa',
  ];

  // Form keys
  final _businessInfoFormKey = GlobalKey<FormState>();
  final _loungeDetailsFormKey = GlobalKey<FormState>();

  // Step 1 fields - Business & Manager Info
  final _businessNameController = TextEditingController();
  final _businessLicenseController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _managerFullNameController = TextEditingController();
  final _managerNicNumberController = TextEditingController();
  final _managerEmailController = TextEditingController();

  // Step 3 fields
  final _loungeNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  String? _selectedProvince;
  final _postalCodeController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _capacityController = TextEditingController();
  final _price1HourController = TextEditingController();
  final _price2HoursController = TextEditingController();
  final _price3HoursController = TextEditingController();
  final _priceUntilBusController = TextEditingController();

  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _selectedAddress;
  String? _selectedDistrictId;
  final List<String> _selectedAmenities = [];

  late LoungeOwnerRemoteDataSource _loungeOwnerRemoteDataSource;
  List<Map<String, dynamic>> _districts = [];
  bool _isLoadingDistricts = true;
  String? _districtsError;

  // Route selection
  bool _loadingRoutes = false;
  // Each selected route stores: {routeId, stopBeforeId, stopAfterId, routeNumber, routeDisplay, stopBeforeName, stopAfterName}
  final List<Map<String, dynamic>> _selectedRoutes = [];

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessLicenseController.dispose();
    _businessAddressController.dispose();
    _managerFullNameController.dispose();
    _managerNicNumberController.dispose();
    _managerEmailController.dispose();
    _loungeNameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _postalCodeController.dispose();
    _contactPhoneController.dispose();
    _capacityController.dispose();
    _price1HourController.dispose();
    _price2HoursController.dispose();
    _price3HoursController.dispose();
    _priceUntilBusController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loungeOwnerRemoteDataSource =
        InjectionContainer().loungeOwnerRemoteDataSource;
    _loadDistricts();
    // Don't load routes on init - load only when user searches
  }

  Future<void> _loadDistricts() async {
    setState(() {
      _isLoadingDistricts = true;
      _districtsError = null;
    });

    try {
      final districts = await _loungeOwnerRemoteDataSource.getAllDistricts();
      if (!mounted) return;
      setState(() {
        _districts = districts;
        _isLoadingDistricts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _districts = [];
        _isLoadingDistricts = false;
        _districtsError = 'Failed to load districts';
      });
    }
  }

  String? _selectedDistrictName() {
    if (_selectedDistrictId == null || _selectedDistrictId!.isEmpty) {
      return null;
    }

    for (final district in _districts) {
      if (district['id'] == _selectedDistrictId) {
        final name = district['district']?.toString().trim();
        if (name != null && name.isNotEmpty) {
          return name;
        }
      }
    }

    return _selectedDistrictId;
  }

  Widget _buildDistrictSelector() {
    if (_isLoadingDistricts) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Loading districts...'),
          ],
        ),
      );
    }

    if (_districtsError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _districtsError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: _loadDistricts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedDistrictId,
      decoration: InputDecoration(
        labelText: 'District *',
        hintText: 'Select your district',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        prefixIcon: const Icon(Icons.location_city),
      ),
      items: _districts.map((district) {
        final id = district['id'] as String? ?? '';
        final name = district['district'] as String? ?? '';
        return DropdownMenuItem<String>(
          value: id,
          child: Text(name),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedDistrictId = value;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a district';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loungeOwnerProvider = Provider.of<LoungeOwnerProvider>(context);
    final registrationProvider = Provider.of<RegistrationProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lounge Owner Registration'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.grey[100],
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_steps.length, (index) {
                      return Expanded(
                        child: Column(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index <= registrationProvider.currentStep
                                    ? AppColors.primary
                                    : Colors.grey[300],
                              ),
                              child: Center(
                                child: index < registrationProvider.currentStep
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 20,
                                      )
                                    : Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: index ==
                                                  registrationProvider
                                                      .currentStep
                                              ? Colors.white
                                              : Colors.grey[600],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _steps[index],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                color: index <= registrationProvider.currentStep
                                    ? AppColors.primary
                                    : Colors.grey[600],
                                fontWeight:
                                    index == registrationProvider.currentStep
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value:
                        (registrationProvider.currentStep + 1) / _steps.length,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildStepContent(),
              ),
            ),

            // Navigation Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (registrationProvider.currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: loungeOwnerProvider.isLoading ||
                                registrationProvider.isLoading
                            ? null
                            : () {
                                registrationProvider.previousStep();
                              },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppColors.primary),
                        ),
                        child: const Text('Previous'),
                      ),
                    ),
                  if (registrationProvider.currentStep > 0)
                    const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: loungeOwnerProvider.isLoading ||
                              registrationProvider.isLoading
                          ? null
                          : () => _handleNextButton(
                                context,
                                loungeOwnerProvider,
                                registrationProvider,
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: loungeOwnerProvider.isLoading ||
                              registrationProvider.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              registrationProvider.currentStep <
                                      _steps.length - 1
                                  ? 'Next'
                                  : 'Submit',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    final registrationProvider = Provider.of<RegistrationProvider>(
      context,
      listen: false,
    );
    switch (registrationProvider.currentStep) {
      case 0:
        return _buildBusinessInfoStep();
      case 1:
        return _buildOwnerReviewStep();
      case 2:
        return _buildLoungeDetailsStep();
      case 3:
        return _buildReviewStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildOwnerReviewStep() {
    final registrationProvider = Provider.of<RegistrationProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review & Submit',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Please verify your details before submitting.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),
        _buildReviewSection(
          title: 'Business & Manager Information',
          icon: Icons.business,
          items: [
            'Business Name: ${registrationProvider.businessName ?? 'N/A'}',
            'Business License: ${registrationProvider.businessLicense?.isNotEmpty == true ? registrationProvider.businessLicense : 'N/A'}',
            'Manager Name: ${registrationProvider.managerFullName ?? 'N/A'}',
            'Manager NIC: ${registrationProvider.managerNicNumber ?? 'N/A'}',
            'Manager Email: ${registrationProvider.managerEmail?.isNotEmpty == true ? registrationProvider.managerEmail : 'N/A'}',
            'District: ${_selectedDistrictName() ?? 'N/A'}',
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'If everything is correct, press Submit. If not, press Previous to edit details.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green[900],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessInfoStep() {
    return Form(
      key: _businessInfoFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Business Information',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          TextFormField(
            controller: _businessNameController,
            decoration: InputDecoration(
              labelText: 'Business/Hotel Name',
              hintText: 'Enter your business or hotel name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.business),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Business name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _businessLicenseController,
            decoration: InputDecoration(
              labelText: 'Business License (Optional)',
              hintText: 'Enter business registration number',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.badge),
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'Manager Information',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _managerFullNameController,
            decoration: InputDecoration(
              labelText: 'Manager Full Name',
              hintText: 'Enter manager full legal name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Manager name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _managerNicNumberController,
            decoration: InputDecoration(
              labelText: 'Manager NIC Number',
              hintText: 'Enter NIC (9+V or 12 digits)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.credit_card),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Manager NIC is required';
              }
              final nicRegex = RegExp(r'^\d{9}[vVxX]$|^\d{12}$');
              if (!nicRegex.hasMatch(value.trim())) {
                return 'Invalid NIC format';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _managerEmailController,
            decoration: InputDecoration(
              labelText: 'Manager Email (Optional)',
              hintText: 'Enter manager email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegex.hasMatch(value.trim())) {
                  return 'Invalid email format';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildDistrictSelector(),
        ],
      ),
    );
  }

  // NIC verification step and camera capture methods removed - admin will verify manually

  Widget _buildLoungeDetailsStep() {
    final registrationProvider = Provider.of<RegistrationProvider>(context);

    return Form(
      key: _loungeDetailsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lounge Details',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us about your lounge',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 30),

          // Lounge Photos
          _buildCameraCard(
            title: 'Add Lounge Photos (${registrationProvider.photoCount}/5)',
            icon: Icons.photo_camera,
            onTap: registrationProvider.canAddMorePhotos
                ? _pickLoungePhotos
                : null,
          ),
          const SizedBox(height: 16),

          // Photo Grid
          if (registrationProvider.photoCount > 0)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: registrationProvider.photoCount,
              itemBuilder: (context, index) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        registrationProvider.loungePhotos[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () =>
                            registrationProvider.removeLoungePhoto(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: 20),

          // Lounge Name
          TextFormField(
            controller: _loungeNameController,
            decoration: InputDecoration(
              labelText: 'Lounge Name *',
              hintText: 'Enter lounge name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.store),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Lounge name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Description
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Description',
              hintText: 'Brief description of your lounge',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.description),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // Address
          TextFormField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: 'Address *',
              hintText: 'Enter complete address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.location_on),
            ),
            maxLines: 2,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Address is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // State and Postal Code Row
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedProvince,
                  decoration: InputDecoration(
                    labelText: 'State/Province *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: _sriLankanProvinces
                      .map(
                        (province) => DropdownMenuItem<String>(
                          value: province,
                          child: Text(province),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedProvince = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Province is required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _postalCodeController,
                  decoration: InputDecoration(
                    labelText: 'Postal Code *',
                    hintText: 'e.g., 10100',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Postal code is required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // District Dropdown
          _buildDistrictSelector(),
          const SizedBox(height: 16),

          // Google Maps Location Picker
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color:
                    _selectedLatitude == null ? Colors.red : Colors.grey[300]!,
                width: _selectedLatitude == null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: const Icon(Icons.map, color: AppColors.primary),
              title: Text(
                _selectedLatitude == null
                    ? 'Select Location on Map *'
                    : 'Location Selected',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _selectedLatitude == null ? Colors.red : Colors.black,
                ),
              ),
              subtitle: _selectedLatitude != null
                  ? Text(
                      _selectedAddress?.isNotEmpty == true
                          ? _selectedAddress!
                          : 'Lat: ${_selectedLatitude!.toStringAsFixed(6)}, '
                              'Lng: ${_selectedLongitude!.toStringAsFixed(6)}',
                      style: TextStyle(fontSize: 12),
                    )
                  : const Text('Tap to open map and select lounge location'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LocationPickerWidget(
                      initialLocation: _selectedLatitude != null
                          ? LatLng(_selectedLatitude!, _selectedLongitude!)
                          : null,
                      onLocationSelected: (location, address) {
                        setState(() {
                          _selectedLatitude = location.latitude;
                          _selectedLongitude = location.longitude;
                          _selectedAddress = address;
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Contact Phone
          TextFormField(
            controller: _contactPhoneController,
            decoration: InputDecoration(
              labelText: 'Contact Phone *',
              hintText: '+94771234567',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Contact phone is required';
              }
              final phonePattern = RegExp(r'^\+?\d{10,15}$');
              if (!phonePattern.hasMatch(value.trim().replaceAll(' ', ''))) {
                return 'Invalid phone number (10-15 digits)';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Capacity
          TextFormField(
            controller: _capacityController,
            decoration: InputDecoration(
              labelText: 'Maximum Capacity *',
              hintText: 'e.g., 50',
              helperText: 'Maximum number of people',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.people),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Capacity is required';
              }
              final capacity = int.tryParse(value);
              if (capacity == null || capacity <= 0) {
                return 'Capacity must be greater than 0';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Pricing Section
          const Text(
            'Pricing (LKR)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Set your lounge pricing tiers',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          // Price 1 Hour
          TextFormField(
            controller: _price1HourController,
            decoration: InputDecoration(
              labelText: '1 Hour Price *',
              hintText: '500.00',
              prefixText: 'LKR ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.attach_money),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '1 hour price is required';
              }
              final price = double.tryParse(value);
              if (price == null || price < 0) {
                return 'Invalid price';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Price 2 Hours
          TextFormField(
            controller: _price2HoursController,
            decoration: InputDecoration(
              labelText: '2 Hours Price *',
              hintText: '900.00',
              prefixText: 'LKR ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.attach_money),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '2 hours price is required';
              }
              final price = double.tryParse(value);
              if (price == null || price < 0) {
                return 'Invalid price';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Price 3 Hours
          TextFormField(
            controller: _price3HoursController,
            decoration: InputDecoration(
              labelText: '3 Hours Price *',
              hintText: '1200.00',
              prefixText: 'LKR ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.attach_money),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '3 hours price is required';
              }
              final price = double.tryParse(value);
              if (price == null || price < 0) {
                return 'Invalid price';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Price Until Bus
          TextFormField(
            controller: _priceUntilBusController,
            decoration: InputDecoration(
              labelText: 'Price Until Bus Arrives *',
              hintText: '1500.00',
              prefixText: 'LKR ',
              helperText: 'Flexible pricing for bus arrival wait',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.attach_money),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Until bus price is required';
              }
              final price = double.tryParse(value);
              if (price == null || price < 0) {
                return 'Invalid price';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Routes Section
          const Text(
            'Routes Served',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Add at least one route that your lounge serves. Select the route and two consecutive stops where your lounge is located between.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),

          // Selected Routes List
          if (_selectedRoutes.isNotEmpty)
            ...(_selectedRoutes.asMap().entries.map((entry) {
              final index = entry.key;
              final route = entry.value;
              // Use stored display data instead of looking up from _masterRoutes
              final routeNumber = route['routeNumber'] as String? ?? 'Route';
              final routeDisplay = route['routeDisplay'] as String? ?? '';
              final stopBeforeName =
                  route['stopBeforeName'] as String? ?? 'Unknown';
              final stopAfterName =
                  route['stopAfterName'] as String? ?? 'Unknown';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text('$routeNumber: $routeDisplay'),
                  subtitle: Text('Between: $stopBeforeName → $stopAfterName'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _selectedRoutes.removeAt(index);
                      });
                    },
                  ),
                ),
              );
            })),

          // Add Route Button
          ElevatedButton.icon(
            onPressed: _loadingRoutes ? null : () => _showAddRouteDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Route'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),

          if (_selectedRoutes.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please add at least one route',
                      style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Amenities Section
          const Text(
            'Amenities & Facilities',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Select available amenities (at least 1 required)',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),

          // Amenities Checkboxes
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedAmenities.isEmpty
                    ? Colors.orange
                    : Colors.grey[300]!,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: LoungeAmenities.allCodes.map((code) {
                return CheckboxListTile(
                  value: _selectedAmenities.contains(code),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedAmenities.add(code);
                      } else {
                        _selectedAmenities.remove(code);
                      }
                    });
                  },
                  title: Text(LoungeAmenities.labels[code] ?? code),
                  secondary: Icon(
                    LoungeAmenities.icons[code] ?? Icons.check_circle_outline,
                    color: _selectedAmenities.contains(code)
                        ? AppColors.primary
                        : Colors.grey,
                  ),
                  dense: true,
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // Validation Messages
          if (!registrationProvider.hasMinimumPhotos)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please add at least 1 photo of your lounge (maximum 5 photos)',
                      style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
            ),

          if (_selectedAmenities.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please select at least one amenity',
                      style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
            ),

          if (_selectedLatitude == null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please select your lounge location on the map',
                      style: TextStyle(fontSize: 13, color: Colors.red[900]),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final registrationProvider = Provider.of<RegistrationProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review & Submit',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Please review your information before submitting',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 30),
        _buildReviewSection(
          title: 'Business & Manager Information',
          icon: Icons.business,
          items: [
            'Business Name: ${registrationProvider.businessName ?? 'N/A'}',
            'Business License: ${registrationProvider.businessLicense ?? 'N/A'}',
            'Manager: ${registrationProvider.managerFullName ?? 'N/A'}',
            'Manager NIC: ${registrationProvider.managerNicNumber ?? 'N/A'}',
            'Manager Email: ${registrationProvider.managerEmail ?? 'N/A'}',
          ],
        ),
        const SizedBox(height: 20),

        // NIC Verification step removed - admin will verify manually
        _buildReviewSection(
          title: 'Lounge Details',
          icon: Icons.store,
          items: [
            'Lounge Name: ${registrationProvider.loungeName ?? 'N/A'}',
            'Address: ${registrationProvider.address ?? 'N/A'}',
            'District: ${registrationProvider.district ?? 'N/A'}',
            'Contact Phone: ${registrationProvider.contactPhone ?? 'N/A'}',
            'Capacity: ${registrationProvider.capacity ?? 'N/A'} people',
            'Location: ${_selectedLatitude != null ? 'Selected' : 'Not selected'}',
            'Photos: ${registrationProvider.photoCount} uploaded',
            'Amenities: ${registrationProvider.amenities.length} selected',
            '\nPricing:',
            '  • 1 Hour: LKR ${registrationProvider.price1Hour ?? '0.00'}',
            '  • 2 Hours: LKR ${registrationProvider.price2Hours ?? '0.00'}',
            '  • 3 Hours: LKR ${registrationProvider.price3Hours ?? '0.00'}',
            '  • Until Bus: LKR ${registrationProvider.priceUntilBus ?? '0.00'}',
          ],
        ),
        const SizedBox(height: 20),

        // Routes Section
        _buildReviewSection(
          title: 'Routes Served',
          icon: Icons.directions_bus,
          items: _selectedRoutes.isEmpty
              ? ['No routes selected']
              : _selectedRoutes.map((route) {
                  final routeNumber =
                      route['routeNumber'] as String? ?? 'Route';
                  final routeDisplay = route['routeDisplay'] as String? ?? '';
                  final stopBeforeName =
                      route['stopBeforeName'] as String? ?? 'Unknown';
                  final stopAfterName =
                      route['stopAfterName'] as String? ?? 'Unknown';
                  return '$routeNumber: $routeDisplay\n  Between: $stopBeforeName → $stopAfterName';
                }).toList(),
        ),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Everything looks good! Click Submit to complete your registration.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green[900],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCameraCard({
    required String title,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: onTap == null ? Colors.grey[300]! : Colors.grey[300]!,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color: onTap == null ? Colors.grey[100] : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to open camera',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.camera_alt, color: Colors.grey[400], size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection({
    required String title,
    required IconData icon,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 8),
              child: Text(
                item,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLoungePhotos() async {
    final picker = ImagePicker();
    final registrationProvider = Provider.of<RegistrationProvider>(
      context,
      listen: false,
    );

    try {
      final images = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      for (var image in images) {
        if (!registrationProvider.canAddMorePhotos) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Maximum 5 photos allowed'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          break;
        }

        final file = File(image.path);
        registrationProvider.addLoungePhoto(file);
      }

      if (mounted && images.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${images.length} photo(s) added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleNextButton(
    BuildContext context,
    LoungeOwnerProvider loungeOwnerProvider,
    RegistrationProvider registrationProvider,
  ) async {
    switch (registrationProvider.currentStep) {
      case 0:
        await _handleStep1Next(registrationProvider);
        break;
      case 1:
        await _submitOwnerRegistration(context, loungeOwnerProvider);
        break;
      case 2:
        await _handleStep2Next(
          registrationProvider,
          InjectionContainer().supabaseStorageService,
        );
        break;
      case 3:
        await _submitRegistration(context);
        break;
    }
  }

  Future<void> _handleStep1Next(
    RegistrationProvider registrationProvider,
  ) async {
    if (!_businessInfoFormKey.currentState!.validate()) {
      return;
    }

    print('📍 Screen - Step 1: Saving business info locally...');
    // Save to provider only - backend submission happens in Step 3
    registrationProvider.saveBusinessInfoData(
      businessName: _businessNameController.text.trim(),
      businessLicense: _businessLicenseController.text.trim(),
      businessAddress: _businessAddressController.text.trim().isEmpty
          ? null
          : _businessAddressController.text.trim(),
      managerFullName: _managerFullNameController.text.trim(),
      managerNicNumber: _managerNicNumberController.text.trim(),
      managerEmail: _managerEmailController.text.trim(),
    );

    final district = _selectedDistrictId;
    if (district == null || district.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a district'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    print('✅ Screen - Step 1: Business info saved locally, moving to review');
    registrationProvider.nextStep();
  }

  Future<void> _submitOwnerRegistration(
    BuildContext context,
    LoungeOwnerProvider loungeOwnerProvider,
  ) async {
    final registrationProvider = Provider.of<RegistrationProvider>(
      context,
      listen: false,
    );

    final district = _selectedDistrictId;
    if (district == null || district.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a district'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final success = await loungeOwnerProvider.saveBusinessInfo(
      businessName: registrationProvider.businessName ?? '',
      businessLicense: registrationProvider.businessLicense ?? '',
      managerFullName: registrationProvider.managerFullName ?? '',
      managerNicNumber: registrationProvider.managerNicNumber ?? '',
      managerEmail: registrationProvider.managerEmail ?? '',
      districtId: district,
    );

    if (success) {
      if (mounted) {
        registrationProvider.reset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration completed successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loungeOwnerProvider.errorMessage ??
                  'Failed to save business information',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // OLD STEP 2 (NIC Verification) REMOVED - Now handled in Step 1 if needed

  Future<void> _handleStep2Next(
    RegistrationProvider registrationProvider,
    dynamic storageService,
  ) async {
    // Step 2 -> Step 3 (Review): Just validate and save locally, don't submit yet
    if (!_loungeDetailsFormKey.currentState!.validate()) {
      return;
    }

    if (!registrationProvider.hasMinimumPhotos) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least 1 photo of your lounge'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (_selectedLatitude == null || _selectedLongitude == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select your lounge location on the map'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_selectedAmenities.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one amenity'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (_selectedRoutes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one route'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Just save lounge data to provider (don't submit to backend yet)
    print('📍 Screen - Saving lounge data to provider for review...');
    registrationProvider.saveLoungeData(
      loungeName: _loungeNameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      address: _addressController.text.trim(),
      state: _selectedProvince,
      postalCode: _postalCodeController.text.trim().isEmpty
          ? null
          : _postalCodeController.text.trim(),
      district: _selectedDistrictId,
      latitude: _selectedLatitude!,
      longitude: _selectedLongitude!,
      contactPhone: _contactPhoneController.text.trim(),
      capacity: int.parse(_capacityController.text.trim()),
      price1Hour: _price1HourController.text.trim(),
      price2Hours: _price2HoursController.text.trim(),
      price3Hours: _price3HoursController.text.trim(),
      priceUntilBus: _priceUntilBusController.text.trim(),
      amenities: _selectedAmenities,
      routes: _selectedRoutes
          .map(
            (r) => LoungeRoute(
              id: '',
              loungeId: '',
              masterRouteId: r['routeId'],
              stopBeforeId: r['stopBeforeId'],
              stopAfterId: r['stopAfterId'],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          )
          .toList(),
    );

    // Move to review step - actual submission happens on Submit button
    print('✅ Screen - Moving to Review step...');
    registrationProvider.nextStep();
  }

  Future<void> _submitRegistration(BuildContext context) async {
    final registrationProvider = Provider.of<RegistrationProvider>(
      context,
      listen: false,
    );
    final loungeOwnerProvider = Provider.of<LoungeOwnerProvider>(
      context,
      listen: false,
    );
    final storageService = InjectionContainer().supabaseStorageService;

    try {
      print('📍 Screen - Starting final submission process...');

      // Step 1: Save business info to backend
      print('📍 Screen - Saving business info to backend...');
      final businessInfoSuccess = await loungeOwnerProvider.saveBusinessInfo(
        businessName: registrationProvider.businessName ?? '',
        businessLicense: registrationProvider.businessLicense ?? '',
        managerFullName: registrationProvider.managerFullName ?? '',
        managerNicNumber: registrationProvider.managerNicNumber ?? '',
        managerEmail: registrationProvider.managerEmail ?? '',
        districtId: registrationProvider.district ?? '',
      );

      if (!businessInfoSuccess) {
        print(
          '❌ Screen - Failed to save business info: ${loungeOwnerProvider.errorMessage}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                loungeOwnerProvider.errorMessage ??
                    'Failed to save business information',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      print('✅ Screen - Business info saved successfully');

      // Step 2: Generate lounge ID and upload photos
      final loungeId = DateTime.now().millisecondsSinceEpoch.toString();
      print('📍 Screen - Generated lounge ID: $loungeId');

      print(
        '📍 Screen - Uploading ${registrationProvider.loungePhotos.length} photos to Supabase...',
      );
      final photoUrls = await storageService.uploadMultipleLoungePhotos(
        imageFiles: registrationProvider.loungePhotos,
        loungeId: loungeId,
      );
      print('✅ Screen - Photos uploaded successfully: $photoUrls');

      // Step 3: Submit lounge to backend
      print('📍 Screen - Submitting lounge to backend...');
      final success = await registrationProvider.submitLounge(
        photoUrls: photoUrls,
      );

      print('📍 Screen - Submit result: $success');

      if (success) {
        print('✅ Screen - Registration complete!');
        if (mounted) {
          // Force reload lounges data before navigating
          await registrationProvider.loadMyLounges();

          // Navigate to dashboard
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        print('❌ Screen - Submit failed: ${registrationProvider.errorMessage}');
        final errorMessage = registrationProvider.errorMessage ?? '';

        // Check if it's an approval pending error
        if (errorMessage.contains('not approved') ||
            errorMessage.contains('not_verified') ||
            errorMessage.contains('approval')) {
          // Save lounge data for later submission after approval
          print(
              '📍 Screen - Account pending approval, saving lounge data locally');
          registrationProvider.savePendingLounge(photoUrls);

          if (mounted) {
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Registration saved! Your lounge will be submitted after account approval.',
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 4),
              ),
            );

            // Navigate to dashboard
            await registrationProvider.loadMyLounges();
            Navigator.of(context).pushReplacementNamed('/home');
          }
        } else {
          // Other errors - show error message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  registrationProvider.errorMessage ??
                      'Failed to create lounge',
                ),
                backgroundColor: Colors.red,
              ),
            );
            registrationProvider.clearError();
          }
        }
      }
    } catch (e) {
      print('❌ Screen - Exception caught: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating lounge: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddRouteDialog() async {
    String? selectedRouteId;
    String? selectedStopBeforeId;
    String? selectedStopAfterId;
    List<MasterRouteStop> routeStops = [];
    bool loadingStops = false;
    bool loadingInitialRoutes = true;
    String searchQuery = '';
    List<MasterRoute> dialogRoutes = [];
    List<MasterRoute> allRoutes = []; // Store all fetched routes for filtering

    // Function to load initial routes
    Future<void> loadInitialRoutes(StateSetter setDialogState) async {
      try {
        final apiClient = InjectionContainer().apiClient;
        final routeDataSource = RouteRemoteDataSource(apiClient: apiClient);
        final routes = await routeDataSource.getMasterRoutes();
        print('📍 Dialog - Loaded ${routes.length} master routes');

        allRoutes = routes;
        // Show first 5 routes initially (like Google search suggestions)
        dialogRoutes = routes.take(5).toList();

        setDialogState(() {
          loadingInitialRoutes = false;
        });
      } catch (e) {
        print('❌ Dialog - Failed to load routes: $e');
        setDialogState(() {
          loadingInitialRoutes = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to load routes: $e')));
        }
      }
    }

    // Function to filter routes based on search query
    void filterRoutes(String query, StateSetter setDialogState) {
      if (query.isEmpty) {
        // Show first 5 routes when search is empty
        setDialogState(() {
          dialogRoutes = allRoutes.take(5).toList();
        });
      } else {
        // Filter routes by query
        final filtered = allRoutes
            .where((route) {
              final q = query.toLowerCase();
              return route.routeNumber.toLowerCase().contains(q) ||
                  route.routeName.toLowerCase().contains(q) ||
                  route.originCity.toLowerCase().contains(q) ||
                  route.destinationCity.toLowerCase().contains(q);
            })
            .take(5)
            .toList();

        setDialogState(() {
          dialogRoutes = filtered;
        });
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Load initial routes when dialog first builds
          if (loadingInitialRoutes && allRoutes.isEmpty) {
            loadInitialRoutes(setDialogState);
          }

          return AlertDialog(
            title: const Text('Add Route'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Field
                    const Text(
                      'Search Route',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: 'Type route number or city name...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  searchQuery = '';
                                  filterRoutes('', setDialogState);
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        searchQuery = value;
                        filterRoutes(value, setDialogState);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Showing top 5 matching routes',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),

                    // Loading indicator for initial routes
                    if (loadingInitialRoutes)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 8),
                              Text('Loading routes...'),
                            ],
                          ),
                        ),
                      ),

                    // Route Selection Dropdown
                    if (!loadingInitialRoutes && dialogRoutes.isNotEmpty) ...[
                      const Text(
                        'Select Route',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedRouteId,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Choose a route',
                        ),
                        isExpanded: true,
                        items: dialogRoutes.map((route) {
                          return DropdownMenuItem(
                            value: route.id,
                            child: Text(
                              '${route.routeNumber}: ${route.routeDisplay}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) async {
                          setDialogState(() {
                            selectedRouteId = value;
                            selectedStopBeforeId = null;
                            selectedStopAfterId = null;
                            routeStops = [];
                            loadingStops = true;
                          });

                          if (value != null) {
                            try {
                              final apiClient = InjectionContainer().apiClient;
                              final routeDataSource = RouteRemoteDataSource(
                                apiClient: apiClient,
                              );
                              final stops = await routeDataSource.getRouteStops(
                                value,
                              );
                              print(
                                '📍 Dialog - Loaded ${stops.length} stops for route $value',
                              );
                              setDialogState(() {
                                routeStops = stops;
                                loadingStops = false;
                              });
                            } catch (e) {
                              print('❌ Dialog - Failed to load stops: $e');
                              setDialogState(() => loadingStops = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to load stops: $e'),
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                    ],

                    if (!loadingInitialRoutes && dialogRoutes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          searchQuery.isEmpty
                              ? 'No routes available'
                              : 'No routes matching "$searchQuery"',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),

                    if (loadingStops)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),

                    if (routeStops.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Stop Before Lounge',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'The stop passengers pass BEFORE reaching your lounge',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedStopBeforeId,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Select stop before',
                        ),
                        isExpanded: true,
                        items: routeStops.map((stop) {
                          return DropdownMenuItem(
                            value: stop.id,
                            child: Text(
                              '${stop.stopOrder}. ${stop.stopName}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedStopBeforeId = value;
                            // Reset after stop if before changes
                            if (selectedStopAfterId != null) {
                              final beforeIndex = routeStops.indexWhere(
                                (s) => s.id == value,
                              );
                              final afterIndex = routeStops.indexWhere(
                                (s) => s.id == selectedStopAfterId,
                              );
                              if (afterIndex <= beforeIndex) {
                                selectedStopAfterId = null;
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Stop After Lounge',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'The stop passengers reach AFTER passing your lounge',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedStopAfterId,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Select stop after',
                        ),
                        isExpanded: true,
                        items: routeStops.where((stop) {
                          if (selectedStopBeforeId == null) return true;
                          final beforeIndex = routeStops.indexWhere(
                            (s) => s.id == selectedStopBeforeId,
                          );
                          final currentIndex = routeStops.indexWhere(
                            (s) => s.id == stop.id,
                          );
                          return currentIndex > beforeIndex;
                        }).map((stop) {
                          return DropdownMenuItem(
                            value: stop.id,
                            child: Text(
                              '${stop.stopOrder}. ${stop.stopName}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedStopAfterId = value);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: (selectedRouteId != null &&
                        selectedStopBeforeId != null &&
                        selectedStopAfterId != null)
                    ? () {
                        // Find the selected route and stops to store their display names
                        final selectedRoute = dialogRoutes.firstWhere(
                          (r) => r.id == selectedRouteId,
                          orElse: () => allRoutes.firstWhere(
                            (r) => r.id == selectedRouteId,
                          ),
                        );
                        final stopBefore = routeStops.firstWhere(
                          (s) => s.id == selectedStopBeforeId,
                        );
                        final stopAfter = routeStops.firstWhere(
                          (s) => s.id == selectedStopAfterId,
                        );

                        setState(() {
                          _selectedRoutes.add({
                            'routeId': selectedRouteId!,
                            'stopBeforeId': selectedStopBeforeId!,
                            'stopAfterId': selectedStopAfterId!,
                            // Store display names for showing in list
                            'routeNumber': selectedRoute.routeNumber,
                            'routeDisplay': selectedRoute.routeDisplay,
                            'stopBeforeName': stopBefore.stopName,
                            'stopAfterName': stopAfter.stopName,
                          });
                        });
                        Navigator.pop(context);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }
}
