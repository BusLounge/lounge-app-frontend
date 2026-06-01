import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../core/services/image_cache_service.dart';
import '../../domain/entities/lounge.dart';

class OwnerLoungeBlogDetailsPage extends StatelessWidget {
  final Lounge lounge;

  const OwnerLoungeBlogDetailsPage({super.key, required this.lounge});

  @override
  Widget build(BuildContext context) {
    final imageUrl = lounge.primaryPhoto;
    final amenities = lounge.amenities ?? const <String>[];
    final images = lounge.images ?? const <String>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F8FC),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'View Details',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHero(imageUrl),
            const SizedBox(height: 18),
            Text(
              lounge.loungeName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(Icons.verified_outlined, lounge.status.toUpperCase()),
                if (lounge.capacity != null)
                  _chip(Icons.people_outline, 'Capacity ${lounge.capacity}'),
                if (lounge.isOperational) _chip(Icons.bolt, 'Operational'),
              ],
            ),
            const SizedBox(height: 20),
            _sectionCard(
              title: 'About This Lounge',
              child: Text(
                (lounge.description == null ||
                        lounge.description!.trim().isEmpty)
                    ? 'No description has been provided yet.'
                    : lounge.description!,
                style: const TextStyle(
                  height: 1.6,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Quick Snapshot',
              child: Column(
                children: [
                  _infoRow(
                      Icons.location_on_outlined, 'Address', lounge.address),
                  _infoRow(
                    Icons.phone_outlined,
                    'Contact',
                    lounge.contactPhone ?? 'Not provided',
                  ),
                  _infoRow(
                    Icons.map_outlined,
                    'District / State',
                    _joinParts([
                      _sanitizeLocationText(lounge.district),
                      _sanitizeLocationText(lounge.state),
                    ]),
                  ),
                  _infoRow(
                    Icons.public,
                    'Country',
                    (lounge.country == null || lounge.country!.trim().isEmpty)
                        ? 'Sri Lanka'
                        : lounge.country!,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Pricing',
              child: Column(
                children: [
                  _priceRow('1 Hour', lounge.price1Hour),
                  _priceRow('2 Hours', lounge.price2Hours),
                  _priceRow('3 Hours', lounge.price3Hours),
                  _priceRow('Until Bus', lounge.priceUntilBus),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Amenities',
              child: amenities.isEmpty
                  ? const Text(
                      'No amenities listed yet.',
                      style: TextStyle(color: AppColors.textSecondary),
                    )
                  : Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: amenities
                          .map(
                            (amenity) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LoungeAmenities.icons[amenity] ??
                                        Icons.check_circle_outline,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    LoungeAmenities.labels[amenity] ?? amenity,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            if (images.isNotEmpty) ...[
              const SizedBox(height: 14),
              _sectionCard(
                title: 'Gallery',
                child: SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: OptimizedCachedImage(
                          imageUrl: images[index],
                          width: 160,
                          height: 120,
                          fit: BoxFit.cover,
                          quality: 'sd',
                          errorWidget: (_, __, ___) => Container(
                            width: 160,
                            height: 120,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHero(String? imageUrl) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF2F6C9E), Color(0xFF88C9A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl.trim().isNotEmpty)
              OptimizedCachedImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                quality: 'hd',
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.05),
                    Colors.black.withOpacity(0.45),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lounge.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String? amount) {
    final hasAmount = amount != null && amount.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(
            hasAmount ? 'LKR $amount' : 'Not set',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color:
                  hasAmount ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _joinParts(List<String?> values) {
    final parts = values
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'Not provided';
    return parts.join(', ');
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
