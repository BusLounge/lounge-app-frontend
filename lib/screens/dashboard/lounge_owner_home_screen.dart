import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../config/constants.dart';
import '../../config/theme_config.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/lounge_owner_provider.dart';
import '../../presentation/providers/registration_provider.dart';
import '../../widgets/owner_bottom_nav_bar.dart';
import '../addtuk/add_tuk_tuk_page.dart';
import '../addtuk/driver_list_page.dart';
import '../addtuk/tuktuk_service_settings.dart';
import '../booking/today_bookings_screen.dart';
import '../bus/qr_scanner_screen.dart';
import '../bus_sedule/upcoming_bus_schedule.dart';
import '../location/location_list_screen.dart';
import '../lounge/edit_lounge_details_page.dart';
import '../staff/staff_list_page.dart';
import '../staff/staff_registration_page.dart';

class LoungeOwnerHomeScreen extends StatefulWidget {
  const LoungeOwnerHomeScreen({super.key});

  @override
  State<LoungeOwnerHomeScreen> createState() => _LoungeOwnerHomeScreenState();
}

class _LoungeOwnerHomeScreenState extends State<LoungeOwnerHomeScreen> {
  bool _hideApprovedVerificationBanner = false;
  late final PageController _currencyPageController;
  late final Future<_CurrencyRatesData> _currencyRatesFuture;
  late Future<_WeatherSnapshot> _weatherFuture;
  late DateTime _currentTime;
  StreamSubscription<dynamic>? _timeSubscription;
  Timer? _clockUiTimer;
  Timer? _weatherTimer;
  int _currencyPageIndex = 0;

  static const EventChannel _systemTimeChannel = EventChannel(
    'lounge_owner_app/system_time_updates',
  );

