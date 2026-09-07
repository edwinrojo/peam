import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricMethod { face, fingerprint }

class BiometricAvailability {
  const BiometricAvailability({
    required this.face,
    required this.fingerprint,
    required this.deviceBiometric,
  });

  static const none = BiometricAvailability(
    face: false,
    fingerprint: false,
    deviceBiometric: false,
  );

  static const stubEnrolled = BiometricAvailability(
    face: true,
    fingerprint: true,
    deviceBiometric: true,
  );

  final bool face;
  final bool fingerprint;

  /// Android often reports only strong/weak instead of face vs fingerprint.
  final bool deviceBiometric;

  bool get hasAny => face || fingerprint || deviceBiometric;

  bool supports(BiometricMethod method) {
    if (deviceBiometric) {
      return true;
    }
    return switch (method) {
      BiometricMethod.face => face,
      BiometricMethod.fingerprint => fingerprint,
    };
  }
}

class BiometricAuthResult {
  const BiometricAuthResult._({required this.authenticated, this.message});

  const BiometricAuthResult.success() : this._(authenticated: true);

  const BiometricAuthResult.failure(String message)
    : this._(authenticated: false, message: message);

  final bool authenticated;
  final String? message;
}

abstract class BiometricAuthService {
  Future<BiometricAvailability> probe();

  Future<BiometricAuthResult> authenticate({required BiometricMethod method});
}

/// Widget tests and desktop CI: no hardware prompt, always succeeds.
class StubBiometricAuthService implements BiometricAuthService {
  const StubBiometricAuthService();

  @override
  Future<BiometricAvailability> probe() async =>
      BiometricAvailability.stubEnrolled;

  @override
  Future<BiometricAuthResult> authenticate({
    required BiometricMethod method,
  }) async {
    return const BiometricAuthResult.success();
  }
}

/// Device Face ID / fingerprint via the OS. Nothing is stored by PEAM.
class DeviceBiometricAuthService implements BiometricAuthService {
  DeviceBiometricAuthService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<BiometricAvailability> probe() async {
    if (kIsWeb) {
      return BiometricAvailability.none;
    }
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!supported && !canCheck) {
        return BiometricAvailability.none;
      }
      final types = await _auth.getAvailableBiometrics();
      return availabilityFromBiometricTypes(types);
    } on LocalAuthException {
      return BiometricAvailability.none;
    }
  }

  @override
  Future<BiometricAuthResult> authenticate({
    required BiometricMethod method,
  }) async {
    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: switch (method) {
          BiometricMethod.face =>
            'PEAM uses Face ID to confirm it is you before recording attendance. Your face data stays on this phone.',
          BiometricMethod.fingerprint =>
            'PEAM uses your fingerprint to confirm it is you before recording attendance. Your fingerprint stays on this phone.',
        },
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (didAuthenticate) {
        return const BiometricAuthResult.success();
      }
      return const BiometricAuthResult.failure(
        'Biometric verification was not completed. Try again.',
      );
    } on LocalAuthException catch (error) {
      return BiometricAuthResult.failure(messageForLocalAuthException(error));
    }
  }
}

BiometricAvailability availabilityFromBiometricTypes(
  List<BiometricType> types,
) {
  return BiometricAvailability(
    face: types.contains(BiometricType.face),
    fingerprint: types.contains(BiometricType.fingerprint),
    deviceBiometric:
        types.contains(BiometricType.strong) ||
        types.contains(BiometricType.weak),
  );
}

String messageForLocalAuthException(LocalAuthException error) {
  return switch (error.code) {
    LocalAuthExceptionCode.userCanceled ||
    LocalAuthExceptionCode.systemCanceled =>
      'Verification was canceled. Authenticate to finish check-in.',
    LocalAuthExceptionCode.timeout =>
      'The biometric prompt timed out. Try again.',
    LocalAuthExceptionCode.noBiometricsEnrolled =>
      'No fingerprint or face is enrolled on this phone. Add one in system Settings, then try again.',
    LocalAuthExceptionCode.noBiometricHardware =>
      'This phone does not have fingerprint or face hardware.',
    LocalAuthExceptionCode.noCredentialsSet =>
      'Set up a screen lock and enroll a fingerprint or face in Settings first.',
    LocalAuthExceptionCode.temporaryLockout =>
      'Too many attempts. Wait a moment, then try again.',
    LocalAuthExceptionCode.biometricLockout =>
      'Biometrics are locked. Unlock the phone with your PIN or password, then return to PEAM.',
    LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable =>
      'Biometric hardware is busy. Close other apps and try again.',
    LocalAuthExceptionCode.uiUnavailable =>
      'The biometric prompt could not be shown. Return to PEAM and try again.',
    LocalAuthExceptionCode.userRequestedFallback =>
      'Use the fingerprint or face enrolled on this phone. PIN fallback is not allowed for attendance.',
    LocalAuthExceptionCode.authInProgress =>
      'A verification is already in progress.',
    _ =>
      error.description?.trim().isNotEmpty == true
          ? error.description!
          : 'Biometric verification failed. Try again.',
  };
}
