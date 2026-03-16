import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/theme_config.dart';
import '../../presentation/providers/driver_provider.dart';
import '../../presentation/providers/registration_provider.dart';
import 'add_tuk_tuk_page.dart';

class DriverListPage extends StatefulWidget {
  const DriverListPage({super.key});

  @override
  State<DriverListPage> createState() => _DriverListPageState();
}

class _DriverListPageState extends State<DriverListPage> {
  String? _selectedLoungeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLounges();
    });
  }

  Future<void> _initializeLounges() async {
    final registrationProvider = context.read<RegistrationProvider>();

    if (registrationProvider.myLounges.isEmpty) {
      await registrationProvider.loadMyLounges();
    }

    final verifiedLounges = registrationProvider.verifiedLounges;
    if (verifiedLounges.isNotEmpty) {
      setState(() {
        _selectedLoungeId = verifiedLounges.first.id;
      });
      _loadDriverList();
    }
  }

  Future<void> _loadDriverList() async {
    final driverProvider = context.read<DriverProvider>();

    if (_selectedLoungeId == null) {
      return;
    }

    await driverProvider.getDriversByLounge(loungeId: _selectedLoungeId!);
  }

  Future<void> _confirmDeleteDriver(String driverId) async {
    if (_selectedLoungeId == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Driver'),
        content: const Text(
          'Are you sure you want to remove this driver from the lounge?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    final driverProvider = context.read<DriverProvider>();
    final success = await driverProvider.removeDriver(
      loungeId: _selectedLoungeId!,
      driverId: driverId,
      showLoading: false,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Driver removed successfully'
              : (driverProvider.error ?? 'Failed to remove driver'),
        ),
      ),
    );

    if (!success) {
      driverProvider.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Driver List',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer2<DriverProvider, RegistrationProvider>(
        builder: (context, driverProvider, registrationProvider, _) {
          if (driverProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (driverProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(driverProvider.error!,
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadDriverList,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final verifiedLounges = registrationProvider.verifiedLounges;
          if (verifiedLounges.isEmpty) {
            return const Center(
              child: Text(
                'No verified lounges yet',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
            );
          }

          final driverList = driverProvider.driverList;

          if (driverList.isEmpty && _selectedLoungeId != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_taxi_outlined,
                      size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  const Text(
                    'No drivers yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadDriverList,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Lounge Selection Dropdown
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButton<String>(
                    isExpanded: true,
                    underline: Container(),
                    hint: const Text('Select Lounge'),
                    value: verifiedLounges
                            .any((lounge) => lounge.id == _selectedLoungeId)
                        ? _selectedLoungeId
                        : null,
                    items: verifiedLounges.map((lounge) {
                      return DropdownMenuItem<String>(
                        value: lounge.id,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                lounge.loungeName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedLoungeId = value;
                        });
                        _loadDriverList();
                      }
                    },
                  ),
                ),
                // Driver list
                ...driverList.map(
                  (driver) => DriverCard(
                    driver: driver,
                    onDelete: () => _confirmDeleteDriver(driver.id),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTukTukPage(),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Driver',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

/// ---------------- DRIVER CARD ----------------
class DriverCard extends StatelessWidget {
  final dynamic driver;
  final VoidCallback? onDelete;

  const DriverCard({
    super.key,
    required this.driver,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd-MM-yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: const Icon(Icons.local_taxi, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  driver.fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                  tooltip: 'Delete driver',
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          InfoRow(label: 'Contact', value: driver.contactNumber),
          InfoRow(label: 'NIC', value: driver.nicNumber),
          InfoRow(label: 'Vehicle Number', value: driver.vehicleNumber),
          InfoRow(
            label: 'Vehicle Type',
            value: driver.vehicleType.toUpperCase().replaceAll('_', ' '),
          ),
          InfoRow(
            label: 'Added Date',
            value: dateFormat.format(driver.createdAt),
          ),
        ],
      ),
    );
  }
}

/// ---------------- INFO ROW ----------------
class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
