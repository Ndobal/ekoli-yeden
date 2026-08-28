import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/member.dart';
import '../../repositories/member_repository.dart';
import '../../services/api/api_response.dart';
import '../../services/auth/auth_controller.dart';

/// THE YAKOLI DIRECTORY (Module 7).
///
/// The people of Ekoli-Yeden who have chosen to be findable — by what they do,
/// what they can do, and where they are.
///
/// ---------------------------------------------------------------------------
/// NOBODY IS HERE WHO DID NOT ASK TO BE
/// ---------------------------------------------------------------------------
///
/// Listing is opt-in and defaults to off, and that is enforced in the server's
/// query rather than by filtering afterwards. A member who has opted in is
/// still shown only what they marked visible: agreeing to be findable is not
/// the same as publishing a phone number, and the two are decided separately.
///
/// The page itself is readable without an account, so a relative abroad can
/// find somebody without joining first — but a signed-in member sees more,
/// because members chose what members may see.
class DirectoryPage extends StatefulWidget {
  const DirectoryPage({super.key});

  @override
  State<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage> {
  final TextEditingController _search = TextEditingController();
  String? _professionId;
  String? _country;
  int _page = 1;
  int _reloads = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _apply() => setState(() {
        _page = 1;
        _reloads += 1;
      });

  @override
  Widget build(BuildContext context) {
    final MemberRepository repository = context.read<MemberRepository>();
    final AuthController auth = context.watch<AuthController>();

    // The directory is the community's list of itself, not a public register.
    // Somebody signed out is offered membership rather than shown the people.
    if (!auth.isSignedIn) return const _MembersOnly();

    return AppScaffold(
      currentPath: AppRoutes.directory,
      seo: const SeoMetadata(
        title: 'Member directory',
        description:
            'The people of Ekoli-Yeden who have chosen to be findable — by profession, skill and '
            'where they are.',
        canonicalPath: AppRoutes.directory,
        // Never offered to a search engine. A list of real people, with their
        // professions and where they live, is exactly the page that should not
        // be indexable — the server refuses it to an anonymous caller, and this
        // says the same thing to a crawler.
        noIndex: true,
      ),
      child: PageSection(
        eyebrow: 'Yakoli',
        title: 'Member directory',
        description:
            'People of Ekoli-Yeden who chose to be listed. Search by what somebody does, or by '
            'where they are — a teacher in Ekori, an engineer in Lagos, a nurse abroad.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!auth.isMember) ...<Widget>[
              _JoinPrompt(signedIn: auth.isSignedIn),
              const Gap.xl(),
            ],
            TextField(
              controller: _search,
              onSubmitted: (_) => _apply(),
              decoration: InputDecoration(
                labelText: 'Search by name, work or employer',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _apply,
                ),
              ),
            ),
            const Gap.lg(),
            AsyncContent<
                ({
                  List<({String id, String name, int count})> professions,
                  List<({String name, int count})> countries
                })>(
              load: repository.directoryFacets,
              // Facets are a convenience. Their absence should never stop the
              // directory itself from rendering.
              emptyBuilder: (BuildContext context) => const SizedBox.shrink(),
              builder: (
                BuildContext context,
                ({
                  List<({String id, String name, int count})> professions,
                  List<({String name, int count})> countries
                }) facets,
              ) =>
                  Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  FilterChip(
                    selected: _professionId == null && _country == null,
                    showCheckmark: false,
                    label: const Text('Everyone'),
                    onSelected: (bool _) => setState(() {
                      _professionId = null;
                      _country = null;
                      _page = 1;
                      _reloads += 1;
                    }),
                  ),
                  ...facets.professions.take(12).map(
                        (({String id, String name, int count}) profession) => FilterChip(
                          selected: _professionId == profession.id,
                          showCheckmark: false,
                          label: Text('${profession.name} (${profession.count})'),
                          onSelected: (bool _) => setState(() {
                            _professionId =
                                _professionId == profession.id ? null : profession.id;
                            _country = null;
                            _page = 1;
                            _reloads += 1;
                          }),
                        ),
                      ),
                  ...facets.countries.take(6).map(
                        (({String name, int count}) country) => FilterChip(
                          selected: _country == country.name,
                          showCheckmark: false,
                          avatar: const Icon(Icons.public, size: 15),
                          label: Text('${country.name} (${country.count})'),
                          onSelected: (bool _) => setState(() {
                            _country = _country == country.name ? null : country.name;
                            _professionId = null;
                            _page = 1;
                            _reloads += 1;
                          }),
                        ),
                      ),
                ],
              ),
            ),
            const Gap.xl(),
            AsyncContent<PaginatedResult<MemberProfile>>(
              key: ValueKey<String>('$_reloads:$_page'),
              load: () => repository.directory(
                page: _page,
                perPage: 24,
                query: _search.text.trim().isEmpty ? null : _search.text.trim(),
                professionId: _professionId,
                country: _country,
              ),
              loadingMessage: 'Looking…',
              isEmpty: (PaginatedResult<MemberProfile> r) => r.isEmpty,
              emptyBuilder: (BuildContext context) => const EmptyView(
                icon: Icons.contacts_outlined,
                title: 'Nobody found',
                message:
                    'Either nobody matches that, or they have not chosen to be listed. Being in '
                    'the directory is something each member turns on for themselves.',
              ),
              builder: (BuildContext context, PaginatedResult<MemberProfile> result) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${Formatters.number(result.total)} listed',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const Gap.md(),
                  _MemberGrid(members: result.items),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown to somebody who is not listed, because they are the person who can
/// change that.
class _JoinPrompt extends StatelessWidget {
  const _JoinPrompt({required this.signedIn});

  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.person_search_outlined, size: 20),
          const Gap.hMd(),
          Expanded(
            child: Text(
              signedIn
                  ? 'You are not listed here. Members find each other by what they do — turn it '
                      'on in your privacy settings whenever you like, and off again just as easily.'
                  : 'Become a member and other people of Ekoli-Yeden can find you here, if you '
                      'choose to be listed.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const Gap.hMd(),
          FilledButton(
            onPressed: () =>
                context.go(signedIn ? AppRoutes.accountPrivacy : AppRoutes.join),
            child: Text(signedIn ? 'Privacy settings' : 'Join'),
          ),
        ],
      ),
    );
  }
}

