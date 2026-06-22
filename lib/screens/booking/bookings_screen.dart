import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/owner_bottom_nav_bar.dart';
import '../../presentation/providers/lounge_owner_provider.dart';
import '../../presentation/providers/lounge_booking_provider.dart';
import '../../presentation/providers/registration_provider.dart';
import '../../config/theme_config.dart';
import 'booking_orders_page.dart';

/// Screen for viewing and managing bookings
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  String _selectedFilter = 'all';
  String? _selectedLoungeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookings();
    });
  }

  Future<void> _loadBookings() async {
    final bookingProvider = context.read<LoungeBookingProvider>();
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

    final selectedLoungeId = _selectedLoungeId;

    // Load bookings based on filter
    if (_selectedFilter == 'all') {
      await bookingProvider.getOwnerBookings(loungeId: selectedLoungeId);
    } else {
      await bookingProvider.getOwnerBookings(
        loungeId: selectedLoungeId,
        status: _selectedFilter,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFFBF5);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text(
          'Bookings',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        actions: [
          // Filter dropdown
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: DropdownButton<String>(
              value: _selectedFilter,
              underline: const SizedBox(),
              icon: const Icon(Icons.filter_list, color: AppColors.primary),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                DropdownMenuItem(
                    value: 'checked_in', child: Text('Checked In')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                DropdownMenuItem(value: 'no_show', child: Text('No Show')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedFilter = value;
                  });
                  _loadBookings();
                }
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer2<LoungeBookingProvider, RegistrationProvider>(
          builder: (context, bookingProvider, registrationProvider, child) {
            final verifiedLounges = registrationProvider.verifiedLounges;
            if (verifiedLounges.isEmpty) {
              return const Center(
                child: Text(
                  'No verified lounges yet',
                  style:
                      TextStyle(fontSize: 16, color: AppColors.textSecondary),
                ),
              );
            }

            if (bookingProvider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (bookingProvider.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Error',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        bookingProvider.error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
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

            final bookings = bookingProvider.bookings;

            if (bookings.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Bookings',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You don\'t have any bookings yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadBookings,
                    color: AppColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: bookings.length,
                      itemBuilder: (context, index) {
                        final booking = bookings[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        AppColors.primary.withOpacity(0.1),
                                    child: const Icon(
                                      Icons.person,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  title: Text(
                                    booking.passengerName ?? 'Guest',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(booking.loungeName ?? 'Lounge'),
                                      Text('Ref: ${booking.bookingReference}'),
                                      Text(
                                          'Scheduled Arrival: ${_formatDateTime(booking.scheduledArrival)}'),
                                      Text('Guests: ${booking.guestCount}'),
                                      if (booking.passengerPhone != null &&
                                          booking.passengerPhone!.isNotEmpty)
                                        Text(
                                            'Phone: ${booking.passengerPhone}'),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(booking.status)
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      booking.status,
                                      style: TextStyle(
                                        color: _getStatusColor(booking.status),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  isThreeLine: true,
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              BookingOrdersPage(
                                            bookingId: booking.id,
                                            bookingReference:
                                                booking.bookingReference,
                                            guestName: booking.passengerName ??
                                                'Guest',
                                            allowStatusActions: true,
                                          ),
                                        ),
                                      );
                                      if (!mounted) return;
                                      _loadBookings();
                                    },
                                    icon: const Icon(Icons.receipt_long),
                                    label: const Text('View Orders'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: OwnerBottomNavBar(
        currentIndex: 2,
        verificationStatus: Provider.of<LoungeOwnerProvider>(
          context,
          listen: false,
        ).loungeOwner?.verificationStatus,
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';

    final localDateTime = dateTime.toLocal();
    final date = "${localDateTime.year}-${localDateTime.month.toString().padLeft(2, '0')}-${localDateTime.day.toString().padLeft(2, '0')}";
    final hour = localDateTime.hour;
    final minute = localDateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'pm' : 'am';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$date $hour12:$minute $period';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'confirmed':
      case 'checked_in':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
      case 'no_show':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
