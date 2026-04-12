import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/theme_config.dart';
import '../../core/di/injection_container.dart';
import '../../data/datasources/lounge_owner_remote_datasource.dart';
import '../../data/datasources/route_remote_datasource.dart';
import '../../domain/entities/lounge.dart';
import '../../domain/entities/lounge_route.dart';
import '../../data/models/route_model.dart';
import '../../presentation/providers/registration_provider.dart';
import '../../presentation/widgets/location_picker_widget.dart';
import '../../data/datasources/supabase_storage_service.dart';

class EditLoungeDetailsPage extends StatefulWidget {
  final Lounge? initialLounge;

  const EditLoungeDetailsPage({super.key, this.initialLounge});

  @override
  State<EditLoungeDetailsPage> createState() => _EditLoungeDetailsPageState();
}

class _EditLoungeDetailsPageState extends State<EditLoungeDetailsPage> {
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

  Lounge? _selectedLounge;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isLoadingLounge = true;

  final _loungeNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _latitudeCtrl = TextEditingController();
  final _longitudeCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _price1HourCtrl = TextEditingController();
  final _price2HourCtrl = TextEditingController();
  final _price3HourCtrl = TextEditingController();
  final _priceUntilBusCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String? _selectedProvince;
  final _postalCodeCtrl = TextEditingController();

  late LoungeOwnerRemoteDataSource _loungeOwnerRemoteDataSource;
  late RouteRemoteDataSource _routeRemoteDataSource;
  late SupabaseStorageService _supabaseStorageService;
  List<Map<String, dynamic>> _districts = [];
  List<MasterRoute> _masterRoutes = [];
  final Map<String, List<MasterRouteStop>> _routeStopsByRouteId = {};
  String? _selectedDistrictId;
  bool _isLoadingDistricts = false;
  String? _districtsError;

  final List<Map<String, dynamic>> _selectedRoutes = [];
  final List<String> _selectedAmenities = [];
  final List<String> _existingImageUrls = [];
  final List<File> _newImageFiles = [];

