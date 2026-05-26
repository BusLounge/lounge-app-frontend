import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme_config.dart';
import '../../presentation/providers/driver_provider.dart';

class TukTukListPage extends StatefulWidget {
  final String? loungeId;
  final String? bookingId;
  final String? guestName;
  final String? guestContact;

  const TukTukListPage({
    super.key,
    this.loungeId,
    this.bookingId,
    this.guestName,
    this.guestContact,
  });

  @override
  State<TukTukListPage> createState() => _TukTukListPageState();
}

class _TukTukListPageState extends State<TukTukListPage> {
  Future<void> _showAlreadyAssignedDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Driver Already Assigned'),
          content: const Text(
            'A driver is already assigned to this booking.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _assignDriverToBooking({
    required String driverId,
    required String driverContact,
  }) async {
    final bookingId = widget.bookingId;
    final loungeId = widget.loungeId;

    if (bookingId == null || bookingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking id is missing')),
      );
      return;
    }

    if (loungeId == null || loungeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lounge id is missing')),
      );
      return;
    }

    final driverProvider = context.read<DriverProvider>();

    // Re-check assignment status immediately before assigning to prevent duplicates.
    final alreadyAssigned = await driverProvider.checkDriverAssigned(
      bookingId: bookingId,
    );

    if (!mounted) return;

    if (alreadyAssigned) {
      await _showAlreadyAssignedDialog();
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    final success = await driverProvider.assignDriverToBooking(
      bookingId: bookingId,
      driverId: driverId,
      loungeId: loungeId,
      guestName: (widget.guestName?.trim().isNotEmpty ?? false)
          ? widget.guestName!.trim()
          : 'Guest',
      guestContact: (widget.guestContact?.trim().isNotEmpty ?? false)
          ? widget.guestContact!.trim()
          : 'N/A',
      driverContact: driverContact,
    );

    if (!mounted) return;

    if (!success) {
      final message = driverProvider.error ?? 'Failed to assign driver';
      if (message.toLowerCase().contains('already assigned')) {
        await _showAlreadyAssignedDialog();
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Driver assigned'),
          content: const Text('Driver assigned'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.loungeId != null) {
        context
            .read<DriverProvider>()
            .getDriversByLounge(
              loungeId: widget.loungeId!,
            )
            .then((_) {
          if (widget.bookingId != null && widget.bookingId!.isNotEmpty) {
            context.read<DriverProvider>().checkDriverAssigned(
                  bookingId: widget.bookingId!,
                );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Drivers & Vehicles',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: Consumer<DriverProvider>(
        builder: (context, driverProvider, _) {
          if (driverProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (driverProvider.error != null) {
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
                    driverProvider.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade400),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (widget.loungeId != null) {
                        context.read<DriverProvider>().getDriversByLounge(
                              loungeId: widget.loungeId!,
                            );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final drivers = driverProvider.driverList;

          if (drivers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    size: 60,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No drivers found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              final assigned = driverProvider.existingAssignment;
              final bookingHasAssignedDriver = assigned != null;
              final isAssigned =
                  assigned != null && assigned.driverId == driver.id;
              final isAssignDisabled = bookingHasAssignedDriver && !isAssigned;
              return Column(
                children: [
                  TukTukCard(
                    name: driver.fullName,
                    vehicleNo: driver.vehicleNumber,
                    phone: driver.contactNumber,
                    isAssigned: isAssigned,
                    isAssignDisabled: isAssignDisabled,
                    onAssign: (isAssigned || isAssignDisabled)
                        ? null
                        : () => _assignDriverToBooking(
                              driverId: driver.id,
                              driverContact: driver.contactNumber,
                            ),
                  ),
                  if (index < drivers.length - 1) const SizedBox(height: 12),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class TukTukCard extends StatefulWidget {
  final String name;
  final String vehicleNo;
  final String phone;
  final VoidCallback? onAssign;
  final bool isAssigned;
  final bool isAssignDisabled;

  const TukTukCard({
    super.key,
    required this.name,
    required this.vehicleNo,
    required this.phone,
    this.onAssign,
    this.isAssigned = false,
    this.isAssignDisabled = false,
  });

  @override
  State<TukTukCard> createState() => _TukTukCardState();
}

class _TukTukCardState extends State<TukTukCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: const Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Tuk Tuk',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.directions_car,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(widget.vehicleNo,
                  style: const TextStyle(color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.phone, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(widget.phone,
                  style: const TextStyle(color: AppColors.textPrimary)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () async {
                  final phoneUrl = Uri(scheme: 'tel', path: widget.phone);
                  if (await canLaunchUrl(phoneUrl)) {
                    await launchUrl(phoneUrl);
                  }
                },
                icon: const Icon(Icons.call, size: 16),
                label: const Text('Call'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: widget.onAssign,
                icon: const Icon(Icons.assignment_ind, size: 16),
                label: widget.isAssigned
                    ? const Text('Assigned')
                    : (widget.isAssignDisabled
                        ? const Text('Already Assigned')
                        : const Text('Assign')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isAssigned
                      ? Colors.green
                      : (widget.isAssignDisabled
                          ? Colors.grey
                          : AppColors.primary),
                  foregroundColor: AppColors.textLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
