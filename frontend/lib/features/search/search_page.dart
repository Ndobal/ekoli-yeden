import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/cms_text.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../repositories/settings_repository.dart';

/// One search across the whole archive.
///
/// History, culture, people, leadership, language, news, events, Leboku,
/// photographs, videos, businesses, organizations and projects are all searched
/// together — because a visitor looking for a name does not know, and should
/// not need to know, which section it was filed under.
class SearchPage extends StatefulWidget {
  const SearchPage({this.initialQuery, super.key});

  final String? initialQuery;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _controller;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery ?? '';
    _controller = TextEditingController(text: _query);
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keeps the box in step when the visitor navigates with a ?q= URL, which
    // is how a shared search link arrives.
    if (widget.initialQuery != oldWidget.initialQuery) {
      _query = widget.initialQuery ?? '';
      _controller.text = _query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _run(String value) {
    final String trimmed = value.trim();
    setState(() => _query = trimmed);
    // Written into the URL so a search can be bookmarked and shared.
    if (trimmed.isEmpty) {
      context.go(AppRoutes.search);
    } else {
      context.go(AppRoutes.searchFor(trimmed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppScaffold(
      currentPath: AppRoutes.search,
      seo: SeoMetadata(
        title: _query.isEmpty ? 'Search the archive' : 'Search: $_query',
        description: 'Search the history, people, language, photographs and videos of Ekoli-Yeden.',
        canonicalPath: AppRoutes.search,
      ),
      child: PageSection(
        eyebrow: 'Search',
        title: context.cmsWatch('system.search', fallback: 'Search the archive'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onSubmitted: _run,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: context.cms(
                    'system.search_placeholder',
                    fallback: 'Search the archive…',
                  ),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear search',
                          onPressed: () {
                            _controller.clear();
                            _run('');
                          },
                        ),
                ),
              ),
            ),
            const Gap.xxl(),
            if (_query.trim().length < 2)
              Text(
                'Type at least two characters to search.',
                style: theme.textTheme.bodyMedium,
              )
            else
              AsyncContent<SearchResults>(
                key: ValueKey<String>('search:$_query'),
                load: () => context.read<SettingsRepository>().search(_query),
                loadingMessage: 'Searching the archive…',
                isEmpty: (SearchResults results) => results.isEmpty,
                emptyBuilder: (BuildContext context) => EmptyView(
                  icon: Icons.search_off,
                  title: 'Nothing found for “$_query”',
                  message:
                      'Either that material is not in the archive yet, or it is recorded under '
                      'different words. If you know something that should be here, please '
                      'contribute it.',
                ),
                builder: (BuildContext context, SearchResults results) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${results.total} result${results.total == 1 ? '' : 's'} for “${results.query}”',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Gap.xl(),
                    ...results.groups.map(
                      (SearchGroup group) => _ResultGroup(group: group),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultGroup extends StatelessWidget {
  const _ResultGroup({required this.group});

  final SearchGroup group;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                group.label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.gold,
                  letterSpacing: 1.4,
                ),
              ),
              const Gap.hSm(),
              Text('(${group.total})', style: theme.textTheme.labelSmall),
            ],
          ),
          const Gap.md(),
          ...group.hits.map((SearchHit hit) => _ResultRow(hit: hit)),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.hit});

  final SearchHit hit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? path = AppRoutes.forSearchHit(hit.resource, hit.pathSegment);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: path == null ? null : () => context.go(path),
        borderRadius: AppRadius.smAll,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(hit.title, style: theme.textTheme.titleSmall),
              if (hit.excerpt != null) ...<Widget>[
                const Gap.xs(),
                Text(hit.excerpt!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
