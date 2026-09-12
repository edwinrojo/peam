import 'package:flutter_test/flutter_test.dart';
import 'package:peam/services/supabase_config.dart';

void main() {
  test('strips a PostgREST URL down to the project origin', () {
    expect(
      SupabaseConfig.normalizeProjectUrl(
        'https://xxxx.supabase.co/rest/v1/',
      ),
      'https://xxxx.supabase.co',
    );
  });

  test('treats an empty or example .env as unconfigured', () {
    expect(SupabaseConfig.isConfigured, isFalse);
  });
}
