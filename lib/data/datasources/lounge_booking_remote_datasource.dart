import 'package:dio/dio.dart';
import '../models/lounge_booking_model.dart';
import '../../core/error/exceptions.dart';
import '../../core/network/api_client.dart';

/// Remote Data Source: Lounge Booking API
/// Handles all lounge booking-related API calls according to backend documentation
abstract class LoungeBookingRemoteDataSource {
  /// Get bookings for lounge owner
  /// GET /api/v1/lounges/:lounge_id/bookings
  Future<List<LoungeBookingModel>> getOwnerBookings({
    String? loungeId,
    String? status,
    String? date,
  });

  /// Get today's bookings (Staff view)
  /// GET /api/v1/lounges/:lounge_id/bookings/today
  Future<List<LoungeBookingModel>> getTodayBookings({
    String? loungeId,
  });

  /// Get my bookings (Passenger view)
  /// GET /api/v1/lounge-bookings/my-bookings
  Future<List<LoungeBookingModel>> getMyBookings({
    String? status,
    int? page,
  });

  /// Get upcoming bookings (Passenger view)
  /// GET /api/v1/lounge-bookings/upcoming
  Future<List<LoungeBookingModel>> getUpcomingBookings();

  /// Get booking by ID
  /// GET /api/v1/lounge-bookings/:booking_id
  Future<LoungeBookingModel> getBookingById(String bookingId);

  /// Get booking by reference
  /// GET /api/v1/lounge-bookings/reference/:reference
  Future<LoungeBookingModel> getBookingByReference(String reference);

  /// Get booking by QR code data
  /// GET /api/v1/lounge-bookings/qr/:qr_code_data
  Future<LoungeBookingModel> getBookingByQrCodeData(String qrCodeData);

  /// Get bookings for staff (Staff view)
  /// GET /api/v1/lounge-staff/bookings
  Future<Map<String, dynamic>> getStaffBookings({
    int? limit,
    int? offset,
    String? status,
    String? date,
  });

  /// Get bookings with orders for a lounge
  /// GET /api/v1/lounges/:lounge_id/bookings-with-orders
  Future<Map<String, dynamic>> getLoungeBookingsWithOrders({
    required String loungeId,
    String? status,
    String? bookingDate,
    String? date,
    int? limit,
    int? offset,
  });

  /// Get orders for a booking
  /// GET /api/v1/lounge-bookings/:id/orders
  Future<Map<String, dynamic>> getBookingOrders({
    required String bookingId,
    String? date,
  });

  /// Get booking with orders
  /// GET /api/v1/lounge-bookings/:id/with-orders
  Future<Map<String, dynamic>> getBookingWithOrders({
    required String bookingId,
    String? date,
  });

  /// Toggle check-in/check-out for booking
  /// POST /api/v1/lounge-bookings/:id/check-in-out
  Future<Map<String, dynamic>> toggleBookingCheckInOut({
    required String bookingId,
    double? latitude,
    double? longitude,
    String? locationName,
  });

  /// Complete a lounge booking
  /// POST /api/v1/lounge-bookings/:id/complete
  Future<Map<String, dynamic>> completeBooking({
    required String bookingId,
  });

  /// Update a lounge order status
  /// PUT /api/v1/lounge-orders/:id/status
  Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String status,
  });
}

