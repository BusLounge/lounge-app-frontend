import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme_config.dart';
import '../../presentation/providers/driver_provider.dart';
import '../../presentation/providers/lounge_booking_provider.dart';

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
  String? _assignedDriverId;
  String? _assignedAssignmentId;

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

  Future<void> _cancelAssignedDriver(String assignmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel assigned driver?'),
          content: const Text(
            'This will remove the current driver assignment for this booking.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Yes, cancel'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    if (!mounted || widget.bookingId == null || widget.bookingId!.isEmpty) {
      return;
    }

    final driverProvider = context.read<DriverProvider>();
    final success = await driverProvider.cancelDriverAssignment(
      assignmentId: assignmentId,
    );

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(driverProvider.error ?? 'Failed to cancel assignment'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    await _refreshAssignedDriverState();

    if (widget.loungeId != null && widget.loungeId!.isNotEmpty) {
      await context.read<DriverProvider>().getDriversByLounge(
            loungeId: widget.loungeId!,
          );
      await _refreshAssignedDriverState();
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Driver assignment cancelled')),
    );
  }

  Future<void> _completeAssignedDriver(String assignmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Complete driver assignment?'),
          content: const Text(
            'This will complete the driver assignment and mark transport as finished.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Yes, complete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    if (!mounted || widget.bookingId == null || widget.bookingId!.isEmpty) {
      return;
    }

    final driverProvider = context.read<DriverProvider>();
    final success = await driverProvider.completeDriverAssignment(
      assignmentId: assignmentId,
    );

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(driverProvider.error ?? 'Failed to complete assignment'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    await _refreshAssignedDriverState();

    if (widget.loungeId != null && widget.loungeId!.isNotEmpty) {
      await context.read<DriverProvider>().getDriversByLounge(
            loungeId: widget.loungeId!,
          );
      await _refreshAssignedDriverState();
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Driver assignment completed')),
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

  Future<void> _refreshAssignedDriverState() async {
    final bookingId = widget.bookingId;
    if (bookingId == null || bookingId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _assignedDriverId = null;
        _assignedAssignmentId = null;
      });
      return;
    }

    final driverProvider = context.read<DriverProvider>();
    final assigned = await driverProvider.checkDriverAssigned(
      bookingId: bookingId,
    )
        ? driverProvider.existingAssignment
        : null;

    if (!mounted) return;

    setState(() {
      _assignedDriverId = assigned?.driverId;
      _assignedAssignmentId = assigned?.id;
    });
  }

  bool get _hasAssignedDriver => _assignedDriverId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.bookingId != null) {
        context.read<LoungeBookingProvider>().getBookingById(widget.bookingId!);
      }
      if (widget.loungeId != null) {
        context
            .read<DriverProvider>()
            .getDriversByLounge(
              loungeId: widget.loungeId!,
            )
            .then((_) => _refreshAssignedDriverState());
      } else {
        _refreshAssignedDriverState();
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
      body: Consumer2<DriverProvider, LoungeBookingProvider>(
        builder: (context, driverProvider, loungeBookingProvider, _) {
          final booking = loungeBookingProvider.selectedBooking;
          final showBookingInfo = booking != null && booking.id == widget.bookingId;
          
          Widget? bookingInfoCard;
          if (showBookingInfo) {
            final vehicleType = booking.vehicleType ?? 'N/A';
            final pickupLocation = booking.pickupLocationName ?? 'N/A';
            
            bookingInfoCard = Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Booking Transport Details',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.directions_car, color: AppColors.secondary, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Vehicle Booked: ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        vehicleType.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Pickup Location: ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          pickupLocation,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          Widget content;
          if (driverProvider.isLoading) {
            content = const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          } else if (driverProvider.error != null) {
            content = Center(
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
          } else {
            final drivers = driverProvider.driverList;
            if (drivers.isEmpty) {
              content = Center(
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
            } else {
              content = ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: drivers.length,
                itemBuilder: (context, index) {
                  final driver = drivers[index];
                  final isAssigned = _assignedDriverId == driver.id;
                  final isAssignDisabled = _hasAssignedDriver && !isAssigned;
                  final assignmentId = _assignedAssignmentId;
                  return Column(
                    children: [
                      TukTukCard(
                        name: driver.fullName,
                        vehicleNo: driver.vehicleNumber,
                        phone: driver.contactNumber,
                        vehicleType: driver.vehicleType,
                        isAssigned: isAssigned,
                        isAssignDisabled: isAssignDisabled,
                        onAssign: (isAssigned || isAssignDisabled)
                            ? null
                            : () => _assignDriverToBooking(
                                  driverId: driver.id,
                                  driverContact: driver.contactNumber,
                                ),
                        onCancelAssignment: (isAssigned && assignmentId != null)
                            ? () => _cancelAssignedDriver(assignmentId)
                            : null,
                        onCompleteAssignment: (isAssigned && assignmentId != null)
                            ? () => _completeAssignedDriver(assignmentId)
                            : null,
                      ),
                      if (index < drivers.length - 1) const SizedBox(height: 12),
                    ],
                  );
                },
              );
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (bookingInfoCard != null) bookingInfoCard,
              Expanded(child: content),
            ],
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
  final String vehicleType;
  final VoidCallback? onAssign;
  final VoidCallback? onCancelAssignment;
  final VoidCallback? onCompleteAssignment;
  final bool isAssigned;
  final bool isAssignDisabled;

  const TukTukCard({
    super.key,
    required this.name,
    required this.vehicleNo,
    required this.phone,
    required this.vehicleType,
    this.onAssign,
    this.onCancelAssignment,
    this.onCompleteAssignment,
    this.isAssigned = false,
    this.isAssignDisabled = false,
  });

  @override
  State<TukTukCard> createState() => _TukTukCardState();
}

class _TukTukCardState extends State<TukTukCard> {
  String _getFormattedVehicleType(String type) {
    switch (type.toLowerCase()) {
      case 'three_wheeler':
        return 'Three Wheeler';
      case 'van':
        return 'Van';
      case 'car':
        return 'Car';
      default:
        if (type.isEmpty) return 'Vehicle';
        return type[0].toUpperCase() + type.substring(1);
    }
  }

  IconData _getVehicleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'three_wheeler':
        return Icons.electric_rickshaw;
      case 'van':
        return Icons.airport_shuttle;
      case 'car':
        return Icons.directions_car;
      default:
        return Icons.directions_car;
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignedCardColor = Colors.orange.shade50;
    final assignedBorderColor = Colors.orange.shade700;
    final assignedAccentColor = Colors.orange.shade800;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isAssigned ? assignedCardColor : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isAssigned ? assignedBorderColor : AppColors.primary,
          width: widget.isAssigned ? 1.4 : 1,
        ),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: widget.isAssigned
                              ? assignedAccentColor
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (widget.isAssigned) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade200,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'ASSIGNED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.deepOrange,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.isAssigned
                          ? Colors.orange.shade200
                          : AppColors.secondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.isAssigned
                          ? 'Assigned ${_getFormattedVehicleType(widget.vehicleType)}'
                          : _getFormattedVehicleType(widget.vehicleType),
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isAssigned
                            ? Colors.deepOrange
                            : AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.isAssigned) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade700),
                      ),
                      child: Text(
                        'Assigned for booking',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.deepOrange.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(_getVehicleIcon(widget.vehicleType),
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
              Expanded(
                child: Text(
                  widget.phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                fit: FlexFit.loose,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final phoneUrl =
                              Uri(scheme: 'tel', path: widget.phone);
                          if (await canLaunchUrl(phoneUrl)) {
                            await launchUrl(phoneUrl);
                          }
                        },
                        icon: const Icon(Icons.call, size: 16),
                        label: const Text('Call'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (widget.isAssigned) ...[
                        ElevatedButton.icon(
                          onPressed: widget.onCancelAssignment,
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('Cancel'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: Colors.deepOrange.shade700,
                            foregroundColor: AppColors.textLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: widget.onCompleteAssignment,
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Complete'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: AppColors.textLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ]
                      else
                        ElevatedButton.icon(
                          onPressed: widget.onAssign,
                          icon: const Icon(Icons.assignment_ind, size: 16),
                          label: widget.isAssignDisabled
                              ? const Text('Already')
                              : const Text('Assign'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: widget.isAssignDisabled
                                ? Colors.grey
                                : AppColors.primary,
                            foregroundColor: AppColors.textLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (widget.isAssigned) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.deepOrange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Assigned driver for this booking',
                  style: TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
