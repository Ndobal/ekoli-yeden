import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/site_settings_controller.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/seo_head.dart';
import '../../repositories/settings_repository.dart';
import '../../services/auth/auth_controller.dart';

/// Sign-in and registration.
///
/// Presented on its own page rather than inside the public shell: somebody
/// arriving here is doing one thing, and the site navigation would only be a
/// distraction.
class SignInPage extends StatefulWidget {
  const SignInPage({this.redirectTo, super.key});

  /// Where to send the user after a successful sign-in.
  final String? redirectTo;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final AuthController auth = context.read<AuthController>();
    final bool success = await auth.signIn(
      email: _email.text.trim(),
      password: _password.text,
    );

    // THIS is what makes the browser offer to remember the account.
    //
    // An `AutofillGroup` collects the fields; the browser only prompts to save
    // once the group is told the credential is finished. Called on success
    // only — asking somebody to save a password that was just rejected is how
    // a wrong password ends up remembered.
    if (success) TextInput.finishAutofillContext();

    if (!success || !mounted) return;

    // Editorial and administrative users land where they work; everybody else
    // returns to wherever they were trying to go.
    final String destination = widget.redirectTo ??
        (auth.canAccessAdmin
            ? AppRoutes.adminDashboard
            : auth.canAccessEditorial
                ? AppRoutes.editorialDashboard
                : AppRoutes.home);
    context.go(destination);
  }

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();

    return AuthShell(
      title: 'Sign in',
      subtitle: 'For members of the Preservation Team, the Editorial Team and administrators.',
      seoTitle: 'Sign in',
      // THE BROWSER'S PASSWORD MANAGER NEEDS THE FIELDS GROUPED.
      //
      // Hints on their own tell the browser what each box is for. What makes it
      // offer to SAVE the pair is an `AutofillGroup` that is then told the
      // credential is complete — see `_signIn`. Without both, Chrome fills a
      // remembered password and never offers to remember a new one, which is
      // why the site appeared to forget accounts.
      child: AutofillGroup(
        child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const <String>[AutofillHints.email, AutofillHints.username],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email address'),
              validator: (String? value) =>
                  (value == null || value.trim().isEmpty) ? 'Enter your email address.' : null,
            ),
            const Gap.lg(),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const <String>[AutofillHints.password],
              onFieldSubmitted: (_) => _signIn(),
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (String? value) =>
                  (value == null || value.isEmpty) ? 'Enter your password.' : null,
            ),
            if (auth.errorMessage != null) ...<Widget>[
              const Gap.lg(),
              AuthErrorNote(message: auth.errorMessage!),
            ],
            const Gap.xl(),
            FilledButton(
              onPressed: auth.isBusy ? null : _signIn,
              child: auth.isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Sign in'),
            ),
            const Gap.lg(),
            TextButton(
              onPressed: () => context.go(AppRoutes.forgotPassword),
              child: const Text('I have forgotten my password'),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.register),
              child: const Text('Create an account'),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Back to the archive'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Registration. Creates a Contributor account and nothing more.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _done = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final bool success = await context.read<AuthController>().register(
          email: _email.text.trim(),
          password: _password.text,
          displayName: _name.text.trim(),
        );

    // Offering to save is most valuable here: somebody who has just invented a
    // password is the person most likely to forget it.
    if (success) TextInput.finishAutofillContext();

    if (success && mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    final ThemeData theme = Theme.of(context);

    if (_done) {
      return AuthShell(
        title: 'Account created',
        subtitle: 'You can now sign in and contribute material for review.',
        seoTitle: 'Account created',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Icon(Icons.check_circle_outline, size: 40, color: AppColors.green),
            const Gap.lg(),
            Text(
              'A new account can submit material to the archive. Publishing rights are granted '
              'separately by an administrator.',
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

    return AuthShell(
      title: 'Create an account',
      subtitle: 'To contribute material to the archive and follow what happens to it.',
      seoTitle: 'Create an account',
      child: AutofillGroup(
        child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _name,
              autofillHints: const <String>[AutofillHints.name],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Your name'),
              validator: (String? value) => (value == null || value.trim().length < 2)
                  ? 'Please enter your name.'
                  : null,
            ),
            const Gap.lg(),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const <String>[AutofillHints.email, AutofillHints.username],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email address'),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) return 'Enter your email address.';
                final bool valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(value.trim());
                return valid ? null : 'That does not look like an email address.';
              },
            ),
            const Gap.lg(),
            TextFormField(
              controller: _password,
              obscureText: true,
              // `newPassword`, not `password`: it tells the browser to OFFER a
              // strong one and to save what is typed, where `password` asks it
              // to fill an existing credential into a form for a new account.
              autofillHints: const <String>[AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _register(),
              decoration: const InputDecoration(
                labelText: 'Password',
                helperText: 'At least six characters. A short phrase works well, and common passwords are refused.',
              ),
              validator: (String? value) => (value == null || value.length < 6)
                  ? 'Please use at least six characters.'
                  : null,
            ),
            if (auth.errorMessage != null) ...<Widget>[
              const Gap.lg(),
              AuthErrorNote(message: auth.errorMessage!),
            ],
            const Gap.xl(),
            FilledButton(
              onPressed: auth.isBusy ? null : _register,
              child: auth.isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create account'),
            ),
            const Gap.lg(),
            TextButton(
              onPressed: () => context.go(AppRoutes.signIn),
              child: const Text('I already have an account'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// The centred card both authentication pages sit in.
class AuthShell extends StatelessWidget {
  const AuthShell({
    required this.title,
    required this.subtitle,
    required this.seoTitle,
    required this.child,
    super.key,
  });

  final String title;
  final String subtitle;
  final String seoTitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SiteSettings settings = context.watch<SiteSettingsController>().settings;

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SeoHead(
        metadata: SeoMetadata(title: seoTitle, canonicalPath: AppRoutes.signIn),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: context.isMobile ? AppSpacing.xxl : AppSpacing.huge,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const BrandLogo(size: 88, onDarkBackground: true),
                  const Gap.lg(),
                  Text(
                    settings.siteName,
                    style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const Gap.xs(),
                  Text(
                    settings.tagline,
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.skyBlue),
                    textAlign: TextAlign.center,
                  ),
                  const Gap.xxl(),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: AppRadius.lgAll,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(title, style: theme.textTheme.headlineSmall),
                        const Gap.xs(),
                        Text(subtitle, style: theme.textTheme.bodySmall),
                        const Gap.xl(),
                        child,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthErrorNote extends StatelessWidget {
  const AuthErrorNote({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
          const Gap.hSm(),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
