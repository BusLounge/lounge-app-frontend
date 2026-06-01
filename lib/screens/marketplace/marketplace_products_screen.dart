import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme_config.dart';
import '../../core/services/image_cache_service.dart';
import '../../domain/entities/lounge_product.dart';
import '../../presentation/providers/marketplace_provider.dart';
import 'product_form_screen.dart';

/// Screen for managing marketplace products for a lounge
class MarketplaceProductsScreen extends StatefulWidget {
  final String loungeId;
  final String loungeName;

  const MarketplaceProductsScreen({
    super.key,
    required this.loungeId,
    required this.loungeName,
  });

  @override
  State<MarketplaceProductsScreen> createState() =>
      _MarketplaceProductsScreenState();
}

class _MarketplaceProductsScreenState extends State<MarketplaceProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Load data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = Provider.of<MarketplaceProvider>(context, listen: false);
    await provider.loadAll(widget.loungeId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Consumer<MarketplaceProvider>(
        builder: (context, provider, child) {
          if (provider.state == MarketplaceState.loading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (provider.state == MarketplaceState.error) {
            return _buildErrorState(
              provider.errorMessage ?? 'An error occurred',
            );
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.primary,
            child: Column(
              children: [
                _buildSearchBar(),
                _buildCategoryFilter(provider),
                Expanded(child: _buildProductsList(provider)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddProduct(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Product',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Marketplace',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            widget.loungeName,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
          ),
        ],
      ),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: 'Search products...',
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(MarketplaceProvider provider) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: provider.categories.length + 1, // +1 for "All" option
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildCategoryChip(
              id: null,
              name: 'All',
              count: provider.products.length,
              isSelected: provider.selectedCategoryId == null,
              onTap: () => provider.clearCategoryFilter(),
            );
          }

          final category = provider.categories[index - 1];
          final count = provider.getProductsCountByCategory()[category.id] ?? 0;

          return _buildCategoryChip(
            id: category.id,
            name: category.name,
            count: count,
            isSelected: provider.selectedCategoryId == category.id,
            onTap: () => provider.filterByCategory(category.id),
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip({
    required String? id,
    required String name,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          '$name ($count)',
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.primary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        checkmarkColor: Colors.white,
        onSelected: (_) => onTap(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
      ),
    );
  }

  Widget _buildProductsList(MarketplaceProvider provider) {
    final products = _filterProducts(provider.filteredProducts);

    if (products.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.medium),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(product, provider);
      },
    );
  }

  List<LoungeProduct> _filterProducts(List<LoungeProduct> products) {
    if (_searchQuery.isEmpty) {
      return products;
    }

    return products.where((product) {
      return product.name.toLowerCase().contains(_searchQuery) ||
          (product.description?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }

  Widget _buildProductCard(
    LoungeProduct product,
    MarketplaceProvider provider,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.medium),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            _buildProductImage(product),
            const SizedBox(width: AppSpacing.medium),

            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and type badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      _buildTypeBadge(product.productType),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Category
                  Text(
                    provider.getCategoryName(product.categoryId),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Price
                  Row(
                    children: [
                      Text(
                        'LKR ${product.price}',
                        style: TextStyle(
                          color: product.hasDiscount
                              ? AppColors.textSecondary
                              : AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          decoration: product.hasDiscount
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (product.hasDiscount) ...[
                        const SizedBox(width: 8),
                        Text(
                          'LKR ${product.discountedPrice}',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Status badges
                  Row(
                    children: [
                      _buildStatusBadge(product.stockStatus),
                      const SizedBox(width: 8),
                      if (!product.isAvailable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Unavailable',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (product.isFeatured)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star,
                                size: 12,
                                color: AppColors.accent,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Featured',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            Column(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.primary,
                  ),
                  onPressed: () => _navigateToEditProduct(product),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                  onPressed: () => _showDeleteConfirmation(product, provider),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(LoungeProduct product) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.border.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: product.imageUrl != null && product.imageUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: OptimizedCachedImage(
                imageUrl: product.imageUrl!,
                fit: BoxFit.cover,
                width: 80,
                height: 80,
                quality: 'sd',
                errorWidget: (_, __, ___) => _buildPlaceholderIcon(product),
              ),
            )
          : _buildPlaceholderIcon(product),
    );
  }

  Widget _buildPlaceholderIcon(LoungeProduct product) {
    IconData icon;
    switch (product.productType) {
      case ProductType.service:
        icon = Icons.room_service;
        break;
      case ProductType.other:
        icon = Icons.devices_other;
        break;
      case ProductType.combo:
        icon = Icons.inventory_2;
        break;
      default:
        icon = Icons.fastfood;
    }

    return Center(child: Icon(icon, size: 40, color: AppColors.textSecondary));
  }

  Widget _buildTypeBadge(ProductType type) {
    Color color;
    String label;

    switch (type) {
      case ProductType.service:
        color = AppColors.secondary;
        label = 'Service';
        break;
      case ProductType.other:
        color = const Color(0xFF546E7A);
        label = 'Other';
        break;
      case ProductType.combo:
        color = AppColors.accent;
        label = 'Combo';
        break;
      default:
        color = AppColors.primary;
        label = 'Product';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ProductStockStatus status) {
    Color color;
    String label;

    switch (status) {
      case ProductStockStatus.inStock:
        color = Colors.green;
        label = 'In Stock';
        break;
      case ProductStockStatus.lowStock:
        color = Colors.orange;
        label = 'Low Stock';
        break;
      case ProductStockStatus.outOfStock:
        color = Colors.red;
        label = 'Out of Stock';
        break;
      case ProductStockStatus.madeToOrder:
        color = AppColors.primary;
        label = 'Made to Order';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 80,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(
            _searchQuery.isNotEmpty
                ? 'No products match your search'
                : 'No products yet',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Add products to your marketplace',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.large),
          if (_searchQuery.isEmpty)
            ElevatedButton.icon(
              onPressed: () => _navigateToAddProduct(),
              icon: const Icon(Icons.add),
              label: const Text('Add First Product'),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: AppColors.error),
          const SizedBox(height: AppSpacing.medium),
          Text(
            'Something went wrong',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            message,
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.large),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _navigateToAddProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductFormScreen(
          loungeId: widget.loungeId,
          loungeName: widget.loungeName,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _navigateToEditProduct(LoungeProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductFormScreen(
          loungeId: widget.loungeId,
          loungeName: widget.loungeName,
          product: product,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _showDeleteConfirmation(
    LoungeProduct product,
    MarketplaceProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to delete "${product.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.deleteProduct(product.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Product deleted successfully'
                          : 'Failed to delete product',
                    ),
                    backgroundColor:
                        success ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
