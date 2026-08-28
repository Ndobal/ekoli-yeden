import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/cms_text.dart';
import '../../core/widgets/page_shell.dart';
import '../../models/ancestry.dart';
import '../../repositories/remembrance_repository.dart';

/// "SOMEBODY HAS REPORTED THAT YOU HAVE DIED."
///
/// ---------------------------------------------------------------------------
/// THIS IS THE MOST IMPORTANT NOTICE ON THE PLATFORM
/// ---------------------------------------------------------------------------
///
/// Everything in the remembrance flow is built so that a living person wrongly
/// reported can undo it themselves. That guarantee is only real if they are
/// told — so this sits above everything else on the account page, is never
/// dismissible, and its button restores the account immediately: no review, no
/// deadline, no form to fill in first.
///
/// Wrongly restoring a genuinely deceased account for a day costs nothing. A
/// living person unable to undo this costs a great deal more.
///
/// It renders nothing at all for everybody else, which is almost everybody, so
/// it is safe to place unconditionally.
class MemorialNoticeBanner extends StatefulWidget {
  const MemorialNoticeBanner({super.key});

  @override
  State<MemorialNoticeBanner> createState() => _MemorialNoticeBannerState();
}

class _MemorialNoticeBannerState extends State<MemorialNoticeBanner> {
  late Future<MemorialNotice?> _notice;
  bool _busy = false;
  String? _restored;

  @override
  void initState() {
    super.initState();
    _notice = _load();
  }

  /// A failure here renders nothing rather than an error.
  ///
  /// This banner is an addition to the account page, not the page itself: an
  /// unreachable endpoint must not take the whole account down with it.
  Future<MemorialNotice?> _load() async {
    try {
      return await context.read<RemembranceRepository>().notice();
    } on AppException {
      return null;
    }
  }

  Future<void> _contest() async {
    setState(() => _busy = true);
    try {
      final String message = await context.read<RemembranceRepository>().contest();
      if (mounted) {
        setState(() {
          _restored = message;
          _notice = Future<MemorialNotice?>.value();
        });
      }
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (_restored != null) {
      return _Band(
        colour: theme.colorScheme.primary,
        child: Row(
          children: <Widget>[
            Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
            const Gap.hLg(),
            Expanded(child: Text(_restored!, style: theme.textTheme.bodyLarge)),
          ],
        ),
      );
    }

    return FutureBuilder<MemorialNotice?>(
      future: _notice,
      builder: (BuildContext context, AsyncSnapshot<MemorialNotice?> snapshot) {
        final MemorialNotice? notice = snapshot.data;
        if (notice == null) return const SizedBox.shrink();

        return _Band(
          colour: theme.colorScheme.error,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.report_outlined, color: theme.colorScheme.error),
                  const Gap.hMd(),
                  Expanded(
                    child: Text(
                      notice.isMemorialised
                          ? 'This account has been recorded as belonging to somebody who has died'
                          : 'Somebody has reported that the holder of this account has died',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const Gap.lg(),
              CmsText(
                'page.memorial.contest_note',
                fallback:
                    'This account has been recorded as belonging to somebody who has died. If '
                    'that is wrong, press the button below and the Preservation Team will be '
                    'told at once. Nothing has been deleted.',
                style: theme.textTheme.bodyMedium,
              ),
              const Gap.md(),
              Text(
                notice.canWrite
                    ? 'Nothing has changed yet. You can still use the site as normal.'
                    : 'Your account is read-only for now. You can still sign in, still read '
                          'everything, and still press the button below — nothing has been '
                          'deleted and nothing is permanent.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (notice.reportedAt != null) ...<Widget>[
                const Gap.sm(),
                Text(
                  'Reported ${Formatters.relative(notice.reportedAt)}.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const Gap.lg(),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: _busy ? null : _contest,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.undo, size: 18),
                    label: const Text('This is wrong — I am here'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                  ),
                  Text(
                    'This restores your account straight away.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({required this.colour, required this.child});

  final Color colour;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: colour.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: ContentContainer(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: colour.withValues(alpha: 0.5), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}
