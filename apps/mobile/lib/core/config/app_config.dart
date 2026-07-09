/// Environment configuration for SkipIt.
/// In production, these would come from --dart-define or .env files.
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://crpbikhjolxdtluqlqkz.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_SdY_IDJI56WuWcM-ngSZzQ_qQ2QQ-__',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.58.16.47:3000/api',
  );

  static const String supportPhoneNumber = String.fromEnvironment(
    'SUPPORT_PHONE_NUMBER',
    defaultValue: '+919876543210', // Easily configurable live support number
  );
}
