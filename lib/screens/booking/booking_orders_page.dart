import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme_config.dart';
import '../../domain/entities/lounge_product.dart';
import '../../presentation/providers/marketplace_provider.dart';
import '../../presentation/providers/lounge_booking_provider.dart';

class BookingOrdersPage extends StatefulWidget {
  final String bookingId;
  final String bookingReference;
  final String guestName;
  final bool allowStatusActions;

  const BookingOrdersPage({
    super.key,
    required this.bookingId,
    required this.bookingReference,
    required this.guestName,
    this.allowStatusActions = true,
  });

  @override
  State<BookingOrdersPage> createState() => _BookingOrdersPageState();
}

class _BookingOrdersPageState extends State<BookingOrdersPage> {
  bool _isLoading = true;
  String? _error;
  List<_OrderWithItems> _orders = const [];
  int _summaryCount = 0;
  String _totalAmount = '0.00';
  String _bookingStatus = 'pending';
  bool _isCompletingBooking = false;
  final Set<String> _updatingOrderIds = <String>{};
  String? _loungeId;
  Map<String, LoungeProduct> _productsById = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final provider = context.read<LoungeBookingProvider>();
    final data = await provider.getBookingOrders(bookingId: widget.bookingId);

    if (!mounted) return;

    if (data == null) {
      setState(() {
        _isLoading = false;
        _error = provider.error ?? 'Failed to load booking orders';
      });
      return;
    }

    final bookingMap = _BookingOrdersViewData._extractBooking(data);
    final loungeId = bookingMap?['lounge_id']?.toString();

    if (loungeId != null && loungeId.isNotEmpty && loungeId != _loungeId) {
      _loungeId = loungeId;
      await _loadMarketplaceProducts(loungeId);
    }

    final parsed = _BookingOrdersViewData.fromApi(
      data,
      productsById: _productsById,
    );

