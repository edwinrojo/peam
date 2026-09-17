import 'package:flutter/widgets.dart';

import '../services/location_service.dart';

class LocationScope extends InheritedWidget {
  const LocationScope({super.key, required this.service, required super.child});

  final LocationService service;

  static LocationService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocationScope>();
    assert(scope != null, 'LocationScope not found in widget tree');
    return scope!.service;
  }

  @override
  bool updateShouldNotify(LocationScope oldWidget) {
    return oldWidget.service != service;
  }
}
