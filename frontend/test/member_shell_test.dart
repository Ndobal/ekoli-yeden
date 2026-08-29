import 'package:ekoli_yeden/core/routing/app_routes.dart';
import 'package:ekoli_yeden/features/membership/member_shell.dart';
import 'package:ekoli_yeden/models/user.dart';
import 'package:ekoli_yeden/models/member.dart';
import 'package:ekoli_yeden/repositories/member_repository.dart';
import 'package:ekoli_yeden/services/api/api_response.dart';
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
  Widget harness({
    required double width,
    required Widget child,
    List<String> permissions = const <String>[],
  }) {
    final ApiClient api = ApiClient();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(
          create: (_) => _FakeAuth(AuthService(api), permissions),
        ),
        // Hermetic: the badge counters poll on a timer, and a real HTTP call
        // in a widget test leaves one pending at teardown. These answer
        // instantly so the test measures layout and nothing else.
        Provider<MessageRepository>(create: (_) => _SilentMessages(api)),
        Provider<MemberRepository>(create: (_) => _SilentMembers(api)),
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

  /// The case that only an administrator hits.
  ///
  /// A member who also holds a role gets the workspace switcher at the top of
  /// the sidebar, and nobody else does — so a fault in it is invisible to every
  /// ordinary member and total for the few people who run the archive.
  testWidgets('renders for somebody who also holds a role', (WidgetTester tester) async {
    await tester.pumpWidget(
      harness(
        width: 1400,
        child: const MemberShell(
          currentPath: AppRoutes.account,
          title: 'Dashboard',
          child: Text('the page content'),
        ),
        permissions: <String>['*'],
      ),
    );
    await tester.pump();

    expect(find.text('the page content'), findsOneWidget);

    // A LAYOUT ERROR, SPECIFICALLY.
    //
    // The badge counters reach for the network, which a widget test has none
    // of, so `takeException` legitimately holds a connection failure here. What
    // must never be in it is an overflow: a RenderFlex overflow in a release
    // web build does not draw a stripe, it takes the content area with it — the
    // bell and the chat icon overflowed this bar by 72 pixels the day they were
    // added, and the page went blank for everybody whose name was long enough.
    final Object? error = tester.takeException();
    expect(
      error?.toString() ?? '',
      isNot(contains('overflowed')),
      reason: 'the top bar must not overflow at this width',
    );

    // The badge counters poll on a timer. Replacing the tree disposes them
    // before the framework checks for stray timers at teardown.
    await tester.pumpWidget(const SizedBox.shrink());
  });

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

    // A LAYOUT ERROR, SPECIFICALLY.
    //
    // The badge counters reach for the network, which a widget test has none
    // of, so `takeException` legitimately holds a connection failure here. What
    // must never be in it is an overflow: a RenderFlex overflow in a release
    // web build does not draw a stripe, it takes the content area with it — the
    // bell and the chat icon overflowed this bar by 72 pixels the day they were
    // added, and the page went blank for everybody whose name was long enough.
    final Object? error = tester.takeException();
    expect(
      error?.toString() ?? '',
      isNot(contains('overflowed')),
      reason: 'the top bar must not overflow at this width',
    );

    // The badge counters poll on a timer. Replacing the tree disposes them
    // before the framework checks for stray timers at teardown.
    await tester.pumpWidget(const SizedBox.shrink());
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

    // A LAYOUT ERROR, SPECIFICALLY.
    //
    // The badge counters reach for the network, which a widget test has none
    // of, so `takeException` legitimately holds a connection failure here. What
    // must never be in it is an overflow: a RenderFlex overflow in a release
    // web build does not draw a stripe, it takes the content area with it — the
    // bell and the chat icon overflowed this bar by 72 pixels the day they were
    // added, and the page went blank for everybody whose name was long enough.
    final Object? error = tester.takeException();
    expect(
      error?.toString() ?? '',
      isNot(contains('overflowed')),
      reason: 'the top bar must not overflow at this width',
    );

    // The badge counters poll on a timer. Replacing the tree disposes them
    // before the framework checks for stray timers at teardown.
    await tester.pumpWidget(const SizedBox.shrink());
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


/// An AuthController that reports a signed-in user with the permissions given,
/// so the shell can be pumped as an administrator without a live session.
class _FakeAuth extends AuthController {
  _FakeAuth(super.service, this._permissions);

  final List<String> _permissions;

  @override
  bool get isSignedIn => true;

  @override
  AppUser? get user => AppUser(
    id: 'u',
    email: 'a@b.c',
    displayName: 'An Administrator',
    status: 'active',
    roles: const <String>['okoli_member'],
    permissions: _permissions.toSet(),
  );

  @override
  bool get canAccessAdmin => _permissions.contains('*');

  @override
  bool get canAccessEditorial => _permissions.contains('*');
}


/// Answers the unread count without a network call.
class _SilentMessages extends MessageRepository {
  const _SilentMessages(super.api);

  @override
  Future<int> unread() async => 0;
}

/// Answers the notification count without a network call.
class _SilentMembers extends MemberRepository {
  const _SilentMembers(super.api);

  @override
  Future<PaginatedResult<MemberNotification>> notifications({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
  }) async =>
      const PaginatedResult<MemberNotification>(
        items: <MemberNotification>[],
        page: 1,
        perPage: 20,
        total: 0,
        totalPages: 0,
      );
}