    setState(() {
      _isLoading = false;
      _orders = parsed.orders;
      _summaryCount = parsed.summaryCount;
      _totalAmount = parsed.ordersTotalAmount;
      _bookingStatus = parsed.bookingStatus;
    });
  }

  Future<void> _markBookingCompleted() async {
    if (_isCompletingBooking) return;

    setState(() => _isCompletingBooking = true);
    final provider = context.read<LoungeBookingProvider>();
    final message = await provider.completeBooking(bookingId: widget.bookingId);

    if (!mounted) return;

    setState(() => _isCompletingBooking = false);

    if (message == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Failed to complete booking')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    await _loadOrders();
  }

  Future<void> _markOrderCompleted(String orderId) async {
    if (_updatingOrderIds.contains(orderId)) return;

    setState(() => _updatingOrderIds.add(orderId));
    final provider = context.read<LoungeBookingProvider>();
    final message = await provider.updateOrderStatus(
      orderId: orderId,
      status: 'completed',
    );

    if (!mounted) return;

    setState(() => _updatingOrderIds.remove(orderId));

    if (message == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Failed to complete order')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    await _loadOrders();
  }

  Future<void> _loadMarketplaceProducts(String loungeId) async {
    final marketplaceProvider = context.read<MarketplaceProvider>();
    try {
      await marketplaceProvider.loadProducts(loungeId);
      if (!mounted) return;

      setState(() {
        _productsById = {
          for (final product in marketplaceProvider.products)
            product.id: product,
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _productsById = {};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Booking Orders',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 52,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: _loadOrders,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadOrders,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      children: [
                        _buildBookingSummary(),
                        const SizedBox(height: 14),
                        _buildOrdersSummary(),
                        const SizedBox(height: 14),
                        if (_orders.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              'No food orders available for this booking.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        else
                          ..._orders.map(_buildOrderCard),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildBookingSummary() {
    final isBookingCompleted = _bookingStatus.toLowerCase() == 'completed';
    final canCompleteBooking = _bookingStatus.toLowerCase() == 'checked_in';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.guestName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ref: ${widget.bookingReference}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          Text(
            'Booking ID: ${widget.bookingId}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatusChip(_bookingStatus),
              const SizedBox(width: 10),
              if (widget.allowStatusActions && !isBookingCompleted)
                ElevatedButton.icon(
                  onPressed: (_isCompletingBooking || !canCompleteBooking)
                      ? null
                      : _markBookingCompleted,
                  icon: _isCompletingBooking
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.done_all, size: 16),
                  label: Text(
                    _isCompletingBooking ? 'Completing' : 'Complete Booking',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (widget.allowStatusActions &&
              !isBookingCompleted &&
              !canCompleteBooking)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Booking can be completed only after check-in.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrdersSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _summaryChip(Icons.receipt_long, 'Orders', _summaryCount.toString()),
          const SizedBox(width: 10),
          _summaryChip(Icons.payments_outlined, 'Total', 'LKR $_totalAmount'),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String value) {
    final normalized = value.trim().toLowerCase();
    Color bg;
    Color fg;

    switch (normalized) {
      case 'completed':
      case 'served':
        bg = Colors.green.withOpacity(0.12);
        fg = const Color(0xFF2E7D32);
        break;
      case 'pending':
        bg = Colors.orange.withOpacity(0.14);
        fg = const Color(0xFFF57C00);
        break;
      case 'cancelled':
        bg = Colors.red.withOpacity(0.12);
        fg = Colors.red.shade700;
        break;
      default:
        bg = AppColors.accent.withOpacity(0.2);
        fg = AppColors.textPrimary;
    }

    final label = normalized.isEmpty
        ? 'Unknown'
        : normalized
            .split('_')
            .map((part) => part.isEmpty
                ? part
                : '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _summaryChip(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
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

  Widget _buildOrderCard(_OrderWithItems order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order ${order.displayOrderNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _buildStatusChip(order.status),
            ],
          ),
          const SizedBox(height: 10),
          ...order.items.map(_buildOrderItemTile),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${order.items.length} items • Total LKR ${order.displayTotalAmount}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.allowStatusActions &&
                  !order.isPreOrderGroup &&
                  order.id.isNotEmpty &&
                  order.status.toLowerCase() != 'completed')
                ElevatedButton.icon(
                  onPressed: _updatingOrderIds.contains(order.id)
                      ? null
                      : () => _markOrderCompleted(order.id),
                  icon: _updatingOrderIds.contains(order.id)
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle, size: 16),
                  label: Text(
                    _updatingOrderIds.contains(order.id)
                        ? 'Updating'
                        : 'Mark Completed',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemTile(_OrderedItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.fastfood, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                if (item.hasReferencePrice) ...[
                  Row(
                    children: [
                      Text(
                        'LKR ${item.displayReferencePrice}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'LKR ${item.displayActualUnitPrice}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ] else
                  Text(
                    'LKR ${item.displayActualUnitPrice}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  'Qty ${item.quantity} • Total LKR ${item.displayTotalPrice}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'x${item.quantity}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingOrdersViewData {
  final List<_OrderWithItems> orders;
  final int summaryCount;
  final String ordersTotalAmount;
  final String bookingStatus;

  const _BookingOrdersViewData({
    required this.orders,
    required this.summaryCount,
    required this.ordersTotalAmount,
    required this.bookingStatus,
  });

  factory _BookingOrdersViewData.fromApi(
    Map<String, dynamic> data, {
    Map<String, LoungeProduct> productsById = const {},
  }) {
    final rawOrders = _extractOrders(data);
    final extractedOrders = <_OrderWithItems>[];

    for (final order in rawOrders) {
      final orderId = order['id']?.toString() ?? '';
      final orderNumber = order['order_number']?.toString();
      final orderStatus = order['status']?.toString() ??
          order['order_status']?.toString() ??
          'pending';
      final orderItems = (order['items'] as List<dynamic>?) ??
          (order['order_items'] as List<dynamic>?) ??
          (order['ordered_items'] as List<dynamic>?) ??
          const [];
      final extractedItems = <_OrderedItem>[];

      for (final item in orderItems) {
        if (item is! Map<String, dynamic>) continue;

        final nestedProduct = item['product'];
        final productMap =
            nestedProduct is Map<String, dynamic> ? nestedProduct : null;

        final name = (item['product_name'] ??
                item['item_name'] ??
                item['name'] ??
                item['title'] ??
                productMap?['name'] ??
                'Item')
            .toString();

        final quantityRaw =
            item['quantity'] ?? item['qty'] ?? item['count'] ?? 1;
        final quantity = int.tryParse(quantityRaw.toString()) ?? 1;
        final productId = item['product_id']?.toString();
        final product = productId != null ? productsById[productId] : null;
        final referenceUnitPrice =
            _priceFromJson(item['unit_price']) ?? product?.priceAsDouble;
        final actualUnitPrice =
            _resolveActualUnitPrice(product, item, referenceUnitPrice);
        final backendTotalPrice = _priceFromJson(item['total_price']);
        final resolvedTotalPrice = actualUnitPrice != null
            ? _calculatedTotal(quantity: quantity, unitPrice: actualUnitPrice)
            : (backendTotalPrice ??
                _calculatedTotal(
                  quantity: quantity,
                  unitPrice: referenceUnitPrice,
                ));

        extractedItems.add(
          _OrderedItem(
            name: name,
            quantity: quantity,
            referenceUnitPrice: referenceUnitPrice,
            actualUnitPrice: actualUnitPrice,
            totalPrice: resolvedTotalPrice,
          ),
        );
      }

      final orderTotalFromItems = extractedItems.fold<double>(
        0,
        (sum, item) => sum + item.totalPriceAsDouble,
      );
      final orderTotalFromBackend = _priceFromJson(order['total_amount']) ??
          _priceFromJson(order['amount']) ??
          0;

      extractedOrders.add(
        _OrderWithItems(
          id: orderId,
          orderNumber: orderNumber,
          status: orderStatus,
          items: extractedItems,
          totalAmount: orderTotalFromItems > 0
              ? orderTotalFromItems
              : orderTotalFromBackend,
        ),
      );
    }

    final bookingMap = _extractBooking(data);
    final bookingStatus = bookingMap?['status']?.toString() ?? 'pending';
    final preOrdersRaw =
        (bookingMap?['pre_orders'] as List<dynamic>?) ?? const [];

    final preOrderItems = <_OrderedItem>[];
    for (final preOrder in preOrdersRaw) {
      if (preOrder is! Map<String, dynamic>) continue;

      final name = (preOrder['product_name'] ??
              preOrder['item_name'] ??
              preOrder['name'] ??
              preOrder['title'] ??
              'Item')
          .toString();

      final quantityRaw =
          preOrder['quantity'] ?? preOrder['qty'] ?? preOrder['count'] ?? 1;
      final quantity = int.tryParse(quantityRaw.toString()) ?? 1;
      final productId = preOrder['product_id']?.toString();
      final product = productId != null ? productsById[productId] : null;
      final referenceUnitPrice =
          _priceFromJson(preOrder['unit_price']) ?? product?.priceAsDouble;
      final actualUnitPrice =
          _resolveActualUnitPrice(product, preOrder, referenceUnitPrice);
      final backendTotalPrice = _priceFromJson(preOrder['total_price']);
      final totalPrice = actualUnitPrice != null
          ? _calculatedTotal(quantity: quantity, unitPrice: actualUnitPrice)
          : (backendTotalPrice ??
              _calculatedTotal(
                quantity: quantity,
                unitPrice: referenceUnitPrice,
              ));

      preOrderItems.add(
        _OrderedItem(
          name: '$name (Pre-order)',
          quantity: quantity,
          referenceUnitPrice: referenceUnitPrice,
          actualUnitPrice: actualUnitPrice,
          totalPrice: totalPrice,
        ),
      );
    }

    if (preOrderItems.isNotEmpty) {
      final preOrderTotal = preOrderItems.fold<double>(
        0,
        (sum, item) => sum + item.totalPriceAsDouble,
      );
      extractedOrders.add(
        _OrderWithItems(
          id: 'pre-orders',
          orderNumber: 'Pre-orders',
          status: bookingStatus,
          items: preOrderItems,
          totalAmount: preOrderTotal,
          isPreOrderGroup: true,
        ),
      );
    }

    final summaryCountRaw = data['orders_count'] ?? data['count'];
    final summaryCount = summaryCountRaw is int
        ? summaryCountRaw
        : int.tryParse(summaryCountRaw?.toString() ?? '') ?? 0;

    final itemsCount = extractedOrders.length;
    final effectiveCount = summaryCount > 0 ? summaryCount : itemsCount;

    final totalFromItems = extractedOrders.fold<double>(
      0,
      (sum, order) => sum + order.totalAmount,
    );

    final backendTotal = _priceFromJson(data['orders_total_amount']) ??
        _priceFromJson(data['total_amount']) ??
        0;

    final bookingMapTotal = _priceFromJson(bookingMap?['pre_order_total']) ?? 0;
    final total =
        totalFromItems > 0 ? totalFromItems : (backendTotal + bookingMapTotal);

    return _BookingOrdersViewData(
      orders: extractedOrders,
      summaryCount: effectiveCount,
      ordersTotalAmount: total.toStringAsFixed(2),
      bookingStatus: bookingStatus,
    );
  }

  static List<Map<String, dynamic>> _extractOrders(Map<String, dynamic> data) {
    final topOrders = data['orders'];
    if (topOrders is List<dynamic>) {
      return topOrders.whereType<Map<String, dynamic>>().toList();
    }

    final bookingMap = data['booking'];
    if (bookingMap is Map<String, dynamic>) {
      final bookingOrders = bookingMap['orders'];
      if (bookingOrders is List<dynamic>) {
        return bookingOrders.whereType<Map<String, dynamic>>().toList();
      }
    }

    final nestedData = data['data'];
    if (nestedData is Map<String, dynamic>) {
      return _extractOrders(nestedData);
    }

    return const [];
  }

  static Map<String, dynamic>? _extractBooking(Map<String, dynamic> data) {
    final booking = data['booking'];
    if (booking is Map<String, dynamic>) {
      return booking;
    }

    final nestedData = data['data'];
    if (nestedData is Map<String, dynamic>) {
      return _extractBooking(nestedData);
    }

    return null;
  }

  static double? _resolveActualUnitPrice(
    LoungeProduct? product,
    Map<String, dynamic> item,
    double? referenceUnitPrice,
  ) {
    if (product != null) {
      return product.discountedPriceAsDouble ?? product.priceAsDouble;
    }

    final discountedPrice = _priceFromJson(
      item['discounted_price'] ?? item['sale_price'] ?? item['actual_price'],
    );
    if (discountedPrice != null) {
      return discountedPrice;
    }

    return referenceUnitPrice;
  }

  static double? _priceFromJson(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(',', '').trim();
      if (normalized.isEmpty) return null;
      return double.tryParse(normalized);
    }
    if (value is Map<String, dynamic>) {
      final nested = value['value'] ?? value['amount'] ?? value['total_price'];
      return _priceFromJson(nested);
    }
    return null;
  }

  static double _calculatedTotal({required int quantity, double? unitPrice}) {
    if (unitPrice == null) return 0;
    return unitPrice * quantity;
  }
}

class _OrderWithItems {
  final String id;
  final String? orderNumber;
  final String status;
  final List<_OrderedItem> items;
  final double totalAmount;
  final bool isPreOrderGroup;

  const _OrderWithItems({
    required this.id,
    this.orderNumber,
    required this.status,
    required this.items,
    required this.totalAmount,
    this.isPreOrderGroup = false,
  });

  String get displayOrderNumber {
    if (orderNumber != null && orderNumber!.trim().isNotEmpty) {
      return orderNumber!;
    }
    if (id.isNotEmpty) {
      return '#${id.length > 8 ? id.substring(0, 8) : id}';
    }
    return 'N/A';
  }

  String get displayTotalAmount => totalAmount.toStringAsFixed(2);
}

class _OrderedItem {
  final String name;
  final int quantity;
  final double? referenceUnitPrice;
  final double? actualUnitPrice;
  final double? totalPrice;

  const _OrderedItem({
    required this.name,
    required this.quantity,
    this.referenceUnitPrice,
    this.actualUnitPrice,
    this.totalPrice,
  });

  bool get hasReferencePrice =>
      referenceUnitPrice != null &&
      actualUnitPrice != null &&
      referenceUnitPrice != actualUnitPrice;

  String get displayReferencePrice => _formatMoney(referenceUnitPrice);

  String get displayActualUnitPrice =>
      _formatMoney(actualUnitPrice ?? referenceUnitPrice);

  String get displayTotalPrice => _formatMoney(
      totalPrice ?? (actualUnitPrice ?? referenceUnitPrice ?? 0) * quantity);

  double get totalPriceAsDouble =>
      totalPrice ?? (actualUnitPrice ?? referenceUnitPrice ?? 0) * quantity;

  static String _formatMoney(double? value) {
    if (value == null) return '0.00';
    return value.toStringAsFixed(2);
  }
}
