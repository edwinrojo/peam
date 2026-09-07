import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
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

  test('treats Android strong/weak as a generic device biometric', () {
    final availability = availabilityFromBiometricTypes(const [
      BiometricType.strong,
    ]);

    expect(availability.face, isFalse);
    expect(availability.fingerprint, isFalse);
    expect(availability.deviceBiometric, isTrue);
    expect(availability.supports(BiometricMethod.face), isTrue);
    expect(availability.supports(BiometricMethod.fingerprint), isTrue);
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
