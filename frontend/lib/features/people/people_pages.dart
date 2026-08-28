import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/content_record.dart';
import '../shared/content_list_page.dart';

/// PEOPLE OF EKOLI-YEDEN.
///
/// Profiles of scholars, professionals, artists, athletes, clergy and community
/// builders. A living person's profile is personal data, not archive material,
/// so the underlying record carries a consent reference and nothing is
/// published without it.
class PeopleListPage extends StatelessWidget {
  const PeopleListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentListPage(
      resource: 'people',
      basePath: AppRoutes.people,
      eyebrow: 'Our people',
      title: 'People of Ekoli-Yeden',
      descriptionKey: 'page.people.intro',
      description:
          'Scholars, professionals, artists, entrepreneurs, athletes, clergy and community builders '
          'from Ekoli-Yeden and its diaspora.',
      emptyTitle: 'No profiles published yet',
      emptyMessage:
          'Profiles are added once the person, or their family, has agreed to be listed and the '
          'information has been confirmed. If you know somebody who belongs here, you can build '
          'their profile below.',
      maxColumns: 4,
      // The button on this page builds a biography rather than opening the
      // general contribution form. A person is not a title and a description,
      // and sending somebody to a box marked "description" to record their
      // grandmother is how a life becomes a sentence.
      emptyAction: (
        label: 'Add somebody to the archive',
        icon: Icons.person_add_alt,
        prompt: 'Know somebody who belongs here? Build their profile — you can fill in as much '
            'as you know, add a photograph, and leave the rest for somebody else to finish.',
        path: AppRoutes.contributePerson,
      ),
      // Adding somebody goes to a profile builder rather than to the general
      // contribution form. This section holds structured records, and an
      // unstructured contribution to it gets taken apart by whoever reviews
      // it — badly, and from memory.
      footer: const _AddSomebody(),
      metaBuilder: (ContentRecord record) {
        final String? profession = record.text('profession');
        final String? city = record.text('city');
        final String? country = record.text('country');
        final String place = <String?>[city, country].whereType<String>().join(', ');
        if (profession != null && place.isNotEmpty) return '$profession · $place';
        return profession ?? (place.isEmpty ? null : place);
      },
    );
  }
}

/// THE WAY IN TO THE PROFILE BUILDER.
///
/// Placed under the list rather than as a button in the header, because
/// somebody who has just read through the people already recorded is the
/// person most likely to notice who is missing.
class _AddSomebody extends StatelessWidget {
  const _AddSomebody();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Gap.section(),
        Text('Somebody missing?', style: theme.textTheme.headlineSmall),
        const Gap.sm(),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
          child: Text(
            'Tell us about them — an elder, a teacher, a professional, somebody who did something '
            'worth remembering. You can add a photograph and a short film, and fill in as much as '
            'you know. A partial record is worth far more than none.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const Gap.lg(),
        FilledButton.icon(
          onPressed: () => context.go(AppRoutes.contributePerson),
          icon: const Icon(Icons.person_add_alt, size: 18),
          label: const Text('Add somebody to the archive'),
        ),
      ],
    );
  }
}
