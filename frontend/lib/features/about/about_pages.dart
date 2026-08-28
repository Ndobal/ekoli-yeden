import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/site_settings_controller.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/cms_text.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';
import '../../repositories/settings_repository.dart';
import 'contact_form.dart';

/// A page banner: title, introduction, and the brand mark.
///
/// Every non-home page opens with one of these, so a visitor always knows where
/// they are. Title and introduction come from the CMS.
class PageBanner extends StatelessWidget {
  const PageBanner({
    required this.titleKey,
    required this.titleFallback,
    this.introKey,
    this.introFallback,
    this.eyebrow,
    this.accent = AppColors.navy,
    super.key,
  });

  final String titleKey;
  final String titleFallback;
  final String? introKey;
  final String? introFallback;
  final String? eyebrow;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[accent, Color.lerp(accent, Colors.black, 0.25) ?? accent],
        ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: context.isMobile ? AppSpacing.xxxl : AppSpacing.huge,
      ),
      child: PageWidthContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (eyebrow != null) ...<Widget>[
              Text(
                eyebrow!.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.goldLight,
                  letterSpacing: 2,
                ),
              ),
              const Gap.md(),
            ],
            CmsText(
              titleKey,
              fallback: titleFallback,
              style: (context.isMobile
                      ? theme.textTheme.displaySmall
                      : theme.textTheme.displayMedium)
                  ?.copyWith(color: Colors.white),
            ),
            if (introKey != null) ...<Widget>[
              const Gap.lg(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppSpacing.maxReadingWidth),
                child: CmsText(
                  introKey!,
                  fallback: introFallback ?? '',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ABOUT.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SiteSettings settings = context.watch<SiteSettingsController>().settings;

    return AppScaffold(
      currentPath: AppRoutes.about,
      seo: const SeoMetadata(
        title: 'About Ekoli-Yeden',
        description:
            'Why the Ekoli Yeden Digital Home exists, how it is built, and how the community can '
            'take part in it.',
        canonicalPath: AppRoutes.about,
      ),
      child: Column(
        children: <Widget>[
          const PageBanner(
            eyebrow: 'About',
            titleKey: 'page.about.title',
            titleFallback: 'About Ekoli-Yeden',
            introKey: 'page.about.intro',
            introFallback:
                'This platform exists because much of what we know about our community lives in '
                'places that were never built to last.',
          ),
          PageSection(
            reading: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CmsText(
                  'page.about.why.title',
                  fallback: 'Why this archive exists',
                  style: theme.textTheme.headlineSmall,
                ),
                const Gap.lg(),
                CmsText(
                  'page.about.why.body',
                  fallback:
                      'A photograph is lost when a phone breaks. A message disappears when a group '
                      'is cleared. Knowledge that is never written down goes with the person who '
                      'held it.\n\nThis archive is the alternative: one permanent place where the '
                      'history, language, culture, people and festivals of ${settings.communityName} '
                      'are collected, checked, labelled and kept.',
                  style: theme.textTheme.bodyLarge,
                ),
                const Gap.xxl(),
                Text('How material gets here', style: theme.textTheme.headlineSmall),
                const Gap.lg(),
                const _WorkflowSteps(),
                const Gap.xxl(),
                CmsText(
                  'page.about.promise.title',
                  fallback: 'What this archive will not do',
                  style: theme.textTheme.headlineSmall,
                ),
                const Gap.lg(),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.06),
                    borderRadius: AppRadius.mdAll,
                    border: const Border(left: BorderSide(color: AppColors.green, width: 4)),
                  ),
                  child: CmsText(
                    'page.about.promise.body',
                    fallback:
                        'It will not invent anything.\n\nNo history, no chief, no leader, no date, '
                        'no cultural claim, no statistic and no meaning of an Ekoli word appears on '
                        'this site because software produced it. Where the community has not yet '
                        'supplied something, the page says so plainly rather than filling the space '
                        'with a plausible guess.',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                const Gap.xxl(),
                Text('Unity · Progress · Development', style: theme.textTheme.headlineSmall),
                const Gap.lg(),
                const BrandPillars(),
                const Gap.md(),
                Text(
                  'The three words carried on the community’s own logo.',
                  style: theme.textTheme.bodySmall,
                ),
                const Gap.xxl(),
                Row(
                  children: <Widget>[
                    const BrandLogo(size: 64),
                    const Gap.hLg(),
                    Expanded(
                      child: Text(
                        settings.tagline,
                        style: theme.textTheme.titleMedium?.copyWith(color: AppColors.navy),
                      ),
                    ),
                  ],
                ),
                const Gap.xxl(),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: <Widget>[
                    FilledButton(
                      onPressed: () => context.go(AppRoutes.contribute),
                      child: const Text('Contribute to the archive'),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go(AppRoutes.preservationTeam),
                      child: const Text('About the Preservation Team'),
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

class _WorkflowSteps extends StatelessWidget {
  const _WorkflowSteps();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    const List<({String title, String body})> steps = <({String title, String body})>[
      (
        title: 'Someone contributes it',
        body: 'A photograph, a document, a story, a recording, or a correction to something '
            'already published. No account is needed.'
      ),
      (
        title: 'It waits for review',
        body: 'The contribution is recorded and given a reference code. It does not appear on the '
            'website at this stage.'
      ),
      (
        title: 'The Preservation Team checks it',
        body: 'Historical claims, leadership records and language entries are verified before they '
            'are treated as fact.'
      ),
      (
        title: 'An editor prepares it',
        body: 'It is written up, labelled, dated where possible, and its sources are recorded.'
      ),
      (
        title: 'It is published',
        body: 'It becomes part of the archive, with the contributor credited — and that credit '
            'stays, however many times the article is later edited.'
      ),
    ];

    return Column(
      children: List<Widget>.generate(steps.length, (int index) {
        final ({String title, String body}) step = steps[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const Gap.hLg(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(step.title, style: theme.textTheme.titleMedium),
                    const Gap.xs(),
                    Text(step.body, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// CONTACT.
class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SiteSettings settings = context.watch<SiteSettingsController>().settings;

    final List<({String label, String? value, IconData icon})> details =
        <({String label, String? value, IconData icon})>[
      (label: 'Email', value: settings.contactEmail, icon: Icons.mail_outline),
      (label: 'Phone', value: settings.contactPhone, icon: Icons.phone_outlined),
      (label: 'Address', value: settings.contactAddress, icon: Icons.place_outlined),
    ];

    final bool anySupplied = details.any((({String label, String? value, IconData icon}) d) => d.value != null);

    return AppScaffold(
      currentPath: AppRoutes.contact,
      seo: const SeoMetadata(
        title: 'Contact',
        description: 'How to reach the people who maintain the Ekoli Yeden Digital Home.',
        canonicalPath: AppRoutes.contact,
      ),
      child: Column(
        children: <Widget>[
          const PageBanner(
            eyebrow: 'Get in touch',
            titleKey: 'page.contact.title',
            titleFallback: 'Contact',
            introKey: 'page.contact.intro',
            introFallback: 'How to reach the people who maintain this archive.',
          ),
          PageSection(
            reading: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (anySupplied)
                  ...details
                      .where((({String label, String? value, IconData icon}) d) => d.value != null)
                      .map(
                        (({String label, String? value, IconData icon}) d) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Icon(d.icon, size: 20, color: AppColors.navy),
                              const Gap.hLg(),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(d.label, style: theme.textTheme.titleSmall),
                                    const Gap.xs(),
                                    SelectableText(d.value!, style: theme.textTheme.bodyLarge),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                else
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: AppRadius.mdAll,
                      border: const Border(left: BorderSide(color: AppColors.warning, width: 4)),
                    ),
                    child: Text(
                      'Official contact details have not been published yet. They will appear here '
                      'once the community has supplied them — nothing has been invented to fill '
                      'this space.\n\n'
                      'In the meantime, you can still send material to the archive through the '
                      'contribution page, and you will be given a reference code to follow it up.',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                const Gap.xxl(),

                // The form comes before the "contribute" button on purpose.
                // Most people arriving here want to say something, not upload
                // a file, and until now the page offered them only an address.
                const ContactForm(),

                const Gap.xxl(),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.contribute),
                      icon: const Icon(Icons.upload_file_outlined, size: 18),
                      label: const Text('Contribute to the archive'),
                    ),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.privacy),
                      child: const Text('How we handle what you send'),
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
