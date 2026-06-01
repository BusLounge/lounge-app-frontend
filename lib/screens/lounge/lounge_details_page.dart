import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme_config.dart';
import '../../core/di/injection_container.dart';
import '../../core/services/image_cache_service.dart';
import '../../data/datasources/route_remote_datasource.dart';
import '../../data/models/route_model.dart';
import '../../domain/entities/lounge.dart';
import '../../presentation/providers/registration_provider.dart';
import 'edit_lounge_details_page.dart';
import 'owner_lounge_blog_details_page.dart';

class LoungeDetailsPage extends StatefulWidget {
  final Lounge lounge;

  const LoungeDetailsPage({super.key, required this.lounge});

  @override
  State<LoungeDetailsPage> createState() => _LoungeDetailsPageState();
}

class _LoungeDetailsPageState extends State<LoungeDetailsPage> {
  late Lounge _lounge;
  late RouteRemoteDataSource _routeRemoteDataSource;
  List<MasterRoute> _masterRoutes = [];
  final Map<String, List<MasterRouteStop>> _routeStopsByRouteId = {};

  @override
  void initState() {
    super.initState();
    _lounge = widget.lounge;
    _routeRemoteDataSource = RouteRemoteDataSource(
      apiClient: InjectionContainer().apiClient,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshLounge();
      await _loadRouteMetadata();
    });
  }

  Future<void> _refreshLounge() async {
    final lounge = await Provider.of<RegistrationProvider>(
      context,
      listen: false,
    ).getLoungeDetails(_lounge.id);

    if (!mounted || lounge == null) return;
    setState(() {
      _lounge = lounge;
    });
  }

  Future<void> _loadRouteMetadata() async {
    final loungeRoutes = _lounge.routes ?? const [];
    if (loungeRoutes.isEmpty) return;

    try {
      final routes = await _routeRemoteDataSource.getMasterRoutes();
      if (!mounted) return;

      _masterRoutes = routes;

      final routeIds = loungeRoutes.map((r) => r.masterRouteId).toSet();
      for (final routeId in routeIds) {
        if (_routeStopsByRouteId.containsKey(routeId)) continue;
        try {
          _routeStopsByRouteId[routeId] =
              await _routeRemoteDataSource.getRouteStops(routeId);
        } catch (_) {
          _routeStopsByRouteId[routeId] = const [];
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // Keep UI usable even if route metadata fetch fails.
    }
  }

  MasterRoute? _masterRouteForId(String routeId) {
    try {
      return _masterRoutes.firstWhere((route) => route.id == routeId);
    } catch (_) {
      return null;
    }
  }

  String _routeLabel(String routeId) {
    final route = _masterRouteForId(routeId);
    if (route == null) return 'Route details unavailable';
    return '${route.routeNumber}: ${route.routeName} (${route.routeDisplay})';
  }

  String _stopLabel(String routeId, String stopId) {
    final cachedStops = _routeStopsByRouteId[routeId] ?? const [];
    for (final stop in cachedStops) {
      if (stop.id == stopId) return stop.stopName;
    }

    final route = _masterRouteForId(routeId);
    if (route != null) {
      for (final stop in route.stops) {
        if (stop.id == stopId) return stop.stopName;
      }
    }

    return 'Unknown stop';
  }

  Future<void> _openEditPage() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditLoungeDetailsPage(initialLounge: _lounge),
      ),
    );

    if (updated == true) {
      await _refreshLounge();
    }
  }

  void _openViewDetailsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OwnerLoungeBlogDetailsPage(lounge: _lounge),
      ),
    );
  }

  Future<void> _deleteLounge() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lounge'),
        content: Text(
          'Are you sure you want to delete ${_lounge.loungeName}? This action cannot be undone.',
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

    final success = await Provider.of<RegistrationProvider>(
      context,
      listen: false,
    ).deleteLoungeById(_lounge.id);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lounge deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
      return;
    }

    final provider = Provider.of<RegistrationProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(provider.errorMessage ?? 'Failed to delete lounge'),
        backgroundColor: AppColors.error,
      ),
    );
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
          'Lounge Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _openEditPage,
            icon: const Icon(Icons.edit, color: AppColors.textPrimary),
            tooltip: 'Edit Lounge',
          ),
          IconButton(
            onPressed: _deleteLounge,
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            tooltip: 'Delete Lounge',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openViewDetailsPage,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('View Details'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: AppColors.primary,
                    side:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionCard(
                title: 'Basic Information',
                icon: Icons.info_outline,
                children: [
                  _buildInfoRow('Lounge Name', _lounge.loungeName, Icons.store),
                  _buildInfoRow(
                    'Description',
                    _lounge.description ?? 'Not provided',
                    Icons.description_outlined,
                  ),
                  _buildInfoRow('Address', _lounge.address, Icons.location_on),
                  _buildInfoRow(
                    'Contact Number',
                    _lounge.contactPhone ?? 'Not provided',
                    Icons.phone,
                  ),
                  _buildInfoRow(
                    'Capacity',
                    _lounge.capacity?.toString() ?? 'Not provided',
                    Icons.people,
                  ),
                  _buildInfoRow('Status', _lounge.status, Icons.verified_user),
                ],
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'Pricing',
                icon: Icons.currency_rupee,
                children: [
                  _buildInfoRow(
                    '1 Hour',
                    _priceLabel(_lounge.price1Hour),
                    Icons.access_time,
                  ),
                  _buildInfoRow(
                    '2 Hours',
                    _priceLabel(_lounge.price2Hours),
                    Icons.schedule,
                  ),
                  _buildInfoRow(
                    '3 Hours',
                    _priceLabel(_lounge.price3Hours),
                    Icons.timelapse,
                  ),
                  _buildInfoRow(
                    'Until Bus',
                    _priceLabel(_lounge.priceUntilBus),
                    Icons.directions_bus,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'Location',
                icon: Icons.map_outlined,
                children: [
                  _buildInfoRow(
                    'State',
                    _sanitizeLocationText(_lounge.state) ?? 'Not provided',
                    Icons.map,
                  ),
                  _buildInfoRow(
                    'Country',
                    (_lounge.country == null || _lounge.country!.trim().isEmpty)
                        ? 'Sri Lanka'
                        : _lounge.country!,
                    Icons.public,
                  ),
                  _buildInfoRow(
                    'Postal Code',
                    _lounge.postalCode ?? 'Not provided',
                    Icons.markunread_mailbox_outlined,
                  ),
                  _buildInfoRow(
                    'Latitude',
                    _lounge.latitude ?? 'Not provided',
                    Icons.place_outlined,
                  ),
                  _buildInfoRow(
                    'Longitude',
                    _lounge.longitude ?? 'Not provided',
                    Icons.place,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildAmenitiesSection(),
              const SizedBox(height: 16),
              _buildRoutesSection(),
              const SizedBox(height: 16),
              _buildImagesSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              image: _lounge.primaryPhoto != null
                  ? DecorationImage(
                      image: NetworkImage(_lounge.primaryPhoto!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _lounge.primaryPhoto == null
                ? Icon(
                    Icons.apartment,
                    size: 64,
                    color: Colors.grey.shade400,
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            _lounge.loungeName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor(_lounge.status).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _lounge.status.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _statusColor(_lounge.status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenitiesSection() {
    final amenities = _lounge.amenities ?? const [];

    return _buildSectionCard(
      title: 'Amenities',
      icon: Icons.miscellaneous_services,
      children: [
        if (amenities.isEmpty)
          const Text(
            'No amenities available',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: amenities.map((amenity) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.primary.withOpacity(0.18)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LoungeAmenities.icons[amenity] ?? Icons.check_circle,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      LoungeAmenities.labels[amenity] ?? amenity,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildRoutesSection() {
    final routes = _lounge.routes ?? const [];

    return _buildSectionCard(
      title: 'Routes',
      icon: Icons.alt_route,
      children: [
        if (routes.isEmpty)
          const Text(
            'No routes available',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          ...routes.asMap().entries.map(
                (entry) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Route ${entry.key + 1}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_routeLabel(entry.value.masterRouteId)),
                      Text(
                        'Between: ${_stopLabel(entry.value.masterRouteId, entry.value.stopBeforeId)} -> ${_stopLabel(entry.value.masterRouteId, entry.value.stopAfterId)}',
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildImagesSection() {
    final images = _lounge.images ?? const [];

    return _buildSectionCard(
      title: 'Images',
      icon: Icons.photo_library_outlined,
      children: [
        if (images.isEmpty)
          const Text(
            'No lounge images available',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: OptimizedCachedImage(
                  imageUrl: images[index],
                  width: 140,
                  height: 110,
                  fit: BoxFit.cover,
                  quality: 'sd',
                  errorWidget: (context, error, stackTrace) => Container(
                    width: 140,
                    height: 110,
                    color: Colors.grey.shade100,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _priceLabel(String? value) {
    if (value == null || value.trim().isEmpty) return 'Not provided';
    return 'LKR $value';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return const Color(0xFF2E7D32);
      case 'pending':
        return const Color(0xFFF57C00);
      case 'suspended':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  String? _sanitizeLocationText(String? value) {
    if (value == null) return null;
    final cleaned = value.trim();
    if (cleaned.isEmpty) return null;

    final lower = cleaned.toLowerCase();
    const knownCodeLikeValues = {
      'null',
      'nil',
      'undefined',
      'n/a',
      'na',
      'id',
      'unknown',
    };
    if (knownCodeLikeValues.contains(lower)) return null;

    final isNumericOnly = RegExp(r'^\d+$').hasMatch(cleaned);
    final isUuidLike = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(cleaned);
    final isMongoLike = RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(cleaned);
    final idPrefix = lower.startsWith('id_') ||
        lower.startsWith('district_') ||
        lower.startsWith('state_');

    if (isNumericOnly || isUuidLike || isMongoLike || idPrefix) {
      return null;
    }

    return cleaned;
  }
}
