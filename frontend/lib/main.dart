import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/config/cms_controller.dart';
import 'core/config/service_locator.dart';
import 'core/config/site_settings_controller.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'services/api/api_client.dart';
import 'services/auth/auth_controller.dart';

/// EKOLI YEDEN DIGITAL HOME
/// "Preserving Our Past. Celebrating Our Present. Building Our Future."
///
/// The Flutter Web client. It talks to one thing — the Cloudflare Worker — and
/// holds no Cloudflare credential of any kind. Everything it renders comes from
/// that API, including the website's own text, which is why the Editorial Team
/// can change the site without anybody touching this code.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Clean URLs. `/history/…` rather than `/#/history/…`, so the archive can be
  // linked to, printed as a QR code and indexed by search engines. This
  // requires the SPA fallback configured in `frontend/_redirects`.
  usePathUrlStrategy();

  runApp(const EkoliYedenApp());
}

class EkoliYedenApp extends StatefulWidget {
  const EkoliYedenApp({super.key});

  @override
  State<EkoliYedenApp> createState() => _EkoliYedenAppState();
}

class _EkoliYedenAppState extends State<EkoliYedenApp> {
  late final ApiClient _api;
  late final AuthController _auth;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    final ({ApiClient api, AuthController auth}) services = ServiceLocator.bootstrap();
    _api = services.api;
    _auth = services.auth;
    _router = buildRouter(_auth);

    // Restores a stored session before the first frame settles, so an editor
    // refreshing an editorial page is not bounced to sign-in.
    _auth.restore();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ...ServiceLocator.providers(_api, _auth),
      ],
      child: Builder(
        builder: (BuildContext context) {
          // Started here rather than in a provider's `create` so both loads run
          // once, in parallel, against the shared client.
          context.read<CmsController>();
          context.read<SiteSettingsController>();

          return MaterialApp.router(
            title: 'Ekoli Yeden Digital Home',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.light,
            routerConfig: _router,
            scrollBehavior: const _AppScrollBehavior(),
          );
        },
      ),
    );
  }
}

/// Lets a mouse drag horizontally scrollable areas.
///
/// Flutter Web only enables drag-scrolling for touch by default, which makes
/// the wide admin tables and the navigation strip feel broken on a laptop.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
