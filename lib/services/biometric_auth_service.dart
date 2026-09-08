import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

enum BiometricMethod { face, fingerprint }

class AndroidBiometricCapabilities {
  const AndroidBiometricCapabilities({
    required this.faceHardware,
    required this.fingerprintHardware,
    this.faceEnrolled,
    this.fingerprintEnrolled,
  });

  final bool faceHardware;
  final bool fingerprintHardware;

  /// Samsung can report face enrollment separately. Null means unknown.
  final bool? faceEnrolled;
  final bool? fingerprintEnrolled;
}

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

  /// True when the OS reported strong/weak classes instead of face vs fingerprint.
  final bool deviceBiometric;

  bool get hasAny => face || fingerprint;

  bool supports(BiometricMethod method) {
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

abstract class AndroidBiometricsClient {
  Future<AndroidBiometricCapabilities?> probe();

  Future<BiometricAuthResult?> authenticate({required BiometricMethod method});
}

class MethodChannelAndroidBiometrics implements AndroidBiometricsClient {
  const MethodChannelAndroidBiometrics();

  static const _channel = MethodChannel('peam.biometrics');

  @override
  Future<AndroidBiometricCapabilities?> probe() async {
    if (!_isAndroid) {
      return null;
    }
    try {
      final data = await _channel.invokeMapMethod<String, Object?>('probe');
      if (data == null) {
        return null;
      }
      return AndroidBiometricCapabilities(
        faceHardware: data['faceHardware'] == true,
        fingerprintHardware: data['fingerprintHardware'] == true,
        faceEnrolled: _optionalBool(data['faceEnrolled']),
        fingerprintEnrolled: _optionalBool(data['fingerprintEnrolled']),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<BiometricAuthResult?> authenticate({
    required BiometricMethod method,
  }) async {
    if (!_isAndroid) {
      return null;
    }
    try {
      final data = await _channel
          .invokeMapMethod<String, Object?>('authenticate', {
            'method': method.name,
            'title': androidTitleForMethod(method),
            'subtitle': androidHintForMethod(method),
            'reason': localizedReasonForMethod(method),
            'cancel': 'Cancel',
          });
      if (data == null) {
        return const BiometricAuthResult.failure(
          'Biometric verification was not completed. Try again.',
        );
      }
      if (data['authenticated'] == true) {
        return const BiometricAuthResult.success();
      }
      return BiometricAuthResult.failure(
        messageForAndroidBiometricCode(
          data['code'] as String?,
          data['message'] as String?,
        ),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      return BiometricAuthResult.failure(
        error.message?.trim().isNotEmpty == true
            ? error.message!
            : 'Biometric verification failed. Try again.',
      );
    }
  }

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool? _optionalBool(Object? value) {
    if (value is bool) {
      return value;
    }
    return null;
  }
}

/// Device Face ID / fingerprint via the OS. Nothing is stored by PEAM.
class DeviceBiometricAuthService implements BiometricAuthService {
  DeviceBiometricAuthService({
    LocalAuthentication? auth,
    AndroidBiometricsClient? androidBiometrics,
  }) : _auth = auth ?? LocalAuthentication(),
       _android = androidBiometrics ?? const MethodChannelAndroidBiometrics();

  final LocalAuthentication _auth;
  final AndroidBiometricsClient _android;

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
      final android = await _android.probe();
      return availabilityFromBiometricTypes(types, android: android);
    } on LocalAuthException {
      return BiometricAvailability.none;
    }
  }

  @override
  Future<BiometricAuthResult> authenticate({
    required BiometricMethod method,
  }) async {
    try {
      final androidResult = await _android.authenticate(method: method);
      if (androidResult != null) {
        return androidResult;
      }
      final didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReasonForMethod(method),
        authMessages: authMessagesForMethod(method),
        biometricOnly: true,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: method == BiometricMethod.fingerprint,
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

/// Android reports Class 3 as [BiometricType.strong] and Class 2 as
/// [BiometricType.weak]. Class 3 (fingerprint) also satisfies Class 2, so a
/// fingerprint-only phone often returns both weak and strong.
///
/// When [android] hardware/enrollment is provided (Galaxy S22 and similar),
/// Face is offered if face hardware exists and is enrolled — or if enrollment
/// cannot be read but face hardware is present and some biometric is enrolled.
BiometricAvailability availabilityFromBiometricTypes(
  List<BiometricType> types, {
  AndroidBiometricCapabilities? android,
}) {
  final namedFace =
      types.contains(BiometricType.face) || types.contains(BiometricType.iris);
  final namedFingerprint = types.contains(BiometricType.fingerprint);
  final strong = types.contains(BiometricType.strong);
  final weak = types.contains(BiometricType.weak);
  final deviceBiometric = strong || weak;

  if (android == null) {
    return BiometricAvailability(
      face: namedFace || (weak && !strong),
      fingerprint: namedFingerprint || strong,
      deviceBiometric: deviceBiometric,
    );
  }

  return BiometricAvailability(
    face:
        namedFace ||
        _androidMethodAvailable(
          hardware: android.faceHardware,
          enrolled: android.faceEnrolled,
          deviceBiometric: deviceBiometric,
        ),
    fingerprint:
        namedFingerprint ||
        _androidMethodAvailable(
          hardware: android.fingerprintHardware,
          enrolled: android.fingerprintEnrolled,
          deviceBiometric: deviceBiometric,
        ),
    deviceBiometric: deviceBiometric,
  );
}

bool _androidMethodAvailable({
  required bool hardware,
  required bool? enrolled,
  required bool deviceBiometric,
}) {
  if (!hardware || !deviceBiometric) {
    return false;
  }
  return enrolled ?? true;
}

String localizedReasonForMethod(BiometricMethod method) {
  return switch (method) {
    BiometricMethod.face =>
      'PEAM uses face unlock to confirm it is you before recording attendance. Your face data stays on this phone.',
    BiometricMethod.fingerprint =>
      'PEAM uses your fingerprint to confirm it is you before recording attendance. Your fingerprint stays on this phone.',
  };
}

String androidTitleForMethod(BiometricMethod method) {
  return switch (method) {
    BiometricMethod.face => 'Verify with face',
    BiometricMethod.fingerprint => 'Verify with fingerprint',
  };
}

String androidHintForMethod(BiometricMethod method) {
  return switch (method) {
    BiometricMethod.face => 'Look at the front camera',
    BiometricMethod.fingerprint => 'Touch the fingerprint sensor',
  };
}

List<AuthMessages> authMessagesForMethod(BiometricMethod method) {
  return switch (method) {
    BiometricMethod.face => [
      AndroidAuthMessages(
        signInTitle: androidTitleForMethod(method),
        signInHint: androidHintForMethod(method),
        cancelButton: 'Cancel',
      ),
      const IOSAuthMessages(cancelButton: 'Cancel', localizedFallbackTitle: ''),
    ],
    BiometricMethod.fingerprint => [
      AndroidAuthMessages(
        signInTitle: androidTitleForMethod(method),
        signInHint: androidHintForMethod(method),
        cancelButton: 'Cancel',
      ),
      const IOSAuthMessages(cancelButton: 'Cancel', localizedFallbackTitle: ''),
    ],
  };
}

String messageForAndroidBiometricCode(String? code, String? platformMessage) {
  return switch (code) {
    'userCanceled' || 'systemCanceled' =>
      'Verification was canceled. Authenticate to finish check-in.',
    'timeout' => 'The biometric prompt timed out. Try again.',
    'noBiometricsEnrolled' =>
      'No fingerprint or face is enrolled on this phone. Add one in system Settings, then try again.',
    'noBiometricHardware' =>
      'This phone does not have fingerprint or face hardware.',
    'noCredentialsSet' =>
      'Set up a screen lock and enroll a fingerprint or face in Settings first.',
    'temporaryLockout' => 'Too many attempts. Wait a moment, then try again.',
    'biometricLockout' =>
      'Biometrics are locked. Unlock the phone with your PIN or password, then return to PEAM.',
    'hardwareUnavailable' =>
      'Biometric hardware is busy. Close other apps and try again.',
    _ =>
      platformMessage?.trim().isNotEmpty == true
          ? platformMessage!
          : 'Biometric verification failed. Try again.',
  };
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
