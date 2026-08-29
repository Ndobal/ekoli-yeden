import 'package:ekoli_yeden/core/config/cms_controller.dart';
import 'package:ekoli_yeden/core/config/site_settings_controller.dart';
import 'package:ekoli_yeden/core/routing/app_routes.dart';
import 'package:ekoli_yeden/features/forums/forum_pages.dart';
import 'package:ekoli_yeden/models/member.dart';
import 'package:ekoli_yeden/services/api/api_response.dart';
import 'package:ekoli_yeden/models/forum.dart';
import 'package:ekoli_yeden/models/user.dart';
import 'package:ekoli_yeden/repositories/cms_repository.dart';
import 'package:ekoli_yeden/repositories/forum_repository.dart';
import 'package:ekoli_yeden/repositories/member_repository.dart';
import 'package:ekoli_yeden/repositories/message_repository.dart';
import 'package:ekoli_yeden/repositories/settings_repository.dart';
import 'package:ekoli_yeden/services/api/api_client.dart';
import 'package:ekoli_yeden/services/auth/auth_controller.dart';
import 'package:ekoli_yeden/services/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// THE FORUMS PAGE, RENDERED.
///
/// The member shell's blank page was a RenderFlex overflow that only appeared
/// once the page was pumped as somebody signed in — the test before it pumped a
/// visitor, and a visitor never saw the widgets that broke.
///
/// This does the same for the forums: a real space list, a signed-in member,
/// and an assertion that nothing overflows. The three spaces are the ones that
/// actually exist, with the access flags the server actually returns.
void main() {
  ForumSpace space({
    required String slug,
    required String name,
    bool canRead = false,
    bool canPost = false,
    String? state,
    String policy = 'request',
    bool isDefault = false,
    String? blocked,
  }) {
    return ForumSpace(
      id: 'space_$slug',
      slug: slug,
      name: name,
      tagline: 'A room of the community',
      description: 'What this space is for, at the length these actually run to.',
      visibility: isDefault ? 'public' : 'members',
      canRead: canRead,
      canPost: canPost,
      membershipState: state,
      joinPolicy: policy,
      canRequestToJoin: state == null && policy == 'request',
      isDefault: isDefault,
      blockedReason: blocked,
      topicCount: 0,
    );
  }

  Widget harness({required double width, required List<ForumSpace> spaces, required bool signedIn}) {
    final ApiClient api = ApiClient();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(
          create: (_) => _Auth(AuthService(api), signedIn),
        ),
        ChangeNotifierProvider<CmsController>(create: (_) => CmsController(CmsRepository(api))),
        ChangeNotifierProvider<SiteSettingsController>(
          create: (_) => SiteSettingsController(SettingsRepository(api)),
        ),
        Provider<ForumRepository>(create: (_) => _Forums(api, spaces)),
        Provider<MessageRepository>(create: (_) => _SilentMessages(api)),
        Provider<MemberRepository>(create: (_) => _SilentMembers(api)),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: Size(width, 900)),
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: <RouteBase>[
              GoRoute(path: '/', redirect: (_, _) => AppRoutes.forums),
              GoRoute(path: AppRoutes.forums, builder: (_, _) => const ForumsIndexPage()),
            ],
          ),
        ),
      ),
    );
  }

  final List<ForumSpace> realShape = <ForumSpace>[
    space(
      slug: 'community',
      name: 'General Forum',
      canRead: true,
      canPost: true,
      state: 'member',
      policy: 'automatic',
      isDefault: true,
    ),
    space(
      slug: 'youth',
      name: 'Yakoli Youth',
      blocked: 'This forum is for its members. You can ask to join it.',
    ),
    space(
      slug: 'students',
      name: 'Yakoli Students',
      blocked: 'This forum is for its members. You can ask to join it.',
    ),
  ];

  for (final double width in <double>[1400, 900, 390]) {
    testWidgets('renders for a signed-in member at ${width.toInt()}px', (WidgetTester tester) async {
      // EVERY error, not just the first.
      //
      // `tester.takeException` hands back one pending exception. A broken
      // layout throws once per card, and the one it returns can easily be the
      // harness complaining about the network instead — which is how a page
      // that fails to lay out four times over can still pass a test.
      final List<String> errors = <String>[];
      final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        errors.add(details.exceptionAsString());
      };

      await tester.pumpWidget(harness(width: width, spaces: realShape, signedIn: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      FlutterError.onError = previous;

      expect(find.text('General Forum'), findsWidgets);

      final String error = errors.firstWhere(_isLayoutFault, orElse: () => '');
      // A LAYOUT FAULT OF ANY KIND, not one particular message.
      //
      // What actually broke the forums was `BoxConstraints forces an infinite
      // height`: a full-height accent stripe in a Row set to stretch, inside a
      // scroll view. A layout error takes the whole list with it, so the page
      // was blank on every account.
      //
      // The badge counters legitimately fail here — a widget test has no
      // network — so this asks whether the failure was about laying out, which
      // is the only kind that blanks a page.
      expect(
        error,
        '',
        reason: 'the forum list must lay out at ${width.toInt()}px',
      );

      tester.takeException();

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('renders for a visitor', (WidgetTester tester) async {
    await tester.pumpWidget(harness(width: 1400, spaces: realShape, signedIn: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(_isLayoutFault(tester.takeException()), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

/// True when the error is about laying widgets out, rather than about the
/// harness having no network.
bool _isLayoutFault(Object? error) {
  if (error == null) return false;
  final String text = error.toString();
  return text.contains('overflowed') ||
      text.contains('infinite height') ||
      text.contains('infinite size') ||
      text.contains('was not laid out') ||
      text.contains('hasSize');
}

class _Auth extends AuthController {
  _Auth(super.service, this._signedIn);

  final bool _signedIn;

  @override
  bool get isSignedIn => _signedIn;

  @override
  AppUser? get user => _signedIn
      ? const AppUser(
          id: 'u',
          email: 'a@b.c',
          displayName: 'A Member Of The Community',
          status: 'active',
          roles: <String>['okoli_member'],
          permissions: <String>{},
        )
      : null;
}

class _Forums extends ForumRepository {
  const _Forums(super.api, this._spaces);

  final List<ForumSpace> _spaces;

  @override
  Future<List<ForumSpace>> spaces() async => _spaces;
}

class _SilentMessages extends MessageRepository {
  const _SilentMessages(super.api);

  @override
  Future<int> unread() async => 0;
}


/// The notification bell polls on a timer; a real HTTP call leaves one pending
/// at teardown and the test then measures the harness rather than the page.
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
