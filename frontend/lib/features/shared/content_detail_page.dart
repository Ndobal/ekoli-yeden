import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/service_locator.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/async_content.dart';
import '../../core/widgets/cms_text.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../core/widgets/state_views.dart';
import '../../models/content_record.dart';
import '../../repositories/cms_repository.dart';

/// The detail page for any archive record.
///
/// Beyond the article itself, this renders the three things that make the
/// archive answerable rather than merely readable:
///
///   • whether the Preservation Team has verified it,
///   • where its claims came from, and
///   • who supplied the material.
///
/// A history page without those is just a blog post with older subject matter.
class ContentDetailPage extends StatelessWidget {
  const ContentDetailPage({
    required this.resource,
    required this.identifier,
    required this.basePath,
    required this.sectionTitle,
    this.detailFields = const <DetailField>[],
    this.showVerification = false,
    this.showSource = false,
    this.showSources = false,
    this.showContributors = false,
    super.key,
  });

  final String resource;
  final String identifier;
  final String basePath;
  final String sectionTitle;

  /// Extra fields shown as a labelled list beneath the body.
  final List<DetailField> detailFields;

  final bool showVerification;

  /// The free-text `source_reference` column.
  final bool showSource;

  /// The structured citation list from the sources table.
  final bool showSources;

  /// Contributor acknowledgement.
  final bool showContributors;

