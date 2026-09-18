import 'package:flutter_test/flutter_test.dart';
import 'package:peam/services/background_attendance_sync.dart';

void main() {
  test('background sync scheduler is safe to call off a phone', () async {
    await BackgroundAttendanceSync.schedulePendingUpload();
    await BackgroundAttendanceSync.cancel();
  });
}
