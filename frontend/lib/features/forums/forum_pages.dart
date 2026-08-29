import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/forum.dart';
import '../../repositories/forum_repository.dart';
import '../../services/auth/auth_controller.dart';

/// THE YAKOLI FORUMS — the index, and one space.
///
/// ---------------------------------------------------------------------------
/// WHAT THIS INTERFACE IS CAREFUL ABOUT
/// ---------------------------------------------------------------------------
///
/// **A space nobody can enter is still shown.** Somebody with an account but no
/// membership sees all three spaces, each with the reason they cannot enter and
/// the one thing that would change it. Hiding the door does not stop somebody
/// wanting through it; it only stops them knowing it is there.
///
/// **Nothing here is ordered by reactions.** The server orders conversations by
/// when somebody last spoke, and this page keeps that order. A community's
/// conversation sorted by approval is one where the loudest thing wins and the
/// quiet question is never answered.
///
/// **Two of the three spaces may contain minors,** so their pages are marked
/// `noindex` from the flag the server sends, in addition to the server refusing
/// their contents to anonymous callers.
class ForumsIndexPage extends StatefulWidget {
  const ForumsIndexPage({super.key});

  @override
  State<ForumsIndexPage> createState() => _ForumsIndexPageState();
}

class _ForumsIndexPageState extends State<ForumsIndexPage> {
  int _reloads = 0;

  @override
  Widget build(BuildContext context) {
    final ForumRepository repository = context.read<ForumRepository>();
    final AuthController auth = context.watch<AuthController>();

    return AppScaffold(
      currentPath: AppRoutes.forums,
      seo: const SeoMetadata(
        title: 'Forums',
        description:
            'The community talking to itself — questions, announcements and the things '
            'worth writing down.',
        canonicalPath: AppRoutes.forums,
      ),
      child: PageSection(
        eyebrow: 'Yakoli',
        title: 'Forums',
        description:
            'Where the community talks to itself. Ask a question, answer one, or say what '
            'happened — and what is said here stays where the next person can find it, '
            'rather than scrolling away in a group chat.',
        child: AsyncContent<List<ForumSpace>>(
          key: ValueKey<int>(_reloads),
          load: repository.spaces,
          loadingMessage: 'Opening the forums…',
          isEmpty: (List<ForumSpace> spaces) => spaces.isEmpty,
          emptyBuilder: (BuildContext context) => const EmptyView(
            icon: Icons.forum_outlined,
            title: 'The forums are not open yet',
            message:
                'The spaces are being prepared. When they open, this is where the community '
                'will talk.',
          ),
          builder: (BuildContext context, List<ForumSpace> spaces) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!auth.isSignedIn) ...<Widget>[
                const _SignedOutNotice(),
                const Gap.xl(),
              ],
              ...spaces.map(
                (ForumSpace space) => _SpaceCard(
                  space: space,
                  onChanged: () => setState(() => _reloads += 1),
                ),
              ),
              const Gap.xxl(),
              const _HouseRules(),
            ],
          ),
        ),
      ),
    );
  }
}

/// An invitation rather than a wall.
///
/// The general space is readable by anybody who arrives from a WhatsApp link,
/// and this says what signing in would add rather than demanding it first.
class _SignedOutNotice extends StatelessWidget {
  const _SignedOutNotice();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Icon(Icons.chat_bubble_outline, color: theme.colorScheme.primary),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'You can read the community space without an account. To reply, to start a '
              'conversation, or to reach the members-only spaces, you need your Okoli '
              'membership.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          FilledButton(
            onPressed: () => context.go(AppRoutes.join),
            child: const Text('Become a member'),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.signInReturningTo(AppRoutes.forums)),
            child: const Text('I have an account'),
          ),
        ],
      ),
    );
  }
}

/// One space on the index.
class _SpaceCard extends StatelessWidget {
  const _SpaceCard({required this.space, required this.onChanged});

  final ForumSpace space;

