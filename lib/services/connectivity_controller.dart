import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Attendance sync follows device connectivity when [listenToDevice] is true.
/// Tests keep [listenToDevice] false and use [simulateOnline] / [simulateOffline].
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
    _setDeviceNetwork(_hasNetwork(results));
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      _setDeviceNetwork(_hasNetwork(results));
    });
  }

  void simulateOffline() {
    _setOnline(false);
  }

  void simulateOnline() {
    _setOnline(true);
  }

  void _setDeviceNetwork(bool hasNetwork) {
    final changed = _deviceHasNetwork != hasNetwork || _isOnline != hasNetwork;
    _deviceHasNetwork = hasNetwork;
    _isOnline = hasNetwork;
    if (changed) {
      notifyListeners();
    }
  }

  void _setOnline(bool online) {
    if (_isOnline == online) {
      return;
    }
    _isOnline = online;
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
