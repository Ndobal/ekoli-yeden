/// THE TERMS, THE PRIVACY POLICY, AND THE COOKIES PAGE.
///
/// ---------------------------------------------------------------------------
/// THESE DESCRIBE WHAT THIS PLATFORM ACTUALLY DOES
/// ---------------------------------------------------------------------------
///
/// Every claim below is one the code makes true, and most of them can be
/// checked against a specific file. That is the only kind of policy worth
/// publishing: a boilerplate privacy notice that mentions advertising partners
/// this archive does not have would be a lie told in legal language.
///
/// Where the answer is "we do not do that", it says so plainly rather than
/// leaving it out — "we do not sell anything about you, to anybody, ever" is
/// information; silence is not.
///
/// **If you change how the platform works, change these pages in the same
/// commit.** A policy that describes last year's system is worse than none,
/// because people rely on it.
///
/// The names, dates and addresses come from the CMS so the Preservation Team
/// can correct them without a deployment; the substance is here, where it can
/// be reviewed in a diff beside the code that implements it.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/cms_text.dart';
import '../../core/widgets/page_shell.dart';
import '../../core/widgets/seo_head.dart';


/// One heading and its paragraphs.
class _Clause {
  const _Clause(this.title, this.paragraphs, {this.points = const <String>[]});

  final String title;
  final List<String> paragraphs;
  final List<String> points;
}

// ---------------------------------------------------------------------------
// Terms of use
// ---------------------------------------------------------------------------

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const List<_Clause> clauses = <_Clause>[
      _Clause(
        'What this archive is',
        <String>[
          'The Ekoli Yeden Digital Home is a community heritage archive: the recorded history, '
              'language, culture, people, leadership and festivals of Ekoli-Yeden, kept in one '
              'permanent place and open to read.',
          'It is maintained by the Preservation Team on behalf of the community. It is not a '
              'commercial service, it carries no advertising, and nothing on it is for sale.',
        ],
      ),
      _Clause(
        'Reading it costs nothing and asks nothing',
        <String>[
          'You do not need an account to read the archive. Most of it is public on purpose — a '
              'community history behind a sign-in is a history the family abroad cannot show '
              'their children.',
          'Three areas are members-only, and each for a stated reason: the member directory, '
              'because it lists real people; the opportunities board, because it is matched to '
              'you and shows nothing useful otherwise; and two of the three forum spaces, '
              'because they may contain young people.',
        ],
      ),
      _Clause(
        'Your account',
        <String>[
          'You are responsible for what is done through your account and for keeping your '
              'password to yourself. Tell us at once if you think somebody else has it — an '
              'administrator can end every session on your account immediately.',
          'One account per person. An account created to impersonate somebody else, living or '
              'dead, will be removed.',
        ],
      ),
      _Clause(
        'What you contribute stays yours',
        <String>[
          'Sending a photograph, a recording, a word or a story to this archive does not sign '
              'anything away. You keep whatever rights you had in it. What you give us is '
              'permission to keep it here, show it to the community, and preserve it — and you '
              'can withdraw that permission by writing to us.',
          'Please only send material that is yours to send. If a photograph shows somebody '
              'else, think about whether they would want it here; if they later ask us to '
              'remove it, we will.',
          'Who supplied what is recorded separately from the article it belongs to, so an '
              'acknowledgement survives every later edit.',
        ],
      ),
      _Clause(
        'What the archive publishes, and what it will not',
        <String>[
          'Nothing is invented. No history, chief, date, cultural claim or meaning of an Ekoli '
              'word appears here because software produced it. Where the community has not '
              'supplied something, the page says so rather than filling the space with a '
              'plausible guess.',
          'Material from outside sources is labelled with its provenance and marked unverified '
              'until the Preservation Team has checked it.',
          'Everything you send is reviewed before it is published. A submission is a proposal, '
              'never content, and there is no path — on the site or in the API — that publishes '
              'a contribution automatically.',
        ],
      ),
      _Clause(
        'How to behave where the community talks',
        <String>[
          'In the forums, on age grade pages, and anywhere else you can write in public: say '
              'the thing you would say to somebody standing in front of you. Disagree with what '
              'was said rather than with the person who said it.',
          'Do not post anybody else’s phone number, address or photograph without asking them '
              'first. Do not post anything that puts a child at risk — that is acted on '
              'immediately, before anybody reviews it.',
        ],
        points: <String>[
          'A moderator may hide or remove a post, close a conversation, or suspend an account '
              'from posting.',
          'Every such action is recorded with a reason, in a log every moderator can read.',
          'A warning does not stop you posting. A suspension ends on a date you are told.',
          'If you think a decision was wrong, write to us — the log means somebody else can '
              'check it.',
        ],
      ),
      _Clause(
        'Age grades, groups and what they say about themselves',
        <String>[
          'A group’s own page is written by its administrators and published under its name. It '
              'is labelled as the group speaking for itself, which is useful and is not the '
              'same as something the Preservation Team has verified.',
          'A group cannot publish its own page, and cannot mark itself verified.',
        ],
      ),
      _Clause(
        'The opportunities board',
        <String>[
          'Listings are posted by members and reviewed before they appear. Review is not a '
              'guarantee: check anything you are about to act on.',
          'Never pay anybody a fee to apply for a job, a scholarship or a training place '
              'advertised here. If a listing asks you for money, report it — one press, on the '
              'listing — and it will be taken down.',
        ],
      ),
      _Clause(
        'Accuracy, and what we can promise',
        <String>[
          'The archive is offered as it stands. Much of what is here is oral history, and the '
              'community is still collecting it. Where something is unverified, the page says '
              'so, and every claim carried from an outside source names it.',
          'If you find something wrong, tell us. A correction to community history matters more '
              'to this project than almost anything else on this page.',
        ],
      ),
      _Clause(
        'Ending an account',
        <String>[
          'You can ask us to close your account at any time. Your profile is removed and you '
              'come out of the directory.',
          'Material you contributed to the archive is not automatically withdrawn with it — a '
              'photograph of the 1998 festival is part of the community’s record by then. Tell '
              'us if you want something removed as well, and we will.',
          'An account may be suspended for impersonating somebody, for repeated abuse, or for '
              'deliberately putting false history into the archive.',
        ],
      ),
      _Clause(
        'Changes to these terms',
        <String>[
          'When these terms change materially, the date at the top of this page changes with '
              'them, and the change is announced in the news section rather than made quietly.',
        ],
      ),
    ];

    return const _LegalPage(
      path: AppRoutes.terms,
      titleKey: 'page.terms.title',
      titleFallback: 'Terms of Use',
      description:
          'What this archive is, what you can expect of it, and what it asks of you.',
      intro:
          'Plain terms for a community archive. If anything here is unclear, write to us and we '
          'will explain it — and if the explanation is better than the wording, we will change '
          'the wording.',
      clauses: clauses,
    );
  }
}

