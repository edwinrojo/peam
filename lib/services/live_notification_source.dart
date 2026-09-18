import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class LiveNotificationSource {
  LiveNotificationSource({this._client});

  final SupabaseClient? _client;
  RealtimeChannel? _channel;

  SupabaseClient? get _resolved {
    if (_client != null) {
      return _client;
    }
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> listDeviceRequests() async {
    final client = _resolved;
    if (client?.auth.currentUser == null) {
      return const [];
    }
    try {
      final response = await client!
          .from('device_change_requests')
          .select('id, status, updated_at')
          .order('updated_at', ascending: false)
          .timeout(const Duration(seconds: 12));
      final rows = response as List<dynamic>;
      return [
        for (final row in rows)
          if (row is Map) Map<String, dynamic>.from(row),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> start({
    required void Function() onEventsChanged,
    required void Function() onDeviceRequestsChanged,
  }) async {
    await stop();
    final client = _resolved;
    if (client?.auth.currentUser == null) {
      return;
    }
    final channel = client!.channel('peam-notices');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'events',
          callback: (_) => onEventsChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'device_change_requests',
          callback: (_) => onDeviceRequestsChanged(),
        );
    try {
      channel.subscribe();
      _channel = channel;
    } catch (_) {
      await client.removeChannel(channel);
    }
  }

  Future<void> stop() async {
    final channel = _channel;
    _channel = null;
    if (channel == null) {
      return;
    }
    try {
      await _resolved?.removeChannel(channel);
    } catch (_) {}
  }
}
