import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'client_ids.dart';

class PersistedAuthSession {
  const PersistedAuthSession({
    required this.employeeNumber,
    required this.deviceUid,
  });

  final String employeeNumber;
  final String deviceUid;
}

class PendingDeviceChange {
  const PendingDeviceChange({
    required this.employeeNumber,
    required this.newDeviceUid,
    required this.reason,
  });

  final String employeeNumber;
  final String newDeviceUid;
  final String reason;
}

abstract class AuthSessionStore {
  Future<String> deviceUid();

  Future<PersistedAuthSession?> readSession();

  Future<void> saveSession({
    required String employeeNumber,
    required String deviceUid,
  });

  Future<void> clearSession();

  Future<String?> bindingFor(String employeeNumber);

  Future<void> saveBinding({
    required String employeeNumber,
    required String deviceUid,
  });

  Future<void> savePendingDeviceChange(PendingDeviceChange request);

  Future<PendingDeviceChange?> pendingDeviceChangeFor(String employeeNumber);
}

class MemoryAuthSessionStore implements AuthSessionStore {
  MemoryAuthSessionStore({String? deviceUid})
    : _deviceUid = deviceUid ?? 'memory-device';

  final String _deviceUid;
  PersistedAuthSession? _session;
  final Map<String, String> _bindings = {};
  final Map<String, PendingDeviceChange> _pendingChanges = {};

  @override
  Future<String> deviceUid() async => _deviceUid;

  @override
  Future<PersistedAuthSession?> readSession() async => _session;

  @override
  Future<void> saveSession({
    required String employeeNumber,
    required String deviceUid,
  }) async {
    _session = PersistedAuthSession(
      employeeNumber: employeeNumber,
      deviceUid: deviceUid,
    );
  }

  @override
  Future<void> clearSession() async {
    _session = null;
  }

  @override
  Future<String?> bindingFor(String employeeNumber) async {
    return _bindings[_key(employeeNumber)];
  }

  @override
  Future<void> saveBinding({
    required String employeeNumber,
    required String deviceUid,
  }) async {
    _bindings[_key(employeeNumber)] = deviceUid;
  }

  @override
  Future<void> savePendingDeviceChange(PendingDeviceChange request) async {
    _pendingChanges[_key(request.employeeNumber)] = request;
  }

  @override
  Future<PendingDeviceChange?> pendingDeviceChangeFor(
    String employeeNumber,
  ) async {
    return _pendingChanges[_key(employeeNumber)];
  }

  String _key(String employeeNumber) => employeeNumber.trim().toLowerCase();
}

class FileAuthSessionStore implements AuthSessionStore {
  FileAuthSessionStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;
  _AuthSnapshot? _cache;

  @override
  Future<String> deviceUid() async {
    final snapshot = await _load();
    if (snapshot.deviceUid.isNotEmpty) {
      return snapshot.deviceUid;
    }
    final created = newClientRecordId();
    await _write(snapshot.copyWith(deviceUid: created));
    return created;
  }

  @override
  Future<PersistedAuthSession?> readSession() async {
    final snapshot = await _load();
    final employeeNumber = snapshot.sessionEmployeeNumber;
    if (employeeNumber == null || employeeNumber.isEmpty) {
      return null;
    }
    return PersistedAuthSession(
      employeeNumber: employeeNumber,
      deviceUid: snapshot.deviceUid,
    );
  }

  @override
  Future<void> saveSession({
    required String employeeNumber,
    required String deviceUid,
  }) async {
    final snapshot = await _load();
    await _write(
      snapshot.copyWith(
        deviceUid: deviceUid,
        sessionEmployeeNumber: employeeNumber,
      ),
    );
  }

  @override
  Future<void> clearSession() async {
    final snapshot = await _load();
    await _write(snapshot.copyWith(clearSession: true));
  }

  @override
  Future<String?> bindingFor(String employeeNumber) async {
    final snapshot = await _load();
    return snapshot.bindings[_key(employeeNumber)];
  }

