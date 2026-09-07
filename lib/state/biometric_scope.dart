import 'package:flutter/widgets.dart';

import '../services/biometric_auth_service.dart';

class BiometricAuthScope extends InheritedWidget {
  const BiometricAuthScope({
    super.key,
    required this.service,
    required super.child,
  });

  final BiometricAuthService service;

  static BiometricAuthService of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<BiometricAuthScope>();
    assert(scope != null, 'BiometricAuthScope not found in widget tree');
    return scope!.service;
  }

  @override
  bool updateShouldNotify(BiometricAuthScope oldWidget) {
    return oldWidget.service != service;
  }
}
