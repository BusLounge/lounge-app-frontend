import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme_config.dart';
import '../../core/services/image_cache_service.dart';
import '../../domain/entities/lounge_product.dart';
import '../../domain/entities/lounge_special_package.dart';
import '../../presentation/providers/marketplace_provider.dart';
import '../../presentation/providers/lounge_special_package_provider.dart';
import 'add_special_package_screen.dart';
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
  bool _showSpecialPackages = false;

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
    final pkgProvider =
        Provider.of<LoungeSpecialPackageProvider>(context, listen: false);
    await Future.wait([
      provider.loadAll(widget.loungeId),
      pkgProvider.loadPackages(widget.loungeId),
    ]);
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

          final hasSearch = _searchQuery.isNotEmpty;
          return RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.primary,
            child: Column(
              children: [
                _buildSearchBar(),
                _buildCategoryFilter(provider),
                Expanded(
                  child: hasSearch
                      ? _buildUniversalSearchResults(provider)
                      : (_showSpecialPackages
                          ? _buildSpecialPackagesList()
                          : _buildProductsList(provider)),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Add Package FAB ──────────────────────────────────────────
          FloatingActionButton.extended(
            heroTag: 'fab_add_package',
            onPressed: () => _navigateToAddPackage(),
            backgroundColor: const Color(0xFFF59E0B),
            icon: const Icon(Icons.card_giftcard_rounded, color: Colors.white),
            label: const Text(
              'Add Package',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          // ── Add Product FAB ──────────────────────────────────────────
          FloatingActionButton.extended(
            heroTag: 'fab_add_product',
            onPressed: () => _navigateToAddProduct(),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add Product',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
        // +1 for "All", +1 for "Special Packages"
        itemCount: provider.categories.length + 2,
        itemBuilder: (context, index) {
          // "All" chip
          if (index == 0) {
            final packagesCount = Provider.of<LoungeSpecialPackageProvider>(context).packages.length;
            return _buildCategoryChip(
              id: null,
              name: 'All',
              count: provider.products.length + packagesCount,
              isSelected:
                  provider.selectedCategoryId == null && !_showSpecialPackages,
              onTap: () {
                setState(() => _showSpecialPackages = false);
                provider.clearCategoryFilter();
              },
            );
          }

          // "Special Packages" chip (last item)
          if (index == provider.categories.length + 1) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Consumer<LoungeSpecialPackageProvider>(
                builder: (ctx, pkgProvider, _) {
                  final count = pkgProvider.packages.length;
                  return FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.card_giftcard_rounded,
                          size: 14,
                          color: _showSpecialPackages
                              ? Colors.white
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Special Packages ($count)',
                          style: TextStyle(
                            color: _showSpecialPackages
                                ? Colors.white
                                : AppColors.primary,
                            fontWeight: _showSpecialPackages
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    selected: _showSpecialPackages,
                    selectedColor: const Color(0xFFF59E0B),
                    backgroundColor: Colors.white,
                    checkmarkColor: Colors.white,
                    onSelected: (_) {
                      setState(() => _showSpecialPackages = true);
                      provider.clearCategoryFilter();
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: _showSpecialPackages
                            ? const Color(0xFFF59E0B)
                            : AppColors.border,
                      ),
                    ),
                  );
                },
              ),
            );
          }

          final category = provider.categories[index - 1];
          final count =
              provider.getProductsCountByCategory()[category.id] ?? 0;

          return _buildCategoryChip(
            id: category.id,
            name: category.name,
            count: count,
            isSelected: provider.selectedCategoryId == category.id &&
                !_showSpecialPackages,
            onTap: () {
              setState(() => _showSpecialPackages = false);
              provider.filterByCategory(category.id);
            },
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
    final isAllView = provider.selectedCategoryId == null;
    final pkgProvider = Provider.of<LoungeSpecialPackageProvider>(context);
    final packages = pkgProvider.packages;

    final totalCount = products.length + (isAllView ? packages.length : 0);

    if (totalCount == 0) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.medium),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index < products.length) {
          final product = products[index];
          return _buildProductCard(product, provider);
        } else {
          final pkgIndex = index - products.length;
          final pkg = packages[pkgIndex];
          return _buildSpecialPackageCard(pkg, pkgProvider);
        }
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

  // ─────────────────────────────────────────────────────────────────────
  // Universal search filters & lists
  // ─────────────────────────────────────────────────────────────────────

  List<LoungeSpecialPackage> _filterPackages(List<LoungeSpecialPackage> packages) {
    if (_searchQuery.isEmpty) {
      return packages;
    }
    return packages.where((pkg) {
      return pkg.packageName.toLowerCase().contains(_searchQuery) ||
          pkg.description.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Widget _buildUniversalSearchResults(MarketplaceProvider provider) {
    final products = _filterProducts(provider.products);
    final pkgProvider = Provider.of<LoungeSpecialPackageProvider>(context, listen: false);
    final packages = _filterPackages(pkgProvider.packages);

    if (products.isEmpty && packages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 80,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppSpacing.medium),
            const Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              'No products or packages match "$_searchQuery"',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final totalCount = packages.length + products.length;

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.medium),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index < packages.length) {
          final pkg = packages[index];
          return _buildSpecialPackageCard(pkg, pkgProvider);
        } else {
          final product = products[index - packages.length];
          return _buildProductCard(product, provider);
        }
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Special packages list
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildSpecialPackagesList() {
    return Consumer<LoungeSpecialPackageProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
          );
        }

        if (provider.packages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.card_giftcard_rounded,
                  size: 80,
                  color: const Color(0xFFF59E0B).withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No special packages yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap "Add Package" to create your first package',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _navigateToAddPackage(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Package'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.medium),
          itemCount: provider.packages.length,
          itemBuilder: (context, index) {
            return _buildSpecialPackageCard(provider.packages[index], provider);
          },
        );
      },
    );
  }

  Widget _buildSpecialPackageCard(
    LoungeSpecialPackage pkg,
    LoungeSpecialPackageProvider provider,
  ) {
    // Tier-based gradient colors
    final List<Color> gradient;
    final IconData tierIcon;
    switch (pkg.packageType) {
      case SpecialPackageType.platinum:
        gradient = const [Color(0xFF6C63FF), Color(0xFF48CAE4)];
        tierIcon = Icons.diamond;
        break;
      case SpecialPackageType.gold:
        gradient = const [Color(0xFFF59E0B), Color(0xFFEF4444)];
        tierIcon = Icons.star_rounded;
        break;
      case SpecialPackageType.standard:
        gradient = const [Color(0xFF3B82F6), Color(0xFF06B6D4)];
        tierIcon = Icons.verified_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // ── Background decorative circle ──────────────────────────────
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          // ── Content ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image or tier icon
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: pkg.imageUrl != null && pkg.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: OptimizedCachedImage(
                            imageUrl: pkg.imageUrl!,
                            fit: BoxFit.cover,
                            width: 70,
                            height: 70,
                            quality: 'sd',
                            errorWidget: (_, __, ___) => Icon(
                              tierIcon,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        )
                      : Icon(tierIcon, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 14),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tier badge + name
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              pkg.packageType.displayName.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        pkg.packageName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pkg.description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      // Price
                      Text(
                        'LKR ${pkg.price}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action buttons
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: Colors.white, size: 20),
                      onPressed: () => _navigateToEditPackage(pkg),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.white.withOpacity(0.8),
                        size: 20,
                      ),
                      onPressed: () =>
                          _showDeletePackageConfirmation(pkg, provider),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────────────────────────────────

  void _navigateToAddPackage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddSpecialPackageScreen(
          loungeId: widget.loungeId,
          loungeName: widget.loungeName,
        ),
      ),
    ).then((result) {
      if (result == true) {
        final pkgProvider = Provider.of<LoungeSpecialPackageProvider>(
            context,
            listen: false);
        pkgProvider.loadPackages(widget.loungeId);
        setState(() => _showSpecialPackages = true);
      }
    });
  }

  void _navigateToEditPackage(LoungeSpecialPackage pkg) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddSpecialPackageScreen(
          loungeId: widget.loungeId,
          loungeName: widget.loungeName,
          package: pkg,
        ),
      ),
    ).then((result) {
      if (result == true) {
        Provider.of<LoungeSpecialPackageProvider>(context, listen: false)
            .loadPackages(widget.loungeId);
      }
    });
  }

  void _showDeletePackageConfirmation(
    LoungeSpecialPackage pkg,
    LoungeSpecialPackageProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Package'),
        content: Text(
          'Are you sure you want to delete "${pkg.packageName}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.deletePackage(
                  widget.loungeId, pkg.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Package deleted successfully'
                          : 'Failed to delete package',
                    ),
                    backgroundColor:
                        success ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
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
