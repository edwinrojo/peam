import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:peam/services/biometric_auth_service.dart';

void main() {
  test('maps enrolled biometric types for face and fingerprint', () {
    final availability = availabilityFromBiometricTypes(const [
      BiometricType.face,
      BiometricType.fingerprint,
    ]);

    expect(availability.face, isTrue);
    expect(availability.fingerprint, isTrue);
    expect(availability.supports(BiometricMethod.face), isTrue);
    expect(availability.supports(BiometricMethod.fingerprint), isTrue);
  });

  test('maps Android strong-only enrollment to fingerprint, not face', () {
    final availability = availabilityFromBiometricTypes(const [
      BiometricType.strong,
    ]);

    expect(availability.face, isFalse);
    expect(availability.fingerprint, isTrue);
    expect(availability.deviceBiometric, isTrue);
    expect(availability.supports(BiometricMethod.face), isFalse);
    expect(availability.supports(BiometricMethod.fingerprint), isTrue);
  });

  test('maps Android weak-only enrollment to face, not fingerprint', () {
    final availability = availabilityFromBiometricTypes(const [
      BiometricType.weak,
    ]);

    expect(availability.face, isTrue);
    expect(availability.fingerprint, isFalse);
    expect(availability.deviceBiometric, isTrue);
    expect(availability.supports(BiometricMethod.face), isTrue);
    expect(availability.supports(BiometricMethod.fingerprint), isFalse);
  });

  test(
    'does not offer face when Android reports weak because strong is enrolled',
    () {
      final availability = availabilityFromBiometricTypes(const [
        BiometricType.weak,
        BiometricType.strong,
      ]);

      expect(availability.face, isFalse);
      expect(availability.fingerprint, isTrue);
      expect(availability.supports(BiometricMethod.face), isFalse);
      expect(availability.supports(BiometricMethod.fingerprint), isTrue);
    },
  );

  test('uses face-specific Android prompt copy', () {
    final messages = authMessagesForMethod(BiometricMethod.face);
    final android = messages.whereType<AndroidAuthMessages>().single;

    expect(android.signInTitle, 'Verify with face');
    expect(android.signInHint, 'Look at the front camera');
    expect(
      localizedReasonForMethod(BiometricMethod.face).toLowerCase(),
      contains('face'),
    );
  });

  test('uses fingerprint-specific Android prompt copy', () {
    final messages = authMessagesForMethod(BiometricMethod.fingerprint);
    final android = messages.whereType<AndroidAuthMessages>().single;

    expect(android.signInTitle, 'Verify with fingerprint');
    expect(android.signInHint, 'Touch the fingerprint sensor');
  });

  test('explains missing enrollment without exposing biometric data', () {
    final message = messageForLocalAuthException(
      const LocalAuthException(
        code: LocalAuthExceptionCode.noBiometricsEnrolled,
      ),
    );

    expect(message.toLowerCase(), contains('enrolled'));
    expect(message.toLowerCase(), isNot(contains('template')));
  });
}
