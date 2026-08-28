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

  /// Whether this build was made without being told where the API lives.
  ///
  /// ---------------------------------------------------------------------
  /// THE MOST EXPENSIVE MISTAKE THIS PROJECT HAS MADE SO FAR
  /// ---------------------------------------------------------------------
  ///
  /// `API_BASE_URL` arrives through `--dart-define` at build time. Leave the
  /// define off — run a bare `flutter build web --release` — and the default
  /// below silently takes over, so the bundle points every visitor's browser
  /// at `http://localhost:8787`, which on their machine is nothing at all.
  ///
  /// The site loads perfectly. Every page renders. Nothing can sign in,
  /// register, or load a single record, and each failure reports itself as
  /// "we could not reach the archive" — which sends everybody to check an
  /// internet connection that was never the problem.
  ///
  /// It is a silent, total, site-wide outage produced by forgetting one flag,
  /// and nothing about it looks like a broken build. So the build is asked to
  /// prove it knows where the API is, and says so loudly when it does not.
  ///
  /// The test is deliberately about the page's own origin rather than about
  /// `ENVIRONMENT`: a bare build gets the development environment too, so
  /// checking that would agree with the mistake instead of catching it.
  static bool get isPointedAtLocalhost {
    const String api = apiBaseUrl;
    if (!api.contains('localhost') && !api.contains('127.0.0.1')) return false;

    // `Uri.base` is the page's own address on web, and works without
    // dart:html so the test runner and any non-web target still compile.
    final String host = Uri.base.host;
    final bool servedLocally =
        host.isEmpty || host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';

    // Localhost API from a localhost page is ordinary development.
    return !servedLocally;
  }

  /// What to tell whoever built this, in the place they will actually see it.
  static const String misconfigurationNotice =
      'This build does not know where the API is, so nothing on this site can load. It was built '
      'without --dart-define=API_BASE_URL. See DEPLOY.md for the full build command.';

  /// How long a network request may take before the client gives up.
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Default page size for list screens.
  static const int defaultPageSize = 20;

  static const String appName = 'Ekoli Yeden Digital Home';
  static const String tagline =
      'Preserving Our Past. Celebrating Our Present. Building Our Future.';
}
