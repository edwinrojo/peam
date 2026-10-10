import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'device_guard.dart';

class TrustedTime {
  const TrustedTime(this.at, this.source);

  final DateTime at;
  final TimeSource source;
}

/// Server time paired with the monotonic clock reading taken at that moment.
class ClockAnchor {
  const ClockAnchor({
    required this.serverMs,
    required this.elapsedMs,
    this.bootCount,
  });

  final int serverMs;
  final int elapsedMs;
  final int? bootCount;

  Map<String, Object?> toJson() => {
    'serverMs': serverMs,
    'elapsedMs': elapsedMs,
    'bootCount': bootCount,
  };

  static ClockAnchor? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final serverMs = json['serverMs'];
    final elapsedMs = json['elapsedMs'];
    if (serverMs is! int || elapsedMs is! int) {
      return null;
    }
    final boot = json['bootCount'];
    return ClockAnchor(
      serverMs: serverMs,
      elapsedMs: elapsedMs,
      bootCount: boot is int ? boot : null,
    );
  }
}

abstract class ClockAnchorStore {
  Future<ClockAnchor?> read();

  Future<void> write(ClockAnchor anchor);
}

class MemoryClockAnchorStore implements ClockAnchorStore {
  ClockAnchor? anchor;

  @override
  Future<ClockAnchor?> read() async => anchor;

  @override
  Future<void> write(ClockAnchor anchor) async {
    this.anchor = anchor;
  }
}

class FileClockAnchorStore implements ClockAnchorStore {
  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, 'peam_clock_anchor.json'));
  }

  @override
  Future<ClockAnchor?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) {
        return null;
      }
      return ClockAnchor.fromJson(jsonDecode(await file.readAsString()));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(ClockAnchor anchor) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(anchor.toJson()));
    } catch (_) {}
  }
}

/// Attendance time that ignores changes to the phone clock: the last server
/// time plus the monotonic time elapsed since then. Falls back to the phone
/// clock (and says so) after a reboot or before the first server contact.
class TrustedClock {
  TrustedClock({
    required DeviceGuard guard,
    ClockAnchorStore? store,
    DateTime Function()? deviceNow,
  }) : _guard = guard,
       _store = store ?? MemoryClockAnchorStore(),
       _deviceNow = deviceNow ?? DateTime.now;

  final DeviceGuard _guard;
  final ClockAnchorStore _store;
  final DateTime Function() _deviceNow;

  Future<void> anchor(DateTime serverNow) async {
    final reading = await _guard.clock();
    if (reading == null) {
      return;
    }
    await _store.write(
      ClockAnchor(
        serverMs: serverNow.millisecondsSinceEpoch,
        elapsedMs: reading.elapsedMs,
        bootCount: reading.bootCount,
      ),
    );
  }

  Future<TrustedTime> now() async {
    final anchor = await _store.read();
    final reading = await _guard.clock();
    if (anchor != null &&
        reading != null &&
        anchor.bootCount == reading.bootCount &&
        reading.elapsedMs >= anchor.elapsedMs) {
      return TrustedTime(
        DateTime.fromMillisecondsSinceEpoch(
          anchor.serverMs + reading.elapsedMs - anchor.elapsedMs,
        ),
        TimeSource.serverAnchor,
      );
    }
    return TrustedTime(_deviceNow(), TimeSource.deviceClock);
  }
}
