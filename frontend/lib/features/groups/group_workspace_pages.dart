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
import '../../models/community_group.dart';
import '../../models/content_status.dart';
import '../../repositories/group_repository.dart';

// ===========================================================================
// Registering a group
// ===========================================================================

/// REGISTERING A GROUP.
///
/// Any member may register the group they belong to, and whoever does becomes
/// its first officer. That is deliberate: the community knows what its groups
/// are and the archive does not, so waiting for an administrator to create them
/// would mean most of them never being recorded.
///
/// It arrives as a draft. A group asserting itself on the archive's public
/// pages is a claim about the community, and the Preservation Team settles
/// those — but the group can fill in its page, its roster and its dues while it
/// waits, so the wait costs nobody anything.
class RegisterGroupPage extends StatefulWidget {
  const RegisterGroupPage({super.key});

  @override
  State<RegisterGroupPage> createState() => _RegisterGroupPageState();
}

class _RegisterGroupPageState extends State<RegisterGroupPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _subtitle = TextEditingController();
  final TextEditingController _motto = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final TextEditingController _formedYear = TextEditingController();
  final TextEditingController _from = TextEditingController();
  final TextEditingController _to = TextEditingController();
  final TextEditingController _contactName = TextEditingController();
  final TextEditingController _contactPhone = TextEditingController();

  String _kind = 'age_grade';
  String _joinPolicy = 'by_age';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _title, _subtitle, _motto, _body, _formedYear, _from, _to, _contactName, _contactPhone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _isAgeGrade => _kind == 'age_grade';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final ({String id, String slug, String message}) result =
          await context.read<GroupRepository>().create(
                kind: _kind,
                title: _title.text.trim(),
                subtitle: _subtitle.text.trim().isEmpty ? null : _subtitle.text.trim(),
                motto: _motto.text.trim().isEmpty ? null : _motto.text.trim(),
                body: _body.text.trim().isEmpty ? null : _body.text.trim(),
                formedYear: int.tryParse(_formedYear.text.trim()),
                birthYearFrom: _isAgeGrade ? int.tryParse(_from.text.trim()) : null,
                birthYearTo: _isAgeGrade ? int.tryParse(_to.text.trim()) : null,
                joinPolicy: _joinPolicy,
                contactName: _contactName.text.trim().isEmpty ? null : _contactName.text.trim(),
                contactPhone: _contactPhone.text.trim().isEmpty ? null : _contactPhone.text.trim(),
              );

      if (!mounted) return;
      context.go(AppRoutes.group(result.slug));
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppScaffold(
      currentPath: AppRoutes.groups,
      seo: const SeoMetadata(
        title: 'Register a group',
        description: 'Register an age grade, cultural group or association of Ekoli-Yeden.',
        canonicalPath: AppRoutes.registerGroup,
      ),
      child: PageSection(
        reading: true,
        eyebrow: 'Community',
        title: 'Register a group',
        description:
            'Age grades, cultural groups, associations and unions. Whoever registers it becomes '
            'its first officer and can add its members, its page and its dues straight away.',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'What kind of group is it?'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: 'age_grade', child: Text('Age grade')),
                  DropdownMenuItem<String>(value: 'cultural_group', child: Text('Cultural group')),
                  DropdownMenuItem<String>(value: 'association', child: Text('Association')),
                  DropdownMenuItem<String>(value: 'union', child: Text('Union')),
                  DropdownMenuItem<String>(value: 'society', child: Text('Society')),
                  DropdownMenuItem<String>(value: 'other', child: Text('Something else')),
                ],
                onChanged: _busy
                    ? null
                    : (String? value) => setState(() {
                          _kind = value ?? _kind;
                          // An age grade decided by anything other than the
                          // years of birth is not an age grade.
                          _joinPolicy = _isAgeGrade ? 'by_age' : 'by_request';
                        }),
              ),
              const Gap.lg(),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Its name'),
                validator: (String? value) =>
                    (value ?? '').trim().isEmpty ? 'Please give the name.' : null,
              ),
              const Gap.lg(),
              TextFormField(
                controller: _subtitle,
                decoration: const InputDecoration(
                  labelText: 'One line about it (optional)',
                  helperText: 'Shown under the name on its card.',
                ),
              ),

              if (_isAgeGrade) ...<Widget>[
                const Gap.xxl(),
                Text('The years it covers', style: theme.textTheme.titleSmall),
                const Gap.xs(),
                Text(
                  'An age grade is defined by when its people were born, and this is what lets the '
                  'archive tell a member which grade is theirs. Without it, nobody can be matched '
                  'to this grade at all.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Gap.md(),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _from,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Born from'),
                        validator: _year,
                      ),
                    ),
                    const Gap.hMd(),
                    Expanded(
                      child: TextFormField(
                        controller: _to,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Born until'),
                        validator: _year,
                      ),
                    ),
                  ],
                ),
              ],

              const Gap.xxl(),
              TextFormField(
                controller: _formedYear,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Year it formed (optional)'),
              ),
              const Gap.lg(),
              DropdownButtonFormField<String>(
                initialValue: _joinPolicy,
                decoration: const InputDecoration(labelText: 'How can people join?'),
                items: <DropdownMenuItem<String>>[
                  if (_isAgeGrade)
                    const DropdownMenuItem<String>(
                      value: 'by_age',
                      child: Text('Anyone born in those years'),
                    ),
                  const DropdownMenuItem<String>(value: 'open', child: Text('Anyone may join')),
                  const DropdownMenuItem<String>(
                    value: 'by_request',
                    child: Text('People ask, and the officers decide'),
                  ),
                  const DropdownMenuItem<String>(
                    value: 'invite',
                    child: Text('By invitation only'),
                  ),
                  const DropdownMenuItem<String>(
                    value: 'closed',
                    child: Text('Not taking anybody at the moment'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (String? value) => setState(() => _joinPolicy = value ?? _joinPolicy),
              ),
              const Gap.lg(),
              TextFormField(
                controller: _motto,
                decoration: const InputDecoration(labelText: 'Its motto (optional)'),
              ),
              const Gap.lg(),
              TextFormField(
                controller: _body,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'About it (optional)',
                  alignLabelWithHint: true,
                  helperText: 'Its history, what it does, what it is known for.',
                ),
              ),
              const Gap.xxl(),
              Text('Who to contact', style: theme.textTheme.titleSmall),
              const Gap.md(),
              TextFormField(
                controller: _contactName,
                decoration: const InputDecoration(labelText: 'Name (optional)'),
              ),
              const Gap.lg(),
              TextFormField(
                controller: _contactPhone,
                decoration: const InputDecoration(labelText: 'Phone (optional)'),
              ),

              if (_error != null) ...<Widget>[
                const Gap.lg(),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                ),
              ],

              const Gap.xxl(),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy ? const Text('Registering…') : const Text('Register this group'),
              ),
              const Gap.md(),
              Text(
                'It is recorded straight away and you become its lead officer. The Preservation '
                'Team publishes its page once they have looked at it — you can fill everything in '
                'while you wait.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _year(String? value) {
    final int? year = int.tryParse((value ?? '').trim());
    if (year == null) return 'Give a year.';
    if (year < 1900 || year > DateTime.now().year) return 'That is not a likely year.';
    return null;
  }
}