  @override
  Future<void> saveBinding({
    required String employeeNumber,
    required String deviceUid,
  }) async {
    final snapshot = await _load();
    final bindings = Map<String, String>.from(snapshot.bindings);
    bindings[_key(employeeNumber)] = deviceUid;
    await _write(snapshot.copyWith(bindings: bindings));
  }

  @override
  Future<void> savePendingDeviceChange(PendingDeviceChange request) async {
    final snapshot = await _load();
    final pending = Map<String, PendingDeviceChange>.from(snapshot.pending);
    pending[_key(request.employeeNumber)] = request;
    await _write(snapshot.copyWith(pending: pending));
  }

  @override
  Future<PendingDeviceChange?> pendingDeviceChangeFor(
    String employeeNumber,
  ) async {
    final snapshot = await _load();
    return snapshot.pending[_key(employeeNumber)];
  }

  Future<_AuthSnapshot> _load() async {
    if (_cache != null) {
      return _cache!;
    }
    try {
      final file = await _file();
      if (!await file.exists()) {
        return _cache = const _AuthSnapshot();
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return _cache = const _AuthSnapshot();
      }
      return _cache = _AuthSnapshot.fromJson(decoded);
    } catch (_) {
      return _cache = const _AuthSnapshot();
    }
  }

  Future<void> _write(_AuthSnapshot snapshot) async {
    _cache = snapshot;
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(snapshot.toJson()));
  }

  Future<File> _file() async {
    final directory = await _directory();
    return File(p.join(directory.path, 'peam_auth.json'));
  }

  String _key(String employeeNumber) => employeeNumber.trim().toLowerCase();
}

class _AuthSnapshot {
  const _AuthSnapshot({
    this.deviceUid = '',
    this.sessionEmployeeNumber,
    this.bindings = const {},
    this.pending = const {},
  });

  final String deviceUid;
  final String? sessionEmployeeNumber;
  final Map<String, String> bindings;
  final Map<String, PendingDeviceChange> pending;

  _AuthSnapshot copyWith({
    String? deviceUid,
    String? sessionEmployeeNumber,
    Map<String, String>? bindings,
    Map<String, PendingDeviceChange>? pending,
    bool clearSession = false,
  }) {
    return _AuthSnapshot(
      deviceUid: deviceUid ?? this.deviceUid,
      sessionEmployeeNumber: clearSession
          ? null
          : (sessionEmployeeNumber ?? this.sessionEmployeeNumber),
      bindings: bindings ?? this.bindings,
      pending: pending ?? this.pending,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'deviceUid': deviceUid,
      'sessionEmployeeNumber': sessionEmployeeNumber,
      'bindings': bindings,
      'pendingDeviceChanges': [
        for (final request in pending.values)
          {
            'employeeNumber': request.employeeNumber,
            'newDeviceUid': request.newDeviceUid,
            'reason': request.reason,
          },
      ],
    };
  }

  factory _AuthSnapshot.fromJson(Map<String, dynamic> json) {
    final rawBindings = json['bindings'];
    final bindings = <String, String>{};
    if (rawBindings is Map) {
      rawBindings.forEach((key, value) {
        if (key is String && value is String) {
          bindings[key.toLowerCase()] = value;
        }
      });
    }
    final pending = <String, PendingDeviceChange>{};
    final rawPending = json['pendingDeviceChanges'];
    if (rawPending is List) {
      for (final item in rawPending) {
        if (item is! Map) {
          continue;
        }
        final employeeNumber = item['employeeNumber'] as String?;
        final newDeviceUid = item['newDeviceUid'] as String?;
        if (employeeNumber == null || newDeviceUid == null) {
          continue;
        }
        pending[employeeNumber.toLowerCase()] = PendingDeviceChange(
          employeeNumber: employeeNumber,
          newDeviceUid: newDeviceUid,
          reason: item['reason'] as String? ?? '',
        );
      }
    }
    return _AuthSnapshot(
      deviceUid: json['deviceUid'] as String? ?? '',
      sessionEmployeeNumber: json['sessionEmployeeNumber'] as String?,
      bindings: bindings,
      pending: pending,
    );
  }
}
