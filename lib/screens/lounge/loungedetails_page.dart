import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../widgets/staff_bottom_nav_bar.dart';
import '../../domain/entities/lounge.dart';
import '../../data/datasources/lounge_remote_datasource.dart';
import '../../core/network/api_client.dart';
import '../../data/datasources/auth_local_datasource.dart';
import '../../data/models/lounge_model.dart';
import '../../presentation/providers/lounge_staff_provider.dart';
import '../../core/services/image_cache_service.dart';

class LoungeDetailsPage extends StatefulWidget {
  final String? loungeId;

  const LoungeDetailsPage({
    super.key,
    this.loungeId,
  });

  @override
  State<LoungeDetailsPage> createState() => _LoungeDetailsPageState();
}

class _LoungeDetailsPageState extends State<LoungeDetailsPage> {
  Lounge? _lounge;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLoungeData();
  }

  Future<void> _loadLoungeData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String? loungeId = widget.loungeId;

      // If no loungeId provided, get it from staff profile
      if (loungeId == null) {
        final staffProvider = context.read<LoungeStaffProvider>();
        loungeId = staffProvider.selectedStaff?.loungeId;
      }

      if (loungeId == null) {
        setState(() {
          _error = 'No lounge associated with your account';
          _isLoading = false;
        });
        return;
      }

      final authLocalDataSource = AuthLocalDataSourceImpl(
        secureStorage: const FlutterSecureStorage(),
      );
      final apiClient = ApiClient(authLocalDataSource);
      final loungeDataSource = LoungeRemoteDataSource(apiClient: apiClient);
      final loungeData = await loungeDataSource.getLoungeById(loungeId);

      setState(() {
        _lounge = LoungeModel.fromJson(loungeData);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load lounge details: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),

      /// APP BAR
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Lounge Details',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),

      /// BODY
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
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
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red.shade400),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadLoungeData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _lounge == null
                  ? const Center(
                      child: Text('No lounge data available'),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// IMAGE
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              children: [
                                _lounge!.primaryPhoto != null &&
                                        _lounge!.primaryPhoto!.isNotEmpty
                                    ? OptimizedCachedImage(
                                        imageUrl: _lounge!.primaryPhoto!,
                                        height: 200,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        quality: 'hd',
                                        loadingWidget: (context, url) {
                                          return Container(
                                            height: 200,
                                            color: Colors.grey.shade200,
                                            child: const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          );
                                        },
                                        errorWidget: (context, url, error) {
                                          return Container(
                                            height: 200,
                                            color: Colors.grey.shade300,
                                            child: const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.image_not_supported,
                                                  size: 50,
                                                  color: Colors.grey,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Image not available',
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        height: 200,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.grey.shade200,
                                              Colors.grey.shade300,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons
                                                  .add_photo_alternate_outlined,
                                              size: 60,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'No photos uploaded yet',
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Add photos when editing lounge',
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                if (_lounge!.images != null &&
                                    _lounge!.images!.isNotEmpty)
                                  Positioned(
                                    right: 12,
                                    top: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '1 / ${_lounge!.images!.length}',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          /// STATUS + SHARE
                          Row(
                            children: [
                              _buildStatusChip(_lounge!.status),
                              const Spacer(),
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.share_outlined),
                              ),
                            ],
                          ),

                          /// TITLE
                          Text(
                            _lounge!.loungeName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),

                          /// DESCRIPTION
                          if (_lounge!.description != null)
                            Text(
                              _lounge!.description!,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                height: 1.5,
                              ),
                            ),

                          const SizedBox(height: 12),

                          /// CAPACITY
                          if (_lounge!.capacity != null)
                            Row(
                              children: [
                                const Icon(Icons.groups,
                                    color: Colors.orange, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Capacity: ${_lounge!.capacity} people',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),

                          const SizedBox(height: 20),

                          /// FACILITIES
                          if (_lounge!.amenities != null &&
                              _lounge!.amenities!.isNotEmpty) ...[
                            const Text(
                              'Facilities',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _lounge!.amenities!
                                  .map((amenity) => FacilityItem(
                                        icon: _getAmenityIcon(amenity),
                                        label: _getAmenityLabel(amenity),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 24),
                          ],

                          /// LOCATION
                          const Text(
                            'Location & Contact',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          const SizedBox(height: 12),

                          InfoRow(
                            icon: Icons.location_on,
                            text: _lounge!.address,
                          ),
                          if (_lounge!.contactPhone != null) ...[
                            const SizedBox(height: 8),
                            InfoRow(
                              icon: Icons.phone,
                              text: _lounge!.contactPhone!,
                            ),
                          ],

                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // TODO: Open map with location
                              },
                              icon: const Icon(Icons.map),
                              label: const Text('View on Map'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          /// PRICES
                          if (_lounge!.price1Hour != null ||
                              _lounge!.price2Hours != null ||
                              _lounge!.price3Hours != null ||
                              _lounge!.priceUntilBus != null) ...[
                            const Text(
                              'Pricing',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            if (_lounge!.price1Hour != null)
                              _buildPriceCard('1 Hour', _lounge!.price1Hour!),
                            if (_lounge!.price2Hours != null)
                              _buildPriceCard('2 Hours', _lounge!.price2Hours!),
                            if (_lounge!.price3Hours != null)
                              _buildPriceCard('3 Hours', _lounge!.price3Hours!),
                            if (_lounge!.priceUntilBus != null)
                              _buildPriceCard(
                                  'Until Bus', _lounge!.priceUntilBus!),
                          ],

                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
      bottomNavigationBar: const StaffBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status.toLowerCase()) {
      case 'active':
      case 'approved':
      case 'verified':
        bgColor = Colors.green.shade100;
        textColor = Colors.green;
        label = 'Approved';
        break;
      case 'pending':
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange;
        label = 'Pending';
        break;
      case 'inactive':
      case 'suspended':
        bgColor = Colors.red.shade100;
        textColor = Colors.red;
        label = 'Inactive';
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  IconData _getAmenityIcon(String amenity) {
    switch (amenity.toLowerCase()) {
      case 'wifi':
        return Icons.wifi;
      case 'ac':
        return Icons.ac_unit;
      case 'parking':
        return Icons.local_parking;
      case 'cafeteria':
      case 'restaurant':
        return Icons.restaurant;
      case 'charging_ports':
        return Icons.charging_station;
      case 'entertainment':
        return Icons.tv;
      case 'restrooms':
        return Icons.wc;
      case 'waiting_area':
        return Icons.event_seat;
      default:
        return Icons.check_circle;
    }
  }

  String _getAmenityLabel(String amenity) {
    switch (amenity.toLowerCase()) {
      case 'wifi':
        return 'WiFi';
      case 'ac':
        return 'AC';
      case 'parking':
        return 'Parking';
      case 'cafeteria':
        return 'Cafeteria';
      case 'restaurant':
        return 'Restaurant';
      case 'charging_ports':
        return 'Charging';
      case 'entertainment':
        return 'TV';
      case 'restrooms':
        return 'Restrooms';
      case 'waiting_area':
        return 'Waiting Area';
      default:
        return amenity;
    }
  }

  Widget _buildPriceCard(String duration, String price) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            duration,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Rs $price',
            style: TextStyle(
              color: Colors.orange.shade700,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------- FACILITY ITEM ----------
class FacilityItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const FacilityItem({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.orange),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// ---------- INFO ROW ----------
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const InfoRow({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
