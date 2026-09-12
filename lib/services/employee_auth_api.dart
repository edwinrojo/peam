import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

class RemoteLoginChallenge {
  const RemoteLoginChallenge({
    required this.employeeNumber,
    required this.maskedEmail,
  });

  final String employeeNumber;
  final String maskedEmail;
}

class RemoteVerifyResult {
  const RemoteVerifyResult({
    this.employee,
    this.error,
    this.deviceChangeRequired = false,
    this.changeTicket,
  });

  final Employee? employee;
  final String? error;
  final bool deviceChangeRequired;
  final String? changeTicket;
}

class EmployeeAuthApi {
  EmployeeAuthApi({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<({String? error, RemoteLoginChallenge? challenge})> requestCode(
    String employeeNumber,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'request-login-otp',
        body: {'employee_number': employeeNumber.trim()},
      );
      final data = _map(response.data);
      if (response.status >= 400) {
        return (
          error:
              data['error'] as String? ??
              'We could not email your verification code. Try again in a moment.',
          challenge: null,
        );
      }
      if (data['found'] != true) {
        return (
          error:
              'This Employee ID is not on file. Ask HRMDO to create your account.',
          challenge: null,
        );
      }
      return (
        error: null,
        challenge: RemoteLoginChallenge(
          employeeNumber:
              data['employee_number'] as String? ?? employeeNumber.trim(),
          maskedEmail: data['masked_email'] as String? ?? '••••@••••',
        ),
      );
    } on FunctionException catch (error) {
      return (error: _functionMessage(error), challenge: null);
    }
  }

  Future<RemoteVerifyResult> verifyCode({
    required String employeeNumber,
    required String token,
    required String deviceUid,
    required String deviceName,
    required String platform,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'verify-login-otp',
        body: {
          'employee_number': employeeNumber,
          'token': token,
          'device_uid': deviceUid,
          'device_name': deviceName,
          'platform': platform,
        },
      );
      final data = _map(response.data);
      if (data['code'] == 'device_bound_elsewhere') {
        return RemoteVerifyResult(
          error:
              data['message'] as String? ??
              'This account is already bound to another phone. Submit a device-change request for HR approval.',
          deviceChangeRequired: true,
          changeTicket: data['change_ticket'] as String?,
        );
      }
      if (response.status >= 400 || data['authenticated'] != true) {
        return RemoteVerifyResult(
          error:
              data['error'] as String? ??
              'That code is incorrect or has expired. Try again.',
        );
      }

      final refreshToken = data['refresh_token'] as String?;
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _client.auth.setSession(refreshToken);
      }

      final employeeJson = data['employee'];
      if (employeeJson is! Map) {
        return const RemoteVerifyResult(error: 'Could not load your profile.');
      }
      return RemoteVerifyResult(
        employee: employeeFromAuthPayload(
          Map<String, dynamic>.from(employeeJson),
        ),
      );
    } on FunctionException catch (error) {
      return RemoteVerifyResult(error: _functionMessage(error));
    }
  }

  Future<String?> submitDeviceChange({
    required String ticket,
    String reason = 'I need to use a new phone for attendance.',
  }) async {
    try {
      final response = await _client.functions.invoke(
        'submit-device-change',
        body: {'ticket': ticket, 'reason': reason},
      );
      final data = _map(response.data);
      if (response.status >= 400 || data['submitted'] != true) {
        return data['error'] as String? ??
            'Could not submit the device-change request.';
      }
      return null;
    } on FunctionException catch (error) {
      return _functionMessage(error);
    }
  }

  Future<Employee?> restore({required String deviceUid}) async {
    final session = _client.auth.currentSession;
    if (session == null) {
      return null;
    }
    final profile = await _client
        .from('profiles')
        .select('employee_number, full_name, email, phone, department_id')
        .eq('id', session.user.id)
        .maybeSingle();
    if (profile == null) {
      await _client.auth.signOut();
      return null;
    }

    Map<String, dynamic>? department;
    final departmentId = profile['department_id'];
    if (departmentId != null) {
      department = await _client
          .from('departments')
          .select('name, code')
          .eq('id', departmentId)
          .maybeSingle();
    }

    final device = await _client
        .from('devices')
        .select('device_uid, device_name')
        .eq('profile_id', session.user.id)
        .eq('is_active', true)
        .maybeSingle();
    final boundUid = device?['device_uid'] as String?;
    if (boundUid == null || boundUid != deviceUid) {
      await _client.auth.signOut();
      return null;
    }

    return Employee(
      employeeNumber: profile['employee_number'] as String? ?? '',
      fullName: profile['full_name'] as String? ?? '',
      email: profile['email'] as String?,
      department: Department(
        name: department?['name'] as String? ?? 'Unassigned',
        code: department?['code'] as String? ?? '—',
      ),
      phone: profile['phone'] as String?,
      deviceUid: boundUid,
      deviceName: device?['device_name'] as String? ?? 'This device',
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Map<String, dynamic> _map(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return const {};
  }

  String _functionMessage(FunctionException error) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return error.reasonPhrase ?? 'Could not reach PEAM sign-in.';
  }
}

Employee employeeFromAuthPayload(Map<String, dynamic> json) {
  return Employee(
    employeeNumber: json['employee_number'] as String? ?? '',
    fullName: json['full_name'] as String? ?? '',
    email: json['email'] as String?,
    department: Department(
      name: json['department_name'] as String? ?? 'Unassigned',
      code: json['department_code'] as String? ?? '—',
    ),
    phone: json['phone'] as String?,
    deviceUid: json['device_uid'] as String?,
    deviceName: json['device_name'] as String? ?? 'This device',
  );
}