// ===========================================================================
// A member's own dues
// ===========================================================================

/// RECORDING A PAYMENT.
///
/// The platform never receives the money. A member sends it to the group's own
/// account the way they already would, and records it here so that they and the
/// treasurer are looking at the same list.
///
/// That is the whole design. Processing payments would mean holding a
/// community's money and being blamed when a transfer failed; a shared ledger
/// solves the problem people actually have, which is that nobody can agree on
/// who has paid.
class GroupDuesPage extends StatefulWidget {
  const GroupDuesPage({required this.slug, super.key});

  final String slug;

  @override
  State<GroupDuesPage> createState() => _GroupDuesPageState();
}

class _GroupDuesPageState extends State<GroupDuesPage> {
  int _reloads = 0;
  String? _notice;

  void _reload([String? notice]) => setState(() {
        _reloads += 1;
        _notice = notice;
      });

  @override
  Widget build(BuildContext context) {
    final GroupRepository repository = context.read<GroupRepository>();

    return AsyncContent<CommunityGroup>(
      key: ValueKey<int>(_reloads),
      load: () => repository.show(widget.slug),
      loadingMessage: 'Opening…',
      builder: (BuildContext context, CommunityGroup group) {
        return AppScaffold(
          currentPath: AppRoutes.groups,
          seo: SeoMetadata(
            title: 'Dues — ${group.title}',
            description: 'Record and review dues for ${group.title}.',
            canonicalPath: AppRoutes.groupDues(group.slug),
            noIndex: true,
          ),
          child: PageSection(
            eyebrow: group.title,
            title: 'Dues',
            description:
                'Send the money to the group\'s account, then record it here. No money passes '
                'through this website — this is a shared record, so you and the treasurer see the '
                'same list.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_notice != null) ...<Widget>[
                  _Banner(message: _notice!),
                  const Gap.lg(),
                ],
                _DeclareDuesForm(group: group, onSaved: _reload),
                const Gap.xxl(),
                Text('What has been recorded', style: Theme.of(context).textTheme.titleMedium),
                const Gap.md(),
                AsyncContent<({List<DuesPayment> items, List<Map<String, dynamic>> summary})>(
                  key: ValueKey<int>(_reloads),
                  load: () => repository.dues(group.id),
                  isEmpty: (({List<DuesPayment> items, List<Map<String, dynamic>> summary}) d) =>
                      d.items.isEmpty,
                  emptyBuilder: (BuildContext context) => const EmptyView(
                    icon: Icons.receipt_long_outlined,
                    title: 'Nothing recorded yet',
                    message: 'Once you record a payment it appears here, with whether the '
                        'treasurer has confirmed it.',
                  ),
                  builder: (
                    BuildContext context,
                    ({List<DuesPayment> items, List<Map<String, dynamic>> summary}) data,
                  ) =>
                      Column(
                    children: data.items
                        .map((DuesPayment payment) => _PaymentRow(payment: payment))
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DeclareDuesForm extends StatefulWidget {
  const _DeclareDuesForm({required this.group, required this.onSaved});

  final CommunityGroup group;
  final void Function([String? notice]) onSaved;

  @override
  State<_DeclareDuesForm> createState() => _DeclareDuesFormState();
}

class _DeclareDuesFormState extends State<_DeclareDuesForm> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _period = TextEditingController();
  final TextEditingController _reference = TextEditingController();
  DateTime? _paidOn;
  String _method = 'bank_transfer';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-filled with what the group asks for, because that is what somebody
    // paying their dues has almost always just sent.
    if (widget.group.hasDues) {
      _amount.text = widget.group.duesAmount!.round().toString();
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _period.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final double? amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please give the amount you paid.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await context.read<GroupRepository>().declareDues(
            widget.group.id,
            amount: amount,
            periodLabel: _period.text.trim().isEmpty ? null : _period.text.trim(),
            paidOn: _paidOn?.toIso8601String().split('T').first,
            method: _method,
            reference: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
          );
      widget.onSaved('Recorded. The treasurer will confirm it against the account.');
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Record a payment you have made', style: theme.textTheme.titleSmall),
          const Gap.lg(),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '${widget.group.duesCurrency} ',
                  ),
                ),
              ),
              const Gap.hMd(),
              Expanded(
                child: TextField(
                  controller: _period,
                  decoration: const InputDecoration(
                    labelText: 'What for',
                    hintText: '2026, or Q1 2026',
                  ),
                ),
              ),
            ],
          ),
          const Gap.lg(),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          final DateTime? chosen = await showDatePicker(
                            context: context,
                            initialDate: _paidOn ?? DateTime.now(),
                            firstDate: DateTime(DateTime.now().year - 5),
                            lastDate: DateTime.now(),
                          );
                          if (chosen != null) setState(() => _paidOn = chosen);
                        },
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(
                    _paidOn == null
                        ? 'When did you pay?'
                        : Formatters.date(_paidOn!.toIso8601String()),
                  ),
                ),
              ),
              const Gap.hMd(),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _method,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'How', isDense: true),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'bank_transfer',
                      child: Text('Bank transfer'),
                    ),
                    DropdownMenuItem<String>(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem<String>(
                      value: 'mobile_money',
                      child: Text('Mobile money'),
                    ),
                    DropdownMenuItem<String>(value: 'other', child: Text('Something else')),
                  ],
                  onChanged: _busy ? null : (String? v) => setState(() => _method = v ?? _method),
                ),
              ),
            ],
          ),
          const Gap.lg(),
          TextField(
            controller: _reference,
            decoration: const InputDecoration(
              labelText: 'Reference (optional)',
              helperText: 'The transfer reference or receipt number, so the treasurer can find it.',
            ),
          ),
          if (_error != null) ...<Widget>[
            const Gap.md(),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const Gap.lg(),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy ? const Text('Recording…') : const Text('Record it'),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, this.onSettle});

  final DuesPayment payment;
  final void Function(String state)? onSettle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool confirmed = payment.state == 'confirmed';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${payment.currency} ${Formatters.number(payment.amount.round())}'
                  '${payment.periodLabel == null ? '' : ' · ${payment.periodLabel}'}',
                  style: theme.textTheme.titleSmall,
                ),
                if (payment.payerName != null && onSettle != null)
                  Text(payment.payerName!, style: theme.textTheme.bodySmall),
                Text(
                  <String?>[
                    payment.paidOn == null ? null : Formatters.date(payment.paidOn),
                    payment.reference,
                  ].whereType<String>().join(' · '),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          // "Recorded" and "confirmed" are different claims, and the interface
          // must never let them blur: one is what a member said, the other is
          // what the treasurer checked.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: (confirmed ? AppColors.success : AppColors.warning).withValues(alpha: 0.15),
              borderRadius: AppRadius.smAll,
            ),
            child: Text(payment.stateLabel, style: theme.textTheme.labelSmall),
          ),
          if (onSettle != null) ...<Widget>[
            const Gap.hSm(),
            if (!confirmed)
              IconButton(
                tooltip: 'Confirm against the account',
                icon: const Icon(Icons.check, size: 18),
                onPressed: () => onSettle!('confirmed'),
              ),
            IconButton(
              tooltip: 'Query it',
              icon: const Icon(Icons.help_outline, size: 18),
              onPressed: () => onSettle!('disputed'),
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// The officers' side
// ===========================================================================

/// RUNNING A GROUP.
///
/// Everything an officer of this group may do, and nothing they may do
/// elsewhere. The authority behind this page is one row in `group_admins` for
/// this group; it grants nothing anywhere else in the archive, which is what
/// makes it safe to hand a community the running of its own page.
class GroupManagePage extends StatefulWidget {
  const GroupManagePage({required this.slug, super.key});

  final String slug;

  @override
  State<GroupManagePage> createState() => _GroupManagePageState();
}

class _GroupManagePageState extends State<GroupManagePage> {
  int _reloads = 0;
  String? _notice;

  void _reload([String? notice]) => setState(() {
        _reloads += 1;
        _notice = notice;
      });

  @override
  Widget build(BuildContext context) {
    final GroupRepository repository = context.read<GroupRepository>();

    return AsyncContent<CommunityGroup>(
      key: ValueKey<int>(_reloads),
      load: () => repository.show(widget.slug),
      loadingMessage: 'Opening…',
      builder: (BuildContext context, CommunityGroup group) {
        if (!group.viewer.isOfficer) {
          return AppScaffold(
            currentPath: AppRoutes.groups,
            child: PageSection(
              title: group.title,
              child: const EmptyView(
                icon: Icons.lock_outline,
                title: 'This is for the officers of this group',
                message: 'If you are one and you are seeing this, ask its lead officer to '
                    'appoint you.',
              ),
            ),
          );
        }

        return AppScaffold(
          currentPath: AppRoutes.groups,
          seo: SeoMetadata(
            title: 'Manage — ${group.title}',
            description: 'Run ${group.title}.',
            canonicalPath: AppRoutes.groupManage(group.slug),
            noIndex: true,
          ),
          child: PageSection(
            eyebrow: group.title,
            title: 'Running this group',
            description:
                'Requests to join, its dues and where they are sent, and anything its members '
                'have raised.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_notice != null) ...<Widget>[
                  _Banner(message: _notice!),
                  const Gap.lg(),
                ],
                TextButton.icon(
                  onPressed: () => context.go(AppRoutes.group(group.slug)),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back to its page'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
                const Gap.xl(),
                _JoinRequests(group: group, onChanged: _reload),
                const Gap.xxl(),
                _PaymentAccounts(group: group, onChanged: _reload),
                const Gap.xxl(),
                _OfficerDues(group: group, onChanged: _reload),
                const Gap.xxl(),
                _Issues(group: group, onChanged: _reload),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _JoinRequests extends StatelessWidget {
  const _JoinRequests({required this.group, required this.onChanged});

  final CommunityGroup group;
  final void Function([String? notice]) onChanged;

  @override
  Widget build(BuildContext context) {
    final GroupRepository repository = context.read<GroupRepository>();
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('People asking to join', style: theme.textTheme.titleMedium),
        const Gap.md(),
        AsyncContent<List<Map<String, dynamic>>>(
          load: () => repository.joinRequests(group.id),
          isEmpty: (List<Map<String, dynamic>> items) => items.isEmpty,
          emptyBuilder: (BuildContext context) => Text(
            'Nobody is waiting.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          builder: (BuildContext context, List<Map<String, dynamic>> items) => Column(
            children: items
                .map(
                  (Map<String, dynamic> item) => Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: AppRadius.smAll,
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                Json.str(item, 'full_name', fallback: 'Somebody'),
                                style: theme.textTheme.bodyMedium,
                              ),
                              if (Json.strOrNull(item, 'request_note') != null)
                                Text(
                                  Json.str(item, 'request_note'),
                                  style: theme.textTheme.bodySmall,
                                ),
                              if (Json.intOrNull(item, 'birth_year') != null)
                                Text(
                                  'Born ${Json.intVal(item, 'birth_year')}',
                                  style: theme.textTheme.labelSmall,
                                ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await repository.decideRequest(Json.str(item, 'id'), accept: false);
                            onChanged('Declined.');
                          },
                          child: const Text('Decline'),
                        ),
                        const Gap.hSm(),
                        FilledButton(
                          onPressed: () async {
                            await repository.decideRequest(Json.str(item, 'id'), accept: true);
                            onChanged('Welcomed in.');
                          },
                          child: const Text('Accept'),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

/// Where the dues go.
///
/// Adding or changing these is restricted to the treasurer and the lead
/// officer, and every change keeps a record of what the value was before —
/// redirecting a community's dues is the obvious way to steal from one, and the
/// group should never have to take anybody's word for what an account number
/// used to be.
class _PaymentAccounts extends StatefulWidget {
  const _PaymentAccounts({required this.group, required this.onChanged});

  final CommunityGroup group;
  final void Function([String? notice]) onChanged;

  @override
  State<_PaymentAccounts> createState() => _PaymentAccountsState();
}

class _PaymentAccountsState extends State<_PaymentAccounts> {
  final TextEditingController _bank = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _number = TextEditingController();
  bool _adding = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _bank.dispose();
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_bank.text.trim().isEmpty || _name.text.trim().isEmpty || _number.text.trim().isEmpty) {
      setState(() => _error = 'The bank, the account name and the number are all needed.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await context.read<GroupRepository>().addPaymentAccount(
            widget.group.id,
            bankName: _bank.text.trim(),
            accountName: _name.text.trim(),
            accountNumber: _number.text.trim(),
          );
      _bank.clear();
      _name.clear();
      _number.clear();
      setState(() => _adding = false);
      widget.onChanged('Saved. Members can see these details; the public cannot.');
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (!widget.group.viewer.isTreasurer) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Where members send the dues', style: theme.textTheme.titleMedium),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _adding = !_adding),
              icon: Icon(_adding ? Icons.close : Icons.add, size: 16),
              label: Text(_adding ? 'Cancel' : 'Add an account'),
            ),
          ],
        ),
        const Gap.xs(),
        Text(
          'Shown to members of this group only. Never on a public page.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const Gap.md(),
        ...widget.group.paymentAccounts.map(
          (GroupPaymentAccount account) => Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: AppRadius.smAll,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(account.bankName, style: theme.textTheme.titleSmall),
                SelectableText(account.accountNumber, style: theme.textTheme.bodyMedium),
                Text(account.accountName, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
        if (_adding) ...<Widget>[
          const Gap.md(),
          TextField(
            controller: _bank,
            decoration: const InputDecoration(labelText: 'Bank', isDense: true),
          ),
          const Gap.md(),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Account name', isDense: true),
          ),
          const Gap.md(),
          TextField(
            controller: _number,
            decoration: const InputDecoration(labelText: 'Account number', isDense: true),
          ),
          if (_error != null) ...<Widget>[
            const Gap.sm(),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const Gap.md(),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save these details'),
          ),
        ],
      ],
    );
  }
}

class _OfficerDues extends StatelessWidget {
  const _OfficerDues({required this.group, required this.onChanged});

  final CommunityGroup group;
  final void Function([String? notice]) onChanged;

  @override
  Widget build(BuildContext context) {
    final GroupRepository repository = context.read<GroupRepository>();
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Payments members have recorded', style: theme.textTheme.titleMedium),
        const Gap.xs(),
        Text(
          'Check each against the account, then confirm it. Confirming here is a record that you '
          'have seen the money — the website never handles it.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const Gap.md(),
        AsyncContent<({List<DuesPayment> items, List<Map<String, dynamic>> summary})>(
          load: () => repository.dues(group.id),
          isEmpty: (({List<DuesPayment> items, List<Map<String, dynamic>> summary}) d) =>
              d.items.isEmpty,
          emptyBuilder: (BuildContext context) => Text(
            'Nothing recorded yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          builder: (
            BuildContext context,
            ({List<DuesPayment> items, List<Map<String, dynamic>> summary}) data,
          ) =>
              Column(
            children: data.items
                .map(
                  (DuesPayment payment) => _PaymentRow(
                    payment: payment,
                    onSettle: (String state) async {
                      await repository.settleDues(payment.id, state: state);
                      onChanged(state == 'confirmed' ? 'Confirmed.' : 'Queried.');
                    },
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _Issues extends StatelessWidget {
  const _Issues({required this.group, required this.onChanged});

  final CommunityGroup group;
  final void Function([String? notice]) onChanged;

  @override
  Widget build(BuildContext context) {
    final GroupRepository repository = context.read<GroupRepository>();
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('What members have raised', style: theme.textTheme.titleMedium),
        const Gap.md(),
        AsyncContent<({List<GroupIssue> items, bool isOfficer})>(
          load: () => repository.issues(group.id),
          isEmpty: (({List<GroupIssue> items, bool isOfficer}) d) => d.items.isEmpty,
          emptyBuilder: (BuildContext context) => Text(
            'Nothing has been raised.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          builder: (BuildContext context, ({List<GroupIssue> items, bool isOfficer}) data) =>
              Column(
            children: data.items
                .map(
                  (GroupIssue issue) => Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: AppRadius.smAll,
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(issue.subject, style: theme.textTheme.titleSmall),
                            ),
                            Text(issue.stateLabel, style: theme.textTheme.labelSmall),
                          ],
                        ),
                        if (issue.raisedByName != null)
                          Text(
                            'Raised by ${issue.raisedByName}',
                            style: theme.textTheme.labelSmall,
                          ),
                        if (issue.detail != null) ...<Widget>[
                          const Gap.sm(),
                          Text(issue.detail!, style: theme.textTheme.bodySmall),
                        ],
                        if (issue.state == 'open') ...<Widget>[
                          const Gap.md(),
                          Row(
                            children: <Widget>[
                              TextButton(
                                onPressed: () async {
                                  await repository.settleIssue(
                                    issue.id,
                                    state: 'acknowledged',
                                  );
                                  onChanged('Marked as seen.');
                                },
                                child: const Text('Mark as seen'),
                              ),
                              const Gap.hSm(),
                              FilledButton(
                                onPressed: () async {
                                  await repository.settleIssue(issue.id, state: 'resolved');
                                  onChanged('Marked resolved.');
                                },
                                child: const Text('Resolved'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
