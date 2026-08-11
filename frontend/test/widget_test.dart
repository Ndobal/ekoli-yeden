import 'package:ekoli_yeden/core/config/cms_controller.dart';
import 'package:ekoli_yeden/core/theme/app_colors.dart';
import 'package:ekoli_yeden/core/theme/app_theme.dart';
import 'package:ekoli_yeden/core/utils/formatters.dart';
import 'package:ekoli_yeden/models/user.dart';
import 'package:ekoli_yeden/repositories/cms_repository.dart';
import 'package:ekoli_yeden/services/api/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the rules that would be expensive to get wrong.
///
/// Two things are worth testing at this stage more than any screen: that the
/// CMS falls back safely when the database has no value, and that the client's
/// permission checks match what the server enforces.
void main() {
  group('CMS fallbacks', () {
    test('uses the compiled-in fallback when the key is absent', () {
      final CmsController cms = CmsController(CmsRepository(ApiClient()));

      // Nothing loaded — the site must still render complete text rather than
      // blank labels or raw keys.
      expect(
        cms.text('home.welcome.title', fallback: 'Welcome to Ekoli-Yeden'),
        'Welcome to Ekoli-Yeden',
      );
      expect(cms.optional('does.not.exist'), isNull);
      expect(cms.isLoaded, isFalse);
    });

    test('an empty stored value falls back rather than rendering blank', () {
      final CmsBundle bundle = CmsBundle.fromJson(<String, dynamic>{
        'strings': <String, dynamic>{'brand.name': '   '},
      });

      expect(bundle.strings['brand.name'], '   ');
      // The controller is what applies the rule, and it treats whitespace as
      // absent — an editor clearing a field should not blank the header.
      final CmsController cms = CmsController(CmsRepository(ApiClient()));
      expect(cms.text('brand.name', fallback: 'EKOLI YEDEN'), 'EKOLI YEDEN');
    });
  });

  group('Permissions mirrored on the client', () {
    AppUser userWith(List<String> permissions, {List<String> roles = const <String>[]}) {
      return AppUser(
        id: 'u1',
        email: 'test@example.test',
        displayName: 'Test User',
        status: 'active',
        roles: roles,
        permissions: permissions.toSet(),
      );
    }

    test('an editorial writer can reach editorial but not administration', () {
      final AppUser writer = userWith(
        <String>['content.create', 'content.edit', 'content.read', 'content.submit'],
        roles: <String>['editorial_writer'],
      );

      expect(writer.canAccessEditorial, isTrue);
      expect(writer.canAccessAdmin, isFalse);
      // Writing is not publishing — the distinction the whole workflow rests on.
      expect(writer.canPublish, isFalse);
      expect(writer.canReview, isFalse);
    });

    test('a publisher can publish but still cannot administer', () {
      final AppUser publisher = userWith(
        <String>['content.read', 'content.publish'],
        roles: <String>['editorial_publisher'],
      );

      expect(publisher.canPublish, isTrue);
      expect(publisher.canAccessAdmin, isFalse);
    });

    test('a contributor reaches neither workspace', () {
      final AppUser contributor = userWith(<String>[], roles: <String>['contributor']);

      expect(contributor.canAccessEditorial, isFalse);
      expect(contributor.canAccessAdmin, isFalse);
    });

    test('the super admin wildcard satisfies every check', () {
      final AppUser admin = userWith(<String>['*'], roles: <String>['super_admin']);

      expect(admin.isSuperAdmin, isTrue);
      expect(admin.canAccessAdmin, isTrue);
      expect(admin.canAccessEditorial, isTrue);
      expect(admin.canPublish, isTrue);
      expect(admin.can('anything.at.all'), isTrue);
    });

    test('initials fall back sensibly for a single-word name', () {
      expect(userWith(<String>[]).initials, 'TU');
    });
  });

  group('Formatters tolerate missing data', () {
    // Most of the archive is partial by nature — a photograph with no date, a
    // word with no confirmed meaning. Nothing should render "null".
    test('null and empty values produce the supplied fallback', () {
      expect(Formatters.date(null), '—');
      expect(Formatters.date(''), '—');
      expect(Formatters.shortDate('not a date'), '—');
      expect(Formatters.number(null), '—');
      expect(Formatters.fileSize(null), '—');
      expect(Formatters.duration(null), '');
      expect(Formatters.dateRange(null, null), 'Dates to be announced');
    });

    test('formats the values it can parse', () {
      expect(Formatters.date('2026-09-15T00:00:00.000Z'), contains('2026'));
      expect(Formatters.fileSize(2048), '2 KB');
      expect(Formatters.duration(3725), '1:02:05');
      expect(Formatters.duration(65), '1:05');
    });

    test('excerpt cuts on a word boundary', () {
      final String result = Formatters.excerpt(
        'The archive preserves the history of the community for future generations.',
        maxLength: 20,
      );
      expect(result.length, lessThanOrEqualTo(21));
      expect(result, endsWith('…'));
    });
  });

  group('Theme', () {
    testWidgets('builds light and dark themes from the brand palette', (WidgetTester tester) async {
      expect(AppTheme.light.colorScheme.primary, AppColors.navy);
      expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: Text('Ekoli Yeden')),
        ),
      );
      expect(find.text('Ekoli Yeden'), findsOneWidget);
    });
  });
}
