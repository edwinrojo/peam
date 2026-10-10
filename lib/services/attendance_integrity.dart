import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Must match `integrityNonce` in supabase/functions/verify-integrity.
String integrityNonce(String clientRecordId) {
  return base64Url.encode(utf8.encode('peam-attendance:$clientRecordId'));
}

abstract class AttendanceIntegrityApi {
  Future<DateTime?> serverNow();

  /// Sends a Play Integrity token to the server, which stores the verdict.
  Future<IntegrityStatus?> verify({
    required String clientRecordId,
    required String token,
  });
}

class SupabaseAttendanceIntegrityApi implements AttendanceIntegrityApi {
  SupabaseAttendanceIntegrityApi({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolved => _client ?? Supabase.instance.client;

  @override
  Future<DateTime?> serverNow() async {
    try {
      final value = await _resolved
          .rpc<dynamic>('server_now')
          .timeout(const Duration(seconds: 8));
      return DateTime.tryParse(value?.toString() ?? '');
    } catch (error) {
      debugPrint('PEAM server time unavailable: $error');
      return null;
    }
  }

  @override
  Future<IntegrityStatus?> verify({
    required String clientRecordId,
    required String token,
  }) async {
    try {
      final response = await _resolved.functions.invoke(
        'verify-integrity',
        body: {'client_record_id': clientRecordId, 'token': token},
      );
      final data = response.data;
      if (response.status >= 400 || data is! Map) {
        return null;
      }
      return IntegrityStatusDb.parse(data['status']);
    } catch (error) {
      debugPrint('PEAM integrity check skipped: $error');
      return null;
    }
  }
}
