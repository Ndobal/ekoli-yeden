import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/cms_text.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/news.dart';
import '../../repositories/news_portal_repository.dart';
import '../events/events_pages.dart' show EventsBrowser;
import '../../services/api/api_response.dart';
import '../community/community_pages.dart' show CommunityProjectsBrowser;

/// NEWS & ANNOUNCEMENTS.
///
/// ---------------------------------------------------------------------------
/// THE ARCHIVE DOES NOT COMPETE WITH FACEBOOK. IT OUTLASTS IT.
/// ---------------------------------------------------------------------------
///
/// Social media is how news reaches this community and will remain so. What it
/// cannot do is still have the story in 2046 — a Facebook post from today is
/// close to unfindable in five years and a WhatsApp message is gone entirely.
///
/// So this page is a publication, not a noticeboard: the announcements that
/// cannot wait, then the story that matters most, then everything else, then
/// the film. And at the bottom, the invitation, because most of what belongs
/// here will be written by somebody who was standing there rather than by an
/// editor.
///
/// ---------------------------------------------------------------------------
/// THE COMMUNITY PROJECTS LIVE HERE TOO
/// ---------------------------------------------------------------------------
///
/// A borehole being finished is news; the borehole project is the thing the
/// news is about. Keeping them in two sections meant somebody reading about the
/// opening had nowhere to go to find out what the project was, and the projects
/// section sat unvisited. They are two tabs of one page now, and `/community`
/// still resolves to the second of them.
class NewsPortalPage extends StatefulWidget {
  const NewsPortalPage({this.initialTab = NewsTab.news, super.key});

  final NewsTab initialTab;

  @override
  State<NewsPortalPage> createState() => _NewsPortalPageState();
}

/// The two halves of the section.
/// WHAT IS HAPPENING IN EKOLI-YEDEN, IN THREE ANSWERS.
///
/// News is what has been announced, Events is when things are, and Community
/// projects is what is being built. They were three sections in the navigation
/// answering one question, so somebody looking for a meeting found the
/// announcement about it in a different place from the date of it.
enum NewsTab { news, events, projects }

class _NewsPortalPageState extends State<NewsPortalPage> {
  final TextEditingController _search = TextEditingController();

