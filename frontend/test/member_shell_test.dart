import 'package:ekoli_yeden/core/routing/app_routes.dart';
import 'package:ekoli_yeden/features/membership/member_shell.dart';
import 'package:ekoli_yeden/repositories/message_repository.dart';
import 'package:ekoli_yeden/services/api/api_client.dart';
import 'package:ekoli_yeden/services/auth/auth_controller.dart';
import 'package:ekoli_yeden/services/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// The member shell wraps every page in the member area, so a failure here is a
/// blank screen on all of them at once rather than on one.
void main() {
  Widget harness({required double width, required Widget child}) {
    final ApiClient api = ApiClient();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(AuthService(api)),
        ),
        Provider<MessageRepository>(create: (_) => MessageRepository(api)),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: Size(width, 900)),
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: <RouteBase>[
              GoRoute(path: '/', redirect: (_, _) => AppRoutes.account),
              GoRoute(path: AppRoutes.account, builder: (_, _) => child),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('renders its child on a wide screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      harness(
        width: 1400,
        child: const MemberShell(
          currentPath: AppRoutes.account,
          title: 'Dashboard',
          child: Text('the page content'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('the page content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders its child on a narrow screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      harness(
        width: 420,
        child: const MemberShell(
          currentPath: AppRoutes.account,
          title: 'Dashboard',
          child: Text('the page content'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('the page content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('memberPageFor decides which pages get the shell', () {
    test('a member page resolves, and the longest match wins', () {
      expect(memberPageFor(AppRoutes.account)?.label, 'Dashboard');
      expect(memberPageFor(AppRoutes.accountProfile)?.label, 'My profile');
      expect(memberPageFor(AppRoutes.messages)?.label, 'Messages');
      // A thread inside messages is still Messages.
      expect(memberPageFor('${AppRoutes.messages}/abc')?.label, 'Messages');
    });

    test('posting an opportunity counts as the member’s own page', () {
      expect(memberPageFor(AppRoutes.postOpportunity), isNotNull);
    });

    test('ordinary pages of the website do not', () {
      for (final String path in <String>[
        AppRoutes.home,
        AppRoutes.history,
        AppRoutes.culture,
        AppRoutes.gallery,
        AppRoutes.news,
      ]) {
        expect(memberPageFor(path), isNull, reason: '$path is not a member page');
      }
    });
  });
}
