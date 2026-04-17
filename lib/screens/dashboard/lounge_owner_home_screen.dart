import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme_config.dart';
import '../../config/constants.dart';
import '../../presentation/providers/lounge_owner_provider.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/registration_provider.dart';
import '../../domain/entities/lounge.dart';
import '../../widgets/owner_bottom_nav_bar.dart';
import '../staff/staff_registration_page.dart';
import '../staff/staff_list_page.dart';
import '../addtuk/add_tuk_tuk_page.dart';
import '../bus_sedule/upcoming_bus_schedule.dart';
import '../lounge/edit_lounge_details_page.dart';
import '../lounge/lounge_details_page.dart';
import '../booking/today_bookings_screen.dart';
import '../bus/qr_scanner_screen.dart';
import '../addtuk/tuktuk_service_settings.dart';
import '../addtuk/driver_list_page.dart';
import '../location/location_list_screen.dart';

class LoungeOwnerHomeScreen extends StatefulWidget {
  const LoungeOwnerHomeScreen({super.key});

  @override
  State<LoungeOwnerHomeScreen> createState() => _LoungeOwnerHomeScreenState();
}

class _LoungeOwnerHomeScreenState extends State<LoungeOwnerHomeScreen> {
  bool _hideApprovedVerificationBanner = false;

  @override
  void initState() {
    super.initState();
    // Load lounge owner profile and lounges when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    await Future.wait([_loadProfile(), _loadMyLounges()]);
    await _loadVerificationBannerPreference();
  }

  String _verificationBannerPrefKey(String? userId) {
    return 'owner_verified_banner_dismissed_${userId ?? 'unknown'}';
  }

  Future<void> _loadVerificationBannerPreference() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    final key = _verificationBannerPrefKey(authProvider.user?.id);
    final dismissed = prefs.getBool(key) ?? false;

