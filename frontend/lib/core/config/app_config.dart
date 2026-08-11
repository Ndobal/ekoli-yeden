/// Build-time configuration.
///
/// Everything here arrives through `--dart-define`, which means the same
/// compiled code runs against development, staging and production without a
/// source change. Nothing secret is ever defined here: the Flutter bundle is
/// downloaded by every visitor, so a value in this file is a public value.
/// Cloudflare credentials, the JWT signing key and the YouTube API key live in
/// the Worker as Cloudflare secrets.
class AppConfig {
  const AppConfig._();

  /// Base URL of the Cloudflare Worker API.
  ///
  /// Defaults to the local `wrangler dev` address so that a fresh checkout runs
  /// with no configuration.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8787',
  );

  /// `development`, `staging` or `production`.
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  /// Canonical site origin, used to build absolute URLs for SEO metadata.
  static const String siteUrl = String.fromEnvironment(
    'SITE_URL',
    defaultValue: 'http://localhost:5000',
  );

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';

  /// How long a network request may take before the client gives up.
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Default page size for list screens.
  static const int defaultPageSize = 20;

  static const String appName = 'Ekoli Yeden Digital Home';
  static const String tagline =
      'Preserving Our Past. Celebrating Our Present. Building Our Future.';
}