// ---------------------------------------------------------------------------
// Privacy
// ---------------------------------------------------------------------------

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    const List<_Clause> clauses = <_Clause>[
      _Clause(
        'The short version',
        <String>[],
        points: <String>[
          'We do not sell anything about you, to anybody, ever.',
          'There is no advertising here, and no advertising or analytics tracker.',
          'Your phone number and email are hidden unless you turn them on yourself.',
          'You are not in the member directory unless you choose to be.',
          'The platform never labels anybody unemployed, anywhere, to anyone.',
          'Your birth year is never shown to anybody but you.',
          'You can ask what we hold about you, and ask us to remove it, without an account.',
        ],
      ),
      _Clause(
        'Who holds this',
        <String>[
          'The archive and its data are held by the Preservation Team of Ekoli-Yeden, who decide '
              'what is published and who answer requests about personal information. Write to '
              'the address at the bottom of this page, or use the contact form.',
        ],
      ),
      _Clause(
        'What we collect, and why',
        <String>[],
        points: <String>[
          'When you read the archive: nothing that identifies you. No account, no tracker, no '
              'profile built from what you looked at.',
          'When you create an account: your name, your email address, and your password — kept '
              'only as a salted PBKDF2 hash, never in a form anybody could read.',
          'When you become a Yakoli member: whatever you choose to fill in — where you are, what '
              'you do, your skills, your interests, where in Ekori you are from. All of it is '
              'optional, and each part has its own visibility setting.',
          'When you contribute: the material itself, your name if you gave one, and how to reach '
              'you so the reviewer can ask a question.',
          'When you write to us: what you wrote and how you asked us to reply.',
          'When something is protected or reported: a salted digest of the IP address — enough '
              'to recognise a flood from one source, and not a log of who visited.',
        ],
      ),
      _Clause(
        'What we do with it',
        <String>[
          'We use it to run the archive and nothing else: to sign you in, to show you what you '
              'asked to see, to match opportunities to the skills you recorded, to let the '
              'community find each other, and to answer you when you write.',
          'We do not sell it, rent it, or hand it to anybody for marketing. There is no '
              'advertising network on this site, so there is nothing to hand it to.',
        ],
      ),
      _Clause(
        'Who can see what',
        <String>[
          'Every visibility setting defaults to the private option, and you change them from '
              'Account → Privacy. Turning something off takes effect immediately.',
          'The rules are enforced by the server on every request, not by hiding things in the '
              'page — a profile you have set to private is not sent to anybody who asks for it.',
        ],
        points: <String>[
          'Your profile: private, members-only, or public. You choose.',
          'Your contact details: hidden unless you switch them on.',
          'The directory: you appear only if you opt in.',
          'In a youth forum space, a post shows a name and nothing else — no handle, no '
              'location, no contact.',
        ],
      ),
      _Clause(
        'Children and young people',
        <String>[
          'Two of the three forum spaces may include young people, and are treated accordingly: '
              'they are never readable by somebody who is not signed in, they are kept out of '
              'search engines, and an author card there carries a name only.',
          'Anything reported as putting a child at risk is hidden the moment it is reported, '
              'before a moderator reviews it.',
          'If you are a parent or guardian and want something about your child removed, write to '
              'us and it will be taken down.',
        ],
      ),
      _Clause(
        'Where it is kept, and for how long',
        <String>[
          'Records are held in Cloudflare D1 and files in Cloudflare R2, reached only through '
              'this platform’s own API. Videos are hosted on YouTube; the archive keeps the '
              'catalogue record rather than the file.',
          'Contributed material is kept for as long as the archive exists, because that is what '
              'an archive is for — unless you ask us to remove it. Account data is kept while '
              'the account exists.',
          'The audit log is append-only and is not deleted: an archive that can be silently '
              'rewritten is not an archive.',
        ],
      ),
      _Clause(
        'What you can ask for',
        <String>[
          'Write to us and we will answer. You do not need an account to ask, and you do not '
              'need to explain why — somebody asking for their own material to be removed should '
              'not first have to create a record of themselves to do it.',
        ],
        points: <String>[
          'A copy of what we hold about you.',
          'A correction to anything wrong.',
          'Removal of a photograph, a name, or anything else about you.',
          'Closure of your account.',
          'An explanation of a moderation decision that affected you.',
        ],
      ),
      _Clause(
        'How your account is protected',
        <String>[],
        points: <String>[
          'Passwords are PBKDF2-HMAC-SHA256 with a per-user salt, at the maximum iteration count '
              'the platform’s runtime allows.',
          'Sessions store only a digest of the refresh token, so a copy of the database cannot '
              'be replayed as somebody’s session.',
          'Changing your password, or suspending an account, ends every session on it at once.',
          'A reset link is single-use and expires. An administrator who generates one for you '
              'never learns your password.',
        ],
      ),
      _Clause(
        'When something goes wrong',
        <String>[
          'If personal information here is ever exposed, we will say so — to the people affected '
              'and to the community — rather than hoping nobody notices.',
        ],
      ),
    ];

    return const _LegalPage(
      path: AppRoutes.privacy,
      titleKey: 'page.privacy.title',
      titleFallback: 'Privacy Policy',
      description:
          'What this archive collects, what it does with it, and what you can ask for. No '
          'advertising, no trackers, nothing sold.',
      intro:
          'This describes what the platform actually does. Every claim here is one the code '
          'makes true, and where the answer is "we do not do that", it says so.',
      clauses: clauses,
    );
  }
}

