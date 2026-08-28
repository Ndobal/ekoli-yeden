import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/service_locator.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/content_record.dart';

/// A PERSON.
///
/// ---------------------------------------------------------------------------
/// WHY THIS IS NOT THE GENERIC DETAIL PAGE
/// ---------------------------------------------------------------------------
///
/// Every other section of the archive is a record: a history entry, a festival
/// edition, a photograph album. The generic detail page renders those well — a
/// title, a body, and a table of labelled fields.
///
/// A person is not a record. Rendering somebody's life as
///
///     Profession:   Teacher
///     Category:     Education
///     City:         Calabar
///
/// is technically complete and reads like a form somebody filled in at a
/// government office. This community is asking its members to write up their
/// elders, and what they get back has to be worth the writing.
///
/// So: a portrait, the name at display size, the things that place a person
/// as quiet chips rather than as rows, and then their life as prose at a
/// readable measure. Colour is used once — the gold rule under the name — and
/// everything else is spacing and type.
class PersonProfilePage extends StatelessWidget {
  const PersonProfilePage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return AsyncContent<ContentRecord>(
      key: ValueKey<String>(slug),
      load: () => context.contentRepository(ServiceLocator.people).find(slug),
      loadingMessage: 'Opening the profile…',
      builder: (BuildContext context, ContentRecord record) => _Profile(record: record),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({required this.record});

  final ContentRecord record;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool stacked = context.screenWidth < Breakpoints.tablet;

    final String name = record.displayTitle;
    final String? headline = record.text('headline');
    final String? profession = record.text('profession');
    final String? biography = record.text('biography') ?? record.body;
    final String? achievements = record.text('achievements');
    final String? website = record.text('website_url');
    final String? category = record.text('category');
    final String? photo = record.text('image_url');

    final String place = <String?>[record.text('city'), record.text('country')]
        .whereType<String>()
        .join(', ');

    return AppScaffold(
      currentPath: AppRoutes.people,
      seo: SeoMetadata(
        title: name,
        description: headline ?? profession ?? 'A person of Ekoli-Yeden.',
        canonicalPath: AppRoutes.person(record.pathSegment),
        type: 'profile',
      ),
      child: Column(
        children: <Widget>[
          // --- The header ---------------------------------------------------
          Container(
            width: double.infinity,
            color: AppColors.navy,
            padding: EdgeInsets.symmetric(
              vertical: stacked ? AppSpacing.xxl : AppSpacing.huge,
            ),
            child: ContentContainer(
              child: Flex(
                direction: stacked ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: stacked
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: <Widget>[
                  _Portrait(url: photo, name: name, size: stacked ? 120 : 168),
                  SizedBox(
                    width: stacked ? 0 : AppSpacing.xxl,
                    height: stacked ? AppSpacing.xl : 0,
                  ),
                  Expanded(
                    flex: stacked ? 0 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'PEOPLE OF EKOLI-YEDEN',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.goldLight,
                            letterSpacing: 2,
                          ),
                        ),
                        const Gap.md(),
                        SelectableText(
                          name,
                          style:
                              (stacked
                                      ? theme.textTheme.displaySmall
                                      : theme.textTheme.displayMedium)
                                  ?.copyWith(color: Colors.white, height: 1.1),
                        ),
                        const Gap.lg(),
                        // The one piece of colour in the header. It carries the
                        // eye from the name into what the person is.
                        Container(width: 64, height: 3, color: AppColors.gold),
                        if (headline != null) ...<Widget>[
                          const Gap.lg(),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: SelectableText(
                              headline,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: OnDark.body,
                                height: 1.55,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                        const Gap.xl(),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: <Widget>[
                            if (profession != null)
                              _HeaderChip(icon: Icons.work_outline, label: profession),
                            if (place.isNotEmpty)
                              _HeaderChip(icon: Icons.place_outlined, label: place),
                            if (category != null)
                              _HeaderChip(icon: Icons.label_outline, label: category),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- The life -----------------------------------------------------
          PageSection(
            reading: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (record.verificationStatus != null) ...<Widget>[
                  VerificationBadge(record.verificationStatus!),
                  const Gap.xl(),
                ],

                if (biography != null) ...<Widget>[
                  SelectableText(
                    biography,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.8),
                  ),
                ] else
                  const AwaitingMaterialNote(),

                if (achievements != null) ...<Widget>[
                  const Gap.section(),
                  _Panel(
                    title: 'What they have done',
                    icon: Icons.emoji_events_outlined,
                    child: SelectableText(
                      achievements,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.75),
                    ),
                  ),
                ],

                if (website != null) ...<Widget>[
                  const Gap.xxl(),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.link, size: 18, color: AppColors.navyLight),
                      const Gap.hMd(),
                      Expanded(
                        child: SelectableText(
                          website,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.navyLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const Gap.section(),
                _CorrectionInvitation(name: name),
              ],
            ),
          ),

          // --- Somebody else ------------------------------------------------
          PageSection(
            background: theme.colorScheme.surfaceContainerHigh,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Somebody else missing?', style: theme.textTheme.titleLarge),
                const Gap.sm(),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
                  child: Text(
                    'An elder, a teacher, a professional, somebody who did something worth '
                    'remembering. Fill in as much as you know — a partial record is worth far '
                    'more than none.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Gap.lg(),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: () => context.go(AppRoutes.contributePerson),
                      icon: const Icon(Icons.person_add_alt, size: 18),
                      label: const Text('Add somebody to the archive'),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go(AppRoutes.people),
                      child: const Text('All the people'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The portrait, or the initials where there is none.
///
/// A person without a photograph gets initials on the brand gold rather than a
/// grey placeholder icon. Most of the people this archive most wants to record
/// have no photograph anybody can find, and a broken-image glyph beside an
/// elder's name is the wrong thing to show for that.
class _Portrait extends StatelessWidget {
  const _Portrait({required this.url, required this.name, required this.size});

  final String? url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Widget fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.goldLight.withValues(alpha: 0.5), width: 2),
      ),
      child: Text(
        _initials,
        style: theme.textTheme.displaySmall?.copyWith(
          color: AppColors.goldLight,
          fontSize: size * 0.3,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (url == null) return fallback;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.goldLight.withValues(alpha: 0.6), width: 3),
      ),
      child: ClipOval(
        child: Image.network(
          url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }

  String get _initials {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return parts.first.substring(0, 1).toUpperCase() +
        parts.last.substring(0, 1).toUpperCase();
  }
}

/// One fact, on the dark header.
class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: AppColors.goldLight),
          const Gap.hSm(),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: OnDark.primary),
          ),
        ],
      ),
    );
  }
}

/// A titled panel, for the parts of a life that are a list rather than prose.
class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
        border: const Border(left: BorderSide(color: AppColors.gold, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: AppColors.goldDark),
              const Gap.hMd(),
              Text(title, style: theme.textTheme.titleMedium),
            ],
          ),
          const Gap.lg(),
          child,
        ],
      ),
    );
  }
}

/// The invitation to correct the record.
///
/// On every person's page, because a profile about a real person is the place
/// where an error matters most and where somebody who knows better is most
/// likely to be reading.
class _CorrectionInvitation extends StatelessWidget {
  const _CorrectionInvitation({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.info_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const Gap.hMd(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Is anything here wrong, or missing?',
                style: theme.textTheme.bodyMedium,
              ),
              const Gap.sm(),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.suggestCorrection('Person', name)),
                child: const Text('Tell the Preservation Team'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
