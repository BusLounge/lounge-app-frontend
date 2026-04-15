import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'realtime_event.dart';

class RealtimeSocketService {
  final String baseUrl;
  final Future<String?> Function() accessTokenProvider;

  final StreamController<RealtimeEvent> _eventController =
      StreamController<RealtimeEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  bool _disposed = false;
  bool _manualDisconnect = false;
  int _retryAttempt = 0;
  static const int _maxRetryAttempts = 6;

  String? _activeUserId;
  List<String> _activeRoles = const [];

  RealtimeSocketService({
    required this.baseUrl,
    required this.accessTokenProvider,
  });

  Stream<RealtimeEvent> get events => _eventController.stream;

  bool get isConnected => _channel != null;

  Future<void> connect({
    required String userId,
    required List<String> roles,
  }) async {
    if (_disposed) {
      return;
    }

    final normalizedRoles = [...roles]..sort();
    final sameSession =
        _activeUserId == userId && _listEquals(_activeRoles, normalizedRoles);

    if (isConnected && sameSession) {
      return;
    }

    _manualDisconnect = false;
    _activeUserId = userId;
    _activeRoles = normalizedRoles;

    await _closeChannel();
    await _openChannel();
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _activeUserId = null;
    _activeRoles = const [];
    _cancelReconnectTimer();
    await _closeChannel();
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _eventController.close();
  }

  Future<void> _openChannel() async {
    if (_disposed || _activeUserId == null) {
      return;
    }

    try {
      final token = await accessTokenProvider();
      final uri = _buildUri(
        token: token,
        userId: _activeUserId!,
        roles: _activeRoles,
      );

      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _retryAttempt = 0;

      _subscription = channel.stream.handleError((_) {
        _scheduleReconnect();
      }).listen(
        _handleMessage,
        onDone: _scheduleReconnect,
        cancelOnError: false,
      );

      _sendInitialSubscription();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  Uri _buildUri({
    required String? token,
    required String userId,
    required List<String> roles,
  }) {
    final base = Uri.parse(baseUrl);
    final query = <String, String>{...base.queryParameters};

    query['user_id'] = userId;
    if (roles.isNotEmpty) {
      query['roles'] = roles.join(',');
    }
    if (token != null && token.isNotEmpty) {
      query['token'] = token;
    }

    return base.replace(queryParameters: query);
  }

  void _sendInitialSubscription() {
    final subscriptionPayload = {
      'type': 'subscribe',
      'topics': [
        'lounge.approval.changed',
        'profile.approval.changed',
        'location.changed',
        'staff.changed',
      ],
      'user_id': _activeUserId,
      'roles': _activeRoles,
    };

    try {
      _channel?.sink.add(jsonEncode(subscriptionPayload));
    } catch (_) {
      // Ignore if backend does not support explicit subscription payloads.
    }
  }

  void _handleMessage(dynamic raw) {
    if (_disposed) {
      return;
    }

    final event = RealtimeEvent.fromRaw(raw);
    _eventController.add(event);
  }

  void _scheduleReconnect() {
    if (_disposed || _manualDisconnect || _activeUserId == null) {
      return;
    }

    _cancelReconnectTimer();
    _retryAttempt += 1;

    if (_retryAttempt > _maxRetryAttempts) {
      return;
    }

    final seconds = _calculateBackoffSeconds(_retryAttempt);
    _reconnectTimer = Timer(Duration(seconds: seconds), () async {
      await _closeChannel();
      await _openChannel();
    });
  }

  int _calculateBackoffSeconds(int attempt) {
    if (attempt <= 1) return 1;
    if (attempt == 2) return 2;
    if (attempt == 3) return 4;
    if (attempt == 4) return 8;
    if (attempt == 5) return 12;
    return 20;
  }

  Future<void> _closeChannel() async {
    await _subscription?.cancel();
    _subscription = null;

    try {
      await _channel?.sink.close();
    } catch (_) {
      // Ignore close failures.
    }

    _channel = null;
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }

    for (var i = 0; i < a.length; i += 1) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
