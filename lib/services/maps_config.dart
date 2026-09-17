import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapsConfig {
  static const _defineKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static String get apiKey {
    if (_defineKey.trim().isNotEmpty) {
      return _defineKey.trim();
    }
    try {
      return dotenv.env['GOOGLE_MAPS_API_KEY']?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  static bool get isConfigured {
    final key = apiKey;
    return key.isNotEmpty &&
        key != 'your-google-maps-key' &&
        !key.startsWith('your-');
  }
}