    if (!mounted) return;
    setState(() {
      _hideApprovedVerificationBanner = dismissed;
    });
  }

  Future<void> _dismissApprovedVerificationBanner() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    final key = _verificationBannerPrefKey(authProvider.user?.id);
    await prefs.setBool(key, true);

    if (!mounted) return;
    setState(() {
      _hideApprovedVerificationBanner = true;
    });
  }

  Future<void> _loadProfile() async {
    final loungeOwnerProvider = Provider.of<LoungeOwnerProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await loungeOwnerProvider.getLoungeOwnerProfile();

    // If profile load failed due to auth issues, logout
    if (!success && mounted) {
      final error = loungeOwnerProvider.error?.toLowerCase() ?? '';
      if (error.contains('unauthorized') ||
          error.contains('401') ||
          error.contains('not authenticated')) {
        // Auth token is invalid, logout user
        await authProvider.logout();

        if (!mounted) return;

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

  Future<void> _loadMyLounges() async {
    final registrationProvider = Provider.of<RegistrationProvider>(
      context,
      listen: false,
    );
    print('🏠 Dashboard - Loading my lounges...');
    await registrationProvider.loadMyLounges();
    print(
      '🏠 Dashboard - Loaded ${registrationProvider.myLounges.length} lounges',
    );
  }

  Future<void> _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final loungeOwnerProvider = Provider.of<LoungeOwnerProvider>(
      context,
      listen: false,
    );
    final registrationProvider = Provider.of<RegistrationProvider>(
      context,
      listen: false,
    );

    await authProvider.logout();
    loungeOwnerProvider.clearData();
    registrationProvider.reset(); // Clear cached registration data

    if (!mounted) return;

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppConstants.phoneInputRoute, (route) => false);
  }

  Future<void> _confirmAndLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textLight,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFFBF5);

    return Consumer3<LoungeOwnerProvider, AuthProvider, RegistrationProvider>(
      builder: (context, loungeOwnerProvider, authProvider,
          registrationProvider, child) {
        final loungeOwner = loungeOwnerProvider.loungeOwner;
        final lounges = registrationProvider.myLounges;
        final isLoading =
            loungeOwnerProvider.isLoading || registrationProvider.isLoading;

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.black87),
                onPressed: _loadData,
                tooltip: 'Refresh',
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.black87),
                onPressed: _confirmAndLogout,
                tooltip: 'Logout',
              ),
            ],
          ),
          body: SafeArea(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Verification Status Banner
                          _buildVerificationBanner(
                            loungeOwner?.verificationStatus,
                          ),

                          const SizedBox(height: 18),

                          // My Lounges Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'My Lounges',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                              if (lounges.isNotEmpty)
                                Text(
                                  '${lounges.length} lounge${lounges.length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Lounge List or Empty State
                          if (lounges.isEmpty)
                            _buildEmptyState()
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: lounges.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) =>
                                  _buildLoungeCard(lounges[index]),
                            ),

                          const SizedBox(height: 24),

                          // Quick Actions
                          const Text(
                            'Quick Actions',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Check if account is approved
                          loungeOwner?.verificationStatus != 'approved'
                              ? _buildPendingActionsMessage()
                              : GridView.count(
                                  crossAxisCount: 2,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 1.6,
                                  children: [
                                    _buildActionTile(
                                      label: 'Add Staff',
                                      icon: Icons.person_add,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const StaffRegistrationPage(
                                              isAddedByAdmin: true,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    _buildActionTile(
                                      label: 'Staff List',
                                      icon: Icons.people,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const StaffListPage(),
                                          ),
                                        );
                                      },
                                    ),
                                    _buildActionTile(
                                      label: 'Add Vehicle Details',
                                      icon: Icons.local_taxi,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const AddTukTukPage(),
                                          ),
                                        );
                                      },
                                    ),
                                    _buildActionTile(
                                      label: 'All Bookings',
                                      icon: Icons.list_alt,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const TodayBookingsScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    _buildActionTile(
                                      label: 'QR Scanner',
                                      icon: Icons.qr_code_scanner,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const QrScannerScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    _buildActionTile(
                                      label: 'Upcoming Bus Schedule',
                                      icon: Icons.directions_bus,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const BusScheduleScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    _buildActionTile(
                                      label: 'Edit Lounge Details',
                                      icon: Icons.edit_location_alt,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const EditLoungeDetailsPage(),
                                          ),
                                        );
                                      },
                                    ),
                                    _buildActionTile(
                                      label: 'Add Location',
                                      icon: Icons.add_location,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const TukTukServiceSettingsPage(),
                                          ),
                                        );
                                      },
                                    ),
                                    _buildActionTile(
                                      label: 'Driver List',
                                      icon: Icons.airport_shuttle,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const DriverListPage(),
                                          ),
                                        );
                                      },
                                    ),
                                    _buildActionTile(
                                      label: 'Location List',
                                      icon: Icons.list_alt,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const LocationListScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),

                          const SizedBox(height: 36),
                        ],
                      ),
                    ),
                  ),
          ),
          bottomNavigationBar: OwnerBottomNavBar(
            currentIndex: 0,
            verificationStatus: loungeOwner?.verificationStatus,
          ),
        );
      },
    );
  }

  Widget _buildVerificationBanner(String? status) {
    if (status == null) return const SizedBox.shrink();

    if (status == 'approved' && _hideApprovedVerificationBanner) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF4CAF50), width: 1.2),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified,
                color: Color(0xFF2E7D32),
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                'Verified',
                style: TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String title;
    String subtitle;

    switch (status) {
      case 'pending':
        bgColor = const Color(0xFFFFF3E0);
        borderColor = const Color(0xFFFFA726);
        textColor = const Color(0xFFF57C00);
        icon = Icons.hourglass_empty;
        title = 'Account Pending Approval';
        subtitle = 'Your registration is awaiting admin approval.';
        break;
      case 'rejected':
        bgColor = Colors.red.shade50;
        borderColor = Colors.red.shade300;
        textColor = Colors.red.shade700;
        icon = Icons.cancel;
        title = 'Account Rejected';
        subtitle = 'Please contact support for more information.';
        break;
      case 'approved':
        bgColor = const Color(0xFFE8F5E9);
        borderColor = const Color(0xFF4CAF50);
        textColor = const Color(0xFF2E7D32);
        icon = Icons.verified;
        title = 'Account Verified';
        subtitle = 'Your account has been approved!';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textColor.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (status == 'approved')
            InkWell(
              onTap: _dismissApprovedVerificationBanner,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: textColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.apartment_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Lounges Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first lounge to start receiving bookings',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.pushNamed(context, '/add-lounge');
              if (!mounted) return;
              await _loadMyLounges();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add First Lounge'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoungeCard(Lounge lounge) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoungeDetailsPage(lounge: lounge),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            // Lounge Image or Placeholder
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
                  ? Icon(Icons.apartment, color: Colors.grey.shade400, size: 32)
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
                      _buildInfoChip(Icons.people, '${lounge.capacity ?? 0}'),
                      const SizedBox(width: 8),
                      if (lounge.price1Hour != null)
                        _buildInfoChip(
                          Icons.currency_rupee,
                          'LKR ${lounge.price1Hour}/hr',
                        ),
                      const Spacer(),
                      if (lounge.amenities != null &&
                          lounge.amenities!.isNotEmpty)
                        Row(
                          children: lounge.amenities!
                              .take(3)
                              .map(
                                (a) => Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(
                                    LoungeAmenities.icons[a] ??
                                        Icons.check_circle,
                                    size: 16,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingActionsMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_clock, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Actions Locked',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Quick actions will be available after admin approval.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
