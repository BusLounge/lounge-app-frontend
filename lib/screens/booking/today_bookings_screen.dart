import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../../config/theme_config.dart';
import '../../widgets/staff_bottom_nav_bar.dart';
import '../../widgets/owner_bottom_nav_bar.dart';
import '../../presentation/providers/lounge_owner_provider.dart';
import '../../presentation/providers/lounge_booking_provider.dart';
import '../../presentation/providers/registration_provider.dart';
import '../marketplace/received_food_screen.dart';
import '../addtuk/tuk_tuk_list_page.dart';
import 'booking_orders_page.dart';

class TodayBookingsScreen extends StatefulWidget {
  final bool isStaffMode;

  const TodayBookingsScreen({super.key, this.isStaffMode = false});

  @override
  State<TodayBookingsScreen> createState() => _TodayBookingsScreenState();
}

class _TodayBookingsScreenState extends State<TodayBookingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _selectedLoungeId;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Load bookings when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookings();
    });
  }

  Future<void> _loadBookings() async {
    final bookingProvider = context.read<LoungeBookingProvider>();

    if (widget.isStaffMode) {
      // Staff mode - use staff-specific endpoint
      // No need to fetch staff profile or lounge ID - endpoint handles it automatically
      final selectedDate = _selectedDay ?? DateTime.now();
      final dateFilter = '${selectedDate.year.toString().padLeft(4, '0')}-'
          '${selectedDate.month.toString().padLeft(2, '0')}-'
          '${selectedDate.day.toString().padLeft(2, '0')}';

      await bookingProvider.getStaffBookings(
        date: dateFilter,
        limit: 100,
      );
    } else {
      // Owner mode - load all owner bookings
      final registrationProvider = context.read<RegistrationProvider>();
      // Get lounge ID
      final lounges = registrationProvider.verifiedLounges;
      if (lounges.isEmpty) {
        await registrationProvider.loadMyLounges();
      }

      final verifiedLounges = registrationProvider.verifiedLounges;
      if (_selectedLoungeId == null && verifiedLounges.isNotEmpty) {
        _selectedLoungeId = verifiedLounges.first.id;
      }
      final selectedDate = _selectedDay ?? DateTime.now();
      final dateFilter = '${selectedDate.year.toString().padLeft(4, '0')}-'
          '${selectedDate.month.toString().padLeft(2, '0')}-'
          '${selectedDate.day.toString().padLeft(2, '0')}';

      await bookingProvider.getOwnerBookings(
        loungeId: _selectedLoungeId,
        date: dateFilter,
      );
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';

    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'pm' : 'am';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: AppColors.textPrimary,
          ),
        ),
        title: const Text(
          'All Bookings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            if (!widget.isStaffMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Consumer<RegistrationProvider>(
                  builder: (context, registrationProvider, child) {
                    final verifiedLounges =
                        registrationProvider.verifiedLounges;
                    if (verifiedLounges.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        underline: const SizedBox(),
                        hint: const Text(
                          'Select Lounge',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        value: verifiedLounges
                                .any((lounge) => lounge.id == _selectedLoungeId)
                            ? _selectedLoungeId
                            : null,
                        items: verifiedLounges.map((lounge) {
                          return DropdownMenuItem<String>(
                            value: lounge.id,
                            child: Row(
                              children: [
                                const Icon(Icons.store,
                                    size: 20, color: AppColors.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    lounge.loungeName,
                                    style: const TextStyle(
                                      fontSize: 15,
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
                            _loadBookings();
                          }
                        },
                      ),
                    );
                  },
                ),
              ),

            // ---------------- Calendar Title ----------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_month,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Calendar',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ---------------- Calendar Card ----------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: CalendarFormat.week,
                  startingDayOfWeek: StartingDayOfWeek.sunday,
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: false,
                    titleTextStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    leftChevronIcon: const Icon(
                      Icons.chevron_left,
                      color: AppColors.textPrimary,
                    ),
                    rightChevronIcon: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    weekendStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    selectedTextStyle: const TextStyle(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.bold,
                    ),
                    defaultTextStyle: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    weekendTextStyle: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    outsideTextStyle: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.5),
                    ),
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    // Reload bookings for the selected date (both staff and owner)
                    _loadBookings();
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ---------------- Bookings Title ----------------
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Bookings',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ---------------- Booking List ----------------
            Expanded(
              child: Consumer<LoungeBookingProvider>(
                builder: (context, bookingProvider, child) {
                  if (bookingProvider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  if (bookingProvider.error != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 60,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            bookingProvider.error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red.shade400),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadBookings,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  // Both staff and owner use bookingProvider.bookings now
                  final bookings = bookingProvider.bookings;

                  if (bookings.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 60,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No bookings found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _loadBookings,
                    color: AppColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: bookings.length,
                      itemBuilder: (context, index) {
                        final booking = bookings[index];
                        return BookingCard(
                          bookingId: booking.id,
                          name: booking.passengerName ?? 'Guest',
                          place: booking.loungeName ?? 'Lounge',
                          time: _formatTime(booking.checkInTime),
                          status: booking.status,
                          bookingReference: booking.bookingReference,
                          guestCount: booking.guestCount,
                          phone: booking.passengerPhone,
                          blinkAnimation: _blinkController,
                          loungeId: _selectedLoungeId,
                          onViewOrders: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BookingOrdersPage(
                                  bookingId: booking.id,
                                  bookingReference: booking.bookingReference,
                                  guestName: booking.passengerName ?? 'Guest',
                                  allowStatusActions: !widget.isStaffMode,
                                ),
                              ),
                            );
                            if (!mounted) return;
                            _loadBookings();
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // ---------------- Receive Food Button ----------------
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ReceivedFoodScreen(isStaffMode: widget.isStaffMode),
                      ),
                    );
                  },
                  child: const Text(
                    'Received Food',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // ---------------- Bottom Navigation ----------------
      bottomNavigationBar: widget.isStaffMode
          ? const StaffBottomNavBar(currentIndex: 2)
          : OwnerBottomNavBar(
              currentIndex: 2,
              verificationStatus: Provider.of<LoungeOwnerProvider>(
                context,
                listen: false,
              ).loungeOwner?.verificationStatus,
            ),
    );
  }
}

// ---------------- Booking Card Widget ----------------
class BookingCard extends StatelessWidget {
  final String bookingId;
  final String name;
  final String place;
  final String time;
  final String status;
  final String bookingReference;
  final int guestCount;
  final String? phone;
  final AnimationController blinkAnimation;
  final String? loungeId;
  final VoidCallback onViewOrders;

  const BookingCard({
    super.key,
    required this.bookingId,
    required this.name,
    required this.place,
    required this.time,
    required this.status,
    required this.bookingReference,
    required this.guestCount,
    this.phone,
    required this.blinkAnimation,
    required this.loungeId,
    required this.onViewOrders,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
        color: AppColors.surface,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.accent,
                child: Icon(Icons.person, color: AppColors.textLight),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      place,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ref: $bookingReference',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Text(
                      'Guests: $guestCount',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (phone != null && phone!.isNotEmpty)
                      Text(
                        'Phone: $phone',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusText(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TukTukListPage(
                        loungeId: loungeId,
                        bookingId: bookingId,
                        guestName: name,
                        guestContact: phone,
                      ),
                    ),
                  );
                },
                child: FadeTransition(
                  opacity: blinkAnimation,
                  child: _buildActionIcon(
                    Icons.local_taxi,
                    "Vehicle List",
                    color: AppColors.primary,
                    isBlinking: true,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onViewOrders,
                child: _buildActionIcon(
                  Icons.receipt_long,
                  "View Orders",
                  color: const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon(
    IconData icon,
    String label, {
    Color? color,
    bool isBlinking = false,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (color ?? AppColors.textSecondary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color ?? AppColors.textSecondary, size: 24),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color ?? AppColors.textSecondary,
            fontWeight: isBlinking ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'active':
      case 'confirmed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'completed':
        return AppColors.info;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getStatusText() {
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }
}
