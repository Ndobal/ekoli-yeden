/// STORIES AND FOLKLORE — §18 of the proposal.
///
/// ---------------------------------------------------------------------------
/// WHY THIS IS NOT PART OF THE LANGUAGE SECTION
/// ---------------------------------------------------------------------------
///
/// §18 asks the archive to preserve proverbs, folktales, children's stories,
/// traditional songs, riddles, idioms, praise names and cultural sayings, each
/// with an Ekoli version, an English interpretation and audio where possible.
///
/// Most of that list is already built, in the language section, as dictionary
/// entry types: `proverb`, `idiom`, `riddle`, `song` and `name` are all there,
/// each carrying its pronunciation. That is the right home for them — they are
/// short, they are quotable, and hearing one said properly is most of the
/// point.
///
/// A folktale is different. It is prose with a beginning and an end, it can run
/// for pages, and forcing it into a dictionary row would lose the telling. So
/// the long forms live here as articles, and the page says plainly where the
/// short forms went, because a visitor looking for proverbs should not have to
/// guess.
library;

import 'package:flutter/material.dart';

import '../../core/routing/app_routes.dart';
import '../shared/content_detail_page.dart';
import '../shared/content_list_page.dart';

class StoriesPage extends StatelessWidget {
  const StoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ContentListPage(
      resource: 'stories',
      title: 'Stories and Folklore',
      basePath: AppRoutes.stories,
      descriptionKey: 'page.stories.intro',
      description:
          'Folktales, children’s stories and the long tellings that do not fit in a '
          'dictionary. Proverbs, riddles, praise names and songs live in the language '
          'section, where they can carry their pronunciation.',
      emptyTitle: 'No stories recorded yet',
      emptyMessage:
          'The folktales of Ekori are still where they have always been — with the people who '
          'can tell them. Writing one down, or recording somebody telling it, is one of the '
          'most useful things anybody can contribute to this archive.',
      showVerification: true,
    );
  }
}

class StoryPage extends StatelessWidget {
  const StoryPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return ContentDetailPage(
      resource: 'stories',
      identifier: slug,
      basePath: AppRoutes.stories,
      sectionTitle: 'Stories and Folklore',
      showVerification: true,
      showSources: true,
      showContributors: true,
      detailFields: const <DetailField>[
        DetailField(label: 'Kind of story', key: 'category'),
        DetailField(label: 'Also known as', key: 'subtitle'),
      ],
    );
  }
}