  /// Asking to join changes what this card should say, so the list reloads.
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = _accentColour(space);
    final bool open = space.canRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.lgAll,
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: open ? () => context.go(AppRoutes.forumSpace(space.slug)) : null,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // The accent stripe carries the space's identity at a glance,
                // and goes grey when the door is shut.
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: open ? accent : theme.colorScheme.outlineVariant,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppRadius.lg),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: (open ? accent : theme.colorScheme.outline)
                                    .withValues(alpha: 0.12),
                                borderRadius: AppRadius.mdAll,
                              ),
                              child: Icon(
                                _iconFor(space),
                                color: open ? accent : theme.colorScheme.outline,
                                size: 22,
                              ),
                            ),
                            const Gap.hLg(),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(space.name, style: theme.textTheme.titleLarge),
                                  if (space.tagline != null) ...<Widget>[
                                    const Gap.xs(),
                                    Text(
                                      space.tagline!,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (!context.isMobile && open)
                              Icon(
                                Icons.arrow_forward,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                          ],
                        ),
                        if (space.description != null) ...<Widget>[
                          const Gap.lg(),
                          Text(
                            space.description!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                        const Gap.lg(),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            _MetaChip(
                              icon: Icons.forum_outlined,
                              label: space.topicCount == 1
                                  ? '1 conversation'
                                  : '${Formatters.number(space.topicCount)} conversations',
                            ),
                            if (space.isPublic)
                              const _MetaChip(
                                icon: Icons.public,
                                label: 'Anybody can read this',
                              )
                            else
                              const _MetaChip(icon: Icons.lock_outline, label: 'Members only'),
                            if (space.isYouthSpace)
                              const _MetaChip(
                                icon: Icons.shield_outlined,
                                label: 'Names only — no contact details shown',
                                emphasis: true,
                              ),
                          ],
                        ),
                        // The reason, and the one thing that would change it.
                        // Somebody who cannot get in should never have to guess
                        // why or what to do about it.
                        if (space.blockedReason != null) ...<Widget>[
                          const Gap.lg(),
                          _BlockedNote(reason: space.blockedReason!, canRead: open),
                        ],
                        const Gap.lg(),
                        _SpaceAction(space: space, onChanged: onChanged),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Why a door is shut, and what opens it.
class _BlockedNote extends StatelessWidget {
  const _BlockedNote({required this.reason, required this.canRead});

  final String reason;

  /// A member who can read but not post gets a softer treatment than somebody
  /// who cannot see the space at all.
  final bool canRead;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            canRead ? Icons.info_outline : Icons.lock_outline,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const Gap.hMd(),
          Expanded(child: Text(reason, style: theme.textTheme.bodySmall)),
          const Gap.hMd(),
          TextButton(
            onPressed: () => context.go(AppRoutes.join),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

/// What is expected of everybody, said once, on the way in.
class _HouseRules extends StatelessWidget {
  const _HouseRules();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('How we talk here', style: theme.textTheme.titleMedium),
          const Gap.md(),
          Text(
            'Say the thing you would say to somebody standing in front of you. Disagree with '
            'what was said rather than with the person who said it. Do not post anybody '
            'else’s phone number, address or photograph without asking them first.',
            style: theme.textTheme.bodyMedium,
          ),
          const Gap.md(),
          Text(
            'If something here is wrong, report it — one press, and a moderator reads it. '
            'Anything that puts a child at risk is hidden the moment it is reported, before '
            'anybody reviews it.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One space
// ---------------------------------------------------------------------------

/// One space: its shelves, and the conversations in it.
class ForumSpacePage extends StatefulWidget {
  const ForumSpacePage({required this.slug, super.key});

  final String slug;

  @override
  State<ForumSpacePage> createState() => _ForumSpacePageState();
}

class _ForumSpacePageState extends State<ForumSpacePage> {
  final TextEditingController _search = TextEditingController();

  String? _category;
  String? _query;
  int _page = 1;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _applySearch() {
    final String text = _search.text.trim();
    setState(() {
      _query = text.isEmpty ? null : text;
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ForumRepository repository = context.read<ForumRepository>();

    return AsyncContent<ForumSpaceView>(
      key: ValueKey<String>('${widget.slug}:${_category ?? ''}:${_query ?? ''}:$_page'),
      load: () => repository.space(
        widget.slug,
        page: _page,
        category: _category,
        query: _query,
      ),
      loadingMessage: 'Opening the conversation…',
      builder: (BuildContext context, ForumSpaceView view) => _SpaceView(
        view: view,
        category: _category,
        query: _query,
        search: _search,
        onSearch: _applySearch,
        onCategory: (String? category) => setState(() {
          _category = category;
          _page = 1;
        }),
        onPage: (int page) => setState(() => _page = page),
      ),
    );
  }
}

class _SpaceView extends StatelessWidget {
  const _SpaceView({
    required this.view,
    required this.category,
    required this.query,
    required this.search,
    required this.onSearch,
    required this.onCategory,
    required this.onPage,
  });

  final ForumSpaceView view;
  final String? category;
  final String? query;
  final TextEditingController search;
  final VoidCallback onSearch;
  final ValueChanged<String?> onCategory;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ForumSpace space = view.space;
    final bool wide = !context.isMobile && !context.isTablet;

    final Widget topics = _TopicList(
      view: view,
      category: category,
      query: query,
      onPage: onPage,
    );

    return AppScaffold(
      currentPath: AppRoutes.forums,
      seo: SeoMetadata(
        title: '${space.name} — Forums',
        description: space.tagline ?? space.description ?? 'A Yakoli forum space.',
        canonicalPath: AppRoutes.forumSpace(space.slug),
        // Two of the three spaces may contain minors. The server says which,
        // and the page honours it as well.
        noIndex: !view.isIndexable,
      ),
      child: PageSection(
        eyebrow: 'Forums',
        title: space.name,
        description: space.tagline,
        action: view.viewer.isModerator
            ? OutlinedButton.icon(
                onPressed: () => context.go(AppRoutes.forumModeration),
                icon: const Icon(Icons.shield_outlined, size: 18),
                label: const Text('Moderation'),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SpaceToolbar(
              view: view,
              search: search,
              onSearch: onSearch,
            ),
            const Gap.xl(),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 260,
                    child: _CategoryRail(
                      view: view,
                      selected: category,
                      onSelect: onCategory,
                    ),
                  ),
                  const Gap.hXl(),
                  Expanded(child: topics),
                ],
              )
            else ...<Widget>[
              _CategoryChips(view: view, selected: category, onSelect: onCategory),
              const Gap.xl(),
              topics,
            ],
            if (space.isYouthSpace) ...<Widget>[
              const Gap.xxl(),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.skyBlue.withValues(alpha: 0.18),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.shield_outlined, size: 20),
                    const Gap.hMd(),
                    Expanded(
                      child: Text(
                        'People here may be young. A post in this space shows a name and '
                        'nothing else — no phone number, no location, no employer — and the '
                        'space is kept out of search engines.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The search box, and the one button that matters.
class _SpaceToolbar extends StatelessWidget {
  const _SpaceToolbar({required this.view, required this.search, required this.onSearch});

  final ForumSpaceView view;
  final TextEditingController search;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canPost = view.viewer.canPost;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SizedBox(
              width: context.isMobile ? double.infinity : 380,
              child: TextField(
                controller: search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => onSearch(),
                decoration: InputDecoration(
                  hintText: 'Search these conversations',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: IconButton(
                    tooltip: 'Search',
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    onPressed: onSearch,
                  ),
                ),
              ),
            ),
            if (canPost)
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.forumNewTopic(view.space.slug)),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Start a conversation'),
              ),
          ],
        ),
        // Said once, at the top, where somebody is deciding whether to type.
        if (!canPost && view.viewer.blockedReason != null) ...<Widget>[
          const Gap.md(),
          Row(
            children: <Widget>[
              Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const Gap.hSm(),
              Flexible(
                child: Text(
                  view.viewer.blockedReason!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The shelves, down the side, grouped under their headings.
class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.view, required this.selected, required this.onSelect});

  final ForumSpaceView view;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, List<ForumCategory>> sections = view.categoriesBySection;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _RailItem(
            label: 'Everything',
            count: view.total,
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final MapEntry<String, List<ForumCategory>> section in sections.entries) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(section.key.toUpperCase(), style: theme.textTheme.labelSmall),
            ),
            ...section.value.map(
              (ForumCategory category) => _RailItem(
                label: category.name,
                count: category.topicCount,
                selected: selected == category.slug,
                locked: category.isModeratorsOnly,
                onTap: () => onSelect(category.slug),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  final String label;
  final int count;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        color: selected ? theme.colorScheme.primary.withValues(alpha: 0.10) : null,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? theme.colorScheme.primary : null,
                ),
              ),
            ),
            if (locked) ...<Widget>[
              Icon(Icons.campaign_outlined, size: 15, color: theme.colorScheme.onSurfaceVariant),
              const Gap.hSm(),
            ],
            Text(
              Formatters.number(count),
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

/// The same shelves, as a scrolling row, on a phone.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.view, required this.selected, required this.onSelect});

  final ForumSpaceView view;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ChoiceChip(
              label: const Text('Everything'),
              selected: selected == null,
              onSelected: (_) => onSelect(null),
            ),
          ),
          ...view.categories.map(
            (ForumCategory category) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(category.name),
                selected: selected == category.slug,
                onSelected: (_) => onSelect(category.slug),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The conversations, in the order the server sent them.
class _TopicList extends StatelessWidget {
  const _TopicList({
    required this.view,
    required this.category,
    required this.query,
    required this.onPage,
  });

  final ForumSpaceView view;
  final String? category;
  final String? query;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (view.topics.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          EmptyView(
            icon: Icons.forum_outlined,
            showContributeAction: false,
            title: query != null
                ? 'Nothing matched “$query”'
                : category != null
                ? 'Nothing here yet'
                : 'No conversations yet',
            message: view.viewer.canPost
                ? 'Be the first to say something. A question counts — somebody here probably '
                      'knows the answer.'
                : 'When somebody starts a conversation here, it will appear on this page.',
          ),
          if (view.viewer.canPost) ...<Widget>[
            const Gap.lg(),
            Center(
              child: FilledButton.icon(
                onPressed: () => context.go(AppRoutes.forumNewTopic(view.space.slug)),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Start a conversation'),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          view.total == 1 ? '1 conversation' : '${Formatters.number(view.total)} conversations',
          style: theme.textTheme.labelMedium,
        ),
        const Gap.md(),
        ...view.topics.map(
          (ForumTopic topic) => TopicRow(topic: topic, spaceSlug: view.space.slug),
        ),
        if (view.totalPages > 1) ...<Widget>[
          const Gap.xl(),
          _Pagination(page: view.page, totalPages: view.totalPages, onPage: onPage),
        ],
      ],
    );
  }
}

/// One conversation in a list.
///
/// The meta line answers the two questions somebody scanning a forum actually
/// has — how busy is it, and is it still alive — before they open anything.
class TopicRow extends StatelessWidget {
  const TopicRow({required this.topic, required this.spaceSlug, super.key});

  final ForumTopic topic;
  final String spaceSlug;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          borderRadius: AppRadius.mdAll,
          onTap: () => context.go(AppRoutes.forumTopic(spaceSlug, topic.slug)),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ForumAvatar(name: topic.authorName, size: 40),
                const Gap.hLg(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (topic.isPinned) ...<Widget>[
                            Padding(
                              padding: const EdgeInsets.only(top: 2, right: AppSpacing.sm),
                              child: Icon(
                                Icons.push_pin_outlined,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                          Expanded(
                            child: Text(
                              topic.title,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          if (topic.isLocked)
                            Tooltip(
                              message: 'Closed to new replies',
                              child: Icon(
                                Icons.lock_outline,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      if (topic.excerpt.isNotEmpty) ...<Widget>[
                        const Gap.sm(),
                        Text(
                          topic.excerpt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const Gap.md(),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          if (topic.categoryName != null)
                            _MetaChip(icon: Icons.label_outline, label: topic.categoryName!),
                          Text(
                            topic.authorName,
                            style: theme.textTheme.labelMedium,
                          ),
                          Text(
                            topic.replyCount == 1
                                ? '1 reply'
                                : '${Formatters.number(topic.replyCount)} replies',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            topic.replyCount == 0
                                ? 'started ${Formatters.relative(topic.createdAt)}'
                                : 'last reply ${Formatters.relative(topic.lastActivityAt)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (topic.isAwaitingApproval) const StatusBadge('pending_review'),
                          if (topic.isHidden)
                            const _MetaChip(
                              icon: Icons.visibility_off_outlined,
                              label: 'Hidden',
                              emphasis: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A circle with somebody's initials.
///
/// Initials rather than a photograph by default: the server sends no avatar in
/// a youth space, and a screen that expected one would have a hole in it.
class ForumAvatar extends StatelessWidget {
  const ForumAvatar({required this.name, this.size = 36, super.key});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ForumAuthor author = ForumAuthor(name: name);

    // A stable colour per person, so the same name looks the same everywhere
    // on the page without anybody storing a preference.
    final List<Color> palette = <Color>[
      AppColors.navy,
      AppColors.green,
      AppColors.goldDark,
      AppColors.navyLight,
      AppColors.greenDark,
    ];
    final Color colour = palette[name.hashCode.abs() % palette.length];

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        author.initials,
        style: theme.textTheme.labelMedium?.copyWith(
          color: colour,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

/// A small labelled fact.
/// THE ONE CONTROL A SPACE CARD NEEDS.
///
/// Which control depends entirely on where the reader stands, and getting that
/// wrong is worse than showing nothing: a "Join" button on a forum somebody was
/// turned away from invites them to be refused twice.
///
///   not signed in      → sign in
///   the General Forum  → nothing; everybody is already in it
///   a member           → open it
///   waiting            → say so, and that it is with the administrators
///   turned away        → say so, with the reason if one was given
///   closed             → say that it is not open to requests
///   otherwise          → ask to join
class _SpaceAction extends StatefulWidget {
  const _SpaceAction({required this.space, required this.onChanged});

  final ForumSpace space;
  final VoidCallback onChanged;

  @override
  State<_SpaceAction> createState() => _SpaceActionState();
}

class _SpaceActionState extends State<_SpaceAction> {
  bool _busy = false;
  String? _notice;

  Future<void> _join() async {
    final String? note = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => _JoinDialog(space: widget.space),
    );
    if (note == null || !mounted) return;

    final ForumRepository repository = context.read<ForumRepository>();
    setState(() => _busy = true);
    try {
      final String message = await repository.requestToJoin(
        widget.space.slug,
        note: note.isEmpty ? null : note,
      );
      if (mounted) setState(() => _notice = message);
      widget.onChanged();
    } on AppException catch (error) {
      if (mounted) setState(() => _notice = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ForumSpace space = widget.space;
    final bool signedIn = context.watch<AuthController>().isSignedIn;

    if (_notice != null) {
      return Text(
        _notice!,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    if (!signedIn) {
      return TextButton.icon(
        onPressed: () => context.go(AppRoutes.signInReturningTo(AppRoutes.forums)),
        icon: const Icon(Icons.login, size: 16),
        label: const Text('Sign in to take part'),
      );
    }

    if (space.isMember || space.isDefault) {
      return FilledButton.tonalIcon(
        onPressed: () => context.go(AppRoutes.forumSpace(space.slug)),
        icon: const Icon(Icons.arrow_forward, size: 16),
        label: Text(space.isDefault ? 'Open — everybody is here' : 'Open'),
      );
    }

    if (space.isPending) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.schedule, size: 15),
          const Gap.hSm(),
          Text('Waiting on the administrators', style: theme.textTheme.bodySmall),
        ],
      );
    }

    if (space.wasRejected) {
      return Text(
        space.blockedReason ?? 'Your request was not accepted.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
      );
    }

    if (space.joinPolicy == 'closed') {
      return Text(
        'Not open to requests — its administrators add people themselves.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    return FilledButton.icon(
      onPressed: _busy ? null : _join,
      icon: const Icon(Icons.group_add_outlined, size: 16),
      label: Text('Ask to join ${space.name}'),
    );
  }
}

class _JoinDialog extends StatefulWidget {
  const _JoinDialog({required this.space});

  final ForumSpace space;

  @override
  State<_JoinDialog> createState() => _JoinDialogState();
}

class _JoinDialogState extends State<_JoinDialog> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ask to join ${widget.space.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'The forum’s administrators will see who is asking and decide. You can say a word '
            'about why you would like to join — it is what they actually decide on.',
          ),
          const Gap.lg(),
          TextField(
            controller: _note,
            maxLength: 500,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Why you would like to join (optional)',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_note.text.trim()),
          child: const Text('Send the request'),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, this.emphasis = false});

  final IconData icon;
  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color colour = emphasis
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 15, color: colour),
        const Gap.hXs(),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: colour)),
      ],
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({required this.page, required this.totalPages, required this.onPage});

  final int page;
  final int totalPages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: page > 1 ? () => onPage(page - 1) : null,
          icon: const Icon(Icons.chevron_left, size: 18),
          label: const Text('Newer'),
        ),
        const Gap.hLg(),
        Text('$page of $totalPages', style: Theme.of(context).textTheme.labelMedium),
        const Gap.hLg(),
        OutlinedButton.icon(
          onPressed: page < totalPages ? () => onPage(page + 1) : null,
          icon: const Icon(Icons.chevron_right, size: 18),
          label: const Text('Older'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reporting — shared by the topic page and every reply on it
// ---------------------------------------------------------------------------

/// Asks why, sends it, and says what happens next.
///
/// Kept to one dialog with nine plain reasons and an optional sentence.
/// Reporting has to be easy or the queue stays empty: somebody being harassed
/// should not have to write an essay about it first.
Future<void> showForumReportDialog(
  BuildContext context, {
  required String targetType,
  required String targetId,
}) async {
  final ForumRepository repository = context.read<ForumRepository>();
  final TextEditingController detail = TextEditingController();
  String reason = ForumReasons.all.first.value;

  final bool send =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => StatefulBuilder(
          builder: (BuildContext inner, StateSetter setInner) {
            final ({String value, String label, String help}) chosen = ForumReasons.all
                .firstWhere((({String value, String label, String help}) r) => r.value == reason);

            return AlertDialog(
              title: Text(targetType == 'topic' ? 'Report this conversation' : 'Report this reply'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'A moderator reads every report. You do not need to explain at '
                        'length — the reason is enough.',
                      ),
                      const Gap.lg(),
                      DropdownButtonFormField<String>(
                        initialValue: reason,
                        decoration: const InputDecoration(labelText: 'What is wrong with it?'),
                        items: ForumReasons.all
                            .map(
                              (({String value, String label, String help}) option) =>
                                  DropdownMenuItem<String>(
                                    value: option.value,
                                    child: Text(option.label),
                                  ),
                            )
                            .toList(growable: false),
                        onChanged: (String? value) => setInner(() => reason = value ?? reason),
                      ),
                      const Gap.sm(),
                      Text(
                        chosen.help,
                        style: Theme.of(inner).textTheme.bodySmall?.copyWith(
                          color: chosen.value == 'child_safety'
                              ? Theme.of(inner).colorScheme.error
                              : Theme.of(inner).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Gap.lg(),
                      TextField(
                        controller: detail,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Anything you want to add (optional)',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Send the report'),
                ),
              ],
            );
          },
        ),
      ) ??
      false;

  if (!send || !context.mounted) return;

  try {
    final String message = await repository.report(
      targetType,
      targetId,
      reason: reason,
      detail: detail.text.trim().isEmpty ? null : detail.text.trim(),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  } on AppException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

Color _accentColour(ForumSpace space) {
  switch (space.kind) {
    case 'youth':
      return AppColors.green;
    case 'students':
      return AppColors.goldDark;
    default:
      return AppColors.navy;
  }
}

IconData _iconFor(ForumSpace space) {
  switch (space.kind) {
    case 'youth':
      return Icons.groups_outlined;
    case 'students':
      return Icons.school_outlined;
    default:
      return Icons.forum_outlined;
  }
}
