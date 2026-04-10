import 'dart:convert';

class RealtimeEvent {
  final String type;
  final Map<String, dynamic> payload;

  const RealtimeEvent({required this.type, required this.payload});

  factory RealtimeEvent.fromRaw(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final normalized = Map<String, dynamic>.from(raw);
      final eventType =
          (normalized['type'] ?? normalized['event'] ?? normalized['name'])
                  ?.toString() ??
              'message';
      return RealtimeEvent(type: eventType, payload: normalized);
    }

    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return RealtimeEvent.fromRaw(decoded);
        }
      } catch (_) {
        return RealtimeEvent(type: 'message', payload: {'message': raw});
      }
    }

    return RealtimeEvent(type: 'message', payload: {'data': raw.toString()});
  }

  String get normalizedText {
    final typeText = type.toLowerCase();
    final payloadText = jsonEncode(payload).toLowerCase();
    return '$typeText $payloadText';
  }

  bool containsAny(Iterable<String> terms) {
    final text = normalizedText;
    for (final term in terms) {
      if (text.contains(term.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  String? firstStringByKeys(List<String> keys) {
    for (final key in keys) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }

    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      for (final key in keys) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) {
          return value;
        }
      }
    }

    return null;
  }
}