// ---------------------------------------------------------------------------
// Cookies
// ---------------------------------------------------------------------------

class CookiesPage extends StatelessWidget {
  const CookiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    const List<_Clause> clauses = <_Clause>[
      _Clause(
        'There is no cookie banner here, and that is not an oversight',
        <String>[
          'A banner is required where a site stores things on your device that it does not need '
              'in order to work — advertising and analytics cookies, mostly. This site stores '
              'nothing of that kind, so there is nothing to ask you to consent to.',
          'What it does store is listed below, in full.',
        ],
      ),
      _Clause(
        'What is stored on your device',
        <String>[],
        points: <String>[
          'Your session, once you sign in: an access token and a refresh token, kept in your '
              'browser’s local storage so you are not asked to sign in again on every page. '
              'Signing out removes them.',
          'Nothing at all if you never sign in. Reading the archive stores nothing.',
        ],
      ),
      _Clause(
        'What is not stored',
        <String>[],
        points: <String>[
          'No advertising cookie. There is no advertising on this site.',
          'No analytics or tracking cookie. Nobody here is building a picture of what you read.',
          'No third-party tracker of any kind on the pages of the archive.',
        ],
      ),
      _Clause(
        'The one exception, and it is worth knowing about',
        <String>[
          'Videos are hosted on YouTube rather than stored here, which keeps the archive’s costs '
              'proportional to photographs and audio. A page with a video on it loads that video '
              'from YouTube, and YouTube may then set cookies of its own — the archive uses the '
              'no-cookie player host to limit that, but it is Google’s player and Google’s '
              'rules apply to it.',
          'A page with no video on it contacts YouTube not at all.',
        ],
      ),
      _Clause(
        'Turning it off',
        <String>[
          'Your browser can clear or block site storage at any time. The only thing you lose is '
              'staying signed in; everything public will still load.',
        ],
      ),
    ];