  @override
  void initState() {
    super.initState();
    _currencyPageController = PageController(viewportFraction: 0.88);
    _currentTime = DateTime.now();
    _currencyRatesFuture = _loadCurrencyRates();
    _weatherFuture = _loadWeatherSnapshot();
    _timeSubscription = _systemTimeChannel.receiveBroadcastStream().listen(
      (event) {
        if (!mounted) return;
        final milliseconds = event as int;
        setState(() {
          _currentTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);
        });
      },
      onError: (_) {},
    );
    // Keep the clock label live even when the OS does not emit time-change events.
    _clockUiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _currentTime = DateTime.now();
      });
    });
    _weatherTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _refreshWeather();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _timeSubscription?.cancel();
    _clockUiTimer?.cancel();
    _weatherTimer?.cancel();
    _currencyPageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadProfile();
    await _loadVerificationBannerPreference();
    await _refreshWeather();
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

  Future<void> _refreshWeather() async {
    if (!mounted) return;

    final loungeOwner = Provider.of<LoungeOwnerProvider>(
      context,
      listen: false,
    ).loungeOwner;
    final district = loungeOwner?.district;

    setState(() {
      _weatherFuture = _loadWeatherSnapshot(district: district);
    });
  }

  Future<void> _loadProfile() async {
    final loungeOwnerProvider = Provider.of<LoungeOwnerProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await loungeOwnerProvider.getLoungeOwnerProfile();

    if (!success && mounted) {
      final error = loungeOwnerProvider.error?.toLowerCase() ?? '';
      if (error.contains('unauthorized') ||
          error.contains('401') ||
          error.contains('not authenticated')) {
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
    registrationProvider.reset();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppConstants.phoneInputRoute,
      (route) => false,
    );
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

  String _greetingForHour(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _displayName(String? managerFullName, String? businessName) {
    final cleanedManagerName = managerFullName?.trim();
    if (cleanedManagerName != null && cleanedManagerName.isNotEmpty) {
      return cleanedManagerName;
    }

    final cleanedBusinessName = businessName?.trim();
    if (cleanedBusinessName != null && cleanedBusinessName.isNotEmpty) {
      return cleanedBusinessName;
    }

    return 'there';
  }

  Future<_CurrencyRatesData> _loadCurrencyRates() async {
    try {
      final response = await http.get(
        Uri.parse('https://open.er-api.com/v6/latest/USD'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load exchange rates');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final rates = decoded['rates'] as Map<String, dynamic>?;
      if (rates == null) {
        throw Exception('Missing exchange rates');
      }

      final lkrPerUsd = (rates['LKR'] as num?)?.toDouble() ?? 0;
      if (lkrPerUsd <= 0) {
        throw Exception('Invalid LKR rate');
      }

      double convertToLkr(String currencyCode) {
        final baseRate = currencyCode == 'USD'
            ? 1.0
            : (rates[currencyCode] as num?)?.toDouble() ?? 0;
        if (baseRate <= 0) return 0;
        return lkrPerUsd / baseRate;
      }

      return _CurrencyRatesData(
        isLive: true,
        lastUpdated: DateTime.now(),
        items: [
        _CurrencyRateItem(
          code: 'USD',
          name: 'US Dollar',
          icon: Icons.attach_money_rounded,
          lkrValue: lkrPerUsd,
          subtitle: '1 USD',
        ),
        _CurrencyRateItem(
          code: 'EUR',
          name: 'Euro',
          icon: Icons.euro_rounded,
          lkrValue: convertToLkr('EUR'),
          subtitle: '1 EUR',
        ),
        _CurrencyRateItem(
          code: 'GBP',
          name: 'British Pound',
          icon: Icons.currency_pound_rounded,
          lkrValue: convertToLkr('GBP'),
          subtitle: '1 GBP',
        ),
        _CurrencyRateItem(
          code: 'INR',
          name: 'Indian Rupee',
          icon: Icons.currency_rupee_rounded,
          lkrValue: convertToLkr('INR'),
          subtitle: '1 INR',
        ),
        _CurrencyRateItem(
          code: 'AED',
          name: 'UAE Dirham',
          icon: Icons.currency_exchange_rounded,
          lkrValue: convertToLkr('AED'),
          subtitle: '1 AED',
        ),
        _CurrencyRateItem(
          code: 'AUD',
          name: 'Australian Dollar',
          icon: Icons.payments_rounded,
          lkrValue: convertToLkr('AUD'),
          subtitle: '1 AUD',
        ),
        ].where((item) => item.lkrValue > 0).toList(),
      );
    } catch (_) {
      return const _CurrencyRatesData(
        isLive: false,
        lastUpdated: null,
        items: [
          _CurrencyRateItem(
            code: 'USD',
            name: 'US Dollar',
            icon: Icons.attach_money_rounded,
            lkrValue: 300.0,
            subtitle: '1 USD',
          ),
          _CurrencyRateItem(
            code: 'EUR',
            name: 'Euro',
            icon: Icons.euro_rounded,
            lkrValue: 325.0,
            subtitle: '1 EUR',
          ),
          _CurrencyRateItem(
            code: 'GBP',
            name: 'British Pound',
            icon: Icons.currency_pound_rounded,
            lkrValue: 380.0,
            subtitle: '1 GBP',
          ),
          _CurrencyRateItem(
            code: 'INR',
            name: 'Indian Rupee',
            icon: Icons.currency_rupee_rounded,
            lkrValue: 3.6,
            subtitle: '1 INR',
          ),
          _CurrencyRateItem(
            code: 'AED',
            name: 'UAE Dirham',
            icon: Icons.currency_exchange_rounded,
            lkrValue: 82.0,
            subtitle: '1 AED',
          ),
          _CurrencyRateItem(
            code: 'AUD',
            name: 'Australian Dollar',
            icon: Icons.payments_rounded,
            lkrValue: 195.0,
            subtitle: '1 AUD',
          ),
        ],
      );
    }
  }

  Widget _buildGreetingCard({
    required String greeting,
    required String userName,
  }) {
    final isMorning = greeting == 'Good morning';
    final isAfternoon = greeting == 'Good afternoon';
    final isEvening = !isMorning && !isAfternoon;

    final background = isMorning
        ? const LinearGradient(
            colors: [Color(0xFFB8D9FF), Color(0xFF2F7BEA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : isAfternoon
            ? const LinearGradient(
                colors: [Color(0xFF8FC6FF), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF1B4B8F), Color(0xFF0A2046)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              );

    final icon = isMorning
        ? Icons.wb_sunny_rounded
        : isAfternoon
            ? Icons.wb_twilight_rounded
            : Icons.nightlight_round_rounded;

    final titleColor = isEvening ? const Color(0xFFE8F1FF) : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: background,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F6FEA).withOpacity(0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -14,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: -6,
            child: Opacity(
              opacity: isEvening ? 0.96 : 0.18,
              child: Image.asset(
                'assets/images/lior_logo_no_bg.png',
                width: 98,
                height: 98,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.16)),
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting, $userName',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Here is your lounge overview for today.',
                      style: TextStyle(
                        color: titleColor.withOpacity(0.92),
                        fontSize: 13,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFFBF5);

    return Consumer2<LoungeOwnerProvider, AuthProvider>(
      builder: (context, loungeOwnerProvider, authProvider, child) {
        final loungeOwner = loungeOwnerProvider.loungeOwner;
        final isLoading =
            loungeOwnerProvider.isLoading || authProvider.isLoading;
        final userName = _displayName(
          loungeOwner?.managerFullName,
          loungeOwner?.businessName,
        );
        final greeting = _greetingForHour(DateTime.now().hour);

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
                          _buildVerificationBanner(
                            loungeOwner?.verificationStatus,
                          ),
                          const SizedBox(height: 18),
                          _buildGreetingCard(
                            greeting: greeting,
                            userName: userName,
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Quick Actions',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
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

  Widget _buildExchangeRatesSection() {
    return FutureBuilder<_CurrencyRatesData>(
      future: _currencyRatesFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final items = data?.items ?? const <_CurrencyRateItem>[];
        final isLive = data?.isLive ?? false;
        final lastUpdated = data?.lastUpdated;
        final statusLabel = isLive ? 'Live' : 'Fallback';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD8E8FF)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2F7BEA).withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB9D9FF), Color(0xFF2F7BEA)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.currency_exchange_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Today\'s exchange rates',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF123A73),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'USD and major currencies converted to LKR',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5F7FAE),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildStatusChip(
                              label: statusLabel,
                              icon: isLive
                                  ? Icons.wifi_tethering_rounded
                                  : Icons.cloud_off_rounded,
                              filled: isLive,
                            ),
                            if (lastUpdated != null)
                              _buildStatusChip(
                                label: 'Updated ${_formatLastUpdated(lastUpdated)}',
                                icon: Icons.schedule_rounded,
                                filled: false,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'Exchange rates are not available right now.',
                    style: TextStyle(color: Color(0xFF5F7FAE)),
                  ),
                )
              else ...[
                SizedBox(
                  height: 170,
                  child: PageView.builder(
                    controller: _currencyPageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currencyPageIndex = index;
                      });
                    },
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildCurrencyRateCard(item),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(items.length, (index) {
                    final isActive = index == _currencyPageIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF2F7BEA)
                            : const Color(0xFFC7D9F7),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrencyRateCard(_CurrencyRateItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF5F9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E8FF)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: Icon(
              item.icon,
              color: const Color(0xFFB9D9FF),
              size: 68,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.code,
                      style: const TextStyle(
                        color: Color(0xFF245DBA),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: Color(0xFF6A86AA),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                item.subtitle,
                style: const TextStyle(
                  color: Color(0xFF6A86AA),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'LKR ${item.lkrValue.toStringAsFixed(item.code == 'INR' ? 2 : 2)}',
                style: const TextStyle(
                  color: Color(0xFF123A73),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'per 1 unit',
                style: TextStyle(
                  color: Color(0xFF7D99BE),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required IconData icon,
    required bool filled,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? const Color(0xFFEAF2FF) : const Color(0xFFF5F9FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD6E6FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF245DBA)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF245DBA),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastUpdated(DateTime dateTime) {
    const dayLabels = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    final dayLabel = dayLabels[dateTime.weekday - 1];
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    return '$dayLabel, $day/$month $hour:$minute';
  }

  Widget _buildTopBadge({
    required IconData icon,
    required String label,
    bool filled = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? const Color(0xFFDDEAFF) : const Color(0xFFF5F9FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD6E6FF), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF245DBA)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF245DBA),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Future<_WeatherSnapshot> _loadWeatherSnapshot({String? district}) async {
    final query = (district?.trim().isNotEmpty ?? false)
        ? district!.trim()
        : 'Colombo';

    try {
      final geoResponse = await http.get(
        Uri.parse(
          'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(query)}&count=1&language=en&format=json',
        ),
      );

      if (geoResponse.statusCode != 200) {
        throw Exception('Geocoding failed');
      }

      final geoJson = jsonDecode(geoResponse.body) as Map<String, dynamic>;
      final results = geoJson['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        throw Exception('No geocoding result');
      }

      final location = results.first as Map<String, dynamic>;
      final latitude = (location['latitude'] as num).toDouble();
      final longitude = (location['longitude'] as num).toDouble();
      final placeName = (location['name'] as String?) ?? query;

      final weatherResponse = await http.get(
        Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current=temperature_2m,weather_code&timezone=auto',
        ),
      );

      if (weatherResponse.statusCode != 200) {
        throw Exception('Weather fetch failed');
      }

      final weatherJson = jsonDecode(weatherResponse.body) as Map<String, dynamic>;
      final current = weatherJson['current'] as Map<String, dynamic>?;
      if (current == null) {
        throw Exception('No current weather');
      }

      final temperature = (current['temperature_2m'] as num?)?.toDouble() ?? 0;
      final weatherCode = (current['weather_code'] as num?)?.toInt() ?? 0;

      return _WeatherSnapshot(
        isLive: true,
        lastUpdated: DateTime.now(),
        locationName: placeName,
        temperatureC: temperature,
        weatherLabel: _weatherLabel(weatherCode),
        weatherIcon: _weatherIcon(weatherCode),
      );
    } catch (_) {
      return const _WeatherSnapshot(
        isLive: false,
        lastUpdated: null,
        locationName: 'Colombo',
        temperatureC: 29,
        weatherLabel: 'Mostly sunny',
        weatherIcon: Icons.wb_sunny_rounded,
      );
    }
  }

  String _weatherLabel(int code) {
    switch (code) {
      case 0:
        return 'Clear';
      case 1:
      case 2:
      case 3:
        return 'Partly cloudy';
      case 45:
      case 48:
        return 'Fog';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 71:
      case 73:
      case 75:
        return 'Snow';
      case 95:
      case 96:
      case 99:
        return 'Storm';
      default:
        return 'Weather';
    }
  }

  IconData _weatherIcon(int code) {
    switch (code) {
      case 0:
        return Icons.wb_sunny_rounded;
      case 1:
      case 2:
      case 3:
        return Icons.wb_cloudy_rounded;
      case 45:
      case 48:
        return Icons.foggy;
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
        return Icons.beach_access_rounded;
      case 71:
      case 73:
      case 75:
        return Icons.ac_unit_rounded;
      case 95:
      case 96:
      case 99:
        return Icons.thunderstorm_rounded;
      default:
        return Icons.wb_sunny_rounded;
    }
  }

  Widget _buildVerificationBanner(String? status) {
    if (status == null) return const SizedBox.shrink();

    if (status == 'approved' && _hideApprovedVerificationBanner) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTopBadge(
                icon: Icons.verified_rounded,
                label: 'Verified',
                filled: true,
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
        bgColor = const Color(0xFFEAF2FF);
        borderColor = const Color(0xFFB9D9FF);
        textColor = const Color(0xFF245DBA);
        icon = Icons.verified_rounded;
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
      child: status == 'approved'
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildTopBadge(
                      icon: Icons.verified_rounded,
                      label: 'Verified',
                      filled: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
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
              ],
            )
          : Row(
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

class _CurrencyRateItem {
  final String code;
  final String name;
  final IconData icon;
  final double lkrValue;
  final String subtitle;

  const _CurrencyRateItem({
    required this.code,
    required this.name,
    required this.icon,
    required this.lkrValue,
    required this.subtitle,
  });
}

class _CurrencyRatesData {
  final bool isLive;
  final DateTime? lastUpdated;
  final List<_CurrencyRateItem> items;

  const _CurrencyRatesData({
    required this.isLive,
    required this.lastUpdated,
    required this.items,
  });
}

class _WeatherSnapshot {
  final bool isLive;
  final DateTime? lastUpdated;
  final String locationName;
  final double temperatureC;
  final String weatherLabel;
  final IconData weatherIcon;

  const _WeatherSnapshot({
    required this.isLive,
    required this.lastUpdated,
    required this.locationName,
    required this.temperatureC,
    required this.weatherLabel,
    required this.weatherIcon,
  });
}