  late NewsTab _tab = widget.initialTab;
  String? _category;
  String? _query;
  int _page = 1;
  Timer? _debounce;

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Searching is debounced. The list is a request, and firing one per
  /// keystroke would be rude to a phone on a slow connection.
  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim().isEmpty ? null : value.trim();
        _page = 1;
      });
    });
  }

  bool get _browsing => _query != null || _category != null || _page > 1;

  @override
  Widget build(BuildContext context) {
    final NewsPortalRepository repository = context.read<NewsPortalRepository>();

    return AppScaffold(
      currentPath: AppRoutes.news,
      seo: const SeoMetadata(
        title: 'News & Announcements',
        description:
            'Community news, announcements, appointments, achievements, events and important '
            'notices from Ekoli-Yeden.',
        canonicalPath: AppRoutes.news,
      ),
      child: PageSection(
        eyebrow: 'Ekoli-Yeden',
        title: 'News & Announcements',
        description: context.cmsWatch(
          'page.news.intro',
          fallback:
              'Community news, announcements, appointments, achievements, events and important '
              'notices from Ekoli-Yeden.',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SegmentedButton<NewsTab>(
              segments: const <ButtonSegment<NewsTab>>[
                ButtonSegment<NewsTab>(
                  value: NewsTab.news,
                  label: Text('News'),
                  icon: Icon(Icons.article_outlined, size: 18),
                ),
                ButtonSegment<NewsTab>(
                  value: NewsTab.events,
                  label: Text('Events'),
                  icon: Icon(Icons.event_outlined, size: 18),
                ),
                ButtonSegment<NewsTab>(
                  value: NewsTab.projects,
                  label: Text('Community projects'),
                  icon: Icon(Icons.handshake_outlined, size: 18),
                ),
              ],
              selected: <NewsTab>{_tab},
              onSelectionChanged: (Set<NewsTab> value) => setState(() => _tab = value.first),
            ),
            const Gap.xxl(),
            if (_tab == NewsTab.events)
              const EventsBrowser()
            else if (_tab == NewsTab.projects)
              const CommunityProjectsBrowser()
            else
              _NewsTab(
                repository: repository,
                search: _search,
                onSearch: _onSearch,
                category: _category,
                query: _query,
                page: _page,
                browsing: _browsing,
                onCategory: (String? slug) => setState(() {
                  _category = slug;
                  _page = 1;
                }),
                onPage: (int page) => setState(() => _page = page),
                onClear: () {
                  _search.clear();
                  setState(() {
                    _query = null;
                    _category = null;
                    _page = 1;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _NewsTab extends StatelessWidget {
  const _NewsTab({
    required this.repository,
    required this.search,
    required this.onSearch,
    required this.category,
    required this.query,
    required this.page,
    required this.browsing,
    required this.onCategory,
    required this.onPage,
    required this.onClear,
  });

  final NewsPortalRepository repository;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final String? category;
  final String? query;
  final int page;
  final bool browsing;
  final ValueChanged<String?> onCategory;
  final ValueChanged<int> onPage;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AsyncContent<NewsOverview>(
      load: repository.overview,
      loadingMessage: 'Opening the news…',
      builder: (BuildContext context, NewsOverview overview) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // The announcements that cannot wait, above everything.
          ...overview.announcements.map(
            (NewsSummary announcement) => _AnnouncementBar(announcement: announcement),
          ),
          if (overview.announcements.isNotEmpty) const Gap.xl(),

          _SearchAndCategories(
            search: search,
            onSearch: onSearch,
            categories: overview.categories,
            selected: category,
            onCategory: onCategory,
          ),
          const Gap.xxl(),

          // Browsing replaces the whole editorial arrangement with a plain
          // list. Somebody who has typed a search wants results, not a hero.
          if (browsing)
            _Results(
              repository: repository,
              category: category,
              query: query,
              page: page,
              onPage: onPage,
              onClear: onClear,
            )
          else if (overview.isEmpty)
            const _NoNewsYet()
          else ...<Widget>[
            if (overview.featured != null) ...<Widget>[
              _FeaturedStory(story: overview.featured!),
              const Gap.section(),
            ],

            if (overview.latest.isNotEmpty) ...<Widget>[
              Text('Latest news', style: Theme.of(context).textTheme.headlineSmall),
              const Gap.lg(),
              _StoryGrid(
                stories: overview.latest
                    .where((NewsSummary story) => story.id != overview.featured?.id)
                    .toList(growable: false),
              ),
              const Gap.section(),
            ],

            if (overview.videos.isNotEmpty) ...<Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.play_circle_outline, color: AppColors.gold),
                  const Gap.hMd(),
                  Text('On film', style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
              const Gap.sm(),
              Text(
                'Stories that carry a recording. The film stays on YouTube; the story stays here.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap.lg(),
              _StoryGrid(stories: overview.videos, compact: true),
              const Gap.section(),
            ],
          ],

          const _SubmitInvitation(),
          const Gap.xxl(),
          const _Philosophy(),
        ],
      ),
    );
  }
}

/// An announcement that sits above the news until it expires.
class _AnnouncementBar extends StatelessWidget {
  const _AnnouncementBar({required this.announcement});

  final NewsSummary announcement;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          borderRadius: AppRadius.mdAll,
          onTap: () => context.go(AppRoutes.newsItem(announcement.slug)),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.campaign_outlined, color: AppColors.goldDark, size: 20),
                const Gap.hMd(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'NOTICE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.goldDark,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const Gap.xs(),
                      Text(announcement.title, style: theme.textTheme.titleMedium),
                      if (announcement.excerpt != null) ...<Widget>[
                        const Gap.xs(),
                        Text(
                          announcement.excerpt!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const Gap.hMd(),
                Icon(Icons.arrow_forward, size: 18, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The search box and the category row.
class _SearchAndCategories extends StatelessWidget {
  const _SearchAndCategories({
    required this.search,
    required this.onSearch,
    required this.categories,
    required this.selected,
    required this.onCategory,
  });

  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final List<NewsCategory> categories;
  final String? selected;
  final ValueChanged<String?> onCategory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: context.isMobile ? double.infinity : 460,
          child: TextField(
            controller: search,
            onChanged: onSearch,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search the news',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          ),
        ),
        const Gap.lg(),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: ChoiceChip(
                  label: const Text('All'),
                  selected: selected == null,
                  onSelected: (_) => onCategory(null),
                ),
              ),
              // Only categories with something in them. A row of twelve
              // filters where nine return nothing teaches people the section
              // is empty when it is not.
              ...categories
                  .where((NewsCategory category) => category.storyCount > 0)
                  .map(
                    (NewsCategory category) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text('${category.name} (${category.storyCount})'),
                        selected: selected == category.slug,
                        onSelected: (_) => onCategory(category.slug),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The story of the moment, given the room to be one.
class _FeaturedStory extends StatelessWidget {
  const _FeaturedStory({required this.story});

  final NewsSummary story;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool stacked = context.screenWidth < Breakpoints.tablet;

    final Widget image = ClipRRect(
      borderRadius: AppRadius.lgAll,
      child: AspectRatio(
        aspectRatio: stacked ? 16 / 9 : 4 / 3,
        child: story.thumbnail != null
            ? Image.network(
                story.thumbnail!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    ColoredBox(color: theme.colorScheme.surfaceContainerHigh),
              )
            : ColoredBox(
                color: theme.colorScheme.surfaceContainerHigh,
                child: Icon(
                  Icons.article_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );

    final Widget words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              (story.categoryName ?? 'News').toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.goldDark,
                letterSpacing: 1.4,
              ),
            ),
            if (story.hasVideo) ...<Widget>[
              const Gap.hMd(),
              const Icon(Icons.play_circle_outline, size: 15, color: AppColors.gold),
            ],
          ],
        ),
        const Gap.md(),
        Text(
          story.title,
          style: stacked ? theme.textTheme.headlineSmall : theme.textTheme.displaySmall,
        ),
        if (story.excerpt != null) ...<Widget>[
          const Gap.md(),
          Text(
            story.excerpt!,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const Gap.lg(),
        Text(
          <String?>[
            Formatters.date(story.displayDate, fallback: ''),
            story.location,
          ].whereType<String>().where((String part) => part.isNotEmpty).join('  ·  '),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap.xl(),
        FilledButton.icon(
          onPressed: () => context.go(AppRoutes.newsItem(story.slug)),
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text('Read the story'),
        ),
      ],
    );

    return stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[image, const Gap.xl(), words],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(flex: 5, child: image),
              const Gap.hXl(),
              Expanded(flex: 6, child: words),
            ],
          );
  }
}

/// The grid of stories.
class _StoryGrid extends StatelessWidget {
  const _StoryGrid({required this.stories, this.compact = false});

  final List<NewsSummary> stories;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) return const SizedBox.shrink();

    final double width = context.screenWidth;
    final int columns = width < 700
        ? 1
        : width < 1100
        ? 2
        : 3;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = AppSpacing.lg;
        final double itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: AppSpacing.xl,
          children: stories
              .map(
                (NewsSummary story) => SizedBox(
                  width: itemWidth,
                  child: NewsCard(story: story, compact: compact),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

/// One story, as a card.
class NewsCard extends StatelessWidget {
  const NewsCard({required this.story, this.compact = false, super.key});

  final NewsSummary story;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: () => context.go(AppRoutes.newsItem(story.slug)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: AppRadius.mdAll,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (story.thumbnail != null)
                      Image.network(
                        story.thumbnail!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            ColoredBox(color: theme.colorScheme.surfaceContainerHigh),
                      )
                    else
                      ColoredBox(
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: Icon(
                          Icons.article_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    // Said on the picture, so a story with film is recognisable
                    // before anything is read.
                    if (story.hasVideo)
                      const Center(
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(0xCC000000),
                          child: Icon(Icons.play_arrow, color: Colors.white, size: 26),
                        ),
                      ),
                    if (story.photoCount > 1)
                      Positioned(
                        right: AppSpacing.sm,
                        bottom: AppSpacing.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xCC000000),
                            borderRadius: AppRadius.pillAll,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.photo_library_outlined,
                                size: 12,
                                color: Colors.white,
                              ),
                              const Gap.hXs(),
                              Text(
                                '${story.photoCount}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Gap.md(),
            if (story.categoryName != null)
              Text(
                story.categoryName!.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.goldDark,
                  letterSpacing: 1.2,
                ),
              ),
            const Gap.xs(),
            Text(
              story.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(height: 1.3),
            ),
            if (!compact && story.excerpt != null) ...<Widget>[
              const Gap.sm(),
              Text(
                story.excerpt!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const Gap.sm(),
            Text(
              <String?>[
                Formatters.date(story.displayDate, fallback: ''),
                story.location,
              ].whereType<String>().where((String part) => part.isNotEmpty).join('  ·  '),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search and category results.
class _Results extends StatelessWidget {
  const _Results({
    required this.repository,
    required this.category,
    required this.query,
    required this.page,
    required this.onPage,
    required this.onClear,
  });

  final NewsPortalRepository repository;
  final String? category;
  final String? query;
  final int page;
  final ValueChanged<int> onPage;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AsyncContent<PaginatedResult<NewsSummary>>(
      key: ValueKey<String>('${category ?? ''}:${query ?? ''}:$page'),
      load: () => repository.list(page: page, perPage: 12, category: category, query: query),
      loadingMessage: 'Searching…',
      isEmpty: (PaginatedResult<NewsSummary> result) => result.isEmpty,
      emptyBuilder: (BuildContext context) => Column(
        children: <Widget>[
          EmptyView(
            icon: Icons.search_off,
            showContributeAction: false,
            title: query != null ? 'Nothing matched “$query”' : 'Nothing in this category yet',
            message: 'Try a different search, or look at everything.',
          ),
          const Gap.lg(),
          Center(
            child: OutlinedButton(onPressed: onClear, child: const Text('Show everything')),
          ),
        ],
      ),
      builder: (BuildContext context, PaginatedResult<NewsSummary> result) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '${Formatters.number(result.total)} '
                '${result.total == 1 ? 'story' : 'stories'}',
                style: theme.textTheme.labelMedium,
              ),
              const Spacer(),
              TextButton(onPressed: onClear, child: const Text('Clear')),
            ],
          ),
          const Gap.lg(),
          _StoryGrid(stories: result.items),
          if (result.totalPages > 1) ...<Widget>[
            const Gap.xxl(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                OutlinedButton(
                  onPressed: page > 1 ? () => onPage(page - 1) : null,
                  child: const Text('Newer'),
                ),
                const Gap.hLg(),
                Text('$page of ${result.totalPages}', style: theme.textTheme.labelMedium),
                const Gap.hLg(),
                OutlinedButton(
                  onPressed: result.hasMore ? () => onPage(page + 1) : null,
                  child: const Text('Older'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The empty state, which still carries the search, the categories and the
/// invitation — a section with nothing in it yet is exactly the moment to ask
/// somebody to put something in it.
class _NoNewsYet extends StatelessWidget {
  const _NoNewsYet();

  @override
  Widget build(BuildContext context) {
    return const EmptyView(
      icon: Icons.article_outlined,
      showContributeAction: false,
      title: 'No news published yet',
      message:
          'Community news and announcements will appear here as they are officially published. '
          'If something has happened that the community should know about, send it in — most of '
          'what belongs here will be written by somebody who was standing there.',
    );
  }
}

/// The invitation to send news in.
class _SubmitInvitation extends StatelessWidget {
  const _SubmitInvitation();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CmsText(
            'page.news.submit.title',
            fallback: 'Do you have news from Ekoli-Yeden?',
            style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          const Gap.md(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
            child: Text(
              'A meeting held, a school opened, somebody appointed, somebody gone. Write it here '
              'and an administrator will read it — they decide what is published under the '
              'community’s name, and your name stays on what you sent.',
              style: theme.textTheme.bodyLarge?.copyWith(color: OnDark.body),
            ),
          ),
          const Gap.xl(),
          FilledButton.icon(
            onPressed: () => context.go(AppRoutes.contributeNews),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Send in news'),
          ),
        ],
      ),
    );
  }
}

/// Why this section exists at all.
class _Philosophy extends StatelessWidget {
  const _Philosophy();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CmsText(
            'page.news.philosophy.title',
            fallback: 'From social media to a permanent archive',
            style: theme.textTheme.titleMedium,
          ),
          const Gap.md(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
            child: CmsText(
              'page.news.philosophy.body',
              fallback:
                  'Social media helps our community share information today. The Ekoli Yeden '
                  'Digital Home makes sure the stories, announcements, achievements and events '
                  'that matter are kept in an organised archive that can still be found years '
                  'from now. Facebook, WhatsApp and YouTube carry the news; this is where it is '
                  'remembered.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
