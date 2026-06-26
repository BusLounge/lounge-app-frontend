import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lounge_owner_app/config/theme_config.dart';
import 'package:lounge_owner_app/config/constants.dart';
import 'package:lounge_owner_app/presentation/providers/staff_provider.dart';
import 'package:lounge_owner_app/presentation/providers/auth_provider.dart';
import 'package:lounge_owner_app/screens/profile/profile_screen.dart';
import 'package:lounge_owner_app/utils/responsive_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load staff profile when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  Future<void> _loadProfile() async {
    final staffProvider = Provider.of<StaffProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await staffProvider.getStaffProfile();

    // If profile load failed due to auth issues, logout
    if (!success && mounted) {
      // Check if error is auth-related (401)
      final error = staffProvider.error?.toLowerCase() ?? '';
      if (error.contains('unauthorized') ||
          error.contains('401') ||
          error.contains('not authenticated')) {
        // Auth token is invalid, logout user
        await authProvider.logout();
        staffProvider.clearStaffData();

        if (!mounted) return;

        // Show error and navigate to login
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please login again.'),
            backgroundColor: AppColors.error,
          ),
        );

        Navigator.of(context).pushNamedAndRemoveUntil(
          AppConstants.phoneInputRoute,
          (route) => false,
        );
      }
    }
  }

  Future<void> _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final staffProvider = Provider.of<StaffProvider>(context, listen: false);

    await authProvider.logout();
    staffProvider.clearStaffData();

    if (!mounted) return;

    // Navigate back to phone input
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppConstants.phoneInputRoute, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Consumer2<StaffProvider, AuthProvider>(
      builder: (context, staffProvider, authProvider, child) {
        final staff = staffProvider.staff;
        final user = authProvider.user;
        final isPending = staff?.isPending ?? true;

        return Scaffold(
          appBar: AppBar(
            title: const Text('SmartTransit'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _logout,
                tooltip: 'Logout',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _loadProfile,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(R.sp(AppSpacing.large)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pending Approval Banner (if status is pending)
                  if (isPending)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.medium),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warning, width: 2),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.pending_outlined,
                            color: AppColors.warning,
                            size: 28,
                          ),
                          const SizedBox(width: AppSpacing.medium),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pending Approval',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.warning,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your registration is under review. You can view your profile while waiting.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.large),

                  // Profile Summary Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.large),
                      child: Column(
                        children: [
                          // Profile Picture/Icon
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.large),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              staff?.isDriver == true
                                  ? Icons.person_pin
                                  : Icons.person_outline,
                              size: 60,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.medium),

                          // Name
                          Text(
                            '${user?.firstName ?? ''} ${user?.lastName ?? ''}'
                                    .trim()
                                    .isEmpty
                                ? 'Staff Member'
                                : '${user?.firstName ?? ''} ${user?.lastName ?? ''}',
                            style: TextStyle(
                              fontSize: R.fs(22, minSize: 16, maxSize: 26),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.small),

                          // Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.medium,
                              vertical: AppSpacing.small,
                            ),
                            decoration: BoxDecoration(
                              color: staff?.isDriver == true
                                  ? AppColors.primary.withOpacity(0.1)
                                  : AppColors.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              staff?.roleDisplay ?? 'Staff',
                              style: TextStyle(
                                color: staff?.isDriver == true
                                    ? AppColors.primary
                                    : AppColors.secondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.small),

                          // Phone Number
                          Text(
                            user?.phoneNumber ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.medium),

                          const Divider(),
                          const SizedBox(height: AppSpacing.medium),

                          // Status
                          _InfoRow(
                            icon: Icons.info_outline,
                            label: 'Status',
                            value: staff?.displayStatus ?? 'Unknown',
                            valueColor: isPending
                                ? AppColors.warning
                                : AppColors.success,
                          ),

                          // Experience (if available)
                          if (staff?.experienceYears != null &&
                              staff!.experienceYears > 0)
                            _InfoRow(
                              icon: Icons.timeline,
                              label: 'Experience',
                              value: '${staff.experienceYears} years',
                            ),

                          // License Number (for drivers)
                          if (staff?.isDriver == true &&
                              staff?.licenseNumber != null)
                            _InfoRow(
                              icon: Icons.credit_card,
                              label: 'License',
                              value: staff!.licenseNumber!,
                            ),

                          // Trips Completed
                          _InfoRow(
                            icon: Icons.directions_bus,
                            label: 'Trips Completed',
                            value: staff?.totalTripsCompleted.toString() ?? '0',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.large),

                  // View Full Profile Button
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person),
                    label: const Text('View Full Profile'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(AppSpacing.medium),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.small),

                  // Placeholder for future features
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.large),
                      child: Column(
                        children: [
                          Icon(
                            Icons.construction,
                            size: 48,
                            color: AppColors.textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: AppSpacing.small),
                          Text(
                            'More features coming soon!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Helper widget for info rows
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
