import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Prototype connectivity: sync follows [isOnline], which starts offline so
/// check-ins stay pending until the employee simulates restored connectivity.
/// [deviceHasNetwork] is informational (Room/Core Data sync still waits on
/// the prototype toggle, matching the “store locally, upload when connected”
/// demo).
class ConnectivityController extends ChangeNotifier {
  ConnectivityController({this.listenToDevice = false});

  final bool listenToDevice;

  bool _isOnline = false;
  bool _deviceHasNetwork = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool get isOnline => _isOnline;
  bool get deviceHasNetwork => _deviceHasNetwork;

  Future<void> start() async {
    if (!listenToDevice) {
      return;
    }
    final results = await Connectivity().checkConnectivity();
    _deviceHasNetwork = _hasNetwork(results);
    notifyListeners();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      _deviceHasNetwork = _hasNetwork(results);
      notifyListeners();
    });
  }

  void simulateOffline() {
    if (!_isOnline) {
      return;
    }
    _isOnline = false;
    notifyListeners();
  }

  void simulateOnline() {
    if (_isOnline) {
      return;
    }
    _isOnline = true;
    notifyListeners();
  }

  bool _hasNetwork(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