class _MemberGrid extends StatelessWidget {
  const _MemberGrid({required this.members});

  final List<MemberProfile> members;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth > 900
            ? 3
            : constraints.maxWidth > 560
                ? 2
                : 1;
        final double width = (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: members
              .map((MemberProfile m) => SizedBox(width: width, child: _MemberCard(member: m)))
              .toList(growable: false),
        );
      },
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member});

  final MemberProfile member;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final String? place = <String?>[member.communityArea, member.city, member.country]
        .whereType<String>()
        .where((String part) => part.isNotEmpty)
        .firstOrNull;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: AppRadius.mdAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(AppRoutes.memberProfile(member.handle)),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.green.withValues(alpha: 0.15),
                backgroundImage:
                    member.avatarUrl == null ? null : NetworkImage(member.avatarUrl!),
                child: member.avatarUrl != null
                    ? null
                    : Text(
                        _initials(member.fullName ?? ''),
                        style: theme.textTheme.titleSmall?.copyWith(color: AppColors.greenDark),
                      ),
              ),
              const Gap.hMd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      // A listed member without a name is a profile somebody
                      // started and did not finish; the handle at least gives
                      // the reader something to press.
                      member.fullName ?? member.handle,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (member.headline != null)
                      Text(
                        member.headline!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (place != null)
                      Text(
                        place,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final List<String> parts =
        name.trim().split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}

/// The door, for somebody who is not through it yet.
///
/// It says what the directory is and how to reach it rather than refusing
/// flatly — the answer to "why can I not see this" is "join, it takes a
/// minute", and a page that does not say so reads as a wall.
class _MembersOnly extends StatelessWidget {
  const _MembersOnly();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppScaffold(
      currentPath: AppRoutes.directory,
      seo: const SeoMetadata(
        title: 'Member directory',
        description: 'The Yakoli member directory is for members of the community.',
        noIndex: true,
      ),
      child: PageSection(
        reading: true,
        eyebrow: 'Yakoli',
        title: 'The directory is for members',
        description:
            'It lists people of Ekoli-Yeden who chose to be findable — what they do, and where '
            'they are. Because those are real people, it is not open to everybody who finds the '
            'address.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Joining is free and takes a minute. Nothing about you appears here unless you '
              'switch it on yourself.',
              style: theme.textTheme.bodyMedium,
            ),
            const Gap.xl(),
            Row(
              children: <Widget>[
                FilledButton(
                  onPressed: () => context.go(AppRoutes.join),
                  child: const Text('Become a member'),
                ),
                const Gap.hLg(),
                TextButton(
                  onPressed: () =>
                      context.go(AppRoutes.signInReturningTo(AppRoutes.directory)),
                  child: const Text('I have an account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
