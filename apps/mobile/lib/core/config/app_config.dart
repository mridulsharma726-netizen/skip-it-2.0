/// Environment configuration for SkipIt.
/// In production, these would come from --dart-define or .env files.
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://qjolinnxfovlliameork.supabase.co',
    );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_pz_KqPLn7xanlzbEVmQrSQ_i2FAOIO0',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.29.224:3000/api',
  );

  static const String signupRedirectUrl = String.fromEnvironment(
    'SIGNUP_REDIRECT_URL',
    defaultValue: 'skipit://email-confirmed',
  );

  static const String googleRedirectUrl = String.fromEnvironment(
    'GOOGLE_REDIRECT_URL',
    defaultValue: 'skipit://google-callback',
  );

  static const String supportPhoneNumber = String.fromEnvironment(
    'SUPPORT_PHONE_NUMBER',
    defaultValue: '+919876543210', // Easily configurable live support number
  );
}
