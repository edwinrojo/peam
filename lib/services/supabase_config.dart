import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static const _defineUrl = String.fromEnvironment('SUPABASE_URL');
  static const _defineAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env', isOptional: true);
    } catch (_) {}
    if (isConfigured) {
      return;
    }
    try {
      await dotenv.load(fileName: '.env.example', isOptional: true);
    } catch (_) {}
  }

  static String get url => normalizeProjectUrl(_read('SUPABASE_URL', _defineUrl));

  static String get anonKey => _read('SUPABASE_ANON_KEY', _defineAnonKey);

  static bool get isConfigured =>
      url.isNotEmpty && anonKey.isNotEmpty && !_isPlaceholder(url, anonKey);

  static String _read(String key, String fromDefine) {
    if (fromDefine.trim().isNotEmpty) {
      return fromDefine.trim();
    }
    try {
      return dotenv.env[key]?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  static bool _isPlaceholder(String projectUrl, String key) {
    return projectUrl.contains('your-project') ||
        key == 'your-anon-key' ||
        key.startsWith('your-');
  }

  static String normalizeProjectUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) {
      return '';
    }
    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    const restSuffix = '/rest/v1';
    if (value.endsWith(restSuffix)) {
      value = value.substring(0, value.length - restSuffix.length);
    }
    return value;
  }
}
