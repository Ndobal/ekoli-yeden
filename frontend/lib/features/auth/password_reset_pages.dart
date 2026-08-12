import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../repositories/account_repository.dart';
import 'auth_pages.dart';

/// FORGOT PASSWORD.
///
/// The response is deliberately identical whether or not the address is
/// registered. An archive of a community must not double as a way of finding
/// out who belongs to it, and a "no such account" message would do exactly that.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  bool _busy = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String message =
          await context.read<AccountRepository>().forgotPassword(_email.text.trim());
      if (mounted) setState(() => _message = message);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (_message != null) {
      return AuthShell(
        title: 'Check your messages',
        subtitle: 'If we have an account for that address, a link is on its way.',
        seoTitle: 'Password reset requested',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Icon(Icons.mark_email_read_outlined, size: 40, color: AppColors.green),
            const Gap.lg(),
            Text(_message!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const Gap.lg(),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: AppRadius.smAll,
              ),
              child: Text(
                'The link works once and expires after an hour. If nothing arrives, ask a '
                'Super Admin — they can generate a link and pass it to you directly.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const Gap.xl(),
            FilledButton(
              onPressed: () => context.go(AppRoutes.signIn),
              child: const Text('Back to sign in'),
            ),
          ],
        ),
      );
    }

    return AuthShell(
      title: 'Reset your password',
      subtitle: 'We will send a link to the address on your account.',
      seoTitle: 'Reset your password',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Email address'),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) return 'Enter your email address.';
                return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(value.trim())
                    ? null
                    : 'That does not look like an email address.';
              },
            ),
            if (_error != null) ...<Widget>[
              const Gap.lg(),
              AuthErrorNote(message: _error!),
            ],
            const Gap.xl(),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send reset link'),
            ),
            const Gap.lg(),
            TextButton(
              onPressed: () => context.go(AppRoutes.signIn),
              child: const Text('Back to sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

/// SET A NEW PASSWORD.
///
/// Reached from the link. The token is checked before the form is shown, so
/// somebody with an expired link is told immediately rather than after typing
/// a password twice.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({required this.token, super.key});

  final String? token;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _checking = true;
  bool _valid = false;
  String _checkMessage = '';
  bool _busy = false;
  bool _done = false;
  String? _error;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final String? token = widget.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _checking = false;
        _valid = false;
        _checkMessage = 'This link is missing its reset code. Please request a new one.';
      });
      return;
    }
    try {
      final ({bool valid, String message}) result =
          await context.read<AccountRepository>().checkResetToken(token);
      if (mounted) {
        setState(() {
          _checking = false;
          _valid = result.valid;
          _checkMessage = result.message;
        });
      }
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _checking = false;
          _valid = false;
          _checkMessage = error.message;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AccountRepository>().resetPassword(
            token: widget.token!,
            password: _password.text,
          );
      if (mounted) setState(() => _done = true);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (_checking) {
      return const AuthShell(
        title: 'Checking your link',
        subtitle: 'One moment.',
        seoTitle: 'Reset password',
        child: Center(child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(),
        )),
      );
    }

    if (_done) {
      return AuthShell(
        title: 'Password changed',
        subtitle: 'You have been signed out everywhere else.',
        seoTitle: 'Password changed',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Icon(Icons.check_circle_outline, size: 40, color: AppColors.green),
            const Gap.lg(),
            Text(
              'Your new password is set. For safety, every other session was ended — sign in '
              'again to continue.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const Gap.xl(),
            FilledButton(
              onPressed: () => context.go(AppRoutes.signIn),
              child: const Text('Sign in'),
            ),
          ],
        ),
      );
    }

    if (!_valid) {
      return AuthShell(
        title: 'This link cannot be used',
        subtitle: 'Reset links work once, and expire after an hour.',
        seoTitle: 'Reset link expired',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Icon(Icons.link_off, size: 40, color: AppColors.warning),
            const Gap.lg(),
            Text(_checkMessage, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const Gap.xl(),
            FilledButton(
              onPressed: () => context.go(AppRoutes.forgotPassword),
              child: const Text('Request a new link'),
            ),
          ],
        ),
      );
    }

    return AuthShell(
      title: 'Choose a new password',
      subtitle: 'Something you will remember, and nobody else would guess.',
      seoTitle: 'Choose a new password',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'New password',
                helperText: 'At least 12 characters. A short phrase works well.',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (String? value) =>
                  (value == null || value.length < 12) ? 'Please use at least 12 characters.' : null,
            ),
            const Gap.lg(),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Confirm new password'),
              validator: (String? value) =>
                  value != _password.text ? 'The two passwords do not match.' : null,
            ),
            if (_error != null) ...<Widget>[
              const Gap.lg(),
              AuthErrorNote(message: _error!),
            ],
            const Gap.xl(),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Set new password'),
            ),
          ],
        ),
      ),
    );
  }
}
