import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/theme_config.dart';
import '../../core/di/injection_container.dart';
import '../../core/services/image_cache_service.dart';
import '../../domain/entities/lounge_product.dart';
import '../../presentation/providers/marketplace_provider.dart';

/// Screen for adding or editing a product
class ProductFormScreen extends StatefulWidget {
  final String loungeId;
  final String loungeName;
  final LoungeProduct? product; // null for add, provided for edit

  const ProductFormScreen({
    super.key,
    required this.loungeId,
    required this.loungeName,
    this.product,
  });

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  // Form controllers
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _discountedPriceController;
  late TextEditingController _displayOrderController;

  // Form values
  String? _selectedCategoryId;
  String _selectedPriceRateType = 'fixed';
  ProductType _productType = ProductType.product;
  ProductStockStatus _stockStatus = ProductStockStatus.inStock;
  bool _isAvailable = true;
  bool _isPreOrderable = false;
  bool _isVegetarian = false;
  bool _isVegan = false;
  bool _isHalal = false;
  bool _isFeatured = false;

  // Image
  File? _selectedImage;
  String? _existingImageUrl;
  bool _isUploadingImage = false;

  // Loading state
  bool _isSubmitting = false;

  bool get _isEditMode => widget.product != null;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadCategories();
  }

  void _initControllers() {
    final product = widget.product;

    _nameController = TextEditingController(text: product?.name ?? '');
    _descriptionController = TextEditingController(
      text: product?.description ?? '',
    );
    _priceController = TextEditingController(text: product?.price ?? '');
    _discountedPriceController = TextEditingController(
      text: product?.discountedPrice ?? '',
    );
    _displayOrderController = TextEditingController(
      text: (product?.displayOrder ?? 0).toString(),
    );

    if (product != null) {
      _selectedCategoryId = product.categoryId;
      _selectedPriceRateType = _toUiPriceRateType(product.priceRateType);
      _productType = product.productType;
      _stockStatus = product.stockStatus;
      _isAvailable = product.isAvailable;
      _isPreOrderable = product.isPreOrderable;
      _isVegetarian = product.isVegetarian;
      _isVegan = product.isVegan;
      _isHalal = product.isHalal;
      _isFeatured = product.isFeatured;
      _existingImageUrl = product.imageUrl;
    }
  }

  void _loadCategories() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<MarketplaceProvider>(context, listen: false);
      if (provider.categories.isEmpty) {
        provider.loadCategories();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _discountedPriceController.dispose();
    _displayOrderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Product' : 'Add Product'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image picker
              _buildImagePicker(),
              const SizedBox(height: AppSpacing.large),

              // Basic Information Section
              _buildSectionTitle('Basic Information'),
              const SizedBox(height: AppSpacing.medium),
              _buildNameField(),
              const SizedBox(height: AppSpacing.medium),
              _buildDescriptionField(),
              const SizedBox(height: AppSpacing.medium),
              _buildCategoryDropdown(),
              const SizedBox(height: AppSpacing.medium),
              _buildProductTypeDropdown(),

              const SizedBox(height: AppSpacing.large),

              // Pricing Section
              _buildSectionTitle('Pricing'),
              const SizedBox(height: AppSpacing.medium),
              _buildPriceRateTypeDropdown(enabled: _isServiceLikeCategory()),
              const SizedBox(height: AppSpacing.medium),
              Row(
                children: [
                  Expanded(child: _buildPriceField()),
                  const SizedBox(width: AppSpacing.medium),
                  Expanded(child: _buildDiscountedPriceField()),
                ],
              ),

              const SizedBox(height: AppSpacing.large),

              // Availability Section
              _buildSectionTitle('Availability'),
              const SizedBox(height: AppSpacing.medium),
              if (!_isServiceLikeCategory()) ...[
                _buildStockStatusDropdown(),
                const SizedBox(height: AppSpacing.medium),
              ],
              _buildSwitchTile(
                title: 'Available',
                subtitle: 'Product can be ordered by customers',
                value: _isAvailable,
                onChanged: (value) => setState(() => _isAvailable = value),
              ),
              if (!_isServiceLikeCategory())
                _buildSwitchTile(
                  title: 'Pre-orderable',
                  subtitle: 'Can be pre-ordered before travel',
                  value: _isPreOrderable,
                  onChanged: (value) => setState(() => _isPreOrderable = value),
                ),

              const SizedBox(height: AppSpacing.large),

              // Dietary Information Section
              if (!_isServiceLikeCategory()) ...[
                _buildSectionTitle('Dietary Information'),
                const SizedBox(height: AppSpacing.medium),
                _buildDietaryChips(),
              ],

              const SizedBox(height: AppSpacing.large),

              // Display Settings Section
              _buildSectionTitle('Display Settings'),
              const SizedBox(height: AppSpacing.medium),
              _buildDisplayOrderField(),
              const SizedBox(height: AppSpacing.medium),
              _buildSwitchTile(
                title: 'Featured',
                subtitle: 'Show in featured products section',
                value: _isFeatured,
                onChanged: (value) => setState(() => _isFeatured = value),
                activeColor: AppColors.accent,
              ),

              const SizedBox(height: AppSpacing.xLarge),

              // Submit Button
              _buildSubmitButton(),

              const SizedBox(height: AppSpacing.large),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: _isUploadingImage
            ? const Center(child: CircularProgressIndicator())
            : _buildImageContent(),
      ),
    );
  }

  Widget _buildImageContent() {
    if (_selectedImage != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(_selectedImage!, fit: BoxFit.cover),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() => _selectedImage = null),
              ),
            ),
          ),
        ],
      );
    }

    if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: OptimizedCachedImage(
              imageUrl: _existingImageUrl!,
              fit: BoxFit.cover,
              quality: 'sd',
              errorWidget: (_, __, ___) => _buildImagePlaceholder(),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: _pickImage,
              ),
            ),
          ),
        ],
      );
    }

    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 60,
          color: AppColors.textSecondary.withOpacity(0.5),
        ),
        const SizedBox(height: AppSpacing.small),
        const Text(
          'Tap to add product image',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Product Name *',
        hintText: 'e.g., Fresh Orange Juice',
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a product name';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Description',
        hintText: 'Describe your product...',
      ),
      maxLines: 3,
    );
  }

  Widget _buildCategoryDropdown() {
    return Consumer<MarketplaceProvider>(
      builder: (context, provider, _) {
        final categories = provider.categories;
        final hasSelectedCategory = categories.any(
          (category) => category.id == _selectedCategoryId,
        );
        final effectiveSelectedCategoryId = hasSelectedCategory
            ? _selectedCategoryId
            : null;

        return DropdownButtonFormField<String>(
          value: effectiveSelectedCategoryId,
          decoration: const InputDecoration(labelText: 'Category *'),
          items: categories.map((category) {
            return DropdownMenuItem<String>(
              value: category.id,
              child: Text(category.name),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCategoryId = value;

              final selectedCategory = categories.firstWhere(
                (category) => category.id == value,
                orElse: () => categories.first,
              );

              final forcedType = _forcedProductTypeForCategoryName(
                selectedCategory.name,
              );
              if (forcedType != null) {
                _productType = forcedType;
              } else {
                _selectedPriceRateType = 'fixed';
                _isPreOrderable = false;
                _isVegetarian = false;
                _isVegan = false;
                _isHalal = false;
                if (_productType == ProductType.service ||
                    _productType == ProductType.other) {
                  _productType = ProductType.product;
                }
              }
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a category';
            }
            return null;
          },
        );
      },
    );
  }

  Widget _buildProductTypeDropdown() {
    final forcedProductType = _forcedProductTypeForSelectedCategory();

    return DropdownButtonFormField<ProductType>(
      value: forcedProductType ?? _productType,
      decoration: const InputDecoration(labelText: 'Product Type'),
      items: ProductType.values.map((type) {
        return DropdownMenuItem<ProductType>(
          value: type,
          child: Text(_getProductTypeName(type)),
        );
      }).toList(),
      onChanged: forcedProductType != null
          ? null
          : (value) {
              if (value != null) {
                setState(() {
                  _productType = value;
                });
              }
            },
    );
  }

  String _getProductTypeName(ProductType type) {
    switch (type) {
      case ProductType.product:
        return 'Product (Food/Drink)';
      case ProductType.service:
        return 'Service';
      case ProductType.other:
        return 'Other';
      case ProductType.combo:
        return 'Combo Package';
    }
  }

  Widget _buildPriceField() {
    return TextFormField(
      controller: _priceController,
      decoration: const InputDecoration(
        labelText: 'Price (LKR) *',
        prefixText: 'LKR ',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Enter price';
        }
        final price = double.tryParse(value);
        if (price == null || price <= 0) {
          return 'Invalid price';
        }
        return null;
      },
    );
  }

  Widget _buildPriceRateTypeDropdown({required bool enabled}) {
    return DropdownButtonFormField<String>(
      value: _selectedPriceRateType,
      decoration: InputDecoration(
        labelText: 'Price Rate Type *',
        helperText: enabled
            ? null
            : 'Only enabled when category is Services or Electronics',
      ),
      items: const [
        DropdownMenuItem(value: 'hourly', child: Text('Hourly')),
        DropdownMenuItem(value: 'daily', child: Text('Daily')),
        DropdownMenuItem(value: 'fixed', child: Text('Fixed')),
      ],
      onChanged: enabled
          ? (value) {
              if (value != null) {
                setState(() {
                  _selectedPriceRateType = value;
                });
              }
            }
          : null,
      validator: (value) {
        if (!enabled) {
          return null;
        }
        if (value == null || value.isEmpty) {
          return 'Please select a rate type';
        }
        return null;
      },
    );
  }

  bool _isServiceLikeCategory() {
    final categoryId = _selectedCategoryId;
    if (categoryId == null || categoryId.isEmpty) {
      return false;
    }

    final provider = Provider.of<MarketplaceProvider>(context, listen: false);
    final matchedCategory = provider.categories.where(
      (c) => c.id == categoryId,
    );
    if (matchedCategory.isEmpty) {
      return false;
    }

    return _isServiceLikeCategoryName(matchedCategory.first.name);
  }

  ProductType? _forcedProductTypeForSelectedCategory() {
    final categoryId = _selectedCategoryId;
    if (categoryId == null || categoryId.isEmpty) {
      return null;
    }

    final provider = Provider.of<MarketplaceProvider>(context, listen: false);
    final matchedCategory = provider.categories.where(
      (c) => c.id == categoryId,
    );
    if (matchedCategory.isEmpty) {
      return null;
    }

    return _forcedProductTypeForCategoryName(matchedCategory.first.name);
  }

  ProductType? _forcedProductTypeForCategoryName(String categoryName) {
    if (_isElectronicsCategoryName(categoryName)) {
      return ProductType.other;
    }
    if (_isServiceCategoryName(categoryName)) {
      return ProductType.service;
    }
    return null;
  }

  bool _isServiceLikeCategoryName(String categoryName) {
    return _isServiceCategoryName(categoryName) ||
        _isElectronicsCategoryName(categoryName);
  }

  bool _isServiceCategoryName(String categoryName) {
    final normalizedName = categoryName.trim().toLowerCase();
    return normalizedName == 'service' || normalizedName == 'services';
  }

  bool _isElectronicsCategoryName(String categoryName) {
    final normalizedName = categoryName.trim().toLowerCase();
    return normalizedName == 'electronic item' ||
        normalizedName == 'electronic items' ||
        normalizedName == 'electronics' ||
        normalizedName == 'electronic';
  }

  String _toUiPriceRateType(String? backendValue) {
    switch ((backendValue ?? '').toLowerCase()) {
      case 'hourly_rate':
      case 'hourly':
        return 'hourly';
      case 'daily_rate':
      case 'daily':
        return 'daily';
      case 'fixed_rate':
      case 'fixed':
      default:
        return 'fixed';
    }
  }

  String _toBackendPriceRateType(String uiValue) {
    switch (uiValue) {
      case 'hourly':
        return 'hourly_rate';
      case 'daily':
        return 'daily_rate';
      case 'fixed':
      default:
        return 'fixed_rate';
    }
  }

  Widget _buildDiscountedPriceField() {
    return TextFormField(
      controller: _discountedPriceController,
      decoration: const InputDecoration(
        labelText: 'Sale Price',
        prefixText: 'LKR ',
        hintText: 'Optional',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return null; // Optional field
        }
        final discountedPrice = double.tryParse(value);
        final originalPrice = double.tryParse(_priceController.text);
        if (discountedPrice == null || discountedPrice <= 0) {
          return 'Invalid price';
        }
        if (originalPrice != null && discountedPrice >= originalPrice) {
          return 'Must be less than original';
        }
        return null;
      },
    );
  }

  Widget _buildStockStatusDropdown() {
    return DropdownButtonFormField<ProductStockStatus>(
      value: _stockStatus,
      decoration: const InputDecoration(labelText: 'Stock Status'),
      items: ProductStockStatus.values.map((status) {
        return DropdownMenuItem<ProductStockStatus>(
          value: status,
          child: Text(_getStockStatusName(status)),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _stockStatus = value;
          });
        }
      },
    );
  }

  String _getStockStatusName(ProductStockStatus status) {
    switch (status) {
      case ProductStockStatus.inStock:
        return 'In Stock';
      case ProductStockStatus.lowStock:
        return 'Low Stock';
      case ProductStockStatus.outOfStock:
        return 'Out of Stock';
      case ProductStockStatus.madeToOrder:
        return 'Made to Order';
    }
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color activeColor = AppColors.primary,
  }) {
    return Card(
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDietaryChips() {
    return Wrap(
      spacing: AppSpacing.small,
      runSpacing: AppSpacing.small,
      children: [
        _buildDietaryChip(
          label: 'Vegetarian',
          icon: Icons.eco,
          isSelected: _isVegetarian,
          onSelected: (value) => setState(() => _isVegetarian = value),
        ),
        _buildDietaryChip(
          label: 'Vegan',
          icon: Icons.grass,
          isSelected: _isVegan,
          onSelected: (value) => setState(() => _isVegan = value),
        ),
        _buildDietaryChip(
          label: 'Halal',
          icon: Icons.verified,
          isSelected: _isHalal,
          onSelected: (value) => setState(() => _isHalal = value),
        ),
      ],
    );
  }

  Widget _buildDietaryChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: AppColors.secondary,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
    );
  }

  Widget _buildDisplayOrderField() {
    return TextFormField(
      controller: _displayOrderController,
      decoration: const InputDecoration(
        labelText: 'Display Order',
        hintText: '0 = default order',
        helperText: 'Lower numbers appear first',
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSubmitting ? null : _submitForm,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.medium),
        backgroundColor: AppColors.primary,
      ),
      child: _isSubmitting
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              _isEditMode ? 'Update Product' : 'Add Product',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload image if selected
      String? imageUrl = _existingImageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage();
      }

      final isServiceLikeCategory = _isServiceLikeCategory();
      final forcedProductType = _forcedProductTypeForSelectedCategory();

      final product = LoungeProduct(
        id:
            widget.product?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        loungeId: widget.loungeId,
        categoryId: _selectedCategoryId!,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        productType: forcedProductType ?? _productType,
        price: _priceController.text.trim(),
        priceRateType: isServiceLikeCategory
            ? _toBackendPriceRateType(_selectedPriceRateType)
            : 'fixed_rate',
        discountedPrice: _discountedPriceController.text.trim().isEmpty
            ? null
            : _discountedPriceController.text.trim(),
        imageUrl: imageUrl,
        stockStatus: _stockStatus,
        isAvailable: _isAvailable,
        isPreOrderable: isServiceLikeCategory ? false : _isPreOrderable,
        isVegetarian: isServiceLikeCategory ? false : _isVegetarian,
        isVegan: isServiceLikeCategory ? false : _isVegan,
        isHalal: isServiceLikeCategory ? false : _isHalal,
        displayOrder: int.tryParse(_displayOrderController.text) ?? 0,
        isFeatured: _isFeatured,
        createdAt: widget.product?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final provider = Provider.of<MarketplaceProvider>(context, listen: false);

      LoungeProduct? result;
      if (_isEditMode) {
        result = await provider.updateProduct(product);
      } else {
        result = await provider.createProduct(product);
      }

      if (mounted) {
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditMode
                    ? 'Product updated successfully'
                    : 'Product added successfully',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.errorMessage ?? 'Failed to save product'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    setState(() => _isUploadingImage = true);

    try {
      final storageService = InjectionContainer().supabaseStorageService;
      return await storageService.uploadProductImage(
        imageFile: _selectedImage!,
        loungeId: widget.loungeId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }
}