  @override
  Widget build(BuildContext context) {
    return AsyncContent<ContentRecord>(
      key: ValueKey<String>('$resource:$identifier'),
      load: () => context.contentRepository(resource).find(identifier),
      loadingMessage: 'Opening the record…',
      builder: (BuildContext context, ContentRecord record) => _Detail(
        record: record,
        resource: resource,
        basePath: basePath,
        sectionTitle: sectionTitle,
        detailFields: detailFields,
        showVerification: showVerification,
        showSource: showSource,
        showSources: showSources,
        showContributors: showContributors,
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.record,
    required this.resource,
    required this.basePath,
    required this.sectionTitle,
    required this.detailFields,
    required this.showVerification,
    required this.showSource,
    required this.showSources,
    required this.showContributors,
  });

  final ContentRecord record;
  final String resource;
  final String basePath;
  final String sectionTitle;
  final List<DetailField> detailFields;
  final bool showVerification;
  final bool showSource;
  final bool showSources;
  final bool showContributors;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isResearchEdition = record.flag('research_edition');

    return AppScaffold(
      currentPath: basePath,
      seo: SeoMetadata(
        title: record.displayTitle,
        description: record.summary,
        canonicalPath: '$basePath/${record.pathSegment}',
        type: 'article',
        publishedAt: record.createdAt,
      ),
      child: PageSection(
        reading: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextButton.icon(
              onPressed: () => context.go(basePath),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text('Back to $sectionTitle'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
            const Gap.lg(),

            if (record.category != null) ...<Widget>[
              Text(
                record.category!.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(color: AppColors.gold),
              ),
              const Gap.sm(),
            ],

            Text(record.displayTitle, style: theme.textTheme.displaySmall),

            if (record.summary != null) ...<Widget>[
              const Gap.lg(),
              Text(
                record.summary!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            // The Initial Research Edition notice. This is the difference
            // between "here is our history" and "here is what published sources
            // say, which nobody local has yet confirmed".
            if (isResearchEdition) ...<Widget>[
              const Gap.xl(),
              const ResearchEditionNotice(),
            ] else if (showVerification && record.verificationStatus != null) ...<Widget>[
              const Gap.xl(),
              VerificationBadge(record.verificationStatus!),
              if (record.needsVerification) ...<Widget>[
                const Gap.md(),
                const AwaitingMaterialNote(
                  message:
                      'This entry has not yet been verified by the Ekoli-Yeden Preservation Team. '
                      'If you can confirm or correct it, please get in touch through the '
                      'contribution page.',
                ),
              ],
            ],

            const Gap.xxl(),

            if (record.body != null && record.body!.trim().isNotEmpty)
              SelectableText(record.body!, style: theme.textTheme.bodyLarge)
            else
              const AwaitingMaterialNote(
                message:
                    'The full account for this entry has not been supplied yet. If you hold '
                    'information, documents or photographs about it, the archive would welcome them.',
              ),

            if (detailFields.isNotEmpty) ...<Widget>[
              const Gap.xxl(),
              _DetailFieldList(record: record, fields: detailFields),
            ],

            if (showContributors) ...<Widget>[
              const Gap.xxl(),
              ContributorAcknowledgement(resourceType: resource, resourceId: record.id),
            ],

            if (showSources) ...<Widget>[
              const Gap.xxl(),
              SourcesAndReferences(resourceType: resource, resourceId: record.id),
            ],

            if (showSource && !showSources) ...<Widget>[
              const Gap.xxl(),
              Divider(color: theme.colorScheme.outlineVariant),
              const Gap.lg(),
              Text('Source', style: theme.textTheme.titleSmall),
              const Gap.xs(),
              Text(
                record.text('source_reference') ?? Placeholders.notYetSupplied,
                style: theme.textTheme.bodySmall,
              ),
            ],

            const Gap.xxl(),
            _CorrectionInvitation(resource: resource, title: record.displayTitle),

            const Gap.xl(),
            Text(
              'Last updated ${Formatters.date(record.updatedAt, fallback: 'recently')}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// The banner shown above history compiled from unverified secondary sources.
///
/// It exists so the archive is never mistaken for asserting something it has
/// not established. The wording is CMS-editable so the Preservation Team can
/// phrase the caveat in the community's own words.
class ResearchEditionNotice extends StatelessWidget {
  const ResearchEditionNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.09),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.science_outlined, size: 20, color: AppColors.warning),
              const Gap.hSm(),
              CmsText(
                'system.research_edition.label',
                fallback: 'Initial Research Edition',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.goldDark,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const Gap.md(),
          CmsText(
            'system.research_edition.notice',
            fallback:
                'This account has been compiled from secondary web sources as a starting point '
                'for research. It has NOT been verified by the Ekoli-Yeden Preservation Team, and '
                'it should not be treated as settled community history. Every claim below names '
                'the source it came from.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// The citation list beneath an article.
class SourcesAndReferences extends StatelessWidget {
  const SourcesAndReferences({
    required this.resourceType,
    required this.resourceId,
    super.key,
  });

  final String resourceType;
  final String resourceId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return FutureBuilder<List<CitedSource>>(
      future: context.read<CmsRepository>().sourcesFor(resourceType, resourceId),
      builder: (BuildContext context, AsyncSnapshot<List<CitedSource>> snapshot) {
        final List<CitedSource> sources = snapshot.data ?? const <CitedSource>[];
        // A failed or empty lookup simply renders nothing — a missing citation
        // list should not push an error into the middle of an article.
        if (sources.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Divider(color: theme.colorScheme.outlineVariant),
            const Gap.lg(),
            CmsText(
              'system.sources_heading',
              fallback: 'Sources & References',
              style: theme.textTheme.headlineSmall,
            ),
            const Gap.md(),
            ...sources.map((CitedSource source) => _SourceEntry(source: source)),
          ],
        );
      },
    );
  }
}

class _SourceEntry extends StatelessWidget {
  const _SourceEntry({required this.source});

  final CitedSource source;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: AppRadius.smAll,
          border: Border(
            left: BorderSide(
              // A source the archive considers contested is marked as such,
              // rather than listed as though it settled the question.
              color: source.isContested ? AppColors.danger : AppColors.navy,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(source.display, style: theme.textTheme.bodyMedium),
            if (source.url != null) ...<Widget>[
              const Gap.xs(),
              SelectableText(
                source.url!,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.navyLight),
              ),
            ],
            const Gap.sm(),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                _Tag(
                  label: source.reliabilityLabel,
                  color: source.isContested ? AppColors.danger : AppColors.inkMuted,
                ),
                if (source.accessedDate != null)
                  _Tag(
                    label: 'Accessed ${Formatters.shortDate(source.accessedDate)}',
                    color: AppColors.inkMuted,
                  ),
              ],
            ),
            if (source.supports != null) ...<Widget>[
              const Gap.sm(),
              Text('Cited for: ${source.supports}', style: theme.textTheme.bodySmall),
            ],
            if (source.notes != null) ...<Widget>[
              const Gap.sm(),
              Text(
                source.notes!,
                style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

/// "Contributed by …", shown on published material.
///
/// Read from its own table rather than from the article, which is what lets it
/// survive every subsequent edit to the article body.
class ContributorAcknowledgement extends StatelessWidget {
  const ContributorAcknowledgement({
    required this.resourceType,
    required this.resourceId,
    super.key,
  });

  final String resourceType;
  final String resourceId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return FutureBuilder<List<ContributorCredit>>(
      future: context.read<CmsRepository>().contributorsFor(resourceType, resourceId),
      builder: (BuildContext context, AsyncSnapshot<List<ContributorCredit>> snapshot) {
        final List<ContributorCredit> credits = snapshot.data ?? const <ContributorCredit>[];
        if (credits.isEmpty) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.06),
            borderRadius: AppRadius.smAll,
            border: const Border(left: BorderSide(color: AppColors.green, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.favorite_outline, size: 16, color: AppColors.green),
                  const Gap.hSm(),
                  Text(
                    'With thanks to',
                    style: theme.textTheme.labelMedium?.copyWith(color: AppColors.greenDark),
                  ),
                ],
              ),
              const Gap.sm(),
              ...credits.map(
                (ContributorCredit credit) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(credit.credit, style: theme.textTheme.bodyMedium),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Invites a reader who knows better to say so.
class _CorrectionInvitation extends StatelessWidget {
  const _CorrectionInvitation({required this.resource, required this.title});

  final String resource;
  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Do you know more about this?', style: theme.textTheme.titleSmall),
          const Gap.xs(),
          Text(
            'Corrections, documents, photographs and first-hand accounts all improve the archive. '
            'Contributions are reviewed before publication.',
            style: theme.textTheme.bodySmall,
          ),
          const Gap.md(),
          OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.suggestCorrection(resource, title)),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: CmsText(
              'system.suggest_correction',
              fallback: 'Suggest a Correction / Add Historical Evidence',
              style: theme.textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// One labelled field on a detail page.
class DetailField {
  const DetailField({required this.label, required this.key, this.formatter});

  final String label;

  /// Column name in the record.
  final String key;

  /// How to render the raw value. Defaults to showing it as text.
  final String Function(dynamic value)? formatter;
}

class _DetailFieldList extends StatelessWidget {
  const _DetailFieldList({required this.record, required this.fields});

  final ContentRecord record;
  final List<DetailField> fields;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fields.map((DetailField field) {
        final dynamic value = record.raw[field.key];
        // A field the community has not supplied is shown as such rather than
        // hidden — it tells a reader what the archive still needs.
        final String display = value == null || value.toString().trim().isEmpty
            ? Placeholders.notYetSupplied
            : (field.formatter?.call(value) ?? value.toString());
        final bool isMissing = display == Placeholders.notYetSupplied;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 160,
                child: Text(field.label, style: theme.textTheme.titleSmall),
              ),
              const Gap.hMd(),
              Expanded(
                child: Text(
                  display,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isMissing
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                    fontStyle: isMissing ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}