    return const _LegalPage(
      path: AppRoutes.cookies,
      titleKey: 'page.cookies.title',
      titleFallback: 'Cookies',
      description:
          'What this site stores on your device — a sign-in session, and nothing else. No '
          'advertising or analytics cookies.',
      intro: 'The whole list, which is short.',
      clauses: clauses,
    );
  }
}

// ---------------------------------------------------------------------------
// The shared frame
// ---------------------------------------------------------------------------

/// One policy page.
///
/// Rendered at the reading measure with generous spacing between clauses. A
/// policy that is technically present but unreadable is a policy nobody reads,
/// and this project's whole argument is that people should be able to check
/// what it does.
class _LegalPage extends StatelessWidget {
  const _LegalPage({
    required this.path,
    required this.titleKey,
    required this.titleFallback,
    required this.description,
    required this.intro,
    required this.clauses,
  });

  final String path;
  final String titleKey;
  final String titleFallback;
  final String description;
  final String intro;
  final List<_Clause> clauses;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String effective = context.cmsWatch(
      'policy.effective_date',
      fallback: '28 August 2026',
    );

    return AppScaffold(
      currentPath: path,
      seo: SeoMetadata(title: titleFallback, description: description, canonicalPath: path),
      child: PageSection(
        reading: true,
        eyebrow: 'The small print, in plain words',
        title: context.cmsWatch(titleKey, fallback: titleFallback),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              intro,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap.md(),
            Text(
              'In effect from $effective.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap.xxl(),
            ...clauses.map((_Clause clause) => _ClauseBlock(clause: clause)),
            const Gap.xl(),
            const _PolicyFooter(),
          ],
        ),
      ),
    );
  }
}

class _ClauseBlock extends StatelessWidget {
  const _ClauseBlock({required this.clause});

  final _Clause clause;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SelectableText(clause.title, style: theme.textTheme.titleLarge),
          const Gap.md(),
          ...clause.paragraphs.map(
            (String paragraph) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: SelectableText(paragraph, style: theme.textTheme.bodyLarge),
            ),
          ),
          if (clause.points.isNotEmpty) ...<Widget>[
            if (clause.paragraphs.isNotEmpty) const Gap.xs(),
            ...clause.points.map(
              (String point) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: AppSpacing.md),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SelectableText(point, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Who to write to, on every policy page, where somebody has just finished
/// reading a paragraph that made them want to.
class _PolicyFooter extends StatelessWidget {
  const _PolicyFooter();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String custodian = context.cmsWatch(
      'policy.custodian',
      fallback: 'The Ekoli-Yeden Preservation Team',
    );
    final String email = context.cmsWatch(
      'policy.contact_email',
      fallback: 'privacy@ekoliyeden.org',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Asking us something about this', style: theme.textTheme.titleMedium),
          const Gap.sm(),
          Text(
            'Write to $custodian. Use the contact form — it reaches every administrator rather '
            'than one inbox, and gives you a reference you can quote — or email $email.',
            style: theme.textTheme.bodyMedium,
          ),
          const Gap.lg(),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.contact),
                icon: const Icon(Icons.mail_outline, size: 18),
                label: const Text('Write to us'),
              ),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.terms),
                child: const Text('Terms'),
              ),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.privacy),
                child: const Text('Privacy'),
              ),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.cookies),
                child: const Text('Cookies'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
