import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/service_locator.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/cms_text.dart';
import '../../core/widgets/content_card.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/age_grade.dart';
import '../../models/content_record.dart';
import '../../repositories/age_grade_repository.dart';
import '../../services/api/api_response.dart';
import '../../services/auth/auth_controller.dart';
import '../gallery/gallery_pages.dart';

/// AGE GRADES.
///
/// Age grades are one of the ways Ekoli-Yeden organises itself. Until now they
/// were articles that only a volunteer editor could write — which is the wrong
/// shape, because the people who know what a grade has been doing this year
/// are its own members.
///
/// So a grade keeps its own page: it registers, waits for the Preservation Team
/// to confirm it, and from then on its administrators add its roster, its
/// photographs and its news. What the grade says about itself is labelled as
/// exactly that, so it is never mistaken for verified community history.
class AgeGradesListPage extends StatelessWidget {
  const AgeGradesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ContentListPageWithActivity();
  }
}

/// The index: the grades themselves, then what they have been saying.
class ContentListPageWithActivity extends StatelessWidget {
  const ContentListPageWithActivity({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthController auth = context.watch<AuthController>();

    final String description = context.cmsWatch(
      'page.age_grades.intro',
      fallback:
          'Age grades are one of the ways Ekoli-Yeden organises itself — groupings of people of a '
          'similar age who take on responsibilities together. Each grade keeps its own page here.',
    );

    return AppScaffold(
      currentPath: AppRoutes.ageGrades,
      seo: SeoMetadata(
        title: 'Age Grades',
        description: description,
        canonicalPath: AppRoutes.ageGrades,
      ),
      child: Column(
        children: <Widget>[
          PageSection(
            eyebrow: 'Community structure',
            title: 'Age Grades',
            description: description,
            action: FilledButton.icon(
              onPressed: () => context.go(
                auth.isSignedIn
                    ? AppRoutes.registerAgeGrade
                    : AppRoutes.signInReturningTo(AppRoutes.registerAgeGrade),
              ),
              icon: const Icon(Icons.groups_outlined, size: 18),
              label: const Text('Register your age grade'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _HowItWorks(),
                const Gap.xxl(),
                AsyncContent<PaginatedResult<ContentRecord>>(
                  load: () => context.contentRepository('age-grades').list(perPage: 48),
                  loadingMessage: 'Opening the age grades…',
                  isEmpty: (PaginatedResult<ContentRecord> result) => result.isEmpty,
                  emptyBuilder: (BuildContext context) => const EmptyView(
                    icon: Icons.groups_outlined,
                    title: 'No age grades recorded yet',
                    message:
                        'Each age grade should have its own page here: its name, when it was '
                        'formed, who belongs to it, and what it has done for the community. If you '
                        'belong to a grade, you can register it and keep its page yourself.',
                    showContributeAction: false,
                  ),
                  builder: (BuildContext context, PaginatedResult<ContentRecord> result) {
                    return ResponsiveCardGrid(
                      maxColumns: 3,
                      children: result.items
                          .map(
                            (ContentRecord record) => ContentCard(
                              record: record,
                              path: AppRoutes.ageGrade(record.pathSegment),
                              metaLine: record.text('birth_years') ??
                                  (record.number('formed_year') == null
                                      ? null
                                      : 'Formed ${record.number('formed_year')}'),
                              showVerification: true,
                            ),
                          )
                          .toList(growable: false),
                    );
                  },
                ),
              ],
            ),
          ),
          PageSection(
            background: theme.colorScheme.surfaceContainerHigh,
            title: 'From the age grades',
            description:
                'What the grades themselves have posted — meetings, projects, reports and notices, '
                'in their own words.',
            child: const _ActivityFeed(),
          ),
        ],
      ),
    );
  }
}

/// Explains the arrangement plainly, because it is unusual: this is the one
/// part of the archive the community runs directly.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    const List<({String title, String detail})> steps = <({String title, String detail})>[
      (
        title: 'Register the grade',
        detail: 'Any member with an account can register their grade. Give its name and the year '
            'it was formed.'
      ),
      (
        title: 'The Preservation Team confirms it',
        detail: 'A page that speaks for a body of the community is checked before it goes live. '
            'That is the only gate.'
      ),
      (
        title: 'The grade runs its own page',
        detail: 'You and anybody you appoint add the roster, the photographs and the news. '
            'Nobody has to wait for an editor.'
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.05),
        borderRadius: AppRadius.mdAll,
        border: const Border(left: BorderSide(color: AppColors.navy, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('How an age grade keeps its page', style: theme.textTheme.titleMedium),
          const Gap.lg(),
          ...steps.asMap().entries.map(
                (MapEntry<int, ({String title, String detail})> entry) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.navy.withValues(alpha: 0.12),
                        child: Text(
                          '${entry.key + 1}',
                          style: theme.textTheme.labelSmall?.copyWith(color: AppColors.navy),
                        ),
                      ),
                      const Gap.hMd(),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(entry.value.title, style: theme.textTheme.titleSmall),
                            const Gap.xs(),
                            Text(entry.value.detail, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed();

  @override
  Widget build(BuildContext context) {
    return AsyncContent<List<AgeGradePost>>(
      load: context.read<AgeGradeRepository>().activity,
      isEmpty: (List<AgeGradePost> posts) => posts.isEmpty,
      emptyBuilder: (BuildContext context) => const AwaitingMaterialNote(
        message:
            'No age grade has posted anything yet. Once a grade is confirmed, its administrators '
            'can post meeting notices, reports and news, and they will appear here.',
      ),
      builder: (BuildContext context, List<AgeGradePost> posts) {
        return Column(
          children: posts
              .map(
                (AgeGradePost post) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AgeGradePostCard(post: post, showGrade: true),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

/// ONE AGE GRADE.
class AgeGradeDetailPage extends StatelessWidget {
  const AgeGradeDetailPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final AgeGradeRepository repository = context.read<AgeGradeRepository>();
    final ThemeData theme = Theme.of(context);

    return AsyncContent<AgeGrade>(
      load: () => repository.grade(slug),
      loadingMessage: 'Opening the age grade…',
      builder: (BuildContext context, AgeGrade grade) {
        return AppScaffold(
          currentPath: AppRoutes.ageGrades,
          seo: SeoMetadata(
            title: grade.title,
            description: grade.excerpt,
            canonicalPath: AppRoutes.ageGrade(grade.slug),
            type: 'article',
          ),
          child: Column(
            children: <Widget>[
              _GradeHeader(grade: grade),

              if (grade.body != null)
                PageSection(
                  reading: true,
                  title: 'About this grade',
                  child: SelectableText(grade.body!, style: theme.textTheme.bodyLarge),
                ),

              PageSection(
                background: grade.body == null ? null : theme.colorScheme.surfaceContainerHigh,
                title: 'News from the grade',
                description:
                    'Posted by the age grade itself. The Preservation Team has not verified these '
                    'as community history — they are the grade speaking for itself, which is a '
                    'different and equally worthwhile thing.',
                child: grade.posts.isEmpty
                    ? const AwaitingMaterialNote(
                        message:
                            'This grade has not posted anything yet. Its administrators can post '
                            'meeting notices, reports and news from their own workspace.',
                      )
                    : Column(
                        children: grade.posts
                            .map(
                              (AgeGradePost post) => Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: AgeGradePostCard(post: post, gradeSlug: grade.slug),
                              ),
                            )
                            .toList(growable: false),
                      ),
              ),

              if (grade.members.isNotEmpty)
                PageSection(
                  title: 'Members',
                  description:
                      'The roster as the grade has recorded it. A name appears here only once '
                      'somebody has confirmed it belongs.',
                  child: _MemberList(members: grade.members),
                ),

              if (grade.gallery.isNotEmpty)
                PageSection(
                  background: theme.colorScheme.surfaceContainerHigh,
                  title: 'Photographs',
                  child: PhotographGrid(photographs: grade.gallery),
                ),

              if (grade.administrators.isNotEmpty)
                PageSection(
                  title: 'Who keeps this page',
                  child: Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: grade.administrators
                        .map(
                          (AgeGradeAdmin admin) => Chip(
                            avatar: Icon(
                              admin.isLead ? Icons.star_outline : Icons.person_outline,
                              size: 16,
                            ),
                            label: Text(
                              admin.office == null
                                  ? admin.displayName
                                  : '${admin.displayName} · ${admin.office}',
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GradeHeader extends StatelessWidget {
  const _GradeHeader({required this.grade});

  final AgeGrade grade;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthController auth = context.watch<AuthController>();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.navy, AppColors.greenDark],
        ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: context.isMobile ? AppSpacing.xxxl : AppSpacing.huge,
      ),
      child: ContentContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.ageGrades),
              icon: const Icon(Icons.arrow_back, size: 18, color: Colors.white70),
              label: const Text('All age grades', style: TextStyle(color: Colors.white70)),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
            const Gap.md(),
            Text(
              grade.title,
              style: (context.isMobile
                      ? theme.textTheme.displaySmall
                      : theme.textTheme.displayMedium)
                  ?.copyWith(color: Colors.white),
            ),
            if (grade.subtitle != null) ...<Widget>[
              const Gap.sm(),
              Text(
                grade.subtitle!,
                style: theme.textTheme.titleMedium?.copyWith(color: AppColors.goldLight),
              ),
            ],
            if (grade.motto != null) ...<Widget>[
              const Gap.md(),
              Text(
                '“${grade.motto}”',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.goldLight,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const Gap.lg(),
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                if (grade.formedYear != null)
                  _HeaderFact(icon: Icons.event_outlined, text: 'Formed ${grade.formedYear}'),
                if (grade.birthYears != null)
                  _HeaderFact(icon: Icons.cake_outlined, text: 'Born ${grade.birthYears}'),
                if (grade.members.isNotEmpty)
                  _HeaderFact(
                    icon: Icons.people_outline,
                    text: '${grade.members.length} members listed',
                  ),
              ],
            ),
            // The grade's own administrators get a way in from the page itself.
            // Everybody else never learns the workspace exists, which is the
            // right amount of interface for a control they cannot use.
            if (auth.isSignedIn) ...<Widget>[
              const Gap.xl(),
              OutlinedButton.icon(
                onPressed: () => context.go(AppRoutes.ageGradeManage(grade.slug)),
                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                label: const Text('Manage this page', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderFact extends StatelessWidget {
  const _HeaderFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: Colors.white70),
        const Gap.hSm(),
        Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

/// One post by an age grade, labelled as the grade's own words.
class AgeGradePostCard extends StatelessWidget {
  const AgeGradePostCard({
    required this.post,
    this.gradeSlug,
    this.showGrade = false,
    this.trailing,
    super.key,
  });

  final AgeGradePost post;
  final String? gradeSlug;
  final bool showGrade;

  /// The controls a grade's own administrator sees on their workspace.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? slug = gradeSlug ?? post.gradeSlug;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha: 0.10),
                        borderRadius: AppRadius.pillAll,
                      ),
                      child: Text(
                        post.postTypeLabel,
                        style: theme.textTheme.labelSmall?.copyWith(color: AppColors.navy),
                      ),
                    ),
                    if (showGrade && post.gradeTitle != null)
                      Text(
                        post.gradeTitle!,
                        style: theme.textTheme.labelMedium?.copyWith(color: AppColors.greenDark),
                      ),
                    if (post.displayDate != null)
                      Text(
                        Formatters.shortDate(post.displayDate),
                        style: theme.textTheme.labelSmall,
                      ),
                    if (!post.isPublished) StatusBadge(post.status),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const Gap.sm(),
          if (slug != null)
            InkWell(
              onTap: () => context.go(AppRoutes.ageGradePost(slug, post.slug)),
              child: Text(post.title, style: theme.textTheme.titleMedium),
            )
          else
            Text(post.title, style: theme.textTheme.titleMedium),
          if (post.excerpt != null || post.body != null) ...<Widget>[
            const Gap.xs(),
            Text(
              post.excerpt ?? Formatters.excerpt(post.body, maxLength: 200),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

/// ONE POST, IN FULL.
class AgeGradePostPage extends StatelessWidget {
  const AgeGradePostPage({required this.gradeSlug, required this.postSlug, super.key});

  final String gradeSlug;
  final String postSlug;

  @override
  Widget build(BuildContext context) {
    final AgeGradeRepository repository = context.read<AgeGradeRepository>();
    final ThemeData theme = Theme.of(context);

    return AsyncContent<AgeGradePost>(
      load: () => repository.post(gradeSlug, postSlug),
      loadingMessage: 'Opening the post…',
      builder: (BuildContext context, AgeGradePost post) {
        return AppScaffold(
          currentPath: AppRoutes.ageGrades,
          seo: SeoMetadata(
            title: post.title,
            description: post.excerpt,
            canonicalPath: AppRoutes.ageGradePost(gradeSlug, post.slug),
            type: 'article',
          ),
          child: PageSection(
            reading: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextButton.icon(
                  onPressed: () => context.go(AppRoutes.ageGrade(gradeSlug)),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: Text(post.authorName ?? 'Back to the age grade'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
                const Gap.lg(),
                Text(post.postTypeLabel.toUpperCase(), style: theme.textTheme.labelSmall),
                const Gap.sm(),
                Text(post.title, style: theme.textTheme.displaySmall),
                const Gap.md(),
                Wrap(
                  spacing: AppSpacing.lg,
                  children: <Widget>[
                    if (post.authorName != null)
                      Text('Posted by ${post.authorName}', style: theme.textTheme.bodySmall),
                    if (post.displayDate != null)
                      Text(Formatters.date(post.displayDate), style: theme.textTheme.bodySmall),
                  ],
                ),
                const Gap.xl(),
                // The label that keeps a grade's own account of itself from
                // being read as something the Preservation Team has checked.
                AwaitingMaterialNote(
                  message: context.cms(
                    'page.age_grades.self_published_note',
                    fallback:
                        'Posted by the age grade itself. The Ekoli-Yeden Preservation Team has not '
                        'verified this as community history.',
                  ),
                ),
                const Gap.xl(),
                if (post.body != null)
                  SelectableText(post.body!, style: theme.textTheme.bodyLarge)
                else if (post.excerpt != null)
                  SelectableText(post.excerpt!, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({required this.members});

  final List<AgeGradeMember> members;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int columns = context.gridColumns(max: 3);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: members
              .map(
                (AgeGradeMember member) => SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: AppRadius.smAll,
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          member.fullName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            // A grade's record of its own dead is part of what
                            // the grade is for; the roster marks it quietly
                            // rather than hiding it.
                            fontStyle:
                                member.isDeceased ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                        if (member.metaLine != null) ...<Widget>[
                          const Gap.xs(),
                          Text(member.metaLine!, style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}
