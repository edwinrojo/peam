import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// State of the Keystore key that Android deletes when a new fingerprint
/// (or other strong biometric) is enrolled.
enum BioGuardState { ok, missing, changed, unsupported }

/// Monotonic time since boot; unaffected by changes to the phone clock.
class ClockReading {
  const ClockReading({required this.elapsedMs, this.bootCount});

  final int elapsedMs;
  final int? bootCount;
}

abstract class DeviceGuard {
  /// Play Integrity token bound to [nonce], or null when unavailable.
  Future<String?> integrityToken(String nonce);

  Future<BioGuardState> bioGuardState();

  Future<bool> armBioGuard();

  Future<void> resetBioGuard();

  Future<ClockReading?> clock();
}

/// Talks to `PeamDeviceGuard.kt`. Only available in the main isolate on
/// Android; every call degrades to "unavailable" elsewhere.
class MethodChannelDeviceGuard implements DeviceGuard {
  const MethodChannelDeviceGuard();

  static const _channel = MethodChannel('peam.device_guard');

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<String?> integrityToken(String nonce) async {
    if (!_supported) {
      return null;
    }
    try {
      return await _channel.invokeMethod<String>('integrityToken', {
        'nonce': nonce,
      });
    } catch (error) {
      debugPrint('PEAM integrity token unavailable: $error');
      return null;
    }
  }

  @override
  Future<BioGuardState> bioGuardState() async {
    if (!_supported) {
      return BioGuardState.unsupported;
    }
    try {
      final raw = await _channel.invokeMethod<String>('bioGuardState');
      return BioGuardState.values.firstWhere(
        (state) => state.name == raw,
        orElse: () => BioGuardState.unsupported,
      );
    } catch (_) {
      return BioGuardState.unsupported;
    }
  }

  @override
  Future<bool> armBioGuard() async {
    if (!_supported) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('armBioGuard') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> resetBioGuard() async {
    if (!_supported) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('resetBioGuard');
    } catch (_) {}
  }

  @override
  Future<ClockReading?> clock() async {
    if (!_supported) {
      return null;
    }
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('clock');
      final elapsed = raw?['elapsedMs'];
      if (elapsed is! int) {
        return null;
      }
      final boot = raw?['bootCount'];
      return ClockReading(
        elapsedMs: elapsed,
        bootCount: boot is int ? boot : null,
      );
    } catch (_) {
      return null;
    }
  }
}

class StubDeviceGuard implements DeviceGuard {
  StubDeviceGuard({
    this.state = BioGuardState.unsupported,
    this.token,
    this.reading,
  });

  BioGuardState state;
  String? token;
  ClockReading? reading;
  final List<String> requestedNonces = [];

  @override
  Future<String?> integrityToken(String nonce) async {
    requestedNonces.add(nonce);
    return token;
  }

  @override
  Future<BioGuardState> bioGuardState() async => state;

  @override
  Future<bool> armBioGuard() async {
    if (state == BioGuardState.unsupported) {
      return false;
    }
    state = BioGuardState.ok;
    return true;
  }

  @override
  Future<void> resetBioGuard() async {
    if (state != BioGuardState.unsupported) {
      state = BioGuardState.missing;
    }
  }

  @override
  Future<ClockReading?> clock() async => reading;
}