  @override
  void initState() {
    super.initState();
    _loungeOwnerRemoteDataSource =
        InjectionContainer().loungeOwnerRemoteDataSource;
    _routeRemoteDataSource = RouteRemoteDataSource(
      apiClient: InjectionContainer().apiClient,
    );
    _supabaseStorageService = InjectionContainer().supabaseStorageService;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadDistricts();
      await _loadRoutes();

      if (widget.initialLounge != null) {
        final latest = await Provider.of<RegistrationProvider>(
          context,
          listen: false,
        ).getLoungeDetails(widget.initialLounge!.id);

        if (!mounted) return;

        setState(() {
          _selectedLounge = latest ?? widget.initialLounge;
          _populateForm(_selectedLounge!);
          _isLoadingLounge = false;
        });
        await _hydrateSelectedRouteNames();
      } else {
        setState(() {
          _isLoadingLounge = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _loungeNameCtrl.dispose();
    _addressCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _latitudeCtrl.dispose();
    _longitudeCtrl.dispose();
    _capacityCtrl.dispose();
    _price1HourCtrl.dispose();
    _price2HourCtrl.dispose();
    _price3HourCtrl.dispose();
    _priceUntilBusCtrl.dispose();
    _descriptionCtrl.dispose();
    _postalCodeCtrl.dispose();
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

  void _populateForm(Lounge lounge) {
    _loungeNameCtrl.text = lounge.loungeName;
    _addressCtrl.text = lounge.address;
    _contactPhoneCtrl.text = lounge.contactPhone ?? '';
    _latitudeCtrl.text = lounge.latitude ?? '';
    _longitudeCtrl.text = lounge.longitude ?? '';
    _capacityCtrl.text = lounge.capacity?.toString() ?? '';
    _price1HourCtrl.text = lounge.price1Hour?.toString() ?? '';
    _price2HourCtrl.text = lounge.price2Hours?.toString() ?? '';
    _price3HourCtrl.text = lounge.price3Hours?.toString() ?? '';
    _priceUntilBusCtrl.text = lounge.priceUntilBus?.toString() ?? '';
    _descriptionCtrl.text = lounge.description ?? '';
    final province = lounge.state?.trim();
    _selectedProvince =
        (province == null || province.isEmpty) ? null : province;
    _postalCodeCtrl.text = lounge.postalCode ?? '';
    _selectedDistrictId = lounge.district;
    _selectedAmenities
      ..clear()
      ..addAll(lounge.amenities ?? const []);
    _existingImageUrls
      ..clear()
      ..addAll(lounge.images ?? const []);
    _newImageFiles.clear();

    _selectedRoutes
      ..clear()
      ..addAll(
        (lounge.routes ?? const []).map(
          (route) => {
            'routeId': route.masterRouteId,
            'stopBeforeId': route.stopBeforeId,
            'stopAfterId': route.stopAfterId,
            'routeNumber':
                _masterRouteForId(route.masterRouteId)?.routeNumber ?? 'Route',
            'routeDisplay':
                _masterRouteForId(route.masterRouteId)?.routeDisplay ??
                    'Route details unavailable',
            'routeName':
                _masterRouteForId(route.masterRouteId)?.routeName ?? 'Route',
            'stopBeforeName':
                _stopNameForId(route.masterRouteId, route.stopBeforeId) ??
                    'Unknown stop',
            'stopAfterName':
                _stopNameForId(route.masterRouteId, route.stopAfterId) ??
                    'Unknown stop',
          },
        ),
      );
  }

  Future<void> _loadSelectedLounge(Lounge lounge) async {
    setState(() {
      _isLoadingLounge = true;
    });

    final latest = await Provider.of<RegistrationProvider>(
      context,
      listen: false,
    ).getLoungeDetails(lounge.id);

    if (!mounted) return;

    setState(() {
      _selectedLounge = latest ?? lounge;
      _populateForm(_selectedLounge!);
      _isLoadingLounge = false;
    });
    await _hydrateSelectedRouteNames();
  }

  Future<void> _hydrateSelectedRouteNames() async {
    if (_selectedRoutes.isEmpty) return;

    bool changed = false;
    for (final route in _selectedRoutes) {
      final routeId = route['routeId'] as String?;
      if (routeId == null || routeId.isEmpty) continue;

      if (!_routeStopsByRouteId.containsKey(routeId)) {
        try {
          _routeStopsByRouteId[routeId] =
              await _routeRemoteDataSource.getRouteStops(routeId);
        } catch (_) {
          _routeStopsByRouteId[routeId] = const [];
        }
      }

      final stopBeforeId = route['stopBeforeId'] as String?;
      final stopAfterId = route['stopAfterId'] as String?;
      final resolvedBefore = _stopNameForId(routeId, stopBeforeId);
      final resolvedAfter = _stopNameForId(routeId, stopAfterId);

      if (resolvedBefore != null && route['stopBeforeName'] != resolvedBefore) {
        route['stopBeforeName'] = resolvedBefore;
        changed = true;
      }
      if (resolvedAfter != null && route['stopAfterName'] != resolvedAfter) {
        route['stopAfterName'] = resolvedAfter;
        changed = true;
      }
    }

    if (changed && mounted) {
      setState(() {});
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate() || _selectedLounge == null) {
      return;
    }

    if (_latitudeCtrl.text.trim().isEmpty ||
        _longitudeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select the lounge location on the map'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final registrationProvider = Provider.of<RegistrationProvider>(
      context,
      listen: false,
    );

    if (_selectedRoutes.isEmpty) {
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please add at least one route',
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final parsedRoutes = _selectedRoutes
        .map(
          (route) => LoungeRoute(
            masterRouteId: route['routeId'] as String,
            stopBeforeId: route['stopBeforeId'] as String,
            stopAfterId: route['stopAfterId'] as String,
          ),
        )
        .toList();

    List<String> finalImageUrls = List<String>.from(_existingImageUrls);
    if (_newImageFiles.isNotEmpty) {
      final loungeId = _selectedLounge!.id.isNotEmpty
          ? _selectedLounge!.id
          : DateTime.now().millisecondsSinceEpoch.toString();
      final uploadedUrls =
          await _supabaseStorageService.uploadMultipleLoungePhotos(
        imageFiles: _newImageFiles,
        loungeId: loungeId,
      );
      finalImageUrls.addAll(uploadedUrls);
    }

    if (finalImageUrls.isEmpty) {
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please keep at least one image or upload a new one'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final updatedLounge = _selectedLounge!.copyWith(
      loungeName: _loungeNameCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      state: _selectedProvince,
      postalCode: _nullableText(_postalCodeCtrl),
      district: _selectedDistrictId,
      contactPhone: _contactPhoneCtrl.text.trim(),
      latitude: _latitudeCtrl.text.trim(),
      longitude: _longitudeCtrl.text.trim(),
      capacity: int.tryParse(_capacityCtrl.text.trim()),
      price1Hour: _nullableText(_price1HourCtrl),
      price2Hours: _nullableText(_price2HourCtrl),
      price3Hours: _nullableText(_price3HourCtrl),
      priceUntilBus: _nullableText(_priceUntilBusCtrl),
      description: _nullableText(_descriptionCtrl),
      amenities: List<String>.from(_selectedAmenities),
      images: finalImageUrls,
      routes: parsedRoutes,
    );

    final success = await registrationProvider.updateLoungeDetails(
      updatedLounge,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (success) {
      await _showSuccessDialog(
        title: 'Lounge Details Updated!',
        message: 'Your lounge details have been updated successfully.',
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          registrationProvider.errorMessage ??
              'Failed to update lounge details',
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  LatLng? _initialMapLocationFromControllers() {
    final latitude = double.tryParse(_latitudeCtrl.text.trim());
    final longitude = double.tryParse(_longitudeCtrl.text.trim());
    if (latitude == null || longitude == null) return null;
    return LatLng(latitude, longitude);
  }

  Widget _buildMapLocationSelector() {
    final latitude = double.tryParse(_latitudeCtrl.text.trim());
    final longitude = double.tryParse(_longitudeCtrl.text.trim());
    final hasLocation = latitude != null && longitude != null;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: hasLocation ? Colors.grey.shade300 : Colors.red,
          width: hasLocation ? 1 : 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: const Icon(Icons.map, color: AppColors.primary),
        title: Text(
          hasLocation ? 'Location Selected' : 'Select Location on Map *',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: hasLocation ? Colors.black87 : Colors.red,
          ),
        ),
        subtitle: hasLocation
            ? Text(
                'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 12),
              )
            : const Text('Tap to open map and select lounge location'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LocationPickerWidget(
                initialLocation: _initialMapLocationFromControllers(),
                onLocationSelected: (location, address) {
                  setState(() {
                    _latitudeCtrl.text = location.latitude.toString();
                    _longitudeCtrl.text = location.longitude.toString();
                  });
                },
              ),
            ),
          );
        },
      ),
    );
  }

  int get _totalImagesCount =>
      _existingImageUrls.length + _newImageFiles.length;

  Widget _buildLoungeSelectorCard(
    RegistrationProvider registrationProvider,
  ) {
    if (widget.initialLounge != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.store, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedLounge?.loungeName ?? widget.initialLounge!.loungeName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    final lounges = registrationProvider.myLounges;
    final matchingSelectedLounges = _selectedLounge == null
        ? <Lounge>[]
        : lounges.where((item) => item.id == _selectedLounge!.id).toList();
    final dropdownSelectedLounge = matchingSelectedLounges.isNotEmpty
        ? matchingSelectedLounges.first
        : null;

    return DropdownButtonFormField<Lounge>(
      value: dropdownSelectedLounge,
      decoration: InputDecoration(
        labelText: 'Select Lounge *',
        hintText: 'Choose a lounge to edit',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.store),
      ),
      items: lounges.map((lounge) {
        return DropdownMenuItem<Lounge>(
          value: lounge,
          child: Text(lounge.loungeName),
        );
      }).toList(),
      onChanged: (lounge) {
        if (lounge != null) {
          _loadSelectedLounge(lounge);
        }
      },
      validator: (v) => v == null ? 'Please select a lounge' : null,
    );
  }

  Widget _buildPhotoSection() {
    final allImageSources = [
      ..._existingImageUrls.map((url) => _ImageSource.network(url)),
      ..._newImageFiles.map((file) => _ImageSource.file(file)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCameraCard(
          title: 'Add Lounge Photos ($_totalImagesCount/5)',
          icon: Icons.photo_camera,
          onTap: _totalImagesCount < 5 ? _pickNewImages : null,
        ),
        const SizedBox(height: 16),
        if (allImageSources.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allImageSources.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final source = allImageSources[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: source.isNetwork
                        ? Image.network(
                            source.value,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          )
                        : Image.file(source.file!, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (source.isNetwork) {
                            _existingImageUrls.remove(source.value);
                          } else {
                            _newImageFiles.removeWhere(
                              (file) => file.path == source.file!.path,
                            );
                          }
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
          controller: _loungeNameCtrl,
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
          controller: _descriptionCtrl,
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
          controller: _addressCtrl,
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
              border: Border.all(color: Colors.grey.shade300),
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
                    onPressed: _loadDistricts, child: const Text('Retry')),
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
            items: _districtDropdownItems(),
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
                items: _provinceDropdownValues()
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
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _postalCodeCtrl,
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
          controller: _contactPhoneCtrl,
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
          controller: _capacityCtrl,
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
          controller: _price1HourCtrl,
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
          controller: _price2HourCtrl,
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
          controller: _price3HourCtrl,
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
          controller: _priceUntilBusCtrl,
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
        _buildSelectedRoutesEditor(),
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
                  : Colors.grey.shade300,
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
        if (_totalImagesCount == 0)
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
        if (_initialMapLocationFromControllers() == null)
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
          border: Border.all(color: Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(12),
          color: onTap == null ? Colors.grey.shade100 : Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Lounge'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<RegistrationProvider>(
        builder: (context, registrationProvider, child) {
          final lounges = registrationProvider.myLounges;

          if (lounges.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.apartment_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Lounges Available',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please add a lounge first',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          if (_isLoadingLounge) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return SafeArea(
            child: Column(
              children: [
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
                            'Edit your lounge details. Current values are prefilled.',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 24),
                          _buildLoungeSelectorCard(registrationProvider),
                          const SizedBox(height: 20),
                          _buildPhotoSection(),
                          const SizedBox(height: 20),
                          _buildBasicInfoSection(),
                          const SizedBox(height: 24),
                          _buildMapLocationSelector(),
                          const SizedBox(height: 24),
                          _buildPricingSection(),
                          const SizedBox(height: 24),
                          _buildRoutesSection(),
                          const SizedBox(height: 24),
                          _buildAmenitiesSection(),
                          const SizedBox(height: 24),
                          _buildValidationMessages(),
                        ],
                      ),
                    ),
                  ),
                ),
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
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String? _nullableText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  List<String> _provinceDropdownValues() {
    final values = List<String>.from(_sriLankanProvinces);
    final selected = _selectedProvince?.trim();
    if (selected != null && selected.isNotEmpty && !values.contains(selected)) {
      values.insert(0, selected);
    }
    return values;
  }

  Future<void> _loadDistricts() async {
    if (!mounted) return;

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
        _districtsError = 'Failed to load districts';
        _isLoadingDistricts = false;
      });
    }
  }

  Future<void> _loadRoutes() async {
    if (!mounted) return;
    try {
      final routes = await _routeRemoteDataSource.getMasterRoutes();
      if (!mounted) return;
      setState(() {
        _masterRoutes = routes;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _masterRoutes = [];
      });
    }
  }

  List<DropdownMenuItem<String>> _districtDropdownItems() {
    final items = _districts.map((district) {
      final id = district['id'] as String? ?? '';
      final name = district['district'] as String? ?? '';
      return DropdownMenuItem<String>(
        value: id,
        child: Text(name),
      );
    }).toList();

    final selectedId = _selectedDistrictId;
    if (selectedId != null &&
        selectedId.isNotEmpty &&
        !_districts.any((d) => d['id'] == selectedId)) {
      items.insert(
        0,
        DropdownMenuItem<String>(
          value: selectedId,
          child: Text('Unknown district ($selectedId)'),
        ),
      );
    }

    return items;
  }

  MasterRoute? _masterRouteForId(String? routeId) {
    if (routeId == null || routeId.isEmpty) return null;
    try {
      return _masterRoutes.firstWhere((route) => route.id == routeId);
    } catch (_) {
      return null;
    }
  }

  String? _stopNameForId(String? routeId, String? stopId) {
    if (stopId == null || stopId.isEmpty) return null;
    if (routeId != null && _routeStopsByRouteId[routeId]?.isNotEmpty == true) {
      try {
        return _routeStopsByRouteId[routeId]!
            .firstWhere((stop) => stop.id == stopId)
            .stopName;
      } catch (_) {}
    }

    final masterRoute = _masterRouteForId(routeId);
    if (masterRoute == null) return null;

    try {
      return masterRoute.stops.firstWhere((stop) => stop.id == stopId).stopName;
    } catch (_) {
      return null;
    }
  }

  String _routeLabelForId(String? routeId) {
    final masterRoute = _masterRouteForId(routeId);
    if (masterRoute == null) {
      return 'Route details unavailable';
    }
    return '${masterRoute.routeNumber}: ${masterRoute.routeName} (${masterRoute.routeDisplay})';
  }

  Widget _buildSelectedRoutesEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedRoutes.isNotEmpty)
          ..._selectedRoutes.asMap().entries.map((entry) {
            final index = entry.key;
            final route = entry.value;
            final routeId = route['routeId'] as String?;
            final routeLabel = _routeLabelForId(routeId);
            final stopBeforeName = route['stopBeforeName'] as String? ??
                _stopNameForId(routeId, route['stopBeforeId'] as String?);
            final stopAfterName = route['stopAfterName'] as String? ??
                _stopNameForId(routeId, route['stopAfterId'] as String?);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(routeLabel),
                subtitle: Text(
                  'Between: ${stopBeforeName ?? 'Unknown stop'} -> ${stopAfterName ?? 'Unknown stop'}',
                ),
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
          }),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load routes: $e')),
          );
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
                              '${route.routeNumber}: ${route.routeName} (${route.routeDisplay})',
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
                            } catch (_) {
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
                            child: Text('${stop.stopOrder}. ${stop.stopName}'),
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
                            'routeName': selectedRoute.routeName,
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

  Future<void> _pickNewImages() async {
    final picker = ImagePicker();

    try {
      final images = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isEmpty) return;

      setState(() {
        for (final image in images) {
          if (_existingImageUrls.length + _newImageFiles.length >= 5) {
            break;
          }
          _newImageFiles.add(File(image.path));
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image(s) added successfully'),
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
}

class _ImageSource {
  final String value;
  final File? file;

  const _ImageSource.network(this.value) : file = null;
  const _ImageSource.file(this.file) : value = '';

  bool get isNetwork => file == null;
}
