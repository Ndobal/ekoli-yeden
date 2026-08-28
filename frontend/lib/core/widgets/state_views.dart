import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../errors/app_exception.dart';
import '../routing/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// The states every data-backed screen can be in.
///
/// The empty state matters more here than in most applications: on the day this
/// launches, almost every section of the archive is empty. It must read as an
/// invitation to contribute, not as a broken page.
class LoadingView extends StatelessWidget {
  const LoadingView({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.huge),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          if (message != null) ...<Widget>[
            const Gap.lg(),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Shown when a section of the archive has nothing in it yet.
class EmptyView extends StatelessWidget {
  const EmptyView({
    this.title = 'Nothing here yet',
    this.message = Placeholders.awaitingMaterial,
    this.icon = Icons.inventory_2_outlined,
    this.showContributeAction = true,
    this.onContribute,
    this.contributeLabel,
    this.contributeIcon,
    this.contributePrompt,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final bool showContributeAction;
  final VoidCallback? onContribute;

  /// What the button says, where "Contribute to the archive" is the wrong
  /// promise.
  ///
  /// The People section is the case that made this necessary: its empty state
  /// used to offer the general contribution form, which takes a title and a
  /// description — and a person is not a title and a description. Sending
  /// somebody there to record their grandmother produced a note in a media
  /// queue instead of a biography.
  final String? contributeLabel;
  final IconData? contributeIcon;

  /// The sentence above the button, where the standard prompt does not fit.
  final String? contributePrompt;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxxl,
        horizontal: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
          const Gap.lg(),
          Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const Gap.sm(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (showContributeAction) ...<Widget>[
            const Gap.xl(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                contributePrompt ?? Placeholders.contributePrompt,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            const Gap.md(),
            FilledButton.icon(
              onPressed: onContribute ?? () => context.go(AppRoutes.contribute),
              icon: Icon(contributeIcon ?? Icons.upload_file_outlined, size: 18),
              label: Text(contributeLabel ?? 'Contribute to the archive'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown when a request failed.
class ErrorView extends StatelessWidget {
  const ErrorView({required this.error, this.onRetry, super.key});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String message = error is AppException
        ? (error as AppException).message
        : 'Something went wrong. Please try again.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
              const Gap.hSm(),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...<Widget>[
            const Gap.lg(),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}

/// A badge for the editorial workflow, used throughout the admin interface.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color color = AppColors.forStatus(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        ContentStatus.label(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Marks an entry that states a fact nobody has confirmed yet.
///
/// This is central to the archive being trustworthy: an unverified account is
/// shown as unverified rather than presented as settled fact.
class VerificationBadge extends StatelessWidget {
  const VerificationBadge(this.verificationStatus, {super.key});

  final String verificationStatus;

  @override
  Widget build(BuildContext context) {
    if (verificationStatus == VerificationStatus.verified) {
      return const _Pill(
        icon: Icons.verified_outlined,
        label: 'Verified',
        color: AppColors.success,
      );
    }
    if (verificationStatus == VerificationStatus.disputed) {
      return const _Pill(
        icon: Icons.report_problem_outlined,
        label: 'Disputed',
        color: AppColors.danger,
      );
    }
    return _Pill(
      icon: Icons.hourglass_empty,
      label: VerificationStatus.label(verificationStatus),
      color: AppColors.warning,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const Gap.hSm(),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// A short note explaining that material has not been supplied yet.
class AwaitingMaterialNote extends StatelessWidget {
  const AwaitingMaterialNote({this.message = Placeholders.awaitingVerification, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: AppRadius.smAll,
        border: const Border(left: BorderSide(color: AppColors.warning, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
          const Gap.hMd(),
          Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
