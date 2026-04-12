import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io';
import 'package:lounge_owner_app/config/theme_config.dart';
import '../../presentation/providers/registration_provider.dart';
import '../../presentation/widgets/location_picker_widget.dart';
import '../../domain/entities/lounge.dart';
import '../../domain/entities/lounge_route.dart';
import '../../core/di/injection_container.dart';
import '../../data/datasources/lounge_owner_remote_datasource.dart';
import '../../data/datasources/route_remote_datasource.dart';
import '../../data/models/route_model.dart';

/// Screen for adding a NEW lounge (existing owner, skips business info)
/// This is different from the registration flow - only shows lounge details
class AddLoungeScreen extends StatefulWidget {
  const AddLoungeScreen({super.key});

  @override
  State<AddLoungeScreen> createState() => _AddLoungeScreenState();
}

class _AddLoungeScreenState extends State<AddLoungeScreen> {
  final _formKey = GlobalKey<FormState>();

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

  // Lounge Details Controllers
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

  // Location
  double? _selectedLatitude;
  double? _selectedLongitude;

  // Amenities
  final List<String> _selectedAmenities = [];

  // Photos
  final List<File> _loungePhotos = [];

  // Routes
  final List<Map<String, dynamic>> _selectedRoutes = [];

  // District selection
  late LoungeOwnerRemoteDataSource _loungeOwnerRemoteDataSource;
  List<Map<String, dynamic>> _districts = [];
  String? _selectedDistrictId;
  bool _isLoadingDistricts = true;
  String? _districtsError;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loungeOwnerRemoteDataSource =
        InjectionContainer().loungeOwnerRemoteDataSource;
    _loadDistricts();
    // Reset provider state for new lounge
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<RegistrationProvider>(
        context,
        listen: false,
      );
      provider.clearLoungePhotos();
      provider.clearRoutes();
    });
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _districts = [];
        _isLoadingDistricts = false;
        _districtsError = 'Failed to load districts';
      });
    }
  }

  @override
  void dispose() {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Lounge'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lounge Details',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add a new lounge to your portfolio',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),

                      // Photo Section
                      _buildPhotoSection(),
                      const SizedBox(height: 20),

                      // Basic Info
                      _buildBasicInfoSection(),
                      const SizedBox(height: 24),

                      // Location Section
                      _buildLocationSection(),
                      const SizedBox(height: 24),

                      // Pricing Section
                      _buildPricingSection(),
                      const SizedBox(height: 24),

                      // Routes Section
                      _buildRoutesSection(),
                      const SizedBox(height: 24),

                      // Amenities Section
                      _buildAmenitiesSection(),
                      const SizedBox(height: 24),

                      // Validation messages
                      _buildValidationMessages(),
                    ],
                  ),
                ),
              ),
            ),

            // Submit Button
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
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitLounge,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Add Lounge',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCameraCard(
          title: 'Add Lounge Photos (${_loungePhotos.length}/5)',
          icon: Icons.photo_camera,
          onTap: _loungePhotos.length < 5 ? _pickLoungePhotos : null,
        ),
        const SizedBox(height: 16),
        if (_loungePhotos.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _loungePhotos.length,
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_loungePhotos[index], fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _loungePhotos.removeAt(index);
                        });
                      },
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
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _loungeNameController,
          decoration: InputDecoration(
            labelText: 'Lounge Name *',
            hintText: 'Enter lounge name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: 'Description',
            hintText: 'Brief description of your lounge',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.description),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: 'Address *',
            hintText: 'Enter complete address',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
        if (_isLoadingDistricts)
          Container(
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
          )
        else if (_districtsError != null)
          Container(
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
          )
        else
          DropdownButtonFormField<String>(
            value: _selectedDistrictId,
            decoration: InputDecoration(
              labelText: 'District *',
              hintText: 'Select lounge district',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.map_outlined),
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
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedProvince,
                decoration: InputDecoration(
                  labelText: 'State/Province',
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
                  labelText: 'Postal Code',
                  hintText: 'e.g., 10100',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _contactPhoneController,
          decoration: InputDecoration(
            labelText: 'Contact Phone *',
            hintText: '+94771234567',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
        TextFormField(
          controller: _capacityController,
          decoration: InputDecoration(
            labelText: 'Maximum Capacity *',
            hintText: 'e.g., 50',
            helperText: 'Maximum number of people',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
      ],
    );
  }

  Widget _buildLocationSection() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: _selectedLatitude == null ? Colors.red : Colors.grey[300]!,
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
                'Lat: ${_selectedLatitude!.toStringAsFixed(6)}, '
                'Lng: ${_selectedLongitude!.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 12),
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
                  });
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPricingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        TextFormField(
          controller: _price1HourController,
          decoration: InputDecoration(
            labelText: '1 Hour Price *',
            hintText: '500.00',
            prefixText: 'LKR ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _price2HoursController,
          decoration: InputDecoration(
            labelText: '2 Hours Price *',
            hintText: '900.00',
            prefixText: 'LKR ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _price3HoursController,
          decoration: InputDecoration(
            labelText: '3 Hours Price *',
            hintText: '1200.00',
            prefixText: 'LKR ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _priceUntilBusController,
          decoration: InputDecoration(
            labelText: 'Price Until Bus Arrives *',
            hintText: '1500.00',
            prefixText: 'LKR ',
            helperText: 'Flexible pricing for bus arrival wait',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildRoutesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Routes Served',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Add at least one route that your lounge serves.',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        if (_selectedRoutes.isNotEmpty)
          ...(_selectedRoutes.asMap().entries.map((entry) {
            final index = entry.key;
            final route = entry.value;
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
        ElevatedButton.icon(
          onPressed: _showAddRouteDialog,
          icon: const Icon(Icons.add),
          label: const Text('Add Route'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildAmenitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  Widget _buildValidationMessages() {
    return Column(
      children: [
        if (_loungePhotos.isEmpty)
          _buildWarningBox(
            icon: Icons.info,
            color: Colors.orange,
            message:
                'Please add at least 1 photo of your lounge (maximum 5 photos)',
          ),
        if (_selectedAmenities.isEmpty)
          _buildWarningBox(
            icon: Icons.warning,
            color: Colors.orange,
            message: 'Please select at least one amenity',
          ),
        if (_selectedLatitude == null)
          _buildWarningBox(
            icon: Icons.error,
            color: Colors.red,
            message: 'Please select your lounge location on the map',
          ),
        if (_selectedRoutes.isEmpty)
          _buildWarningBox(
            icon: Icons.warning,
            color: Colors.orange,
            message: 'Please add at least one route',
          ),
      ],
    );
  }

  Widget _buildWarningBox({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: color.withOpacity(0.9)),
            ),
          ),
        ],
      ),
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
          border: Border.all(color: Colors.grey[300]!, width: 2),
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
                    'Tap to add photos',
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

  Future<void> _pickLoungePhotos() async {
    final picker = ImagePicker();

    try {
      final images = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      for (var image in images) {
        if (_loungePhotos.length >= 5) {
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
        setState(() {
          _loungePhotos.add(file);
        });
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

  Future<void> _submitLounge() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate district selection (UUID from /api/v1/districts)
    if (_selectedDistrictId == null || _selectedDistrictId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a district'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate photos
    if (_loungePhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least 1 photo of your lounge'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate location
    if (_selectedLatitude == null || _selectedLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your lounge location on the map'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate amenities
    if (_selectedAmenities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one amenity'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate routes
    if (_selectedRoutes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one route'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final registrationProvider = Provider.of<RegistrationProvider>(
        context,
        listen: false,
      );
      final storageService = InjectionContainer().supabaseStorageService;

      // Generate lounge ID for photo upload
      final loungeId = DateTime.now().millisecondsSinceEpoch.toString();

      // Upload photos to Supabase
      print('📍 AddLoungeScreen - Uploading ${_loungePhotos.length} photos...');
      final photoUrls = await storageService.uploadMultipleLoungePhotos(
        imageFiles: _loungePhotos,
        loungeId: loungeId,
      );
      print('✅ AddLoungeScreen - Photos uploaded: $photoUrls');

      // Convert routes to LoungeRoute objects
      final routes = _selectedRoutes
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
          .toList();

      // Save lounge data to provider
      registrationProvider.saveLoungeData(
        loungeName: _loungeNameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        district: _selectedDistrictId,
        state: _selectedProvince,
        postalCode: _postalCodeController.text.trim().isEmpty
            ? null
            : _postalCodeController.text.trim(),
        latitude: _selectedLatitude!,
        longitude: _selectedLongitude!,
        contactPhone: _contactPhoneController.text.trim(),
        capacity: int.parse(_capacityController.text.trim()),
        price1Hour: _price1HourController.text.trim(),
        price2Hours: _price2HoursController.text.trim(),
        price3Hours: _price3HoursController.text.trim(),
        priceUntilBus: _priceUntilBusController.text.trim(),
        amenities: _selectedAmenities,
        routes: routes,
      );

      // Submit to backend
      final success = await registrationProvider.submitLounge(
        photoUrls: photoUrls,
      );

      if (success) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Dialog(
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
                    // Blue checkmark icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    Text(
                      'Lounge Added Successfully!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // Subtitle message
                    Text(
                      'Your new lounge has been created and is pending admin approval. '
                      'You\'ll be notified when it goes live.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // OK button
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
                        onPressed: () {
                          Navigator.of(context).pop();
                          // Go back to lounges list and refresh
                          Navigator.of(
                            context,
                          ).pop(true); // Return true to indicate success
                        },
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
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                registrationProvider.errorMessage ?? 'Failed to add lounge',
              ),
              backgroundColor: Colors.red,
            ),
          );
          registrationProvider.clearError();
        }
      }
    } catch (e) {
      print('❌ AddLoungeScreen - Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding lounge: $e'),
            backgroundColor: Colors.red,
          ),
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

  Future<void> _showAddRouteDialog() async {
    String? selectedRouteId;
    String? selectedStopBeforeId;
    String? selectedStopAfterId;
    List<MasterRouteStop> routeStops = [];
    bool loadingStops = false;
    bool loadingInitialRoutes = true;
    String searchQuery = '';
    List<MasterRoute> dialogRoutes = [];
    List<MasterRoute> allRoutes = [];

    Future<void> loadInitialRoutes(StateSetter setDialogState) async {
      try {
        final apiClient = InjectionContainer().apiClient;
        final routeDataSource = RouteRemoteDataSource(apiClient: apiClient);
        final routes = await routeDataSource.getMasterRoutes();

        allRoutes = routes;
        dialogRoutes = routes.take(5).toList();

        setDialogState(() {
          loadingInitialRoutes = false;
        });
      } catch (e) {
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

    void filterRoutes(String query, StateSetter setDialogState) {
      if (query.isEmpty) {
        setDialogState(() {
          dialogRoutes = allRoutes.take(5).toList();
        });
      } else {
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
                    const SizedBox(height: 16),
                    if (loadingInitialRoutes)
                      const Center(child: CircularProgressIndicator()),
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
                              setDialogState(() {
                                routeStops = stops;
                                loadingStops = false;
                              });
                            } catch (e) {
                              setDialogState(() => loadingStops = false);
                            }
                          }
                        },
                      ),
                    ],
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
                            child: Text('${stop.stopOrder}. ${stop.stopName}'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedStopBeforeId = value;
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
