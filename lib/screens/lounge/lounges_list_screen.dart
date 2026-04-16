import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme_config.dart';
import '../../presentation/providers/registration_provider.dart';
import '../../presentation/providers/lounge_owner_provider.dart';
import '../../domain/entities/lounge.dart';
import '../../widgets/owner_bottom_nav_bar.dart';
import 'lounge_details_page.dart';
import 'edit_lounge_details_page.dart';

/// Screen showing list of all lounges owned by the user
class LoungesListScreen extends StatefulWidget {
  const LoungesListScreen({super.key});

  @override
  State<LoungesListScreen> createState() => _LoungesListScreenState();
}

class _LoungesListScreenState extends State<LoungesListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLounges();
    });
  }

  Future<void> _loadLounges() async {
    final registrationProvider = Provider.of<RegistrationProvider>(
      context,
      listen: false,
    );
    await registrationProvider.loadMyLounges();
  }

  Future<void> _confirmDeleteLounge(Lounge lounge) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lounge'),
        content: Text(
          'Are you sure you want to delete ${lounge.loungeName}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    final provider = Provider.of<RegistrationProvider>(context, listen: false);
    final success = await provider.deleteLoungeById(lounge.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Lounge deleted successfully'
              : provider.errorMessage ?? 'Failed to delete lounge',
        ),
        backgroundColor: success ? Colors.green : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFFBF5);

    return Consumer2<RegistrationProvider, LoungeOwnerProvider>(
      builder: (context, registrationProvider, loungeOwnerProvider, child) {
        final lounges = registrationProvider.myLounges;
        final isLoading = registrationProvider.isLoading;
        final loungeOwner = loungeOwnerProvider.loungeOwner;

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            elevation: 0,
            title: const Text(
              'My Lounges',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.black87),
                onPressed: _loadLounges,
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.black87),
                onPressed: () async {
                  // Navigate to Add Lounge screen (not registration)
                  final result = await Navigator.pushNamed(
                    context,
                    '/add-lounge',
                  );
                  // Refresh list if lounge was added successfully
                  if (result == true) {
                    _loadLounges();
                  }
                },
                tooltip: 'Add Lounge',
              ),
            ],
          ),
          body: SafeArea(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadLounges,
                    child: lounges.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: lounges.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _buildLoungeCard(lounges[index]),
                          ),
                  ),
          ),
          bottomNavigationBar: OwnerBottomNavBar(
            currentIndex: 1,
            verificationStatus: loungeOwner?.verificationStatus,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.apartment_outlined,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 24),
              Text(
                'No Lounges Yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Add your first lounge to start\nreceiving bookings from passengers',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  // Navigate to Add Lounge screen (not registration)
                  final result = await Navigator.pushNamed(
                    context,
                    '/add-lounge',
                  );
                  // Refresh list if lounge was added successfully
                  if (result == true) {
                    _loadLounges();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Your First Lounge'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoungeCard(Lounge lounge) {
    return InkWell(
      onTap: () => _showLoungeOptions(lounge),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Lounge Image
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    image: lounge.primaryPhoto != null
                        ? DecorationImage(
                            image: NetworkImage(lounge.primaryPhoto!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: lounge.primaryPhoto == null
                      ? Icon(
                          Icons.apartment,
                          color: Colors.grey.shade400,
                          size: 32,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                // Lounge Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lounge.loungeName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusChip(lounge.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              lounge.address,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildInfoChip(
                            Icons.people,
                            '${lounge.capacity ?? 0} seats',
                          ),
                          const SizedBox(width: 8),
                          if (lounge.price1Hour != null)
                            _buildInfoChip(
                              Icons.currency_rupee,
                              'LKR ${lounge.price1Hour}/hr',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Amenities row
            if (lounge.amenities != null && lounge.amenities!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: lounge.amenities!.map((amenity) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LoungeAmenities.icons[amenity] ?? Icons.check_circle,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          LoungeAmenities.labels[amenity] ?? amenity,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            // Quick Action Buttons
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.storefront,
                    label: 'Marketplace',
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/marketplace',
                      arguments: {
                        'loungeId': lounge.id,
                        'loungeName': lounge.loungeName,
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.settings,
                    label: 'Settings',
                    onTap: () => _showLoungeOptions(lounge),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoungeOptions(Lounge lounge) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  lounge.loungeName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.visibility_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('View Details'),
                subtitle: const Text('See lounge profile in detail view'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LoungeDetailsPage(lounge: lounge),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.storefront, color: AppColors.primary),
                title: const Text('Manage Marketplace'),
                subtitle: const Text('Add and edit products'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/marketplace',
                    arguments: {
                      'loungeId': lounge.id,
                      'loungeName': lounge.loungeName,
                    },
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.edit, color: Colors.grey.shade600),
                title: const Text('Edit Lounge'),
                subtitle: const Text('Update lounge details'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EditLoungeDetailsPage(initialLounge: lounge),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: const Text('Delete Lounge'),
                subtitle: const Text('Remove this lounge permanently'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteLounge(lounge);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'active':
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        label = 'Active';
        break;
      case 'pending':
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFF57C00);
        label = 'Pending';
        break;
      case 'inactive':
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade600;
        label = 'Inactive';
        break;
      case 'suspended':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        label = 'Suspended';
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade600;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
