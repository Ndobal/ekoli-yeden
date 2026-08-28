import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
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
import '../../repositories/kinship_repository.dart';
import '../../services/auth/auth_controller.dart';

/// BIRTHDAYS.
///
/// Whose birthday it is among the people you know, and every wish you have ever
/// been sent, kept by year.
///
/// TWO THINGS THIS DOES THAT A NOTIFICATION SYSTEM WOULD NOT.
///
/// It asks ONCE. "Not now" means not now — the card does not reappear on the
/// next page load. A prompt that nags gets dismissed unread, which defeats it.
///
/// It keeps the wishes BY YEAR. The question a member actually asks, years
/// later, is "what did people say to me in 2027?" — and a feed cannot answer
/// that. Each year is its own page and the earlier ones do not scroll away.
class BirthdaysPage extends StatefulWidget {
  const BirthdaysPage({super.key});

  @override
  State<BirthdaysPage> createState() => _BirthdaysPageState();
}

class _BirthdaysPageState extends State<BirthdaysPage> {
  int _reloads = 0;
  int? _year;

  @override
  Widget build(BuildContext context) {
    final KinshipRepository repository = context.read<KinshipRepository>();
    final AuthController auth = context.watch<AuthController>();
    final String? handle = auth.user?.handle;

    return AppScaffold(
      currentPath: AppRoutes.account,
      seo: const SeoMetadata(
        title: 'Birthdays',
        description: 'Birthdays in your community, and the wishes you have received.',
        canonicalPath: AppRoutes.accountBirthdays,
        noIndex: true,
      ),
      child: PageSection(
        reading: true,
        eyebrow: 'Your account',
        title: 'Birthdays',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.account),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back to your dashboard'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
            const Gap.lg(),

            // Today first: it is the only part of this page that is time-bound.
            AsyncContent<({List<BirthdayCard> prompts, Map<String, dynamic>? own})>(
              key: ValueKey<int>(_reloads),
              load: repository.birthdaysToday,
              isEmpty: (({List<BirthdayCard> prompts, Map<String, dynamic>? own}) d) =>
                  d.prompts.isEmpty && d.own == null,
              emptyBuilder: (BuildContext context) => Text(
                'No birthdays today among the people you know.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              builder: (
                BuildContext context,
                ({List<BirthdayCard> prompts, Map<String, dynamic>? own}) data,
              ) {
                final ThemeData theme = Theme.of(context);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (data.own != null) ...<Widget>[
                      _OwnBirthday(own: data.own!),
                      const Gap.xl(),
                    ],
                    if (data.prompts.isNotEmpty) ...<Widget>[
                      Text('Today', style: theme.textTheme.titleMedium),
                      const Gap.md(),
                      ...data.prompts.map(
                        (BirthdayCard card) => _BirthdayPrompt(
                          card: card,
                          onAnswered: () => setState(() => _reloads += 1),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),

            const Gap.xxl(),
            Text('Wishes you have received', style: Theme.of(context).textTheme.titleMedium),
            const Gap.md(),
            if (handle == null)
              Text(
                'Complete your membership and your birthday chart starts here.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              AsyncContent<BirthdayChart>(
                key: ValueKey<String>('chart:${_year ?? 0}'),
                load: () => repository.chart(handle, year: _year),
                isEmpty: (BirthdayChart c) => c.wishes.isEmpty && c.years.isEmpty,
                emptyBuilder: (BuildContext context) => const EmptyView(
                  icon: Icons.cake_outlined,
                  title: 'Nothing yet',
                  message:
                      'When people wish you a happy birthday, every message is kept here — one '
                      'page for each year, so you can look back at any of them.',
                ),
                builder: (BuildContext context, BirthdayChart chart) => _Chart(
                  chart: chart,
                  onYear: (int year) => setState(() => _year = year),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OwnBirthday extends StatelessWidget {
  const _OwnBirthday({required this.own});

  final Map<String, dynamic> own;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.cake_outlined, size: 22),
              const Gap.hMd(),
              Text('Today is your birthday', style: theme.textTheme.titleMedium),
            ],
          ),
          const Gap.md(),
          // What the platform itself says. Held as a CMS string, so the words
          // belong to the community rather than to this file.
          Text(
            own['greeting']?.toString() ??
                'Happy birthday from all of us at Ekoli-Yeden.',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// One card: their picture, their name, and two answers.
class _BirthdayPrompt extends StatefulWidget {
  const _BirthdayPrompt({required this.card, required this.onAnswered});

  final BirthdayCard card;
  final VoidCallback onAnswered;

  @override
  State<_BirthdayPrompt> createState() => _BirthdayPromptState();
}

class _BirthdayPromptState extends State<_BirthdayPrompt> {
  final TextEditingController _message = TextEditingController();
  bool _writing = false;
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BirthdayCard card = widget.card;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
            children: <Widget>[
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.green.withValues(alpha: 0.15),
                backgroundImage:
                    card.avatarUrl == null ? null : NetworkImage(card.avatarUrl!),
                child: card.avatarUrl != null
                    ? null
                    : const Icon(Icons.person_outline, size: 24),
              ),
              const Gap.hLg(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Congratulations ${card.name}, on your birthday!',
                      style: theme.textTheme.titleSmall,
                    ),
                    if (card.headline != null)
                      Text(card.headline!, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ],
          ),
          const Gap.lg(),
          if (_writing) ...<Widget>[
            TextField(
              controller: _message,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Your message',
                alignLabelWithHint: true,
                helperText: 'It is kept in their birthday chart for this year.',
              ),
            ),
            const Gap.md(),
            Row(
              children: <Widget>[
                FilledButton(
                  onPressed: _busy ? null : _send,
                  child: const Text('Send it'),
                ),
                const Gap.hMd(),
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _writing = false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ] else
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: card.wishesEnabled
                      ? () => setState(() => _writing = true)
                      : null,
                  icon: const Icon(Icons.cake_outlined, size: 18),
                  label: const Text('Wish birthday'),
                ),
                const Gap.hMd(),
                // "Not now" means not now. Recorded, so the card does not come
                // back on the next page load.
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          final KinshipRepository repository =
                              context.read<KinshipRepository>();
                          setState(() => _busy = true);
                          await repository.skip(card.userId);
                          widget.onAnswered();
                        },
                  child: const Text('Not now'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    if (_message.text.trim().length < 2) return;

    final KinshipRepository repository = context.read<KinshipRepository>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      await repository.wish(widget.card.userId, message: _message.text.trim());
      widget.onAnswered();
    } on AppException catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
        setState(() => _busy = false);
      }
    }
  }
}

/// One year of wishes, with the other years alongside.
class _Chart extends StatelessWidget {
  const _Chart({required this.chart, required this.onYear});

  final BirthdayChart chart;
  final ValueChanged<int> onYear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (chart.years.length > 1) ...<Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            children: chart.years
                .map(
                  (int year) => ChoiceChip(
                    selected: year == chart.year,
                    label: Text('$year'),
                    onSelected: (bool _) => onYear(year),
                  ),
                )
                .toList(growable: false),
          ),
          const Gap.lg(),
        ],
        if (chart.wishes.isEmpty)
          Text(
            'Nothing in ${chart.year}.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...chart.wishes.map(
            (BirthdayWish wish) => Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: AppRadius.mdAll,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(wish.message, style: theme.textTheme.bodyLarge),
                  const Gap.sm(),
                  Text(
                    <String?>[
                      wish.senderName,
                      wish.createdAt == null ? null : Formatters.date(wish.createdAt),
                    ].whereType<String>().join(' · '),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
