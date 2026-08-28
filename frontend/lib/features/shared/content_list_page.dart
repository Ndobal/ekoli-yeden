import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/service_locator.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/cms_text.dart';
import '../../core/widgets/content_card.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/content_record.dart';
import '../../repositories/content_repository.dart';
import '../../services/api/api_response.dart';

/// The index page for any content type.
///
/// History, leadership, people, news, events, galleries, businesses,
/// organizations and community projects all render through this. Each feature
/// supplies its own title, description, empty-state wording and the line of
/// metadata shown under each card — the differences that actually matter to a
/// visitor — rather than a duplicated screen.
class ContentListPage extends StatefulWidget {
  const ContentListPage({
    required this.resource,
    required this.title,
    required this.basePath,
    this.eyebrow,
    this.description,
    this.descriptionKey,
    this.emptyTitle,
    this.emptyMessage,
    this.metaBuilder,
    this.showVerification = false,
    this.maxColumns = 3,
    this.searchable = true,
    this.footer,
    this.emptyAction,
    this.bare = false,
    super.key,
  });

  /// Renders the list without the page around it.
  ///
  /// Used where a section becomes a tab of another page rather than a page of
  /// its own — the community projects inside News. The scaffold, the heading
  /// and the SEO belong to the host in that case, and nesting a second one
  /// would produce two headers and two footers.
  final bool bare;

  /// Replaces the empty state's "Contribute to the archive" button.
  ///
  /// A section whose contributions are structured needs to send people to its
  /// own form. See `PeopleListPage`, where the button builds a biography.
  final ({String label, IconData icon, String prompt, String path})? emptyAction;

  /// The API resource key, e.g. `history`.
  final String resource;

  final String title;

  /// Public path prefix used to build links to each record.
  final String basePath;

  final String? eyebrow;

  /// The fallback introduction, used when `descriptionKey` has no CMS value.
  final String? description;

  /// CMS key for the introduction, so the Editorial Team can rewrite it.
  final String? descriptionKey;

  final String? emptyTitle;
  final String? emptyMessage;

  /// The line beneath each card's title.
  final String? Function(ContentRecord record)? metaBuilder;

  final bool showVerification;
  final int maxColumns;
  final bool searchable;

  /// Rendered below the list, whether or not the list has anything in it.
  ///
  /// Used by the Gallery, which shows its albums and then every photograph
  /// across all of them — two different questions about the same records, and
  /// the second one is not worth a page of its own on the way in.
  final Widget? footer;

  @override
  State<ContentListPage> createState() => _ContentListPageState();
}

class _ContentListPageState extends State<ContentListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  int _page = 1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch(String value) {
    setState(() {
      _search = value.trim();
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ContentRepository repository = context.contentRepository(widget.resource);

    // The introduction comes from the CMS where a key is supplied, so the
    // Editorial Team can rewrite any section's opening paragraph without a
    // deployment. The constructor argument is the fallback.
    final String? description = widget.descriptionKey == null
        ? widget.description
        : context.cmsWatch(widget.descriptionKey!, fallback: widget.description ?? '');

    final Widget body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (widget.searchable) ...<Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: _applySearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search ${widget.title.toLowerCase()}',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _applySearch('');
                            },
                          ),
                  ),
                ),
              ),
              const Gap.xl(),
            ],
            AsyncContent<PaginatedResult<ContentRecord>>(
              // The key rebuilds the future when the query changes.
              key: ValueKey<String>('${widget.resource}:$_search:$_page'),
              load: () => repository.list(page: _page, search: _search.isEmpty ? null : _search),
              loadingMessage: 'Opening the archive…',
              isEmpty: (PaginatedResult<ContentRecord> result) => result.isEmpty,
              emptyBuilder: (BuildContext context) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  EmptyView(
                    title: _search.isEmpty
                        ? (widget.emptyTitle ?? 'Nothing recorded yet')
                        : 'No results for “$_search”',
                    message: _search.isEmpty
                        ? (widget.emptyMessage ??
                            'This part of the archive is ready and waiting for verified material from the community.')
                        : 'Try a different search, or browse everything by clearing the search box.',
                    showContributeAction: _search.isEmpty,
                    contributeLabel: widget.emptyAction?.label,
                    contributeIcon: widget.emptyAction?.icon,
                    contributePrompt: widget.emptyAction?.prompt,
                    onContribute: widget.emptyAction == null
                        ? null
                        : () => context.go(widget.emptyAction!.path),
                  ),
                  ?widget.footer,
                ],
              ),
              builder: (BuildContext context, PaginatedResult<ContentRecord> result) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ResponsiveCardGrid(
                      maxColumns: widget.maxColumns,
                      children: result.items
                          .map(
                            (ContentRecord record) => ContentCard(
                              record: record,
                              path: '${widget.basePath}/${record.pathSegment}',
                              metaLine: widget.metaBuilder?.call(record),
                              showVerification: widget.showVerification,
                            ),
                          )
                          .toList(growable: false),
                    ),
                    if (result.totalPages > 1) ...<Widget>[
                      const Gap.xxl(),
                      _Pagination(
                        page: result.page,
                        totalPages: result.totalPages,
                        total: result.total,
                        onChanged: (int page) => setState(() => _page = page),
                      ),
                    ],
                    ?widget.footer,
                  ],
                );
              },
            ),
          ],
    );

    // A tab of another page supplies its own scaffold and heading. Nesting a
    // second one would give the visitor two headers and two footers.
    if (widget.bare) return body;

    return AppScaffold(
      currentPath: widget.basePath,
      seo: SeoMetadata(
        title: widget.title,
        description: description,
        canonicalPath: widget.basePath,
      ),
      child: PageSection(
        eyebrow: widget.eyebrow,
        title: widget.title,
        description: description,
        child: body,
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onChanged,
  });

  final int page;
  final int totalPages;
  final int total;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: page > 1 ? () => onChanged(page - 1) : null,
          icon: const Icon(Icons.chevron_left, size: 18),
          label: const Text('Previous'),
        ),
        const Gap.hMd(),
        Text(
          'Page $page of $totalPages · ${Formatters.number(total)} entries',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Gap.hMd(),
        OutlinedButton.icon(
          onPressed: page < totalPages ? () => onChanged(page + 1) : null,
          icon: const Icon(Icons.chevron_right, size: 18),
          label: const Text('Next'),
          iconAlignment: IconAlignment.end,
        ),
      ],
    );
  }
}
