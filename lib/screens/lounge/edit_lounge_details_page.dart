import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme_config.dart';
import '../../presentation/providers/registration_provider.dart';
import '../../domain/entities/lounge.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.initialLounge != null) {
        setState(() {
          _selectedLounge = widget.initialLounge;
          _populateForm(widget.initialLounge!);
        });

        final latest = await Provider.of<RegistrationProvider>(
          context,
          listen: false,
        ).getLoungeDetails(widget.initialLounge!.id);

        if (!mounted || latest == null) return;
        _syncSelectedLounge(latest);
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
    super.dispose();
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
  }

  Future<void> _loadSelectedLounge(Lounge lounge) async {
    setState(() {
      _selectedLounge = lounge;
      _populateForm(lounge);
    });

    final latest = await Provider.of<RegistrationProvider>(
      context,
      listen: false,
    ).getLoungeDetails(lounge.id);

    if (!mounted || latest == null) return;
    _syncSelectedLounge(latest);
  }

  void _syncSelectedLounge(Lounge latest) {
    final lounges =
        Provider.of<RegistrationProvider>(context, listen: false).myLounges;
    final matched = lounges.where((item) => item.id == latest.id).toList();
    final selected = matched.isNotEmpty ? matched.first : latest;

    setState(() {
      _selectedLounge = selected;
      _populateForm(selected);
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

    final updatedLounge = _selectedLounge!.copyWith(
      loungeName: _loungeNameCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      contactPhone: _contactPhoneCtrl.text.trim(),
      latitude: _latitudeCtrl.text.trim(),
      longitude: _longitudeCtrl.text.trim(),
      capacity: int.tryParse(_capacityCtrl.text.trim()),
      price1Hour: _nullableText(_price1HourCtrl),
      price2Hours: _nullableText(_price2HourCtrl),
      price3Hours: _nullableText(_price3HourCtrl),
      priceUntilBus: _nullableText(_priceUntilBusCtrl),
      description: _nullableText(_descriptionCtrl),
    );

    final success = await registrationProvider.updateLoungeDetails(
      updatedLounge,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lounge details updated successfully!'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      Navigator.pop(context, true);
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
                            'Modify your lounge details',
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
}
