import 'dart:io';

import 'package:flutter/material.dart';
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
import '../../data/datasources/supabase_storage_service.dart';

class EditLoungeDetailsPage extends StatefulWidget {
  final Lounge? initialLounge;

  const EditLoungeDetailsPage({super.key, this.initialLounge});

  @override
  State<EditLoungeDetailsPage> createState() => _EditLoungeDetailsPageState();
}

class _EditLoungeDetailsPageState extends State<EditLoungeDetailsPage> {
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
  final _stateCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();

  late LoungeOwnerRemoteDataSource _loungeOwnerRemoteDataSource;
  late SupabaseStorageService _supabaseStorageService;
  List<Map<String, dynamic>> _districts = [];
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
    _supabaseStorageService = InjectionContainer().supabaseStorageService;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadDistricts();

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
    _stateCtrl.dispose();
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
    _stateCtrl.text = lounge.state ?? '';
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
            'routeNumber': route.masterRouteId,
            'routeDisplay': route.masterRouteId,
            'stopBeforeName': route.stopBeforeId,
            'stopAfterName': route.stopAfterId,
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
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate() || _selectedLounge == null) {
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
      state: _nullableText(_stateCtrl),
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

  @override
  Widget build(BuildContext context) {
    const Color pageBg = Color(0xFFFFFBF5);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: Colors.black87,
          ),
        ),
        title: const Text(
          'Edit Lounge Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<RegistrationProvider>(
        builder: (context, registrationProvider, child) {
          final lounges = registrationProvider.myLounges;
          final matchingSelectedLounges = _selectedLounge == null
              ? <Lounge>[]
              : lounges
                  .where((item) => item.id == _selectedLounge!.id)
                  .toList();
          final dropdownSelectedLounge = matchingSelectedLounges.isNotEmpty
              ? matchingSelectedLounges.first
              : null;

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
                              Icons.edit_location_alt,
                              size: 48,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Update Lounge Information',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Current values are prefilled below. Edit only what needs changing.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    if (_selectedLounge != null) ...[
                      _buildCurrentValuesCard(_selectedLounge!),
                      const SizedBox(height: 24),
                    ],

                    if (widget.initialLounge == null) ...[
                      const Text(
                        'Select Lounge',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: DropdownButtonFormField<Lounge>(
                          value: dropdownSelectedLounge,
                          items: lounges.map((lounge) {
                            return DropdownMenuItem<Lounge>(
                              value: lounge,
                              child: Text(
                                lounge.loungeName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          }).toList(),
                          decoration: InputDecoration(
                            hintText: 'Choose a lounge to edit',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            prefixIcon: const Icon(
                              Icons.business,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            isDense: true,
                          ),
                          icon: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          onChanged: (lounge) {
                            if (lounge != null) {
                              _loadSelectedLounge(lounge);
                            }
                          },
                          validator: (v) =>
                              v == null ? 'Please select a lounge' : null,
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.business,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedLounge?.loungeName ??
                                    widget.initialLounge!.loungeName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_selectedLounge != null) ...[
                      const SizedBox(height: 32),

                      // Basic Information
                      const Text(
                        'Basic Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _loungeNameCtrl,
                        decoration: _inputDecoration(
                          'Lounge Name',
                          Icons.store_outlined,
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Please enter lounge name'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _addressCtrl,
                        decoration: _inputDecoration(
                          'Address',
                          Icons.location_on_outlined,
                        ),
                        textCapitalization: TextCapitalization.words,
                        maxLines: 2,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Please enter address'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _stateCtrl,
                        decoration: _inputDecoration(
                          'State / Province',
                          Icons.map_outlined,
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _postalCodeCtrl,
                        decoration: _inputDecoration(
                          'Postal Code',
                          Icons.markunread_mailbox_outlined,
                        ),
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 16),

                      if (_isLoadingDistricts)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
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
                            border:
                                Border.all(color: Colors.red.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.red),
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
                          decoration: _inputDecoration(
                            'District',
                            Icons.location_city_outlined,
                          ),
                          items: _districtDropdownItems(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDistrictId = value;
                            });
                          },
                        ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _contactPhoneCtrl,
                        decoration: _inputDecoration(
                          'Contact Phone',
                          Icons.phone_outlined,
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Please enter contact phone'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _latitudeCtrl,
                        decoration: _inputDecoration(
                          'Latitude',
                          Icons.place_outlined,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Please enter latitude'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _longitudeCtrl,
                        decoration: _inputDecoration(
                          'Longitude',
                          Icons.place,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Please enter longitude'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _capacityCtrl,
                        decoration: _inputDecoration(
                          'Capacity (People)',
                          Icons.people_outline,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Please enter capacity'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _descriptionCtrl,
                        decoration: _inputDecoration(
                          'Description',
                          Icons.description_outlined,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 3,
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'Amenities, Images & Routes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildAmenitiesSelector(),

                      const SizedBox(height: 16),

                      _buildImagesSection(),

                      const SizedBox(height: 16),

                      _buildSelectedRoutesEditor(),
                      const SizedBox(height: 8),
                      Text(
                        'Use Add Route to select route and stops',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Pricing Information
                      const Text(
                        'Pricing (LKR)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _price1HourCtrl,
                        decoration: _inputDecoration(
                          '1 Hour Price',
                          Icons.access_time,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Please enter price'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _price2HourCtrl,
                        decoration: _inputDecoration(
                          '2 Hour Price',
                          Icons.more_time,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _price3HourCtrl,
                        decoration: _inputDecoration(
                          '3 Hour Price',
                          Icons.schedule,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _priceUntilBusCtrl,
                        decoration: _inputDecoration(
                          'Until Bus Price',
                          Icons.directions_bus,
                        ),
                        keyboardType: TextInputType.number,
                      ),

                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            shadowColor: AppColors.primary.withOpacity(0.3),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  String? _nullableText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
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

  String? _districtNameForId(String? districtId) {
    if (districtId == null || districtId.isEmpty) return null;
    final match = _districts.where((d) => d['id'] == districtId).toList();
    if (match.isNotEmpty) {
      return match.first['district'] as String?;
    }
    return districtId;
  }

  Widget _buildSelectedRoutesEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedRoutes.isNotEmpty)
          ..._selectedRoutes.asMap().entries.map((entry) {
            final index = entry.key;
            final route = entry.value;
            final routeNumber = route['routeNumber'] as String? ?? 'Route';
            final routeDisplay = route['routeDisplay'] as String? ?? '';
            final stopBeforeName =
                route['stopBeforeName'] as String? ?? route['stopBeforeId'];
            final stopAfterName =
                route['stopAfterName'] as String? ?? route['stopAfterId'];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text('$routeNumber: $routeDisplay'),
                subtitle: Text('Between: $stopBeforeName -> $stopAfterName'),
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

  Widget _buildCurrentValuesCard(Lounge lounge) {
    final routes = lounge.routes ?? const [];
    final amenities = lounge.amenities ?? const [];
    final images = lounge.images ?? const [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Saved Values',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _summaryRow('Lounge Name', lounge.loungeName),
          _summaryRow('Description', lounge.description),
          _summaryRow('Address', lounge.address),
          _summaryRow('District', _districtNameForId(lounge.district)),
          _summaryRow('State / Province', lounge.state),
          _summaryRow('Postal Code', lounge.postalCode),
          _summaryRow('Contact', lounge.contactPhone),
          _summaryRow('Max Capacity', lounge.capacity?.toString()),
          _summaryRow(
            'Location',
            '${lounge.latitude ?? 'Not provided'}, ${lounge.longitude ?? 'Not provided'}',
          ),
          _summaryRow('Price 1 Hour', lounge.price1Hour),
          _summaryRow('Price 2 Hours', lounge.price2Hours),
          _summaryRow('Price 3 Hours', lounge.price3Hours),
          _summaryRow('Price Until Bus', lounge.priceUntilBus),
          _summaryRow('Route Count', routes.length.toString()),
          _summaryRow('Amenities Count', amenities.length.toString()),
          _summaryRow('Image Count', images.length.toString()),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              (value == null || value.trim().isEmpty) ? 'Not provided' : value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenitiesSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color:
              _selectedAmenities.isEmpty ? Colors.orange : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
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
    );
  }

  Widget _buildImagesSection() {
    final allImageSources = [
      ..._existingImageUrls.map((url) => _ImageSource.network(url)),
      ..._newImageFiles.map((file) => _ImageSource.file(file)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Lounge Images',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _pickNewImages,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add Image'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Current images are shown as previews. Add new ones from your device.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        if (allImageSources.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              'No images available yet.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          )
        else
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
                    borderRadius: BorderRadius.circular(10),
                    child: source.isNetwork
                        ? Image.network(
                            source.value,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          )
                        : Image.file(
                            source.file!,
                            fit: BoxFit.cover,
                          ),
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
                                (file) => file.path == source.file!.path);
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