class LoungeBookingRemoteDataSourceImpl
    implements LoungeBookingRemoteDataSource {
  final ApiClient apiClient;

  LoungeBookingRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<LoungeBookingModel>> getOwnerBookings({
    String? loungeId,
    String? status,
    String? date,
  }) async {
    try {
      final queryParameters = <String, dynamic>{};
      if (status != null) queryParameters['status'] = status;
      if (date != null) queryParameters['date'] = date;

      final response = loungeId != null
          ? await apiClient.get(
              '/api/v1/lounges/$loungeId/bookings',
              queryParameters: queryParameters,
            )
          : await apiClient.get(
              '/api/v1/lounge-bookings/owner',
              queryParameters: queryParameters,
            );

      if (response.data == null) {
        throw const ServerException(
          'Empty response from server',
          'EMPTY_RESPONSE',
          null,
        );
      }

      final data = response.data as Map<String, dynamic>;
      final bookingsList = data['bookings'] as List<dynamic>? ?? [];

      if (bookingsList.isNotEmpty) {
        return bookingsList
            .map((json) =>
                LoungeBookingModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      // Legacy response: grouped by lounge
      final lounges = data['lounges'] as List<dynamic>? ?? [];
      final allBookings = <LoungeBookingModel>[];
      for (final lounge in lounges) {
        final loungeData = lounge as Map<String, dynamic>;
        final bookings = loungeData['bookings'] as List<dynamic>? ?? [];
        final loungeName = loungeData['lounge_name'] as String?;

        for (final booking in bookings) {
          final bookingMap = booking as Map<String, dynamic>;
          bookingMap['lounge_name'] = loungeName;
          allBookings.add(LoungeBookingModel.fromJson(bookingMap));
        }
      }

      return allBookings;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<List<LoungeBookingModel>> getTodayBookings({
    String? loungeId,
  }) async {
    try {
      final response = loungeId != null
          ? await apiClient.get('/api/v1/lounges/$loungeId/bookings/today')
          : await apiClient.get('/api/v1/lounge-bookings/today');

      if (response.data == null) {
        throw const ServerException(
          'Empty response from server',
          'EMPTY_RESPONSE',
          null,
        );
      }

      final data = response.data as Map<String, dynamic>;
      final bookingsList = data['bookings'] as List<dynamic>? ?? [];

      return bookingsList
          .map((json) =>
              LoungeBookingModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<List<LoungeBookingModel>> getMyBookings({
    String? status,
    int? page,
  }) async {
    try {
      final queryParameters = <String, dynamic>{};
      if (status != null) queryParameters['status'] = status;
      if (page != null) queryParameters['page'] = page;

      final response = await apiClient.get(
        '/api/v1/lounge-bookings/my-bookings',
        queryParameters: queryParameters,
      );

      if (response.data == null) {
        throw const ServerException(
          'Empty response from server',
          'EMPTY_RESPONSE',
          null,
        );
      }

      final data = response.data as Map<String, dynamic>;
      final bookingsList = data['bookings'] as List<dynamic>? ?? [];

      return bookingsList
          .map((json) =>
              LoungeBookingModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<List<LoungeBookingModel>> getUpcomingBookings() async {
    try {
      final response = await apiClient.get('/api/v1/lounge-bookings/upcoming');

      if (response.data == null) {
        throw const ServerException(
          'Empty response from server',
          'EMPTY_RESPONSE',
          null,
        );
      }

      final data = response.data as Map<String, dynamic>;
      final bookingsList = data['bookings'] as List<dynamic>? ?? [];

      return bookingsList
          .map((json) =>
              LoungeBookingModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<LoungeBookingModel> getBookingById(String bookingId) async {
    try {
      final response =
          await apiClient.get('/api/v1/lounge-bookings/$bookingId');

      if (response.data == null) {
        throw const ServerException(
          'Empty response from server',
          'EMPTY_RESPONSE',
          null,
        );
      }

      return LoungeBookingModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<LoungeBookingModel> getBookingByReference(String reference) async {
    try {
      // GET /api/v1/lounge-bookings/reference/{reference}
      // Retrieves lounge booking by its booking reference number (e.g., LNG-b7336f)
      // Accessible by: booking owner, lounge owner, or approved lounge staff
      final encodedReference = Uri.encodeComponent(reference);
      final response = await apiClient.get(
        '/api/v1/lounge-bookings/reference/$encodedReference',
      );

      if (response.data == null) {
        throw const ServerException(
          'Empty response from server',
          'EMPTY_RESPONSE',
          null,
        );
      }

      return LoungeBookingModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<LoungeBookingModel> getBookingByQrCodeData(String qrCodeData) async {
    try {
      final encodedQrCodeData = Uri.encodeComponent(qrCodeData);
      final response = await apiClient.get(
        '/api/v1/lounge-bookings/qr/$encodedQrCodeData',
      );

      if (response.data == null) {
        throw const ServerException(
          'Empty response from server',
          'EMPTY_RESPONSE',
          null,
        );
      }

      return LoungeBookingModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> getStaffBookings({
    int? limit,
    int? offset,
    String? status,
    String? date,
  }) async {
    try {
      final queryParameters = <String, dynamic>{};
      if (limit != null) queryParameters['limit'] = limit;
      if (offset != null) queryParameters['offset'] = offset;
      if (status != null) queryParameters['status'] = status;
      if (date != null) queryParameters['date'] = date;

      final response = await apiClient.get(
        '/api/v1/lounge-staff/bookings',
        queryParameters: queryParameters,
      );

      if (response.data == null) {
        throw const ServerException(
          'Empty response from server',
          'EMPTY_RESPONSE',
          null,
        );
      }

      final data = response.data as Map<String, dynamic>;
      final bookingsList = data['bookings'] as List<dynamic>? ?? [];

      final bookings = bookingsList
          .map((json) =>
              LoungeBookingModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return {
        'bookings': bookings,
        'lounge_id': data['lounge_id'],
        'limit': data['limit'] ?? limit ?? 50,
        'offset': data['offset'] ?? offset ?? 0,
      };
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> getLoungeBookingsWithOrders({
    required String loungeId,
    String? status,
    String? bookingDate,
    String? date,
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParameters = <String, dynamic>{};
      if (status != null) queryParameters['status'] = status;
      if (bookingDate != null) queryParameters['booking_date'] = bookingDate;
      if (date != null) queryParameters['date'] = date;
      if (limit != null) queryParameters['limit'] = limit;
      if (offset != null) queryParameters['offset'] = offset;

      final response = await apiClient.get(
        '/api/v1/lounges/$loungeId/bookings-with-orders',
        queryParameters: queryParameters,
      );

      if (response.data == null) {
        throw const ServerException(
          'Empty response from server',
          'EMPTY_RESPONSE',
          null,
        );
      }

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> getBookingOrders({
    required String bookingId,
    String? date,
  }) async {
    try {
      final queryParameters = <String, dynamic>{};
      if (date != null) queryParameters['date'] = date;

      final response = await apiClient.get(
        '/api/v1/lounge-bookings/$bookingId/orders',
        queryParameters: queryParameters,
      );

      if (response.data == null) {
        throw const ServerException(
          'Empty response from server',
          'EMPTY_RESPONSE',
          null,
        );
      }

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> getBookingWithOrders({
    required String bookingId,
    String? date,
  }) async {
    try {
      final queryParameters = <String, dynamic>{};
      if (date != null) queryParameters['date'] = date;

      final response = await apiClient.get(
        '/api/v1/lounge-bookings/$bookingId/with-orders',
        queryParameters: queryParameters,
      );

      if (response.data == null) {
        throw const ServerException(
          'Empty response from server',
          'EMPTY_RESPONSE',
          null,
        );
      }

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> toggleBookingCheckInOut({
    required String bookingId,
    double? latitude,
    double? longitude,
    String? locationName,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (latitude != null) payload['latitude'] = latitude;
      if (longitude != null) payload['longitude'] = longitude;
      if (locationName != null && locationName.trim().isNotEmpty) {
        payload['location_name'] = locationName.trim();
      }

      final response = await apiClient.post(
        '/api/v1/lounge-bookings/$bookingId/check-in-out',
        data: payload.isEmpty ? null : payload,
      );

      if (response.data == null) {
        throw const ServerException(
          'Empty response from server',
          'EMPTY_RESPONSE',
          null,
        );
      }

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> completeBooking({
    required String bookingId,
  }) async {
    try {
      final response = await apiClient.post(
        '/api/v1/lounge-bookings/$bookingId/complete',
      );

      if (response.data == null) {
        throw const ServerException(
          'Empty response from server',
          'EMPTY_RESPONSE',
          null,
        );
      }

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    try {
      final response = await apiClient.put(
        '/api/v1/lounge-orders/$orderId/status',
        data: {'status': status},
      );

      if (response.data == null) {
        throw const ServerException(
          'Empty response from server',
          'EMPTY_RESPONSE',
          null,
        );
      }

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Handle Dio errors and convert to app exceptions
  AppException _handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const NetworkException('Connection timeout');
    }

    if (error.type == DioExceptionType.connectionError) {
      return const NetworkException('No internet connection');
    }

    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final data = error.response!.data;

      String message = 'An error occurred';
      String? code;

      if (data is Map<String, dynamic>) {
        message = data['message'] as String? ?? message;
        code = data['code'] as String? ?? data['error'] as String?;
      }

      if (statusCode == 401) {
        return AuthException(message, code);
      } else if (statusCode == 403) {
        return AuthException(message, code ?? 'FORBIDDEN');
      } else if (statusCode == 404) {
        return ServerException(message, code ?? 'NOT_FOUND', statusCode);
      } else if (statusCode == 429) {
        return ServerException(message, code, statusCode);
      } else if (statusCode != null && statusCode >= 500) {
        return ServerException(message, code, statusCode);
      } else {
        return ServerException(message, code, statusCode);
      }
    }

    return NetworkException(error.message ?? 'Network error');
  }
}
